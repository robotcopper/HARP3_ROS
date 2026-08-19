# 5. Navigation owns pose estimation, localization and mapping

Date: 2026-08-19

Status: accepted

## Context

Producing a pose for the robot involves three pieces that are usually discussed
separately. An EKF fuses wheel odometry and the IMU into a continuous, drift-prone
estimate. AMCL matches the laser against a stored map and corrects that estimate
in discrete jumps. A SLAM package builds the map in the first place.

The first instinct was to give pose estimation its own package, on the grounds
that it has to converge before navigation may be activated, and that isolating it
would keep the Nav2 source dependency out of it.

The second argument turned out to be void. AMCL *is* Nav2: `nav2_amcl` has no
binary release for Lyrical, so a separate pose estimation package would have
carried the same source dependency anyway.

The first argument is real but is about launch ordering, not about packaging.
`turtlebot4_navigation` demonstrates the resolution: it ships
`localization.launch.py`, `slam.launch.py` and `nav2.launch.py`, with one YAML
each, in a single package.

## Decision

`harp3_navigation` owns everything that answers "where am I" and "how do I get
there". Its boundary is stated in terms of the TF edges it produces rather than
its name: it is the sole publisher of `odom → base_footprint` and of
`map → odom`, and it holds the planning above them.

The launch files are split along those edges, not bundled:

| Launch file | Starts | Produces |
| --- | --- | --- |
| `odometry.launch.py` | the EKF | `odom → base_footprint` |
| `localization.launch.py` | AMCL and the map server | `map → odom` |
| `nav2.launch.py` | the Nav2 servers | plans and velocity commands |
| `slam.launch.py` | `slam_toolbox` | a map, off-match |

SLAM does not get a package. On a table whose geometry is known, the map is
produced once per season, and neither `slam_toolbox` nor `cartographer_ros` has a
Lyrical binary. Its entry in `dependencies.repos` stays commented out so that
whoever remakes the map pays for the source build and nobody else does.

## Consequences

The startup ordering that motivated a separate package is preserved, because the
EKF can be launched without AMCL and AMCL without Nav2. A teleoperation session or
a manipulation test brings up `odometry.launch.py` alone.

This package becomes the largest in the repository and mixes a C++ costmap plugin
with four sets of configuration. The name also now covers pose estimation, which
is a mild stretch; the TF-edge formulation above is what keeps the boundary
checkable in spite of it.

The base controller must run with `enable_odom_tf: false`. The EKF owns
`odom → base_footprint`, and a controller left at its default would publish the
same edge.
