@echo off
rem Double-click launcher: runs run-with-speech.ps1 with the execution policy
rem bypassed for this single call, then keeps the window open if it failed.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-with-speech.ps1" %*
if errorlevel 1 pause
