# Ultralight WebView Integration for OTClient V8

## Overview

This module integrates the [Ultralight](https://ultralig.ht/) HTML/CSS/JS rendering engine into the OTClient Mehah V8 game client, allowing you to render HTML, CSS, and JavaScript content as textures within the game.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    OTClient V8                       │
│                                                     │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │  UIWebView   │────▶│   UltralightManager      │  │
│  │  (OTClient   │     │   (Singleton)            │  │
│  │   UI Widget) │     │   - Renderer::Create()   │  │
│  └──────┬───────┘     │   - Update()             │  │
│         │             │   - Render()              │  │
│         │             └──────────┬───────────────┘  │
│         │                        │                   │
│         ▼                        ▼                   │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │ OpenGL       │     │ Ultralight SDK            │  │
│  │ Texture      │◀────│ BitmapSurface (CPU)       │  │
│  │ (BGRA→RGBA)  │     │ View → Render → Surface   │  │
│  └──────────────┘     └──────────────────────────┘  │
│                                                     │
│  Lua Module: modules/game_webview/                  │
│  └─ init.lua     → Module loader                    │
│  └─ webview.otml → Widget styles                    │
│  └─ webview_demo.lua → Demo script                  │
└─────────────────────────────────────────────────────┘
```

## Files Created

### C++ (Framework)
| File | Purpose |
|------|---------|
| `src/framework/graphics/ultralightmanager.h` | UltralightManager singleton header |
| `src/framework/graphics/ultralightmanager.cpp` | UltralightManager implementation with platform handlers |
| `src/framework/graphics/uiwebview.h` | UIWebView widget header |
| `src/framework/graphics/uiwebview.cpp` | UIWebView widget (renders HTML→texture, forwards input) |
| `src/framework/luafunctions_ultralight.cpp` | Lua bindings for UltralightManager + UIWebView |

### Lua Module
| File | Purpose |
|------|---------|
| `modules/game_webview/module.otml` | Module configuration |
| `modules/game_webview/init.lua` | Module entry point |
| `modules/game_webview/webview.otml` | Widget OTML styles |
| `modules/game_webview/webview_demo.lua` | Interactive demo script |
| `modules/game_webview/sample.html` | Sample HTML page |
| `modules/game_webview/README.md` | This file |

### Build / Setup
| File | Purpose |
|------|---------|
| `vc16/download_ultralight.bat` | SDK download helper |
| `vc16/otclient.vcxproj` (modified) | Added new source files |
| `vc16/settings.props` (modified) | Added WITH_ULTRALIGHT + SDK paths |
| `src/framework/core/application.h` (modified) | Added registerLuaFunctionsUltralight() |
| `src/framework/core/application.cpp` (modified) | Calls Ultralight init/terminate |

## Setup Instructions

### 1. Download the Ultralight SDK

Run `vc16/download_ultralight.bat` or download manually from [ultralig.ht](https://ultralig.ht/).

The SDK should be placed in `vc16/ultralight-sdk/` with this structure:
```
vc16/ultralight-sdk/
├── include/
│   ├── Ultralight/
│   │   ├── Ultralight.h
│   │   ├── Bitmap.h
│   │   ├── View.h
│   │   ├── Renderer.h
│   │   ├── Platform/
│   │   │   ├── FileSystem.h
│   │   │   ├── FontLoader.h
│   │   │   └── Surface.h
│   │   └── ...
│   ├── AppCore/
│   └── ...
└── lib/
    └── x86/
        ├── Ultralight.lib
        ├── UltralightCore.lib
        ├── WebCore.lib
        └── AppCore.lib
```

### 2. Build the Project

1. Open `vc16/otclient.sln` in Visual Studio 2022
2. Select the **OpenGL** configuration
3. Build the solution (Ctrl+Shift+B)
4. Copy the Ultralight DLLs to the output directory:
   - `Ultralight.dll`
   - `UltralightCore.dll`
   - `WebCore.dll`

### 3. Test the Integration

In the Lua console:
```lua
-- Load the webview module
g_modules:loadModule('game_webview')

-- Show the demo window
dofile('modules/game_webview/webview_demo.lua')
showWebViewDemo()
```

## Usage in Lua

### Creating a WebView

```lua
-- Create a 600x400 WebView widget
local webView = UIWebView:create()
webView:setSize(600, 400)

-- Load HTML content
webView:loadHTML([[
    <html>
    <body style="background: #1a1a2e; color: white; padding: 20px;">
        <h1>Hello from Ultralight!</h1>
        <p>This HTML is rendered inside the game client.</p>
    </body>
    </html>
]])

-- Or load from a URL
webView:loadURL("https://example.com")

-- Execute JavaScript
webView:executeScript("alert('Hello from Lua!')")
```

### Adding to the UI Tree

```lua
-- Create a parent panel
local panel = g_ui.createWidget('Panel')
panel:setSize(620, 440)
panel:centerIn('rootWidget')

-- Add WebView as child
panel:addChild(webView)
```

## How It Works

1. **Initialization**: `UltralightManager::init()` sets up the Ultralight platform handlers (filesystem, fonts) and creates the `Renderer`.

2. **View Creation**: `UIWebView::create()` creates an Ultralight `View` with a CPU-rendered `BitmapSurface`.

3. **HTML Loading**: `loadHTML()` / `loadURL()` loads content into the Ultralight view.

4. **Rendering**: Each frame, `UIWebView::drawSelf()` checks if the `BitmapSurface` has dirty pixels. If so, it converts the BGRA bitmap to RGBA and uploads it to an OpenGL texture, which is then drawn using OTClient's painter.

5. **Input Forwarding**: Mouse and keyboard events on the widget are translated and forwarded to the Ultralight view via `FireMouseEvent()`, `FireKeyEvent()`, etc.

## Limitations

1. **CPU Rendering Only**: The integration uses Ultralight's CPU renderer (BitmapSurface) because OTClient V8 doesn't expose its OpenGL context directly. GPU rendering would require deeper integration with OTClient's graphics pipeline.

2. **No JavaScript-to-Lua Bridge Yet**: The current implementation provides `executeScript()` for calling JavaScript from Lua, but doesn't yet support calling Lua functions from JavaScript. This can be extended by using Ultralight's JavaScript API to bind C++ callbacks.

3. **Performance**: For complex pages with frequent updates, CPU rendering may impact frame rate. Consider using simpler HTML/CSS for game UI overlays.

4. **Font Loading**: The default font loader is simplified. For production use, you may want to implement a more complete font loader that uses the game's bundled fonts.

5. **File URLs**: Loading local HTML files via `file:///` URLs requires the `UltralightFileSystem` to be able to resolve the paths correctly through PhysFS.

## Troubleshooting

### "UltralightManager not initialized"
- Make sure `WITH_ULTRALIGHT` is defined in the project preprocessor definitions
- Check that `download_ultralight.bat` was run successfully
- Verify the SDK is in `vc16/ultralight-sdk/`

### WebView appears blank
- Check the console log for Ultralight errors
- Verify the HTML content is valid
- Try loading a simple HTML page first: `webView:loadHTML("<h1>Test</h1>")`

### Build errors
- Ensure all Ultralight DLLs are in the output directory
- Check that the SDK include path is correct in `settings.props`
- Verify the library files are in `ultralight-sdk/lib/x86/`
