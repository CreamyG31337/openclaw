@echo off
cd /d "%~dp0"
:loop
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"
echo.
echo Press any key to redeploy, or close this window to exit.
pause >nul
goto loop
