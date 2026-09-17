local codeWindow = nil
local closeButton, redeemButton, closeRedeemButton = nil, nil, nil
local codeEdit, codeLabel, textBg = nil, nil, nil
local rewardModal, rewardItems, rewardCode, confirmButton = nil, nil, nil, nil
local codeBtn = nil

local CODE_SHOW_OPCODE = 44
local CODE_ACTION_OPCODE = 45

local hoverTimer = nil
local lastOverClose = false
local lastOverRedeem = false
local lastOverCloseRedeem = false
local lastOverConfirm = false
local closeHit = nil
local redeeming = false

local function nowMs()
  if g_clock and g_clock.millis then
    return g_clock.millis()
  end
  return os.time() * 1000
end

local function setOpacitySafe(widget, value)
  if widget and widget.setOpacity then
    widget:setOpacity(value)
  end
end

local function bindWidgets()
  closeButton = codeWindow:getChildById("closeButton")
  redeemButton = codeWindow:getChildById("redeemButton")
  closeRedeemButton = codeWindow:getChildById("closeRedeemButton")

  textBg = codeWindow:getChildById("textBg")
  if textBg then
    codeEdit = textBg:getChildById("codeEdit")
    codeLabel = textBg:getChildById("codeLabel")
  end

  rewardModal = codeWindow:getChildById("rewardModal")
  if rewardModal then
    rewardItems = rewardModal:getChildById("rewardItems")
    rewardCode = rewardModal:getChildById("rewardCode")
    confirmButton = rewardModal:getChildById("confirmButton")
  end

  return closeButton and redeemButton and closeRedeemButton and textBg and codeEdit and codeLabel and rewardModal and rewardItems and rewardCode and confirmButton
end

local function ensureCloseHit()
  if closeHit then
    return
  end

  local root = g_ui.getRootWidget()
  closeHit = g_ui.createWidget("UIButton", root)
  closeHit:setFocusable(false)
  closeHit:setPhantom(false)

  if closeHit.setOpacity then
    closeHit:setOpacity(0)
  end

  closeHit:hide()
  closeHit.onClick = function()
    naoexibir()
  end
end

local function syncCloseHit()
  if not closeHit or not closeButton or not codeWindow then
    return
  end

  if not codeWindow:isVisible() then
    closeHit:hide()
    return
  end

  local pos = closeButton:getPosition()
  local size = closeButton:getSize()

  if not pos or not size then
    closeHit:hide()
    return
  end

  closeHit:setPosition(pos)
  closeHit:setSize(size)
  closeHit:show()
  closeHit:raise()
end

local function stopHoverTimer()
  if hoverTimer then
    removeEvent(hoverTimer)
    hoverTimer = nil
  end

  lastOverClose = false
  lastOverRedeem = false
  lastOverCloseRedeem = false
  lastOverConfirm = false
end

local function isMouseOver(w, mouse)
  if not w or not w:isVisible() then
    return false
  end

  local pos = w:getPosition()
  local size = w:getSize()

  if not pos or not size then
    return false
  end

  return mouse.x >= pos.x and mouse.x <= (pos.x + size.width)
     and mouse.y >= pos.y and mouse.y <= (pos.y + size.height)
end

local function startHoverTimer()
  stopHoverTimer()

  local function tick()
    hoverTimer = nil

    if not codeWindow or not codeWindow:isVisible() then
      stopHoverTimer()
      return
    end

    syncCloseHit()

    local mouse = g_window.getMousePosition()
    if not mouse then
      hoverTimer = scheduleEvent(tick, 80)
      return
    end

    local overClose = isMouseOver(closeHit, mouse)
    local overRedeem = (redeemButton and redeemButton:isVisible()) and isMouseOver(redeemButton, mouse) or false
    local overCloseRedeem = (closeRedeemButton and closeRedeemButton:isVisible()) and isMouseOver(closeRedeemButton, mouse) or false
    local overConfirm = (rewardModal and rewardModal:isVisible()) and isMouseOver(confirmButton, mouse) or false

    if overClose ~= lastOverClose then
      setOpacitySafe(closeButton, overClose and 0.85 or 1.0)
      lastOverClose = overClose
    end

    if overRedeem ~= lastOverRedeem then
      setOpacitySafe(redeemButton, overRedeem and 0.80 or 1.0)
      lastOverRedeem = overRedeem
    end

    if overCloseRedeem ~= lastOverCloseRedeem then
      setOpacitySafe(closeRedeemButton, overCloseRedeem and 0.80 or 1.0)
      lastOverCloseRedeem = overCloseRedeem
    end

    if overConfirm ~= lastOverConfirm then
      setOpacitySafe(confirmButton, overConfirm and 0.80 or 1.0)
      lastOverConfirm = overConfirm
    end

    hoverTimer = scheduleEvent(tick, 80)
  end

  hoverTimer = scheduleEvent(tick, 80)
end

local function normalizeCode(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("%s+", "")
  s = s:upper()
  return s
end

local function doRedeem()
  if not g_game.isOnline() then
    return
  end

  -- Com o modal de recompensa aberto, Resgatar/Enter apenas fecha
  -- (mesmo comportamento do botao Confirmar / tecla Escape).
  if rewardModal and rewardModal:isVisible() then
    hideRewardModal()
    return
  end

  if redeeming then
    return
  end

  local code = normalizeCode(codeEdit:getText())
  if code == "" then
    displayInfoBox("Resgatar", "Digite um codigo.")
    return
  end

  redeeming = true
  local payload = "redeem@" .. code
  g_game.getProtocolGame():sendExtendedOpcode(CODE_ACTION_OPCODE, payload)

  -- seguranca: libera o botao mesmo se o servidor nao responder
  scheduleEvent(function()
    redeeming = false
  end, 2000)
end

local function fade(widget, from, to, ms, onDone)
  if not widget then
    return
  end

  local start = nowMs()

  local function step()
    local t = (nowMs() - start) / ms
    if t >= 1 then
      setOpacitySafe(widget, to)
      if onDone then
        onDone()
      end
      return
    end

    local v = from + (to - from) * t
    setOpacitySafe(widget, v)
    scheduleEvent(step, 16)
  end

  setOpacitySafe(widget, from)
  scheduleEvent(step, 16)
end

local function createRewardSlot(parent, clientItemId, count, itemName)
  local slot = g_ui.createWidget("UIWidget", parent)
  slot:setSize("40 41")
  slot:setImageSource("images/itembg")

  local item = g_ui.createWidget("UIItem", slot)
  item:setSize("32 32")
  item:setItemId(clientItemId)
  item:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
  item:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)

  local c = tonumber(count) or 1
  local name = tostring(itemName or "Item")
  local tip = name .. " - " .. c

  if item and item.setTooltipTable then
    item:setTooltipTable("", clientItemId, tip, true)
  end

  if c > 1 then
    local label = g_ui.createWidget("Label", slot)
    label:setText(tostring(c))
    label:setFont("verdana-11px-antialised")
    label:setTextAlign(AlignRight)
    label:addAnchor(AnchorBottom, "parent", AnchorBottom)
    label:addAnchor(AnchorRight, "parent", AnchorRight)
    label:setMarginBottom(2)
    label:setMarginRight(4)
  end

  return slot
end

local function showRewardModal(code, items)
  if not rewardModal then
    return
  end

  rewardModal:show()
  rewardModal:raise()
  setOpacitySafe(rewardModal, 0.00)

  rewardCode:setText(tostring(code or ""))

  rewardItems:destroyChildren()
  for i = 1, #items do
    local it = items[i]
    local id = tonumber(it[1]) or 0
    local count = tonumber(it[2]) or 1
    local name = tostring(it[3] or "Item")
    if id > 0 then
      createRewardSlot(rewardItems, id, count, name)
    end
  end

  fade(rewardModal, 0.00, 1.00, 160)
end

local function hideRewardModal()
  if not rewardModal then
    return
  end

  fade(rewardModal, rewardModal:getOpacity() or 1.0, 0.00, 120, function()
    rewardModal:hide()
  end)

  codeEdit:focus()
end

local function syncCodeLabel()
  if not codeEdit or not codeLabel then
    return
  end

  codeLabel:setText(codeEdit:getText() or "")
end

function exibir()
  if not codeWindow then
    return
  end

  if codeBtn:isOn() then
    codeBtn:setOn(false)
    naoexibir()
  else
    codeBtn:setOn(true)
    codeWindow:show()
    syncCloseHit()
    startHoverTimer()
    codeEdit:focus()
    g_game.getProtocolGame():sendExtendedOpcode(CODE_SHOW_OPCODE, "show")
  end
end

function naoexibir()
  redeeming = false

  if rewardModal and rewardModal:isVisible() then
    rewardModal:hide()
  end

  if codeEdit then
    codeEdit:setText("")
  end

  if codeLabel then
    codeLabel:setText("")
  end

  if rewardItems then
    rewardItems:destroyChildren()
  end

  if codeBtn then
    codeBtn:setOn(false)
  end

  if codeWindow then
    codeWindow:hide()
  end

  if closeHit then
    closeHit:hide()
  end

  stopHoverTimer()
end

function init()
  codeWindow = g_ui.displayUI("code")
  if not codeWindow then
    return
  end

  if not bindWidgets() then
    return
  end

  ensureCloseHit()

  connect(g_game, {
    onGameStart = naoexibir,
    onGameEnd = naoexibir
  })

  codeBtn = modules.client_topmenu.addRightGameToggleButton(
    'codeWindow',
    tr('Codes'),
    '/images/topbuttons/code',
    exibir
  )
  codeBtn:setWidth(34)
  codeBtn:setOn(false)

  g_keyboard.bindKeyDown("Escape", function()
    if rewardModal and rewardModal:isVisible() then
      hideRewardModal()
      return
    end
    naoexibir()
  end)

  codeWindow:hide()
  rewardModal:hide()

  codeEdit:setText("")
  codeLabel:setText("")

  textBg.onClick = function()
    codeEdit:focus()
  end

  codeLabel.onClick = function()
    codeEdit:focus()
  end

  connect(codeEdit, {
    onTextChange = function()
      syncCodeLabel()
    end
  })

  redeemButton.onClick = doRedeem

  closeRedeemButton.onClick = function()
    naoexibir()
  end
  g_keyboard.bindKeyPress("Enter", doRedeem, codeEdit)

  confirmButton.onClick = function()
    hideRewardModal()
  end

  ProtocolGame.registerExtendedOpcode(CODE_SHOW_OPCODE, onCodeShow)
end

function terminate()
  disconnect(g_game, {
    onGameStart = naoexibir,
    onGameEnd = naoexibir
  })

  stopHoverTimer()
  g_keyboard.unbindKeyPress("Enter", doRedeem, codeEdit)
  ProtocolGame.unregisterExtendedOpcode(CODE_SHOW_OPCODE)

  if closeHit then
    closeHit:destroy()
    closeHit = nil
  end

  if codeWindow then
    codeWindow:destroy()
    codeWindow = nil
  end
end

function hide()
  naoexibir()
end

function onCodeShow(protocol, opcode, buffer)
  if not codeWindow then
    return
  end

  buffer = tostring(buffer or "")
  if buffer == "" then
    return
  end

  local p = buffer:explode("@")
  local action = p[1] or ""

  if action == "show" then
    codeBtn:setOn(true)
    codeWindow:show()
    syncCloseHit()
    startHoverTimer()
    codeEdit:focus()
    return
  end

  if action == "result" then
    redeeming = false
    local status = p[2] or "err"
    local msg = p[3] or ""

    if status ~= "ok" then
      displayInfoBox("Resgatar", msg ~= "" and msg or "Nao foi possivel resgatar.")
      return
    end

    local code = p[4] or ""
    local items = {}

    for i = 5, #p, 3 do
      local itemId = tonumber(p[i]) or 0
      local count = tonumber(p[i + 1]) or 1
      local name = p[i + 2] or "Item"
      if itemId > 0 then
        table.insert(items, {itemId, count, name})
      end
    end

    codeEdit:setText("")
    syncCodeLabel()

    if #items == 0 then
      displayInfoBox("Resgatar", msg ~= "" and msg or "Codigo resgatado.")
      return
    end

    showRewardModal(code, items)
  end
end