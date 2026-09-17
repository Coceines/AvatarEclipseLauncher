-- @docclass
UIWindow = extends(UIWidget, "UIWindow")

local FADE_MS = 300
local FADE_STEPS = 10

local fadeEvts = setmetatable({}, { __mode = "k" })

local function fadeCancel(w)
  if fadeEvts[w] then
    for _, e in ipairs(fadeEvts[w]) do removeEvent(e) end
    fadeEvts[w] = nil
  end
end

local function fadeTo(w, to, done)
  fadeCancel(w)
  local from = w:getOpacity()
  if math.abs(from - to) < 0.01 then if done then done() end return end
  local n, dt = FADE_STEPS, math.max(1, math.floor(FADE_MS / FADE_STEPS))
  local evs = {}
  for i = 1, n do
    local e = scheduleEvent(function()
      if w:isDestroyed() then return end
      w:setOpacity(from + (to - from) * (i / n))
      if i == n and done then done() end
    end, dt * i)
    evs[#evs + 1] = e
  end
  fadeEvts[w] = evs
end

function UIWindow.create()
  local w = UIWindow.internalCreate()
  w:setTextAlign(AlignTopCenter)
  w:setDraggable(true)
  w:setAutoFocusPolicy(AutoFocusFirst)
  return w
end

function UIWindow:getClassName() return 'UIWindow' end

-- Central funnel: all visibility changes go through here
function UIWindow:setVisible(vis)
  if vis == self:isExplicitlyVisible() then return end
  fadeCancel(self)
  if vis then
    -- Show: set invisible first, then fade in
    self:setOpacity(0)
    UIWidget.setVisible(self, true)
    fadeTo(self, 1)
  else
    -- Hide: fade out first, then actually hide
    fadeTo(self, 0, function()
      if self:isDestroyed() then return end
      UIWidget.setVisible(self, false)
      self:setOpacity(1)
    end)
  end
end

function UIWindow:show()
  self:setVisible(true)
end

function UIWindow:hide()
  self:setVisible(false)
end

function UIWindow:destroy()
  fadeCancel(self)
  UIWidget.destroy(self)
end

-- Subclasses can override this for extra cleanup (e.g. UIMiniWindow)
function UIWindow:onVisibilityChange(visible)
end

function UIWindow:onKeyDown(keyCode, keyboardModifiers)
  if keyboardModifiers == KeyboardNoModifier then
    if keyCode == KeyEnter then signalcall(self.onEnter, self)
    elseif keyCode == KeyEscape then signalcall(self.onEscape, self) end
  end
end

function UIWindow:onFocusChange(focused) if focused then self:raise() end end

function UIWindow:onDragEnter(mousePos)
  self:breakAnchors()
  self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
  return true
end

function UIWindow:onDragLeave() end

function UIWindow:onDragMove(mousePos, mMoved)
  local p = { x = mousePos.x - self.movingReference.x, y = mousePos.y - self.movingReference.y }
  self:setPosition(p)
  self:bindRectToParent()
end
