dofile("/modules/gamelib/opcodes.lua")
avatarEdit = true

-- Colocar o [nome do item] = cor 
-- Caso a cor do item nao seja definida aqui, o padr�o � ser verde clarinho.

ItemsColor = {
  ['Fire Stone'] = '#ff0000',
  ['Water Stone'] = '#00c7ff',
  ['Air Stone'] = '#fffafa',
  ['Earth Stone'] = '#008000',
  ['crystal coin'] = '#00c7ff',
  ['platinum coin'] = '#fffafa',
  ['gold coin'] = "#f4e542"
}

MessageSettings = {
  none            = {},
  consoleRed      = { color = TextColors.red,    consoleTab='Default' },
  consoleOrange   = { color = TextColors.orange, consoleTab='Default' },
  consoleBlue     = { color = TextColors.blue,   consoleTab='Default' },
  centerRed       = { color = TextColors.red,    consoleTab='Server Log', screenTarget='lowCenterLabel' },
  centerGreen     = { color = TextColors.green,  consoleTab='Server Log', screenTarget='highCenterLabel',   consoleOption='showInfoMessagesInConsole' },
  centerWhite     = { color = TextColors.white,  consoleTab='Server Log', screenTarget='middleCenterLabel', consoleOption='showEventMessagesInConsole' },
  bottomWhite     = { color = TextColors.white,  consoleTab='Server Log', screenTarget='statusLabel',       consoleOption='showEventMessagesInConsole' },
  status          = { color = TextColors.white,  consoleTab='Server Log', screenTarget='statusLabel',       consoleOption='showStatusMessagesInConsole' },
  statusSmall     = { color = TextColors.white,                           screenTarget='statusLabel' },
  private         = { color = TextColors.lightblue,                       screenTarget='privateLabel' }
}

MessageTypes = {
  [MessageModes.MonsterSay] = MessageSettings.consoleOrange,
  [MessageModes.MonsterYell] = MessageSettings.consoleOrange,
  [MessageModes.BarkLow] = MessageSettings.consoleOrange,
  [MessageModes.BarkLoud] = MessageSettings.consoleOrange,
  [MessageModes.Failure] = MessageSettings.statusSmall,
  [MessageModes.Login] = MessageSettings.bottomWhite,
  [MessageModes.Game] = MessageSettings.centerWhite,
  [MessageModes.Status] = MessageSettings.status,
  [MessageModes.Warning] = MessageSettings.centerRed,
  [MessageModes.Look] = MessageSettings.centerGreen,
  [MessageModes.Loot] = MessageSettings.centerGreen,
  [MessageModes.Red] = MessageSettings.consoleRed,
  [MessageModes.Blue] = MessageSettings.consoleBlue,
  [MessageModes.PrivateFrom] = MessageSettings.consoleBlue,

  [MessageModes.DamageDealed] = MessageSettings.status,
  [MessageModes.DamageReceived] = MessageSettings.status,
  [MessageModes.Heal] = MessageSettings.status,
  [MessageModes.Exp] = MessageSettings.status,

  [MessageModes.DamageOthers] = MessageSettings.none,
  [MessageModes.HealOthers] = MessageSettings.none,
  [MessageModes.ExpOthers] = MessageSettings.none,

  [MessageModes.TradeNpc] = MessageSettings.centerWhite,
  [MessageModes.Guild] = MessageSettings.centerWhite,
  [MessageModes.PartyManagement] = MessageSettings.centerWhite,
  [MessageModes.TutorialHint] = MessageSettings.centerWhite,
  [MessageModes.Market] = MessageSettings.centerWhite,
  [MessageModes.BeyondLast] = MessageSettings.centerWhite,
  [MessageModes.Mana] = MessageSettings.centerWhite,
  [MessageModes.GameHighlight] = MessageSettings.centerWhite,
  [46] = MessageSettings.none,  -- deprecated MessageBlue
  [MessageModes.Report] = MessageSettings.consoleRed,
  [MessageModes.HotkeyUse] = MessageSettings.centerGreen,

  [254] = MessageSettings.private
}

messagesPanel = nil

function init()
  connect(g_game, 'onTextMessage', displayMessage)
  connect(g_game, 'onGameEnd', clearMessages)
  messagesPanel = g_ui.loadUI('textmessage', modules.game_interface.getRootPanel())
end

function terminate()
  disconnect(g_game, 'onTextMessage', displayMessage)
  disconnect(g_game, 'onGameEnd',clearMessages)
  clearMessages()
  messagesPanel:destroy()
end

function calculateVisibleTime(text)
  return math.max(#text * 100, 4000)
end

function getColorByItemName(text)
  for itemName,color in pairs(ItemsColor) do
    if text:match(itemName) then
	  return color
    end
  end
  return "#aaffaa"
end

function getItemsFromLootString(str)
  local items = {}
  str = str:gsub(".*:", "")
  for k,v in pairs(str:split(',')) do
    v = v:gsub("%.", "")
	table.insert(items, v:trim())
  end
  return items
end

function displayMessage(mode, text)
  if not g_game.isOnline() then return end
--print(text)
--print(mode)
  --sistema mirto: folds/�gua usam mode Look com #m#/#w#/#v#/#j#
  --n�o bloquear qualquer "#" � isso apagava look de items com descri��o colorida/custom
  if mode == 20 then
    if modules.game_folds.checkIsFoldMsg(text) or modules.game_inventory.checkIsWaterMsg(text) then
      return
    end
  end
  --Fim--

  local msgtype = MessageTypes[mode]

  if not msgtype then
    perror('unhandled onTextMessage message mode ' .. mode .. ': ' .. text)
    return
  end

  if msgtype == MessageSettings.none then return end

  -- show on screen FIRST so a console error cannot swallow Look/Status messages
  if msgtype.screenTarget then
    local label = messagesPanel:recursiveGetChildById(msgtype.screenTarget)
    if mode == MessageModes.Failure or mode == MessageModes.Status then
      label:setMarginBottom(modules.game_console.getConsolePanel():getHeight()+85)
    end
    if not modules.game_console.CheckFolds() and mode == MessageModes.Failure or not modules.game_console.CheckFolds() and mode == MessageModes.Status  then
      label:setMarginBottom(modules.game_console.getConsolePanel():getHeight())
    end

    label:setText(text)
    label:setColor(msgtype.color)
    label:setVisible(true)
    removeEvent(label.hideEvent)
    label.hideEvent = scheduleEvent(function() label:setVisible(false) end, calculateVisibleTime(text))
  end

  if msgtype.consoleTab ~= nil and (msgtype.consoleOption == nil or modules.client_options.getOption(msgtype.consoleOption)) then
    modules.game_console.addText(text, msgtype, tr(msgtype.consoleTab))
  end
end

function displayPrivateMessage(text)
  displayMessage(254, text)
end

function displayStatusMessage(text)
  displayMessage(MessageModes.Status, text)
end

function displayFailureMessage(text)
  displayMessage(MessageModes.Failure, text)
end

function displayGameMessage(text)
  displayMessage(MessageModes.Game, text)
end

function displayBroadcastMessage(text)
  displayMessage(MessageModes.Warning, text)
end

function clearMessages()
  for _i,child in pairs(messagesPanel:recursiveGetChildren()) do
    if child:getId():match('Label') then
      child:hide()
      removeEvent(child.hideEvent)
    end
  end
end

function LocalPlayer:onAutoWalkFail(player)
  modules.game_textmessage.displayFailureMessage(tr('There is no way.'))
end
