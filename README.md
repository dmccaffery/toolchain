# make

Shared Makefiles for the bitwise-media-group ecosystem. Each repo consumes this library as a git submodule mounted at
`make/` (bumped by Dependabot's `gitsubmodule` ecosystem) and reduces its own `Makefile` to a few lines.

See [RECOMMENDATION.md](RECOMMENDATION.md) for the design rationale and the per-repo migration map.

## Layout

```text
make/
├── fragments/          # composable building blocks, one capability each
│   ├── common.mk       #   .DEFAULT_GOAL, help, commit, .NOTPARALLEL
│   ├── tools.mk        #   install pinned CLIs from mise.toml/mise.lock into .bin/
│   ├── license.mk      #   LICENSE_HOLDER, .licenseignore, license / license-check
│   ├── node.mk         #   node_modules sentinel, fmt-prose / lint-prose
│   ├── go.mk           #   version stamping, tidy, go-{fmt,lint,test,build}, snapshot, release, fuzz
│   ├── docs.mk         #   zensical sync / docs-build / serve (uv)
│   ├── action.mk       #   biome + tsc + rollup + vitest helpers
│   ├── terraform.mk    #   init / plan / apply / tf-{fmt,lint,docs}
│   └── noop.mk         #   build / test / e2e no-ops
└── <archetype>.mk      # wires fragments into the canonical contract
    ├── go-cli.mk
    ├── node-action.mk
    ├── node-lib.mk
    ├── docs-site.mk
    ├── markdown-lib.mk
    └── terraform.mk
```

## Usage

Add the submodule once:

```sh
git submodule add https://github.com/bitwise-media-group/make.git make
```

Then reduce the repo's `Makefile` to its archetype plus any per-repo knobs:

```makefile
# a Go CLI (dotty, evolve, gh-claude)
APP     := dotty
APP_PKG := ./cmd
include make/go-cli.mk

# docs is app-specific (regenerates the CLI reference), so it stays here and is
# appended to the pull-request gate:
docs: build ## regenerate the CLI reference and build the docs site
 @ ./$(APP) docs --out docs/cli --format markdown
 @ $(MAKE) docs-build
pr: docs
```

```makefile
# a Node Action (ff-merge, setup-evolve)
include make/node-action.mk
```

```makefile
# a Markdown/YAML library (github-workflows, skills)
include make/markdown-lib.mk
```

```makefile
# a Terraform environment (cloud-accounts/environments/<name>/)
include ../../make/terraform.mk
```

## The contract

The reusable CI workflow (`bitwise-media-group/github-workflows`) runs a matrix of **`make lint`**, **`make build`**,
**`make test`** (and opt-in **`make e2e`**); release drives GoReleaser / Zensical directly. Every archetype provides
those canonical targets, plus **`fmt`**, **`ci`**, and **`pr`** for local use. Run `make help` in any consuming repo to
list what it exposes.

Canonical targets are **pure prerequisite aggregators** (no recipe), so a repo extends them by adding prerequisites —
`build: ui`, `pr: docs`, `lint: my-extra` — without touching the library.

## Developer tools

The pinned CLIs (`addlicense`, `golangci-lint`, `govulncheck`, `gotestsum`, `goreleaser`, `syft`, `terraform`, `tflint`,
`terraform-docs`, `actionlint`, `evolve`, `dotty`, `prettier`, `markdownlint-cli2`) are **not** vendored through a
`tools/go.mod` or a `package.json`. `go tool` management is deliberately avoided — golangci-lint in particular breaks
under it and its maintainers document that as unsupported — and a repo whose only Node use was the prose linters needs
no npm plumbing at all. Instead:

- every tool is pinned in `mise.toml` **at the root of this library**, with per-platform sha256 checksums (and, where
  the publisher provides it, cosign/SLSA/GitHub-attestation provenance) locked in `mise.lock`. `locked = true` means
  [mise](https://mise.jdx.dev) refuses to install anything the lockfile doesn't cover, so a moved or re-pointed upstream
  tag cannot substitute different code;
- most tools install as verified prebuilt release binaries. The exceptions install through their language ecosystems
  using runtimes mise itself provisions from the pins: govulncheck compiles via `go install` (Go checksum database) with
  the pinned Go, and prettier/markdownlint-cli2 install from the npm registry with the pinned Node — so no system Go or
  Node is needed. govulncheck stays in the library (not just CI) to keep `make lint` and the CI gate in parity;
  gocover-cobertura is gone entirely: Codecov ingests Go's native coverage profile directly;
- `fragments/tools.mk` installs a tool into mise's shared per-machine store the first time a target needs it and
  symlinks it into the repo-local `.bin/`, refreshing the link when the pins change;
- bumping a tool for the **whole fleet** is one commit here (the daily updater below, or a hand-edit of `mise.toml` +
  `mise lock`) + a submodule bump in the consumers. That includes the tooling runtimes themselves (`go = "1.26.4"`,
  `node = "24.18.0"`), which replaced the old `.go-version` / `.node-version` markers.

A consuming repo therefore needs **zero** tool configuration — just `mise` on PATH (`brew install mise`). It can still
substitute its own binary for a one-off by setting e.g. `GOLANGCI_LINT := /path/to/golangci-lint` before the include.

Consuming repos should add `.bin/` (and `coverage/`) to `.gitignore`.

Dependabot has no mise ecosystem, so `.github/workflows/update-tools.yaml` replaces it: it runs `mise upgrade --bump`
daily, which honours `minimum_release_age = "7d"` — a release must be at least 7 days old before it is adopted, a
Dependabot-style cooldown — re-locks the checksums with `mise lock`, and opens a single `fix(deps):` PR. Run it by hand
with `mise upgrade --bump && mise lock` in this directory (or `mise outdated` to just report).

## Other conventions the library assumes

- **License holder** is `BitWise Media Group Ltd` (override `LICENSE_HOLDER`).
- **Prose linting needs no `package.json`**: `fmt-prose` / `lint-prose` run the mise-pinned prettier + markdownlint-cli2
  against the repo's `.prettierrc.yaml` / `.prettierignore` / `.markdownlint-cli2.yaml` (which also declares the globs
  markdownlint scans). Node Action **npm scripts** are named `check`, `check:fix`, `typecheck`, `build`, `test:coverage`
  (biome + rollup + vitest).
- **Overridable knobs** (`APP`, `APP_PKG`, `MODULE`, `BUILD_TAGS`, `NPM_CI_FLAGS`, `TF_RUN`, `TOOLS_BIN`,
  `GOLANGCI_LINT`, …) are set in the repo `Makefile` _before_ the `include`.

## Knobs by fragment

| Fragment       | Key variables                                                                                                 |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| `tools.mk`     | `TOOLS_BIN`, `MK_ROOT`, per-tool binary overrides (e.g. `GOLANGCI_LINT := /path`)                             |
| `license.mk`   | `LICENSE_HOLDER`, `LICENSE_IGNORE`                                                                            |
| `node.mk`      | `NPM_CI_FLAGS`                                                                                                |
| `go.mk`        | `APP`, `APP_PKG`, `MODULE`, `VERSION`, `VERSION_PKG`, `LDFLAGS`, `BUILD_TAGS`, `FUZZ`, `FUZZ_PKG`, `FUZZTIME` |
| `terraform.mk` | `TERRAFORM_BINARY`, `TF_RUN`                                                                                  |
