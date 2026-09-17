function init()
  castButton = modules.client_topmenu.addRightGameButton('castButton', tr('Gerenciar TV System'), '/images/topbuttons/cast', toggle, true)

  castSenha = g_ui.displayUI('castsenha')
  castKick = g_ui.displayUI('castkick')
  castBan = g_ui.displayUI('castban')
  castUnban = g_ui.displayUI('castunban')
  castMute = g_ui.displayUI('castmute')
  castUnmute = g_ui.displayUI('castunmute')

  castSenha:hide()
  castKick:hide()
  castBan:hide()
  castUnban:hide()
  castMute:hide()
  castUnmute:hide()
end

function terminate()
  if castButton then
    castButton:destroy()
    castButton = nil
  end
  castCancel()
  if castSenha then castSenha:destroy() castSenha = nil end
  if castKick then castKick:destroy() castKick = nil end
  if castBan then castBan:destroy() castBan = nil end
  if castUnban then castUnban:destroy() castUnban = nil end
  if castMute then castMute:destroy() castMute = nil end
  if castUnmute then castUnmute:destroy() castUnmute = nil end
end

local function castTalk(cmd)
  if not g_game.isOnline() then
    return
  end
  g_game.talk(cmd)
end

function toggle()
  local menu = g_ui.createWidget('PopupMenu')
  menu:addOption(tr("Proteger a TV com Senha"), function() castSenha:show() castSenha:raise() castSenha:focus() end)
  menu:addOption(tr("Remover a Senha da TV"), function() castTalk("/cast password off") end)
  menu:addSeparator()
  menu:addOption(tr("Expulsar Espectador da TV"), function() castKick:show() castKick:raise() castKick:focus() end)
  menu:addOption(tr("Banir Espectador da TV"), function() castBan:show() castBan:raise() castBan:focus() end)
  menu:addSeparator()
  menu:addOption(tr("Desbanir Espectador da TV"), function() castUnban:show() castUnban:raise() castUnban:focus() end)
  menu:addOption(tr("Espectadores Banidos da TV"), function() castTalk("/cast bans") end)
  menu:addSeparator()
  menu:addOption(tr("Mutar Espectador da TV"), function() castMute:show() castMute:raise() castMute:focus() end)
  menu:addOption(tr("Desmutar Espectador da TV"), function() castUnmute:show() castUnmute:raise() castUnmute:focus() end)
  menu:addSeparator()
  menu:addOption(tr("Espectadores Mutados da TV"), function() castTalk("/cast mutes") end)
  menu:addOption(tr("Qtd. de Espectadores Online na TV"), function() castTalk("/cast show") end)
  menu:addOption(tr("Status da TV"), function() castTalk("/cast status") end)
  menu:display()
end

function senhaCast()
  local text = castSenha:getChildById('senhaCastText'):getText()
  castTalk('/cast password ' .. text)
  castSenha:hide()
end

function kickCast()
  local text = castKick:getChildById('kickCastText'):getText()
  castTalk('/cast kick ' .. text)
  castKick:hide()
end

function banCast()
  local text = castBan:getChildById('banCastText'):getText()
  castTalk('/cast ban ' .. text)
  castBan:hide()
end

function unbanCast()
  local text = castUnban:getChildById('unbanCastText'):getText()
  castTalk('/cast unban ' .. text)
  castUnban:hide()
end

function muteCast()
  local text = castMute:getChildById('muteCastText'):getText()
  castTalk('/cast mute ' .. text)
  castMute:hide()
end

function unmuteCast()
  local text = castUnmute:getChildById('unmuteCastText'):getText()
  castTalk('/cast unmute ' .. text)
  castUnmute:hide()
end

function castCancel()
  if castSenha then castSenha:hide() end
  if castKick then castKick:hide() end
  if castBan then castBan:hide() end
  if castUnban then castUnban:hide() end
  if castMute then castMute:hide() end
  if castUnmute then castUnmute:hide() end
end
