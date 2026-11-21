-- MedalUI's own minimap button: the gold medal of assets/medalui-icon.svg
-- (art/strips/gen_sidepanel.py renders it). Left click opens the settings; right click
-- switches Simulate party frames on or off, as its box on the page does;
-- middle click opens the unit frame editor (options/editor.lua), or closes it.
--
-- It is made on the minimap like any addon's button, so the action bar's
-- drawer (bars/drawer.lua) takes it with the others. Without the action bar
-- there is no drawer, and it sits inside the minimap's lower-left, clear of
-- the ring.
local _, ns = ...
local Tr = ns.L

local SIZE = 32

local button = CreateFrame("Button", "MedalUIMinimapButton", Minimap)
button:SetSize(SIZE, SIZE)
button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ns.media .. "strips\\minimap-button")
icon:SetAllPoints()
button.icon = icon
local glow = button:CreateTexture(nil, "HIGHLIGHT")
glow:SetTexture(ns.media .. "strips\\round")
glow:SetVertexColor(1, 0.9, 0.6)
glow:SetAlpha(0.25)
glow:SetBlendMode("ADD")
glow:SetAllPoints()
ns.minimapButton = button

local function Tip(self)
    ns.Tip(self, "ANCHOR_LEFT", { title = "MedalUI",
        { "row", Tr["Left click"], Tr["settings"], true },
        { "row", Tr["Right click"], ns.db.simParty and Tr["simulate party frames (on)"]
            or Tr["simulate party frames (off)"], true },
        { "row", Tr["Middle click"], Tr["unit frame editor"], true } })
end

button:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
        ns.SetOption("simParty", not ns.db.simParty)
        if GameTooltip:IsOwned(self) then Tip(self) end
    elseif mouse == "MiddleButton" then
        local editor = _G.MedalUIEditor
        if editor and editor:IsShown() then
            editor:Hide()
        elseif ns.OpenEditor then
            ns.OpenEditor()
        end
    elseif SlashCmdList.MEDALUI then
        SlashCmdList.MEDALUI("")
    end
end)
button:SetScript("OnEnter", Tip)
button:SetScript("OnLeave", GameTooltip_Hide)

-- Where it rests on the minimap, which has its size by now. This file loads
-- before the bar's, so this runs before the drawer is built and takes it
-- (and the drawer puts back any button moved after it has).
ns.On("PLAYER_LOGIN", function()
    local d = (Minimap:GetWidth() or 0) * 0.3
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", -d, -d)
end)
