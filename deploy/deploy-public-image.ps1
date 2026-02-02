# Deploy using public image so Watchtower/Portainer can update (no build, no login)
$env:OPENCLAW_USE_PUBLIC_IMAGE = "1"
& (Join-Path $PSScriptRoot "deploy.ps1")
