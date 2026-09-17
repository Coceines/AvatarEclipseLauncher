-- ============================================================
-- game_cooking - CLIENT (Apenas Interface Visual)
-- Forja (game_crafting) fundida com o minigame da pesca
-- (game_fishing): escolhe a receita, clica em "Cook" e acerta a
-- "mexida" da panela STIR_TOTAL vezes seguidas pra comida sair.
-- Toda a logica, validacao e recipes fica no SERVER
-- (data/lib/cookingSystem.lua, opcode 107).
-- ============================================================

local COOKING_OPCODE = 107

-- ============================================================
-- MINIGAME (copiado do game_fishing, tema cozinha)
-- ============================================================
local BAR_WIDTH = 324        -- Vao interno da hud.png
local GREEN_ZONE_WIDTH = 16  -- ~5% da barra
local SLIDER_SPEED = 2       -- ~2.6s de ponta a ponta
local SLIDER_WIDTH = 4       -- Largura do marcador
local BAR_HEIGHT = 15        -- Altura do vao da arte
local HUD_ICON = 34          -- Tamanho da frigideira no medalhao
local UPDATE_INTERVAL = 16   -- 60 FPS
local MAX_BOUNCES = 5        -- Sem mexer por 5 quicadas = desiste

-- ============================================================
-- VARIAVEIS DO MODULO
-- ============================================================
local cookingWindow = nil   -- janela de receitas (copia da forja)
local minigameWindow = nil  -- HUD da mexida (copia da pesca)
local overlay = nil
local destroyOverlay  -- forward-declare: usada em terminate() antes da definicao

-- Estado do minigame
local sliderPosition = 0
local sliderDirection = 1
local greenZonePosition = 0
local minigameActive = false
local updateEvent = nil
local bounceCount = 0

-- Medalhao: frigideira + mexidas restantes
local toolIcon = nil
local toolClientId = 0
local stirsRemaining = 0

function init()
  cookingWindow = g_ui.displayUI('cooking')
  cookingWindow:hide()

  cookingWindow.onEscape = hide
  cookingWindow:getChildById("closeButton").onClick = hide

  -- Botoes APENAS enviam pedidos ao server
  cookingWindow:getChildById("craftButton").onClick = function() sendCraftRequest(false) end
  cookingWindow:getChildById("craftAllButton").onClick = function() sendCraftRequest(true) end

  -- Recipe selection (apenas seleciona visualmente)
  cookingWindow:recursiveGetChildById("recipeList").onChildFocusChange = onRecipeSelected

  -- Enquanto a janela de receitas esta aberta, espaco e consumido
  -- (nao vaza pra hotkey/ataque) e ESC fecha.
  cookingWindow.onKeyDown = function(self, keyCode, keyboardModifiers)
    if keyCode == KeyEscape then
      hide()
      return true
    end
    return true -- consome tudo
  end

  -- Fechar ao andar
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })

  if g_game.getLocalPlayer() then
    connect(g_game.getLocalPlayer(), {
      onWalk = onPlayerWalk,
      onPositionChange = onPlayerPositionChange,
    })
  end

  ProtocolGame.registerExtendedOpcode(COOKING_OPCODE, onExtendedOpcode)
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })

  if g_game.getLocalPlayer() then
    disconnect(g_game.getLocalPlayer(), {
      onWalk = onPlayerWalk,
      onPositionChange = onPlayerPositionChange,
    })
  end

  pcall(function() ProtocolGame.unregisterExtendedOpcode(COOKING_OPCODE) end)
  destroyOverlay()
  hideMinigame(true)

  if cookingWindow then
    cookingWindow:destroy()
    cookingWindow = nil
  end
end

function onGameStart()
  if g_game.getLocalPlayer() then
    connect(g_game.getLocalPlayer(), {
      onWalk = onPlayerWalk,
      onPositionChange = onPlayerPositionChange,
    })
  end
end

function onGameEnd()
  hide()
  hideMinigame(true)
end

-- ============================================================
-- FECHAR AO ANDAR
-- ============================================================

function onPlayerWalk()
  if minigameWindow and minigameWindow:isVisible() then
    hideMinigame()
  end
  if cookingWindow and cookingWindow:isVisible() then
    hide()
  end
end

function onPlayerPositionChange()
  if minigameWindow and minigameWindow:isVisible() then
    hideMinigame()
  end
  if cookingWindow and cookingWindow:isVisible() then
    hide()
  end
end

-- ============================================================
-- RECEBER DADOS DO SERVER (apenas exibir)
-- ============================================================

function onExtendedOpcode(protocol, code, buffer)
  if code ~= COOKING_OPCODE then return end

  local json_ok, json_data = pcall(function() return json.decode(buffer) end)

  if not json_ok then
    g_logger.error("[Cooking] JSON error")
    return false
  end

  local action = json_data.action

  if action == "open" then
    -- Server envia as receitas para exibir
    displayCookingWindow(json_data.skill, json_data.recipes)
  elseif action == "minigame" then
    -- Server cobrou os ingredientes e mandou abrir a mexida da panela
    hide()
    openMinigameWindow(json_data.ticks, json_data.toolId, json_data.remaining)
  elseif action == "stir_result" then
    -- Mexida certa: mostra quantas faltam e recomeca a barra
    setHudStirs(json_data.remaining)
    scheduleEvent(startMinigame, 1200)
  elseif action == "result" then
    -- Resultado final (5 acertos ou queimou)
    showResult(json_data.success, json_data.error or json_data.message or "")
  elseif action == "close" then
    hide()
    hideMinigame()
  end
end

-- ============================================================
-- EXIBICAO DAS RECEITAS (copiado do game_crafting)
-- ============================================================

-- O server ja envia client IDs (via ItemType:getClientId())
local function resolveClientId(clientId)
  return clientId or 0
end

function displayCookingWindow(skill, recipes)
  cookingWindow:setText("Cooking")

  local skillBar = cookingWindow:getChildById("skillBar")
  if skillBar then skillBar:hide() end
  local skillLabel = cookingWindow:getChildById("skillLabel")
  if skillLabel then skillLabel:hide() end

  local recipeList = cookingWindow:recursiveGetChildById("recipeList")
  recipeList:destroyChildren()

  for i, recipe in ipairs(recipes) do
    local widget = g_ui.createWidget('Recipe', recipeList)
    widget:setText("T" .. recipe.tier .. " " .. recipe.name)
    widget.recipe = recipe
    widget.globalId = recipe.globalId
  end

  recipeList:focusChild(recipeList:getFirstChild())
  show()
end

-- ============================================================
-- SELECIONAR RECIPE (apenas exibe detalhes)
-- ============================================================

function onRecipeSelected(w, child)
  local recipe = child.recipe
  if not recipe then return end

  cookingWindow:getChildById("cost"):setText(recipe.cost .. " Gold")

  local item = cookingWindow:recursiveGetChildById("recipeItem")
  item:setItemId(resolveClientId(recipe.spriteId))
  item:setVirtual(true)
  item:setItemCount(recipe.count)

  local panel = cookingWindow:recursiveGetChildById("ingredientsPanel")
  panel:destroyChildren()
  for _, ingredient in ipairs(recipe.ingredients) do
    local widget = g_ui.createWidget('Item', panel)
    widget:setItemId(resolveClientId(ingredient.spriteId))
    widget:setVirtual(true)
    widget:setItemCount(ingredient.count)
    widget:setTooltip(ingredient.playerCount .. "/" .. ingredient.count .. " " .. ingredient.name)
  end

  cookingWindow:recursiveGetChildById("recipeDesc"):setText(recipe.desc)

  local label = cookingWindow:recursiveGetChildById("recipeLabel")
  label:setText(recipe.name)
  label:setWidth(label:getTextSize().width)

  local maxAmount = 1
  for _, ingredient in ipairs(recipe.ingredients) do
    local canMake = math.floor(ingredient.playerCount / ingredient.count)
    if canMake < maxAmount or maxAmount == 1 then
      maxAmount = canMake
    end
  end
  if maxAmount < 1 then maxAmount = 1 end

  cookingWindow:recursiveGetChildById("craftButton"):setEnabled(maxAmount > 0)
  cookingWindow:recursiveGetChildById("craftAllButton"):setEnabled(maxAmount > 0)
end

-- ============================================================
-- ENVIAR PEDIDO AO SERVER (apenas envia, nao valida)
-- ============================================================

function sendCraftRequest(all)
  local recipeList = cookingWindow:recursiveGetChildById("recipeList")
  local focusedChild = recipeList:getFocusedChild()
  if not focusedChild or not focusedChild.globalId then return end

  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(COOKING_OPCODE, json.encode({
      action = "craft",
      recipeId = focusedChild.globalId,
      amount = 1,
    }))
  end
end

-- ============================================================
-- RESULTADO FINAL (apenas exibe)
-- ============================================================

function showResult(success, message)
  destroyOverlay()
  hideMinigame(true)
  if cookingWindow then
    cookingWindow:hide()
  end
  addEvent(function()
    displayInfoBox(tr(success and 'Success' or 'Failed'), message)
  end, 50)
end

-- ============================================================
-- ABRIR/FECHAR JANELA DE RECEITAS
-- ============================================================

local function createOverlay()
  if overlay then return end
  local root = modules.game_interface and modules.game_interface.getRootPanel()
  if not root then return end
  overlay = g_ui.createWidget('Panel', root)
  overlay:setId('cookingOverlay')
  overlay:setBackgroundColor('#000000CC')
  overlay:fill('parent')
  overlay.onMousePress = function() end
  overlay.onMouseRelease = function() end
end

destroyOverlay = function()
  if overlay then
    overlay:destroy()
    overlay = nil
  end
end

function show()
  if cookingWindow then
    createOverlay()
    cookingWindow:show()
    cookingWindow:raise()
    cookingWindow:focus()
    cookingWindow:grabKeyboard()
  end
end

function hide()
  if cookingWindow then
    cookingWindow:hide()
    cookingWindow:ungrabKeyboard()
    destroyOverlay()
    if modules.game_interface then
      modules.game_interface.getRootPanel():focus()
    end
  end
end

-- ============================================================
-- MINIGAME DA MEXIDA (copiado do game_fishing, tema cozinha)
-- ============================================================

-- Enquanto a HUD da mexida esta aberta, o teclado INTEIRO e dela
-- ("supremo"): Space NAO chega no chat, hotkeys/ataque NAO disparam.
function bindMinigameKeys()
  if not minigameWindow then return end

  minigameWindow.onKeyDown = function(self, keyCode, keyboardModifiers)
    if keyCode == KeySpace then
      -- Consome SEMPRE, mesmo entre tentativas
      onSpacePress()
      return true
    elseif keyCode == KeyEscape then
      hideMinigame()
      return true
    end
    return false
  end

  minigameWindow.onKeyPress = function(self, keyCode, keyboardModifiers, autoRepeatTicks)
    return true
  end

  minigameWindow:grabKeyboard()
end

-- Centraliza a HUD no mapa (este client nao tem centerOnGameMap nativo)
function centerMinigameWindow()
  if not minigameWindow then return end
  local parent = minigameWindow:getParent()
  local parentW, parentH = 0, 0
  if parent then
    parentW = parent:getWidth()
    parentH = parent:getHeight()
  end
  local w = minigameWindow:getWidth()
  local h = minigameWindow:getHeight()
  minigameWindow:breakAnchors()
  minigameWindow:setPosition({
    x = math.max(0, math.floor((parentW - w) / 2)),
    y = math.max(0, math.floor((parentH - h) / 2)),
  })
  minigameWindow:bindRectToParent()
end

function openMinigameWindow(ticks, toolId, remaining)
  if minigameWindow then
    minigameWindow:show()
    minigameWindow:raise()
    minigameWindow:focus()
    centerMinigameWindow()
    bindMinigameKeys()
    stopMinigame()
    startMinigame()
    return
  end

  local root = modules.game_interface and modules.game_interface.getRootPanel()
  if not root then return end

  minigameWindow = g_ui.createWidget('UIWidget', root)
  if not minigameWindow then
    g_logger.error("Failed to create cooking minigame window")
    return
  end

  local HUD_W, HUD_H = 420, 64
  minigameWindow:setId('cookingMinigameWindow')
  minigameWindow:setSize({width = HUD_W, height = HUD_H})
  minigameWindow:setImageSource('/modules/game_cooking/imagens/hud')
  minigameWindow:setImageSmooth(true)
  minigameWindow:setBackgroundColor('#00000000')
  minigameWindow:setDraggable(true)
  minigameWindow:setFocusable(true)

  minigameWindow.onDragEnter = function(self, mousePos)
    self:breakAnchors()
    self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
    return true
  end

  minigameWindow.onDragMove = function(self, mousePos, mouseMoved)
    local ref = self.movingReference
    if not ref then return false end
    self:setPosition({ x = mousePos.x - ref.x, y = mousePos.y - ref.y })
    self:bindRectToParent()
    return true
  end

  minigameWindow.onDragLeave = function(self, droppedWidget, mousePos)
    return true
  end

  local barLeft = math.floor(HUD_W * 0.1899)
  local barTop  = math.floor(HUD_H * 0.4286)

  -- Medalhao: frigideira + mexidas restantes
  toolIcon = g_ui.createWidget('UIItem', minigameWindow)
  toolIcon:setId('toolIcon')
  toolIcon:setSize({width = HUD_ICON, height = HUD_ICON})
  toolIcon:setVirtual(true)
  toolIcon:setPhantom(true)
  toolIcon:setFont('verdana-11px-rounded')
  toolIcon:setImageSource('')
  toolIcon:setBackgroundColor('#00000000')
  toolIcon:setBorderWidth(0)
  toolIcon.onItemChange = function(self)
    self:setImageSource('')
  end
  toolIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
  toolIcon:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  toolIcon:setMarginLeft(math.floor(HUD_W * 0.1003 - HUD_ICON / 2))
  toolIcon:setMarginTop(math.floor(HUD_H * 0.5015 - HUD_ICON / 2))

  setHudStirs(remaining, toolId)

  -- Trilho vermelho ocupando exatamente o vao da arte
  local redBar = g_ui.createWidget('UIWidget', minigameWindow)
  redBar:setId('redBar')
  redBar:setBackgroundColor('#b02c2cb0')
  redBar:setSize({width = BAR_WIDTH, height = BAR_HEIGHT})
  redBar:addAnchor(AnchorTop, 'parent', AnchorTop)
  redBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  redBar:setMarginLeft(barLeft)
  redBar:setMarginTop(barTop)

  minigameWindow.onGeometryChange = function()
    syncBarChildren()
  end
  redBar.onGeometryChange = function()
    syncBarChildren()
  end

  centerMinigameWindow()

  createGreenZone()
  createSlider()

  minigameWindow:show()
  minigameWindow:raise()
  minigameWindow:focus()
  bindMinigameKeys()

  startMinigame()
end

-- Medalhao: mostra a frigideira e quantas mexidas faltam
function setHudStirs(remaining, clientId)
  if clientId and tonumber(clientId) and tonumber(clientId) > 0 then
    toolClientId = tonumber(clientId)
  end
  if remaining ~= nil and tonumber(remaining) then
    stirsRemaining = math.max(0, math.floor(tonumber(remaining)))
  end

  if toolIcon and not toolIcon:isDestroyed() and toolClientId > 0 then
    toolIcon:setItemId(toolClientId)
    toolIcon:setItemCount(math.max(1, stirsRemaining))
  end
end

function syncBarChildren()
  if not minigameWindow then return end
  local redBar = minigameWindow:getChildById('redBar')
  if not redBar then return end

  local slider = minigameWindow:getChildById('slider')
  if slider then
    local clamped = math.max(0, math.min(sliderPosition, BAR_WIDTH - SLIDER_WIDTH))
    slider:setMarginLeft(clamped)
  end

  local greenZone = minigameWindow:getChildById('greenZone')
  if greenZone then
    local clampedGreen = math.max(0, math.min(greenZonePosition, BAR_WIDTH - GREEN_ZONE_WIDTH))
    greenZone:setMarginLeft(clampedGreen)
  end
end

function createGreenZone()
  if not minigameWindow then return end
  local redBar = minigameWindow:getChildById('redBar')
  if not redBar then return end

  local oldGreenZone = minigameWindow:getChildById('greenZone')
  if oldGreenZone then
    oldGreenZone:destroy()
  end

  local greenZone = g_ui.createWidget('UIWidget', minigameWindow)
  greenZone:setId('greenZone')
  greenZone:setBackgroundColor('#3fbf4ad0')
  greenZone:setSize({width = GREEN_ZONE_WIDTH, height = BAR_HEIGHT})

  greenZone:addAnchor(AnchorTop, 'redBar', AnchorTop)
  greenZone:addAnchor(AnchorLeft, 'redBar', AnchorLeft)
  greenZone:setMarginTop(0)
  greenZone:setMarginLeft(greenZonePosition)

  syncBarChildren()
end

function createSlider()
  if not minigameWindow then return end
  local redBar = minigameWindow:getChildById('redBar')
  if not redBar then return end

  local oldSlider = minigameWindow:getChildById('slider')
  if oldSlider then
    oldSlider:destroy()
  end

  local slider = g_ui.createWidget('UIWidget', minigameWindow)
  slider:setId('slider')
  slider:setBackgroundColor('#ffffff')
  slider:setBorderColor('#000000')
  slider:setBorderWidth(1)
  slider:setSize({width = SLIDER_WIDTH, height = BAR_HEIGHT})

  slider:addAnchor(AnchorTop, 'redBar', AnchorTop)
  slider:addAnchor(AnchorLeft, 'redBar', AnchorLeft)
  slider:setMarginTop(0)
  slider:setMarginLeft(sliderPosition)

  syncBarChildren()
end

-- Espaco: manda o resultado da mexida pro server
function onSpacePress()
  if not minigameActive or not minigameWindow or not minigameWindow:isVisible() then
    return false
  end

  local success = isSliderInGreenZone()

  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(COOKING_OPCODE, json.encode({
      action = "stir",
      success = success
    }))
  end

  stopMinigame()
  return true
end

function startMinigame()
  sliderPosition = 0
  sliderDirection = 1
  bounceCount = 0

  greenZonePosition = math.random(50, BAR_WIDTH - GREEN_ZONE_WIDTH - 50)

  createGreenZone()
  createSlider()

  minigameActive = true

  scheduleEvent(function() updateSlider() end, UPDATE_INTERVAL)
end

function stopMinigame()
  minigameActive = false
end

function updateSlider()
  if not minigameActive or not minigameWindow then
    return
  end

  sliderPosition = sliderPosition + (SLIDER_SPEED * sliderDirection)

  if sliderPosition >= BAR_WIDTH - SLIDER_WIDTH then
    sliderPosition = BAR_WIDTH - SLIDER_WIDTH
    sliderDirection = -1
    bounceCount = bounceCount + 1
  elseif sliderPosition <= 0 then
    sliderPosition = 0
    sliderDirection = 1
    bounceCount = bounceCount + 1
  end

  -- Sem mexer por MAX_BOUNCES quicadas: desiste (fecha e avisa o server)
  if bounceCount >= MAX_BOUNCES then
    stopMinigame()
    scheduleEvent(function() hideMinigame() end, 2000)
    return
  end

  local slider = minigameWindow:getChildById('slider')
  if slider then
    slider:setMarginLeft(sliderPosition)
  end

  local greenZone = minigameWindow:getChildById('greenZone')
  if greenZone then
    greenZone:setMarginLeft(greenZonePosition)
  end

  if minigameActive then
    scheduleEvent(function() updateSlider() end, UPDATE_INTERVAL)
  end
end

function isSliderInGreenZone()
  return sliderPosition >= greenZonePosition and
         sliderPosition <= greenZonePosition + GREEN_ZONE_WIDTH
end

-- Fecha a HUD da mexida e avisa o server pra limpar o estado
function hideMinigame(force)
  if minigameWindow then
    minigameWindow:ungrabKeyboard()
    minigameWindow:hide()
    stopMinigame()

    if not force then
      local protocolGame = g_game.getProtocolGame()
      if protocolGame then
        protocolGame:sendExtendedOpcode(COOKING_OPCODE, json.encode({ action = 'cancel' }))
      end
    end
  end
end