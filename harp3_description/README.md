# harp3_description

The xacro, the meshes and the `<ros2_control>` block. This package is the single
source of truth for every physical dimension of the robot: wheel radius, distance
from the centre to the wheels, joint limits. Never repeat one of those numbers in
a controller parameter file — `ros2_control` reads them from the URDF it is handed,
and two copies drift apart at the first mechanical change.

## The `<ros2_control>` block is a contract

It declares the named slots that controllers claim: a `<joint>` per wheel and per
arm axis, a `<sensor>` for the IMU, and a `<gpio>` for the pump, the valves, the
emergency stop state and the side selector. Those names are what every controller
binds to, so changing one here breaks the stack above.

The block names the plugin that fills the slots, chosen by the `hardware`
argument:

| `hardware` | Plugin | Use |
| --- | --- | --- |
| `mock` | `mock_components/GenericSystem` | default; mirrors commands to states, no physics |
| `sim` | `gz_ros2_control/GazeboSimSystem` | Gazebo Jetty |
| `real` | `harp3_hardware/Harp3System` | the robot, once that package exists |

`mock_components/GenericSystem` ships with `hardware_interface` and handles
`<gpio>` too: `initial_value` fakes the state of a selector, and
`mock_gpio_commands` lets an external node drive it. The whole control stack is
therefore exercisable before any electronics exist, which is why `harp3_hardware`
does not exist yet. See `docs/adr/0006-deferred-packages.md`.

Nothing lives here yet.
