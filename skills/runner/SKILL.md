---
name: runner
description: Use when executing a stable E2E test case that has already been refined. Follows test steps exactly without deviation, reports pass/fail with evidence.
---

# E2E Test Runner

## Overview

Executes a refined, stable E2E test case exactly as documented. No improvisation, no refinement - just faithful execution and clear pass/fail reporting.

**Core principle:** The test case is the source of truth. If a step fails, the test fails. Do not work around failures.

## When to Use

- Running a previously refined test case
- User says "run the test" or "execute {test name}"
- CI-style validation of a known-good flow

**Do NOT use when:**
- No test case file exists (use `browser-test:author`)
- The test is known to be flaky (use `browser-test:refiner`)

## Prerequisites

- Stable test case file in `tests/e2e/{area}/`
- The Playwright MCP server must be available (configured in `.mcp.json`)
- Dev server must be running (or `E2E_BASE_URL` set to a reachable environment)

## Process

### 1. Load test context
Read in order:
1. `tests/e2e/conventions.md` (global)
2. `tests/e2e/{area}/conventions.md` (area)
3. The test case file

### 2. Environment gate
Read `E2E_ENVIRONMENT` from the environment (default: `local`). Check the test case's **Environments** line in preconditions. If the current environment is not listed, **refuse to execute** and report:
```
BLOCKED: {test name}
Reason: Test not allowed in "{environment}" (allowed: {environments list})
```
This is a hard stop - do not proceed, do not ask if the user wants to override.

### 3. Verify preconditions
Check each remaining precondition listed in the test case. If any are unmet, report and stop.

Read `E2E_BASE_URL` from the environment (default: `http://localhost:5173`). Use this value wherever the test references `E2E_BASE_URL`.

### 4. Set up fresh session
Follow Session Management from global conventions:
1. Close any existing browser session (`browser_close`)
2. Navigate to `E2E_BASE_URL` - this starts a fresh browser instance
3. Verify clean session (cookie consent banner should appear on first navigation)

### 5. Execute steps
Execute the three hook sections **in this order**: `## Before Hook` → `## Test Steps` → `## After Hook` . Validate the markdown has all three sections before starting — if any is missing, refuse to execute and report a malformed test case.

For each step in each section:
1. Perform the action exactly as described
2. If the step references a convention (e.g., "Complete Auth0 login"), follow that convention's documented sequence
3. If a **Verify** directive exists, confirm the condition
4. If verification fails in **Before Hook** or **Test Steps**, capture the failure evidence, then **still run every `## After Hook` step** (try/finally semantics) so the next run starts from a clean fixture. Report the test as FAIL with the section name.
5. After Hook steps are idempotent — a missing-resource error (e.g., the resource was never created) is acceptable and not a failure. Only report an After Hook failure if it actively errors on a present resource.

### 6. Report result

**On PASS:**
```
PASS: {test name}
Order/Reference: {any generated ID}
Before Hook: {N}/{N}
Test Steps:  {N}/{N}
After Hook:  {N}/{N}
```

**On FAIL:**
```
FAIL: {test name}
Failed in: {Before Hook | Test Steps | After Hook}
Failed at: Step {N} - {step title}
Expected: {verification condition}
Actual: {what happened}
After Hook: {ran | partial | skipped} ({M}/{N} cleanup steps completed)
Screenshot: {path}
URL: {current URL}
```

## Rules

- **No improvisation.** If a button isn't where the test says it is, that's a failure, not an opportunity to find it elsewhere.
- **No refinement.** If the test fails, report the failure. Don't update the test case - that's the refiner's job.
- **Fresh session per run.** Always. Even if running a single test.
- **Evidence on failure.** Always capture screenshot and URL when a step fails.
- **Execute conventions literally.** When a step says "Complete Auth0 login", follow every sub-step from the area conventions. Don't skip steps because "it should still be logged in."
- **Three-hook execution order .** Always: `## Before Hook` → `## Test Steps` → `## After Hook`. After Hook runs even when Before Hook or Test Steps fails. A test case missing any of the three sections is malformed — refuse to execute and report.
- **After Hook errors are reported but don't override a Test Steps failure.** If Test Steps fails AND After Hook fails, the headline failure is the Test Steps failure; After Hook issues are listed in the report body, not in the headline.

## Batch Execution

When asked to run multiple tests:
1. Run each test with its own fresh session
2. Report results as a summary table:

```
| Test | Result | Notes |
|------|--------|-------|
| season-pass-new-member | PASS | Order #TEST-RO-4643 |
| day-pass-purchase | FAIL | Step 5 - dropdown not found |
```

3. Continue to next test even if one fails (unless user says otherwise)
