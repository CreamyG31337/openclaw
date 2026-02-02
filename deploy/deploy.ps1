# Deploy OpenClaw to ts-ubuntu-server via Docker (SSH + remote-setup.sh)
# Usage: .\deploy.ps1   or   pwsh -File deploy.ps1
# To use Z.AI (GLM): set $env:ZAI_API_KEY before running, or it uses the default below.

$ErrorActionPreference = "Stop"
$Server = "ts-ubuntu-server"
$KeyPath = "C:\Utils\id_rsa"

# Z.AI API key — used as default if $env:ZAI_API_KEY is not set. Override or clear for production.
if (-not $env:ZAI_API_KEY) {
  $env:ZAI_API_KEY = "9778eb4ca4da4bac8a6099cee15fbc02.ASXTVlCUr0IdZuCP"
}

# SSH user on the server (default: lance). Override with $env:OPENCLAW_DEPLOY_USER if needed.
$User = if ($env:OPENCLAW_DEPLOY_USER) { $env:OPENCLAW_DEPLOY_USER } else { "lance" }
$Target = "$User@$Server"

$DeployDir = $PSScriptRoot
$RemoteScript = Join-Path $DeployDir "remote-setup.sh"

if (-not (Test-Path $KeyPath)) {
  Write-Error "SSH key not found: $KeyPath"
  exit 1
}
if (-not (Test-Path $RemoteScript)) {
  Write-Error "remote-setup.sh not found: $RemoteScript"
  exit 1
}

Write-Host "==> Deploying OpenClaw to $Target (key: $KeyPath)" -ForegroundColor Cyan
if ($env:ZAI_API_KEY) { Write-Host "==> Z.AI API key will be configured (default model: zai/glm-4.7)" -ForegroundColor Cyan }
if ($env:OPENCLAW_REGISTRY_IMAGE) {
  if ($env:OPENCLAW_REGISTRY_USER) { Write-Host "==> Build, push to $($env:OPENCLAW_REGISTRY_IMAGE); gateway runs from registry" -ForegroundColor Cyan }
  else { Write-Host "==> Pull $($env:OPENCLAW_REGISTRY_IMAGE) (no build); gateway runs from registry; Watchtower can update" -ForegroundColor Cyan }
}
Write-Host "==> Uploading and running remote-setup.sh..." -ForegroundColor Cyan

# Pass env to remote so remote-setup.sh can use it
$RemoteEnv = ""
if ($env:ZAI_API_KEY) { $RemoteEnv += "export ZAI_API_KEY='$($env:ZAI_API_KEY)'; " }
# Public image for Watchtower (pull-only, no login): set OPENCLAW_USE_PUBLIC_IMAGE=1 or set OPENCLAW_REGISTRY_IMAGE yourself
if ($env:OPENCLAW_USE_PUBLIC_IMAGE -eq "1" -and -not $env:OPENCLAW_REGISTRY_IMAGE) {
  $env:OPENCLAW_REGISTRY_IMAGE = "docker.io/heimdall777/openclaw:latest"
}
if ($env:OPENCLAW_REGISTRY_IMAGE) { $RemoteEnv += "export OPENCLAW_REGISTRY_IMAGE='$($env:OPENCLAW_REGISTRY_IMAGE)'; " }
if ($env:OPENCLAW_REGISTRY_USER) { $RemoteEnv += "export OPENCLAW_REGISTRY_USER='$($env:OPENCLAW_REGISTRY_USER)'; " }
if ($env:OPENCLAW_REGISTRY_PASSWORD) { $RemoteEnv += "export OPENCLAW_REGISTRY_PASSWORD='$($env:OPENCLAW_REGISTRY_PASSWORD)'; " }
if ($env:OPENCLAW_REPO) { $RemoteEnv += "export OPENCLAW_REPO='$($env:OPENCLAW_REPO)'; " }
if ($env:OPENCLAW_REPO_BRANCH) { $RemoteEnv += "export OPENCLAW_REPO_BRANCH='$($env:OPENCLAW_REPO_BRANCH)'; " }
# Copy script to server and run (avoids stdin issues with PowerShell). Use LF only; strip any CR so bash never sees $'\r': command not found.
$ScriptContent = (Get-Content -Path $RemoteScript -Raw) -replace "`r`n", "`n" -replace "`r", ""
$ScriptContent | ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "${RemoteEnv}cat > /tmp/openclaw-remote-setup.sh && chmod +x /tmp/openclaw-remote-setup.sh && bash /tmp/openclaw-remote-setup.sh"

Write-Host ""
Write-Host "Done. Check output above for gateway token and next steps." -ForegroundColor Green
