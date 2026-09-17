BUY = 1
SELL = 2
CURRENCY = 'gold'
CURRENCY_DECIMAL = false
WEIGHT_UNIT = 'oz'
LAST_INVENTORY = 10

npcWindow = nil
itemsPanel = nil
radioTabs = nil
radioItems = nil
searchText = nil
setupPanel = nil
quantity = nil
quantityScroll = nil
nameLabel = nil
priceLabel = nil
moneyLabel = nil
moneyDesc = nil
weightDesc = nil
weightLabel = nil
capacityDesc = nil
capacityLabel = nil
tradeButton = nil
buyTab = nil
sellTab = nil
initialized = false

showWeight = true
buyWithBackpack = nil
ignoreCapacity = nil
ignoreEquipped = nil
showAllItems = nil
sellAllButton = nil

local SPECIAL_ITEM_TOOLTIPS = {
  ['capa de viajante'] = "Capa de viajante\nArmadura: 8\n------------------------\n* +100 Vida\n* +50 Mana\n* +10 Velocidade",
  ['capa reforcada'] = "Capa Reforcada\nArmadura: 12\n------------------------\n* +180 Vida\n* +40 Mana\n* Absorve 1% de todo dano",
  ['capa resistente'] = "Capa Resistente\nArmadura: 7\n------------------------\n* +2% Dano de Dobra\n* +80 Vida\n* +200 Mana\n* +15 Velocidade",
  ['capa aprimorada'] = "Capa Aprimorada\nArmadura: 10\n------------------------\n* +3% Chance de Critico\n* +180 Vida\n* +120 Mana\n* +35 Velocidade",
  ['capa nobre'] = "Capa Nobre\nArmadura: 15\n------------------------\n* +400 Vida\n* +100 Mana\n* Absorve 2% de todo dano",
  ['capa de protecao'] = "Capa de Protecao\nArmadura: 10\n------------------------\n* +4% Dano de Dobra\n* +200 Vida\n* +450 Mana\n* Regenera 3 Mana a cada 2s",
  ['capa majestosa'] = "Capa Majestosa\nArmadura: 13\n------------------------\n* +8% Chance de Critico\n* +3% Dano de Dobra\n* +350 Vida\n* +200 Mana\n* +50 Velocidade",
  ['capa gloriosa'] = "Capa Gloriosa\nArmadura: 11\n------------------------\n* +7% Dano de Dobra\n* +4% Chance de Critico\n* +250 Vida\n* +700 Mana\n* +25 Velocidade",
  ['capa soberana'] = "Capa Soberana\nArmadura: 20\n------------------------\n* +800 Vida\n* +150 Mana\n* Absorve 4% de todo dano\n* +15 Velocidade",
  ['capa das nacoes'] = "Capa das Nações\nArmadura: 18\n------------------------\n* +5% Dano de Dobra\n* +5% Chance de Critico\n* +500 Vida\n* +400 Mana\n* Absorve 3% de todo dano\n* Regenera 3 Mana a cada 2s\n* +30 Velocidade",
  ['capa das nações'] = "Capa das Nações\nArmadura: 18\n------------------------\n* +5% Dano de Dobra\n* +5% Chance de Critico\n* +500 Vida\n* +400 Mana\n* Absorve 3% de todo dano\n* Regenera 3 Mana a cada 2s\n* +30 Velocidade",
}

function getItemCustomTooltip(item)
  if not item then return nil end
  local name = item.name and item.name:lower() or ''
  for key, tt in pairs(SPECIAL_ITEM_TOOLTIPS) do
    if name == key or name:find(key, 1, true) then
      return tt
    end
  end
  return nil
end

playerFreeCapacity = 0
playerMoney = 0
tradeItems = {}
playerItems = {}
selectedItem = nil
shopCurrencyOverride = nil

cancelNextRelease = nil

function init()
  npcWindow = g_ui.displayUI('npctrade')
  npcWindow:setVisible(false)

  itemsPanel = npcWindow:recursiveGetChildById('itemsPanel')
  searchText = npcWindow:recursiveGetChildById('searchText')

  setupPanel = npcWindow:recursiveGetChildById('setupPanel')
  quantityScroll = setupPanel:getChildById('quantityScroll')
  nameLabel = setupPanel:getChildById('name')
  priceLabel = setupPanel:getChildById('price')
  moneyLabel = setupPanel:getChildById('money')
  weightDesc = setupPanel:getChildById('weightDesc')
  weightLabel = setupPanel:getChildById('weight')
  capacityDesc = setupPanel:getChildById('capacityDesc')
  capacityLabel = setupPanel:getChildById('capacity')
  tradeButton = npcWindow:recursiveGetChildById('tradeButton')

  buyWithBackpack = npcWindow:recursiveGetChildById('buyWithBackpack')
  ignoreCapacity = npcWindow:recursiveGetChildById('ignoreCapacity')
  ignoreEquipped = npcWindow:recursiveGetChildById('ignoreEquipped')
  showAllItems = npcWindow:recursiveGetChildById('showAllItems')
  sellAllButton = npcWindow:recursiveGetChildById('sellAllButton')

  buyTab = npcWindow:getChildById('buyTab')
  sellTab = npcWindow:getChildById('sellTab')
  moneyDesc = setupPanel:getChildById('moneyDesc')

  radioTabs = UIRadioGroup.create()
  radioTabs:addWidget(buyTab)
  radioTabs:addWidget(sellTab)
  radioTabs:selectWidget(buyTab)
  radioTabs.onSelectionChange = onTradeTypeChange

  cancelNextRelease = false

  if g_game.isOnline() then
    playerFreeCapacity = g_game.getLocalPlayer():getFreeCapacity()
  end

  connect(g_game, { onGameEnd = hide,
                    onOpenNpcTrade = onOpenNpcTrade,
                    onCloseNpcTrade = onCloseNpcTrade,
                    onPlayerGoods = onPlayerGoods } )

  connect(LocalPlayer, { onFreeCapacityChange = onFreeCapacityChange,
                         onInventoryChange = onInventoryChange } )

  pcall(function() ProtocolGame.registerExtendedOpcode(101, onSetCurrencyOpcode) end)

  initialized = true
end

function terminate()
  initialized = false
  npcWindow:destroy()

  disconnect(g_game, {  onGameEnd = hide,
                        onOpenNpcTrade = onOpenNpcTrade,
                        onCloseNpcTrade = onCloseNpcTrade,
                        onPlayerGoods = onPlayerGoods } )

  disconnect(LocalPlayer, { onFreeCapacityChange = onFreeCapacityChange,
                            onInventoryChange = onInventoryChange } )

  pcall(function() ProtocolGame.unregisterExtendedOpcode(101) end)
end

function show()
  if g_game.isOnline() then
    if #tradeItems[BUY] > 0 then
      radioTabs:selectWidget(buyTab)
    else
      radioTabs:selectWidget(sellTab)
    end

    npcWindow:show()
    npcWindow:raise()
    npcWindow:focus()
  end
end

function hide()
  npcWindow:hide()
end

function onItemBoxChecked(widget)
  if widget:isChecked() then
    local item = widget.item
    selectedItem = item
    refreshItem(item)
    tradeButton:enable()

    if getCurrentTradeType() == SELL then
      quantityScroll:setValue(quantityScroll:getMaximum())
    end
  end
end

function onQuantityValueChange(quantity)
  if selectedItem then
    weightLabel:setText(string.format('%.2f', selectedItem.weight*quantity) .. ' ' .. WEIGHT_UNIT)
    priceLabel:setText(formatCurrency(getItemPrice(selectedItem)))
  end
end

function onTradeTypeChange(radioTabs, selected, deselected)
  tradeButton:setText(selected:getText())
  selected:setOn(true)
  deselected:setOn(false)

  local currentTradeType = getCurrentTradeType()
  buyWithBackpack:setVisible(currentTradeType == BUY)
  ignoreCapacity:setVisible(currentTradeType == BUY)
  ignoreEquipped:setVisible(currentTradeType == SELL)
  showAllItems:setVisible(currentTradeType == SELL)
  sellAllButton:setVisible(currentTradeType == SELL)

  refreshTradeItems()
  refreshPlayerGoods()
end

function onTradeClick()
  if getCurrentTradeType() == BUY then
    g_game.buyItem(selectedItem.ptr, quantityScroll:getValue(), ignoreCapacity:isChecked(), buyWithBackpack:isChecked())
  else
    g_game.sellItem(selectedItem.ptr, quantityScroll:getValue(), ignoreEquipped:isChecked())
  end
end

function onSearchTextChange()
  refreshPlayerGoods()
end

function itemPopup(self, mousePosition, mouseButton)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  if mouseButton == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:addOption(tr('Look'), function() return g_game.inspectNpcTrade(self:getItem()) end)
    menu:display(mousePosition)
    return true
  elseif ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) 
    or (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
    cancelNextRelease = true
    g_game.inspectNpcTrade(self:getItem())
    return true
  end
  return false
end

function onBuyWithBackpackChange()
  if selectedItem then
    refreshItem(selectedItem)
  end
end

function onIgnoreCapacityChange()
  refreshPlayerGoods()
end

function onIgnoreEquippedChange()
  refreshPlayerGoods()
end

function onShowAllItemsChange()
  refreshPlayerGoods()
end

function setCurrency(currency, decimal)
  CURRENCY = currency
  CURRENCY_DECIMAL = decimal
  local isGold = (currency == 'gold')
  if moneyDesc then moneyDesc:setVisible(isGold) end
  if moneyLabel then moneyLabel:setVisible(isGold) end
end

function onSetCurrencyOpcode(protocol, opcode, buffer)
  shopCurrencyOverride = (buffer and buffer ~= '') and buffer or nil
  setCurrency(shopCurrencyOverride or 'gold', false)
  if tradeItems[BUY] and tradeItems[SELL] then
    refreshTradeItems()
    refreshPlayerGoods()
  end
end

function setShowWeight(state)
  showWeight = state
  weightDesc:setVisible(state)
  weightLabel:setVisible(state)
end

function setShowYourCapacity(state)
  capacityDesc:setVisible(state)
  capacityLabel:setVisible(state)
  ignoreCapacity:setVisible(state)
end

function clearSelectedItem()
  nameLabel:clearText()
  nameLabel:removeTooltip()
  weightLabel:clearText()
  priceLabel:clearText()
  tradeButton:disable()
  quantityScroll:setMinimum(0)
  quantityScroll:setMaximum(0)
  if selectedItem then
    radioItems:selectWidget(nil)
    selectedItem = nil
  end
end

function getCurrentTradeType()
  if tradeButton:getText() == tr('Buy') then
    return BUY
  else
    return SELL
  end
end

function getItemPrice(item, single)
  local amount = 1
  local single = single or false
  if not single then
    amount = quantityScroll:getValue()
  end
  if getCurrentTradeType() == BUY then
    if buyWithBackpack:isChecked() then
      if item.ptr:isStackable() then
          return item.price*amount + 20
      else
        return item.price*amount + math.ceil(amount/20)*20
      end
    end
  end
  return item.price*amount
end

function getSellQuantity(item)
  if not item or not playerItems[item:getId()] then return 0 end
  local removeAmount = 0
  if ignoreEquipped:isChecked() then
    local localPlayer = g_game.getLocalPlayer()
    for i=1,LAST_INVENTORY do
      local inventoryItem = localPlayer:getInventoryItem(i)
      if inventoryItem and inventoryItem:getId() == item:getId() then
        removeAmount = removeAmount + inventoryItem:getCount()
      end
    end
  end
  return playerItems[item:getId()] - removeAmount
end

function canTradeItem(item)
  if getCurrentTradeType() == BUY then
    local hasMoney = (CURRENCY ~= 'gold') or (playerMoney >= getItemPrice(item, true))
    return (ignoreCapacity:isChecked() or (not ignoreCapacity:isChecked() and playerFreeCapacity >= item.weight)) and hasMoney
  else
    return getSellQuantity(item.ptr) > 0
  end
end

function refreshItem(item)
  nameLabel:setText(item.name)
  weightLabel:setText(string.format('%.2f', item.weight) .. ' ' .. WEIGHT_UNIT)
  priceLabel:setText(formatCurrency(getItemPrice(item)))

  local tooltip = getItemCustomTooltip(item)
  if tooltip then
    nameLabel:setTooltip(tooltip)
  else
    nameLabel:removeTooltip()
  end

  if getCurrentTradeType() == BUY then
    local capacityMaxCount = math.floor(playerFreeCapacity / item.weight)
    if ignoreCapacity:isChecked() then
      capacityMaxCount = 65535
    end
    local priceMaxCount = 65535
    if CURRENCY == 'gold' then
      priceMaxCount = math.floor(playerMoney / getItemPrice(item, true))
    end
    local finalCount = math.max(0, math.min(getMaxAmount(), math.min(priceMaxCount, capacityMaxCount)))
    quantityScroll:setMinimum(1)
    quantityScroll:setMaximum(finalCount)
  else
    quantityScroll:setMinimum(1)
    quantityScroll:setMaximum(math.max(0, math.min(getMaxAmount(), getSellQuantity(item.ptr))))
  end

  setupPanel:enable()
end

function refreshTradeItems()
  local layout = itemsPanel:getLayout()
  layout:disableUpdates()

  clearSelectedItem()

  searchText:clearText()
  setupPanel:disable()
  itemsPanel:destroyChildren()

  if radioItems then
    radioItems:destroy()
  end
  radioItems = UIRadioGroup.create()

  local currentTradeItems = tradeItems[getCurrentTradeType()]
  for key,item in pairs(currentTradeItems) do
    local itemBox = g_ui.createWidget('NPCItemBox', itemsPanel)
    itemBox.item = item

    local text = ''
    local name = item.name
    text = text .. name
    if showWeight then
      local weight = string.format('%.2f', item.weight) .. ' ' .. WEIGHT_UNIT
      text = text .. '\n' .. weight
    end
    local price = formatCurrency(item.price)
    text = text .. '\n' .. price
    itemBox:setText(text)

    local tooltip = getItemCustomTooltip(item)
    if tooltip then
      itemBox:setTooltip(tooltip)
    end

    local itemWidget = itemBox:getChildById('item')
    itemWidget:setItem(item.ptr)
    itemWidget.onMouseRelease = itemPopup
    if tooltip then
      itemWidget:setTooltip(tooltip)
    end

    radioItems:addWidget(itemBox)
  end

  layout:enableUpdates()
  layout:update()
end

function refreshPlayerGoods()
  if not initialized then return end

  checkSellAllTooltip()

  moneyLabel:setText(formatCurrency(playerMoney))
  capacityLabel:setText(string.format('%.2f', playerFreeCapacity) .. ' ' .. WEIGHT_UNIT)

  local currentTradeType = getCurrentTradeType()
  local searchFilter = searchText:getText():lower()
  local foundSelectedItem = false

  local items = itemsPanel:getChildCount()
  for i=1,items do
    local itemWidget = itemsPanel:getChildByIndex(i)
    local item = itemWidget.item

    local canTrade = canTradeItem(item)
    itemWidget:setOn(canTrade)
    itemWidget:setEnabled(canTrade)

    local searchCondition = (searchFilter == '') or (searchFilter ~= '' and string.find(item.name:lower(), searchFilter) ~= nil)
    local showAllItemsCondition = (currentTradeType == BUY) or (showAllItems:isChecked()) or (currentTradeType == SELL and not showAllItems:isChecked() and canTrade)
    itemWidget:setVisible(searchCondition and showAllItemsCondition)

    if selectedItem == item and itemWidget:isEnabled() and itemWidget:isVisible() then
      foundSelectedItem = true
    end
  end

  if not foundSelectedItem then
    clearSelectedItem()
  end

  if selectedItem then
    refreshItem(selectedItem)
  end
end

function onOpenNpcTrade(items)
  if g_things and g_things.clearItemShaders then
    g_things.clearItemShaders()
  end
  setCurrency(shopCurrencyOverride or 'gold', false)
  shopCurrencyOverride = nil

  tradeItems[BUY] = {}
  tradeItems[SELL] = {}

  for key,item in pairs(items) do
    local itemName = item[2] or ""
    local itemTier = 0
    local tierStr = itemName:match('%[Tier (%d+)%]') or itemName:match('Tier (%d+)')
    if tierStr then
      itemTier = tonumber(tierStr) or 0
    end

    if item[4] > 0 then
      local newItem = {}
      newItem.ptr = item[1]
      if newItem.ptr and newItem.ptr.setTier then
        newItem.ptr:setTier(itemTier)
      end
      newItem.name = itemName
      newItem.weight = item[3] / 100
      newItem.price = item[4]
      table.insert(tradeItems[BUY], newItem)
    end

    if item[5] > 0 then
      local newItem = {}
      newItem.ptr = item[1]
      if newItem.ptr and newItem.ptr.setTier then
        newItem.ptr:setTier(itemTier)
      end
      newItem.name = itemName
      newItem.weight = item[3] / 100
      newItem.price = item[5]
      table.insert(tradeItems[SELL], newItem)
    end
  end

  refreshTradeItems()
  addEvent(show) -- player goods has not been parsed yet
end

function closeNpcTrade()
  g_game.closeNpcTrade()
  hide()
end

function onCloseNpcTrade()
  shopCurrencyOverride = nil
  hide()
end

function onPlayerGoods(money, items)
  playerMoney = money

  playerItems = {}
  for key,item in pairs(items) do
    local id = item[1]:getId()
    if not playerItems[id] then
      playerItems[id] = item[2]
    else
      playerItems[id] = playerItems[id] + item[2]
    end
  end
  
  refreshPlayerGoods()
end

function onFreeCapacityChange(localPlayer, freeCapacity, oldFreeCapacity)
  playerFreeCapacity = freeCapacity

  if npcWindow:isVisible() then
    refreshPlayerGoods()
  end
end

function onInventoryChange(inventory, item, oldItem)
  refreshPlayerGoods()
end

function getTradeItemData(id, type)
  if table.empty(tradeItems[type]) then
    return false
  end

  if type then
    for key,item in pairs(tradeItems[type]) do
      if item.ptr and item.ptr:getId() == id then
        return item
      end
    end
  else
    for _,items in pairs(tradeItems) do
      for key,item in pairs(items) do
        if item.ptr and item.ptr:getId() == id then
          return item
        end
      end
    end
  end
  return false
end

function checkSellAllTooltip()
  sellAllButton:setEnabled(true)
  sellAllButton:removeTooltip()
  
  local total = 0
  local info = ''
  local first = true

  for key, amount in pairs(playerItems) do
    local data = getTradeItemData(key, SELL)
    if data then
      amount = getSellQuantity(data.ptr)
      if amount > 0 then
        if data and amount > 0 then
          info = info..(not first and "\n" or "")..
                 amount.." "..
                 data.name.." ("..
                 data.price*amount.." gold)"

          total = total+(data.price*amount)
          if first then first = false end
        end
      end
    end
  end
  if info ~= '' then
    info = info.."\nTotal: "..total.." gold"
    sellAllButton:setTooltip(info)
  else
    sellAllButton:setEnabled(false)
  end
end

function formatCurrency(amount)
  if CURRENCY_DECIMAL then
    return string.format("%.02f", amount/100.0) .. ' ' .. CURRENCY
  else
    return amount .. ' ' .. CURRENCY
  end
end

function getMaxAmount()
  if getCurrentTradeType() == SELL and g_game.getFeature(GameDoubleShopSellAmount) then
    return 10000
  end
  return 100
end

function sellAll()
  for itemid,item in pairs(playerItems) do
    local item = Item.create(itemid)
    local amount = getSellQuantity(item)
    if amount > 0 then
      g_game.sellItem(item, amount, ignoreEquipped:isChecked())
    end
  end
end
