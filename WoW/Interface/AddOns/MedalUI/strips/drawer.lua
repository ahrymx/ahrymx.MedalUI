-- The corner strips as drawers (2026-11-23, the user's; mockup A of the
-- "MedalUI strip drawers" canvas). Each strip's row rests on information
-- cells (strips/infocells.lua: on the left durability or ammo and the
-- class's reagents, on the right the professions). A chevron on the bare
-- plate beside the medallion (no key: the channel starts after it) unrolls
-- the menu keys over them, from the medallion inward. Pressed again, or a
-- second after the pointer has left the strip, they roll back. The chevron
-- (the user's pick 4b of that canvas) is a double one standing off the
-- plate on its shadow, inside a frame cut into the plate
-- (media/strips/drawer-frame, `art/strips/gen_strips.py bay`).
--
-- The cells are secure buttons (a reagent casts its spell), so the drawer
-- moves only out of combat: in combat it holds as it is, and a change of
-- cells waits for the fight's end. A side with no cells to show (no
-- profession learned), or its option off, is no drawer: its keys stand
-- as before, the whole row theirs.
--
--   D = ns.stripDrawers[side]
--   D.keys, D.info      the layers the menu keys and the cells go on
--   D.Keys(list)        the menu keys shown, in order (their owners lay them out here)
--   D.Info(list)        the cells shown, in order (strips/infocells.lua)
--   D.Set(open, now)    open or close it, rolling (or at once)
--   D.open              whether it is open (or rolling open)
--   D.On()              whether it is a drawer: its option on and cells to show
--   D.Notice()          the chevron turns blue while a key behind it is
--                       (something new behind it, strips/micro.lua)
local _, ns = ...
local Tr = ns.L

local art, cells, KEY = ns.stripArt, ns.stripCells, ns.stripKey
local BAY = 22                  -- the bare plate the chevron sits on, before the channel
local GLYPH = 15
local REST, LIT = 0.9, 1        -- the chevron's gold, shaded: at rest; open or under the mouse
local GLOW = { hover = 0.45, open = 0.25 }
local ROLL = 0.18               -- seconds to unroll or roll back
local LINGER = 1                -- seconds off the strip before it rolls back
local NOTICE = { 0.35, 0.80, 1 }
local OPTION = { [-1] = "stripDrawerLeft", [1] = "stripDrawerRight" }

ns.stripDrawers = {}

-- a layer over the strip from x0 to x1 (art px from its outer end), its whole height
local function Span(f, side, x0, x1)
    local strip = ns.strips[side]
    local a = side < 0 and "LEFT" or "RIGHT"
    f:ClearAllPoints()
    f:SetPoint("TOP" .. a, strip, "TOP" .. a, -side * x0, 0)
    f:SetPoint("BOTTOM" .. a, strip, "BOTTOM" .. a, -side * x0, 0)
    f:SetWidth(math.max(x1 - x0, 1))
end

-- a drawer's channel starts BAY later; the clip, at its start inset; its end, the strip's
local START = cells.from + BAY
local FROM = START - 2 + KEY.inset
local TO = art.width

local function Drawer(side)
    local strip = ns.strips[side]
    local D = { side = side, open = false, reach = 0, keyList = {}, infoList = {} }
    local away = 0

    local function Layer(what)
        local f = CreateFrame("Frame", "MedalUIDrawer" .. what .. (side < 0 and "Left" or "Right"), strip)
        f:SetFrameLevel(ns.levels.stripTop - 1)
        f:SetClipsChildren(true)
        return f
    end
    D.keys, D.info = Layer("Keys"), Layer("Cells")
    D.keys:SetAllPoints(strip)
    D.info:Hide()

    -- the chevron: on the plate itself, from the ring's side to the channel
    local key = CreateFrame("Button", side < 0 and "MedalUIDrawerLeft" or "MedalUIDrawerRight", strip)
    key:SetFrameLevel(ns.levels.stripTop)
    key:RegisterForClicks("LeftButtonUp")
    ns.OnStrip(key, side, cells.from - 2 + BAY / 2, cells.y, BAY, KEY.channel)
    -- the frame cut into the plate round it, the same in every state
    key.frame = key:CreateTexture(nil, "ARTWORK")
    key.frame:SetTexture(ns.media .. "strips\\drawer-frame")
    key.frame:SetPoint("CENTER")
    key.frame:SetSize(32, 32)
    -- the double chevron on its shadow: a hard one a pixel under it, a soft
    -- one round it
    local function Glyph(layer, sub, size)
        local t = key:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(ns.media .. "strips\\chevron-double")
        t:SetSize(size, size)
        return t
    end
    key.halo = Glyph("OVERLAY", 4, GLYPH + 2)
    key.halo:SetPoint("CENTER")
    key.halo:SetVertexColor(0, 0, 0)
    key.halo:SetAlpha(0.7)
    key.shadow = Glyph("OVERLAY", 5, GLYPH)
    key.shadow:SetPoint("CENTER", 0, -1)
    key.shadow:SetVertexColor(0, 0, 0)
    key.tex = Glyph("OVERLAY", 6, GLYPH)
    key.tex:SetPoint("CENTER")
    key.glow = Glyph("OVERLAY", 7, GLYPH)
    key.glow:SetBlendMode("ADD")
    key.glow:SetAllPoints(key.tex)
    key.glow:Hide()
    key:Hide()
    D.key = key

    function D.On()
        return #D.infoList > 0 and ns.db ~= nil and ns.db[OPTION[side]] ~= false
    end

    -- its colour: blue while noticing (closed), else its gold, full while
    -- open or under the mouse
    local noticing = false
    -- in minimal mode (strips/corners.lua): the frame round it at the
    -- corner's box, the chevron at its strength
    local strength = 1
    local function Paint()
        local lit = noticing and not D.open
        local k = (D.open or key.hover) and LIT or REST
        local c = lit and NOTICE or { k, k, k }
        key.tex:SetVertexColor(c[1], c[2], c[3])
        -- the gold made grey, so the blue reads as blue
        key.tex:SetDesaturated(lit)
        key.halo:SetAlpha(0.7 * strength)
        key.shadow:SetAlpha(strength)
        key.tex:SetAlpha(strength)
        -- a glow under the mouse, a softer one while open, in its colour
        local glow = key.hover and GLOW.hover or D.open and GLOW.open or nil
        key.glow:SetShown(glow ~= nil)
        if glow then
            key.glow:SetAlpha(glow * strength)
            key.glow:SetVertexColor(c[1], c[2], c[3])
            key.glow:SetDesaturated(lit)
        end
    end

    -- the chevron points the way the keys go next: inward to open, out to
    -- close (the art points down: a half turn more than an up one)
    local function Face()
        local turn = (D.open and -side or side) * math.pi / 2 + math.pi
        for _, t in ipairs({ key.halo, key.shadow, key.tex, key.glow }) do t:SetRotation(turn) end
    end

    function D.Corner(box, s)
        key.frame:SetAlpha(box)
        if s ~= strength then
            strength = s
            Paint()
        end
    end

    function D.Notice()
        local any = false
        for _, f in ipairs(D.keyList) do
            local n = f.NotificationOverlay
            if n and n:IsShown() then any = true end
        end
        noticing = any
        Paint()
    end

    -- the layers as far as it has rolled: the keys up to the seam, the cells after it
    local function Place()
        if not D.On() then
            ns.StripChannel(side)
            D.keys:ClearAllPoints()
            D.keys:SetAllPoints(strip)
            D.keys:Show()
            D.info:Hide()
            return
        end
        ns.StripChannel(side, START)
        local seam = FROM + D.reach * (TO - FROM)
        Span(D.keys, side, FROM, seam)
        D.keys:SetShown(D.reach > 0)
        Span(D.info, side, seam, TO)
        D.info:SetShown(D.reach < 1)
    end
    D.Place = Place

    local function Arrange()
        local on = D.On()
        if not on then D.open, D.reach = false, 0 end
        key:SetShown(on)
        ns.StripCells(side, D.keyList, on and START or nil)
        -- the cells abut: the grooves cut between them part them (strips/infocells.lua)
        if on then ns.StripCells(side, D.infoList, START, 0) end
        Face()
        D.Notice()
        Place()
    end

    local queued = false
    local function Later()
        if InCombatLockdown() then
            if queued then return end
            queued = true
            ns.OutOfCombat(function()
                queued = false
                Arrange()
            end)
        else
            Arrange()
        end
    end
    D.Arrange = Later

    function D.Keys(list)
        D.keyList = list
        Later()
    end
    function D.Info(list)
        D.infoList = list
        Later()
    end

    -- the roll, and the wait off the strip before it rolls back
    local ticker = CreateFrame("Frame", nil, strip)
    ticker:Hide()
    D.ticker = ticker
    ticker:SetScript("OnUpdate", function(_, elapsed)
        if InCombatLockdown() then return end
        local goal = D.open and 1 or 0
        if D.reach ~= goal then
            local step = elapsed / ROLL
            D.reach = goal > D.reach and math.min(goal, D.reach + step) or math.max(goal, D.reach - step)
            Place()
        end
        if D.open then
            if strip:IsMouseOver() then away = 0 else away = away + elapsed end
            if away >= LINGER then D.Set(false) end
        elseif D.reach == goal then
            ticker:Hide()
        end
    end)

    function D.Set(open, now)
        if not D.On() or InCombatLockdown() then return end
        D.open = open and true or false
        away = 0
        Face()
        D.Notice()
        if now then
            D.reach = D.open and 1 or 0
            Place()
        end
        ticker:SetShown(D.open or D.reach > 0)
    end

    key:SetScript("OnClick", function() D.Set(not D.open) end)
    key:SetScript("OnEnter", function(self)
        self.hover = true
        Paint()
        local spec = { title = D.open and Tr["Close the menu"] or Tr["Open the menu"] }
        if InCombatLockdown() then
            spec[1] = { "body", Tr["In combat the drawer stays as it is until the fight ends."] }
        end
        ns.Tip(self, function(owner) ns.window.Outside(owner, "ANCHOR_TOP") end, spec)
    end)
    key:SetScript("OnLeave", function(self)
        self.hover = nil
        Paint()
        GameTooltip:Hide()
    end)

    ns.OnSetting(OPTION[side], Later)
    return D
end

for _, side in ipairs({ -1, 1 }) do ns.stripDrawers[side] = Drawer(side) end

-- A fight starting mid-roll: the roll ends where it was going, while it still can.
ns.On("PLAYER_REGEN_DISABLED", function()
    for _, D in pairs(ns.stripDrawers) do
        local goal = D.open and 1 or 0
        if D.reach ~= goal and D.On() then
            D.reach = goal
            D.Place()
        end
    end
end)
