-- Quest Log - modulo game_quests (SakkenOT)
-- Quest log oficial do Avatar. Comunica com o server via extended opcode 0xF0 (JSON).
-- Server: data/creaturescripts/scripts/questSystem.lua + data/lib/questSystemLib.lua
-- Somente a lista de quests (sem janela de detalhes/recompensas).

questListWindow = nil
local quests = {}
local tooltipWidget = nil

local QUEST_STATUS = {
    NOT_STARTED = 0,
    IN_PROGRESS = 1,
    COMPLETED = 2
}

function init()
    connect(g_game, {
        onGameEnd = onGameEnd
    })

    ProtocolGame.registerExtendedOpcode(0xF0, onQuestSystemPacket)
    g_ui.importStyle('questlist')

    questListWindow = g_ui.createWidget('QuestListWindow', rootWidget)
    questListWindow:hide()

    questLogButton = modules.client_topmenu.addRightGameButton('questLogButton', tr('Quest Log'), '/images/topbuttons/questlog', function() modules.game_quests.toggle() end, true)
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd
    })
    ProtocolGame.unregisterExtendedOpcode(0xF0)

    if tooltipWidget then
        tooltipWidget:destroy()
        tooltipWidget = nil
    end

    if questListWindow then
        questListWindow:destroy()
    end

    if questLogButton then
        questLogButton:destroy()
    end
end

function onGameEnd()
    quests = {}
    if questListWindow then
        questListWindow:hide()
    end
    if tooltipWidget then
        tooltipWidget:hide()
    end
end

function onQuestSystemPacket(protocol, opcode, buffer)
    local status, data = pcall(function() return json.decode(buffer) end)
    if not status or not data then return end

    if data.action == "questList" then
        quests = data.quests or {}
        updateQuestList()
    end
end

function showQuestTooltip(widget, quest)
    if tooltipWidget then
        tooltipWidget:destroy()
    end

    tooltipWidget = g_ui.createWidget('QuestTooltip', rootWidget)

    -- Set tooltip content
    local nameLabel = tooltipWidget:getChildById('tooltipQuestName')
    nameLabel:setText(quest.name)

    local statusLabel = tooltipWidget:getChildById('tooltipStatus')
    if quest.status == QUEST_STATUS.COMPLETED then
        statusLabel:setText('Status: Completed')
        statusLabel:setColor('#00FF00')
    elseif quest.status == QUEST_STATUS.IN_PROGRESS then
        statusLabel:setText('Status: In Progress')
        statusLabel:setColor('#FFFF00')
    else
        statusLabel:setText('')
        statusLabel:setColor('#888888')
    end

    local missionsLabel = tooltipWidget:getChildById('tooltipMissions')
    missionsLabel:setText('Missions: ' .. quest.completedMissions .. '/' .. quest.missionCount)

    local descLabel = tooltipWidget:getChildById('tooltipDescription')
    if quest.description and quest.description ~= "" then
        descLabel:setText(quest.description)
    else
        descLabel:setText('')
    end

    -- Position tooltip near mouse
    local mousePos = g_window.getMousePosition()
    tooltipWidget:setPosition({x = mousePos.x + 15, y = mousePos.y + 15})

    -- Make sure tooltip stays on screen
    local tooltipRect = tooltipWidget:getRect()
    local windowSize = g_window.getSize()

    if tooltipRect.x + tooltipRect.width > windowSize.width then
        tooltipWidget:setX(mousePos.x - tooltipRect.width - 5)
    end

    if tooltipRect.y + tooltipRect.height > windowSize.height then
        tooltipWidget:setY(mousePos.y - tooltipRect.height - 5)
    end

    tooltipWidget:show()
    tooltipWidget:raise()
end

function hideQuestTooltip()
    if tooltipWidget then
        tooltipWidget:destroy()
        tooltipWidget = nil
    end
end

function updateQuestList()
    if not questListWindow then return end

    local questList = questListWindow:getChildById('questList')
    questList:destroyChildren()

    for _, quest in ipairs(quests) do
        local questWidget = g_ui.createWidget('QuestListItem', questList)
        questWidget:setId('quest_' .. quest.id)

        -- Icone da quest: outfit do NPC ou item (nada de imagens custom)
        local questIcon = questWidget:getChildById('questIcon')
        local questItem = questWidget:getChildById('questItem')

        if questIcon then questIcon:hide() end
        if questItem then questItem:hide() end

        if quest.lookType and quest.lookType > 0 then
            if questIcon then
                questIcon:show()
                questIcon:setOutfit({type = quest.lookType})
            end
        elseif quest.lookTypeEx and quest.lookTypeEx > 0 then
            if questItem then
                questItem:show()
                questItem:setItemId(quest.lookTypeEx)
            end
        end

        local nameLabel = questWidget:getChildById('questName')
        nameLabel:setText(quest.name)

        local statusLabel = questWidget:getChildById('questStatus')
        if quest.status == QUEST_STATUS.COMPLETED then
            statusLabel:setText('Completed')
            statusLabel:setColor('#00FF00')
        elseif quest.status == QUEST_STATUS.IN_PROGRESS then
            statusLabel:setText('In Progress')
            statusLabel:setColor('#FFFF00')
        else
            statusLabel:setText('')
            statusLabel:setColor('#888888')
        end

        local progressLabel = questWidget:getChildById('questProgress')
        local progressBar = questWidget:getChildById('questProgressBar')

        -- Barra enche pela porcentagem de criaturas mortas (progress/maxProgress)
        if quest.maxProgress and quest.maxProgress > 0 then
            progressLabel:setText(quest.progress .. '/' .. quest.maxProgress)
            progressBar:setPercent((quest.progress / quest.maxProgress) * 100)
        elseif quest.missionCount > 0 then
            progressLabel:setText(quest.completedMissions .. '/' .. quest.missionCount .. ' missions')
            progressBar:setPercent((quest.completedMissions / quest.missionCount) * 100)
        else
            progressLabel:setText('')
            progressBar:setPercent(0)
        end

        -- Click: nao faz nada (sem janela de detalhes)
        questWidget.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton == MouseLeftButton then
                hideQuestTooltip()
                return true
            end
            return false
        end

        -- Tooltip handlers
        questWidget.onHoverChange = function(widget, hovered)
            if hovered then
                showQuestTooltip(widget, quest)
            else
                hideQuestTooltip()
            end
        end
    end
end

function requestQuestList()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        local data = {action="requestQuestList"}
        protocolGame:sendExtendedOpcode(0xF0, json.encode(data))
    end
end

function toggle()
    if questListWindow:isVisible() then
        hideQuestTooltip()
        questListWindow:hide()
    else
        requestQuestList()
        questListWindow:show()
        questListWindow:raise()
        questListWindow:focus()
    end
end

function hide()
    hideQuestTooltip()
    if questListWindow then
        questListWindow:hide()
    end
end
