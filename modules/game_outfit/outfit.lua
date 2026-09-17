outfitWindow = nil
outfit = nil
outfits = nil
outfitCreature = nil
currentOutfit = 1

function init()
  connect(g_game, { onOpenOutfitWindow = create,
                    onGameEnd = destroy })
end

function terminate()
  disconnect(g_game, { onOpenOutfitWindow = create,
                       onGameEnd = destroy })
  destroy()
end

function create(creatureOutfit, outfitList, creatureMount, mountList)
  if outfitWindow and not outfitWindow:isHidden() then
    return
  end

  outfitCreature = creatureOutfit
  outfits = outfitList or {}
  destroy()

  outfitWindow = g_ui.displayUI('outfitwindow')

  local outfitCreatureBox = outfitWindow:getChildById('outfitCreatureBox')
  if outfitCreature then
    outfit = outfitCreature:getOutfit()
    outfitCreatureBox:setCreature(outfitCreature)
  else
    outfitCreatureBox:hide()
    outfitWindow:getChildById('outfitName'):hide()
    outfitWindow:getChildById('outfitNextButton'):hide()
    outfitWindow:getChildById('outfitPrevButton'):hide()
  end

  currentOutfit = 1
  for i = 1, #outfits do
    if outfit and outfits[i][1] == outfit.type then
      currentOutfit = i
      break
    end
  end

  updateOutfit()
end

function destroy()
  if outfitWindow then
    outfitWindow:destroy()
    outfitWindow = nil
    outfitCreature = nil
  end
end

function accept()
  if outfit then
    g_game.changeOutfit(outfit)
  end
  destroy()
end

function nextOutfitType()
  if not outfits or #outfits == 0 then
    return
  end
  currentOutfit = currentOutfit + 1
  if currentOutfit > #outfits then
    currentOutfit = 1
  end
  updateOutfit()
end

function previousOutfitType()
  if not outfits or #outfits == 0 then
    return
  end
  currentOutfit = currentOutfit - 1
  if currentOutfit <= 0 then
    currentOutfit = #outfits
  end
  updateOutfit()
end

function updateOutfit()
  if not outfits or #outfits == 0 or not outfit or not outfitCreature then
    return
  end

  local nameWidget = outfitWindow:getChildById('outfitName')
  local name = outfits[currentOutfit][2]
  if name and #name > 0 then
    nameWidget:setText(name)
  else
    nameWidget:setText(tr('Outfit') .. ' ' .. tostring(outfits[currentOutfit][1]))
  end

  outfit.type = outfits[currentOutfit][1]
  if outfits[currentOutfit][3] then
    outfit.addons = outfits[currentOutfit][3]
  end
  outfitCreature:setOutfit(outfit)
end
