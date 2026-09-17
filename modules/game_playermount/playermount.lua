-- online/offline lifecycle handlers were stripped from this custom module but
-- are still referenced by init/terminate; define no-op stubs so they are safe.
function online() end
function offline() end

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  if g_game.isOnline() then online() end
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  offline()
end

function toggleMount()
  local player = g_game.getLocalPlayer()
  if player then
    player:toggleMount()
  end
end

function mount()
  local player = g_game.getLocalPlayer()
  if player then
    player:mount()
  end
end

function dismount()
  local player = g_game.getLocalPlayer()
  if player then
    player:dismount()
  end
end
