# tools.mk — install pinned developer CLIs via mise, no per-repo tools module.
#
# Tools are pinned in mise.toml at the root of the make library (this submodule)
# and locked — with per-platform sha256 checksums and provenance — in mise.lock.
# mise verifies the checksum (plus cosign/SLSA/GitHub attestations where the
# publisher provides them) on every install, and `locked = true` refuses anything
# the lockfile doesn't cover. Most tools are prebuilt release binaries; the
# exceptions install through their language ecosystems using runtimes mise itself
# provisions from the pins — govulncheck via `go install` (Go checksum database)
# with the pinned Go, prettier/markdownlint-cli2 from the npm registry with the
# pinned Node — so no system Go or Node is needed anywhere.
#
# A consuming repo needs no tools/go.mod and no mise.toml of its own — just the
# archetype include and mise on PATH (https://mise.jdx.dev). A tool is installed
# into mise's shared per-machine store the first time a target needs it and
# symlinked into a repo-local $(TOOLS_BIN); the symlink is refreshed whenever the
# pins change (bumping the submodule bumps the pins for the whole fleet). A repo
# can still substitute its own binary by setting e.g. `GOLANGCI_LINT := /path`
# before the include.
ifndef MK_TOOLS_INCLUDED
MK_TOOLS_INCLUDED := 1

# Absolute path to this library's root (…/make), where mise.toml + mise.lock
# live — resolved (immediately, while this fragment is the last-parsed file)
# relative to the fragment, so it is independent of the caller's CWD.
ifndef MK_ROOT
MK_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
endif

# Where tool symlinks land. Repo-local and git-ignorable; the real binaries live
# in mise's shared store, so nothing is rebuilt or re-downloaded per repo.
TOOLS_BIN ?= $(CURDIR)/.bin

# $(call mise_tool,<binary>,<mise backend spec>[,<dependency tools>]): declare a
# rule that installs the pinned tool via mise and (re)links $(TOOLS_BIN)/<binary>
# whenever the pins change. mise runs from MK_ROOT so it resolves this library's
# mise.toml; the config is trusted explicitly first (running make already implies
# trusting the repo's build files). A single-tool `mise install` does not resolve
# backend dependencies, so the runtime a backend needs (the pinned `go` for go:,
# `node` for npm:) is passed as the third argument and installed alongside.
define mise_tool
$(TOOLS_BIN)/$(1): $(MK_ROOT)/mise.toml $(MK_ROOT)/mise.lock
	@ command -v mise >/dev/null || { echo "tools: mise is required (https://mise.jdx.dev — brew install mise)" >&2; exit 1; }
	@ mkdir -p "$(TOOLS_BIN)"
	@ echo "tools: installing $(1) via mise ($(2))"
	@ cd "$(MK_ROOT)" && mise trust --quiet mise.toml && mise install --quiet $(3) '$(2)'
	@ ln -sf "$$$$(cd "$(MK_ROOT)" && mise which $(1))" "$(TOOLS_BIN)/$(1)"
endef

$(eval $(call mise_tool,addlicense,ubi:google/addlicense))
$(eval $(call mise_tool,golangci-lint,aqua:golangci/golangci-lint))
$(eval $(call mise_tool,govulncheck,go:golang.org/x/vuln/cmd/govulncheck,go))
$(eval $(call mise_tool,gotestsum,aqua:gotestyourself/gotestsum))
$(eval $(call mise_tool,goreleaser,aqua:goreleaser/goreleaser))
$(eval $(call mise_tool,prettier,npm:prettier,node))
$(eval $(call mise_tool,markdownlint-cli2,npm:markdownlint-cli2,node))
$(eval $(call mise_tool,syft,aqua:anchore/syft))
$(eval $(call mise_tool,terraform,aqua:hashicorp/terraform))
$(eval $(call mise_tool,tflint,aqua:terraform-linters/tflint))
$(eval $(call mise_tool,terraform-docs,aqua:terraform-docs/terraform-docs))
$(eval $(call mise_tool,actionlint,aqua:rhysd/actionlint))
# First-party CLIs (bitwise-media-group), pinned like the rest: evolve is the
# skill-evaluation CLI the skills repo's lint/test/triggers/evals targets use;
# dotty is the secrets/env wrapper terraform.mk's TF_RUN invokes.
$(eval $(call mise_tool,evolve,github:bitwise-media-group/evolve))
$(eval $(call mise_tool,dotty,github:bitwise-media-group/dotty))

# Invocation variables: use these as both a recipe command and a prerequisite, e.g.
#   license: $(ADDLICENSE) ; @ $(ADDLICENSE) ... .
ADDLICENSE        ?= $(TOOLS_BIN)/addlicense
GOLANGCI_LINT     ?= $(TOOLS_BIN)/golangci-lint
GOVULNCHECK       ?= $(TOOLS_BIN)/govulncheck
GOTESTSUM         ?= $(TOOLS_BIN)/gotestsum
GORELEASER        ?= $(TOOLS_BIN)/goreleaser
PRETTIER          ?= $(TOOLS_BIN)/prettier
MARKDOWNLINT_CLI2 ?= $(TOOLS_BIN)/markdownlint-cli2
SYFT              ?= $(TOOLS_BIN)/syft
TERRAFORM         ?= $(TOOLS_BIN)/terraform
TFLINT            ?= $(TOOLS_BIN)/tflint
TERRAFORM_DOCS    ?= $(TOOLS_BIN)/terraform-docs
ACTIONLINT        ?= $(TOOLS_BIN)/actionlint
EVOLVE            ?= $(TOOLS_BIN)/evolve
DOTTY             ?= $(TOOLS_BIN)/dotty

# Lint the repo's GitHub Actions workflows (no-op where there are none).
.PHONY: actionlint
actionlint: $(ACTIONLINT) ## lint .github/workflows with actionlint
	@ $(ACTIONLINT)

endif
