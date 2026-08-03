@echo off
REM BESTAGON - run this AFTER the game crashes or freezes, then send the zip
REM it puts on your Desktop.
REM
REM A thin launcher on purpose: the work is in collect-logs.ps1, and -NoProfile
REM plus -ExecutionPolicy Bypass mean it runs on a machine that has never been
REM set up to run scripts, which is every machine this is sent to.
setlocal
echo.
echo   BESTAGON - collecting logs...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect-logs.ps1"
if errorlevel 1 (
  echo.
  echo   Something went wrong collecting the logs. The logs themselves are here:
  echo     %APPDATA%\Godot\app_userdata\BESTAGON\logs
  echo   Zip that folder by hand and send it.
)
echo.
pause
