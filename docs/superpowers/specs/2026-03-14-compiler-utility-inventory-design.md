# Design: Compiler Utility Inventory

**Date:** 2026-03-14
**Status:** Implemented
**Scope:** `browser-test:compiler` skill + target project repo conventions

---

## Problem

The compiler skill needs to discover and reuse existing helper/utility functions in the target project's Playwright codebase. A previous version embedded a utility mapping table directly in the skill, but that was project-specific and was removed. There is currently no mechanism for the compiler to know what utilities exist in a given project — the `## Utility Mapping Table` section in `SKILL.md` is intentionally empty.

---

## Goals

- Compiler discovers existing utilities in the target project and reuses them
- Compiler identifies new utility extraction candidates and proposes them to the user (human-in-the-loop writes)
- Inventory lives in the target project repo, not the skills repo
- Structure mirrors the existing `conventions.md` pattern (global + area-level)
- `conventions.md` files are not overloaded with utility information

---

## Non-Goals

- Compiler does not autonomously write utilities without human approval
- Compiler does not refactor existing utilities
- No changes to `browser-test:author` or `browser-test:refiner` skills

---

## File Structure

Two new file types are added to the **target project repo**:

```
playwright-tests/
├── utils/
│   ├── INVENTORY.md          ← global utility inventory
│   ├── auth.ts
│   └── navigation.ts
└── journeys/
    ├── checkout/
    │   ├── INVENTORY.md      ← area-specific inventory
    │   └── checkout-flow.spec.ts
    └── auth/
        ├── INVENTORY.md
        └── login.spec.ts
```

`INVENTORY.md` at the global level covers utilities applicable across all test areas. Area-level `INVENTORY.md` files cover utilities scoped to a specific functional area.

---

## Inventory File Format

```markdown
# Utility Inventory
<!-- Auto-maintained by browser-test:compiler. Manual edits will be overwritten. -->
<!-- Last updated: {ISO timestamp} | Compilation: {test-name} -->

| Function | File | Signature | Purpose | When to Use |
|----------|------|-----------|---------|-------------|
| `login` | `utils/auth.ts` | `login(page, email, password): Promise<void>` | Full Auth0 login flow | Any test requiring an authenticated session |
| `acceptCookies` | `utils/cookies.ts` | `acceptCookies(page): Promise<void>` | Clicks Accept on cookie banner (unconditional) | Once per test after first Auth0 redirect; never call twice |

Signatures use simplified format for readability (type annotations omitted in display).

<!-- declined: verifyOrderSummary | utils/checkout.ts | 2026-03-14 -->
```

Declined extraction records are appended as HTML comments. The comment format is `<!-- declined: {functionName} | {targetFile} | {ISO date} -->`. Matching on future runs is by **function name + target file path** — if a candidate's proposed name and target file both match a declined entry, it is skipped. This is intentionally loose: a different function name for the same logical pattern will be re-proposed, letting users accept a renamed variant.

---

## Bootstrapping

On first compilation in a project where no global `INVENTORY.md` exists:

1. Compiler scans `playwright-tests/utils/**/*.ts` (recursive) and extracts exported function signatures and JSDoc comments
2. Generates a proposed `INVENTORY.md` and presents it to the user for review before any other compilation work continues
3. User approves or declines:
   - **Approved:** file is written, compilation proceeds with the inventory loaded
   - **Declined:** compilation proceeds without an inventory for this run; no file is written; the bootstrap will be offered again on the next compile run
4. The bootstrap comment reads: `<!-- Auto-maintained by browser-test:compiler. Manual edits will be overwritten. -->` — this is accurate for ongoing use. The initial approval step is a one-time bootstrapping action, not a contradiction of this instruction.

Area-level `INVENTORY.md` files are not bootstrapped. They are created on-demand when the first area-specific utility is extracted and the user approves it.

---

## Global vs. Area-Level Placement

When proposing a new utility, the compiler determines placement by scope:

- **Global** (`playwright-tests/utils/INVENTORY.md`): utility is used in steps across 2 or more test areas, or it addresses a cross-cutting concern (session management, cookie handling, navigation to shared entry points)
- **Area-level** (`playwright-tests/journeys/{area}/INVENTORY.md`): utility is specific to one functional area's flows and is unlikely to be referenced outside it

The area is derived from the test's immediate parent directory under `journeys/` (e.g., `journeys/checkout/login.spec.ts` → area is `checkout`).

If the compiler cannot determine scope with confidence, it defaults to global and notes this in the proposal. The user can override the placement during approval.

---

## Compiler Skill Changes

### Step 1 — Load Context (additions)

After reading conventions, load inventories:

1. `playwright-tests/utils/INVENTORY.md` — if absent, run bootstrapping flow (blocks compilation until user responds)
2. `playwright-tests/journeys/{area}/INVENTORY.md` — if absent, proceed without (no scan needed)

The staleness check also runs at this point: cross-check each inventory entry against its referenced `.ts` file. Any entry whose function no longer exists in the referenced file is flagged and presented for removal confirmation before compilation continues. Multiple stale entries are presented as a single batch for removal confirmation. If the user declines removal, the stale entries are retained in the inventory file unchanged and treated as valid for this run — the compiler will not rewrite the inventory, and stale entries will be flagged again on the next compile.

**Replaces:** current Step 1 item 4, which reads `All files in playwright-tests/utils/ (utility inventory)`. The new wording for item 4 is:
> `playwright-tests/utils/INVENTORY.md` and `playwright-tests/journeys/{area}/INVENTORY.md` (utility inventories — run bootstrapping if global inventory absent; run staleness check against referenced `.ts` files before proceeding)

### Step 4 — Map to Existing Utilities (replacement)

The empty "Utility Mapping Table" section is replaced by a runtime lookup against the loaded inventories. Before emitting any inline Playwright code for a recorded sequence, the compiler checks both the global and area inventories for a matching utility.

Three triggers flag a recorded sequence as a **utility extraction candidate**:

| Trigger | Condition |
|---------|-----------|
| **Repetition** | Same logical sequence already appears in ≥1 other `.spec.ts` in `playwright-tests/journeys/` (excludes the test currently being compiled) |
| **Complexity** | Inline sequence is 5+ lines for a single logical operation |
| **Dangling convention reference** | A markdown step names a convention shorthand (e.g. "Complete checkout") but no matching utility exists in the loaded inventory. This trigger only fires when an inventory has been loaded — if bootstrapping was declined, this trigger is suppressed for the run. |

Candidates whose function name + target file match a `<!-- declined -->` entry in the relevant inventory are silently skipped — not re-proposed.

### Step 5.5 — Propose Utility Extractions (new, between assembly and verify)

Before running `npx playwright test`, the compiler presents all candidates to the user:

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

**Approved:** write function to `.ts` file, update import in compiled spec (using relative paths; multiple utilities from the same file are combined into a single import statement), queue inventory update.

**Declined:** record `<!-- declined: {functionName} | {targetFile} | {ISO date} -->` in the relevant inventory. The compiled spec retains the inline code for this run.

**Edit:** the compiler outputs the proposed function definition (signature and body) as editable text and instructs the user to paste a revised version in their next reply. "Submitting" means sending a message that contains a function definition (i.e., the user's reply contains code). The compiler then re-presents the revised implementation as a standard yes/no prompt with no further editing allowed. If the user's next reply does not contain a function definition (e.g. they reply with text only, or say "skip" or "no"), the candidate is treated as declined.

If there are no candidates, this step is skipped entirely with no output.

---

## Inventory Write Protocol

After verification passes, the compiler writes queued inventory updates:

1. Append new rows to the appropriate `INVENTORY.md` (determined by global vs. area placement rule above)
2. Append `<!-- declined -->` comments for declined candidates to the same file
3. Update the `Last updated` comment at the top of the file

If an area-level `INVENTORY.md` does not yet exist and an area-scoped utility was approved, the file is created at this point.

**Atomicity note:** Utility extraction writes to `.ts` files and inventory updates are batched together after verification. If verification fails, approved utilities remain in `.ts` files but are *not* recorded in inventory — they will appear as existing utilities on the next compile run.

---

## Success Report Changes

The compiler success report gains extraction sections when relevant. Sections are omitted entirely if there is nothing to report in them:

```
Utility extractions approved:
  - completeCheckout() → written to utils/checkout.ts
  - INVENTORY.md updated (global)

Utility extractions declined:
  - verifyOrderSummary() → recorded as declined in utils/INVENTORY.md
```

---

## Scope of Implementation

Changes required:

1. **`skills/compiler/SKILL.md`**
   - Step 1 item 4: replace direct `utils/*.ts` scan with inventory loading + staleness check (exact wording specified above)
   - Step 3: update convention-shorthand sentence from "check the Utility Mapping Table before expanding inline" to "check the loaded utility inventories before expanding inline"
   - Step 4: replace empty Utility Mapping Table section with inventory lookup and extraction trigger rules
   - Add Step 5.5: Propose Utility Extractions
   - Step 7 (success report): remove the `Suggested new utilities:` block; replace with conditional `Utility extractions approved:` and `Utility extractions declined:` sections (omitted when empty)
   - Rule 9: update from "Check the Utility Mapping Table before emitting inline code" to "Check loaded utility inventories before emitting inline code. Do not duplicate an existing utility."

2. **Target project repos** — `INVENTORY.md` files (auto-generated on first compile, not part of this skills repo)

3. **`README.md`** — brief mention of `INVENTORY.md` in the Project Setup section
