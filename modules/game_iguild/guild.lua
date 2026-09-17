function init()
  --guildButton = modules.client_topmenu.addLeftGameToggleButton('guildButton', tr('Guild'), '/modules/game_guild/img/guild', toggle, true)
  --guildButton:setOn(true)
  
   guildButton = modules.client_topmenu.addRightGameButton('guildButton', tr('Gerenciar Guild'), '/images/topbuttons/guild', toggle, true)

  guildCreate = g_ui.displayUI('guildcreate')
  guildInvite = g_ui.displayUI('guildinvite')
  guildJoin = g_ui.displayUI('guildjoin')
  guildLeave = g_ui.displayUI('guildleave')
  guildKick = g_ui.displayUI('guildkick')
  guildRevoke = g_ui.displayUI('guildrevoke')
  guildPromote = g_ui.displayUI('guildpromote')
  guildDemote = g_ui.displayUI('guilddemote')
  guildNick = g_ui.displayUI('guildnick')
  guildRankName = g_ui.displayUI('guildrankname')
  guildPassLeader = g_ui.displayUI('guildpassleader')
  guildDisband = g_ui.displayUI('guilddisband')
  guildWarinvite = g_ui.displayUI('guildwarinvite')
  guildWaraccept = g_ui.displayUI('guildwaraccept')
  guildWarreject = g_ui.displayUI('guildwarreject')
  guildWarcancel = g_ui.displayUI('guildwarcancel')
  guildWarsurrender = g_ui.displayUI('guildwarsurrender')
  guildWardeposit = g_ui.displayUI('guildwardeposit')
  guildWarpick = g_ui.displayUI('guildwarpick')

  g_keyboard.bindKeyDown('Escape', guildCancel)
end

function toggle()
  local menu = g_ui.createWidget('PopupMenu')
  menu:addOption("Criar Guild", function() guildCreate:setVisible(true) end)
  menu:addOption("Excluir Guild", function() guildDisband:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Aceitar Guild", function() guildJoin:setVisible(true) end)
  menu:addOption("Sair da Guild", function() guildLeave:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Convidar Jogador", function() guildInvite:setVisible(true) end)
  menu:addOption("Rescindir Convite", function() guildRevoke:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Promover Jogador", function() guildPromote:setVisible(true) end)
  menu:addOption("Rebaixar Jogador", function() guildDemote:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Alterar Categoria", function() guildRankName:setVisible(true) end)
  menu:addOption("Inserir Nick", function() guildNick:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Remover Jogador", function() guildKick:setVisible(true) end)
  menu:addOption("Passar Comando", function() guildPassLeader:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Invitar para War", function() guildWarinvite:setVisible(true) end)
  menu:addOption("Aceitar Convite para War", function() guildWaraccept:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Rejeitar Convite para War", function() guildWarreject:setVisible(true) end)
  menu:addOption("Cancelar Convite para War", function() guildWarcancel:setVisible(true) end)
  menu:addSeparator()
  menu:addOption("Desistir da War", function() guildWarsurrender:setVisible(true) end)
  menu:addOption(tr("Placar da Guerra"), function() g_game.talkChannel(MessageModes.Channel, 0, "/war placar") end)
  menu:addSeparator()
  menu:addOption(tr("Saldo da Guild"), function() g_game.talkChannel(MessageModes.Channel, 0, "/balance") end)
  menu:addOption("Depositar no Saldo da Guild", function() guildWardeposit:setVisible(true) end)
  menu:addOption("Retirar do Saldo da Guild", function() guildWarpick:setVisible(true) end)
  menu:display()
end

function warinviteGuild()
  local text1 = guildWarinvite:getChildById('warinviteGuildText1'):getText()
  local text2 = guildWarinvite:getChildById('warinviteGuildText2'):getText()
  local text3 = guildWarinvite:getChildById('warinviteGuildText3'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/war invite, ' .. text1 .. ', ' .. text2 .. ', ' .. text3)
  guildWarinvite:setVisible(false)
end

function waracceptGuild()
  local text = guildWaraccept:getChildById('waracceptGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/war accept, ' .. text)
  guildWaraccept:setVisible(false)
end

function warrejectGuild()
  local text = guildWarreject:getChildById('warrejectGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/war reject, ' .. text)
  guildWarreject:setVisible(false)
end

function warcancelGuild()
  local text = guildWarcancel:getChildById('warcancelGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/war cancel, ' .. text)
  guildWarcancel:setVisible(false)
end

function warsurrenderGuild()
  local text = guildWarsurrender:getChildById('warsurrenderGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/war end, ' .. text)
  guildWarsurrender:setVisible(false)
end

function wardepositGuild()
  local text = guildWardeposit:getChildById('wardepositGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/balance donate ' .. text)
  guildWardeposit:setVisible(false)
end

function warpickGuild()
  local text = guildWarpick:getChildById('warpickGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '/balance pick ' .. text)
  guildWarpick:setVisible(false)
end

function nickGuild()
  local text1 = guildNick:getChildById('nickGuildText1'):getText()
  local text2 = guildNick:getChildById('nickGuildText2'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!nick ' .. text1 .. ', ' .. text2)
  guildNick:setVisible(false)
end

function createGuild()
  local text = guildCreate:getChildById('createGuildText'):getText()
  g_game.talk('!createguild ' .. text)
  guildCreate:setVisible(false)
end

function inviteGuild()
  local text = guildInvite:getChildById('inviteGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!invite ' .. text)
  guildInvite:setVisible(false)
end

function joinGuild()
  local text = guildJoin:getChildById('joinGuildText'):getText()
  g_game.talk('!joinguild ' .. text)
  guildJoin:setVisible(false)
end

function leaveGuild()
  g_game.talkChannel(MessageModes.Channel, 0, '!leave')
  guildLeave:setVisible(false)
end

function kickGuild()
  local text = guildKick:getChildById('kickGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!kick ' .. text)
  guildKick:setVisible(false)
end

function revokeGuild()
  local text = guildRevoke:getChildById('revokeGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!revoke ' .. text)
  guildRevoke:setVisible(false)
end

function promoteGuild()
  local text = guildPromote:getChildById('promoteGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!promote ' .. text)
  guildPromote:setVisible(false)
end

function demoteGuild()
  local text = guildDemote:getChildById('demoteGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!demote ' .. text)
  guildDemote:setVisible(false)
end

function rankNameGuild()
  local text1 = guildRankName:getChildById('rankNameGuildText1'):getText()
  local text2 = guildRankName:getChildById('rankNameGuildText2'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!setrankname ' .. text1 .. ', ' .. text2)
  guildRankName:setVisible(false)
end

function passLeaderGuild()
  local text = guildPassLeader:getChildById('passLeaderGuildText'):getText()
  g_game.talkChannel(MessageModes.Channel, 0, '!passleadership ' .. text)
  guildPassLeader:setVisible(false)
end

function disbandGuild()
  g_game.talkChannel(MessageModes.Channel, 0, '!disband')
  guildDisband:setVisible(false)
end

function guildCancel()
  guildCreate:setVisible(false)
  guildInvite:setVisible(false)
  guildJoin:setVisible(false)
  guildLeave:setVisible(false)
  guildKick:setVisible(false)
  guildRevoke:setVisible(false)
  guildPromote:setVisible(false)
  guildDemote:setVisible(false)
  guildNick:setVisible(false)
  guildRankName:setVisible(false)
  guildPassLeader:setVisible(false)
  guildDisband:setVisible(false)
  guildWarinvite:setVisible(false)
  guildWaraccept:setVisible(false)
  guildWarreject:setVisible(false)
  guildWarcancel:setVisible(false)
  guildWarsurrender:setVisible(false)
  guildWardeposit:setVisible(false)
  guildWarpick:setVisible(false)
end
