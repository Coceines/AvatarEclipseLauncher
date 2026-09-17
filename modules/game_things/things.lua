-- =============================================================================
-- DAT / SPR features
-- Ligue SOMENTE se o seu .dat foi exportado com essas op��es (Object Builder).
-- Se o DAT for cl�ssico 8.6 SEM essas flags, deixe false � sen�o o load corrompe.
-- Frame Groups e Improved Animations s�o do formato do .DAT (n�o do .SPR em si).
-- =============================================================================
USE_ENHANCED_ANIMATIONS = true -- Improved Animations (Animator no DAT)
USE_FRAME_GROUPS = true        -- Frame Groups / Idle Animations (creatures)

filename = nil
loaded = false

function init()
  connect(g_game, { onClientVersionChange = load })
end

function terminate()
  disconnect(g_game, { onClientVersionChange = load })
end

function setFileName(name)
  filename = name
end

function isLoaded()
  return loaded
end

function load()
  local version = g_game.getClientVersion()
  g_game.enableFeature(GameBlueNpcNameColor)

  g_game.enableFeature(GameSpritesU32)
  g_game.enableFeature(GameSpritesAlphaChannel)
  g_game.enableFeature(GamePlayerMounts) -- Avatar custom: server sends mount in outfit
  g_game.enableFeature(GameWingsAndAura)
  g_game.enableFeature(GameOutfitShaders)

  -- Render (obrigatorio com asas/auras grandes): o chao e desenhado antes de
  -- itens e criaturas, senao o chao do tile da frente corta a parte de baixo dos
  -- outfits grandes. Com a flag ligada, paredes e itens "on bottom" voltam para
  -- a camada de objetos (desenhados junto das criaturas, tile a tile), que e o
  -- que mantem criaturas atras de uma parede escondidas por ela.
  g_game.enableFeature(GameMapDrawGroundFirst)

  -- Canonical protocol 8.60 feature set (matches the original Avatar client, whose
  -- engine enabled these in C++). The Beta modules only enabled a minimal subset,
  -- which broke the login/game handshake against the TFS 0.4 server.
  -- >= 770
  g_game.enableFeature(GameLooktypeU16)
  -- Raava/Avatar SEMPRE envia statementId (U32) em AddCreatureSpeak � obrigat�rio.
  g_game.enableFeature(GameMessageStatements)
  g_game.enableFeature(GameLoginPacketEncryption)
  -- >= 780
  g_game.enableFeature(GamePlayerAddons)
  g_game.enableFeature(GamePlayerStamina)
  g_game.enableFeature(GameNewFluids)
  g_game.enableFeature(GameMessageLevel)
  g_game.enableFeature(GamePlayerStateU16)
  g_game.enableFeature(GameNewOutfitProtocol)
  -- >= 790
  g_game.enableFeature(GameWritableDate)
  -- >= 840
  g_game.enableFeature(GameProtocolChecksum)
  g_game.enableFeature(GameAccountNames)
  g_game.enableFeature(GameDoubleFreeCapacity)
  -- >= 841
  g_game.enableFeature(GameChallengeOnLogin)
  g_game.enableFeature(GameMessageSizeCheck)
  g_game.enableFeature(GameTileAddThingWithStackpos)
  -- >= 854
  g_game.enableFeature(GameCreatureEmblems)
  -- >= 860
  g_game.enableFeature(GameAttackSeq)

  -- DAT format extras (must be set BEFORE loadDat)
  if USE_ENHANCED_ANIMATIONS then
    g_game.enableFeature(GameEnhancedAnimations)
  end
  if USE_FRAME_GROUPS then
    g_game.enableFeature(GameIdleAnimations)
  end

  -- Keep the downloaded full-world map in memory: without this the client
  -- erases every tile outside the camera when the player walks, which would
  -- throw away the whole map download (and the smoothness with it).
  g_game.enableFeature(GameKeepUnawareTiles)

  local datPath, sprPath
  if filename then
    datPath = resolvepath('/modules/corelib/ui/zUniD')
    sprPath = resolvepath('/modules/corelib/ui/zUniD')
  else
    datPath = resolvepath('/modules/corelib/ui/zUniD')
    sprPath = resolvepath('/modules/corelib/ui/zUniD')
  end

  local errorMessage = ''
  if not g_things.loadDat(datPath) then
    errorMessage = errorMessage .. tr("Unable to load dat file, please place a valid dat in '%s'", datPath) .. '\n'
  end
  if not g_sprites.loadSpr(sprPath) then
    errorMessage = errorMessage .. tr("Unable to load spr file, please place a valid spr in '%s'", sprPath)
  end

  -- OTML overrides (opacity etc.) MUST run after DAT is loaded, otherwise every
  -- effect/missile/item id logs "invalid thing type client id X in category Y".
  if errorMessage:len() == 0 then
    g_things.loadOtml('/things/things.otml')

    -- NOTE: the full texture preload is now triggered by the loading screen
    -- (modules/client_loading) right after the player picks a character, and it
    -- holds the login until everything is loaded.
  end

  -- Global helper: ItemType(id) � SakkenOT pattern. Without OTB the lookup
  -- returns null (handled gracefully via isNull()), but the C++ binding
  -- g_lua.bindGlobalFunction("ItemType", ...) stays in the source for future use.
  -- Prevent registerClass<ItemType>() table from shadowing the function.
  if type(ItemType) ~= "function" then
    if g_things.tryGetItemType then
      ItemType = function(id) return g_things.tryGetItemType(id) end
    else
      ItemType = function(id) return g_things.getItemType(id) end
    end
  end

  loaded = (errorMessage:len() == 0)

  if errorMessage:len() > 0 then
    local messageBox = displayErrorBox(tr('Error'), errorMessage)
    addEvent(function() messageBox:raise() messageBox:focus() end)

    disconnect(g_game, { onClientVersionChange = load })
    g_game.setClientVersion(0)
    g_game.setProtocolVersion(0)
    connect(g_game, { onClientVersionChange = load })
  end
end
