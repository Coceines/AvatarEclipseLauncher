-- ============================================================================
-- MOMO POUCH (client) — sistema de coleta automatica personalizada
-- ----------------------------------------------------------------------------
-- * CTRL + botao direito no Momo Pouch (clientId 17437) -> janela de config (on/off)
-- * CTRL + botao direito em QUALQUER item -> Add/Remove da lista do pouch
-- * Estado (ativado + lista de itens) fica no server (opcode 212, JSON)
-- ============================================================================

-- ATENCAO: o server envia o CLIENT id (clientId do OTB). O Momo Pouch tem
-- server id 18435, mas clientId 17437 — as checagens do client usam 17437.
local MOMO_ITEM_ID = 17437
local MOMO_OPCODE = 212
local MOMO_MENU_CATEGORY = 'Momo Pouch'
local MOMO_MENU_KEY = 'momoItemOption'
local MOMO_TOGGLE_KEY = 'momoToggleOption'

momoWindow = nil
local momoEnabled = true
local momoItems = {} -- itemId -> "1" (coleta) | "0" (bloqueia)

local function sendAction(action, data)
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(MOMO_OPCODE, json.encode({action = action, data = data or {}}))
  end
end

local function requestState()
  sendAction('get')
end

local function onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= MOMO_OPCODE then return end
  if not buffer or buffer == '' then return end

  local ok, json_data = pcall(json.decode, buffer)
  if not ok or type(json_data) ~= 'table' then return end

  local action = json_data['action']
  if action == 'state' and json_data['data'] then
    momoEnabled = tostring(json_data['data'].enabled) == '1'
    momoItems = {}
    local items = json_data['data'].items
    if type(items) == 'table' then
      for _, entry in ipairs(items) do
        if entry and entry.id then
          momoItems[tonumber(entry.id)] = tostring(entry.status)
        end
      end
    end
    refreshConfigWindow()
  end
end

-- Rotulo dinamico da opcao no menu: depende do estado atual do item.
local function itemMenuLabel(itemId)
  if momoItems[itemId] == '1' then
    return tr('Remove from Momo Pouch')
  end
  return tr('Add to Momo Pouch')
end

-- CTRL + botao direito:
--   * no Momo Pouch -> abre a janela de configuracao
--   * em qualquer outro item -> abre o menu do item (com a opcao do pouch)
-- Retorna true se tratou o clique.
function onCtrlRightClick(menuPosition, lookThing, useThing, creatureThing)
  if not g_game.isOnline() then return false end
  if not (useThing and useThing:isItem()) then return false end

  if useThing:getId() == MOMO_ITEM_ID then
    showConfig()
    return true
  end

  if modules.game_interface.createThingMenu then
    modules.game_interface.createThingMenu(menuPosition, lookThing, useThing, creatureThing)
    return true
  end
  return false
end

-- Callback da opcao do menu: alterna o item entre "coleta" e "bloqueia".
function toggleItemOption(menuPosition, lookThing, useThing, creatureThing)
  if not (useThing and useThing:isItem()) then return end
  local itemId = useThing:getId()
  local nextStatus
  if momoItems[itemId] == '1' then
    nextStatus = '0' -- Remove from Momo Pouch -> nunca coleta
  else
    nextStatus = '1' -- Add to Momo Pouch -> sempre coleta
  end
  momoItems[itemId] = nextStatus
  sendAction('setitem', { item = itemId, status = nextStatus })
end

-- ---------------------------------------------------------------------------
-- Janela de configuracao
-- ---------------------------------------------------------------------------

function createConfigWindow()
  if momoWindow then return end
  momoWindow = g_ui.displayUI('momo')
  momoWindow:hide()
  local statusButton = momoWindow:recursiveGetChildById('statusButton')
  if statusButton then
    statusButton.onClick = toggleStatus
  end
end

function showConfig()
  if not momoWindow then createConfigWindow() end
  refreshConfigWindow()
  momoWindow:show()
  momoWindow:raise()
  momoWindow:focus()
end

function hideConfig()
  if momoWindow then momoWindow:hide() end
end

function refreshConfigWindow()
  if not momoWindow then return end
  local statusButton = momoWindow:recursiveGetChildById('statusButton')
  if statusButton then
    statusButton:setText(momoEnabled and tr('Enabled') or tr('Disabled'))
  end
  local itemsLabel = momoWindow:recursiveGetChildById('itemsLabel')
  if itemsLabel then
    local n = 0
    for _, status in pairs(momoItems) do
      if status == '1' then n = n + 1 end
    end
    itemsLabel:setText(tr('Items to collect: %s', n))
  end
end

function toggleStatus()
  momoEnabled = not momoEnabled
  refreshConfigWindow()
  sendAction('toggle')
end

-- ---------------------------------------------------------------------------
-- Init / terminate
-- ---------------------------------------------------------------------------

function init()
  connect(g_game, {
    onGameStart = requestState,
    onGameEnd = hideConfig
  })
  ProtocolGame.registerExtendedOpcode(MOMO_OPCODE, onExtendedOpcode)

  -- opcao no menu de itens (aparece segurando CTRL)
  modules.game_interface.addMenuHook(MOMO_MENU_CATEGORY, MOMO_MENU_KEY, toggleItemOption,
    function(menuPosition, lookThing, useThing, creatureThing)
      return g_keyboard.isCtrlPressed()
        and useThing and useThing:isItem()
        and useThing:getId() ~= MOMO_ITEM_ID
    end)

  -- rotulo dinamico (Add/Remove conforme o estado do item)
  if modules.game_interface.hookedMenuOptions
    and modules.game_interface.hookedMenuOptions[MOMO_MENU_CATEGORY]
    and modules.game_interface.hookedMenuOptions[MOMO_MENU_CATEGORY][MOMO_MENU_KEY] then
    modules.game_interface.hookedMenuOptions[MOMO_MENU_CATEGORY][MOMO_MENU_KEY].name =
      function(menuPosition, lookThing, useThing, creatureThing)
        if useThing and useThing:isItem() then
          return itemMenuLabel(useThing:getId())
        end
        return tr('Momo Pouch')
      end
  end

  -- opcao no menu do PROPRIO pouch (botao direito): Turn on / Turn off do autoloot
  modules.game_interface.addMenuHook(MOMO_MENU_CATEGORY, MOMO_TOGGLE_KEY, toggleStatus,
    function(menuPosition, lookThing, useThing, creatureThing)
      return useThing and useThing:isItem() and useThing:getId() == MOMO_ITEM_ID
    end)

  -- rotulo dinamico: 'Turn off' quando ativo / 'Turn on' quando desativado
  if modules.game_interface.hookedMenuOptions
    and modules.game_interface.hookedMenuOptions[MOMO_MENU_CATEGORY]
    and modules.game_interface.hookedMenuOptions[MOMO_MENU_CATEGORY][MOMO_TOGGLE_KEY] then
    modules.game_interface.hookedMenuOptions[MOMO_MENU_CATEGORY][MOMO_TOGGLE_KEY].name =
      function(menuPosition, lookThing, useThing, creatureThing)
        if momoEnabled then
          return tr('Turn off')
        end
        return tr('Turn on')
      end
  end

  createConfigWindow()
end

function terminate()
  disconnect(g_game, {
    onGameStart = requestState,
    onGameEnd = hideConfig
  })
  pcall(ProtocolGame.unregisterExtendedOpcode, MOMO_OPCODE)
  modules.game_interface.removeMenuHook(MOMO_MENU_CATEGORY, MOMO_MENU_KEY)
  modules.game_interface.removeMenuHook(MOMO_MENU_CATEGORY, MOMO_TOGGLE_KEY)
  if momoWindow then
    momoWindow:destroy()
    momoWindow = nil
  end
end
