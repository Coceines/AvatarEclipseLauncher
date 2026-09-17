-- Fishing Module
-- Implements a fishing minigame with a sliding bar interface

-- Configuration
local FISHING_OPCODE = 103 -- Unique opcode for fishing communication
local BAR_WIDTH = 324 -- Vao interno da hud.png, de ouro a ouro (0.7728 da arte)
local GREEN_ZONE_WIDTH = 16 -- ~5% da barra, mesma dificuldade de sempre
local SLIDER_SPEED = 2 -- ~2.6s de ponta a ponta
local SLIDER_WIDTH = 4 -- Width of the slider indicator
local BAR_HEIGHT = 15 -- Altura do vao da arte
local HUD_ICON = 34 -- Tamanho do peixe dentro do medalhao
local UPDATE_INTERVAL = 16 -- Aiming for 60 FPS (16ms between frames)

-- Module variables
local fishingWindow = nil
local hudPosition = nil   -- onde o jogador largou a HUD (persiste na sessao)
local contentPanel = nil
local wormIcon = nil
local wormClientId = 0
local wormAmount = 0
local sliderPosition = 0
local sliderDirection = 1
local greenZonePosition = 0
local fishingActive = false
local updateEvent = nil
local debugMode = false -- Enable to show debug messages
local attemptsCount = 0
-- Default ticks (= attempts) for land fishing. Overwritten by the server's
-- "open" payload based on the player's selected fishing accessory.
local MAX_ATTEMPTS = 5
local bounceCount = 0
local MAX_BOUNCES = 5

-- Debug log function
function debugLog(message)
  if debugMode and message then
    -- Also print to console for immediate visibility
  end
end

-- Initialize the module
function init()
  connect(g_game, {
    onGameStart = create,
    onGameEnd = destroy,
    onKeyDown = handleKeyDown
  })

  -- Close fishing window automatically when the player moves
  connect(LocalPlayer, {
    onWalk = onLocalPlayerWalk,
    onPositionChange = onLocalPlayerPositionChange
  })

  -- Register the opcode handler for server communications
  ProtocolGame.registerExtendedOpcode(FISHING_OPCODE, onExtendedOpcode)
  
  -- Handle text messages to prevent errors
  connect(g_game, { onTextMessage = handleTextMessage })
  
  -- Initialize if already logged in
  if g_game.isOnline() then
    create()
  end
  
  debugLog("Fishing module initialized")
end

-- Handler for text messages (to prevent errors)
function handleTextMessage(mode, text)
  -- Only handle fishing related messages to prevent errors in log
  if string.find(text, "fish") or string.find(text, "worm") then
    debugLog("Captured fishing text message: " .. text)
    return true -- This prevents "unhandled" errors
  end
  return false -- Let other handlers process it
end

-- Clean up when module unloads
function terminate()
  disconnect(g_game, {
    onGameStart = create,
    onGameEnd = destroy,
    onKeyDown = handleKeyDown,
    onTextMessage = handleTextMessage
  })

  -- Disconnect movement hooks
  disconnect(LocalPlayer, {
    onWalk = onLocalPlayerWalk,
    onPositionChange = onLocalPlayerPositionChange
  })

  -- Unregister the opcode
  ProtocolGame.unregisterExtendedOpcode(FISHING_OPCODE)

  -- Clean up
  destroy()
  
  debugLog("Fishing module terminated")
end

-- Auto-close on player movement
function onLocalPlayerWalk(player, newPos, oldPos)
  if fishingWindow and fishingWindow:isVisible() then
    debugLog("Player walked - closing fishing window")
    hide()
  end
end

function onLocalPlayerPositionChange(player, newPos, oldPos)
  if fishingWindow and fishingWindow:isVisible() then
    debugLog("Player position changed - closing fishing window")
    hide()
  end
end

-- Create interface elements
function create()
  -- Nothing to create until fishing window is opened
  debugLog("Game started, waiting for fishing window request")
end

-- Clean up interface
function destroy()
  -- Stop fishing if active
  stopFishing()

  -- Destroy window if it exists
  if fishingWindow then
    fishingWindow:destroy()
    fishingWindow = nil
    wormIcon = nil
    debugLog("Fishing window destroyed")
  end
end

-- Handle messages from server
function onExtendedOpcode(protocol, opcode, buffer)
  -- Verify this is our opcode
  if opcode ~= FISHING_OPCODE then
    return
  end
  
  -- Parse the message
  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)
  
  if not json_status then
    g_logger.error("Fishing JSON error: " .. json_data)
    return
  end
  
  debugLog("Received message: " .. buffer)
  
  -- Process messages from server
  if json_data.action == "result" then
    if json_data.worms ~= nil then
      setHudWorms(json_data.worms)
    end
    -- stop: servidor mandou encerrar (ficou sem isca) -- fecha na hora, sem
    -- esperar as tentativas restantes.
    if json_data.stop then
      hide()
      return
    end
    showFishingResult(json_data.success, json_data.message)
  elseif json_data.action == "open" then
    if json_data.worms ~= nil or json_data.wormId then
      setHudWorms(json_data.worms, json_data.wormId)
    end
    -- Server tells us how many ticks (= attempts) this run gets, based on
    -- the player's active fishing accessory. Falls back to 5 if missing.
    local serverTicks = tonumber(json_data.ticks)
    if serverTicks and serverTicks > 0 then
      MAX_ATTEMPTS = serverTicks
    end
    openFishingWindow()
  end
end

-- Medalhao: mostra o worm e quantos restam. O servidor manda o numero na
-- abertura e a cada tentativa (o worm e gasto por lance).
function setHudWorms(amount, clientId)
  if clientId and tonumber(clientId) and tonumber(clientId) > 0 then
    wormClientId = tonumber(clientId)
  end
  if amount ~= nil and tonumber(amount) then
    wormAmount = math.max(0, math.floor(tonumber(amount)))
  end

  if wormIcon and not wormIcon:isDestroyed() and wormClientId > 0 then
    wormIcon:setItemId(wormClientId)
    -- O proprio UIItem desenha o numero no canto, igual a uma pilha de itens
    -- na mochila (precisa de fonte + item stackable + count > 1).
    wormIcon:setItemCount(wormAmount)
  end
end

-- Enquanto a janela de pesca esta aberta, o teclado INTEIRO e da pesca
-- ("supremo"): a janela vira o unico receptor de teclas (grabKeyboard), entao
-- Space NAO chega no chat, hotkeys/ataque NAO disparam e nenhum outro sistema
-- do jogo recebe tecla. Tudo volta ao normal quando a janela fecha.
function bindFishingKeys()
  if not fishingWindow then return end

  fishingWindow.onKeyDown = function(self, keyCode, keyboardModifiers)
    if keyCode == KeySpace then
      -- Consome SEMPRE, mesmo entre tentativas: o espaco e do minigame.
      onSpacePress()
      return true
    elseif keyCode == KeyEscape then
      hide()
      return true
    end
    return false
  end

  -- Consome todos os keypress (e onde hotkeys/ataque se encaixariam).
  fishingWindow.onKeyPress = function(self, keyCode, keyboardModifiers, autoRepeatTicks)
    return true
  end

  fishingWindow:grabKeyboard()
end

-- Centraliza a HUD no mapa (este client nao tem centerOnGameMap nativo).
-- O pai da janela e o root panel do game_interface, entao centralizar nele
-- equivale a centralizar na area do mapa.
function centerFishingWindow()
  if not fishingWindow then return end
  local parent = fishingWindow:getParent()
  local parentW, parentH = 0, 0
  if parent then
    parentW = parent:getWidth()
    parentH = parent:getHeight()
  end
  local w = fishingWindow:getWidth()
  local h = fishingWindow:getHeight()
  fishingWindow:breakAnchors()
  fishingWindow:setPosition({
    x = math.max(0, math.floor((parentW - w) / 2)),
    y = math.max(0, math.floor((parentH - h) / 2)),
  })
  fishingWindow:bindRectToParent()
end

-- Create and show the fishing window
function openFishingWindow()
  -- If window already exists, just show it
  if fishingWindow then
    fishingWindow:show()
    fishingWindow:raise()
    fishingWindow:focus()
    centerFishingWindow()
    bindFishingKeys()
    debugLog("Showing existing fishing window")
    -- Reset state and UI when reopening
    attemptsCount = 0
    stopFishing()
    -- Rebind keyboard and restart minigame
    g_keyboard.bindKeyDown('Space', onSpacePress)
    g_keyboard.bindKeyDown('Escape', hide)
    startFishing()
    return
  end
  
  debugLog("Creating fishing window")

  -- HUD montado em cima da arte hud.png (2143x329). As posicoes abaixo sao
  -- as medidas REAIS tiradas da imagem, em fracao do tamanho dela:
  --   vao interno da barra ......... x 0.1899..0.9627   y 0.4286..0.6657
  --   centro do medalhao ........... x 0.1003           y 0.5015
  -- Mantendo a janela na mesma proporcao (6.51:1) tudo encaixa sozinho.
  fishingWindow = g_ui.createWidget('UIWidget', modules.game_interface.getRootPanel())
  if not fishingWindow then
    g_logger.error("Failed to create fishing window")
    return
  end
  attemptsCount = 0

  local HUD_W, HUD_H = 420, 64
  fishingWindow:setId('fishingWindow')
  fishingWindow:setSize({width = HUD_W, height = HUD_H})
  fishingWindow:setImageSource('/modules/game_fishing/imagens/hud')
  fishingWindow:setImageSmooth(true)
  fishingWindow:setBackgroundColor('#00000000')
  fishingWindow:setDraggable(true)
  fishingWindow:setFocusable(true)

  -- setDraggable so LIBERA o arrasto; quem move o widget sao os handlers.
  -- Mesma logica do UIWindow do corelib (quebra as ancoras, guarda o ponto de
  -- pega e prende o retangulo no pai pra HUD nao sair da tela).
  fishingWindow.onDragEnter = function(self, mousePos)
    self:breakAnchors()
    self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
    return true
  end

  fishingWindow.onDragMove = function(self, mousePos, mouseMoved)
    local ref = self.movingReference
    if not ref then return false end
    self:setPosition({ x = mousePos.x - ref.x, y = mousePos.y - ref.y })
    self:bindRectToParent()
    -- Guarda onde o jogador largou: a HUD e recriada a cada pescaria e
    -- voltaria pro canto padrao sem isso.
    hudPosition = { x = self:getX(), y = self:getY() }
    return true
  end

  fishingWindow.onDragLeave = function(self, droppedWidget, mousePos)
    return true
  end

  -- Volta pra ultima posicao escolhida nesta sessao.
  if hudPosition then
    fishingWindow:breakAnchors()
    fishingWindow:setPosition(hudPosition)
    fishingWindow:bindRectToParent()
  end

  contentPanel = fishingWindow

  local barLeft = math.floor(HUD_W * 0.1899)
  local barTop  = math.floor(HUD_H * 0.4286)

  -- Medalhao: worm + quantidade restante.
  wormIcon = g_ui.createWidget('UIItem', contentPanel)
  wormIcon:setId('wormIcon')
  wormIcon:setSize({width = HUD_ICON, height = HUD_ICON})
  wormIcon:setVirtual(true)
  wormIcon:setPhantom(true)
  wormIcon:setFont('verdana-11px-rounded')
  wormIcon:setImageSource('')
  wormIcon:setBackgroundColor('#00000000')
  wormIcon:setBorderWidth(0)
  -- UIItem:onItemChange chama updateItemRarity, que reaplica a moldura padrao
  -- (/images/ui/item) TODA vez que o item muda. Sobrescrevendo o evento neste
  -- widget o medalhao fica so com o sprite do worm.
  wormIcon.onItemChange = function(self)
    self:setImageSource('')
  end
  wormIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
  wormIcon:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  wormIcon:setMarginLeft(math.floor(HUD_W * 0.1003 - HUD_ICON / 2))
  wormIcon:setMarginTop(math.floor(HUD_H * 0.5015 - HUD_ICON / 2))

  setHudWorms(wormAmount, wormClientId)

  -- Trilho vermelho ocupando exatamente o vao da arte.
  local redBar = g_ui.createWidget('UIWidget', contentPanel)
  redBar:setId('redBar')
  redBar:setBackgroundColor('#b02c2cb0')
  redBar:setSize({width = BAR_WIDTH, height = BAR_HEIGHT})
  redBar:addAnchor(AnchorTop, 'parent', AnchorTop)
  redBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  redBar:setMarginLeft(barLeft)
  redBar:setMarginTop(barTop)

  fishingWindow.onGeometryChange = function()
    syncBarChildren()
  end
  redBar.onGeometryChange = function()
    syncBarChildren()
  end

  -- Centraliza na area do mapa (nao na tela inteira, que os paineis laterais
  -- deslocam).
  centerFishingWindow()

  createGreenZone()
  createSlider()

  -- Show the window
  fishingWindow:show()
  fishingWindow:raise()
  fishingWindow:focus()
  bindFishingKeys()
  
  -- Directly bind spacebar (catch attempt) and escape (close window).
  g_keyboard.bindKeyDown('Space', onSpacePress)
  g_keyboard.bindKeyDown('Escape', hide)
  
  -- Start the minigame
  startFishing()
  
  debugLog("Fishing window created and minigame started")
end

-- Keep red bar children aligned within bounds (called on geometry change)
function syncBarChildren()
  if not fishingWindow then return end
  local redBar = fishingWindow:getChildById('redBar')
  if not redBar then return end

  local slider = fishingWindow:getChildById('slider')
  if slider then
    local clamped = math.max(0, math.min(sliderPosition, BAR_WIDTH - SLIDER_WIDTH))
    slider:setMarginLeft(clamped)
  end

  local greenZone = fishingWindow:getChildById('greenZone')
  if greenZone then
    local clampedGreen = math.max(0, math.min(greenZonePosition, BAR_WIDTH - GREEN_ZONE_WIDTH))
    greenZone:setMarginLeft(clampedGreen)
  end
end

-- Create the green zone
function createGreenZone()
  if not fishingWindow then return end
  
  local redBar = fishingWindow:getChildById('redBar')
  if not redBar then return end

  -- Remove existing green zone if any
  local oldGreenZone = fishingWindow:getChildById('greenZone')
  if oldGreenZone then
    oldGreenZone:destroy()
  end
  
  -- Create new green zone anchored to redBar (sibling under fishingWindow)
  local greenZone = g_ui.createWidget('UIWidget', fishingWindow)
  greenZone:setId('greenZone')
  greenZone:setBackgroundColor('#3fbf4ad0')
  greenZone:setSize({width = GREEN_ZONE_WIDTH, height = BAR_HEIGHT})
  
  -- Anchor to the top-left of redBar and offset by margin
  greenZone:addAnchor(AnchorTop, 'redBar', AnchorTop)
  greenZone:addAnchor(AnchorLeft, 'redBar', AnchorLeft)
  greenZone:setMarginTop(0)
  greenZone:setMarginLeft(greenZonePosition)
  
  debugLog("Created green zone at position: " .. greenZonePosition)
  syncBarChildren()
end

-- Create or update the slider
function createSlider()
  if not fishingWindow then return end
  
  local redBar = fishingWindow:getChildById('redBar')
  if not redBar then return end

  -- Remove existing slider if any
  local oldSlider = fishingWindow:getChildById('slider')
  if oldSlider then
    oldSlider:destroy()
  end
  
  -- Create new slider anchored to redBar (sibling under fishingWindow)
  local slider = g_ui.createWidget('UIWidget', fishingWindow)
  slider:setId('slider')
  slider:setBackgroundColor('#ffffff')
  slider:setBorderColor('#000000')
  slider:setBorderWidth(1)
  slider:setSize({width = SLIDER_WIDTH, height = BAR_HEIGHT})
  
  -- Anchor to the top-left of redBar and offset by margin
  slider:addAnchor(AnchorTop, 'redBar', AnchorTop)
  slider:addAnchor(AnchorLeft, 'redBar', AnchorLeft)
  slider:setMarginTop(0)
  slider:setMarginLeft(sliderPosition)
  
  debugLog("Created slider at position: " .. sliderPosition)
  syncBarChildren()
end

-- Function for when spacebar is pressed
function onSpacePress()
  if not fishingActive or not fishingWindow or not fishingWindow:isVisible() then
    debugLog("Spacebar pressed but fishing not active")
    return false
  end
  
  -- Determine if slider is in green zone
  local success = isSliderInGreenZone()
  
  debugLog("Space pressed, success: " .. tostring(success) .. 
            ", slider at: " .. sliderPosition .. 
            ", green zone at: " .. greenZonePosition)
  
  -- Send result to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(FISHING_OPCODE, json.encode({
      action = "fish",
      success = success
    }))
    
    debugLog("Sent fishing action to server, success: " .. tostring(success))
  else
    debugLog("Could not send fish action, protocol game not available")
  end
  
  -- Stop the current fishing attempt
  stopFishing()
  
  return true
end

-- Start the fishing minigame
function startFishing()
  -- Reset variables
  sliderPosition = 0
  sliderDirection = 1
  bounceCount = 0

  -- Generate random position for green zone
  greenZonePosition = math.random(50, BAR_WIDTH - GREEN_ZONE_WIDTH - 50)
  
  debugLog("Starting fishing minigame, green zone at: " .. greenZonePosition)
  
  -- Create green zone at the new position
  createGreenZone()

  -- Update the slider position
  createSlider()

  -- Start the slider movement
  fishingActive = true
  
  -- Start the update loop - using standard scheduleEvent
  scheduleEvent(function() updateSlider() end, UPDATE_INTERVAL)
  
  debugLog("Started fishing minigame")
end

-- Stop the fishing minigame
function stopFishing()
  fishingActive = false
  debugLog("Stopped fishing minigame")
end

-- Update the slider position
function updateSlider()
  -- Don't continue if fishing is not active
  if not fishingActive or not fishingWindow then
    debugLog("Update slider canceled - fishing not active")
    return
  end
  
  -- Move the slider
  sliderPosition = sliderPosition + (SLIDER_SPEED * sliderDirection)
  
  -- Bounce at edges - ensure we stay within bounds
  if sliderPosition >= BAR_WIDTH - SLIDER_WIDTH then
    sliderPosition = BAR_WIDTH - SLIDER_WIDTH
    sliderDirection = -1
    bounceCount = bounceCount + 1
    debugLog("Slider hit right edge, changing direction, bounce: " .. bounceCount)
  elseif sliderPosition <= 0 then
    sliderPosition = 0
    sliderDirection = 1
    bounceCount = bounceCount + 1
    debugLog("Slider hit left edge, changing direction, bounce: " .. bounceCount)
  end

  -- Close minigame after MAX_BOUNCES without pressing space
  if bounceCount >= MAX_BOUNCES then
    debugLog("Max bounces reached, fishing failed")
    stopFishing()
    -- Close window after short delay (hide() sends cancel to server)
    scheduleEvent(function() hide() end, 2000)
    return
  end
  
  -- Update the slider position (relative to red bar via margin)
  local redBar = fishingWindow:getChildById('redBar')
  local slider = fishingWindow:getChildById('slider')
  local greenZone = fishingWindow:getChildById('greenZone')
  
  if slider then
    slider:setMarginLeft(sliderPosition)
  else
    debugLog("Could not update slider - elements not found")
  end

  -- Keep green zone aligned with red bar while dragging (re-apply its margin)
  if greenZone then
    greenZone:setMarginLeft(greenZonePosition)
  end
  
  -- Update debug label if in debug mode
  if debugMode then
    local debugLabel = fishingWindow:getChildById('debugLabel')
    if debugLabel then
      debugLabel:setText('Slider: ' .. sliderPosition .. ', Green: ' .. greenZonePosition)
    end
  end
  
  -- If still active, schedule next update using the correct format for scheduleEvent
  if fishingActive then
    scheduleEvent(function() updateSlider() end, UPDATE_INTERVAL)
  end
end

-- Check if slider is in the green zone
function isSliderInGreenZone()
  local inZone = sliderPosition >= greenZonePosition and 
                 sliderPosition <= greenZonePosition + GREEN_ZONE_WIDTH
  debugLog("Checking green zone: " .. tostring(inZone) .. 
           " (slider=" .. sliderPosition .. 
           ", green=" .. greenZonePosition .. 
           "-" .. (greenZonePosition + GREEN_ZONE_WIDTH) .. ")")
  return inZone
end

-- Show the result of fishing
function showFishingResult(success, message)
  if not fishingWindow then
    debugLog("Cannot show result, fishing window does not exist")
    return
  end
  
  debugLog("Showing fishing result: " .. tostring(success) .. ", " .. message)
  
  -- Restart the minigame after a brief delay
  attemptsCount = attemptsCount + 1
  if attemptsCount >= MAX_ATTEMPTS then
    hide()
  else
    scheduleEvent(startFishing, 2000)
    debugLog("Scheduled restart of fishing minigame in 2 seconds")
  end
end

-- Function to hide the window
function hide()
  if fishingWindow then
    -- Devolve o teclado pro jogo: hotkeys/chat/ataque voltam ao normal.
    fishingWindow:ungrabKeyboard()

    -- Unbind keyboard when closing
    g_keyboard.unbindKeyDown('Space')
    g_keyboard.unbindKeyDown('Escape')
    
    -- Notify server to clear active state
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
      protocolGame:sendExtendedOpcode(FISHING_OPCODE, json.encode({ action = 'cancel' }))
      debugLog('Sent cancel action to server')
    end

    fishingWindow:hide()
    stopFishing()
    attemptsCount = 0
    debugLog("Fishing window hidden")
  end
end

-- Handle keypresses
function handleKeyDown(self, keyCode, keyChar, keyboardModifiers)
  -- Only process if fishing is active
  if not fishingActive or not fishingWindow or not fishingWindow:isVisible() then
    return false
  end
  
  -- Check for spacebar (keyCode 32)
  if keyCode == 32 then
    debugLog("Spacebar keypress detected in handleKeyDown")
    return onSpacePress()
  end
  
  -- Let other handlers process the key
  return false
end 
