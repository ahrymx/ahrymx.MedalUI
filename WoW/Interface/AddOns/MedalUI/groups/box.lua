-- The group frames (party, raid, boss, arena): a box of unit frames in
-- columns, each column under a header with its title ("Party", "Group 3",
-- "Bosses", "Arena"). A header is the grip: hold it to drag the box anywhere;
-- where it is left is kept for every profile. The look is
-- art/groups/gen_frames.py (2026-11-27, B: a header strip): the headers make
-- one strip across the box's top, the title on the left, a grip's three dots
-- on the right, a gold underline fading rightward; the box a dark rim, no
-- shadow. (Before it, gen_groups.py's draft B: a tab of art on the top
-- edge.)
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
local GOLD, GOLD_D, GOLD_B = ns.gold.mid, ns.gold.dark, ns.gold.bright
-- the header strip: its height, the title's inset, the grip's dots
local HEAD_H, HEAD_INSET, DOT, DOT_STEP = 18, 7, 2, 5
-- the rim, a dark line round the box and its strip; a faint lighter line
-- inside it (no shadow outside: taken off 2026-11-27)
local RIM, BEVEL = { 0.03, 0.03, 0.03 }, { 0.16, 0.15, 0.13 }
local STRIP = { 0.11, 0.10, 0.086, 0.96 }

ns.GROUP = { edge = 2, pad = 3, gap = 3 }
local W = ns.GROUP

local boxes = {}

-- A rule round a frame, inset from its edge.
local function Edge(parent, layer, inset, thick, color)
    local t = {}
    for i = 1, 4 do
        t[i] = parent:CreateTexture(nil, layer)
        t[i]:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
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

-- A gradient where the client has one: from a to b along orient ("HORIZONTAL"
-- left to right, "VERTICAL" bottom to top); else a flat mean.
local function Fade(t, orient, a, b)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient(orient, CreateColor(unpack(a)), CreateColor(unpack(b)))
    else
        t:SetColorTexture(a[1], a[2], a[3], (a[4] + b[4]) / 2)
    end
end

-- A column's header: its strip, rim and underline, the title, the dots.
local function Head(box)
    local head = CreateFrame("Button", nil, box)
    head:SetFrameLevel(box.skin:GetFrameLevel())
    head:SetHeight(HEAD_H)
    -- (2026-11-27) two layers: the surface (band, rim, underline, dots),
    -- which Minimal OoC Mode fades by the pointer (groupMinimalTitleAlpha),
    -- and the words over it, always whole there (TitleFade)
    local surface = CreateFrame("Frame", nil, head)
    surface:SetAllPoints()
    surface:SetFrameLevel(head:GetFrameLevel() + 1)
    head.surface = surface
    local words = CreateFrame("Frame", nil, head)
    words:SetAllPoints()
    words:SetFrameLevel(head:GetFrameLevel() + 2)
    head.words = words
    local bg = surface:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(STRIP))
    Edge(surface, "BORDER", 0, 1, RIM)
    local rule = surface:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", 1, 0)
    rule:SetPoint("BOTTOMRIGHT", -1, 0)
    rule:SetHeight(1)
    Fade(rule, "HORIZONTAL", { GOLD[1], GOLD[2], GOLD[3], 1 }, { GOLD[1], GOLD[2], GOLD[3], 0.15 })
    head.rule = rule
    head.label = ns.Text(words, 11)
    head.label:SetTextColor(GOLD_B[1], GOLD_B[2], GOLD_B[3])
    head.label:SetPoint("LEFT", HEAD_INSET, 1)
    head.label:SetPoint("RIGHT", -(HEAD_INSET + 3 * DOT_STEP), 1)
    head.label:SetJustifyH("LEFT")
    head.label:SetWordWrap(false)
    head.dots = {}
    for i = 1, 3 do
        local d = surface:CreateTexture(nil, "ARTWORK")
        d:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        d:SetSize(DOT, DOT)
        d:SetPoint("RIGHT", -(HEAD_INSET + (i - 1) * DOT_STEP), 1)
        head.dots[i] = d
    end

    -- the grip: the holder moves only out of combat (it is protected)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function(self)
        if not self.title or InCombatLockdown() then return end
        box.moving = true
        box:StartMoving()
    end)
    head:SetScript("OnDragStop", function()
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
    head:SetScript("OnEnter", function(self)
        if not self.title then return end
        ns.Tip(self, "ANCHOR_TOP", { title = self.title, color = ns.colors.white,
            { "hint", Tr["Drag to move. Not in combat."] } })
    end)
    head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return head
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
    ink:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 0.94)
    -- the edge's two pixels (W.edge): the dark rim, a faint bevel inside it
    Edge(skin, "BORDER", 0, 1, RIM)
    Edge(skin, "BORDER", 1, 1, BEVEL)
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

-- The skin: the box drawn at this size, a header over each column, the
-- headers one strip across its top. A column whose title is false keeps
-- its piece of the strip, bare and no grip. In combat too.
function ns.GroupSkin(box, titles, width, height)
    local w, h = ns.GroupSize(#titles, width, height)
    box.skin:SetSize(w, h)
    local n = #titles
    for i, title in ipairs(titles) do
        local head = box.tabs[i] or Head(box)
        box.tabs[i] = head
        head:Show()
        head.title = title or nil
        head.label:SetText(title or "")
        for _, d in ipairs(head.dots) do d:SetShown(title and true or false) end
        head:EnableMouse(title and true or false)
        -- from the middle of the gap before its column to the middle of the
        -- one after; the ends to the skin's
        local left = i == 1 and 0 or ns.GroupColumnX(i, width) - math.floor(W.gap / 2)
        local right = i == n and w or ns.GroupColumnX(i, width) + width + math.ceil(W.gap / 2)
        head:ClearAllPoints()
        head:SetPoint("BOTTOMLEFT", box.skin, "TOPLEFT", left, -1)
        head:SetWidth(right - left)
    end
    for i = n + 1, #box.tabs do box.tabs[i]:Hide() end
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
-- The cell's look (2026-11-27, art/groups/gen_cells.py: "class fill,
-- deepened"). The class colour kept, shaded toward its foot under a faint
-- light along its top; the name and the value on a soft dark band at the
-- health's foot, outlined; the level top left. The shades hang from the bars
-- and the band from the cell's texts (b.text), so the dead look, which
-- fades the texts, takes the band with them. Alpha only: nothing secure.
local LOOK = { shade = 0.30, powerShade = 0.35, light = 0.10, band = 0.30, feather = 4,
    name = 13, small = 12, value = 11, level = 10, powerMute = 0.65 }
ns.GROUP_LOOK = LOOK

-- black at alpha at the foot, clear at the top; a flat half where the
-- client has no colour gradients
local function Rise(t, alpha)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("VERTICAL", CreateColor(0, 0, 0, alpha), CreateColor(0, 0, 0, 0))
    else
        t:SetColorTexture(0, 0, 0, alpha / 2)
    end
end

local function Shade(bar, alpha)
    local t = bar:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    Rise(t, alpha)
    return t
end

-- The band behind the name row: flat, its top feathered.
local function Band(b)
    local body = b.text:CreateTexture(nil, "BACKGROUND")
    body:SetColorTexture(0, 0, 0, LOOK.band)
    body:SetPoint("BOTTOMLEFT")
    body:SetPoint("BOTTOMRIGHT")
    local top = b.text:CreateTexture(nil, "BACKGROUND")
    top:SetPoint("BOTTOMLEFT", body, "TOPLEFT")
    top:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT")
    top:SetHeight(LOOK.feather)
    Rise(top, LOOK.band)
    return { body = body, top = top }
end

-- The band as tall as the name's line: the editor's size, or the look's.
function ns.GroupBandHeight(b)
    if not b.band then return end
    local _, size = b.name:GetFont()
    b.band.body:SetHeight(math.max(1, (size or LOOK.name) + 5 - LOOK.feather))
end

-- A text in the look: its size, outlined, the shadow kept.
local function Outlined(fs, size)
    local face = fs:GetFont()
    fs:SetFont(face or ns.font, size, "OUTLINE")
end

-- The look on cell b, once: the shades, the light, the band. small: a
-- raid's cell, its name a size smaller. The texts' sizes and places are
-- ns.GroupCellText's, as each frame lays them.
function ns.GroupCellLook(b, opts)
    if b.cellLook then return b end
    b.cellLook = true
    b.healthShade = Shade(b.health, LOOK.shade)
    b.powerShade = Shade(b.power, LOOK.powerShade)
    local light = b.health:CreateTexture(nil, "OVERLAY")
    light:SetColorTexture(1, 1, 1, LOOK.light)
    light:SetPoint("TOPLEFT", b.health:GetStatusBarTexture(), "TOPLEFT")
    light:SetPoint("TOPRIGHT", b.health:GetStatusBarTexture(), "TOPRIGHT")
    light:SetHeight(1)
    b.healthLight = light
    -- (the console's player and target take none: their text sits on the
    -- middle of a taller health, where the shade is light)
    if not (opts and opts.band == false) then b.band = Band(b) end
    return b
end

-- The texts of a cell in the look: the name and value on the band, the
-- level top left. inset: the name's left (clear of a role icon).
function ns.GroupCellText(b, small, inset)
    local mid = (LOOK[small and "small" or "name"] + 5) / 2
    Outlined(b.name, LOOK[small and "small" or "name"])
    b.name:SetTextColor(unpack(C.text))
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b.health, "BOTTOMLEFT", inset or 4, mid)
    b.name:SetPoint("RIGHT", b.value, "LEFT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    Outlined(b.value, small and LOOK.level or LOOK.value)
    b.value:SetTextColor(unpack(C.text))
    b.value:ClearAllPoints()
    b.value:SetPoint("RIGHT", b.health, "BOTTOMRIGHT", -4, mid)
    b.value:SetJustifyH("RIGHT")
    Outlined(b.levelText, LOOK.level)
    b.levelText:ClearAllPoints()
    b.levelText:SetPoint("TOPLEFT", b.health, "TOPLEFT", 4, -3)
    ns.GroupBandHeight(b)
end

-- (2026-11-27, art/console/gen_units.py B) The console's player and target
-- in the look: the shades and the light, no band; the name, value, power
-- value and level outlined in the text's colour at their own sizes (the
-- profile's layout.unit). Here, not in console/units.lua, which loads
-- before this file; still before the editor's first snapshot (PLAYER_LOGIN),
-- so Reset gives these back.
function ns.ConsoleUnitLook(b)
    if not b or b.cellLook then return end
    ns.GroupCellLook(b, { band = false })
    for _, fs in ipairs({ b.name, b.value, b.powerValue, b.levelText }) do
        local _, size = fs:GetFont()
        Outlined(fs, size or LOOK.value)
        if fs ~= b.levelText then fs:SetTextColor(unpack(C.text)) end
    end
end
for _, unit in ipairs({ "player", "target" }) do ns.ConsoleUnitLook(ns.units and ns.units[unit]) end

-- A unit cell, the suite's one rectangle: health, a seam, power under it;
-- the name and the health's value on the band at the health's foot, the
-- level top left, a leader's crown on the top edge's left end. units.lua
-- draws it (ns.UpdateUnitButton) as it draws the console's frames, and
-- auras.lua its auras (ns.AttachAuras gives it them).
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
    b.name = ns.Text(text, LOOK.name)
    b.value = ns.Text(text, LOOK.value)
    b.levelText = ns.Text(text, LOOK.level)
    b.levelText:SetWordWrap(false)
    ns.GroupCellLook(b)
    -- a raid's cell (36 high by default) a size smaller
    ns.GroupCellText(b, height < 40)
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
-- (2026-11-27) The title strips: in the mode, a box's strip is whole while
-- the pointer is on the box and at groupMinimalTitleAlpha otherwise (combat
-- and the hurt do not bring it; the box's Back on mouseover does not stop
-- it). Its words stay whole all the while, over a box faded to nothing too:
-- they take no alpha from the box (SetIgnoreParentAlpha).
minimal.titles = { faders = {}, goals = {} }
local function TitleFade(box, now)
    local on = GroupMinimal()
    local goal = 1
    if on and not box.moving and not ns.db.simParty and not Hovered(box) then
        goal = math.max(0, math.min(1, tonumber(ns.db.groupMinimalTitleAlpha) or 0))
    end
    local T = minimal.titles
    for _, head in ipairs(box.tabs or {}) do
        local label = head.label
        if label.SetIgnoreParentAlpha then label:SetIgnoreParentAlpha(on) end
        local f = T.faders[head]
        if not f then
            f = ns.Fader(head.surface)
            T.faders[head] = f
        end
        if T.goals[head] ~= goal or now then
            T.goals[head] = goal
            f:Go(goal, not now and (goal == 1 and GROUP_IN or GROUP_OUT) or 0)
        end
    end
end
function minimal.FadeAll(now)
    if not ns.db then return end
    for _, box in ipairs(boxes) do
        if box.minimal then
            GroupFade(box, now)
            TitleFade(box, now)
        end
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
for _, key in ipairs({ "groupMinimal", "groupMinimalAlpha", "groupMinimalTitleAlpha", "groupMinimalHurt",
    "groupMinimalMouse", "simParty" }) do
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
