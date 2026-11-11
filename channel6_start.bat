@echo off
setlocal enabledelayedexpansion
title PulseCast Channel 6 - Direct HTTP Radio Streamer

echo ======================================================================
echo          P U L S E C A S T   C H A N N E L   6   S E R V E R
echo          Icecast-Free Direct HTTP Audio Streaming Engine
echo ======================================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "SERVER_SCRIPT=%SCRIPT_DIR%radio\channel6-streamer\server.js"
set "PORT=8000"

:: Check if Node.js is installed
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js is required but was not found in PATH!
    pause
    exit /b 1
)

:: Free Port 8000 from Docker Icecast or previous instances
echo [1/3] Checking port %PORT% availability...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%PORT% ^| findstr LISTENING') do (
    echo [INFO] Found process PID %%a listening on port %PORT%.
    echo Stopping old process to bind Channel 6 streaming server...
    taskkill /F /PID %%a >nul 2>&1
)

:: If Docker container is holding port 8000, stop it cleanly
docker ps -q -f name=pulsecast-icecast >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Stopping legacy Docker Icecast and Liquidsoap containers...
    docker stop pulsecast-icecast pulsecast-liquidsoap >nul 2>&1
)

echo [2/3] Setting up audio environment...
if not defined MUSIC_DIR (
    if exist "C:\pulsecast-radio\music" (
        set "MUSIC_DIR=C:\pulsecast-radio\music"
    )
)
echo Music Library: %MUSIC_DIR%

echo [3/3] Starting PulseCast Channel 6 Node.js Streaming Server...
echo.
echo Local Stream:      http://localhost:%PORT%/pulsecast.mp3
echo Stream Health:     http://localhost:%PORT%/health
echo Now-Playing API:   http://localhost:%PORT%/api/now-playing
echo.
echo Press Ctrl+C to stop the stream.
echo ======================================================================
echo.

node "%SERVER_SCRIPT%"
pause

