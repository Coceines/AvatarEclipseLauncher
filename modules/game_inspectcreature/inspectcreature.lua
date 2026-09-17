local InspectOpcode = 164

local inspectWindow = nil
local itemDetailWindow = nil
local lblMonsterName = nil
local lblMonsterInfo = nil
local listLoot = nil
local uiCreature = nil
local detailItemIcon = nil
local detailItemName = nil
local detailItemRarity = nil
local detailDescription = nil
local currentMonsterData = nil
local isDetailVisible = false

local function requestMonsterInfo(creatureName)
  if not creatureName or creatureName == "" then return end
  g_game.talkChannel(MessageModes.say, MessageModes.none, "!inspect " .. creatureName)
end

local function toggle()
  if inspectWindow then
    local show = not inspectWindow:isVisible()
    if show then
      inspectWindow:show()
      inspectWindow:raise()
      inspectWindow:focus()
    else
      inspectWindow:hide()
    end
  end
  if isDetailVisible and itemDetailWindow then
    itemDetailWindow:hide()
    isDetailVisible = false
  end
end

local function closeAll()
  if isDetailVisible and itemDetailWindow then
    itemDetailWindow:hide()
    isDetailVisible = false
  end
  if inspectWindow then
    inspectWindow:hide()
  end
end

local function showInspectWindow()
  if isDetailVisible and itemDetailWindow then
    itemDetailWindow:hide()
    isDetailVisible = false
  end
  if inspectWindow then
    inspectWindow:show()
    inspectWindow:raise()
    inspectWindow:focus()
  end
end

local function onBackClicked()
  if isDetailVisible and itemDetailWindow then
    itemDetailWindow:hide()
    isDetailVisible = false
  end
  if inspectWindow then
    inspectWindow:show()
    inspectWindow:raise()
    inspectWindow:focus()
  end
end

local function onExitClicked()
  -- Exit from detail: closes the detail, doesn't reopen the main inspect window
  if isDetailVisible and itemDetailWindow then
    itemDetailWindow:hide()
    isDetailVisible = false
  end
end

local function centerPopupOnScreen(widget)
  if not widget then return end
  -- itemDetailWindow has anchors.fill: parent, so it's already centered inside MainWindow
  -- Just make sure it's visible
  widget:show()
end

local function resolveItemId(itemId)
  -- Try ItemType(id):getClientId() first
  -- ItemType must be a function � registerClass<ItemType>() creates a TABLE, not a function.
  -- The C++ bindGlobalFunction OR the Lua fallback in things.lua replaces it.
  if type(ItemType) == "function" then
    local ok, itemType = pcall(ItemType, itemId)
    if ok and itemType and not itemType:isNull() then
      local cid = itemType:getClientId()
      if cid and cid > 0 then return cid end
    end
  end
  -- Fallback: pass raw ID to setItemId � validates against .dat directly
  return itemId
end

local function getItemDescription(itemId, itemName)
  local name = itemName or "item"
  if type(ItemType) == "function" then
    local ok, itemType = pcall(ItemType, itemId)
    if ok and itemType and not itemType:isNull() then
      return "You see " .. name .. ". (ID: " .. itemType:getServerId() .. ")"
    end
  end
  return "You see " .. name .. "."
end

local function openItemDetail(lootItem)
  if not itemDetailWindow then return end
  local clientId = resolveItemId(lootItem.id)
  if detailItemIcon then
    if clientId > 0 then
      detailItemIcon:setItemId(clientId)
      detailItemIcon:setVisible(true)
    else
      detailItemIcon:setVisible(false)
    end
  end
  if detailItemName then detailItemName:setText(lootItem.name) end
  local infoText = ""
  if lootItem.chance and lootItem.chance ~= "-" then infoText = "Drop: " .. lootItem.chance end
  if lootItem.count and lootItem.count > 0 then
    if infoText ~= "" then infoText = infoText .. " | " end
    infoText = infoText .. "Max: " .. lootItem.count
  end
  if detailItemRarity then detailItemRarity:setText(infoText) end
  if detailDescription then  detailDescription:setText(getItemDescription(lootItem.id, lootItem.name)) end
  -- Close first window, open second window
  if inspectWindow then inspectWindow:hide() end
  itemDetailWindow:show()
  itemDetailWindow:raise()
  itemDetailWindow:focus()
  isDetailVisible = true
end

local function setMonsterInfo(monster)
  if not inspectWindow or not monster then return end

  currentMonsterData = monster
  if lblMonsterName and monster.name then lblMonsterName:setText(monster.name) end
  if uiCreature then
    if monster.outfit then
      uiCreature:setOutfit(monster.outfit)
      uiCreature:setVisible(true)
    else
      uiCreature:setVisible(false)
    end
  end
  if lblMonsterInfo then
    local infoParts = {}
    if monster.experience and monster.experience > 0 then table.insert(infoParts, monster.experience .. " EXP") end
    if monster.health and monster.health > 0 then table.insert(infoParts, monster.health .. " HP") end
    lblMonsterInfo:setText(#infoParts > 0 and table.concat(infoParts, " | ") or "")
  end
  if listLoot then
    listLoot:destroyChildren()
    if not monster.loot or #monster.loot == 0 then
      local empty = g_ui.createWidget('InspectLootItem', listLoot)
      if empty then
        local lbl = empty:getChildById('itemName')
        if lbl then lbl:setText("No loot data available") end
        local icon = empty:getChildById('itemIcon')
        if icon then icon:setVisible(false) end
      end
    else
      for _, loot in ipairs(monster.loot) do
        local uiLoot = g_ui.createWidget('InspectLootItem', listLoot)
        if not uiLoot then break end
        local icon = uiLoot:getChildById('itemIcon')
        if icon then
          local ci = resolveItemId(loot.id)
          if ci > 0 then
            icon:setItemId(ci)
            icon:setVisible(true)
          else
            icon:setVisible(false)
          end
        end
        local nameLabel = uiLoot:getChildById('itemName')
        if nameLabel then nameLabel:setText(loot.name) end
        local chanceLabel = uiLoot:getChildById('itemChance')
        if chanceLabel then chanceLabel:setText(loot.chance and loot.chance ~= "-" and loot.chance or "") end
        local lootData = { id = loot.id, name = loot.name, chance = loot.chance, count = loot.count }
        uiLoot.onMouseRelease = function(self, pos, button)
          if button == MouseLeftButton then
            openItemDetail(lootData)
            return true
          end
          return false
        end
      end
    end
  end
  showInspectWindow()
end

local function receiveMonsterData(buffer)
  if not buffer or buffer == "" then
    return
  end
  -- payload do servidor: nunca rodar com o ambiente global (corelib/util.lua)
  local monster, err = safeLuaDeserialize(buffer)
  if err then
    g_logger.error("[inspectcreature] invalid payload: " .. tostring(err))
    return
  end
  if type(monster) ~= "table" then
    return
  end
  if monster.name or (monster.loot and #monster.loot > 0) then
    setMonsterInfo(monster)
  end
end

function init()
  connect(g_game, { onGameEnd = onGameEnd })

  -- Register opcode 164
  pcall(ProtocolGame.registerExtendedOpcode,
    InspectOpcode, function(protocol, opcode, buffer)
      receiveMonsterData(buffer)
    end)

  -- Display UI
  local ok, widget = pcall(g_ui.displayUI, 'inspectcreature')
  if not ok or not widget then
    return
  end
  inspectWindow = widget

  uiCreature = inspectWindow:getChildById('uiCreature')
  lblMonsterName = inspectWindow:getChildById('lblMonsterName')
  lblMonsterInfo = inspectWindow:getChildById('lblMonsterInfo')
  listLoot = inspectWindow:getChildById('listLoot')

  -- Create detail window as a SEPARATE root window (not child of inspectWindow)
  -- so we can truly hide one and show the other independently
  itemDetailWindow = g_ui.createWidget('InspectDetailWindow', rootWidget)
  if itemDetailWindow then
    itemDetailWindow:setVisible(false)
    detailItemIcon = itemDetailWindow:getChildById('detailItemIcon')
    detailItemName = itemDetailWindow:getChildById('detailItemName')
    detailItemRarity = itemDetailWindow:getChildById('detailItemRarity')
    detailDescription = itemDetailWindow:getChildById('detailDescription')
  end

  -- Ctrl+I removido (batia com o Inventory). O icone/lupa continua abrindo.
end

function terminate()
  disconnect(g_game, { onGameEnd = onGameEnd })
  pcall(ProtocolGame.unregisterExtendedOpcode, InspectOpcode)
  if inspectWindow then inspectWindow:destroy(); inspectWindow = nil end
  if itemDetailWindow then itemDetailWindow:destroy(); itemDetailWindow = nil end
  uiCreature = nil; lblMonsterName = nil; lblMonsterInfo = nil; listLoot = nil
  detailItemIcon = nil; detailItemName = nil
  detailItemRarity = nil; detailDescription = nil
  currentMonsterData = nil; isDetailVisible = false
end

function onGameEnd()
  if inspectWindow then inspectWindow:hide() end
  if isDetailVisible and itemDetailWindow then itemDetailWindow:hide(); isDetailVisible = false end
  currentMonsterData = nil
end

modules.game_inspectcreature = {
  requestMonsterInfo = requestMonsterInfo,
  showInspectWindow = showInspectWindow,
  closeAll = closeAll,
  onBackClicked = onBackClicked,
  onExitClicked = onExitClicked
}
