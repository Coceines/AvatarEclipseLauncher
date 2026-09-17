-- ============================================================================
-- Daily Reward Module (OTClient) - Fixed layout version
-- ============================================================================

if type(ItemType) == "table" then
  local mt = getmetatable(ItemType) or {}
  mt.__call = function(_, id)
    if g_things and g_things.tryGetItemType then
      return g_things.tryGetItemType(id)
    elseif g_things and g_things.getItemType then
      return g_things.getItemType(id)
    end
    return nil
  end
  setmetatable(ItemType, mt)
elseif type(ItemType) ~= "function" then
  ItemType = function(id)
    if g_things and g_things.tryGetItemType then
      return g_things.tryGetItemType(id)
    elseif g_things and g_things.getItemType then
      return g_things.getItemType(id)
    end
    return nil
  end
end

local OPCODE = 170
local window = nil
local daysPanel = nil
local claimButton = nil
local dayWidgets = {}

local COLOR_AVAILABLE = '#f0c040'
local COLOR_CLAIMED = '#40c040'
local COLOR_MISSED = '#c04040'
local COLOR_FUTURE = '#666666'
local COLOR_PANEL_BG = '#1e1e30'

modules.game_dailyreward = {}

function init()
  g_ui.importStyle('game_dailyreward')
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.getLocalPlayer() then
    online()
  end
end

function terminate()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  offline()
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
end

function online()
  local ok, w = pcall(function() return g_ui.createWidget('DailyRewardWindow', rootWidget) end)
  if ok and w then
    window = w
    window:hide()

    daysPanel = window:getChildById('daysPanel')
    claimButton = window:getChildById('claimButton')

    buildDaysPanel()

    pcall(function()
      ProtocolGame.registerExtendedOpcode(OPCODE, function(protocol, op, buffer)
        receiveData(buffer)
      end)
    end)
  end
end

function offline()
  dayWidgets = {}
  if window then
    window:destroy()
    window = nil
  end
  daysPanel = nil
  claimButton = nil
end

function modules.game_dailyreward.onEscape()
  if window and window:isVisible() then
    window:hide()
  end
end

function modules.game_dailyreward.onClose()
  if window then
    window:hide()
  end
end

local currentDaysData = {}
local currentDayIndex = 1

local function sendClaim()
  pcall(function()
    if g_game.getProtocolGame() then
      g_game.getProtocolGame():sendExtendedOpcode(OPCODE, "claim")
    end
  end)
end

function modules.game_dailyreward.onClaim()
  if not g_game.getLocalPlayer() or not window then
    return
  end

  local todayData = nil
  if currentDaysData then
    for _, d in ipairs(currentDaysData) do
      if d.status == 'available' then
        todayData = d
        break
      end
    end
    if not todayData and currentDaysData[currentDayIndex] then
      todayData = currentDaysData[currentDayIndex]
    end
  end

  if todayData and todayData.warn and todayData.warn ~= '' then
    local msgBox = nil
    local function onYes()
      if msgBox then msgBox:ok() end
      sendClaim()
    end
    local function onNo()
      if msgBox then msgBox:cancel() end
    end

    msgBox = displayGeneralBox(
      tr('Aviso'),
      todayData.warn,
      {
        { text = tr('Sim'), callback = onYes },
        { text = tr('Nao'), callback = onNo }
      },
      onYes,
      onNo
    )
    return
  end

  sendClaim()
end

function buildDaysPanel()
  if not daysPanel then return end

  daysPanel:destroyChildren()
  dayWidgets = {}

  for i = 1, 7 do
    local ok, box = pcall(function() return g_ui.createWidget('DailyRewardDayBox', daysPanel) end)
    if ok and box then
      dayWidgets[i] = box
    end
  end
end

function updateDayBox(dayData)
  local box = dayWidgets[dayData.day]
  if not box then return end

  local dayLabel = box:getChildById('dayLabel')
  local itemSprite = box:getChildById('itemSprite')
  local nameLabel = box:getChildById('itemName')
  local overlay = box:getChildById('overlay')

  if dayLabel then
    local labelText = 'Dia ' .. dayData.day
    if dayData.status == 'available' then
      labelText = labelText .. ' *'
    end
    dayLabel:setText(labelText)
  end

  if itemSprite then
    local clientId = 0

    if dayData.clientId and dayData.clientId > 0 then
      clientId = dayData.clientId
    else
      local ok, res = pcall(function()
        local it = ItemType(dayData.itemId)
        if it and not it:isNull() then
          return it:getClientId()
        end
        return 0
      end)
      if ok and res and res > 0 then
        clientId = res
      end
    end

    -- Fallback se nao encontrou
    if clientId == 0 and dayData.itemId and dayData.itemId > 0 then
      clientId = dayData.itemId
    end

    if clientId > 0 then
      itemSprite:setItemId(clientId)
      if dayData.count and dayData.count > 1 then
        itemSprite:setItemCount(dayData.count)
      end
      itemSprite:show()
    else
      itemSprite:hide()
    end
  end

  if nameLabel then
    nameLabel:setText(dayData.name or '')
  end

  box:setBorderWidth(2)

  if dayData.status == 'claimed' then
    box:setBorderColor(COLOR_CLAIMED)
    box:setBackgroundColor('#1a2e1a')
    if itemSprite then itemSprite:setOpacity(0.2) end
    if overlay then
      overlay:setText('V')
      overlay:setColor(COLOR_CLAIMED)
      overlay:setVisible(true)
    end
    if dayLabel then dayLabel:setColor(COLOR_CLAIMED) end

  elseif dayData.status == 'missed' then
    box:setBorderColor(COLOR_MISSED)
    box:setBackgroundColor('#2e1a1a')
    if itemSprite then itemSprite:setOpacity(0.2) end
    if overlay then
      overlay:setText('FAIL')
      overlay:setColor(COLOR_MISSED)
      overlay:setVisible(true)
    end
    if dayLabel then dayLabel:setColor(COLOR_MISSED) end

  elseif dayData.status == 'available' then
    box:setBorderColor(COLOR_AVAILABLE)
    box:setBackgroundColor('#2a2a1e')
    if itemSprite then itemSprite:setOpacity(1.0) end
    if overlay then overlay:setVisible(false) end
    if dayLabel then dayLabel:setColor(COLOR_AVAILABLE) end

  else
    box:setBorderColor('#444444')
    box:setBackgroundColor(COLOR_PANEL_BG)
    if itemSprite then itemSprite:setOpacity(0.4) end
    if overlay then overlay:setVisible(false) end
    if dayLabel then dayLabel:setColor('#666666') end
  end
end

function receiveData(buffer)
  if not window or not buffer or buffer == '' then return end

  local status, data = pcall(function() return json.decode(buffer) end)
  if not status or not data or type(data) ~= 'table' then return end

  if data.action == 'dailyRewardOpen' then
    currentDaysData = data.days or {}
    currentDayIndex = data.currentDay or 1

    if data.days then
      for _, dayData in ipairs(data.days) do
        updateDayBox(dayData)
      end
    end

    if claimButton then
      if data.canClaim then
        claimButton:enable()
      else
        claimButton:disable()
      end
    end

    window:show()
    window:raise()
    window:focus()

  elseif data.action == 'dailyRewardClaimed' then
    if data.message then
      displayInfoBox('Daily Reward', data.message)
    end
  end
end
