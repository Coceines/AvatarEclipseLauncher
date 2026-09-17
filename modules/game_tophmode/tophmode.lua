--[[
  game_tophmode -- "Toph Mode" (menu FUN)

  Efeito de visao de dobrador de terra:
    * o mundo inteiro fica 95% escuro (shader map_toph no mapa);
    * criaturas e players ficam com outline #9bd2fb + glow simples
      (shader outfit_toph; o map_toph reconhece a cor exata e mantem ela acesa);
    * uma onda senoidal circular sai em volta do personagem a cada 5 segundos
      (mesmo shader do mapa, usando u_Time).

  Regras de disponibilidade:
    * so' funciona/aparece para dobrador de TERRA (elemento 4);
    * trocar de personagem (logout/login) desliga o modo.

  Quem liga/desliga e' o menu (modules/client_options, aba FUN). Este modulo
  so' cuida do efeito e informa se a opcao esta' disponivel.

  Os dois shaders conversam pela cor KEY = #9bd2fb:
  nao mude uma sem mudar a outra (map_toph_fragment.frag / outfit_toph_fragment.frag).
]]--

local MAP_SHADER = 'map_toph'
local OUTFIT_SHADER = 'outfit_toph'
local EARTH = 4
local POLL_MS = 2000
TOPH_KEY_COLOR = { r = 0x9b, g = 0xd2, b = 0xfb, a = 255 }

-- 1/5 = fogo, 2/6 = agua, 3/7 = ar, 4/8 = terra (mesma tabela do game_myhelper)
local VOCATION_TO_ELEMENT = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 1, [6] = 2, [7] = 3, [8] = 4 }

local enabled = false
local applying = false
local tracked = {}
local availabilityListener = nil
local lastAvailable = nil
local pollEvent = nil
local lastElementSource = '?'

-- ===========================================================================
--  ELEMENTO DO PERSONAGEM
-- ===========================================================================
local function detectElement()
  -- 1) modulo de folds (mesma fonte que o helper usa)
  local ok, v = pcall(function()
    return modules.game_folds and modules.game_folds.infos and modules.game_folds.infos.vocation
  end)
  if ok and type(v) == 'number' and v >= 1 and v <= 4 then
    lastElementSource = 'folds'
    return v
  end

  -- 2) global do proprio sandbox (alguns clients expoem)
  local ok2, v2 = pcall(function()
    return infos and infos.vocation
  end)
  if ok2 and type(v2) == 'number' and v2 >= 1 and v2 <= 4 then
    lastElementSource = 'infos'
    return v2
  end

  -- 3) helper (game_myhelper)
  local ok3, v3 = pcall(function()
    return modules.game_myhelper and modules.game_myhelper.element
  end)
  if ok3 and type(v3) == 'number' and v3 >= 1 and v3 <= 4 then
    lastElementSource = 'helper'
    return v3
  end

  -- 4) vocacao que vem do protocolo
  local voc = 0
  pcall(function()
    local player = g_game.getLocalPlayer()
    voc = player and player:getVocation() or 0
  end)
  local mapped = VOCATION_TO_ELEMENT[voc]
  if mapped then
    lastElementSource = 'vocation'
    return mapped
  end

  lastElementSource = 'nenhuma'
  return 0
end

function isEarthBender()
  -- offline nao existe personagem: a opcao fica indisponivel (e some do menu)
  if not g_game.isOnline() then
    return false
  end
  return detectElement() == EARTH
end

function getElement()
  return detectElement()
end

function debugInfo()
  return string.format('elemento=%d (terra=%d) fonte=%s', detectElement(), EARTH, lastElementSource)
end

-- ===========================================================================
--  SHADERS
-- ===========================================================================
local function createShaders()
  -- createShader e' assincrono (roda na thread grafica)
  pcall(function()
    g_shaders.createShader(MAP_SHADER, '/shaders/map_default_vertex', '/shaders/map_toph_fragment')
  end)
  pcall(function()
    g_shaders.createOutfitShader(OUTFIT_SHADER, '/shaders/novos/outfit_toph_vertex', '/shaders/novos/outfit_toph_fragment')
  end)
end

local function mapPanel()
  local iface = modules.game_interface
  if iface and iface.getMapPanel then
    return iface.getMapPanel()
  end
  return nil
end

local function applyMapShader()
  local panel = mapPanel()
  if panel then
    panel:setShader(MAP_SHADER)
  end
end

local function clearMapShader()
  local panel = mapPanel()
  if not panel then
    return
  end
  -- o modulo de nuvens usa o mesmo slot de shader do mapa
  local sky = modules.game_skyclouds
  if sky and sky.shouldApply and sky.shouldApply() then
    panel:setShader('sky_clouds')
  else
    panel:setShader('')
  end
end

-- Reaplica depois de dois frames: garante que o shader ja' foi compilado.
local function applyMapShaderDeferred()
  addEvent(function()
    addEvent(function()
      if enabled then
        applyMapShader()
      end
    end)
  end)
end

-- ===========================================================================
--  CRIATURAS / PLAYERS
-- ===========================================================================
local function applyToCreature(creature)
  if not creature then
    return
  end
  local ok = pcall(function()
    local outfit = creature:getOutfit()
    if not outfit then
      return
    end
    if outfit.shader == OUTFIT_SHADER then
      return
    end
    outfit.shader = OUTFIT_SHADER
    applying = true
    creature:setOutfit(outfit)
    applying = false
  end)
  if not ok then
    applying = false
  end
end

local function restoreCreature(creature)
  if not creature then
    return
  end
  pcall(function()
    local outfit = creature:getOutfit()
    if outfit and outfit.shader == OUTFIT_SHADER then
      outfit.shader = ''
      applying = true
      creature:setOutfit(outfit)
      applying = false
    end
  end)
  -- devolve o shader de prefixo (ALPHA / Spiritual) se ele existir
  local sh = modules.game_shaders
  if sh and sh.applyPrefixOutfitShader then
    pcall(sh.applyPrefixOutfitShader, creature)
  end
end

local function onCreatureAppear(creature)
  if not creature then
    return
  end
  tracked[creature:getId()] = creature
  if enabled then
    applyToCreature(creature)
  end
end

local function onCreatureDisappear(creature)
  if creature then
    tracked[creature:getId()] = nil
  end
end

local function onCreatureOutfitChange(creature)
  if applying or not creature then
    return
  end
  -- o servidor mandou uma roupa nova e limpou o shader: aplica de novo
  if enabled then
    applyToCreature(creature)
  end
end

-- ===========================================================================
--  LIGAR / DESLIGAR
-- ===========================================================================
function setEnabled(value)
  value = value and true or false

  if enabled == value then
    if value then
      applyMapShader()   -- reafirma (pode ter sido perdido por um fade)
    end
    return
  end

  enabled = value

  if enabled then
    for _, creature in pairs(tracked) do
      applyToCreature(creature)
    end
    applyMapShaderDeferred()
  else
    for _, creature in pairs(tracked) do
      restoreCreature(creature)
    end
    clearMapShader()
  end
end

function isEnabled()
  return enabled
end

function toggle()
  setEnabled(not enabled)
  return enabled
end

-- ===========================================================================
--  DISPONIBILIDADE (para o menu FUN aparecer/sumir)
-- ===========================================================================
local function notifyAvailability(avail)
  if availabilityListener then
    pcall(availabilityListener, avail)
  end
end

local function checkAvailability()
  local avail = isEarthBender()
  if avail ~= lastAvailable then
    lastAvailable = avail
    notifyAvailability(avail)
  end
end

function setAvailabilityListener(fn)
  availabilityListener = fn
  lastAvailable = nil        -- forca um aviso imediato
  checkAvailability()
end

function refresh()
  checkAvailability()
end

-- ===========================================================================
--  CICLO DE VIDA
-- ===========================================================================
local function poll()
  if g_game.isOnline() then
    if enabled then
      -- se o sistema de fade/teleporte trocou o shader do mapa, reaplica
      local panel = mapPanel()
      local current = nil
      if panel and panel.getShader then
        current = panel:getShader()
      end
      if not current or current == '' or current == 'map_default' then
        applyMapShader()
      end
    end
    checkAvailability()
  end
  pollEvent = scheduleEvent(poll, POLL_MS)
end

local function onGameStart()
  checkAvailability()
end

local function onGameEnd()
  -- trocar de personagem desliga o modo
  setEnabled(false)
  tracked = {}
  lastAvailable = nil
end

function init()
  createShaders()
  connect(Creature, {
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear,
    onOutfitChange = onCreatureOutfitChange
  })
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })
  poll()
end

function terminate()
  if pollEvent then
    removeEvent(pollEvent)
    pollEvent = nil
  end
  setEnabled(false)
  tracked = {}
  disconnect(Creature, {
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear,
    onOutfitChange = onCreatureOutfitChange
  })
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })
end
