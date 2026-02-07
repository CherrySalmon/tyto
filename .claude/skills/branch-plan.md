# Branch Plan Skill

Create a new git branch with an accompanying plan file for tracked, context-preserving work.

## Usage

```
/branch-plan <branch-name>
```

Example: `/branch-plan ray/refactor-backend-gateway`

## What This Skill Does

1. **Create git branch** with the provided name
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

## Current State

- [ ] Plan created
- [ ] [Additional items to be added]

## Design

[To be filled in]

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [ ] [To be added]

## Tasks

- [ ] [To be added]

## Completed

(none yet)

---

*Last updated: [date]*
```

## Instructions for Claude

When the user invokes `/branch-plan`:

1. **Discover the branch name** from git
2. **Sanitize for filename**: Replace `/` with `-` for the plan filename, etc.
4. **Create plan file**: `CLAUDE.<sanitized-name>.md` with the template above
5. **Update CLAUDE.local.md**: Replace the existing `@CLAUDE.*.md` reference with the new file
6. **Ask the user** for a one-line goal to add to the plan (optional)
7. **Report success** with the created branch and file paths

## Example

Input: `/branch-plan ray/add-file-uploads`

Creates:
- Branch: `ray/add-file-uploads`
- File: `CLAUDE.ray-add-file-uploads.md`
- Updates: `CLAUDE.local.md` → `@CLAUDE.ray-add-file-uploads.md`
