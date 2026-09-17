function init()
  
   marketButton = modules.client_topmenu.addRightGameButton('marketButton', tr('Market'), '/images/topbuttons/shop', toggle, true)

  marketBuy = g_ui.displayUI('marketBuy')
  marketAdd = g_ui.displayUI('marketAdd')
  marketRemove = g_ui.displayUI('marketRemove')

  g_keyboard.bindKeyDown('Escape', marketCancel)
end

function toggle()
  local menu = g_ui.createWidget('PopupMenu')
  menu:addOption("Ver ofertas", function() modules.game_textmessage.displayGameMessage("Veja as ofertas em: www.tibiaavatar.com/?subtopic=market") end)
  menu:addOption("Comprar item", function() marketBuy:setVisible(true) end)
  menu:addOption("Adicionar oferta", function() marketAdd:setVisible(true) end)
  menu:addOption("Remover oferta", function() marketRemove:setVisible(true) end)
  menu:display()
end


function addMarket()
  local text1 = marketAdd:getChildById('addMarketText1'):getText()
  local text2 = marketAdd:getChildById('addMarketText2'):getText()
  local text3 = marketAdd:getChildById('addMarketText3'):getText()
  g_game.talk('!offer add, ' .. text1 .. ', ' .. text3 .. ', ' .. text2)
  marketAdd:setVisible(false)
end

function buyMarket()
  local text = marketBuy:getChildById('buyMarketText1'):getText()
  g_game.talk('!offer buy, ' .. text)
  marketBuy:setVisible(false)
end

function removeMarket()
  local text = marketRemove:getChildById('removeMarketText1'):getText()
  g_game.talk('!offer remove, ' .. text)
  marketRemove:setVisible(false)
end

function marketCancel()
  marketBuy:setVisible(false)
  marketAdd:setVisible(false)
  marketRemove:setVisible(false)
end
