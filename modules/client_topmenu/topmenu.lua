-- private variables
local topMenu
local leftButtonsPanel
local rightButtonsPanel
local leftGameButtonsPanel
local rightGameButtonsPanel
local fpsEvent
local fpsText = ''

-- compact menu (right corner)
local menuRoot = nil
local menuCorner = nil
local menuPanel = nil
local menuList = nil
local menuEntries = {}
local menuAnimEvent = nil
local menuOpen = false
local menuRestY = 0
-- botao do Shop no centro-norte da tela
local shopCorner = nil
local MENU_ANIM_DURATION = 240
local MENU_ANIM_STEPS = 18
local MENU_REST_GAP = 6

-- private functions
local function stopMenuAnim()
  if menuAnimEvent then
    removeEvent(menuAnimEvent)
    menuAnimEvent = nil
  end
end

-- A barra superior foi substituida pelo menu compacto do canto direito.
-- Os botoes continuam existindo (modulos seguem usando addLeftButton & cia),
-- mas ficam escondidos e passam a ser listados dentro da gaveta do canto.
local function hideTopbarPanels()
  local panels = { leftButtonsPanel, rightButtonsPanel, leftGameButtonsPanel, rightGameButtonsPanel }
  for _, panel in pairs(panels) do
    if panel then
      panel:hide()
    end
  end
  if fpsLabel then fpsLabel:hide() end
  if pingLabel then pingLabel:hide() end
end

local function menuEntryLabel(entry)
  return entry.description or entry.id
end

local function rebuildMenuList()
  if not menuList then return end
  menuList:destroyChildren()

  -- somente os botoes que os modulos deixaram visiveis entram na gaveta
  -- isExplicitlyVisible(): o botao vive dentro de um painel oculto, entao
  -- isVisible() seria sempre falso por causa do estado herdado do pai.
  local entries = {}
  for _, entry in ipairs(menuEntries) do
    local button = entry.button
    if button and not button:isDestroyed() and button:isExplicitlyVisible() then
      table.insert(entries, entry)
    end
  end

  -- ordem alfabetica pelo nome exibido
  table.sort(entries, function(a, b)
    return string.lower(menuEntryLabel(a)) < string.lower(menuEntryLabel(b))
  end)

  for _, entry in ipairs(entries) do
    local button = entry.button
    local item = g_ui.createWidget('GameMenuListButton', menuList)
    item:setId('menu_' .. entry.id)
    item:setText(menuEntryLabel(entry))
    item:setOn(button.isOn and button:isOn() or false)
    item.onClick = function()
      if entry.callback then
        entry.callback()
      end
      scheduleEvent(function()
        if item and not item:isDestroyed() and button and not button:isDestroyed() then
          item:setOn(button.isOn and button:isOn() or false)
        end
      end, 50)
    end
  end
end

local function registerMenuEntry(id, description, icon, callback, button, front)
  for _, entry in ipairs(menuEntries) do
    if entry.id == id then
      entry.description = description
      entry.icon = resolvepath(icon, 3)
      entry.callback = callback
      entry.button = button
      return
    end
  end
  local entry = {
    id = id,
    description = description,
    icon = resolvepath(icon, 3),
    callback = callback,
    button = button
  }
  if front then
    table.insert(menuEntries, 1, entry)
  else
    table.insert(menuEntries, entry)
  end
end

local function addButton(id, description, icon, callback, panel, toggle, front)
  local class
  if toggle then
    class = 'TopToggleButton'
  else
    class = 'TopButton'
  end

  local button = panel:getChildById(id)
  if not button then
    button = g_ui.createWidget(class)
    if front then
      panel:insertChild(1, button)
    else
      panel:addChild(button)
    end
  end
  button:setId(id)
  button:setTooltip(description)
  button:setIcon(resolvepath(icon, 3))
  button.onMouseRelease = function(widget, mousePos, mouseButton)
    if widget:containsPoint(mousePos) and mouseButton ~= MouseMiddleButton then
      callback()
      return true
    end
  end

  -- toda a barra superior vive agora na gaveta do menu compacto
  registerMenuEntry(id, description, icon, callback, button, front)
  hideTopbarPanels()

  return button
end

-- drawer geometry: o painel fica logo acima do botao de canto
local function updateMenuRestY()
  if not menuPanel or not menuCorner then return end
  local cornerTop = menuCorner:getY()
  -- se o layout ainda nao rodou, calcula pelo tamanho da tela
  if cornerTop <= 0 and menuRoot then
    cornerTop = menuRoot:getHeight() - menuCorner:getHeight()
  end
  menuRestY = cornerTop - menuPanel:getHeight() - MENU_REST_GAP
end

local function menuHiddenY()
  if not menuRoot then return 0 end
  return menuRoot:getHeight()
end

-- drawer animation (ease-out sobre o eixo Y)
local function animateMenuPanel(targetY, onFinish)
  if not menuPanel then return end
  stopMenuAnim()

  local startY = menuPanel:getY()
  local stepDelay = math.max(1, math.floor(MENU_ANIM_DURATION / MENU_ANIM_STEPS))
  local step = 0

  local function tick()
    if not menuPanel or menuPanel:isDestroyed() then
      menuAnimEvent = nil
      return
    end
    step = step + 1
    local progress = step / MENU_ANIM_STEPS
    local eased = 1 - (1 - progress) * (1 - progress) -- ease-out
    menuPanel:setY(math.floor(startY + (targetY - startY) * eased + 0.5))
    if step >= MENU_ANIM_STEPS then
      menuPanel:setY(targetY)
      menuAnimEvent = nil
      if onFinish then
        onFinish()
      end
    else
      menuAnimEvent = scheduleEvent(tick, stepDelay)
    end
  end

  menuAnimEvent = scheduleEvent(tick, stepDelay)
end

function hideGameMenu()
  if not menuPanel then return end
  if not menuOpen and not menuPanel:isVisible() then return end

  menuOpen = false
  -- desce como uma gaveta e so entao se esconde
  animateMenuPanel(menuHiddenY(), function()
    if menuPanel and not menuOpen then
      menuPanel:hide()
      menuPanel:setY(menuRestY)
    end
  end)
end

function showGameMenu()
  if not menuPanel then return end
  rebuildMenuList()
  stopMenuAnim()
  menuOpen = true
  updateMenuRestY()
  -- comeca abaixo da tela e sobe como uma gaveta
  menuPanel:setY(menuHiddenY())
  menuPanel:show()
  menuPanel:raise()
  if menuCorner then
    menuCorner:raise()
  end
  animateMenuPanel(menuRestY)
end

function toggleGameMenu()
  if menuOpen then
    hideGameMenu()
  else
    showGameMenu()
  end
end

-- o botao do centro-norte abre o Shop (mod/game_shop)
function toggleShop()
  if modules.game_shop and modules.game_shop.toggle then
    modules.game_shop.toggle()
  end
end

-- ESC fecha a gaveta (e so entao consome a tecla, para nao atrapalhar o resto)
local function onMenuEscape()
  if not menuOpen then return false end
  hideGameMenu()
  return true
end

-- public functions
function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline,
                    onPingBack = updatePing })

  g_keyboard.bindKeyDown('Escape', onMenuEscape)

  topMenu = g_ui.displayUI('topmenu')

  leftButtonsPanel = topMenu:getChildById('leftButtonsPanel')
  rightButtonsPanel = topMenu:getChildById('rightButtonsPanel')
  leftGameButtonsPanel = topMenu:getChildById('leftGameButtonsPanel')
  rightGameButtonsPanel = topMenu:getChildById('rightGameButtonsPanel')
  pingLabel = topMenu:getChildById('pingLabel')
  fpsLabel = topMenu:getChildById('fpsLabel')

  hideTopbarPanels()

  menuRoot = g_ui.displayUI('game_menu')
  if menuRoot then
    menuCorner = menuRoot:getChildById('gameMenuCorner')
    menuPanel = menuRoot:getChildById('gameMenuPanel')
    if menuPanel then
      menuList = menuPanel:getChildById('gameMenuList')
      updateMenuRestY()
      menuPanel:setY(menuRestY)
      menuPanel:hide()
    end
    -- reposiciona a gaveta se a resolucao/janela mudar
    menuRoot.onGeometryChange = function()
      updateMenuRestY()
      if menuPanel and not menuOpen then
        menuPanel:setY(menuRestY)
      end
    end
    menuRoot:raise()
    if menuCorner then
      -- Assim como o botao de Options, o menu do canto so aparece in-game:
      -- na tela de login ele nao deve existir.
      if g_game.isOnline() then
        menuCorner:show()
      else
        menuCorner:hide()
      end
    end

    -- o botao do Shop segue a mesma regra: in-game apenas
    shopCorner = menuRoot:getChildById('gameMenuShop')
    if shopCorner then
      if g_game.isOnline() then
        shopCorner:show()
      else
        shopCorner:hide()
      end
    end
  end

  updateFps()
  fpsEvent = cycleEvent(function() updateFps() end, 1000)

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline,
                       onPingBack = updatePing })

  g_keyboard.unbindKeyDown('Escape', onMenuEscape)

  if fpsEvent then
    removeEvent(fpsEvent)
    fpsEvent = nil
  end

  stopMenuAnim()

  if menuRoot then
    menuRoot:destroy()
    menuRoot = nil
    menuCorner = nil
    shopCorner = nil
    menuPanel = nil
    menuList = nil
  end
  menuEntries = {}
  menuOpen = false

  topMenu:destroy()
end

function online()
  hideTopbarPanels()
  g_game.enableFeature(GameClientPing)
  addEvent(function()
    if menuRoot then
      menuRoot:raise()
    end
    if menuCorner then
      menuCorner:show()
    end
    if shopCorner then
      shopCorner:show()
    end
  end)
end

function offline()
  hideGameMenu()
  if menuCorner then
    menuCorner:hide()
  end
  if shopCorner then
    shopCorner:hide()
  end
end

function updateFps(fps)
  fps = fps or g_app.getFps()
  if fps < 0 then fps = 0 end
  local text = 'FPS: ' .. fps
  if text ~= fpsText then
    fpsText = text
    if fpsLabel then fpsLabel:setText(text) end
  end
end

function updatePing(ping)
  ping = math.ceil(ping/4)
  local text = 'PING: '
  local color
  if ( ping <= 70 ) then
    color = 'green'
  elseif ( ping <= 130 ) then
    color = 'yellow'
  else
    color = 'red'
  end
  text = text .. ping .. ' ms'

  if pingLabel then
    pingLabel:setColor(color)
    pingLabel:setText(text)
  end
end

function setPingVisible(enable)
  -- a barra superior nao existe mais; o indicador fica sempre oculto
  if pingLabel then pingLabel:setVisible(false) end
end

function setFpsVisible(enable)
  if fpsLabel then fpsLabel:setVisible(false) end
end

function addLeftButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, leftButtonsPanel, false, front)
end

function addLeftToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, leftButtonsPanel, true, front)
end

function addRightButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, rightButtonsPanel, false, front)
end

function addRightToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, rightButtonsPanel, true, front)
end

function addLeftGameButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, leftGameButtonsPanel, true, front)
end

function addLeftGameToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, leftGameButtonsPanel, true, front)
end

function addRightGameButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, rightGameButtonsPanel, false, front)
end

function addRightGameToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, rightGameButtonsPanel, true, front)
end

function showGameButtons()
  hideTopbarPanels()
  if menuRoot then
    menuRoot:raise()
  end
  if menuCorner then
    menuCorner:show()
  end
  if shopCorner then
    shopCorner:show()
  end
end

function hideGameButtons()
  hideGameMenu()
  if menuCorner then
    menuCorner:hide()
  end
  if shopCorner then
    shopCorner:hide()
  end
end

function getButton(id)
  return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
  return topMenu
end
