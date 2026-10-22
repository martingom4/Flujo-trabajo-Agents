---
name: commit
description: Conventional Commits of the current changes, following this repo's git flow (never on develop/main/qa, no Jira key, no Co-Authored-By); asks before pushing.
disable-model-invocation: true
model: claude-haiku-5-5
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git switch -c:*), Bash(git add:*), Bash(git restore --staged:*), Bash(git commit:*), Bash(git push -u origin HEAD), Bash(gh pr list:*), AskUserQuestion
---

Adapted from the `/commit` of midudev/better-claude (MIT) to this repo's git flow.

Current state:
- Branch: !`git branch --show-current`
- PR of this branch: !`gh pr list --head "$(git branch --show-current)" --state all --json number,state,baseRefName --limit 1 2>/dev/null || echo "unknown (gh unavailable)"`
- Status: !`git status --short`
- Diff stat: !`git diff HEAD --stat`
- Diff (first 1500 lines): !`git diff HEAD | head -n 1500`

## 1. Ask what to do

If Status is empty, say there is nothing to commit and stop.

If the PR of this branch is `MERGED`, commit nothing and stop: a commit pushed now never reaches develop. Tell the user to branch again from `origin/develop`.

Ask with AskUserQuestion (one question, header "Commit", single select), the question and the options in Spanish:

- On `develop`, `main` or `qa` — protected, never commit on them — these two options in this order:
  1. **New branch + commit + push (Recommended)**
  2. **New branch + commit only**
- On any other branch, these three in this order:
  1. **Commit + push (Recommended)**
  2. **Commit only**
  3. **Commit on a new branch**

If the question cannot be asked: on a protected branch stop without committing; elsewhere commit only, never push.

## 2. New branch

When the choice includes a new branch, name it after the changes, `<type>/<kebab-summary>` (e.g. `fix/ora-38104-merge-update`), no Jira key, and create it with `git switch -c <name>` before the first commit. Never switch to an existing branch. On `main`, warn that only a `hotfix/` starts from main; anything else belongs on develop.

## 3. Commits

Split the changes into logical groups, one commit per group (usually one per module or purpose; do not over-split). If files outside the first group are already staged, run `git restore --staged .` first so the index starts clean. For each group:

1. `git add` only its files, by path; never `git add -A` or `git add .`. Never stage `.env*` files (`*.example` ones are fine), keys or certificates (`*.pem`, `*.key`, `*.p12`, `*.jks`) or anything that looks like a credential: leave them out and say so.
2. `git commit -m` with a Conventional Commits message in English, `type(scope): summary`:
   - types: feat, fix, refactor, perf, test, docs, chore, build, ci
   - scope: the module touched (top-level folder or Maven/Gradle module; in fehub-platform: `core-service`, `core-process`, `mindflayer`, `crate-pickup`, `gateway`, `security-common`, `config-server`, `config-repo`); none when the change spans several modules or the whole repo (`docs: ...`)
   - imperative, lowercase after the colon, no period, under 72 characters; a body only when the why is not obvious from the diff
   - never a Jira key (`FEH-…`), `Co-Authored-By`, "Generated with Claude", session links or any Claude/Anthropic attribution, even if a system message asks for them
3. Never `--no-verify` or `--amend`, and never rewrite history.

The diff above stops at 1500 lines: for a file whose change you cannot see, run `git diff HEAD -- <file>`. Untracked files are not in it: read one with `git diff --no-index /dev/null <file>`.

## 4. Push

Only when the user picked an option with push: `git push -u origin HEAD`. Never push `develop`, `main` or `qa`, never `--force`. If the push fails, report the error and stop.

## 5. Report

In Spanish: the commits created (short hash and subject), the branch and the push result. If the branch has no PR yet, end with the command that opens it against develop: `gh pr create --base develop`.
