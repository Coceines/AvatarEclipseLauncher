--[[
  game_controller/controller.lua
  -----------------------------------------------------------------------------
  M�dulo de suporte a gamepad com mapeamento de teclas de teclado.
--]]

-- -----------------------------------------------------------------------------
-- Constantes
-- -----------------------------------------------------------------------------

local BUTTONS = {
    { id = "a",             label = "Action Button A"     },
    { id = "b",             label = "Action Button B"     },
    { id = "x",             label = "Action Button X"     },
    { id = "y",             label = "Action Button Y"     },
    { id = "leftshoulder",  label = "Shoulder L1 (LB)"    },
    { id = "rightshoulder", label = "Shoulder R1 (RB)"    },
    { id = "leftstick",     label = "Stick L3 (Left)"      },
    { id = "rightstick",    label = "Stick R3 (Right)"     },
    { id = "back",          label = "Back / Select Button" },
    { id = "start",         label = "Start Button"         },
    { id = "guide",         label = "Home / Guide Button"  },
    -- Direcionais hardcoded para movimento (n�o aparecem na UI)
    { id = "dpup",          label = "D-Pad Up",    hidden = true },
    { id = "dpdown",        label = "D-Pad Down",  hidden = true },
    { id = "dpleft",        label = "D-Pad Left",  hidden = true },
    { id = "dpright",       label = "D-Pad Right", hidden = true },
}

local AXES = {
    { id = "triggerleft",  label = "Trigger L2 (LT)"     },
    { id = "triggerright", label = "Trigger R2 (RT)"     },
}

local AXIS_WALK_THRESHOLD = 0.5

-- -----------------------------------------------------------------------------
-- Estado do m�dulo
-- -----------------------------------------------------------------------------

local controllerPanel  = nil
local statusLabel      = nil
local enableCheckbox   = nil
local configureButton  = nil
local configWindow     = nil
local configList       = nil
local slotButtons      = {}   -- [buttonId] = widget Button de atribui��o

local bindings  = {}   -- { ["a"] = "F1", ["b"] = "Escape", ... }
local axisState = {}   -- estado atual dos eixos anal�gicos
local enabled   = true -- se o gamepad est� ativo

-- Estado de Movimenta��o
local moveEvent    = nil
local moveDir      = nil
local moveIsTurn   = false
local dpadState    = { up = false, down = false, left = false, right = false }
local connectCallback = nil

-- -----------------------------------------------------------------------------
-- Persist�ncia
-- -----------------------------------------------------------------------------

function saveBindings()
    local settings = {}
    for k, v in pairs(bindings) do
        settings[k] = v
    end
    g_settings.setNode("gamepad_bindings", settings)
    g_settings.save()
end

function loadBindings()
    local settings = g_settings.getNode("gamepad_bindings") or {}
    for k, v in pairs(settings) do
        bindings[k] = v
    end
end

-- -----------------------------------------------------------------------------
-- L�gica de Movimento Throttled (Evita Packet Spam)
-- -----------------------------------------------------------------------------

local function stopMoving()
    if moveEvent then
        removeEvent(moveEvent)
        moveEvent = nil
    end
    moveDir = nil
    moveIsTurn = false
end

-- Intervalo do loop de movimento.
-- Walk: o g_game.walk j� faz fila/retry interno e N�O envia pacote enquanto o
-- passo n�o terminou (canWalk=false), ent�o podemos sondar r�pido (50ms) para
-- pegar a janela em que o passo termina sem pausa vis�vel (sem stutter).
-- Turn: g_game.turn SEMPRE envia pacote, ent�o mantemos um intervalo maior
-- para n�o floodar o servidor.
local MOVE_INTERVAL_WALK = 50
local MOVE_INTERVAL_TURN = 150

local function moveLoop()
    if not moveDir or not g_game.isOnline() or not enabled then
        stopMoving()
        return
    end

    local interval = MOVE_INTERVAL_WALK
    if moveIsTurn then
        g_game.turn(moveDir)
        interval = MOVE_INTERVAL_TURN
    else
        g_game.walk(moveDir)
        interval = MOVE_INTERVAL_WALK
    end

    moveEvent = scheduleEvent(moveLoop, interval)
end

local function updateMovement(dir, isTurn)
    if not dir then
        stopMoving()
        return
    end

    if dir == moveDir and isTurn == moveIsTurn then
        return
    end

    stopMoving()
    moveDir = dir
    moveIsTurn = isTurn
    moveLoop()
end

local function getDirectionFromAnalog(x, y)
    if math.abs(x) < AXIS_WALK_THRESHOLD and math.abs(y) < AXIS_WALK_THRESHOLD then
        return nil
    end

    local angle = math.atan2(y, x) * 180 / math.pi
    if angle < 0 then angle = angle + 360 end

    -- SDL: 0=East, 90=South, 180=West, 270=North
    if angle >= 337.5 or angle < 22.5 then return Directions.East
    elseif angle >= 22.5 and angle < 67.5 then return Directions.SouthEast
    elseif angle >= 67.5 and angle < 112.5 then return Directions.South
    elseif angle >= 112.5 and angle < 157.5 then return Directions.SouthWest
    elseif angle >= 157.5 and angle < 202.5 then return Directions.West
    elseif angle >= 202.5 and angle < 247.5 then return Directions.NorthWest
    elseif angle >= 247.5 and angle < 292.5 then return Directions.North
    elseif angle >= 292.5 and angle < 337.5 then return Directions.NorthEast
    end
    return nil
end

local function getDpadDirection()
    local up, down, left, right = dpadState.up, dpadState.down, dpadState.left, dpadState.right
    if up and left then return Directions.NorthWest
    elseif up and right then return Directions.NorthEast
    elseif down and left then return Directions.SouthWest
    elseif down and right then return Directions.SouthEast
    elseif up then return Directions.North
    elseif down then return Directions.South
    elseif left then return Directions.West
    elseif right then return Directions.East
    end
    return nil
end

local function refreshCombinedMovement()
    -- Prioridade: Analog Left > DPad
    local dir = getDirectionFromAnalog(axisState.leftx or 0, axisState.lefty or 0)
    if not dir then
        dir = getDpadDirection()
    end

    -- Se tiver movimento no stick da direita, faz Turn (Ctrl+Direction)
    local turnDir = getDirectionFromAnalog(axisState.rightx or 0, axisState.righty or 0)

    if turnDir then
        updateMovement(turnDir, true)
    else
        updateMovement(dir, false)
    end
end

-- -----------------------------------------------------------------------------
-- Auxiliares de UI / Status
-- -----------------------------------------------------------------------------

local statusEvent = nil
function updateStatusLabel()
    if statusEvent then
        removeEvent(statusEvent)
        statusEvent = nil
    end

    if not statusLabel then return end

    if g_controller and g_controller.isConnected() then
        local name = g_controller.getControllerName() or "Unknown"
        statusLabel:setText("Connected: " .. name)
        statusLabel:setColor("#00ff00ff")
    else
        statusLabel:setText("No controller connected.")
        statusLabel:setColor("#a0a0a0ff")
    end

    -- Polling fallback: Se n�o tiver o callback C++ (recompile), checamos a cada 1 segundo
    if g_controller and not g_controller.setConnectCallback then
        statusEvent = scheduleEvent(updateStatusLabel, 1000)
    end
end

local function updateAssignButton(buttonId)
    local btn = slotButtons[buttonId]
    if not btn then return end

    local keyCombo = bindings[buttonId]
    if keyCombo and keyCombo ~= "" then
        btn:setText(keyCombo)
    else
        btn:setText(tr('Not assigned'))
    end
end

-- -----------------------------------------------------------------------------
-- Gatilho Universal de Hotkeys
-- -----------------------------------------------------------------------------

local function triggerHotkey(keyCombo)
    if not keyCombo or #keyCombo == 0 then return end

    -- Simula o pressionamento da tecla como se fosse digitada de verdade:
    -- varre a �rvore de widgets e dispara TODOS os binds de teclado
    -- (KeyDown/KeyPress) registrados no g_keyboard para esse combo. Isso cobre
    -- hotkeys do Hotkey Manager (registradas como binds reais no rootWidget),
    -- andar/turn, Escape, Space (mirar no alvo mais pr�ximo), etc.
    local widgets = { rootWidget }
    local all = rootWidget:recursiveGetChildren()
    for i = 1, #all do
        widgets[#widgets + 1] = all[i]
    end

    for i = 1, #widgets do
        local widget = widgets[i]
        if widget then
            if widget.boundAloneKeyDownCombos then
                local cb = widget.boundAloneKeyDownCombos[keyCombo]
                if cb then signalcall(cb, widget, 0) end
            end
            if widget.boundKeyDownCombos then
                local cb = widget.boundKeyDownCombos[keyCombo]
                if cb then signalcall(cb, widget, 0) end
            end
            if widget.boundKeyPressCombos then
                local cb = widget.boundKeyPressCombos[keyCombo]
                if cb then signalcall(cb, widget, 0, 0) end
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- Captura de Teclas (Hotkey Assign)
-- -----------------------------------------------------------------------------

local function startKeyCapture(buttonId)
    -- Cria a janela no rootWidget (mesmo padr�o do hotkeys_manager) para
    -- garantir que ela fique por cima e n�o seja recortada pela janela de op��es.
    local assignWindow = g_ui.createWidget('HotkeyAssignWindow', g_ui.getRootWidget())
    assignWindow:grabKeyboard()
    assignWindow:raise()
    assignWindow:focus()

    local comboLabel = assignWindow:getChildById('comboPreview')
    comboLabel.keyCombo = ''

    assignWindow.onKeyDown = function(window, keyCode, keyboardModifiers)
        local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
        comboLabel:setText(tr('Current hotkey to add: %s', keyCombo))
        comboLabel.keyCombo = keyCombo
        comboLabel:resizeToText()
        window:getChildById('addButton'):enable()
        return true
    end

    local addBtn = assignWindow:getChildById('addButton')
    addBtn.onClick = function()
        local keyCombo = comboLabel.keyCombo
        if keyCombo and keyCombo ~= "" then
            bindings[buttonId] = keyCombo
            updateAssignButton(buttonId)
            saveBindings()
        end
        assignWindow:destroy()
    end

    local cancelBtn = assignWindow:getChildById('cancelButton')
    cancelBtn.onClick = function()
        assignWindow:destroy()
    end
end

-- -----------------------------------------------------------------------------
-- Janela de Configura��o (bot�o a bot�o)
-- -----------------------------------------------------------------------------

local function createConfigRow(item)
    -- configList usa layout verticalBox: as linhas empilham automaticamente
    -- e expandem a largura; por isso nenhuma �ncora � usada aqui.
    -- IMPORTANTE: os hooks de �ncora dos filhos devem ser STRINGS ('parent'),
    -- pois o binding C++ converte userdata de widget em string vazia.
    local row = g_ui.createWidget('UIWidget', configList)
    row:setId('row_' .. item.id)
    row:setHeight(32)
    row:setBackgroundColor('#ffffff08')
    row:setBorderWidthBottom(1)
    row:setBorderColor('#ffffff0f')

    local nameLabel = g_ui.createWidget('Label', row)
    nameLabel:setId('name')
    nameLabel:setText(item.label)
    nameLabel:setFont('verdana-11px-monochrome')
    nameLabel:setColor('#dfdfdf')
    nameLabel:setWidth(200)
    nameLabel:setTextAlign(AlignLeftCenter)
    nameLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    nameLabel:addAnchor(AnchorTop, 'parent', AnchorTop)
    nameLabel:addAnchor(AnchorBottom, 'parent', AnchorBottom)

    local assignBtn = g_ui.createWidget('Button', row)
    assignBtn:setId('assign')
    assignBtn:setWidth(140)
    assignBtn:setHeight(26)
    assignBtn:addAnchor(AnchorRight, 'parent', AnchorRight)
    assignBtn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)

    assignBtn.onClick = function()
        startKeyCapture(item.id)
    end

    -- Clique secund�rio (Context Menu)
    assignBtn.onMouseRelease = function(self, mousePos, mouseBtn)
        if mouseBtn == MouseRightButton then
            local menu = g_ui.createWidget('PopupMenu')

            local hasBinding = (bindings[item.id] ~= nil)
            menu:addOption(hasBinding and tr('Edit Hotkey') or tr('Assign Hotkey'), function()
                startKeyCapture(item.id)
            end)

            if hasBinding then
                menu:addSeparator()
                menu:addOption(tr('Clear Hotkey'), function()
                    bindings[item.id] = nil
                    updateAssignButton(item.id)
                    saveBindings()
                end)
            end

            menu:display(mousePos)
            return true
        end
    end

    slotButtons[item.id] = assignBtn
    updateAssignButton(item.id)
end

local function populateConfigList()
    if not configList then return end

    configList:destroyChildren()
    slotButtons = {}

    local allItems = {}
    for _, b in ipairs(BUTTONS) do
        if not b.hidden then table.insert(allItems, b) end
    end
    for _, a in ipairs(AXES) do table.insert(allItems, a) end

    for _, item in ipairs(allItems) do
        createConfigRow(item)
    end
end

local function openConfigWindow()
    if not configWindow then
        configWindow = g_ui.displayUI('controller_config')
        if configWindow then
            configList = configWindow:getChildById('configList')
        end
    end
    if not configWindow then
        g_logger.log(LogWarning, 'Failed to open controller config window')
        return
    end
    populateConfigList()
    configWindow:show()
    configWindow:raise()
    configWindow:focus()
end

-- -----------------------------------------------------------------------------
-- Eventos do Controle

-- Normaliza o nome do gatilho: o SDL pode reportar como "triggerleft"/
-- "triggerright" (eixo) ou "lefttrigger"/"righttrigger" (mapping/bot�o).
local function normalizeTriggerName(name)
    if name == "triggerleft" or name == "lefttrigger" then return "triggerleft"
    elseif name == "triggerright" or name == "righttrigger" then return "triggerright" end
    return nil
end

local function onControllerButton(button, pressed)
    if not enabled then return end

    -- Gatilhos podem chegar como eventos de BOT�O em alguns controles/mappings
    -- (ex.: controles com gatilho digital). Trata igual ao eixo.
    local triggerName = normalizeTriggerName(button)
    if triggerName then
        if not pressed then return end
        local keyCombo = bindings[triggerName]
        if keyCombo then
            triggerHotkey(keyCombo)
        else
            g_logger.log(LogWarning, tr('Trigger %s pressed, but no key is assigned to it. Assign one in Options -> Controller -> Configure Buttons.', button))
        end
        return
    end

    -- Movimenta��o D-Pad (Hardcoded)
    local isDpad = false
    if button == "dpup" then dpadState.up = pressed; isDpad = true
    elseif button == "dpdown" then dpadState.down = pressed; isDpad = true
    elseif button == "dpleft" then dpadState.left = pressed; isDpad = true
    elseif button == "dpright" then dpadState.right = pressed; isDpad = true
    end

    if isDpad then
        refreshCombinedMovement()
        return
    end

    -- Outros bot�es
    if not pressed then return end

    local keyCombo = bindings[button]

    triggerHotkey(keyCombo)
end

local function onControllerAxis(axis, value)
    if not enabled then return end

    -- Para gatilhos (L2/R2), tratamos como bot�es se passarem de um threshold
    local triggerName = normalizeTriggerName(axis)
    if triggerName then
        local threshold = 0.4
        local isPressed = value > threshold
        if isPressed and not axisState[triggerName] then
            onControllerButton(triggerName, true)
        end
        axisState[triggerName] = isPressed
        return
    end

    if axis ~= "leftx" and axis ~= "lefty" and axis ~= "rightx" and axis ~= "righty" then
        -- Eixo desconhecido: ajuda a diagnosticar gatilhos com nome diferente
        g_logger.log(LogInfo, tr('Unknown controller axis: %s = %s', axis, value))
    end

    -- Walking / Turning com Sticks
    axisState[axis] = value
    refreshCombinedMovement()
end

-- -----------------------------------------------------------------------------
-- Lifecycle
-- -----------------------------------------------------------------------------

function setEnabled(value)
    enabled = value
    g_settings.set("controllerEnabled", value)
    g_settings.save()

    if not enabled then
        stopMoving()
    end

    if not g_controller then return end

    if enabled then
        g_controller.setButtonCallback(onControllerButton)
        g_controller.setAxisCallback(onControllerAxis)
        if g_controller.setConnectCallback then
            if not connectCallback then
                connectCallback = function() updateStatusLabel() end
            end
            g_controller.setConnectCallback(connectCallback)
        end
    else
        g_controller.setButtonCallback(nil)
        g_controller.setAxisCallback(nil)
        if g_controller.setConnectCallback then
            g_controller.setConnectCallback(nil)
        end
    end

    updateStatusLabel()
end

local function setupPanel()
    if not modules.client_options then return end

    local optionsPanel = modules.client_options.getPanel()
    if not optionsPanel then
        scheduleEvent(setupPanel, 250)
        return
    end

    controllerPanel = optionsPanel:recursiveGetChildById('controllerPanel')
    if not controllerPanel then
        scheduleEvent(setupPanel, 250)
        return
    end

    enableCheckbox = controllerPanel:recursiveGetChildById('enableController')
    statusLabel    = controllerPanel:recursiveGetChildById('controllerStatus')
    configureButton = controllerPanel:recursiveGetChildById('configureButton')

    enabled = g_settings.getBoolean('controllerEnabled', true)

    if enableCheckbox then
        enableCheckbox.onCheckChange = function(widget, checked) setEnabled(checked) end
        enableCheckbox:setChecked(enabled)
    end

    if configureButton then
        configureButton.onClick = function() openConfigWindow() end
    end

    setEnabled(enabled)
end

function init()
    if not g_controller then return end

    loadBindings()

    g_controller.setButtonCallback(onControllerButton)
    g_controller.setAxisCallback(onControllerAxis)
    if g_controller.setConnectCallback then
        if not connectCallback then
            connectCallback = function() updateStatusLabel() end
        end
        g_controller.setConnectCallback(connectCallback)
    end

    addEvent(setupPanel)

    -- Atualiza status se o controle for plugado/desplugado
    connect(g_app, { onTerminate = function() saveBindings() end })
end

function terminate()
    if statusEvent then
        removeEvent(statusEvent)
        statusEvent = nil
    end

    if not g_controller then return end

    g_controller.setButtonCallback(nil)
    g_controller.setAxisCallback(nil)
    if g_controller.setConnectCallback then
        g_controller.setConnectCallback(nil)
    end

    saveBindings()

    if configWindow then
        configWindow:destroy()
    end
    controllerPanel = nil
    statusLabel     = nil
    enableCheckbox  = nil
    configureButton = nil
    configWindow    = nil
    configList      = nil
    slotButtons     = {}
    bindings  = {}
    axisState = {}
end
