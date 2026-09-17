-- Simple test - just a black panel in the center of the screen
function showBlackBox()
    local rootSize = rootWidget:getSize()

    local panel = g_ui.createWidget('Panel', rootWidget)
    panel:setId('testBlackBox')
    panel:setSize({width = 400, height = 300})
    panel:setX(math.floor((rootSize.width - 400) / 2))
    panel:setY(math.floor((rootSize.height - 300) / 2))
    panel:setBackgroundColor('#000000')
    panel:setBorderColor('#ffffff')
    panel:setBorderWidth(2)
    panel:show()
    panel:focus()
    panel:raise()

    g_logger.info("[Test] Black box created at " .. panel:getX() .. "," .. panel:getY() .. " size " .. panel:getWidth() .. "x" .. panel:getHeight())

    return panel
end

showBlackBox()
