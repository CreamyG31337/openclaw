@echo off
cd /d "%~dp0"
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"
echo.
if errorlevel 1 (
  echo Deploy failed. Fix the error above, then re-run this file.
) else (
  echo Deploy completed successfully.
)
echo Press any key to close.
pause >nul
