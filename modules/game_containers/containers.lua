-- ============================================================================
--  game_containers - janelas de containers (embutido no client)
--  Inclui a "lupa" de busca no dep�sito (opcode 233 <-> servidor):
--    * bot�o de lupinha na barra do container (so aparece em dep�sitos)
--    * clique -> mini box (campo de texto + Limpar), com foco automatico
--    * Enter/busca -> drop-down compacto com os itens que batem
--    * clique num resultado -> server move o item pra mochila (take)
--    * Esc ou clique na lupinha de novo -> fecha
-- ============================================================================

-- ===================== Depot Search (nativo, sem m�dulo extra) =============
local DEPOT_SEARCH_OPCODE = 233

-- IDs de CLIENT dos containers de dep�sito (o server manda o clientId do OTB):
-- locker = 3497 (e variantes), depot chest = 3502, reward mailbox = 18358.
local DEPOT_IDS = { [3497] = true, [3498] = true, [3499] = true, [3500] = true, [3501] = true, [3502] = true, [18358] = true }

local depotSearchPopup
local depotSearchEdit
local depotSearchResults
local depotSearchEvent
local depotSearchPollEvent
local lastDepotSearchText = ""
local lastContainerWindow = nil

local function shortName(value, maxLine)
  if string.len(value) >= maxLine then
    return string.sub(value, 1, maxLine - 4) .. " ..."
  end
  return value
end

local function getContainerItemId(container)
  local ok, item = pcall(function() return container and container:getContainerItem() end)
  if not ok or not item then return 0 end
  local ok2, id = pcall(function() return item:getId() end)
  if ok2 and id then return id end
  return 0
end

local function isDepotContainer(container)
  local id = getContainerItemId(container)
  if DEPOT_IDS[id] then return true end
  local ok, name = pcall(function() return container and container:getName() end)
  if ok and name then
    local ln = string.lower(name)
    if ln:find('locker') or ln:find('depot') or ln:find('reward') then
      return true
    end
  end
  return false
end

local function requestDepotSearch(term)
  lastDepotSearchText = term or ""
  local protocol = g_game.getProtocolGame()
  if protocol then
    local msg = "search>" .. tostring(term or "")
    protocol:sendExtendedOpcode(DEPOT_SEARCH_OPCODE, msg)
  end
end

local function takeDepotItem(itemid, count)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(DEPOT_SEARCH_OPCODE, "take>" .. tostring(itemid) .. ">" .. tostring(count or 0))
  end
  scheduleEvent(function() requestDepotSearch(lastDepotSearchText) end, 400)
end

local function renderDepotResults(list, total)
  if not depotSearchResults then return end
  depotSearchResults:destroyChildren()

  local term = lastDepotSearchText or ""

  if term == "" then
    depotSearchResults:setVisible(false)
    return
  end

  local rows = list or {}
  local shown = 0
  local maxRows = 8
  for _, r in ipairs(rows) do
    shown = shown + 1
    if shown > maxRows then break end

    local row = g_ui.createWidget('Panel', depotSearchResults)
    row:setSize({ width = 254, height = 16 })
    row:setPosition({ x = 0, y = (shown - 1) * 18 })
    row:setBackgroundColor('#ffffff10')

    local lbl = g_ui.createWidget('Label', row)
    lbl:setPosition({ x = 4, y = 1 })
    lbl:setSize({ width = 246, height = 14 })
    lbl:setFont('verdana-11px-monochrome')

    local qtd = r.count or 0
    local text = shortName(r.name or "", 24) .. (qtd > 0 and ("  x" .. qtd) or "")
    lbl:setText(text)
    row:setTooltip((r.name or "") .. (qtd > 0 and ("  x" .. qtd) or ""))
    row.onClick = function()
      takeDepotItem(r.itemid, r.count or 1)
    end
  end

  if shown == 0 then
    local row = g_ui.createWidget('Panel', depotSearchResults)
    row:setSize({ width = 254, height = 16 })
    row:setPosition({ x = 0, y = 0 })
    local lbl = g_ui.createWidget('Label', row)
    lbl:setPosition({ x = 4, y = 1 })
    lbl:setSize({ width = 246, height = 14 })
    lbl:setFont('verdana-11px-monochrome')
    lbl:setColor('#909090')
    lbl:setText('Nenhum item encontrado')
  else
    local totalN = tonumber(total) or #rows
    if totalN > shown then
      local row = g_ui.createWidget('Panel', depotSearchResults)
      row:setSize({ width = 254, height = 16 })
      row:setPosition({ x = 0, y = shown * 18 })
      local lbl = g_ui.createWidget('Label', row)
      lbl:setPosition({ x = 4, y = 1 })
      lbl:setSize({ width = 246, height = 14 })
      lbl:setFont('verdana-11px-monochrome')
      lbl:setColor('#b0b0b0')
      lbl:setText(string.format('+%d mais - refine a busca', totalN - shown))
    end
  end

  depotSearchResults:setVisible(true)
end

-- Posiciona a mini box FIXA acima da janela do container (depot chest)
local function positionDepotSearchPopup(containerWindow)
  if not depotSearchPopup then return end
  local pos = containerWindow:getPosition()
  local pw = depotSearchPopup:getWidth()
  local ph = depotSearchPopup:getHeight()
  -- Centraliza horizontalmente acima da janela, 8px acima do topo
  local x = pos.x + math.floor((containerWindow:getWidth() - pw) / 2)
  local y = pos.y - ph - 8
  depotSearchPopup:setPosition({ x = x, y = y })
  if depotSearchResults then
    depotSearchResults:setPosition({ x = x, y = y + ph + 2 })
  end
end

local function hideDepotSearchPopup()
  if depotSearchPopup then
    depotSearchPopup:hide()
  end
  if depotSearchResults then
    depotSearchResults:hide()
  end
  if depotSearchPollEvent then
    depotSearchPollEvent:cancel()
    depotSearchPollEvent = nil
  end
end

-- Polling: verifica o texto a cada 200ms e dispara busca se mudou.
local function startSearchPoll()
  if depotSearchPollEvent then depotSearchPollEvent:cancel() end
  local lastText = ""
  depotSearchPollEvent = scheduleEvent(function()
    if not depotSearchPopup or not depotSearchPopup:isVisible() then
      depotSearchPollEvent = nil
      return
    end
    if depotSearchEdit then
      local currentText = depotSearchEdit:getText() or ""
      if currentText ~= lastText then
        lastText = currentText
        if depotSearchEvent then depotSearchEvent:cancel() end
        requestDepotSearch(currentText)
      end
    end
    depotSearchPollEvent = scheduleEvent(function() startSearchPoll() end, 200)
  end, 200)
end

local function buildDepotSearchPopup()
  if depotSearchPopup then return end

  depotSearchPopup = g_ui.displayUI('depotsearch')
  depotSearchEdit = depotSearchPopup:getChildById('depotSearchEdit')
  local btnClear = depotSearchPopup:getChildById('btnClear')

  depotSearchPopup.onMousePress = function()
    if depotSearchEdit then depotSearchEdit:focus() end
    return false
  end

  -- Conectar onTextChange via connect()
  local ok, err = pcall(function()
    connect(depotSearchEdit, {
      onTextChange = function(text, oldText)
        if depotSearchEvent then depotSearchEvent:cancel() end
        depotSearchEvent = scheduleEvent(function()
          if depotSearchEdit then
            requestDepotSearch(depotSearchEdit:getText())
          end
        end, 250)
      end
    })
  end)
  if not ok then
    print("[containers] connect onTextChange falhou: " .. tostring(err))
  end

  -- Botao Limpar
  btnClear.onClick = function()
    if depotSearchEdit then depotSearchEdit:clearText() end
    lastDepotSearchText = ""
    requestDepotSearch("")
    if depotSearchResults then
      depotSearchResults:setVisible(false)
    end
  end

  -- Drop-down de resultados: IRMAO do popup (standalone)
  depotSearchResults = g_ui.createWidget('Panel')
  depotSearchResults:setId('depotSearchResults')
  depotSearchResults:setSize({ width = 254, height = 150 })
  depotSearchResults:setBackgroundColor('#0d0d0dcc')
  depotSearchResults:setVisible(false)

  -- Enter busca na hora
  g_keyboard.bindKeyDown('Enter', function()
    if depotSearchEdit then
      if depotSearchEvent then depotSearchEvent:cancel() end
      requestDepotSearch(depotSearchEdit:getText())
    end
  end, depotSearchEdit)

  -- Esc fecha a mini box
  local closeHandler = function()
    hideDepotSearchPopup()
  end
  g_keyboard.bindKeyPress('Escape', closeHandler, depotSearchEdit)
  g_keyboard.bindKeyPress('Escape', closeHandler, depotSearchPopup)
end

local function onDepotSearchButtonClick(containerWindow)
  buildDepotSearchPopup()
  if not depotSearchPopup then return end

  lastContainerWindow = containerWindow
  local visible = not depotSearchPopup:isVisible()
  if visible then
    positionDepotSearchPopup(containerWindow)
    depotSearchPopup:show()
    depotSearchPopup:raise()
    if depotSearchResults then depotSearchResults:raise() end

    if depotSearchEdit then
      depotSearchEdit:clearText()
      lastDepotSearchText = ""
      depotSearchEdit:focus()
      scheduleEvent(function()
        if depotSearchEdit and depotSearchPopup and depotSearchPopup:isVisible() then
          depotSearchPopup:raise()
          if depotSearchResults then depotSearchResults:raise() end
          depotSearchEdit:focus()
        end
      end, 50)
      startSearchPoll()
    end
  else
    hideDepotSearchPopup()
  end
end

local function setupDepotSearchButton(container, containerWindow)
  local button = containerWindow:recursiveGetChildById('depotSearchButton')
  if not button then
    return
  end

  local isDepot = isDepotContainer(container)
  button:setVisible(isDepot)
  if isDepot then
    button.onClick = function() onDepotSearchButtonClick(containerWindow) end
  end
end

-- ============================ containers (original) =========================

function init()
  g_ui.importStyle('container')

  connect(Container, { onOpen = onContainerOpen,
                       onClose = onContainerClose,
                       onSizeChange = onContainerSizeChange,
                       onAddItem = onContainerAddItem,
                       onUpdateItem = onContainerUpdateItem,
                       onRemoveItem = onContainerRemoveItem })
  connect(Game, { onGameEnd = clean() })

  ProtocolGame.registerExtendedOpcode(DEPOT_SEARCH_OPCODE, function(protocol, opcode, buffer)
    if type(buffer) ~= "string" or buffer == "" then return end
    local ok, err = pcall(function()
      local action = buffer:explode('>')
      if action[1] == "search" then
        local data = {}
        for i = 3, #action do
          data[#data + 1] = action[i]
        end
        local joined = table.concat(data, ">")
        -- payload do servidor: nunca rodar com o ambiente global (corelib/util.lua)
        local list = safeLuaDeserialize(joined)
        if type(list) ~= 'table' then
          list = {}
        end
        renderDepotResults(list, tonumber(action[2]) or #list)
      end
    end)
    if not ok then
      g_logger.error("[depot-search] parse ERROR: " .. tostring(err))
    end
  end)

  reloadContainers()
end

function terminate()
  disconnect(Container, { onOpen = onContainerOpen,
                          onClose = onContainerClose,
                          onSizeChange = onContainerSizeChange,
                          onAddItem = onContainerAddItem,
                          onUpdateItem = onContainerUpdateItem,
                          onRemoveItem = onContainerRemoveItem })
  disconnect(Game, { onGameEnd = clean() })
  pcall(function() ProtocolGame.unregisterExtendedOpcode(DEPOT_SEARCH_OPCODE) end)
  if depotSearchEvent then depotSearchEvent:cancel() end
  if depotSearchPollEvent then depotSearchPollEvent:cancel() end
  if depotSearchPopup then depotSearchPopup:destroy() depotSearchPopup = nil end
  if depotSearchResults then depotSearchResults:destroy() depotSearchResults = nil end
end

function reloadContainers()
  clean()
  for _,container in pairs(g_game.getContainers()) do
    onContainerOpen(container)
  end
end

function clean()
  hideDepotSearchPopup()
  for containerid,container in pairs(g_game.getContainers()) do
    destroy(container)
  end
end

function destroy(container)
  if container.window then
    container.window:destroy()
    container.window = nil
    container.itemsPanel = nil
  end
end

function refreshContainerItems(container)
  local panel = container.itemsPanel
  if not panel then return end
  local children = panel:getChildren()
  for slot, itemWidget in ipairs(children) do
    itemWidget:setItem(container:getItem(slot - 1))
  end
end

-- ---------------------------------------------------------------------------
-- Containers de slots DINAMICOS ("a cada 1 que ocupa, mais 1 surge"):
--   * Momo Pouch (server id 18435 / clientId 17437)
--   * Reward mailbox (18358)
-- O server mantem capacity = itens + 1 (sempre 1 slot vazio no fim). O client
-- sincroniza a grade com a quantidade real de itens + 1, criando/destruindo
-- slots conforme itens entram/saem, ate 5000 slots (protocolo agora em U16).
-- ---------------------------------------------------------------------------
-- ATENCAO: o server envia o CLIENT id do item (clientId do OTB). O Momo Pouch
-- tem server id 18435, mas clientId 17437 � as checagens do client usam 17437.
local DYNAMIC_CONTAINER_IDS = { [17437] = true, [18358] = true }

local function isDynamicSlotsContainer(container)
  local ok, item = pcall(function() return container and container:getContainerItem() end)
  if not ok or not item then return false end
  local ok2, id = pcall(function() return item:getId() end)
  return ok2 and DYNAMIC_CONTAINER_IDS[id] == true
end

function syncDynamicContainerSlots(container)
  if not container.window then return end
  local panel = container.itemsPanel
  if not panel then return end

  local needed = math.min(container:getItemsCount() + 1, 5000)
  local children = panel:getChildren()

  -- cria slots vazios enquanto o loot entra (cresce "infinitamente")
  while #children < needed do
    local w = g_ui.createWidget('Item', panel)
    w:setMargin(0)
    w:setItem(nil)
    w.position = container:getSlotPosition(#children)
    children = panel:getChildren()
  end

  -- remove slots extras quando itens saem
  while #children > needed do
    children[#children]:destroy()
    children = panel:getChildren()
  end

  refreshContainerItems(container)

  -- ajusta a altura da janela para caber as linhas atuais
  local layout = panel:getLayout()
  local cellSize = layout:getCellSize()
  local filledLines = math.max(math.ceil(container:getItemsCount() / layout:getNumColumns()), 1)
  container.window:setContentHeight(filledLines * cellSize.height)
end

function onContainerSizeChange(container, size)
  if not container.window then return end
  if isDynamicSlotsContainer(container) then
    syncDynamicContainerSlots(container)
  end
end

function onContainerOpen(container, previousContainer)
  local containerWindow
  if previousContainer then
    containerWindow = previousContainer.window
    previousContainer.window = nil
    previousContainer.itemsPanel = nil
  else
    containerWindow = g_ui.createWidget('ContainerWindow', modules.game_interface.getRightPanel())
  end
  containerWindow:setId('container' .. container:getId())
  local containerPanel = containerWindow:getChildById('contentsPanel')
  local containerItemWidget = containerWindow:getChildById('containerItemWidget')
  containerWindow.onClose = function()
    g_game.close(container)
    containerWindow:hide()
  end

  local scrollbar = containerWindow:getChildById('miniwindowScrollBar')
  scrollbar:mergeStyle({ ['$!on'] = { }})

  local upButton = containerWindow:getChildById('upButton')
  upButton.onClick = function()
    g_game.openParent(container)
  end
  upButton:setVisible(container:hasParent())

  local name = container:getName()
  name = name:sub(1,1):upper() .. name:sub(2)
  containerWindow:setText(name)

  containerItemWidget:setItem(container:getContainerItem())

  containerPanel:destroyChildren()
  local capacity = container:getCapacity()
  local layout = containerPanel:getLayout()
  local cols = layout and layout:getNumColumns() or 4
  -- Create all capacity slots so every slot is always visible.
  for slot=0,capacity-1 do
    local itemWidget = g_ui.createWidget('Item', containerPanel)
    itemWidget:setId('item' .. slot)
    itemWidget:setItem(container:getItem(slot))
    itemWidget:setMargin(0)
    itemWidget.position = container:getSlotPosition(slot)
  end

  container.window = containerWindow
  container.itemsPanel = containerPanel

  -- containers de slots dinamicos: normaliza a grade para itens + 1 slot vazio
  if isDynamicSlotsContainer(container) then
    syncDynamicContainerSlots(container)
  end

  local layout = containerPanel:getLayout()
  local cellSize = layout:getCellSize()
  containerWindow:setContentMinimumHeight(cellSize.height)
  containerWindow:setContentMaximumHeight(cellSize.height*layout:getNumLines())

  if not previousContainer then
    local totalLines = math.ceil(capacity / layout:getNumColumns())
    containerWindow:setContentHeight(totalLines*cellSize.height)
  end

  setupDepotSearchButton(container, containerWindow)
  containerWindow:setup()
end

function onContainerClose(container)
  hideDepotSearchPopup()
  destroy(container)
end

function onContainerAddItem(container, slot, item)
  if not container.window then return end
  if isDynamicSlotsContainer(container) then
    syncDynamicContainerSlots(container)
  else
    refreshContainerItems(container)
  end
end

function onContainerUpdateItem(container, slot, item, oldItem)
  if not container.window then return end
  if isDynamicSlotsContainer(container) then
    syncDynamicContainerSlots(container)
    return
  end
  local itemWidget = container.itemsPanel:getChildById('item' .. slot)
  if itemWidget then
    itemWidget:setItem(item)
  else
    refreshContainerItems(container)
  end
end

function onContainerRemoveItem(container, slot, item)
  if not container.window then return end
  if isDynamicSlotsContainer(container) then
    syncDynamicContainerSlots(container)
  else
    refreshContainerItems(container)
  end
end
