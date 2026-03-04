---
name: pr-create
description: Push branch and create or update a GitHub PR with a structured description derived from the branch plan
allowed-tools: Bash(git *), Bash(gh pr *), Bash(gh api *)
---

# PR Create Skill

Push the current branch and create (or update) a GitHub pull request with a structured description derived from the branch plan document.

## Usage

```text
/pr-create [<base-branch>] [--ready]
```

- `/pr-create` — create a draft PR (base branch auto-detected)
- `/pr-create develop` — create a draft PR targeting `develop`
- `/pr-create --ready` — create a non-draft PR (for finished work)

PRs are created as **drafts by default** — open them early after your first commit and update as you go.

## What This Skill Does

1. **Detect base branch** — use explicit argument, or auto-detect (see below)
2. **Check for existing PR** on this branch — update it if one exists, create if not
3. **Locate the branch plan** for the current branch (with fallback)
4. **Read the plan** to extract goal, changes, and decisions
5. **Push the branch** to the remote (with `-u` flag)
6. **Create or update the PR** using `gh pr create` or `gh pr edit`

## Instructions for Claude

### Step 1: Determine the base branch

If the user provides a base branch, use it. Otherwise, auto-detect:

1. Check if a `develop` branch exists (`git rev-parse --verify develop`)
2. If `develop` exists **and** the current branch is not a release branch (`release/*`), use `develop`
3. If on a release branch, ask the user — both `main`/`master` and `develop` are reasonable targets
4. Otherwise, use `main` — or `master` if `main` does not exist

### Step 2: Check for an existing PR

Run `gh pr view --json number,title,url 2>/dev/null` to check if a PR already exists for this branch.

- If a PR exists, this is an **update** — use `gh pr edit` in step 6
- If no PR exists, this is a **create** — use `gh pr create` in step 6

### Step 3: Gather context

Run these in parallel:

- `git log <base>..HEAD --oneline` to see all commits on this branch
- `git diff <base>...HEAD --stat` to see files changed
- Read the branch plan document (`CLAUDE.<branch-name>.md` referenced in `CLAUDE.local.md`)

**If no branch plan exists**, fall back to deriving the PR description from the commits and diff alone. Use the commit messages to infer the summary, and the diff stat to understand scope.

### Step 4: Derive PR content

**When a branch plan exists** — extract from it:

- **Summary**: from the plan's Goal section — 1-3 sentences on what this PR achieves.
- **Plan**: from the plan's Tasks section — a checklist of work items. Completed items are checked off; remaining items are unchecked. This lets reviewers see both what's done and what's planned.
- **Changes**: from commits and the plan's completed tasks — what was actually implemented, organized by concern. Only include this section if the plan checklist alone doesn't convey the changes clearly enough.
- **Design notes**: from the plan's Architecture Decisions or Questions sections — only non-obvious decisions a reviewer needs to understand. Omit if straightforward.

**When no branch plan exists** — derive from commits and diff:

- **Summary**: synthesize from commit messages — what does this PR achieve overall?
- **Changes**: group commits by concern into a concise list of what changed.
- Omit the Plan section (no plan document to reference).

### Step 5: Write the PR title

Follow the pattern: `<category>(<scope>): <purpose>`

- All lowercase
- Under 70 characters
- Categories: `feat`, `fix`, `docs`, `chore` (also `style`, `refactor`)
- Scope in parentheses (e.g., `backend`, `frontend`, `fullend`, `database`, `app`, `api`, `worker`) — omit if the project has a single scope
- Purpose describes the outcome, not the mechanism

Examples:

- `feat(app): add new survey chart`
- `fix(backend): make service layer generate survey correctly`
- `docs: split workflow docs into semver and trunk-based`

### Step 6: Push and create or update PR

```bash
git push -u origin <branch>
```

**Creating a new PR** (default is draft):

```bash
gh pr create --draft --title "..." --body "..." --base <base>
```

If `--ready` was specified:

```bash
gh pr create --title "..." --body "..." --base <base>
```

**Updating an existing PR**:

```bash
gh pr edit --title "..." --body "..."
```

## PR Structure

```markdown
## Summary

[1-3 sentences from the plan's Goal. What does this PR achieve? Quantify impact where possible.]

## Plan

- [x] [completed item]
- [x] [completed item]
- [ ] [remaining item]

## Changes

[Group by architectural layer/concern — see "Organizing Changes" below. Skip if the plan checklist is sufficient.]

**[Layer/concern]** — [one-line summary]:
- [specific change]
- [specific change]

### Design note

[Only if there's a non-obvious decision reviewers need. Otherwise omit this section.]

## Test plan

- [x] [category] ([count] tests)
- [x] Full suite: [count] tests, 0 failures
- [x] Manual verification: [brief description if done]

[Omit this section if no tests were added or run.]
```

### Organizing Changes

Group changes by the project's architectural layers or concerns. The right groupings are **project-specific** — determine them from:

1. **Project documentation** (preferred) — look for architecture docs, CLAUDE.md, or similar references that describe the project's layer structure
2. **Project structure** (fallback) — infer layers from the directory layout if no documentation exists

For example, a DDD project might use: Domain, Repositories, Services, Contracts, Policies, Presentation, Routes. A Rails app might use: Models, Controllers, Views, Jobs. A React app might use: Components, Hooks, State, API Client.

For full-stack projects, split changes into **Backend** and **Frontend** subsections when both are affected. Use whichever layers are relevant — skip layers with no changes.

### Principles

- **Orient the reviewer**: the PR description's job is to help someone review the diff. Keep it concise.
- **Plan is a living checklist**: the plan section reflects the branch plan document — check off items as they're completed, add new ones as discovered.
- **Changes, not plans**: the Changes section describes what was done, not what was considered.
- **Quantify where possible**: test counts, request counts, query counts.
- **No duplication**: each section has a distinct purpose. Don't repeat information across Summary, Plan, and Changes.

## Important

- Do NOT add a `Co-Authored-By` line or reference AI in the PR title or description.
- Do NOT push to `main` or `master` directly — always create the PR against the base branch.
- Return the PR URL when done so the user can review it.
