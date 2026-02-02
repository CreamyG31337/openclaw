# Copy your local Codex auth (from this PC) to the server so the gateway can use your ChatGPT login.
# Use this when device code is disabled ("contact your workspace admin to enable device code").
# 1. On this PC: npm i -g @openai/codex   then   codex login   (complete login in the browser).
# 2. Run this script: .\copy-codex-auth.ps1
# Requires .env with OPENCLAW_SERVER, OPENCLAW_KEY_PATH, OPENCLAW_DEPLOY_USER.

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

# Codex on Windows stores auth in %USERPROFILE%\.codex\auth.json
$LocalAuth = Join-Path $env:USERPROFILE ".codex\auth.json"
if (-not (Test-Path $LocalAuth)) {
  Write-Error "No Codex auth found at $LocalAuth. On this PC run: npm i -g @openai/codex  then  codex login  (complete login in the browser), then run this script again."
  exit 1
}

Write-Host "==> Copying Codex auth from this PC to $Target (~/.openclaw/cli-auth/codex/)" -ForegroundColor Cyan
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "mkdir -p ~/.openclaw/cli-auth/codex"
scp -i $KeyPath $LocalAuth "${Target}:~/.openclaw/cli-auth/codex/auth.json"

Write-Host "Done. The gateway container uses ~/.openclaw/cli-auth/codex as ~/.codex; auth is in place. Restart the gateway if it was already running: ssh ... 'docker restart openclaw-gateway'" -ForegroundColor Green
