
local Opcode = 163

local window
local lblName
local listLoot
local uiCreature

function init()
  
  connect(g_game, { onGameEnd = onGameEnd })
  
  ProtocolGame.registerExtendedOpcode(Opcode, function(protocol, opcode, buffer)
    -- payload do servidor: nunca rodar com o ambiente global (corelib/util.lua)
    local monster, err = safeLuaDeserialize(buffer)
    if err then
      g_logger.error('[monsterloot] invalid payload: ' .. tostring(err))
      return
    end
    if type(monster) == 'table' and not table.empty(monster) then
      setMonsterInfo(monster)
    end
  end)
  
  window = g_ui.displayUI('monsterloot')
  lblName = window:getChildById('lblName')
  listLoot = window:getChildById('listLoot')
  uiCreature = window:getChildById('uiCreature')

  -- Ctrl+W removido (colidia com o WASD/limpar textos). O botao continua abrindo.
end

function terminate()
  disconnect(g_game, { onGameEnd = onGameEnd })
  ProtocolGame.unregisterExtendedOpcode(Opcode)
  window:destroy()
  

end

function onGameEnd()
  window:hide()
end

function toggle()
  window:setVisible(not window:isVisible())
end

function searchMonster(monsterName)
  if ( monsterName:trim():len() > 0 ) then
    g_game.talkChannel(MessageModes.say, MessageModes.none, "!loot "..monsterName)
  end
end

function setMonsterInfo(monster)
  window:show()
  lblName:setText(monster.name)
  uiCreature:setOutfit(monster.outfit)
  listLoot:destroyChildren()
  for i, loot in pairs(monster.loot) do
    local uiLoot = g_ui.createWidget('Loot', listLoot)
    uiLoot:getChildById('item'):setItemId(loot.id)	
	uiLoot:getChildById('name'):setText(loot.name)
	uiLoot:getChildById('count'):setText('Count: '..loot.count)
	if ( loot.chance ~= '-' ) then
	  uiLoot:getChildById('chance'):setText('Chance: '..loot.chance)
	end
  end
end