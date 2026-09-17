partyDamageWindow = nil
partyDamageButton = nil
local damageData = {}
local totalPartyDamage = 0
local interpolationEvent = nil
local lastShield = 0

local OPCODE = 115

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = reset,
  })

  connect(LocalPlayer, {
    onShieldChange = onShieldChange
  })

  ProtocolGame.registerExtendedOpcode(OPCODE, onPartyDamageOpcode)

  -- Docked MiniWindow on the right panel, same style as Skills/Battle/VIP list
  partyDamageWindow = g_ui.loadUI('partydamage', modules.game_interface.getRightPanel())

  -- Topbar button with the PartyDPS icon
  partyDamageButton = modules.client_topmenu.addRightGameToggleButton('partyDamageButton', tr('Party Damage') .. ' (Ctrl+D)', '/images/topbuttons/PartyDPS', toggle)

  -- Ctrl+D opens/closes the meter (same key shown in the button tooltip)
  g_keyboard.bindKeyDown('Ctrl+D', toggle)

  partyDamageWindow:setup()
  partyDamageWindow:setContentMinimumHeight(44)
  partyDamageWindow:setContentMaximumHeight(303)

  -- Sync the button with the window state restored from settings
  partyDamageButton:setOn(partyDamageWindow:isExplicitlyVisible())
  if partyDamageWindow:isExplicitlyVisible() then
    startInterpolation()
  end

  if g_game.isOnline() then
    onGameStart()
  end
end

function startInterpolation()
  if not interpolationEvent then
    interpolationEvent = cycleEvent(updateInterpolation, 50)
  end
end

function stopInterpolation()
  if interpolationEvent then
    removeEvent(interpolationEvent)
    interpolationEvent = nil
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = reset,
  })

  disconnect(LocalPlayer, {
    onShieldChange = onShieldChange
  })

  ProtocolGame.unregisterExtendedOpcode(OPCODE)

  g_keyboard.unbindKeyDown('Ctrl+D')

  stopInterpolation()

  if partyDamageWindow then
    partyDamageWindow:destroy()
    partyDamageWindow = nil
  end

  if partyDamageButton then
    partyDamageButton:destroy()
    partyDamageButton = nil
  end
end

function toggle()
  if not partyDamageWindow or not partyDamageButton then return end
  -- The topbar button does NOT auto-toggle its state, so we manage it here
  -- (same pattern as the skills module)
  if partyDamageButton:isOn() then
    partyDamageButton:setOn(false)
    partyDamageWindow:close()
    stopInterpolation()
  else
    partyDamageButton:setOn(true)
    partyDamageWindow:open()
    startInterpolation()
    updateUI()
  end
end

function onMiniWindowClose()
  if partyDamageButton then
    partyDamageButton:setOn(false)
  end
  stopInterpolation()
end

function onGameStart()
  reset()
  if g_game.isOnline() then
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, "request")
  end
end

function reset()
  damageData = {}
  totalPartyDamage = 0
  if partyDamageWindow then
    local ok, rowsContainer = pcall(function() return partyDamageWindow:recursiveGetChildById('rowsContainer') end)
    if ok and rowsContainer then
      rowsContainer:destroyChildren()
    end
  end
end

function onShieldChange(localPlayer, shield)
  -- Leaving the party clears the shield -> reset the meter and sync the button.
  -- Only react when transitioning FROM a party shield, so the initial shield-0
  -- event at login never closes a window the user left open.
  if shield == 0 and lastShield ~= 0 then
    reset()
    if partyDamageButton then
      partyDamageButton:setOn(false)
    end
    if partyDamageWindow then
      partyDamageWindow:close()
    end
  end
  lastShield = shield
end

function formatNumber(n)
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  elseif n >= 1000 then
    return string.format("%.1fK", n / 1000)
  end
  return tostring(n)
end

function getPlayerColor(name)
  local colors = {"#ff5555", "#55ff55", "#5555ff", "#ffff55", "#ff55ff", "#55ffff"}
  local hash = 0
  for i = 1, #name do
    hash = hash + string.byte(name, i)
  end
  return colors[math.max(1, (hash % #colors) + 1)]
end

function updateUI()
  if not partyDamageWindow then return end
  if not partyDamageButton or not partyDamageButton:isOn() then return end

  local ok, rowsContainer = pcall(function() return partyDamageWindow:recursiveGetChildById('rowsContainer') end)
  if not ok or not rowsContainer then return end

  local sortedData = {}
  for name, damage in pairs(damageData) do
    if damage > 0 then
      table.insert(sortedData, {name = name, damage = damage})
    end
  end

  if #sortedData == 0 then
    -- Button is on but there is no party damage yet: leave the list empty
    rowsContainer:destroyChildren()
    return
  end

  table.sort(sortedData, function(a, b) return a.damage > b.damage end)

  local validNames = {}
  for i, data in ipairs(sortedData) do
    if i <= 8 then
      validNames[data.name] = true
    end
  end

  for _, child in ipairs(rowsContainer:getChildren()) do
    local childName = child:getId():sub(5)
    if not validNames[childName] then
      child:destroy()
    end
  end

  for i, data in ipairs(sortedData) do
    if i > 8 then break end

    local percentOfTotal = totalPartyDamage > 0 and (data.damage / totalPartyDamage) * 100 or 0
    local displayPercent = math.floor(percentOfTotal)

    local rowId = 'row-' .. data.name
    local row = rowsContainer:getChildById(rowId)
    if not row then
      row = g_ui.createWidget('PartyDamageRow', rowsContainer)
      row:setId(rowId)
      local pb = row:recursiveGetChildById('progressBar')
      if pb then
        pb.currentPercent = 0
        pb:setPercent(0)
      end
    end

    row:recursiveGetChildById('nameLabel'):setText(data.name)
    row:recursiveGetChildById('damageLabel'):setText(formatNumber(data.damage) .. " (" .. displayPercent .. "%)")

    local pb = row:recursiveGetChildById('progressBar')
    if pb then
      pb.targetPercent = percentOfTotal
      pb:setBackgroundColor(getPlayerColor(data.name) .. "aa")
    end
  end
end

function updateInterpolation()
  if not partyDamageWindow then return end
  local ok, rowsContainer = pcall(function() return partyDamageWindow:recursiveGetChildById('rowsContainer') end)
  if not ok or not rowsContainer then return end

  for _, row in ipairs(rowsContainer:getChildren()) do
    local pb = row:recursiveGetChildById('progressBar')
    if pb and pb.targetPercent then
      pb.currentPercent = pb.currentPercent or 0
      local diff = pb.targetPercent - pb.currentPercent
      if math.abs(diff) > 0.1 then
        pb.currentPercent = pb.currentPercent + diff * 0.15
        pb:setPercent(math.floor(pb.currentPercent))
      else
        pb.currentPercent = pb.targetPercent
        pb:setPercent(math.floor(pb.currentPercent))
      end
    end
  end
end

function onPartyDamageOpcode(protocol, opcode, buffer)
  if buffer == "reset" then
    reset()
    -- Keep the window open with the hint when the button is still on
    if partyDamageButton and partyDamageButton:isOn() then
      updateUI()
    end
    return
  end

  -- Format expected: "Name1:Damage1,Name2:Damage2..."
  damageData = {}
  totalPartyDamage = 0

  local entries = string.split(buffer, ",")
  for _, entry in ipairs(entries) do
    if entry and entry ~= "" then
      local parts = string.split(entry, ":")
      if #parts == 2 then
        local name = parts[1]
        local damage = tonumber(parts[2]) or 0
        if damage > 0 then
          damageData[name] = damage
          totalPartyDamage = totalPartyDamage + damage
        end
      end
    end
  end

  if partyDamageButton and partyDamageButton:isOn() then
    updateUI()
  end
end

function requestReset()
  if g_game.isOnline() then
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, "reset")
  else
    reset()
  end
end
