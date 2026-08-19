# 1. Packages live at the root of a single repository

Date: 2026-08-18

Status: accepted

## Context

The previous generation of this project, `HARP2_Docker`, contained a workspace
(`ros2_ws/src/`) at the root of the repository and pulled the ROS packages in as a
git submodule from a second repository, `HARP2_ROS`.

Two problems followed from that. Submodules pin an exact commit, so any change
touching both the environment and the packages required two commits in two
repositories in the right order. And a repository whose root is a workspace cannot
be released: `bloom`, `rosdep` and `vcs import` all assume that packages sit at the
root of the repository, as does indexing on index.ros.org.

## Decision

All HARP3 packages live at the root of a single repository. The repository *is* the
content of a colcon `src` directory and does not contain a workspace.

Third-party code that has no binary release for the targeted ROS 2 distribution is
declared in `dependencies.repos` and imported with `vcstool`, not as a submodule.

## Consequences

The repository is releasable with `bloom` and importable with `vcs import`, and a
change spanning several packages is a single atomic commit.

In exchange, the workspace has to be created around the clone rather than being
part of it, which is one extra step in the README, and every package shares a
single version number until they are released individually.
