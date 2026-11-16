local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PRESETS
-- Ready-made radials, read-only. A player adds a copy (RM:AddPreset), changes it however they like,
-- and can put it back as it comes (RM:ResetToPreset): the copy keeps the preset's key in
-- radial.preset. The emote presets are rings of categories, grouped by feeling; each category opens
-- a ring of its emotes (ACTIONS.category in Radial/Radial.lua).
--------------------------------------------------

local function Emotes(...)
    local t = {}
    for i, token in ipairs({ ... }) do t[i] = { kind = "emote", emote = token } end
    return t
end

local function Category(name, glyph, buttons)
    return { kind = "category", name = name, glyph = glyph, buttons = buttons }
end

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
}
-- the sidebar's order
ns.PRESET_ORDER = { "markers", "emotes", "voice" }
