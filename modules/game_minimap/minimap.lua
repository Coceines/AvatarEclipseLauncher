minimapWidget = nil
minimapButton = nil
minimapWindow = nil
otmm = true
preloaded = false
fullmapView = false
oldZoom = nil
oldPos = nil

local btnClose
local btnCenter

local locais = {
	{ name = "Ba Sing Se", pos = {x = 505, y = 342, z = 7} },
	{ name = "Fire Nation Capital", pos = {x = 226, y = 441, z = 7} },
	{ name = "South Air Temple", pos = {x = 529, y = 683, z = 7} },
	{ name = "South Water Tribe", pos = {x = 465, y = 849, z = 7} },
	{ name = "North Water Tribe", pos = {x = 336, y = 214, z = 7} }
}

-- Dimi position system (from HD minimap)
local fixedPosition
local lastTargetName = "Marcado"
local shouldSetDimiPosition = false
local posCamera
local dimiOldZoom -- separate from fullmap oldZoom to avoid conflicts

function UIMinimap:setDimiPosition(pos, text)
	if self.dimiCross then
		self.dimiCross:destroy()
		self.dimiCross = nil
	end

	local dimiCross = g_ui.createWidget("MinimapCross", self)
	dimiCross:setIcon("/images/game/minimap/shino")
	self.dimiCross = dimiCross

	local label = g_ui.createWidget("UILabel", dimiCross)
	label:setId("dimiLabel")
	label:setColor("red")
	label:setFont("verdana-11px-rounded")
	label:setPhantom(true)
	label:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	label:addAnchor(AnchorBottom, "parent", AnchorTop)
	label:setText(text)

	if not self.dimiRemoveEvent then
		self.dimiRemoveEvent = scheduleEvent(function()
			if self.dimiCross then
				self.dimiCross:destroy()
				self.dimiCross = nil
			end
			self.dimiRemoveEvent = nil
			minimapWidget:setCameraPosition(posCamera)
			minimapWidget:setZoom(oldZoom or 0)
			shouldSetDimiPosition = false
			updateCameraPosition()
		end, 5000)
	end

	dimiOldZoom = minimapWidget:getZoom()
	pos.z = fixedPosition and fixedPosition.z or pos.z
	dimiCross.pos = pos

	if pos then
		self:setCameraPosition(pos)
		self:centerInPosition(dimiCross, pos)
	else
		dimiCross:breakAnchors()
	end
end

-- Extended opcode for server position marking
ProtocolGame.registerExtendedOpcode(128, function(protocol, opcode, buffer)
	local params = buffer:split("@")
	local posStr = params[1]
	local targetName = params[2] or "Marcado"
	local x, y, z = posStr:match("([^,]+),([^,]+),([^,]+)")
	x, y, z = tonumber(x), tonumber(y), tonumber(z)
	fixedPosition = {
		x = x,
		y = y,
		z = z
	}
	lastTargetName = targetName
	shouldSetDimiPosition = true
	updateCameraPosition()
end)

function init()
  minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton', tr('Minimap') .. ' (Ctrl+M)', '/images/topbuttons/minimap', toggle)
  minimapButton:setOn(true)

  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(64)

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')
  btnClose  = minimapWidget:getChildById('close')
  btnCenter = minimapWidget:getChildById('resetButton')

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', function()
    if fullmapView then
      toggleFullMap()
    else
      toggle()
    end
  end)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap)

  -- Hook zoom change -> hide cross in tactical mode (zoom >= 3)
  local origOnZoomChange = minimapWidget.onZoomChange
  minimapWidget.onZoomChange = function(self, zoom, oldZoom)
    if origOnZoomChange then origOnZoomChange(self, zoom, oldZoom) end
    if self.cross then
      if zoom >= 3 then self.cross:hide()
      else self.cross:show() end
    end
  end

  minimapWindow:setup()
  minimapWindow:open()

  -- Initialize HD minimap toggle from settings
  local hdCheck = minimapWindow:recursiveGetChildById('minimapHDCheck')
  if hdCheck then
    local hdEnabled = g_settings.get('minimapHD', true)
    hdCheck:setChecked(hdEnabled)
    g_minimap.setMinimapHD(hdEnabled)
  end

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Shift+M')

  minimapWindow:destroy()
  minimapButton:destroy()
end

function toggle()
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  minimapButton:setOn(false)
end

function preload()
  loadMap(false)
  preloaded = true
end

function online()
  loadMap(not preloaded)
  updateCameraPosition()
end

function offline()
  saveMap()
end

function loadMap(clean)
  local clientVersion = g_game.getClientVersion()

  if clean then
    g_minimap.clean()
  end

  if otmm then
    -- Try loading with versioned split files first (HD minimap format)
    local loaded = false
    local minimapFile = '/minimap.otmm'
    local dataMinimapFile = '/data' .. minimapFile
    local versionedMinimapFile = '/minimap' .. clientVersion .. '.otmm'

    if g_resources.fileExists(dataMinimapFile) then
      loaded = g_minimap.loadOtmm(dataMinimapFile)
    end

    if not loaded and g_resources.fileExists(versionedMinimapFile) then
      loaded = g_minimap.loadOtmm(versionedMinimapFile)
    end

    if not loaded and g_resources.fileExists(minimapFile) then
      loaded = g_minimap.loadOtmm(minimapFile)
    end

    if not loaded then
      for z = 0, 15 do
        if g_minimap.loadOtmm('/minimap' .. clientVersion .. '_z' .. z .. '.otmm') then
          loaded = true
        end
      end
    end

    if not loaded then
      print("Minimap couldn't be loaded, file missing?")
    end
  else
    local minimapFile = '/minimap_' .. clientVersion .. '.otcm'
    if g_resources.fileExists(minimapFile) then
      g_map.loadOtcm(minimapFile)
    end
  end
  minimapWidget:load()

  -- Create city labels
  for i, value in ipairs(locais) do
    local uiLabelCity = g_ui.createWidget('LocalLabel', minimapWidget)
    minimapWidget:centerInPosition(uiLabelCity, value.pos)
    uiLabelCity:setText(value.name)
    uiLabelCity:setId('localId'..i)
  end
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  if otmm then
    local minimapFile = '/minimap' .. clientVersion .. '.otmm'
    g_minimap.saveOtmm(minimapFile)
    -- Also save legacy file for backward compatibility
    g_minimap.saveOtmm('/minimap.otmm')
  else
    local minimapFile = '/minimap_' .. clientVersion .. '.otcm'
    g_map.saveOtcm(minimapFile)
  end
  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end

  if shouldSetDimiPosition and fixedPosition then
    minimapWidget:setDimiPosition(fixedPosition, lastTargetName)
    minimapWidget:setZoom(0)
    posCamera = pos
  end

  -- Tactical mode (zoom >= 3) -> hide cross, outfit does the job
  local tactical = minimapWidget:getZoom() >= 3
  local function syncCross(p)
    if tactical then
      if minimapWidget.cross then minimapWidget.cross:hide() end
    else
      minimapWidget:setCrossPosition(p)
      if minimapWidget.cross then minimapWidget.cross:show() end
    end
  end

  if shouldSetDimiPosition then
    syncCross(pos)
    return
  end

  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(pos)
    end
    syncCross(pos)
  end
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
	visibleLocalName(true)
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:fill('parent')
	minimapWidget:setOpacity(0.9)	
	btnClose:show()
	btnClose:setMarginTop(45)
	btnCenter:setMarginTop(45)	
	btnCenter:setMarginLeft(btnClose:getWidth()+10)
    minimapWidget:setAlternativeWidgetsVisible(true)
  else
    fullmapView = false
	visibleLocalName(false)
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWindow:show()
	minimapWidget:setOpacity(1)
	btnClose:hide()
	btnClose:setMarginTop(4)
	btnCenter:setMarginTop(4)
	btnCenter:setMarginLeft(4)
    minimapWidget:setAlternativeWidgetsVisible(false)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function toggleMinimapHD(checkBox)
  local enabled = checkBox:isChecked()
  g_minimap.setMinimapHD(enabled)
  g_settings.set('minimapHD', enabled)
end

function visibleLocalName(visible)
  for i, value in ipairs(locais) do
    minimapWidget:getChildById('localId'..i):setVisible(visible)
  end
end