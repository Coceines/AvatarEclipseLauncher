local defaultOptions = {
  vsync = false,
  showFps = false,
  showPing = true,
  fullscreen = false,
  classicControl = true,
  disableLoadingScreen = false,
  smartWalk = true,
  showStatusMessagesInConsole = true,
  showEventMessagesInConsole = true,
  showInfoMessagesInConsole = true,
  showTimestampsInConsole = true,
  showLevelsInConsole = true,
  showPrivateMessagesInConsole = true,
  showPrivateMessagesOnScreen = true,
  foregroundFrameRate = 61,
  backgroundFrameRate = 144,
  painterEngine = 0,
  enableLights = true,
  ambientLight = 25,
  effectOpacitySelf = 100,
  effectOpacityOthers = 100,
  effectOpacityMonsters = 100,
  showSelfEmblem = true,
  displayNames = true,
  displayHealth = true,
  displayText = true,
  hdMode = true,
  drawShadows = true,
  floorShadow = true,
  floorShadowFadeWidth = 32,
  floorShadowFadeEasing = 0,
  highFloorTransparency = true,
  skyClouds = true,
  dashWalk = false,
  turnDelay = 50,
  walkSmoothing = true,
  -- FUN: Toph Mode (aba que so' aparece para dobrador de terra)
  tophMode = false
}

-- Tempo (ms) do lerp de camera enquanto a opcao 'walkSmoothing' esta ligada.
-- Em 0 o mapa volta a pular de SQM em SQM, exatamente como era antes.
local WALK_SMOOTHING_TIME = 100

local optionsWindow
local optionsCornerMenu
local optionsTabBar
local options = {}
local generalPanel
local consolePanel
local graphicsPanel
local effectsPanel
local soundPanel
local controllerPanel
-- aba FUN (Toph Mode)
local funPanel
local funTabAdded = false
local funTabIcon
local funListenerRegistered = false
-- forward declarations: a aba FUN tambem e' usada por onGameEnd (definido acima)
local tophAvailable, syncTophCheckbox, disableTophMode

local function setScrollActive(panel, bgId, scrollId, value, maxVal)
  local bg = panel and panel:getChildById(bgId)
  if not bg then return end
  local scroll = bg:getChildById(scrollId)
  if scroll then
    local active = scroll:getChildById('activeScroll')
    if active then
      local w = math.floor((value * 200) / math.max(maxVal, 1))
      active:setWidth(math.max(0, math.min(200, w)))
    end
  end
end

local function setupGraphicsEngines()
  local enginesRadioGroup = UIRadioGroup.create()
  local ogl1 = graphicsPanel:getChildById('opengl1')
  local dx9 = graphicsPanel:getChildById('directx9')
  -- Engine buttons may be nested in a wrapper panel
  if not ogl1 then
    ogl1 = graphicsPanel:recursiveGetChildById('opengl1')
  end
  if not dx9 then
    dx9 = graphicsPanel:recursiveGetChildById('directx9')
  end
  enginesRadioGroup:addWidget(ogl1)
  enginesRadioGroup:addWidget(dx9)

  if g_window.getPlatformType() == 'WIN32-EGL' then
    enginesRadioGroup:selectWidget(dx9)
    ogl1:setEnabled(false)
    dx9:setEnabled(true)
  else
    enginesRadioGroup:selectWidget(ogl1)
    ogl1:setEnabled(true)
    dx9:setEnabled(false)
  end

  if g_graphics.canCacheBackbuffer and not g_graphics.canCacheBackbuffer() then
    local fgBg = graphicsPanel:getChildById('foregroundFrameRateBG')
    if fgBg then
      local scroll = fgBg:getChildById('foregroundFrameRate')
      local label = fgBg:getChildById('foregroundFrameRateLabelBG')
      if scroll then scroll:disable() end
      if label then label:disable() end
    else
      local scroll = graphicsPanel:recursiveGetChildById('foregroundFrameRate')
      local label = graphicsPanel:recursiveGetChildById('foregroundFrameRateLabelBG')
        or graphicsPanel:recursiveGetChildById('foregroundFrameRateLabel')
      if scroll then scroll:disable() end
      if label then label:disable() end
    end
  end
end

function init()
  -- Garante o shader de brilho das opcoes ativas (mesmo do talent tree)
  if g_shaders and g_shaders.createShader then
    pcall(function()
      g_shaders.createShader("talent_border_glow", "/shaders/map_default_vertex", "/shaders/talent_border_glow")
    end)
  end

  for k,v in pairs(defaultOptions) do
    g_settings.setDefault(k, v)
    options[k] = v
  end

  g_app.setDrawShadows(g_settings.getBoolean('drawShadows'))
  if g_settings.getBoolean('floorShadow') then
    g_game.enableFeature(GameDrawFloorShadow)
  end
  if g_settings.getBoolean('skyClouds') then
    g_game.enableFeature(GameDrawSkyClouds)
  end
  g_game.enableFeature(GameVocationMonk)
  -- Apply sky clouds setting via Lua module
  if modules.game_skyclouds and modules.game_skyclouds.setEnabled then
    modules.game_skyclouds.setEnabled(g_settings.getBoolean('skyClouds'))
  end
  if g_sprites.setHdMode then
    g_sprites.setHdMode(g_settings.getBoolean('hdMode'))
  end

  optionsWindow = g_ui.displayUI('options')
  optionsWindow:hide()

  optionsTabBar = optionsWindow:getChildById('optionsTabBar')
  optionsTabBar:setContentWidget(optionsWindow:getChildById('optionsTabContent'))

  g_keyboard.bindKeyDown('Ctrl+Shift+F', function() toggleOption('fullscreen') end)
  g_keyboard.bindKeyDown('Ctrl+N', toggleDisplays)

  local tabIcon = '/modules/client_options/settings/iconpanel'

  generalPanel = g_ui.loadUI('game')
  optionsTabBar:addTab(tr('Game'), generalPanel, tabIcon)

  consolePanel = g_ui.loadUI('console')
  optionsTabBar:addTab(tr('Console'), consolePanel, tabIcon)

  graphicsPanel = g_ui.loadUI('graphics')
  optionsTabBar:addTab(tr('Graphics'), graphicsPanel, tabIcon)

  effectsPanel = g_ui.loadUI('effects')
  optionsTabBar:addTab(tr('Effects'), effectsPanel, tabIcon)

  controllerPanel = g_ui.loadUI('styles/controller/controller')
  optionsTabBar:addTab(tr('Controller'), controllerPanel, tabIcon)

  -- FUN: aba exclusiva de dobrador de terra (Toph Mode). Ela e' adicionada
  -- por refreshFunTab() so' quando o personagem pode usar o modo.
  funTabIcon = tabIcon
  refreshFunTab()
  addEvent(function() refreshFunTab() end)

  optionsCornerMenu = g_ui.displayUI('corner_menu')
  if optionsCornerMenu then
    optionsCornerMenu:hide()
    if g_game.isOnline() then
      onGameStart()
    end
  end

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  addEvent(function() setup() end)
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })
  g_keyboard.unbindKeyDown('Ctrl+Shift+F')
  g_keyboard.unbindKeyDown('Ctrl+N')
  optionsWindow:destroy()
  if optionsCornerMenu then
    optionsCornerMenu:destroy()
    optionsCornerMenu = nil
  end
end

function onGameStart()
  if optionsCornerMenu then
    optionsCornerMenu:show()
    optionsCornerMenu:raise()
  end
  -- o elemento/classe do personagem chega logo depois do login (#v#):
  -- confere agora e de novo um pouco depois
  refreshFunTab()
  addEvent(function() refreshFunTab() end)
  scheduleEvent(refreshFunTab, 1000)
  scheduleEvent(refreshFunTab, 3000)
end

function onGameEnd()
  if optionsCornerMenu then
    optionsCornerMenu:hide()
  end
  -- trocar de personagem desliga o Toph Mode
  disableTophMode()
  refreshFunTab()
  hide()
end

-- ===========================================================================
--  ABA "FUN" -- Toph Mode (somente dobrador de terra)
-- ===========================================================================
local FUN_TAB_NAME = 'FUN'

local function tophModule()
  return modules.game_tophmode
end

tophAvailable = function()
  local mod = tophModule()
  if mod and mod.isEarthBender then
    local ok, avail = pcall(mod.isEarthBender)
    return ok and avail == true
  end
  return false
end

syncTophCheckbox = function()
  if not funPanel then return end
  local widget = funPanel:recursiveGetChildById('tophMode')
  if widget then
    widget:setChecked(options['tophMode'] and true or false)
  end
end

disableTophMode = function()
  local mod = tophModule()
  if mod and mod.setEnabled then
    pcall(mod.setEnabled, false)
  end
  if options['tophMode'] ~= false then
    options['tophMode'] = false
    g_settings.set('tophMode', false)
    syncTophCheckbox()
  end
end

function refreshFunTab()
  -- registra o aviso de disponibilidade assim que o modulo existir
  local mod = tophModule()
  if mod and mod.setAvailabilityListener and not funListenerRegistered then
    funListenerRegistered = true
    pcall(mod.setAvailabilityListener, function() refreshFunTab() end)
  end

  local available = tophAvailable()

  if available and not funTabAdded then
    -- o painel e' recriado a cada vez: removeTab() destroi o painel da aba
    funPanel = g_ui.loadUI('fun')
    optionsTabBar:addTab(tr(FUN_TAB_NAME), funPanel, funTabIcon)
    funTabAdded = true
    syncTophCheckbox()
  elseif not available and funTabAdded then
    local tab = optionsTabBar:getTab(tr(FUN_TAB_NAME))
    if tab then
      optionsTabBar:removeTab(tab)
    end
    funTabAdded = false
    funPanel = nil
    disableTophMode()
  end
end

function setup()
  setupGraphicsEngines()

  -- load options
  for k,v in pairs(defaultOptions) do
    if type(v) == 'boolean' then
      setOption(k, g_settings.getBoolean(k), true)
    elseif type(v) == 'number' then
      setOption(k, g_settings.getNumber(k), true)
    end
  end
end

function toggle()
  if optionsWindow:isVisible() then
    hide()
  else
    show()
  end
end

function show()
  optionsWindow:show()
  optionsWindow:raise()
  optionsWindow:focus()
end

function hide()
  optionsWindow:hide()
  if optionsCornerMenu then
    optionsCornerMenu:raise()
  end
end

function toggleDisplays()
  if options['displayNames'] and options['displayHealth'] then
    setOption('displayNames', false)
  elseif options['displayHealth'] then
    setOption('displayHealth', false)
  else
    if not options['displayNames'] and not options['displayHealth'] then
      setOption('displayNames', true)
    else
      setOption('displayHealth', true)
    end
  end
end

function toggleOption(key)
  setOption(key, not getOption(key))
end

function setOption(key, value, force)
  if not force and options[key] == value then return end
  local gameMapPanel = modules.game_interface.getMapPanel()

  if key == 'vsync' then
    g_window.setVerticalSync(value)
  elseif key == 'showFps' then
    modules.client_topmenu.setFpsVisible(value)
  elseif key == 'showPing' then
    modules.client_topmenu.setPingVisible(value)
  elseif key == 'fullscreen' then
    g_window.setFullscreen(value)
  elseif key == 'backgroundFrameRate' then
    local text, v = value, value
    if value <= 0 or value >= 201 then text = 'max' v = 0 end
    local bg = graphicsPanel:getChildById('backgroundFrameRateBG')
    if bg then
      local label = bg:getChildById('backgroundFrameRateLabelBG')
      if label then label:setText(tr('%s', text)) end
    else
      local label = graphicsPanel:recursiveGetChildById('backgroundFrameRateLabel')
      if label then label:setText(tr('Game framerate limit: %s', text)) end
    end
    setScrollActive(graphicsPanel, 'backgroundFrameRateBG', 'backgroundFrameRate', value, 201)
    if g_app.setBackgroundPaneMaxFps then g_app.setBackgroundPaneMaxFps(v) else g_app.setMaxFps(v) end
  elseif key == 'foregroundFrameRate' then
    local text, v = value, value
    if value <= 0 or value >= 61 then  text = 'max' v = 0 end
    local bg = graphicsPanel:getChildById('foregroundFrameRateBG')
    if bg then
      local label = bg:getChildById('foregroundFrameRateLabelBG')
      if label then label:setText(tr('%s', text)) end
    else
      local label = graphicsPanel:recursiveGetChildById('foregroundFrameRateLabel')
      if label then label:setText(tr('Interface framerate limit: %s', text)) end
    end
    setScrollActive(graphicsPanel, 'foregroundFrameRateBG', 'foregroundFrameRate', value, 61)
    if g_app.setForegroundPaneMaxFps then g_app.setForegroundPaneMaxFps(v) end
  elseif key == 'enableLights' then
    gameMapPanel:setDrawLights(value and options['ambientLight'] < 100)
    local ambientBg = graphicsPanel:getChildById('ambientLightBG')
    if ambientBg then
      local scroll = ambientBg:getChildById('ambientLight')
      local label = ambientBg:getChildById('ambientLightLabelBG')
      if scroll then scroll:setEnabled(value) end
      if label then label:setEnabled(value) end
    else
      local scroll = graphicsPanel:recursiveGetChildById('ambientLight')
      local label = graphicsPanel:recursiveGetChildById('ambientLightLabelBG')
        or graphicsPanel:recursiveGetChildById('ambientLightLabel')
      if scroll then scroll:setEnabled(value) end
      if label then label:setEnabled(value) end
    end
  elseif key == 'ambientLight' then
    local bg = graphicsPanel:getChildById('ambientLightBG')
    if bg then
      local label = bg:getChildById('ambientLightLabelBG')
      if label then label:setText(tr('%s%%', value)) end
    else
      local label = graphicsPanel:recursiveGetChildById('ambientLightLabel')
      if label then label:setText(tr('Ambient light: %s%%', value)) end
    end
    setScrollActive(graphicsPanel, 'ambientLightBG', 'ambientLight', value, 100)
    gameMapPanel:setMinimumAmbientLight(value/100)
    gameMapPanel:setDrawLights(options['enableLights'] and value < 100)
  elseif key == 'effectOpacitySelf' or key == 'effectOpacityOthers' or key == 'effectOpacityMonsters' then
    local source = 1
    if key == 'effectOpacitySelf' then
      source = 0
    elseif key == 'effectOpacityMonsters' then
      source = 2
    end
    if g_game.setEffectOpacity then g_game.setEffectOpacity(source, value / 100) end
    local bg = effectsPanel:getChildById(key .. 'BG')
    if bg then
      local label = bg:getChildById(key .. 'LabelBG')
      if label then label:setText(tr('%s%%', value)) end
    else
      local label = effectsPanel:recursiveGetChildById(key .. 'LabelBG')
      if label then label:setText(tr('%s%%', value)) end
    end
    setScrollActive(effectsPanel, key .. 'BG', key, value, 100)
  elseif key == 'painterEngine' then
    if g_graphics.selectPainterEngine then g_graphics.selectPainterEngine(value) end
  elseif key == 'displayNames' then
    gameMapPanel:setDrawNames(value)
  elseif key == 'displayHealth' then
    gameMapPanel:setDrawHealthBars(value)
  elseif key == 'displayText' then
    gameMapPanel:setDrawTexts(value)
  elseif key == 'walkSmoothing' then
    if gameMapPanel and gameMapPanel.setWalkSmoothingTime then
      gameMapPanel:setWalkSmoothingTime(value and WALK_SMOOTHING_TIME or 0)
    end
  elseif key == 'hdMode' then
    if g_sprites.setHdMode then
      g_sprites.setHdMode(value)
    end
  elseif key == 'drawShadows' then
    g_app.setDrawShadows(value)
  elseif key == 'floorShadow' then
    if value then
      g_game.enableFeature(GameDrawFloorShadow)
    else
      g_game.disableFeature(GameDrawFloorShadow)
    end
  elseif key == 'floorShadowFadeWidth' then
    if gameMapPanel and gameMapPanel.setFloorShadowFadeWidth then
      gameMapPanel:setFloorShadowFadeWidth(value)
      local bg = graphicsPanel:getChildById('floorShadowFadeWidthBG')
      if bg then
        local label = bg:getChildById('floorShadowFadeWidthLabelBG')
        if label then label:setText(tr('%s px', value)) end
      else
        local label = graphicsPanel:recursiveGetChildById('floorShadowFadeWidthLabel')
        if label then label:setText(tr('Floor shadow fade width: %s px', value)) end
      end
      setScrollActive(graphicsPanel, 'floorShadowFadeWidthBG', 'floorShadowFadeWidth', value, 128)
    end
  elseif key == 'floorShadowFadeEasing' then
    if gameMapPanel and gameMapPanel.setFloorShadowFadeEasing then
      gameMapPanel:setFloorShadowFadeEasing(value)
      local name = value == 1 and 'Linear' or 'Smoothstep'
      local bg = graphicsPanel:getChildById('floorShadowFadeEasingBG')
      if bg then
        local label = bg:getChildById('floorShadowFadeEasingLabelBG')
        if label then label:setText(tr('%s', name)) end
      else
        local label = graphicsPanel:recursiveGetChildById('floorShadowFadeEasingLabel')
        if label then label:setText(tr('Floor shadow fade easing: %s', name)) end
      end
      setScrollActive(graphicsPanel, 'floorShadowFadeEasingBG', 'floorShadowFadeEasing', value, 1)
    end
  elseif key == 'highFloorTransparency' then
    if gameMapPanel and gameMapPanel.setFloorTransparencyEnabled then
      gameMapPanel:setFloorTransparencyEnabled(value)
    end
  elseif key == 'skyClouds' then
    if value then
      g_game.enableFeature(GameDrawSkyClouds)
    else
      g_game.disableFeature(GameDrawSkyClouds)
    end
    if gameMapPanel and gameMapPanel.setDrawSkyClouds then
      gameMapPanel:setDrawSkyClouds(value)
    end
    if modules.game_skyclouds and modules.game_skyclouds.setEnabled then
      modules.game_skyclouds.setEnabled(value)
    end
  elseif key == 'tophMode' then
    -- recusa ligar se o personagem nao for dobrador de terra (a aba fica
    -- escondida nesse caso, isto e' so' uma trava extra)
    if value and not tophAvailable() then
      syncTophCheckbox()
      return
    end
    local mod = tophModule()
    if mod and mod.setEnabled then
      local ok, err = pcall(mod.setEnabled, value)
      if not ok then
        g_logger.warning('Toph Mode: ' .. tostring(err))
      end
    end
  end

  -- change value for keybind updates
  for _,panel in pairs(optionsTabBar:getTabsPanel()) do
    local widget = panel:recursiveGetChildById(key)
    if widget then
      if widget:getStyle().__class == 'UICheckBox' then
        widget:setChecked(value)
      elseif widget:getStyle().__class == 'UIScrollBar' then
        widget:setValue(value)
      end
      break
    end
  end

  g_settings.set(key, value)
  options[key] = value
end

function getOption(key)
  return options[key]
end

function getPanel()
  return optionsWindow
end

function resetWindowLayout()
  local miniWindows = {}
  local containers = {}

  local function collect(widget)
    local children = widget:getChildren()
    for i = 1, #children do
      local child = children[i]
      local className = child:getClassName()
      if className == 'UIMiniWindow' then
        miniWindows[#miniWindows + 1] = child
      elseif className == 'UIMiniWindowContainer' then
        containers[#containers + 1] = child
      end
      collect(child)
    end
  end
  collect(rootWidget)

  table.sort(miniWindows, function(a, b)
    local aIndex, bIndex = a.defaultIndex, b.defaultIndex
    if aIndex and bIndex and aIndex ~= bIndex then return aIndex < bIndex end
    if aIndex and not bIndex then return true end
    if bIndex and not aIndex then return false end
    return a:getId() < b:getId()
  end)

  g_settings.setNode('MiniWindows', {})

  for i = 1, #containers do
    containers[i].fitAllDisabled = true
  end

  for i = 1, #miniWindows do
    miniWindows[i]:resetToDefault()
  end

  for i = 1, #containers do
    containers[i].fitAllDisabled = nil
  end

  g_settings.save()
end

function addTab(name, panel, icon)
  optionsTabBar:addTab(name, panel, icon)
end

function addButton(name, func, icon)
  optionsTabBar:addButton(name, func, icon)
end
