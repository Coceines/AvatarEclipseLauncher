@echo off
set MSBUILD="C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
%MSBUILD% "C:\Users\imfis\Desktop\Avatar-Compraado-server\sources\build\theforgottenserver.sln" /t:Build /p:Configuration=Release /p:Platform=Win32 /m /v:minimal /nologo
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)
echo BUILD SUCCESS
