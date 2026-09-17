-- ============================================================================
-- PET (criatura fantasma)
-- ----------------------------------------------------------------------------
-- Janela identica a de escolher outfit: cicla pelos pets que o jogador possui
-- (lista vinda do servidor, definida em data/XML/pets.xml), mostra o preview
-- na criatura virtual e envia a escolha pro servidor.
--
-- O pet em si e uma criatura puramente visual: nao toma dano, nao ataca, nao
-- bloqueia passagem e nao pode ser clicado. Veja g_game.changePet.
-- ============================================================================

petWindow = nil
petPreviewCreature = nil
petList = {}
currentPet = 1

function init()
  connect(g_game, { onOpenPetWindow = create,
                    onGameEnd = destroy })
end

function terminate()
  disconnect(g_game, { onOpenPetWindow = create,
                       onGameEnd = destroy })
  destroy()
end

-- aberta pelo menu de contexto (ctrl + botao direito em voce mesmo) ou via
-- g_game.requestPet()
function create(currentPetClientId, list, previewCreature)
  if petWindow and not petWindow:isHidden() then
    return
  end

  destroy()

  petList = list or {}
  petPreviewCreature = previewCreature
  petWindow = g_ui.displayUI('petwindow')

  local petCreatureBox = petWindow:getChildById('petCreatureBox')
  local petName = petWindow:getChildById('petName')
  local petNextButton = petWindow:getChildById('petNextButton')
  local petPrevButton = petWindow:getChildById('petPrevButton')
  local petOkButton = petWindow:getChildById('petOkButton')
  local petRemoveButton = petWindow:getChildById('petRemoveButton')

  currentPet = 1
  for i = 1, #petList do
    if petList[i][1] == currentPetClientId then
      currentPet = i
      break
    end
  end

  if #petList == 0 then
    -- jogador nao tem nenhum pet: esconde o preview e os botoes de acao
    petCreatureBox:hide()
    petNextButton:hide()
    petPrevButton:hide()
    petOkButton:hide()
    petRemoveButton:hide()
    petName:setText(tr('You do not own any pet') .. ' ' .. tr('Buy one in the Store (Pets).'))
    return
  end

  if petPreviewCreature then
    petCreatureBox:setCreature(petPreviewCreature)
  else
    petCreatureBox:hide()
  end

  updatePet()
end

function destroy()
  if petWindow then
    petWindow:destroy()
    petWindow = nil
    petPreviewCreature = nil
  end
end

function accept()
  if petWindow and #petList > 0 then
    g_game.changePet(petList[currentPet][1])
  end
  destroy()
end

function removePet()
  g_game.changePet(0)
  destroy()
end

function nextPet()
  if #petList == 0 then
    return
  end

  currentPet = currentPet + 1
  if currentPet > #petList then
    currentPet = 1
  end
  updatePet()
end

function previousPet()
  if #petList == 0 then
    return
  end

  currentPet = currentPet - 1
  if currentPet <= 0 then
    currentPet = #petList
  end
  updatePet()
end

function updatePet()
  if not petWindow or #petList == 0 then
    return
  end

  local clientId = petList[currentPet][1]
  local name = petList[currentPet][2]

  local nameWidget = petWindow:getChildById('petName')
  if nameWidget then
    if name and #name > 0 then
      nameWidget:setText(name)
    else
      nameWidget:setText(tr('Pet') .. ' ' .. tostring(clientId))
    end
  end

  if petPreviewCreature then
    petPreviewCreature:setOutfit({ type = clientId, head = 0, body = 0, legs = 0, feet = 0, addons = 0, mount = 0 })
  end
end

-- chamado por outros modulos que querem abrir a janela
function toggle()
  if petWindow then
    destroy()
  else
    g_game.requestPet()
  end
end
