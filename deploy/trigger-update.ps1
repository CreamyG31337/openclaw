# Pull latest gateway image on the server and restart (no waiting for Watchtower).
# Run from deploy folder. Requires .env with OPENCLAW_SERVER, OPENCLAW_KEY_PATH, OPENCLAW_DEPLOY_USER.
# The server must have pull-and-restart.sh (written by remote-setup.sh on deploy).
# Usage: .\trigger-update.ps1

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
  Write-Error "Set OPENCLAW_SERVER and OPENCLAW_KEY_PATH in deploy\.env (copy from .env.example)."
  exit 1
}
if (-not $User) { $User = "deploy" }
$Target = "${User}@${Server}"

Write-Host "==> Triggering immediate pull + restart on $Target (no Watchtower wait)..." -ForegroundColor Cyan
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "bash ~/openclaw/pull-and-restart.sh"

Write-Host "Done. Gateway is running the latest image." -ForegroundColor Green
