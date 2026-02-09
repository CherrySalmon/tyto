---
name: branch-plan
description: Create a new git branch with an accompanying plan file for tracked, context-preserving work
disable-model-invocation: true
---

# Branch Plan Skill

Create an accompanying plan file for current or provided branch to track context-preserving work.

## Usage

```
/branch-plan [<branch-name>]
```

Example 1: `/branch-plan` — creates a plan for the current branch
Example 2: `/branch-plan ray/refactor-backend-gateway` - creates a plan for a new branch

## What This Skill Does

1. **Create git branch** with the provided name if branch name is provided
2. **Create plan file** at `CLAUDE.<sanitized-branch-name>.md` (slashes become hyphens)
3. **Update `CLAUDE.local.md`** to reference the new plan file
4. **Seed the plan** with a template including the "keep up-to-date" requirement

## Plan File Template

The created plan file includes:

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
- [ ] 3 [Frontend update]
- [ ] 4 Manual verification

## Completed

(none yet)

---

*Last updated: [date]*
```

## Instructions for Claude

When the user invokes `/branch-plan`:

1. **Discover the branch name** from git
2. **Sanitize for filename**: Replace `/` with `-` for the plan filename, etc.
3. **Create plan file**: `CLAUDE.<sanitized-name>.md` with the template above
4. **Update CLAUDE.local.md**: Replace the existing `@CLAUDE.*.md` reference with the new file
5. **Ask the user** for a one-line goal to add to the plan (optional)
6. **Report success** with the created branch and file paths

### Planning and execution guidelines

When populating or updating a plan, follow these principles:

**Vertical slice**: Each branch is typically one slice — a complete, testable feature from backend to frontend. Avoid horizontal layers (e.g., "all tests first, then all implementation"). For extensive long-term plans requiring multiple slices, number them (Slice 1, Slice 2, etc.) with per-slice Scope/Tasks sections and prefixed task IDs (1.1a, 1.2, 2.1a, 2.2, etc.).

**Test-first (red-green-refactor)**: Each branch begins with failing tests before implementation.

- Test tasks use lettered sub-IDs (1a, 1b) and precede implementation tasks (2, 3)
- Implementation should make the tests pass — no more, no less
- If tests cannot be written first for a particular task (e.g., pure config changes, frontend-only cleanup), note that explicitly

**Single plan file**: Tests are part of the plan, not a separate document. The Tasks section includes both test and implementation tasks in execution order.

**Scope decisions**: Record what's deferred and why. Use the Questions section for open design decisions — cross off when resolved, note the decision made.

## Example

Input: `/branch-plan ray/add-file-uploads`

Creates:

- Branch: `ray/add-file-uploads`
- File: `CLAUDE.ray-add-file-uploads.md`
- Updates: `CLAUDE.local.md` → `@CLAUDE.ray-add-file-uploads.md`
