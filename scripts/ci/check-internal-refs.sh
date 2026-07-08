#!/usr/bin/env bash
# Guard against internal/enterprise references leaking into published content.
# Keeps the public repo generic. Scoped to the content surfaces (skills, docs,
# README); CODEOWNERS is intentionally excluded (its owners are managed
# separately) and CLAUDE.md may name products inside "do not reintroduce"
# guidance.
set -euo pipefail

scope=(skills docs README.md)
# High-signal leakage patterns (not bare product words, to avoid false positives):
pattern='git\.autodesk\.com|[A-Za-z0-9._%+-]+@autodesk\.com|FUS-[0-9]|Fusion Manage|loginToUpchain|[Uu]pchain|@(dueckb|monarqp|naika1|kumarn7|wanis)([^A-Za-z0-9]|$)'

if grep -rnIE "$pattern" "${scope[@]}" 2>/dev/null; then
  echo "::error::internal/enterprise reference found in published content (see matches above); keep the public repo generic"
  exit 1
fi

echo "internal-reference guard: OK"
