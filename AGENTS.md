# Agent instructions for the harp3 repository

This is a ROS 2 robotics stack written in C++. Follow these conventions without
being asked, and say so explicitly if a request would require breaking one.

## Target platform

ROS 2 Lyrical Luth on Ubuntu 26.04, Gazebo Jetty via `ros_gz`, C++17. Do not add
code, dependencies or instructions that target Humble, Jazzy or Gazebo Classic.

Before declaring a dependency in a `package.xml`, verify that it is actually
released for Lyrical (`apt-cache show ros-lyrical-<name>`). Nav2 is only partially
released; see `docs/adr/0002-nav2-source-dependency.md`. Anything unavailable as a
binary belongs in `dependencies.repos`, not in a `package.xml`.

## Repository structure

Packages live at the root. This repository is the content of a colcon `src`
directory and must never contain a workspace, a `ros2_ws/` directory, or a git
submodule.

Dependencies flow in one direction. `harp3_msgs` and `harp3_description` depend on
no other `harp3_*` package. `harp3_bringup` depends on the others and nothing
depends on it. Never introduce a `harp3_common` or `harp3_utils` package; put
shared code in the lowest package that legitimately owns it.

Packages in the middle layer are independent of each other at build time.
`harp3_navigation` does not depend on `harp3_perception`, and
`harp3_manipulation` does not depend on `harp3_navigation`. They communicate over
topics, services and actions. Never turn a runtime relationship into a
`package.xml` dependency; see `docs/architecture.md`, which documents the build
graph and the runtime graph separately.

`harp3_bringup`, `harp3_description` and `harp3_simulation` contain no source
code.

A package is created when no upstream code can do its job, and deferred while one
can. `harp3_hardware`, `harp3_sensors`, `harp3_controllers` and `harp3_safety` are
deferred for that reason, each with a written trigger in
`docs/adr/0006-deferred-packages.md`. Do not create one of them without meeting
its trigger, and do not propose a package that duplicates an upstream one:
`omni_wheel_drive_controller` already drives a three-wheel holonomic base, and
`mock_components/GenericSystem` already fills the `ros2_control` interface slots.

The boundary those deferred packages would enforce still applies. A device that
the `controller_manager` update loop needs a value from is a `ros2_control`
plugin; any other device is a `LifecycleNode`, and only if no upstream driver
exists — an upstream driver is an `exec_depend` and a parameter file, never a
wrapper package. See `docs/adr/0003-hardware-boundary.md`.

## Launch files and parameters

Every package that produces runtime behaviour ships both the launch file that
starts it and the parameter file that configures it, in its own `launch/` and
`config/`. The Nav2, AMCL and EKF parameters belong in `harp3_navigation`, not in
`harp3_bringup`.

`harp3_bringup` composes and does not configure: it includes those launch files
and passes arguments. Its `config/` holds only what no single package can own —
the `controller_manager` YAML, which spans the hardware component and the
controllers, the `twist_mux` arbitration, the joystick mapping and per-robot
overrides.

Sequence startup with lifecycle transitions, never with `TimerAction` delays: a
delay calibrated on a laptop fails on the robot.

## Naming

Package names follow REP-144: lowercase letters, digits and underscores only, and
always the `harp3_` prefix. Never use capitals in a package, file, or directory
name, including for configuration files.

| Item | Convention |
| --- | --- |
| Source file | `snake_case.cpp` |
| Header | `snake_case.hpp`, never `.h` for C++ |
| Header location | `include/<package_name>/`, matching the package name exactly |
| Namespace | matches the package name, `snake_case` |
| Class, struct, enum | `CamelCase` |
| Function, method | `snake_case` |
| Member variable | `snake_case_` with a trailing underscore |
| Constant | `kCamelCase` |
| Macro | `UPPER_CASE` |
| Launch file | `<name>.launch.py` |
| Topic, service, action, parameter | `snake_case` |

## Runtime conventions

Units and frames follow REP-103 and REP-105: SI units, metres, radians,
right-handed frames, x forward, y left, z up, and the frame names `map`, `odom`,
`base_link`, `base_footprint`.

Declare topics and services with relative names, never absolute ones, so the stack
can be pushed into a namespace.

Always set QoS explicitly. Sensor streams use `rclcpp::SensorDataQoS()`; latched
data such as `robot_description` uses a transient-local profile.

Velocity commands are `geometry_msgs/TwistStamped`. Bare `Twist` is silently
ignored by the controllers and by Nav2 since Jazzy; `use_stamped_vel` no longer
exists.

Every TF edge has exactly one publisher. `harp3_navigation` owns `map → odom` and
`odom → base_footprint`, so a base controller is configured with
`enable_odom_tf: false`.

## C++ conventions

Write nodes as classes deriving from `rclcpp::Node`, compiled into a shared library
and registered with `rclcpp_components_register_node`. Do not write a standalone
`main()` with a `spin()` loop unless explicitly asked.

Anything owning hardware, or requiring a defined startup and shutdown order,
derives from `rclcpp_lifecycle::LifecycleNode`.

Declare parameters with `generate_parameter_library` from a YAML specification in
`src/<package>_parameters.yaml`. Do not hand-write `declare_parameter` and
`get_parameter` calls. The one exception is a `ros2_control` hardware component,
which is not a node and takes its configuration from `<param>` tags in the xacro.

Code inside the `controller_manager` update loop must not allocate, lock or log.
Data enters it through `realtime_tools::RealtimeBuffer`.

Use modern target-based CMake: `target_link_libraries(<target> PUBLIC dep::dep)`
with exported targets, not directory-level `include_directories`.

## Tests

Unit tests use `ament_add_gtest` and live in `test/`. Integration tests that need a
running graph use `launch_testing`. Keep logic testable on the host: separate
computation from I/O so it does not require a robot or a simulator to exercise.

C++ style comes from the `.clang-format` and `.clang-tidy` at the repository root.
Those files are rules and never execute on their own; `.pre-commit-config.yaml` is
the trigger that decides what runs and when. Only `.clang-format` has one — the
`clang-tidy` checks, including the naming table above, run in the editor through
clangd and are advisory. Follow them anyway: nothing will catch a violation for
you.

Never add `ament_lint_common`, `uncrustify` or `cpplint` to a `package.xml`: they
carry their own incompatible style and would contradict those files. The only
linters wired into the build are `ament_cmake_lint_cmake` and
`ament_cmake_xmllint`, which cover what `pre-commit` does not.

## Documentation and commits

Record structural decisions as a numbered file in `docs/adr/`, stating context,
decision and consequences. Add one whenever a choice would otherwise have to be
re-explained later.

Commit messages follow Conventional Commits with the package as the scope, for
example `feat(harp3_navigation): add opponent costmap layer`.

## Things this repository deliberately does not have

There is no CI, no devcontainer, and no firmware. Do not add any of them unless
asked. Adding CI later is a single file in `.github/workflows/` and requires no
change to the packages.
