
ScreenLoot = {}

local OpcodeLoot = 158

local screenTab  = {}
local uiItemLoot = {}

local screenDepth = 5
local cacheLastTime = { t = 0, i = 1 }

local mapPanel = modules.game_interface.getMapPanel()
local topMenu  = modules.client_topmenu.getTopMenu()

function ScreenLoot.init()
	-- payload do servidor: nunca rodar com o ambiente global (corelib/util.lua)
	ProtocolGame.registerExtendedOpcode(OpcodeLoot, function(protocol, opcode, buffer)
		local value, err = safeLuaDeserialize(buffer)
		if err then
			g_logger.error('[loot] invalid payload: ' .. tostring(err))
			return
		end
		ScreenLoot.show(value)
	end)
end

function ScreenLoot.terminate()
	ProtocolGame.unregisterExtendedOpcode(OpcodeLoot)
end

function ScreenLoot.show(value)
	for i = 1, screenDepth do
		screenTab[i] = {}
		if i+1 <= screenDepth then
			screenTab[i] = screenTab[i+1]
		else
			if value ~= nil then
				screenTab[i].loot = value
				if g_clock.millis() == cacheLastTime.t then
					screenTab[i].id = g_clock.millis() * 100 + cacheLastTime.i
					cacheLastTime.i = cacheLastTime.i + 1
					ScreenLoot.hide(screenTab[i].id)
				else
					screenTab[i].id = g_clock.millis()
					cacheLastTime.t = g_clock.millis()
					cacheLastTime.i = 1
					ScreenLoot.hide(screenTab[i].id)
				end
			else
				screenTab[i] = nil
			end
		end
	end	
	if value == nil and table.size(screenTab) then
		screenTab[#screenTab] = nil
	end
	ScreenLoot.refresh()
end

function ScreenLoot.hide(id)
	scheduleEvent(function()
		for a, b in pairs(screenTab) do
			if screenTab[a].id == id then
				screenTab[a] = nil
				ScreenLoot.show(nil)
				ScreenLoot.refresh()
				break
			end
		end
	end, 3000)
end

function ScreenLoot.refresh()
	ScreenLoot.destroy()
	local eixoX = (mapPanel:getWidth()/2)-100
	local eixoY = 0
	if topMenu:isVisible() then
		eixoY = topMenu:getHeight()
	end
	for i, value in pairs(screenTab) do
		if eixoY <= mapPanel:getHeight() - 32 then
			for name, loot in pairs(value.loot) do
				if eixoX <= mapPanel:getWidth() - 32 then
					uiItemLoot[name..i] = g_ui.createWidget("UIItem", mapPanel)
					uiItemLoot[name..i]:setSize({width = 32, height  = 32})
					uiItemLoot[name..i]:setItemId(loot.itemId)
					g_effects.fadeOut(uiItemLoot[name..i], 2200)
					uiItemLoot[name..i]:setVirtual(true)
					uiItemLoot[name..i]:move(eixoX + mapPanel:getX(), eixoY)
					eixoX = eixoX + 32
					if loot.count > 1 then
						--uiItemLoot[name..i]:setItemCount(loot.count)
					end
				end
			end
		end
		eixoX = (mapPanel:getWidth()/2)-100
		eixoY = eixoY + 32
	end
end

function ScreenLoot.destroy()
	for i in pairs(uiItemLoot) do
	    g_effects.fadeOut(uiItemLoot[i], 420)
		uiItemLoot[i]:destroy()
		uiItemLoot[i] = nil
	end
end

