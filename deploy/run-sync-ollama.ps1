# Sync Ollama models (ollama list) into OpenClaw openclaw.json on the server.
# Use this after you pull new Ollama models (e.g. dolphin-mixtral:8x7b) so the bot can use them.
# Run from deploy folder. Requires .env with OPENCLAW_SERVER, OPENCLAW_KEY_PATH, OPENCLAW_DEPLOY_USER.
# Usage: .\run-sync-ollama.ps1

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

Write-Host "==> Syncing Ollama models into OpenClaw config on $Target..." -ForegroundColor Cyan
$ScriptPath = Join-Path $DeployDir "sync-ollama-models.py"
$ScriptContent = (Get-Content -Path $ScriptPath -Raw) -replace "`r`n", "`n" -replace "`r", ""
$ConfigDir = "/home/$User/.openclaw"
$ScriptContent | ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "cat > /tmp/sync-ollama-models.py && OPENCLAW_CONFIG_DIR=$ConfigDir python3 /tmp/sync-ollama-models.py"

Write-Host "==> Restarting gateway..." -ForegroundColor Cyan
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "docker restart openclaw-gateway"

Write-Host "Done. Use ollama/dolphin-mixtral:8x7b (lowercase) in the UI." -ForegroundColor Green
