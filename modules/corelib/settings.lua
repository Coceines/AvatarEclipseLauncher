g_settings = makesingleton(g_configs.getSettings())

-- Autosave das configuracoes.
-- O client so salva o config.otml no encerramento NORMAL (o C++
-- ConfigManager::terminate() chama save()). Se o processo for fechado
-- de forma abrupta (Task Manager, kill, crash, queda de energia) as
-- ultimas opcoes alteradas em memoria seriam perdidas.
--
-- Aqui resolvemos isso com dois mecanismos:
--   1) Debounce: apos qualquer mudanca via g_settings (set/setNode/...)
--      agendamos um save ~2s depois, pegando a ultima alteracao.
--   2) Rede de seguranca: um save periodico a cada 30s cobre mudancas
--      feitas por fora dos metodos monitorados (ex: Config:get com
--      default, ou codigo que mexe direto no objeto).

local AUTOSAVE_DEBOUNCE_MS = 2000
local AUTOSAVE_PERIOD_MS   = 30000

local autosaveEvent = nil

local function doAutosave()
  autosaveEvent = nil
  pcall(function()
    g_settings.save()
  end)
end

local function scheduleAutosave()
  if autosaveEvent then
    removeEvent(autosaveEvent)
    autosaveEvent = nil
  end
  autosaveEvent = scheduleEvent(doAutosave, AUTOSAVE_DEBOUNCE_MS)
end

-- envolve os metodos que alteram as configuracoes para agendar o save
local mutators = { 'set', 'setValue', 'setNode', 'setList', 'mergeNode', 'remove', 'setDefault' }
for _, name in ipairs(mutators) do
  local original = g_settings[name]
  if type(original) == 'function' then
    g_settings[name] = function(...)
      local result = original(...)
      pcall(scheduleAutosave)
      return result
    end
  end
end

-- rede de seguranca: salva periodicamente, mesmo sem mudancas recentes
local function periodicAutosave()
  pcall(function()
    g_settings.save()
  end)
  scheduleEvent(periodicAutosave, AUTOSAVE_PERIOD_MS)
end
scheduleEvent(periodicAutosave, AUTOSAVE_PERIOD_MS)
