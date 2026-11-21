-- What the list pages share (Reputation, Currency, Skills, Statistics):
-- a scrolling list of headers and rows over the page, and the details
-- under it.
--
--   ns.character.List(body) -> list
--     list:Set(rows)   draws them; each row is
--       { header = true, label, collapsed, depth, click(), bright }   a heading: ± at its
--                                                     right; bright, a stronger band
--       { label, depth, icon, value, bar = { min, max, cur, color, text },
--         selected, click(button), enter(row), dim, color, inset }   an entry; inset,
--                                                     how far short of the right its label stops
--     an entry may also have (the quest tracker's):
--       font = { path, size }   its label's, MedalUI's at 12 without
--       pad                     a gap before what follows, past its depth's indent
--       middle()                its middle click (no other entry hears that button)
--       badge = { atlas, file, tint, size }   a mark before its label: the
--                               atlas where the client has it, else the file
--                               (tinted); size square
--       lead = "bullet" | "mid" | "last" | "pass" | "blank", leadWidth
--                               before the label: a dot, a tree's branch (├ └),
--                               its stem going on past a wrapped line (│), or room
--       group                   rows with the same group light together under
--                               the pointer, the row's own glow over that
--       wash = { r, g, b, a }   its band's colour (the waypoint's quest)
--     list:Draw()      again, at the same scroll (after the body's height changes)
--     list.plain = true  headings a flat band with a +/- at their right,
--                       entries bare (the quest tracker's, over the world);
--                       otherwise a heading is an engraved plate (Plate,
--                       below), a margin above and below it, so rows are not
--                       all as tall, and the entries under it are striped
--                       every other row and tied to it by a thread (Thread)
--     list.fade = true  a plain list's headings fade out to the right, where
--                       the client has gradients
--     list.row          a row's height (22)
--
--   ns.character.Plate(frame, title) -> plate   a heading's engraved plate
--     on frame (the talents' plans have one too): a gold metal rim, a soft
--     gold wash, a shine under its lit edge, a fold triangle and a diamond
--     before title (a font string the caller places on the right)
--     plate:Set{ inset, x, folded, foldable, bright, depth }   inset: the
--       band's room above and below; x: where the fold starts; folded: the
--       triangle turned to point at the title; foldable false: no triangle
--     plate:Hide()
--   ns.character.Thread(row) -> thread   an entry's stripe and thread
--     thread:Set(x, striped, last)   the thread at x (nil: none), down the
--       row and a tick across to its content, or to its middle for the last
--   ns.character.Card(frame) -> card   a slice of a group's parchment card
--     (the spellbook's parchment, in a thin metal rim): each row of a plated
--     list paints its own slice, so a card scrolls by row; the talents'
--     plans wrap each plan in one whole
--     card:Set{ top, h, first, last, plate }   top: the slice's y in the
--       whole list (the grain runs on from slice to slice); h: its height,
--       the frame's and a foot below it on the last; first/last: the card's
--       top or bottom edge here; plate: a heading's slice, its plate the rim
--     card:Hide()
--
--   ns.character.Details(foot, ticks, nothing, lines) -> details
--     details:Set{ title, sub, bar, text, lines }   (nil hides the lot; empty says so)
--     ticks = { { label, tip, click(on) } ... }: details.ticks[i]:Set(on, enabled)
--   ns.character.Tick(parent, { label, tip, click(on), at (its tooltip's
--   anchor, as ns.Tip takes) }) -> one such tick, alone
--     nothing: what it says with nothing chosen; lines: how many its text runs to (3)
--
-- The list fills the body; the wheel scrolls it a row at a time, and a thin
-- thumb on its right says where it is when there is more than it shows.
local _, ns = ...

local ROW, INDENT, BAR_W, BAR_H, ICON = 22, 12, 150, 16, 18
local LEAD, STEM, DOT = 12, 1, 4        -- a lead's room, its stem's width, a bullet's size
local MARGIN = 6                        -- the gap above a plated heading, between cards
local FOOT = 6                          -- a card's room under its last entry
local PAGE = 256                        -- the parchment's tile (as the spellbook's)
local METAL_LIT = { 0.98, 0.88, 0.58 }  -- the rim's lit edge
local METAL_DARK = { 0.36, 0.27, 0.10 } -- its shadowed edge
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local FOLD, DIAMOND = 12, 5             -- a plate's fold triangle, its diamond
local TITLE_SIZE = 14                   -- a plated heading's title
local STRIPE = 0.12                     -- an entry's stripe, every other row (dark, on parchment)

local function Well(f, inset)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", inset, -inset)
    well:SetPoint("BOTTOMRIGHT", -inset, inset)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    return edge, well
end

-- A bar in an ink well with a gold edge, its words over it. b.notches
-- (optional, values between min and max): a dark tick at each, and the
-- part filled past the last one passed a shade lighter. sleek: a flat
-- bronze fill, a sheen on its upper half and a bright top edge, its words
-- cream (the professions' pillars), so they read over it.
local NOTCH = { 0.07, 0.06, 0.04 }
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local BRONZE = { 0.42, 0.31, 0.11 }
local CREAM = { 1, 0.95, 0.82 }
local function Bar(parent, width, height, sleek)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, height or BAR_H)
    holder.ticks = {}
    Well(holder, 1)
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(sleek and WHITE8 or ns.bar)
    holder.bar = bar
    holder.sleek = sleek
    if sleek then
        local fill = bar:GetStatusBarTexture()
        local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        sheen:SetColorTexture(1, 1, 1, 0.08)
        sheen:SetPoint("TOPLEFT", fill, "TOPLEFT")
        sheen:SetPoint("BOTTOMRIGHT", fill, "RIGHT")
        local top = bar:CreateTexture(nil, "ARTWORK", nil, 3)
        top:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.55)
        top:SetHeight(1)
        top:SetPoint("TOPLEFT", fill, "TOPLEFT")
        top:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
        holder.sheen, holder.top = sheen, top
    end
    holder.text = ns.Text(bar, 11)
    holder.text:SetPoint("CENTER", 0, 0)
    if sleek then holder.text:SetTextColor(CREAM[1], CREAM[2], CREAM[3]) end
    function holder:Fill(b)
        local lo, hi, cur = b.min or 0, b.max or 1, b.cur or 0
        if hi <= lo then lo, hi, cur = 0, 1, 1 end
        self.bar:SetMinMaxValues(lo, hi)
        self.bar:SetValue(cur)
        local c = b.color or (self.sleek and BRONZE or GOLD)
        local mute = self.sleek and 1 or ns.mute
        self.bar:SetStatusBarColor(c[1] * mute, c[2] * mute, c[3] * mute)
        self.text:SetText(b.text or "")
        self:Notch(b.notches, lo, hi, cur)
    end
    function holder:Notch(list, lo, hi, cur)
        if not list and #self.ticks == 0 then return end    -- a plain bar makes nothing
        local inner = self:GetWidth() - 2
        local from = lo
        local n = 0
        for _, v in ipairs(list or {}) do
            if v > lo and v < hi then
                n = n + 1
                local t = self.ticks[n]
                if not t then
                    t = self.bar:CreateTexture(nil, "OVERLAY", nil, -1)
                    t:SetWidth(2)
                    t:SetColorTexture(NOTCH[1], NOTCH[2], NOTCH[3], 1)
                    self.ticks[n] = t
                end
                t:ClearAllPoints()
                t:SetPoint("TOP", self.bar, "TOPLEFT", math.floor(inner * (v - lo) / (hi - lo) + 0.5), 0)
                t:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", math.floor(inner * (v - lo) / (hi - lo) + 0.5), 0)
                t:Show()
                if v <= cur then from = v end
            end
        end
        for i = n + 1, #self.ticks do self.ticks[i]:Hide() end
        if not self.lit then
            self.lit = self.bar:CreateTexture(nil, "ARTWORK", nil, 1)
            self.lit:SetColorTexture(1, 0.89, 0.6, 0.12)
        end
        local x0, x1 = inner * (from - lo) / (hi - lo), inner * (math.min(cur, hi) - lo) / (hi - lo)
        self.lit:SetShown(n > 0 and x1 - x0 >= 1)
        if n > 0 then
            self.lit:ClearAllPoints()
            self.lit:SetPoint("TOPLEFT", self.bar, "TOPLEFT", math.floor(x0 + 0.5), 0)
            self.lit:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", math.floor(x0 + 0.5), 0)
            self.lit:SetWidth(math.max(1, math.floor(x1 - x0 + 0.5)))
        end
    end
    return holder
end
ns.character.Bar = Bar

-- ---------------------------------------------------------------- plate
local function Plate(f, title)
    local plate = { title = title }
    plate.wash = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    -- lit along the top, shadowed along the bottom, the sides running from
    -- one to the other; a shine inside, under the top
    plate.rim = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        plate.rim[side] = f:CreateTexture(nil, "BORDER")
    end
    plate.shine = f:CreateTexture(nil, "BORDER")
    plate.fold = f:CreateTexture(nil, "ARTWORK")
    plate.fold:SetTexture(ns.media .. "character\\fold")
    plate.fold:SetSize(FOLD, FOLD)
    plate.fold:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    plate.diamond = f:CreateTexture(nil, "ARTWORK")
    plate.diamond:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    plate.diamond:SetSize(DIAMOND, DIAMOND)
    if plate.diamond.SetRotation then plate.diamond:SetRotation(math.pi / 4) end
    function plate:Hide()
        for _, t in ipairs({ self.wash, self.shine, self.fold, self.diamond }) do t:Hide() end
        for _, t in pairs(self.rim) do t:Hide() end
    end
    function plate:Set(o)
        local inset, x = o.inset or 0, o.x or 6
        local a = o.bright and 0.55 or (o.depth or 0) == 0 and 0.30 or 0.15
        local wash = self.wash
        wash:ClearAllPoints()
        wash:SetPoint("TOPLEFT", 0, -inset)
        wash:SetPoint("BOTTOMRIGHT", 0, inset)
        if wash.SetGradient and CreateColor then
            wash:SetColorTexture(1, 1, 1, 1)
            wash:SetGradient("VERTICAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a * 0.5),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a * 1.5))
        else
            wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a)
        end
        local rim = self.rim
        rim.TOP:ClearAllPoints()
        rim.TOP:SetPoint("TOPLEFT", 0, -inset)
        rim.TOP:SetPoint("TOPRIGHT", 0, -inset)
        rim.TOP:SetHeight(1)
        rim.TOP:SetColorTexture(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 1)
        rim.BOTTOM:ClearAllPoints()
        rim.BOTTOM:SetPoint("BOTTOMLEFT", 0, inset)
        rim.BOTTOM:SetPoint("BOTTOMRIGHT", 0, inset)
        rim.BOTTOM:SetHeight(1)
        rim.BOTTOM:SetColorTexture(METAL_DARK[1], METAL_DARK[2], METAL_DARK[3], 1)
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local t = rim[side]
            t:ClearAllPoints()
            t:SetPoint("TOP" .. side, 0, -inset)
            t:SetPoint("BOTTOM" .. side, 0, inset)
            t:SetWidth(1)
            if t.SetGradient and CreateColor then
                t:SetColorTexture(1, 1, 1, 1)
                t:SetGradient("VERTICAL", CreateColor(METAL_DARK[1], METAL_DARK[2], METAL_DARK[3], 1),
                    CreateColor(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 1))
            else
                t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            end
        end
        self.shine:ClearAllPoints()
        self.shine:SetPoint("TOPLEFT", 1, -(inset + 1))
        self.shine:SetPoint("TOPRIGHT", -1, -(inset + 1))
        self.shine:SetHeight(1)
        self.shine:SetColorTexture(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 0.35)
        -- the fold, pointing down open and at the title folded; the diamond
        -- after it, then the title
        local foldable = o.foldable ~= false
        self.fold:SetShown(foldable)
        self.fold:ClearAllPoints()
        self.fold:SetPoint("LEFT", wash, "LEFT", x, 0)
        if self.fold.SetRotation then self.fold:SetRotation(o.folded and -math.pi / 2 or 0) end
        local after = foldable and x + FOLD + 4 or x
        self.diamond:ClearAllPoints()
        self.diamond:SetPoint("CENTER", wash, "LEFT", after + 3, 0)
        self.title:ClearAllPoints()
        self.title:SetPoint("LEFT", wash, "LEFT", after + 3 + DIAMOND + 4, 0)
        self.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        for _, t in ipairs({ wash, self.shine, self.diamond }) do t:Show() end
        for _, t in pairs(rim) do t:Show() end
    end
    plate:Hide()
    return plate
end
ns.character.Plate = Plate

-- --------------------------------------------------------------- thread
local function Thread(r)
    local t = {}
    t.stripe = r:CreateTexture(nil, "BACKGROUND", nil, 0)
    t.stripe:SetColorTexture(0, 0, 0, STRIPE)
    t.stem = r:CreateTexture(nil, "ARTWORK")
    t.stem:SetWidth(1)
    t.stem:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.9)
    t.tick = r:CreateTexture(nil, "ARTWORK")
    t.tick:SetSize(5, 1)
    t.tick:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.9)
    function t:Set(x, striped, last)
        self.striped, self.last, self.x = striped and true or false, last and true or false, x
        self.stripe:SetShown(striped and true or false)
        self.stripe:ClearAllPoints()
        self.stripe:SetPoint("TOPLEFT", x and x + 6 or 0, 0)
        self.stripe:SetPoint("BOTTOMRIGHT")
        self.stem:SetShown(x ~= nil)
        self.tick:SetShown(x ~= nil)
        if not x then return end
        self.stem:ClearAllPoints()
        self.stem:SetPoint("TOPLEFT", x, 0)
        self.stem:SetPoint("BOTTOMLEFT", x, last and math.floor(r:GetHeight() / 2) or 0)
        self.tick:ClearAllPoints()
        self.tick:SetPoint("LEFT", r, "LEFT", x, 0)
    end
    t:Set(nil, false, false)
    return t
end
ns.character.Thread = Thread

-- ----------------------------------------------------------------- card
local function Card(f)
    local c = {}
    c.paper = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    c.paper:SetTexture(ns.media .. "spellbook\\parchment", "REPEAT", "REPEAT")
    -- black fading in from the left edge, and up from the foot
    c.shadeL = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    c.shadeB = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    for _, e in ipairs({ { c.shadeL, "HORIZONTAL", 0.35 }, { c.shadeB, "VERTICAL", 0.3 } }) do
        local t, dir, a = e[1], e[2], e[3]
        if t.SetGradient and CreateColor then
            t:SetColorTexture(1, 1, 1, 1)
            t:SetGradient(dir, CreateColor(0, 0, 0, a), CreateColor(0, 0, 0, 0))
        else
            t:SetColorTexture(0, 0, 0, a / 2)
        end
    end
    c.shadeL:SetWidth(10)
    c.shadeB:SetHeight(10)
    c.rim = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do c.rim[side] = f:CreateTexture(nil, "BORDER") end
    c.rim.TOP:SetColorTexture(METAL_LIT[1], METAL_LIT[2], METAL_LIT[3], 1)
    c.rim.BOTTOM:SetColorTexture(METAL_DARK[1], METAL_DARK[2], METAL_DARK[3], 1)
    c.rim.LEFT:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.rim.RIGHT:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    -- the grain from the slice's place in the whole: across the frame's
    -- width, down from top
    local function Coords()
        if not c.top then return end
        local w = f:GetWidth() or 0
        c.paper:SetTexCoord(0, w / PAGE, c.top / PAGE, (c.top + c.h) / PAGE)
    end
    f:HookScript("OnSizeChanged", Coords)
    function c:Hide()
        self.top = nil
        for _, t in ipairs({ self.paper, self.shadeL, self.shadeB }) do t:Hide() end
        for _, t in pairs(self.rim) do t:Hide() end
    end
    function c:Set(o)
        self.top, self.h = o.top or 0, o.h or (f:GetHeight() or 0)
        self.first, self.last = o.first and true or false, o.last and true or false
        local below = math.max(0, self.h - (f:GetHeight() or 0))      -- the foot, past the frame
        local p = self.paper
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT")
        p:SetPoint("BOTTOMRIGHT", 0, -below)
        p:Show()
        Coords()
        -- a heading's plate is the card's rim there; an entry's slice has
        -- the sides, and the top or bottom edge where the card starts or ends
        local plate = o.plate and true or false
        local rim = self.rim
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local t = rim[side]
            t:ClearAllPoints()
            t:SetPoint("TOP" .. side)
            t:SetPoint("BOTTOM" .. side, 0, -below)
            t:SetWidth(1)
            t:SetShown(not plate)
        end
        rim.TOP:ClearAllPoints()
        rim.TOP:SetPoint("TOPLEFT")
        rim.TOP:SetPoint("TOPRIGHT")
        rim.TOP:SetHeight(1)
        rim.TOP:SetShown(self.first and not plate)
        rim.BOTTOM:ClearAllPoints()
        rim.BOTTOM:SetPoint("BOTTOMLEFT", 0, -below)
        rim.BOTTOM:SetPoint("BOTTOMRIGHT", 0, -below)
        rim.BOTTOM:SetHeight(1)
        rim.BOTTOM:SetShown(self.last and not plate)
        self.shadeL:ClearAllPoints()
        self.shadeL:SetPoint("TOPLEFT", 1, 0)
        self.shadeL:SetPoint("BOTTOMLEFT", 1, -below)
        self.shadeL:SetShown(not plate)
        self.shadeB:ClearAllPoints()
        self.shadeB:SetPoint("BOTTOMLEFT", 1, -below + 1)
        self.shadeB:SetPoint("BOTTOMRIGHT", -1, -below + 1)
        self.shadeB:SetShown(self.last and not plate)
    end
    c:Hide()
    return c
end
ns.character.Card = Card

-- ----------------------------------------------------------------- rows
local function Row(list)
    local r = CreateFrame("Button", nil, list)
    r:SetHeight(ROW)
    r.fill = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.fill:SetAllPoints()
    r.mark = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.mark:SetAllPoints()
    r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    -- the selected entry's band, a gold hairline along each edge
    r.markEdges = {}
    for i, point in ipairs({ "TOP", "BOTTOM" }) do
        local t = r:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetHeight(1)
        t:SetPoint(point .. "LEFT", r.mark, point .. "LEFT")
        t:SetPoint(point .. "RIGHT", r.mark, point .. "RIGHT")
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.4)
        r.markEdges[i] = t
    end
    r.glow = r:CreateTexture(nil, "HIGHLIGHT")
    r.glow:SetAllPoints()
    r.glow:SetColorTexture(1, 1, 1, 0.06)
    -- the group's light, the glow's colour, on every row of it
    r.lit = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    r.lit:SetAllPoints()
    r.lit:SetColorTexture(1, 1, 1, 0.06)
    r.lit:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.badge = r:CreateTexture(nil, "ARTWORK")
    -- a lead: a dot, or a stem down the row and a branch across to the label
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(DOT, DOT)
    r.stem = r:CreateTexture(nil, "ARTWORK")
    r.stem:SetWidth(STEM)
    r.branch = r:CreateTexture(nil, "ARTWORK")
    r.branch:SetHeight(STEM)
    r.label = ns.Text(r, 12)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    -- a heading's plate (its title the label) and an entry's thread
    r.plate = Plate(r, r.label)
    r.thread = Thread(r)
    r.card = Card(r)
    r.value = ns.Text(r, 12)
    r.value:SetPoint("RIGHT", -6, 0)
    r.sign = ns.Text(r, 14)
    r.sign:SetPoint("RIGHT", -6, 0)
    r.sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    r.bar = Bar(r, BAR_W)
    r.bar:SetPoint("RIGHT", -4, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    r:SetScript("OnClick", function(self, button)
        local d = self.data
        if not d then return end
        -- the middle button only for an entry that asks for it
        if button == "MiddleButton" then
            if d.middle then d.middle() end
        elseif d.click then
            d.click(button)
        end
    end)
    r:SetScript("OnEnter", function(self)
        list:Light(self.data and self.data.group)
        if self.data and self.data.enter then self.data.enter(self) end
    end)
    r:SetScript("OnLeave", function()
        list:Light(nil)
        GameTooltip:Hide()
    end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) list:Scroll(-delta) end)
    return r
end

-- The mark before a label: the atlas where the client has one, its own
-- colours; else the file, tinted.
local function Badge(t, b)
    local atlas = b.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(b.atlas) and b.atlas
    if atlas then
        t:SetAtlas(atlas)
        t:SetVertexColor(1, 1, 1)
    else
        t:SetTexture(b.file)
        t:SetTexCoord(0, 1, 0, 1)
        local c = b.tint or { 1, 1, 1 }
        t:SetVertexColor(c[1], c[2], c[3])
    end
    t:SetDesaturated(not atlas and b.tint ~= nil)
end
ns.character.Badge = Badge     -- the NPC windows' quest marks too (npc/window.lua)

-- The lead at x, w wide, in the label's colour: a dot, or a stem (the
-- whole row, or down to the middle for the last) and a branch from it.
local function Lead(r, d, x, w, c)
    local kind = d.lead
    local mid = x + math.floor(w / 2) - 2
    r.dot:SetShown(kind == "bullet")
    r.stem:SetShown(kind == "mid" or kind == "last" or kind == "pass")
    r.branch:SetShown(kind == "mid" or kind == "last")
    for _, t in ipairs({ r.dot, r.stem, r.branch }) do t:SetColorTexture(c[1], c[2], c[3], 0.6) end
    r.dot:ClearAllPoints()
    r.dot:SetPoint("CENTER", r, "LEFT", mid, 0)
    r.stem:ClearAllPoints()
    r.stem:SetPoint("TOPLEFT", mid, 0)
    r.stem:SetPoint("BOTTOMLEFT", mid, kind == "last" and r:GetHeight() / 2 or 0)
    r.branch:ClearAllPoints()
    r.branch:SetPoint("LEFT", r, "LEFT", mid, 0)
    r.branch:SetPoint("RIGHT", r, "LEFT", x + w - 2, 0)
end

-- meta: the row's place in its group and card (List:Place): { striped,
-- thread, first, last, top, h }
local function Paint(r, d, list, meta)
    r.data = d
    local plated = d.header and not list.plain and true or false
    if meta then
        r.card:Set({ top = meta.top, h = meta.h, first = meta.first, last = meta.last, plate = d.header })
    else
        r.card:Hide()
    end
    local depth = d.depth or 0
    local x = 6 + depth * INDENT + (d.pad or 0)
    local font = plated and { ns.font, TITLE_SIZE } or d.font or { ns.font, 12 }
    if r.font ~= font[1] .. font[2] then
        r.label:SetFont(font[1], font[2], "")
        r.font = font[1] .. font[2]
    end
    r.icon:SetShown(d.icon ~= nil)
    if d.icon then
        r.icon:SetTexture(d.icon)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", x, 0)
        x = x + ICON + 4
    end
    r.badge:SetShown(d.badge ~= nil)
    if d.badge then
        local size = d.badge.size or ICON
        Badge(r.badge, d.badge)
        r.badge:SetSize(size, size)
        r.badge:ClearAllPoints()
        r.badge:SetPoint("LEFT", x, 0)
        x = x + size + 4
    end
    local lead = d.lead and d.leadWidth or LEAD
    Lead(r, d, x, lead, d.dim and ns.colors.dim or d.color or ns.colors.text)
    if d.lead then x = x + lead end
    r.lit:SetShown(d.group ~= nil and d.group == list.lit)
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", x, 0)
    r.label:SetText(d.label or "")
    r.thread:Set(meta and meta.thread, meta and meta.striped, meta and meta.last)
    if plated then
        r.fill:SetColorTexture(0, 0, 0, 0)
        r.plate:Set({ x = x, folded = d.collapsed, foldable = d.click ~= nil, bright = d.bright,
            depth = depth })
        r.sign:SetText("")
    elseif d.header then
        r.plate:Hide()
        local a = d.bright and 0.55 or depth == 0 and 0.30 or 0.15
        if list.fade and r.fill.SetGradient and CreateColor then
            r.fill:SetColorTexture(1, 1, 1, 1)
            r.fill:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], a),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0))
        else
            r.fill:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a)
        end
        r.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        r.sign:SetText(d.collapsed and "+" or "-")
    else
        r.plate:Hide()
        local w = d.wash
        r.fill:SetColorTexture(w and w[1] or 0, w and w[2] or 0, w and w[3] or 0, w and w[4] or 0)
        r.label:SetTextColor(unpack(d.color or d.dim and ns.colors.dim or ns.colors.text))
        r.sign:SetText("")
    end
    r.mark:SetShown(d.selected and true or false)
    for _, t in ipairs(r.markEdges) do t:SetShown(d.selected and true or false) end
    -- a heading with a bar of its own (a reputation's) shows it at its right,
    -- left of its sign on a plain list
    r.bar:SetShown(d.bar ~= nil)
    r.bar:ClearAllPoints()
    r.bar:SetPoint("RIGHT", d.header and not plated and -20 or -4, 0)
    if d.bar then r.bar:Fill(d.bar) end
    r.value:SetShown(d.bar == nil and d.value ~= nil)
    r.value:SetText(d.value or "")
    r.label:SetPoint("RIGHT", r, "RIGHT", d.inset and -d.inset or d.bar and -(BAR_W + 10) or d.value and -60 or -24, 0)
end

-- ----------------------------------------------------------------- list
local List = {}

function List:Shown() return math.max(1, math.floor((self.body:GetHeight() or 0) / self.row)) end

-- the rows of a group lit together (nil: none)
function List:Light(group)
    self.lit = group
    for _, r in ipairs(self.rows) do
        r.lit:SetShown(group ~= nil and r.data ~= nil and r.data.group == group)
    end
end

-- the room row k takes: a plated heading's the gap above it too, a card's
-- last entry its foot
function List:Height(k)
    if self.plain then return self.row end
    local d, m = self.data[k], self.meta[k]
    if d.header then return self.row + MARGIN end
    return self.row + (m and m.last and FOOT or 0)
end

-- the furthest the list scrolls: the first row from which the rest fit
function List:Most()
    if self.plain then return math.max(0, #self.data - self:Shown()) end
    local room, y = self.body:GetHeight() or 0, 0
    for k = #self.data, 1, -1 do
        y = y + self:Height(k)
        if y > room then return k end
    end
    return 0
end

function List:Scroll(lines)
    local most = self:Most()
    self.offset = math.max(0, math.min(most, self.offset + lines))
    self:Draw()
end

-- A plated list's rows, each as tall as it is, down to the body's foot
-- (one at least).
function List:DrawPlated()
    self.offset = math.max(0, math.min(self.offset, self:Most()))
    local room, y, n = self.body:GetHeight() or 0, 0, 0
    for k = self.offset + 1, #self.data do
        local d = self.data[k]
        local h = self:Height(k)
        if n > 0 and y + h > room then break end
        n = n + 1
        local r = self.rows[n]
        if not r then
            r = Row(self)
            self.rows[n] = r
        end
        -- the row's frame is its line: a heading's below its gap, an
        -- entry's foot painted past it by its card
        local gap = d.header and MARGIN or 0
        r:SetHeight(self.row)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(y + gap))
        r:SetPoint("TOPRIGHT", -6, -(y + gap))
        r:Show()
        Paint(r, d, self, self.meta[k])
        y = y + h
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    local total, most = #self.data, self:Most()
    self.empty:SetShown(total == 0)
    self.track:SetShown(most > 0)
    if most > 0 then
        local h = room
        local size = math.max(12, h * n / total)
        self.thumb:SetHeight(size)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(h - size) * self.offset / most)
    end
end

function List:Draw()
    if not self.plain then return self:DrawPlated() end
    local shown = self:Shown()
    self.offset = math.max(0, math.min(self.offset, #self.data - shown))
    for i = 1, shown do
        local r = self.rows[i]
        if not r then
            r = Row(self)
            self.rows[i] = r
        end
        r:SetHeight(self.row)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(i - 1) * self.row)
        r:SetPoint("TOPRIGHT", -6, -(i - 1) * self.row)
        local d = self.data[self.offset + i]
        r:SetShown(d ~= nil)
        if d then Paint(r, d, self) end
    end
    for i = shown + 1, #self.rows do self.rows[i]:Hide() end
    local total = #self.data
    self.empty:SetShown(total == 0)
    self.track:SetShown(total > shown)
    if total > shown then
        local h = shown * self.row
        local size = math.max(12, h * shown / total)
        self.thumb:SetHeight(size)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(h - size) * self.offset / (total - shown))
    end
end

-- Each row's place in its group, on a plated list: an entry striped every
-- other row from its heading, its thread under the heading's indent. A card
-- starts at a heading (or at the first row, before any heading) and ends at
-- the row before the next heading or the end. Entries before any heading
-- are striped but have no thread. top and h: the row's slice of its card,
-- in the whole list (a heading's below its gap, a last entry's with its
-- foot).
function List:Place()
    self.meta = {}
    if self.plain then return end
    local n, under, y = 0, false, 0
    for k, d in ipairs(self.data) do
        local nextOne = self.data[k + 1]
        local last = nextOne == nil or nextOne.header == true
        local m = { last = last }
        if d.header then
            n, under = 0, true
            m.first = true
        else
            n = n + 1
            m.first = k == 1
            m.striped = n % 2 == 1
            m.thread = under and 3 + math.max(0, (d.depth or 1) - 1) * INDENT or nil
        end
        self.meta[k] = m
        local h = self:Height(k)
        local gap = d.header and MARGIN or 0
        m.top, m.h = y + gap, h - gap
        y = y + h
    end
end

function List:Set(rows)
    self.data = rows
    self:Place()
    self:Draw()
end

function ns.character.List(body, empty)
    local list = CreateFrame("Frame", nil, body)
    list:SetAllPoints()
    for k, v in pairs(List) do list[k] = v end
    list.body, list.rows, list.data, list.offset, list.row, list.meta = body, {}, {}, 0, ROW, {}
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta) end)
    list.track = list:CreateTexture(nil, "ARTWORK")
    list.track:SetPoint("TOPRIGHT")
    list.track:SetPoint("BOTTOMRIGHT")
    list.track:SetWidth(3)
    list.track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    list.thumb = list:CreateTexture(nil, "OVERLAY")
    list.thumb:SetWidth(3)
    list.thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    hooksecurefunc(list.track, "SetShown", function(_, on) list.thumb:SetShown(on) end)
    list.empty = ns.Text(list, 13)
    list.empty:SetPoint("CENTER")
    list.empty:SetTextColor(unpack(ns.colors.dim))
    list.empty:SetText(empty or "")
    return list
end

-- -------------------------------------------------------------- details
local TICK = 16
local TITLE, SUB, LINE = 18, 14, 15      -- the details' title, its sub-line, a line of its text

local function Tick(foot, spec)
    local b = CreateFrame("Button", nil, foot)
    b:SetHeight(TICK)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(TICK, TICK)
    b.box:SetPoint("LEFT")
    Well(b.box, 1)
    b.check = b.box:CreateTexture(nil, "ARTWORK")
    b.check:SetPoint("TOPLEFT", 3, -3)
    b.check:SetPoint("BOTTOMRIGHT", -3, 3)
    b.check:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.label = ns.Text(b, 12)
    b.label:SetPoint("LEFT", b.box, "RIGHT", 5, 0)
    b.label:SetText(spec.label)
    b:SetWidth(TICK + 5 + b.label:GetStringWidth() + 4)
    b:SetScript("OnClick", function(self)
        if self.enabled then spec.click(not self.on) end
    end)
    b:SetScript("OnEnter", function(self)
        ns.Tip(self, spec.at or "ANCHOR_TOP", { title = spec.tip, color = ns.colors.white, wrap = true })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:Set(on, enabled)
        self.on, self.enabled = on and true or false, enabled ~= false
        self.check:SetShown(self.on)
        self.label:SetTextColor(unpack(self.enabled and ns.colors.text or ns.colors.dim))
        self:SetAlpha(self.enabled and 1 or 0.5)
    end
    return b
end

ns.character.Tick = Tick

function ns.character.Details(foot, ticks, nothing, lines)
    local d = { ticks = {} }
    lines = lines or 3
    d.title = ns.Text(foot, 15)
    d.title:SetPoint("TOP", 0, -2)
    d.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    d.sub = ns.Text(foot, 12)
    d.sub:SetPoint("TOP", d.title, "BOTTOM", 0, -3)
    d.sub:SetTextColor(unpack(ns.colors.dim))
    d.bar = Bar(foot, 220)
    d.bar:SetPoint("TOP", d.sub, "BOTTOM", 0, -5)
    d.text = ns.PlainText(foot, 12)
    d.text:SetPoint("TOPLEFT", 4, -(TITLE + 3 + SUB + 5 + BAR_H + 6))
    d.text:SetPoint("TOPRIGHT", -4, -(TITLE + 3 + SUB + 5 + BAR_H + 6))
    d.text:SetJustifyH("LEFT")
    d.text:SetJustifyV("TOP")
    d.text:SetHeight(lines * LINE)           -- more trail off
    -- the line said when nothing is chosen: as wide as the foot, wrapping
    -- (one with only its centre placed runs past the window's edges)
    d.nothing = ns.Text(foot, 13)
    d.nothing:SetPoint("LEFT", 8, 0)
    d.nothing:SetPoint("RIGHT", -8, 0)
    d.nothing:SetJustifyH("CENTER")
    d.nothing:SetWordWrap(true)
    d.nothing:SetTextColor(unpack(ns.colors.dim))
    d.nothing:SetText(nothing or "")
    local prev
    for i, spec in ipairs(ticks or {}) do
        local b = Tick(foot, spec)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 16, 0) else b:SetPoint("BOTTOMLEFT", 4, 2) end
        d.ticks[i], prev = b, b
    end
    d.height = TITLE + 3 + SUB + 5 + BAR_H + 6 + lines * LINE + ((ticks and #ticks > 0) and (6 + TICK + 2) or 0)
    local parts = { d.title, d.sub, d.bar, d.text }
    function d:Set(info)
        for _, p in ipairs(parts) do p:SetShown(info ~= nil) end
        for _, b in ipairs(self.ticks) do b:SetShown(info ~= nil) end
        self.nothing:SetShown(info == nil)
        if not info then return end
        self.title:SetText(info.title or "")
        self.sub:SetText(info.sub or "")
        self.bar:SetShown(info.bar ~= nil)
        if info.bar then self.bar:Fill(info.bar) end
        local text = info.text or ""
        if info.lines then
            text = (text ~= "" and text .. "\n\n" or "") .. table.concat(info.lines, "\n")
        end
        self.text:SetText(text)
    end
    return d
end
