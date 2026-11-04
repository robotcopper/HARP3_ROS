# The six limit switches wired to the mobile base board, true while pressed.
#
# Field names are the board's schematic designators, Switch11 to Switch32: the
# first digit is the motor connector, the second the switch on it. Published
# reliable and transient_local with depth 1, on every change, so a late
# subscriber receives the current state rather than waiting for the next edge.

std_msgs/Header header

bool switch_11
bool switch_12
bool switch_21
bool switch_22
bool switch_31
bool switch_32
