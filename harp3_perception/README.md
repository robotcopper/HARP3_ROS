# harp3_perception

Sensor processing for the HARP3 robot.

Nodes here are written as composable components so that they can be loaded into
the same process as the sensor drivers, which enables zero-copy intra-process
transport for images and point clouds. Sensor subscriptions and publications use
`rclcpp::SensorDataQoS()`.
