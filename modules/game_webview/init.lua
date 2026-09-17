-- Webview module for OTClient V8
-- Provides HTML/CSS/JS rendering inside the client using Ultralight

WebviewModule = {}
WebviewModule.currentWindow = nil
WebviewModule.currentWebView = nil
WebviewModule.updateEvent = nil

function onModuleLoad()
    g_logger.info("[Webview] Module loaded")
    -- Check if Ultralight and UIWebView are available
    if not g_ultralight then
        g_logger.info("[Webview] g_ultralight not available - overlay disabled")
        return
    end
    if not UIWebView then
        g_logger.info("[Webview] UIWebView class not registered - overlay disabled")
        return
    end
    -- Load overlay module safely
    local success, err = pcall(function()
        dofile('/modules/game_webview/overlay.lua')
    end)
    if success and OverlayModule then
        OverlayModule.init()
        g_keyboard.bindKeyDown('Ctrl+Shift+H', function() OverlayModule.toggle() end)
        g_logger.info("[Webview] Overlay loaded - Ctrl+Shift+H to toggle")
    else
        g_logger.info("[Webview] Overlay load error: " .. tostring(err))
    end
end

function onModuleUnload()
    g_keyboard.unbindKeyDown('Ctrl+Shift+H')
    OverlayModule.terminate()
    WebviewModule.destroy()
    g_logger.info("[Webview] Module unloaded")
end

--- Create a floating window with a WebView inside
function WebviewModule.create(opts)
    opts = opts or {}
    local width = opts.width or 800
    local height = opts.height or 600

    WebviewModule.destroy()

    -- Create container panel
    local window = g_ui.createWidget('Panel', rootWidget)
    window:setSize({width = width, height = height})
    window:setId('webviewWindow')
    window:setDraggable(true)
    window:show()

    -- Position centered
    local rootSize = rootWidget:getSize()
    window:setX(math.floor((rootSize.width - width) / 2))
    window:setY(math.floor((rootSize.height - height) / 2))

    -- Create the WebView widget
    local webView = UIWebView:create()
    webView:setSize({width = width, height = height})
    window:addChild(webView)

    -- Initialize the Ultralight view
    webView:init(width, height)

    if opts.html then
        webView:loadHTML(opts.html)
    elseif opts.url then
        webView:loadURL(opts.url)
    end

    if opts.transparent then
        webView:setTransparent(true)
    end

    WebviewModule.currentWindow = window
    WebviewModule.currentWebView = webView

    window:focus()
    window:raise()

    -- Start periodic texture update timer (every 33ms = ~30fps)
    WebviewModule.startUpdateTimer()

    g_logger.info("[Webview] Window created and displayed")
    return window
end

--- Start a timer to update the WebView texture periodically
function WebviewModule.startUpdateTimer()
    WebviewModule.stopUpdateTimer()
    WebviewModule.updateEvent = cycleEvent(function()
        if WebviewModule.currentWebView then
            WebviewModule.currentWebView:pendingTextureUpdate()
        else
            WebviewModule.stopUpdateTimer()
        end
    end, 33)
end

--- Stop the update timer
function WebviewModule.stopUpdateTimer()
    if WebviewModule.updateEvent then
        WebviewModule.updateEvent:cancel()
        WebviewModule.updateEvent = nil
    end
end

--- Run the full demo with styled HTML
function WebviewModule.showDemo()
    local html = [[
<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>
body { font-family: Arial; background: #1a1a2e; color: #fff; padding: 20px; margin: 0; }
h1 { color: #e94560; text-align: center; }
.card { background: rgba(255,255,255,0.1); border-radius: 12px; padding: 20px; margin: 10px 0; border: 1px solid rgba(255,255,255,0.2); }
.btn { padding: 10px 24px; background: #e94560; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; margin: 5px; }
.counter { font-size: 48px; text-align: center; color: #e94560; margin: 15px 0; font-weight: bold; }
.output { background: #000; padding: 12px; border-radius: 6px; font-family: monospace; color: #0f0; margin-top: 10px; }
input { padding: 8px 12px; border: 1px solid rgba(255,255,255,0.3); border-radius: 6px; background: rgba(255,255,255,0.1); color: white; width: 200px; }
</style></head><body>
<h1>Ultralight WebView in OTClient</h1>
<div class="card">
<h2>Interactive Demo</h2>
<div class="counter" id="counter">0</div>
<button class="btn" onclick="count++;document.getElementById('counter').textContent=count">+ Inc</button>
<button class="btn" onclick="count--;document.getElementById('counter').textContent=count">- Dec</button>
<button class="btn" onclick="count=0;document.getElementById('counter').textContent=count">Reset</button>
</div>
<div class="card">
<h2>JavaScript Bridge</h2>
<input type="text" id="msg" placeholder="Type a message..." />
<button class="btn" onclick="document.getElementById('out').textContent='Sent: '+document.getElementById('msg').value">Send</button>
<div class="output" id="out">Waiting...</div>
</div>
<script>var count=0;</script>
</body></html>
    ]]
    WebviewModule.create({width = 800, height = 600, html = html})
end

function WebviewModule.destroy()
    WebviewModule.stopUpdateTimer()
    WebviewModule.currentWindow = nil
    WebviewModule.currentWebView = nil
end

function WebviewModule.loadHTML(widget, html, baseUrl)
    if not widget then return end
    widget:loadHTML(html, baseUrl or "")
end

function WebviewModule.executeScript(widget, script)
    if not widget then return "" end
    return widget:executeScript(script)
end

function WebviewModule.reload(widget)
    if not widget then return end
    widget:reload()
end
