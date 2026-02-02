# Deploy OpenClaw from your fork and push to GitHub Container Registry (ghcr.io).
# Gateway runs from the registry image so Watchtower can auto-update.
# Usage: .\deploy-with-registry.ps1
# Loads deploy/.env (gitignored) if present; put GHCR_TOKEN there to avoid prompts.

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

# Your fork and registry (CreamyG31337/openclaw)
$env:OPENCLAW_REPO = "https://github.com/CreamyG31337/openclaw.git"
$env:OPENCLAW_REPO_BRANCH = "deploy"
$env:OPENCLAW_REGISTRY_IMAGE = "ghcr.io/creamyg31337/openclaw:deploy"
$env:OPENCLAW_REGISTRY_USER = "creamyg31337"

# Token for push (write:packages). Prompt if not set.
if (-not $env:GHCR_TOKEN) {
  $token = Read-Host "GitHub token (write:packages) for ghcr.io push" -AsSecureString
  $env:OPENCLAW_REGISTRY_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
} else {
  $env:OPENCLAW_REGISTRY_PASSWORD = $env:GHCR_TOKEN
}

if (-not $env:OPENCLAW_REGISTRY_PASSWORD) {
  Write-Error "No token set. Use GHCR_TOKEN or enter at prompt."
  exit 1
}

Write-Host "==> Deploying from fork (deploy branch) and pushing to $env:OPENCLAW_REGISTRY_IMAGE" -ForegroundColor Cyan
& (Join-Path $DeployDir "deploy.ps1")

Write-Host ""
Write-Host "Next (if first time):" -ForegroundColor Yellow
Write-Host "  1. Make package public: https://github.com/CreamyG31337?tab=packages -> openclaw -> Package settings -> Public" -ForegroundColor Gray
Write-Host "  2. On server, start Watchtower: see REGISTRY-AND-WATCHTOWER.md Step 4" -ForegroundColor Gray
Write-Host ""
