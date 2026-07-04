# The make library dogfoods its own markdown-lib archetype: prose lint + license,
# with build/test/e2e as no-ops. Included by relative path because this *is* the
# library (consumers use `include make/markdown-lib.mk`).
include markdown-lib.mk

# This repo is nothing but workflows and Makefiles, so also lint the workflows
# with the pinned actionlint (from gotools.mk).
lint: actionlint
