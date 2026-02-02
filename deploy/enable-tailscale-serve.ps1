# Enable Tailscale Serve for OpenClaw Control UI on your server
# Usage: .\enable-tailscale-serve.ps1
# Requires: Tailscale installed and logged in on the server; OpenClaw gateway running (port 18789).
# Note: You may be prompted for your sudo password on the server.

$ErrorActionPreference = "Stop"
$Server = if ($env:OPENCLAW_SERVER) { $env:OPENCLAW_SERVER } else { "your-server" }
$KeyPath = if ($env:OPENCLAW_KEY_PATH) { $env:OPENCLAW_KEY_PATH } else { "" }
$User = if ($env:OPENCLAW_DEPLOY_USER) { $env:OPENCLAW_DEPLOY_USER } else { "deploy" }
if (-not $KeyPath -or $Server -eq "your-server") {
  Write-Error "Set OPENCLAW_SERVER and OPENCLAW_KEY_PATH in deploy\.env (copy from .env.example)."
  exit 1
}
$Target = "$User@$Server"

if (-not (Test-Path $KeyPath)) {
  Write-Error "SSH key not found: $KeyPath"
  exit 1
}

Write-Host "==> Enabling Tailscale Serve on $Target (Control UI -> https)" -ForegroundColor Cyan
Write-Host "    (Enter sudo password when prompted on the server)" -ForegroundColor Gray
Write-Host ""
$Cmd = "sudo tailscale serve https / http://127.0.0.1:18789"
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new -t $Target $Cmd
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "To run manually instead, SSH in and run:" -ForegroundColor Yellow
  Write-Host "  ssh -i $KeyPath $Target" -ForegroundColor Gray
  Write-Host "  sudo tailscale serve https / http://127.0.0.1:18789" -ForegroundColor Gray
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "==> Serve status:" -ForegroundColor Cyan
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new -t $Target "sudo tailscale serve status"
Write-Host ""
Write-Host "Open the Control UI from any device on your Tailnet:" -ForegroundColor Green
Write-Host "  https://$Server" -ForegroundColor White
Write-Host "  (or https://$Server.your-tailnet.ts.net if using MagicDNS)" -ForegroundColor Gray
Write-Host "Use your gateway token when prompted." -ForegroundColor Gray
