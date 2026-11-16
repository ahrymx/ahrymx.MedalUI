local _, ns = ...

--------------------------------------------------
-- PAD
-- Controller helpers, from FlareUI's GamepadMode.lua (by Malkkav, MIT): stick-press combos, bar
-- slots, key text, and the controller addons that own the pad's buttons.
--------------------------------------------------

-- Controller addons that bind the pad's buttons themselves: with one loaded, no controller button is
-- bound here (two owners of a stick press leave it stuck or dead)
local CONTROLLER_ADDONS = { "ConsolePort", "ImprovedForever", "ImprovedForever_Wheel", "EasyController",
                            "ControllerForever" }

-- the first one loaded, or nil
function ns.OtherControllerAddon()
    for _, name in ipairs(CONTROLLER_ADDONS) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
end

--------------------------------------------------
-- STICK-PRESS COMBOS AND KEY TEXT
-- In the Gamepad UI, LT and RT are not keys: they hold the bar's crossbar modifiers, and LB / RB are
-- its targeting. So a radial's controller key is saved as a combo, "PADCOMBO-<side>-<stick>": the
-- stick pressed (L3 or R3) and the triggers held (TOP for none, LT, RT or LTRT).
--------------------------------------------------
local COMBO_STICKS = { L3 = "PADLSTICK", R3 = "PADRSTICK" }
local COMBO_SIDES = { TOP = true, LT = true, RT = true, LTRT = true }

-- stick ("L3" / "R3") and side, or nil for any other key
function ns.ParsePadCombo(key)
    if type(key) ~= "string" then return nil end
    local side, stick = key:match("^PADCOMBO%-(%u+)%-(%w+)$")
    if not side then
        stick = key:match("^PADCOMBO%-(%w+)$")
        side = "TOP"
    end
    if stick and COMBO_STICKS[stick] and COMBO_SIDES[side] then return stick, side end
end

function ns.PadComboKey(stick, side)
    return side == "TOP" and ("PADCOMBO-" .. stick) or ("PADCOMBO-" .. side .. "-" .. stick)
end

function ns.PadStickKey(stick) return COMBO_STICKS[stick] end

-- The button each crossbar modifier is on (the Gamepad UI keeps its bindings in mode 1), or the
-- default trigger
function ns.PadTriggerKey(side)
    local action = side == "LT" and "GAMEPADLEFTMOD" or "GAMEPADRIGHTMOD"
    local ok, key = pcall(GetBindingKey, action, 1)
    return (ok and key) or (side == "LT" and "PADLTRIGGER" or "PADRTRIGGER")
end

local function TriggersText(side)
    local parts = {}
    if side == "LT" or side == "LTRT" then parts[#parts + 1] = GetBindingText(ns.PadTriggerKey("LT")) end
    if side == "RT" or side == "LTRT" then parts[#parts + 1] = GetBindingText(ns.PadTriggerKey("RT")) end
    return parts
end

-- "LT + R3", with the client's controller icons where it has them; nil for any other key
function ns.PadComboText(key)
    local stick, side = ns.ParsePadCombo(key)
    if not stick then return nil end
    local parts = TriggersText(side)
    parts[#parts + 1] = GetBindingText(COMBO_STICKS[stick])
    return table.concat(parts, " + ")
end

-- A slot of the controller bar: "PADBAR-<side>-<button>"
function ns.PadBarKey(side, button)
    return "PADBAR-" .. side .. "-" .. button
end

function ns.ParsePadBar(key)
    if type(key) ~= "string" then return nil end
    local side, button = key:match("^PADBAR%-(%u+)%-(%w+)$")
    if side and COMBO_SIDES[side] then return side, button end
end

-- any key as text: a stick combo or bar slot ("LT + A"), else Blizzard's name for it
function ns.KeyText(key)
    if not key or key == "" then return "" end
    local combo = ns.PadComboText(key)
    if combo then return combo end
    local side, button = ns.ParsePadBar(key)
    if side then
        local parts = TriggersText(side)
        parts[#parts + 1] = GetBindingText(button)
        return table.concat(parts, " + ")
    end
    return (GetBindingText and GetBindingText(key)) or key
end
