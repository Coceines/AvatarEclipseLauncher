if not UIWindow then dofile 'uiwindow' end

-- @docclass
UIMessageBox = extends(UIWindow, "UIMessageBox")

-- messagebox cannot be created from otui files
UIMessageBox.create = nil

local FADE_DURATION_MS = 150
local FADE_STEPS = 5

local fadeEvents = setmetatable({}, { __mode = "k" })

local function cancelFadeBox(widget)
  if fadeEvents[widget] then
    for _, ev in ipairs(fadeEvents[widget]) do
      removeEvent(ev)
    end
    fadeEvents[widget] = nil
  end
end

local function animateFadeBox(widget, fromOpacity, toOpacity, callback)
  cancelFadeBox(widget)
  local steps = FADE_STEPS
  local stepTime = FADE_DURATION_MS / steps
  local events = {}
  widget:setOpacity(fromOpacity)

  for i = 1, steps do
    local ev = scheduleEvent(function()
      if widget:isDestroyed() then return end
      local progress = i / steps
      local opacity = fromOpacity + (toOpacity - fromOpacity) * progress
      widget:setOpacity(opacity)
      if i == steps and callback then
        callback()
      end
    end, math.floor(stepTime * i))
    table.insert(events, ev)
  end
  fadeEvents[widget] = events
end

function UIMessageBox.display(title, message, buttons, onEnterCallback, onEscapeCallback)
  local messageBox = UIMessageBox.internalCreate()
  rootWidget:addChild(messageBox)

  messageBox:setStyle('MainWindow')
  messageBox:setText(title)

  local messageLabel = g_ui.createWidget('MessageBoxLabel', messageBox)
  messageLabel:setText(message)

  local buttonsWidth = 0
  local buttonsHeight = 0

  local anchor = AnchorRight
  if buttons.anchor then anchor = buttons.anchor end

  local buttonHolder = g_ui.createWidget('MessageBoxButtonHolder', messageBox)
  buttonHolder:addAnchor(anchor, 'parent', anchor)

  for i=1,#buttons do
    local button = messageBox:addButton(buttons[i].text, buttons[i].callback)
    if i == 1 then
      button:setMarginLeft(0)
      button:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      button:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      buttonsHeight = button:getHeight()
    else
      button:addAnchor(AnchorBottom, 'prev', AnchorBottom)
      button:addAnchor(AnchorLeft, 'prev', AnchorRight)
    end
    buttonsWidth = buttonsWidth + button:getWidth() + button:getMarginLeft()
  end

  buttonHolder:setWidth(buttonsWidth)
  buttonHolder:setHeight(buttonsHeight)

  if onEnterCallback then connect(messageBox, { onEnter = onEnterCallback }) end
  if onEscapeCallback then connect(messageBox, { onEscape = onEscapeCallback }) end

  messageBox:setWidth(math.max(messageLabel:getWidth(), messageBox:getTextSize().width, buttonHolder:getWidth()) + messageBox:getPaddingLeft() + messageBox:getPaddingRight())
  messageBox:setHeight(messageLabel:getHeight() + messageBox:getPaddingTop() + messageBox:getPaddingBottom() + buttonHolder:getHeight() + buttonHolder:getMarginTop())

  -- Fade in
  messageBox:setOpacity(0)
  animateFadeBox(messageBox, 0, 1)

  return messageBox
end

function displayInfoBox(title, message)
  local messageBox
  local defaultCallback = function() messageBox:ok() end
  messageBox = UIMessageBox.display(title, message, {{text='Ok', callback=defaultCallback}}, defaultCallback, defaultCallback)
  return messageBox
end

function displayErrorBox(title, message)
  local messageBox
  local defaultCallback = function() messageBox:ok() end
  messageBox = UIMessageBox.display(title, message, {{text='Ok', callback=defaultCallback}}, defaultCallback, defaultCallback)
  return messageBox
end

function displayCancelBox(title, message)
  local messageBox
  local defaultCallback = function() messageBox:cancel() end
  messageBox = UIMessageBox.display(title, message, {{text='Cancel', callback=defaultCallback}}, defaultCallback, defaultCallback)
  return messageBox
end

function displayGeneralBox(title, message, buttons, onEnterCallback, onEscapeCallback)
  return UIMessageBox.display(title, message, buttons, onEnterCallback, onEscapeCallback)
end

function UIMessageBox:addButton(text, callback)
  local buttonHolder = self:getChildById('buttonHolder')
  local button = g_ui.createWidget('MessageBoxButton', buttonHolder)
  button:setText(text)
  connect(button, { onClick = callback })
  return button
end

function UIMessageBox:ok()
  signalcall(self.onOk, self)
  self.onOk = nil
  self:fadeOutAndDestroy()
end

function UIMessageBox:cancel()
  signalcall(self.onCancel, self)
  self.onCancel = nil
  self:fadeOutAndDestroy()
end

-- UIWindow.onVisibilityChange would also fade; prevent double-fade
function UIMessageBox:onVisibilityChange(visible)
  -- MessageBox manages its own fade via display() / fadeOutAndDestroy()
  if not visible then
    signalcall(self.onClose, self)
  end
end

function UIMessageBox:fadeOutAndDestroy()
  animateFadeBox(self, self:getOpacity(), 0, function()
    if self:isDestroyed() then return end
    self:destroy()
  end)
end
