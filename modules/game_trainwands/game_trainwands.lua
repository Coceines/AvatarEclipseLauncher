-- Training Wand Charges (Tibia Global style)
-- O servidor envia via extended opcode 0xF8:
--   [containerId u8] (0xFF = inventario; senao o indice do container aberto)
--   [index u8]       (slot do inventario 1-10, ou indice dentro do container)
--   [charges u16 LE] (cargas restantes da varinha)
local Opcode = 0xF8

local function receiveCharges(buffer)
  if not buffer or #buffer < 4 then return end

  local containerId = buffer:byte(1)
  local index       = buffer:byte(2)
  local charges     = buffer:byte(3) + buffer:byte(4) * 256
  if charges <= 0 then return end

  local item = nil
  if containerId == 0xFF then
    local player = g_game.getLocalPlayer()
    if player then
      item = player:getInventoryItem(index)
    end
  else
    local container = g_game.getContainer(containerId)
    if container then
      item = container:getItem(index)
    end
  end

  if item then
    item:setCount(charges)
  end
end

local function online()
  pcall(function()
    ProtocolGame.registerExtendedOpcode(Opcode, function(protocol, op, buffer)
      receiveCharges(buffer)
    end)
  end)
end

local function offline()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(Opcode) end)
end

function init()
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.getLocalPlayer() then online() end
end

function terminate()
  offline()
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
end
