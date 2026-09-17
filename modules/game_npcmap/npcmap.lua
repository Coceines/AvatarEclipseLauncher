-- NPC Map: mostra os NPCs do mapa (spawn fixo) no minimapa.
-- Cada NPC vira um icone no local do spawn: disco de fundo + outfit olhando
-- pro sul. Passar o mouse mostra o nome (tooltip).
--
-- Regra de visibilidade: so aparece NPC cujo tile de spawn ja esta
-- DESBLOQUEADO no seu minimapa (a area foi explorada alguma vez). Areas pretas
-- (nunca vistas) nao ganham icone.
--
-- Os dados (nome, posicao absoluta, outfit) vem de npcs.lua, gerado por
-- gen_npcmap.py a partir dos spawns do servidor.

-- Referencia a tabela carregada pelo script npcs.lua (mesmo sandbox do modulo)
if type(NPCMapData) ~= "table" then
  print("[NpcMap] aviso: npcs.lua nao carregado ou vazio")
end

-- Suporte nativo (precisa do client recompilado). Sem ele o modulo continua
-- funcionando mostrando todos os NPCs (comportamento antigo).
local hasExploredApi =
    type(g_minimap) == "table" and type(g_minimap.isTileExplored) == "function"

-- Opcao em Options > Game: "Mark NPCs in minimap" (persistida em g_settings)
local SETTING_KEY = "markNpcsMinimap"
local enabled = true

local minimapWidget = nil
local icons = {}     -- widget -> { x=, y=, z=, visible= } do andar atual
local currentZ = nil
local built = false
local pollEvent = nil

-- Agrupa os NPCs por andar pra so criar os do andar visivel no minimapa
local byFloor = {}
for _, npc in ipairs(NPCMapData or {}) do
  local z = npc.z
  if not byFloor[z] then
    byFloor[z] = {}
  end
  table.insert(byFloor[z], npc)
end

local function countNpcs()
  local n = 0
  for _, list in pairs(byFloor) do
    n = n + #list
  end
  return n
end

local function findMinimapWidget()
  if minimapWidget and not minimapWidget:isDestroyed() then
    return minimapWidget
  end
  minimapWidget = nil
  if rootWidget then
    minimapWidget = rootWidget:recursiveGetChildById("minimap")
  end
  if not minimapWidget then
    local mm = modules.game_minimap
    if mm and mm.minimapWindow and not mm.minimapWindow:isDestroyed() then
      minimapWidget = mm.minimapWindow:recursiveGetChildById("minimap")
    end
  end
  return minimapWidget
end

local function destroyIcons()
  for w in pairs(icons) do
    pcall(function()
      if not w:isDestroyed() then
        w:destroy()
      end
    end)
  end
  icons = {}
end

-- Esconde/mostra cada icone conforme o tile de spawn ja foi explorado.
-- Rodada a cada poll e depois de criar/mudar de andar: quando o jogador
-- explora uma area nova, os icones dela aparecem na hora seguinte.
local function refreshVisibility()
  if not hasExploredApi or next(icons) == nil then
    return
  end
  for w, data in pairs(icons) do
    if not w:isDestroyed() then
      local seen = g_minimap.isTileExplored({ x = data.x, y = data.y, z = data.z })
      if seen ~= data.visible then
        data.visible = seen
        if seen then
          w:show()
        else
          w:hide()
        end
      end
    end
  end
end

-- Cria um icone por NPC do andar dado. Como o layout do minimapa re-ancora
-- os filhos a cada frame, o icone acompanha a camera/zoom sozinho depois do
-- centerInPosition inicial.
local function buildFloor(z)
  destroyIcons()
  currentZ = z

  local mm = findMinimapWidget()
  if not mm or mm:isDestroyed() then
    built = false
    return
  end

  local list = byFloor[z]
  if list then
    for _, npc in ipairs(list) do
      local ok, icon = pcall(function()
        local w = g_ui.createWidget("NpcMapIcon", mm)
        w:setTooltip(npc.name)
        local spr = w:getChildById("npc")
        if spr then
          spr:setOutfit({
            type = npc.looktype or 0,
            head = npc.head or 0,
            body = npc.body or 0,
            legs = npc.legs or 0,
            feet = npc.feet or 0,
            addons = npc.addons or 0,
          })
        end
        mm:centerInPosition(w, { x = npc.x, y = npc.y, z = npc.z })
        return w
      end)
      if ok and icon then
        icons[icon] = {
          x = npc.x,
          y = npc.y,
          z = npc.z,
          visible = not hasExploredApi, -- sem API: comeca visivel
        }
        -- com a API nativa os icones nascem ocultos ate o 1o refresh
        if hasExploredApi then
          icon:hide()
        end
      end
    end
  end
  built = true
  refreshVisibility()
end

local function rebuildForPlayer()
  if not enabled then
    return
  end
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end
  local pos = player:getPosition()
  if not pos then
    return
  end
  if not built or pos.z ~= currentZ then
    buildFloor(pos.z)
  end
end

-- Le a opcao da janela de Options: liga/desliga os icones em tempo real e
-- mantem o checkbox sincronizado com o valor gravado.
local function applySetting()
  local want = g_settings.getBoolean(SETTING_KEY)
  if want ~= enabled then
    enabled = want
    if want then
      if g_game.isOnline() then
        rebuildForPlayer()
      end
    else
      destroyIcons()
      built = false
      currentZ = nil
    end
  end
  local opts = modules.client_options
  if opts and opts.getPanel then
    local panel = opts.getPanel()
    if panel and not panel:isDestroyed() then
      local box = panel:recursiveGetChildById(SETTING_KEY)
      if box and box:isChecked() ~= want then
        box:setChecked(want)
      end
    end
  end
end

-- LocalPlayer muda de andar -> recria os icones do andar novo
local function onPositionChange(creature, newPos, oldPos)
  if built and newPos and newPos.z == currentZ then
    return
  end
  rebuildForPlayer()
end

local function onGameStart()
  rebuildForPlayer()
end

local function onGameEnd()
  destroyIcons()
  built = false
  currentZ = nil
end

local function poll()
  applySetting()
  refreshVisibility()
  pollEvent = scheduleEvent(poll, 800)
end

function init()
  g_ui.importStyle("npcmap")
  g_settings.setDefault(SETTING_KEY, true)
  enabled = g_settings.getBoolean(SETTING_KEY)
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })
  connect(LocalPlayer, {
    onPositionChange = onPositionChange,
  })
  pollEvent = scheduleEvent(poll, 800)
  if g_game.isOnline() then
    rebuildForPlayer()
  end
  print("[NpcMap] carregado com " .. countNpcs() .. " NPCs"
        .. (hasExploredApi and " (filtro: area explorada)" or " (sem filtro)")
        .. (enabled and " (ligado)" or " (desligado)"))
end

function terminate()
  if pollEvent then
    pollEvent:cancel()
    pollEvent = nil
  end
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })
  disconnect(LocalPlayer, {
    onPositionChange = onPositionChange,
  })
  destroyIcons()
end
