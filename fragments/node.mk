# node.mk — the node_modules sentinel plus prose format/lint helpers.
# Requires tools.mk (provides $(PRETTIER), $(MARKDOWNLINT_CLI2) from the
# mise.toml pins).
ifndef MK_NODE_INCLUDED
MK_NODE_INCLUDED := 1

# Install the repo's Node dependencies exactly as locked in package-lock.json,
# and run them straight from node_modules (never npx or a global).
# --ignore-scripts is the safe default; Node Action repos that need lifecycle
# scripts set `NPM_CI_FLAGS :=` before the include. Only repos that actually
# build Node (a real package.json) use this sentinel — prose linting below does
# not, so a markdown/Go/Terraform repo needs no package.json at all.
NPM_CI_FLAGS ?= --ignore-scripts --no-fund

# Sentinel target: re-runs npm ci only when package.json / the lockfile change.
node_modules: package.json package-lock.json
	@ npm ci $(NPM_CI_FLAGS)
	@ touch node_modules

# Prose format/lint via the mise-pinned prettier + markdownlint-cli2 (tools.mk).
# Per-repo behaviour lives in the config files each repo already carries:
# .prettierrc.yaml / .prettierignore and .markdownlint-cli2.yaml (which also
# declares the globs markdownlint scans).
.PHONY: fmt-prose lint-prose
fmt-prose: $(PRETTIER) $(MARKDOWNLINT_CLI2)
	@ $(PRETTIER) --write "**/*.md"
	@ $(MARKDOWNLINT_CLI2) --fix

lint-prose: $(PRETTIER) $(MARKDOWNLINT_CLI2)
	@ $(MARKDOWNLINT_CLI2)
	@ $(PRETTIER) --check "**/*.md"

endif
