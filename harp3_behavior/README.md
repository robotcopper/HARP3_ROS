# harp3_behavior

Mission logic for the HARP3 robot.

Strategies are expressed as BehaviorTree.CPP trees in `trees/`, built from action
and condition nodes registered as plugins from `src/`. Keeping the strategy in
trees rather than in one script per scenario is what makes it composable,
inspectable in Groot and testable without a robot.
