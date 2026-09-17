local defaultOptions = {
  vsync = false,
  showFps = false,
  showPing = true,
  fullscreen = false,
  classicControl = true,
  disableLoadingScreen = false,
  smartWalk = false,
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
  showSelfEmblem = true,
  autoloot = false,
  displayNames = true,
  displayHealth = true,
  displayText = true,
  hdMode = true,
  drawShadows = true,
  floorShadow = true,
  skyClouds = true
}

local optionsWindow
local optionsButton
local optionsTabBar
local options = {}
local generalPanel
local consolePanel
local graphicsPanel
local soundPanel

local function setupGraphicsEngines()
  local enginesRadioGroup = UIRadioGroup.create()
  local ogl1 = graphicsPanel:getChildById('opengl1')
  local dx9 = graphicsPanel:getChildById('directx9')
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
    graphicsPanel:getChildById('foregroundFrameRate'):disable()
    graphicsPanel:getChildById('foregroundFrameRateLabel'):disable()
  end
end

function init()
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

  generalPanel = g_ui.loadUI('game')
  optionsTabBar:addTab(tr('Game'), generalPanel, '/images/optionstab/game')

  consolePanel = g_ui.loadUI('console')
  optionsTabBar:addTab(tr('Console'), consolePanel, '/images/optionstab/console')

  graphicsPanel = g_ui.loadUI('graphics')
  optionsTabBar:addTab(tr('Graphics'), graphicsPanel, '/images/optionstab/graphics')

  optionsButton = modules.client_topmenu.addLeftButton('optionsButton', tr('Options'), '/images/topbuttons/options', toggle)

  addEvent(function() setup() end)
end

function terminate()
  g_keyboard.unbindKeyDown('Ctrl+Shift+F')
  g_keyboard.unbindKeyDown('Ctrl+N')
  optionsWindow:destroy()
  optionsButton:destroy()
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
    graphicsPanel:getChildById('backgroundFrameRateLabel'):setText(tr('Game framerate limit: %s', text))
    if g_app.setBackgroundPaneMaxFps then g_app.setBackgroundPaneMaxFps(v) else g_app.setMaxFps(v) end
  elseif key == 'foregroundFrameRate' then
    local text, v = value, value
    if value <= 0 or value >= 61 then  text = 'max' v = 0 end
    graphicsPanel:getChildById('foregroundFrameRateLabel'):setText(tr('Interface framerate limit: %s', text))
    if g_app.setForegroundPaneMaxFps then g_app.setForegroundPaneMaxFps(v) end
  elseif key == 'enableLights' then
    gameMapPanel:setDrawLights(value and options['ambientLight'] < 100)
    graphicsPanel:getChildById('ambientLight'):setEnabled(value)
    graphicsPanel:getChildById('ambientLightLabel'):setEnabled(value)
  elseif key == 'autoloot' then
    local protocolGame = g_game.getProtocolGame()
	if protocolGame then
		local outStr = "false"
		if value then
			outStr = "true"
		end
		protocolGame:sendExtendedOpcode(131, outStr)
	end
  elseif key == 'ambientLight' then
    graphicsPanel:getChildById('ambientLightLabel'):setText(tr('Ambient light: %s%%', value))
    gameMapPanel:setMinimumAmbientLight(value/100)
    gameMapPanel:setDrawLights(options['enableLights'] and value < 100)
  elseif key == 'painterEngine' then
    if g_graphics.selectPainterEngine then g_graphics.selectPainterEngine(value) end
  elseif key == 'displayNames' then
    gameMapPanel:setDrawNames(value)
  elseif key == 'displayHealth' then
    gameMapPanel:setDrawHealthBars(value)
  elseif key == 'displayText' then
    gameMapPanel:setDrawTexts(value)
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

function addTab(name, panel, icon)
  optionsTabBar:addTab(name, panel, icon)
end

function addButton(name, func, icon)
  optionsTabBar:addButton(name, func, icon)
end
