@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop-proxy.ps1" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
if not "%EXITCODE%"=="0" (
  echo Stop failed. Check the messages above or stop nginx.exe manually in Task Manager.
) else (
  echo Proxy stop command completed.
)
pause
exit /b %EXITCODE%
