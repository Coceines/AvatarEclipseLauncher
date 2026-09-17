-- game_notification: modulo reutilizavel de notificacoes no centro da tela

local notifWidget = nil
local hideEvent = nil
local fadeEvent = nil
local queue = {}
local isShowing = false
local mapPanel = nil

local checkEvent = nil

local FADE_STEPS = 10
local FADE_IN_MS = 300
local FADE_OUT_MS = 500
local DEFAULT_DURATION = 3000

function init()
    mapPanel = modules.game_interface.getMapPanel()
    g_ui.importStyle('notification')

    ProtocolGame.registerExtendedOpcode(201, onExtendedOpcode)
end

function terminate()
    clearTimers()
    
    ProtocolGame.unregisterExtendedOpcode(201)

    if notifWidget then
        notifWidget:destroy()
        notifWidget = nil
    end
    queue = {}
    isShowing = false
    mapPanel = nil
end

function clearTimers()
    if hideEvent then removeEvent(hideEvent); hideEvent = nil end
    if fadeEvent then removeEvent(fadeEvent); fadeEvent = nil end
end

-- ======== EXTENDED OPCODE: Handlers for server-side triggers (Quests, etc) ========
function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= 201 then return end
    local status, data = pcall(function() return json.decode(buffer) end)
    if not status or not data then
        -- Treat as simple message if JSON fails
        show({ title = "Notificacao", message = buffer })
        return
    end
    show(data)
end

-- Helper: formata numeros com virgula
function comma_value(n)
    if not n then return "0" end
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)((%d+).-)$')
    return left and (left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse())) or tostring(n)
end

-- ======== SHOW API ========
function show(opts)
    if not opts then return end
    print("[Notification] " .. (opts.title or "?") .. ": " .. (opts.message or ""))
    table.insert(queue, opts)
    if not isShowing then
        processQueue()
    end
end

function processQueue()
    if #queue == 0 then
        isShowing = false
        return
    end

    isShowing = true
    local opts = table.remove(queue, 1)
    displayNotification(opts)
end

function displayNotification(opts)
    clearTimers()

    if not mapPanel then
        mapPanel = modules.game_interface.getMapPanel()
    end
    if not mapPanel then return end

    -- Som (Quest/NPC)
    if opts.soundType and opts.npcName and g_sounds then
        local soundFile = opts.soundType
        if soundFile == "start" then 
            soundFile = "Inicio_quest" 
        elseif soundFile == "end" then 
            soundFile = "Fim_quest"
        end
        
        local soundPath = "/sounds/NPCS/" .. opts.npcName .. "/" .. soundFile .. ".ogg"
        
        -- Tenta tocar o som
        if g_sounds.playOneShot then
            g_sounds.playOneShot(soundPath, 1.0)
        else
            g_sounds.play(soundPath, 0, 1.0)
        end
    end

    -- Se nao houver titulo nem mensagem, nao mostra o widget (apenas som)
    if not opts.title and not opts.message then
        isShowing = false
        processQueue()
        return
    end

    -- Cria ou reutiliza o widget
    if not notifWidget then
        notifWidget = g_ui.createWidget('NotificationWidget', mapPanel)
    end

    if not notifWidget then return end

    local title   = opts.title or "Notificacao"
    local message = opts.message or ""
    local icon    = opts.icon or nil
    local color   = opts.color or "#FFD700"
    local duration = opts.duration or DEFAULT_DURATION

    -- Atualiza conteudo
    local titleLabel = notifWidget:getChildById('notifTitle')
    local msgLabel   = notifWidget:getChildById('notifMessage')
    local iconWidget = notifWidget:getChildById('notifIcon')
    local bgWidget   = notifWidget:getChildById('notifBg')

    if titleLabel then
        titleLabel:setText(title)
        titleLabel:setColor(color)
    end

    if msgLabel then
        msgLabel:setText(message)
    end

    -- Icone (opcional)
    if iconWidget then
        if icon then
            iconWidget:setImageSource(icon)
            iconWidget:setVisible(true)
            if titleLabel then titleLabel:setMarginLeft(52) end
            if msgLabel then msgLabel:setMarginLeft(52) end
        else
            iconWidget:setVisible(false)
            if titleLabel then titleLabel:setMarginLeft(16) end
            if msgLabel then msgLabel:setMarginLeft(16) end
        end
    end

    -- Cor da borda baseada na cor do titulo
    if bgWidget then
        bgWidget:setBorderColor(color .. "88")
    end

    -- Ajusta altura: conta linhas do texto para suportar ate 3 linhas
    local lineCount = 1
    for _ in message:gmatch("\n") do
        lineCount = lineCount + 1
    end
    -- Estima se o texto e longo o suficiente para wrap (mais de ~35 chars por linha)
    local estimatedWrapLines = math.ceil(#message / 35)
    if estimatedWrapLines > lineCount then
        lineCount = estimatedWrapLines
    end
    if lineCount > 3 then lineCount = 3 end
    local baseHeight = 70
    local extraPerLine = 16
    notifWidget:setHeight(baseHeight + (lineCount - 1) * extraPerLine)

    -- Fade in
    notifWidget:setOpacity(0.0)
    notifWidget:show()
    notifWidget:raise()
    fadeIn(function()
        hideEvent = scheduleEvent(function()
            fadeOut(function()
                notifWidget:hide()
                processQueue()
            end)
        end, duration)
    end)
end

function fadeIn(callback)
    local step = 0
    local interval = math.floor(FADE_IN_MS / FADE_STEPS)
    local function doStep()
        step = step + 1
        if not notifWidget then return end
        local alpha = step / FADE_STEPS
        if alpha > 1.0 then alpha = 1.0 end
        notifWidget:setOpacity(alpha)
        if step < FADE_STEPS then
            fadeEvent = scheduleEvent(doStep, interval)
        else
            fadeEvent = nil
            if callback then callback() end
        end
    end
    doStep()
end

function fadeOut(callback)
    local step = 0
    local interval = math.floor(FADE_OUT_MS / FADE_STEPS)
    local function doStep()
        step = step + 1
        if not notifWidget then return end
        local alpha = 1.0 - (step / FADE_STEPS)
        if alpha < 0 then alpha = 0 end
        notifWidget:setOpacity(alpha)
        if step < FADE_STEPS then
            fadeEvent = scheduleEvent(doStep, interval)
        else
            fadeEvent = nil
            if callback then callback() end
        end
    end
    doStep()
end