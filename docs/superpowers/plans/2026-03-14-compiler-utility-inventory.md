# Compiler Utility Inventory Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the compiler skill to discover existing utilities via INVENTORY.md files and propose new utility extractions with human approval.

**Architecture:** Inventory files live in target project repos (not the skills repo). The compiler reads inventories at startup, checks for staleness, proposes extractions during compilation, and updates inventories after verification passes.

**Tech Stack:** Markdown skill definition, no runtime code changes.

**Spec:** `docs/superpowers/specs/2026-03-14-compiler-utility-inventory-design.md`

---

## Chunk 1: Step 1 and Step 3 Updates

### Task 1: Update Step 1 Item 4 — Inventory Loading

**Files:**

- Modify: `skills/compiler/SKILL.md:41` (Step 1 item 4)

The current item 4 reads:

```
4. All files in `playwright-tests/utils/` (utility inventory)
```

Replace with the new wording from the spec.

- [ ] **Step 1.1: Read current Step 1 section to confirm exact location**

Verify line 41 contains item 4 as expected.

- [ ] **Step 1.2: Replace Step 1 item 4**

Old:

```markdown
4. All files in `playwright-tests/utils/` (utility inventory)
```

New:

```markdown
4. `playwright-tests/utils/INVENTORY.md` and `playwright-tests/journeys/{area}/INVENTORY.md` (utility inventories — run bootstrapping if global inventory absent; run staleness check against referenced `.ts` files before proceeding)
```

- [ ] **Step 1.3: Verify the edit didn't break surrounding content**

Read lines 35-50 to confirm structure is intact.

---

### Task 2: Add Bootstrapping Subsection to Step 1

**Files:**

- Modify: `skills/compiler/SKILL.md` (after Step 1 item list, before Step 2)

- [ ] **Step 2.1: Add bootstrapping flow after the item list**

Insert after the "Parse from the markdown" bullet list (around line 52):

```markdown
#### Bootstrapping (first compile in a project)

If no global `INVENTORY.md` exists at `playwright-tests/utils/INVENTORY.md`:

1. Scan `playwright-tests/utils/**/*.ts` (recursive) and extract exported function signatures and JSDoc comments
2. Generate a proposed `INVENTORY.md` and present it to the user for review before any other compilation work continues
3. User approves or declines:
   - **Approved:** file is written, compilation proceeds with the inventory loaded
   - **Declined:** compilation proceeds without an inventory for this run; no file is written; the bootstrap will be offered again on the next compile run

Area-level `INVENTORY.md` files are not bootstrapped — they are created on-demand when the first area-specific utility is extracted and the user approves it.

#### Staleness Check

After loading inventories, cross-check each entry against its referenced `.ts` file. Any entry whose function no longer exists in the referenced file is flagged and presented for removal confirmation (multiple stale entries are batched). If the user declines removal, stale entries are retained unchanged and flagged again on the next compile.
```

- [ ] **Step 2.2: Verify insertion is correctly placed**

Read the section to confirm it appears between Step 1 and Step 2.

---

### Task 3: Update Step 3 Convention-Shorthand Reference

**Files:**

- Modify: `skills/compiler/SKILL.md:82` (Step 3 critical constraints)

- [ ] **Step 3.1: Find and update the convention-shorthand sentence**

Current text (line 82):

```markdown
- If a step references a convention shorthand (e.g., "Complete Auth0 login"), check the Utility Mapping Table before expanding inline
```

New text:

```markdown
- If a step references a convention shorthand (e.g., "Complete Auth0 login"), check the loaded utility inventories before expanding inline
```

- [ ] **Step 3.2: Commit chunk 1**

```bash
git add skills/compiler/SKILL.md
git commit -m "feat(compiler): add inventory loading, bootstrapping, and staleness check to Step 1

- Replace direct utils/*.ts scan with INVENTORY.md loading
- Add bootstrapping flow for first compile in a project
- Add staleness check against referenced .ts files
- Update Step 3 to reference inventories instead of mapping table

Implements spec sections: Bootstrapping, Compiler Skill Changes Step 1"
```

---

## Chunk 2: Step 4 Replacement

### Task 4: Replace Step 4 with Inventory Lookup and Extraction Triggers

**Files:**

- Modify: `skills/compiler/SKILL.md:84-89` (Step 4)

- [ ] **Step 4.1: Read current Step 4 content**

Confirm the current Step 4 "Map to Existing Utilities" section boundaries.

- [ ] **Step 4.2: Replace Step 4 entirely**

Replace the current Step 4 (lines 84-89) with:

```markdown
### 4. Map to Existing Utilities

Before emitting raw Playwright calls for a recorded sequence, check the loaded utility inventories (global and area-level). Rules:
- If an exact match exists, use the utility
- If a utility is close but not identical to the recorded sequence, emit inline code — do not force a fit
- Track which utilities were reused and which steps required inline code (for the report)

#### Extraction Triggers

Three conditions flag a recorded sequence as a **utility extraction candidate**:

| Trigger | Condition |
|---------|-----------|
| **Repetition** | Same logical sequence already appears in ≥1 other `.spec.ts` in `playwright-tests/journeys/` (excludes the test currently being compiled) |
| **Complexity** | Inline sequence is 5+ lines for a single logical operation |
| **Dangling convention reference** | A markdown step names a convention shorthand (e.g., "Complete checkout") but no matching utility exists in the loaded inventory. This trigger only fires when an inventory has been loaded — if bootstrapping was declined, this trigger is suppressed for the run. |

Candidates whose function name + target file match a `<!-- declined -->` entry in the relevant inventory are silently skipped — not re-proposed.
```

- [ ] **Step 4.3: Verify Step 4 replacement**

Read the updated section to confirm formatting is correct.

- [ ] **Step 4.4: Commit chunk 2**

```bash
git add skills/compiler/SKILL.md
git commit -m "feat(compiler): replace Step 4 with inventory lookup and extraction triggers

- Check loaded inventories instead of empty mapping table
- Add extraction trigger rules: repetition, complexity, dangling convention
- Skip candidates matching declined entries

Implements spec section: Compiler Skill Changes Step 4"
```

---

## Chunk 3: Add Step 5.5 — Propose Utility Extractions

### Task 5: Insert Step 5.5 Between Assembly and Verify

**Files:**

- Modify: `skills/compiler/SKILL.md` (after Step 5, before Step 6)

- [ ] **Step 5.1: Locate insertion point**

Find where Step 5 (Assemble .spec.ts) ends and Step 6 (Verify) begins.

- [ ] **Step 5.2: Insert Step 5.5**

Insert before Step 6:

```markdown
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

- **Global** (`playwright-tests/utils/INVENTORY.md`): utility is used in steps across 2 or more test areas, or it addresses a cross-cutting concern (session management, cookie handling, navigation to shared entry points)
- **Area-level** (`playwright-tests/journeys/{area}/INVENTORY.md`): utility is specific to one functional area's flows and is unlikely to be referenced outside it

The area is derived from the test's immediate parent directory under `journeys/` (e.g., `journeys/checkout/login.spec.ts` → area is `checkout`).

If the compiler cannot determine scope with confidence, it defaults to global and notes this in the proposal. The user can override the placement during approval.
```

- [ ] **Step 5.3: Verify Step 5.5 is correctly positioned**

Read surrounding sections to confirm step numbering flow.

- [ ] **Step 5.4: Commit chunk 3**

```bash
git add skills/compiler/SKILL.md
git commit -m "feat(compiler): add Step 5.5 for utility extraction proposals

- Present extraction candidates before verification
- Support approve/decline/edit workflow
- Document global vs area-level placement rules

Implements spec section: Compiler Skill Changes Step 5.5"
```

---

## Chunk 4: Step 6 (Inventory Write Protocol) and Step 7 (Report) Updates

### Task 6: Add Inventory Write Protocol to Step 6

**Files:**

- Modify: `skills/compiler/SKILL.md` (Step 6 Verify section)

- [ ] **Step 6.1: Read current Step 6 content**

Confirm the current structure of the Verify section.

- [ ] **Step 6.2: Add inventory write protocol after verification passes**

Insert after the retry strategy section, before Step 7:

```markdown
#### Inventory Write Protocol

After verification passes, write queued inventory updates:

1. Append new rows to the appropriate `INVENTORY.md` (determined by global vs. area placement rule)
2. Append `<!-- declined -->` comments for declined candidates to the same file
3. Update the `Last updated` comment at the top of the file

If an area-level `INVENTORY.md` does not yet exist and an area-scoped utility was approved, create the file.

**Atomicity note:** Utility extraction writes to `.ts` files and inventory updates are batched together after verification. If verification fails, approved utilities remain in `.ts` files but are *not* recorded in inventory — they will appear as existing utilities on the next compile run.
```

---

### Task 7: Update Step 7 Report Format

**Files:**

- Modify: `skills/compiler/SKILL.md` (Step 7 Report section)

- [ ] **Step 7.1: Read current Step 7 success report format**

Identify the "Suggested new utilities:" block to replace.

- [ ] **Step 7.2: Replace success report format**

Remove the `Suggested new utilities:` block and replace the relevant portion with:

Old block (remove entirely):

```
Suggested new utilities:
  - {functionName}({params}): {returnType}
    -> Add to playwright-tests/utils/{file}.ts
    -> {description of what it does}
    -> Used in: {which steps reference this pattern}
```

New blocks (add conditionally — omit when empty):

```
Utility extractions approved:
  - {functionName}() → written to {file}
  - INVENTORY.md updated ({global|area})

Utility extractions declined:
  - {functionName}() → recorded as declined in {INVENTORY.md location}
```

- [ ] **Step 7.3: Commit chunk 4**

```bash
git add skills/compiler/SKILL.md
git commit -m "feat(compiler): add inventory write protocol and update report format

- Add inventory write protocol after verification passes
- Replace 'Suggested new utilities' with extraction approved/declined sections
- Sections omitted when empty

Implements spec sections: Inventory Write Protocol, Success Report Changes"
```

---

## Chunk 5: Rule 9 Update and Utility Mapping Table Section

### Task 8: Update Rule 9

**Files:**

- Modify: `skills/compiler/SKILL.md:269` (Rule 9)

- [ ] **Step 8.1: Find and update Rule 9**

Current text:

```markdown
9. **Use existing utilities.** Check the Utility Mapping Table before emitting inline code. Do not duplicate existing utilities.
```

New text:

```markdown
9. **Use existing utilities.** Check loaded utility inventories before emitting inline code. Do not duplicate existing utilities.
```

---

### Task 9: Update Utility Mapping Table Section

**Files:**

- Modify: `skills/compiler/SKILL.md:241-244` (Utility Mapping Table section)

- [ ] **Step 9.1: Replace Utility Mapping Table section**

Current section (empty placeholder):

```markdown
## Utility Mapping Table

Check recorded sequences against known playwright utilities in the repo before emitting inline code:
```

New section:

```markdown
## Utility Inventory Format

The compiler reads `INVENTORY.md` files from the target project repo. Format:

```markdown
# Utility Inventory
<!-- Auto-maintained by browser-test:compiler. Manual edits will be overwritten. -->
<!-- Last updated: {ISO timestamp} | Compilation: {test-name} -->

| Function | File | Signature | Purpose | When to Use |
|----------|------|-----------|---------|-------------|
| `login` | `utils/auth.ts` | `login(page, email, password): Promise<void>` | Full Auth0 login flow | Any test requiring an authenticated session |

<!-- declined: verifyOrderSummary | utils/checkout.ts | 2026-03-14 -->
```

Signatures use simplified format for readability (type annotations omitted in display). Declined extraction records are appended as HTML comments — matching on future runs is by **function name + target file path**.

```

- [ ] **Step 9.2: Commit chunk 5**

```bash
git add skills/compiler/SKILL.md
git commit -m "feat(compiler): update Rule 9 and replace Utility Mapping Table with Inventory Format

- Rule 9 now references utility inventories
- Document INVENTORY.md format for target project repos

Implements spec section: Inventory File Format"
```

---

## Chunk 6: README Update

### Task 10: Update README Project Setup Section

**Files:**

- Modify: `README.md:170-185` (Project Setup section)

- [ ] **Step 10.1: Read current Project Setup structure**

Verify the file tree location.

- [ ] **Step 10.2: Add INVENTORY.md to the file tree**

Update the file tree to include:

```
└── playwright-tests/
    ├── playwright.config.ts
    ├── utils/
    │   ├── INVENTORY.md              # Utility inventory (auto-generated by compiler)
    │   └── *.ts                      # Shared test utilities
    ├── fixtures/                     # Test data and credentials
    └── journeys/{area}/
        ├── INVENTORY.md              # Area-specific inventory (auto-generated)
        └── *.spec.ts                 # Compiled test files
```

- [ ] **Step 10.3: Add brief explanation after the tree**

After the file tree, before "### Conventions Files", add:

```markdown
### Utility Inventories

The `browser-test:compiler` skill auto-generates `INVENTORY.md` files to track available utilities:

- **`playwright-tests/utils/INVENTORY.md`** — Global utilities available to all test areas
- **`playwright-tests/journeys/{area}/INVENTORY.md`** — Area-specific utilities

These files are created on first compile and updated as new utilities are extracted. The compiler uses them to avoid duplicating existing utilities and to propose extractions for repeated patterns.
```

- [ ] **Step 10.4: Commit chunk 6**

```bash
git add README.md
git commit -m "docs: add INVENTORY.md to project setup documentation

- Add INVENTORY.md files to project structure diagram
- Add Utility Inventories subsection explaining auto-generation

Implements spec section: README.md updates"
```

---

## Chunk 7: Final Verification

### Task 11: Verify Complete Implementation

- [ ] **Step 11.1: Read the full updated SKILL.md**

Verify all sections are present and correctly formatted.

- [ ] **Step 11.2: Cross-check against spec**

Verify each spec requirement is addressed:

- [ ] Step 1 item 4 replacement
- [ ] Bootstrapping flow documented
- [ ] Staleness check documented
- [ ] Step 3 convention-shorthand updated
- [ ] Step 4 extraction triggers documented
- [ ] Step 5.5 proposal workflow documented
- [ ] Inventory write protocol documented
- [ ] Success report updated
- [ ] Rule 9 updated
- [ ] Utility Inventory Format section added

- [ ] **Step 11.3: Verify README updates**

Confirm INVENTORY.md appears in project structure and has explanation.

- [ ] **Step 11.4: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: final cleanup for compiler utility inventory implementation"
```

- [ ] **Step 11.5: Mark spec as Implemented**

Update spec status from "Approved" to "Implemented":

```bash
# In docs/superpowers/specs/2026-03-14-compiler-utility-inventory-design.md
# Change: **Status:** Approved
# To:     **Status:** Implemented
```

```bash
git add docs/superpowers/specs/2026-03-14-compiler-utility-inventory-design.md
git commit -m "docs: mark compiler utility inventory spec as implemented"
```
