-- ============================================================================
-- GAME HEALCUT + HUNGER + NOMANA ICONS - OTClient Module
-- ----------------------------------------------------------------------------
-- Mostra ícones acima do nome dos players:
--   - Heal Cut (Grievous Wounds): redução de cura PvP
--   - Hungry: player sem food (fome)
--   - No Mana: player com mana abaixo de 20%
--
-- Recebe extended opcodes do servidor com o formato: "creatureId,state"
--   state = "1" → ativa o ícone
--   state = "0" → remove o ícone
--
-- INSTALAÇÃO: Copie esta pasta para <client>/modules/game_healcut/
-- ============================================================================

local OPCODE_HEAL_CUT = 108
local OPCODE_HUNGRY   = 109
local OPCODE_NO_MANA  = 110

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE_HEAL_CUT, onHealCut)
    ProtocolGame.registerExtendedOpcode(OPCODE_HUNGRY, onHungry)
    ProtocolGame.registerExtendedOpcode(OPCODE_NO_MANA, onNoMana)
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(OPCODE_HEAL_CUT)
    ProtocolGame.unregisterExtendedOpcode(OPCODE_HUNGRY)
    ProtocolGame.unregisterExtendedOpcode(OPCODE_NO_MANA)
end

-- Helper: parse "creatureId,state" and set a boolean on the creature
local function handleIcon(protocol, opcode, buffer, setter)
    local data = buffer:split(",")
    if #data < 2 then return end

    local creatureId = tonumber(data[1])
    local state = tonumber(data[2]) == 1

    local creature = g_map.getCreatureById(creatureId)
    if creature then
        creature[setter](creature, state)
    end
end

function onHealCut(protocol, opcode, buffer)
    handleIcon(protocol, opcode, buffer, "setHealCut")
end

function onHungry(protocol, opcode, buffer)
    handleIcon(protocol, opcode, buffer, "setHungry")
end

function onNoMana(protocol, opcode, buffer)
    handleIcon(protocol, opcode, buffer, "setNoMana")
end
