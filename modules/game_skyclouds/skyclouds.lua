-- Sky Clouds Module
-- Realistic animated cloud layer with per-pixel occlusion.
--
-- Shader registration & server opcode handling are done in game_shaders/shaders.lua.
-- This module handles:
--   - Player Z position tracking (above-ground vs underground)
--   - Auto-enable/disable clouds based on Z level
--   - Public API (setEnabled, isEnabled, refresh, isActive)
--   - Settings persistence

local SHADER_NAME = "sky_clouds"
local ENABLED_KEY = "skyCloudsEnabled"
local POLL_INTERVAL_MS = 1000

local cloudsEnabled = true
local wasAboveGround = nil
local moduleLoaded = false
local pollEvent = nil

-- ---------------------------------------------------------------------------
--  Initialization
-- ---------------------------------------------------------------------------

function init()
  -- Restore user preference
  local saved = g_settings.get(ENABLED_KEY)
  if saved ~= nil then
    cloudsEnabled = (saved == true or saved == "true" or saved == "1")
  else
    cloudsEnabled = true
  end

  -- Connect game events
  connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })

  moduleLoaded = true
end

function terminate()
  stopPolling()
  disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  removeShader()
  moduleLoaded = false
end

-- ---------------------------------------------------------------------------
--  Polling (periodic Z check)
-- ---------------------------------------------------------------------------

function startPolling()
  stopPolling()

  local function tick()
    if not moduleLoaded then return end
    checkPlayerZ()
    -- Schedule next tick
    pollEvent = scheduleEvent(tick, POLL_INTERVAL_MS)
  end

  -- First tick
  pollEvent = scheduleEvent(tick, 500)
end

function stopPolling()
  if pollEvent then
    removeEvent(pollEvent)
    pollEvent = nil
  end
end

function checkPlayerZ()
  local player = g_game.getLocalPlayer()
  if not player then
    if wasAboveGround ~= false then
      wasAboveGround = false
      removeShader()
    end
    return
  end

  local pos = player:getPosition()
  if not pos or not pos.z then
    return
  end

  local aboveGround = (pos.z <= 7)

  if aboveGround ~= wasAboveGround then
    wasAboveGround = aboveGround
    if aboveGround and cloudsEnabled then
      applyShader()
    else
      removeShader()
    end
  end
end

-- ---------------------------------------------------------------------------
--  Event handlers
-- ---------------------------------------------------------------------------

function onGameStart()
  -- Start periodic Z checking
  addEvent(startPolling)
end

function onGameEnd()
  stopPolling()
  wasAboveGround = nil
  removeShader()
end

-- ---------------------------------------------------------------------------
--  Shader management
-- ---------------------------------------------------------------------------

function getMapPanel()
  if modules and modules.game_interface and modules.game_interface.getMapPanel then
    return modules.game_interface.getMapPanel()
  end
  return nil
end

function applyShader()
  local mapPanel = getMapPanel()
  if not mapPanel then
    return
  end

  mapPanel:setShader(SHADER_NAME)
end

function removeShader()
  local mapPanel = getMapPanel()
  if not mapPanel then
    return
  end

  if mapPanel:getShader() == SHADER_NAME then
    mapPanel:setShader("")
  end
end

-- ---------------------------------------------------------------------------
--  Public API
-- ---------------------------------------------------------------------------

function setEnabled(enabled)
  cloudsEnabled = enabled
  g_settings.set(ENABLED_KEY, enabled)

  if enabled and wasAboveGround then
    applyShader()
  else
    removeShader()
  end
end

function isEnabled()
  return cloudsEnabled
end

function refresh()
  removeShader()
  if cloudsEnabled and wasAboveGround then
    applyShader()
  end
end

function isActive()
  local panel = getMapPanel()
  return panel ~= nil and panel:getShader() == SHADER_NAME
end

-- For debugging from console: modules.game_skyclouds.forceEnable()
function forceEnable()
  cloudsEnabled = true
  wasAboveGround = true
  g_settings.set(ENABLED_KEY, true)
  applyShader()
end
