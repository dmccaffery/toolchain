# The make library dogfoods its own markdown-lib archetype: the tasks are wired
# via the root mise.toml (see the comment there for why the layout is inverted
# relative to consumers, whose Makefiles say `include .mise/mise.mk`).
include mise.mk

# This repo is nothing but workflows and task files, so also lint the workflows
# with the pinned actionlint — a make-side prerequisite extension (it runs
# `mise run actionlint` via the .DEFAULT forwarder before `mise run lint`).
lint: actionlint
