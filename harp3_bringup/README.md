# harp3_bringup

The single entry point of the stack. This package composes and does not
configure: it includes the launch files that other packages own, passes them
arguments, and holds only the configuration that no single package can own.

```
launch/   harp3.launch.py       the entry point: hardware, namespace, strategy, side
          robot.launch.py       description, control, sensors
          autonomy.launch.py    localization, perception, navigation, manipulation, behaviour
          teleop.launch.py      joystick, for development only
config/   controllers.yaml      the controller_manager, spanning hardware and controllers
          twist_mux.yaml        arbitration between navigation, behaviour and joystick
          joy.yaml              button mapping
rviz/     the layout for the running robot
```

## Why these three files and not one

`robot.launch.py` brings up everything that makes the robot a robot: the
description, the `controller_manager` with its hardware component, the
controllers, the sensors and the EKF. After it, the robot can be driven and knows
where it is relative to where it started.

`autonomy.launch.py` adds AMCL, the map, Nav2 and the skills. After it, the robot
knows where it is on the table and can be given goals.

The split matters because the first half must be usable on its own, for any test
that moves the robot without navigating it.

## Selecting the hardware

`harp3.launch.py` takes a `hardware` argument with three values, forwarded to the
xacro in `harp3_description`:

| Value | Plugin loaded | Use |
| --- | --- | --- |
| `mock` | `mock_components/GenericSystem` | no physics, no Gazebo; commands mirror to states |
| `sim` | `gz_ros2_control/GazeboSimSystem` | Gazebo Jetty |
| `real` | `harp3_hardware/Harp3System` | the robot, once that package exists |

Nothing above `robot.launch.py` is aware of which one was selected.

## Arbitration, not remapping

Three sources want to command the base: Nav2, the joystick and, occasionally, the
behaviour tree. `twist_mux` is the arbiter, with the joystick above navigation in
priority and the emergency stop wired as a lock rather than as a command source.
Its output is remapped onto the base controller's `cmd_vel`.

Set `use_stamped: true` in `twist_mux.yaml`. It is no longer declared
automatically since version 4.5.0, and the controllers only accept
`geometry_msgs/TwistStamped`.
