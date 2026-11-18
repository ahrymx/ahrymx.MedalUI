local addonName, ns = ...

--------------------------------------------------
-- DB
-- mdlui_RadialMenuDB, a plain table (no AceDB):
--   options   the radial's look and opening (FlareUI's profile.radialmenu), account-wide
--   global    the radials, groups and controller settings (global.radialmenu), each character's
--             keys and bar slots (global.characters[GUID]), and what a closed radial gives back
-- The radial code reads them as FlareUI laid them out: ns.db.profile.radialmenu and ns.db.global.
--------------------------------------------------
ns.DEFAULTS = {
    showNames = true,           -- the hovered button names its action
    position = "cursor",        -- cursor | center: where a mouse radial opens
    activation = "hold",        -- hold (release to use) | toggle (press to open, click to use)
    subRadials = "reset",       -- reset | remember: a sub-radial's button when the radial opens again
    scale = 1,                  -- the whole radial's size
    autoRanks = true,           -- a spell button follows the best rank learned (unless pinned lower)
    catalogAllRanks = false,    -- the editor's Catalog lists every rank of a spell, not only the best known
    minimapButton = false,      -- a button on the minimap's edge opening the editor
    minimapAngle = 225,         -- where round the minimap it stands
    labelFont = { face = "__global", size = 16, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
    countFont = { face = "Arial Narrow", size = 14, flags = "OUTLINE", enableShadow = false,
                  shadowX = 1, shadowY = -1 },
}

-- missing fields from the defaults; a table default fills a table field key by key
local function Fill(into, from)
    for key, value in pairs(from) do
        if type(value) == "table" then
            if type(into[key]) ~= "table" then into[key] = {} end
            Fill(into[key], value)
        elseif into[key] == nil then
            into[key] = value
        end
    end
end
ns.FillDefaults = Fill

function ns.LoadDB()
    local saved = _G.mdlui_RadialMenuDB
    if type(saved) ~= "table" then saved = {} end
    _G.mdlui_RadialMenuDB = saved
    saved.options = type(saved.options) == "table" and saved.options or {}
    saved.global = type(saved.global) == "table" and saved.global or {}
    Fill(saved.options, ns.DEFAULTS)
    ns.db = { profile = { radialmenu = saved.options }, global = saved.global }
    return ns.db
end

--------------------------------------------------
-- FLAREUI SIDE BY SIDE
-- FlareUI's own radial overrides the same kind of keys: said once a session when it is on.
--------------------------------------------------
function ns.FlareRadialOn()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FlareUI")) then return false end
    local db = _G.FlareUI2_DB
    if type(db) ~= "table" then return false end
    local profileName = "Default"
    local name, realm = UnitName("player"), GetRealmName and GetRealmName()
    local keys = type(db.profileKeys) == "table" and db.profileKeys
    if keys and name and realm and keys[name .. " - " .. realm] then profileName = keys[name .. " - " .. realm] end
    local profile = type(db.profiles) == "table" and db.profiles[profileName]
    local radial = type(profile) == "table" and profile.radialmenu
    return type(radial) == "table" and radial.enabled == true
end

--------------------------------------------------
-- START
--------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        ns.LoadDB()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not ns.db then ns.LoadDB() end
        ns.RadialMenu:Init()
        if ns.Options then ns.Options.register() end
        if ns.FlareRadialOn() then
            ns.Print("FlareUI's radial menu is on too: keys both bind go to whichever binds last. "
                .. "Switch one of them off.")
        end
    end
end)
