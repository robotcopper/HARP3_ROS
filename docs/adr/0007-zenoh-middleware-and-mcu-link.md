# 7. Zenoh on the host, and no ROS on the microcontrollers

Date: 2026-08-23

Status: accepted, superseded in part by
[ADR 0010](0010-pico-ros-on-the-motor-board.md): the mobile base board runs
Pico-ROS, and the firmware lives in its own repository.

## Context

Two decisions were on the table at once, and the first thing worth recording is
that they are separable — treating them as one is what makes this look hard.

The first is which middleware the host runs. `rmw_zenoh_cpp` is released for
Lyrical, has an upstream `lyrical` branch, and comes with `zenoh_security_tools`.
Zenoh removes the multicast discovery storms and the QoS-matching failures that
make DDS painful on a contested competition network, which is the reason to want
it.

The second is how the two microcontrollers are reached. HARP3 has two: one closing
the drive and arm loops — motors, encoders, IMU — and one driving auxiliary devices
— pumps, valves, time-of-flight sensors, the emergency-stop state, the side
selector. The boards are a Teensy 4.1 and an RP2040 class part.

micro-ROS is the obvious way to put ROS on a microcontroller, and it cannot be
combined with the first decision. Its agent's DDS side is Fast-DDS-only; DDS and
Zenoh do not interoperate at the wire level and upstream states they are not
expected to. Non-Fast-DDS hosts do not merely degrade, they fail silently: with a
Cyclone host, service replies are lost with no error. Since a host runs one RMW,
putting micro-ROS on the auxiliary board would cost Zenoh on the entire robot.

`rmw_zenoh_pico` exists to resolve exactly this, replacing XRCE-DDS under
`rcl`/`rclc` and speaking to `rmw_zenoh` with no agent. It is not usable here, for
four reasons that compound:

* Its supported targets are PC, Raspberry Pi and ESP32 dev kits. Neither Teensy
  nor RP2040 is among them.
* It tracks Zenoh 1.4.0. Lyrical's `rmw_zenoh_cpp` bundles Zenoh 1.8.0, and the
  ROS-level conventions — key expressions, attachments carrying the GID and
  sequence number, liveliness tokens — moved in between.
* micro-ROS has no Lyrical branch at all: `micro_ros_setup` supports Humble,
  Jazzy, Kilted and Rolling.
* It is a declared prototype with no graph-cache support, requiring a `zenohd`
  router for any microcontroller-to-host traffic, and needing forks of
  `micro_ros_setup` and `micro_ros_platformio`.

Writing against `zenoh-pico` directly, without micro-ROS, would mean
reimplementing that key and attachment mapping by hand. `rmw_zenoh_pico` exists
because that mapping is the hard part.

## Decision

The host runs `rmw_zenoh_cpp`. Neither microcontroller runs ROS.

Both are reached over a serial protocol, and the boundary between them is the one
[ADR 0003](0003-hardware-boundary.md) already draws, applied to two devices
instead of one:

| Board | In the update loop? | Mechanism |
| --- | --- | --- |
| control: motors, encoders, IMU | yes | `ros2_control` `SystemInterface` in `harp3_hardware` |
| auxiliary: pumps, valves, ToF, e-stop state, side selector | no | `LifecycleNode` in `harp3_sensors` |

Nothing on the auxiliary board needs to be read to compute the next command. A
pump switched at 1 Hz and a side selector read once at startup are not real-time
data, so ADR 0003's test puts that board outside the control loop.

micro-ROS is reconsidered when both of these hold, and not before:

1. `micro_ros_setup` has a Lyrical branch.
2. `rmw_zenoh_pico` targets Zenoh 1.8 or later *and* supports the board in use.

## Consequences

The firmware is independent of the middleware. Because the control link stops at a
`ros2_control` component and the auxiliary link at a lifecycle node, neither board
knows or cares which RMW the host runs. `RMW_IMPLEMENTATION` can be changed, or
reverted, without recompiling a line of embedded code — which also means this
decision is cheap to undo, unlike the micro-ROS one.

The cost is a second serial protocol to write, for the auxiliary board. It carries
booleans and small integers, so the frame is a few bytes; this is materially less
work than either alternative.

Zenoh needs a router. `rmw_zenoh_cpp` operates with a `rmw_zenohd` process, which
becomes an element of `harp3_bringup` and a new way for startup to fail. Bring it
up early rather than discovering it the day before a match.

Both triggers in [ADR 0006](0006-deferred-packages.md) are now met by this
hardware plan. The control board supplies the first `<param name="port">`, which
creates `harp3_hardware`; the auxiliary board is a device with no upstream driver,
which creates `harp3_sensors`.

This repository now has firmware, which `AGENTS.md` said it did not. Where that
firmware lives is deliberately left open here: a PlatformIO project is not a colcon
package, so it is either a separate repository or a `firmware/` directory carrying
a `COLCON_IGNORE` marker. That belongs in its own record, once the question is
answered.
