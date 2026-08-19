# harp3_navigation

This package owns two TF edges and the planning above them:

| Edge | Producer |
| --- | --- |
| `odom → base_footprint` | the `robot_localization` EKF, fusing wheel odometry and the IMU |
| `map → odom` | AMCL, matching the laser against the stored map |

Nothing else in the stack may publish either one. In particular the base
controller must run with `enable_odom_tf: false`, otherwise it and the EKF
publish the same edge and TF interpolates between two competing truths.

## Layout

```
config/   ekf.yaml, amcl.yaml, nav2.yaml, slam.yaml
launch/   odometry.launch.py, localization.launch.py, nav2.launch.py, slam.launch.py
maps/     the table, produced once by slam.launch.py
src/      the OpponentLayer costmap plugin
```

The launch files are split along the two edges rather than bundled, because the
EKF has to run whenever the robot moves — a teleoperation session, a
manipulation test — while AMCL only makes sense with a map, and navigation only
starts once AMCL has converged. That ordering is the reason the four files exist
separately in one package.

## The opponent does not arrive as a fake laser scan

`harp3_perception` publishes `harp3_msgs/DetectionArray`, and the `OpponentLayer`
plugin here consumes it as a `nav2_costmap_2d::Layer`. This is what `src/` and
`include/` are for, and it keeps the perception side unaware that Nav2 exists.

## Source dependencies

Nav2 is only partially released for Lyrical: `nav2_costmap_2d`, `nav2_msgs`,
`nav2_util` and `nav2_ros_common` are available from `packages.ros.org`, but the
servers, `nav2_amcl` and `nav2_map_server` are not. `slam_toolbox` and
`cartographer_ros` have no Lyrical release either.

The Nav2 entry in `dependencies.repos` is therefore mandatory for this package to
run. The `slam_toolbox` entry is commented out on purpose: producing the map is a
once-a-season task, so whoever does it uncomments the entry rather than making
everyone build it. See `docs/adr/0002-nav2-source-dependency.md`.
