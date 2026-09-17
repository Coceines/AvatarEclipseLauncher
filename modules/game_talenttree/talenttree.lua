-- ============================================================
-- TALENT TREE CLIENT MODULE
-- ============================================================
-- Arvore de talentos por vocation (Fire/Water/Air/Earth).
-- Comunica-se com o servidor via Extended Opcode 222.
-- Atalho global: CTRL + B
-- ============================================================

TalentTree = TalentTree or {}

local OPCODE          = 222
local window          = nil
local topbarButton    = nil
local currentTree     = "fire"
local availablePoints = 0
local playerLevel     = 1
local nodeWidgets     = {}   -- [talentId] = widget
local linkWidgets     = {}   -- list of link widgets
local pendingResetCost    = 0    -- custo de reset retornado pelo servidor
local pendingResetLearned = 0    -- quantidade de talentos aprendidos
local waitingCostInfo     = false -- aguardando resposta costinfo do servidor
local confirmBox          = nil  -- caixa de dialogo para confirmar aprendizado
local resetBox            = nil  -- caixa de dialogo para confirmar reset

-- ============================================================
-- MAPA VISUAL DOS NOS POR ARVORE
-- ============================================================
local NODE_SIZE   = 52
local COL_SPACING = 160
local ROW_SPACING = 85
local CANVAS_PADX = 45
local CANVAS_PADY = 20
local MAX_ROWS    = 5

-- Requisito de level por fila (row de baixo pra cima)
local ROW_LEVEL_REQ = {
    [1] = 50,
    [2] = 75,
    [3] = 100,
    [4] = 150,
    [5] = 200,
}

-- IDs de talentos por arvore (15 cada)
local TREE_TALENTS = {
    fire  = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
    water = {21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35},
    air   = {41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55},
    earth = {61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75},
}

-- Mapa de vocation ID -> nome da arvore
local VOCATION_TREE = {
    [1] = "fire",  [5] = "fire",
    [2] = "water", [6] = "water",
    [3] = "air",   [7] = "air",
    [4] = "earth", [8] = "earth",
}

-- Cores por tipo de efeito
local EFFECT_COLORS = {
    maxhp             = "#b82b2b",
    maxmana           = "#2858b8",
    benddmg           = "#d4751e",
    magiclevel        = "#8c32b8",
    speed             = "#28a87d",
    armor             = "#6b7280",
    shielding         = "#3b6cb8",
    grandarcane       = "#ba3aba",
    cooldownreduction = "#1da4cf",
    dodge             = "#b0e0ff",
    burnrank          = "#ff6a22",
    healcrit          = "#40d4a0",
}

-- ============================================================
-- DADOS PADRAO DOS TALENTOS (mirror do servidor)
-- ============================================================

local DEFAULT_TALENTS = {
    -- FIRE
    { id = 1,  learned=false, name="Scorching Touch I",     desc="Attacks may burn the target for 0.5% max HP/s for 5s (20s CD).",              tree="fire",  row=1, col=1, req={},   cost=1, minLevel=50,  effectType="burnrank",          excludes={} },
    { id = 2,  learned=false, name="Cauterize",             desc="Increases your Magic Level by 3.",                                            tree="fire",  row=2, col=1, req={1},  cost=1, minLevel=75,  effectType="magiclevel",        excludes={} },
    { id = 3,  learned=false, name="Scorching Touch II",    desc="Upgrades burn to deal 1.0% max HP/s for 5s (20s CD).",                        tree="fire",  row=3, col=1, req={2},  cost=1, minLevel=100, effectType="burnrank",          excludes={} },
    { id = 4,  learned=false, name="Blazing Soul",          desc="Increases your Magic Level by 5 and maximum Mana by 200.",                    tree="fire",  row=4, col=1, req={3},  cost=1, minLevel=150, effectType="grandarcane",       excludes={} },
    { id = 5,  learned=false, name="Pyromancer's Dominance",desc="Increases your spell/bending damage by 10%.",                                  tree="fire",  row=5, col=1, req={4},  cost=1, minLevel=200, effectType="benddmg",           excludes={} },

    { id = 6,  learned=false, name="Swift Flames I",        desc="Reduces your spell cooldowns by 6%.",                                         tree="fire",  row=1, col=2, req={},   cost=1, minLevel=50,  effectType="cooldownreduction", excludes={} },
    { id = 7,  learned=false, name="Swift Flames II",       desc="Reduces your spell cooldowns by an additional 6% (total 12%).",               tree="fire",  row=2, col=2, req={6},  cost=1, minLevel=75,  effectType="cooldownreduction", excludes={} },
    { id = 8,  learned=false, name="Swift Flames III",      desc="Reduces your spell cooldowns by an additional 6% (total 18%).",               tree="fire",  row=3, col=2, req={7},  cost=1, minLevel=100, effectType="cooldownreduction", excludes={} },
    { id = 9,  learned=false, name="Swift Flames IV",       desc="Reduces your spell cooldowns by an additional 6% (total 24%).",               tree="fire",  row=4, col=2, req={8},  cost=1, minLevel=150, effectType="cooldownreduction", excludes={} },
    { id = 10, learned=false, name="Swift Flames V",        desc="Reduces your spell cooldowns by an additional 6% (total 30%).",               tree="fire",  row=5, col=2, req={9},  cost=1, minLevel=200, effectType="cooldownreduction", excludes={} },

    { id = 11, learned=false, name="Flame Barrier I",       desc="Increases your maximum Health by 70.",                                        tree="fire",  row=1, col=3, req={},   cost=1, minLevel=50,  effectType="maxhp",             excludes={} },
    { id = 12, learned=false, name="Molten Armor",          desc="Increases your damage reduction armor by 4%.",                                tree="fire",  row=2, col=3, req={11}, cost=1, minLevel=75,  effectType="armor",             excludes={} },
    { id = 13, learned=false, name="Flame Barrier II",      desc="Increases your maximum Health by 130.",                                       tree="fire",  row=3, col=3, req={12}, cost=1, minLevel=100, effectType="maxhp",             excludes={} },
    { id = 14, learned=false, name="Ash Shield",            desc="Increases your damage reduction armor by 6%.",                                tree="fire",  row=4, col=3, req={13}, cost=1, minLevel=150, effectType="armor",             excludes={} },
    { id = 15, learned=false, name="Inferno Bastion",       desc="Increases your maximum Health by 220 and armor by 5%.",                       tree="fire",  row=5, col=3, req={14}, cost=1, minLevel=200, effectType="maxhp",             excludes={} },

    -- WATER
    { id = 21, learned=false, name="Healing Waters I",      desc="10% chance to critically heal allies for 50% more (no self-heal).",          tree="water", row=1, col=1, req={},   cost=1, minLevel=50,  effectType="healcrit",          excludes={31,32,33,34,35} },
    { id = 22, learned=false, name="Purifying Stream",      desc="Increases your Magic Level by 3 and maximum Mana by 150.",                    tree="water", row=2, col=1, req={21}, cost=1, minLevel=75,  effectType="grandarcane",       excludes={31,32,33,34,35} },
    { id = 23, learned=false, name="Healing Waters II",     desc="Increases ally healing critical chance to 20%.",                              tree="water", row=3, col=1, req={22}, cost=1, minLevel=100, effectType="healcrit",          excludes={31,32,33,34,35} },
    { id = 24, learned=false, name="Healing Waters III",    desc="Increases ally healing critical chance to 30%.",                              tree="water", row=4, col=1, req={23}, cost=1, minLevel=150, effectType="healcrit",          excludes={31,32,33,34,35} },
    { id = 25, learned=false, name="Ocean's Blessing",      desc="Increases your maximum Health by 250.",                                       tree="water", row=5, col=1, req={24}, cost=1, minLevel=200, effectType="maxhp",             excludes={31,32,33,34,35} },

    { id = 26, learned=false, name="Tidal Flow I",          desc="Reduces your spell cooldowns by 6%.",                                         tree="water", row=1, col=2, req={},   cost=1, minLevel=50,  effectType="cooldownreduction", excludes={} },
    { id = 27, learned=false, name="Tidal Flow II",         desc="Reduces your spell cooldowns by an additional 6% (total 12%).",               tree="water", row=2, col=2, req={26}, cost=1, minLevel=75,  effectType="cooldownreduction", excludes={} },
    { id = 28, learned=false, name="Tidal Flow III",        desc="Reduces your spell cooldowns by an additional 6% (total 18%).",               tree="water", row=3, col=2, req={27}, cost=1, minLevel=100, effectType="cooldownreduction", excludes={} },
    { id = 29, learned=false, name="Tidal Flow IV",         desc="Reduces your spell cooldowns by an additional 6% (total 24%).",               tree="water", row=4, col=2, req={28}, cost=1, minLevel=150, effectType="cooldownreduction", excludes={} },
    { id = 30, learned=false, name="Tidal Flow V",          desc="Reduces your spell cooldowns by an additional 6% (total 30%).",               tree="water", row=5, col=2, req={29}, cost=1, minLevel=200, effectType="cooldownreduction", excludes={} },

    { id = 31, learned=false, name="Crushing Wave I",       desc="Increases your spell/bending damage by 4%.",                                  tree="water", row=1, col=3, req={},   cost=1, minLevel=50,  effectType="benddmg",           excludes={21,22,23,24,25} },
    { id = 32, learned=false, name="Riptide",               desc="Increases your Magic Level by 3.",                                            tree="water", row=2, col=3, req={31}, cost=1, minLevel=75,  effectType="magiclevel",        excludes={21,22,23,24,25} },
    { id = 33, learned=false, name="Crushing Wave II",      desc="Increases your spell/bending damage by 6%.",                                  tree="water", row=3, col=3, req={32}, cost=1, minLevel=100, effectType="benddmg",           excludes={21,22,23,24,25} },
    { id = 34, learned=false, name="Undertow Surge",        desc="Increases your Magic Level by 5 and maximum Mana by 200.",                    tree="water", row=4, col=3, req={33}, cost=1, minLevel=150, effectType="grandarcane",       excludes={21,22,23,24,25} },
    { id = 35, learned=false, name="Abyssal Dominance",     desc="Increases your spell/bending damage by 10% and max Health by 150.",           tree="water", row=5, col=3, req={34}, cost=1, minLevel=200, effectType="benddmg",          excludes={21,22,23,24,25} },

    -- AIR
    { id = 41, learned=false, name="Gale Reflex I",         desc="Grants a 5% chance to completely evade any incoming damage.",                 tree="air",   row=1, col=1, req={},   cost=1, minLevel=50,  effectType="dodge",             excludes={} },
    { id = 42, learned=false, name="Zephyr Stride",         desc="Increases your Speed by 20.",                                                 tree="air",   row=2, col=1, req={41}, cost=1, minLevel=75,  effectType="speed",             excludes={} },
    { id = 43, learned=false, name="Gale Reflex II",        desc="Increases your evasion chance to 10% total.",                                 tree="air",   row=3, col=1, req={42}, cost=1, minLevel=100, effectType="dodge",             excludes={} },
    { id = 44, learned=false, name="Wind Veil",             desc="Increases your maximum Health by 120 and Speed by 15.",                       tree="air",   row=4, col=1, req={43}, cost=1, minLevel=150, effectType="maxhp",             excludes={} },
    { id = 45, learned=false, name="Eye of the Hurricane",  desc="Increases your Speed by 35 and armor by 5%.",                                 tree="air",   row=5, col=1, req={44}, cost=1, minLevel=200, effectType="speed",             excludes={} },

    { id = 46, learned=false, name="Wind Step I",           desc="Reduces your spell cooldowns by 6%.",                                         tree="air",   row=1, col=2, req={},   cost=1, minLevel=50,  effectType="cooldownreduction", excludes={} },
    { id = 47, learned=false, name="Wind Step II",          desc="Reduces your spell cooldowns by an additional 6% (total 12%).",               tree="air",   row=2, col=2, req={46}, cost=1, minLevel=75,  effectType="cooldownreduction", excludes={} },
    { id = 48, learned=false, name="Wind Step III",         desc="Reduces your spell cooldowns by an additional 6% (total 18%).",               tree="air",   row=3, col=2, req={47}, cost=1, minLevel=100, effectType="cooldownreduction", excludes={} },
    { id = 49, learned=false, name="Wind Step IV",          desc="Reduces your spell cooldowns by an additional 6% (total 24%).",               tree="air",   row=4, col=2, req={48}, cost=1, minLevel=150, effectType="cooldownreduction", excludes={} },
    { id = 50, learned=false, name="Wind Step V",           desc="Reduces your spell cooldowns by an additional 6% (total 30%).",               tree="air",   row=5, col=2, req={49}, cost=1, minLevel=200, effectType="cooldownreduction", excludes={} },

    { id = 51, learned=false, name="Razor Wind I",          desc="Increases your spell/bending damage by 4%.",                                  tree="air",   row=1, col=3, req={},   cost=1, minLevel=50,  effectType="benddmg",           excludes={} },
    { id = 52, learned=false, name="Gust Surge",            desc="Increases your Magic Level by 3.",                                            tree="air",   row=2, col=3, req={51}, cost=1, minLevel=75,  effectType="magiclevel",        excludes={} },
    { id = 53, learned=false, name="Razor Wind II",         desc="Increases your spell/bending damage by 6%.",                                  tree="air",   row=3, col=3, req={52}, cost=1, minLevel=100, effectType="benddmg",           excludes={} },
    { id = 54, learned=false, name="Tempest Force",         desc="Increases your Magic Level by 5 and maximum Mana by 150.",                    tree="air",   row=4, col=3, req={53}, cost=1, minLevel=150, effectType="grandarcane",       excludes={} },
    { id = 55, learned=false, name="Storm Unleashed",       desc="Increases your spell/bending damage by 10%.",                                 tree="air",   row=5, col=3, req={54}, cost=1, minLevel=200, effectType="benddmg",           excludes={} },

    -- EARTH
    { id = 61, learned=false, name="Iron Fortress I",       desc="Increases your maximum Health by 100.",                                       tree="earth", row=1, col=1, req={},   cost=1, minLevel=50,  effectType="maxhp",             excludes={71,72,73,74,75} },
    { id = 62, learned=false, name="Stone Barrier",         desc="Increases your Shielding skill by 5.",                                        tree="earth", row=2, col=1, req={61}, cost=1, minLevel=75,  effectType="shielding",         excludes={71,72,73,74,75} },
    { id = 63, learned=false, name="Iron Fortress II",      desc="Increases your damage reduction armor by 5%.",                                tree="earth", row=3, col=1, req={62}, cost=1, minLevel=100, effectType="armor",             excludes={71,72,73,74,75} },
    { id = 64, learned=false, name="Bedrock Skin",          desc="Increases your maximum Health by 180 and Shielding by 4.",                    tree="earth", row=4, col=1, req={63}, cost=1, minLevel=150, effectType="maxhp",             excludes={71,72,73,74,75} },
    { id = 65, learned=false, name="Mountain's Heart",      desc="Pinnacle of defense: +8% armor and +8 Shielding.",                            tree="earth", row=5, col=1, req={64}, cost=1, minLevel=200, effectType="armor",             excludes={71,72,73,74,75} },

    { id = 66, learned=false, name="Stone Wall I",          desc="Reduces your spell cooldowns by 6%.",                                         tree="earth", row=1, col=2, req={},   cost=1, minLevel=50,  effectType="cooldownreduction", excludes={} },
    { id = 67, learned=false, name="Stone Wall II",         desc="Reduces your spell cooldowns by an additional 6% (total 12%).",               tree="earth", row=2, col=2, req={66}, cost=1, minLevel=75,  effectType="cooldownreduction", excludes={} },
    { id = 68, learned=false, name="Stone Wall III",        desc="Reduces your spell cooldowns by an additional 6% (total 18%).",               tree="earth", row=3, col=2, req={67}, cost=1, minLevel=100, effectType="cooldownreduction", excludes={} },
    { id = 69, learned=false, name="Stone Wall IV",         desc="Reduces your spell cooldowns by an additional 6% (total 24%).",               tree="earth", row=4, col=2, req={68}, cost=1, minLevel=150, effectType="cooldownreduction", excludes={} },
    { id = 70, learned=false, name="Stone Wall V",          desc="Reduces your spell cooldowns by an additional 6% (total 30%).",               tree="earth", row=5, col=2, req={69}, cost=1, minLevel=200, effectType="cooldownreduction", excludes={} },

    { id = 71, learned=false, name="Seismic Force I",       desc="Increases your spell/bending damage by 6% and Magic Level by 3.",             tree="earth", row=1, col=3, req={},   cost=1, minLevel=50,  effectType="benddmg",           excludes={61,62,63,64,65} },
    { id = 72, learned=false, name="Tectonic Strike",       desc="Increases your Magic Level by 4.",                                            tree="earth", row=2, col=3, req={71}, cost=1, minLevel=75,  effectType="magiclevel",        excludes={61,62,63,64,65} },
    { id = 73, learned=false, name="Seismic Force II",      desc="Increases your spell/bending damage by 8%.",                                  tree="earth", row=3, col=3, req={72}, cost=1, minLevel=100, effectType="benddmg",           excludes={61,62,63,64,65} },
    { id = 74, learned=false, name="Earth Crusher",         desc="Increases your Magic Level by 6 and maximum Mana by 200.",                    tree="earth", row=4, col=3, req={73}, cost=1, minLevel=150, effectType="grandarcane",       excludes={61,62,63,64,65} },
    { id = 75, learned=false, name="Titan's Wrath",         desc="Master offensive talent: +12% damage and +100 max Health.",                   tree="earth", row=5, col=3, req={74}, cost=1, minLevel=200, effectType="benddmg",          excludes={61,62,63,64,65} },
}

local DEFAULT_TALENTS_BY_ID = {}
for _, t in ipairs(DEFAULT_TALENTS) do
    DEFAULT_TALENTS_BY_ID[t.id] = t
end

-- Icones dos talentos (sprites de game_proficiency)
local TALENT_ICONS = {
    -- Fire
    [1]  = { source="icons-8", offset=0 },    -- Burn I
    [2]  = { source="icons-8", offset=384 },  -- ML
    [3]  = { source="icons-8", offset=64 },   -- Burn II
    [4]  = { source="icons-8", offset=192 },  -- grandarcane
    [5]  = { source="icons-0", offset=0 },    -- benddmg
    [6]  = { source="icons-0", offset=1024 }, -- CDR 1
    [7]  = { source="icons-0", offset=1024 }, -- CDR 2
    [8]  = { source="icons-0", offset=1024 }, -- CDR 3
    [9]  = { source="icons-0", offset=1024 }, -- CDR 4
    [10] = { source="icons-0", offset=1024 }, -- CDR 5
    [11] = { source="icons-0", offset=768 },  -- maxhp
    [12] = { source="icons-0", offset=64 },   -- armor
    [13] = { source="icons-0", offset=768 },  -- maxhp
    [14] = { source="icons-0", offset=64 },   -- armor
    [15] = { source="icons-0", offset=768 },  -- maxhp

    -- Water
    [21] = { source="icons-0", offset=704 },  -- healcrit 1
    [22] = { source="icons-8", offset=192 },  -- grandarcane
    [23] = { source="icons-0", offset=704 },  -- healcrit 2
    [24] = { source="icons-0", offset=704 },  -- healcrit 3
    [25] = { source="icons-0", offset=768 },  -- maxhp
    [26] = { source="icons-0", offset=1024 }, -- CDR 1
    [27] = { source="icons-0", offset=1024 }, -- CDR 2
    [28] = { source="icons-0", offset=1024 }, -- CDR 3
    [29] = { source="icons-0", offset=1024 }, -- CDR 4
    [30] = { source="icons-0", offset=1024 }, -- CDR 5
    [31] = { source="icons-0", offset=0 },    -- benddmg
    [32] = { source="icons-8", offset=384 },  -- ML
    [33] = { source="icons-0", offset=0 },    -- benddmg
    [34] = { source="icons-8", offset=192 },  -- grandarcane
    [35] = { source="icons-0", offset=0 },    -- benddmg

    -- Air
    [41] = { source="icons-0", offset=1088 }, -- dodge 1
    [42] = { source="icons-0", offset=1024 }, -- speed
    [43] = { source="icons-0", offset=1088 }, -- dodge 2
    [44] = { source="icons-0", offset=768 },  -- maxhp
    [45] = { source="icons-0", offset=1024 }, -- speed/armor
    [46] = { source="icons-0", offset=1024 }, -- CDR 1
    [47] = { source="icons-0", offset=1024 }, -- CDR 2
    [48] = { source="icons-0", offset=1024 }, -- CDR 3
    [49] = { source="icons-0", offset=1024 }, -- CDR 4
    [50] = { source="icons-0", offset=1024 }, -- CDR 5
    [51] = { source="icons-0", offset=0 },    -- benddmg
    [52] = { source="icons-8", offset=384 },  -- ML
    [53] = { source="icons-0", offset=0 },    -- benddmg
    [54] = { source="icons-8", offset=192 },  -- grandarcane
    [55] = { source="icons-7", offset=0 },    -- benddmg master

    -- Earth
    [61] = { source="icons-0", offset=768 },  -- maxhp
    [62] = { source="icons-0", offset=64 },   -- shielding
    [63] = { source="icons-0", offset=64 },   -- armor
    [64] = { source="icons-0", offset=768 },  -- maxhp
    [65] = { source="icons-0", offset=64 },   -- armor
    [66] = { source="icons-0", offset=1024 }, -- CDR 1
    [67] = { source="icons-0", offset=1024 }, -- CDR 2
    [68] = { source="icons-0", offset=1024 }, -- CDR 3
    [69] = { source="icons-0", offset=1024 }, -- CDR 4
    [70] = { source="icons-0", offset=1024 }, -- CDR 5
    [71] = { source="icons-0", offset=0 },    -- benddmg
    [72] = { source="icons-8", offset=384 },  -- ML
    [73] = { source="icons-0", offset=0 },    -- benddmg
    [74] = { source="icons-8", offset=192 },  -- grandarcane
    [75] = { source="icons-7", offset=0 },    -- benddmg master
}

local DEFAULT_EFFECT_ICONS = {
    maxhp             = { source="icons-0", offset=768 },
    maxmana           = { source="icons-0", offset=704 },
    benddmg           = { source="icons-0", offset=0 },
    magiclevel        = { source="icons-8", offset=384 },
    speed             = { source="icons-0", offset=1024 },
    armor             = { source="icons-0", offset=64 },
    shielding         = { source="icons-0", offset=64 },
    grandarcane       = { source="icons-8", offset=192 },
    cooldownreduction = { source="icons-0", offset=1024 },
    dodge             = { source="icons-0", offset=1088 },
    burnrank          = { source="icons-8", offset=0 },
    healcrit          = { source="icons-0", offset=704 },
}

local talentData = {}

local function cloneDefaultTalents()
    local copy = {}
    for i, t in ipairs(DEFAULT_TALENTS) do
        copy[i] = {
            id         = t.id,
            learned    = false,
            name       = t.name,
            desc       = t.desc,
            tree       = t.tree,
            row        = t.row,
            col        = t.col,
            req        = t.req,
            cost       = t.cost,
            minLevel   = t.minLevel,
            effectType = t.effectType,
            excludes   = t.excludes or {},
        }
    end
    return copy
end

talentData = cloneDefaultTalents()

-- ============================================================
-- TOPBAR BUTTON
-- ============================================================

function createTopbarButton()
    if not modules.client_topmenu or topbarButton then return end

    topbarButton = modules.client_topmenu.addRightGameToggleButton(
        'talentTreeButton',
        tr('Talents') .. ' (Ctrl+B)',
        '/images/topbuttons/talenttree',
        function() TalentTree:toggle() end
    )

    if topbarButton then
        topbarButton:setOn(false)
    end
end

-- ============================================================
-- INIT / TERMINATE
-- ============================================================

function TalentTree:init()
    pcall(function()
        if g_shaders and g_shaders.createShader then
            g_shaders.createShader("talent_border_glow", "/shaders/map_default_vertex", "/shaders/talent_border_glow")
        end
    end)

    ProtocolGame.registerExtendedOpcode(OPCODE, onTalentTreeOpcode)

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = onGameEnd,
    })

    g_keyboard.bindKeyDown('Ctrl+B', function() TalentTree:toggle() end)

    createTopbarButton()

    if g_game.isOnline() then
        onGameStart()
    end
end

function TalentTree:terminate()
    pcall(function()
        ProtocolGame.unregisterExtendedOpcode(OPCODE)
    end)

    g_keyboard.unbindKeyDown('Ctrl+B')

    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = onGameEnd,
    })

    if confirmBox then
        confirmBox:destroy()
        confirmBox = nil
    end
    if resetBox then
        resetBox:destroy()
        resetBox = nil
    end

    if topbarButton then
        topbarButton:destroy()
        topbarButton = nil
    end

    if window then
        window:destroy()
        window = nil
    end

    talentData      = cloneDefaultTalents()
    nodeWidgets     = {}
    linkWidgets     = {}
    availablePoints = 0
end

-- ============================================================
-- GAME LIFECYCLE
-- ============================================================

function onGameStart()
    createTopbarButton()
    requestData()
end

function onGameEnd()
    if confirmBox then
        confirmBox:destroy()
        confirmBox = nil
    end
    if resetBox then
        resetBox:destroy()
        resetBox = nil
    end
    talentData          = cloneDefaultTalents()
    nodeWidgets         = {}
    linkWidgets         = {}
    availablePoints     = 0
    playerLevel         = 1   -- reseta level para nao vazar dados entre personagens
    pendingResetCost    = 0
    pendingResetLearned = 0
    waitingCostInfo     = false
    if window then
        window:hide()
    end
    if topbarButton then
        topbarButton:setOn(false)
    end
end

-- ============================================================
-- COMUNICACAO COM O SERVIDOR
-- ============================================================

function requestData()
    local protocol = g_game.getProtocolGame()
    if protocol and g_game.isOnline() then
        protocol:sendExtendedOpcode(OPCODE, json.encode({ action = "request" }))
    end
end

function sendLearnTalent(talentId)
    local protocol = g_game.getProtocolGame()
    if protocol and g_game.isOnline() then
        protocol:sendExtendedOpcode(OPCODE, json.encode({
            action   = "learn",
            talentId = talentId
        }))
    end
    -- Nao ha fallback local: toda alteracao de talentos depende do servidor.
end

function sendResetTalents()
    local protocol = g_game.getProtocolGame()
    if protocol and g_game.isOnline() then
        protocol:sendExtendedOpcode(OPCODE, json.encode({ action = "reset" }))
    end
    -- Nao ha fallback local: toda alteracao de talentos depende do servidor.
end

-- ============================================================
-- HANDLER DO OPCODE 222
-- ============================================================

function onTalentTreeOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE or buffer == "" then return end

    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then return end

    if data.action == "data" then
        availablePoints = data.points or 0
        playerLevel     = data.level or 1
        if data.resetCost ~= nil then
            pendingResetCost = tonumber(data.resetCost) or 0
        end
        if data.learnedCnt ~= nil then
            pendingResetLearned = tonumber(data.learnedCnt) or 0
        end
        if data.vocTree then
            currentTree = data.vocTree
        end

        if type(data.talents) == "table" and #data.talents > 0 then
            for _, st in ipairs(data.talents) do
                local def = DEFAULT_TALENTS_BY_ID[st.id]
                if def then
                    st.effectType = st.effectType or def.effectType
                    st.name       = st.name or def.name
                    st.desc       = st.desc or def.desc
                    st.req        = st.req or def.req
                    st.cost       = st.cost or def.cost
                    st.minLevel   = st.minLevel or def.minLevel or (ROW_LEVEL_REQ[st.row] or 1)
                    st.tree       = st.tree or def.tree
                    st.row        = st.row or def.row
                    st.col        = st.col or def.col
                    st.excludes   = st.excludes or def.excludes or {}
                end
            end
            talentData = data.talents
        end

        if window and window:isVisible() then
            rebuildTreeCanvas()
            updateResetCostLabel()
        end
    elseif data.action == "costinfo" then
        -- Resposta do servidor com custo atual de reset
        pendingResetCost    = data.resetCost or 0
        pendingResetLearned = data.learned  or 0
        updateResetCostLabel()
        if waitingCostInfo then
            waitingCostInfo = false
            showResetDialog()
        end
    elseif data.action == "error" then
        if modules.game_textmessage then
            modules.game_textmessage.displayFailureMessage(data.msg or "Unknown error.")
        end
    end
end

-- ============================================================
-- JANELA
-- ============================================================

function TalentTree:toggle()
    if not window then
        createWindow()
    end

    if not window then
        return
    end

    if window:isVisible() then
        if confirmBox then confirmBox:destroy() confirmBox = nil end
        if resetBox then resetBox:destroy() resetBox = nil end
        window:hide()
        if topbarButton then topbarButton:setOn(false) end
    else
        window:show()
        window:raise()
        window:focus()
        if topbarButton then topbarButton:setOn(true) end
        requestData()
        refreshUI()
    end
end

function createWindow()
    if window then return end

    window = g_ui.displayUI('talenttree')
    if not window then
        print("[TalentTree] ERROR: Failed to create window from talenttree.otui")
        return
    end
    window:hide()

    local closeBtn = window:getChildById('closeButton')
    if closeBtn then
        closeBtn.onClick = function() TalentTree:toggle() end
    end

    local resetBtn = window:recursiveGetChildById('resetButton')
    if resetBtn then
        resetBtn.onClick = function() TalentTree.onResetClick() end
    end

    local startTree = getPlayerTree()
    currentTree = startTree
    applyVocationFilter(startTree)
    selectTree(startTree)
end

function getPlayerTree()
    local player = g_game.getLocalPlayer()
    if player then
        local voc = player:getVocation()
        if VOCATION_TREE[voc] then
            return VOCATION_TREE[voc]
        end
    end
    return "fire"
end

function applyVocationFilter(playerTree)
    -- As abas foram removidas; a vocation ja define a arvore automaticamente.
end

-- ============================================================
-- SELECAO DE ARVORE (ABA)
-- ============================================================

function TalentTree.selectTree(treeName)
    selectTree(treeName)
end

function selectTree(treeName)
    currentTree = treeName or "fire"
    rebuildTreeCanvas()
end

-- ============================================================
-- CONSTRUIR O CANVAS DA ARVORE
-- ============================================================

function rebuildTreeCanvas()
    if not window then return end

    local canvas = window:recursiveGetChildById('treeCanvas')
    if not canvas then return end

    canvas:destroyChildren()
    nodeWidgets = {}
    linkWidgets = {}

    local ids = TREE_TALENTS[currentTree] or {}

    local byId = {}
    for _, t in ipairs(talentData) do
        byId[t.id] = t
    end

    local function nodePos(row, col)
        local x = CANVAS_PADX + (col - 1) * COL_SPACING
        local y = CANVAS_PADY + (MAX_ROWS - row) * ROW_SPACING
        return x, y
    end

    local excludedIds = buildExcludedSet(byId, ids)

    -- 1. Linhas de conexao (Requires links)
    for _, id in ipairs(ids) do
        local t = byId[id]
        if t and t.req then
            for _, reqId in ipairs(t.req) do
                local reqT = byId[reqId]
                if reqT then
                    drawLink(canvas, t, reqT)
                end
            end
        end
    end

    -- 2. Nos
    for _, id in ipairs(ids) do
        local t = byId[id]
        if t then
            local x, y = nodePos(t.row, t.col)
            createNodeWidget(canvas, t, x, y, excludedIds[id] or false)
        end
    end

    updateNodeStates(byId)
    updatePointsLabel()
    updateResetCostLabel()
end

function buildExcludedSet(byId, ids)
    local excluded = {}
    for _, id in ipairs(ids) do
        local t = byId[id]
        if t and t.learned and t.excludes then
            for _, exId in ipairs(t.excludes) do
                excluded[exId] = true
            end
        end
    end
    return excluded
end

-- ============================================================
-- CRIAR NO WIDGET
-- ============================================================

function createNodeWidget(canvas, talent, x, y, isExcluded)
    local node = g_ui.createWidget('TalentNode', canvas)
    node:setId('talentNode' .. talent.id)
    node:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    node:addAnchor(AnchorTop, 'parent', AnchorTop)
    node:setMarginLeft(x)
    node:setMarginTop(y)
    node:setWidth(NODE_SIZE)
    node:setHeight(NODE_SIZE)

    local iconData = TALENT_ICONS[talent.id] or DEFAULT_EFFECT_ICONS[talent.effectType or ''] or { source="icons-0", offset=0 }
    local icon = node:getChildById('nodeIcon')
    if icon then
        icon:setImageSource('/modules/game_proficiency/images/' .. iconData.source)
        local yOffset = talent.learned and 0 or 64
        if torect then
            icon:setImageClip(torect(string.format("%d %d 64 64", iconData.offset, yOffset)))
        end
    end

    local border = node:getChildById('border')
    if border then
        if talent.learned then
            border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-active')
            if border.setImageShader then
                border:setImageShader("talent_border_glow")
            end
        else
            border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-inactive')
            if border.setImageShader then
                border:setImageShader("")
            end
        end
    end

    local costLabel = node:getChildById('nodeCost')
    if costLabel then
        if talent.learned then
            costLabel:setText("OK")
            costLabel:setColor('#4CAF50')
        else
            costLabel:setText(tostring(talent.cost or 1))
            costLabel:setColor('#e7b131')
        end
    end

    if isExcluded and not talent.learned then
        node:setOpacity(0.25)
        if border then
            border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-inactive')
        end
    end

    -- Sempre habilitado para hover/tooltip — o click que verifica se pode aprender
    node:setEnabled(true)

    node.onHoverChange = function(widget, hovered)
        if hovered then
            showTalentInfo(talent)
        end
    end

    node.onClick = function(widget)
        onNodeClick(talent)
    end

    nodeWidgets[talent.id] = node
    return node
end

-- ============================================================
-- DESENHAR LINK (LINHA DE CONEXAO)
-- ============================================================

function drawLink(canvas, talent, reqTalent)
    local function center(row, col)
        local x = CANVAS_PADX + (col - 1) * COL_SPACING + math.floor(NODE_SIZE / 2)
        local y = CANVAS_PADY + (MAX_ROWS - row) * ROW_SPACING + math.floor(NODE_SIZE / 2)
        return x, y
    end

    local x1, y1 = center(reqTalent.row, reqTalent.col)
    local x2, y2 = center(talent.row, talent.col)

    local link
    if talent.col == reqTalent.col then
        link = g_ui.createWidget('TalentLinkV', canvas)
        link:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        link:addAnchor(AnchorTop, 'parent', AnchorTop)
        link:setMarginLeft(math.floor(x1 - 1))
        link:setMarginTop(math.floor(math.min(y1, y2)))
        link:setWidth(2)
        link:setHeight(math.floor(math.abs(y2 - y1)))
    elseif talent.row == reqTalent.row then
        link = g_ui.createWidget('TalentLinkH', canvas)
        link:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        link:addAnchor(AnchorTop, 'parent', AnchorTop)
        local lx = math.min(x1, x2)
        link:setMarginLeft(math.floor(lx))
        link:setMarginTop(math.floor(y1 - 1))
        link:setWidth(math.abs(x2 - x1))
        link:setHeight(2)
    else
        local linkV = g_ui.createWidget('TalentLinkV', canvas)
        linkV:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        linkV:addAnchor(AnchorTop, 'parent', AnchorTop)
        linkV:setMarginLeft(math.floor(x1 - 1))
        local minY = math.min(y1, y2)
        linkV:setMarginTop(math.floor(minY))
        linkV:setWidth(2)
        linkV:setHeight(math.floor(math.abs(y2 - y1)))
        linkWidgets[#linkWidgets + 1] = {widget = linkV, from = reqTalent.id, to = talent.id}

        link = g_ui.createWidget('TalentLinkH', canvas)
        link:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        link:addAnchor(AnchorTop, 'parent', AnchorTop)
        local minX = math.min(x1, x2)
        link:setMarginLeft(math.floor(minX))
        link:setMarginTop(math.floor(y2 - 1))
        link:setWidth(math.floor(math.abs(x2 - x1) + 2))
        link:setHeight(2)
    end

    if link then
        linkWidgets[#linkWidgets + 1] = {widget = link, from = reqTalent.id, to = talent.id}
    end
end

-- ============================================================
-- ATUALIZAR ESTADOS DOS NOS
-- ============================================================

function updateNodeStates(byId)
    if not byId then
        byId = {}
        for _, t in ipairs(talentData) do
            byId[t.id] = t
        end
    end

    local ids = TREE_TALENTS[currentTree] or {}
    local excludedIds = buildExcludedSet(byId, ids)

    for _, id in ipairs(ids) do
        local t = byId[id]
        local node = nodeWidgets[id]
        if t and node then
            local iconData = TALENT_ICONS[t.id] or DEFAULT_EFFECT_ICONS[t.effectType or ''] or { source="icons-0", offset=0 }
            local icon = node:getChildById('nodeIcon')
            local border = node:getChildById('border')
            local costLabel = node:getChildById('nodeCost')

            if t.learned then
                node:setOn(true)
                node:setEnabled(true)
                node:setOpacity(1.0)
                if border then
                    border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-active')
                    if border.setImageShader then
                        border:setImageShader("talent_border_glow")
                    end
                end
                if icon and torect then
                    icon:setImageClip(torect(string.format("%d 0 64 64", iconData.offset)))
                end
                if costLabel then
                    costLabel:setText("OK")
                    costLabel:setColor('#4CAF50')
                end

            elseif excludedIds[id] then
                node:setOn(false)
                node:setEnabled(true)  -- mantém hover ativo
                node:setOpacity(0.2)
                if border then
                    border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-inactive')
                    if border.setImageShader then
                        border:setImageShader("")
                    end
                end
                if icon and torect then
                    icon:setImageClip(torect(string.format("%d 64 64 64", iconData.offset)))
                end
                if costLabel then
                    costLabel:setText(tostring(t.cost or 1))
                    costLabel:setColor('#555555')
                end

            elseif canLearnTalent(t, byId) then
                node:setOn(false)
                node:setEnabled(true)
                node:setOpacity(1.0)
                if border then
                    border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-inactive')
                    if border.setImageShader then
                        border:setImageShader("")
                    end
                end
                if icon and torect then
                    icon:setImageClip(torect(string.format("%d 64 64 64", iconData.offset)))
                end
                if costLabel then
                    costLabel:setText(tostring(t.cost or 1))
                    costLabel:setColor('#e7b131')
                end

            else
                node:setOn(false)
                node:setEnabled(true)  -- mantém hover ativo mesmo bloqueado
                node:setOpacity(0.4)
                if border then
                    border:setImageSource('/modules/game_proficiency/images/border-weaponmasterytreeicons-inactive')
                    if border.setImageShader then
                        border:setImageShader("")
                    end
                end
                if icon and torect then
                    icon:setImageClip(torect(string.format("%d 64 64 64", iconData.offset)))
                end
                if costLabel then
                    costLabel:setText(tostring(t.cost or 1))
                    costLabel:setColor('#888888')
                end
            end
        end
    end

    -- Atualiza links
    for _, linkInfo in ipairs(linkWidgets) do
        local fromT = byId[linkInfo.from]
        local toT   = byId[linkInfo.to]
        local activated = fromT and fromT.learned and toT and toT.learned
        if linkInfo.widget then
            linkInfo.widget:setOn(activated or false)
        end
    end
end

function canLearnTalent(talent, byId)
    if talent.learned then return false end
    if playerLevel < (talent.minLevel or (ROW_LEVEL_REQ[talent.row] or 1)) then return false end
    if availablePoints < (talent.cost or 1) then return false end

    -- Verifica exclusoes
    if talent.excludes then
        for _, exId in ipairs(talent.excludes) do
            local ex = byId[exId]
            if ex and ex.learned then return false end
        end
    end

    -- Verifica requisitos (Requires)
    for _, reqId in ipairs(talent.req or {}) do
        local req = byId[reqId]
        if not req or not req.learned then return false end
    end

    return true
end

-- ============================================================
-- INFO PANEL
-- ============================================================

function showTalentInfo(talent)
    if not window then return end

    local nameL  = window:recursiveGetChildById('infoName')
    local descL  = window:recursiveGetChildById('infoDesc')
    local costL  = window:recursiveGetChildById('infoCost')
    local reqL   = window:recursiveGetChildById('infoReq')
    local statL  = window:recursiveGetChildById('infoStatus')

    if nameL then nameL:setText(talent.name or '') end
    if descL then descL:setText(talent.desc or '') end
    if costL then costL:setText(tr('Cost: %d point(s)', talent.cost or 1)) end

    local minLevel = talent.minLevel or (ROW_LEVEL_REQ[talent.row] or 1)
    local reqParts = {}
    if minLevel and minLevel > 1 then
        reqParts[#reqParts + 1] = string.format("Level %d", minLevel)
    end

    if talent.req and #talent.req > 0 then
        local byId = {}
        for _, t in ipairs(talentData) do byId[t.id] = t end
        local reqNames = {}
        for _, rid in ipairs(talent.req) do
            local rt = byId[rid]
            if rt then
                reqNames[#reqNames + 1] = rt.name
            end
        end
        if #reqNames > 0 then
            reqParts[#reqParts + 1] = table.concat(reqNames, ', ')
        end
    end

    if reqL then
        if #reqParts > 0 then
            reqL:setText(tr('Requires: ') .. table.concat(reqParts, ' | '))
        else
            reqL:setText(tr('No requirements'))
        end
    end

    if statL then
        local byId = {}
        for _, t in ipairs(talentData) do byId[t.id] = t end

        if talent.learned then
            statL:setText(tr('Learned'))
            statL:setColor('#4CAF50')
        else
            local isExcluded = false
            if talent.excludes then
                for _, exId in ipairs(talent.excludes) do
                    local ex = byId[exId]
                    if ex and ex.learned then isExcluded = true; break end
                end
            end

            if isExcluded then
                statL:setText(tr('Locked — opposite path chosen'))
                statL:setColor('#cc4444')
            elseif canLearnTalent(talent, byId) then
                statL:setText(tr('Click to learn'))
                statL:setColor('#e7b131')
            else
                local reason = getCannotLearnReason(talent, byId)
                statL:setText(reason)
                statL:setColor('#cc4444')
            end
        end
    end
end

function getCannotLearnReason(talent, byId)
    if talent.learned then
        return tr('You have already learned this talent.')
    end
    if talent.excludes then
        for _, exId in ipairs(talent.excludes) do
            local ex = byId[exId]
            if ex and ex.learned then
                return tr('Locked — you chose the opposite path. Reset to change.')
            end
        end
    end
    local minLevel = talent.minLevel or (ROW_LEVEL_REQ[talent.row] or 1)
    if playerLevel < minLevel then
        return string.format("Level %d required (current: %d).", minLevel, playerLevel)
    end
    for _, reqId in ipairs(talent.req or {}) do
        local req = byId[reqId]
        if not req or not req.learned then
            local reqName = req and req.name or tr("previous talent")
            return string.format('Requires: %s', reqName)
        end
    end
    if availablePoints < (talent.cost or 1) then
        return string.format('Not enough talent points. Need %d, have %d.', talent.cost or 1, availablePoints)
    end
    return tr('Cannot learn this talent.')
end

-- ============================================================
-- CLICK NO NO
-- ============================================================

function onNodeClick(talent)
    local byId = {}
    for _, t in ipairs(talentData) do byId[t.id] = t end

    showTalentInfo(talent)

    if talent.learned then
        if modules.game_textmessage then
            modules.game_textmessage.displayFailureMessage(tr('You already learned this talent.'))
        end
        return
    end

    if not canLearnTalent(talent, byId) then
        local reason = getCannotLearnReason(talent, byId)
        if modules.game_textmessage then
            modules.game_textmessage.displayFailureMessage(reason)
        end
        return
    end

    -- Fecha dialogo anterior se ainda estiver aberto
    if confirmBox then
        confirmBox:destroy()
        confirmBox = nil
    end

    -- Dialogo de confirmacao: aprender e permanente
    local confirmMsg = string.format(
        'Learn "%s"?\n\nThis choice is PERMANENT and cannot be undone\nwithout spending gold to reset your talent tree.',
        talent.name
    )

    local yesCallback = function()
        if confirmBox then
            confirmBox:destroy()
            confirmBox = nil
        end
        sendLearnTalent(talent.id)
    end

    local noCallback = function()
        if confirmBox then
            confirmBox:destroy()
            confirmBox = nil
        end
    end

    confirmBox = displayGeneralBox(tr('Confirm Talent'), confirmMsg, {
        { text = tr('Learn'),  callback = yesCallback },
        { text = tr('Cancel'), callback = noCallback },
        anchor = AnchorHorizontalCenter
    }, yesCallback, noCallback)
end

-- ============================================================
-- BOTAO RESET
-- ============================================================

function TalentTree.onResetClick()
    -- Pede o custo atual ao servidor antes de exibir o dialogo
    local protocol = g_game.getProtocolGame()
    if not protocol or not g_game.isOnline() then return end
    waitingCostInfo = true
    protocol:sendExtendedOpcode(OPCODE, json.encode({ action = "costinfo" }))
    -- O dialogo sera aberto em showResetDialog() quando a resposta chegar
end

function showResetDialog()
    if resetBox then
        resetBox:destroy()
        resetBox = nil
    end

    local costMsg
    if pendingResetCost == 0 then
        if pendingResetLearned == 0 then
            costMsg = tr('You have no talents to reset.')
        else
            costMsg = tr('Resetting talents is free (level 50 or below). Proceed?')
        end
    else
        costMsg = string.format(
            'Resetting your %d talent(s) costs %s gold (%d x 5,000g).\n\nAll learned talents will be lost. Proceed?',
            pendingResetLearned, comma_value(pendingResetCost), pendingResetLearned
        )
    end

    local yesCallback = function()
        if resetBox then
            resetBox:destroy()
            resetBox = nil
        end
        sendResetTalents()
    end

    local noCallback = function()
        if resetBox then
            resetBox:destroy()
            resetBox = nil
        end
    end

    resetBox = displayGeneralBox(tr('Reset Talents'), costMsg, {
        { text = tr('Yes'), callback = yesCallback },
        { text = tr('No'),  callback = noCallback },
        anchor = AnchorHorizontalCenter
    }, yesCallback, noCallback)
end

function comma_value(n)
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    if not left then return tostring(n) end
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function getLearnedTalentsCount()
    local count = 0
    if talentData then
        for _, t in ipairs(talentData) do
            if t.learned then
                count = count + 1
            end
        end
    end
    return count
end

function updateResetCostLabel()
    if not window then return end
    local lbl = window:recursiveGetChildById('resetCostLabel')
    if not lbl then return end

    local count = pendingResetLearned
    if not count or count == 0 then
        count = getLearnedTalentsCount()
    end

    if playerLevel <= 50 then
        lbl:setText("Cost to reset talents: Free (level 50 or below)")
        lbl:setColor("#77dd77")
    elseif count == 0 then
        lbl:setText("Cost to reset talents: Free (0 learned)")
        lbl:setColor("#888888")
    else
        local cost = (pendingResetCost and pendingResetCost > 0) and pendingResetCost or (count * 5000)
        local suffix = (count > 1) and "s" or ""
        lbl:setText(string.format("Cost to reset talents: %s gold (%d talent%s)", comma_value(cost), count, suffix))
        lbl:setColor("#ffcc44")
    end
end

function updatePointsLabel()
    if not window then return end
    local lbl = window:recursiveGetChildById('pointsValue')
    if lbl then
        lbl:setText(tostring(availablePoints))
    end
end

function refreshUI()
    if not window or not window:isVisible() then return end
    updatePointsLabel()
    updateResetCostLabel()
    local byId = {}
    for _, t in ipairs(talentData) do
        byId[t.id] = t
    end
    updateNodeStates(byId)
end
