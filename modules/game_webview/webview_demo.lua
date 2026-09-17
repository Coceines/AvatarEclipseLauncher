-- Webview Demo Script
-- Run this to test the HTML/CSS/JS integration

local demoWindow = nil
local webView = nil

function showWebViewDemo()
    if demoWindow and not demoWindow:isDestroyed() then
        demoWindow:raise()
        demoWindow:focus()
        return
    end

    -- Check if Ultralight is available
    if not g_ultralight or not g_ultralight:isInitialized() then
        g_logger.error("[WebviewDemo] Ultralight is not initialized!")
        g_logger.error("[WebviewDemo] Make sure WITH_ULTRALIGHT is defined in the build")
        return
    end

    -- Create the demo window
    demoWindow = g_ui.createWidget('Panel')
    demoWindow:setSize(800, 600)
    demoWindow:centerIn('rootWidget')
    demoWindow:setId('webviewDemoWindow')
    demoWindow:setDraggable(true)

    -- Title bar
    local titleBar = g_ui.createWidget('Label', demoWindow)
    titleBar:setId('webviewDemoTitle')
    titleBar:setText('WebView Demo - HTML/CSS/JS via Ultralight')
    titleBar:setColor('#ffffff')
    titleBar:setFont('terminus-12px')
    titleBar:setMarginTop(5)
    titleBar:setMarginLeft(10)

    -- Close button
    local closeButton = g_ui.createWidget('Button', demoWindow)
    closeButton:setId('webviewDemoClose')
    closeButton:setText('X')
    closeButton:setSize(20, 20)
    closeButton:setX(demoWindow:getWidth() - 30)
    closeButton:setY(5)
    closeButton.onClick = function()
        demoWindow:destroy()
        demoWindow = nil
    end

    -- Create the WebView widget
    webView = UIWebView:create()
    webView:setSize(780, 560)
    webView:setX(10)
    webView:setY(30)
    demoWindow:addChild(webView)

    -- Load a demo HTML page
    local demoHTML = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: #ffffff;
            min-height: 100vh;
            padding: 20px;
        }
        h1 {
            text-align: center;
            margin-bottom: 20px;
            color: #e94560;
            font-size: 28px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
        }
        .card {
            background: rgba(255,255,255,0.1);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 16px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.2s;
        }
        .card:hover {
            transform: scale(1.02);
        }
        .card h2 {
            color: #e94560;
            margin-bottom: 10px;
        }
        .card p {
            color: #ccc;
            line-height: 1.6;
        }
        .btn {
            display: inline-block;
            padding: 10px 24px;
            background: #e94560;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            margin: 5px;
            transition: background 0.2s;
        }
        .btn:hover { background: #c81e45; }
        .btn-secondary {
            background: #0f3460;
        }
        .btn-secondary:hover { background: #1a4a8a; }
        .counter {
            font-size: 48px;
            text-align: center;
            color: #e94560;
            margin: 15px 0;
            font-weight: bold;
        }
        .input-group {
            margin: 10px 0;
        }
        .input-group input {
            padding: 8px 12px;
            border: 1px solid rgba(255,255,255,0.3);
            border-radius: 6px;
            background: rgba(255,255,255,0.1);
            color: white;
            font-size: 14px;
            width: 200px;
        }
        .output {
            background: #000;
            padding: 12px;
            border-radius: 6px;
            font-family: monospace;
            color: #0f0;
            margin-top: 10px;
            min-height: 40px;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
        }
        .flex-center {
            display: flex;
            justify-content: center;
            align-items: center;
            flex-direction: column;
        }
        .status {
            text-align: center;
            padding: 8px;
            margin-top: 10px;
            background: rgba(0, 255, 0, 0.1);
            border-radius: 6px;
            color: #0f0;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <h1>? Ultralight WebView in OTClient</h1>

    <div class="grid">
        <div class="card">
            <h2>? Interactive Demo</h2>
            <p>This is a fully rendered HTML page running inside the OTClient game!</p>
            <div class="counter" id="counter">0</div>
            <div class="flex-center">
                <button class="btn" onclick="increment()">+ Increment</button>
                <button class="btn btn-secondary" onclick="decrement()">- Decrement</button>
                <button class="btn btn-secondary" onclick="reset()">? Reset</button>
            </div>
        </div>

        <div class="card">
            <h2>* JavaScript Bridge</h2>
            <p>Test communication between HTML and the OTClient Lua engine.</p>
            <div class="input-group">
                <input type="text" id="msgInput" placeholder="Type a message..." />
            </div>
            <button class="btn" onclick="sendToLua()">Send to Lua</button>
            <button class="btn btn-secondary" onclick="callLuaFunction()">Call Lua</button>
            <div class="output" id="output">Waiting for messages...</div>
        </div>
    </div>

    <div class="card">
        <h2>? CSS Features</h2>
        <p>This demo showcases modern CSS: gradients, flexbox, grid, animations,
           backdrop-filter, border-radius, transitions, and more. All rendered in real-time
           by Ultralight's WebKit-based engine!</p>
        <div class="status" id="status">* Ultralight rendering active</div>
    </div>

    <script>
        let count = 0;

        function increment() {
            count++;
            document.getElementById('counter').textContent = count;
            updateStatus();
        }

        function decrement() {
            count--;
            document.getElementById('counter').textContent = count;
            updateStatus();
        }

        function reset() {
            count = 0;
            document.getElementById('counter').textContent = count;
            updateStatus();
        }

        function sendToLua() {
            var msg = document.getElementById('msgInput').value;
            if (msg) {
                document.getElementById('output').textContent = 'Sent: ' + msg;
                document.getElementById('msgInput').value = '';
            }
        }

        function callLuaFunction() {
            document.getElementById('output').textContent = 'Calling Lua function...';
        }

        function updateStatus() {
            var s = document.getElementById('status');
            s.textContent = 'Counter: ' + count + ' | Last update: ' + new Date().toLocaleTimeString();
        }

        // Update time every second
        setInterval(updateStatus, 1000);
        updateStatus();
    </script>
</body>
</html>
    ]]

    webView:loadHTML(demoHTML)
    demoWindow:show()
    demoWindow:focus()

    g_logger.info("[WebviewDemo] Demo window opened")
end

-- Auto-run the demo when this file is loaded (for testing)
-- Uncomment the line below to auto-show:
-- showWebViewDemo()
