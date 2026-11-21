@echo off
setlocal
set "WINLINK_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "WINLINK_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%WINLINK_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\Setup-Windows.ps1" -User "%USERNAME%" %*
if errorlevel 1 echo Setup failed. Review the error and local log shown above.
pause
