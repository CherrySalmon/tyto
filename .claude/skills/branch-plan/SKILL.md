---
name: branch-plan
description: Create a plan document for the current branch, or for a specified new/existing branch. The complete template and all instructions are provided below — do not search for examples elsewhere.
disable-model-invocation: true
---

# Branch Plan Skill

## Usage

```
/branch-plan [<branch-name>]
```

- `/branch-plan` — plan for the current branch
- `/branch-plan ray/refactor-backend-gateway` — create branch and plan

## Instructions for Claude

When the user invokes `/branch-plan`:

1. **Discover branch**: Use current branch, or create the named branch
2. **Create plan file**: `CLAUDE.<sanitized-name>.md` (replace `/` with `-`) using the template below
3. **Update `CLAUDE.local.md`**: Replace existing `@CLAUDE.*.md` reference with the new file
4. **Ask the user** for a one-line goal (optional)
5. **Report** created branch and file paths

### Planning and execution guidelines

When populating or updating a plan:

**Vertical slice**: One branch = one complete feature, backend to frontend. No horizontal layers. For multi-slice plans, number slices (Slice 1, 2) with per-slice Scope/Tasks sections and prefixed task IDs (1.1a, 1.2, 2.1a).

**Test-first**: Tests (lettered sub-IDs: 1a, 1b) precede implementation (2, 3). Implementation makes tests pass — no more, no less. Note explicitly when test-first isn't feasible.

**Single plan file**: Tests and implementation tasks together in execution order.

**Update after each phase**: After each phase completes (tests written, implementation passing, frontend updated, verification), immediately update the plan: mark completed tasks, record findings/decisions, update Current State.

**Completed log**: After each task, add a one-line entry to the Completed table (task ID, summary, test count). Include implementation gotchas only if they'll help resume after context clears. When a slice is finished and stable, trim the Completed table to compact one-liners and move any important gotchas into code comments where they'll be found in context.

**Review log**: After verification, add review notes as numbered items. When review items are resolved, collapse them to a single summary line and keep only deferred items with full detail.

**Review checkpoints**: Insert explicit pause points in the task list where work stops for developer review before continuing. At minimum, insert a checkpoint after backend implementation passes all tests (before starting frontend) and after frontend verification (before moving to the next slice). Use a bold line in the task list:

```
**REVIEW CHECKPOINT**: Pause for developer review of [scope]. All [tests/flows] should [pass/work]. Resume with [next phase] after review.
```

The checkpoint ensures the developer can inspect, run, and approve the work before building on top of it. Do not proceed past a checkpoint without developer confirmation.

**Scope decisions**: Record deferrals and rationale. Cross off resolved Questions with the decision made.

**Markdownlint clean**: The final plan document must have no markdownlint warnings. Verify before finishing. Note: line-length limits (MD013) are disabled — do not wrap lines to 80 characters. If a `.markdownlint.json` does not already exist in the project root, create one to codify these and any other deliberate rule exclusions from this skill.

## Plan File Template

```markdown
# [Title based on branch name]

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`<branch-name>`

## Goal

[To be filled in]

## Strategy: Vertical Slice

Deliver a complete, testable feature end-to-end:

1. **Backend test** — Write failing test for new behavior (red)
2. **Backend implementation** — Make the test pass (green)
3. **Frontend update** — Remove old logic, consume new API
4. **Verify** — Manual or E2E test confirms behavior

## Current State

- [ ] Plan created
- [ ] [Additional items to be added]

## Key Findings

[Analysis of existing code, capabilities, and gaps — to be filled in during investigation]

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [ ] [To be added]

## Scope

[What's in and out of scope]

**Backend changes**:

- [Description of backend work]

**Frontend changes**:

- [Description of frontend work]

## Tasks

> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

- [ ] 1a [Failing test for expected behavior]
- [ ] 1b [Additional test scenarios]
- [ ] 2 [Implementation to make tests pass]
- [ ] 3 All backend tests pass

**REVIEW CHECKPOINT**: Pause for developer review of backend. All tests should pass. Resume with frontend after review.

- [ ] 4 [Frontend update]
- [ ] 5 Hybrid verification (see review log)
- [ ] 6 Resolve review notes from verification

## Completed

| Task | Summary | Tests |
|------|---------|-------|
| — | *(none yet)* | — |

## Review Log

*(none yet)*

---

Last updated: [date]
```

## Example

Input: `/branch-plan ray/add-file-uploads`

Creates:

- Branch: `ray/add-file-uploads`
- File: `CLAUDE.ray-add-file-uploads.md`
- Updates: `CLAUDE.local.md` → `@CLAUDE.ray-add-file-uploads.md`
