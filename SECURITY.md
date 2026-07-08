# Security Policy

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, report them privately using GitHub's **[Report a vulnerability](https://github.com/Autodesk/claude-browser-test-skills/security/advisories/new)** feature (Security → Advisories on this repository). This opens a private advisory visible only to the maintainers.

Please include, where possible:

- A description of the issue and the potential impact.
- Steps to reproduce (a minimal proof of concept, affected skill/file, and configuration).
- Any suggested remediation.

## What to expect

- Maintainers will acknowledge your report and work with you on a fix, coordinating with Autodesk security as needed.
- Please give us a reasonable window to investigate and release a fix before any public disclosure.

## Scope

This repository contains Claude Code **skills and plugin manifests** — Markdown and JSON, with no runtime server component. The most relevant concerns are the guidance the skills generate (e.g. selector/credential handling in produced tests) and the plugin metadata. Reports about those are in scope.
