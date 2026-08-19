# 2. Nav2 is built from source until Lyrical binaries are complete

Date: 2026-08-18

Status: accepted

## Context

Nav2 is only partially released for ROS 2 Lyrical. As of August 2026,
`packages.ros.org` provides the low-level packages — `nav2_common`,
`nav2_costmap_2d`, `nav2_msgs`, `nav2_ros_common`, `nav2_util`, `nav2_voxel_grid`
and the minimal TurtleBot simulations — but not the servers, the behaviour tree
navigator, or `nav2_bringup`.

The `lyrical` branch of `ros-navigation/navigation2` exists and is being
maintained, so the source is available even though the binaries are not.

## Decision

`harp3_navigation` declares in its `package.xml` only the Nav2 packages that
`rosdep` can currently resolve. The remainder is obtained by building the
`lyrical` branch of `ros-navigation/navigation2` from source, declared as a
commented entry in `dependencies.repos`.

## Consequences

A first-time setup requires a source build of Nav2, which is slow. The entry stays
commented out so that cloning and building this repository alone does not silently
pull in that cost.

Once the Lyrical binaries are complete, the entry is deleted from
`dependencies.repos`, the missing packages are added to the `package.xml` of
`harp3_navigation`, and this record is marked superseded. Nothing else changes.
