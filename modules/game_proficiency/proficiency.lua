-- ============================================================
-- WEAPON PROFICIENCY CLIENT CONTROLLER (OTClient)
-- ============================================================
-- Manages the weapon proficiency interface,
-- communication via Extended Opcode 188 and Topbar integration.
-- ============================================================

WeaponProficiency = {}

-- Exports to the OTClient modules namespace
modules.game_proficiency = modules.game_proficiency or {}
modules.game_proficiency.WeaponProficiency = WeaponProficiency

local OPCODE_PROFICIENCY = 188

local window = nil
local topbarButton = nil
local currentData = nil

WeaponProficiency.filters = {}

WeaponProficiency.pendingSelections = {}

-- Module initialization
function init()
    -- Registers Extended Opcode 188
    ProtocolGame.registerExtendedOpcode(OPCODE_PROFICIENCY, onProficiencyOpcode)

    -- Game connection and disconnection events
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then
        onGameStart()
    end
end

-- Module termination
function terminate()
    pcall(function()
        ProtocolGame.unregisterExtendedOpcode(OPCODE_PROFICIENCY)
    end)

    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if topbarButton then
        topbarButton:destroy()
        topbarButton = nil
    end

    if window then
        window:destroy()
        window = nil
    end

    currentData = nil
    WeaponProficiency.pendingSelections = {}
end

-- Called when the game starts
function onGameStart()
    -- Creates the Topbar button on the Avatar Client if client_topmenu is present
    if modules.client_topmenu and not topbarButton then
        topbarButton = modules.client_topmenu.addRightGameToggleButton(
            'weaponProficiencyButton',
            tr('Weapon Proficiency'),
            '/modules/game_proficiency/images/topbar_icon',
            toggle
        )
        if topbarButton then
            topbarButton:setOn(false)
        end
    end

    -- Requests initial data from the server
    requestData()
end

-- Called when the game ends
function onGameEnd()
    stopAutoRefresh()
    if window then
        window:hide()
    end
    if topbarButton then
        topbarButton:setOn(false)
    end
end

-- Periodic refresh while the window is open, so kills show up live
local autoRefreshEvent = nil
local AUTO_REFRESH_MS = 3000

function stopAutoRefresh()
    if autoRefreshEvent then
        removeEvent(autoRefreshEvent)
        autoRefreshEvent = nil
    end
end

function refreshTick()
    autoRefreshEvent = scheduleEvent(refreshTick, AUTO_REFRESH_MS)
    if window and window:isVisible() and g_game.isOnline() then
        requestData()
    end
end

function startAutoRefresh()
    stopAutoRefresh()
    autoRefreshEvent = scheduleEvent(refreshTick, AUTO_REFRESH_MS)
end

-- Window toggle
function toggle()
    if not window then
        createWindow()
    end

    if window:isVisible() then
        window:hide()
        if topbarButton then
            topbarButton:setOn(false)
        end
        stopAutoRefresh()
    else
        window:show()
        window:raise()
        window:focus()
        if topbarButton then
            topbarButton:setOn(true)
        end
        requestData()
        startAutoRefresh()
    end
end

-- Requests updated data from the server
function requestData()
    local protocol = g_game.getProtocolGame()
    if protocol and g_game.isOnline() then
        protocol:sendExtendedOpcode(OPCODE_PROFICIENCY, json.encode({ action = "request" }))
    end
end

-- Creates the interface window
function createWindow()
    if window then
        return
    end

    window = g_ui.displayUI('proficiency')
    window:hide()

    -- Adjusts the close button if it exists
    local closeButton = window:getChildById('closeButton')
    if closeButton then
        closeButton.onClick = function()
            toggle()
        end
    end

    -- Connects the search filter
    local searchEdit = window:recursiveGetChildById('searchText')
    if searchEdit then
        searchEdit.onTextChange = function(widget, text)
            refreshItemList()
        end
    end
end

-- ============================================================
-- METHODS CALLED BY THE OTUI
-- ============================================================

-- Window close
function WeaponProficiency:onCloseWindow()
    if window and window:isVisible() then
        toggle()
    end
end

-- Toggle filter options (kept safe for compatibility)
function WeaponProficiency:toggleFilterOption(button)
    refreshItemList()
end

-- Clears the item search field
function WeaponProficiency:clearSearch()
    if not window then
        return
    end
    local searchEdit = window:recursiveGetChildById('searchText')
    if searchEdit then
        searchEdit:setText('')
        searchEdit:focus()
    end
    refreshItemList()
end

-- Reset button
function WeaponProficiency:onResetClick()
    self.pendingSelections = {}
    displayInfo(tr("Info"), tr("Pending selections have been reset."))
    requestData()
end

-- Apply button
function WeaponProficiency:onApplyClick()
    local protocol = g_game.getProtocolGame()
    if not protocol or not g_game.isOnline() then
        return
    end

    -- Applies the pending selected perks
    for lvl, pIdx in pairs(self.pendingSelections) do
        local payload = {
            action = "selectPerk",
            level = lvl,
            perkIndex = pIdx
        }
        protocol:sendExtendedOpcode(OPCODE_PROFICIENCY, json.encode(payload))
    end
    self.pendingSelections = {}
end

-- OK button
function WeaponProficiency:onOkClick()
    self:onApplyClick()
    self:onCloseWindow()
end

-- ============================================================
-- SELECTION AND INTERFACE UPDATE
-- ============================================================

local selectedWeaponId = nil

-- Handler for clicking a perk
function selectPerk(level, perkIndex)
    local protocol = g_game.getProtocolGame()
    if not protocol or not g_game.isOnline() then
        return
    end

    local payload = {
        action = "selectPerk",
        level = level,
        perkIndex = perkIndex
    }
    protocol:sendExtendedOpcode(OPCODE_PROFICIENCY, json.encode(payload))
end

-- Updates the weapon listing in the catalog (bottom-left corner)
function refreshItemList()
    if currentData and currentData.weapons then
        populateItemList(currentData.weapons)
    end
end

-- Fills the weapons/gloves grid (itemList)
function populateItemList(weapons)
    if not window or not weapons then
        return
    end

    local itemList = window:recursiveGetChildById('itemList')
    if not itemList then
        return
    end

    itemList:destroyChildren()

    local searchEdit = window:recursiveGetChildById('searchText')
    local query = searchEdit and searchEdit:getText():lower():trim() or ""

    for _, w in ipairs(weapons) do
        local matchesSearch = (#query == 0) or (w.name:lower():find(query, 1, true) ~= nil)

        if matchesSearch then
            local itemBox = g_ui.createWidget('ItemBox', itemList)
            itemBox:setId('itemBox_' .. w.id)
            itemBox:setTooltip(w.name) -- Rule: never displays IDs

            if selectedWeaponId == w.id then
                itemBox:focus()
            end

            local itemWidget = itemBox:getChildById('item')
            if itemWidget and w.clientId and w.clientId > 0 then
                itemWidget:setItemId(w.clientId)
                itemWidget:setVisible(true)
            end

            -- Mini stars for the mastery level on the weapon
            local starsBg = itemBox:getChildById('starsBackground')
            if starsBg then
                starsBg:destroyChildren()
                local wLevel = w.level or 0
                for s = 1, math.min(7, wLevel) do
                    local star = g_ui.createWidget('MiniStar', starsBg)
                    star:setImageSource('/modules/game_proficiency/images/icon-star-tiny-gold')
                end
            end

            itemBox.onClick = function()
                selectedWeaponId = w.id
                displayWeapon(w)
            end
        end
    end
end

-- Resolves the perk tree to display for the given weapon.
-- Priority: per-weapon theme sent by the server (themes + weaponTheme)
-- > global perksDefinition (backward compatible).
function WeaponProficiency:getPerksDefinitionFor(w)
    if not w or not currentData then
        return nil
    end
    if currentData.themes and currentData.weaponTheme then
        local themeKey = currentData.weaponTheme[tostring(w.id)]
        if themeKey and currentData.themes[themeKey] then
            return currentData.themes[themeKey]
        end
    end
    return nil
end

-- Displays the data and perk tree of the selected weapon
function displayWeapon(w)
    if not window or not w or not currentData then
        return
    end

    local content = window:getChildById('contentPanel')
    if not content then
        return
    end

    -- 1. Selected Item Panel
    local itemNameTitle = content:recursiveGetChildById('itemNameTitle')
    local itemWidget = content:recursiveGetChildById('item')
    local iconMasteryLevel = content:recursiveGetChildById('iconMasteryLevel')
    local progressDesc = content:recursiveGetChildById('progressDescription')
    local nextLevelDesc = content:recursiveGetChildById('nextLevelDescription')

    if itemNameTitle then
        itemNameTitle:setText(w.name)
        itemNameTitle:setColor('#ffffff')
    end

    if itemWidget and w.clientId and w.clientId > 0 then
        itemWidget:setItemId(w.clientId)
        itemWidget:setVisible(true)
    end

    local wLevel = w.level or 0
    if iconMasteryLevel then
        local lvlIcon = math.min(7, math.max(0, wLevel))
        iconMasteryLevel:setImageSource('/modules/game_proficiency/images/icon-masterylevel-' .. lvlIcon)
    end

    if progressDesc then
        progressDesc:setText(string.format("%d / %d XP", w.exp or 0, w.maxExp or 0))
    end

    if nextLevelDesc then
        if wLevel >= (w.maxLevel or 7) then
            nextLevelDesc:setText(tr("Maximum Mastery Reached"))
        else
            local needed = math.max(0, (w.maxExp or 0) - (w.exp or 0))
            nextLevelDesc:setText(string.format("%d EXP for next Lv.", needed))
        end
    end

    -- 2. Main Progress Bar
    local profProgress = content:recursiveGetChildById('proficiencyProgress')
    if profProgress then
        profProgress:setPercent(w.percent or 0)
    end

    local maxLvl = currentData.maxLevel or 7
    local perksDef = WeaponProficiency:getPerksDefinitionFor(w) or currentData.perksDefinition or {}
    local playerPerks = w.perks or {}
    local isEquipped = currentData.equipped and (currentData.equipped.id == w.id)

    -- 3. Mastery Stars (starsPanelBackground)
    local starsPanel = content:recursiveGetChildById('starsPanelBackground')
    if starsPanel then
        for lvl = 1, maxLvl do
            local starWidget = starsPanel:getChildById('starWidget_' .. lvl)
            if not starWidget then
                starWidget = g_ui.createWidget('StarWidget', starsPanel)
                starWidget:setId('starWidget_' .. lvl)
            end

            local isUnlocked = (wLevel >= lvl)
            local starProg = starWidget:getChildById('starProgress')
            local starIcon = starWidget:getChildById('star')
            if starProg then
                starProg:setPercent(isUnlocked and 100 or 0)
            end
            if starIcon then
                if isUnlocked then
                    starIcon:setImageSource('/modules/game_proficiency/images/icon-star-tiny-gold')
                else
                    starIcon:setImageSource('/modules/game_proficiency/images/icon-star-dark')
                end
            end
            starWidget:setTooltip(string.format("Mastery Level %d", lvl))
        end
    end

    -- 4. Perk Selection Panel (bonusProgressBackground)
    local bonusProgressBg = content:recursiveGetChildById('bonusProgressBackground')
    local bonusDetailBg = content:recursiveGetChildById('bonusDetailBackground')

    if bonusProgressBg then
        for lvl = 1, maxLvl do
            local colPanel = bonusProgressBg:getChildById('bonusSelect_' .. lvl)
            if not colPanel then
                colPanel = g_ui.createWidget('BonusSelectPanel', bonusProgressBg)
                colPanel:setId('bonusSelect_' .. lvl)
            end

            local isLvlUnlocked = (wLevel >= lvl)
            local activePerkIdx = tonumber(playerPerks[tostring(lvl)]) or tonumber(playerPerks[lvl]) or 0

            local threePanel = colPanel:getChildById('threeBonusIconPanel')
            if threePanel then
                threePanel:setVisible(true)

                local lvlPerks = perksDef[lvl] or perksDef[tostring(lvl)] or {}
                for pIdx = 1, 3 do
                    local iconWidget = threePanel:getChildById('bonusIcon' .. (pIdx - 1))
                    local pData = lvlPerks[pIdx]
                    if iconWidget and pData then
                        local isSelected = (activePerkIdx == pIdx)

                        local highlight = iconWidget:getChildById('highlight')
                        if highlight then
                            highlight:setVisible(isSelected)
                        end

                        local border = iconWidget:getChildById('border')
                        if border then
                            if isLvlUnlocked then
                                border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-active')
                            else
                                border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-inactive')
                            end
                        end

                        local lock = iconWidget:getChildById('locked-perk')
                        if lock then
                            lock:setVisible(not isLvlUnlocked)
                        end

                        -- Loads the specific bonus icon
                        local iconImg = iconWidget:getChildById('icon')
                        if iconImg then
                            local src = pData.iconSource or "icons-0"
                            local clip = pData.iconClip or "0 0 64 64"
                            iconImg:setImageSource('/modules/game_proficiency/images/' .. src)
                            if torect then
                                iconImg:setImageClip(torect(clip))
                            end
                            iconImg:setVisible(true)
                        end

                        local statusText = isSelected and "[ACTIVE] " or (isLvlUnlocked and "[AVAILABLE] " or "[LOCKED] ")
                        iconWidget:setTooltip(string.format("%s%s\n\n%s", statusText, pData.name, pData.description))

                        iconWidget.onClick = function()
                            if not isEquipped then
                                displayInfo(tr("Warning"), tr("Equip this weapon to configure its mastery perks."))
                                return
                            end
                            if not isLvlUnlocked then
                                displayInfo(tr("Locked"), tr("Increase your weapon's mastery to unlock this perk."))
                                return
                            end
                            selectPerk(lvl, pIdx)
                        end
                    end
                end
            end

            -- 5. Perk Details Panel (bonusDetailBackground)
            if bonusDetailBg then
                local detailPanel = bonusDetailBg:getChildById('detailPanel_' .. lvl)
                if not detailPanel then
                    detailPanel = g_ui.createWidget('BonusDetailPanel', bonusDetailBg)
                    detailPanel:setId('detailPanel_' .. lvl)
                end

                local nameWidget = detailPanel:getChildById('bonusName')
                if nameWidget then
                    local lvlPerks = perksDef[lvl] or perksDef[tostring(lvl)] or {}
                    if activePerkIdx > 0 and lvlPerks[activePerkIdx] then
                        nameWidget:setText(lvlPerks[activePerkIdx].name)
                        nameWidget:setColor('#00ff66')
                        nameWidget:setTooltip(string.format("%s\n\n%s", lvlPerks[activePerkIdx].name, lvlPerks[activePerkIdx].description))
                    elseif isLvlUnlocked then
                        nameWidget:setText(tr("Choose a Perk"))
                        nameWidget:setColor('#e0e0e0')
                        nameWidget:setTooltip(tr("Click one of the 3 options above to activate the perk."))
                    else
                        nameWidget:setText(string.format("Level %d", lvl))
                        nameWidget:setColor('#707070')
                        nameWidget:setTooltip(string.format("Unlocks at Mastery Level %d.", lvl))
                    end
                end
            end
        end
    end
end

-- Updates the interface with the data received from the server
function updateUI(data)
    if not window then
        return
    end

    currentData = data
    local equipped = data.equipped
    local targetWeapon = nil

    -- If there is already a selected weapon, try to find it in the updated data
    if selectedWeaponId and data.weapons then
        for _, w in ipairs(data.weapons) do
            if w.id == selectedWeaponId then
                targetWeapon = w
                break
            end
        end
    end

    -- If not found, prioritize the equipped weapon
    if not targetWeapon then
        targetWeapon = equipped
        if targetWeapon then
            selectedWeaponId = targetWeapon.id
        elseif data.weapons and #data.weapons > 0 then
            targetWeapon = data.weapons[1]
            selectedWeaponId = targetWeapon.id
        end
    end

    if targetWeapon then
        displayWeapon(targetWeapon)
    else
        local content = window:getChildById('contentPanel')
        if content then
            local itemNameTitle = content:recursiveGetChildById('itemNameTitle')
            if itemNameTitle then
                itemNameTitle:setText(tr('No weapon equipped'))
                itemNameTitle:setColor('#909090')
            end
            local itemWidget = content:recursiveGetChildById('item')
            if itemWidget then
                itemWidget:clearItem()
            end
        end
    end

    -- Populates the gloves/weapons catalog in the bottom-left corner
    if data.weapons then
        populateItemList(data.weapons)
    end
end

-- Simple warning message
function displayInfo(title, message)
    if modules.game_textmessage then
        modules.game_textmessage.displayFailureMessage(message)
    else
        print(string.format("[%s] %s", tostring(title), tostring(message)))
    end
end

-- Extended Opcode 188 message handler
function onProficiencyOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_PROFICIENCY then
        return
    end

    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then
        return
    end

    if data.action == "sync" then
        updateUI(data)
    elseif data.action == "selectResult" then
        if not data.success then
            displayInfo(tr("Error"), data.message or tr("Could not activate the perk."))
        else
            requestData()
        end
    end
end