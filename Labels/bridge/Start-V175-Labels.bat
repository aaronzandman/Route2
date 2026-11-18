@echo off
title V175 label bridge
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0v175_bridge.ps1"
echo.
echo The bridge stopped. Read any message above, then press a key to close.
pause >nul
