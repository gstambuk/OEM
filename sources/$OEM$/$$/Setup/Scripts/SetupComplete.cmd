@echo off
Title GShield && Color 0b

:: Step 1: Elevate
>nul 2>&1 fsutil dirty query %systemdrive% || echo CreateObject^("Shell.Application"^).ShellExecute "%~0", "ELEVATED", "", "runas", 1 > "%temp%\uac.vbs" && "%temp%\uac.vbs" && exit /b
DEL /F /Q "%temp%\uac.vbs"

:: Step 2: Move to the script directory
cd /d %~dp0

:: Step 3: Working folder
cd Bin

:: Step 4: Initialize environment 
setlocal EnableExtensions EnableDelayedExpansion

:: Step 5: Execute PowerShell (.ps1) files alphabetically
for /f "tokens=*" %%B in ('dir /b /o:n *.ps1') do (
    powershell -ExecutionPolicy Bypass -File "%%B"
)

:: Step 6: Resident Protection
mkdir %windir%\Setup\Scripts
Regasm "GSecurity.dll" /codebase

:: Step 7: Takeown of group policy client service
SetACL.exe -on "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\gpsvc" -ot reg -actn setowner -ownr n:Administrators
SetACL.exe -on "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\gpsvc" -ot reg -actn ace -ace "n:Administrators;p:full"
sc stop gpsvc