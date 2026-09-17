@echo off
cd /d "C:\Users\imfis\Desktop\Avatar-comprado-client"
echo Current dir: %CD%
echo Checking DLLs:
dir /b *.dll
echo.
echo Running exe (3 second timeout)...
timeout /t 3 /nobreak >nul
echo Done waiting.
