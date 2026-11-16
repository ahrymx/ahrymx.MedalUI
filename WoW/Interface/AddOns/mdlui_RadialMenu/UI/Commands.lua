local _, ns = ...

--------------------------------------------------
-- COMMANDS
-- /mdlradial                     the editor window (UI/Window.lua)
-- /mdlradial options             the window's Options tab
-- /mdlradial list                the radials, their keys and macros, in chat
-- /mdlradial key <radial> <key>  bind a radial (a name or number from the list); "none" clears it
-- /mdlradial padlog              the controller aim log on or off
-- A key binding (Bindings.xml) opens and closes the window.
--------------------------------------------------
local RM = ns.RadialMenu

local function KeyLabel(key)
    if not key then return "|cff888888no key|r" end
    return ns.KeyText(key)
end

-- a radial by its number in the list, or its name (any case)
local function FindRadial(word)
    local order = RM:GetRadialOrder()
    local index = tonumber(word)
    if index then return order[index] end
    local wanted = word:lower()
    for _, id in ipairs(order) do
        local data = RM:GetRadial(id)
        if data and data.name and data.name:lower() == wanted then return id end
    end
end

local function List()
    local order = RM:GetRadialOrder()
    if #order == 0 then
        ns.Print("no radials.")
        return
    end
    ns.Print("radials:")
    for index, id in ipairs(order) do
        local data = RM:GetRadial(id)
        local key, own = RM:GetRadialKey(id)
        print(("  %d. %s  -  %s%s  -  %s"):format(index, data.name or "?", KeyLabel(key),
            own and " (this character)" or "", RM:GetMacroText(id)))
    end
    print("  /mdlradial key <number or name> <key>, e.g. /mdlradial key 1 SHIFT-Q")
end

local function Bind(rest)
    -- the key is the last word; the radial's name may have spaces
    local which, key = rest:match("^(.-)%s+(%S+)$")
    if not which or which == "" then
        ns.Print("usage: /mdlradial key <number or name> <key>")
        return
    end
    local id = FindRadial(which)
    if not id then
        ns.Print(("no radial called \"%s\"."):format(which))
        return
    end
    if InCombatLockdown() then
        ns.Print("try again out of combat.")
        return
    end
    key = key:upper()
    if key == "NONE" then key = nil end
    RM:SetRadialKey(id, key)
    ns.Print(("%s: %s"):format(RM:GetRadial(id).name or "?", KeyLabel(key)))
end

SLASH_MDLUI_RADIAL1 = "/mdlradial"
SlashCmdList.MDLUI_RADIAL = function(message)
    message = strtrim(message or "")
    local command, rest = message:match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()
    if command == "key" then
        Bind(rest or "")
    elseif command == "padlog" then
        RM.PadLogCommand()
    elseif command == "list" then
        List()
    elseif command == "options" then
        ns.OpenEditor("options")
    else
        ns.OpenEditor("radials")
    end
end

-- the key binding (Bindings.xml)
BINDING_HEADER_MDLUI_RADIAL = "mdlui_RadialMenu"
BINDING_NAME_MDLUI_RADIAL_EDITOR = "Open or close the radial editor"
function mdluiRadialToggleEditor() ns.ToggleEditor() end
