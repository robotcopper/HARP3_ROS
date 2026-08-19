# harp3_ui

The touchscreen mounted on the robot. Before a match it selects the side and the
strategy, through the services declared in `harp3_msgs`. During a match it
displays the match state, the score and the aggregated diagnostics.

This package is strictly observational once the match has started. It never
commands the robot, and its failure must be inconsequential: a disconnected
screen or a stalled renderer cannot be allowed to cost match time, which is why
the match orchestrator lives in `harp3_behavior` and not here.

The graphical toolkit is not chosen yet. `foxglove_bridge` is declared as an
exec dependency because a web front end served over it is the cheapest option
that requires no toolkit at all; a native application would replace that
dependency rather than add to it. Record the decision in `docs/adr/` once taken.

Nothing lives here yet.
