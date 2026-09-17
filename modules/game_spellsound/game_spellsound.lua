-- game_spellsound.lua
-- Toca o som de uma magia SOMENTE quando ela ENTRAR EM COOLDOWN.
--
-- Regra (100% do servidor):
--   O servidor envia a mensagem de cooldown das folds
--   (onTextMessage mode 20, formato #m#<id>,<delay> com delay > 0) SOMENTE
--   quando a magia casta de verdade e entra em cooldown.
--
--   -> Magia entrou em cooldown -> SOM.
--   -> Magia NùO castou (cooldown ativo, mana, nùvel, sem alvo) -> nada.
--   -> Clicou mas falhou -> nada.
--
-- O som NùO toca no clique do botùo e NùO usa o eco de fala (mode 44),
-- porque este servidor ecoa o nome mesmo quando o cast falha.
--
-- As tentativas locais ficam num MAPA (nome -> tempo) para casar o id do
-- cooldown recebido com a magia que acabamos de tentar lanùar. Tentativas
-- expiram sozinhas apùs CAST_CONFIRM_MS.

local SOUNDS_DIR = '/data/sounds'
local CAST_CONFIRM_MS = 2500   -- janela p/ o servidor confirmar o cooldown
local FOLD_MSG_MODE = 20       -- mode Look, canal usado pelas folds

local sounds = {}       -- nome normalizado -> caminho do arquivo
local optionsPanel = nil
local optionsVolumeLabel = nil
local optionsVolumeBar = nil

local originalTalk = nil -- g_game.talk original (restaurado no terminate)
local recentCasts = {}   -- nome normalizado -> { name = original, time = ms }
local lastPlayedName = ''
local lastPlayedTime = 0

-- normaliza um nome para comparaùùo (minùsculas, sem espaùos/pontuaùùo/acentos)
local function normalizeName(name)
  if not name then return '' end
  name = name:lower()
  name = name:gsub('[ùùùùùù]', 'a'):gsub('[ùùùù]', 'e'):gsub('[ùùùù]', 'i')
  name = name:gsub('[ùùùùù]', 'o'):gsub('[ùùùù]', 'u'):gsub('[ù]', 'c')
  name = name:gsub('[^%a%d]', '')
  return name
end

-- varre recursivamente data/sounds atrùs de arquivos de ùudio (.ogg)
local function scanSounds(dir)
  if not g_resources.directoryExists(dir) then return end
  local entries = g_resources.listDirectoryFiles(dir, true)
  for _, entry in pairs(entries) do
    if g_resources.directoryExists(entry) then
      scanSounds(entry)
    else
      local lower = entry:lower()
      if lower:match('%.ogg$') then
        local base = lower:match('([^/\\]+)%.ogg$')
        if base and #base > 0 then
          sounds[normalizeName(base)] = entry
        end
      end
    end
  end
end

local function isEnabled()
  return g_settings.getBoolean('spellsoundEnabled')
end

local function getVolume()
  local v = g_settings.getNumber('spellsoundVolume')
  if not v then v = 100 end
  return math.max(0, math.min(100, v))
end

-- toca o som de uma magia pelo nome (com dedup rùpido para nùo tocar 2x)
local function playSpellSound(spellName)
  if not g_sounds or not g_sounds.isAudioEnabled() then return end
  if not isEnabled() then return end

  local path = sounds[normalizeName(spellName)]
  if not path then return end

  local volume = getVolume()
  if volume <= 0 then return end

  -- dedup: mesma magia tocada hù menos de 600ms (evita duplicar)
  local norm = normalizeName(spellName)
  if norm == lastPlayedName and g_clock.millis() - lastPlayedTime < 600 then return end

  lastPlayedName = norm
  lastPlayedTime = g_clock.millis()
  g_sounds.play(path, 0, volume / 100)
end

-- nome da magia a partir do id de cooldown das folds (spellInfos[voc][id])
local function spellNameById(id)
  local folds = modules.game_folds
  if not folds or not folds.spellInfos or not folds.infos then return nil end
  local list = folds.spellInfos[folds.infos.vocation or 1]
  if not list or not list[id] then return nil end
  return list[id].name
end

-- a magia estù em cooldown agora? (consulta o estado que as folds mantùm)
local function isSpellOnCooldown(name)
  local folds = modules.game_folds
  if not folds or not folds.spellInfos or not folds.infos then return false end
  local list = folds.spellInfos[folds.infos.vocation or 1]
  if not list then return false end
  local target = normalizeName(name)
  for id, sp in pairs(list) do
    if sp and sp.name and normalizeName(sp.name) == target then
      local v = (folds.infos.spells or {})[id]
      return not (v == nil or v == 0)
    end
  end
  return false
end

-- parseia mensagens de cooldown das folds: "#m#<id>,<delay>;#m#<id2>,<delay2>"
local function parseFoldCooldowns(text)
  local result = {}
  if not text then return result end
  for part in text:gmatch('[^;]+') do
    for id, delay in part:gmatch('#m#(%d+),([%-%d]+)') do
      result[tonumber(id)] = tonumber(delay)
    end
  end
  return result
end

-- remove tentativas que jù expiraram (mantùm o mapa pequeno)
local function pruneCasts()
  local t = g_clock.millis()
  for norm, entry in pairs(recentCasts) do
    if not entry or not entry.time or t - entry.time > CAST_CONFIRM_MS then
      recentCasts[norm] = nil
    end
  end
end

-- CONFIRMAùùO DE COOLDOWN: o servidor sù envia #m# com delay > 0 quando a
-- magia CASTA e ENTRA EM COOLDOWN. Casou com uma tentativa recente -> som.
local function onTextMessage(mode, text)
  if mode ~= FOLD_MSG_MODE then return end
  if next(recentCasts) == nil then return end

  pruneCasts()
  if next(recentCasts) == nil then return end

  local cds = parseFoldCooldowns(text)
  for id, delay in pairs(cds) do
    -- delay > 0 = magia entrou em cooldown = cast confirmado
    if delay and delay > 0 then
      local name = spellNameById(id)
      if name then
        local norm = normalizeName(name)
        if recentCasts[norm] then
          local entry = recentCasts[norm]
          recentCasts[norm] = nil

          local elapsed = g_clock.millis() - (entry.time or 0)
          if elapsed >= 0 and elapsed <= CAST_CONFIRM_MS then
            playSpellSound(entry.name)
          end
          return
        end
      end
    end
  end
end

-- intercepta o cast local SEM tocar som: sù registra a tentativa quando a
-- magia tem som E nùo estù em cooldown (clicar em cooldown nunca soa).
local function onLocalTalk(text, ...)
  if type(text) == 'string' then
    local norm = normalizeName(text)
    if sounds[norm] and not isSpellOnCooldown(text) then
      recentCasts[norm] = { name = text, time = g_clock.millis() }
    end
    pruneCasts()
  end
  return originalTalk(text, ...)
end

function init()
  g_settings.setDefault('spellsoundEnabled', true)
  g_settings.setDefault('spellsoundVolume', 100)

  scanSounds(SOUNDS_DIR)

  -- prù-carrega os sons pequenos para tocar sem delay
  if g_sounds and g_sounds.preload then
    for _, path in pairs(sounds) do
      pcall(function() g_sounds.preload(path) end)
    end
  end

  -- intercepta o cast local apenas para registrar tentativas pendentes
  if not originalTalk and g_game and g_game.talk then
    originalTalk = g_game.talk
    g_game.talk = onLocalTalk
  end

  connect(g_game, { onTextMessage = onTextMessage })

  -- painel de opcoes (volume / ativar) dentro da janela de Options
  if modules.client_options and modules.client_options.addTab then
    optionsPanel = g_ui.loadUI('spellsound')
    if optionsPanel then
      local volumeBg = optionsPanel:getChildById('spellsoundVolumeBG')
      optionsVolumeLabel = volumeBg and volumeBg:getChildById('spellsoundVolumeLabelBG')
      optionsVolumeBar = volumeBg and volumeBg:getChildById('spellsoundVolume')
      local enabledBox = optionsPanel:getChildById('spellsoundEnabled')
      if enabledBox then
        enabledBox:setChecked(isEnabled())
      end
      if optionsVolumeBar then
        optionsVolumeBar:setValue(getVolume())
        optionsVolumeBar.onValueChange = function(self, value)
          g_settings.set('spellsoundVolume', value)
          if optionsVolumeLabel then
            optionsVolumeLabel:setText(tr('%d', value))
          end
          local active = self:getChildById('activeScroll')
          if active then
            active:setWidth(math.max(0, math.min(200, math.floor((value * 200) / 100))))
          end
        end
      end
      if optionsVolumeLabel then
        optionsVolumeLabel:setText(tr('%d', getVolume()))
      end
      modules.client_options.addTab(tr('Spell Sounds'), optionsPanel, '/modules/client_options/settings/iconpanel')
    end
  end
end

function terminate()
  -- restaura o g_game.talk original (se ainda for o nosso wrapper)
  if originalTalk and g_game and g_game.talk == onLocalTalk then
    g_game.talk = originalTalk
  end
  originalTalk = nil
  for norm in pairs(recentCasts) do recentCasts[norm] = nil end

  disconnect(g_game, { onTextMessage = onTextMessage })
  -- o painel de opùùes ù mantido vivo para nùo quebrar a janela de Options
  -- se o mùdulo for recarregado (o tab do client_options o referencia)
end
