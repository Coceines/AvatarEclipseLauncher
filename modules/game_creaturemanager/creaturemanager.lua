-- ---------------------------------------------------------------
-- Agriculture System (Farm) — Client Module
-- Protocolo de strings sem json
-- ---------------------------------------------------------------

local opcode = 135

local managerWindow  = nil
local storeWindow    = nil

local myPlantsList    = {}
local storePlantsList = {}

local selectedMyPlant    = nil
local selectedStorePlant = nil

local currentServerTime = 0
local clientFetchTime   = 0
local previewTimerEvent = nil
local allowOpen         = false

modules.game_creaturemanager = {}

-- --- Helpers --------------------------------------------------

local function split(str, sep)
  local t = {}
  local pattern = "([^" .. sep .. "]*)" .. sep .. "?"
  for part in str:gmatch("([^" .. sep .. "]+)") do
    t[#t+1] = part
  end
  return t
end

local function formatTime(seconds)
  if seconds <= 0 then return "Ready!" end
  local hours = math.floor(seconds / 3600)
  local mins  = math.floor((seconds % 3600) / 60)
  local secs  = seconds % 60
  if hours > 0 then
    return string.format("%02dh %02dm %02ds", hours, mins, secs)
  else
    return string.format("%02dm %02ds", mins, secs)
  end
end

local function sendToServer(msg)
  pcall(function()
    local pg = g_game.getProtocolGame()
    if pg then pg:sendExtendedOpcode(opcode, msg) end
  end)
end

local function setItemWidget(widget, id)
  if not widget or not id or id <= 0 then return end
  -- The server already sends client IDs (translated via ItemType(id):getClientId() server-side).
  -- We still attempt g_things.tryGetItemType as a safety-net for edge cases.
  local cid = 0
  if g_things and g_things.tryGetItemType then
    local it = g_things.tryGetItemType(id)
    if it and not it:isNull() then
      cid = it:getClientId()
    end
  end
  widget:setItemId(cid > 0 and cid or id)
end

-- --- Parsing --------------------------------------------------
--
-- myPlants: id~baseName~customName~stage~maxStage~lastWater~cooldown~stageClientId~harvestName;...
-- storePlants: baseName~seedClientId~price~harvestName;...

local function parsePlantList(raw)
  local list = {}
  if not raw or raw == "" then return list end
  for _, entry in ipairs(split(raw, ";")) do
    local f = split(entry, "~")
    if #f >= 8 then
      list[#list+1] = {
        id            = tonumber(f[1]),
        baseName      = f[2]  or "",
        customName    = f[3]  or "",
        stage         = tonumber(f[4]) or 1,
        maxStage      = tonumber(f[5]) or 3,
        lastWater     = tonumber(f[6]) or 0,
        waterCooldown = tonumber(f[7]) or 18000,
        stageClientId = tonumber(f[8]) or 0,
        harvestName   = f[9]  or ""
      }
    end
  end
  return list
end

local function parseStoreList(raw)
  local list = {}
  if not raw or raw == "" then return list end
  for _, entry in ipairs(split(raw, ";")) do
    local f = split(entry, "~")
    if #f >= 3 then
      list[#list+1] = {
        baseName    = f[1] or "",
        seedClientId= tonumber(f[2]) or 0,
        price       = tonumber(f[3]) or 0,
        harvestName = f[4] or ""
      }
    end
  end
  return list
end

-- --- Init / Terminate -----------------------------------------

function init()
  g_ui.importStyle('creaturemanager')
  g_ui.importStyle('creaturestore')
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.getLocalPlayer() then online() end
end

function terminate()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(opcode) end)
  offline()
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
end

function online()
  pcall(function()
    ProtocolGame.registerExtendedOpcode(opcode, function(protocol, op, buffer)
      onExtendedOpcode(protocol, op, buffer)
    end)
  end)
end

function offline()
  allowOpen = false
  myPlantsList    = {}
  storePlantsList = {}
  selectedMyPlant    = nil
  selectedStorePlant = nil
  if previewTimerEvent then
    removeEvent(previewTimerEvent)
    previewTimerEvent = nil
  end
  if managerWindow then managerWindow:destroy() managerWindow = nil end
  if storeWindow   then storeWindow:destroy()   storeWindow   = nil end
end

-- --- Show / Hide ----------------------------------------------

function show()
  if not allowOpen then return end
  if storeWindow and not storeWindow:isHidden() then storeWindow:hide() end

  if not managerWindow then
    local ok, w = pcall(function() return g_ui.createWidget('creatureManagerWindow', rootWidget) end)
    if not ok or not w then return end
    managerWindow = w
    managerWindow:hide()
  end

  sendToServer("fetch")
  managerWindow:show()
  managerWindow:raise()
  managerWindow:focus()

  if not previewTimerEvent then
    previewTimerEvent = cycleEvent(updateManagerPreview, 1000)
  end
end

function hide()
  allowOpen = false
  if managerWindow then managerWindow:hide() end
  selectedMyPlant = nil
  updateManagerPreview()
  if previewTimerEvent then
    removeEvent(previewTimerEvent)
    previewTimerEvent = nil
  end
end

function showStore()
  if not allowOpen then return end
  if managerWindow and not managerWindow:isHidden() then managerWindow:hide() end

  if not storeWindow then
    local ok, w = pcall(function() return g_ui.createWidget('creatureStoreWindow', rootWidget) end)
    if not ok or not w then return end
    storeWindow = w
    storeWindow:hide()
  end

  storeWindow:show()
  storeWindow:raise()
  storeWindow:focus()
  populateStoreGrid()
end

function hideStore()
  if storeWindow then storeWindow:hide() end
  selectedStorePlant = nil
  updateStorePreview()
  if managerWindow and allowOpen then
    managerWindow:show()
    managerWindow:raise()
    managerWindow:focus()
  end
end

function hideAll()
  hide()
  if storeWindow then storeWindow:hide() end
end

-- --- Opcode Handler -------------------------------------------

function onExtendedOpcode(protocol, op, buffer)
  if op ~= opcode then return end
  if not buffer or buffer == "" then return end

  local parts = split(buffer, "|")
  local topic = parts[1]

  if topic == "open" then
    allowOpen = true
    show()

  elseif topic == "update_all" then
    local unlocked  = true
    local myRaw     = ""
    local storeRaw  = ""

    for i = 2, #parts do
      local colonPos = parts[i]:find(":")
      if colonPos then
        local k = parts[i]:sub(1, colonPos - 1)
        local v = parts[i]:sub(colonPos + 1)
        if k == "unlocked" then
          unlocked = (v == "1")
        elseif k == "serverTime" then
          currentServerTime = tonumber(v) or os.time()
          clientFetchTime   = os.time()
        elseif k == "myPlants" then
          myRaw = v
        elseif k == "storePlants" then
          storeRaw = v
        end
      end
    end

    if not unlocked then
      if managerWindow and not managerWindow:isHidden() then
        hide()
        pcall(function()
          modules.game_textmessage.displayFailureMessage("You must talk to the Farmer and unlock your farm first!")
        end)
      end
      return
    end

    myPlantsList    = parsePlantList(myRaw)
    storePlantsList = parseStoreList(storeRaw)

    populateManagerGrid()
    populateStoreGrid()
  end
end

-- --- Manager Grid ---------------------------------------------

function populateManagerGrid()
  if not managerWindow then return end
  local grid = managerWindow:recursiveGetChildById('creatureGrid')
  if not grid then return end

  grid:destroyChildren()
  local lastSelectedId = selectedMyPlant and selectedMyPlant.id
  selectedMyPlant = nil

  for _, p in ipairs(myPlantsList) do
    local ok, card = pcall(function() return g_ui.createWidget('PlantCard', grid) end)
    if ok and card then
      card.creatureData = p

      local itemWidget = card:getChildById('stageItem')
      if itemWidget and p.stageClientId and p.stageClientId > 0 then
        setItemWidget(itemWidget, p.stageClientId)
      end

      local nameLabel = card:getChildById('nameLabel')
      if nameLabel then nameLabel:setText(p.customName or p.baseName) end

      if p.id == lastSelectedId then
        pcall(function() card:setChecked(true) end)
      end
    end
  end

  updateManagerPreview()
end

function onCreatureCheckChange(card)
  if card:isChecked() then
    local grid = card:getParent()
    for _, other in ipairs(grid:getChildren()) do
      if other ~= card then pcall(function() other:setChecked(false) end) end
    end
    selectedMyPlant = card.creatureData
  else
    selectedMyPlant = nil
  end
  updateManagerPreview()
end

function updateManagerPreview()
  if not managerWindow then return end

  local previewItem  = managerWindow:recursiveGetChildById('previewItem')
  local nameLabel    = managerWindow:recursiveGetChildById('creatureNameLabel')
  local infoLabel    = managerWindow:recursiveGetChildById('creatureInfoLabel')
  local waterBtn     = managerWindow:recursiveGetChildById('feedButton')
  local growBtn      = managerWindow:recursiveGetChildById('trainButton')
  local harvestBtn   = managerWindow:recursiveGetChildById('harvestButton')
  local releaseBtn   = managerWindow:recursiveGetChildById('releaseButton')

  if not waterBtn then return end

  if selectedMyPlant then
    local p = selectedMyPlant
    if previewItem and p.stageClientId and p.stageClientId > 0 then
      setItemWidget(previewItem, p.stageClientId)
    end
    if nameLabel then nameLabel:setText(p.customName or p.baseName) end

    local nowServer  = currentServerTime + (os.time() - clientFetchTime)
    local readyTime  = p.lastWater + (p.waterCooldown or 18000)
    local remaining  = math.max(0, readyTime - nowServer)
    local isMaxStage = (p.stage or 1) >= (p.maxStage or 3)

    local stageText
    if not isMaxStage then
      stageText = "Stage: " .. p.stage .. "/" .. p.maxStage
        .. (remaining > 0 and (" | Grow in: " .. formatTime(remaining)) or " | Ready to Grow!")
    else
      stageText = "Stage: " .. p.stage .. "/" .. p.maxStage
        .. (remaining > 0 and (" | Harvest in: " .. formatTime(remaining)) or " | Ready to Harvest!")
    end

    if infoLabel then
      infoLabel:setText(stageText .. "\nHarvest: " .. (p.harvestName or ""))
    end

    waterBtn:setEnabled(true)
    growBtn:setEnabled((not isMaxStage) and remaining <= 0)
    harvestBtn:setEnabled(isMaxStage and remaining <= 0)
    releaseBtn:setEnabled(true)
  else
    if previewItem then pcall(function() previewItem:setItemId(0) end) end
    if nameLabel  then nameLabel:setText("No plant selected") end
    if infoLabel  then infoLabel:setText("") end
    waterBtn:setEnabled(false)
    growBtn:setEnabled(false)
    harvestBtn:setEnabled(false)
    releaseBtn:setEnabled(false)
  end
end

function feedSelected()
  if not selectedMyPlant then return end
  sendToServer("water|" .. selectedMyPlant.id)
end

function trainSelected()
  if not selectedMyPlant then return end
  sendToServer("grow|" .. selectedMyPlant.id)
end

function harvestSelected()
  if not selectedMyPlant then return end
  sendToServer("harvest|" .. selectedMyPlant.id)
end

function releaseSelected()
  if not selectedMyPlant then return end
  sendToServer("release|" .. selectedMyPlant.id)
end

-- --- Store Grid -----------------------------------------------

function populateStoreGrid()
  if not storeWindow then return end
  local grid = storeWindow:recursiveGetChildById('storeGrid')
  if not grid then return end

  grid:destroyChildren()
  local lastSelected = selectedStorePlant and selectedStorePlant.baseName
  selectedStorePlant = nil

  for _, p in ipairs(storePlantsList) do
    local ok, card = pcall(function() return g_ui.createWidget('StoreSeedCard', grid) end)
    if ok and card then
      card.creatureData = p

      local itemWidget = card:getChildById('seedItem')
      if itemWidget and p.seedClientId and p.seedClientId > 0 then
        setItemWidget(itemWidget, p.seedClientId)
      end

      local nameLabel = card:getChildById('nameLabel')
      if nameLabel then nameLabel:setText(p.baseName) end

      local priceLabel = card:getChildById('priceLabel')
      if priceLabel then priceLabel:setText(p.price .. " gold") end

      if p.baseName == lastSelected then
        pcall(function() card:setChecked(true) end)
      end
    end
  end

  updateStorePreview()
end

function onStoreCreatureCheckChange(card)
  if card:isChecked() then
    local grid = card:getParent()
    for _, other in ipairs(grid:getChildren()) do
      if other ~= card then pcall(function() other:setChecked(false) end) end
    end
    selectedStorePlant = card.creatureData
  else
    selectedStorePlant = nil
  end
  updateStorePreview()
end

function updateStorePreview()
  if not storeWindow then return end

  local previewItem  = storeWindow:recursiveGetChildById('previewItem')
  local nameLabel    = storeWindow:recursiveGetChildById('creatureNameLabel')
  local priceLabel   = storeWindow:recursiveGetChildById('creaturePriceLabel')
  local harvestLabel = storeWindow:recursiveGetChildById('creatureFoodLabel')
  local buyBtn       = storeWindow:recursiveGetChildById('buyButton')

  if not buyBtn then return end

  if selectedStorePlant then
    local p = selectedStorePlant
    if previewItem and p.seedClientId and p.seedClientId > 0 then
      setItemWidget(previewItem, p.seedClientId)
    end
    if nameLabel    then nameLabel:setText(p.baseName) end
    if priceLabel   then priceLabel:setText("Price: " .. p.price .. " gold") end
    if harvestLabel then harvestLabel:setText("Harvest: " .. (p.harvestName or "")) end
    buyBtn:setEnabled(true)
  else
    if previewItem  then pcall(function() previewItem:setItemId(0) end) end
    if nameLabel    then nameLabel:setText("No seed selected") end
    if priceLabel   then priceLabel:setText("") end
    if harvestLabel then harvestLabel:setText("") end
    buyBtn:setEnabled(false)
  end
end

function buySelected()
  if not selectedStorePlant then return end
  sendToServer("buy|" .. selectedStorePlant.baseName)
end

-- Expõe funções públicas para o OTUI
modules.game_creaturemanager.show                       = show
modules.game_creaturemanager.hide                       = hide
modules.game_creaturemanager.showStore                  = showStore
modules.game_creaturemanager.hideStore                  = hideStore
modules.game_creaturemanager.hideAll                    = hideAll
modules.game_creaturemanager.feedSelected               = feedSelected
modules.game_creaturemanager.harvestSelected            = harvestSelected
modules.game_creaturemanager.trainSelected              = trainSelected
modules.game_creaturemanager.releaseSelected            = releaseSelected
modules.game_creaturemanager.buySelected                = buySelected
modules.game_creaturemanager.onCreatureCheckChange      = onCreatureCheckChange
modules.game_creaturemanager.onStoreCreatureCheckChange = onStoreCreatureCheckChange
modules.game_creaturemanager.updateManagerPreview       = updateManagerPreview
modules.game_creaturemanager.updateStorePreview         = updateStorePreview
