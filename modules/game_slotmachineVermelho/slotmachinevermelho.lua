

SlotMachineVermelho = {}

local Opcodes  = 202
local elements = { "fire", "water", "air", "earth" }

local slotWindow
local btnApostar
local slots = {}

function SlotMachineVermelho.init()

	connect(g_game, { onGameEnd = SlotMachineVermelho.offline })
	connect(LocalPlayer, { onPositionChange = SlotMachineVermelho.onCreaturePositionChange })
	ProtocolGame.registerExtendedOpcode(Opcodes, function(protocol, opcode, buffer)
		local actionAndResult = buffer:explode('>')
		if ( actionAndResult[1] == 'open') then
		  SlotMachineVermelho.toggle()
		elseif ( actionAndResult[1] == 'msgErro' ) then
		  btnApostar:enable()
		  slotWindow:setImageSource('ui/background1')
		elseif ( actionAndResult[1] == 'start' ) then
		  SlotMachineVermelho.runSlots(actionAndResult[2])
		end		
	end)
	
	slotWindow = g_ui.displayUI('slotmachinevermelho')
	slotWindow:hide()
	btnApostar = slotWindow:getChildById('btnApostar')
	slots 	   = {
		slotWindow:getChildById('slot1'),
		slotWindow:getChildById('slot2'),
		slotWindow:getChildById('slot3')
	}
end

function SlotMachineVermelho.terminate()
	disconnect(g_game, { onGameEnd = SlotMachineVermelho.offline })
	disconnect(LocalPlayer, { onPositionChange = SlotMachineVermelho.onCreaturePositionChange })
	ProtocolGame.unregisterExtendedOpcode(Opcodes)
	slotWindow:destroy()
end

function SlotMachineVermelho.offline()
	slotWindow:hide()
end

function SlotMachineVermelho.onCreaturePositionChange(creature, newPos, oldPos)
	if creature:isLocalPlayer() then
		slotWindow:hide()
	end
end

function SlotMachineVermelho.toggle()
	slotWindow:setVisible(not slotWindow:isVisible())
end

function SlotMachineVermelho.apostar()
    btnApostar:disable()
	slotWindow:setImageSource('ui/background2')
	g_game.talkChannel(11, 11, "!apostarvermelho start")
end

function SlotMachineVermelho.runSlots(value)
  local speed  = 0
  for i, widget in pairs(slots) do
    removeEvent(widget.runSlot)
	widget.runSlot = cycleEvent(function()
	  speed = speed + 1
	  widget.icon = elements[math.random(#elements)]
	  widget:setImageSource('ui/'..widget.icon)
	  if ( speed >= 40 ) then
	    btnApostar:enable()
	    slotWindow:setImageSource('ui/background1')
		removeEvent(widget.runSlot)
		if ( value ~= 'none' ) then
		  widget:setImageSource('ui/'..value)
	    end
	  end
	end, 130)
  end
  scheduleEvent(function() 
	if ( value == 'none' and slots[1].icon == slots[2].icon and slots[2].icon == slots[3].icon ) then
        slots[1]:setImageSource('ui/fire')
        slots[2]:setImageSource('ui/water')
        slots[3]:setImageSource('ui/air')
	end
  end, 1900)
end