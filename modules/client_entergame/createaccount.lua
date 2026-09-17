CreateAccount = {}

local createWindow
local protocolLogin
local createBox

-- Avatar vocations (data/XML/vocations.xml): 1=fire, 2=water, 3=air, 4=earth
local VOCATIONS = {
  { text = 'Fogo',  id = 1 },
  { text = 'Agua',  id = 2 },
  { text = 'Ar',    id = 3 },
  { text = 'Terra', id = 4 },
}

-- the login server answers account creation with opcode 0x0A (same as an error);
-- success messages are prefixed with "OK|" by the server (protocollogin.cpp).
local function onCreateResult(protocol, message, errorCode)
  if not protocolLogin then return end -- guard against the socket-close firing twice
  protocolLogin = nil

  if createBox then
    createBox:destroy()
    createBox = nil
  end

  if message:sub(1, 3) == 'OK|' then
    createWindow:hide()
    local infoBox = displayInfoBox(tr('Conta criada'), message:sub(4))
    connect(infoBox, { onOk = function() EnterGame.show() end })
  else
    local errorBox = displayErrorBox(tr('Erro ao criar conta'), message)
    connect(errorBox, { onOk = function() CreateAccount.show() end })
  end
end

function CreateAccount.init()
  createWindow = g_ui.displayUI('createaccount')
  createWindow:hide()

  local sexBox = createWindow:getChildById('sexBox')
  sexBox:addOption(tr('Masculino'))
  sexBox:addOption(tr('Feminino'))
  sexBox:setCurrentOption(tr('Masculino'))

  local vocBox = createWindow:getChildById('vocBox')
  for _, voc in ipairs(VOCATIONS) do
    vocBox:addOption(voc.text)
  end
  vocBox:setCurrentOption(VOCATIONS[1].text)
end

function CreateAccount.terminate()
  if protocolLogin then
    protocolLogin:cancelLogin()
    protocolLogin = nil
  end
  if createBox then
    createBox:destroy()
    createBox = nil
  end
  if createWindow then
    createWindow:destroy()
    createWindow = nil
  end
  CreateAccount = nil
end

function CreateAccount.show()
  EnterGame.hide()
  createWindow:show()
  createWindow:raise()
  createWindow:focus()
end

function CreateAccount.hide()
  createWindow:hide()
  EnterGame.show()
end

function CreateAccount.doCreate()
  local account = createWindow:getChildById('accountName'):getText()
  local password = createWindow:getChildById('password'):getText()
  local passwordConfirm = createWindow:getChildById('passwordConfirm'):getText()
  local charName = createWindow:getChildById('characterName'):getText()
  local sex = (createWindow:getChildById('sexBox'):getText() == tr('Feminino')) and 0 or 1

  local vocText = createWindow:getChildById('vocBox'):getText()
  local vocation = 1
  for _, voc in ipairs(VOCATIONS) do
    if voc.text == vocText then vocation = voc.id break end
  end

  if account:len() < 3 then
    displayErrorBox(tr('Erro'), tr('O nome da conta deve ter no minimo 3 caracteres.'))
    return
  end
  if password:len() < 3 then
    displayErrorBox(tr('Erro'), tr('A senha deve ter no minimo 3 caracteres.'))
    return
  end
  if password ~= passwordConfirm then
    displayErrorBox(tr('Erro'), tr('As senhas nao conferem.'))
    return
  end
  if charName:len() < 3 then
    displayErrorBox(tr('Erro'), tr('O nome do personagem deve ter no minimo 3 caracteres.'))
    return
  end

  local host, port = EnterGame.getHostPort()
  if not host or not port or port == 0 then
    displayErrorBox(tr('Erro'), tr('Selecione um mundo valido na tela de login.'))
    return
  end

  local clientVersion = 860
  g_game.chooseRsa(host)
  g_game.setClientVersion(clientVersion)
  g_game.setProtocolVersion(g_game.getProtocolVersionForClient(clientVersion))

  if not modules.game_things.isLoaded() then
    displayErrorBox(tr('Erro'), tr('Os dados do jogo ainda nao foram carregados.'))
    return
  end

  createWindow:hide()
  createBox = displayCancelBox(tr('Por favor aguarde'), tr('Criando conta...'))
  connect(createBox, { onCancel = function()
                                    createBox = nil
                                    if protocolLogin then protocolLogin:cancelLogin() protocolLogin = nil end
                                    CreateAccount.show()
                                  end })

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onCreateResult
  protocolLogin:createAccount(host, port, account, password, charName, sex, vocation)
end
