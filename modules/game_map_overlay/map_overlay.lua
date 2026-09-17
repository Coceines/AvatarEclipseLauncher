local overlayRoot
local overlayMiniMap
local mapSideButton

local SHADER_NAME = 'map_lens'
local SHADER_VERTEX = '/shaders/map_default_vertex'
local SHADER_FRAGMENT = '/shaders/map_lens_fragment'

-- Escurecimento do fundo (vinheta atras do mapa). O .otui pede esse shader pelo
-- nome em 'image-shader', mas quem registra ele e' este modulo - sem o
-- createShader aqui o nome nao existe.
local DIM_SHADER_NAME = 'map_overlay_dim'
local DIM_SHADER_FRAGMENT = '/shaders/map_overlay_dim_fragment'

-- Keep in sync with LENS_STRENGTH in data/shaders/map_lens_fragment.frag
local LENS_STRENGTH = 0.40

-- Zoom the map opens with (0 = 1 pixel per tile, 1 = 2, 2 = 4, ...)
local DEFAULT_ZOOM = 2

local HOTKEY = 'Ctrl+Shift+B'

local function syncFlagsToPanel()
  local panel = modules.game_minimap and modules.game_minimap.minimapWidget
  if not panel or panel == overlayMiniMap then return end

  for _, flag in pairs(overlayMiniMap.flags or {}) do
    if not panel:getFlag(flag.pos) then
      panel:addFlag(flag.pos, flag.icon, flag.description)
    end
  end
end

local function onPlayerPositionChange(player, newPos, oldPos)
  if not newPos then return end
  if not overlayRoot or not overlayRoot:isVisible() then return end
  -- Sem camera valida, o setCrossPosition do minimapa estoura (getCameraPosition vira nil).
  if not overlayMiniMap:getCameraPosition() then return end
  overlayMiniMap:setCrossPosition(newPos)
end

local function onGameStart()
  if mapSideButton then
    mapSideButton:show()
    mapSideButton:raise()
  end
end

local function onGameEnd()
  hide()
  if mapSideButton then
    mapSideButton:hide()
  end
end

local function createSideButton()
  if mapSideButton then return end
  if not modules.game_interface then return end

  local rootPanel = modules.game_interface.getRootPanel()
  if not rootPanel then return end

  pcall(function() g_ui.importStyle('map_button') end)

  local ok, button = pcall(function() return g_ui.createWidget('MapSideButton', rootPanel) end)
  if not ok or not button then return end

  mapSideButton = button

  if rootPanel:getChildById('inventorySideButton') then
    mapSideButton:addAnchor(AnchorBottom, 'inventorySideButton', AnchorTop)
  else
    mapSideButton:addAnchor(AnchorBottom, 'consolePanel', AnchorTop)
  end
  mapSideButton:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  mapSideButton:setMarginBottom(6)
  mapSideButton:setMarginLeft(0)
  mapSideButton:hide()
end

local function ensureUI()
  if overlayRoot then return true end
  if not modules.game_interface then return false end

  local parent = modules.game_interface.getRootPanel()
  if not parent then return false end

  overlayRoot = g_ui.loadUI('map_overlay', parent)
  if not overlayRoot then return false end

  overlayRoot:hide()

  overlayMiniMap = overlayRoot:getChildById('mapOverlayMinimap')
  if not overlayMiniMap then
    overlayRoot:destroy()
    overlayRoot = nil
    return false
  end

  -- A lente precisa que o client desenhe o minimapa num buffer proprio antes de
  -- deformar a imagem. Clients sem esse suporte continuam abrindo o mapa, so
  -- sem a lente.
  pcall(function()
    overlayMiniMap:setShader(SHADER_NAME)
    overlayMiniMap:setLensStrength(LENS_STRENGTH)
  end)

  -- Sem nenhum botao: esconde tudo o que vem de brinde no estilo do Minimap.
  for _, id in ipairs({ 'floorUpButton', 'floorDownButton', 'zoomInButton', 'zoomOutButton', 'resetButton', 'close' }) do
    local button = overlayMiniMap:getChildById(id)
    if button then button:hide() end
  end

  return true
end

function show()
  if not ensureUI() then return end
  if overlayRoot:isVisible() then return end

  overlayRoot:show()
  overlayRoot:raise()

  local player = g_game.getLocalPlayer()
  local pos = player and player:getPosition()
  if pos then
    overlayMiniMap:setCameraPosition(pos)
    overlayMiniMap:setCrossPosition(pos)
  end

  pcall(function() overlayMiniMap:load() end)
  pcall(function() overlayMiniMap:setZoom(DEFAULT_ZOOM) end)

  -- Tecla de atalho tem que ficar no rootWidget: o Escape so chega no widget que
  -- esta com o foco, e a overlay nao tem foco.
  g_keyboard.bindKeyDown('Escape', hide)
end

function hide()
  if not overlayRoot or not overlayRoot:isVisible() then return end

  syncFlagsToPanel()
  overlayRoot:hide()
  g_keyboard.unbindKeyDown('Escape', hide)
end

function toggle()
  if overlayRoot and overlayRoot:isVisible() then
    hide()
  else
    show()
  end
end

function init()
  pcall(function()
    g_shaders.createShader(SHADER_NAME, SHADER_VERTEX, SHADER_FRAGMENT)
  end)

  pcall(function()
    g_shaders.createShader(DIM_SHADER_NAME, SHADER_VERTEX, DIM_SHADER_FRAGMENT)
  end)

  connect(LocalPlayer, {
    onPositionChange = onPlayerPositionChange
  })

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  g_keyboard.bindKeyDown(HOTKEY, toggle)

  createSideButton()
  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  g_keyboard.unbindKeyDown(HOTKEY)
  g_keyboard.unbindKeyDown('Escape', hide)

  disconnect(LocalPlayer, {
    onPositionChange = onPlayerPositionChange
  })

  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  if mapSideButton then
    mapSideButton:destroy()
    mapSideButton = nil
  end

  if overlayRoot then
    overlayRoot:destroy()
    overlayRoot = nil
    overlayMiniMap = nil
  end
end
