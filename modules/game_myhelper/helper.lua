-- =============================================================================
-- game_myhelper - Helper pessoal
--  * Cura com a magia FIXA da classe (Air/Earth/Fire/Water Recover) quando a
--    vida cai abaixo do % definido - com icone igual ao modulo de folds
--  * Pocao de mana quando a mana cai abaixo do % definido
--  * Pocao de vida quando a vida cai abaixo do % definido
--  * Water Heal em aliado (apenas Dobrador de Agua) - o player define o nome
--  * Auto target de criaturas proximas (tecla Espaco de mirar e desativada)
--  * Perfil por personagem salvo em data/helperconfig/characters.json
-- =============================================================================

helperWindow = nil
helperButton = nil
helperSideButton = nil
updateEvent = nil

-- widgets (buscados no init)
statusLabel = nil
profileLabel = nil
powerButton = nil
healEnabled = nil
healIcon = nil
healSpellName = nil
healPercent = nil
hpItemSlot = nil
hpItemBox = nil
hpPotPercent = nil
manaItemSlot = nil
manaItemBox = nil
manaPotPercent = nil
waterTitle = nil
waterRow = nil
waterEnabled = nil
waterAllyEdit = nil
waterHealPercent = nil
autoTargetEnabled = nil
autoTargetDistance = nil

enabled = false
element = 0 -- 1=fire 2=water 3=air 4=earth (0 = ainda nao detectado)
currentCharacter = ''
potionsLoaded = false

-- true enquanto loadProfileIntoUI esta aplicando o perfil salvo: evita que o
-- setChecked dispare o allyActivate() (focus/grabKeyboard) roubando o foco
-- do gameMapPanel no primeiro login
local loadingProfile = false

-- magia de cura fixa por classe (mesma ordem do modulo de folds: 1=fire...)
ELEMENT_FOLDER = { [1] = 'fire', [2] = 'water', [3] = 'air', [4] = 'earth' }
ELEMENT_SPELL = {
  [1] = 'Fire Recover',
  [2] = 'Water Recover',
  [3] = 'Air Recover',
  [4] = 'Earth Recover',
}
-- vocacao do servidor -> elemento (1/5=fire, 2/6=water, 3/7=air, 4/8=earth)
VOCATION_TO_ELEMENT = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 1, [6] = 2, [7] = 3, [8] = 4 }

local CYCLE_MS = 400      -- loop do helper
local ACTION_CD = 2000    -- cooldown entre acoes (ms)
local MIN_MANA_PCT = 10   -- so casta magia se tiver pelo menos 10% de mana

local lastHealTime = 0
local lastHpPotTime = 0
local lastManaPotTime = 0
local lastWaterTime = 0

-- Water Heal e a dobra de indice 4 na lista de aguas (mesmo indice que o
-- servidor usa em "#m#<id>,<segundos>;", enviado a cada cast com sucesso).
local WATER_HEAL_SPELL_ID = 4
-- ate quando (ms) a Water Heal esta em cooldown segundo o aviso do servidor
local waterHealCdUntil = 0

local PZ_STATE = 16384 -- PlayerStates.Pz (protection zone)

-- pocao selecionada por clique (id do item no servidor; 0 = nenhuma)
hpItemId = 0
manaItemId = 0

-- -----------------------------------------------------------------------------
-- arquivo de perfil por personagem
-- -----------------------------------------------------------------------------
local HELPER_CONFIG_DIR = 'data/helperconfig'
local HELPER_CONFIG_FILE = HELPER_CONFIG_DIR .. '/characters.json'

local function configPath()
  local workDir = g_resources.getWorkDir() or ''
  -- remove trailing separador
  workDir = workDir:gsub('[\\/]+$', '')
  return workDir .. '/' .. HELPER_CONFIG_FILE
end

local function loadAllProfiles()
  local ok, content = pcall(g_resources.readFileContents, configPath())
  if ok and content and #content > 0 then
    local dec, data = pcall(json.decode, content)
    if dec and type(data) == 'table' then
      return data
    end
  end
  return {}
end

local function saveAllProfiles(profiles)
  local ok, content = pcall(json.encode, profiles)
  if not ok or not content then return end
  if not g_resources.directoryExists(HELPER_CONFIG_DIR) then
    pcall(g_resources.makeDir, HELPER_CONFIG_DIR)
  end
  pcall(g_resources.writeFileContents, configPath(), content)
end

local function getProfile(name)
  local profiles = loadAllProfiles()
  return profiles[name] or {}
end

local function saveProfile(name, profile)
  local profiles = loadAllProfiles()
  profiles[name] = profile
  saveAllProfiles(profiles)
end

local function currentProfileName()
  local player = g_game.getLocalPlayer()
  if player and player:getName() and #player:getName() > 0 then
    return player:getName()
  end
  local cn = g_game.getCharacterName()
  if cn and #cn > 0 then
    return cn
  end
  return ''
end

function loadProfileIntoUI()
  currentCharacter = currentProfileName()
  if #currentCharacter == 0 then
    if profileLabel then profileLabel:setText(tr('Perfil')) end
    return
  end

  local p = getProfile(currentCharacter)

  -- pocao selecionada. O id usado em todo o helper e o CLIENT id (CID do
  -- DAT) - e o id que o client recebe do servidor (item:getId()) e o que o
  -- servidor espera no useInventoryItem (getItemIdByClientId). Perfis antigos
  -- salvaram o id do servidor (7618 etc.); converte aqui.
  hpItemId = SERVER_TO_CLIENT[tonumber(p.hpItemId)] or tonumber(p.hpItemId) or 0
  manaItemId = SERVER_TO_CLIENT[tonumber(p.manaItemId)] or tonumber(p.manaItemId) or 0
  updateItemBoxes()

  if waterAllyEdit then waterAllyEdit:setText(p.waterAlly or '') end
  loadingProfile = true
  if healEnabled then healEnabled:setChecked(p.healEnabled ~= false) end
  if waterEnabled then waterEnabled:setChecked(p.waterEnabled == true) end
  if autoTargetEnabled then autoTargetEnabled:setChecked(p.autoTargetEnabled == true) end
  loadingProfile = false

  local function applySpin(widget, key, def)
    if not widget then return end
    local v = tonumber(p[key])
    widget:setValue(v or def)
  end
  applySpin(healPercent, 'healPercent', 50)
  applySpin(hpPotPercent, 'hpPotPercent', 30)
  applySpin(manaPotPercent, 'manaPotPercent', 30)
  applySpin(waterHealPercent, 'waterHealPercent', 50)
  applySpin(autoTargetDistance, 'autoDistance', 6)

  if profileLabel then
    profileLabel:setText(tr('Perfil: %s', currentCharacter))
  end
  potionsLoaded = true
end

function saveProfileFromUI()
  if not potionsLoaded or #currentCharacter == 0 then return end
  local profile = {
    hpItemId = hpItemId or 0,
    manaItemId = manaItemId or 0,
    waterAlly = waterAllyEdit and waterAllyEdit:getText() or '',
    -- cuidado com o "or": se o checkbox estiver desmarcado, isChecked() = false
    -- e o 'or true' sobrescreveria para true (bug: nunca salvava desligado)
    healEnabled = (healEnabled and healEnabled:isChecked()) ~= false,
    waterEnabled = waterEnabled and waterEnabled:isChecked() or false,
    autoTargetEnabled = autoTargetEnabled and autoTargetEnabled:isChecked() or false,
    healPercent = healPercent and tostring(healPercent:getValue()) or '50',
    hpPotPercent = hpPotPercent and tostring(hpPotPercent:getValue()) or '30',
    manaPotPercent = manaPotPercent and tostring(manaPotPercent:getValue()) or '30',
    waterHealPercent = waterHealPercent and tostring(waterHealPercent:getValue()) or '50',
    autoDistance = autoTargetDistance and tostring(autoTargetDistance:getValue()) or '6',
  }
  saveProfile(currentCharacter, profile)
end

-- -----------------------------------------------------------------------------
-- settings (fallback antigo, mantido por compatibilidade)
-- -----------------------------------------------------------------------------
function saveSettings()
  saveProfileFromUI()
end

-- -----------------------------------------------------------------------------
-- elemento / classe (dobrador)
-- -----------------------------------------------------------------------------
local function detectElement()
  -- fonte principal: o proprio modulo de folds (infos.vocation, 1-4)
  if infos and infos.vocation and infos.vocation >= 1 and infos.vocation <= 4 then
    return infos.vocation
  end
  -- fallback: vocacao do servidor (se algum dia vier pelo protocolo)
  local player = g_game.getLocalPlayer()
  local voc = player and player:getVocation() or 0
  return VOCATION_TO_ELEMENT[voc] or 0
end

function setElement(el)
  if el < 1 or el > 4 then return end
  element = el

  if healIcon then
    healIcon:setImageSource('/images/folds/' .. ELEMENT_FOLDER[el] .. '/2')
  end
  if healSpellName then
    healSpellName:setText(ELEMENT_SPELL[el])
  end

  -- a secao do aliado so existe para dobrador de agua
  local isWater = (el == 2)
  if waterTitle then waterTitle:setVisible(isWater) end
  if waterRow then waterRow:setVisible(isWater) end
end

function applyElement()
  setElement(detectElement())
end

-- mensagens do modo Look (mode 20) enviadas pelo servidor:
--  #v#<elemento>  -> classe do dobrador (fire/water/air/earth)
--  #m#<id>,<seg>; -> cooldown de uma dobra, enviado a cada cast com sucesso
--                    (respeita buffs de reducao de cooldown do servidor)
function onTextMessage(mode, text)
  if mode == 20 and type(text) == 'string' then
    local _, _, v = text:find('#v#(%d+)')
    if v then
      local el = tonumber(v)
      if el and el >= 1 and el <= 4 then
        setElement(el)
      end
    end

    for id, delay in text:gmatch('#m#(%d+),([%-%d]+)') do
      local cd = tonumber(delay)
      if cd and cd > 0 and tonumber(id) == WATER_HEAL_SPELL_ID then
        waterHealCdUntil = g_clock.millis() + cd * 1000
      end
    end
  end
end

-- -----------------------------------------------------------------------------
-- ciclo principal
-- -----------------------------------------------------------------------------
-- usa a pocao do slot (kind). O id guardado e o CLIENT id (CID do DAT).
-- 1) Se achar o item REAL numa mochila aberta, usa pela posicao real
--    (g_game.use - fluxo onUse de clicar com botao direito -> Usar).
-- 2) Se nao achar (mochila fechada), usa pelo id via useInventoryItem: o
--    servidor trata como hotkey e procura a pocao em QUALQUER mochila
--    (busca profunda, independente de estar aberta ou fechada).
local function usePotion(kind)
  local itemId = (kind == 'hp') and hpItemId or manaItemId
  if not itemId or itemId <= 0 then return false end

  local player = g_game.getLocalPlayer()
  if not player then return false end

  local function tryUse(item)
    if item and item:getId() == itemId then
      g_game.use(item)
      return true
    end
    return false
  end

  -- slots de equipamento/inventario
  for i = 1, 10 do
    if tryUse(player:getInventoryItem(i)) then return true end
  end
  -- mochilas abertas
  for _, container in pairs(g_game.getContainers()) do
    if container then
      for _, item in pairs(container:getItems()) do
        if tryUse(item) then return true end
      end
    end
  end

  -- nao achou em mochila aberta: usa pelo id (hotkey do servidor - acha em
  -- qualquer mochila, aberta ou fechada)
  g_game.useInventoryItem(itemId)
  return true
end

local function findCreatureByName(name)
  name = name:lower():trim()
  if #name == 0 then return nil end
  local player = g_game.getLocalPlayer()
  if not player then return nil end
  local spectators = g_map.getSpectators(player:getPosition(), false)
  for _, c in ipairs(spectators) do
    if c:isPlayer() and not c:isLocalPlayer() and c:getName():lower() == name then
      return c
    end
  end
  return nil
end

local function autoTarget()
  local player = g_game.getLocalPlayer()
  if not player then return end

  local maxDist = autoTargetDistance:getValue()
  local pos = player:getPosition()
  local spectators = g_map.getSpectatorsInRangeEx(pos, false, maxDist, maxDist, maxDist, maxDist)

  local best, bestDist = nil, math.huge
  for _, c in ipairs(spectators) do
    if c ~= player and not c:isLocalPlayer() and c:isMonster()
       and not c:isInvisible() and c:getHealthPercent() > 0 then
      local cpos = c:getPosition()
      if cpos and cpos.z == pos.z then
        local dx, dy = cpos.x - pos.x, cpos.y - pos.y
        local d = dx * dx + dy * dy
        if d < bestDist then
          best, bestDist = c, d
        end
      end
    end
  end

  if best then
    g_game.attack(best)
  end
end

local function cycle()
  updateEvent = scheduleEvent(cycle, CYCLE_MS)

  -- mantem o elemento atualizado mesmo com o helper ligado
  local el = detectElement()
  if el ~= element then applyElement() end

  -- carrega o perfil do personagem assim que o nome estiver disponivel
  if not potionsLoaded then
    local name = currentProfileName()
    if #name > 0 then
      loadProfileIntoUI()
    end
  end

  if not enabled then return end
  if not g_game.isOnline() then return end

  local player = g_game.getLocalPlayer()
  if not player or g_game.isDead() then return end

  local now = g_clock.millis()
  -- Este servidor roda protocolo 860, que NAO envia mana% dos seres
  -- (GameCreaturesMana e feature do 12.x) -> getManaPercent() fica -1 pra
  -- sempre. Calcula dos valores exatos do stats packet (health/maxHealth e
  -- mana/maxMana), que tambem e mais preciso que o percentual arredondado.
  local maxHp = player:getMaxHealth()
  local hpPct = (maxHp and maxHp > 0) and (player:getHealth() / maxHp) * 100 or -1
  local maxMana = player:getMaxMana()
  local manaPct = (maxMana and maxMana > 0) and (player:getMana() / maxMana) * 100 or -1

  -- 1) cura com a magia fixa da classe
  if element >= 1 and element <= 4 and healEnabled:isChecked()
     and hpPct > 0 and hpPct <= healPercent:getValue()
     and now - lastHealTime >= ACTION_CD and manaPct >= MIN_MANA_PCT then
    g_game.talk(ELEMENT_SPELL[element])
    lastHealTime = now
  end

  -- 2) pocao de vida (se um item estiver escolhido)
  if hpItemId and hpItemId > 0 and hpPct > 0 and hpPct <= hpPotPercent:getValue()
     and now - lastHpPotTime >= ACTION_CD then
    if usePotion('hp') then
      lastHpPotTime = now
    end
  end

  -- 3) pocao de mana (se um item estiver escolhido)
  if manaItemId and manaItemId > 0 and manaPct > 0 and manaPct <= manaPotPercent:getValue()
     and now - lastManaPotTime >= ACTION_CD then
    if usePotion('mana') then
      lastManaPotTime = now
    end
  end

  -- 4) water heal no aliado (somente dobrador de agua). Respeita o cooldown
  -- real enviado pelo servidor (#m#4,<seg>;) em vez de ficar tentando spam.
  if element == 2 and waterEnabled:isChecked()
     and now >= waterHealCdUntil and now - lastWaterTime >= ACTION_CD then
    local allyName = waterAllyEdit:getText():trim()
    if #allyName > 0 then
      local ally = findCreatureByName(allyName)
      if ally and ally:getHealthPercent() > 0 and ally:getHealthPercent() <= waterHealPercent:getValue() then
        local proto = g_game.getProtocolGame()
        if proto then
          proto:sendExtendedOpcode(210, allyName)
        end
        g_game.talk('Water Heal')
        lastWaterTime = now
      end
    end
  end

  -- 5) auto target (desliga automatico em protection zone)
  local inPz = bit32.band(player:getStates(), PZ_STATE) ~= 0
  if inPz then
    if autoTargetEnabled:isChecked() then
      autoTargetEnabled:setChecked(false)
    end
  elseif autoTargetEnabled:isChecked() then
    local target = g_game.getAttackingCreature()
    if not target or target:getHealthPercent() <= 0 then
      autoTarget()
    end
  end
end

local function startCycle()
  if not updateEvent then
    updateEvent = scheduleEvent(cycle, CYCLE_MS)
  end
end

local function stopCycle()
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end
end

-- -----------------------------------------------------------------------------
-- status / toggle
-- -----------------------------------------------------------------------------
local function updateStatus()
  if statusLabel then
    if enabled then
      statusLabel:setText(tr('Ativo'))
      statusLabel:setColor('#7fd87f')
    else
      statusLabel:setText(tr('Desativado'))
      statusLabel:setColor('#ff8a8a')
    end
  end
  if powerButton then
    if enabled then
      powerButton:setImageSource('/images/game/helperimg/ON')
    else
      powerButton:setImageSource('/images/game/helperimg/OFF')
    end
  end
end

function onWindowClose()
  if helperButton then helperButton:setOn(enabled) end
end

function start()
  enabled = true
  if helperButton then helperButton:setOn(true) end
  if helperWindow then helperWindow:open() end
  updateStatus()
  startCycle()
end

function stop()
  enabled = false
  allyDeactivate()
  if helperButton then helperButton:setOn(false) end
  if helperWindow then helperWindow:close() end
  updateStatus()
  stopCycle()
end

function toggle()
  if enabled then
    stop()
  else
    start()
  end
end

-- botao ON/OFF dentro da janela: liga/desliga o helper sem fechar a janela
-- (o botao do topo continua abrindo/fechando a janela junto)
function togglePower()
  if enabled then
    enabled = false
    allyDeactivate()
    stopCycle()
  else
    enabled = true
    startCycle()
  end
  if helperButton then helperButton:setOn(enabled) end
  updateStatus()
end

function onGameStart()
  potionsLoaded = false
  loadProfileIntoUI()
  applyElement()
  updateStatus()
  if helperSideButton then
    helperSideButton:show()
    helperSideButton:raise()
  end
end

function onGameEnd()
  stop()
  hidePotionList()
  element = 0
  potionsLoaded = false
  waterHealCdUntil = 0
  currentCharacter = ''
  if healSpellName then healSpellName:setText('') end
  if profileLabel then profileLabel:setText(tr('Perfil')) end
  if helperSideButton then helperSideButton:hide() end
end

-- -----------------------------------------------------------------------------
-- lista de pocoes: botao '+' abre uma janela estilo alquimia com as potions
-- -----------------------------------------------------------------------------
-- As pocoes usam o CLIENT id (CID do DAT): e o id que o servidor envia pro
-- client (item:getId()) e o que o servidor espera de volta no useInventoryItem
-- (ele faz getItemIdByClientId). O OTB do servidor mapeia: 7618->266,
-- 7588->236, 8473->239, 15014->7643, 7620->268, 7589->237, 7590->238.
POTION_LISTS = {
  hp = {
    { id = 266,  name = 'Health Potion' },
    { id = 236,  name = 'Strong Health Potion' },
    { id = 239,  name = 'Great Health Potion' },
    { id = 7643, name = 'Ultimate Health Potion' },
  },
  mana = {
    { id = 268, name = 'Mana Potion' },
    { id = 237, name = 'Strong Mana Potion' },
    { id = 238, name = 'Great Mana Potion' },
  },
}

-- id do servidor -> id do client (para migrar perfis antigos que salvaram o
-- id do servidor). O client nao tem OTB, entao ItemType(id):getClientId()
-- devolve null e o fallback e este mapa / identidade.
SERVER_TO_CLIENT = {
  [7618] = 266,  [7588] = 236,  [8473] = 239, [15014] = 7643,
  [7620] = 268,  [7589] = 237,  [7590] = 238,
}

-- sprite do DAT a partir do id guardado: tenta ItemType(id):getClientId()
-- (se um dia o client tiver OTB) e cai no mapa/conversao de id antigo.
local function resolveClientId(itemId)
  if type(ItemType) == 'function' then
    local ok, itemType = pcall(ItemType, itemId)
    if ok and itemType and not itemType:isNull() then
      local cid = itemType:getClientId()
      if cid and cid > 0 and cid ~= itemId then return cid end
    end
  end
  return SERVER_TO_CLIENT[itemId] or itemId
end

potionListWindow = nil
potionListPanel = nil
potionListKind = nil

-- animacao de "gaveta": a lista fica encostada no module (helper) e desliza
-- vindo do lado direito dele (do canto da tela em direcao a esquerda)
local slideEvt = nil
local SLIDE_STEPS = 8
local SLIDE_MS = 140
local SLIDE_DIST = 250

-- posicao absoluta (na tela) de um widget, somando os offsets dos pais
local function widgetAbsPos(w)
  local x, y = w:getX(), w:getY()
  local p = w:getParent()
  while p do
    x = x + p:getX()
    y = y + p:getY()
    p = p:getParent()
  end
  return x, y
end

local function cancelSlide()
  if slideEvt then
    removeEvent(slideEvt)
    slideEvt = nil
  end
end

function hidePotionList()
  potionListKind = nil
  allyDeactivate()
  cancelSlide()
  if not potionListWindow or potionListWindow:isDestroyed() then return end
  if not potionListWindow:isVisible() then return end

  -- desliza de volta para a ESQUERDA (reverso da abertura) e esconde
  local x0, y0 = potionListWindow:getX(), potionListWindow:getY()
  local i = 0
  local function out()
    i = i + 1
    if potionListWindow and not potionListWindow:isDestroyed() then
      potionListWindow:setPosition({ x = x0 - math.floor(SLIDE_DIST * i / SLIDE_STEPS), y = y0 })
    end
    if i < SLIDE_STEPS then
      slideEvt = scheduleEvent(out, math.floor(SLIDE_MS / SLIDE_STEPS))
    else
      potionListWindow:hide()
    end
  end
  slideEvt = scheduleEvent(out, 1)
end

function openPotionList(kind)
  local list = POTION_LISTS[kind]
  if not list or not potionListWindow or not potionListPanel then return end
  if not helperWindow then return end
  allyDeactivate()
  potionListKind = kind
  potionListPanel:destroyChildren()
  for i = 1, #list do
    local potion = list[i]
    local option = g_ui.createWidget('PotionOption', potionListPanel)
    local icon = option:getChildById('optionIcon')
    icon:setItemId(resolveClientId(potion.id))
    icon:setItemCount(1)
    local name = option:getChildById('optionName')
    name:setText(potion.name)
    option.onMouseRelease = function(widget, mousePos, mouseButton)
      if mouseButton == MouseLeftButton then
        onPotionOptionClick(potion)
      end
    end
  end

  cancelSlide()
  potionListWindow:show()
  potionListWindow:raise()
  potionListWindow:breakAnchors()

  -- gaveta do lado DIREITO do module: posicao final encostada na direita do
  -- helper, topo alinhado; a animacao surge da ESQUERDA e desliza para a
  -- DIREITA ate parar no lugar
  local hx, hy = widgetAbsPos(helperWindow)
  local ww = potionListWindow:getWidth()
  local finalX = hx + helperWindow:getWidth() + 8
  -- nao deixa passar da borda direita da tela
  local root = g_ui.getRootWidget()
  if root then
    finalX = math.min(finalX, root:getWidth() - ww - 6)
  end
  finalX = math.max(0, finalX)
  local finalY = hy
  potionListWindow:setPosition({ x = finalX - SLIDE_DIST, y = finalY })
  local i = 0
  local function inStep()
    i = i + 1
    if potionListWindow and not potionListWindow:isDestroyed() and potionListWindow:isVisible() then
      potionListWindow:setPosition({ x = finalX - SLIDE_DIST + math.floor(SLIDE_DIST * i / SLIDE_STEPS), y = finalY })
    end
    if i < SLIDE_STEPS then
      slideEvt = scheduleEvent(inStep, math.floor(SLIDE_MS / SLIDE_STEPS))
    end
  end
  slideEvt = scheduleEvent(inStep, 1)
end

function onPotionOptionClick(potion)
  local kind = potionListKind
  hidePotionList()
  if kind then
    selectItem(kind, potion.id)
  end
end

-- aplica o item escolhido no slot e avisa para definir a porcentagem
function selectItem(kind, itemId)
  if not itemId or itemId <= 0 then return end
  if kind == 'hp' then
    hpItemId = itemId
    updateItemBoxes()
    saveProfileFromUI()
  elseif kind == 'mana' then
    manaItemId = itemId
    updateItemBoxes()
    saveProfileFromUI()
  end
end

-- atualiza os sprites das caixas conforme o item selecionado
function updateItemBoxes()
  if hpItemBox then
    if hpItemId and hpItemId > 0 then
      hpItemBox:setItemId(resolveClientId(hpItemId))
      hpItemBox:setItemCount(1)
    else
      hpItemBox:setItemId(0)
    end
  end
  if manaItemBox then
    if manaItemId and manaItemId > 0 then
      manaItemBox:setItemId(resolveClientId(manaItemId))
      manaItemBox:setItemCount(1)
    else
      manaItemBox:setItemId(0)
    end
  end
end

-- -----------------------------------------------------------------------------
-- defaults / init / terminate
-- -----------------------------------------------------------------------------

function setDefaults()
  -- valores padrao dos spinboxes (aplicados DEPOIS do estilo, via addEvent)
  local function spct(key, def)
    local v = tonumber(g_settings.get(key))
    return v or def
  end
  addEvent(function()
    healPercent:setMaximum(95)
    healPercent:setMinimum(5)
    healPercent:setStep(5)
    healPercent:setValue(spct('myhelper_healPercent', 50))

    hpPotPercent:setMaximum(95)
    hpPotPercent:setMinimum(5)
    hpPotPercent:setStep(5)
    hpPotPercent:setValue(spct('myhelper_hpPotPercent', 30))

    manaPotPercent:setMaximum(95)
    manaPotPercent:setMinimum(5)
    manaPotPercent:setStep(5)
    manaPotPercent:setValue(spct('myhelper_manaPotPercent', 30))

    autoTargetDistance:setMaximum(12)
    autoTargetDistance:setMinimum(2)
    autoTargetDistance:setStep(1)
    autoTargetDistance:setValue(spct('myhelper_autoDistance', 6))

    waterHealPercent:setMaximum(95)
    waterHealPercent:setMinimum(5)
    waterHealPercent:setStep(5)
    waterHealPercent:setValue(spct('myhelper_waterHealPercent', 50))
  end)
end

-- -----------------------------------------------------------------------------
-- campo do aliado (water heal): captura de teclado na janela
-- -----------------------------------------------------------------------------
allyEditActive = false

local ALLY_MAX_LEN = 29 -- nome de player

function allySetText(t)
  if waterAllyEdit then waterAllyEdit:setText(t or '') end
  saveProfileFromUI()
end

function allyActivate()
  -- so ativa se a janela estiver visivel: nunca roubar o foco do
  -- gameMapPanel com a janela fechada (ex.: load de perfil no login)
  if not helperWindow or not helperWindow:isVisible() then
    allyEditActive = false
    return
  end
  allyEditActive = true
  if waterAllyEdit then waterAllyEdit:focus() end
  if helperWindow then helperWindow:grabKeyboard() end
end

function allyDeactivate()
  allyEditActive = false
  if helperWindow then helperWindow:ungrabKeyboard() end
end

function assignHandlers()
  local spins = { healPercent, hpPotPercent, manaPotPercent, waterHealPercent, autoTargetDistance }
  for i = 1, #spins do
    if spins[i] then
      spins[i].onValueChange = function() saveProfileFromUI() end
    end
  end

  local checks = { healEnabled, autoTargetEnabled }
  for i = 1, #checks do
    if checks[i] then
      checks[i].onCheckChange = function() saveProfileFromUI() end
    end
  end

  -- campo do aliado: captura o teclado NA JANELA (mesmo padrao do hotkeys
  -- manager, que funciona garantido): enquanto o campo esta ativo, as teclas
  -- vao direto pra janela e o texto e escrito no campo. Se o foco normal do
  -- TextEdit funcionar, ele trata primeiro (sem duplicar); se nao, a janela
  -- escreve manualmente.
  if waterAllyEdit then
    waterAllyEdit.onTextChange = function() saveProfileFromUI() end
    waterAllyEdit.onMousePress = function(self, mousePos, mouseButton)
      allyActivate()
      return false
    end
  end

  if waterRow then
    waterRow.onMousePress = function(self, mousePos, mouseButton)
      allyActivate()
      return false
    end
  end

  if helperWindow then
    helperWindow.onKeyText = function(self, keyText)
      if not allyEditActive then return false end
      local t = waterAllyEdit and waterAllyEdit:getText() or ''
      if #t < 29 then
        allySetText(t .. keyText)
      end
      return true
    end

    helperWindow.onKeyPress = function(self, keyCode, keyboardModifiers)
      if not allyEditActive then return false end
      if keyCode == KeyBackspace then
        local t = waterAllyEdit and waterAllyEdit:getText() or ''
        allySetText(t:sub(1, -2))
        return true
      elseif keyCode == KeyEnter or keyCode == KeyEscape then
        allyDeactivate()
        return true
      end
      return false
    end

    local baseFocusChange = helperWindow.onFocusChange
    helperWindow.onFocusChange = function(self, focused)
      if baseFocusChange then baseFocusChange(self, focused) end
      if not focused then
        allyDeactivate()
      end
    end
  end

  -- marcar o checkbox ja ativa o campo para digitar o nome
  if waterEnabled then
    waterEnabled.onCheckChange = function(self)
      saveProfileFromUI()
      -- durante o load do perfil o setChecked() tambem dispara aqui; nao pode
      -- ativar o campo (roubaria o foco do jogo no login)
      if loadingProfile then return end
      if self:isChecked() then
        allyActivate()
      else
        allyDeactivate()
      end
    end
  end
end

-- Botao lateral esquerdo (imagem custom), que fica acima dos botoes da mochila
-- e do mapa. Criado em addEvent porque o game_myhelper carrega antes do
-- game_map_overlay/game_inventory (autoload-priority) e a ancora precisa que
-- eles ja' existam.
local function createSideButton()
  if helperSideButton then return end
  if not modules.game_interface then return end

  local rootPanel = modules.game_interface.getRootPanel()
  if not rootPanel then return end

  pcall(function() g_ui.importStyle('helper_button') end)

  local ok, button = pcall(function() return g_ui.createWidget('HelperSideButton', rootPanel) end)
  if not ok or not button then return end

  helperSideButton = button

  if rootPanel:getChildById('mapSideButton') then
    helperSideButton:addAnchor(AnchorBottom, 'mapSideButton', AnchorTop)
  elseif rootPanel:getChildById('inventorySideButton') then
    helperSideButton:addAnchor(AnchorBottom, 'inventorySideButton', AnchorTop)
  else
    helperSideButton:addAnchor(AnchorBottom, 'consolePanel', AnchorTop)
  end
  helperSideButton:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  helperSideButton:setMarginBottom(6)
  helperSideButton:setMarginLeft(0)
  helperSideButton:hide()

  if g_game.isOnline() then
    helperSideButton:show()
    helperSideButton:raise()
  end
end

function init()
  -- remove o mirar pela tecla Espaco (pedido: auto target assume o papel)
  if gameRootPanel then
    g_keyboard.unbindKeyDown('Space', gameRootPanel)
  end

  local ok, initErr = pcall(function()
    helperWindow = g_ui.loadUI('helper', modules.game_interface.getRightPanel())
    helperWindow:setup()

    statusLabel = helperWindow:recursiveGetChildById('statusLabel')
    profileLabel = helperWindow:recursiveGetChildById('profileLabel')
    powerButton = helperWindow:recursiveGetChildById('powerButton')
    healEnabled = helperWindow:recursiveGetChildById('healEnabled')
    healIcon = helperWindow:recursiveGetChildById('healIcon')
    healSpellName = helperWindow:recursiveGetChildById('healSpellName')
    healPercent = helperWindow:recursiveGetChildById('healPercent')
    hpItemSlot = helperWindow:recursiveGetChildById('hpItemSlot')
    hpItemBox = helperWindow:recursiveGetChildById('hpItemBox')
    hpPotPercent = helperWindow:recursiveGetChildById('hpPotPercent')
    manaItemSlot = helperWindow:recursiveGetChildById('manaItemSlot')
    manaItemBox = helperWindow:recursiveGetChildById('manaItemBox')
    manaPotPercent = helperWindow:recursiveGetChildById('manaPotPercent')
    waterTitle = helperWindow:recursiveGetChildById('waterTitle')
    waterRow = helperWindow:recursiveGetChildById('waterRow')
    waterEnabled = helperWindow:recursiveGetChildById('waterEnabled')
    waterAllyEdit = helperWindow:recursiveGetChildById('waterAllyEdit')
    waterHealPercent = helperWindow:recursiveGetChildById('waterHealPercent')
    autoTargetEnabled = helperWindow:recursiveGetChildById('autoTargetEnabled')
    autoTargetDistance = helperWindow:recursiveGetChildById('autoTargetDistance')
  end)
  if not ok then
    perror('[game_myhelper] falha ao criar a janela, abortando init')
    return
  end

  setDefaults()
  assignHandlers()
  updateItemBoxes()

  -- janela de lista de pocoes (botao '+', estilo alquimia)
  local okList = pcall(function()
    potionListWindow = g_ui.displayUI('helperpotionlist')
    potionListWindow:hide()
    potionListPanel = potionListWindow:getChildById('listPanel')
  end)
  if not okList then
    perror('[game_myhelper] falha ao criar a janela de lista de pocoes')
  end

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onTextMessage = onTextMessage,
  })

  -- botao do topo POR ULTIMO: se falhar, o resto do modulo ja esta pronto
  local okButton = pcall(function()
    helperButton = modules.client_topmenu.addRightGameToggleButton(
      'myHelperButton', tr('Helper'), '/images/topbuttons/Helper', toggle, true)
  end)
  if not okButton then
    perror('[game_myhelper] falha ao criar o botao do topo')
  end

  -- botao lateral por ultimo e adiado: os botoes da mochila/mapa sao criados
  -- por outros modulos que ainda vao carregar
  addEvent(function() createSideButton() end)

  applyElement()
  updateStatus()
  helperWindow:close(true)
end

function terminate()
  stop()
  allyDeactivate()
  saveProfileFromUI()

  if helperButton then helperButton:destroy() end
  if helperSideButton then helperSideButton:destroy() end
  if helperWindow then helperWindow:destroy() end
  if potionListWindow then potionListWindow:destroy() end

  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onTextMessage = onTextMessage,
  })

  helperWindow = nil
  helperButton = nil
  helperSideButton = nil
end
