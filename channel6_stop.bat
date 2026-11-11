@echo off
title Stop PulseCast Channel 6

echo ======================================================================
echo           STOPPING PULSECAST CHANNEL 6 STREAMING SERVER
echo ======================================================================
echo.

set "PORT=8000"

:: Kill any process listening on port 8000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%PORT% ^| findstr LISTENING') do (
    echo [INFO] Stopping Channel 6 Streaming Server (PID: %%a)...
    taskkill /F /PID %%a >nul 2>&1
)

:: Also check port 8006 if test was running
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8006 ^| findstr LISTENING') do (
    echo [INFO] Stopping test instance (PID: %%a)...
    taskkill /F /PID %%a >nul 2>&1
)

echo.
echo PulseCast Channel 6 Streaming Server stopped successfully.
pause

