
local Opcode = 165

local window
local uiOutfit
local lblName
local lblLevel
local lblInfo

function init()
 
 connect(g_game, { onGameEnd = onGameEnd })
 connect(LocalPlayer, { onOutfitChange = onOutfitChange })  
 
 ProtocolGame.registerExtendedOpcode(Opcode, function(protocol, opcode, buffer)
    
	local player = g_game.getLocalPlayer()
	window:setImageSource('img/'..modules.game_folds.infos.vocation)	
	setInformation({
	  name = player:getName(),
	  level = player:getLevel(),
	  outfit = player:getOutfit(),
	  info = buffer
	})	
  end)
  
  window = g_ui.displayUI('playerinfo')

  uiOutfit = window:getChildById('uiOutfit')
  lblName = window:getChildById('lblName')
  lblLevel = window:getChildById('lblLevel')
  lblInfo = window:getChildById('lblInfo')
end

function terminate()
  disconnect(g_game, { onGameEnd = onGameEnd })
  disconnect(LocalPlayer, { onOutfitChange = onOutfitChange }) 
  ProtocolGame.unregisterExtendedOpcode(Opcode)
  window:destroy()
  
  g_keyboard.unbindKeyPress('Ctrl+B')
end

function onGameEnd()
  hideInformation()
end

function onOutfitChange(outfit, oldOutfit)
  if ( oldOutfit.type ~= 267 ) then
    uiOutfit:setOutfit(oldOutfit)
  end 
end

function requestInformation()
 g_game.talkChannel(MessageModes.say, MessageModes.none, "!status")
end

function hideInformation()
  window:hide()
end

function setInformation(player)
  if ( player.outfit.type ~= 267 ) then
    uiOutfit:setOutfit(player.outfit)
  end  
  lblName:setText(player.name)
  lblLevel:setText('Level: '..player.level)
  lblInfo:setText(player.info)
  window:show() 
end