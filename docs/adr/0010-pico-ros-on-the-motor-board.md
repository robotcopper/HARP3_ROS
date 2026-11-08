# 10. Pico-ROS on the mobile base board

Date: 2026-11-03

Status: accepted, superseded in part by [ADR 0011](0011-micro-ros-on-the-motor-board.md):
the board runs micro-ROS over `rmw_zenoh_pico` rather than Pico-ROS; the link, the
entities, the motor cut-off and the restart stand. Supersedes in part
[ADR 0007](0007-zenoh-middleware-and-mcu-link.md): the rule that no
microcontroller runs ROS, for the mobile base board only.

## Context

ADR 0007 kept ROS off the microcontrollers for three reasons: micro-ROS cannot
talk to Zenoh, `rmw_zenoh_pico` targets neither the boards nor the Zenoh version in
use, and writing against `zenoh-pico` directly would mean reimplementing by hand
the mapping from ROS entities to Zenoh key expressions, attachments and liveliness
tokens.

The third reason no longer holds. [Pico-ROS](https://github.com/Pico-ROS/Pico-ROS-software)
(BSD-3) is that mapping, written in C on top of `zenoh-pico`, with no `rcl` and no
agent. A first spike on the RP2040 board, linked over USB CDC to `rmw_zenohd` with
`zenoh-pico` 1.8.0 — the Zenoh version Lyrical's `rmw_zenoh_cpp` bundles — passed
the criterion set for it: `ros2 node list`, `ros2 topic echo` in both directions
and `ros2 service call` work against stock Lyrical tools.

The serial link worked, but nothing around it was standard. The board's clock came
from a synchronisation written for it, timing round trips of a ROS service that
some other node had to be running to answer. The router had to open the board's
tty before the board started talking, so it needed a supervisor script, and a
replugged board moved to another tty. Flashing went through a topic or the
BOOTSEL button.

Ethernet over USB replaces each of those with a standard part: the USB CDC-NCM
class, which Linux drives with its own `cdc_ncm`; TCP, the default transport of
Zenoh and `rmw_zenoh`; SNTP (RFC 4330) against `chrony`, a system service with no
relation to ROS; and the reset interface `picotool` uses to flash a running board.
On the board this is lwIP under FreeRTOS, with the SNTP client and a one-lease
DHCP server from the Pico SDK.

Getting there needed changes, carried in forks until they are merged upstream, of
which these decided the outcome:

* `zenoh-pico` decoded a batch holding a best-effort frame followed by a reliable
  one as a single frame, failed on the second header and silently stopped its
  read task. `rmw_zenohd` sends such batches under load, so the link stalled after
  a few minutes. Upstream `main` has the same bug.
* `zenoh-pico` called a query reply callback after releasing the lock that
  protected it.
* `zenoh-pico`'s RP2040 network layer assumed the Pico W's Wi-Fi chip, and did not
  build a TCP link without it.
* Pico-ROS stamped the `rmw_zenoh_cpp` attachment with the time since boot, where
  `rmw_zenoh_cpp` puts the system clock that subscribers read as the source
  timestamp. It now reads the wall clock, which SNTP sets.
* Pico-ROS resolved `~` in service names but not in topic names, so a private
  topic `~/name` became `/~/name`, which no ROS tool can name.

Measured on the RP2040 over that link, with `ros2` command-line tools on the host.
The odometry figures come from the mobile base firmware reading its PAA5160E1, the
others from the example firmware of `picoros-usb-eth`:

| Quantity | Result |
| --- | --- |
| ICMP round trip | 0.92 ms mean, 0.84 to 1.04 ms |
| Wheel commands, host to board, 100 Hz | 1.5 ms mean, 0.95 to 2.0 ms |
| Odometry, sensor read to host, 100 Hz | 4 ms mean, 3 to 5 ms, of which reading the sensor takes 1.5 ms |
| Odometry period at 100 Hz | 0.2 ms standard deviation |
| Clock steps at each 15 s SNTP update | about 0.1 ms, with an occasional sample off by 0.6 ms |
| Idle time, 100 Hz in each direction | 81 % |

The latencies include the error of the board's clock, and the command-line tools'
own Python overhead. The link needed one setting to reach them: the board accepts
a single datagram per USB transfer, because the Linux driver otherwise holds each
frame for up to 1.2 ms waiting for others to batch with it.

The base board is the RP2040 board carried over from HARP2: three stepper motors
with no encoders, a PAA5160E1 optical odometry sensor and six limit switches.

On the host side, `joint_state_topic_hardware_interface` is released for Lyrical.
It is the upstream successor of `topic_based_ros2_control`, which HARP2 used: a
`ros2_control` system that publishes its commands as a `sensor_msgs/JointState`
topic and reads its states from another.

Of the two conditions ADR 0007 set for reconsidering micro-ROS, the first is now
met — `micro_ros_setup` has a `lyrical` branch — and the second is not:
`rmw_zenoh_pico`'s latest release is 1.4.0, pinned to `zenoh-pico` 1.4.0, and its
targets are ESP32 kits.

## Decision

The mobile base board runs `zenoh-pico` and Pico-ROS, and appears in the ROS graph
as an ordinary node. It is reached over Ethernet over USB: the board is
192.168.7.1, leases 192.168.7.2 to the host, and connects over TCP to `rmw_zenohd`
on the host, which runs with its default configuration. The board takes its clock
from `chrony` on the host over SNTP, and is flashed with `picotool`.

| Entity | Type | QoS |
| --- | --- | --- |
| `topic_based_joint_commands`, subscribed | `sensor_msgs/JointState` | best effort |
| `odom/paa5160e1`, published at 100 Hz | `nav_msgs/Odometry` | best effort |
| `limit_switches`, published on change | `harp3_msgs/LimitSwitches` | reliable, transient local, depth 1 |
| `reset_odometry`, served | `std_srvs/Trigger` | default |

The `real` branch of the `<ros2_control>` block in `harp3_description` is
`joint_state_topic_hardware_interface/JointStateTopicSystem`, configured to
publish on every cycle. `omni_wheel_drive_controller` runs open loop and publishes
no TF; the odometry sensor reaches the EKF in `harp3_navigation`, which keeps
`odom → base_footprint`.

The board stops its motors when no command has arrived for 200 ms. That single
rule covers the loss of the host, the router or the cable, and a stopped
controller.

When its session ends, the board disables the motor drivers and restarts. Closing
a `zenoh-pico` session and opening another hung the board in testing, and a
restart needs no teardown. It is warm: the odometry sensor stays powered and
keeps its pose.

The firmware lives outside this repository, in its own, and builds on
[`picoros-usb-eth`](https://github.com/robotcopper/picoros-usb-eth), a reusable
repository holding the Pico-ROS and `zenoh-pico` forks and the Ethernet-over-USB
platform. This repository holds only the interfaces the firmware is generated
from.

micro-ROS stays excluded, and ADR 0007 still governs every other board.

## Consequences

Motor commands now cross a topic and the router instead of a dedicated serial
protocol, with no bound on their latency. That is the price, and it buys
visibility: every message to and from the base can be echoed, recorded and
replayed with stock tools, there is no protocol to write or version, and no
`harp3_hardware` package to write either. The 200 ms cut-off is what makes an
unbounded link acceptable on a robot that moves.

The host needs configuration that a serial link did not: `chrony` serving the
192.168.7.0/24 subnet even without an upstream source, the firewall open to that
subnet for TCP 7447 and UDP 123, and the `picotool` udev rule. Each board adds a
network interface, named after a MAC address derived from the board's unique ID,
so the name is stable across reboots.

The board's odometry and limit switches wait for its first SNTP answer, so a host
without `chrony` gets a board that is in the graph but publishes no stamped data.

`zenoh-pico` expires the router after the shorter of the two leases, and the
default router configuration sends a keepalive only every 30 s, so the firmware
announces a 60 s lease instead of `zenoh-pico`'s 10 s. It tries a keepalive every
5 s rather than every third of the lease, which costs nothing because one is
sent only when nothing else has been. A stopped router is detected when one
fails, 5 to 10 s later, 6 s when measured; a silent link only when the lease
runs out, after 60 to 120 s. The router can likewise keep a dead board in the
graph for up to 60 s, unless it has something to send to it. None of this
delays the motor cut-off.

This stays inside [ADR 0003](0003-hardware-boundary.md)'s boundary because the
update loop reads nothing from the base: the plugin only writes. If wheel
encoders are ever added and the controller has to close a loop on them, their
values would arrive through the router at an unbounded delay, and this decision
must be revisited first.

`harp3_hardware` stays deferred. The base supplies no `<param name="port">`, so
[ADR 0006](0006-deferred-packages.md)'s trigger is not met by it.

ADR 0007's statement that the firmware is independent of the middleware no longer
holds for this board. A Zenoh upgrade on the host has to be checked against the
board, and the firmware compiles in the type hash of every message it exchanges:
changing a field of `LimitSwitches.msg` means regenerating and reflashing.

Until the forks are merged upstream, `picoros-usb-eth` pins their commits, and a
`zenoh-pico` upgrade means rebasing the fixes above.

The wheel velocity sign follows `omni_wheel_drive_controller`, the opposite of
HARP2's controller, so the firmware does not reuse HARP2's motor directions.
