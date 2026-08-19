# 3. Device access is split by real-time participation, not by device type

Date: 2026-08-18

Status: accepted, amended 2026-08-19

## Context

HARP3 talks to two populations of device. The drive base and the arm are closed
loops: their measurements are needed by the `controller_manager` update loop in
order to compute the next command, at a fixed rate, synchronously. The LiDAR,
the cameras and the time-of-flight sensors are open loops: they are sampled at
their own rate and consumed only by pose estimation and perception.

`ros2_control` offers a `SensorInterface`, which makes it tempting to route every
sensor through it and end up with a single package holding all device code. The
two populations have almost nothing in common, though. A `ros2_control` plugin is
loaded into the `controller_manager` process, its `read()` runs inside the
real-time loop and may not allocate, lock or log, and it is declared in the
`<ros2_control>` block of the xacro. A LiDAR driver is an ordinary node with a
lifecycle, publishes on `SensorDataQoS` and is started by a launch file.

Merging them would give every consumer of either one the union of two unrelated
dependency sets, and would subject code that has no real-time constraint to a
package whose reason for existing is that constraint.

## Decision

Device access is split by whether the `controller_manager` update loop needs the
value, not by whether the device is a sensor or an actuator.

`harp3_hardware` contains `ros2_control` plugins only: `SystemInterface`,
`ActuatorInterface` and `SensorInterface` implementations, subject to the
real-time rules. Wheel motors, encoders, the IMU and the arm's actuators are
here, as are the GPIO lines wired to the microcontroller.

`harp3_sensors` contains standalone device nodes deriving from
`rclcpp_lifecycle::LifecycleNode`, publishing on `SensorDataQoS`. LiDAR, cameras,
time-of-flight arrays and beacon receivers are here.

`harp3_sensors` is for devices with no upstream driver. When an upstream driver
exists it is an `exec_depend` and a parameter file, never a wrapper package.

## Consequences

Real-time code is confined to one package, which can be reviewed against the
allocation and locking rules as a unit, and the sensor package can be tested on
the host with no `controller_manager` in the loop.

`harp3_simulation` has to replace both packages rather than one, since Gazebo
supplies `gz_ros2_control` on one side and its own sensor plugins on the other.

Moving a sensor across the boundary later — promoting an IMU from a driver node
to a `SensorInterface` because a controller starts needing it — is a rewrite, not
a move. The question has to be answered when the device is first integrated.

The same wire decides the package: a button on the microcontroller is a `<gpio>`
state interface in `harp3_hardware`, while the same button on the header of the
board running ROS is a node in `harp3_sensors`.

## Amendment, 2026-08-19

The rule above stands and is the reason this file exists. Neither package exists
yet, and the second one was called `harp3_drivers` when this decision was first
recorded.

Both are deferred until there is a device that upstream code cannot already
handle. The criterion and the triggers are recorded in
[ADR 0006](0006-deferred-packages.md). Read this file for *where* a device goes,
and ADR 0006 for *whether the package exists yet*.
