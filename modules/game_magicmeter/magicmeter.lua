-- Magic Meter - Client side
-- Shows how much damage EACH spell dealt (opcode 116 <-> data/creaturescripts/scripts/magicmeter.lua)
-- The server always counts (even with the window closed); the client just renders when open.

magicMeterWindow = nil
magicMeterButton = nil
local spellData = {}
local totalMagicDamage = 0
local interpolationEvent = nil

local OPCODE = 116

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = reset,
  })

  ProtocolGame.registerExtendedOpcode(OPCODE, onMagicMeterOpcode)

  -- Docked MiniWindow on the right panel, same style as Skills/Battle/VIP list
  magicMeterWindow = g_ui.loadUI('magicmeter', modules.game_interface.getRightPanel())

  -- Topbar button with the Magicmeter icon
  magicMeterButton = modules.client_topmenu.addRightGameToggleButton('magicMeterButton', tr('Magic Meter') .. ' (Ctrl+Shift+D)', '/images/topbuttons/Magicmeter', toggle)

  -- Ctrl+Shift+D opens/closes the meter
  g_keyboard.bindKeyDown('Ctrl+Shift+D', toggle)

  magicMeterWindow:setup()
  magicMeterWindow:setContentMinimumHeight(44)
  magicMeterWindow:setContentMaximumHeight(303)

  -- Sync the button with the window state restored from settings
  magicMeterButton:setOn(magicMeterWindow:isExplicitlyVisible())
  if magicMeterWindow:isExplicitlyVisible() then
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

  ProtocolGame.unregisterExtendedOpcode(OPCODE)

  g_keyboard.unbindKeyDown('Ctrl+Shift+D')

  stopInterpolation()

  if magicMeterWindow then
    magicMeterWindow:destroy()
    magicMeterWindow = nil
  end

  if magicMeterButton then
    magicMeterButton:destroy()
    magicMeterButton = nil
  end
end

function toggle()
  if not magicMeterWindow or not magicMeterButton then return end
  -- The topbar button does NOT auto-toggle its state, so we manage it here
  if magicMeterButton:isOn() then
    magicMeterButton:setOn(false)
    magicMeterWindow:close()
    stopInterpolation()
  else
    magicMeterButton:setOn(true)
    magicMeterWindow:open()
    startInterpolation()
    sendRequest()
    updateUI()
  end
end

function onMiniWindowClose()
  if magicMeterButton then
    magicMeterButton:setOn(false)
  end
  stopInterpolation()
end

function onGameStart()
  reset()
  -- Ask for the current totals on login (the server kept counting while offline data exists)
  if g_game.isOnline() then
    sendRequest()
  end
end

function reset()
  spellData = {}
  totalMagicDamage = 0
  if magicMeterWindow then
    local rowsContainer = magicMeterWindow:recursiveGetChildById('rowsContainer')
    if rowsContainer then
      rowsContainer:destroyChildren()
    end
  end
end

function sendRequest()
  if g_game.isOnline() then
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, "request")
  end
end

function formatNumber(n)
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  elseif n >= 1000 then
    return string.format("%.1fK", n / 1000)
  end
  return tostring(n)
end

function getSpellColor(name)
  local colors = {"#ff5555", "#55ff55", "#5555ff", "#ffff55", "#ff55ff", "#55ffff"}
  local hash = 0
  for i = 1, #name do
    hash = hash + string.byte(name, i)
  end
  return colors[math.max(1, (hash % #colors) + 1)]
end

function updateUI()
  if not magicMeterWindow then return end
  if not magicMeterButton or not magicMeterButton:isOn() then return end

  local rowsContainer = magicMeterWindow:recursiveGetChildById('rowsContainer')
  if not rowsContainer then return end

  local sortedData = {}
  for name, damage in pairs(spellData) do
    if damage > 0 then
      table.insert(sortedData, {name = name, damage = damage})
    end
  end

  if #sortedData == 0 then
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

    local percentOfTotal = totalMagicDamage > 0 and (data.damage / totalMagicDamage) * 100 or 0
    local displayPercent = math.floor(percentOfTotal)

    local rowId = 'row-' .. data.name
    local row = rowsContainer:getChildById(rowId)
    if not row then
      row = g_ui.createWidget('MagicMeterRow', rowsContainer)
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
      pb:setBackgroundColor(getSpellColor(data.name) .. "aa")
    end
  end
end

function updateInterpolation()
  if not magicMeterWindow then return end
  local rowsContainer = magicMeterWindow:recursiveGetChildById('rowsContainer')
  if not rowsContainer then return end

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

function onMagicMeterOpcode(protocol, opcode, buffer)
  if buffer == "reset" then
    reset()
    -- Keep the window open with the hint when the button is still on
    if magicMeterButton and magicMeterButton:isOn() then
      updateUI()
    end
    return
  end

  -- Format expected: "Spell1:Damage1,Spell2:Damage2..."
  spellData = {}
  totalMagicDamage = 0

  local entries = string.split(buffer, ",")
  for _, entry in ipairs(entries) do
    if entry and entry ~= "" then
      local parts = string.split(entry, ":")
      if #parts == 2 then
        local name = parts[1]
        local damage = tonumber(parts[2]) or 0
        if damage > 0 then
          spellData[name] = damage
          totalMagicDamage = totalMagicDamage + damage
        end
      end
    end
  end

  if magicMeterButton and magicMeterButton:isOn() then
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
