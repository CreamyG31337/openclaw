# Patching and Upstream Guide

Current working model:
- Local source repo: `openclaw-upstream-fresh/`
- Deploy target: fork branch from `deploy/.env` (`OPENCLAW_REPO`, `OPENCLAW_REPO_BRANCH`)
- Deploy entry point: `deploy/deploy.ps1`

## Hotfix workflow (recommended)

1. Work in `openclaw-upstream-fresh`:
```powershell
cd ..\openclaw-upstream-fresh
git fetch origin
git checkout main
git reset --hard origin/main
git checkout -b hotfix/<short-name>
```
2. Make changes and run tests.
3. Push to your fork:
```powershell
git push -u fork hotfix/<short-name>
```
4. Point `deploy/.env` at that branch:
```env
OPENCLAW_REPO=https://github.com/<you>/openclaw.git
OPENCLAW_REPO_BRANCH=hotfix/<short-name>
OPENCLAW_LOCAL_REPO_DIR=..\openclaw-upstream-fresh
```
5. Deploy:
```powershell
cd ..\deploy
.\deploy.ps1
```

## Sync + deploy wrapper

`run-sync-and-deploy.cmd` still works and runs `sync-clean-upstream-and-deploy.ps1`.  
Despite the script name, it uses `OPENCLAW_LOCAL_REPO_DIR`; set that to `..\openclaw-upstream-fresh`.

## Branch hygiene

Keep only:
- `main`
- active `hotfix/*` branch(es)

Delete old branches when done:
```powershell
git push fork --delete <old-branch>
```

After a hotfix is accepted as your new baseline, either:
- merge/cherry-pick it into your fork `main`, then delete the hotfix branch, or
- keep deploying from that hotfix branch and delete older hotfix branches.

## Conflict handling

If rebase stops with conflicts:
```powershell
cd ..\openclaw-upstream-fresh
git add -A
git rebase --continue
```

Abort if needed:
```powershell
git rebase --abort
```
