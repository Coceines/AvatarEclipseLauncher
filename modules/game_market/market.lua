-- ============================================================================
--  Market - Client module (game_market)
--  Opcode 230  <->  server data/lib/market_lib.lua
--
--  Protocolo (cliente -> servidor):
--    getOffer>PAGE>CATEGORY>TIER
--    search>TERM>PAGE>CATEGORY>TIER
--    details>OFFER_ID
--    pick>{endereco do item clicado}      -- crosshair do "Adicionar Oferta"
--  Protocolo (servidor -> cliente):
--    create>COUNT>{lua table of offers}   -- ofertas (com o campo tier)
--    details>DESCRIPTION
--    pickok>{item escolhido} / pickerr>MOTIVO
--
--  Fluxo do "Adicionar Oferta" (nada acontece antes do servidor confirmar):
--    1. clica em "Adicionar Oferta"      -> abre o crosshair nativo do client
--    2. clica no item (mochila/depot)    -> pick>ENDERECO
--    3. servidor confirma o item         -> pickok>{itemName,count,tier,clientId}
--    4. janela ABRE com sprite + nome    -> jogador escolhe preco/quantidade
--    5. clica em "Adicionar"             -> pick>ENDERECO de novo (re-confere)
--    6. resposta igual `a do passo 3     -> !offer add, NOME, COUNT, PRICE
-- ============================================================================

Market = {}

mOpcode = 230
numPage = 1
lastSearch = ""
lastFilter = "all"
lastTier = 0

local marketWindow
local marketWindowAdd
local marketButton
local marketList
local btnNext
local btnPrev
local lblIndex
local edtSearch
local cmbFilter
local cmbTier
local searchEvent

-- Estado da selecao de item: nil quando nao esta escolhendo. Enquanto ativo:
--   step = 'search'  -> crosshair aberto, esperando o clique
--   step = 'confirm' -> clicou, esperando o servidor dizer qual item e'
--   step = 'window'  -> item confirmado, janela aberta esperando preco/quantidade
--   step = 'verify'  -> clicou em "Adicionar", conferindo o item de novo antes
--                       de enviar a oferta (a oferta so' sai depois disso)
local pickState = nil

local function short(value, maxLine)
  if string.len(value) >= maxLine then
    return string.sub(value, 1, maxLine-4) .. " ..."
  else
    return value
  end
end

local function round(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function formatPrice(price)
  price = tonumber(price) or 0
  if price >= 1000000000000 then
    return round(price / 1000000000000, 2) .. "T"
  elseif price >= 1000000000 then
    return round(price / 1000000000, 2) .. "B"
  elseif price >= 1000000 then
    return round(price / 1000000, 2) .. "M"
  else
    return round(price / 1000, 2) .. "k"
  end
end

-- Mensagem no canal de status do jogo (nao abre janela modal no meio do clique)
local function feedback(text)
  if modules.game_textmessage and modules.game_textmessage.displayGameMessage then
    modules.game_textmessage.displayGameMessage(text)
  else
    print("[market] " .. text)
  end
end

-- Filter categories. The data values must match the server (market_lib.lua)
-- getItemCategory() return values.
local filterOptions = {
  { 'Todas',      'all'    },
  { 'Armas',      'weapon' },
  { 'Escudos',    'shield' },
  { 'Capacetes',  'helmet' },
  { 'Armaduras',  'armor'  },
  { 'Calças',     'legs'   },
  { 'Botas',      'boots'  },
  { 'Anéis',      'ring'   },
  { 'Amuletos',   'amulet' },
  { 'Variados',   'misc'   }
}

-- Tier filter: 0 = "Todos" (mesmo valor que o servidor entende como sem filtro).
-- O servidor filtra pelo campo `tier` da oferta (market_lib.lua).
local tierOptions = {
  { 'Todos', 0 }
}

local function requestOffers(page, search)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  page = page or numPage
  search = search or lastSearch
  local filter = lastFilter or "all"
  local tier = tonumber(lastTier) or 0
  if search and search ~= "" then
    protocol:sendExtendedOpcode(mOpcode, "search>" .. search .. ">" .. page .. ">" .. filter .. ">" .. tier)
  else
    protocol:sendExtendedOpcode(mOpcode, "getOffer>" .. page .. ">" .. filter .. ">" .. tier)
  end
end

-- ============================================================================
--  Crosshair: escolher o item que vai ser vendido
-- ============================================================================

-- Endereco do item clicado no mesmo formato que o tooltip manda pro servidor.
-- Devolve nil quando o clique nao caiu em cima de um item valido.
local function itemAddress(item, widget)
  if not item then return nil end

  local pos = item:getPosition()
  if pos and pos.x then
    if pos.x < 65000 then
      -- esta' no mapa (chao, bau no chao, corpo...): nunca pode ser vendido
      return { pos = { pos.x, pos.y, pos.z, item:getStackPos() } }
    elseif pos.y and pos.y >= 64 then
      -- item dentro de um container aberto (mochila, bolsa, depot)
      return { container = pos.y - 64, slot = pos.z }
    end
  end

  local slotNum = tonumber(string.match(widget and widget:getId() or "", 'slot(%d+)'))
  if slotNum then
    return { slot = slotNum }
  end

  return nil
end

-- Encerra a selecao em andamento (crosshair) e fecha a janela de confirmacao.
function Market.clearAddOffer()
  pickState = nil
  if modules.game_interface and modules.game_interface.getMapPanel then
    local map = modules.game_interface.getMapPanel()
    if map then map:setCrosshair('') end
  end
  if marketWindowAdd and marketWindowAdd:isVisible() then
    marketWindowAdd:hide()
  end
end

-- Botao Cancelar / X da janela de confirmacao.
function Market.cancelAddOffer()
  local wasPicking = pickState ~= nil
  Market.clearAddOffer()
  if wasPicking then
    feedback(tr('Oferta cancelada.'))
  end
end

-- Manda o endereco do item escolhido pro servidor. O servidor e' quem diz o
-- nome, a quantidade e o tier - e so' responde quando o item e' do jogador.
local function sendPickRequest(address)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  protocol:sendExtendedOpcode(mOpcode, "pick>" .. json.encode(address))
end

-- Preenche a janela de confirmacao com o item que o servidor validou:
-- sprite (com o shader do tier), nome embaixo, tier em amarelo e quanto o
-- jogador tem. So' o preco e a quantidade ficam pro jogador digitar.
local function showPickedWindow()
  if not marketWindowAdd then return end

  local item = pickState and pickState.item
  if not item then return end

  local uiItem = marketWindowAdd:getChildById('uiPickedItem')
  if uiItem then
    uiItem:setItemId(item.clientId)
    -- o icone mostra o shader do tier do item (mesmos shaders do tooltip)
    if item.tier > 0 then
      uiItem:setItemShader('item_tier_' .. item.tier)
    else
      uiItem:setItemShader('')
    end
    uiItem:setTooltip(item.name)
  end

  marketWindowAdd:getChildById('lblPickedName'):setText(item.name)
  marketWindowAdd:getChildById('lblPickedTier'):setText(item.tier > 0 and ('[Tier ' .. item.tier .. ']') or '')
  marketWindowAdd:getChildById('lblPickedAvail'):setText(tr('Disponivel: %d (%s)', item.count, item.origin or tr('mochila')))

  -- a quantidade ja' vem preenchida com o maximo que cabe numa oferta
  local edtCount = marketWindowAdd:getChildById('edtCount')
  if item.stackable then
    edtCount:setText(tostring(math.min(item.count, 100)))
    edtCount:enable()
  else
    -- item unico (nao-stackavel): o servidor so' aceita quantidade 1
    edtCount:setText('1')
    edtCount:disable()
  end
  marketWindowAdd:getChildById('buttonOk'):enable()

  marketWindowAdd:show()
  marketWindowAdd:raise()
  marketWindowAdd:focus()
  marketWindowAdd:getChildById('edtPrice'):focus()
end

-- Abre o crosshair NATIVO do client (o mesmo de mirar com runa): o proximo
-- clique esquerdo escolhe o item, o botao direito cancela. Nenhuma janela
-- aparece antes do item estar confirmado pelo servidor.
function Market.startOfferPick()
  -- se ja' tem uma selecao pela metade, comeca de zero
  Market.clearAddOffer()

  if not modules.game_interface or not modules.game_interface.startItemPick then
    displayInfoBox('Market', tr('Nao foi possivel iniciar a selecao do item.'))
    return false
  end

  local started = modules.game_interface.startItemPick(function(widget, mousePosition)
    Market.onOfferPick(widget, mousePosition)
  end)

  if not started then
    displayInfoBox('Market', tr('Feche outras janelas de selecao antes de escolher o item.'))
    return false
  end

  pickState = { step = 'search' }

  -- crosshair amarelo desenhado no tile embaixo do mouse (MapView::setCrosshair)
  modules.game_interface.getMapPanel():setCrosshair('/modules/game_market/ui/crosshair')
  feedback(tr('Abra a mochila (ou o depot) e clique no item que voce quer vender. Botao direito cancela.'))
  return true
end

-- Clique do crosshair. Aqui so' acontecem as checagens LOCAIS: o que vale e'
-- a resposta do servidor (Market.onPickOk), que so' confirma item da mochila
-- ou do deposito do jogador.
function Market.onOfferPick(widget, mousePosition)
  if not pickState then return end

  -- botao direito: o gameinterface devolve widget nil -> cancela a selecao
  if not widget then
    Market.cancelAddOffer()
    return
  end

  local address
  local className = widget.getClassName and widget:getClassName() or ""
  if className == 'UIItem' and not widget:isVirtual() then
    address = itemAddress(widget:getItem(), widget)
  end

  -- 1ª checagem local: o clique tem que ter caido num item de verdade. Se nao
  -- caiu, o crosshair CONTINUA ativo (igual mirar com runa) pra tentar de novo.
  if not address then
    feedback(tr('Esse lugar nao tem item. Clique num item da sua mochila ou do seu deposito.'))
    return
  end

  -- 2ª checagem local: item no chao/mapa nunca passa (o servidor recusa de novo)
  if address.pos then
    feedback(tr('Voce so pode vender itens da sua mochila ou do seu deposito.'))
    return
  end

  pickState.address = address
  pickState.step = 'confirm'
  sendPickRequest(address)
  feedback(tr('Conferindo o item no servidor...'))
end

-- Resposta do servidor para o item escolhido.
function Market.onPickOk(data)
  if not pickState or type(data) ~= "table" then return end

  -- resposta fora de hora (selecao cancelada ou refeita nesse meio tempo)
  if pickState.step ~= 'confirm' and pickState.step ~= 'verify' then return end

  local name = data.itemName or ""
  local available = tonumber(data.count) or 0
  local tier = tonumber(data.tier) or 0
  local clientId = tonumber(data.clientId) or tonumber(data.itemId) or 0

  if name == "" or available <= 0 or clientId <= 0 then
    Market.onPickError(tr('Nao foi possivel identificar o item selecionado.'))
    return
  end

  if pickState.step == 'verify' then
    -- 4ª checagem: o item foi conferido de novo antes de enviar. A resposta tem
    -- que ser identica `a que abriu a janela (nome, tier, sprite, quantidade);
    -- se o jogador mexeu no item nesse meio tempo, a oferta nao sai.
    local first = pickState.item
    local pending = pickState.pending
    if not first or not pending or first.name ~= name or first.tier ~= tier
       or first.count ~= available or first.clientId ~= clientId then
      Market.clearAddOffer()
      feedback(tr('O item mudou de lugar ou mudou de tier. Escolha o item de novo.'))
      return
    end

    local price = pending.price
    local count = pending.count
    Market.clearAddOffer()

    g_game.talkChannel(MessageModes.Market, MessageModes.None,
                       string.format("!offer add, %s, %d, %d", name, count, price))
    feedback(tr('Enviando oferta: %dx %s por %s gold.', count, name, formatPrice(price)))

    scheduleEvent(function() requestOffers(1, lastSearch) end, 700)
    return
  end

  -- 3ª checagem: o item foi confirmado pelo servidor - agora sim abre a janela
  -- com o sprite, o nome e o tier, pra escolher preco e quantidade.
  pickState.step = 'window'
  pickState.item = {
    name      = name,
    count     = available,
    tier      = tier,
    clientId  = clientId,
    stackable = data.stackable == true,
    origin    = data.source == 'depot' and tr('deposito') or tr('mochila')
  }
  modules.game_interface.getMapPanel():setCrosshair('')
  showPickedWindow()
end

function Market.onPickError(message)
  if not pickState then return end

  local text = (message ~= "" and message) or tr('Nao foi possivel vender esse item.')

  if pickState.step == 'verify' then
    -- estava conferindo antes de enviar: fecha a janela e para por aqui
    Market.clearAddOffer()
  else
    -- ainda escolhendo (ou confirmando o item clicado): o crosshair continua
    -- ativo pra o jogador clicar em outro item
    pickState.step = 'search'
    pickState.address = nil
  end

  feedback(text)
end

-- ============================================================================

function Market.init()
  connect(g_game, {
    onGameStart = Market.online,
    onGameEnd   = Market.offline
  })

  ProtocolGame.registerExtendedOpcode(mOpcode, function(protocol, opcode, buffer)
    if type(buffer) ~= "string" or buffer == "" then
      return
    end

    local ok, err = pcall(function()
      local action = buffer:explode('>')

      -- "open>" e' o servidor pedindo pra ABRIR a janela (use no item da action
      -- 50005 / balcao do market). Sem esse prefixo o payload e' so' dado de
      -- lista: atualiza o conteudo se a janela ja' estiver aberta e NAO abre
      -- nada. Antes disso qualquer resposta do servidor abria a janela - era o
      -- que fazia o market aparecer sozinho ao entrar no jogo / relogar.
      -- A permissao vale so' para ESTE payload (nada de flag que possa ficar
      -- pendurada da ultima vez que a janela foi aberta).
      local allowOpen = false
      if action[1] == "open" then
        allowOpen = true
        table.remove(action, 1)
      end

      if action[1] == "create" then
        if allowOpen and not marketWindow:isVisible() then
          marketWindow:show()
          marketWindow:raise()
          marketWindow:focus()
        end
        Market.updateControlsPagination(action[2])
        -- payload: create>COUNT>{lua table} - rejoin everything after count
        local data = {}
        for i = 3, #action do
          data[#data + 1] = action[i]
        end
        -- payload do servidor: nunca rodar com o ambiente global (corelib/util.lua)
        local list, cerr = safeLuaDeserialize(table.concat(data, ">"))
        if cerr then
          print("[market] payload error: " .. tostring(cerr))
        end
        Market.createList(list or {})
      elseif action[1] == "details" then
        displayInfoBox('Market', action[2] or "")
      elseif action[1] == "pickok" then
        local decoded, data = pcall(function() return json.decode(action[2]) end)
        if decoded and type(data) == "table" then
          Market.onPickOk(data)
        else
          Market.onPickError(tr('Nao foi possivel identificar o item selecionado.'))
        end
      elseif action[1] == "pickerr" then
        Market.onPickError(action[2] or "")
      end
    end)
    if not ok then
      print("[market] parse error: " .. tostring(err))
    end
  end)

  -- marketButton    = modules.client_topmenu.addRightGameButton('marketButton', tr('Market'), '/images/topbuttons/shop', Market.toggle, true)
  marketWindow    = g_ui.displayUI('market')
  marketWindow:hide()
  marketWindowAdd = g_ui.displayUI('marketadd')
  marketWindowAdd:hide()
  -- Enter envia a oferta, Escape cancela a selecao/janela
  marketWindowAdd.onEnter = Market.addOffer
  marketWindowAdd.onEscape = Market.cancelAddOffer

  -- NOTE: getChildById in this client only finds DIRECT children.
  -- The pagination/search widgets are nested inside panels, so use the
  -- recursive variant here.
  marketList = marketWindow:recursiveGetChildById('marketList')
  btnNext    = marketWindow:recursiveGetChildById('btnNext')
  btnPrev    = marketWindow:recursiveGetChildById('btnPrev')
  lblIndex   = marketWindow:recursiveGetChildById('lblIndex')
  edtSearch  = marketWindow:recursiveGetChildById('edtSearch')
  cmbFilter  = marketWindow:recursiveGetChildById('cmbFilter')
  cmbTier    = marketWindow:recursiveGetChildById('cmbTier')

  -- Populate the filter dropdown.
  if cmbFilter then
    for i, opt in ipairs(filterOptions) do
      cmbFilter:addOption(opt[1], opt[2])
    end
    cmbFilter.onOptionChange = Market.onFilterChange
  end

  -- Populate the tier dropdown ("Todos" + Tier 1..10).
  if cmbTier then
    for i = 1, 10 do
      tierOptions[#tierOptions + 1] = { 'Tier ' .. i, i }
    end
    for i, opt in ipairs(tierOptions) do
      cmbTier:addOption(opt[1], opt[2])
    end
    cmbTier.onOptionChange = Market.onTierChange
  end
end

function Market.terminate()
  disconnect(g_game, {
    onGameStart = Market.online,
    onGameEnd   = Market.offline
  })
  pcall(function() ProtocolGame.unregisterExtendedOpcode(mOpcode) end)
  -- nao deixa um crosshair pendente segurando o mouse depois do unload
  -- (pickState primeiro: assim o callback do cancel nao mexe mais em janela)
  pickState = nil
  if modules.game_interface and modules.game_interface.cancelItemPick then
    pcall(function() modules.game_interface.cancelItemPick() end)
  end
  -- o botao da topbar foi substituido pelo botao de Shop: marketButton nunca e
  -- criado (a linha antiga esta comentada acima), entao indexar direto aqui
  -- abortava o terminate() inteiro a cada unload/saida (market.lua:150).
  if marketButton then marketButton:destroy() end
  if marketWindow then marketWindow:destroy() marketWindow = nil end
  if marketWindowAdd then marketWindowAdd:destroy() marketWindowAdd = nil end
end

function Market.online()
  numPage = g_settings.getNumber('mNumPage', 1)
  lastSearch = ""
  lastFilter = "all"
  lastTier = 0
  if cmbFilter then
    cmbFilter:setCurrentOption(tr('Todas'))
  end
  if cmbTier then
    cmbTier:setCurrentOptionByData(0)
  end
  -- Nada de requestOffers() aqui. Pedir a lista ao entrar no jogo fazia o
  -- servidor responder "create>" e a janela do market pulava na tela em qualquer
  -- lugar do mapa. A lista e' buscada quando a janela e' aberta (Market.toggle).
end

function Market.offline()
  if pickState then
    -- saindo do jogo: cancela sem reabrir nada
    pickState = nil
    if modules.game_interface and modules.game_interface.cancelItemPick then
      pcall(function() modules.game_interface.cancelItemPick() end)
    end
  end
  marketWindow:hide()
  if marketWindowAdd then marketWindowAdd:hide() end
  g_settings.set('mNumPage', numPage)
end

function Market.toggle()
  local visible = not marketWindow:isVisible()
  marketWindow:setVisible(visible)
  if visible then
    numPage = 1
    requestOffers(1, lastSearch)
  end
end

function Market.refresh()
  numPage = 1
  requestOffers(1, lastSearch)
end

function Market.clearSearch()
  edtSearch:clearText()
  lastSearch = ""
  numPage = 1
  requestOffers(1, "")
end

function Market.onSearchTextChange(text)
  if searchEvent then
    searchEvent:cancel()
  end
  searchEvent = scheduleEvent(function()
    lastSearch = text or ""
    numPage = 1
    requestOffers(1, lastSearch)
  end, 300)
end

function Market.onFilterChange(self, text, data)
  lastFilter = data or "all"
  numPage = 1
  requestOffers(1, lastSearch)
end

function Market.onTierChange(self, text, data)
  lastTier = tonumber(data) or 0
  numPage = 1
  requestOffers(1, lastSearch)
end

-- Botao "Adicionar Oferta" do market: abre o crosshair NA HORA. A janela de
-- preco/quantidade so' aparece depois que o jogador escolhe o item e o servidor
-- confirma que ele e' dele (por isso nao ha mais campo de nome do item).
function Market.showAddOffer()
  if pickState then
    -- ja' estava escolhendo: o clique cancela a selecao anterior
    Market.cancelAddOffer()
    return
  end

  if marketWindowAdd:isVisible() then
    marketWindowAdd:hide()
  end

  Market.startOfferPick()
end

-- Botao "Adicionar" da janela de confirmacao: valida o que o jogador digitou e
-- pergunta ao servidor outra vez pelo mesmo item antes de mandar a oferta.
function Market.addOffer()
  local item = pickState and pickState.item
  if not item or pickState.step ~= 'window' then
    return
  end

  local priceNum = tonumber(marketWindowAdd:getChildById('edtPrice'):getText())
  local countNum = tonumber(marketWindowAdd:getChildById('edtCount'):getText())

  if not priceNum or priceNum < 1000 or priceNum ~= math.floor(priceNum) then
    displayInfoBox('Market', tr('O preço minimo por oferta é 1.000 gold.'))
    return
  end

  local maxCount = math.min(item.count, 100)
  if not countNum or countNum < 1 or countNum ~= math.floor(countNum) then
    displayInfoBox('Market', tr('Quantidade inválida (de 1 a %d).', maxCount))
    return
  end
  if countNum > maxCount then
    displayInfoBox('Market', tr('Voce so tem %d desse item.', maxCount))
    return
  end

  -- 4ª checagem: re-consulta o mesmo endereco no servidor. Se o item tiver
  -- saido da mochila/deposito (ou mudado de tier/quantidade) nesse meio tempo,
  -- a oferta nem sai.
  pickState.step = 'verify'
  pickState.pending = { price = math.floor(priceNum), count = math.floor(countNum) }
  marketWindowAdd:getChildById('buttonOk'):disable()
  sendPickRequest(pickState.address)
  feedback(tr('Confirmando o item antes de enviar a oferta...'))
end

-- Tier de uma oferta: o servidor manda no campo `tier`; o nome (em servidores
-- antigos, sem o campo) pode trazer " [Tier N]".
local function offerTier(value)
  local tier = tonumber(value.tier) or 0
  if tier == 0 then
    local name = value.itemName or ""
    local tierStr = name:match('%[Tier (%d+)%]') or name:match('Tier (%d+)')
    if tierStr then tier = tonumber(tierStr) or 0 end
  end
  if tier < 0 or tier > 10 then tier = 0 end
  return tier
end

function Market.createList(list)
  marketList:destroyChildren()

  if not list or #list == 0 then
    local empty = g_ui.createWidget('MarketRow', marketList)
    empty:getChildById('uiItem'):setVisible(false)
    empty:getChildById('btnAction'):setVisible(false)
    -- re-anchor the label to the row start so the empty message is centered.
    -- This client has NO setAnchors; use breakAnchors + addAnchor instead.
    -- NOTE: breakAnchors() removes ALL anchors, so re-add vertical centering too.
    local lbl = empty:getChildById('lblItem')
    lbl:breakAnchors()
    lbl:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    lbl:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    lbl:setMarginLeft(8)
    lbl:setText(tr('Nenhuma oferta encontrada'))
    empty:getChildById('lblPlayer'):setText('')
    empty:getChildById('lblQtd'):setText('')
    empty:getChildById('lblPrice'):setText('')
    empty:getChildById('lblTier'):setText('')
    return
  end

  for i, value in ipairs(list) do
    local marketRow = g_ui.createWidget('MarketRow', marketList)

    marketRow.onDoubleClick = function(self)
      g_game.getProtocolGame():sendExtendedOpcode(mOpcode, "details>"..value.id)
    end

    local tier = offerTier(value)

    local uiItem = marketRow:getChildById('uiItem')
    uiItem:setItemId(value.itemId or 0)
    -- o icone mostra o shader do tier do item (mesmos shaders do tooltip)
    if tier > 0 then
      uiItem:setItemShader('item_tier_' .. tier)
    else
      uiItem:setItemShader('')
    end

    -- "look real" tooltip with full item stats (sent by the server).
    -- Shown on both the sprite and the item name.
    local lblItem = marketRow:getChildById('lblItem')
    if value.look and value.look ~= "" then
      uiItem:setTooltip(value.look)
      lblItem:setTooltip(value.look)
    end

    lblItem:setText(short(value.itemName or "", 24))
    -- TIER em amarelo, logo depois do nome do item
    marketRow:getChildById('lblTier'):setText(tier > 0 and ('[Tier ' .. tier .. ']') or '')
    marketRow:getChildById('lblPlayer'):setText(short(value.player or "", 20))
    marketRow:getChildById('lblQtd'):setText(value.count or 0)
    marketRow:getChildById('lblPrice'):setText(formatPrice(value.price))

    local btnAction = marketRow:getChildById('btnAction')
    btnAction:setText(value.type == 0 and tr('Comprar') or tr('Remover'))
    btnAction.onClick = function(self)
      local action = (value.type == 0 and "!offer buy," or "!offer remove,")..value.id
      g_game.talkChannel(MessageModes.Market, MessageModes.None, action)
      scheduleEvent(function() requestOffers(numPage, lastSearch) end, 600)
    end
  end
end

function Market.nextAndPrev(control)
  numPage = ( control == 1 ) and ( numPage + 1 ) or ( numPage - 1 )
  if numPage < 1 then
    numPage = 1
  end
  requestOffers(numPage, lastSearch)
end

function Market.updateControlsPagination(value)
  local total = tonumber(value) or 0
  local totalPages = math.max(1, math.ceil(total / 15))
  btnPrev:setEnabled(numPage ~= 1)
  btnNext:setEnabled(numPage < totalPages)
  lblIndex:setText(tr('Página: ') .. numPage .. '/' .. totalPages)
end
