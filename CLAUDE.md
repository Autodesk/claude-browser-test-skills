# CLAUDE.md

Guidance for working **on** this repository. For how the skills behave at runtime, read each `skills/*/SKILL.md`.

## What this repo is

A Claude Code **plugin** named `browser-test`, distributed through a **marketplace** (`browser-test-skills`) defined in the same repo. It provides a four-skill pipeline for authoring, stabilizing, compiling, and running E2E browser tests with Playwright MCP. There is no application code here — the deliverable is the skills themselves plus their manifests.

The pipeline: **Author → Refiner → Compiler → Playwright CI**, with a **Runner** for LLM-driven execution of the markdown source. The markdown test case is authoritative; the compiled `.spec.ts` is a derived artifact.

## Layout

```
.claude-plugin/
  marketplace.json    # marketplace "browser-test-skills" → plugin "browser-test", source "./"
  plugin.json         # plugin manifest: name, version, license, metadata
skills/
  author/SKILL.md     # vague description → structured markdown test case
  refiner/SKILL.md    # run repeatedly, stabilize flaky steps + conventions
  compiler/SKILL.md   # stable markdown → Playwright .spec.ts via live browser replay
  runner/SKILL.md     # execute a stable markdown test faithfully, report pass/fail
.github/CODEOWNERS
docs/superpowers/     # design specs and implementation plans (historical context)
README.md             # user-facing docs
```

## Conventions when editing skills

- **SKILL.md frontmatter `name` is the bare skill name** (`name: author`), never the plugin-prefixed form. Claude Code adds the `browser-test:` namespace automatically from `plugin.json`'s plugin name. A prefixed name is a bug.
- **The `description` drives activation** — it is what Claude matches against to decide when to invoke the skill. Keep it specific and trigger-oriented.
- **Keep examples product-neutral.** This is a public, general-purpose repo. Use neutral placeholders (`PROJ-123` for Jira keys, generic app/tenant names). Do not reintroduce internal Autodesk product names (Upchain, Fusion, etc.) or real credentials/URLs.
- **The skills describe conventions-driven test projects**, not this repo. When a skill references `tests/e2e/`, `playwright-tests/`, `conventions.md`, or `INVENTORY.md`, those live in the *consuming* project, not here.

## Validate before publishing

From the repo root:

```bash
claude plugin validate .
```

This checks manifest JSON, `plugin.json` schema, skill frontmatter, duplicate names, and path-traversal safety.

## Manual verification of a skill change

There is no automated test suite yet (CI quality gates are planned — see the tracking issues). To sanity-check a change, install the plugin from a local checkout and invoke the affected skill against a public demo app such as `https://www.saucedemo.com` (see README → Getting Started).

## Two-repo context

This is being open-sourced to `github.com/Autodesk/claude-browser-test-skills`. Real-world test suites built with these skills live in separate consuming repos. Keep this repo generic and self-contained.
