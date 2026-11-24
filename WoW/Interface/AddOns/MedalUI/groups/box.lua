-- The group frames (party, raid, boss, arena): a box of unit frames in
-- columns, each column under a tab with its title ("Party", "Group 3",
-- "Bosses", "Arena"). A tab is the grip: hold it to drag the box anywhere;
-- where it is left is kept for every profile. The look is art/groups/gen_groups.py
-- (draft B: a tab on the box's top edge); the tab is its export.
--
-- Two frames, because combat locks one of them. The holder is what the
-- secure unit buttons hang from, so it is protected: it moves, and takes a
-- size, only out of combat, and is sized for every unit it can hold. The
-- skin (the ink, the gold edge, the tabs) hangs from the holder and holds
-- nothing secure, so it follows what is shown, in combat too: a boss that
-- comes mid-fight lengthens it.
local _, ns = ...
local Tr = ns.L

local C = ns.colors
local GOLD, GOLD_D = { 0.769, 0.647, 0.341 }, { 0.541, 0.439, 0.204 }
-- the tab's art: 64x32, the shape 20 high, its ends 8 wide, its bottom 2
-- rows over the box's edge (gen_groups.py: TAB_*)
local TAB_W, TAB_TEX_H, TAB_H, TAB_END, TAB_OVER = 64, 32, 20, 8, 2

ns.GROUP = { edge = 2, pad = 3, gap = 3 }
local W = ns.GROUP

local boxes = {}

-- A rule of the box's edge: gold outside, a dark line inside it.
local function Edge(parent, layer, inset, thick, color)
    local t = {}
    for i = 1, 4 do
        t[i] = parent:CreateTexture(nil, layer)
        t[i]:SetColorTexture(color[1], color[2], color[3], 1)
    end
    t[1]:SetPoint("TOPLEFT", inset, -inset)
    t[1]:SetPoint("TOPRIGHT", -inset, -inset)
    t[1]:SetHeight(thick)
    t[2]:SetPoint("BOTTOMLEFT", inset, inset)
    t[2]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[2]:SetHeight(thick)
    t[3]:SetPoint("TOPLEFT", inset, -inset)
    t[3]:SetPoint("BOTTOMLEFT", inset, inset)
    t[3]:SetWidth(thick)
    t[4]:SetPoint("TOPRIGHT", -inset, -inset)
    t[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[4]:SetWidth(thick)
    return t
end

local function Place(box)
    local at = ns.db[box.key] or box.default
    box:ClearAllPoints()
    box:SetPoint(at[1], UIParent, at[2], at[3], at[4])
end

local function Remember(box)
    local point, _, relative, x, y = box:GetPoint()
    ns.db[box.key] = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
end

-- A tab's art and its label, on parent at level: the group frames' grip, and the
-- corner minimap's (console/minimap.lua). ns.GroupTabWidth(tab) sizes it to
-- its label; it stands on what it grips with its foot over the edge
-- (ns.GROUP_TAB_OVER).
function ns.GroupTab(parent, level)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetFrameLevel(level)
    tab:SetHeight(TAB_H)
    local l, m, r = tab:CreateTexture(nil, "ARTWORK"), tab:CreateTexture(nil, "ARTWORK"),
        tab:CreateTexture(nil, "ARTWORK")
    for _, t in ipairs({ l, m, r }) do t:SetTexture(ns.media .. "groups/tab") end
    local v = TAB_H / TAB_TEX_H
    l:SetTexCoord(0, TAB_END / TAB_W, 0, v)
    m:SetTexCoord(TAB_END / TAB_W, (TAB_W - TAB_END) / TAB_W, 0, v)
    r:SetTexCoord((TAB_W - TAB_END) / TAB_W, 1, 0, v)
    l:SetPoint("TOPLEFT")
    l:SetPoint("BOTTOMLEFT")
    l:SetWidth(TAB_END)
    r:SetPoint("TOPRIGHT")
    r:SetPoint("BOTTOMRIGHT")
    r:SetWidth(TAB_END)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    tab.label = ns.Text(tab, 12)
    tab.label:SetTextColor(0.878, 0.722, 0.290)
    tab.label:SetPoint("CENTER", 0, (TAB_OVER - 1) / 2)
    tab.label:SetWordWrap(false)
    return tab
end
ns.GROUP_TAB_OVER = TAB_OVER

-- As wide as its label, or most wide (the label ends in an ellipsis).
function ns.GroupTabWidth(tab, most)
    tab.label:SetWidth(0)
    local w = math.ceil(tab.label:GetStringWidth())
    if most and w + 2 * TAB_END + 10 > most then
        w = most - 2 * TAB_END - 10
        tab.label:SetWidth(w)
    end
    tab:SetWidth(math.max(48, w + 2 * TAB_END + 10))
end

local function Tab(box)
    -- behind the skin: the box's gold edge runs on across the tab's foot, so
    -- the tab grows out of the box, and the cells over both
    local tab = ns.GroupTab(box.skin, box:GetFrameLevel())

    -- the grip: the holder moves only out of combat (it is protected)
    tab:RegisterForDrag("LeftButton")
    tab:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        box.moving = true
        box:StartMoving()
    end)
    tab:SetScript("OnDragStop", function()
        if not box.moving then return end
        box.moving = nil
        box:StopMovingOrSizing()
        -- kept by MedalUI for every profile, not in the game's layout cache
        if box.SetUserPlaced then box:SetUserPlaced(false) end
        Remember(box)
        -- a row outside its cells runs toward the nearer screen edge
        -- (editor.lua), which may be the other one now
        if ns.editor then ns.editor.ApplyAll() end
    end)
    tab:SetScript("OnEnter", function(self)
        ns.Tip(self, "ANCHOR_TOP", { title = self.label:GetText(), color = ns.colors.white,
            { "hint", Tr["Drag to move. Not in combat."] } })
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return tab
end

-- A box: name, the option keeping where it was dragged, and where it is
-- until then ({ point, relativePoint, x, y } on UIParent); hover, the option
-- (or a function giving it) that shows its tabs only on mouseover.
function ns.GroupBox(name, key, default, hover, minimal)
    local box = CreateFrame("Frame", name, UIParent)
    box.minimal = minimal       -- faded by the group frames' Minimal OoC Mode
    box:SetFrameStrata("LOW")
    box:SetMovable(true)
    box:SetClampedToScreen(true)
    box.key, box.default, box.hover = key, default, hover

    -- the skin a level over the box, its tabs at the box's, the cells two
    -- over: tabs, skin, cells, back to front
    local skin = CreateFrame("Frame", nil, box)
    skin:SetPoint("TOPLEFT")
    skin:SetFrameLevel(box:GetFrameLevel() + 1)
    local ink = skin:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 0.92)
    Edge(skin, "BORDER", 0, W.edge, GOLD)
    Edge(skin, "BORDER", W.edge, 1, GOLD_D)
    box.skin, box.tabs = skin, {}
    box:Hide()
    table.insert(boxes, box)
    return box
end

-- The left of column i, from the box's left.
function ns.GroupColumnX(i, width)
    return W.edge + W.pad + (i - 1) * (width + W.gap)
end

-- The top of row i of a column whose rows are step apart, from the box's top.
function ns.GroupRowY(i, step)
    return -(W.edge + W.pad + (i - 1) * step)
end

-- The box's size for n columns of width and a column height.
function ns.GroupSize(n, width, height)
    return 2 * W.edge + 2 * W.pad + n * width + (n - 1) * W.gap, 2 * W.edge + 2 * W.pad + height
end

-- The holder: where the box is, and room for everything it can hold. Out of
-- combat only.
function ns.GroupHolder(box, w, h)
    Place(box)
    box:SetSize(w, h)
end

-- The skin: the box drawn at this size with a tab over each column, or
-- none over a column whose title is false. In combat too.
function ns.GroupSkin(box, titles, width, height)
    local w, h = ns.GroupSize(#titles, width, height)
    box.skin:SetSize(w, h)
    for i, title in ipairs(titles) do
        local tab = box.tabs[i] or Tab(box)
        box.tabs[i] = tab
        tab:SetShown(title and true or false)
        if title then
            tab.label:SetText(title)
            ns.GroupTabWidth(tab)
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOM", box.skin, "TOPLEFT", ns.GroupColumnX(i, width) + width / 2, -TAB_OVER)
        end
    end
    for i = #titles + 1, #box.tabs do box.tabs[i]:Hide() end
end

-- Movers only on mouseover (each Unit Frames tab's option): a box's tabs
-- show while the mouse is over the box or one of them, or while it is being
-- dragged. A hidden tab is only clear (alpha 0), so it is still there to find.
local function Hovered(box)
    if box.moving or box.skin:IsMouseOver() then return true end
    for _, tab in ipairs(box.tabs) do
        if tab:IsShown() and tab:IsMouseOver() then return true end
    end
    return false
end

-- Another grip that shows as these do: { hover = its option, tabs = { tab },
-- Hovered = function() -> whether the pointer is on what it moves }.
function ns.WatchMover(grip)
    table.insert(boxes, grip)
    ns.OnSetting(grip.hover, function() ns.UpdateGroupMovers() end)
end

function ns.UpdateGroupMovers()
    for _, box in ipairs(boxes) do
        local key = box.hover
        if type(key) == "function" then key = key() end
        local shown = not (key and ns.db[key]) or (box.Hovered or Hovered)(box)
        for _, tab in ipairs(box.tabs) do tab:SetAlpha(shown and 1 or 0) end
    end
end

local movers = CreateFrame("Frame")
local moversSince = 0
movers:SetScript("OnUpdate", function(_, elapsed)
    moversSince = moversSince + elapsed
    if moversSince < 0.1 then return end
    moversSince = 0
    ns.UpdateGroupMovers()
end)
for _, key in ipairs({ "partyMoverHover", "raidMoverHover", "bgMoverHover", "bossMoverHover",
    "arenaMoverHover" }) do
    ns.OnSetting(key, function() ns.UpdateGroupMovers() end)
end

-- ------------------------------------------------------------ the cells
-- A unit cell, the suite's one rectangle: health, a seam, power under it;
-- the name top left, the level bottom left, the health's value bottom
-- right, a leader's crown on the top edge's left end. units.lua draws it
-- (ns.UpdateUnitButton) as it draws the console's frames, and auras.lua its
-- auras (ns.AttachAuras gives it them).
function ns.GroupCell(b, width, height)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.086, 0.086, 0.102, 1)
    b.health = CreateFrame("StatusBar", nil, b)
    b.health:SetStatusBarTexture(ns.bar)
    b.health:SetPoint("TOPLEFT")
    b.health:SetPoint("TOPRIGHT")
    b.power = CreateFrame("StatusBar", nil, b)
    b.power:SetStatusBarTexture(ns.bar)
    b.power:SetPoint("BOTTOMLEFT")
    b.power:SetPoint("BOTTOMRIGHT")
    ns.SizeGroupCell(b, width, height)
    local text = CreateFrame("Frame", nil, b)
    text:SetAllPoints(b.health)
    text:SetFrameLevel(b.health:GetFrameLevel() + 2)
    b.text = text
    b.name = ns.Text(text, 11)
    b.name:SetPoint("TOPLEFT", 4, -3)
    b.name:SetPoint("TOPRIGHT", -4, -3)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.value = ns.Text(text, 9)
    b.value:SetTextColor(unpack(C.dim))
    b.value:SetPoint("BOTTOMRIGHT", -4, 3)
    b.levelText = ns.Text(text, 9)
    b.levelText:SetPoint("BOTTOMLEFT", 4, 3)
    b.levelText:SetWordWrap(false)
    ns.LeaderIcon(b, 12, b.health:GetFrameLevel() + 3)
    b.leaderFrame:SetPoint("CENTER", b, "TOPLEFT", 8, 0)
    return b
end

-- A cell at a size (the editor's, editor.lua): the power under the health,
-- a seam between. A secure cell takes a size only out of combat.
function ns.SizeGroupCell(b, width, height)
    b:SetSize(width, height)
    ns.LayPower(b, height >= 40 and 5 or 4, 1, height)
end

-- A cell drawn: the unit, then its auras.
function ns.UpdateGroupCell(b)
    ns.UpdateUnitButton(b)
    ns.UpdateUnitAuras(b)
end

-- Units shown in the group frames, by unit, so one event frame updates them all
-- (a raid button's unit changes with the roster: ns.WatchGroupUnit again).
local watched = {}
function ns.WatchGroupUnit(b, unit)
    if b.unit and watched[b.unit] then watched[b.unit][b] = nil end
    b.unit = unit
    if unit then
        watched[unit] = watched[unit] or {}
        watched[unit][b] = true
        ns.UpdateGroupCell(b)
    end
end

local events = CreateFrame("Frame")
for event in pairs(ns.unitEvents) do pcall(events.RegisterEvent, events, event) end
events:RegisterEvent("UNIT_AURA")
-- a new leader: the crown of every cell watching a unit
for _, e in ipairs({ "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE" }) do
    ns.On(e, function()
        for _, list in pairs(watched) do
            for b in pairs(list) do ns.UpdateLeader(b) end
        end
    end)
end
events:SetScript("OnEvent", function(_, event, unit)
    local list = unit and watched[unit]
    if not list then return end
    local fn = ns.unitEvents[event] or ns.UpdateUnitAuras
    for b in pairs(list) do
        if b:IsVisible() and not b.stub then fn(b) end
    end
end)

-- A secure button for one unit, in a group frame's column, with the auras of
-- its kind (ns.AttachAuras).
function ns.GroupUnit(parent, name, unit, width, height, auras)
    local b = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")
    ns.GroupCell(b, width, height)
    ns.AttachAuras(b, auras)
    ns.EditableCell(b, auras)
    b:SetScript("OnEnter", function(self)
        if self.stub then
            ns.Tip(self, "ANCHOR_RIGHT", { title = self.stub.name, color = ns.colors.white,
                { "body", Tr["Simulated"], ns.colors.grey } })
        elseif UnitFrame_OnEnter then
            UnitFrame_OnEnter(self)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if self.stub then GameTooltip_Hide() elseif UnitFrame_OnLeave then UnitFrame_OnLeave(self) end
    end)
    b:SetScript("OnShow", function(self) ns.UpdateGroupCell(self) end)
    ns.WatchGroupUnit(b, unit)
    return b
end

-- A box's state driver for its visibility: shown by the game's own
-- conditional (in combat too), or always, while previewing.
function ns.GroupVisibility(box, conditional)
    if box.shownBy == conditional then return end
    box.shownBy = conditional
    RegisterStateDriver(box, "visibility", conditional)
end

-- Every group frame's update: the roster, the units there are, the preview.
local updates = {}
function ns.OnGroupUpdate(fn) table.insert(updates, fn) end
function ns.UpdateGroups()
    for _, fn in ipairs(updates) do fn() end
end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
    "UNIT_TARGETABLE_CHANGED", "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS",
    "PLAYER_REGEN_ENABLED" }) do
    ns.On(event, function() ns.UpdateGroups() end)
end
ns.OnSetting("simParty", function() ns.UpdateGroups() end)

-- ------------------------------------------------ Minimal OoC Mode
-- (Shared > Immersion Mode, 2026-11-20): out of combat the party and raid
-- boxes fade to groupMinimalAlpha, whole again in combat, while anyone in
-- the group is hurt (ns.UnitHurt: not the dead or offline), or while the
-- pointer is on the box, as ticked. Moved or previewed, always whole. The
-- box's alpha is all of it: the skin, its tabs and the cells hang from it,
-- and an alpha may change in combat. At nothing with no mouseover, out of
-- the pointer's way (ns.Untouchable), so its secure cells are not clicked
-- unseen; combat always brings it back first.
local minimal = { faders = {}, goals = {}, touches = {} }
ns.groupMinimal = minimal
local GROUP_IN, GROUP_OUT = 0.2, 0.6
local inCombat = false
local function GroupMinimal() return ns.db and ns.db.groupMinimal and true or false end
local function GroupUnits()
    if IsInRaid() then
        local out = {}
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 40) do out[#out + 1] = "raid" .. i end
        return out
    end
    return { "player", "party1", "party2", "party3", "party4" }
end
local function GroupHurt()
    for _, unit in ipairs(GroupUnits()) do
        if ns.UnitHurt and ns.UnitHurt(unit) then return true end
    end
    return false
end
minimal.Hurt = GroupHurt
local function Wanted(box)
    local db = ns.db
    if not GroupMinimal() or inCombat or box.moving or db.simParty then return true end
    if db.groupMinimalMouse and Hovered(box) then return true end
    return db.groupMinimalHurt and GroupHurt() or false
end
local function Touch(box)
    local t = minimal.touches[box]
    if not t then
        t = ns.Untouchable(box, function()
            return GroupMinimal() and not ns.db.groupMinimalMouse and minimal.goals[box] == 0
                and minimal.faders[box].alpha == 0
        end)
        t.name = "group " .. tostring(box:GetName())
        minimal.touches[box] = t
    end
    return t
end
local function GroupFade(box, now)
    local f = minimal.faders[box]
    if not f then
        f = ns.Fader(box)
        minimal.faders[box] = f
    end
    local alpha = math.max(0, math.min(1, tonumber(ns.db.groupMinimalAlpha) or 0))
    local goal = Wanted(box) and 1 or alpha
    if minimal.goals[box] == goal and not now then return end
    minimal.goals[box] = goal
    local touch = Touch(box)
    f:Go(goal, not now and (goal == 1 and GROUP_IN or GROUP_OUT) or 0, function() touch:Update() end)
    touch:Update()
end
function minimal.FadeAll(now)
    if not ns.db then return end
    for _, box in ipairs(boxes) do
        if box.minimal then GroupFade(box, now) end
    end
end
-- the pointer, and secret health's guess (a time, not an event): a look
-- each tenth while the mode is on
local minimalWatch = CreateFrame("Frame")
minimalWatch:Hide()
local minimalSince = 0
minimalWatch:SetScript("OnUpdate", function(_, dt)
    minimalSince = minimalSince + dt
    if minimalSince < 0.1 then return end
    minimalSince = 0
    minimal.FadeAll()
end)
minimal.watch = minimalWatch
local function GroupSettings()
    minimalWatch:SetShown(GroupMinimal())
    minimal.FadeAll(true)
end
ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; minimal.FadeAll() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; minimal.FadeAll() end)
ns.On("GROUP_ROSTER_UPDATE", function() minimal.FadeAll() end)
ns.On("PLAYER_LOGIN", function()
    inCombat = UnitAffectingCombat("player") and true or false
    GroupSettings()
end)
for _, key in ipairs({ "groupMinimal", "groupMinimalAlpha", "groupMinimalHurt", "groupMinimalMouse", "simParty" }) do
    ns.OnSetting(key, GroupSettings)
end

-- Raid cells fade out of range as the party's do (units.lua), by the Raid
-- tab's Fade out of range, or the Battleground tab's in a battleground.
-- Enemies do not fade.
function ns.RaidRange()
    return ns.db and (ns.InBattleground() and ns.db.bgRange or ns.db.raidRange)
end
local fade = CreateFrame("Frame")
ns.groupFade = fade
local since = 0
fade:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.2 then return end
    since = 0
    local dist = ns.RaidRange()
    for unit, list in pairs(watched) do
        local friendly = unit:match("^raid")
        for b in pairs(list) do
            if b:IsVisible() then
                -- (the last may be a secret: passed on untested)
                local near = b.stub or not friendly or dist == 0 or ns.UnitInRange(unit, dist)
                ns.RangeFade(b, near)
            end
        end
    end
end)
