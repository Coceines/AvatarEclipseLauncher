Icons = {}
Icons[1] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[2] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[4] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[8] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[16] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[32] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[64] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[128] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[256] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[512] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[1024] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[2048] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[4096] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[8192] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[16384] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[32768] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[65536] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }

healthInfoWindow = nil
healthBar = nil
healthLabel = nil
manaLabel = nil
experienceLabel = nil
manaBar = nil
experienceBar = nil
healthTooltip = 'Your character health is %d out of %d.'
manaTooltip = 'Your character mana is %d out of %d.'
experienceTooltip = 'You have %d%% to advance to level %d.'
avatarEdit = true
uiAvatar = nil
imgAvatar = { "fire", "water", "air", "earth" }
currentHealthVocation = 0

function updateHealthbarShader(voc)
  local v = voc or currentHealthVocation
  if not v or v <= 0 then
    local lp = g_game.getLocalPlayer()
    if lp then
      v = lp:getVocation()
    end
  end
  v = v or 1
  currentHealthVocation = v
  local elem = ((v - 1) % 4) + 1
  local overlay = healthInfoWindow and healthInfoWindow:recursiveGetChildById('backgroundOverlay')
  if overlay then
    overlay:setImageShader('healthbar_bg_' .. elem)
  end
end

function init()
  connect(LocalPlayer, { onHealthChange = onHealthChange,
                         onManaChange = onManaChange,
                         onLevelChange = onLevelChange,
                         onStatesChange = onStatesChange,
                         onSoulChange = onSoulChange,
                        })

  connect(g_game, { onGameEnd = offline,
                    onGameStart = online  })


  ProtocolGame.registerExtendedOpcode(19, function(protocol, opcode, buffer)
	setImageAvatar(tonumber(buffer))
  end)

  -- healthInfoButton = modules.client_topmenu.addRightGameToggleButton('healthInfoButton', tr('Health Information'), '/images/topbuttons/healthinfo', toggle)
  -- healthInfoButton:setOn(true)

  healthInfoWindow = g_ui.loadUI('healthinfo', modules.game_interface.getRootPanel())
  healthBar = healthInfoWindow:recursiveGetChildById('healthBar')
  healthLabel = healthInfoWindow:recursiveGetChildById('healthLabel')
  manaLabel = healthInfoWindow:recursiveGetChildById('manaLabel')
  experienceLabel = healthInfoWindow:recursiveGetChildById('experienceLabel')
  manaBar = healthInfoWindow:recursiveGetChildById('manaBar')
  experienceBar = healthInfoWindow:recursiveGetChildById('experienceBar')
  uiAvatar = healthInfoWindow:recursiveGetChildById('uiAvatar')

  -- load condition icons
  for k,v in pairs(Icons) do
    g_textures.preload(v.path)
  end

  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
    onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
    syncConditionIcons(localPlayer:getStates())
    updateHealthbarShader()
  end

  -- healthInfoWindow:setup()
end

function online()
  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    if localPlayer then
      syncConditionIcons(localPlayer:getStates())
    end
  end
end

function terminate()
  disconnect(LocalPlayer, { onHealthChange = onHealthChange,
                            onManaChange = onManaChange,
                            onLevelChange = onLevelChange,
                            onStatesChange = onStatesChange,
                          })

  disconnect(g_game, { onGameEnd = offline,
                    onGameStart = online  })

  healthInfoWindow:destroy()
  if healthInfoButton then healthInfoButton:destroy() end
end

-- function toggle()
  -- if healthInfoButton:isOn() then
    -- healthInfoWindow:close()
    -- healthInfoButton:setOn(false)
  -- else
    -- healthInfoWindow:open()
    -- healthInfoButton:setOn(true)
  -- end
-- end


function toggle()
  if healthInfoWindow:isVisible() then
    healthInfoWindow:hide()
  else
    healthInfoWindow:show()
  end
end

-- A barra de estados e' ESPELHO do bitfield que o servidor manda.
-- O codigo antigo alternava (toggle) o icone a cada bit que mudava: qualquer
-- dessincronia entre o painel e o servidor (reload de modulo, bit que nao
-- muda entre duas sessoes, dois updates no mesmo pacote) deixava um icone
-- fantasma "You are poisoned / paralysed" que nao correspondia a nenhuma
-- condicao real e so' saia quando aquele bit mudasse de novo.
function syncConditionIcons(states)
  if not healthInfoWindow then return end
  local content = healthInfoWindow:recursiveGetChildById('conditionPanel')
  if not content then return end

  states = tonumber(states) or 0
  content:destroyChildren()

  local bit = 1
  for _ = 1, 32 do
    if bit > states then break end
    if bit32.band(states, bit) ~= 0 then
      local icon = loadIcon(bit, content)
      if icon then
        icon:setParent(content)
      end
    end
    bit = bit * 2
  end
end

function toggleIcon(bitChanged)
  -- mantido por compatibilidade: sincroniza com o estado atual do servidor
  local localPlayer = g_game.getLocalPlayer()
  syncConditionIcons(localPlayer and localPlayer:getStates() or 0)
end

function loadIcon(bitChanged, parent)
  if not Icons[bitChanged] then
    return nil
  end

  local icon = g_ui.createWidget('ConditionWidget', parent)
  icon:setId(Icons[bitChanged].id)
  icon:setImageSource(Icons[bitChanged].path)
  icon:setTooltip(Icons[bitChanged].tooltip)
  return icon
end

function offline()
  healthInfoWindow:recursiveGetChildById('conditionPanel'):destroyChildren()
  local overlay = healthInfoWindow:recursiveGetChildById('backgroundOverlay')
  if overlay then overlay:setImageShader('') end
  currentHealthVocation = 0
end

-- hooked events
function onMiniWindowClose()
  if healthInfoButton then healthInfoButton:setOn(false) end
end

function onHealthChange(localPlayer, health, maxHealth)
  -- os eventos do LocalPlayer podem chegar com valor nil (login/logout/dead):
  -- concatenar nil abortava o handler e a barra parava de atualizar.
  if not health or not maxHealth then
    return
  end

  healthBar:setText(health .. ' / ' .. maxHealth)
  healthBar:setFont('verdana-11px-rounded')
  healthLabel:setTooltip(tr(healthTooltip, health, maxHealth))
  
  healthBar:setValue(health, 0, maxHealth)
end

function onManaChange(localPlayer, mana, maxMana)
  -- manaBar:setText(mana .. ' / ' .. maxMana)
  -- healthBar:setFont('verdana-11px-antialised')
  manaLabel:setTooltip(tr(manaTooltip, mana, maxMana))
  manaBar:setValue(mana, 0, maxMana)
end

function onLevelChange(localPlayer, value, percent)
  -- experienceBar:setText(percent .. '%')
  experienceLabel:setTooltip(tr(experienceTooltip, percent, value+1))
  experienceBar:setPercent(percent)
end

function onStatesChange(localPlayer, now, old)
  -- Sempre re-renderiza a partir do estado atual (nao do que mudou).
  syncConditionIcons(now)
end

-- personalization functions
function hideExperience()
  local removeHeight = experienceBar:getMarginRect().height
  experienceBar:setOn(false)
  healthInfoWindow:setHeight(math.max(healthInfoWindow.minimizedHeight, healthInfoWindow:getHeight() - removeHeight))
end

function setHealthTooltip(tooltip)
  healthTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    healthBar:setTooltip(tr(healthTooltip, localPlayer:getHealth(), localPlayer:getMaxHealth()))
  end
end

function setManaTooltip(tooltip)
  manaTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    manaBar:setTooltip(tr(manaTooltip, localPlayer:getMana(), localPlayer:getMaxMana()))
  end
end

function setExperienceTooltip(tooltip)
  experienceTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    experienceLabel:setTooltip(tr(experienceTooltip, localPlayer:getLevelPercent(), localPlayer:getLevel()+1))
  end
end

function setImageAvatar(vocation)
  uiAvatar:setImageSource('img/'..imgAvatar[vocation])
  updateHealthbarShader(vocation)
end
