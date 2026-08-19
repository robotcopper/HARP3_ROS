# 6. A package exists when upstream code cannot do its job

Date: 2026-08-19

Status: accepted

## Context

The repository was scaffolded with one package per architectural layer, all of
them empty. That is a defensible way to state a target architecture, but it makes
every absence ambiguous: a reader cannot tell whether a missing package is a
decision or an oversight, and an empty package still costs a `package.xml`, a
`CMakeLists.txt`, a README and a build step on every compile.

"Delete the empty ones" is not a usable criterion, because at this point every
package is empty. It would delete the whole stack.

There is a better criterion. Some layers have an upstream implementation that
already does the job: `mock_components/GenericSystem` and
`gz_ros2_control/GazeboSimSystem` both fill the `ros2_control` interface slots,
`omni_wheel_drive_controller` drives a three-wheel holonomic base,
`joint_trajectory_controller` executes arm trajectories, and every LiDAR in this
class ships with a driver. Other layers have no upstream equivalent by
construction: nobody else can define this robot's actions, describe its geometry,
or encode its match strategy.

## Decision

A package is created when no upstream code can do its job, and deferred while one
can. Each deferred package has a written trigger, so that its absence is a
decision rather than an omission.

| Deferred package | Currently covered by | Trigger to create it |
| --- | --- | --- |
| `harp3_hardware` | `mock_components/GenericSystem`, `gz_ros2_control` | the first `<param name="port">`: a physical link to speak to |
| `harp3_sensors` | upstream drivers for every sensor so far | the first sensor with no upstream driver |
| `harp3_controllers` | `omni_wheel_drive_controller`, `joint_trajectory_controller` | the gripper controller, since no gripper action controller is released for Lyrical |

Deferring the implementation does not defer the interface. The `<ros2_control>`
block in `harp3_description` declares every joint, sensor and GPIO slot now, with
the names controllers bind to. The `hardware` xacro argument selects which plugin
fills them — `mock`, `sim`, or `real` — and only the `real` branch is missing.

`harp3_safety` is deferred on different grounds. Most of what it would contain has
a natural home already: `cmd_vel_timeout` in the controller configuration, joint
limits in the URDF, the `twist_mux` locks and the diagnostics aggregation in
`harp3_bringup`, `collision_monitor` in `harp3_navigation`, and the end-of-match
watchdog in `harp3_behavior`. Only the emergency-stop state watcher and the
localization-health monitor are homeless; they go in `harp3_behavior`, since it is
what must react. The trigger is a second package needing to react to the same
condition.

## Consequences

Nine packages exist instead of fourteen, and the four remaining absences are
documented with objective triggers rather than intentions.

The three-way `hardware` argument replaces the `use_sim` boolean that earlier
drafts of `docs/architecture.md` described. `mock` is the default, which means the
control stack is exercisable with neither hardware nor a simulator — the fastest
configuration for integration tests.

The risk is that a deferred package gets recreated badly under time pressure,
because the boundary it was meant to enforce is not visible in the tree. ADR 0003
and this file are the mitigation: the rules survive the packages.
