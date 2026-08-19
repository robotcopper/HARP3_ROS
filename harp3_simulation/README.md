# harp3_simulation

Gazebo Jetty worlds, models and bridge configuration for the HARP3 robot.

Simulation is the primary development target: the robot is driven through
`gz_ros2_control`, which exposes the same `ros2_control` interfaces as the real
hardware would. Controllers, navigation and behaviour therefore do not know
whether they are running in simulation.
