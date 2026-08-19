cmake_minimum_required(VERSION 3.16)
project(harp3_msgs)

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)

# rosidl_generate_interfaces() rejects an empty file list, so the call is added
# together with the first definition placed in msg/, srv/ or action/.

ament_export_dependencies(rosidl_default_runtime)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
