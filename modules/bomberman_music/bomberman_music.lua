-- ============================================================================
-- BOMBERMAN MUSIC (modulo OTClient)
-- ----------------------------------------------------------------------------
-- Musica do evento Bomberman por AREA (estilo shader):
--   * O SERVIDOR envia o opcode 162 ("play" / "stop") conforme o jogador
--     entra/sai da area do evento ({1459,7,7} ate {1604,170,7}).
--   * Enquanto o jogador estiver dentro da area, o tema toca em loop.
--   * Ao sair da area, a musica para (g_sounds.stopAll).
--
-- INSTALACAO:
--   Copie esta PASTA (bomberman_music) para a pasta de modulos do seu client:
--     <client>/modules/bomberman_music/
--   (deve ficar assim: <client>/modules/bomberman_music/bomberman_music.lua
--                      <client>/modules/bomberman_music/bomberman_music.otmod)
--   Depois reinicie o client.
--
-- O arquivo de musica fica em <client>/data/sounds/Bombermanevent/theme.ogg
-- (o client ja tem esse arquivo). LOOP_MS abaixo e a duracao do tema (~2:54);
-- se voce trocar a musica, ajuste LOOP_MS para a nova duracao.
-- ============================================================================

local MUSIC_OPCODE = 162 -- opcode servidor -> client (play/stop)
local MUSIC_PATH = '/data/sounds/Bombermanevent/theme.ogg'
local LOOP_MS = 174000   -- pouco acima da duracao do theme.ogg (~2:54) para nao sobrepor. Ajuste se trocar a musica.
local VOLUME = 1.0       -- 0.0 a 1.0

local playing = false
local loopTimer = nil

local function stopMusic()
  if loopTimer then
    removeEvent(loopTimer)
    loopTimer = nil
  end
  playing = false
  if g_sounds and g_sounds.stopAll then
    g_sounds.stopAll()
  end
end

local function playMusic()
  if not g_sounds then
    return
  end
  if not playing then
    playing = true
    if g_sounds.preload then
      pcall(function() g_sounds.preload(MUSIC_PATH) end)
    end
  end
  if g_sounds.play then
    g_sounds.play(MUSIC_PATH, 0, VOLUME)
  end
  -- loop enquanto o jogador continuar dentro da area
  if loopTimer then
    removeEvent(loopTimer)
  end
  loopTimer = scheduleEvent(playMusic, LOOP_MS)
end

local function onMusicOpcode(protocol, opcode, buffer)
  buffer = buffer or ''
  if buffer == 'play' then
    playMusic()
  elseif buffer == 'stop' then
    stopMusic()
  end
end

function init()
  ProtocolGame.registerExtendedOpcode(MUSIC_OPCODE, onMusicOpcode)
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(MUSIC_OPCODE)
  stopMusic()
end
