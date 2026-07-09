# terraform.mk — plan/apply/lint/docs for a Terraform module.
# Generalises cloud-accounts/environments/cloud.mk.
# Requires tools.mk (provides $(TERRAFORM), $(TFLINT), $(TERRAFORM_DOCS) from the
# mise.toml pins).
ifndef MK_TERRAFORM_INCLUDED
MK_TERRAFORM_INCLUDED := 1

# The mise-pinned terraform by default. Overridable, but the override must be a
# path (it doubles as a prerequisite), e.g. `TERRAFORM_BINARY := /usr/local/bin/terraform`.
TERRAFORM_BINARY ?= $(TERRAFORM)

# Wrapper that injects secrets/env around terraform — the mise-pinned dotty by
# default. Set `TF_RUN :=` (empty) to call terraform directly, or point it at
# your own wrapper.
TF_RUN ?= $(DOTTY) env run --

# Any mise-pinned binary referenced by TF_RUN becomes a prerequisite, so the
# default dotty installs on first use but an overridden/empty TF_RUN drops it.
TF_RUN_DEPS := $(filter $(TOOLS_BIN)/%,$(TF_RUN))

.PHONY: tf-init init-no-backend plan apply tf-fmt tf-lint tf-docs
tf-init: $(TERRAFORM_BINARY) $(TF_RUN_DEPS) ## initialise the terraform module
	@ $(TF_RUN) $(TERRAFORM_BINARY) init

# Backend-less init used by lint (validate needs an initialised module but no
# remote state); no `## ` so it stays out of `help`.
init-no-backend: $(TERRAFORM_BINARY) $(TF_RUN_DEPS)
	@ $(TF_RUN) $(TERRAFORM_BINARY) init -backend=false -input=false

plan: $(TERRAFORM_BINARY) $(TF_RUN_DEPS) ## plan infrastructure changes
	@ $(TF_RUN) $(TERRAFORM_BINARY) plan -out=plan.tfplan

apply: plan ## apply infrastructure changes
	@ $(TF_RUN) $(TERRAFORM_BINARY) apply plan.tfplan

# Auto-format pass wired into `fmt`.
tf-fmt: $(TERRAFORM_BINARY)
	@ $(TERRAFORM_BINARY) fmt -recursive

# Check-mode pass wired into `lint`.
tf-lint: init-no-backend $(TFLINT)
	@ $(TERRAFORM_BINARY) validate .
	@ $(TFLINT)

# Doc generation wired into `docs`.
tf-docs: $(TERRAFORM_DOCS)
	@ $(TERRAFORM_DOCS) .

endif
