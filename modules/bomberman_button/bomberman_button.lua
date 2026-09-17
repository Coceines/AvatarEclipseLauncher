-- ============================================================================
-- BOMBERMAN BUTTON (modulo OTClient)
-- ----------------------------------------------------------------------------
-- Janelinha "BOMB" do evento Bomberman.
--   * O SERVIDOR envia o opcode 171 ("open" / "close") para mostrar/ocultar.
--   * O CLIENT envia o opcode 161 ("bomb") quando o botao e clicado.
--
-- A janela e definida no bomberman_button.otui (MainWindow + UIButton) e
-- criada na hora (g_ui.createWidget), ancorada no canto inferior direito.
-- INSTALACAO: copie a pasta inteira para <client>/modules/ e reinicie o client.
-- ============================================================================

local OPCODE_SHOW = 171  -- servidor -> client
local OPCODE_CLICK = 161 -- client -> servidor

local bombWindow = nil

modules.bomberman_button = {}

function modules.bomberman_button.onBombClick()
  g_game.sendExtendedOpcode(OPCODE_CLICK, 'bomb')
end

local function ensureWindow()
  if not bombWindow then
    local ok, w = pcall(function() return g_ui.createWidget('BombermanWindow', rootWidget) end)
    if ok and w then
      bombWindow = w
      bombWindow:hide()
    end
  end
  return bombWindow
end

local function onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE_SHOW then
    return
  end
  buffer = buffer or ''
  if buffer == 'open' then
    local w = ensureWindow()
    if w then
      w:show()
      w:raise()
    end
  elseif buffer == 'close' then
    if bombWindow then
      bombWindow:hide()
    end
  end
end

function init()
  -- registerExtendedOpcode e fatal quando o opcode ja esta tomado (um reload de
  -- module pode rodar o init sem passar pelo terminate anterior). Desregistrar
  -- antes deixa a operacao idempotente.
  pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE_SHOW) end)
  ProtocolGame.registerExtendedOpcode(OPCODE_SHOW, onExtendedOpcode)
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_SHOW)
  if bombWindow then
    bombWindow:destroy()
    bombWindow = nil
  end
end
