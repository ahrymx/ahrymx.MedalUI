local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PRESETS
-- Ready-made radials, read-only. A player adds a copy (RM:AddPreset), changes it however they like,
-- and can put it back as it comes (RM:ResetToPreset): the copy keeps the preset's key in
-- radial.preset. The emote presets are rings of categories, grouped by feeling; each category opens
-- a ring of its emotes (ACTIONS.category in Radial/Radial.lua). Camping: a slice for each camp kit
-- you carry (ACTIONS.campkits), and Sit (by the fire a minute: the camp's full buff). Consumables:
-- the best health and mana potions or stones, food and drink in your bags (ACTIONS.consumable).
-- A preset with a class (class = "SHAMAN") is shown to that class only, and its copy is for every
-- character of it. Totem Bars: a category for each of the shaman's Calls, standing for its spell
-- (gone until it is learned), its ring the Call and the four totems on its page of the totem bar,
-- read live (ACTIONS.totem).
--------------------------------------------------

local function Emotes(...)
    local t = {}
    for i, token in ipairs({ ... }) do t[i] = { kind = "emote", emote = token } end
    return t
end

local function Category(name, glyph, buttons)
    return { kind = "category", name = name, glyph = glyph, buttons = buttons }
end

-- a page of the totem bar: its Call (all four at once), then its earth, fire, water and air totems
local function TotemBar(page, call)
    local t = { { kind = "spell", id = call } }
    for slot = 1, 4 do t[#t + 1] = { kind = "totem", page = page, slot = slot } end
    return { kind = "category", spell = call, buttons = t }
end
-- Call of the Elements' own icon (the preset's), a stone totem's where the client can't say
local CALLS_ICON = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(66842))
    or "Interface\\Icons\\Spell_Nature_StoneSkinTotem"

local function Markers()
    local t = {}
    for i = 1, 8 do t[i] = { kind = "targetmarker", marker = i } end
    t[9] = { kind = "targetmarker", marker = -1 }
    return t
end

ns.PRESETS = {
    markers = { name = L["Markers"], icon = { texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
        buttons = Markers() },
    -- the chat menu's emotes (22)
    emotes = { name = L["Emotes"], icon = { texture = "Interface\\Icons\\Spell_Misc_EmotionHappy" }, buttons = {
        Category(L["Greetings"], "greetings", Emotes("WAVE", "BOW", "SALUTE", "KNEEL")),
        Category(L["Joy"], "joy", Emotes("APPLAUD", "DANCE", "LAUGH", "KISS")),
        Category(L["Sorrow"], "sorrow", Emotes("CRY", "BEG", "SHY")),
        Category(L["Taunts"], "taunts", Emotes("FLEX", "ROAR", "RUDE", "CHICKEN")),
        Category(L["At Ease"], "atease", Emotes("SIT", "STAND", "SLEEP", "LEAN", "EAT", "TALK", "POINT")),
    } },
    -- the chat menu's voice emotes (23); FACTION is For the Alliance or For the Horde, as you are
    voice = { name = L["Voice Emotes"], icon = { texture = "Interface\\Icons\\INV_Misc_GroupNeedMore" }, buttons = {
        Category(L["Greetings"], "greetings", Emotes("HELLO", "BYE", "WELCOME", "THANK", "CONGRATULATE")),
        Category(L["Playful"], "playful", Emotes("CHEER", "FLIRT", "SILLY", "TRAIN", "RASP")),
        Category(L["Battle"], "battle", Emotes("ATTACKMYTARGET", "CHARGE", "OPENFIRE", "INCOMING", "FACTION")),
        Category(L["Distress"], "distress", Emotes("HELPME", "HEALME", "OOM", "FLEE")),
        Category(L["Signals"], "signals", Emotes("FOLLOW", "WAIT", "NOD", "NO")),
    } },
    camping = { name = L["Camping"], icon = { texture = "Interface\\Icons\\Spell_Fire_Fire" }, buttons = {
        { kind = "campkits" },
        { kind = "emote", emote = "SIT" },
    } },
    -- the best potion or stone for health and for mana, the best food and drink, from your bags
    -- (ACTIONS.consumable); each one's ring the rest of its kind you carry
    consumables = { name = L["Consumables"], icon = { texture = "Interface\\Icons\\INV_Potion_54" }, buttons = {
        { kind = "consumable", want = "health" }, { kind = "consumable", want = "mana" },
        { kind = "consumable", want = "food" }, { kind = "consumable", want = "drink" },
    } },
    -- the shaman's: Call of the Elements, of the Ancestors, of the Spirits
    totems = { name = L["Totem Bars"], class = "SHAMAN", icon = { texture = CALLS_ICON }, buttons = {
        TotemBar(1, 66842), TotemBar(2, 66843), TotemBar(3, 66844),
    } },
}
-- the sidebar's order
ns.PRESET_ORDER = { "markers", "emotes", "voice", "camping", "consumables", "totems" }
-- (2026-11-22) the built-in category each is listed under in the sidebar (RM.CATEGORIES); only
-- the list's sub-headings: a copy is put in no category
for key, category in pairs({ markers = "group", emotes = "social", voice = "social", camping = "items",
    consumables = "items", totems = "combat" }) do
    ns.PRESETS[key].category = category
end
