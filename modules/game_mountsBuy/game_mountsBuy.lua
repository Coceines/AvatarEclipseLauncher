local isOpen = false
local mountWindow = nil

function doOpen()
openWindow()
end

function doClose()
mountWindow:destroy()
  isOpen = false
end

function toggle()
    if g_game.isOnline() and not isOpen then
        doOpen()
    elseif isOpen then 
        doClose()
    end
end

function init()
     ProtocolGame.registerExtendedOpcode(201, toggle)
end

function terminate()
    if mountWindow then
        mountWindow.onEscape()
    end
end

function openWindow()
    local voc = modules.game_folds.infos.vocation or 1
    if not isOpen then
--        g_game.talk("!mount none")

        mountWindow = g_ui.loadUI('game_mountsBuy', rootWidget)

        mountWindow.onEscape = function()
            mountWindow:destroy()
            isOpen = false
        end

        for x = 1, #mountsData[voc] do
            local a = mountWindow:getChildById("mountButton"..x)

            if a then
                a:setImageSource("icones/"..pastas[voc].."/"..x)

                local mold = mountWindow:getChildById("mold"..x)

                if mold then
                    mold:setTooltip(mountsData[voc][x].desc)

                    mold.onClick = function()
                        g_game.talk("!mountbuy "..x)
                        mountWindow.onEscape()
                    end
                end
            end
        end

        isOpen = true
    end
end