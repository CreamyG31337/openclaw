# Patching and Upstream Guide

This file describes the update model we use now:
- `openclaw-clean/` is the working source repo (close to upstream)
- `deploy/.env` controls which fork+branch is deployed
- `deploy/run-sync-and-deploy.cmd` is the normal update entry point

## Standard update (no manual git)

From `deploy/`, run:

```bat
run-sync-and-deploy.cmd
```

That calls `sync-clean-upstream-and-deploy.ps1` and performs:
1. fetch latest upstream (`origin/main`) in `openclaw-clean`
2. checkout/rebase local deploy branch (`OPENCLAW_REPO_BRANCH`) onto upstream
3. push that branch to your fork (`OPENCLAW_REPO`)
4. run `deploy.ps1` to rebuild/restart gateway on server

## Required `deploy/.env` values

```env
OPENCLAW_REPO=https://github.com/<you>/openclaw.git
OPENCLAW_REPO_BRANCH=deploy-clean
```

Recommended optional values:

```env
OPENCLAW_LOCAL_REPO_DIR=..\openclaw-clean
OPENCLAW_UPSTREAM_REMOTE_NAME=origin
OPENCLAW_UPSTREAM_BRANCH=main
OPENCLAW_FORK_REMOTE_NAME=fork
OPENCLAW_AUTO_COMMIT_DIRTY=1
```

`OPENCLAW_AUTO_COMMIT_DIRTY=1` means local uncommitted/untracked changes are moved onto the deploy branch and auto-committed before rebase.

## Conflict handling

When upstream touches the same files as our patches, rebase can pause with conflicts.

1. Open `openclaw-clean`, resolve conflicts in the listed files.
2. Continue rebase:

```powershell
cd openclaw-clean
git add -A
git rebase --continue
```

3. After rebase succeeds, run `deploy/run-sync-and-deploy.cmd` again.

## Recovery

If you want to cancel the partial rebase:

```powershell
cd openclaw-clean
git rebase --abort
```

Then re-run `run-sync-and-deploy.cmd`.

## Notes

- Keep customizations in as few files as possible to reduce conflict frequency.
- If you intentionally changed `OPENCLAW_REPO_BRANCH`, the sync script will target that branch.
- `run-deploy.cmd` still exists for deploy-only runs (no upstream sync).
