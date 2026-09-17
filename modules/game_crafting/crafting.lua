-- ============================================================
-- game_crafting - CLIENT (Apenas Interface Visual)
-- Toda a logica de craft, validacao e recipes fica no SERVER.
-- Este script APENAS exibe dados e envia pedidos.
-- ============================================================

local CRAFTING_OPCODE = 106

local craftingWindow = nil
local isCraftingOpen = false
local overlay = nil
local destroyOverlay  -- forward-declare: usada em terminate() antes da definicao

-- Profissoes (apenas nomes para exibicao - dados reais vem do server)
local skillIdToUI = {
  [1] = "Blacksmith",
  [2] = "Alchemy",
  [3] = "Cooking",
  [4] = "Enchanting",
}

local skillIdToImage = {
  [1] = "/images/topbuttons/skills",
  [2] = "/images/topbuttons/shop",
  [3] = "/images/topbuttons/drop",
  [4] = "/images/topbuttons/market",
}

function init()
  craftingWindow = g_ui.displayUI('crafting')
  craftingWindow:hide()

  craftingWindow.onEscape = hide
  craftingWindow:getChildById("closeButton").onClick = hide

  -- Botoes APENAS enviam pedidos ao server
  craftingWindow:getChildById("craftButton").onClick = function() sendCraftRequest(false) end
  craftingWindow:getChildById("craftAllButton").onClick = function() sendCraftRequest(true) end

  -- Recipe selection (apenas seleciona visualmente)
  craftingWindow:recursiveGetChildById("recipeList").onChildFocusChange = onRecipeSelected

  -- Fechar ao andar
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = hide,
  })

  if g_game.getLocalPlayer() then
    connect(g_game.getLocalPlayer(), {
      onWalk = onPlayerWalk,
      onPositionChange = onPlayerPositionChange,
    })
  end

  ProtocolGame.registerExtendedOpcode(CRAFTING_OPCODE, onExtendedOpcode)
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = hide,
  })

  if g_game.getLocalPlayer() then
    disconnect(g_game.getLocalPlayer(), {
      onWalk = onPlayerWalk,
      onPositionChange = onPlayerPositionChange,
    })
  end

  pcall(function() ProtocolGame.unregisterExtendedOpcode(CRAFTING_OPCODE) end)
  destroyOverlay()

  if craftingWindow then
    craftingWindow:destroy()
    craftingWindow = nil
  end
end

function onGameStart()
  if g_game.getLocalPlayer() then
    connect(g_game.getLocalPlayer(), {
      onWalk = onPlayerWalk,
      onPositionChange = onPlayerPositionChange,
    })
  end
end

-- ============================================================
-- FECHAR AO ANDAR
-- ============================================================

function onPlayerWalk()
  if isCraftingOpen then hide() end
end

function onPlayerPositionChange()
  if isCraftingOpen then hide() end
end

-- ============================================================
-- RECEBER DADOS DO SERVER (apenas exibir)
-- ============================================================

function onExtendedOpcode(protocol, code, buffer)
  if code ~= CRAFTING_OPCODE then return end

  local json_ok, json_data = pcall(function() return json.decode(buffer) end)

  if not json_ok then
    g_logger.error("[Crafting] JSON error")
    return false
  end

  local action = json_data.action

  if action == "open" or action == "update" then
    -- Server envia dados para exibir
    displayCraftingWindow(json_data.skill, json_data.recipes)
  elseif action == "result" then
    -- Server envia resultado do craft
    showResult(json_data.success, json_data.error or "")
  elseif action == "close" then
    hide()
  end
end

-- ============================================================
-- EXIBICAO (apenas visual)
-- ============================================================

-- O server ja envia client IDs (via ItemType:getClientId())
-- Nao precisa de conversao no client
local function resolveClientId(clientId)
  return clientId or 0
end

function displayCraftingWindow(skill, recipes)
  craftingWindow:setText(skillIdToUI[skill.profId] or "Crafting")
  craftingWindow.profId = skill.profId

  -- Esconde barra de skill (desabilitada)
  local skillBar = craftingWindow:getChildById("skillBar")
  if skillBar then skillBar:hide() end
  local skillLabel = craftingWindow:getChildById("skillLabel")
  if skillLabel then skillLabel:hide() end

  local recipeList = craftingWindow:recursiveGetChildById("recipeList")
  recipeList:destroyChildren()

  for i, recipe in ipairs(recipes) do
    local widget = g_ui.createWidget('Recipe', recipeList)
    widget:setText("T" .. recipe.tier .. " " .. recipe.name)
    widget.recipe = recipe
    widget.globalId = recipe.globalId

    -- Todas as receitas estao liberadas
  end

  recipeList:focusChild(recipeList:getFirstChild())
  show()
end

-- ============================================================
-- SELECIONAR RECIPE (apenas exibe detalhes)
-- ============================================================

function onRecipeSelected(w, child)
  local recipe = child.recipe
  if not recipe then return end

  -- Exibe custo
  craftingWindow:getChildById("cost"):setText(recipe.cost .. " Gold")

  -- Exibe item resultado (converte server ID -> client sprite)
  local item = craftingWindow:recursiveGetChildById("recipeItem")
  item:setItemId(resolveClientId(recipe.spriteId))
  item:setVirtual(true)
  item:setItemCount(recipe.count)

  -- Exibe ingredientes (converte server ID -> client sprite)
  local panel = craftingWindow:recursiveGetChildById("ingredientsPanel")
  panel:destroyChildren()
  for _, ingredient in ipairs(recipe.ingredients) do
    local widget = g_ui.createWidget('Item', panel)
    widget:setItemId(resolveClientId(ingredient.spriteId))
    widget:setVirtual(true)
    widget:setItemCount(ingredient.count)
    widget:setTooltip(ingredient.playerCount .. "/" .. ingredient.count .. " " .. ingredient.name)
  end

  -- Exibe descricao
  craftingWindow:recursiveGetChildById("recipeDesc"):setText(recipe.desc)

  -- Exibe nome
  local label = craftingWindow:recursiveGetChildById("recipeLabel")
  label:setText(recipe.name)
  label:setWidth(label:getTextSize().width)

  -- Atualiza quantidade maxima (baseado no que o server enviou)
  local maxAmount = 1
  for _, ingredient in ipairs(recipe.ingredients) do
    local canMake = math.floor(ingredient.playerCount / ingredient.count)
    if canMake < maxAmount or maxAmount == 1 then
      maxAmount = canMake
    end
  end
  if maxAmount < 1 then maxAmount = 1 end

  -- Habilita/desabilita botoes
  craftingWindow:recursiveGetChildById("craftButton"):setEnabled(maxAmount > 0)
  craftingWindow:recursiveGetChildById("craftAllButton"):setEnabled(maxAmount > 0)
end

-- ============================================================
-- ENVIAR PEDIDO AO SERVER (apenas envia, nao valida)
-- ============================================================

function sendCraftRequest(all)
  local recipeList = craftingWindow:recursiveGetChildById("recipeList")
  local focusedChild = recipeList:getFocusedChild()
  if not focusedChild or not focusedChild.globalId then return end

  -- Sempre envia amount=1 (botoes de quantidade removidos)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(CRAFTING_OPCODE, json.encode({
      action = "craft",
      recipeId = focusedChild.globalId,
      amount = 1,
      profId = craftingWindow.profId,
    }))
  end
end

-- ============================================================
-- RESULTADO DO CRAFT (apenas exibe)
-- ============================================================

function showResult(success, message)
  -- Esconde overlay e janela para o InfoBox ficar visivel
  destroyOverlay()
  if craftingWindow then
    craftingWindow:hide()
  end
  addEvent(function()
    displayInfoBox(tr(success and 'Success' or 'Failed'), message)
  end, 50)
end

-- ============================================================
-- ABRIR/FECHAR
-- ============================================================

local function createOverlay()
  if overlay then return end
  local root = modules.game_interface and modules.game_interface.getRootPanel()
  if not root then return end
  overlay = g_ui.createWidget('Panel', root)
  overlay:setId('craftingOverlay')
  overlay:setBackgroundColor('#000000CC')
  overlay:fill('parent')
  overlay.onMousePress = function() end
  overlay.onMouseRelease = function() end
end

destroyOverlay = function()
  if overlay then
    overlay:destroy()
    overlay = nil
  end
end

function show()
  if craftingWindow then
    createOverlay()
    craftingWindow:show()
    craftingWindow:raise()
    craftingWindow:grabKeyboard()
    isCraftingOpen = true
  end
end

function hide()
  if craftingWindow then
    craftingWindow:hide()
    craftingWindow:ungrabKeyboard()
    isCraftingOpen = false
    destroyOverlay()
    if modules.game_interface then
      modules.game_interface.getRootPanel():focus()
    end
  end
end
