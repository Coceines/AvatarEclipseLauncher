-- game_webview/overlay.lua
-- HTML Overlay UI for Freebuff Desktop
-- Renders a modern HTML/CSS interface over the game via Ultralight

OverlayModule = {}
OverlayModule.webView = nil
OverlayModule.window = nil
OverlayModule.updateTimer = nil
OverlayModule.textureTimer = nil
OverlayModule.visible = false

function OverlayModule.init()
    connect(g_game, {
        onGameStart = OverlayModule.onGameStart,
        onGameEnd = OverlayModule.onGameEnd,
    })
    if g_game.isOnline() then
        OverlayModule.onGameStart()
    end
    g_logger.info("[Overlay] Module initialized")
end

function OverlayModule.terminate()
    OverlayModule.hide()
    disconnect(g_game, {
        onGameStart = OverlayModule.onGameStart,
        onGameEnd = OverlayModule.onGameEnd,
    })
    g_logger.info("[Overlay] Module terminated")
end

function OverlayModule.onGameStart()
    -- Overlay is on-demand (Ctrl+Shift+H) to avoid burning frame resources on login
    OverlayModule.hide()
end

function OverlayModule.onGameEnd()
    OverlayModule.hide()
end

function OverlayModule.show()
    local showResult, showErr = pcall(OverlayModule._showInternal)
    if not showResult then
        g_logger.info("[Overlay] SHOW FAILED: " .. tostring(showErr))
    end
end

function OverlayModule._showInternal()
    if OverlayModule.visible then return end

    -- Check if UIWebView class exists
    if not UIWebView then
        g_logger.info("[Overlay] UIWebView class NOT registered - compile with WITH_ULTRALIGHT")
        return
    end
    g_logger.info("[Overlay] UIWebView class available")

    -- Check Ultralight
    if not g_ultralight then
        g_logger.info("[Overlay] g_ultralight not found")
        return
    end
    if not g_ultralight.isInitialized() then
        g_logger.info("[Overlay] Ultralight not initialized, trying init...")
        local ok, err = pcall(function() g_ultralight.init() end)
        if not ok then
            g_logger.info("[Overlay] Ultralight init error: " .. tostring(err))
            return
        end
        if not g_ultralight.isInitialized() then
            g_logger.info("[Overlay] Ultralight init failed")
            return
        end
    end
    local root = g_ui.getRootWidget()
    if not root then return end

    local rootW = root:getWidth()
    local rootH = root:getHeight()
    local testW = 800
    local testH = 600
    g_logger.info("[Overlay] Testing fixed window size: " .. testW .. "x" .. testH)

    -- Create container panel
    local container = g_ui.createWidget('Panel', root)
    container:setId('overlayContainer')
    container:setSize({width = testW, height = testH})
    container:setPosition({x = math.max(0, math.floor((rootW - testW) / 2)), y = math.max(0, math.floor((rootH - testH) / 2))})
    container:show()
    container:raise()

    -- Create UIWebView
    local webView = UIWebView:create()
    if not webView then
        g_logger.info("[Overlay] UIWebView:create() returned nil")
        container:destroy()
        return
    end
    g_logger.info("[Overlay] UIWebView object created")

    -- Configure widget geometry and properties BEFORE init
    webView:setSize({width = testW, height = testH})
    webView:setTransparent(true)
    webView:setJavaScriptEnabled(true)
    webView:setId('overlayWebView')
    container:addChild(webView)
    g_logger.info("[Overlay] WebView configured and added to UI tree")

    -- Initialize the Ultralight view
    local initOk, initErr = pcall(function()
        webView:init(testW, testH)
    end)
    if not initOk then
        g_logger.info("[Overlay] webView:init FAILED: " .. tostring(initErr))
        container:destroy()
        return
    end
    g_logger.info("[Overlay] webView:init OK")

    -- Step 1: Read the HTML file
    g_logger.info("[Overlay] Step 1: reading overlay.html...")
    local htmlContent = nil
    local readOk, readErr = pcall(function()
        htmlContent = g_resources.readFileContents("/modules/game_webview/overlay.html")
    end)
    g_logger.info("[Overlay] Step 1 done: readOk=" .. tostring(readOk) .. " hasContent=" .. tostring(htmlContent ~= nil))

    -- Step 2: Load simple HTML test
    g_logger.info("[Overlay] Step 2: calling loadHTML with simple test...")
    local testHTML = [[
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    margin: 0;
                    padding: 40px;
                    background: rgba(15, 24, 35, 0.92);
                    color: #ffffff;
                    font-family: Arial, sans-serif;
                    border: 2px solid #638cff;
                    border-radius: 12px;
                }
                h1 { color: #638cff; margin-bottom: 10px; }
                p { font-size: 16px; color: #a0aec0; }
                .btn {
                    padding: 10px 20px;
                    background: #638cff;
                    color: white;
                    border-radius: 6px;
                    display: inline-block;
                    margin-top: 20px;
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <h1>Ultralight Web View OK!</h1>
            <p>Se você está vendo esta janela, o renderizador WebKit está funcionando 100%!</p>
            <div class="btn">Interface HTML5 Ativa</div>
        </body>
        </html>
    ]]
    local loadOk, loadErr = pcall(function()
        webView:loadHTML(testHTML, "http://localhost/")
    end)
    g_logger.info("[Overlay] Step 2: loadHTML result ok=" .. tostring(loadOk) .. " err=" .. tostring(loadErr))

    g_logger.info("[Overlay] Step 3: setting state...")
    OverlayModule.window = container
    OverlayModule.webView = webView
    OverlayModule.visible = true
    g_logger.info("[Overlay] Step 3: state set OK")

    -- Start texture update timer (~30fps)
    g_logger.info("[Overlay] Step 4: starting timers...")
    OverlayModule.textureTimer = cycleEvent(function()
        if OverlayModule.webView then
            OverlayModule.webView:pendingTextureUpdate()
        end
    end, 33)

    -- Start state update timer (100ms)
    OverlayModule.updateTimer = cycleEvent(function()
        OverlayModule.pushState()
    end, 100)

    g_logger.info("[Overlay] Shown - " .. rootW .. "x" .. rootH)
end


function OverlayModule.hide()
    if not OverlayModule.visible then return end

    if OverlayModule.textureTimer then
        OverlayModule.textureTimer:cancel()
        OverlayModule.textureTimer = nil
    end
    if OverlayModule.updateTimer then
        OverlayModule.updateTimer:cancel()
        OverlayModule.updateTimer = nil
    end

    if OverlayModule.window then
        OverlayModule.window:destroy()
        OverlayModule.window = nil
    end

    OverlayModule.webView = nil
    OverlayModule.visible = false
    g_logger.info("[Overlay] Hidden")
end

function OverlayModule.toggle()
    if OverlayModule.visible then
        OverlayModule.hide()
    else
        OverlayModule.show()
    end
end

function OverlayModule.js(script)
    if OverlayModule.webView and not OverlayModule.webView:isLoading() then
        pcall(function()
            OverlayModule.webView:executeScript(script)
        end)
    end
end

function OverlayModule.pushState()
    if not OverlayModule.visible or not OverlayModule.webView then return end
    if OverlayModule.webView:isLoading() then return end

    local player = g_game.getLocalPlayer()
    if not player then return end

    pcall(function()
        OverlayModule.js("if (typeof updateHealth === 'function') updateHealth(" .. player:getHealth() .. "," .. player:getMaxHealth() .. ")")
        OverlayModule.js("if (typeof updateMana === 'function') updateMana(" .. player:getMana() .. "," .. player:getMaxMana() .. ")")
        OverlayModule.js("if (typeof updateExp === 'function') updateExp(" .. player:getLevelPercent() .. ")")
        OverlayModule.js("if (typeof updateCap === 'function') updateCap(" .. player:getCapacity() .. ")")
        OverlayModule.js("if (typeof updateSoul === 'function') updateSoul(" .. player:getSoul() .. ")")
        OverlayModule.js("if (typeof updateFPS === 'function') updateFPS(" .. g_app.getFps() .. ")")
        OverlayModule.js("if (typeof updateSkill === 'function') updateSkill('level'," .. player:getLevel() .. ")")
        OverlayModule.js("if (typeof updateSkill === 'function') updateSkill('ml'," .. player:getMagicLevel() .. ")")
        OverlayModule.js("if (typeof updateSkill === 'function') updateSkill('exp','" .. tostring(player:getExperience()) .. "')")
        local swordSkill = (Skill and Skill.Sword) and player:getSkillLevel(Skill.Sword) or (player:getSkillLevel(2) or 10)
        local shieldSkill = (Skill and Skill.Shielding) and player:getSkillLevel(Skill.Shielding) or (player:getSkillLevel(5) or 10)
        OverlayModule.js("if (typeof updateSkill === 'function') updateSkill('sword'," .. swordSkill .. ")")
        OverlayModule.js("if (typeof updateSkill === 'function') updateSkill('shield'," .. shieldSkill .. ")")
    end)
end
