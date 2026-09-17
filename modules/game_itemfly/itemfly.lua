-- Smooth Item Pickup Animation
-- When items are picked up, a small sprite flies from the tile to the inventory

local FLY_DURATION_MS = 300
local FLY_HEIGHT = 40  -- arc height in pixels

local pickups = {}  -- { itemId, startX, startY, endX, endY, progress, widget, event }

function init()
  connect(g_game, { onItemPickup = onItemPickup, onGameEnd = onGameEnd })

end

function terminate()
  cleanup()
  disconnect(g_game, { onItemPickup = onItemPickup, onGameEnd = onGameEnd })
end

function onGameEnd()
  cleanup()
end

function cleanup()
  for i, pickup in pairs(pickups) do
    if pickup.event then
      removeEvent(pickup.event)
    end
    if pickup.widget then
      pickup.widget:destroy()
    end
  end
  pickups = {}
end

-- --- Map coordinate to screen position ---------------------------------

function tileToScreen(tileX, tileY, tileZ)
  local mapPanel = modules.game_interface.getMapPanel()
  if not mapPanel then return nil end

  local cameraPos = mapPanel:getCameraPosition()
  if not cameraPos then return nil end

  -- Isometric projection matching OTClient's transformPositionTo2D
  -- Uses g_sprites.spriteSize() for HD mode compatibility (32px normal, 64px HD)
  local sprSize = g_sprites.spriteSize()
  local halfSpr = sprSize / 2

  local dx = tileX - cameraPos.x
  local dy = tileY - cameraPos.y
  local dz = tileZ - cameraPos.z

  local offsetX = (dx + dy) * sprSize
  local offsetY = (dy - dx) * halfSpr - (dz * sprSize * 3 / 4)

  local rect = mapPanel:getRect()
  if not rect then return nil end

  local screenX = rect.x + (rect.width / 2) + offsetX
  local screenY = rect.y + (rect.height / 2) + offsetY

  return screenX, screenY
end

-- --- Inventory slot screen position ------------------------------------

function getInventorySlotScreen(slot)
  -- Try module path first, fall back to raw global (works across sandbox variants)
  local panel = (modules.game_inventory and modules.game_inventory.inventoryPanel) or inventoryPanel
  if not panel then return nil end

  -- Slots are named slot1, slot2, ..., slot10 in the inventory UI
  local slotWidget = panel:getChildById('slot' .. slot)
  if not slotWidget then return nil end

  local rect = slotWidget:getRect()
  if not rect then return nil end

  return rect.x + rect.width / 2, rect.y + rect.height / 2
end

-- --- Easing function (quadratic ease-out) ------------------------------

function easeOutQuad(t)
  return t * (2 - t)
end

-- --- Animation update --------------------------------------------------

function updateFly(pickup)
  if not pickup.widget then return end

  pickup.progress = pickup.progress + 1
  local t = pickup.progress / pickup.totalFrames
  if t >= 1.0 then
    t = 1.0
  end

  local et = easeOutQuad(t)

  -- Interpolate position
  local x = pickup.startX + (pickup.endX - pickup.startX) * et
  local y = pickup.startY + (pickup.endY - pickup.startY) * et

  -- Add arc height (parabolic curve)
  local arc = math.sin(t * math.pi) * FLY_HEIGHT
  y = y - arc

  -- Scale: start at full size, shrink slightly as it flies
  local scale = 1.0 - (t * 0.3)

  pickup.widget:setPosition({ x = math.floor(x) - 16, y = math.floor(y) - 16 })
  pickup.widget:setSize({ width = math.floor(32 * scale), height = math.floor(32 * scale) })

  if t >= 1.0 then
    -- Animation complete
    if pickup.widget then
      pickup.widget:destroy()
    end
    -- Remove from table
    for i, p in pairs(pickups) do
      if p == pickup then
        pickups[i] = nil
        break
      end
    end
    return
  end

  -- Schedule next frame
  pickup.event = scheduleEvent(function()
    pickup.event = nil
    updateFly(pickup)
  end, 1000 / 60)  -- ~60fps
end

-- --- Main event handler ------------------------------------------------

function onItemPickup(itemId, fromX, fromY, fromZ, toType, toSlot, containerId)


  -- Validate parameters
  if not itemId or itemId == 0 then
    return
  end

  -- Get source (tile) screen position
  local startX, startY = tileToScreen(fromX, fromY, fromZ)
  if not startX or not startY then return end

  -- Get destination screen position
  local endX, endY
  if toType == "inventory" then
    endX, endY = getInventorySlotScreen(toSlot)
  elseif toType == "container" and containerId then
    -- Find the container window by containerId and fly toward its center
    local container = g_game.getContainer(containerId)
    if container and container.window then
      local rect = container.window:getRect()
      if rect then
        endX = rect.x + rect.width / 2
        endY = rect.y + rect.height / 2
      end
    end
    -- Fallback: center of screen if container not found
    if not endX or not endY then
      local mapPanel = modules.game_interface.getMapPanel()
      if mapPanel then
        local rect = mapPanel:getRect()
        if rect then
          endX = rect.x + rect.width / 2
          endY = rect.y + rect.height / 2 + 50
        end
      end
    end
  end

  if not endX or not endY then return end

  -- Create the flying item widget on root
  local root = g_ui.getRootWidget()
  if not root then return end

  local widget = g_ui.createWidget('UIItem', root)
  if not widget then return end

  -- Set the item sprite
  widget:setItemId(itemId)
  widget:setItemCount(1)
  widget:setPosition({ x = math.floor(startX) - 16, y = math.floor(startY) - 16 })
  widget:setSize({ width = 32, height = 32 })
  widget:setVisible(true)
  widget:raise()
  widget:setOpacity(0.9)

  -- Start animation
  local totalFrames = math.floor(FLY_DURATION_MS / (1000 / 60))
  local pickup = {
    itemId = itemId,
    startX = startX,
    startY = startY,
    endX = endX,
    endY = endY,
    progress = 0,
    totalFrames = totalFrames,
    widget = widget,
    event = nil
  }
  table.insert(pickups, pickup)

  -- Start first frame
  updateFly(pickup)
end
