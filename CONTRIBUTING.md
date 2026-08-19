# Contributing

## Development setup

Install the git hooks once per clone. They are the only style gate in this
repository, so skipping this step means unformatted code reaches `main`.

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

The last line is not required, but run it now: the hook only ever sees the files
you touch, so it never cleans up what is already committed.

Point colcon at the shared build settings so that everyone builds with the same
flags and `compile_commands.json` is generated for clangd:

```bash
export COLCON_DEFAULTS_FILE=/path/to/harp3_ws/src/harp3/colcon_defaults.yaml
```

## Rules and triggers

The configuration files at the repository root split into two kinds, and mixing
them up is the usual source of confusion about what is actually enforced.

`.clang-format` and `.clang-tidy` are **rules**. They state how code should look
and what it may not do, and they never execute on their own — something has to
invoke a tool that reads them.

`.pre-commit-config.yaml` is the **trigger**. It decides which tool runs, when,
and on which files. One says *how*, the other says *when*.

Two consequences follow, and neither is obvious from reading either file alone.

The trigger is inert until `pre-commit install` writes `.git/hooks/pre-commit`.
Before that, the rules exist and nothing applies them. This is why the setup step
above is not optional.

Of the two rule files, only `.clang-format` has a trigger. `clang-tidy` appears
nowhere in `.pre-commit-config.yaml`, because it has to compile the code to say
anything and would make every commit take minutes. It runs in the editor instead,
through clangd, which reads `.clang-tidy` by itself. Formatting is therefore
mechanically enforced while the `clang-tidy` checks — including the naming rules
below, which its `CheckOptions` section encodes — are advisory. Wiring
`clang-tidy` into CI on changed files is the obvious way to close that gap if it
ever matters.

For clangd to give any diagnostics at all it needs the compilation database, so
symlink the aggregated one from the workspace root:

```bash
ln -s build/compile_commands.json compile_commands.json
```

`pre-commit` is not a C++ tool, incidentally. `clang-format` is one of its four
hook sources; the others check that XML and YAML parse, normalise line endings and
trailing whitespace, catch misspellings, and run `ruff` over Python — which is what
covers every `*.launch.py` in this repository.

## What the build checks, and what it does not

The hooks really are the only style gate, and the packages are configured to keep
it that way. No package depends on `ament_lint_common`, because it pulls in
`uncrustify` and `cpplint`, whose built-in style contradicts the `.clang-format`
above and would make the two gates disagree on the same file. Packages depend only
on `ament_cmake_lint_cmake` and `ament_cmake_xmllint`, which lint CMake and
validate `package.xml` against its schema — neither of which `pre-commit` does.

Be aware that `ament_xmllint` fetches `package_format3.xsd` from
`download.ros.org` at test time, so `colcon test` reports it as failing on a
machine with no internet access. That failure is an artefact of being offline, not
a problem with the file.

## Naming conventions

Package names follow [REP-144](https://ros.org/reps/rep-0144.html): lowercase
letters, digits and underscores only. Every package in this repository is
prefixed with `harp3_`.

| Item | Convention | Example |
| --- | --- | --- |
| Package | `snake_case` | `harp3_navigation` |
| Source file | `snake_case.cpp` | `opponent_layer.cpp` |
| Header | `snake_case.hpp` | `opponent_layer.hpp` |
| Header location | `include/<package>/` | `include/harp3_navigation/opponent_layer.hpp` |
| Namespace | matches the package | `harp3_navigation` |
| Class, struct, enum | `CamelCase` | `OpponentLayer` |
| Function, method | `snake_case` | `update_costs` |
| Member variable | `snake_case_` | `inflation_radius_` |
| Constant | `kCamelCase` | `kDefaultTimeout` |
| Macro | `UPPER_CASE` | `HARP3_NAVIGATION_PUBLIC` |
| Launch file | `<name>.launch.py` | `robot_bringup.launch.py` |
| Topic, service, parameter | `snake_case` | `wheel_states` |

The `include/<package>/` nesting is not redundant: headers are installed into a
shared `include` directory, and the subdirectory prevents name collisions
between packages. The directory name must match the package name exactly.

## Where things go

* Every package that produces runtime behaviour ships both the launch file that
  starts it and the parameter file that configures it, in its own `launch/` and
  `config/`. The Nav2, AMCL and EKF parameters all live in `harp3_navigation`.
* `harp3_bringup` composes and does not configure. Its `config/` holds only what
  no single package can own: the `controller_manager` YAML, the `twist_mux`
  arbitration, the joystick mapping and per-robot overrides.
* A device whose measurement the `controller_manager` update loop needs is a
  `ros2_control` plugin. Every other device is a `LifecycleNode` — and only if it
  has no upstream driver, because an upstream driver is an `exec_depend` and a
  parameter file, not a package.
* A runtime relationship is never a `package.xml` dependency. See
  [`docs/architecture.md`](docs/architecture.md), which separates the build graph
  from the runtime graph.

## Before adding a package

Nine packages exist; the architecture provides for four more that upstream code
currently covers. Check [ADR 0006](docs/adr/0006-deferred-packages.md) before
creating one: it lists the trigger for each, and the upstream package that makes
it unnecessary until then. A package that duplicates an upstream one is the most
expensive mistake available here, because everything above it then has to be
rewritten when the duplicate is removed.

## Runtime conventions

* Units and coordinate conventions follow
  [REP-103](https://ros.org/reps/rep-0103.html): SI units, metres, radians,
  right-handed frames, x forward, y left, z up.
* Frame names follow [REP-105](https://ros.org/reps/rep-0105.html): `map`,
  `odom`, `base_link`, `base_footprint`.
* Topics and services are declared with **relative** names, never absolute ones,
  so that the whole stack can be pushed into a namespace.
* QoS is always explicit. Sensor streams use `rclcpp::SensorDataQoS()`; latched
  data such as `robot_description` uses a transient-local profile.

## C++ conventions

* Nodes are classes deriving from `rclcpp::Node`, built into a shared library
  and registered with `rclcpp_components_register_node`. Do not write a
  standalone `main()` with a `spin()` loop: composition is what allows the whole
  stack to run in a single process with zero-copy intra-process transport.
* Anything owning hardware or requiring a deterministic startup and shutdown
  sequence derives from `rclcpp_lifecycle::LifecycleNode`.
* Parameters are declared with
  [`generate_parameter_library`](https://github.com/PickNikRobotics/generate_parameter_library)
  from a YAML specification, not with hand-written `declare_parameter` calls.
* Real-time control paths perform no allocation, no locking and no logging. Data
  crosses into them through `realtime_tools::RealtimeBuffer`.

## Commits and changelog

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/),
with the package as the scope:

```
feat(harp3_navigation): add opponent costmap layer
fix(harp3_description): correct wheel separation in xacro
docs(adr): record the monorepo topology decision
```

Structural decisions are recorded as short files in `docs/adr/`, numbered
sequentially, stating the context, the options considered and the consequence.
Add one whenever a choice would otherwise have to be re-explained later.
