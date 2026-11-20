-- The unit-frame editor's window, laid out as the Settings window
-- (options/window.lua): a head bar (its name, Medalluin and the version,
-- the x in its own cell); the chosen frame's pieces down the sidebar under
-- their groups' headings (Frame, Texts, Icons, Auras), the chosen one lit,
-- a changed one marked; a page header (the frame's name, the console's or
-- the widgets' and whose, a (?) saying what the frame is) with the frames
-- as its sheets, the console's then the widgets'. Under it two cards: the
-- canvas (options/canvas.lua: the frame drawn large, the chosen piece
-- boxed; drag it to move the piece, the arrow keys nudge it), its zoom,
-- Fit and Reset frame in its band and the previews under it (editor.lua's
-- E.preview: Glow, a dispel type's or none; Show, the aggro glow, the
-- combat tint, crowd control, a boss debuff, your buffs and debuffs); and
-- the chosen piece's, its name, Changed and Shown in its band, its tabs
-- (Place, Look, Auras) over its rows, applied as they change, Reset piece
-- at its foot. The footer has the preview (simulate.lua's: a party, a
-- raid, bosses and an arena to edit out of a group) and Close. editor.lua
-- is the model: what the pieces are, and where they go.
--
-- Opened by /mdlui edit, and by the button on each Unit Frames tab.
local _, ns = ...
local Tr = ns.L

local UI = ns.OptionsUI
local C = UI.colors
local E = ns.editor

-- the Settings window's measures (options/window.lua)
local W, H = 1040, 680
local EDGE, BAR_H, SIDE_W, FOOT = 1, 34, 200, 40
local X, RIGHT = EDGE + SIDE_W + 18, 16          -- the page's left, its right margin
local HEAD_TOP, HEAD_H, STRIP_H = EDGE + BAR_H + 14, 50, 26
local TOP = HEAD_TOP + HEAD_H + STRIP_H - 4 + 12  -- the cards' top, under the frames' tabs
local BOTTOM = EDGE + FOOT + 14                   -- the cards' foot, over the footer
local CARD_PAD, BAND_H, COL_GAP, ROW_GAP = 12, 36, 12, 4
local ITEM_H, CAT_H = 24, 28                      -- the sidebar's rows: a piece, a group's heading
local CANVAS_W = 480                              -- the canvas's card; the piece's takes the rest
local BODY_W = W - X - RIGHT - CANVAS_W - COL_GAP
local ROWS_W = BODY_W - 2 * CARD_PAD              -- a row's width in the piece's card
local PIECE_TAB_H = 22                            -- the piece's tabs (Place, Look, Auras)
local BODY_FOOT = 44                              -- the piece's card's foot: Reset piece
local GAP = ROW_GAP

local window, tabs, list, stage, body, chips
local frame, piece        -- what is chosen: the frame (E.FRAMES) and its piece
local tab = "place"       -- the piece's tab, kept by name from piece to piece
local controls = {}       -- the body's controls, by field
local Refresh

-- ------------------------------------------------------------ the fields
-- A field of the chosen piece: what the player set, else where the piece
-- is now (a place read off a button the first time, editor.lua's E.Seed).
local function Edits() return E.Edits(frame, piece) or {} end
-- (read each time: a button laid again by its own code has a new place)
local function Seed() return E.Seed(frame, piece) end
local function PlaceField(field)
    local e = Edits()
    if e.h then return e[field] end
    return Seed()[field]
end
-- A change of place: the first one writes the whole place, so what is not
-- changed stays where it was. A row placed is in its frame again (Outside).
local function SetPlace(fields)
    local write = { out = E.NIL }
    -- a row outside, placed: it goes on running the way it ran out there
    -- (2026-11-17: dragged, Outside went off and it turned to its own way)
    local e = Edits()
    if e.out and E.PIECES[piece].type == "row" then write.grow = E.OutGrow(frame, e) or E.NIL end
    if not Edits().h then
        for k, v in pairs(Seed()) do write[k] = v end
    end
    for k, v in pairs(fields) do write[k] = v end
    E.Set(frame, piece, write)
end
local function SetField(field, value) E.Set(frame, piece, { [field] = value }) end

-- A row outside its frame moves from its place there (just past the
-- frame's end) by ox, outward, and oy, up: a drag or a key moves it and it
-- stays outside.
local function Out() return E.PIECES[piece].type == "row" and Edits().out and true or false end
local function SetOut(ox, oy)
    E.Set(frame, piece, { ox = ox ~= 0 and ox or E.NIL, oy = oy ~= 0 and oy or E.NIL })
end
-- the way outward from button b's row, on the screen (-1 left, 1 right)
local function OutWay(b)
    b = b or frame.buttons()[1]
    return b and E.OutEdge(b, frame, Edits()) or -1
end

local function Mirrored() return frame.id == "unit" or frame.id == "party" end

-- What a piece's outline is set to, read off its font when not set.
local function Outline()
    local e = Edits()
    if e.outline then return e.outline end
    local b = frame.buttons()[1]
    local r = b and E.PIECES[piece].get(b)
    local flags = r and r.GetFont and select(3, r:GetFont()) or ""
    flags = tostring(flags or "")
    return flags:match("THICK") and "thick" or flags:match("OUTLINE") and "thin" or "none"
end

-- ------------------------------------------------------------ the controls
-- An offset to the hundredth: one saved earlier from a float read back
-- from the game (-2 as -2.0000002384186) shows as what it is.
local function Pixels(v) return tostring(math.floor(v * 100 + 0.5) / 100) end

local function Specs()
    return {
        shown = { kind = "check", label = Tr["Shown"],
            get = function() return E.Shown(frame, piece) end,
            set = function(v)
                local key = frame.shows and frame.shows[piece]
                if key then ns.SetOption(key, v) else SetField("shown", v) end
            end,
            tip = function()
                local key = frame.shows and frame.shows[piece]
                if key then return Tr["The same option as on the Unit Frames page."] end
                return Tr["Off, the piece is not drawn, but keeps its place."]
            end },
        on = { kind = "choice", label = Tr["On"],
            choices = E.ON,
            get = function() return PlaceField("on") or "health" end,
            set = function(v) SetPlace({ on = v }) end,
            tip = Tr["What the piece is placed on. Its anchor (a corner, an edge or the middle of it) is "
                .. "where it is dropped on the canvas."] },
        x = { kind = "slider", label = Tr["Inward"], min = -150, max = 150,
            get = function() return PlaceField("x") or 0 end,
            set = function(v) SetPlace({ x = v }) end, text = Pixels,
            tip = Tr["Pixels from the anchor, toward the frame's inner end (on the console) or right (a widget)."] },
        ox = { kind = "slider", label = Tr["Outward"], min = -300, max = 150,
            get = function() return Edits().ox or 0 end,
            set = function(v) SetOut(v, Edits().oy or 0) end, text = Pixels,
            tip = Tr["Pixels from its place just past the frame's end, away from the frame."] },
        oy = { kind = "slider", label = Tr["Up"], min = -60, max = 60,
            get = function() return Edits().oy or 0 end,
            set = function(v) SetOut(Edits().ox or 0, v) end, text = Pixels,
            tip = Tr["Pixels from its place level with the frame's top, up."] },
        y = { kind = "slider", label = Tr["Up"], min = -60, max = 60,
            get = function() return PlaceField("y") or 0 end,
            set = function(v) SetPlace({ y = v }) end, text = Pixels,
            tip = Tr["Pixels from the anchor, up."] },
        size = { kind = "slider", label = Tr["Size"], min = 6, max = 48,
            get = function()
                -- (the debuffs matched to the buffs: theirs)
                local own = piece == "mine" and E.Matched(frame) and E.BuffSize(frame) or Edits().size
                return own or math.floor((E.SizeOf(frame, piece) or 12) + 0.5)
            end,
            set = function(v) SetField("size", v) end,
            tip = Tr["A text's font size, an icon's width and height."] },
        -- the debuffs', while both rows are outside
        match = { kind = "check", label = Tr["Match buffs size"],
            get = function() return Edits().match == true end,
            set = function(v) SetField("match", v or E.NIL) end,
            tip = Tr["The debuffs as large as the buffs, and following them as the buffs' Size changes. Only "
                .. "while both rows are outside the frame; each keeps its own side."] },
        outline = { kind = "choice", label = Tr["Outline"], choices = E.OUTLINES,
            get = Outline, set = function(v) SetField("outline", v) end,
            tip = Tr["A dark edge round the letters."] },
        format = { kind = "choice", label = Tr["Format"], choices = {},
            get = function()
                local formats = E.FORMATS[piece]
                return Edits().format or (formats and formats[1][1])
            end,
            set = function(v) SetField("format", v) end,
            tip = Tr["What the text says."] },
        len = { kind = "slider", label = Tr["Longest name"], min = 0, max = 30,
            get = function() return Edits().len or 0 end,
            set = function(v) SetField("len", v > 0 and v or E.NIL) end,
            text = function(v) return v > 0 and format(Tr["%d letters"], v) or Tr["No limit"] end,
            tip = Tr["Letters before a name is cut. A name the game keeps secret is shown whole."] },
        grow = { kind = "choice", label = Tr["Grow"], choices = {},
            get = function() return Edits().grow or (E.RowOwn(frame, piece)) end,
            set = function(v) SetField("grow", v) end,
            tip = Tr["Which way the icons run from the first."] },
        cols = { kind = "slider", label = Tr["Columns"], min = 1, max = 10,
            get = function() return Edits().cols or 10 end,
            set = function(v) SetField("cols", v < 10 and v or E.NIL) end,
            text = function(v) return v < 10 and tostring(v) or Tr["One line"] end,
            tip = Tr["Icons in a line before the next starts, away from the edge the first hangs on. Growing up "
                .. "or down, icons in a column."] },
        out = { kind = "check", label = Tr["Outside"],
            get = function() return Edits().out == true end,
            set = function(v) SetField("out", v or E.NIL) end,
            tip = Tr["Beyond the frame's outer end, running toward the screen's edge. With buffs and debuffs both "
                .. "outside, the debuffs' Next to buffs says where they go. A drag or the arrow keys move "
                .. "it from there, outside still."] },
        -- a widget's: which side, or toward the nearer edge of the screen
        side = { kind = "choice", label = Tr["Place"], choices = {
                { "in", Tr["Inside the frame"] }, { "edge", Tr["Toward screen edge"] },
                { "left", Tr["Outside, left"] }, { "right", Tr["Outside, right"] } },
            get = function()
                local out = Edits().out
                return out == true and "edge" or out or "in"
            end,
            set = function(v) SetField("out", v == "edge" or (v ~= "in" and v) or E.NIL) end,
            tip = Tr["Inside the frame, or beyond one of its ends, running away from it: toward the nearer edge of "
                .. "the screen, or left or right. Buffs and debuffs out on the same side: the debuffs' Next to "
                .. "buffs says where they go. A drag or the arrow keys move it from there, outside still."] },
        -- the debuffs', while both rows are out on one side
        by = { kind = "choice", label = Tr["Next to buffs"], choices = {},
            get = function() return Edits().by or "below" end,
            set = function(v) SetField("by", v ~= "below" and v or E.NIL) end,
            tip = Tr["Where the debuffs go while the buffs are outside on the same side: under them, over them, "
                .. "or beside them."] },
        from = { kind = "choice", label = Tr["From"], choices = E.FROM,
            get = function()
                local b = frame.buttons()[1]
                local row = b and E.PIECES[piece].get(b)
                return Edits().from or row and row.from or "mine"
            end,
            set = function(v) SetField("from", v) end,
            tip = Tr["Whose auras the row shows: only the ones you cast, or all of them."]
                .. (piece == "buffs" and " " .. Tr["An enemy's buffs all show either way."] or "") },
        max = { kind = "slider", label = Tr["Most icons"], min = 1, max = 10,
            get = function() return Edits().max or select(2, E.RowOwn(frame, piece)) end,
            set = function(v) SetField("max", v) end,
            tip = Tr["The most auras the row shows at once."] },
        ph = { kind = "slider", label = Tr["Height"], min = 0, max = 20,
            get = function()
                local b = frame.buttons()[1]
                return ns.PowerHeight(frame.id, b and b.powerDefault or 4)
            end,
            set = function(v) SetField("ph", v) end,
            text = function(v) return v > 0 and tostring(v) or Tr["None"] end,
            tip = Tr["The power bar's height; the health bar takes the rest. None: no power bar, the health the "
                .. "whole frame."] },
        w = { kind = "slider", label = Tr["Width"], min = 60, max = 300,
            get = function() return (ns.CellSize(frame.id)) end,
            set = function(v) SetField("w", v) end,
            tip = Tr["The cell's width. Takes effect out of combat."] },
        h = { kind = "slider", label = Tr["Height"], min = 18, max = 80,
            get = function() return select(2, ns.CellSize(frame.id)) end,
            set = function(v) SetField("h", v) end,
            tip = Tr["The cell's height, the power bar included. Takes effect out of combat."] },
    }
end

-- The piece's tabs, in order: where it goes, how it looks, which auras (a
-- row's). Shown is over them all, never in one. A cell and a bar have one
-- tab each, and no strip.
local TAB_NAMES = { place = Tr["Place"], look = Tr["Look"], auras = Tr["Auras"] }
local function Tabs()
    local kind = E.PIECES[piece].type
    if kind == "cell" then return { { id = "place", fields = { "w", "h" } } } end
    if kind == "bar" then return { { id = "place", fields = { "ph" } } } end
    local place = { "on", "x", "y" }
    local look = { "size" }
    if kind == "text" then
        look[#look + 1] = "outline"
        if E.FORMATS[piece] then look[#look + 1] = "format" end
        if piece == "name" then look[#look + 1] = "len" end
    end
    if kind ~= "row" then
        return { { id = "place", fields = place }, { id = "look", fields = look } }
    end
    local out = Mirrored() and "out" or "side"
    -- the debuffs out with the buffs: a size of the buffs' to take
    local buffs = E.Edits(frame, "buffs")
    if piece == "mine" and Edits().out and buffs and buffs.out then look = { "match", "size" } end
    -- a row outside its frame is placed by that, moved from there: no
    -- anchor, no way to grow
    if Edits().out then
        place = { out, "ox", "oy", "cols" }
        -- the debuffs out on the buffs' side: where, beside them (and moved
        -- with them)
        if piece == "mine" and E.Stacked(frame, frame.buttons()[1]) then place = { out, "by", "ox", "oy", "cols" } end
    else
        place = { out, "on", "x", "y", "grow", "cols" }
    end
    return { { id = "place", fields = place }, { id = "look", fields = look },
        { id = "auras", fields = { "from", "max" } } }
end

-- The chosen tab of the piece's: the one kept, else its first.
local function Tab()
    local all = Tabs()
    for _, t in ipairs(all) do if t.id == tab then return t, all end end
    return all[1], all
end

-- What is laid, as one string; laid: Lay's last.
local function Laid()
    local t, all = Tab()
    return piece .. ":" .. t.id .. "/" .. #all .. ":" .. table.concat(t.fields, ",")
end
local laid

-- The piece's tabs across its card, under the band: one well, as wide as
-- the card, the chosen tab lit with a gold foot (the Settings window's
-- segmented control). A piece with one tab has none.
local function Strip(y)
    local strip = body.tabStrip
    local t, all = Tab()
    for _, b in ipairs(strip.tabs) do b:Hide() end
    strip:SetShown(#all > 1)
    if #all < 2 then return y end
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", body, "TOPLEFT", CARD_PAD, y)
    strip:SetPoint("TOPRIGHT", body, "TOPRIGHT", -CARD_PAD, y)
    local w = math.floor(ROWS_W / #all)
    for i, one in ipairs(all) do
        local b = strip.tabs[i]
        b.id = one.id
        b.text:SetText(TAB_NAMES[one.id])
        b:SetWidth(i < #all and w or ROWS_W - w * (#all - 1))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", strip, "TOPLEFT", w * (i - 1), 0)
        local on = one == t
        b.on = on
        b.lit:SetShown(on)
        b.foot:SetShown(on)
        b.sep:SetShown(i > 1)
        local c = on and C.goldBright or C.dim
        b.text:SetTextColor(c[1], c[2], c[3])
        b:Show()
    end
    return y - PIECE_TAB_H - 8
end

-- The chosen tab's controls, a row each, a hairline between them (Shown is
-- in the card's band). Should a tab ever hold more than the card (none
-- does: the harness measures every one), its rows close up rather than run
-- into Reset piece.
local function Lay()
    laid = Laid()
    local t = Tab()
    window.tab = t.id
    local kind = E.PIECES[piece].type
    local function Down(gap)
        for _, c in pairs(controls) do c:Hide() end
        if kind ~= "cell" and kind ~= "bar" then controls.shown:Show() end
        local y = Strip(-(BAND_H + 10))
        for i, field in ipairs(t.fields) do
            local c = controls[field]
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", body, "TOPLEFT", CARD_PAD, y)
            c.hair:ClearAllPoints()
            c.hair:SetPoint("BOTTOMLEFT", c, "TOPLEFT", -(CARD_PAD - 1), gap / 2)
            c.hair:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", CARD_PAD - 1, gap / 2)
            c.hair:SetShown(i > 1)
            c:Show()
            y = y - c:GetHeight() - gap
        end
        controls.reset:Show()
        return -(y + gap)
    end
    -- (the card's height from the window's sizes: read off the card, it is
    -- 0 until the game first lays it out)
    if Down(GAP) > H - TOP - BOTTOM - BODY_FOOT then Down(1) end
end

-- ------------------------------------------------------------ choosing
local function Choose(id, which)
    frame = E.byId[id] or E.FRAMES[1]
    local ok = false
    for _, p in ipairs(frame.pieces) do if p == which then ok = true end end
    piece = ok and which or frame.pieces[1]
    controls.x.spec.label = Mirrored() and Tr["Inward"] or Tr["Right"]
    controls.x.label:SetText(controls.x.spec.label)
    controls.format.spec.choices = E.FORMATS[piece] or {}
    controls.grow.spec.choices = Mirrored()
        and { { "inner", Tr["Inward"] }, { "outer", Tr["Outward"] }, { "up", Tr["Up"] }, { "down", Tr["Down"] } }
        or { { "inner", Tr["Right"] }, { "outer", Tr["Left"] }, { "up", Tr["Up"] }, { "down", Tr["Down"] } }
    controls.by.spec.choices = Mirrored()
        and { { "below", Tr["Below"] }, { "above", Tr["Above"] }, { "outer", Tr["Outward"] }, { "inner",
            Tr["Inward"] } }
        or { { "below", Tr["Below"] }, { "above", Tr["Above"] }, { "left", Tr["Left"] }, { "right", Tr["Right"] } }
    Lay()
    Refresh()
    if E.onChoose then E.onChoose() end
end

-- What the frame is, whose it is, and where it can be seen.
local NOTES = {
    unit = Tr["The player and the target: one layout, mirrored."],
    party = Tr["The console's party; the left and right wings mirrored."],
    partyWidget = Tr["The party, while Console > Layout > Party layout is Widget."],
    raid = Tr["The Raid widget, and in a battleground too."],
    boss = Tr["The Boss widget, while Console > Layout > Boss frames shows it."],
    arena = Tr["The Arena widget's enemy frames."],
}
-- Whose the frame's places are: the console profile's, or every profile's.
local function Whose()
    local profile = ns.db.consoleProfile
    for _, p in ipairs(ns.PROFILE_NAMES) do if p[1] == profile then profile = p[2] end end
    return ns.PER_PROFILE[frame.key] and format(Tr["Per profile: %s"], profile) or Tr["Shared by every profile"]
end
-- The header's (?): what the frame is, and whose.
local function About() return NOTES[frame.id] .. " " .. Whose() .. "." end
-- Over the canvas: why a frame is not on screen now, else nothing.
local function Scope()
    for _, b in ipairs(frame.buttons()) do if b:IsVisible() then return "" end end
    -- the party is one or the other: the preview cannot show the one its
    -- layout does not use
    local widget = ns.PartyWidgetLayout and ns.PartyWidgetLayout()
    if frame.id == "partyWidget" and not widget then return Tr["Not on screen now: the party layout is Console."] end
    if frame.id == "party" and widget then return Tr["Not on screen now: the party layout is Widget."] end
    return Tr["Not on screen now: Preview, below, shows it."]
end

-- ------------------------------------------------------------ the list
-- The pieces in groups, each under its heading, in the frame's order.
local GROUPS = {
    { name = "Frame", types = { cell = true, bar = true } },
    { name = Tr["Texts"], types = { text = true } },
    { name = Tr["Icons"], types = { icon = true } },
    { name = Tr["Auras"], types = { row = true } },
}

-- The sidebar's i-th line, made the first time it is wanted: a group's
-- heading (its glyph and name, gold: every group is open), or a piece (its
-- name; the chosen one lit, a faint gold fill and a gold bar at the
-- sidebar's edge; a changed one with a gold mark at its right; another
-- lifts under the pointer).
local function List(i)
    local row = list.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row.lift = UI.Fill(row, "BACKGROUND", C.lift, 1)
    row.lift:SetAllPoints()
    row.lift:Hide()
    row.lit = UI.Fill(row, "BACKGROUND", C.lit, 2)
    row.lit:SetAllPoints()
    row.bar = UI.Fill(row, "ARTWORK", C.goldBright)
    row.bar:SetWidth(3)
    row.bar:SetPoint("TOPLEFT", -6, 0)
    row.bar:SetPoint("BOTTOMLEFT", -6, 0)
    row.text = UI.Serif(row, 12, C.dim)
    row.text:SetPoint("LEFT", 20, 0)
    row.glyph = UI.Fill(row, "ARTWORK", C.goldBright)
    row.glyph:SetSize(6, 6)
    row.glyph:SetPoint("LEFT", 9, -3)
    if row.glyph.SetRotation then row.glyph:SetRotation(math.pi / 4) end
    row.head = UI.Plain(row, 10, C.gold)
    row.head:SetPoint("LEFT", 25, -3)
    row.mark = UI.Fill(row, "ARTWORK", C.gold)
    row.mark:SetSize(5, 5)
    row.mark:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnClick", function(self) if self.piece then Choose(frame.id, self.piece) end end)
    row:SetScript("OnEnter", function(self)
        if not self.piece or self.piece == piece then return end
        self.lift:Show()
        self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        UI.Tip(self, E.PIECES[self.piece].label, E.Edits(frame, self.piece) and Tr["Changed: Reset piece puts it back."]
            or Tr["As its frame draws it."])
    end)
    row:SetScript("OnLeave", function(self)
        self.lift:Hide()
        if GameTooltip then GameTooltip:Hide() end
        if not self.piece then return end
        local c = self.piece == piece and C.goldBright or E.Edits(frame, self.piece) and C.text or C.dim
        self.text:SetTextColor(c[1], c[2], c[3])
    end)
    list.rows[i] = row
    return row
end

-- ------------------------------------------------------------ refresh
function Refresh()
    if not window or not window:IsShown() then return end
    -- a row taken outside, or brought in, has other controls
    if laid ~= Laid() then Lay() end
    for _, b in ipairs(tabs) do
        local on = b.frame == frame
        b.foot:SetShown(on)
        local c = on and C.goldBright or C.dim
        b.text:SetTextColor(c[1], c[2], c[3])
    end
    -- the pieces under their group's heading; a group the frame has none
    -- of, no heading
    local i, y = 0, -6
    for _, group in ipairs(GROUPS) do
        local ids = {}
        for _, id in ipairs(frame.pieces) do
            if group.types[E.PIECES[id].type] then ids[#ids + 1] = id end
        end
        if #ids > 0 then
            i = i + 1
            local head = List(i)
            head.piece = nil
            head.heading = group.name
            head:EnableMouse(false)
            head:SetHeight(CAT_H)
            head.lit:Hide()
            head.bar:Hide()
            head.lift:Hide()
            head.mark:Hide()
            head.text:Hide()
            head.head:SetText(ns.Upper(group.name))
            head.head:Show()
            head.glyph:Show()
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 0, y)
            head:SetPoint("TOPRIGHT", 0, y)
            head:Show()
            y = y - CAT_H
            for _, id in ipairs(ids) do
                i = i + 1
                local row = List(i)
                row.piece = id
                row.heading = nil
                row:EnableMouse(true)
                row:SetHeight(ITEM_H)
                row.head:Hide()
                row.glyph:Hide()
                row.text:SetText(E.PIECES[id].label)
                row.text:Show()
                local on = id == piece
                row.lit:SetShown(on)
                row.bar:SetShown(on)
                local edited = E.Edits(frame, id) ~= nil
                local c = on and C.goldBright or (edited or row.lift:IsShown()) and C.text or C.dim
                row.text:SetTextColor(c[1], c[2], c[3])
                row.mark:SetShown(edited)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 6, y)
                row:SetPoint("TOPRIGHT", -6, y)
                row:Show()
                y = y - ITEM_H
            end
            y = y - 4
        end
    end
    for k = i + 1, #list.rows do list.rows[k]:Hide() end
    -- the header: the frame, the console's or the widgets' and whose
    window.pageTitle:SetText(frame.name)
    window.crumb:SetText((ns.PER_PROFILE[frame.key] and Tr["Console"] or Tr["Widgets"]) .. "   \194\183   " .. Whose())
    window.more.tip = About()
    -- the canvas's card: the frame; the piece's: its name, Changed
    window.canvasCard.title:SetText(frame.name)
    body.title:SetText(E.PIECES[piece].label)
    body.changed:SetShown(E.Edits(frame, piece) ~= nil)
    for field, c in pairs(controls) do
        if c:IsShown() and c.Refresh then
            -- a hidden piece's other fields stay set, but wait
            local kind = E.PIECES[piece].type
            local enabled = field == "shown" or field == "reset" or kind == "cell" or kind == "bar"
                or controls.shown.spec.get() ~= false
            if field == "reset" then enabled = E.Edits(frame, piece) ~= nil end
            -- the debuffs' size, while it is the buffs'
            if field == "size" and piece == "mine" and E.Matched(frame) then enabled = false end
            c:Refresh(enabled)
        end
    end
    window.preview:Refresh(true)
    for _, b in ipairs(chips) do
        local on = E.preview[b.id] and true or false
        b.on = on
        b.lit:SetShown(on)
        b.foot:SetShown(on)
        local c = on and C.goldBright or b.lift:IsShown() and C.text or C.dim
        b.text:SetTextColor(c[1], c[2], c[3])
        if b.swatch then
            local key = b.id == "threat" and "threatColor" or ("dispelColor" .. b.id)
            b.swatch:SetColorTexture(ns.HexColor(ns.db[key]))
        end
    end
end

-- ------------------------------------------------------------ the keys
-- The arrow keys nudge the chosen piece; the other keys go on to the game
-- (not in combat: the game forbids passing them on, so a fight hands them
-- all back).
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local function Key(self, key)
    local step = ARROWS[key]
    local kind = E.PIECES[piece].type
    local move = step and kind ~= "cell" and kind ~= "bar"
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not move) end
    if not move then return end
    -- a row outside: moved from its place there, outside still
    if Out() then
        local e = Edits()
        return SetOut((e.ox or 0) + OutWay() * step[1], (e.oy or 0) + step[2])
    end
    local b = frame.buttons()[1]
    local side = Mirrored() and b and E.Side(b, frame) or -1
    SetPlace({ x = (PlaceField("x") or 0) - side * step[1], y = (PlaceField("y") or 0) + step[2] })
end

local function Keys(on)
    if not window then return end
    window:EnableKeyboard(on)
    if on and not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end
ns.On("PLAYER_REGEN_DISABLED", function() Keys(false) end)
ns.On("PLAYER_REGEN_ENABLED", function() if window and window:IsShown() then Keys(true) end end)

-- ------------------------------------------------------------ the chips
-- The canvas's previews (E.PREVIEWS) under it, in two wells as the
-- Settings window's segmented control, each name at its left: Glow, the
-- dispel types' (one at a time), each with its colour's swatch; Show, the
-- rest, the aggro's with its swatch. A chip on is lit with a gold foot.
local DISPEL = {}
for _, p in ipairs(E.PREVIEWS) do if p.dispel then DISPEL[p[1]] = true end end

local function ChipTip(p)
    if p.dispel then
        return format(Tr["A %s debuff's glow on the canvas, in its colour (Unit Frames > General > Glows). "
            .. "One type at a time."], p[2])
    end
    if p[1] == "threat" then return Tr["The aggro glow on the canvas, and the console's tint red."] end
    if p[1] == "combat" then return Tr["The console's combat tint, on screen."] end
    return Tr["Shown on the canvas, as in play."]
end

local function Chips(parent, name, dispel)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(UI.SEG_H)
    holder.name = UI.Plain(holder, 11, C.faint)
    holder.name:SetPoint("LEFT", 0, 0)
    holder.name:SetText(name)
    local box = CreateFrame("Frame", nil, holder)
    box:SetHeight(UI.SEG_H)
    box:SetPoint("LEFT", 44, 0)
    UI.Fill(box, "BACKGROUND", C.well, 1):SetAllPoints()
    UI.Outline(box, "BORDER", C.lineStrong, 0)
    local x, first = 0, true
    for _, p in ipairs(E.PREVIEWS) do
        if (p.dispel and true or false) == dispel then
            local swatch = p.dispel or p[1] == "threat"
            local b = CreateFrame("Button", nil, box)
            b:SetSize(math.max(UI.SEG_MIN, UI.TextWidth(p[2]) + UI.SEG_PAD + (swatch and 11 or 0)), UI.SEG_H)
            b:SetPoint("TOPLEFT", x, 0)
            b.id = p[1]
            b.lit = UI.Fill(b, "ARTWORK", C.lit, 1)
            b.lit:SetPoint("TOPLEFT", 1, -1)
            b.lit:SetPoint("BOTTOMRIGHT", -1, 1)
            b.lift = UI.Fill(b, "ARTWORK", C.lift, 0)
            b.lift:SetPoint("TOPLEFT", 1, -1)
            b.lift:SetPoint("BOTTOMRIGHT", -1, 1)
            b.lift:Hide()
            b.foot = UI.Fill(b, "ARTWORK", C.goldBright, 2)
            b.foot:SetHeight(2)
            b.foot:SetPoint("BOTTOMLEFT", 1, 1)
            b.foot:SetPoint("BOTTOMRIGHT", -1, 1)
            if not first then
                local sep = UI.Fill(b, "ARTWORK", C.line, 3)
                sep:SetWidth(1)
                sep:SetPoint("TOPLEFT", 0, -1)
                sep:SetPoint("BOTTOMLEFT", 0, 1)
            end
            b.text = UI.Plain(b, 12, C.dim)
            b.text:SetText(p[2])
            if swatch then
                b.swatch = UI.Fill(b, "ARTWORK", C.gold, 4)
                b.swatch:SetSize(6, 6)
                b.swatch:SetPoint("LEFT", 9, 0)
                b.text:SetPoint("LEFT", b.swatch, "RIGHT", 5, 0)
            else
                b.text:SetPoint("CENTER", 0, 0)
            end
            b:SetScript("OnClick", function(self)
                E.TogglePreview(self.id)
                Refresh()
            end)
            b:SetScript("OnEnter", function(self)
                if not self.on then
                    self.lift:Show()
                    self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
                end
                UI.Tip(self, p[2], ChipTip(p))
            end)
            b:SetScript("OnLeave", function(self)
                self.lift:Hide()
                local c = self.on and C.goldBright or C.dim
                self.text:SetTextColor(c[1], c[2], c[3])
                if GameTooltip then GameTooltip:Hide() end
            end)
            chips[#chips + 1] = b
            x, first = x + b:GetWidth(), false
        end
    end
    box:SetWidth(x)
    holder:SetWidth(44 + x)
    return holder
end

-- ------------------------------------------------------------ the window
local function Remember()
    local point, _, relative, x, y = window:GetPoint()
    ns.SetOption("editorPoint", { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) })
end

local function Grip(f)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() window:StartMoving() end)
    f:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        if window.SetUserPlaced then window:SetUserPlaced(false) end
        Remember()
    end)
end

-- A bar of the window's chrome (its head or its footer), a hairline on its
-- inner edge.
local function Bar(top)
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", EDGE, top and -EDGE or EDGE)
    bar:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", -EDGE, top and -EDGE or EDGE)
    bar:SetHeight(top and BAR_H or FOOT)
    bar:SetFrameLevel(window:GetFrameLevel() + 5)
    UI.Fill(bar, "BACKGROUND", C.chrome, 1):SetAllPoints()
    local rule = UI.Fill(bar, "BORDER", C.line)
    rule:SetHeight(1)
    rule:SetPoint(top and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
    rule:SetPoint(top and "BOTTOMRIGHT" or "TOPRIGHT", 0, 0)
    return bar
end

-- The head: the window's name, Medalluin and the version; the x in its own
-- cell, red under the pointer. All of it drags the window.
local function Head()
    local bar = Bar(true)
    Grip(bar)
    local text = UI.Serif(bar, 15, C.goldBright)
    text:SetPoint("LEFT", 14, 0)
    text:SetText(Tr["Unit Frame Editor"])
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = get and get("Medalluin", "Version")
    local sub = UI.Plain(bar, 11, C.faint)
    sub:SetPoint("LEFT", text, "RIGHT", 10, -1)
    sub:SetText("Medalluin" .. (version and ("  \194\183  " .. version) or ""))
    window.title, window.version = text, sub
    local x = CreateFrame("Button", nil, bar)
    x:SetSize(BAR_H, BAR_H - 1)
    x:SetPoint("TOPRIGHT", 0, 0)
    x.lit = UI.Fill(x, "BACKGROUND", C.red, 1)
    x.lit:SetAllPoints()
    x.lit:Hide()
    local seam = UI.Fill(x, "BORDER", C.line)
    seam:SetWidth(1)
    seam:SetPoint("TOPLEFT", 0, 0)
    seam:SetPoint("BOTTOMLEFT", 0, 0)
    x.glyph = x:CreateTexture(nil, "ARTWORK")
    x.glyph:SetTexture(ns.media .. "strips\\close")
    x.glyph:SetSize(14, 14)
    x.glyph:SetPoint("CENTER", 0, 0)
    x.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    x:SetScript("OnClick", function() window:Hide() end)
    x:SetScript("OnEnter", function(self)
        self.lit:Show()
        self.glyph:SetVertexColor(0.949, 0.847, 0.784, 1)
    end)
    x:SetScript("OnLeave", function(self)
        self.lit:Hide()
        self.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    end)
    window.closeX = x
end

-- The sidebar: the chosen frame's pieces (Refresh lays them).
local function Sidebar()
    local side = CreateFrame("Frame", nil, window)
    side:SetPoint("TOPLEFT", EDGE, -(EDGE + BAR_H))
    side:SetPoint("BOTTOMLEFT", EDGE, EDGE + FOOT)
    side:SetWidth(SIDE_W)
    UI.Fill(side, "BACKGROUND", C.chrome, 1):SetAllPoints()
    local rule = UI.Fill(side, "BORDER", C.line)
    rule:SetWidth(1)
    rule:SetPoint("TOPRIGHT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    list = CreateFrame("Frame", nil, side)
    list:SetPoint("TOPLEFT", 0, -4)
    list:SetPoint("BOTTOMRIGHT", -1, 4)
    list.rows = {}
    window.side = side
end

-- The page's header: the frame's name, the console's or the widgets' and
-- whose, a (?) saying what the frame is; the frames as its sheets along its
-- foot, the console's, then (a gap) the widgets'; a hairline under.
local function Header()
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT", window, "TOPLEFT", X, -HEAD_TOP)
    head:SetPoint("TOPRIGHT", window, "TOPRIGHT", -RIGHT, -HEAD_TOP)
    head:SetHeight(HEAD_H + STRIP_H - 4)
    window.head = head
    window.pageTitle = UI.Serif(head, 20, C.text)
    window.pageTitle:SetPoint("TOPLEFT", 0, -2)
    window.crumb = UI.Plain(head, 12, C.faint)
    window.crumb:SetPoint("TOPLEFT", 0, -28)
    local q = CreateFrame("Button", nil, head)
    q:SetSize(22, 16)
    q:SetPoint("LEFT", window.crumb, "RIGHT", 6, 0)
    q.text = UI.Plain(q, 12, C.gold)
    q.text:SetPoint("CENTER", 0, 0)
    q.text:SetText("(?)")
    q:SetScript("OnEnter", function(self)
        self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3])
        UI.Tip(self, window.pageTitle:GetText(), self.tip)
    end)
    q:SetScript("OnLeave", function(self)
        self.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    window.more = q
    local rule = UI.Fill(head, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    tabs = {}
    local left, group = 0, nil
    for i, f in ipairs(E.FRAMES) do
        local console = ns.PER_PROFILE[f.key] and true or false
        if group ~= nil and console ~= group then left = left + 16 end
        group = console
        local b = CreateFrame("Button", nil, head)
        b:SetHeight(STRIP_H)
        b.lift = UI.Fill(b, "BACKGROUND", C.lift, 1)
        b.lift:SetAllPoints()
        b.lift:Hide()
        b.text = UI.Serif(b, 13, C.dim)
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(f.name)
        b:SetWidth(math.ceil(b.text:GetStringWidth()) + 28)
        b.foot = UI.Fill(b, "OVERLAY", C.goldBright)
        b.foot:SetHeight(2)
        b.foot:SetPoint("BOTTOMLEFT", 8, 0)
        b.foot:SetPoint("BOTTOMRIGHT", -8, 0)
        b:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", left, 1)
        left = left + b:GetWidth() + 2
        b.frame, b.console = f, console
        b:SetScript("OnClick", function(self) Choose(self.frame.id, piece) end)
        b:SetScript("OnEnter", function(self)
            if self.frame ~= frame then
                self.lift:Show()
                self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
            end
            UI.Tip(self, self.frame.name, NOTES[self.frame.id] .. (self.console and Tr[" Per profile."]
                or Tr[" Shared by every profile."]))
        end)
        b:SetScript("OnLeave", function(self)
            self.lift:Hide()
            local c = self.frame == frame and C.goldBright or C.dim
            self.text:SetTextColor(c[1], c[2], c[3])
            if GameTooltip then GameTooltip:Hide() end
        end)
        tabs[i] = b
    end
    -- what the gap between them means, at their right
    window.groups = UI.Plain(head, 11, C.faint)
    window.groups:SetPoint("BOTTOMRIGHT", 0, 7)
    window.groups:SetText(Tr["Console: per profile  \194\183  Widgets: shared"])
end

-- A card: a step lighter than the page, its title in a band across its
-- top, a hairline under the band.
local function Card(x, width, title)
    local card = CreateFrame("Frame", nil, window)
    card:SetPoint("TOPLEFT", window, "TOPLEFT", x, -TOP)
    card:SetSize(width, H - TOP - BOTTOM)
    UI.Fill(card, "BACKGROUND", C.raised, 1):SetAllPoints()
    UI.Outline(card, "BORDER", C.line, 0)
    local rule = UI.Fill(card, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 1, -BAND_H)
    rule:SetPoint("TOPRIGHT", -1, -BAND_H)
    card.title = UI.Serif(card, 14, C.text)
    card.title:SetPoint("LEFT", card, "TOPLEFT", CARD_PAD, -BAND_H / 2)
    card.title:SetText(title or "")
    return card
end

-- A chip after a card's title: small, gold-edged.
local function Chip(card, text)
    local chip = CreateFrame("Frame", nil, card)
    chip:SetHeight(14)
    chip:SetPoint("LEFT", card.title, "RIGHT", 8, 0)
    UI.Outline(chip, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.45 }, 0)
    chip.text = UI.Plain(chip, 10, C.gold)
    chip.text:SetPoint("CENTER", 0, 0)
    function chip:SetText(t)
        self.text:SetText(t or "")
        self:SetWidth(math.ceil(self.text:GetStringWidth() or 0) + 10)
    end
    chip:SetText(text)
    return chip
end

-- The canvas's card: the frame's name, the zoom, Fit and Reset frame in
-- its band; the canvas in a well; the previews under it.
local function CanvasCard()
    local card = Card(X, CANVAS_W)
    window.canvasCard = card
    local height = H - TOP - BOTTOM
    stage = ns.EditorStage(card)
    stage:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -(BAND_H + 10))
    stage:SetSize(CANVAS_W - 2 * CARD_PAD, height - BAND_H - 10 - 2 * (UI.SEG_H + 10) - 10)
    stage.zoom = Chip(card, "100%")
    local reset = UI.Button(card, Tr["Reset frame"], 86, 22, function() E.ResetFrame(frame) end,
        Tr["Every piece of this frame back to how it draws it."], "quiet")
    reset:SetPoint("RIGHT", card, "TOPRIGHT", -8, -BAND_H / 2)
    window.reset = reset
    local fit = UI.Button(card, Tr["Fit"], 40, 22, function() if stage.Fit then stage.Fit() end end,
        Tr["The whole frame in view again, at the size that fits (or double-click the canvas)."], "quiet")
    fit:SetPoint("RIGHT", reset, "LEFT", -2, 0)
    window.fit = fit
    chips = {}
    local glow = Chips(card, Tr["Glow"], true)
    glow:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -10)
    local show = Chips(card, Tr["Show"], false)
    show:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 0, -10)
    window.glowChips, window.showChips = glow, show
end

-- The piece's card: its name, Changed and Shown in its band; its tabs, its
-- rows (Lay); Reset piece at its foot.
local function PieceCard()
    body = Card(X + CANVAS_W + COL_GAP, BODY_W)
    body.changed = Chip(body, Tr["Changed"])
    local strip = CreateFrame("Frame", nil, body)
    strip:SetHeight(PIECE_TAB_H)
    UI.Fill(strip, "BACKGROUND", C.well, 1):SetAllPoints()
    UI.Outline(strip, "BORDER", C.lineStrong, 0)
    strip.tabs = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, strip)
        b:SetHeight(PIECE_TAB_H)
        b.lit = UI.Fill(b, "ARTWORK", C.lit, 1)
        b.lit:SetPoint("TOPLEFT", 1, -1)
        b.lit:SetPoint("BOTTOMRIGHT", -1, 1)
        b.lift = UI.Fill(b, "ARTWORK", C.lift, 0)
        b.lift:SetPoint("TOPLEFT", 1, -1)
        b.lift:SetPoint("BOTTOMRIGHT", -1, 1)
        b.lift:Hide()
        b.foot = UI.Fill(b, "ARTWORK", C.goldBright, 2)
        b.foot:SetHeight(2)
        b.foot:SetPoint("BOTTOMLEFT", 1, 1)
        b.foot:SetPoint("BOTTOMRIGHT", -1, 1)
        b.sep = UI.Fill(b, "ARTWORK", C.line, 3)
        b.sep:SetWidth(1)
        b.sep:SetPoint("TOPLEFT", 0, -1)
        b.sep:SetPoint("BOTTOMLEFT", 0, 1)
        b.text = UI.Plain(b, 12, C.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b:SetScript("OnClick", function(self)
            tab = self.id
            Lay()
            Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            if self.on then return end
            self.lift:Show()
            self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        end)
        b:SetScript("OnLeave", function(self)
            self.lift:Hide()
            local c = self.on and C.goldBright or C.dim
            self.text:SetTextColor(c[1], c[2], c[3])
        end)
        b:Hide()
        strip.tabs[i] = b
    end
    body.tabStrip = strip
    -- the foot: a hairline over it, a word on when changes apply, Reset piece
    local rule = UI.Fill(body, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 1, BODY_FOOT)
    rule:SetPoint("BOTTOMRIGHT", -1, BODY_FOOT)
    body.applied = UI.Plain(body, 11, C.faint)
    body.applied:SetPoint("BOTTOMLEFT", CARD_PAD, 16)
    body.applied:SetText(Tr["Applied as you change it"])
end

-- The footer: the preview (a party, a raid, bosses and an arena to edit
-- out of a group) at its left, Close at its right.
local function Footer()
    local bar = Bar(false)
    window.foot = bar
    local spec = { kind = "check", key = "simParty", label = Tr["Preview"],
        tip = Tr["Simulated party, raid, bosses and arena enemies to edit out of a group; their panel sets what "
            .. "they show."] }
    local preview = UI.Switch(bar, spec)
    preview:SetPoint("LEFT", 14, 0)
    preview.text = UI.Plain(bar, 12, C.text)
    preview.text:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    preview.text:SetText(Tr["Preview"])
    preview.line = UI.Plain(bar, 11, C.faint)
    preview.line:SetPoint("LEFT", preview.text, "RIGHT", 10, 0)
    preview.line:SetText(Tr["A party, a raid, bosses and an arena to edit out of a group"])
    window.preview = preview
    local close = UI.Button(bar, Tr["Close"], 64, 26, function() window:Hide() end, nil, "quiet")
    close:SetPoint("RIGHT", -8, 0)
    window.close = close
end

local function Window()
    if window then return end
    window = CreateFrame("Frame", "MedalluinEditor", UIParent)
    window:SetSize(W, H)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    Grip(window)
    local at = ns.db.editorPoint
    if at then
        window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
    -- the page's tone; a hairline edge, a faint gold ring outside it
    UI.Fill(window, "BACKGROUND", C.page, 1):SetAllPoints()
    UI.Outline(window, "BORDER", C.lineStrong, 0)
    UI.Outline(window, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.35 }, -1)
    window:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalluinEditor") end
    window:SetScript("OnShow", function()
        Keys(true)
        Refresh()
    end)
    window:SetScript("OnHide", function()
        UI.CloseMenu()
        Keys(false)
        E.ClearPreview()
    end)
    window:SetScript("OnKeyDown", Key)

    Head()
    Sidebar()
    Header()
    CanvasCard()
    PieceCard()
    Footer()

    -- the piece's controls: Shown a switch in the card's band; the rest a
    -- row each (the Settings window's rows), a hairline over each but the first
    local specs = Specs()
    for field, spec in pairs(specs) do
        if type(spec.tip) == "function" then
            local fn = spec.tip
            spec.tip = nil
            spec.tipFn = fn
        end
        local c
        if field == "shown" then
            c = UI.Switch(body, spec, Tr["Shown"])
            c:SetPoint("RIGHT", body, "TOPRIGHT", -CARD_PAD, -BAND_H / 2)
        elseif spec.kind == "check" then
            c = UI.Check(body, spec, ROWS_W, true)
        elseif spec.kind == "choice" then
            c = UI.Choice(body, spec, ROWS_W, true)
        else
            c = UI.Slider(body, spec, ROWS_W, true)
        end
        if field ~= "shown" then
            c.hair = c:CreateTexture(nil, "BACKGROUND")
            UI.Paint(c.hair, C.line)
            c.hair:SetHeight(1)
        end
        controls[field] = c
    end
    controls.reset = UI.Button(body, Tr["Reset piece"], 96, 24, function() E.ResetPiece(frame, piece) end,
        Tr["This piece back to how its frame draws it."])
    controls.reset:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -CARD_PAD, 10)

    -- its parts, by name (the harness reads them)
    window.tabs, window.list, window.body, window.controls = tabs, list, body, controls
    window.stage, window.chips = stage, chips
    Choose(E.FRAMES[1].id)
end

-- The Shown tip says which option it is; set as the pointer comes.
local function TipShown()
    local c = controls.shown
    if not c then return end
    c:SetScript("OnEnter", function(self) UI.Tip(self, Tr["Shown"], c.spec.tipFn()) end)
end

-- ------------------------------------------------------------ open
-- ns.OpenEditor(id): the window, on that frame ("party", "raid", ...), or
-- its first tab (player and target).
function ns.OpenEditor(id)
    Window()
    TipShown()
    id = id or E.FRAMES[1].id
    Choose(id, piece)
    window:Show()
    window:Raise()
end

-- The window's frames, made without showing it (the harness's way in).
function ns.BuildEditor()
    Window()
    TipShown()
end

ns.OnAnySetting(function()
    if not window or not window:IsShown() then return end
    Refresh()
end)

-- What the canvas shares: the choice, and the place a drag or a key writes.
E.ui = {
    Choose = function(id, which) Choose(id, which) end,
    Chosen = function() return frame, piece end,
    PlaceField = PlaceField,
    SetPlace = SetPlace,
    -- a row outside: its ox and oy, set; the way outward from a button
    Out = function() return Out() end,
    OutField = function(field) return Edits()[field] or 0 end,
    SetOut = SetOut,
    OutWay = OutWay,
    Mirrored = function() return Mirrored() end,
    Window = function() return window end,
    -- why the frame is not on screen now, over the canvas ("" while it is)
    Scope = function() return frame and Scope() or "" end,
    Refresh = function() Refresh() end,
}
