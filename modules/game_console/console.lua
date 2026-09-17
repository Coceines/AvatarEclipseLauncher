-- =============================================================================
-- Avatar client (OTClient V8) compatibility shims
-- This chat was ported from the Landcore client. Everything here, plus the
-- "Avatar integration" section at the end of the file, exists because this
-- branch has different enums/modules. Keep them when re-syncing upstream.
-- =============================================================================

-- Enums that Landcore declares in gamelib/const.lua but this branch does not.
if not ChannelEvent then
  ChannelEvent = {
    Join = 0,
    Leave = 1,
    Invite = 2,
    Exclude = 3,
  }
end

-- Same enum members, different names in this branch.
if not MessageModes.NpcFromStartBlock then
  MessageModes.NpcFromStartBlock = MessageModes.SystemFromStartBlock
end
if not MessageModes.GamemasterTo then
  MessageModes.GamemasterTo = MessageModes.GamemasterPrivateTo
end

-- Landcore locks WASD walking through modules.game_walking plus the
-- 'wsadWalking' client option. Here game_interface owns the walk keys, so we
-- mirror both: the flag below stands in for the client option.
local WASD_WALK_KEYS = {
  { 'W', North }, { 'D', East }, { 'S', South }, { 'A', West },
  { 'E', NorthEast }, { 'Q', NorthWest }, { 'C', SouthEast }, { 'Z', SouthWest },
}
-- Sem Ctrl+WASD de proposito: o Ctrl+W/A/S/D batia com Ctrl+W (limpar o chat) e
-- Ctrl+A/S do proprio jogo, alem de virar o personagem sem querer no meio da
-- digitacao. Quem quiser virar sem andar usa as setas com Ctrl (game_interface).

wsadWalking = true

function enableWasdWalking()
  for _, key in ipairs(WASD_WALK_KEYS) do
    modules.game_interface.bindWalkKey(key[1], key[2])
  end
end

function disableWasdWalking()
  for _, key in ipairs(WASD_WALK_KEYS) do
    modules.game_interface.unbindWalkKey(key[1])
  end
end

SpeakTypesSettings = {
  none = {},
  say = { speakType = MessageModes.Say, color = '#FFFFFF' },
  whisper = { speakType = MessageModes.Whisper, color = '#FFFFFF' },
  yell = { speakType = MessageModes.Yell, color = '#FFFFFF' },
  broadcast = { speakType = MessageModes.GamemasterBroadcast, color = '#F55E5E' },
  private = { speakType = MessageModes.PrivateTo, color = '#3ebaf3', private = true },
  privateRed = { speakType = MessageModes.GamemasterTo, color = '#F55E5E', private = true },
  privatePlayerToPlayer = { speakType = MessageModes.PrivateTo, color = '#fbce9d', private = true },
  privatePlayerToNpc = { speakType = MessageModes.NpcTo, color = '#a1d694', private = true, npcChat = true },
  privateNpcToPlayer = { speakType = MessageModes.NpcFrom, color = '#da7720', private = true, npcChat = true },
  channelYellow = { speakType = MessageModes.Channel, color = '#faf1e2' },
  channelWhite = { speakType = MessageModes.ChannelManagement, color = '#FFFFFF' },
  channelRed = { speakType = MessageModes.GamemasterChannel, color = '#F55E5E' },
  channelOrange = { speakType = MessageModes.ChannelHighlight, color = '#c1df8d' },
  monsterSay = { speakType = MessageModes.MonsterSay, color = '#FE6500', hideInConsole = true},
  monsterYell = { speakType = MessageModes.MonsterYell, color = '#FE6500', hideInConsole = true},
  rvrAnswerFrom = { speakType = MessageModes.RVRAnswer, color = '#FE6500' },
  rvrAnswerTo = { speakType = MessageModes.RVRAnswer, color = '#FE6500' },
  rvrContinue = { speakType = MessageModes.RVRContinue, color = '#FFFF00' },
}

SpeakTypes = {
  [MessageModes.Say] = SpeakTypesSettings.say,
  [MessageModes.Whisper] = SpeakTypesSettings.whisper,
  [MessageModes.Yell] = SpeakTypesSettings.yell,
  [MessageModes.GamemasterBroadcast] = SpeakTypesSettings.broadcast,
  [MessageModes.PrivateFrom] = SpeakTypesSettings.private,
  [MessageModes.GamemasterPrivateFrom] = SpeakTypesSettings.privateRed,
  [MessageModes.NpcTo] = SpeakTypesSettings.privatePlayerToNpc,
  [MessageModes.NpcFrom] = SpeakTypesSettings.privateNpcToPlayer,
  [MessageModes.Channel] = SpeakTypesSettings.channelYellow,
  [MessageModes.ChannelManagement] = SpeakTypesSettings.channelWhite,
  [MessageModes.GamemasterChannel] = SpeakTypesSettings.channelRed,
  [MessageModes.ChannelHighlight] = SpeakTypesSettings.channelOrange,
  [MessageModes.MonsterSay] = SpeakTypesSettings.monsterSay,
  [MessageModes.MonsterYell] = SpeakTypesSettings.monsterYell,
  [MessageModes.RVRChannel] = SpeakTypesSettings.channelWhite,
  [MessageModes.RVRContinue] = SpeakTypesSettings.rvrContinue,
  [MessageModes.RVRAnswer] = SpeakTypesSettings.rvrAnswerFrom,
  [MessageModes.NpcFromStartBlock] = SpeakTypesSettings.privateNpcToPlayer,

  -- ignored types
  [MessageModes.Spell] = SpeakTypesSettings.none,
  [MessageModes.BarkLow] = SpeakTypesSettings.none,
  [MessageModes.BarkLoud] = SpeakTypesSettings.none,
}

SayModes = {
  [1] = { speakTypeDesc = 'whisper', icon = '/images/game/console/whisper' },
  [2] = { speakTypeDesc = 'say', icon = '/images/game/console/say' },
  [3] = { speakTypeDesc = 'yell', icon = '/images/game/console/yell' }
}

ChannelEventFormats = {
  [ChannelEvent.Join] = '%s joined the channel.',
  [ChannelEvent.Leave] = '%s left the channel.',
  [ChannelEvent.Invite] = '%s has been invited to the channel.',
  [ChannelEvent.Exclude] = '%s has been removed from the channel.',
}

MAX_HISTORY = 500
MAX_LINES = 100
HELP_CHANNEL = 9

consolePanel = nil
consoleContentPanel = nil
consoleTabBar = nil
consoleTextEdit = nil
channels = nil
channelsWindow = nil
communicationWindow = nil
ownPrivateName = nil
messageHistory = {}
currentMessageIndex = 0
ignoreNpcMessages = false
defaultTab = nil
serverTab = nil
knockoutTab = nil
violationsChannelId = nil
violationWindow = nil
violationReportTab = nil
cooldownBars = nil
sendMessageButton = nil
consoleTextBackground = nil
panelBox = nil
ignoredChannels = {}
filters = {}

floatingMode = false
rightResizeBorder = nil
topResizeBorder = nil
local communicationSettings = {
  useIgnoreList = true,
  useWhiteList = true,
  privateMessages = false,
  yelling = false,
  allowVIPs = false,
  ignoredPlayers = {},
  whitelistedPlayers = {}
}

-- =============================================================================
-- Chat keyboard model
--
-- The engine delivers a key starting at the widget that owns the keyboard grab and
-- then walks down through the *focused* children only. So the chat input grabs the
-- keyboard itself and every chat shortcut is bound on it:
--   * typing and the shortcuts keep working even after a click moved the focus to
--     another widget of the panel (the "the chat looks dead" symptom);
--   * nothing above the chat (game root panel, walk keys, hotkeys) sees a key
--     while you type, so no hotkey fires in the middle of a message.
-- The bindings are created once in init() and can only fire while the input holds
-- the grab, which enableChat()/disableChat() toggle.
-- =============================================================================

-- rebuilds the focus chain from the root down to `widget`: focusChild() only flags
-- the child inside its parent, so the whole chain is needed for the caret/visual
-- focus. recursiveFocus(), the C++ function that does exactly this, is not exposed
-- to Lua, hence the manual walk.
local function focusWidgetChain(widget)
  if not widget then return end

  local chain = {}
  local node = widget
  while node do
    table.insert(chain, 1, node)
    node = node:getParent()
  end

  for _, chainNode in ipairs(chain) do
    local parent = chainNode:getParent()
    if parent then
      parent:focusChild(chainNode)
    end
  end
end

-- Enter opens the chat for typing. It is bound on the game root panel, so windows
-- outside the game (options, terminal, depot search, ...) keep their own Enter, and
-- it can only fire while the chat is closed: when the input owns the keyboard the
-- key never reaches the game root panel.
local function onEnterOpenChat()
  if not g_game.isOnline() or isChatEnabled() then return false end
  enableChat(true)
  return true
end

local function onEscapeCloseChat()
  if not isChatEnabled() then return false end
  disableChat(true)
  return true
end

function init()
  connect(g_game, {
    onTalk = onTalk,
    onChannelList = onChannelList,
    onOpenChannel = onOpenChannel,
    onCloseChannel = onCloseChannel,
    onChannelEvent = onChannelEvent,
    onOpenPrivateChannel = onOpenPrivateChannel,
    onOpenOwnPrivateChannel = onOpenOwnPrivateChannel,
    onRuleViolationChannel = onRuleViolationChannel,
    onRuleViolationRemove = onRuleViolationRemove,
    onRuleViolationCancel = onRuleViolationCancel,
    onRuleViolationLock = onRuleViolationLock,
    onGameStart = online,
    onGameEnd = offline,
    onTeleport = onTeleport, -- Avatar integration (chat stickers)
  })

  consolePanel = g_ui.loadUI('console', modules.game_interface.getRootPanel())
  
  topResizeBorder = consolePanel:recursiveGetChildById('topResizeBorder')
  if topResizeBorder then
  topResizeBorder:setMinimum(150)
  topResizeBorder.onMouseMove = function(self,mousePos, mouseMoved)
  if self:isPressed() then
    local parent = self:getParent()
    local newSize = 0
    if self.vertical then
      local delta = mousePos.y - self:getY() - self:getHeight()/2
      newSize = math.min(math.max(parent:getHeight() - delta, self.minimum), self.maximum)
      parent:setHeight(newSize)
    else
      local delta = mousePos.x - self:getX() - self:getWidth()/2
      newSize = math.min(math.max(parent:getWidth() + delta, self.minimum), self.maximum)
      parent:setWidth(newSize)
    end
    self:checkBoundary(newSize)
    return true
  end
  end
end 
 rightResizeBorder = consolePanel:recursiveGetChildById('rightResizeBorder')
 if rightResizeBorder then
  rightResizeBorder:setMinimum(160)
  rightResizeBorder.onMouseMove = function(self,mousePos, mouseMoved)
  if self:isPressed() then
    local parent = self:getParent()
    local newSize = 0
    if self.vertical then
      local delta = mousePos.y - self:getY() - self:getHeight()/2
      newSize = math.min(math.max(parent:getHeight() + delta, self.minimum), self.maximum)
      parent:setHeight(newSize)
    else
      local delta = mousePos.x - self:getX() - self:getWidth()/2
      newSize = math.min(math.max(parent:getWidth() + delta, self.minimum), self.maximum)
      parent:setWidth(newSize)
    end

    self:checkBoundary(newSize)
    return true
  end
  end
end
consolePanel:setPhantom(true)
  consoleTextEdit = consolePanel:getChildById('consoleTextEdit')
  consoleContentPanel = consolePanel:getChildById('consoleContentPanel')
  sendMessageButton = consolePanel:getChildById('sendMessage')
  consoleTextBackground = consolePanel:getChildById('consoleTextBackground')
  panelBox = consolePanel:getChildById('panelBox')
  consoleTabBar = consolePanel:getChildById('consoleTabBar')
  consoleTabBar:setContentWidget(consoleContentPanel)
  channels = {}
    
	
  consolePanel.onDragEnter = onDragEnter
  consolePanel.onDragLeave = onDragLeave
  consolePanel.onDragMove = onDragMove
  consoleTabBar.onDragEnter = onDragEnter
  consoleTabBar.onDragLeave = onDragLeave
  consoleTabBar.onDragMove = onDragMove
  
  -- chat shortcuts: bound on the input, which is the widget holding the keyboard
  -- grab while you type (see the keyboard model comment above init)
  g_keyboard.bindKeyPress('Ctrl+C', function()
    -- a selection made inside the input is copied by the text edit itself
    if consoleTextEdit:hasSelection() then return false end

    local tab = consoleTabBar:getCurrentTab()
    if not tab then return false end

    local selection = tab.tabPanel:getChildById('consoleBuffer').selectionText
    if not selection then return false end

    g_window.setClipboardText(selection)
    return true
  end, consoleTextEdit)
  g_keyboard.bindKeyPress('Ctrl+A', function() consoleTextEdit:clearText() return true end, consoleTextEdit)
  g_keyboard.bindKeyPress('Shift+Up', function() navigateMessageHistory(1) end, consoleTextEdit)
  g_keyboard.bindKeyPress('Shift+Down', function() navigateMessageHistory(-1) end, consoleTextEdit)
  g_keyboard.bindKeyPress('Tab', function() consoleTabBar:selectNextTab() end, consoleTextEdit)
  g_keyboard.bindKeyPress('Shift+Tab', function() consoleTabBar:selectPrevTab() end, consoleTextEdit)
  g_keyboard.bindKeyDown('Enter', sendCurrentMessage, consoleTextEdit)
  g_keyboard.bindKeyDown('Escape', onEscapeCloseChat, consoleTextEdit)

  -- clicking anything outside the chat (the map, the side panels, ...) leaves the
  -- typing mode: the panel loses the focus and the keyboard goes back to the game
  consolePanel.onFocusChange = function(self, focused)
    if not focused and isChatEnabled() then
      disableChat(true)
    end
  end

  -- clicking inside the chat (a tab, a message, a side button) can move the focus
  -- away from the input: keys still reach it, but the caret disappears and the chat
  -- looks dead, so the focus is put back where it belongs
  local refocusingChatInput = false
  consolePanel.onChildFocusChange = function(self, focusedChild, unfocusedChild, reason)
    if refocusingChatInput or not isChatEnabled() then return end
    if focusedChild == consoleTextEdit then return end

    refocusingChatInput = true
    focusWidgetChain(consoleTextEdit)
    refocusingChatInput = false
  end
  
  
  
    cooldownBars = g_ui.createWidget('CooldownBarPanel', modules.game_interface.getMapPanel())
    cooldownBars:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    cooldownBars:addAnchor(AnchorLeft, 'parent', AnchorLeft)
	cooldownBars:setMarginBottom(30)
	cooldownBars:setMarginLeft(25)
  -- apply buttom functions after loaded
  local sidePanel = consolePanel:getChildById('sidePanel')
  local moveUpButton = sidePanel:getChildById('moveUpButton')
  local moveDownButton = sidePanel:getChildById('moveDownButton')
  if consoleTabBar.setNavigation then
    consoleTabBar:setNavigation(moveUpButton, moveDownButton)
  else
    -- this branch's UIMoveableTabBar has no setNavigation
    moveUpButton.onClick = function() consoleTabBar:selectPrevTab() end
    moveDownButton.onClick = function() consoleTabBar:selectNextTab() end
  end
  consoleTabBar.onTabChange = onTabChange

  -- Avatar integration: server broadcasts knockouts through an extended opcode
  local knockoutOk, knockoutErr = pcall(ProtocolGame.registerExtendedOpcode, KNOCKOUT_OPCODE, onKnockoutOpcode)
  if not knockoutOk then
    g_logger.error('[KnockoutLog] falha ao registrar opcode ' .. KNOCKOUT_OPCODE .. ': ' .. tostring(knockoutErr))
  end

  -- Avatar integration: Tab targets the closest monster while the chat is closed
  g_keyboard.bindKeyPress('Tab', onTabPressed)

  -- tibia like hotkeys
  -- (Ctrl+E e Ctrl+H sairam: batiam com o modulo Atributos e com o painel de
  --  EXP, e abriam coisa sozinhas no meio da jogada)
  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyDown('Ctrl+O', g_game.requestChannels, gameRootPanel)
  g_keyboard.bindKeyDown('Enter', onEnterOpenChat, gameRootPanel)

  load()

  -- Inicia o chat sempre lockado (desabilitado)
  -- Usa scheduleEvent para garantir que game_walking esteja carregado
  scheduleEvent(function()
    local chatLockButton = sidePanel:getChildById('chatLockButton')
    if chatLockButton then
      disableChat()
      chatLockButton:setOn(true) -- Lockado (on = chat desabilitado)
      local mask = chatLockButton:getChildById('mask')
      if mask then
        mask:show()
      end
    end
  end, 100)

  if g_game.isOnline() then
    online()
    -- Garante que o chat permaneça lockado mesmo se o jogo já estiver online
    scheduleEvent(function()
      local lockButton = consolePanel:getChildById('sidePanel'):getChildById('chatLockButton')
      if lockButton and not lockButton:isOn() then
        disableChat()
        lockButton:setOn(true)
        local btnMask = lockButton:getChildById('mask')
        if btnMask then
          btnMask:show()
        end
      end
    end, 600)
  end
end



function getConsolePanel()
return consolePanel
end
function getConsoleBar()
return consoleTextEdit
end

function clearSelection(consoleBuffer)
  for _,label in pairs(consoleBuffer:getChildren()) do
    label:clearSelection()
  end
  consoleBuffer.selectionText = nil
  consoleBuffer.selection = nil
end

function selectAll(consoleBuffer)
  clearSelection(consoleBuffer)
  if consoleBuffer:getChildCount() > 0 then
    local text = {}
    for _,label in pairs(consoleBuffer:getChildren()) do
      label:selectAll()
      table.insert(text, label:getSelection())
    end
    consoleBuffer.selectionText = table.concat(text, '\n')
    consoleBuffer.selection = { first = consoleBuffer:getChildIndex(consoleBuffer:getFirstChild()), last = consoleBuffer:getChildIndex(consoleBuffer:getLastChild()) }
  end
end

function toggleChatByOptions(value)
  local button = consolePanel:getChildById('sidePanel'):getChildById('chatLockButton')
  local isButtonActive = button:isOn()
  if isButtonActive == value then
    return true
  end

  if value then
    enableChat()
    button:setOn(true)
  else
    disableChat()
    button:setOn(false)
  end
end

function toggleChat(self)
  if self:isOn() then
    enableChat()
    self:getChildById('mask'):hide()
    self:setOn(false)
  else
    disableChat()
    self:setOn(true)
    self:getChildById('mask'):show()
  end
end

function enableChat(temporarily)
  if not temporarily then
    wsadWalking = false
  end

  consolePanel:show()
  consoleTextEdit:setVisible(true)
  consoleTextEdit:setText("")
  consoleTextEdit:setEditable(true)
  consoleTextEdit:setFocusable(true)

  -- the input takes the keyboard: key events start there, so typing always reaches
  -- the input and the game/hotkeys above the chat never see the keys
  focusWidgetChain(consoleTextEdit)
  consoleTextEdit:setCursorPos(0)
  consoleTextEdit:grabKeyboard()

  -- re-assert once: the key/mouse release that opened the chat can hand the focus
  -- back to the game right after this
  scheduleEvent(function()
    if isChatEnabled() then
      focusWidgetChain(consoleTextEdit)
    end
  end, 1)

  disableWasdWalking()
end

function disableChat(temporarily)
  if not temporarily then
    wsadWalking = true
  end

  consoleTextEdit:setVisible(false)
  consoleTextEdit:setText("")
  consoleTextEdit:ungrabKeyboard()
  consolePanel:ungrabKeyboard()

  -- hand the keyboard back to the game instead of leaving it on the hidden input:
  -- the walk keys live on the game root panel and it only sees them when the focus
  -- chain reaches it. (skipped while offline, where the login windows own the focus)
  local gameRootPanel = modules.game_interface.getRootPanel()
  if gameRootPanel and g_game.isOnline() then
    focusWidgetChain(gameRootPanel)
  end

  enableWasdWalking()
end

function isChatEnabled()
  -- chamado tambem durante a destruicao da janela (onFocusChange -> destroy no
  -- terminate), quando consoleTextEdit ja nao existe: indexar direto gerava
  -- erro no unload do module.
  return consoleTextEdit ~= nil and consoleTextEdit:isVisible()
end

function terminate()
  save()
  disconnect(g_game, {
    onTalk = onTalk,
    onChannelList = onChannelList,
    onOpenChannel = onOpenChannel,
    onOpenPrivateChannel = onOpenPrivateChannel,
    onOpenOwnPrivateChannel = onOpenPrivateChannel,
    onCloseChannel = onCloseChannel,
    onRuleViolationChannel = onRuleViolationChannel,
    onRuleViolationRemove = onRuleViolationRemove,
    onRuleViolationCancel = onRuleViolationCancel,
    onRuleViolationLock = onRuleViolationLock,
    onGameStart = online,
    onGameEnd = offline,
    onChannelEvent = onChannelEvent,
  })

  if g_game.isOnline() then clear() end

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyDown('Ctrl+O', gameRootPanel)
  g_keyboard.unbindKeyDown('Enter', gameRootPanel)

  -- Avatar integration
  pcall(ProtocolGame.unregisterExtendedOpcode, KNOCKOUT_OPCODE)
  g_keyboard.unbindKeyPress('Tab')
  if Stickers and Stickers.stickersPanel then
    Stickers.stickersPanel:destroy()
    Stickers.stickersPanel = nil
  end

  saveCommunicationSettings()

  if channelsWindow then
    channelsWindow:destroy()
  end

  if communicationWindow then
    communicationWindow:destroy()
  end

  if violationWindow then
    violationWindow:destroy()
  end

  consoleTabBar = nil
  consoleContentPanel = nil
  consoleTextEdit = nil

  consolePanel:destroy()
  consolePanel = nil
  ownPrivateName = nil

  Console = nil
end

function save()
  local settings = {}
  settings.messageHistory = messageHistory
  g_settings.setNode('game_chat', settings)
end

function load()
  local settings = g_settings.getNode('game_chat')
  if settings then
    messageHistory = settings.messageHistory or {}
  end
  loadCommunicationSettings()
end

function onTabChange(tabBar, tab)
  
end

function clear()
  -- save last open channels
  local lastChannelsOpen = g_settings.getNode('lastChannelsOpen') or {}
  local char = g_game.getCharacterName()
  local savedChannels = {}
  local set = false
  for channelId, channelName in pairs(channels) do
    if type(channelId) == 'number' then
      savedChannels[channelName] = channelId
      set = true
    end
  end
  if set then
    lastChannelsOpen[char] = savedChannels
  else
    lastChannelsOpen[char] = nil
  end
  g_settings.setNode('lastChannelsOpen', lastChannelsOpen)

  -- close channels
  for _, channelName in pairs(channels) do
    local tab = consoleTabBar:getTab(channelName)
    consoleTabBar:removeTab(tab)
  end
  channels = {}

  consoleTabBar:removeTab(defaultTab)
  defaultTab = nil
  consoleTabBar:removeTab(serverTab)
  serverTab = nil
  if knockoutTab then -- Avatar integration
    consoleTabBar:removeTab(knockoutTab)
    knockoutTab = nil
  end

  local npcTab = consoleTabBar:getTab('NPCs')
  if npcTab then
    consoleTabBar:removeTab(npcTab)
    npcTab = nil
  end

  if violationReportTab then
    consoleTabBar:removeTab(violationReportTab)
    violationReportTab = nil
  end

  consoleTextEdit:clearText()

  if violationWindow then
    violationWindow:destroy()
    violationWindow = nil
  end

  if channelsWindow then
    channelsWindow:destroy()
    channelsWindow = nil
  end
end

function switchMode(newView)
  if newView then
    consolePanel:setImageColor('#ffffff88')  
  else
    consolePanel:setImageColor('white')  
  end
  --consolePanel:setDraggable(floating)
  --consoleTabBar:setDraggable(floating)
  --floatingMode = floating
end

function onDragEnter(widget, pos)
  return floatingMode
end

function onDragMove(widget, pos, moved)
  if not floatingMode then
    return
  end
  -- update margin
  return true
end

function onDragLeave(widget, pos)
  return floatingMode
end

function clearChannel(consoleTabBar)
  consoleTabBar:getCurrentTab().tabPanel:getChildById('consoleBuffer'):destroyChildren()
end

function setTextEditText(text)
  consoleTextEdit:setText(text)
  consoleTextEdit:setCursorPos(-1)
end

function openHelp()
  local helpChannel = 9
  if g_game.getClientVersion() <= 810 then
    helpChannel = 8
  end
  g_game.joinChannel(helpChannel)
end

function openPlayerReportRuleViolationWindow()
  if violationWindow or violationReportTab then return end
  violationWindow = g_ui.loadUI('violationwindow', rootWidget)
  violationWindow.onEscape = function()
    violationWindow:destroy()
    violationWindow = nil
  end
  violationWindow.onEnter = function()
    local text = violationWindow:getChildById('text'):getText()
    g_game.talkChannel(MessageModes.RVRChannel, 0, text)
    violationReportTab = addTab(tr('Report Rule') .. '...', true)
    addTabText(tr('Please wait patiently for a gamemaster to reply') .. '.', SpeakTypesSettings.privateRed, violationReportTab)
    addTabText(applyMessagePrefixies(g_game.getCharacterName(), 0, text),  SpeakTypesSettings.say, violationReportTab, g_game.getCharacterName())
    violationReportTab.locked = true
    violationWindow:destroy()
    violationWindow = nil
  end
end

function addTab(name, focus)
  local tab = getTab(name)
  if tab then -- is channel already open
    if not focus then focus = true end
  else
    tab = consoleTabBar:addTab(name, nil, processChannelTabMenu)
    tab:setIconWidth(tab:getWidth())
  end
  if focus then
    consoleTabBar:selectTab(tab)
  end
  return tab
end

function removeTab(tab)
  if type(tab) == 'string' then
    tab = consoleTabBar:getTab(tab)
  end

  if tab == defaultTab or tab == serverTab then
    return
  end

  if tab == violationReportTab then
    g_game.cancelRuleViolation()
    violationReportTab = nil
  elseif tab.violationChatName then
    g_game.closeRuleViolation(tab.violationChatName)
  elseif tab.channelId then
    -- notificate the server that we are leaving the channel
    for k, v in pairs(channels) do
      if (k == tab.channelId) then channels[k] = nil end
    end
    g_game.leaveChannel(tab.channelId)
  elseif tab:getText() == "NPCs" then
    g_game.closeNpcChannel()
  end

  if getCurrentTab() == tab then
    consoleTabBar:selectTab(defaultTab)
  end

  consoleTabBar:removeTab(tab)
end

function removeCurrentTab()
  removeTab(consoleTabBar:getCurrentTab())
end

function getTab(name)
  return consoleTabBar:getTab(name)
end

function getChannelTab(channelId)
  local channel = channels[channelId]
  if channel then
    return getTab(channel)
  end
  return nil
end

function getRuleViolationsTab()
  if violationsChannelId then
    return getChannelTab(violationsChannelId)
  end
  return nil
end

function getCurrentTab()
  return consoleTabBar:getCurrentTab()
end

function addChannel(name, id)
  channels[id] = name
  local focus = not table.find(ignoredChannels, id)
  local tab = addTab(name, focus)
  tab.channelId = id
  return tab
end

function addPrivateChannel(receiver)
  channels[receiver] = receiver
  return addTab(receiver, true)
end

function addPrivateText(text, speaktype, name, isPrivateCommand, creatureName)
  local focus = false
  if speaktype.npcChat then
    name = 'NPCs'
    focus = true
  end

  local privateTab = getTab(name)
  if privateTab == nil then
    if (modules.client_options.getOption('showPrivateMessagesInConsole') and not focus) or (isPrivateCommand and not privateTab) then
      privateTab = defaultTab
    else
      privateTab = addTab(name, focus)
      channels[name] = name
    end
    privateTab.npcChat = speaktype.npcChat
  elseif focus then
    consoleTabBar:selectTab(privateTab)
  end
  addTabText(text, speaktype, privateTab, creatureName)
end
function addText(text, speaktype, tabName, creatureName)
  local tab = getTab(tabName)
  if tab ~= nil then
    addTabText(text, speaktype, tab, creatureName)
  end
end

-- Contains letter width for font "verdana-11px-antialised" as console is based on it
local letterWidth = {  -- New line (10) and Space (32) have width 1 because they are printed and not replaced with spacer
  [10] = 1, [32] = 1, [33] = 3, [34] = 6, [35] = 8, [36] = 7, [37] = 13, [38] = 9, [39] = 3, [40] = 5, [41] = 5, [42] = 6, [43] = 8, [44] = 4, [45] = 5, [46] = 3, [47] = 8,
  [48] = 7, [49] = 6, [50] = 7, [51] = 7, [52] = 7, [53] = 7, [54] = 7, [55] = 7, [56] = 7, [57] = 7, [58] = 3, [59] = 4, [60] = 8, [61] = 8, [62] = 8, [63] = 6,
  [64] = 10, [65] = 9, [66] = 7, [67] = 7, [68] = 8, [69] = 7, [70] = 7, [71] = 8, [72] = 8, [73] = 5, [74] = 5, [75] = 7, [76] = 7, [77] = 9, [78] = 8, [79] = 8,
  [80] = 7, [81] = 8, [82] = 8, [83] = 7, [84] = 8, [85] = 8, [86] = 8, [87] = 12, [88] = 8, [89] = 8, [90] = 7, [91] = 5, [92] = 8, [93] = 5, [94] = 9, [95] = 8,
  [96] = 5, [97] = 7, [98] = 7, [99] = 6, [100] = 7, [101] = 7, [102] = 5, [103] = 7, [104] = 7, [105] = 3, [106] = 4, [107] = 7, [108] = 3, [109] = 11, [110] = 7,
  [111] = 7, [112] = 7, [113] = 7, [114] = 6, [115] = 6, [116] = 5, [117] = 7, [118] = 8, [119] = 10, [120] = 8, [121] = 8, [122] = 6, [123] = 7, [124] = 4, [125] = 7, [126] = 8,
  [127] = 1, [128] = 7, [129] = 6, [130] = 3, [131] = 7, [132] = 6, [133] = 11, [134] = 7, [135] = 7, [136] = 7, [137] = 13, [138] = 7, [139] = 4, [140] = 11, [141] = 6, [142] = 6,
  [143] = 6, [144] = 6, [145] = 4, [146] = 3, [147] = 7, [148] = 6, [149] = 6, [150] = 7, [151] = 10, [152] = 7, [153] = 10, [154] = 6, [155] = 5, [156] = 11, [157] = 6, [158] = 6,
  [159] = 8, [160] = 4, [161] = 3, [162] = 7, [163] = 7, [164] = 7, [165] = 8, [166] = 4, [167] = 7, [168] = 6, [169] = 10, [170] = 6, [171] = 8, [172] = 8, [173] = 16, [174] = 10,
  [175] = 8, [176] = 5, [177] = 8, [178] = 5, [179] = 5, [180] = 6, [181] = 7, [182] = 7, [183] = 3, [184] = 5, [185] = 6, [186] = 6, [187] = 8, [188] = 12, [189] = 12, [190] = 12,
  [191] = 6, [192] = 9, [193] = 9, [194] = 9, [195] = 9, [196] = 9, [197] = 9, [198] = 11, [199] = 7, [200] = 7, [201] = 7, [202] = 7, [203] = 7, [204] = 5, [205] = 5, [206] = 6,
  [207] = 5, [208] = 8, [209] = 8, [210] = 8, [211] = 8, [212] = 8, [213] = 8, [214] = 8, [215] = 8, [216] = 8, [217] = 8, [218] = 8, [219] = 8, [220] = 8, [221] = 8, [222] = 7,
  [223] = 7, [224] = 7, [225] = 7, [226] = 7, [227] = 7, [228] = 7, [229] = 7, [230] = 11, [231] = 6, [232] = 7, [233] = 7, [234] = 7, [235] = 7, [236] = 3, [237] = 4, [238] = 4,
  [239] = 4, [240] = 7, [241] = 7, [242] = 7, [243] = 7, [244] = 7, [245] = 7, [246] = 7, [247] = 9, [248] = 7, [249] = 7, [250] = 7, [251] = 7, [252] = 7, [253] = 8, [254] = 7, [255] = 8
}

-- Return information about start, end in the string and the highlighted words
function getHighlightedText(text)
  local tmpData = {}

  repeat
    local tmp = {string.find(text, "{([^}]+)}", tmpData[#tmpData-1])}
    for _, v in pairs(tmp) do
      table.insert(tmpData, v)
    end
  until not(string.find(text, "{([^}]+)}", tmpData[#tmpData-1]))

  return tmpData
end

function getNewHighlightedText(text, color, highlightColor)
  local tmpData = {}
  
  for i, part in ipairs(text:split("{")) do
    if i == 1 then
      table.insert(tmpData, part)
      table.insert(tmpData, color)
    else
      for j, part2 in ipairs(part:split("}")) do
        if j == 1 then
          table.insert(tmpData, part2)
          table.insert(tmpData, highlightColor)
        else
          table.insert(tmpData, part2)
          table.insert(tmpData, color)
        end
      end
    end
  end

  return tmpData
end

CONSOLE_LOOTCOLOR_RARE = "blue"
CONSOLE_LOOTCOLOR_EPIC = "red"
CONSOLE_LOOTCOLOR_LEGENDARY = "green"
CONSOLE_LOOTCOLOR_NORMAL = "orange"
CONSOLE_LOOTCOLOR_REST = "white"
function getRarityHighlightedText(text,basicColor,textBefore)
  local tmpData = {}
          table.insert(tmpData, textBefore)
          table.insert(tmpData, CONSOLE_LOOTCOLOR_REST)
  local splittedText = text:split(",")
  for i, part in pairs(splittedText) do
  if string.find(part, "{legendary}") then
  local stringFix = part:gsub("{legendary}","")
          table.insert(tmpData, stringFix)
          table.insert(tmpData, CONSOLE_LOOTCOLOR_LEGENDARY)
  elseif string.find(part, "{epic}") then
  local stringFix = part:gsub("{epic}","")
          table.insert(tmpData, stringFix)
          table.insert(tmpData, CONSOLE_LOOTCOLOR_EPIC)
  elseif string.find(part, "{rare}") then
  local stringFix = part:gsub("{rare}","")
          table.insert(tmpData, stringFix)
          table.insert(tmpData, CONSOLE_LOOTCOLOR_RARE)
  else
  local stringFix = part:gsub("{normal}","")
          table.insert(tmpData, stringFix)
          table.insert(tmpData, CONSOLE_LOOTCOLOR_NORMAL)
	end
		if i ~= #splittedText then
      table.insert(tmpData, ",")
      table.insert(tmpData, CONSOLE_LOOTCOLOR_REST)
	  end
  end

  return tmpData
end

local CHAT_ANIMATION_DURATION = 350 -- duração da animação em ms
local CHAT_MIN_WIDTH = 36
local CHAT_MAX_WIDTH = 550

function expandChat(self)
  -- Cancela animação anterior se existir
  if consolePanel.expandEvent then
    removeEvent(consolePanel.expandEvent)
    consolePanel.expandEvent = nil
  end

  local isExpanding = self:isOn()
  local targetWidth = isExpanding and CHAT_MAX_WIDTH or CHAT_MIN_WIDTH
  local startWidth = consolePanel:getWidth()
  local startTime = g_clock.millis()

  -- Define elementos que serão animados
  local elementsToAnimate = {
    consoleTabBar,
    consoleContentPanel,
    sendMessageButton,
    consoleTextBackground,
    panelBox
  }

  -- Prepara elementos para animação
  if isExpanding then
    -- Expandindo - mostra elementos com opacidade 0
    for _, element in pairs(elementsToAnimate) do
      if element then
        element:setVisible(true)
        element:setOpacity(0)
      end
    end
    self:setOn(false)
  else
    -- Colapsando - inicia animação de fade out
    self:setOn(true)
  end

  -- Função de atualização da animação
  local function updateAnimation()
    local elapsed = g_clock.millis() - startTime
    local progress = math.min(elapsed / CHAT_ANIMATION_DURATION, 1.0)
    
    -- Interpolação suave (ease-out)
    local easeProgress = 1 - math.pow(1 - progress, 3)
    
    -- Anima a largura
    local currentWidth = startWidth + (targetWidth - startWidth) * easeProgress
    consolePanel:setWidth(currentWidth)
    
    -- Anima a opacidade dos elementos
    if isExpanding then
      -- Fade in
      local opacity = easeProgress
      for _, element in pairs(elementsToAnimate) do
        if element then
          element:setOpacity(opacity)
        end
      end
      
      -- Garante opacidade total quando animação termina
      if progress >= 1.0 then
        for _, element in pairs(elementsToAnimate) do
          if element then
            element:setOpacity(1.0)
          end
        end
      end
    else
      -- Fade out
      local opacity = 1 - easeProgress
      for _, element in pairs(elementsToAnimate) do
        if element then
          element:setOpacity(opacity)
        end
      end
      
      -- Esconde elementos quando animação termina
      if progress >= 1.0 then
        for _, element in pairs(elementsToAnimate) do
          if element then
            element:setVisible(false)
            element:setOpacity(1.0) -- Reseta opacidade para próxima vez
          end
        end
      end
    end
    
    -- Continua animação se não terminou
    if progress < 1.0 then
      consolePanel.expandEvent = scheduleEvent(updateAnimation, 16) -- ~60fps
    else
      consolePanel.expandEvent = nil
    end
  end

  -- Inicia a animação
  updateAnimation()
end

function addTabText(text, speaktype, tab, creatureName)
  if not tab or tab.locked or not text or #text == 0 then return end

  local timestamp = ''
  if modules.client_options.getOption('showTimestampsInConsole') then
    timestamp = os.date('%H:%M') .. ' '
  end

  text = timestamp .. text

  local panel = consoleTabBar:getTabPanel(tab)
  local consoleBuffer = panel:getChildById('consoleBuffer')

  local label = nil
  if consoleBuffer:getChildCount() > MAX_LINES then
    label = consoleBuffer:getFirstChild()
    consoleBuffer:moveChildToIndex(label, consoleBuffer:getChildCount())
  end

  if not label then
    label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
  end
  label:setId('consoleLabel' .. consoleBuffer:getChildCount())
  label:setText(text)
  label:setColor(speaktype.color)
  consoleTabBar:blinkTab(tab)

  local name = label:getChildById('name')
  if name and creatureName then
    name:setText(timestamp .. creatureName)
  end

	if tab:getText():lower() == "loot" then
  local lootList = text:split("Loot of")
  local lootList2 = lootList[2]:split(":")
  local getList = lootList2[2]
  if lootList2[2] then
		local highlightData = getRarityHighlightedText(lootList2[2],speaktype.color,text:gsub(lootList2[2],""))
		if #highlightData > 1 then
			label:setColoredText(highlightData)
		end
	end
end

  if speaktype.npcChat and (g_game.getCharacterName() ~= creatureName or g_game.getCharacterName() == 'Account Manager') then
    local highlightData = getNewHighlightedText(text, speaktype.color, "#3ebaf3")
    if #highlightData > 2 then
      label:setColoredText(highlightData)
    end
  end


  label.name = creatureName
  consoleBuffer.onMouseRelease = function(self, mousePos, mouseButton)
    processMessageMenu(mousePos, mouseButton, nil, nil, nil, tab)
  end
  label.onMouseRelease = function(self, mousePos, mouseButton)
    processMessageMenu(mousePos, mouseButton, creatureName, text, self, tab)
  end
  label.onMousePress = function(self, mousePos, button)
    if button == MouseLeftButton then clearSelection(consoleBuffer) end
  end
  label.onDragEnter = function(self, mousePos)
    clearSelection(consoleBuffer)
    return true
  end
  label.onDragLeave = function(self, droppedWidget, mousePos)
    local text = {}
    for selectionChild = consoleBuffer.selection.first, consoleBuffer.selection.last do
      local label = self:getParent():getChildByIndex(selectionChild)
      table.insert(text, label:getSelection())
    end
    consoleBuffer.selectionText = table.concat(text, '\n')
    return true
  end
  label.onDragMove = function(self, mousePos, mouseMoved)
    local parent = self:getParent()
    local parentRect = parent:getPaddingRect()
    local selfIndex = parent:getChildIndex(self)
    local child = parent:getChildByPos(mousePos)

    -- find bonding children
    if not child then
      if mousePos.y < self:getY() then
        for index = selfIndex - 1, 1, -1 do
          local label = parent:getChildByIndex(index)
          if label:getY() + label:getHeight() > parentRect.y then
            if (mousePos.y >= label:getY() and mousePos.y <= label:getY() + label:getHeight()) or index == 1 then
              child = label
              break
            end
          else
            child = parent:getChildByIndex(index + 1)
            break
          end
        end
      elseif mousePos.y > self:getY() + self:getHeight() then
        for index = selfIndex + 1, parent:getChildCount(), 1 do
          local label = parent:getChildByIndex(index)
          if label:getY() < parentRect.y + parentRect.height then
            if (mousePos.y >= label:getY() and mousePos.y <= label:getY() + label:getHeight()) or index == parent:getChildCount() then
              child = label
              break
            end
          else
            child = parent:getChildByIndex(index - 1)
            break
          end
        end
      else
        child = self
      end
    end

    if not child then return false end

    local childIndex = parent:getChildIndex(child)

    -- remove old selection
    clearSelection(consoleBuffer)

    -- update self selection
    local textBegin = self:getTextPos(self:getLastClickPosition())
    local textPos = self:getTextPos(mousePos)
    self:setSelection(textBegin, textPos)

    consoleBuffer.selection = { first = math.min(selfIndex, childIndex), last = math.max(selfIndex, childIndex) }

    -- update siblings selection
    if child ~= self then
      for selectionChild = consoleBuffer.selection.first + 1, consoleBuffer.selection.last - 1 do
        parent:getChildByIndex(selectionChild):selectAll()
      end

      local textPos = child:getTextPos(mousePos)
      if childIndex > selfIndex then
        child:setSelection(0, textPos)
      else
        child:setSelection(string.len(child:getText()), textPos)
      end
    end

    return true
  end
end

function removeTabLabelByName(tab, name)
  local panel = consoleTabBar:getTabPanel(tab)
  local consoleBuffer = panel:getChildById('consoleBuffer')
  for _,label in pairs(consoleBuffer:getChildren()) do
    if label.name == name then
      label:destroy()
    end
  end
end

function processChannelTabMenu(tab, mousePos, mouseButton)
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)

  local worldName = g_game.getWorldName()
  local characterName = g_game.getCharacterName()
  channelName = tab:getText()
  if tab ~= defaultTab and tab ~= serverTab then
    menu:addOption(tr('Close'), function() removeTab(channelName) end)
    --menu:addOption(tr('Show Server Messages'), function() --[[TODO]] end)
    menu:addSeparator()
  end

  if consoleTabBar:getCurrentTab() == tab then
    menu:addOption(tr('Clear Messages'), function() clearChannel(consoleTabBar) end)
    menu:addOption(tr('Save Messages'), function()
      local panel = consoleTabBar:getTabPanel(tab)
      local consoleBuffer = panel:getChildById('consoleBuffer')
      local lines = {}
      for _,label in pairs(consoleBuffer:getChildren()) do
        table.insert(lines, label:getText())
      end

      local filename = worldName .. ' - ' .. characterName .. ' - ' .. channelName .. '.txt'
      local filepath = '/user_dir/' .. filename

      -- extra information at the beginning
      table.insert(lines, 1, os.date('\nChannel saved at %a %b %d %H:%M:%S %Y'))

      if g_resources.fileExists(filepath) then
        table.insert(lines, 1, protectedcall(g_resources.readFileContents, filepath) or '')
      end

      g_resources.writeFileContents(filepath, table.concat(lines, '\n'))
      modules.game_textmessage.displayStatusMessage(tr('Channel appended to %s', filename))
    end)
  end

  menu:display(mousePos)
end

function processMessageMenu(mousePos, mouseButton, creatureName, text, label, tab)
  if mouseButton == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    if creatureName and #creatureName > 0 then
      if creatureName ~= g_game.getCharacterName() then
        menu:addOption(tr('Message to ' .. creatureName), function () g_game.openPrivateChannel(creatureName) end)
        if not g_game.getLocalPlayer():hasVip(creatureName) then
          menu:addOption(tr('Add to VIP list'), function () g_game.addVip(creatureName) end)
        end
        if getOwnPrivateTab() then
          menu:addSeparator()
          menu:addOption(tr('Invite to private chat'), function() g_game.inviteToOwnChannel(creatureName) end)
          menu:addOption(tr('Exclude from private chat'), function() g_game.excludeFromOwnChannel(creatureName) end)
        end
        if isIgnored(creatureName) then
          menu:addOption(tr('Unignore') .. ' ' .. creatureName, function() removeIgnoredPlayer(creatureName) end)
        else
          menu:addOption(tr('Ignore') .. ' ' .. creatureName, function() addIgnoredPlayer(creatureName) end)
        end
        menu:addSeparator()
      end
      if modules.game_ruleviolation.hasWindowAccess() then
        menu:addOption(tr('Rule Violation'), function() modules.game_ruleviolation.show(creatureName, text:match('.+%:%s(.+)')) end)
        menu:addSeparator()
      end

      menu:addOption(tr('Copy name'), function () g_window.setClipboardText(creatureName) end)
    end
    local selection = tab.tabPanel:getChildById('consoleBuffer').selectionText
    if selection and #selection > 0 then
      menu:addOption(tr('Copy'), function() g_window.setClipboardText(selection) end, '(Ctrl+C)')
    end
    if text then
      menu:addOption(tr('Copy message'), function() g_window.setClipboardText(text) end)
    end
    menu:addOption(tr('Select all'), function() selectAll(tab.tabPanel:getChildById('consoleBuffer')) end)
    if tab.violations and creatureName then
      menu:addSeparator()
      menu:addOption(tr('Process') .. ' ' .. creatureName, function() processViolation(creatureName, text) end)
      menu:addOption(tr('Remove') .. ' ' .. creatureName, function() g_game.closeRuleViolation(creatureName) end)
    end
    menu:display(mousePos)
  end
end

function sendCurrentMessage()
  if not isChatEnabled() then
    enableChat(true)
    return
  end
  
  local message = consoleTextEdit:getText()
  if #message == 0 then
    if wsadWalking then
      disableChat(true)
    end
    return 
  end
  
  consoleTextEdit:clearText()

  -- send message
  sendMessage(message)
  
  if wsadWalking then
    disableChat(true)
  end
end

function onTextChange(self)
	if self:getText() ~= '' then
		self:getChildById('mask'):hide()
	else
		self:getChildById('mask'):show()
	end
end

function clearCurrentTab(self)
  local consoleTabBar = self:getParent():getParent():getChildById("consoleTabBar")
  clearChannel(consoleTabBar)
end

function openNewChannel()
  consolePanel:getChildById('sidePanel'):getChildById('openChatButton'):getChildById('mask'):show()
  g_game.requestChannels()
end

function addFilter(filter)
  table.insert(filters, filter)
end

function removeFilter(filter)
  table.removevalue(filters, filter)
end

function sendMessage(message, tab)
  local tab = tab or getCurrentTab()
  if not tab then return end

  -- Support both /testbeam and /testebeam, case insensitive
  local beamCommand = message:match("^/[Tt]est[e]?beam%s+(.+)") or 
                      message:match("^[Tt]est[e]?beam%s+\"([^\"]+)\"") or
                      message:match("^[Tt]est[e]?beam%s+(.+)")

  if beamCommand then
    g_logger.info("Beam command detected with parameter: " .. beamCommand)
    
    if not Beam or not Beam.create then
       g_logger.error("CRITICAL: Beam class is NOT registered in Lua! Did you rebuild the client?")
       return false
    end

    local targetName = beamCommand:trim()
    if targetName:sub(1,1) == "\"" then targetName = targetName:sub(2) end
    if targetName:sub(-1,-1) == "\"" then targetName = targetName:sub(1, -2) end
    
    local target = g_map.getCreatureByName(targetName)
    if not target then
       g_logger.info("Target '" .. targetName .. "' not found by name, searching spectators...")
       local localPlayer = g_game.getLocalPlayer()
       if localPlayer then
         for _, creature in ipairs(g_map.getSpectators(localPlayer:getPosition(), false)) do
           if creature:getName():lower() == targetName:lower() then
             target = creature
             break
           end
         end
       end
    end

    if target then
      g_logger.info("Beam target found: " .. target:getName() .. " (ID: " .. target:getId() .. ")")
      local player = g_game.getLocalPlayer()
      local beam = Beam.create()
      beam:setSourceCreature(player)
      beam:setTargetCreature(target)
      beam:setThickness(30.0) 
      beam:setColor("#FF0000") -- RED
      beam:setShader("beam_shader")
      beam:setDuration(10000) 
      g_map.addBeam(beam)
      g_logger.info("Beam added to map")
      addText("Beam casted on " .. target:getName() .. "!", SpeakTypesSettings.say, tab:getText())
    else
      g_logger.info("Beam target not found: " .. targetName)
      addText("Creature " .. targetName .. " not found.", SpeakTypesSettings.say, tab:getText())
    end
    return true
  end

  -- Shortcut for testingbeam on self or target
  if message:match("^/[Tt]est[e]?beam$") then
     g_logger.info("Short Beam command detected (self/target)")
     if not Beam or not Beam.create then
        g_logger.error("CRITICAL: Beam class is NOT registered in Lua!")
        return false
     end

     local player = g_game.getLocalPlayer()
     local target = g_game.getAttackingCreature()
     
     -- If no attacking target, try to find any nearby creature
     if not target and player then
        local spectators = g_map.getSpectators(player:getPosition(), false)
        for _, creature in ipairs(spectators) do
          if creature ~= player then
            target = creature
            break
          end
        end
     end

     -- Fallback to player
     target = target or player

     if target == player then
        g_logger.info("Test beam fired at SELF (length will be 0.0). Target someone else for a line!")
     else
        g_logger.info("Test beam fired at " .. target:getName())
     end

     local beam = Beam.create()
     beam:setSourceCreature(player)
     beam:setTargetCreature(target)
     beam:setThickness(30.0)
     beam:setColor("#FF0000")
     beam:setShader("beam_shader")
     beam:setDuration(10000)
     g_map.addBeam(beam)
     g_logger.info("Test beam fired at " .. target:getName())
     return true
  end

  for k,func in pairs(filters) do
    if func(message) then
      return true
    end
  end

  -- when talking on server log, the message goes to default channel
  local name = tab:getText()
  if tab == serverTab or tab == knockoutTab or tab == getRuleViolationsTab() then
    tab = defaultTab
    name = defaultTab:getText()
  end

  -- handling chat commands
  local channel = tab.channelId
  local originalMessage = message
  local chatCommandSayMode
  local chatCommandPrivate
  local chatCommandPrivateReady
  local chatCommandMessage

  -- player used yell command
  chatCommandMessage = message:match("^%#[y|Y] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'yell'
    channel = 0
    message = chatCommandMessage
  end

   -- player used whisper
  chatCommandMessage = message:match("^%#[w|W] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'whisper'
    message = chatCommandMessage
    channel = 0
  end

  -- player say
  chatCommandMessage = message:match("^%#[s|S] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'say'
    message = chatCommandMessage
    channel = 0
  end

  -- player red talk on channel
  chatCommandMessage = message:match("^%#[c|C] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'channelRed'
    message = chatCommandMessage
  end

  -- player broadcast
  chatCommandMessage = message:match("^%#[b|B] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'broadcast'
    message = chatCommandMessage
    channel = 0
  end

  local findIni, findEnd, chatCommandInitial, chatCommandPrivate, chatCommandEnd, chatCommandMessage = message:find("([%*%@])(.+)([%*%@])(.*)")
  if findIni ~= nil and findIni == 1 then -- player used private chat command
    if chatCommandInitial == chatCommandEnd then
      chatCommandPrivateRepeat = false
      if chatCommandInitial == "*" then
        setTextEditText('*'.. chatCommandPrivate .. '* ')
      end
      message = chatCommandMessage:trim()
      chatCommandPrivateReady = true
    end
  end

  message = message:gsub("^(%s*)(.*)","%2") -- remove space characters from message init
  if #message == 0 then return end

  -- add new command to history
  currentMessageIndex = 0
  if #messageHistory == 0 or messageHistory[#messageHistory] ~= originalMessage then
    table.insert(messageHistory, originalMessage)
    if #messageHistory > MAX_HISTORY then
      table.remove(messageHistory, 1)
    end
  end

  local speaktypedesc
  if (channel or tab == defaultTab) and not chatCommandPrivateReady then
    if tab == defaultTab then
      speaktypedesc = chatCommandSayMode or 'say'
    else
      speaktypedesc = chatCommandSayMode or 'channelYellow'
    end

    g_game.talkChannel(SpeakTypesSettings[speaktypedesc].speakType, channel, message)
    return
  else
    local isPrivateCommand = false
    local priv = true
    local tabname = name
    local dontAdd = false
    if chatCommandPrivateReady then
      speaktypedesc = 'privatePlayerToPlayer'
      name = chatCommandPrivate
      isPrivateCommand = true
    elseif tab.npcChat then
      speaktypedesc = 'privatePlayerToNpc'
    elseif tab == violationReportTab then
      if violationReportTab.locked then
        modules.game_textmessage.displayFailureMessage('Wait for a gamemaster reply.')
        dontAdd = true
      else
        speaktypedesc = 'rvrContinue'
        tabname = tr('Report Rule') .. '...'
      end
    elseif tab.violationChatName then
      speaktypedesc = 'rvrAnswerTo'
      name = tab.violationChatName
      tabname = tab.violationChatName .. '\'...'
    else
      speaktypedesc = 'privatePlayerToPlayer'
    end


    local speaktype = SpeakTypesSettings[speaktypedesc]
    local player = g_game.getLocalPlayer()
    g_game.talkPrivate(speaktype.speakType, name, message)
    if not dontAdd then
      message = applyMessagePrefixies(g_game.getCharacterName(), player:getLevel(), message)
      addPrivateText(message, speaktype, tabname, isPrivateCommand, g_game.getCharacterName())
    end
  end
end

function getOwnPrivateTab()
  if not ownPrivateName then return end
  return getTab(ownPrivateName)
end

function setIgnoreNpcMessages(ignore)
  ignoreNpcMessages = ignore
end

function navigateMessageHistory(step)
  if not isChatEnabled() then
    return
  end

  local numCommands = #messageHistory
  if numCommands > 0 then
    currentMessageIndex = math.min(math.max(currentMessageIndex + step, 0), numCommands)
    if currentMessageIndex > 0 then
      local command = messageHistory[numCommands - currentMessageIndex + 1]
      setTextEditText(command)
    else
      consoleTextEdit:clearText()
    end
  end
  local player = g_game.getLocalPlayer()
  if player then
    player:lockWalk(200) -- lock walk for 200 ms to avoid walk during release of shift
  end
end

function applyMessagePrefixies(name, level, message)
  if name and #name > 0 then
    if modules.client_options.getOption('showLevelsInConsole') and level > 0 then
      message = name .. ' [' .. level .. ']: ' .. message
    else
      message = name .. ': ' .. message
    end
  end
  return message
end

function onTalk(name, level, mode, message, channelId, creaturePos)
  -- Avatar integration: messages matching a sticker code are drawn in the world
  local stickerConfig = Stickers and Stickers.stickersConfig[message]
  if stickerConfig then
    if creaturePos then
      local tile = g_map.getTile(creaturePos)
      if tile and not tile:getWidget() then
        Stickers.createSticker(tile, stickerConfig)
      end
    end
    return
  end

  if mode == MessageModes.GamemasterBroadcast then
    modules.game_textmessage.displayBroadcastMessage(name .. ': ' .. message)
    return
  end

  local isNpcMode = (mode == MessageModes.NpcFromStartBlock or mode == MessageModes.NpcFrom)

  if ignoreNpcMessages and isNpcMode then return end

  speaktype = SpeakTypes[mode]

  if not speaktype then
    perror('unhandled onTalk message mode ' .. mode .. ': ' .. message)
    return
  end

  local localPlayer = g_game.getLocalPlayer()
  if name ~= g_game.getCharacterName()
      and isUsingIgnoreList()
        and not(isUsingWhiteList()) or (isUsingWhiteList() and not(isWhitelisted(name)) and not(isAllowingVIPs() and localPlayer:hasVip(name))) then

    if mode == MessageModes.Yell and isIgnoringYelling() then
      return
    elseif speaktype.private and isIgnoringPrivate() and not isNpcMode then
      return
    elseif isIgnored(name) then
      return
    end
  end

  if mode == MessageModes.RVRChannel then
    channelId = violationsChannelId
  end

  if (mode == MessageModes.Say or mode == MessageModes.Whisper or mode == MessageModes.Yell or
      mode == MessageModes.Spell or mode == MessageModes.MonsterSay or mode == MessageModes.MonsterYell or
      mode == MessageModes.NpcFrom or mode == MessageModes.BarkLow or mode == MessageModes.BarkLoud or
      mode == MessageModes.NpcFromStartBlock) and creaturePos then

    -- Try to find the creature that spoke the message at the specified position
    local tile = g_map.getTile(creaturePos)
    local creature = tile and tile:getTopCreature()

    -- Landcore draws these as bubbles owned by the creature (Creature:addChatMessage).
    -- That is a client patch this client does not have, so whenever the method is
    -- missing (or throws) we fall back to the classic StaticText on the tile instead of
    -- losing the message silently - otherwise nothing is drawn in the game world.
    local drewOnCreature = false
    if creature and type(creature.addChatMessage) == "function" then
      -- Extract RGB values from hex color string
      local colorHex = speaktype.color or "#FFFFFF"
      local r = tonumber(colorHex:sub(2, 3), 16) or 255
      local g = tonumber(colorHex:sub(4, 5), 16) or 255
      local b = tonumber(colorHex:sub(6, 7), 16) or 255
      local success, errorMsg = pcall(function()
        creature:addChatMessage(mode, message, isNpcMode and true or false, r, g, b)
      end)
      if success then
        drewOnCreature = true
      else
        g_logger.warning("Failed to add chat message to creature: " .. errorMsg)
      end
    end

    if not drewOnCreature then
      -- Fallback: create static text at position (old behavior)
      local staticText = StaticText.create()
      -- Remove curly braces from screen message
      local staticMessage = message
      if isNpcMode then
        local highlightData = getNewHighlightedText(staticMessage, speaktype.color, "#3ebaf3")
        if #highlightData > 2 then
          staticText:addColoredMessage(name, mode, highlightData)
        else
          staticText:addMessage(name, mode, staticMessage)
        end
        staticText:setColor(speaktype.color)
      else
        staticText:addMessage(name, mode, staticMessage)
      end
      g_map.addThing(staticText, creaturePos, -1)
    end
  end

  local defaultMessage = mode <= 3 and true or false

  if speaktype == SpeakTypesSettings.none then return end

  if speaktype.hideInConsole then return end

  local composedMessage = applyMessagePrefixies(name, level, message)

  if mode == MessageModes.RVRAnswer then
    violationReportTab.locked = false
    addTabText(composedMessage, speaktype, violationReportTab, name)
  elseif mode == MessageModes.RVRContinue then
    addText(composedMessage, speaktype, name .. '\'...', name)
  elseif speaktype.private then
    addPrivateText(composedMessage, speaktype, name, false, name)
    if modules.client_options.getOption('showPrivateMessagesOnScreen') and speaktype ~= SpeakTypesSettings.privateNpcToPlayer then
      modules.game_textmessage.displayPrivateMessage(name .. ':\n' .. message)
    end
  else
    local channel = tr('Default')
    if not defaultMessage then
      channel = channels[channelId]
    end

    if channel then
      addText(composedMessage, speaktype, channel, name)
    else
      -- server sent a message on a channel that is not open
      pwarning('message in channel id ' .. channelId .. ' which is unknown, this is a server bug, relogin if you want to see messages in this channel')
    end
  end
end

function onOpenChannel(channelId, channelName)
  addChannel(channelName, channelId)
end

function onOpenPrivateChannel(receiver)
  addPrivateChannel(receiver)
end

function onOpenOwnPrivateChannel(channelId, channelName)
  local privateTab = getTab(channelName)
  if privateTab == nil then
    addChannel(channelName, channelId)
  end
  ownPrivateName = channelName
end

function onCloseChannel(channelId)
  local channel = channels[channelId]
  if channel then
    local tab = getTab(channel)
    if tab then
      consoleTabBar:removeTab(tab)
    end
    for k, v in pairs(channels) do
      if (k == tab.channelId) then channels[k] = nil end
    end
  end
end

function processViolation(name, text)
  local tabname = name .. '\'...'
  local tab = addTab(tabname, true)
  channels[tabname] = tabname
  tab.violationChatName = name
  g_game.openRuleViolation(name)
  addTabText(text, SpeakTypesSettings.say, tab, name)
end

function onRuleViolationChannel(channelId)
  violationsChannelId = channelId
  local tab = addChannel(tr('Rule Violations'), channelId)
  tab.violations = true
end

function onRuleViolationRemove(name)
  local tab = getRuleViolationsTab()
  if not tab then return end
  removeTabLabelByName(tab, name)
end

function onRuleViolationCancel(name)
  local tab = getTab(name .. '\'...')
  if not tab then return end
  addTabText(tr('%s has finished the request', name) .. '.', SpeakTypesSettings.privateRed, tab)
  tab.locked = true
end

function onRuleViolationLock()
  if not violationReportTab then return end
  violationReportTab.locked = false
  addTabText(tr('Your request has been closed') .. '.', SpeakTypesSettings.privateRed, violationReportTab)
  violationReportTab.locked = true
end

function doChannelListSubmit()
  local channelListPanel = channelsWindow:getChildById('channelList')
  local openPrivateChannelWith = channelsWindow:getChildById('openPrivateChannelWith'):getText()
  if openPrivateChannelWith ~= '' then
    if openPrivateChannelWith:lower() ~= g_game.getCharacterName():lower() then
      g_game.openPrivateChannel(openPrivateChannelWith)
    else
      modules.game_textmessage.displayFailureMessage('You cannot create a private chat channel with yourself.')
    end
  else
    local selectedChannelLabel = channelListPanel:getFocusedChild()
    if not selectedChannelLabel then return end
    if selectedChannelLabel.channelId == 0xFFFF then
      g_game.openOwnChannel()
    else
      g_game.leaveChannel(selectedChannelLabel.channelId)
      g_game.joinChannel(selectedChannelLabel.channelId)
    end
  end

  channelsWindow:destroy()
end

function manageButton(name, value)
  consolePanel:getChildById('sidePanel'):getChildById(name):getChildById('mask'):setVisible(value)
end

function onChannelList(channelList)
  if channelsWindow then channelsWindow:destroy() end
  channelsWindow = g_ui.displayUI('channelswindow')
  local channelListPanel = channelsWindow:getChildById('channelList')
  channelsWindow.onEnter = doChannelListSubmit
  channelsWindow.onDestroy = function()
    channelsWindow = nil
    consolePanel:getChildById('sidePanel'):getChildById('openChatButton'):getChildById('mask'):hide()
  end
  g_keyboard.bindKeyPress('Down', function() channelListPanel:focusNextChild(KeyboardFocusReason) end, channelsWindow)
  g_keyboard.bindKeyPress('Up', function() channelListPanel:focusPreviousChild(KeyboardFocusReason) end, channelsWindow)

  for k,v in pairs(channelList) do
    local channelId = v[1]
    local channelName = v[2]

    if #channelName > 0 then
      local label = g_ui.createWidget('ChannelListLabel', channelListPanel)
      label.channelId = channelId
      label:setText(channelName)

      label:setPhantom(false)
      label.onDoubleClick = doChannelListSubmit
    end
  end
end

function loadCommunicationSettings()
  communicationSettings.whitelistedPlayers = {}
  communicationSettings.ignoredPlayers = {}

  local ignoreNode = g_settings.getNode('IgnorePlayers')
  if ignoreNode then
    for _, player in pairs(ignoreNode) do
      table.insert(communicationSettings.ignoredPlayers, player)
    end
  end

  local whitelistNode = g_settings.getNode('WhitelistedPlayers')
  if whitelistNode then
    for _, player in pairs(whitelistNode) do
      table.insert(communicationSettings.whitelistedPlayers, player)
    end
  end

  communicationSettings.useIgnoreList = g_settings.getBoolean('UseIgnoreList')
  communicationSettings.useWhiteList = g_settings.getBoolean('UseWhiteList')
  communicationSettings.privateMessages = g_settings.getBoolean('IgnorePrivateMessages')
  communicationSettings.yelling = g_settings.getBoolean('IgnoreYelling')
  communicationSettings.allowVIPs = g_settings.getBoolean('AllowVIPs')
end

function saveCommunicationSettings()
  local tmpIgnoreList = {}
  local ignoredPlayers = getIgnoredPlayers()
  for i = 1, #ignoredPlayers do
    table.insert(tmpIgnoreList, ignoredPlayers[i])
  end

  local tmpWhiteList = {}
  local whitelistedPlayers = getWhitelistedPlayers()
  for i = 1, #whitelistedPlayers do
    table.insert(tmpWhiteList, whitelistedPlayers[i])
  end

  g_settings.set('UseIgnoreList', communicationSettings.useIgnoreList)
  g_settings.set('UseWhiteList', communicationSettings.useWhiteList)
  g_settings.set('IgnorePrivateMessages', communicationSettings.privateMessages)
  g_settings.set('IgnoreYelling', communicationSettings.yelling)
  g_settings.setNode('IgnorePlayers', tmpIgnoreList)
  g_settings.setNode('WhitelistedPlayers', tmpWhiteList)
end

function getIgnoredPlayers()
  return communicationSettings.ignoredPlayers
end

function getWhitelistedPlayers()
  return communicationSettings.whitelistedPlayers
end

function isUsingIgnoreList()
  return communicationSettings.useIgnoreList
end

function isUsingWhiteList()
  return communicationSettings.useWhiteList
end
function isIgnored(name)
  return table.find(communicationSettings.ignoredPlayers, name, true)
end

function addIgnoredPlayer(name)
  if isIgnored(name) then return end
  table.insert(communicationSettings.ignoredPlayers, name)
  communicationSettings.useIgnoreList = true
end

function removeIgnoredPlayer(name)
  table.removevalue(communicationSettings.ignoredPlayers, name)
end

function isWhitelisted(name)
  return table.find(communicationSettings.whitelistedPlayers, name, true)
end

function addWhitelistedPlayer(name)
  if isWhitelisted(name) then return end
  table.insert(communicationSettings.whitelistedPlayers, name)
end

function removeWhitelistedPlayer(name)
  table.removevalue(communicationSettings.whitelistedPlayers, name)
end

function isIgnoringPrivate()
  return communicationSettings.privateMessages
end

function isIgnoringYelling()
  return communicationSettings.yelling
end

function isAllowingVIPs()
  return communicationSettings.allowVIPs
end

function onClickIgnoreButton()
  if communicationWindow then return end
  communicationWindow = g_ui.displayUI('communicationwindow')
  local ignoreListPanel = communicationWindow:getChildById('ignoreList')
  local whiteListPanel = communicationWindow:getChildById('whiteList')
  communicationWindow.onDestroy = function() communicationWindow = nil end

  local useIgnoreListBox = communicationWindow:getChildById('checkboxUseIgnoreList')
  useIgnoreListBox:setChecked(communicationSettings.useIgnoreList)
  local useWhiteListBox = communicationWindow:getChildById('checkboxUseWhiteList')
  useWhiteListBox:setChecked(communicationSettings.useWhiteList)

  local removeIgnoreButton = communicationWindow:getChildById('buttonIgnoreRemove')
  removeIgnoreButton:disable()
  ignoreListPanel.onChildFocusChange = function() removeIgnoreButton:enable() end
  removeIgnoreButton.onClick = function()
    local selection = ignoreListPanel:getFocusedChild()
    if selection then
      ignoreListPanel:removeChild(selection)
      selection:destroy()
    end
    removeIgnoreButton:disable()
  end

  local removeWhitelistButton = communicationWindow:getChildById('buttonWhitelistRemove')
  removeWhitelistButton:disable()
  whiteListPanel.onChildFocusChange = function() removeWhitelistButton:enable() end
  removeWhitelistButton.onClick = function()
    local selection = whiteListPanel:getFocusedChild()
    if selection then
      whiteListPanel:removeChild(selection)
      selection:destroy()
    end
    removeWhitelistButton:disable()
  end

  local newlyIgnoredPlayers = {}
  local addIgnoreName = communicationWindow:getChildById('ignoreNameEdit')
  local addIgnoreButton = communicationWindow:getChildById('buttonIgnoreAdd')
  local addIgnoreFunction = function()
      local newEntry = addIgnoreName:getText()
      if newEntry == '' then return end
      if table.find(getIgnoredPlayers(), newEntry) then return end
      if table.find(newlyIgnoredPlayers, newEntry) then return end
      local label = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
      label:setText(newEntry)
      table.insert(newlyIgnoredPlayers, newEntry)
      addIgnoreName:setText('')
    end
  addIgnoreButton.onClick = addIgnoreFunction

  local newlyWhitelistedPlayers = {}
  local addWhitelistName = communicationWindow:getChildById('whitelistNameEdit')
  local addWhitelistButton = communicationWindow:getChildById('buttonWhitelistAdd')
  local addWhitelistFunction = function()
      local newEntry = addWhitelistName:getText()
      if newEntry == '' then return end
      if table.find(getWhitelistedPlayers(), newEntry) then return end
      if table.find(newlyWhitelistedPlayers, newEntry) then return end
      local label = g_ui.createWidget('WhiteListLabel', whiteListPanel)
      label:setText(newEntry)
      table.insert(newlyWhitelistedPlayers, newEntry)
      addWhitelistName:setText('')
    end
  addWhitelistButton.onClick = addWhitelistFunction

  communicationWindow.onEnter = function()
      if addWhitelistName:isFocused() then
        addWhitelistFunction()
      elseif addIgnoreName:isFocused() then
        addIgnoreFunction()
      end
    end

  local ignorePrivateMessageBox = communicationWindow:getChildById('checkboxIgnorePrivateMessages')
  ignorePrivateMessageBox:setChecked(communicationSettings.privateMessages)
  local ignoreYellingBox = communicationWindow:getChildById('checkboxIgnoreYelling')
  ignoreYellingBox:setChecked(communicationSettings.yelling)
  local allowVIPsBox = communicationWindow:getChildById('checkboxAllowVIPs')
  allowVIPsBox:setChecked(communicationSettings.allowVIPs)

  local saveButton = communicationWindow:recursiveGetChildById('buttonSave')
  saveButton.onClick = function()
      communicationSettings.ignoredPlayers = {}
      for i = 1, ignoreListPanel:getChildCount() do
        addIgnoredPlayer(ignoreListPanel:getChildByIndex(i):getText())
      end

      communicationSettings.whitelistedPlayers = {}
      for i = 1, whiteListPanel:getChildCount() do
        addWhitelistedPlayer(whiteListPanel:getChildByIndex(i):getText())
      end

      communicationSettings.useIgnoreList = useIgnoreListBox:isChecked()
      communicationSettings.useWhiteList = useWhiteListBox:isChecked()
      communicationSettings.yelling = ignoreYellingBox:isChecked()
      communicationSettings.privateMessages = ignorePrivateMessageBox:isChecked()
      communicationSettings.allowVIPs = allowVIPsBox:isChecked()
      communicationWindow:destroy()
    end

  local cancelButton = communicationWindow:recursiveGetChildById('buttonCancel')
  cancelButton.onClick = function()
      communicationWindow:destroy()
    end

  local ignoredPlayers = getIgnoredPlayers()
  for i = 1, #ignoredPlayers do
    local label = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
    label:setText(ignoredPlayers[i])
  end

  local whitelistedPlayers = getWhitelistedPlayers()
  for i = 1, #whitelistedPlayers do
    local label = g_ui.createWidget('WhiteListLabel', whiteListPanel)
    label:setText(whitelistedPlayers[i])
  end
end

function online()
  -- a session always starts out of typing mode: walking has to work right away
  disableChat(true)

  defaultTab = addTab(tr('Default'), true)
  serverTab = addTab(tr('Server Log'), false)
  knockoutTab = addTab(tr('Knockout Log'), false) -- Avatar integration
  if g_game.getClientVersion() >= 820 then
    local tab = addTab("NPCs", false)
    tab.npcChat = true
  end
  
  if g_game.getClientVersion() < 862 then
    local gameRootPanel = modules.game_interface.getRootPanel()
    g_keyboard.bindKeyDown('Ctrl+R', openPlayerReportRuleViolationWindow, gameRootPanel)
  end
  -- open last channels
  local lastChannelsOpen = g_settings.getNode('lastChannelsOpen')
  if lastChannelsOpen then
    local savedChannels = lastChannelsOpen[g_game.getCharacterName()]
    if savedChannels then
      for channelName, channelId in pairs(savedChannels) do
        channelId = tonumber(channelId)
        if channelId ~= -1 and channelId < 100 then
          if not table.find(channels, channelId) then
            g_game.joinChannel(channelId)
            table.insert(ignoredChannels, channelId)
          end
        end
      end
    end
  end
  scheduleEvent(function()
  consoleTabBar:selectTab(defaultTab)
  -- Garante que o chat permaneça lockado após conectar
  local chatLockButton = consolePanel:getChildById('sidePanel'):getChildById('chatLockButton')
  if chatLockButton and not chatLockButton:isOn() then
    disableChat()
    chatLockButton:setOn(true) -- Lockado (on = chat desabilitado)
    local mask = chatLockButton:getChildById('mask')
    if mask then
      mask:show()
    end
  end
 end, 500)
  scheduleEvent(function() ignoredChannels = {} end, 3000)

  -- Avatar integration: the chat is a floating panel now, so collapse the bottom
  -- console panel and hand the whole height back to the map
  local bottomPanel = modules.game_interface.getBottomPanel()
  local bottomSplitter = modules.game_interface.getRootPanel():getChildById('bottomSplitter')
  if bottomPanel then
    bottomPanel:hide()
  end
  if bottomSplitter then
    bottomSplitter:disable()
    bottomSplitter:setMarginBottom(-2)
  end

  -- Avatar integration: the old console force-showed the folds/spellbar window
  local foldWindow = rootWidget:recursiveGetChildById('foldWindow')
  if foldWindow then
    foldWindow:show()
    foldWindow:setVisible(true)
  end

  -- Avatar integration: chat stickers rendered in the world
  if Stickers then
    if Stickers.stickersPanel then
      Stickers.stickersPanel:destroy()
      Stickers.stickersPanel = nil
    end
    Stickers.createStickersPanel()
  end
end



function offline()
  -- leaving the game must never leave the keyboard grabbed by the chat
  disableChat(true)

  if g_game.getClientVersion() < 862 then
    local gameRootPanel = modules.game_interface.getRootPanel()
    g_keyboard.unbindKeyDown('Ctrl+R', gameRootPanel)
  end
  clear()
end

function onChannelEvent(channelId, name, type)
  local fmt = ChannelEventFormats[type]
  if not fmt then
    print(('Unknown channel event type (%d).'):format(type))
    return
  end

  local channel = channels[channelId]
  if channel then
    local tab = getTab(channel)
    if tab then
      addTabText(fmt:format(name), SpeakTypesSettings.channelOrange, tab)
    end
  end
end

-- =============================================================================
-- Avatar integration
-- Features this client had in its previous console that are not part of the
-- Landcore chat. Delete this whole section for a 100% upstream port, and drop
-- the calls marked "Avatar integration" inside init/online/terminate/sendMessage
-- /onTalk.
-- =============================================================================

-- Knockout Log: the server broadcasts player deaths through an extended opcode.
-- Buffer format: victim>oldLevel>newLevel>killer1;killer2;...
KNOCKOUT_OPCODE = 250
KNOCKOUT_COLOR = '#F55E5E'

-- Tab target: maximum distance (in tiles) for picking the next monster
DISTANCE_TARGET = 10
monstersAttacked = {}

function addKnockoutMessage(buffer)
  if not knockoutTab or not buffer or #buffer == 0 then return end

  -- the server may already send a ready-to-print message (no '>' separators)
  if not buffer:find('>', 1, true) then
    addTabText(buffer, { color = KNOCKOUT_COLOR }, knockoutTab)
    return
  end

  local parts = buffer:explode('>')
  local victim = parts[1]
  local fromLevel = tostring(parts[2] or '')
  local toLevel = tostring(parts[3] or '')

  if not victim or #victim == 0 then return end

  local killers = {}
  if parts[4] then
    for _, name in ipairs(parts[4]:explode(';')) do
      if name and #name > 0 then
        table.insert(killers, name)
      end
    end
  end

  local killerText = ''
  if #killers == 1 then
    killerText = ' to ' .. killers[1]
  elseif #killers > 1 then
    local list = killers[1]
    for i = 2, #killers - 1 do
      list = list .. ', ' .. killers[i]
    end
    list = list .. ', and ' .. killers[#killers]
    killerText = ' to ' .. list
  end

  local text = victim .. ' has been knocked out from level ' .. fromLevel
    .. ' to level ' .. toLevel .. killerText

  addTabText(text, { color = KNOCKOUT_COLOR }, knockoutTab)
end

function onKnockoutOpcode(protocol, opcode, buffer)
  local ok, err = pcall(addKnockoutMessage, buffer)
  if not ok then
    g_logger.error('[KnockoutLog] erro ao processar buffer: ' .. tostring(err))
  end
end

-- game_textmessage asks the console whether the folds/spellbar window is shown
function CheckFolds()
  local foldWindow = rootWidget:recursiveGetChildById('foldWindow')
  if not foldWindow then return false end
  return foldWindow:isVisible()
end

local function distanceBetween(p1, p2)
  return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
end

function isMonsterOnTarget(creature)
  return creature:isMonster() and not creature:isInvisible()
end

function chooseTarget()
  local player = g_game.getLocalPlayer()
  if not player then return end

  local playerPos = player:getPosition()
  local spectators = g_map.getSpectators(playerPos, false)
  for i, creature in pairs(spectators) do
    if distanceBetween(playerPos, creature:getPosition()) <= DISTANCE_TARGET then
      if isMonsterOnTarget(creature) then
        if monstersAttacked[creature:getId()] then
          if monstersAttacked[creature:getId()] ~= 1 then
            g_game.attack(creature)
            break
          end
        else
          monstersAttacked[creature:getId()] = 1
          g_game.attack(creature)
          break
        end
      end
    end
    if i == #spectators and next(monstersAttacked) ~= nil then
      monstersAttacked = {}
      chooseTarget()
    end
  end
end

function onTabPressed()
  if not isChatEnabled() then
    chooseTarget()
  end
end

function onTeleport()
  if not Stickers then return end
  for _, stickerData in ipairs(Stickers.activeStickers) do
    if stickerData.widget and stickerData.tile then
      stickerData.tile:removeWidget(stickerData.widget)
    end
  end
  Stickers.activeStickers = {}
end
