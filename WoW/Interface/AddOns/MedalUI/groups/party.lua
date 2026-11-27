-- The the party frames: the party's buttons, party1..4 (made by the console,
-- console/units.lua), taken into a box under a "Party" tab at login. In a
-- raid the box gives way to the raid frames. It has no pets.
--
-- The buttons hang in four fixed rows (the holder is sized for them all, out
-- of combat); the skin ends under the last member shown, so a box of three
-- has no empty fourth row. It follows the buttons' showing and hiding, in
-- combat too.
local _, ns = ...
local Tr = ns.L

local W = ns.GROUP
-- a cell is 160x40 until the editor sizes it (ns.CellSize, editor.lua)

local box = ns.GroupBox("MedalUIParty", "partyPoint", { "LEFT", "LEFT", 40, 120 },
    "partyMoverHover", true)
ns.partyBox = box

local function Step()
    local _, unitH = ns.CellSize("party")
    return unitH + W.gap
end

local function Conditional()
    if ns.db.simParty then return "[group:raid] hide; show" end
    -- shown while party1 is there, the test the members' own unit watch
    -- makes: [group:party] held on in combat after the player left a party
    -- of four, the box empty but for the player's cell (2026-11-11)
    return "[group:raid] hide; [@party1,exists] show; hide"
end

local function Show()
    ns.OutOfCombat(function() ns.GroupVisibility(box, Conditional()) end)
end

-- The skin to the last member shown.
local function Skin()
    if not ns.units.party1.inBox then return end
    local CELL_W, UNIT_H = ns.CellSize("party")
    local last
    for i = 1, 4 do
        if ns.units["party" .. i]:IsShown() then last = i end
    end
    -- no party: the box hides; the player's cell alone until it does
    if ns.db.partyPlayer then last = (last or 0) + 1 end
    if not last then return end
    ns.GroupSkin(box, { Tr["Party"] }, CELL_W, (last - 1) * Step() + UNIT_H)
end

local function LayCell(b, row, CELL_W, UNIT_H, step)
    local x, y = ns.GroupColumnX(1, CELL_W), ns.GroupRowY(row, step)
    b:SetParent(box)
    b:SetFrameLevel(box:GetFrameLevel() + 2)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    b:SetSize(CELL_W, UNIT_H)
    b.power:ClearAllPoints()
    b.health:ClearAllPoints()
    ns.LayPower(b, 5, 1, UNIT_H)
    b.power:SetPoint("BOTTOMLEFT")
    b.power:SetPoint("BOTTOMRIGHT")
    b.health:SetPoint("TOPLEFT")
    b.health:SetPoint("TOPRIGHT")
    b.health:SetReverseFill(false)
    b.power:SetReverseFill(false)
    -- the crown on the top edge's left end
    b.leaderFrame:ClearAllPoints()
    b.leaderFrame:SetPoint("CENTER", b, "TOPLEFT", 10, 0)

    -- a cell is a left copy, whichever way its console slot faced
    ns.LayBuffs(b, -1)
    b.inBox = true
    -- the editor's own writes undone first (editor.lua), so the look's
    -- sizes below are what its next snapshot takes for the cell's
    ns.editor.Relaid(b, "name", "level", "role", "leader", "value", "buffs", "mine")
    -- the group cells' look (box.lua): the role icon on the band, the name
    -- after it, the value at its end, the level top left
    ns.GroupCellLook(b)
    ns.GroupCellText(b, false, 20)
    -- (on the cell, not its health: the editor keeps a moved icon's place
    -- by what it is on, and saved places say the cell)
    local foot = b.health:GetHeight() > 0 and (UNIT_H - b.health:GetHeight()) or 0
    b.roleFrame:ClearAllPoints()
    b.roleFrame:SetPoint("CENTER", b, "BOTTOMLEFT", 10, foot + (ns.GROUP_LOOK.name + 5) / 2)
    -- what the editor changed goes back on
    ns.ApplyEdits(b)
end

-- Called by ns.RelayoutUnits (units.lua).
function ns.LayoutPartyGroup()
    local step = Step()
    local withPlayer = ns.db.partyPlayer and true or false
    local rows = withPlayer and 5 or 4
    local height = rows * step - W.gap
    local CELL_W, UNIT_H = ns.CellSize("party")
    ns.OutOfCombat(function()
        ns.GroupHolder(box, ns.GroupSize(1, CELL_W, height))
        local pb = ns.partyPlayer
        if pb then
            if withPlayer then
                LayCell(pb, 1, CELL_W, UNIT_H, step)
                pb:Show()
                ns.UpdateUnitButton(pb)
                if ns.UpdateUnitAuras then ns.UpdateUnitAuras(pb) end
            else
                pb:Hide()
                pb.inBox = nil
            end
        end
        local offset = withPlayer and 1 or 0
        for i = 1, 4 do
            LayCell(ns.units["party" .. i], i + offset, CELL_W, UNIT_H, step)
        end
        Skin()
    end)
    Show()
end

local function Relayout()
    ns.OutOfCombat(function()
        ns.RelayoutUnits()
        if ns.UpdateConsoleArt then ns.UpdateConsoleArt() end
        if ns.UpdateMinimapLocation then ns.UpdateMinimapLocation() end
    end)
end

ns.OnSetting("partyPlayer", Relayout)
-- the editor's cell size: the box laid again only when that changed (its
-- pieces follow the editor at once, in combat too)
local laidSize
ns.OnSetting("editParty", function()
    local w, h = ns.CellSize("party")
    local size = w .. "x" .. h
    if size == laidSize then return end
    laidSize = size
    Relayout()
end)
ns.OnGroupUpdate(Show)
-- the skin follows the members as they show and hide
for i = 1, 4 do
    local b = ns.units["party" .. i]
    b:HookScript("OnShow", Skin)
    b:HookScript("OnHide", Skin)
end
-- the console makes the party's buttons at load; the box takes them at login
ns.On("PLAYER_LOGIN", function()
    if not ns.units.party1.inBox then Relayout() end
end)
