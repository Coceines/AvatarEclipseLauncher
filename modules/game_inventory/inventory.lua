local waterNumber = 0
local monkMirrorItem = nil
fightOffensiveBox = nil
fightBalancedBox = nil
fightDefensiveBox = nil
chaseModeButton = nil
safeFightButton = nil
fightModeRadioGroup = nil
avatarEdit = true
cameraSlot = nil
cameraEquipped = false
momoSlot = nil
momoEquipped = false

function doMessageCheck(msg, keyword)
    local a, b = string.find(msg, keyword)

    if(a and b) then
        return true
    end

    return false
end

function string.explode(str, sep, limit)
    local i, pos, tmp, t = 0, 1, "", {}
    
    for s, e in function() return string.find(str, sep, pos) end do
        tmp = str:sub(pos, s - 1):trim()
        table.insert(t, tmp)
        pos = e + 1

        i = i + 1
        if(limit ~= nil and i == limit) then
            break
        end
    end

    tmp = str:sub(pos):trim()
    table.insert(t, tmp)
    
    return t
end

function getPrimaryAndSecondary(msg)
    local strings = string.explode(msg, "#")

    if doMessageCheck(strings[3], ",") then
        local number = string.explode(strings[3], ",")

        return {tonumber(number[1]), tonumber(number[2])}
    else
        return {tonumber(strings[3])}
    end
end

function checkIsWaterMsg(msg)
    local containsW = doMessageCheck(msg, "#w#")

    if containsW then
        local strings = string.explode(msg, ";")

        for x = 1, #strings do
            if doMessageCheck(strings[x], "#w#") then
                local a = getPrimaryAndSecondary(strings[x])
                waterNumber = a[1]
                break
            end
        end

        if inventoryPanel:getChildById('slot10').itemid == 131 then
          refleshNumber()
        else
          refleshNumber(true)
        end

        return true
    end

    return false
end

InventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot"
}

inventoryWindow = nil
inventoryPanel = nil
inventoryButton = nil
inventorySideButton = nil



function init()
  connect(LocalPlayer, { 
    onInventoryChange = onInventoryChange,
    onFreeCapacityChange = onFreeCapacityChange
  })

  connect(g_game, { onGameStart = refresh })

  -- Ctrl+I removido (batia com o Inspect Creature). O botao continua abrindo.

  inventoryButton = modules.client_topmenu.addRightGameToggleButton('inventoryButton', tr('Inventory'), '/images/topbuttons/inventory', toggle)
  inventoryButton:setOn(true)

  inventoryWindow = g_ui.loadUI('inventory', modules.game_interface.getRightPanel())
  inventoryWindow:disableResize()
  inventoryPanel = inventoryWindow:getChildById('contentsPanel')

  cameraSlot = inventoryPanel:getChildById('cameraSlot')
  if cameraSlot then
    cameraSlot.onClick = onCameraSlotClick
  end

  momoSlot = inventoryPanel:getChildById('momoSlot')

  -- Botao lateral esquerdo (imagem custom) que abre/fecha a mochila equipada.
  -- O estilo fica em inventory_button.otui deste mesmo modulo.
  -- O pai e' o gameRootPanel para a ancora 'consolePanel.top' funcionar
  -- (ancoras so enxergam irmaos, ou seja, filhos do mesmo pai).
  local okSideStyle = pcall(function() g_ui.importStyle('inventory_button') end)
  if okSideStyle then
    -- pai = gameRootPanel, para poder ancorar no topo do chat (consolePanel)
    local sideParent = rootWidget
    local okPanel, rootPanel = pcall(function() return modules.game_interface.getRootPanel() end)
    if okPanel and rootPanel then
      sideParent = rootPanel
    end
    local okCreate, sideButton = pcall(function() return g_ui.createWidget('InventorySideButton', sideParent) end)
    if okCreate and sideButton then
      inventorySideButton = sideButton
      inventorySideButton:hide()
    end
  end


  refresh()

  --alteracoes juntando tudo--
  fightOffensiveBox = inventoryWindow:recursiveGetChildById('fightOffensiveBox')
  fightBalancedBox = inventoryWindow:recursiveGetChildById('fightBalancedBox')
  fightDefensiveBox = inventoryWindow:recursiveGetChildById('fightDefensiveBox')

  -- Tooltips das posturas (descricao de cada modo de combate)
  fightOffensiveBox:setTooltip("F\250ria\n+15% dano.\n-20% cura recebida.")
  fightBalancedBox:setTooltip("Fortaleza\n-15% dano recebido.\n-15% dano causado.")
  fightDefensiveBox:setTooltip("Canaliza\231\227o\n-20% custo de mana.\n-15% dano.")
  chaseModeButton = inventoryWindow:recursiveGetChildById('chaseModeBox')
  safeFightButton = inventoryWindow:recursiveGetChildById('safeFightBox')
  fightModeRadioGroup = UIRadioGroup.create()
  fightModeRadioGroup:addWidget(fightOffensiveBox)
  fightModeRadioGroup:addWidget(fightBalancedBox)
  fightModeRadioGroup:addWidget(fightDefensiveBox)

  connect(fightModeRadioGroup, { onSelectionChange = onSetFightMode })
  connect(chaseModeButton, { onCheckChange = onSetChaseMode })
  connect(safeFightButton, { onCheckChange = onSetSafeFight })
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onWalk = check,
    onAutoWalk = check
  })
  --end--

  if g_game.isOnline() then
    online()
    local localPlayer = g_game.getLocalPlayer()
    if localPlayer then
      onFreeCapacityChange(localPlayer, localPlayer:getFreeCapacity())
    end
  end

  inventoryWindow:setup()
end

function onFreeCapacityChange(player, freeCapacity)
  if not inventoryPanel then return end
  local capLabel = inventoryPanel:getChildById('cap')
  if capLabel then
    capLabel:setText(tr('Cap') .. ': ' .. math.floor(freeCapacity))
  end
end

function refleshNumber(toZero)
  local percentWater = inventoryPanel:getChildById('slot10')

  if not percentWater or waterNumber < 0 then
    return
  end

  if not toZero then
    percentWater:setText(waterNumber.."%")
    percentWater:setColor("white")
    --refresh()
  else
    percentWater:setText()
  end

end

function updateCameraSlot(item)
  cameraEquipped = item ~= nil
  if not cameraSlot then return end
  if item then
    cameraSlot:setStyle('Item')
    cameraSlot:setItem(item)
  else
    cameraSlot:setStyle('CameraSlot')
    cameraSlot:setItem(nil)
  end
end

function updateMomoSlot(item)
  momoEquipped = item ~= nil
  if not momoSlot then return end
  if item then
    momoSlot:setStyle('Item')
    momoSlot:setItem(item)
  else
    momoSlot:setStyle('MomoSlot')
    momoSlot:setItem(nil)
  end
end

-- Clique esquerdo na camera no slot = liga/desliga a TV.
function onCameraSlotClick(widget, mousePos, button)
  if not g_game.isOnline() then return end
  if button == MouseLeftButton and cameraEquipped then
    sendCameraCmd('toggle')
  end
end

function sendCameraCmd(cmd)
  if modules.game_shop and modules.game_shop.sendCamera then
    modules.game_shop.sendCamera(cmd)
  end
end

function terminate()
  if g_game.isOnline() then
    offline()
  end

  disconnect(LocalPlayer, { 
    onInventoryChange = onInventoryChange,
    onFreeCapacityChange = onFreeCapacityChange
  })

  disconnect(g_game, { onGameStart = refresh })

  cameraSlot = nil
  momoSlot = nil
  inventoryWindow:destroy()
  inventoryButton:destroy()
  if inventorySideButton then
    inventorySideButton:destroy()
    inventorySideButton = nil
  end

  fightModeRadioGroup:destroy()

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onWalk = check,
    onAutoWalk = check
  })
end

function refresh()
  local player = g_game.getLocalPlayer()
  for i=InventorySlotFirst,InventorySlotLast do
    if g_game.isOnline() then
      onInventoryChange(player, i, player:getInventoryItem(i))
    else
      onInventoryChange(player, i, nil)
    end
  end
end

function toggle()
  if inventoryButton:isOn() then
    inventoryWindow:close()
    inventoryButton:setOn(false)
  else
    inventoryWindow:open()
    inventoryButton:setOn(true)
  end
end

-- Abre a mochila (backpack) equipada no slot das costas. Se ela ja estiver
-- aberta, fecha. Usado pelo botao lateral esquerdo.
function toggleBackpack()
  if not g_game.isOnline() then return end

  local player = g_game.getLocalPlayer()
  if not player then return end

  local backpack = player:getInventoryItem(InventorySlotBack)
  if not backpack then return end
  if not backpack:isContainer() then return end

  for _, container in pairs(g_game.getContainers()) do
    local containerItem = container and container:getContainerItem()
    if containerItem and containerItem:getId() == backpack:getId() then
      g_game.close(container)
      return
    end
  end

  g_game.open(backpack)
end

function onMiniWindowClose()
  inventoryButton:setOn(false)
end

-- hooked events
-- Monk Mirror: espelha o item da mao esquerda no slot da mao direita
-- Funciona para TODAS as classes do Avatar automaticamente.
local function isMonkMirrorEnabled()
  local player = g_game.getLocalPlayer()
  if not player then
    return false
  end
  return true
end

local function updateMonkMirrorItem(leftItem)
  local ui = inventoryPanel
  if not ui then return end

  local rightSlot = ui:getChildById('slot' .. InventorySlotRight)
  if not rightSlot then return end

  if not isMonkMirrorEnabled() then
    if monkMirrorItem then
      monkMirrorItem = nil
    end
    return
  end

  -- Right slot is mirror-only: ignore any real item the server placed there.
  -- Always mirror the left hand item regardless of what's in the real right slot.

  if leftItem then
    monkMirrorItem = leftItem
    rightSlot:setStyle('Item')
    rightSlot:setItem(leftItem:clone())
    rightSlot:setOpacity(0.4)
    rightSlot:setDraggable(false)
    rightSlot:setEnabled(false)
    rightSlot:setFlipDirection(FlipDirection.Horizontal)
    rightSlot.itemid = leftItem:getId()
  else
    monkMirrorItem = nil
    rightSlot:setStyle(InventorySlotStyles[InventorySlotRight])
    rightSlot:setItem(nil)
    rightSlot:setOpacity(1.0)
    rightSlot:setDraggable(true)
    rightSlot:setEnabled(true)
    rightSlot:setFlipDirection(FlipDirection.None)
  end
end

function onInventoryChange(player, slot, item, oldItem)
  if slot == 11 then
    updateCameraSlot(item)
    return
  end
  if slot == 12 then
    updateMomoSlot(item)
    return
  end
  if slot >= InventorySlotPurse then return end

  -- BLOCKED: right slot is mirror-only. Server cannot place real items here.
  if slot == InventorySlotRight then
    return
  end

  local itemWidget = inventoryPanel:getChildById('slot' .. slot)

  if item then
    itemWidget:setStyle('Item')
    itemWidget:setItem(item)
    itemWidget.itemid = item:getId()
  else
    if slot == 10 then
      refleshNumber(true)
    end
    itemWidget:setStyle(InventorySlotStyles[slot])
    itemWidget:setItem(nil)
  end

  -- Update monk mirror when left hand changes
  if slot == InventorySlotLeft then
    updateMonkMirrorItem(item)
  end

end

function online()
  if inventorySideButton then
    inventorySideButton:show()
    inventorySideButton:raise()
  end
  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()

    local lastCombatControls = g_settings.getNode('LastCombatControls')

    if not table.empty(lastCombatControls) then
      if lastCombatControls[char] then
        g_game.setFightMode(lastCombatControls[char].fightMode)
        g_game.setChaseMode(lastCombatControls[char].chaseMode)
        g_game.setSafeFight(lastCombatControls[char].safeFight)
      end
    end

    -- Initialize monk mirror on game start (todas as classes)
    if isMonkMirrorEnabled() then
      local leftItem = player:getInventoryItem(InventorySlotLeft)
      if leftItem then
        updateMonkMirrorItem(leftItem)
      end
    end
  end

  update()
  refresh()
end

function offline()
  if inventorySideButton then
    inventorySideButton:hide()
  end
  -- limpa o slot da camera e do momo pouch ao sair do jogo, para nao ficar
  -- "fantasma" (item do personagem anterior) ao trocar de personagem
  updateCameraSlot(nil)
  updateMomoSlot(nil)
  monkMirrorItem = nil

  local lastCombatControls = g_settings.getNode('LastCombatControls')
  if not lastCombatControls then
    lastCombatControls = {}
  end

  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    lastCombatControls[char] = {
      fightMode = g_game.getFightMode(),
      chaseMode = g_game.getChaseMode(),
      safeFight = g_game.isSafeFight()
    }

    -- save last combat control settings
    g_settings.setNode('LastCombatControls', lastCombatControls)
  end
end

function onSetFightMode(self, selectedFightButton)
  if selectedFightButton == nil then return end
  local buttonId = selectedFightButton:getId()
  local fightMode
  if buttonId == 'fightOffensiveBox' then
    fightMode = FightOffensive
  elseif buttonId == 'fightBalancedBox' then
    fightMode = FightBalanced
  else
    fightMode = FightDefensive
  end
  g_game.setFightMode(fightMode)
end

function onSetChaseMode(self, checked)
  local chaseMode
  if checked then
    chaseMode = ChaseOpponent
  else
    chaseMode = DontChase
  end
  g_game.setChaseMode(chaseMode)
end

function onSetSafeFight(self, checked)
  g_game.setSafeFight(not checked)
end

function update()
  local fightMode = g_game.getFightMode()
  if fightMode == FightOffensive then
    fightModeRadioGroup:selectWidget(fightOffensiveBox)
  elseif fightMode == FightBalanced then
    fightModeRadioGroup:selectWidget(fightBalancedBox)
  else
    fightModeRadioGroup:selectWidget(fightDefensiveBox)
  end

  local chaseMode = g_game.getChaseMode()
  chaseModeButton:setChecked(chaseMode == ChaseOpponent)

  local safeFight = g_game.isSafeFight()
  safeFightButton:setChecked(not safeFight)
end

function check()
  if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
    g_game.setChaseMode(DontChase)
  end
end

--fim--