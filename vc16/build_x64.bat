@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -test >nul 2>&1
if errorlevel 1 (
    call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
)
cd /d "C:\Users\imfis\Desktop\Avatar-comprado-client"
MSBuild.exe vc16\otclient.vcxproj /p:Configuration=OpenGL /p:Platform=x64 /t:Build /v:minimal
echo Exit code: %errorlevel%
