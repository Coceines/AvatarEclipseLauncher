local isOpen = false
local mountWindow = nil


function openWindow()
  if not g_game.isOnline() then 
   return 
  end
    local voc = modules.game_folds.infos.vocation or 1
  
    if not isOpen then
        g_game.talk("!mount none")

        mountWindow = g_ui.loadUI('game_mountsAvatar', rootWidget)

        mountWindow.onEscape = function()
            mountWindow:destroy()
            isOpen = false
        end
      
        for x = 1, #mountsData[voc] do
            local a = mountWindow:getChildById("mountButton"..x)

            if a then
                a:setImageSource("icones/"..pastas[voc].."/"..mountsData[voc][x].icone)

                local mold = mountWindow:getChildById("mold"..x)

                if mold then
                    mold:setTooltip(mountsData[voc][x].desc)

                    mold.onClick = function()
                        g_game.talk("!mount "..mountsData[voc][x].id)
                        mountWindow.onEscape()
                    end
                end
            end
        end

        isOpen = true
    end
end
function doOpen()
openWindow()
end

function doClose()
mountWindow:destroy()
  isOpen = false
end
function toggle()
  return g_game.talk("!mount none")
end
--[[
    if not isOpen then
        doOpen()
    else
        doClose()
    end
end]]
function onMiniWindowClose()
mountWindow:destroy()
  isOpen = false
end