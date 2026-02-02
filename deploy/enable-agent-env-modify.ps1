# Enable OpenClaw agent to modify its own environment (config, skills, exec on gateway).
# Usage: .\enable-agent-env-modify.ps1
# Runs enable-agent-env-modify.py on the server and restarts the gateway.

$ErrorActionPreference = "Stop"
$Server = "ts-ubuntu-server"
$KeyPath = "C:\Utils\id_rsa"
$User = if ($env:OPENCLAW_DEPLOY_USER) { $env:OPENCLAW_DEPLOY_USER } else { "lance" }
$Target = "$User@$Server"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PyScript = Join-Path $ScriptDir "enable-agent-env-modify.py"

if (-not (Test-Path $KeyPath)) {
  Write-Error "SSH key not found: $KeyPath"
  exit 1
}
if (-not (Test-Path $PyScript)) {
  Write-Error "Script not found: $PyScript"
  exit 1
}

Write-Host "==> Enabling agent env modify on $Target (sandbox=off, exec.host=gateway)" -ForegroundColor Cyan
scp -i $KeyPath -o StrictHostKeyChecking=accept-new $PyScript "${Target}:~/enable-agent-env-modify.py"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Cmd = "python3 ~/enable-agent-env-modify.py && cd ~/openclaw && docker compose restart openclaw-gateway"
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target $Cmd
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "To run manually instead, SSH in and run:" -ForegroundColor Yellow
  Write-Host "  ssh -i $KeyPath $Target" -ForegroundColor Gray
  Write-Host "  python3 ~/enable-agent-env-modify.py" -ForegroundColor Gray
  Write-Host "  cd ~/openclaw && docker compose restart openclaw-gateway" -ForegroundColor Gray
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Done. Agent can now run exec on the gateway and modify its environment (e.g. config, skills)." -ForegroundColor Green
