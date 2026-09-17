dofile("config.lua")
EnterGame = { }

-- private variables
local loadBox
local enterGame
local motdWindow
local motdButton
local enterGameButton
local clientBox
local protocolLogin
local motdEnabled = true

-- private functions
local function onError(protocol, message, errorCode)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if not errorCode then
    EnterGame.clearAccountFields()
  end

  local errorBox = displayErrorBox(tr('Login Error'), message)
  connect(errorBox, { onOk = EnterGame.show })
end

local function onMotd(protocol, motd)
  G.motdNumber = tonumber(motd:sub(0, motd:find("\n")))
  G.motdMessage = motd:sub(motd:find("\n") + 1, #motd)
  if motdEnabled then
    motdButton:show()
  end
end

local function onCharacterList(protocol, characters, account, otui)
  -- Try add server to the server list
  ServerList.add(G.host, G.port, g_game.getProtocolVersion())

  if enterGame:getChildById('rememberPasswordBox'):isChecked() then
    local account = g_crypt.encrypt(G.account)
    local password = g_crypt.encrypt(G.password)

    g_settings.set('account', account)
    g_settings.set('password', password)

    ServerList.setServerAccount(G.host, account)
    ServerList.setServerPassword(G.host, password)
    -- (o antigo checkbox "Entrar automaticamente" foi removido da tela, por isso
    --  nao guardamos mais o 'autologin' nas settings)
  else
    -- reset server list account/password
    ServerList.setServerAccount(G.host, '')
    ServerList.setServerPassword(G.host, '')

    EnterGame.clearAccountFields()
  end

  loadBox:destroy()
  loadBox = nil

  CharacterList.create(characters, account, otui)
  CharacterList.show()

  if motdEnabled then
    local lastMotdNumber = g_settings.getNumber("motd")
    if G.motdNumber and G.motdNumber ~= lastMotdNumber then
      g_settings.set("motd", motdNumber)
      motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
      connect(motdWindow, { onOk = function() CharacterList.show() motdWindow = nil end })
      CharacterList.hide()
    end
  end
end

local function onUpdateNeeded(protocol, signature)
  loadBox:destroy()
  loadBox = nil

  if EnterGame.updateFunc then
    local continueFunc = EnterGame.show
    local cancelFunc = EnterGame.show
    EnterGame.updateFunc(signature, continueFunc, cancelFunc)
  else
    local errorBox = displayErrorBox(tr('Update needed'), tr('Your client needs update, try redownloading it.'))
    connect(errorBox, { onOk = EnterGame.show })
  end
end

-- public functions
function EnterGame.init()
  enterGame = g_ui.displayUI('entergame')
  enterGameButton = modules.client_topmenu.addLeftButton('enterGameButton', tr('Login') .. ' (Ctrl+G)', '/images/topbuttons/login', EnterGame.openWindow)
  motdButton = modules.client_topmenu.addLeftButton('motdButton', tr('Message of the day'), '/images/topbuttons/motd', EnterGame.displayMotd)
  motdButton:hide()
  g_keyboard.bindKeyDown('Ctrl+G', EnterGame.openWindow)

  if motdEnabled and G.motdNumber then
    motdButton:show()
  end

  local account = g_settings.get('account')
  local password = g_settings.get('password')
  local host = g_settings.get('host')
  local port = g_settings.get('port')
  local clientVersion = g_settings.getInteger('client-version')
  if clientVersion == 0 then clientVersion = 860 end

  if port == nil or port == 0 then port = 7171 end
  -- local testing: default to the local server when no host was saved
  if host == nil or #host == 0 then host = "127.0.0.1" end

  EnterGame.setAccountName(account)
  EnterGame.setPassword(password)

  enterGame:getChildById('serverHostTextEdit'):setText(host)
  enterGame:getChildById('serverPortTextEdit'):setText(port)

  clientBox = enterGame:getChildById('clientComboBox')
  for _, proto in pairs(g_game.getSupportedClients()) do
    clientBox:addOption(proto)
  end
  clientBox:setCurrentOption(clientVersion)

  enterGame:hide()

  -- A tela de login tem DOIS caminhos de abertura: o startup do modulo "client"
  -- (evento g_app.onRun, em modules/client/client.lua) e este aqui. O onRun so'
  -- dispara uma vez por processo, entao num reload de modulos (Ctrl+Shift+Z,
  -- troca de idioma) aquele caminho nao roda de novo e o jogador ficava sem
  -- tela de login - so' voltava fechando e abrindo o client.
  EnterGame.showIfNeeded()

  -- Rede de seguranca: se ainda nao deu pra mostrar agora (o app pode nao estar
  -- rodando durante o load inicial), tenta de novo daqui a pouco. showIfNeeded
  -- nao mostra nada quando o jogador esta online, na lista de personagens ou na
  -- tela de carregamento.
  scheduleEvent(function() EnterGame.showIfNeeded() end, 1000)

  g_keyboard.bindKeyDown("CTRL+SHIFT+T", setTestServer)
end

local isTest = false

function setTestServer()
    if not isTest then
        EnterGame.setUniqueServer("127.0.0.1", 9192, 860, windowWidth, windowHeight)
        isTest = true
    else
        EnterGame.setUniqueServer("127.0.0.1", 9191, 860, windowWidth, windowHeight)
        isTest = false
    end

    enterGame:getChildById("testLogin"):setVisible(isTest) 
end

function EnterGame.firstShow()
  EnterGame.show()
end

function EnterGame.terminate()
  g_keyboard.unbindKeyDown('Ctrl+G')
  g_keyboard.unbindKeyDown('CTRL+SHIFT+T')

  enterGame:destroy()
  enterGame = nil
  enterGameButton:destroy()
  enterGameButton = nil
  clientBox = nil
  if motdWindow then
    motdWindow:destroy()
    motdWindow = nil
  end
  if motdButton then
    motdButton:destroy()
    motdButton = nil
  end
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  if protocolLogin then
    protocolLogin:cancelLogin()
    protocolLogin = nil
  end
  EnterGame = nil
end

function EnterGame.show()
  if loadBox then return end
  enterGame:show()
  enterGame:raise()
  enterGame:focus()
end

-- Mostra a tela de login quando ela e' devida: client rodando, fora do jogo e
-- sem outra janela de entrada na frente (lista de personagens ou tela de
-- carregamento). Idempotente: chamar varias vezes nao muda nada.
function EnterGame.showIfNeeded()
  if not enterGame or not g_app.isRunning() then
    return false
  end
  if g_game.isOnline() or g_game.isLogging() then
    return false
  end
  if loadBox then
    return false
  end
  if CharacterList and CharacterList.isVisible and CharacterList.isVisible() then
    return false
  end
  if modules.client_loading and modules.client_loading.isVisible and modules.client_loading.isVisible() then
    return false
  end
  if enterGame:isVisible() then
    return true
  end

  EnterGame.show()
  return true
end

function EnterGame.hide()
  enterGame:hide()
end

-- Host/porta do mundo unico do client (config.lua). Usado pelo login e pela
-- janela de criacao de conta. Antes isso vinha do combo de mundos; agora nao ha'
-- escolha, entao lemos a unica entrada da lista 'servers'.
function EnterGame.getHostPort()
  local world = servers and servers[1]
  local host = enterGame:getChildById('serverHostTextEdit'):getText()
  if host == nil or #host == 0 then host = "127.0.0.1" end
  local port
  if world then
    if world.port and world.port > 0 then port = world.port end
    if world.host then host = world.host end
  end
  return host, port
end

function EnterGame.openWindow()
  if g_game.isOnline() then
    CharacterList.show()
  elseif not g_game.isLogging() and not CharacterList.isVisible() then
    EnterGame.show()
  end
end

function EnterGame.setAccountName(account)
  local account = g_crypt.decrypt(account)
  enterGame:getChildById('accountNameTextEdit'):setText(account)
  enterGame:getChildById('accountNameTextEdit'):setCursorPos(-1)
  enterGame:getChildById('rememberPasswordBox'):setChecked(#account > 0)
end

function EnterGame.setPassword(password)
  local password = g_crypt.decrypt(password)
  enterGame:getChildById('accountPasswordTextEdit'):setText(password)
end

function EnterGame.clearAccountFields()
  enterGame:getChildById('accountNameTextEdit'):clearText()
  enterGame:getChildById('accountPasswordTextEdit'):clearText()
  enterGame:getChildById('accountNameTextEdit'):focus()
  g_settings.remove('account')
  g_settings.remove('password')
end

function EnterGame.doLogin()
  G.account = enterGame:getChildById('accountNameTextEdit'):getText()
  G.password = enterGame:getChildById('accountPasswordTextEdit'):getText()
  G.host = enterGame:getChildById('serverHostTextEdit'):getText()

  -- mundo unico (config.lua): sem combo, a porta vem da unica entrada da lista
  local world = servers and servers[1]
  if not world or not world.port or world.port <= 0 then
      local errorBox = displayErrorBox(tr('Login Error'), tr('Select a valid server in list to join.'))
      EnterGame.hide()
      connect(errorBox, { onOk = EnterGame.show })
      return
  end
  G.port = world.port
  -- o mundo pode fixar o proprio host (ex.: Local -> 127.0.0.1); sem isso vale
  -- o host digitado/salvo no campo
  if world.host then G.host = world.host end


  local clientVersion = tonumber(clientBox:getText())
  EnterGame.hide()

  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
    connect(errorBox, { onOk = EnterGame.show })
    return
  end

  g_settings.set('host', G.host)
  g_settings.set('port', G.port)
  g_settings.set('client-version', clientVersion) 

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onError
  protocolLogin.onMotd = onMotd
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded = onUpdateNeeded

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  protocolLogin:cancelLogin()
                                  EnterGame.show()
                                end })

  g_game.chooseRsa(G.host)
  g_game.setClientVersion(clientVersion)
  g_game.setProtocolVersion(g_game.getProtocolVersionForClient(clientVersion))

  if modules.game_things.isLoaded() then
    protocolLogin:login(G.host, G.port, G.account, G.password)
  else
    loadBox:destroy()
    loadBox = nil
    EnterGame.show()
  end
end

function EnterGame.cast()
  G.account  = ''
  G.password = ''
  G.host = enterGame:getChildById('serverHostTextEdit'):getText()

  -- mundo unico (config.lua): sem combo, a porta vem da unica entrada da lista
  local world = servers and servers[1]
  if not world or not world.port or world.port <= 0 then
      local errorBox = displayErrorBox(tr('Login Error'), tr('Select a valid server in list to join.'))
      EnterGame.hide()
      connect(errorBox, { onOk = EnterGame.show })
      return
  end
  G.port = world.port
  -- o mundo pode fixar o proprio host (ex.: Local -> 127.0.0.1); sem isso vale
  -- o host digitado/salvo no campo
  if world.host then G.host = world.host end


  local clientVersion = tonumber(clientBox:getText())
  EnterGame.hide()

  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
    connect(errorBox, { onOk = EnterGame.show })
    return
  end

  g_settings.set('host', G.host)
  g_settings.set('port', G.port)
  g_settings.set('client-version', clientVersion) 

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onError
  protocolLogin.onMotd = onMotd
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded = onUpdateNeeded

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  protocolLogin:cancelLogin()
                                  EnterGame.show()
                                end })

  g_game.chooseRsa(G.host)
  g_game.setClientVersion(clientVersion)
  g_game.setProtocolVersion(g_game.getProtocolVersionForClient(clientVersion))

  if modules.game_things.isLoaded() then
    protocolLogin:login(G.host, G.port, G.account, G.password)
  else
    loadBox:destroy()
    loadBox = nil
    EnterGame.show()
  end
end

function EnterGame.displayMotd()
  if not motdWindow then
    motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
    motdWindow.onOk = function() motdWindow = nil end
  end
end

function EnterGame.setDefaultServer(host, port, protocol)
  local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
  local portTextEdit = enterGame:getChildById('serverPortTextEdit')
  local clientLabel = enterGame:getChildById('clientLabel')
  local accountTextEdit = enterGame:getChildById('accountNameTextEdit')
  local passwordTextEdit = enterGame:getChildById('accountPasswordTextEdit')

  if hostTextEdit:getText() ~= host then
    hostTextEdit:setText(host)
    portTextEdit:setText(port)
    clientBox:setCurrentOption(protocol)
    accountTextEdit:setText('')
    passwordTextEdit:setText('')
  end
end

function EnterGame.setUniqueServer(host, port, protocol, windowWidth, windowHeight)
  local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
  hostTextEdit:setText(host)
  hostTextEdit:setVisible(false)
  hostTextEdit:setHeight(0)
  local portTextEdit = enterGame:getChildById('serverPortTextEdit')
  portTextEdit:setText(port)
  portTextEdit:setVisible(false)
  portTextEdit:setHeight(0)

  clientBox:setCurrentOption(protocol)
  clientBox:setVisible(false)
  clientBox:setHeight(0)

  local serverLabel = enterGame:getChildById('serverLabel')
  serverLabel:setVisible(false)
  serverLabel:setHeight(0)
  local portLabel = enterGame:getChildById('portLabel')
  portLabel:setVisible(false)
  portLabel:setHeight(0)
  local clientLabel = enterGame:getChildById('clientLabel')
  clientLabel:setVisible(false)
  clientLabel:setHeight(0)

  local serverListButton = enterGame:getChildById('serverListButton')
  serverListButton:setVisible(false)
  serverListButton:setHeight(0)
  serverListButton:setWidth(0)

  -- O checkbox fica logo abaixo das linhas escondidas acima (que tem altura 0),
  -- entao a margem aqui e' um ajuste fino da posicao dele: 13 = 18 px mais
  -- baixo do que estava (-5), dividindo com a fileira de botoes o espaco que
  -- sobrou das linhas removidas da tela (ver o comentario da fileira no
  -- entergame.otui).
  local rememberPasswordBox = enterGame:getChildById('rememberPasswordBox')
  rememberPasswordBox:setMarginTop(13)

  if not windowWidth then windowWidth = 380 end
  enterGame:setWidth(windowWidth)
  if not windowHeight then windowHeight = 480 end
  enterGame:setHeight(windowHeight)
end

function EnterGame.setServerInfo(message)
  local label = enterGame:getChildById('serverInfoLabel')
  label:setText(message)
end

function EnterGame.disableMotd()
  motdEnabled = false
  motdButton:hide()
end
