# harp3_manipulation

Inverse kinematics, grasp sequencing and gripper control for the HARP3 arm,
exposed as actions defined in `harp3_msgs`.

This package is a peer of `harp3_navigation`: both turn a goal into motion, both
drive the controllers, neither depends on the other, and `harp3_behavior` is the
only package that sequences them.

The arm's joints are ordinary `ros2_control` actuators driven by
`joint_trajectory_controller`. The boundary is the real-time loop: an inverse
kinematic solve allocates, may fail and wants to log, so it cannot live in a
controller. Whether MoveIt is used for the planning above them is not decided; the
choice changes the contents of this package but not its interface. See
`docs/adr/0004-manipulation-placement.md`.

The gripper is the likely trigger for creating `harp3_controllers`: no gripper
action controller is released for Lyrical. See
`docs/adr/0006-deferred-packages.md`.

Nothing lives here yet.
