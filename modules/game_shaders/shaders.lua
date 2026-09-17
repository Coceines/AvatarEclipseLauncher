local FADE_MS = 2000
local fadeTimer = nil
local clearFadeTimer -- forward declaration (used by terminate() defined below)
local SPIRITUAL_SHADER = "outfit_spiritual"
local SPIRITUAL_PREFIX = "Spiritual "
local SPIRITUAL_NAME_COLOR = {r = 0x66, g = 0xCC, b = 0xFF, a = 255} -- light blue, like NPC names
local appliedSpiritual = {}
local applyingSpiritual = false

--[[
  Shaders aplicados pelo PREFIXO do nome da criatura.
  O servidor so' precisa dar o nome certo: o client cuida do visual.
    "Spiritual X" -> outfit espiritual (soul/ghost)
    "ALPHA X"     -> outline VERMELHO PULSANTE (bosses do sistema ALPHA)
  O shader outfit_outlinered recebe u_Time do PaintShaderProgram e usa
  alpha = 0.4 + abs(0.4 - mod(u_Time, 0.8)), ou seja, pulsa sozinho.
  Guardamos a regra tambem para impedir que jogadores "falsifiquem" o nome:
  apenas monstros (isMonster) recebem o efeito.
]]--
local PREFIX_SHADERS = {
  { prefix = SPIRITUAL_PREFIX, shader = SPIRITUAL_SHADER, color = SPIRITUAL_NAME_COLOR },
  { prefix = "ALPHA ", shader = "outfit_outlinered", color = {r = 0xFF, g = 0x3B, b = 0x3B, a = 255} },
}
local appliedPrefix = {}

function init()
  g_shaders.createShader("map_default", "/shaders/map_default_vertex", "/shaders/map_default_fragment")

  g_shaders.createShader("map_rainbow", "/shaders/map_rainbow_vertex", "/shaders/map_rainbow_fragment")
  g_shaders.addTexture("map_rainbow", "/images/shaders/rainbow.png")

  g_shaders.createShader("map_cloudy", "/shaders/map_cloudy_vertex", "/shaders/map_cloudy_fragment")
  g_shaders.createShader("background_particles", "/shaders/map_default_vertex", "/shaders/background_particles_fragment")

  -- Brilho bem suave nas bordas da arte do login (logo.png, a imagem da janela
  -- enterGame). O shader desenha a propria arte e soma luz nas bordas dela, por
  -- isso e' aplicado direto na janela: veja image-shader em
  -- client_entergame/entergame.otui (EnterGameWindow).
  g_shaders.createShader("entergame_glow", "/shaders/map_default_vertex", "/shaders/entergame_glow_fragment")

  -- Sky Clouds: procedural animated clouds with per-pixel occlusion
  g_shaders.createShader("sky_clouds", "/shaders/sky_clouds_vertex", "/shaders/sky_clouds_fragment")

  createFadeShaders()
  createOutfitShaders()
  createTierShaders()
  createTooltipTierShaders()
  g_shaders.createShader("spellbar_bg", "/shaders/map_default_vertex", "/shaders/spellbar_bg")
  for i = 1, 4 do
    g_shaders.createShader("spellbar_bg_" .. i, "/shaders/map_default_vertex", "/shaders/spellbar_bg_" .. i)
  end

  g_shaders.createShader("healthbar_bg", "/shaders/map_default_vertex", "/shaders/healthbar_bg")
  for i = 1, 4 do
    g_shaders.createShader("healthbar_bg_" .. i, "/shaders/map_default_vertex", "/shaders/healthbar_bg_" .. i)
  end

  g_shaders.createShader("talent_border_glow", "/shaders/map_default_vertex", "/shaders/talent_border_glow")

  ProtocolGame.registerExtendedOpcode(ExtendedIds.MapShader, onMapShader)
  ProtocolGame.registerExtendedOpcode(111, onTierOpcode)
  connect(g_game, { onGameEnd = onGameEndClearShader })
  hookUIItemForTier()
  g_things.clearItemShaders()
  connect(Creature, {
    onAppear = onCreatureAppearSpiritual,
    onDisappear = onCreatureDisappearSpiritual,
    onOutfitChange = onCreatureOutfitSpiritual
  })
end

function terminate()
  clearFadeTimer()
  ProtocolGame.unregisterExtendedOpcode(ExtendedIds.MapShader)
  ProtocolGame.unregisterExtendedOpcode(111)
  disconnect(g_game, { onGameEnd = onGameEndClearShader })
  unhookUIItemForTier()
  disconnect(Creature, {
    onAppear = onCreatureAppearSpiritual,
    onDisappear = onCreatureDisappearSpiritual,
    onOutfitChange = onCreatureOutfitSpiritual
  })
  appliedSpiritual = {}
  appliedPrefix = {}
end

function createFadeShaders()
  -- Recreating resets u_Time (link sets m_startTime).
  g_shaders.createShader("map_fade_out", "/shaders/map_default_vertex", "/shaders/map_fade_out_fragment")
  g_shaders.createShader("map_fade_in", "/shaders/map_default_vertex", "/shaders/map_fade_in_fragment")
  g_shaders.createShader("map_cloudy_fade_out", "/shaders/map_cloudy_vertex", "/shaders/map_cloudy_fade_out_fragment")
end

dofile 'outfit_shaders'

function createOutfitShaders()
  if OUTFIT_SHADERS then
    for _, s in ipairs(OUTFIT_SHADERS) do
      g_shaders.createOutfitShader(s.name, s.vert, s.frag)
    end
  else
    g_shaders.createOutfitShader(SPIRITUAL_SHADER, "/shaders/outfit_spiritual_vertex", "/shaders/outfit_spiritual_fragment")
  end
end

-- Tier outline shaders: registered globally so Item::draw() can use them per-instance
function createTierShaders()
  for i = 1, 10 do
    g_shaders.createShader("item_tier_" .. i, "/shaders/item_tier_vertex", "/shaders/item_tier_" .. i)
  end
end

-- Tooltip panel shaders: glowing surface effect for tooltip windows per tier
function createTooltipTierShaders()
  for i = 1, 10 do
    g_shaders.createShader("tooltip_tier_" .. i, "/shaders/map_default_vertex", "/shaders/tooltip_tier_" .. i)
  end
end

function onTierOpcode(protocol, opcode, buffer)
  -- Tier shaders are handled per-item instance (Item:getTier() / m_tier).
  -- Calling g_things.setItemShader(clientId, ...) applies the shader to ALL items of that ID globally,
  -- which causes items without tier (such as in NPC shops) to incorrectly show the tier shader.
  g_things.clearItemShaders()
end

function hookUIItemForTier()
  -- No longer needed: tier rendering is handled per-instance in Item::draw() in C++
end

function unhookUIItemForTier()
end
local function isSkyCloudsActive()
  if modules.game_skyclouds and modules.game_skyclouds.shouldApply and modules.game_skyclouds.shouldApply() then
    return true
  end
  return false
end

local function setMapShader(name)
  local mapPanel = modules.game_interface and modules.game_interface.getMapPanel and modules.game_interface.getMapPanel()
  if not mapPanel then
    return
  end
  if not name or name == "" or name == "off" or name == "none" or name == "map_default" then
    -- When clearing, re-apply sky_clouds if it is active
    if isSkyCloudsActive() then
      mapPanel:setShader("sky_clouds")
    else
      mapPanel:setShader("")
    end
  else
    mapPanel:setShader(name)
  end
end

function clearFadeTimer()
  if fadeTimer then
    removeEvent(fadeTimer)
    fadeTimer = nil
  end
end

local function notifyServer(buffer)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(ExtendedIds.MapShader, buffer)
  end
end

-- createShader is async on the graphics thread. Defer apply so we don't use a stale u_Time.
local function applyFade(shaderName, doneMsg, notifyAtMs)
  clearFadeTimer()
  setMapShader("")
  createFadeShaders()
  local waitMs = notifyAtMs or FADE_MS
  addEvent(function()
    addEvent(function()
      setMapShader(shaderName)
      fadeTimer = scheduleEvent(function()
        fadeTimer = nil
        notifyServer(doneMsg)
      end, waitMs)
    end)
  end)
end

function onMapShader(protocol, opcode, buffer)
  buffer = buffer or ""
  if buffer == "fade_out" then
    -- Start of flight: fully dark before staging teleport.
    applyFade("map_fade_out", "fade_out_done", FADE_MS)
  elseif buffer == "cloudy_fade_out" then
    -- End of flight: darken while clouds still play; TP as soon as nearly black.
    applyFade("map_cloudy_fade_out", "exit_fade_done", math.floor(FADE_MS * 0.9))
  elseif buffer == "fade_in" then
    applyFade("map_fade_in", "fade_in_done", math.floor(FADE_MS * 0.9))
  elseif buffer == "sky_clouds_on" then
    if modules.game_skyclouds and modules.game_skyclouds.setEnabled then
      modules.game_skyclouds.setEnabled(true)
    else
      g_logger.warning("Sky Clouds module not loaded � ignoring 'sky_clouds_on'.")
    end
  elseif buffer == "sky_clouds_off" then
    if modules.game_skyclouds and modules.game_skyclouds.setEnabled then
      modules.game_skyclouds.setEnabled(false)
    else
      g_logger.warning("Sky Clouds module not loaded � ignoring 'sky_clouds_off'.")
    end
  elseif buffer == "sky_clouds_refresh" then
    if modules.game_skyclouds and modules.game_skyclouds.refresh then
      modules.game_skyclouds.refresh()
    end
  else
    clearFadeTimer()
    setMapShader(buffer)
  end
end


function onGameEndClearShader()
  clearFadeTimer()
  setMapShader("")
  appliedSpiritual = {}
  appliedPrefix = {}
  -- Clear all tier shaders from the global registry on disconnect/logout
  g_things.clearItemShaders()
  -- Also clear local tier table
  if type(g_itemTiers) == "table" then
    for k in pairs(g_itemTiers) do g_itemTiers[k] = nil end
  else
    g_itemTiers = {}
  end
end

-- Procura a regra de prefixo que combina com o nome (case-insensitive)
local function prefixRuleFor(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  for _, rule in ipairs(PREFIX_SHADERS) do
    if name:sub(1, #rule.prefix) == rule.prefix then
      return rule
    end
  end
  local upper = name:upper()
  for _, rule in ipairs(PREFIX_SHADERS) do
    if upper:sub(1, #rule.prefix) == rule.prefix:upper() then
      return rule
    end
  end
  return nil
end

local function isSpiritualName(name)
  return name and name:sub(1, #SPIRITUAL_PREFIX) == SPIRITUAL_PREFIX
end

function applyPrefixOutfitShader(creature)
  if applyingSpiritual or not creature or creature:isLocalPlayer() then
    return
  end
  -- somente monstros: impede que um jogador "clone" o visual do boss
  if not creature:isMonster() then
    return
  end

  local rule = prefixRuleFor(creature:getName())
  if not rule then
    return
  end

  local id = creature:getId()
  if appliedPrefix[id] == rule.prefix then
    return
  end

  local outfit = creature:getOutfit()
  outfit.shader = rule.shader
  appliedPrefix[id] = rule.prefix
  applyingSpiritual = true
  creature:setOutfit(outfit)
  applyingSpiritual = false
  creature:setNameColor(rule.color)
end

-- mantido para compatibilidade (outros modulos/scripts podem chamar)
function applySpiritualOutfitShader(creature)
  applyPrefixOutfitShader(creature)
end

function onCreatureAppearSpiritual(creature)
  applyPrefixOutfitShader(creature)
end

function onCreatureDisappearSpiritual(creature)
  if creature then
    appliedSpiritual[creature:getId()] = nil
    appliedPrefix[creature:getId()] = nil
    creature:resetNameColor()
  end
end

function onCreatureOutfitSpiritual(creature, outfit, oldOutfit)
  if applyingSpiritual or not creature then
    return
  end
  -- External outfit update from server clears shader; mark dirty and re-apply.
  appliedSpiritual[creature:getId()] = nil
  appliedPrefix[creature:getId()] = nil
  applyPrefixOutfitShader(creature)
end
