--[[
  game_dailyhunt -- janela da task diaria

  Quem manda e' o servidor (data/lib/dailyHunt.lua): metas, contagem de kills,
  re-roll e a ENTREGA DO PREMIO. O client so' desenha e pede - nenhum item e'
  criado aqui (item 18340 / Moeda Avatar sai do servidor).

  Protocolo (opcode 166, string pipe-delimited)

    day:<id>|monsters:m1,m2,..|kills:k1,k2,..|required:r1,r2,..
    |outfits:t_h_b_l_f_a_aux;..|claimed:0,1,0,0,1|reroll:0|1|bosses:N

  Buffer enviado pelo client

    "request"      -> pede a lista
    "reroll"       -> usa o re-roll do dia (troca ate 3 criaturas)
    "claim:<slot>" -> resgata o premio da task CONCLUIDA do slot 1..5
                      (o slot vem do clique na linha da janela)

  Se o servidor nao responder a lista, os botoes ficam so' informativos.
]]

local opcode = 166

local window = nil
local button = nil
local sideButton = nil

local monsters, kills, required, outfits, claimed = {}, {}, {}, {}, {}
local rerollAvailable = 1
local bossesReady = 0
local selectedSlot = nil
local rows = {}
-- ultimo pacote do servidor: serve para repintar a janela quando ela e'
-- recriada (troca de personagem) ou se o pacote chegar antes do onGameStart
local lastBuffer = nil

local COLOR_DONE = '#33cc33'
local COLOR_NORMAL = '#c8c8c8'
local COLOR_BOSS_READY = '#ff3b3b'
local COLOR_LOCKED = '#ff9b3b'
local COLOR_CLAIMED = '#7f8f7f'

-- botoes laterais esquerdos, de baixo para cima (o do chat fica embaixo)
local SIDE_BUTTON_ID = 'dailyHuntSideButton'
local SIDE_BUTTONS = {
  'inventorySideButton',
  'mapSideButton',
  'helperSideButton',
  SIDE_BUTTON_ID,
}

-- NAO recriar a tabela do modulo aqui (nada de `modules.game_dailyhunt = {}`).
-- O modulo e' sandboxed e o OTClient roda os scripts com o ambiente da thread
-- apontando para o proprio package.loaded['game_dailyhunt']
-- (Module::setGlobalEnvironment): ou seja, `modules.game_dailyhunt` JA e' a
-- tabela onde caem as funcoes globais deste arquivo (init, online, toggle...).
-- Substituir isso por um {} novo, sem metatable, esconde essas funcoes de quem
-- chama pelo nome do modulo - o @onClick do botao lateral
-- (dailyhunt_button.otui) dava "attempt to call field 'toggle' (a nil value)".
-- Quem for chamado de .otui continua podendo ser exportado na mao
-- (ver `modules.game_dailyhunt.toggle = toggle` depois de toggle()).

-- ===========================================================================
--  ESTADO DA LISTA
-- ===========================================================================
local function isSlotComplete(slot)
  local need = required[slot]
  if not need or need <= 0 then
    return false
  end
  return (kills[slot] or 0) >= need
end

local function isSlotClaimed(slot)
  return claimed[slot] == 1
end

-- ===========================================================================
--  BOTOES LATERAIS (inventario / mapa / helper / daily task)
-- ===========================================================================
-- Reempilha todos os botoes laterais que existirem. addAnchor troca a ancora
-- da mesma borda, entao rodar isso de novo e' seguro e garante a ordem certa
-- independente da ordem em que os modulos foram carregados.
local function restackSideButtons()
  local rootPanel = modules.game_interface and modules.game_interface.getRootPanel()
  if not rootPanel then
    return
  end

  local below = nil
  for _, id in ipairs(SIDE_BUTTONS) do
    local widget = rootPanel:getChildById(id)
    if widget then
      if below then
        widget:addAnchor(AnchorBottom, below:getId(), AnchorTop)
      else
        widget:addAnchor(AnchorBottom, 'consolePanel', AnchorTop)
      end
      widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      widget:setMarginBottom(6)
      widget:setMarginLeft(0)
      below = widget
    end
  end
end

local function createSideButton()
  if not modules.game_interface then
    return
  end

  local rootPanel = modules.game_interface.getRootPanel()
  if not rootPanel then
    return
  end

  if not sideButton then
    pcall(function() g_ui.importStyle('dailyhunt_button') end)
    local ok, created = pcall(function() return g_ui.createWidget('DailyHuntSideButton', rootPanel) end)
    if not ok or not created then
      return
    end
    sideButton = created
    sideButton:hide()
  end

  restackSideButtons()

  if g_game.isOnline() then
    sideButton:show()
    sideButton:raise()
  end
end

-- ===========================================================================
--  CICLO DE VIDA
-- ===========================================================================
function init()
  g_ui.importStyle('dailyhunt')
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  addEvent(createSideButton)
  if g_game.getLocalPlayer() then
    online()
  end
end

function terminate()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(opcode) end)
  offline()
  if sideButton then
    sideButton:destroy()
    sideButton = nil
  end
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
end

function online()
  local okW, created = pcall(function() return g_ui.createWidget('DailyHuntWindow', rootWidget) end)
  if okW and created then
    window = created
    window:hide()
  end

  local okB, created = pcall(function()
    return modules.client_topmenu.addRightGameToggleButton(
      'dailyHuntButton',
      tr('Daily Hunt'),
      '/images/topbuttons/dailyhunt',
      toggle,
      true
    )
  end)
  if okB and created then
    button = created
  end

  addEvent(createSideButton)

  pcall(function()
    ProtocolGame.registerExtendedOpcode(opcode, function(protocol, op, buffer)
      receiveData(buffer)
    end)
  end)

  if lastBuffer then
    receiveData(lastBuffer)
  end
end

function offline()
  monsters, kills, required, outfits, claimed = {}, {}, {}, {}, {}
  rerollAvailable = 1
  bossesReady = 0
  selectedSlot = nil
  rows = {}
  lastBuffer = nil

  if window then
    window:destroy()
    window = nil
  end
  if button then
    button:destroy()
    button = nil
  end
  if sideButton then
    sideButton:hide()
  end
end

function modules.game_dailyhunt.onEscape()
  if window and window:isVisible() then
    window:hide()
    if button then
      button:setOn(false)
    end
  end
end

function toggle()
  if not g_game.getLocalPlayer() or not window or not button then
    return
  end
  if button:isOn() then
    window:hide()
    button:setOn(false)
  else
    -- a pilha de botoes laterais pode ter mudado (helper/mapa entrando ou
    -- saindo): reempilha antes de abrir
    restackSideButtons()
    if sideButton then
      sideButton:show()
      sideButton:raise()
    end
    window:show()
    window:raise()
    window:focus()
    button:setOn(true)
    pcall(function()
      if g_game.getProtocolGame() then
        g_game.getProtocolGame():sendExtendedOpcode(opcode, "request")
      else
        g_game.talk("!dailyhunt")
      end
    end)
  end
end

-- API publica chamada de fora (o .otui roda no ambiente global, onde `modules`
-- e' package.loaded: funcoes globais deste arquivo nao aparecem aqui sozinhas).
modules.game_dailyhunt.toggle = toggle

-- ===========================================================================
--  PEDIDOS AO SERVIDOR
-- ===========================================================================
local function sendToServer(opcodeBuffer, talkCommand)
  pcall(function()
    local protocol = g_game.getProtocolGame()
    if protocol then
      protocol:sendExtendedOpcode(opcode, opcodeBuffer)
    else
      g_game.talk("!dailyhunt " .. talkCommand)
    end
  end)
end

function modules.game_dailyhunt.onSelectSlot(slot)
  slot = tonumber(slot)
  if not slot or not monsters[slot] then
    return
  end
  -- a selecao fica fixa ate' clicar em outra linha (nada de desmarcar sem
  -- querer no meio do clique duplo)
  if selectedSlot == slot then
    return
  end
  selectedSlot = slot
  modules.game_dailyhunt.refresh()
end

function modules.game_dailyhunt.onClaimReward()
  if not g_game.getLocalPlayer() or not window then
    return
  end
  local slot = selectedSlot
  if not slot or not isSlotComplete(slot) or isSlotClaimed(slot) then
    return
  end
  -- o servidor valida a task, marca o resgate do dia e entrega o item
  sendToServer("claim:" .. slot, "claim " .. slot)
end

function modules.game_dailyhunt.onReroll()
  if not g_game.getLocalPlayer() or not window then
    return
  end
  -- sem trava no client: quem decide se o re-roll ainda esta disponivel e'
  -- o servidor (e ele responde com a lista nova ou com o aviso do dia)
  sendToServer("reroll", "reroll")
end

-- ===========================================================================
--  DESENHO
-- ===========================================================================
local function parseList(value, separator, convert)
  local out = {}
  if not value or value == '' then
    return out
  end
  local parts = value:explode(separator)
  for i, part in ipairs(parts) do
    out[i] = convert and convert(part) or part
  end
  return out
end

local function refreshFooter()
  if not window then
    return
  end

  local status = window:recursiveGetChildById('bossStatus')
  if status then
    if bossesReady > 0 then
      status:setText(tr('Boss ALPHA disponivel hoje: %d - pise no portal da area para invocar.', bossesReady))
      status:setColor(COLOR_BOSS_READY)
    else
      status:setText(tr('Complete uma task para liberar o boss ALPHA dela.'))
      status:setColor(COLOR_NORMAL)
    end
  end

  local selectedLabel = window:recursiveGetChildById('selectedLabel')
  local claimBtn = window:recursiveGetChildById('claimButton')

  local slot = selectedSlot
  local name = slot and monsters[slot] or nil
  local done = slot and isSlotComplete(slot) or false
  local alreadyClaimed = slot and isSlotClaimed(slot) or false

  if selectedLabel then
    if not slot then
      selectedLabel:setText(tr('Clique na task concluida para selecionar.'))
    elseif alreadyClaimed then
      selectedLabel:setText(tr('Selecionada: %s - premio ja resgatado hoje.', name))
    elseif done then
      selectedLabel:setText(tr('Selecionada: %s - concluida!', name))
    else
      selectedLabel:setText(tr('Selecionada: %s - ainda nao concluida.', name))
    end
  end

  if claimBtn then
    if not slot then
      claimBtn:setText(tr('Resgatar'))
      claimBtn:setEnabled(false)
      claimBtn:setOpacity(0.4)
    elseif alreadyClaimed then
      claimBtn:setText(tr('Ja resgatado hoje'))
      claimBtn:setEnabled(false)
      claimBtn:setOpacity(0.4)
    elseif done then
      claimBtn:setText(tr('Resgatar'))
      claimBtn:setEnabled(true)
      claimBtn:setOpacity(1.0)
    else
      claimBtn:setText(tr('Resgatar'))
      claimBtn:setEnabled(false)
      claimBtn:setOpacity(0.4)
    end
  end

  local rerollBtn = window:recursiveGetChildById('rerollButton')
  if rerollBtn then
    if rerollAvailable == 1 then
      rerollBtn:setText(tr('Re-roll (1x/dia)'))
      rerollBtn:setEnabled(true)
      rerollBtn:setOpacity(1.0)
    else
      rerollBtn:setText(tr('Re-roll usado hoje'))
      rerollBtn:setEnabled(false)
      rerollBtn:setOpacity(0.4)
    end
  end
end

local function refreshRow(slot, row)
  local name = monsters[slot] or 'Unknown'
  local count = kills[slot] or 0
  local need = required[slot] or 0
  local done = isSlotComplete(slot)
  local alreadyClaimed = isSlotClaimed(slot)

  local creature = row:recursiveGetChildById('creatureIcon')
  local outfit = outfits[slot]
  if creature and outfit and outfit.type and outfit.type > 0 then
    pcall(function() creature:setOutfit(outfit) end)
  end

  local nameLabel = row:recursiveGetChildById('monsterName')
  if nameLabel then
    nameLabel:setText(name)
    nameLabel:setColor(done and COLOR_DONE or COLOR_NORMAL)
  end

  local countLabel = row:recursiveGetChildById('killCount')
  if countLabel then
    countLabel:setText(count .. ' / ' .. need)
    countLabel:setColor(done and COLOR_DONE or COLOR_NORMAL)
  end

  local prog = row:recursiveGetChildById('progressBar')
  if prog then
    local percent = need > 0 and math.min((count / need) * 100, 100) or 0
    prog:setPercent(percent)
    if done then
      prog:setBackgroundColor(COLOR_DONE)
    end
  end

  local status = row:recursiveGetChildById('statusLabel')
  if status then
    if alreadyClaimed then
      status:setText(tr('Premio ja resgatado hoje.'))
      status:setColor(COLOR_CLAIMED)
    elseif done then
      status:setText(tr('Concluida - clique para selecionar e resgatar.'))
      status:setColor(COLOR_DONE)
    else
      status:setText(tr('Complete a meta para liberar o boss ALPHA.'))
      status:setColor(COLOR_LOCKED)
    end
  end
end

local function refreshSelection()
  for slot, row in pairs(rows) do
    local bar = row:recursiveGetChildById('selectionBar')
    if bar then
      bar:setVisible(slot == selectedSlot)
    end
    if slot == selectedSlot then
      row:setBackgroundColor('#ffffff22')
    else
      row:setBackgroundColor('#00000000')
    end
  end
end

function modules.game_dailyhunt.refresh()
  if not window then
    return
  end

  local listPanel = window:recursiveGetChildById('monsterList')
  if not listPanel then
    return
  end

  listPanel:destroyChildren()
  rows = {}

  local total = math.max(#monsters, 5)
  for slot = 1, total do
    local ok, row = pcall(function() return g_ui.createWidget('DailyHuntRow', listPanel) end)
    if not ok or not row then
      break
    end

    -- quem recebe o clique e' o botao invisivel que cobre a linha inteira
    -- (rowHit): ele e' o "pressed widget" do release, logo o onClick e' dele.
    -- Sem o rowHit a linha (que e' phantom) so' seria atingida em cheio.
    local index = slot
    local hit = row:recursiveGetChildById('rowHit')
    if hit then
      hit.onClick = function()
        modules.game_dailyhunt.onSelectSlot(index)
      end
    else
      row.onMouseRelease = function()
        modules.game_dailyhunt.onSelectSlot(index)
        return true
      end
    end

    rows[slot] = row
    refreshRow(slot, row)
  end

  refreshSelection()
  refreshFooter()

  local completed, totalTasks = 0, #monsters
  for slot = 1, totalTasks do
    if isSlotComplete(slot) then
      completed = completed + 1
    end
  end
  if totalTasks > 0 then
    window:setText(tr('Daily Hunt - %d/%d concluidas', completed, totalTasks))
  else
    window:setText(tr('Daily Hunt'))
  end
end

function receiveData(buffer)
  if not buffer or buffer == '' then
    return
  end

  lastBuffer = buffer

  if not window then
    return
  end

  local newMonsters, newKills, newRequired, newOutfits, newClaimed = {}, {}, {}, {}, {}

  for _, part in ipairs(buffer:explode('|')) do
    local key, value = part:match('([^:]+):(.+)')
    if key then
      if key == 'monsters' then
        newMonsters = parseList(value, ',')
      elseif key == 'kills' then
        newKills = parseList(value, ',', function(v) return tonumber(v) or 0 end)
      elseif key == 'required' then
        newRequired = parseList(value, ',', function(v) return tonumber(v) or 0 end)
      elseif key == 'claimed' then
        newClaimed = parseList(value, ',', function(v) return tonumber(v) or 0 end)
      elseif key == 'outfits' then
        for i, str in ipairs(parseList(value, ';')) do
          local p = str:explode('_')
          newOutfits[i] = {
            type = tonumber(p[1]) or 0,
            head = tonumber(p[2]) or 0,
            body = tonumber(p[3]) or 0,
            legs = tonumber(p[4]) or 0,
            feet = tonumber(p[5]) or 0,
            addons = tonumber(p[6]) or 0,
            auxType = tonumber(p[7]) or 0,
          }
        end
      elseif key == 'reroll' then
        rerollAvailable = tonumber(value) or 0
      elseif key == 'bosses' then
        bossesReady = tonumber(value) or 0
      end
    end
  end

  monsters = newMonsters
  kills = newKills
  required = newRequired
  outfits = newOutfits
  claimed = newClaimed

  -- se a selecao aponta para um slot que nao existe mais, limpa
  if selectedSlot and not monsters[selectedSlot] then
    selectedSlot = nil
  end

  modules.game_dailyhunt.refresh()
end
