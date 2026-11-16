local _, ns = ...

--------------------------------------------------
-- SHIM
-- The small part of FlareUI's core (Core.lua, by Malkkav, MIT) the radial menu reads, so the fork
-- stands alone: no Ace libraries, no FlareUI. LibSharedMedia is used only when another addon has it.
--------------------------------------------------

-- English only for now: a key is its own text
ns.L = setmetatable({}, { __index = function(_, key) return key end })

-- Medalluin's palette (copied: this addon stands alone)
ns.colors = {
    ink = { 0.071, 0.067, 0.063 },
    text = { 0.949, 0.918, 0.824 },
    dim = { 0.70, 0.66, 0.55 },
    gold = { 0.541, 0.439, 0.204 },
}
ns.BORDER_COLOR = { r = 0.541, g = 0.439, b = 0.204 }

--------------------------------------------------
-- EVENTS
-- What the fork used of AceEvent-3.0: RegisterEvent(event[, handler]) and UnregisterEvent(event).
-- A function handler is called with the event first; with none, the object's method of the event's
-- name is called as a method.
--------------------------------------------------
function ns.EmbedEvents(target)
    local frame = CreateFrame("Frame")
    local handlers = {}
    frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if type(handler) == "function" then
            handler(event, ...)
        elseif type(handler) == "string" then
            target[handler](target, event, ...)
        elseif target[event] then
            target[event](target, event, ...)
        end
    end)
    function target:RegisterEvent(event, handler)
        frame:RegisterEvent(event)   -- an event the client lacks throws, as AceEvent's did
        handlers[event] = handler or true
    end
    function target:UnregisterEvent(event)
        handlers[event] = nil
        frame:UnregisterEvent(event)
    end
    target.eventFrame = frame
    return target
end

--------------------------------------------------
-- VALUES, SPELLS, THE PLAYER
--------------------------------------------------
-- A client without secret values can read everything
function ns.CanAccess(value)
    if canaccessvalue then return canaccessvalue(value) end
    return true
end

-- A spell the player knows. IsPlayerSpell is deprecated on Forever: C_SpellBook first.
function ns.IsPlayerSpell(id)
    if not id then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        return C_SpellBook.IsSpellKnown(id, bank) and true or false
    end
    return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- InputUtil.IsGamepadUIEnabled; switching reloads the UI, so the answer holds for the session
function ns.IsGamepadUI()
    return C_InputInterfaceStyle ~= nil and Enum ~= nil and Enum.InputDeviceInterfaceType ~= nil
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

function ns.PlayerGUID()
    local guid = UnitGUID("player")
    if guid == nil or not ns.CanAccess(guid) then return nil end
    return guid
end

-- This character's table; a throwaway one while the GUID is unknown
function ns.CharDB()
    local guid = ns.PlayerGUID()
    local global = ns.db and ns.db.global
    if not (guid and global) then return {} end
    global.characters = global.characters or {}
    local entry = global.characters[guid]
    if not entry then
        entry = {}
        global.characters[guid] = entry
    end
    return entry
end

--------------------------------------------------
-- FONTS
-- ns.GLOBAL_FONT is Medalluin's Marcellus SC when Medalluin is installed, else the client's own font
-- (which has the client language's letters). Other names go through LibSharedMedia when present.
--------------------------------------------------
ns.GLOBAL_FONT = "__global"
local MARCELLUS = "Interface\\AddOns\\Medalluin\\media\\fonts\\MarcellusSC-Regular.ttf"
local KNOWN_FONTS = {
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\SKURRI.TTF",
}

-- the faces the Options tab offers: ours first, the game's, then LibSharedMedia's when it is there
function ns.FontNames()
    local names, seen = { ns.GLOBAL_FONT }, { [ns.GLOBAL_FONT] = true }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local more = {}
    for name in pairs(KNOWN_FONTS) do more[#more + 1] = name end
    if LSM then for _, name in ipairs(LSM:List("font") or {}) do more[#more + 1] = name end end
    table.sort(more)
    for _, name in ipairs(more) do
        if not seen[name] then seen[name] = true; names[#names + 1] = name end
    end
    return names
end

local function BaseFont()
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function HasMedalluin()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Medalluin") and true or false
end

-- Marcellus has Latin letters only: other client languages keep the game's font
local function LatinClient()
    local locale = GetLocale and GetLocale() or "enUS"
    return not (locale == "ruRU" or locale == "koKR" or locale == "zhCN" or locale == "zhTW")
end

function ns.GetFontPath(face)
    if face == nil or face == ns.GLOBAL_FONT then
        if HasMedalluin() and LatinClient() then return MARCELLUS end
        return BaseFont()
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local ok, found = pcall(LSM.Fetch, LSM, "font", face, true)
        if ok and found then return found end
    end
    return KNOWN_FONTS[face] or BaseFont()
end

-- A font file loads only once a drawn string asks for it: until then SetFont answers false. The
-- string gets the base font at the right size and asks again until the client says yes.
local RETRY_SECONDS, RETRY_TICKS = 0.5, 60
local pendingFonts = setmetatable({}, { __mode = "k" })
local retryTicker, retryTicks

local function RetryFonts()
    retryTicks = retryTicks + 1
    for fontString, want in pairs(pendingFonts) do
        if fontString:SetFont(want.path, want.size, want.flags) ~= false then pendingFonts[fontString] = nil end
    end
    if retryTicks >= RETRY_TICKS or not next(pendingFonts) then
        wipe(pendingFonts)
        retryTicker:Cancel()
        retryTicker = nil
    end
end

function ns.SetFont(fontString, path, size, flags)
    pendingFonts[fontString] = nil
    if fontString:SetFont(path, size, flags) ~= false then return end
    fontString:SetFont(BaseFont(), size, flags)
    fontString:SetFont(path, size, flags)
    pendingFonts[fontString] = { path = path, size = size, flags = flags }
    retryTicks = 0
    retryTicker = retryTicker or C_Timer.NewTicker(RETRY_SECONDS, RetryFonts)
end
-- FlareUI draws other alphabets through font families; the button names here are the player's own
-- spells, in the client's language, which the global font already chooses for
ns.SetFontFamily = ns.SetFont

function ns.ApplyShadow(fontString, fontConfig)
    if not fontString or not fontConfig then return end
    if fontConfig.enableShadow then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(fontConfig.shadowX or 1, fontConfig.shadowY or -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

--------------------------------------------------
-- SOUNDS
--------------------------------------------------
function ns.ButtonSound()
    if SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
end
function ns.WindowOpenSound()
    if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
end
function ns.WindowCloseSound()
    if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end
end

function ns.Print(text)
    print("|cffff9900mdlui_RadialMenu:|r " .. text)
end
