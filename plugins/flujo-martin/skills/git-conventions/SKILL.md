---
name: git-conventions
description: 'Git conventions: commit message format, branching strategy (main/develop/qa), PR rules, and branch protection for this project.'
---

# Git Conventions

Standards for version control workflow in this multi-module Spring Boot project.

## When to Activate

- Writing commit messages
- Creating or merging branches
- Opening pull requests
- Reviewing branch strategy decisions
- Resolving merge conflicts

## Branching Strategy

```
main ─────────────────────────────────── (production releases)
  │
  └── qa ─────────────────────────────── (QA/staging validation)
        │
        └── develop ──────────────────── (integration branch)
              │
              ├── feat/target-management
              ├── fix/oracle-merge-error
              └── refactor/sell-history
```

### Branch Types

| Prefix | Purpose | Base Branch | Merges Into |
| -------- | --------- | ------------- | ------------- |
| `feat/` | New feature | `develop` | `develop` |
| `fix/` | Bug fix | `develop` | `develop` |
| `refactor/` | Code refactoring | `develop` | `develop` |
| `hotfix/` | Urgent production fix | `main` | `main` + `develop` |
| `chore/` | Build, CI, config changes | `develop` | `develop` |

### Branch Naming
```
feat/short-description
fix/issue-number-description
refactor/module-name-what

Examples:
feat/target-management
fix/ora-38104-merge-update
refactor/sell-history-route-code
chore/update-ci-pipeline
```

## Commit Messages

### Format
```
<type>: <short description>

<optional body — what and why, not how>
```

### Types
| Type | When |
| ------ | ------ |
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `chore` | Build, CI, dependencies, config |
| `docs` | Documentation only |
| `test` | Adding or fixing tests |
| `perf` | Performance improvement |

### Examples
```
feat: add routeCode support in target management

refactor: introduce SellFeduroEntity and separate from domain model

fix: prevent ORA-38104 in product merge by excluding ON columns from UPDATE

chore: update Spring Boot to 4.0.5

test: add unit tests for ProductService approval flow
```

### Rules
- Subject line under 72 characters
- Use imperative mood ("add" not "added", "fix" not "fixing")
- No period at the end of subject line
- Body explains **why**, not **what** (the diff shows what)

## Pull Requests

### PR Title
- Same format as commit subject: `<type>: <description>`
- Under 70 characters

### PR Description
```markdown
## Summary
- Brief description of changes

## Changes
- List of specific changes made

## Test Plan
- How the changes were verified

## Related
- Links to issues, tickets, or related PRs
```

### PR Rules
- Target branch: PRs go to `develop` (features/fixes) or `main` (hotfixes)
- Must pass CI (build + tests) before merge
- Keep PRs focused — one feature/fix per PR
- Prefer bundled PRs for related refactors over many tiny PRs

## Merge Strategy

- **develop → qa**: Merge commit (preserve history)
- **qa → main**: Merge commit (preserve history)
- **feature → develop**: Squash merge (clean history) for small features, merge commit for larger ones

## CI Integration

GitHub Actions runs on:
- PRs to `main`, `develop`, `qa`
- Pushes to `main`, `qa`

Pipeline: build → test → (deploy pipeline commented out)

**Remember**: Commit messages are documentation. Write them for the developer who will read `git log` six months from now trying to understand why a change was made.
