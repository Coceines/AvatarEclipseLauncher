-- Bosses do sistema ALPHA: +20% de tamanho.
-- O nome do monstro no servidor comeca com "ALPHA " (ex: "ALPHA Cockroach"),
-- entao nao precisa registrar cada boss na tabela abaixo.
local ALPHA_PREFIX = "alpha "
local ALPHA_SCALE = 1.2

local outfitScales = {
    ["fierce bear"] = 0.6,
    ["steel shell centipede"] = 0.6,
    ["wild wolf"] = 0.8,
    ["vacaceronte"] = 0.6,
    ["desert crocodile"] = 0.6,
    ["giant snail"] = 0.6,
    ["urso feroz"] = 0.6,
    ["centopeia carapaca de aco"] = 0.6,
    ["lobo selvagem"] = 0.8,
    ["crocodilo do deserto"] = 0.6,
    ["caracol gigante"] = 0.6,
}

function init()
    connect(Creature, {
        onAppear = onCreatureAppearScale,
    })
end

function terminate()
    disconnect(Creature, {
        onAppear = onCreatureAppearScale,
    })
end

function onCreatureAppearScale(creature)
    if not creature then return end
    local ok, err = pcall(function()
        local id = creature:getId()
        if not id or id == 0 then return end
        local name = creature:getName()
        if not name or name == "" then return end
        local key = name:lower()
        local scale = outfitScales[key]
        if not scale and key:sub(1, #ALPHA_PREFIX) == ALPHA_PREFIX then
            scale = ALPHA_SCALE
        end
        if scale then
            creature:setOutfitScale(scale)
        end
    end)
    if not ok then
    end
end

function setOutfitScaleByName(name, scale)
    if type(name) ~= "string" or type(scale) ~= "number" then return end
    outfitScales[name:lower()] = scale
end

function getOutfitScaleByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    local key = name:lower()
    local scale = outfitScales[key]
    if not scale and key:sub(1, #ALPHA_PREFIX) == ALPHA_PREFIX then
        scale = ALPHA_SCALE
    end
    return scale
end

function isAlphaBoss(name)
    if type(name) ~= "string" or name == "" then return false end
    return name:lower():sub(1, #ALPHA_PREFIX) == ALPHA_PREFIX
end
