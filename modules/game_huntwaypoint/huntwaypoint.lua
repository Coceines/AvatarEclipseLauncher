-- Hunt Waypoint - marca o caminho ate a hunt no chao do jogo e no minimap
-- Dados (lista, localizacoes) vem do servidor via extended opcode.
-- O caminho e renderizado 100% localmente (so quem pediu ve).

local opcode = 169

-- ============ CONSTANTES (ajuste aqui) ============
local effectId = 185        -- efeito criado no object builder (teste 184/185)
local dotSpacing = 3        -- SQM entre bolinhas
local expiryMs = 10 * 60 * 1000 -- bolinhas somem apos 10 min da marcacao
local respawnMs = 450       -- re-spawn do efeito no chao (a animacao some sozinha)
local removeRadius = 1      -- distancia (Chebyshev) p/ bolinha sumir ao passar perto
local spawnRadius = 22      -- raio ao redor do player p/ manter o efeito no chao
local maxPathComplexity = 50000

local PathFindAllowNotSeenTiles = 1
local PathFindIgnoreCreatures = 16
local findPathFlags = PathFindAllowNotSeenTiles + PathFindIgnoreCreatures

local DirectionDelta = {
  [0] = { 0, -1 },  -- North
  [1] = { 1, 0 },   -- East
  [2] = { 0, 1 },   -- South
  [3] = { -1, 0 },  -- West
  [4] = { 1, -1 },  -- NorthEast
  [5] = { 1, 1 },   -- SouthEast
  [6] = { -1, 1 },  -- SouthWest
  [7] = { -1, -1 }, -- NorthWest
}
-- ==================================================

local window = nil
local button = nil
local minimapWidget = nil

local hunts = {}          -- lista vinda do server: {name, looktype, exp, level}
local page = 1
local pageSize = 6

local activePath = nil    -- { huntName, dots = { {pos, widget} }, expiresAt }
local tickEvent = nil

modules.game_huntwaypoint = {}

local function log(...)
  print("[HuntWaypoint]", ...)
end

-- ============ init / terminate ============

function init()
  g_ui.importStyle('huntwaypoint')
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.isOnline() then
    online()
  end
end

function terminate()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(opcode) end)
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
  clearPath()
  if window then
    window:destroy()
    window = nil
  end
  if button then
    button:destroy()
    button = nil
  end
end

function online()
  clearPath()

  local okW, w = pcall(function() return g_ui.createWidget('HuntWaypointWindow', rootWidget) end)
  if okW and w then
    window = w
    window:hide()
  else
    log('erro ao criar janela:', w)
  end

  local okB, b = pcall(function()
    return modules.client_topmenu.addRightGameToggleButton(
      'huntWaypointButton',
      tr('Hunt Waypoint'),
      '/images/topbuttons/huntfinder',
      toggle
    )
  end)
  if okB and b then
    button = b
  end

  pcall(function()
    ProtocolGame.registerExtendedOpcode(opcode, function(protocol, op, buffer)
      receiveData(buffer)
    end)
  end)

  -- pede a lista de hunts ao server
  if g_game.isOnline() and g_game.getProtocolGame() then
    g_game.getProtocolGame():sendExtendedOpcode(opcode, "list")
  end
end

function offline()
  clearPath()
  hunts = {}
  refreshGrid()
  if window then
    window:destroy()
    window = nil
  end
  if button then
    button:destroy()
    button = nil
  end
end

-- ============ janela ============

function toggle()
  if not g_game.isOnline() or not window or not button then
    return
  end
  -- o botao da topbar nao alterna sozinho; o modulo gerencia o estado
  if button:isOn() then
    window:hide()
    button:setOn(false)
  else
    window:show()
    window:raise()
    window:focus()
    button:setOn(true)
    refreshGrid()
  end
end

function modules.game_huntwaypoint.onEscape()
  if window and window:isVisible() then
    window:hide()
    if button then
      button:setOn(false)
    end
  end
end

-- declarada ANTES de prevPage/nextPage: como e `local`, se ficar depois as
-- funcoes nao a enxergam (resolvem pra global nil) e o botao > nao paginava
local function getPageCount()
  return math.max(1, math.ceil(#hunts / pageSize))
end

function modules.game_huntwaypoint.prevPage()
  if page > 1 then
    page = page - 1
    refreshGrid()
  end
end

function modules.game_huntwaypoint.nextPage()
  local pages = getPageCount()
  if page < pages then
    page = page + 1
    refreshGrid()
  end
end

function modules.game_huntwaypoint.onCardClick(cardId)
  if not g_game.isOnline() then
    return
  end
  local index = tonumber((cardId or ''):match('%d+'))
  if not index then
    return
  end
  local slot = (page - 1) * pageSize + index
  local hunt = hunts[slot]
  if not hunt then
    return
  end
  if g_game.getProtocolGame() then
    g_game.getProtocolGame():sendExtendedOpcode(opcode, 'path:' .. hunt.name)
  end
end

-- ============ dados do server ============

function receiveData(buffer)
  if not buffer or buffer == '' then
    return
  end
  local parts = buffer:explode('|')
  local kind = parts[1]
  local payload = parts[2] or ''

  if kind == 'list' then
    hunts = {}
    if payload ~= '' then
      for _, entry in ipairs(payload:explode(';')) do
        local f = entry:explode('~')
        table.insert(hunts, {
          name = f[1] or '?',
          looktype = tonumber(f[2]) or 0,
          exp = f[3] or '',
          level = f[4] or '',
        })
      end
    end
    page = 1
    refreshGrid()
  elseif kind == 'path' then
    local f = payload:explode('~')
    local goal = {
      x = tonumber(f[2]) or 0,
      y = tonumber(f[3]) or 0,
      z = tonumber(f[4]) or 0,
    }
    local dots = computePath(goal)
    if dots then
      startPath(f[1] or '?', dots)
    end
  elseif kind == 'nopath' then
    if window then
      window:setText(tr('Hunt Waypoint - nao encontrada: ') .. payload)
    end
  end
end

local function wireCardClick(card)
  -- cards sao paineis (UIWidget), nao botoes: o clique e manual
  card.onMouseRelease = function(widget, mousePos, mouseButton)
    if mouseButton == MouseLeftButton then
      modules.game_huntwaypoint.onCardClick(widget:getId())
    end
    return true
  end
end

function refreshGrid()
  if not window then
    return
  end
  local emptyLabel = window:recursiveGetChildById('emptyLabel')
  local grid = window:recursiveGetChildById('gridContainer')
  if not emptyLabel or not grid then
    return
  end

  if #hunts == 0 then
    emptyLabel:show()
    grid:hide()
    return
  end
  emptyLabel:hide()
  grid:show()

  local pages = getPageCount()
  if page > pages then
    page = pages
  end

  local base = (page - 1) * pageSize
  for i = 1, pageSize do
    local card = grid:recursiveGetChildById('card' .. i)
    if card then
      if not card.onMouseRelease then
        wireCardClick(card)
      end
      local hunt = hunts[base + i]
      if hunt then
        card:show()
        local sprite = card:recursiveGetChildById('sprite')
        if sprite then
          if hunt.looktype and hunt.looktype > 0 then
            sprite:show()
            pcall(function()
              sprite:setOutfit({
                type = hunt.looktype,
                head = 0, body = 0, legs = 0, feet = 0, addons = 0, auxType = 0,
              })
            end)
          else
            sprite:hide()
          end
        end
        local nameLbl = card:recursiveGetChildById('name')
        if nameLbl then
          nameLbl:setText(hunt.name)
        end
        local expLbl = card:recursiveGetChildById('exp')
        if expLbl then
          if hunt.exp and hunt.exp ~= '' then
            expLbl:show()
            expLbl:setText(tr('EXP ') .. hunt.exp)
          else
            expLbl:hide()
          end
        end
        local levelLbl = card:recursiveGetChildById('level')
        if levelLbl then
          if hunt.level and hunt.level ~= '' then
            levelLbl:show()
            levelLbl:setText(tr('LVL ') .. hunt.level)
          else
            levelLbl:hide()
          end
        end
        -- destaca a hunt com caminho ativo
        local active = activePath and activePath.huntName == hunt.name
        card:setBorderColor(active and '#3f7bff' or '#3a3f4a')
      else
        card:hide()
      end
    end
  end

  local prev = grid:recursiveGetChildById('prevButton')
  local next = grid:recursiveGetChildById('nextButton')
  local pageLabel = grid:recursiveGetChildById('pageLabel')
  if prev then
    prev:setEnabled(page > 1)
  end
  if next then
    next:setEnabled(page < pages)
  end
  if pageLabel then
    pageLabel:setText(page .. '/' .. pages)
  end
end

-- ============ path ============

local function lineFallback(start, goal)
  local dots = {}
  local dx = goal.x - start.x
  local dy = goal.y - start.y
  local steps = math.max(math.abs(dx), math.abs(dy))
  if steps == 0 then
    return { { x = goal.x, y = goal.y, z = goal.z } }
  end
  for i = 1, steps do
    if i % dotSpacing == 0 then
      local t = i / steps
      table.insert(dots, {
        x = math.floor(start.x + dx * t + 0.5),
        y = math.floor(start.y + dy * t + 0.5),
        z = goal.z,
      })
    end
  end
  table.insert(dots, { x = goal.x, y = goal.y, z = goal.z })
  return dots
end

function computePath(goal)
  local player = g_game.getLocalPlayer()
  if not player or not g_game.isOnline() then
    return nil
  end
  local start = player:getPosition()
  if not start then
    return nil
  end

  local dots = {}
  local ok, dirs = pcall(g_map.findPath, start, goal, maxPathComplexity, findPathFlags)
  if ok and dirs and #dirs > 0 then
    local pos = { x = start.x, y = start.y, z = start.z }
    local step = 0
    for _, dir in ipairs(dirs) do
      local delta = DirectionDelta[dir]
      if delta then
        pos.x = pos.x + delta[1]
        pos.y = pos.y + delta[2]
        step = step + 1
        if step % dotSpacing == 0 then
          table.insert(dots, { x = pos.x, y = pos.y, z = pos.z })
        end
      end
    end
  end

  if #dots == 0 then
    dots = lineFallback(start, goal)
    if goal.z ~= start.z then
      -- hunt em outro andar: o findPath nao atravessa andares, entao as
      -- bolinhas ficam no andar do jogador guiando ate o X,Y do destino
      for _, d in ipairs(dots) do
        d.z = start.z
      end
    end
  end

  -- garante bolinha no destino (no andar do jogador se for outro andar)
  local goalZ = (goal.z ~= start.z) and start.z or goal.z
  local last = dots[#dots]
  if not last or last.x ~= goal.x or last.y ~= goal.y or last.z ~= goalZ then
    table.insert(dots, { x = goal.x, y = goal.y, z = goalZ })
  end
  return dots
end

-- ============ render (chao + minimap) ============

local function findMinimapWidget()
  if minimapWidget and not minimapWidget:isDestroyed() then
    return minimapWidget
  end
  minimapWidget = rootWidget:recursiveGetChildById('minimap')
  return minimapWidget
end

local function spawnFloorDot(d)
  local tile = g_map.getTile(d)
  if not tile then
    return
  end
  local fx = tile:getEffects()
  -- spawna mesmo com efeito ainda ativo (a bolinha nasce antes da anterior
  -- terminar -> sem piscar). Cap de 3 copias evita acumulo se a animacao
  -- for muito longa.
  if fx and #fx >= 3 then
    return
  end
  local ok, e = pcall(function() return Effect.create() end)
  if not ok or not e then
    return
  end
  pcall(function()
    e:setId(effectId)
    g_map.addThing(e, d)
  end)
end

function startPath(huntName, dots)
  clearPath()

  local mm = findMinimapWidget()
  activePath = {
    huntName = huntName,
    dots = {},
    expiresAt = g_clock.millis() + expiryMs,
  }

  for _, d in ipairs(dots) do
    local dot = { pos = d, widget = nil }
    if mm then
      local okW, w = pcall(function() return g_ui.createWidget('HuntWaypointDot', mm) end)
      if okW and w then
        pcall(function() mm:centerInPosition(w, d) end)
        dot.widget = w
      end
    end
    table.insert(activePath.dots, dot)
  end

  log('caminho ativo: ', huntName, '(', #activePath.dots, 'bolinhas,', expiryMs / 60000, 'min)')
  refreshGrid()
  tickEvent = scheduleEvent(tick, respawnMs)
end

function clearPath()
  if tickEvent then
    tickEvent:cancel()
    tickEvent = nil
  end
  if activePath then
    for _, dot in ipairs(activePath.dots) do
      if dot.widget then
        pcall(function() dot.widget:destroy() end)
      end
    end
    activePath = nil
  end
end

function tick()
  tickEvent = nil
  if not activePath then
    return
  end

  local player = g_game.getLocalPlayer()
  if not player or not g_game.isOnline() then
    clearPath()
    refreshGrid()
    return
  end

  local ppos = player:getPosition()
  if not ppos then
    return
  end

  -- expirou os 10 minutos?
  if g_clock.millis() >= activePath.expiresAt then
    clearPath()
    refreshGrid()
    return
  end

  local mm = findMinimapWidget()
  local cameraZ = (mm and mm:getCameraPosition()) and mm:getCameraPosition().z or ppos.z

  -- percorre de tras pra frente (remocoes nao quebram o indice)
  for i = #activePath.dots, 1, -1 do
    local dot = activePath.dots[i]
    local d = dot.pos
    local dist = math.max(math.abs(d.x - ppos.x), math.abs(d.y - ppos.y))
    local sameZ = (d.z == ppos.z)

    -- chegou perto -> bolinha some
    if not sameZ or dist <= removeRadius then
      if dot.widget then
        pcall(function() dot.widget:destroy() end)
      end
      table.remove(activePath.dots, i)
    else
      -- visibilidade no minimap (so o andar da camera)
      if dot.widget then
        dot.widget:setVisible(d.z == cameraZ)
      end
      -- efeito no chao (so perto do player e no mesmo andar)
      if sameZ and dist <= spawnRadius then
        spawnFloorDot(d)
      end
    end
  end

  if #activePath.dots == 0 then
    clearPath()
    refreshGrid()
    return
  end

  tickEvent = scheduleEvent(tick, respawnMs)
end
