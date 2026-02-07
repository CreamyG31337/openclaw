# Deploy OpenClaw to your server via Docker (SSH + remote-setup.sh)
# Usage: .\deploy.ps1   or   pwsh -File deploy.ps1
# Sensitive config: copy .env.example to .env (gitignored) and fill in; scripts load it automatically.

$ErrorActionPreference = "Stop"
$DeployDir = $PSScriptRoot
# Load .env if present (KEY=value or KEY="value"; comments and empty lines skipped)
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
$Server = if ($env:OPENCLAW_SERVER) { $env:OPENCLAW_SERVER } else { "your-server" }
$KeyPath = if ($env:OPENCLAW_KEY_PATH) { $env:OPENCLAW_KEY_PATH } else { "" }

# SSH user on the server (default: deploy). Override with $env:OPENCLAW_DEPLOY_USER if needed.
$User = if ($env:OPENCLAW_DEPLOY_USER) { $env:OPENCLAW_DEPLOY_USER } else { "deploy" }
$Target = "$User@$Server"

$RemoteScript = Join-Path $DeployDir "remote-setup.sh"

if (-not $KeyPath -or $Server -eq "your-server") {
  Write-Error "Set OPENCLAW_SERVER and OPENCLAW_KEY_PATH in deploy\.env (copy from .env.example)."
  exit 1
}
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
if ($env:OPENAI_API_KEY) { Write-Host "==> OpenAI API key will be configured (Codex CLI headless)" -ForegroundColor Cyan }
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
if ($env:OPENCLAW_GATEWAY_TOKEN) { $RemoteEnv += "export OPENCLAW_GATEWAY_TOKEN='$($env:OPENCLAW_GATEWAY_TOKEN)'; " }
if ($env:OPENAI_API_KEY) { $RemoteEnv += "export OPENAI_API_KEY='$($env:OPENAI_API_KEY)'; " }
if ($env:OPENROUTER_API_KEY) { $RemoteEnv += "export OPENROUTER_API_KEY='$($env:OPENROUTER_API_KEY)'; " }
# Copy script to server and run. Use a temp file + SCP so the remote file is LF-only (piping from PowerShell can re-introduce CRLF and cause $'\r': command not found).
$ScriptContent = (Get-Content -Path $RemoteScript -Raw) -replace "`r`n", "`n" -replace "`r", ""
$TempScript = [System.IO.Path]::GetTempFileName()
try {
  [System.IO.File]::WriteAllText($TempScript, $ScriptContent, [System.Text.UTF8Encoding]::new($false))
  scp -i $KeyPath -o StrictHostKeyChecking=accept-new $TempScript "${Target}:/tmp/openclaw-remote-setup.sh"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload remote-setup.sh to $Target (scp exit code: $LASTEXITCODE)."
  }
  ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "${RemoteEnv}chmod +x /tmp/openclaw-remote-setup.sh && bash /tmp/openclaw-remote-setup.sh"
  if ($LASTEXITCODE -ne 0) {
    throw "Remote setup failed on $Target (ssh exit code: $LASTEXITCODE)."
  }
} finally {
  Remove-Item -LiteralPath $TempScript -Force -ErrorAction SilentlyContinue
}

Write-Host ""
try {
  $CurrentToken = ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "grep '^OPENCLAW_GATEWAY_TOKEN=' ~/openclaw/.env | cut -d= -f2-"
  if ($CurrentToken) {
    $Token = $CurrentToken.Trim()
    $GatewayPort = if ($env:OPENCLAW_GATEWAY_PORT) { $env:OPENCLAW_GATEWAY_PORT } else { "18789" }
    Write-Host "Gateway token: $Token" -ForegroundColor Green
    Write-Host "Tokenized dashboard URL (direct): http://$Server`:$GatewayPort/?token=$Token" -ForegroundColor Green
    if ($env:OPENCLAW_TAILSCALE_HOST) {
      Write-Host "Tokenized dashboard URL (Tailscale): https://$($env:OPENCLAW_TAILSCALE_HOST)/?token=$Token" -ForegroundColor Green
    }
    Write-Host "If using SSH tunnel: http://127.0.0.1:$GatewayPort/?token=$Token" -ForegroundColor Green
  }
} catch {
  Write-Host "Could not fetch token with post-check; use token from remote output above." -ForegroundColor Yellow
}
Write-Host "Done." -ForegroundColor Green
