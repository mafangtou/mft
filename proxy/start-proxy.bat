@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-proxy.ps1" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
if not "%EXITCODE%"=="0" (
  echo Start failed. Check proxy\logs\nginx-error.log and the messages above.
) else (
  echo Proxy start/reload completed. The browser should now be open.
)
pause
exit /b %EXITCODE%
