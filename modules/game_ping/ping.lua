-- Smart Ping System Module
-- Ping de localização usando Middle Click

local PING_OPCODE = 100 -- Extended opcode for ping system
local PING_EFFECT = 56 -- Efeito desenhado no chao (o mesmo de data/lib/smartPing.lua)
local originalOnMouseRelease = nil

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })
  
  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  -- Restaura handler original do mapa (se existir)
  local ok, mapPanel = pcall(function()
    if modules and modules.game_interface and modules.game_interface.getMapPanel then
      return modules.game_interface.getMapPanel()
    end
  end)

  if ok and mapPanel and originalOnMouseRelease then
    mapPanel.onMouseRelease = originalOnMouseRelease
    originalOnMouseRelease = nil
  end
end

function onGameStart()
  -- Pega o painel do mapa via game_interface (funciona em módulo sandboxed)
  local ok, mapPanel = pcall(function()
    if modules and modules.game_interface and modules.game_interface.getMapPanel then
      return modules.game_interface.getMapPanel()
    end
  end)

  if ok and mapPanel then
    if not originalOnMouseRelease then
      originalOnMouseRelease = mapPanel.onMouseRelease

      mapPanel.onMouseRelease = function(self, mousePosition, mouseButton)
        -- Middle click: marca o local e NAO deixa o clique andar junto
        if onMapMouseRelease(self, mousePosition, mouseButton) then
          -- o UIGameMap so limpa essa flag no fim do proprio onMouseRelease
          self.allowNextRelease = false
          return true
        end

        -- Qualquer outro clique segue o comportamento original do mapa
        if originalOnMouseRelease then
          return originalOnMouseRelease(self, mousePosition, mouseButton)
        end
      end
    end
  else
  end
end

function onGameEnd()
  -- Restaura handler original do mapa (se disponível)
  local ok, mapPanel = pcall(function()
    if modules and modules.game_interface and modules.game_interface.getMapPanel then
      return modules.game_interface.getMapPanel()
    end
  end)

  if ok and mapPanel and originalOnMouseRelease then
    mapPanel.onMouseRelease = originalOnMouseRelease
    originalOnMouseRelease = nil
  end
end

function onMapMouseRelease(widget, mousePosition, mouseButton)
  -- Middle Click (MouseMidButton = 3 em corelib/const.lua)
  if mouseButton == MouseMidButton then
    -- Pega a posição do tile no mapa
    local tile = widget:getTile(mousePosition)
    if tile then
      local position = tile:getPosition()
      sendPing(position)
      return true -- Indica que o evento foi tratado
    else
      g_logger.warning("[Smart Ping] ERROR: No tile found at mouse position")
    end
  end
  return false
end

function sendPing(position)
  -- Envia o ping para o servidor via extended opcode
  local data = string.format("%d,%d,%d", position.x, position.y, position.z)
  
  if g_game.getProtocolGame() then
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
      protocolGame:sendExtendedOpcode(PING_OPCODE, data)
      
      -- Feedback visual local imediato. Este client nao tem g_map.addEffect: o jeito
      -- aqui e criar um Effect e largar na tile (mesmo padrao de game_huntwaypoint).
      -- O servidor manda o efeito para os outros membros da party, mas nao reenvia
      -- para quem clicou, justamente para nao desenhar duas vezes em cima.
      local effect = Effect.create()
      if effect then
        effect:setId(PING_EFFECT)
        g_map.addThing(effect, position)
      end
    end
  end
end

