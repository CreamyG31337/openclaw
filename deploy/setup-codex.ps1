# Setup OpenAI Codex CLI on the OpenClaw gateway (skill + install + auth reminder).
# Run from deploy folder. Requires .env with OPENCLAW_SERVER, OPENCLAW_KEY_PATH, OPENCLAW_DEPLOY_USER.
# If you haven't deployed since Codex was added, run .\deploy.ps1 first so the server has the codex volume (~/.openclaw/cli-auth/codex).
# Usage: .\setup-codex.ps1

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
$SkillsDir = Join-Path $DeployDir "skills"
$CodexSkill = Join-Path $SkillsDir "openai-codex"
if (-not (Test-Path $CodexSkill)) {
  Write-Error "Skill not found: $CodexSkill"
  exit 1
}

Write-Host "==> Syncing openai-codex skill to $Target (remote ~/.openclaw/skills/)" -ForegroundColor Cyan
ssh -i $KeyPath -o StrictHostKeyChecking=accept-new $Target "mkdir -p ~/.openclaw/skills"
scp -i $KeyPath -r $CodexSkill "${Target}:~/.openclaw/skills/"

Write-Host "==> Installing @openai/codex in gateway container (as root)..." -ForegroundColor Cyan
ssh -i $KeyPath $Target "docker exec -u root openclaw-gateway sh -c 'npm i -g @openai/codex'"

Write-Host ""
Write-Host "Codex CLI is installed and skill is on the server." -ForegroundColor Green
Write-Host ""
Write-Host "Auth (no API key):" -ForegroundColor Yellow
Write-Host "  If device code works (personal account): ssh ... then docker exec -it openclaw-gateway sh, run: codex login --device-auth" -ForegroundColor Gray
Write-Host "  If you see 'contact your workspace admin to enable device code':" -ForegroundColor Gray
Write-Host "    1. On this PC (with a browser), run: codex login   (install Codex first: npm i -g @openai/codex)" -ForegroundColor Gray
Write-Host "    2. Then run: .\copy-codex-auth.ps1   (copies your PC's auth to the server so the gateway can use it)" -ForegroundColor Gray
Write-Host ""
Write-Host "Restart the gateway to load the skill: ssh ... 'docker restart openclaw-gateway'" -ForegroundColor Cyan
