-- The inspect window: Medalluin's own (the shell is window/shell.lua), on
-- the right strip, opposite the character window, so the two stand side by
-- side; the bags' medallion in its margin, as the talents'.
--
-- Blizzard's InspectFrame (Blizzard_InspectUI, loaded on demand by the first
-- inspection) keeps every way in: the unit menu's Inspect, InspectUnit,
-- Escape, and its own closing when the unit goes (another target, out of
-- range). It still opens and closes, but on the veil (core.lua, ns.Park):
-- its code reads the items only while it is visible to itself, which a
-- frame under the hidden parent never is. This window shows while it is
-- open, on its own pages: the Character page (inspect/page.lua), whose gear
-- slots are Blizzard's own (InspectHeadSlot and the rest), taken onto it as
-- the character page takes the player's; the Talents (inspect/talents.lua,
-- Forever's trees, where Blizzard sends you to its talents frame instead)
-- its PvP is in the Character page's details. Blizzard's Guild page has none.
--
-- Docked, it and the strip's other windows close each other (exclusive):
-- the spellbook, the talents, the professions and the quest log.
--
-- Built when Blizzard_InspectUI loads, and only when the Inspect window
-- option is on.
local _, ns = ...

local W = ns.Window{
    name = "MedalluinInspect", side = 1, exclusive = true,
    closeTip = "Close the inspect window.",
    Close = function() if InspectFrame then HideUIPanel(InspectFrame) end end,
    Open = function() end,             -- the pages are ours alone: Blizzard's tab is left as it is
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.inspect = { width = W.width, InspectPage = W.Page }

-- the unit inspected: Blizzard's record of it
function ns.inspect.Unit()
    return InspectFrame and InspectFrame.unit or "target"
end

local function Sync()
    W.SetShown(InspectFrame:IsShown())
end

local adopted
local function Adopt()
    if adopted or not ns.db.inspect or not InspectFrame then return end
    adopted = true
    W.Build()
    ns.Park(InspectFrame, ns.veil)
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        hooksecurefunc(InspectFrame, method, Sync)
    end
    W.Select(W.pages[1])
    ns.inspect.window, ns.inspect.W = W.window, W
    Sync()
end

ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_InspectUI" then Adopt() end end)
ns.On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then Adopt() end
end)
