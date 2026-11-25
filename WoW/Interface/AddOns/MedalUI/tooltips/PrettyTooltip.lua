-- Startup. Loads last of the tooltips; setup moves here as its modules are refactored.
-- (2026-11-25) Built into MedalUI, no longer the mdlui_Tooltips companion: it
-- starts once MedalUI's saved settings are in (settings.lua's ADDON_LOADED,
-- registered before this one), unless the switch (Tooltips > Reskin tooltips)
-- is off, or the old companion is still enabled, which would hook every
-- tooltip twice: that one is disabled and this waits for the reload.
local _, medal = ...
local ns = medal.tips
local Tr = medal.L

local OLD = "mdlui_Tooltips"

-- the old companion, enabled for this character (its folder left behind by an update)
local function oldCompanion()
    local get = C_AddOns and C_AddOns.GetAddOnEnableState or GetAddOnEnableState
    if not get then return false end
    local me = UnitName and UnitName("player")
    local ok, state = pcall(get, OLD, me)
    if not (ok and type(state) == "number") then ok, state = pcall(get, me, OLD) end    -- the older order
    return ok and type(state) == "number" and state > 0
end

local started = false
function ns.start()
    if started then return end
    started = true
    ns.migrateOptions()
    ns.ItemLite.register()
    if ns.Hooks then ns.Hooks.install() end
    if ns.Details then ns.Details.register() end
    if ns.Cursor then ns.Cursor.register() end
    ns.Options.register()
    ns.Commands.register()
end

-- what start-up did: "started", "off" (the switch) or "old" (the companion stood aside for)
function ns.boot()
    if oldCompanion() then
        local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
        if disable then pcall(disable, OLD) end
        print("|cffe0b84aMedalUI|r: " .. Tr["Tooltips are now part of MedalUI, so mdlui_Tooltips has been "
            .. "turned off. Type /reload to finish."])
        ns.booted = "old"
    elseif medal.db.tooltips == false then
        ns.booted = "off"
    else
        ns.start()
        ns.booted = "started"
    end
    return ns.booted
end

medal.On("ADDON_LOADED", function(_, name)
    if name == "MedalUI" and not ns.booted then ns.boot() end
end)
