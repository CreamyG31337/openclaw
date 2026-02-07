# Sync openclaw-clean deploy branch onto latest upstream, push to fork, then deploy.
# Usage:
#   .\sync-clean-upstream-and-deploy.ps1
#   .\sync-clean-upstream-and-deploy.ps1 -SkipDeploy
# Optional env vars in deploy/.env:
#   OPENCLAW_LOCAL_REPO_DIR=..\openclaw-clean
#   OPENCLAW_FORK_REMOTE_NAME=fork
#   OPENCLAW_UPSTREAM_REMOTE_NAME=origin
#   OPENCLAW_UPSTREAM_BRANCH=main
#   OPENCLAW_AUTO_COMMIT_DIRTY=1

[CmdletBinding()]
param(
  [switch]$SkipDeploy,
  [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
$DeployDir = $PSScriptRoot

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)][string]$RepoDir,
    [Parameter(Mandatory = $true)][string[]]$Args
  )
  & git -C $RepoDir @Args
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Args -join ' ') failed."
  }
}

# Load deploy/.env into process env.
$EnvFile = Join-Path $DeployDir ".env"
if (Test-Path $EnvFile) {
  Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and $line -notmatch '^\s*#') {
      $i = $line.IndexOf('=')
      if ($i -gt 0) {
        $k = $line.Substring(0, $i).Trim()
        $v = $line.Substring($i + 1).Trim().Trim('"').Trim("'")
        if ($k) { [Environment]::SetEnvironmentVariable($k, $v, 'Process') }
      }
    }
  }
}

$RepoDir = if ($env:OPENCLAW_LOCAL_REPO_DIR) { $env:OPENCLAW_LOCAL_REPO_DIR } else { "..\openclaw-clean" }
$RepoDir = [System.IO.Path]::GetFullPath((Join-Path $DeployDir $RepoDir))
$ForkRemoteName = if ($env:OPENCLAW_FORK_REMOTE_NAME) { $env:OPENCLAW_FORK_REMOTE_NAME } else { "fork" }
$UpstreamRemoteName = if ($env:OPENCLAW_UPSTREAM_REMOTE_NAME) { $env:OPENCLAW_UPSTREAM_REMOTE_NAME } else { "origin" }
$UpstreamBranch = if ($env:OPENCLAW_UPSTREAM_BRANCH) { $env:OPENCLAW_UPSTREAM_BRANCH } else { "main" }
$DeployBranch = if ($env:OPENCLAW_REPO_BRANCH) { $env:OPENCLAW_REPO_BRANCH } else { "deploy-clean" }
$ForkRepoUrl = $env:OPENCLAW_REPO
$AutoCommitDirty = ($env:OPENCLAW_AUTO_COMMIT_DIRTY -eq "1" -or [string]::IsNullOrWhiteSpace($env:OPENCLAW_AUTO_COMMIT_DIRTY))

if (-not (Test-Path $RepoDir)) {
  throw "Repo directory not found: $RepoDir"
}
if (-not (Test-Path (Join-Path $RepoDir ".git"))) {
  throw "Not a git repo: $RepoDir"
}
if (-not $SkipPush -and [string]::IsNullOrWhiteSpace($ForkRepoUrl)) {
  throw "OPENCLAW_REPO is required in deploy\.env to push your deploy branch."
}

Write-Host "==> Using local repo: $RepoDir" -ForegroundColor Cyan
Write-Host "==> Upstream: $UpstreamRemoteName/$UpstreamBranch  Deploy branch: $DeployBranch" -ForegroundColor Cyan

# Ensure fork remote points at OPENCLAW_REPO.
if (-not $SkipPush) {
  $ExistingForkUrl = ""
  try {
    $ExistingForkUrl = (git -C $RepoDir remote get-url $ForkRemoteName 2>$null).Trim()
  } catch {}
  if ([string]::IsNullOrWhiteSpace($ExistingForkUrl)) {
    Invoke-Git -RepoDir $RepoDir -Args @("remote", "add", $ForkRemoteName, $ForkRepoUrl)
  } elseif ($ExistingForkUrl -ne $ForkRepoUrl) {
    Invoke-Git -RepoDir $RepoDir -Args @("remote", "set-url", $ForkRemoteName, $ForkRepoUrl)
  }
}

$StatusLines = @(git -C $RepoDir status --porcelain)
$HasDirty = $StatusLines.Count -gt 0
$Stashed = $false
$AutoCommitNeeded = $false

if ($HasDirty) {
  if (-not $AutoCommitDirty) {
    throw "Working tree is dirty and OPENCLAW_AUTO_COMMIT_DIRTY is not enabled."
  }
  $StashName = "openclaw-auto-sync-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  Write-Host "==> Stashing local changes before switching branches..." -ForegroundColor Yellow
  Invoke-Git -RepoDir $RepoDir -Args @("stash", "push", "--include-untracked", "-m", $StashName)
  $Stashed = $true
}

Write-Host "==> Fetching latest refs..." -ForegroundColor Cyan
Invoke-Git -RepoDir $RepoDir -Args @("fetch", $UpstreamRemoteName, "--prune")
if (-not $SkipPush) {
  Invoke-Git -RepoDir $RepoDir -Args @("fetch", $ForkRemoteName, "--prune")
}

$HasDeployBranch = $false
& git -C $RepoDir show-ref --verify --quiet ("refs/heads/" + $DeployBranch)
if ($LASTEXITCODE -eq 0) { $HasDeployBranch = $true }

if ($HasDeployBranch) {
  Invoke-Git -RepoDir $RepoDir -Args @("checkout", $DeployBranch)
} else {
  Write-Host "==> Creating local branch $DeployBranch from $UpstreamRemoteName/$UpstreamBranch" -ForegroundColor Cyan
  Invoke-Git -RepoDir $RepoDir -Args @("checkout", "-b", $DeployBranch, "$UpstreamRemoteName/$UpstreamBranch")
}

if ($Stashed) {
  Write-Host "==> Restoring stashed local changes onto $DeployBranch..." -ForegroundColor Cyan
  & git -C $RepoDir stash pop
  if ($LASTEXITCODE -ne 0) {
    throw "git stash pop failed. Resolve conflicts in $RepoDir and re-run."
  }
  $AutoCommitNeeded = $true
}

if ($AutoCommitNeeded) {
  Write-Host "==> Auto-committing carried local changes..." -ForegroundColor Cyan
  Invoke-Git -RepoDir $RepoDir -Args @("add", "-A")
  $CommitMsg = "chore(deploy): capture local patches before upstream sync " + (Get-Date -Format "yyyy-MM-dd HH:mm")
  Invoke-Git -RepoDir $RepoDir -Args @("commit", "-m", $CommitMsg)
}

Write-Host "==> Rebasing $DeployBranch onto $UpstreamRemoteName/$UpstreamBranch..." -ForegroundColor Cyan
& git -C $RepoDir rebase "$UpstreamRemoteName/$UpstreamBranch"
if ($LASTEXITCODE -ne 0) {
  throw "Rebase failed. Resolve conflicts in $RepoDir, then run: git rebase --continue"
}

if (-not $SkipPush) {
  Write-Host "==> Pushing $DeployBranch to $ForkRemoteName/$DeployBranch..." -ForegroundColor Cyan
  Invoke-Git -RepoDir $RepoDir -Args @("push", "--force-with-lease", $ForkRemoteName, "${DeployBranch}:$DeployBranch")
}

if ($SkipDeploy) {
  Write-Host ""
  Write-Host "Sync complete. Deployment skipped (-SkipDeploy)." -ForegroundColor Green
  exit 0
}

Write-Host ""
Write-Host "==> Running deploy.ps1..." -ForegroundColor Cyan
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $DeployDir "deploy.ps1")
if ($LASTEXITCODE -ne 0) {
  throw "deploy.ps1 failed."
}

Write-Host ""
Write-Host "Done. Upstream sync + push + deploy completed." -ForegroundColor Green
