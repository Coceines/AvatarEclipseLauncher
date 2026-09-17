-- ============================================================================
-- Knockout Log (server side) -- TFS API ANTIGA (0.4-style)
-- ----------------------------------------------------------------------------
-- Mostra na aba "Knockout Log" do client (opcode 250) ate 10 criaturas que
-- participaram da morte de um player. Sem logs no console.
--
-- EVENTOS (nomes separados de proposito):
--   * combat       -> "KnockoutCombat"  (rastreia quem ataca o player)
--   * preparedeath -> "KnockoutLogPrep" (limpa a lista e guarda o level)
--   * death        -> "KnockoutLog"     (monta e envia a mensagem)
--
-- INSTALL (no seu servidor Avatar-Compraado-server):
--   1. knockout.lua em:
--        data/creaturescripts/scripts/knockout.lua
--        data/talkactions/scripts/knockout.lua
--   2. data/creaturescripts/creaturescripts.xml:
--        <event type="combat" name="KnockoutCombat" event="script" value="knockout.lua"/>
--        <event type="preparedeath" name="KnockoutLogPrep" event="script" value="knockout.lua"/>
--        <event type="death" name="KnockoutLog" event="script" value="knockout.lua"/>
--   3. data/creaturescripts/scripts/loginLogout/login.lua:
--        registerCreatureEvent(cid, "KnockoutCombat")
--        registerCreatureEvent(cid, "KnockoutLog")
--        registerCreatureEvent(cid, "KnockoutLogPrep")
--   4. data/talkactions/talkactions.xml (teste):
--        <talkaction words="/testknockout" event="script" value="knockout.lua"/>
--      No jogo:  /testknockout Fulano>100>99>Demon;OutroPlayer
-- ============================================================================

local KNOCKOUT_OPCODE = 250
local MAX_KILLERS = 10

-- storages (o seu servidor aceita chave em string, tipo "lastHit")
local STORAGE_LEVEL = "knockoutOldLevel"
local STORAGE_ATTACKERS = "knockoutAttackers"

local function split(str, sep)
  local parts = {}
  if not str or #str == 0 then return parts end
  for part in string.gmatch(str, '([^' .. sep .. ']+)') do
    table.insert(parts, part)
  end
  return parts
end

local function addUnique(list, value)
  for _, v in ipairs(list) do
    if v == value then return end
  end
  table.insert(list, value)
end

-- rastreia os atacantes do player durante o combate (maximo 10, sem repetir)
function onCombat(cid, target)
  if not isPlayer(target) or not isCreature(cid) then
    return true
  end
  local name = getCreatureName(cid)
  if not name or #name == 0 or name == getCreatureName(target) then
    return true
  end

  local list = getPlayerStorageValue(target, STORAGE_ATTACKERS)
  local names = {}
  if list and type(list) == 'string' and #list > 0 then
    names = split(list, ';')
  end
  local has = false
  for _, n in ipairs(names) do
    if n == name then has = true break end
  end
  if not has and #names < MAX_KILLERS then
    table.insert(names, name)
    setPlayerStorageValue(target, STORAGE_ATTACKERS, table.concat(names, ';'))
  end
  return true
end

-- limpa a lista de atacantes e guarda o level antes da penalidade de morte
function onPrepareDeath(cid, deathList)
  if isPlayer(cid) then
    setPlayerStorageValue(cid, STORAGE_ATTACKERS, '')
    setPlayerStorageValue(cid, STORAGE_LEVEL, getPlayerLevel(cid))
  end
  return true
end

function onDeath(cid, corpse, deathList)
  if not isPlayer(cid) then
    return true
  end

  local oldLevel = getPlayerStorageValue(cid, STORAGE_LEVEL)
  if not oldLevel or oldLevel < 1 then
    oldLevel = getPlayerLevel(cid)
  end
  local newLevel = getPlayerLevel(cid)
  local victimName = getCreatureName(cid)

  local killers = {}

  -- 1) atacantes rastreados em combate (mais completo)
  local tracked = getPlayerStorageValue(cid, STORAGE_ATTACKERS)
  if tracked and type(tracked) == 'string' and #tracked > 0 then
    for _, name in ipairs(split(tracked, ';')) do
      if #killers < MAX_KILLERS then addUnique(killers, name) end
    end
  end

  -- 2) deathList (neste fork e um ARRAY de ids de criaturas)
  if type(deathList) == 'table' then
    for i = 1, #deathList do
      if #killers >= MAX_KILLERS then break end
      local killerId = deathList[i]
      if type(killerId) == 'number' and isCreature(killerId) then
        local name = getCreatureName(killerId)
        if name and #name > 0 and name ~= victimName then addUnique(killers, name) end
      end
    end
  end

  -- 3) fallback: ultimo atacante (o imuneable.lua guarda em "lastHit")
  if #killers == 0 then
    local lastHit = getPlayerStorageValue(cid, 'lastHit')
    if type(lastHit) == 'number' and isCreature(lastHit) then
      local name = getCreatureName(lastHit)
      if name and #name > 0 and name ~= victimName then addUnique(killers, name) end
    end
  end

  -- monta o buffer: victim>oldLevel>newLevel>killer1;killer2;... (max 10)
  local buffer = victimName .. '>' .. oldLevel .. '>' .. newLevel
  local count = math.min(#killers, MAX_KILLERS)
  if count > 0 then
    local names = {}
    for i = 1, count do
      table.insert(names, killers[i])
    end
    buffer = buffer .. '>' .. table.concat(names, ';')
  end

  for _, p in ipairs(getPlayersOnline()) do
    doSendPlayerExtendedOpcode(p, KNOCKOUT_OPCODE, buffer)
  end
  return true
end

-- ============================================================================
-- TESTE: /testknockout <buffer>  (so para verificar o client)
-- ============================================================================
function onSay(cid, words, param, channel)
  if not isPlayer(cid) then return false end

  local buffer = param or ''
  if #buffer == 0 then
    buffer = getCreatureName(cid) .. '>100>99>test killer'
  end

  for _, p in ipairs(getPlayersOnline()) do
    doSendPlayerExtendedOpcode(p, KNOCKOUT_OPCODE, buffer)
  end
  return false
end
