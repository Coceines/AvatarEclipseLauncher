@echo off
setlocal
set MSBUILD="C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
if not exist %MSBUILD% (
  echo MSBuild not found.
  exit /b 1
)

echo Building otclient OpenGL...
%MSBUILD% "%~dp0otclient.sln" /t:Build /p:Configuration=OpenGL /p:Platform=Win32 /m /v:minimal /nologo
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)

echo.
echo OK: %~dp0..\otclient_gl.exe
dir "%~dp0..\otclient_gl.exe"
endlocal
