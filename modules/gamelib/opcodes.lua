function doMessageCheck(msg, keyword)
    local a, b = string.find(msg, keyword)

    if(a and b) then
        return true
    end

    return false
end

function canBlockMessageOldClient(msg)
    if doMessageCheck(msg, "#") then
        return true
    end

    return false
end
