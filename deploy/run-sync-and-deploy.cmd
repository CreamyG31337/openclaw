@echo off
cd /d "%~dp0"
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-clean-upstream-and-deploy.ps1"
echo.
if errorlevel 1 (
  echo Sync/deploy failed. Fix the error above, then re-run this file.
) else (
  echo Sync/deploy completed successfully.
)
echo Press any key to close.
pause >nul
