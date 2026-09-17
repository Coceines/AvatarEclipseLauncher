dofile("/modules/gamelib/opcodes.lua")

infos = {
    vocation = 1,
    hotkey = "Ctrl+F",
    spells = {},
    currentEvents = {},
    maxNumberSpells = 16,
    buy = {}
}

-- Cores da barra de cooldown da spellbar (formato #rrggbbaa)
CD_SWEEP_COLOR = "#ff2b4d"   -- neon vermelho/rosa (opaco) que "descompleta" a borda
CD_TEXT_COLOR = "#ffffff"     -- numero de segundos por cima da borda
DEFAULT_SWEEP_COLOR = "#585858AA" -- cor padrao do fundo (igual ao estilo)

-- guarda o timer ativo (100ms) de cada slot em cooldown
cdTimer = {}

function string.explode(str, sep, limit)
    local i, pos, tmp, t = 0, 1, "", {}
    
    for s, e in function() return string.find(str, sep, pos) end do
        tmp = str:sub(pos, s - 1):trim()
        table.insert(t, tmp)
        pos = e + 1

        i = i + 1
        if(limit ~= nil and i == limit) then
            break
        end
    end

    tmp = str:sub(pos):trim()
    table.insert(t, tmp)
    
    return t
end

function getPrimaryAndSecondary(msg)
    local strings = string.explode(msg, "#")

    if doMessageCheck(strings[3], ",") then
        local number = string.explode(strings[3], ",")

        return {tonumber(number[1]), tonumber(number[2])}
    else
        return {tonumber(strings[3])}
    end
end

function checkIsFoldMsg(msg)
    local containsM = doMessageCheck(msg, "#m#")
    local containsV = doMessageCheck(msg, "#v#")
    local containsJ = doMessageCheck(msg, "#j#")
    local Ms = {}

    if containsM or containsV or containsJ then
        local strings = string.explode(msg, ";")

        for x = 1, #strings do
            if doMessageCheck(strings[x], "#m#") then
                local a = getPrimaryAndSecondary(strings[x])
                infos.spells[a[1]] = a[2]
                table.insert(Ms, a[1])
            
            elseif doMessageCheck(strings[x], "#v#") then
                local vocationId = getPrimaryAndSecondary(strings[x])[1]

                if vocationId > 0 and vocationId < 5 then
                    infos.vocation = vocationId
                end

            elseif doMessageCheck(strings[x], "#j#") then
                local a = getPrimaryAndSecondary(strings[x])
                infos.buy[a[1]] = true
            end
        end

        if containsV then
            configureFolds(infos.vocation)
        end

        if containsM then
            refreshCDs(Ms)
        end

        if containsJ then
            checkBuys()
        end

        return true
    end

    return false
end

function updateSpellbarShader(voc)
    local v = voc or infos.vocation
    if not v or v <= 0 then
        local lp = g_game.getLocalPlayer()
        if lp then
            v = lp:getVocation()
        end
    end
    v = v or 1
    local elem = ((v - 1) % 4) + 1
    if miniWindow then
        miniWindow:setImageShader("spellbar_bg_" .. elem)
    end
end

function doRefleshClient()
    local protocolGame = g_game.getProtocolGame()

    if protocolGame then
        protocolGame:sendExtendedOpcode(2) --manda pro server, mandar todas spells
		protocolGame:sendExtendedOpcode(40)
    end
    updateSpellbarShader()
end


-- (desativado: o indicador final e o anel tipo relogio em game_folds; o
-- contorno retangular ficaria poluindo o icone de 32px)
function setCooldownOutline(slot, cooling)
end

-- Escurece o icone da spell enquanto estiver em cooldown (some ao liberar)
function setIconDimmed(slot, dim)
    if not miniWindow or miniWindow:isDestroyed() then
        return
    end
    local icon = miniWindow:getChildById("m"..slot)
    if icon then
        icon:setOpacity(dim and 0.45 or 1)
    end
end

-- Flash branco bem rapido ("pa pum") quando a spell libera o cooldown
function flashReadyIcon(slot)
    if not miniWindow or miniWindow:isDestroyed() then
        return
    end
    local overlay = miniWindow:getChildById("p"..slot)
    if not overlay or overlay:isDestroyed() then
        return
    end
    local ok, flash = pcall(function()
        return g_ui.createWidget("CooldownFlash", overlay)
    end)
    if not ok or not flash then
        return
    end
    pcall(function() flash:fill("parent") end)
    flash:setOpacity(1)
    scheduleEvent(function()
        if not flash:isDestroyed() then
            flash:setOpacity(0.5)
        end
    end, 60)
    scheduleEvent(function()
        if not flash:isDestroyed() then
            flash:setOpacity(0.15)
        end
    end, 120)
    scheduleEvent(function()
        if not flash:isDestroyed() then
            flash:destroy()
        end
    end, 190)
end

-- Anel tipo relogio suave: atualiza a cada 100ms o percent (100 -> 0) e o
-- numero de segundos restantes, sem depender de ticks por segundo do server.
function startCdSweep(a, delay, progress)
    local startMs = g_clock.millis()
    local totalMs = delay * 1000

    -- drenagem nativa fluida: o anel anda sozinho a cada frame pelo relogio
    -- (setAutoCountdown); o Lua aqui so cuida do texto e do flash final
    pcall(function()
        progress:setAutoCountdown(totalMs)
    end)

    local function tick()
        if not progress or progress:isDestroyed() or not cdTimer[a] then
            cdTimer[a] = nil
            return
        end
        local remainMs = totalMs - (g_clock.millis() - startMs)
        if remainMs <= 0 then
            cdTimer[a] = nil
            pcall(function() progress:clearAutoCountdown() end)
            progress:setText()
            progress:setColor("gray")
            progress:setBackgroundColor(DEFAULT_SWEEP_COLOR)
            progress:setPercent(0)
            infos.spells[a] = 0
            setCooldownOutline(a, false)
            setIconDimmed(a, false)
            flashReadyIcon(a)
            return
        end
        -- 100 = anel cheio, encolhendo ate 0 (libera)
        progress:setPercent(remainMs / totalMs * 100)
        local secs = math.max(1, math.ceil(remainMs / 1000))
        if secs ~= infos.spells[a] then
            infos.spells[a] = secs
            progress:setText(secs)
        end
        cdTimer[a] = scheduleEvent(tick, 100)
    end

    cdTimer[a] = scheduleEvent(tick, 100)
end

function refreshCDs(CDs)
    local level = g_game.getLocalPlayer():getLevel()

    for x = 1, #CDs do
        local a, currentLevel = CDs[x], 0

        if spellInfos[infos.vocation][a] then
            currentLevel = spellInfos[infos.vocation][a].level
        end

        if level >= currentLevel then
            local delay = infos.spells[a]
            local progress = miniWindow:getChildById("p"..a)            if progress then
                cancelEventFold(a)
                progress:setColor("gray")

                if delay == 0 then
                    setCooldownOutline(a, false)
                    progress:setColor("gray")
                    progress:setBackgroundColor(DEFAULT_SWEEP_COLOR)
                    progress:setPercent(0)
                    progress:setText()
                    local wasCooling = infos.spells[a] and infos.spells[a] > 0
                    infos.spells[a] = 0
                    setIconDimmed(a, false)
                    if wasCooling then
                        flashReadyIcon(a)
                    end

                elseif delay > 0 then
                    -- anel tipo relogio: contorno neon no quadrado que vai se
                    -- descompletando (suave, 100ms) ate zerar e liberar a spell
                    setCooldownOutline(a, true)
                    setIconDimmed(a, true)
                    progress:setColor(CD_TEXT_COLOR)
                    progress:setBackgroundColor(CD_SWEEP_COLOR)
                    progress:setPercent(100)
                    progress:setText(delay)
                    startCdSweep(a, delay, progress)

                elseif delay < 0 then
                    setCooldownOutline(a, true)
                    progress:setPercent(0)
                end
            end
        end
    end
end

function checkBuys()
    local playerLevel = g_game.getLocalPlayer():getLevel()

    for x = 12, #spellInfos[infos.vocation] do
        local current = spellInfos[infos.vocation][x]
        local progress = miniWindow:getChildById("p"..x)

        if not infos.buy[x] then
            setCooldownOutline(x, false)
            progress:setText("NPC")
            progress:setColor("gray")
            progress:setPercent(0)
        else
            if progress:getText() == "NPC" and infos.spells[x] == 0 then
                if playerLevel >= current.level then
                    progress:setText()
                    progress:setBackgroundColor(DEFAULT_SWEEP_COLOR)
                    progress:setPercent(0)
                else
                    progress:setText("L"..current.level)
                    progress:setColor("pink") 
                end
            end
        end
    end
end

function refreshLevel()
    local level = g_game.getLocalPlayer():getLevel()

    for x = 1, #spellInfos[infos.vocation] do
        local progress = miniWindow:getChildById("p"..x)

        if level >= spellInfos[infos.vocation][x].level then
            if infos.spells[x] == 0 then
                setCooldownOutline(x, false)
                progress:setText()
                progress:setBackgroundColor(DEFAULT_SWEEP_COLOR)
                progress:setPercent(0)
            end
        else
            setCooldownOutline(x, false)
            progress:setText("L"..spellInfos[infos.vocation][x].level)
            progress:setColor("pink")
            progress:setPercent(0)
        end
    end

    checkBuys()
end

function cancelEventFold(id)
    if cdTimer[id] then
        pcall(function() cdTimer[id]:cancel() end)
        cdTimer[id] = nil
    end
    -- para a drenagem nativa do anel tambem (se existir)
    if miniWindow and not miniWindow:isDestroyed() then
        local pp = miniWindow:getChildById("p"..id)
        if pp then
            pcall(function() pp:clearAutoCountdown() end)
        end
    end
    if infos.currentEvents[id] then
        if #infos.currentEvents[id] > 0 then
            for x = 1, #infos.currentEvents[id] do
                infos.currentEvents[id][x]:cancel()
            end
        end
    end

    infos.currentEvents[id] = {}
end

function configureFolds(voc)
    infos.buy = {}
    updateSpellbarShader(voc)
    modules.game_healthinfo.setImageAvatar(voc)
    for x = 1, #spellInfos[voc] do
        cancelEventFold(x)

        local current = miniWindow:getChildById("m"..x)
        local progress = miniWindow:getChildById("p"..x)
        local levelFold = spellInfos[voc][x].level
        setCooldownOutline(x, false)
        setIconDimmed(x, false)
		
		progress.info = spellInfos[voc][x].name..", lv. "..levelFold
        current:setImageSource(images[voc]..x)		
        progress:setTooltip(progress.info)
        progress.name = spellInfos[voc][x].name
        progress.slotIndex = x

        progress.onClick = function(self)
            if self.name == "Water Heal" and G.healTargetName and #G.healTargetName > 0 then
                local proto = g_game.getProtocolGame()
                if proto then
                    proto:sendExtendedOpcode(210, G.healTargetName)
                end
            end
            g_game.talk(self.name)
        end
        g_mouse.bindPress(progress, function() createMenu(progress) end, MouseRightButton)
    end
	tooltipHotkey()
    -- Re-apply Water Heal target tooltip (tooltipHotkey overwrites it)
    updateHealTargetTooltip()
    refreshLevel()
end

function toggle()
    if not miniWindow:isVisible() then
        doOpen()
    else
        doClose()
    end
end

function doOpen()
    if foldsButton then foldsButton:setOn(true) end
    miniWindow:show()
end

function doClose()
    if foldsButton then foldsButton:setOn(false) end
    miniWindow:hide()
end

function init()
    miniWindow = g_ui.loadUI('folds', modules.game_interface.getRootPanel())
    updateSpellbarShader()
    -- miniWindow:disableResize()

    -- Carrega o nome salvo do target da Water Heal
    G.healTargetName = g_settings.get('waterHealTarget') or nil
    if G.healTargetName and #G.healTargetName == 0 then
        G.healTargetName = nil
    end

    connect(g_game, {onGameStart = doRefleshClient})
    connect(LocalPlayer, {onLevelChange = refreshLevel})

    g_keyboard.bindKeyDown(infos.hotkey, toggle)
	local bendNames = tr('Bend List (Ctrl F)')
    -- foldsButton = modules.client_topmenu.addRightGameToggleButton('foldsButton', bendNames, '/images/topbuttons/cooldowns', toggle)
    -- miniWindow:setup()
end

function terminate()
    miniWindow:destroy()
    if foldsButton then foldsButton:destroy() end
    g_keyboard.unbindKeyDown(infos.hotkey)
    disconnect(g_game, {onGameStart = doRefleshClient})
    disconnect(LocalPlayer, {onLevelChange = refreshLevel})
end

function createMenu(spell)
    local menu   = g_ui.createWidget('PopupMenu')
    local hotkey = modules.game_hotkeys

    menu:addOption(tr('Add Hotkey'), function() hotkey.addSpell(spell) end)

    local spellHotkey = hotkey.checkSpell(spell.name)
    if spellHotkey then
        menu:addOption(tr('Remove Hotkey'), function()
            spell:setTooltip(spell.info)
            hotkey.removeSpell(spellHotkey)
        end)
    end

    -- Opcao extra para Water Heal: definir o alvo
    if spell.name == "Water Heal" then
        menu:addOption(tr('Set Heal Target'), function()
            local cur = G.healTargetName or ''
            displayTextInputBox(
                'Water Heal - Who to heal?',
                'Player name' .. (cur ~= '' and ' (current: ' .. cur .. ')' or ''),
                function(inputText)
                    local name = inputText:trim()
                    if name and #name > 0 then
                        G.healTargetName = name
                        g_settings.set('waterHealTarget', name)
                        g_settings.save()
                    else
                        G.healTargetName = nil
                        g_settings.set('waterHealTarget', '')
                        g_settings.save()
                    end
                    updateHealTargetTooltip()
                end,
                function() end
            )
        end)
    end

    menu:display()
end

function tooltipHotkey()
  for x = 1, #spellInfos[infos.vocation] do
    local progress = miniWindow:getChildById("p"..x)
	local hotkey = modules.game_hotkeys.checkSpell(progress.name)
	if ( hotkey ) then
	  progress:setTooltip(progress.info.." - Hotkey: "..hotkey)
	else
	  progress:setTooltip(progress.info)
	end
  end
end

function updateHealTargetTooltip()
    for x = 1, 24 do
        local progress = miniWindow:getChildById("p"..x)
        if progress and progress.name == "Water Heal" then
            if G.healTargetName and #G.healTargetName > 0 then
                progress:setTooltip(progress.info .. ' -> ' .. G.healTargetName)
            else
                progress:setTooltip(progress.info)
            end
            break
        end
    end
end