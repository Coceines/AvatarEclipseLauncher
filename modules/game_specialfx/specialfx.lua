-- ============================================================================
-- GAME SPECIAL FX - OTClient Module
-- ----------------------------------------------------------------------------
-- Recebe extended opcodes do servidor para efeitos visuais especiais em criaturas:
--   - "float|creatureId|duration": faz a criatura levitar/flutuar
--   - "stopfloat|creatureId": encerra a levitação
-- ============================================================================

local SPECIALFX_OPCODE = 114

function init()
    ProtocolGame.registerExtendedOpcode(SPECIALFX_OPCODE, onSpecialFx)
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(SPECIALFX_OPCODE)
end

function onSpecialFx(protocol, opcode, buffer)
    local params = buffer:split("|")
    if #params < 2 then return end

    local action = params[1]
    local creatureId = tonumber(params[2])
    if not creatureId then return end

    local creature = g_map.getCreatureById(creatureId)
    if not creature then return end

    if action == "float" then
        local duration = tonumber(params[3]) or 3000
        -- Faz a criatura levitar durante o tempo indicado
        if creature.jump then
            creature:jump(24, duration)
        end
    end
end
