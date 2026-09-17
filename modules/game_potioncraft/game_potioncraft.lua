PotionCraft = {}

local OPCODE = 215

local POTIONS = {
  { id = 7620, clientId = 268, name = "Mana Potion", timeSec = 45, timeStr = "45s" },
  { id = 7589, clientId = 283, name = "Strong Mana Potion", timeSec = 60, timeStr = "1m" },
  { id = 7590, clientId = 284, name = "Great Mana Potion", timeSec = 120, timeStr = "2m" },
  { id = 7618, clientId = 266, name = "Health Potion", timeSec = 60, timeStr = "1m" },
  { id = 7588, clientId = 285, name = "Strong Health Potion", timeSec = 90, timeStr = "1m 30s" },
  { id = 8473, clientId = 7443, name = "Great Health Potion", timeSec = 120, timeStr = "2m" },
}

local potionCraftWindow = nil
local selectionView = nil
local quantityView = nil
local subtitle = nil
local cardsGrid = nil
local selectedPotion = nil
local quantityScrollBar = nil
local lblQuantity = nil
local lblTotalTime = nil
local btnClose = nil

local function setItemDisplay(widget, clientId, itemId)
  if not widget then return end
  local idToUse = clientId or itemId
  if not idToUse or idToUse <= 0 then return end

  widget:setItemId(idToUse)
  widget:setItemCount(1)
end

local function formatTime(seconds)
  if seconds <= 0 then
    return "0s"
  end
  local hours = math.floor(seconds / 3600)
  local mins = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60

  local parts = {}
  if hours > 0 then
    table.insert(parts, hours .. "h")
  end
  if mins > 0 then
    table.insert(parts, mins .. "m")
  end
  if secs > 0 or #parts == 0 then
    table.insert(parts, secs .. "s")
  end
  return table.concat(parts, " ")
end

function init()
  potionCraftWindow = g_ui.displayUI('game_potioncraft')
  potionCraftWindow:hide()

  selectionView = potionCraftWindow:getChildById('selectionView')
  subtitle = selectionView:getChildById('subtitle')
  quantityView = potionCraftWindow:getChildById('quantityView')
  cardsGrid = selectionView:getChildById('cardsGrid')
  btnClose = potionCraftWindow:getChildById('btnClose')

  quantityScrollBar = quantityView:getChildById('quantityScrollBar')
  lblQuantity = quantityView:getChildById('lblQuantity')
  lblTotalTime = quantityView:getChildById('lblTotalTime')

  subtitle:setText("Selecione a poção que deseja sintetizar:")

  quantityScrollBar.onValueChange = PotionCraft.onQuantityChange

  ProtocolGame.registerExtendedOpcode(OPCODE, PotionCraft.onOpcode)
  connect(g_game, { onGameEnd = PotionCraft.hide })
end

function terminate()
  disconnect(g_game, { onGameEnd = PotionCraft.hide })
  pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  if potionCraftWindow then
    potionCraftWindow:destroy()
    potionCraftWindow = nil
  end
end

function PotionCraft.buildCards()
  if not cardsGrid then return end
  cardsGrid:destroyChildren()
  for _, potion in ipairs(POTIONS) do
    local card = g_ui.createWidget('PotionCard', cardsGrid)
    local itemIcon = card:getChildById('itemIcon')
    local potionName = card:getChildById('potionName')
    local potionTime = card:getChildById('potionTime')

    setItemDisplay(itemIcon, potion.clientId, potion.id)
    potionName:setText(potion.name)
    potionTime:setText("Tempo: " .. potion.timeStr)

    card.onMouseRelease = function(widget, mousePos, mouseButton)
      if mouseButton == MouseLeftButton then
        PotionCraft.selectPotion(potion)
      end
    end
  end
end

function PotionCraft.showSelectionView()
  selectedPotion = nil
  selectionView:setVisible(true)
  quantityView:setVisible(false)
  btnClose:setVisible(true)
end

function PotionCraft.selectPotion(potion)
  selectedPotion = potion
  selectionView:setVisible(false)
  quantityView:setVisible(true)
  btnClose:setVisible(false)

  local headerCard = quantityView:getChildById('headerCard')
  local selectedItemIcon = headerCard:getChildById('selectedItemIcon')
  local selectedPotionName = headerCard:getChildById('selectedPotionName')
  local selectedPotionTime = headerCard:getChildById('selectedPotionTime')

  setItemDisplay(selectedItemIcon, potion.clientId, potion.id)
  selectedPotionName:setText(potion.name)
  selectedPotionTime:setText("Tempo por Unidade: " .. potion.timeStr)

  quantityScrollBar:setValue(1)
  PotionCraft.onQuantityChange(quantityScrollBar, 1)
end

function PotionCraft.onQuantityChange(scrollbar, value)
  if not selectedPotion then return end
  lblQuantity:setText("Quantidade a produzir: " .. value)
  local totalSeconds = value * selectedPotion.timeSec
  lblTotalTime:setText("Tempo Total de Produção: " .. formatTime(totalSeconds))
end

function PotionCraft.confirmCraft()
  if not selectedPotion then return end
  local count = quantityScrollBar:getValue()
  if count <= 0 then
    return
  end

  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE, string.format("craft>%d>%d", selectedPotion.id, count))
  end

  PotionCraft.hide()
end

function PotionCraft.show()
  if potionCraftWindow then
    PotionCraft.buildCards()
    PotionCraft.showSelectionView()
    potionCraftWindow:show()
    potionCraftWindow:raise()
    potionCraftWindow:focus()
  end
end

function PotionCraft.hide()
  if potionCraftWindow and potionCraftWindow:isVisible() then
    potionCraftWindow:hide()
  end
end

function PotionCraft.onOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then return end
  local ok, data = pcall(json.decode, buffer)
  if ok and type(data) == "table" then
    if data.action == "open" then
      if data.potions and #data.potions > 0 then
        POTIONS = data.potions
      end
      PotionCraft.show()
    elseif data.action == "close" then
      PotionCraft.hide()
    end
  else
    if buffer == "open" then
      PotionCraft.show()
    elseif buffer == "close" then
      PotionCraft.hide()
    end
  end
end
