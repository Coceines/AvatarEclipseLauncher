@echo off
echo ============================================
echo  Ultralight SDK Downloader for OTClient V8
echo ============================================
echo.

:: Check if already installed
if exist "%~dp0ultralight-sdk\include\Ultralight" (
    echo [INFO] Ultralight SDK already exists at %~dp0ultralight-sdk
    echo [INFO] To reinstall, delete the ultralight-sdk folder first.
    goto :done
)

echo [1/3] Downloading Ultralight SDK...
echo        URL: https://ultralight-sdk.sfo2.cdn.digitaloceanspaces.com/ultralight-sdk/latest/ultralight-sdk.zip
echo.

:: Try PowerShell download
powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://ultralight-sdk.sfo2.cdn.digitaloceanspaces.com/ultralight-sdk/latest/ultralight-sdk.zip' -OutFile '%~dp0ultralight-sdk.zip' -UseBasicParsing } catch { Write-Host 'PowerShell download failed, trying curl...'; exit 1 }"

if %errorlevel% neq 0 (
    echo [INFO] Trying curl...
    curl -L -o "%~dp0ultralight-sdk.zip" "https://ultralight-sdk.sfo2.cdn.digitaloceanspaces.com/ultralight-sdk/latest/ultralight-sdk.zip"
)

if not exist "%~dp0ultralight-sdk.zip" (
    echo [ERROR] Failed to download Ultralight SDK!
    echo.
    echo Please download manually from:
    echo   https://ultralig.ht/  (click "Download SDK")
    echo.
    echo Then extract the SDK to: %~dp0ultralight-sdk
    echo Make sure the following structure exists:
    echo   ultralight-sdk\include\Ultralight\*
    echo   ultralight-sdk\lib\x86\*.lib
    echo.
    goto :done
)

echo [2/3] Extracting SDK...
powershell -Command "Expand-Archive -Path '%~dp0ultralight-sdk.zip' -DestinationPath '%~dp0ultralight-sdk' -Force"

if %errorlevel% neq 0 (
    echo [ERROR] Failed to extract SDK!
    goto :cleanup
)

echo [3/3] Cleaning up...
del "%~dp0ultralight-sdk.zip" 2>nul

echo.
echo ============================================
echo  Ultralight SDK installed successfully!
echo ============================================
echo.
echo SDK location: %~dp0ultralight-sdk
echo.

:done
echo Next steps:
echo   1. Open the Visual Studio solution (vc16\otclient.sln)
echo   2. Build with the OpenGL configuration
echo   3. The Ultralight DLLs will need to be in the output directory
echo.
echo To use the WebView module in-game:
echo   1. Enable game_webview module in modules/game_webview/module.otml
echo   2. Load from Lua console: g_modules:loadModule('game_webview')
echo   3. Run demo: dofile('modules/game_webview/webview_demo.lua')
echo   4. Show demo window: showWebViewDemo()
echo.
goto :end

:cleanup
del "%~dp0ultralight-sdk.zip" 2>nul

:end
