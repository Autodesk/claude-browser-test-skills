# Contributing

Thanks for your interest in improving **browser-test-skills** — a Claude Code plugin providing an E2E browser-test skill pipeline (Author → Refiner → Compiler → Runner). Contributions of all kinds are welcome.

Please also read [`CLAUDE.md`](CLAUDE.md) — it explains the repo layout and the conventions that keep the skills working — and our [Code of Conduct](CODE_OF_CONDUCT.md).

## Contributor License Agreement (CLA)

External contributors (anyone who is **not** an Autodesk employee) must sign Autodesk's Contributor License Agreement before a contribution can be merged:

- **Individuals** sign the individual CLA (ICLA).
- **Contributing on behalf of a company** — your employer completes the corporate CLA (CCLA).

The **CLA Assistant bot** checks this automatically: on your first pull request it will comment with a link to sign, and the PR cannot be merged until the check passes. (This repo follows the same model as [Autodesk/maya-usd](https://github.com/Autodesk/maya-usd/blob/dev/doc/CONTRIBUTING.md).)

## Types of contributions

- **Bug reports** — problems with a skill, the pipeline, or install (use the bug template).
- **Feature requests** — improvements to a skill or the pipeline (use the feature template).
- **Pull requests** — skill improvements, documentation, examples, CI/tooling.

## Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI
- [Playwright MCP server](https://github.com/microsoft/playwright-mcp) (to exercise the skills)
- Node.js 20+ (only to run the local checks below)

## Making a change

1. Fork the repo and create a branch off `main`.
2. Make your change. The substance lives in `skills/*/SKILL.md`, the manifests under `.claude-plugin/`, and the docs. There is no build step — the deliverable is the skills and manifests themselves.
3. Run the local checks (below) and, ideally, exercise the affected skill against a public demo app such as `https://www.saucedemo.com` (see the README → Getting Started).
4. Open a pull request using the template. CI must pass, the CLA check must be green, and a code owner will review.

## Local checks

Run the same gates CI runs on every pull request, from the repo root:

```bash
node scripts/ci/check-manifests.mjs          # manifests parse + required fields
bash scripts/ci/check-skill-frontmatter.sh   # SKILL.md frontmatter is valid
bash scripts/ci/check-internal-refs.sh        # no internal/enterprise references
npx markdownlint-cli2 "**/*.md" "#node_modules" "#CODE_OF_CONDUCT.md"   # markdown lint
```

And validate the plugin itself:

```bash
claude plugin validate .
```

### How CI works

Every pull request runs the **Quality gates** GitHub Actions workflow (`.github/workflows/quality.yml`): a job that validates the manifests, checks SKILL.md frontmatter, and runs the internal-reference guard, plus a markdown-lint job. All jobs must pass before merge.

## Conventions

- **Bare skill names.** Each `skills/*/SKILL.md` `name` is the bare skill name (`name: author`), never `browser-test:author` — Claude Code adds the `browser-test:` namespace automatically.
- **The `description` drives activation.** Keep it specific and trigger-oriented; it's what Claude matches against to decide when to invoke the skill.
- **Keep examples generic.** This is a public, general-purpose repo. Use neutral placeholders (e.g. `PROJ-123` for Jira keys). Don't add internal product names, real credentials, or internal URLs — the internal-reference guard will fail the build.
- **The markdown test case is authoritative.** Compiled `.spec.ts` files are derived artifacts; the markdown is what's maintained.

## Issues, reviews, and response expectations

- File bugs and feature requests through the issue templates. For anything security-related, do **not** open a public issue — see [`SECURITY.md`](SECURITY.md).
- Maintainers review issues and pull requests at least weekly and aim to acknowledge new activity promptly. Complex fixes may take longer, but we'll keep the thread updated.
- Discussion happens in the open, on issues and pull requests.

## Becoming a maintainer

Maintainers keep the project healthy: triaging issues, reviewing PRs, and cutting releases. Contributors with a track record of high-quality contributions may be invited to become maintainers. Per Autodesk open-source policy, the project retains at least one Autodesk employee as a maintainer, and all maintainers follow Autodesk's Guidelines for Open Source Maintainers.
