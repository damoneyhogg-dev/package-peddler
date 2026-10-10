@echo off
setlocal
set "GODOT=%~dp0..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Package Peddler could not find the verified Godot 4.7.2 installation.
  pause
  exit /b 1
)
start "Package Peddler" "%GODOT%" --path "%~dp0"
endlocal
