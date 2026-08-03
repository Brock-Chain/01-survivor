@echo off
REM BESTAGON - web build launcher.
REM
REM ASCII ONLY and no fancy quoting: a .bat is read as the system ANSI codepage,
REM so a stray non-ASCII character can break the whole script on another machine.
REM
REM Why this file exists: a browser refuses to fetch() the game's .wasm and .pck
REM when the page is opened straight off the disk (a file:// URL), because a file
REM origin is opaque and cross-origin. The Godot loader then shows the splash and
REM the message "Failed to fetch". Nothing is broken; the page just has to come
REM from a server. This starts one.

setlocal
cd /d "%~dp0"

if not exist "index.html" (
  echo.
  echo   Could not find index.html next to this file.
  echo   Keep START-HERE.bat in the same folder as index.html.
  echo.
  pause
  exit /b 1
)

set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" ( where python >nul 2>&1 && set PY=python )

if "%PY%"=="" (
  echo.
  echo   Python was not found on this machine, so this launcher cannot start
  echo   a local server.
  echo.
  echo   Two options:
  echo     1. Ask for the Windows build instead - it is a single .exe and
  echo        needs none of this.
  echo     2. Install Python from https://python.org and run this again.
  echo.
  echo   Do NOT double-click index.html. It will show "Failed to fetch".
  echo.
  pause
  exit /b 1
)

echo.
echo   Serving BESTAGON at http://localhost:8099
echo   Leave this window OPEN while you play. Close it when you are done.
echo.

start "" "http://localhost:8099"
%PY% -m http.server 8099
