-- Conquistas + Titulos - modulo game_achievements
-- Comunica com o server via extended opcode 172 (JSON).
-- Server: data/creaturescripts/scripts/achievements.lua + data/lib/achievementsLib.lua
-- O titulo equipado aparece acima do nome do player (creature:setTitle).

local opcode = 172
local window = nil
local button = nil
local list = {}
local equippedId = -1

modules.game_achievements = {}

function init()
  g_ui.importStyle('achievements')
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  connect(Creature, {
    onAppear = onCreatureAppear
  })

  if g_game.getLocalPlayer() then
    online()
  end
end

function terminate()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(opcode) end)
  offline()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  disconnect(Creature, {
    onAppear = onCreatureAppear
  })
end

function online()
  -- Do NOT create the window here — defer until toggle() is called.
  -- This prevents the achievements window from flashing open on login.

  local okB, errB = pcall(function()
    return modules.client_topmenu.addRightGameToggleButton(
      'achievementsButton',
      tr('Conquistas e Titulos'),
      '/images/topbuttons/Conquistas',
      toggle,
      true
    )
  end)
  if okB and errB then
    button = errB
  end

  pcall(function()
    ProtocolGame.registerExtendedOpcode(opcode, function(protocol, op, buffer)
      receiveData(buffer)
    end)
  end)
end

function offline()
  list = {}
  equippedId = -1
  if window then
    window:destroy()
    window = nil
  end
  if button then
    button:destroy()
    button = nil
  end
  disconnect(Creature, {
    onAppear = onCreatureAppear
  })
end

function modules.game_achievements.onEscape()
  if window and window:isVisible() then
    window:hide()
    if button then
      button:setOn(false)
    end
  end
end

function ensureWindow()
  if window then
    return
  end
  local okW, errW = pcall(function() return g_ui.createWidget('AchievementsWindow', rootWidget) end)
  if okW and errW then
    window = errW
    window:hide()
  end
end

function toggle()
  if not g_game.getLocalPlayer() or not button then
    return
  end

  ensureWindow()
  if not window then
    return
  end

  if button:isOn() then
    window:hide()
    button:setOn(false)
  else
    window:show()
    window:raise()
    window:focus()
    button:setOn(true)
    requestData()
  end
end

function requestData()
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(opcode, json.encode({action = "request"}))
  end
end

function receiveData(buffer)
  if not buffer or buffer == "" then
    return
  end

  local status, data = pcall(function() return json.decode(buffer) end)
  if not status or not data or type(data) ~= "table" then
    return
  end

  -- Titulo de outro player (apareceu na tela / equipou/removeu)
  if data.action == "title" then
    applyRemoteTitle(data)
    return
  end

  if data.action ~= "achievements" then
    return
  end

  if not window then
    return
  end

  list = data.list or {}
  equippedId = data.equipped or -1
  rebuildList()
  applyTitle()
end

-- Um player apareceu na tela: pede o titulo dele pro servidor
function onCreatureAppear(creature)
  local protocol = g_game.getProtocolGame()
  if not protocol then
    return
  end
  if not creature or not creature:isPlayer() then
    return
  end

  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer or creature == localPlayer then
    return
  end

  pcall(function()
    protocol:sendExtendedOpcode(opcode, json.encode({action = "requestTitle", id = creature:getId()}))
  end)
end

-- Aplica o titulo recebido do servidor na criatura
function applyRemoteTitle(data)
  local creature = g_map.getCreatureById(data.id)
  if not creature then
    return
  end

  if data.title and data.title ~= "" then
    pcall(function()
      creature:setTitle(data.title, 'verdana-11px-rounded', '#FFD700')
    end)
  else
    pcall(function() creature:clearTitle() end)
  end
end

function getAchievement(id)
  for _, ach in ipairs(list) do
    if ach.id == id then
      return ach
    end
  end
  return nil
end

function rebuildList()
  local achList = window:getChildById('achList')
  if not achList then
    return
  end

  achList:destroyChildren()

  for _, ach in ipairs(list) do
    local ok, card = pcall(function() return g_ui.createWidget('AchievementCard', achList) end)
    if not ok or not card then
      break
    end

    local isEquipped = (ach.id == equippedId)
    local unlocked = ach.unlocked

    local nameLabel = card:getChildById('achName')
    if nameLabel then
      nameLabel:setText(ach.name)
    end

    local titleLabel = card:getChildById('achTitle')
    if titleLabel then
      titleLabel:setText('Titulo: ' .. ach.title)
    end

    local statusLabel = card:getChildById('achStatus')
    if isEquipped then
      statusLabel:setText('Equipada')
      statusLabel:setColor('#FFD700')
      card:setBackgroundColor('#3d3d28')
    elseif unlocked then
      statusLabel:setText('Desbloqueada')
      statusLabel:setColor('#33cc33')
    else
      statusLabel:setText('')
    end

    local progressLabel = card:getChildById('achProgress')
    local bar = card:getChildById('achBar')
    local progress = math.min(ach.progress or 0, ach.target or 1)
    if progressLabel then
      progressLabel:setText(progress .. ' / ' .. ach.target)
    end
    if bar then
      if unlocked then
        bar:setPercent(100)
      else
        bar:setPercent((progress / ach.target) * 100)
      end
    end

    card.onMouseRelease = function(widget, mousePos, mouseButton)
      if mouseButton ~= MouseLeftButton then
        return false
      end
      if isEquipped then
        askUnequip(ach)
      elseif unlocked then
        askEquip(ach)
      end
      return true
    end
  end
end

function askEquip(ach)
  local messageBox
  messageBox = displayGeneralBox(
    'Conquista desbloqueada',
    'Deseja adicionar o titulo "' .. ach.title .. '" ao seu personagem?',
    {
      { text = 'Sim', callback = function()
        sendEquip(ach.id)
        if messageBox then messageBox:ok() end
      end },
      { text = 'Nao', callback = function()
        if messageBox then messageBox:cancel() end
      end }
    }
  )
end

function askUnequip(ach)
  local messageBox
  messageBox = displayGeneralBox(
    'Titulo equipado',
    'Deseja remover o titulo "' .. ach.title .. '" do seu personagem?',
    {
      { text = 'Sim', callback = function()
        sendUnequip()
        if messageBox then messageBox:ok() end
      end },
      { text = 'Nao', callback = function()
        if messageBox then messageBox:cancel() end
      end }
    }
  )
end

function sendEquip(id)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(opcode, json.encode({action = "equip", id = id}))
  end
end

function sendUnequip()
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(opcode, json.encode({action = "unequip"}))
  end
end

function applyTitle()
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end

  local ach = getAchievement(equippedId)
  if ach then
    pcall(function()
      player:setTitle(ach.title, 'verdana-11px-rounded', '#FFD700')
    end)
  else
    pcall(function() player:clearTitle() end)
  end
end
