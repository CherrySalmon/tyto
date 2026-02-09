---
name: pr-create
description: Push branch and create a GitHub PR with a structured description derived from the branch plan
---

# PR Create Skill

Push the current branch and create a GitHub pull request with a structured description derived from the branch plan document.

## Usage

```
/pr-create [<base-branch>]
```

- `/pr-create` — create PR targeting `main`
- `/pr-create develop` — create PR targeting `develop`

## What This Skill Does

1. **Locate the branch plan** for the current branch
2. **Read the plan** to extract problem, changes, design decisions, and test results
3. **Push the branch** to the remote (with `-u` flag)
4. **Create a PR** using `gh pr create` with the structured description below

## Instructions for Claude

### Step 1: Gather context

Run these in parallel:
- `git log main..HEAD --oneline` (or the specified base branch) to see all commits
- `git diff <base>...HEAD --stat` to see files changed
- Read the branch plan document (`CLAUDE.<branch-name>.md` referenced in `CLAUDE.local.md`)

### Step 2: Derive PR content from the branch plan

Extract from the branch plan:

- **Problem**: from the plan's Goal/Problem section — what user-facing or architectural issue this solves. Quantify impact where possible (e.g., "3N+1 requests → 1").
- **Changes**: from the plan's Tasks/Phases sections — what was actually implemented. Organize by architecture layer (see PR Structure below).
- **Design notes**: from the plan's Architecture Decisions or Questions sections — only non-obvious decisions a reviewer needs to understand. Omit if straightforward.
- **Test plan**: from the plan's verification/testing tasks — summarize test coverage.

### Step 3: Write the PR title

- Under 70 characters
- Describes the outcome, not the mechanism (e.g., "Enrich event responses to eliminate N+1 frontend requests" not "Add batch repository methods")

### Step 4: Push and create PR

```bash
git push -u origin <branch>
gh pr create --title "..." --body "..." --base <base>
```

## PR Structure

```markdown
## Problem

[1-3 sentences from the plan's Goal/Problem. Quantify the issue.]

## Changes

### Backend

**[Layer/concern]** — [one-line summary]:
- [specific change]
- [specific change]

**[Layer/concern]** — [one-line summary]:
- [specific change]

### Frontend

- [component]: [what changed and why]

### Design note

[Only if there's a non-obvious decision reviewers need. Otherwise omit this section.]

## Test plan

- [x] [category] ([count] tests)
- [x] [category] ([count] tests)
- [x] Full suite: [count] tests, 0 failures
- [x] Manual verification: [brief description if done]
```

### Layer/concern groupings for Changes

Organize backend changes by architectural layer. Use whichever layers are relevant — skip layers with no changes:

- **Domain** — entities, value objects, types
- **Repositories** — data access, query methods
- **Application responses** — DTOs, response objects
- **Services** — use cases, orchestration
- **Contracts** — input validation
- **Policies** — authorization, business rules
- **Presentation** — representers, serialization
- **Routes** — endpoint wiring

Frontend changes are listed by component or concern (router, state, API client, etc.).

### Principles

- **Orient the reviewer**: the PR description's job is to help someone review the diff, not replicate the design doc. Keep it concise.
- **Changes, not plans**: describe what was done, not what was considered. Design decisions belong in a short "Design note" only if they'd surprise a reviewer.
- **Quantify where possible**: test counts, request counts, query counts.
- **No duplication**: don't repeat the same information across sections. Each section has a distinct purpose.
