# 4. Manipulation is a peer of navigation, and the MoveIt question is deferred

Date: 2026-08-18

Status: accepted

## Context

HARP3 has an arm as well as a base. Two questions arrive together and are easy to
conflate: where manipulation code lives, and whether MoveIt is used to implement
it.

The second question is genuinely open. MoveIt brings planning, collision checking
and a large configuration surface; for an arm with few degrees of freedom and a
known set of grasps, a closed-form inverse kinematic and a trajectory controller
may be the whole of it. There is not enough information yet to choose.

The first question is not open, and answering it now is what allows the second to
be postponed. If manipulation is instead folded into `harp3_behavior`, mission
sequencing and arm kinematics end up in one package, and adopting MoveIt later
means splitting a package that has grown dependencies in both directions.

## Decision

`harp3_manipulation` sits at the same layer as `harp3_navigation`. It exposes
actions defined in `harp3_msgs`, it drives `harp3_controllers`, and it does not
depend on `harp3_navigation` nor `harp3_navigation` on it. `harp3_behavior` is the
only package that sequences the two.

The arm's joints are ordinary `ros2_control` actuators, driven by
`joint_trajectory_controller`. `harp3_manipulation` owns everything above that:
the inverse kinematics for this arm, grasp sequencing and the gripper.

That boundary is set by the real-time constraint, not by taste. A controller runs
inside the `controller_manager` update loop, where an inverse kinematic solve — which
allocates, may fail and wants to log — cannot go. Putting the arm's motion planning
in a controller would break the rule stated in `AGENTS.md`.

Whether MoveIt is used is left undecided. If it is adopted, it arrives as a
generated `harp3_moveit_config` package, following the conventional
`<robot>_moveit_config` naming, and `harp3_manipulation` shrinks to task-level
glue between MoveIt and `harp3_behavior`.

## Consequences

The MoveIt decision changes the contents of `harp3_manipulation` but not its
interface, its position in the layering, or any other package. It can therefore
be taken once the arm's kinematics and the required grasps are known, rather than
now.

In exchange, the stack carries a package whose internals are not yet designed, and
the actions it exposes have to be defined in `harp3_msgs` before either
implementation can begin.
