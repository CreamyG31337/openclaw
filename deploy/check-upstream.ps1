# Check if your OpenClaw fork (deploy branch) is current with upstream openclaw/openclaw.
# Option A: Run on the server (where ~/openclaw is your fork clone).
# Option B: Run locally if you have openclaw-src with upstream and fork remotes.
# Usage: .\check-upstream.ps1

$ErrorActionPreference = "Stop"
$DeployDir = $PSScriptRoot
if (Test-Path (Join-Path $DeployDir ".env")) {
  Get-Content (Join-Path $DeployDir ".env") | ForEach-Object {
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
$Server = $env:OPENCLAW_SERVER
$KeyPath = $env:OPENCLAW_KEY_PATH
$User = $env:OPENCLAW_DEPLOY_USER
if (-not $Server -or -not $KeyPath) {
  Write-Host "Set OPENCLAW_SERVER and OPENCLAW_KEY_PATH in deploy\.env to check on the server." -ForegroundColor Yellow
  Write-Host "Or run from a machine that has openclaw-src (your fork clone) with upstream added." -ForegroundColor Yellow
  exit 1
}
if (-not $User) { $User = "deploy" }
$Target = "${User}@${Server}"

Write-Host "==> Checking upstream vs your fork on server (~/openclaw)..." -ForegroundColor Cyan
$Script = @'
set -e
cd ~/openclaw
git remote add upstream https://github.com/openclaw/openclaw.git 2>/dev/null || true
git fetch upstream 2>/dev/null || { echo "Fetch upstream failed (network?)"; exit 1; }
UPSTREAM_BRANCH="main"
if ! git rev-parse upstream/main &>/dev/null; then UPSTREAM_BRANCH="master"; fi
echo ""
echo "=== Commits in upstream/$UPSTREAM_BRANCH NOT in your current branch (you are behind) ==="
BEHIND=$(git rev-list HEAD..upstream/$UPSTREAM_BRANCH 2>/dev/null | wc -l)
if [ "$BEHIND" -eq 0 ]; then
  echo "None. Your base is current with upstream."
else
  git log HEAD..upstream/$UPSTREAM_BRANCH --oneline
  echo ""
  echo "Total: $BEHIND commit(s) behind."
fi
echo ""
echo "=== Merge-base (common ancestor of your branch and upstream) ==="
git merge-base HEAD upstream/$UPSTREAM_BRANCH 2>/dev/null || echo "Could not compute."
echo ""
echo "=== Your current branch and latest commit ==="
git rev-parse --abbrev-ref HEAD
git log -1 --oneline
'@
$ScriptClean = $Script -replace "`r`n", "`n" -replace "`r", ""
$ScriptClean | ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "bash -s"
