---
name: compiler
description: Use when converting a refined markdown E2E test case into a standard Playwright .spec.ts file. Triggers on "compile this test", "convert to playwright", or "generate spec from markdown". Requires a stable markdown test case and a running dev server.
---

# E2E Test Compiler

## Overview

Converts a refined markdown E2E test case into a Playwright `.spec.ts` file by replaying the test in a live browser session and recording every selector from `browser_snapshot` — never from reading application source code.

**Core principle:** Every selector in the compiled output must come from a live browser snapshot. Static code analysis produces brittle, untested selectors. The browser is the source of truth.

## When to Use

- A markdown test case has been refined and is stable (passed consecutive browser-use runs)
- User says "compile this test", "convert to playwright", or "generate spec from markdown"
- Batch compilation of multiple stable test cases

**Do NOT use when:**

- No test case file exists (use `browser-test:author`)
- Test case hasn't been refined/stabilized (use `browser-test:refiner`)
- Test is known to be flaky (refine first)
- Test involves complex dynamic behavior that can't be captured in static code (rare)

## Prerequisites

- Stable, refined markdown test case in `tests/e2e/{area}/`
- Playwright MCP server available (configured in `.mcp.json`)
- Dev server running (or `E2E_BASE_URL` set to a reachable environment)
- Existing `playwright-tests/` structure with utils and fixtures

## Process

### 1. Load Context

Read in order:

1. `tests/e2e/conventions.md` (global conventions)
2. `tests/e2e/{area}/conventions.md` (area conventions)
3. The markdown test case to compile
4. `playwright-tests/utils/INVENTORY.md` and `playwright-tests/journeys/{area}/INVENTORY.md` (utility inventories — run bootstrapping if global inventory absent; run staleness check against referenced `.ts` files before proceeding).
   Also load `playwright-tests/locators/INVENTORY.md` if it exists — this tracks all locator objects separately from action utilities.
   **Additionally, scan the actual `.ts` files directly** — do not rely solely on INVENTORY.md:
   - Glob `playwright-tests/utils/**/*.ts` and extract all exported `async function` signatures
   - Glob `playwright-tests/locators/**/*.ts` and extract all exported `const` objects + their method signatures
   This catches utilities that exist in `.ts` files but are not yet documented in INVENTORY.md. Any undocumented utility found this way is treated as an existing utility for the purpose of Step 4 (use it if it matches) and is flagged for inventory documentation in the Step 6 report (Step 6: Inventory Write Protocol → Auto-detection).

   **Build the Locator Lookup Table** — after scanning all `locators/*.ts` files, construct an in-memory map of every raw selector pattern to its locator method call. This table is used as a blocking gate in Step 4 before any selector is emitted.

   For each exported method in each locator object, record:
   - **Raw selector** — the `page.getByRole(...)`, `page.getByTestId(...)`, etc. expression inside the method body
   - **Locator call** — the method call that replaces it, e.g. `foo.submitButton(page)`
   - **Import** — the import statement needed, e.g. `import { fooLocators as foo } from '../../locators/foo-locators'`

   Generic example of entries the table might contain after scanning `*-locators.ts` files:

   ```
   page.getByTestId('search-input')                  → nav.searchInput(page)
   page.getByTestId('search-input').getByRole('combobox') → nav.searchCombobox(page)
   page.getByRole('button', { name: 'Submit' })      → form.submitButton(page)
   page.getByRole('heading', { name: 'Dashboard' })  → dash.pageHeading(page)
   page.getByRole('textbox', { name: 'Email' })      → login.emailInput(page)
   page.getByRole('columnheader', { name, exact: true }) → table.columnHeader(page, name)
   page.getByTestId(`row-checkbox-${id}`)            → table.rowCheckbox(page, id)
   ```

   For parameterized methods (e.g. `table.columnHeader(page, name)`), record the pattern with a placeholder so matching can be done by role + structural shape rather than exact string.

   **If no `locators/` directory exists or it is empty:** the Lookup Table is empty and the blocking gate passes everything through. Raw selectors recorded during replay will be evaluated against the Extraction Triggers in Step 4 for potential locator creation.
5. All files in `playwright-tests/fixtures/` (test data inventory)
   - Additionally, if `playwright-tests/fixtures/teardowns.ts` exists, scan it for exported teardown helper functions. Build a **Teardown Helper Map**: function name → signature + purpose. These are named helpers (e.g. `tearDownArchivedProject(page, baseURL, name)`) that can be called inside `registerTeardown`.
6. `playwright-tests/fixtures.ts` — check whether the `registerTeardown` fixture is exported. If it is, the compiled spec MUST import from `@fixtures` (not `@playwright/test`) whenever teardown is needed, and MAY use `registerTeardown` for all resource cleanup.
7. `playwright.config.ts` (base URL env var, `testIdAttribute`, timeouts)
8. At least one existing `.spec.ts` in `playwright-tests/journeys/` (gold standard for output structure and style)

Parse from the markdown:

- **Test name** from the `# heading`
- **Jira key** from `<!-- Jira: PROJ-XXXXX -->` or the `# PROJ-XXXXX —` heading (authored by `/author`; compiler reads only — never writes)
- **Environments** from the Preconditions section
- **Markers** from the Preconditions section (used for the `{ tag: [...] }` array)
- **Before Hook** — each `### Setup N.` block under `## Before Hook`
- **Test Steps** — each `### N.` block under `## Test Steps`
- **After Hook** — each `### Teardown N.` block under `## After Hook`
- **Verify** directives within steps
- **Convention references** (e.g., "Complete Auth0 login")

**Three-section structure  is mandatory.** If the markdown does not contain all three top-level sections (`## Before Hook`, `## Test Steps`, `## After Hook`), the test case is malformed — stop compilation and report back to the user with the missing section(s). Do NOT guess or auto-classify; route the user to re-author or hand-fix the markdown first. Empty sections are allowed only when the markdown uses the explicit `_None — {reason}._` placeholder body.

#### Bootstrapping (first compile in a project)

If no global `INVENTORY.md` exists at `playwright-tests/utils/INVENTORY.md`:

1. Scan both:
   - `playwright-tests/utils/**/*.ts` — extract exported `async function` signatures and JSDoc (auth utilities, helpers)
   - `playwright-tests/locators/**/*.ts` — extract exported `const` objects whose methods return `Locator` (e.g. `dashboardLocators`, `navLocators`)
2. Generate two proposed inventory files and present them to the user for review before any other compilation work continues:
   - `playwright-tests/utils/INVENTORY.md` for action utilities and helpers
   - `playwright-tests/locators/INVENTORY.md` for locator factory objects (only if `locators/` directory exists and contains `.ts` files)
3. User approves or declines:
   - **Approved:** file is written, compilation proceeds with the inventory loaded
   - **Declined:** compilation proceeds without an inventory for this run; no file is written; the bootstrap will be offered again on the next compile run

Area-level `INVENTORY.md` files are not bootstrapped — they are created on-demand when the first area-specific utility is extracted and the user approves it. Similarly, `playwright-tests/locators/INVENTORY.md` is created on-demand when the first locator object is extracted and approved.

#### Staleness Check

After loading inventories, run two checks:

**1. Forward staleness (inventory → ts files):** Cross-check each inventory entry against its referenced `.ts` file. Any entry whose function no longer exists in the referenced file is flagged and presented for removal confirmation (multiple stale entries are batched). If the user declines removal, stale entries are retained unchanged and flagged again on the next compile.

**2. Reverse coverage check (ts files → inventory):** Scan all existing `.spec.ts` files in `playwright-tests/journeys/` for inline sequences that match an inventory utility. For each match found, record it as a **coverage gap** — a spec that should be using a utility but has inline code instead. Apply the exception rule below before flagging.

**Coverage gap exception — do not flag when:**

- The matching inline sequence constitutes the MAJORITY (>50%) of the test body — that spec is likely testing the utility behavior itself (e.g., `login-web-client.spec.ts` tests the login flow, so it should keep inline steps)
- The spec is the one currently being compiled

Coverage gaps found during this check are surfaced in the report (Step 7) as a **"Specs with coverage gaps"** section, with a prompt to update them. They are NOT blocking — compilation continues regardless.

### 2. Set Up Fresh Session

Follow Session Management from global conventions:

1. Clear all cookies including httpOnly auth cookies:

   ```js
   // browser_run_code
   async (page) => { await page.context().clearCookies(); }
   ```

2. Clear client-side storage:

   ```js
   // browser_evaluate
   () => { localStorage.clear(); sessionStorage.clear(); }
   ```

3. Navigate to `E2E_BASE_URL` (or `PLAYWRIGHT_TEST_BASE_URL` — check `playwright.config.ts`)
4. Verify clean session: cookie consent banner visible, navbar shows "Log in" (not a user avatar)

### 3. Guided Replay

Walk through each markdown step in the live browser. For every interaction:

1. Take a `browser_snapshot` to get the accessibility tree
2. Perform the action via browser-use tools
3. **Record** the Playwright-native equivalent using the Recording Rules table below
4. **Record** wait conditions from what actually happened (URL changes, element appearances, redirect timeouts)

**Critical constraints:**

- Selectors come from `browser_snapshot` output ONLY — do not read Svelte components, HTML files, or application source code to find selectors
- Translate each markdown step faithfully. Do not reorder steps, add extra verification not in the markdown, or skip steps
- If the markdown says a field is "pre-populated", verify the value with an assertion — do not call a fill utility
- If a step references a convention shorthand (e.g., "Complete Auth0 login"), check the loaded utility inventories before expanding inline

### 4. Map to Existing Utilities

Before emitting raw Playwright calls for a recorded sequence, check the loaded utility inventories (global and area-level). Rules:

- If an exact match exists, use the utility
- If a utility is close but not identical to the recorded sequence, emit inline code — do not force a fit
- **Locator Lookup Table gate (hard blocking rule):** Before emitting ANY raw `page.getByRole(...)`, `page.getByTestId(...)`, `page.getByLabel(...)`, or `page.getByText(...)` call, look it up in the Locator Lookup Table built in Step 1. If a match exists → you MUST use the locator method. This is non-negotiable — emitting a raw selector when the Lookup Table has a locator method for it is a **compilation error**. Stop, use the locator, add the import. Only emit a raw selector if no entry exists in the Lookup Table for that selector pattern.
- Track which utilities were reused and which steps required inline code (for the report)

**Two utility kinds to check:**

1. **Action utilities** — `async function foo(page, ...)` that perform multi-step sequences (click + fill + assert). Import and call directly.
2. **Locator objects** — `const fooLocators = { bar: (page) => page.getByRole(...) }`. Import the object and call its methods inline (e.g. `nav.searchInput(page).fill(...)`). Use these to avoid repeating raw `getByRole` calls.

#### When No Locator Method Exists

If a raw selector passes through the Lookup Table gate (no match found), it can be emitted inline for this compilation run. However, if it meets a Locator repetition trigger (see table below), the compiler must propose adding it to a locator file before writing the spec:

- **If a suitable `*-locators.ts` file already exists** for the feature area (e.g. `nav-locators.ts` for navigation elements, `dashboard-locators.ts` for dashboard elements): propose adding the new method to that file.
- **If no suitable locator file exists** for the area: propose creating a new `{area}-locators.ts` file in `playwright-tests/locators/` with the new method(s) as the initial content.

The proposal follows the same approval flow as Step 5.5. On approval, write the method to the locator file and update `playwright-tests/locators/INVENTORY.md`. On decline, emit the raw selector inline and record as declined.

#### Extraction Triggers

| Trigger | Condition |
|---------|-----------|
| **Repetition** | Same logical sequence already appears in ≥1 other `.spec.ts` in `playwright-tests/journeys/` (excludes the test currently being compiled) |
| **Complexity** | Inline sequence is 5+ lines for a single logical operation |
| **Dangling convention reference** | A markdown step names a convention shorthand (e.g., "Complete checkout") but no matching utility exists in the loaded inventory. This trigger only fires when an inventory has been loaded — if bootstrapping was declined, this trigger is suppressed for the run. |
| **Locator repetition** | The same raw `page.getByRole/getByTestId/getByLabel` call (same role/testId and identical parameters) appears 2+ times within the compiled spec, OR appears in ≥2 other specs. When counting occurrences, ignore trailing method calls (`.click()`, `.toBeChecked()`, `.fill()`, etc.) — the selector itself is what matters. Propose adding it to an existing or new `*-locators.ts` file. Check both INVENTORY.md and scanned `locators/*.ts` files before proposing — if a match already exists, use it instead. |
| **Spec-level function** ⛔ | Any `async function` or named helper function defined **outside** `test.describe` in the spec output. This is a **hard blocker** — the compiler must NEVER write a spec-level function. If one is needed, raise it as an extraction candidate BEFORE writing the spec. If the user approves, write it to `utils/*-helpers.ts` and import it. If the user declines, inline the logic as an arrow function inside the test body only — never as a named function at file scope. |

**Utility type for proposals:**

- Single-selector locator → propose adding to an existing `*-locators.ts` file, or creating a new one if none fits
- Multi-step action sequence → propose as an `async function` in `utils/*.ts` or `utils/*-helpers.ts`
- If both apply (a helper that also wraps repeated selectors), extract the helper first; locator extraction is secondary

Candidates whose function name + target file match a `<!-- declined -->` entry in the relevant inventory are silently skipped — not re-proposed.

### 5. Assemble .spec.ts

Combine recorded calls into a file that mirrors the source markdown path:

**Output path convention:** `playwright-tests/journeys/{area}/{test-name}.spec.ts` — same area directory and kebab-case filename as the source markdown. This makes tracing from compiled test back to source trivial.

**Required file structure (PROJ-256234 — Before Hook / Test Steps / After Hook):**

```typescript
// Compiled from: tests/e2e/{area}/{test-name}.md
// Compiled at: {ISO 8601 timestamp}
// Source is authoritative — do not edit; re-compile from markdown if broken.

import { test, expect } from '@fixtures';   // use @fixtures when registerTeardown is needed; @playwright/test otherwise
// ... utility imports as needed (note: ../../utils/ for action utilities/helpers, ../../locators/ for locator objects, ../../fixtures/ for test data — all two levels up from area subdirectory)

const ENV = process.env.E2E_ENVIRONMENT || 'local';

test.describe('{Test Name from markdown heading}', () => {

    test.skip(!['env1', 'env2'].includes(ENV),
        `Test not allowed in "${ENV}" (allowed: env1, env2)`);

    // === Before Hook (from markdown ## Before Hook) ===
    test.beforeEach(async ({ page, baseURL }, testInfo) => {
        testInfo.setTimeout(currentTimeout() * 6);
        testInfo.annotations.push({ type: 'source', description: 'tests/e2e/{area}/{test-name}.md' });

        await test.step('Setup 1: {setup title from markdown}', async () => {
            // ... setup playwright calls (login, env gates, navigation to starting state)
        });

        await test.step('Setup 2: {setup title from markdown}', async () => {
            // ...
        });
    });

    // === Test Steps (from markdown ## Test Steps) ===
    test('{test description}', { tag: ['@regression', '@positive', '@{area}'] }, async ({ page, baseURL, registerTeardown }) => {

        await test.step('Step 1: {step title from markdown}', async () => {
            // ... scenario playwright calls
        });

        await test.step('Step 2: Create resource (example)', async () => {
            const resourceName = `AutoTest_${Date.now()}`;
            // ... creation calls ...
            // ... assertion confirming the resource exists ...

            // Register teardown immediately after confirmed creation — runs even on failure/timeout.
            // Wrap the teardown body in test.step() so it appears as a labeled phase in the HTML reporter.
            registerTeardown(async () => {
                await test.step('Teardown: Delete {resource type} {resourceName}', async () => {
                    if (!(await page.getByText(resourceName).isVisible().catch(() => false))) return;
                    // ... cleanup calls ...
                });
            });
        });

        await test.step('Step 3: {step title from markdown}', async () => {
            // ...
        });
    });

    // === After Hook (from markdown ## After Hook — only emitted when the markdown has non-placeholder Teardown steps that restore SHARED fixture state, not resource cleanup) ===
    test.afterEach(async ({ page }, testInfo) => {
        await test.step('Teardown 1: {restore action title from markdown}', async () => {
            // ... idempotent restore code (re-read state, no-op if already correct)
        }).catch(err => testInfo.annotations.push({ type: 'teardown-warning', description: String(err) }));
    });
});
```

**Hook emission rules (apply in this order):**

1. **`test.beforeEach`** — emit one per spec; each `### Setup N.` from the markdown becomes one `await test.step('Setup N: {title}', async () => { ... })` block in the order they appear. Always push the `source` annotation here. Always call `testInfo.setTimeout(currentTimeout() * 6)` (matches the project's retry-aware timeout strategy).
2. **`test()` body** — every `### N.` from the markdown's `## Test Steps` section becomes one `await test.step('Step N: {title}', async () => { ... })` block in the order they appear. Raw playwright calls live ONLY inside `test.step` — never directly in the `test()` body.
3. **`registerTeardown`** — for any `## After Hook` step that cleans up a resource the test created (project, item, supplier, upload), register it inline immediately after the confirmed-creation step using `registerTeardown`. The teardown body MUST be wrapped in `await test.step('Teardown: {title}', ...)` so it shows up in the reporter.
4. **`test.afterEach`** — only emit when the markdown's `## After Hook` contains steps that restore SHARED fixture state (e.g., restore BOM row order, close an extra tab opened during setup) rather than delete created resources. Wrap each restore in `test.step(...)`. Swallow individual-step errors into a `teardown-warning` annotation so one failure doesn't mask another.
5. **Placeholder handling** — if a markdown section uses `_None — {reason}._`, skip emitting the corresponding hook entirely. Do NOT emit empty `test.beforeEach(async () => {})` or `test.afterEach(async () => {})` blocks.

**Why both `registerTeardown` AND `test.afterEach`:** `registerTeardown` fires on test timeout (`afterEach` does not), so it's required for resource cleanup. `afterEach` is for state restoration on shared fixtures that the test only mutated, never created — these can safely skip on timeout because the next test's Before Hook will set up its own state.

The `tag` array comes directly from the `**Markers:**` line in the markdown Preconditions section. If no `**Markers:**` line exists, use standard defaults: `@regression @positive` (add `@smoke @sanity` for login/auth tests, `@flaky` when the YAML source has a `Flaky` tag).

**Assembly rules:**

- The header comment with `Compiled from:`, `Compiled at:`, and the "do not edit" warning is mandatory
- The `testInfo.annotations.push({ type: 'source', ... })` call inside `test.beforeEach` is mandatory — enables tracing failures back to the source markdown in HTML/JSON reports
- Environment gating via `test.skip` is mandatory — derive allowed environments from the markdown Preconditions `**Environments:**` line
- **Three-hook emission is mandatory** — every spec must have a `test.beforeEach` for `## Before Hook` and `test.step('Step N: ...')` blocks for `## Test Steps`. `test.afterEach` and/or `registerTeardown` calls are emitted from `## After Hook`. See Hook Emission Rules above for the placement matrix.
- Each `## Test Steps` step becomes an `await test.step('Step N: {title}', async () => { ... })` block. No raw Playwright call may live directly in the `test()` body — everything goes inside a `test.step`. Setup steps inside `test.beforeEach` follow the same rule: `await test.step('Setup N: ...')` wrapping the body.
- Use `expect(page).toHaveURL()` for URL assertions after navigation (not `waitForURL`)
- Conditional elements use `.isVisible().catch(() => false)` pattern
- **Import source:** Use `import { test, expect } from '@fixtures'` when the test needs `registerTeardown`. Use `@playwright/test` only when no teardown is needed.
- **No spec-level functions.**
- **Teardown rule — see Teardown Detection section below.** When a test creates a resource, `registerTeardown` must be called immediately after the step that confirms the resource was created (not at the end of the test). Multiple `registerTeardown` calls are allowed and execute in LIFO order — register in creation order so the last created is cleaned up first. If a step requires a helper function, do NOT write it above `test.describe`. Instead, pause assembly, raise it as a **Spec-level function** extraction candidate (Step 5.5), and wait for the user's decision before continuing. If approved → import from `utils/*-helpers.ts`. If declined → inline as an arrow function INSIDE the test body only.
- **Use locators from `locators/*.ts` before emitting raw selectors.** For every selector recorded in Steps 3–4, check the Locator Lookup Table built in Step 1. If a match exists, use the locator method — this is a hard requirement (see Rule #13). Only emit a raw `page.getByRole(...)` call if no locator method covers it. If a raw selector appears 2+ times in the spec output, flag it as a Locator repetition extraction candidate.
- Import paths (two levels up from area subdirectory `journeys/{area}/`):
  - `../../utils/` — action utilities and assertion helpers (`auth.ts`, `*-helpers.ts`)
  - `../../locators/` — locator factory objects (`*-locators.ts`)
  - `../../fixtures/` — test data files

### 5.5. Propose Utility Extractions

Before running verification, present all extraction candidates to the user:

```
UTILITY EXTRACTION PROPOSALS

1. completeCheckout(page, firstName, lastName, zip)  [COMPLEXITY + REPETITION]
   Seen in: Step 4 of this test; also Step 3 of checkout-guest.spec.ts
   Placement: global (used in 2 areas)
   Would write to:  playwright-tests/utils/checkout.ts
   Would update:    playwright-tests/utils/INVENTORY.md

   async function completeCheckout(page, firstName, lastName, zip) {
     await page.getByRole('textbox', { name: 'First Name' }).fill(firstName);
     // ...
   }

   Approve? [yes / no / edit]
```

**Response handling:**

- **Approved:** write function to `.ts` file, update import in compiled spec (using relative paths; multiple utilities from the same file are combined into a single import statement), queue inventory update.

- **Declined:** record `<!-- declined: {functionName} | {targetFile} | {ISO date} -->` in the relevant inventory. The compiled spec retains the inline code for this run.

- **Edit:** output the proposed function definition (signature and body) as editable text and instruct the user to paste a revised version in their next reply. The compiler then re-presents the revised implementation as a standard yes/no prompt with no further editing allowed. If the user's next reply does not contain a function definition, the candidate is treated as declined.

If there are no candidates, skip this step entirely with no output.

#### Global vs. Area-Level Placement

The compiler determines placement by scope:

- **Global** (`playwright-tests/utils/INVENTORY.md`): utility is used in steps across 2 or more test areas, or it addresses a cross-cutting concern (session management, cookie handling, navigation to shared entry points). Locator objects always go in `playwright-tests/locators/` and are tracked in `playwright-tests/locators/INVENTORY.md` regardless of scope.
- **Area-level** (`playwright-tests/journeys/{area}/INVENTORY.md`): utility is specific to one functional area's flows and is unlikely to be referenced outside it

The area is derived from the test's immediate parent directory under `journeys/` (e.g., `journeys/checkout/login.spec.ts` → area is `checkout`).

If the compiler cannot determine scope with confidence, it defaults to global and notes this in the proposal. The user can override the placement during approval.

### 5.6. Teardown Detection

After assembling the spec body, scan each step for **resource creation signals** and emit `registerTeardown` calls immediately after the confirmed creation point.

#### Resource Creation Signals

| Signal | Examples |
|--------|---------|
| Dynamic name/ID generated in the test | `const projectName = \`AutoTest_${Date.now()}\`` |
| Step title contains "Create", "Upload", "Add", "Invite" | "Step 4: Create a new project", "Step 6: Upload file" |
| Success toast / dialog close after a form submit | `expect(page.getByText('Project successfully created')).toBeVisible()` |
| API call confirmed by visible record in a list or tree | item appears in BOM tree, supplier row visible in table |

#### Teardown Placement Rule

Register teardown **immediately after the step that confirms the resource exists** — not at the top of the test and not at the bottom. This ensures cleanup runs even when the test fails mid-way.

```typescript
// Step 4: Create project
await proj.createButton(page).click();
await expect(proj.successToast(page, 'Project successfully created.')).toBeVisible({ timeout: currentTimeout() });
// ← register here, after confirmed creation
registerTeardown(async () => {
    await tearDownArchivedProject(page, baseURL!, projectName);
});

// Step 5: ... rest of test continues
```

#### Teardown Helper Lookup

Before writing inline cleanup code, check the **Teardown Helper Map** built in Step 1 from `playwright-tests/fixtures/teardowns.ts`. If a matching helper exists, use it:

```typescript
registerTeardown(async () => {
    await tearDownArchivedProject(page, baseURL!, projectName);  // from teardowns.ts
});
```

If no helper exists, write defensive inline cleanup directly in the arrow function:

```typescript
registerTeardown(async () => {
    const row = page.getByRole('row').filter({ hasText: resourceName });
    if (!(await row.isVisible().catch(() => false))) return;
    await row.hover();
    await row.getByText('Delete', { exact: true }).click();
    await page.getByRole('button', { name: 'Delete' }).click();
});
```

#### Teardown Writing Rules

1. **Always defensive:** start with a visibility check — `if (!(await locator.isVisible().catch(() => false))) return;` — so teardown is idempotent and safe to call even if creation failed.
2. **LIFO for multi-resource:** if the test creates resources A then B, register teardown for A first, B second. LIFO execution cleans up B before A (dependency-safe).
3. **Conditional registration:** if resource creation is gated (e.g. behind a flag or a successful upload), set a `let resourceCreated = false` flag before the creation step, set it `true` immediately after the success assertion, and guard teardown: `if (!resourceCreated) return;`
4. **New tab references:** if teardown needs a page opened in a later step (e.g. admin tab), declare `let adminPage: Page | null = null` before `registerTeardown`, assign it when the tab opens, and reference it inside the teardown closure.
5. **Never use `await` outside teardown body** for teardown-only navigation — all navigation inside teardown must be inside the arrow function, not in the test body.
6. **Propose new teardown helper** when the same teardown logic appears in 2+ specs and no helper exists in `teardowns.ts` — follow the same Step 5.5 proposal flow used for action utilities.

#### When NOT to add teardown

- Test only reads data (no resource creation)
- Step title is "Verify", "Assert", "Check", or "Navigate" with no side effects
- Resource is cleaned up as a test assertion (i.e. the test itself deletes it as a verified step) — in that case, teardown is a safety net only (register it anyway but mark with `// safety net`)

### 6. Verify

Run the compiled test and confirm it passes. This is a hard gate — do not report success without a passing test run.

```bash
npx playwright test playwright-tests/journeys/{testName}.spec.ts
```

**Retry strategy (up to 3 attempts):**

1. Run the compiled test
2. On failure, analyze the Playwright error using the Error Handling Table below
3. Patch the `.spec.ts` (never the markdown source) and re-run
4. After 3 failed attempts, stop and report failure with diagnostics

#### Inventory Write Protocol

After verification passes, write queued inventory updates:

1. **Auto-detection:** Scan the compiled spec for all imported locators and utilities. Check if each is documented in INVENTORY.md.
2. **Auto-append undocumented items:** For any utility/locator imported in the spec but missing from INVENTORY.md:
   - Extract its signature from the `.ts` file or inline implementation
   - Auto-append a new row to the appropriate INVENTORY.md with a note: `(Auto-added during compilation)`
3. **Append new rows** to the appropriate `INVENTORY.md` (determined by global vs. area-level placement rule):
   - Global utilities → `playwright-tests/utils/INVENTORY.md`
   - Area-level utilities → `playwright-tests/journeys/{area}/INVENTORY.md`
   - Locator objects → `playwright-tests/locators/INVENTORY.md`
4. **Append `<!-- declined -->` comments** for declined candidates to the same file
5. **Update the `Last updated` comment** at the top of each modified file to current ISO 8601 timestamp + compilation test name

If an area-level `INVENTORY.md` does not yet exist and an area-scoped utility was approved, create the file.
If `playwright-tests/locators/INVENTORY.md` does not yet exist and a locator object was approved, create the file.

**Atomicity note:** Utility extraction writes to `.ts` files and inventory updates are batched together after verification. If verification fails, approved utilities remain in `.ts` files but are *not* recorded in inventory — they will appear as existing utilities on the next compile run.

**Staleness detection:** Before writing INVENTORY.md, run a forward-staleness check: for each entry in the existing file, verify the referenced function/method still exists in the source `.ts` file. If missing, flag for user confirmation before removal.

### 6.1. Mark Source Test Case

After verification passes (or after compilation completes when verification is skipped due to a known environment issue), write a pipeline status comment back to the markdown source file.

**Insert immediately after the `# {Test Name}` heading line** (after any existing `<!-- Jira: ... -->` comment from `/author`):

```markdown
<!-- status: compiled | spec: playwright-tests/journeys/{area}/{test-name}.spec.ts | date: {YYYY-MM-DD} -->
```

Status values:

- `compiled` — spec written and verified passing
- `compiled-env-pending` — spec written; verification skipped due to known environment issue (e.g. staging API outage); spec is structurally correct and expected to pass when environment recovers
- `blocked` — cannot proceed; reason noted in the `## ⚠️ BLOCKED` section
- `pending-compile` — test case authored/refined but not yet compiled to spec

**If a previous `<!-- status: ... -->` comment exists**, replace it in place (do not add a duplicate).

**Rule:** The only permitted modifications to the markdown source during or after compilation are the `<!-- status: ... -->` comment (Step 6.5). The `<!-- Jira: ... -->` comment, test steps, preconditions, and all other content remain authoritative and are never changed by the compiler.

### 6.2. Inventory Propagation

After writing inventory updates, check whether any newly added utility matches inline code in other existing specs:

1. For each **newly added utility** in this compilation, scan all `.spec.ts` files in `playwright-tests/journeys/` **except** the spec just compiled
2. Identify files where the utility's logical sequence appears as inline code
3. Apply the coverage gap exception: skip any spec where the matching sequence is the MAJORITY (>50%) of the test body
4. For each remaining match, propose updating the spec:

```
INVENTORY PROPAGATION

{utilityName}() was just added to the inventory.
The following specs have equivalent inline code and could be updated to use it:

  - journeys/{area}/{spec}.spec.ts  (Step N: {step title})

Update these specs to use {utilityName}()? [yes / no / skip]
```

**Response handling:**

- **yes:** Update the spec — replace the inline sequence with a utility call and add the import. Re-run `npx playwright test {spec}.spec.ts` to confirm it still passes.
- **no / skip:** Leave inline code as-is. Record the spec path in a `<!-- coverage-gap: {spec} | {utilityName} | {ISO date} -->` comment in INVENTORY.md so it is not re-proposed on the next compile.

If no matches are found, skip this step entirely with no output.

### 7. Report

**On success:**

```
COMPILED: {test name}
Source:   tests/e2e/{area}/{test-name}.md
Output:   playwright-tests/journeys/{testName}.spec.ts
Verified: PASS (attempt N/3)

Utilities reused:
  - {function} ({file})

Inline code (no matching utility):
  - Step N: {description}

Undocumented utilities found in .ts files (used but missing from INVENTORY.md):
  - {functionName} ({file}) → added to INVENTORY.md

Utility extractions approved:
  - {functionName}() → written to {file}
  - INVENTORY.md updated ({global|area})

Utility extractions declined:
  - {functionName}() → recorded as declined in {INVENTORY.md location}

Specs with coverage gaps (inline code matches an inventory utility):
  - journeys/{area}/{spec}.spec.ts — {utilityName}() at Step N  [exception: majority-of-test / updated / skipped]
```

(Utility extractions, propagation, and coverage gap sections omitted when empty)

**On failure:**

```
FAILED TO COMPILE: {test name}
Source:   tests/e2e/{area}/{test-name}.md
Output:   playwright-tests/journeys/{testName}.spec.ts (non-passing)
Attempts: 3/3

Last failure:
  Step N: {step title}
  Error: {Playwright error message}
  Suggestion: {actionable next step — e.g., "re-refine step N" or "add wait for X"}
```

## Recording Rules

How to translate browser-use actions into Playwright code:

| Browser-use action | Playwright equivalent |
|---|---|
| `browser_click` on button "{name}" | `page.getByRole('button', { name: '{name}' }).click()` |
| `browser_click` on link "{name}" | `page.getByRole('link', { name: '{name}' }).click()` |
| `browser_type` on textbox "{name}" | `page.getByRole('textbox', { name: '{name}' }).fill('{value}')` |
| `browser_type` on input with `data-test-id` | `page.getByTestId('{id}').fill('{value}')` |
| `browser_select_option` on combobox | `page.getByRole('combobox', { name: '{name}' }).selectOption('{value}')` |
| `browser_select_option` on labeled select | `page.getByLabel('{label}').selectOption('{value}')` |
| `browser_click` on checkbox | `page.getByRole('checkbox', { name: '{name}' }).check()` |
| `browser_navigate` to URL | `page.goto('{url}')` or use `goToChoosePlan(page, baseURL)` |
| `browser_wait_for` text "{text}" | `await expect(page.getByText('{text}')).toBeVisible()` |
| `browser_wait_for` URL change | `await expect(page).toHaveURL(/{pattern}/)` |
| `browser_snapshot` verify element value | `await expect(page.getByTestId('{id}')).toHaveValue('{value}')` |
| Conditional element check | `if (await el.isVisible().catch(() => false)) { ... }` |

## Selector Priority

When recording from `browser_snapshot`, choose selectors in this order:

1. **Role-based** (preferred) — `getByRole('button', { name: 'Continue' })`
2. **Test ID** — `getByTestId('login-button')` when `data-test-id` attribute exists in the snapshot
3. **Label** — `getByLabel('Primary Club')` for labeled form controls
4. **Text** — `getByText('...')` for verification assertions
5. **CSS/locator** (last resort) — `page.locator('#submit-btn')` for third-party UIs (Chargebee, Auth0 iframes)

For ambiguous matches (multiple elements), use `{ exact: true }`, `.nth()`, or scope to a parent locator.

**Note:** This project uses `testIdAttribute: 'data-test-id'` in `playwright.config.ts`. So `getByTestId('foo')` matches elements with `data-test-id="foo"` (not `data-testid`). Verify this in the config during context loading.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `isVisible({timeout: N})` | `isVisible()` takes no arguments. Use `waitFor({state: 'visible', timeout: N})` instead. |
| Guessing selectors from markdown text | ALWAYS use `browser_snapshot`. Markdown says "Proceed to Next Step" but the button might have `data-test-id="next-step-button"` and a different accessible name. |
| Static generation without browser | The whole point is guided replay. If you skip the browser, start over. |
| Cookies before vs after plan select | Only the browser reveals correct interaction order. Overlays may block buttons. |
| Patching markdown from compiled output | Source of truth flows one way: markdown → code. Never reverse. |
| Hardcoding base URL | Use `baseURL` from Playwright fixtures, not hardcoded URLs. |
| Missing environment gating | Every compiled test MUST have `test.skip` matching markdown's Environments line. |
| Forcing utility fit with wrong params | If utility is close but not identical, write inline code instead. |
| Using `page.waitForURL()` | Use `expect(page).toHaveURL()` for consistency with Playwright assertions. |
| Calling `acceptCookies()` more than once | `acceptCookies()` is **unconditional** — it clicks the Accept button with no visibility check. If the banner was already dismissed, the second call will timeout. Call it exactly once per test, at the point where the cookie banner appears (typically after the first Auth0 redirect). |
| `getByText()` for input values | `getByText()` matches visible **text content**, not input `value` attributes. For verifying values inside `<input>` or `<textarea>` elements, use `expect(locator).toHaveValue()` or `getByTestId()` combined with `.toHaveValue()`. |
| Substring name collisions in column headers | When using `getByRole('columnheader', {name})`, watch for substring matches: "Order" matches both "Order" and "Order Date"; "Status" matches both "Status" and "Pass Status". **Always add `{ exact: true }` when a column name is a prefix/substring of another column in the same table.** |
| `getByText().first()` resolving to hidden `<option>` | `getByText('Option Label').first()` may resolve to a hidden `<option>` inside a native `<select>` rather than a visible interactive element. Hidden options are not clickable. Use `selectOption()` on the `<select>` element instead. |
| `filter({hasText})` matching too broadly | `locator.filter({hasText: 'text'})` matches any ancestor containing that text, which may include multiple tables or rows. Scope to a more specific parent first, or use a more specific filter. |
| Role-hierarchy selectors break across viewport sizes | A panel that renders as `role="table"` at the default headless viewport (1280×720) may render as `role="treegrid"` at larger headed viewports. A selector like `[role="treegrid"] [role="rowgroup"] [role="row"]` can pass in headless and silently break in headed mode. **Prefer structural attributes assigned by application logic** (`aria-level`, `aria-expanded`, `aria-selected`) over role-hierarchy chains — they are viewport-independent. Example: use `[role="row"][aria-level]` to target data rows in a BOM treegrid regardless of how the surrounding layout renders. Always run verification in both headless and headed modes (`--headed` flag) when row/element count assertions are involved. |
| `registerTeardown` at end of test | Teardown registered at the end of a test body does NOT run if the test fails before reaching it. Always register immediately after the confirmed creation step. |
| Teardown without visibility guard | If the creation step failed, teardown will error trying to interact with a resource that doesn't exist. Always start with `if (!(await locator.isVisible().catch(() => false))) return;`. |
| Importing from `@playwright/test` when using `registerTeardown` | `registerTeardown` is a custom fixture from `@fixtures` — it does not exist in `@playwright/test`. Change the import or the test will fail with "registerTeardown is not a function". |
| Using `afterEach` instead of `registerTeardown` | `afterEach` does not fire on test timeout (hard time limit exceeded). `registerTeardown` (fixture teardown) does. Always use `registerTeardown` for resource cleanup. |
| Module-level variable for resource name | `let projectName: string \| undefined` declared outside `test()` and set inside is fragile when tests run in parallel. Declare the variable inside the test body and capture it in the `registerTeardown` closure. |
| Raw Playwright calls directly in the `test()` body | Every action must live inside an `await test.step('Step N: ...', async () => { ... })` block . Raw `await page.click(...)` at the test-body top level breaks the HTML reporter's step labeling. |
| Setup steps written inline in the test body | Login, navigation to the starting state, and fixture expansion belong in `test.beforeEach` (each wrapped in `test.step('Setup N: ...')`). Inline setup in the `test()` body indicates the markdown was authored without a `## Before Hook` section — re-author or hand-fix the markdown, do not paper over by inlining. |
| `test.afterEach` used for resource cleanup | `afterEach` does not fire on test timeout — created resources will leak. Use `registerTeardown` (LIFO, timeout-safe). Reserve `afterEach` for shared-fixture state restore. |
| `registerTeardown` body NOT wrapped in `test.step` | The teardown still runs but appears as an unlabeled span in the HTML reporter, making post-mortem analysis harder. Always wrap: `registerTeardown(async () => { await test.step('Teardown: ...', async () => { ... }); })`. |

## Timeout strategy (retry-aware)

This project uses a retry-aware timeout module at `playwright-tests/utils/timeouts.ts`. All non-trivial waits in compiled specs MUST go through it instead of hardcoded `timeout: N` values.

**Tiers** — caps scale with `test.info().retry`:

- Retry 0 (initial run): **2 min**
- Retry 1: **3 min**
- Retry 2+: **4 min**

**Imports:**

```ts
import { currentTimeout, smartWaitFor, smartScrollIntoView } from '../../../utils/timeouts';
// (relative path varies by spec nesting — match the existing utils/* imports in the file)
```

**Patterns to emit:**

| Intent | Old (don't emit) | New (do emit) |
|---|---|---|
| Wait for an element to be visible | `locator.waitFor({ state: 'visible', timeout: 30000 })` | `await smartWaitFor(locator)` |
| Scroll-and-wait for a lazy element | `locator.scrollIntoViewIfNeeded(); expect(locator).toBeVisible()` | `await smartScrollIntoView(locator)` |
| Native `expect(...).toBeVisible/toHaveURL/...` with long cap | `{ timeout: 30000 }` (or 15000, 60000, 120000) | `{ timeout: currentTimeout() }` |
| Fast-fail probe (≤10s) — intentional short waits like cookie banner, optional dialog | leave as-is (3000–10000) | leave as-is |
| Legitimately long wait (e.g. a slow server-side `Search for...`, 150s) | leave as-is | leave as-is, with a comment explaining why |

**When NOT to use:**

- A `.catch(() => {})` probe meant to detect optional UI — keep the short fixed cap.
- The 3s tenant-selector probe in `loginWithCredentials`.
- Very long, intentional waits (>2 min) for known-slow flows — keep explicit and comment why.

**Rule:** any new long wait (>10s) emitted by the compiler MUST go through `smartWaitFor` or `{ timeout: currentTimeout() }`. Static `timeout: 15000+` literals are a compilation defect.

## Utility Inventory Format

The compiler reads `INVENTORY.md` files from the target project repo. Format:

```markdown
# Utility Inventory
<!-- Auto-maintained by browser-test:compiler. Manual edits will be overwritten. -->
<!-- Last updated: {ISO timestamp} | Compilation: {test-name} -->

| Function | File | Signature | Purpose | When to Use |
|----------|------|-----------|---------|-------------|
| `login` | `utils/auth.ts` | `login(page, email, password): Promise<void>` | Full Auth0 login flow | Any test requiring an authenticated session |
| `navLocators.searchInput` | `locators/nav-locators.ts` | `navLocators.searchInput(page): Locator` | Search input in the nav bar | Any test that needs to interact with the nav search |
| `verifyFooSections` | `utils/foo-helpers.ts` | `verifyFooSections(page): Promise<void>` | Asserts standard Foo sections are visible/expanded | Any Foo properties test verifying standard sections |

<!-- declined: verifyOrderSummary | utils/checkout.ts | 2026-03-14 -->
```

Signatures use simplified format for readability (type annotations omitted in display). Declined extraction records are appended as HTML comments — matching on future runs is by **function name + target file path**.

**Three utility file patterns used in this project:**

- `utils/auth.ts` / `utils/*-helpers.ts` / `utils/*.ts` — action utilities and assertion helpers (`async function`)
- `locators/*-locators.ts` — locator factory objects (`const fooLocators = { method: (page) => Locator }`), each with its own entry in `locators/INVENTORY.md`
- Import paths from a spec at `journeys/{area}/foo.spec.ts`: use `../../utils/` for utilities, `../../locators/` for locators

When proposing extraction, pick the right location: locators-only → `locators/*-locators.ts`; assertions/actions → `utils/*-helpers.ts`.

## Error Handling Table

Common Playwright errors during verification and how to fix them:

| Error | Cause | Fix |
|---|---|---|
| `Timeout waiting for selector` | Element not yet rendered | Prefer `smartWaitFor(locator)` from `utils/timeouts` — it polls visibility with a retry-aware cap and network-idle fail-fast. |
| `strict mode violation` (multiple elements) | Selector matches >1 element | Add `{ exact: true }`, use `.nth(0)`, or scope to parent |
| `element is not visible` | Overlay or loading state | Add wait for overlay to disappear, or dismiss it first |
| `Navigation timeout` | Cross-domain redirect slow | Use `{ timeout: currentTimeout() }` — retry-aware cap (2/3/4 min for attempt 0/1/2+). |
| `Target page, context or browser has been closed` | Session management issue | Ensure `browser_close` before fresh session, not during test |
| `locator.fill: Element is not an input` | Wrong element type targeted | Switch to `getByTestId` or more specific role selector |
| `expect(page).toHaveURL` timeout | URL assertion too early | `{ timeout: currentTimeout() }`. Avoid sprinkling `waitForLoadState('networkidle')` — `smartWaitFor` already short-circuits on network idle. |

## Rules

1. **Browser replay is mandatory.** Every compiled test must go through guided replay. Do not generate code by reading application source files.
2. **Selectors come from snapshots.** Never read application source files (`.svelte`, route handlers, components) to discover selectors. The browser snapshot is the only selector source. Reading `playwright-tests/utils/` and `playwright-tests/fixtures/` for utility signatures (Step 1) is expected and permitted.
3. **Faithful translation.** Each markdown step maps 1:1 to a `// Step N:` comment block. Do not reorder, merge, split, or add steps beyond what the markdown specifies.
4. **Verification is a hard gate.** The compiled `.spec.ts` must pass `npx playwright test` before reporting success. No "should work" or "looks correct".
5. **Environment gating is mandatory.** Every compiled test must include `test.skip` derived from the markdown Preconditions `**Environments:**` line.
6. **Header comment is mandatory.** Every compiled file must start with `Compiled from:`, `Compiled at:`, and the "do not edit" warning.
7. **Markdown is authoritative.** Never modify the markdown source during compilation. If the test cannot compile, report failure. **Exception:** The `<!-- status: ... -->` comment (Step 6.5) is the only permitted write to the markdown source — it is inserted/updated after successful compilation or after a confirmed block.
8. **Patch code, not source.** During retry attempts, only modify the `.spec.ts` — never the markdown test case.
9. **Use existing utilities.** Check loaded utility inventories before emitting inline code. Do not duplicate existing utilities.
10. **Consistent URL assertions.** Use `expect(page).toHaveURL()` for all post-navigation URL checks, not `page.waitForURL()`.
11. **Propagate utilities back.** After adding a utility to inventory, always run the propagation check (Step 6.5) to find existing specs that still have equivalent inline code. Do not silently leave the codebase in an inconsistent state where some specs use the utility and others repeat the same logic inline.
12. **Coverage gap exception.** Never propose replacing inline code with a utility call if the matching sequence constitutes the majority of the test body — that test is likely validating the utility's behavior and must remain explicit.
13. **Use locator objects — enforced via Lookup Table.** The Locator Lookup Table built in Step 1 is the enforcement mechanism for this rule. Before emitting ANY raw selector, it must be checked against that table. If a match is found, the locator method MUST be used — no exceptions. Raw selectors in compiled output when a locator method exists = compilation error. **During extraction:** If the same raw selector appears 2+ times in the compiled spec (or 2+ times across other specs), and no matching locator method exists yet, propose extracting it as a new locator method before writing the spec.
14. **Right file for the right pattern.** Place locator factories in `*-locators.ts`, multi-step assertion/action helpers in `*-helpers.ts`, and cross-cutting auth/session utilities in `utils/*.ts`. Never mix selector-only code with assertion logic in the same file.
15. **No spec-level functions.** A `.spec.ts` file must contain only imports, `const ENV`, and `test.describe`. Any `async function` or named helper defined at the file level (above or outside `test.describe`) is forbidden. If a helper is needed, it belongs in `utils/*-helpers.ts`. Violating this rule means the spec was compiled incorrectly — stop, extract to utils, and re-assemble.
16. **Scan `.ts` files, not just inventories.** Before emitting any raw Playwright call, check actual `utils/**/*.ts` and `locators/**/*.ts` files for matching exported functions or locator methods. INVENTORY.md may lag behind the actual codebase. A utility that exists in a `.ts` file but is missing from INVENTORY.md is still an existing utility — use it and flag it for inventory documentation in the report.
17. **Teardown is mandatory for resource-creating tests.** Any test that creates a project, item, file, supplier, IR, or other persistent resource MUST emit a `registerTeardown` call immediately after the creation is confirmed. Teardown must be defensive (visibility-guarded), LIFO-ordered for multi-resource tests, and use helpers from `teardowns.ts` when available. A compiled spec that creates resources without teardown is a compilation error.
18. **Import from `@fixtures` when using `registerTeardown`.** Never import `registerTeardown` from `@playwright/test` — it does not exist there. When a test uses `registerTeardown`, change the import to `import { test, expect } from '@fixtures'`. When a test has no teardown, `@playwright/test` is acceptable but `@fixtures` is preferred for consistency.
19. **Teardown helpers over inline cleanup.** Before writing inline teardown logic, check `playwright-tests/fixtures/teardowns.ts` for an existing helper. If one matches the resource type, use it inside `registerTeardown`. If inline code would be duplicated across 2+ specs, propose a new teardown helper (same approval flow as Step 5.5).
20. **Three-hook structure is mandatory .** Every compiled spec MUST separate setup, scenario, and cleanup using `test.beforeEach` + `test.step('Setup N: ...')`, `test()` body + `test.step('Step N: ...')` per Test Step, and `registerTeardown` / `test.afterEach` per After Hook. The markdown source MUST contain `## Before Hook`, `## Test Steps`, and `## After Hook` sections (placeholders `_None — {reason}._` allowed for genuinely empty sections). A markdown source missing any of these is a compilation block — stop and report the missing section. A compiled spec missing any required hook is a compilation defect.
21. **No bare Playwright calls in the test body.** Every action and assertion in the `test()` body and inside `test.beforeEach` / `test.afterEach` lives inside an `await test.step('{Phase} N: {title}', async () => { ... })` block. Step labels mirror the markdown step titles. This is what makes Playwright's HTML reporter and trace viewer show each phase as a discrete, navigable step (the JIRA goal).

## Batch Compilation

When compiling multiple test cases:

1. Compile each test independently with its own guided replay session
2. Report results as a summary table:

```
| Test | Source | Output | Result |
|------|--------|--------|--------|
| BOM Children Count Test | tests/e2e/bom/bom-children-count.md | playwright-tests/journeys/bom/bom-children-count.spec.ts | COMPILED (1/3) |
| Item Properties Update Test | tests/e2e/item/item-properties-update.md | playwright-tests/journeys/portal/item-properties-update.spec.ts | FAILED (3/3) |
```

3. Continue to the next test even if one fails
4. End with individual reports for each test (success or failure format)
