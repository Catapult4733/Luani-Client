@echo off
:: Windows Protocol Registration script for luani:// custom scheme handler
title Luani Protocol Setup

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%..\..\.."
set "CLIENT_EXE=%ROOT_DIR%\client_and_studio\bin\luani.exe"

if not exist "%CLIENT_EXE%" (
    set "CLIENT_EXE=%SCRIPT_DIR%luani.exe"
)

echo Registering custom protocol handler luani:// ...
echo Target executable: "%CLIENT_EXE%"

reg add "HKCR\luani" /ve /d "URL:Luani Protocol" /f
reg add "HKCR\luani" /v "URL Protocol" /d "" /f
reg add "HKCR\luani\shell\open\command" /ve /d "\"%CLIENT_EXE%\" \"%%1\"" /f

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Successfully registered luani:// protocol in Windows Registry!
) else (
    echo [ERROR] Failed to update registry. Please re-run this batch script as Administrator.
)

pause
