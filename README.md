# harp3

ROS 2 software stack for the HARP3 robot.

> **Status: skeleton.** The repository layout, conventions and tooling are in
> place; no node, controller or launch file has been written yet.

## Target platform

| Item | Version |
| --- | --- |
| ROS 2 | Lyrical Luth (LTS, supported until May 2031) |
| Ubuntu | 26.04 (Resolute Raccoon) |
| Simulator | Gazebo Jetty, via `ros_gz` |
| C++ | 17 |

## Repository layout

This repository *is* the content of a colcon `src` directory: packages live at
the root so that the stack stays releasable with `bloom` and importable with
`vcs import`. It is not a workspace, and does not contain one.

| Package | Layer | Responsibility |
| --- | --- | --- |
| `harp3_msgs` | contracts | The vocabulary the other packages speak: messages, services and actions. Depends on nothing else, which is what lets it be depended on by everything. |
| `harp3_description` | contracts | The single source of truth for the robot's physical dimensions: xacro, meshes, and the `<ros2_control>` block that declares the interface slots controllers bind to. No code. |
| `harp3_simulation` | devices | Gazebo Jetty worlds, the competition table, and the `gz_ros2_control` wiring that substitutes the real hardware. Replaces the two bottom layers rather than adding to them. No code. |
| `harp3_perception` | estimation | Turns raw sensor data into statements about the world: where the opponent is, where the game elements are. Publishes `harp3_msgs` types and knows nothing of Nav2. |
| `harp3_navigation` | skills | Everything that answers "where am I" and "how do I get there": the EKF, AMCL, the map, the Nav2 configuration, and the `OpponentLayer` costmap plugin. Sole publisher of `map → odom` and `odom → base_footprint`. |
| `harp3_manipulation` | skills | Everything above the arm's trajectory controller: inverse kinematics, grasp sequencing, the gripper. A peer of navigation, not a client of it. |
| `harp3_behavior` | mission | The only package that knows a match lasts 100 seconds. Sequences the skills as BehaviorTree.CPP trees and owns the end-of-match watchdog. |
| `harp3_ui` | interface | The touchscreen on the robot: side and strategy selection before the match, state and diagnostics during it. Observational once started — it must never be able to cost match time. |
| `harp3_bringup` | composition | The single entry point. Composes the launch files the other packages own, and configures only what no single package can: the `controller_manager`, `twist_mux`, the joystick. No code. |

Those layers describe the flow of data at runtime, not the build graph. At build
time only `harp3_msgs` and `harp3_description` are depended upon, and
`harp3_bringup` depends on everything while nothing depends on it. Packages in
between are mutually independent and talk over topics, services and actions, so
each can be rebuilt, replaced and tested on its own. The two graphs are drawn
separately in [`docs/architecture.md`](docs/architecture.md).

Four packages the architecture provides for do not exist yet, because upstream
code currently does their job: `harp3_hardware` (`mock_components` and
`gz_ros2_control` fill the interface slots), `harp3_sensors` (every sensor so far
ships a driver), `harp3_controllers` (`omni_wheel_drive_controller` and
`joint_trajectory_controller`) and `harp3_safety`. Each has a written trigger in
[ADR 0006](docs/adr/0006-deferred-packages.md), so that its absence is a decision
rather than an omission.

There is deliberately no `harp3_common` or `harp3_utils` package, because such a
package inevitably becomes a shared dependency that collapses that independence.

## Getting started

Binary assets are tracked with [git-lfs](https://git-lfs.com/), so install it
before adding or checking out any mesh:

```bash
sudo apt install git-lfs && git lfs install
```

```bash
# 1. Clone into the src directory of a colcon workspace
mkdir -p ~/harp3_ws/src && cd ~/harp3_ws/src
git clone https://github.com/robotcopper/harp3.git

# 2. Resolve dependencies
cd ~/harp3_ws
rosdep install --from-paths src --ignore-src -r -y

# 3. Build
source /opt/ros/lyrical/setup.bash
export COLCON_DEFAULTS_FILE=$PWD/src/harp3/colcon_defaults.yaml
colcon build
```

Third-party packages that have no binary release for Lyrical are listed in
[`dependencies.repos`](dependencies.repos) and imported with
`vcs import src < src/harp3/dependencies.repos`.

## Documentation

* [`docs/architecture.md`](docs/architecture.md) — component and dependency overview.
* [`docs/adr/`](docs/adr) — architecture decision records.
* [`CONTRIBUTING.md`](CONTRIBUTING.md) — conventions and development workflow.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
