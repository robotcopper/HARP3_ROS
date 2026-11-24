# 12. The IMU and obstacle ring board, a second ROS node on Pico-ROS

Date: 2026-11-23

Status: accepted. Extends [ADR 0010](0010-pico-ros-on-the-motor-board.md) to a second
board, provisionally: [ADR 0011](0011-micro-ros-on-the-motor-board.md)'s port to
micro-ROS over `rmw_zenoh_pico` applies to it too.

## Context

The robot has a BNO085 IMU and a ring of 94 WS2812B LEDs around its plate, lit from
the lidar's scan: red where something is within 20 cm, green elsewhere. Neither
belongs on the mobile base board, whose firmware is about to be corrected and ported.
Both are on a Raspberry Pi Pico of their own.

[ADR 0007](0007-zenoh-middleware-and-mcu-link.md) keeps ROS off the other boards, and
ADR 0010 and ADR 0011 make the mobile base board the exception, with `AGENTS.md`
recording micro-ROS over `rmw_zenoh_pico` as what a microcontroller that runs ROS
uses. That port is not done: the mobile base board still runs Pico-ROS, and the
forks that make `rmw_zenoh_pico` run on the RP2040 are the board's own work in
progress.

The IMU and the ring follow the same ROS interfaces whichever stack carries them: a
`sensor_msgs/Imu` published, a `sensor_msgs/LaserScan` subscribed. The earlier
version of this firmware ran micro-ROS with an agent, which ADR 0007 excludes.

## Decision

The board runs the mobile base's stack as it is now: Pico-ROS on zenoh-pico over
Ethernet over USB, in its own directory of HARP3_uC, `imu_led_pico`, as the node
`/imu_led_pico`. It is a prototype, corrected and ported to micro-ROS together with
the mobile base board, and not before.

| Entity | Type | QoS |
| --- | --- | --- |
| `imu/bno085`, published at 100 Hz | `sensor_msgs/Imu`, frame `imu_link` | best effort |
| `scan`, subscribed | `sensor_msgs/LaserScan` | best effort |

The board's Ethernet over USB link is 192.168.8.0/24, not the mobile base's
192.168.7.0/24: both boards plug into the same host.

The ring shows, on each LED, the nearest valid measurement of the scan in the
directions the LED faces, seen from the lidar at the centre of `base_link`: red under
0.20 m, green otherwise, amber when a lidar has been silent for 0.5 s and blue while
the board has no session. Green is never shown without recent data.

The micro-ROS agent stays excluded, for ADR 0007's reason.

## Consequences

`AGENTS.md` says a microcontroller that runs ROS uses micro-ROS over
`rmw_zenoh_pico`. This board does not yet, by choice: it carries a second copy of
the Pico-ROS code that ADR 0011 retires, to be ported at the same time as the first.
The two boards share `picoros-usb-eth` and the type generator, so the port is the
same work done once for both.

The host needs, for the second subnet, what it has for the first: `chrony` allowing
192.168.8.0/24, and TCP 7447 and UDP 123 open to it. Each board adds a network
interface named after a MAC address derived from its unique ID.

The firmware compiles in the type hash of `Imu` and `LaserScan`: a ROS distribution
upgrade means regenerating `imu_led_types.h` and reflashing, as for the mobile base.
It exchanges no `harp3_msgs` type, so a change there does not touch it.

The threshold is measured from the lidar, which sees the plate 6.5 to 14 cm away
depending on the direction, and the robot's own structure. A mast or cable within
20 cm of the lidar keeps its LEDs red until that sector is masked, and a threshold
measured from the edge of the plate is a change to one function.

The IMU is published in its own axes, in `imu_link`. The transform from `base_link`
to `imu_link` belongs in `harp3_description` once the sensor's mounting is fixed,
and the sensor's use by the EKF in `harp3_navigation` is a separate step. The IMU is
an input to estimation, not to the `controller_manager` update loop, so
[ADR 0003](0003-hardware-boundary.md)'s boundary is respected.

The mobile base's controller configuration puts the wheels at -60, 60 and 180
degrees from `x` (`wheel_offset: -pi/3`), while the plate drawing the ring was
measured on has `+x` on a wheel. One of the two is to be checked when the mobile
base is corrected; the ring follows the drawing.
