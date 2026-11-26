-- Blizzard's own windows in MedalUI's look: the pieces the Cooldown
-- Manager (cooldowns/window.lua) and Click Casting (spells/clickcast.lua)
-- share. Each dresses a game window that keeps every click, menu and save
-- its own: its art hidden with alpha (or hidden outright where it is art),
-- ours drawn beside it and kept in one side table by frame (deco), never
-- as fields on the game's frames.
--
--   R.Bare(f)                every texture of f put away, once
--   R.Box(f, fill)           an ink well and a gold edge (four lines) on f
--   R.Edge(d, color)         that edge's colour
--   R.Glyph(f, name, size)   a gold strip glyph at f's centre
--   R.Font(fs, size, color)  our font, shadowed
--   R.Lit(f)                 its box's edge (and glyph) lit under the mouse
--   R.Plain(b)               a button's own states' art put away
--   R.Medal(owner, icon, inset, layer)    an icon round in a gold rim
--   R.Shade(t, top, bottom)  a vertical shade, top's colour to bottom's
--   R.Engrave(f)             the chamfered engraved frame (the zone tray's)
--   R.Inside(f, draw, sub)   a texture inside that frame's chamfer
--   R.Slot(f)                a tab's engraved slot; R.Under, R.Held, R.Recess
--   R.Plate(f), R.Lift(f, on)  a raised plate (the macro cards'), held or not
--   R.Chrome(f, title, rules, hairAt)     the frame's art gone, ours under it
--   R.Place(f)               where the LFG window stands, and kept there
--   R.Stand(f, who, shown)   the spot's rules (one window there at a time)
--   R.Dropdown(button)       its menu (the game's shared one) dressed while open
local _, ns = ...

local R = {}
ns.reskin = R

local L = ns.stripLayout
local WIDTH = L.chatLeft + L.chatWidth
local PAD = 12
local ROW = 28                      -- the cells' height, as the chat's tabs (strips/chat.lua)
local GOLD = ns.gold.light
local GOLD_D = ns.gold.dark
local DIM = { 0.55, 0.52, 0.45 }
local ROUND = ns.media .. "strips\\round"
local GLYPHS = ns.media .. "strips\\"

R.PAD, R.ROW, R.GAP, R.EDGE = PAD, ROW, 4, 3
R.GOLD, R.GOLD_D, R.DIM, R.ROUND, R.GLYPHS = GOLD, GOLD_D, DIM, ROUND, GLYPHS

local deco = {}         -- our dress, by the game's frame
R.deco = deco

-- ---------------------------------------------------------------- pieces
function R.Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], 0))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.5)
    end
end

-- Every texture of a frame put away (its art), fonts kept: once, as first
-- met, so ours drawn on it after stay
function R.Bare(f)
    if not f or not f.GetRegions then return end
    local d = deco[f] or {}
    deco[f] = d
    if d.bare then return end
    d.bare = true
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
end

-- A box in the windows' face: an ink well, a gold edge, drawn on the frame
-- under its own (hidden) art
-- (its edge four lines, so a see-through well shows the world, not gold);
-- fill: the well's opacity, 0.92 unless given
function R.Edge(d, c)
    for _, t in ipairs(d.edges) do t:SetColorTexture(c[1], c[2], c[3], 1) end
end

function R.Box(f, fill)
    local d = deco[f] or {}
    deco[f] = d
    if d.box then return d end
    d.box = true
    d.edges = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[1]:sub(1, 3) == side[2]:sub(1, 3) then t:SetHeight(1) else t:SetWidth(1) end
        table.insert(d.edges, t)
    end
    R.Edge(d, GOLD_D)
    local well = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    local ink = ns.colors.ink
    well:SetColorTexture(ink[1], ink[2], ink[3], fill or 0.92)
    d.well = well
    return d
end

function R.Glyph(f, name, size)
    local d = deco[f] or {}
    deco[f] = d
    if not d.glyph then
        d.glyph = f:CreateTexture(nil, "OVERLAY")
        d.glyph:SetPoint("CENTER")
    end
    d.glyph:SetTexture(GLYPHS .. name)
    d.glyph:SetSize(size, size)
    d.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    return d.glyph
end

function R.Font(fs, size, color)
    if not fs then return end
    fs:SetFont(ns.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- Its controls' box faces: the edge lit under the mouse
function R.Lit(f)
    local d = deco[f]
    if not d or d.lit then return end
    d.lit = true
    f:HookScript("OnEnter", function()
        R.Edge(d, GOLD)
        if d.glyph then d.glyph:SetVertexColor(1, 1, 1) end
    end)
    f:HookScript("OnLeave", function()
        R.Edge(d, GOLD_D)
        if d.glyph then
            local on = not f.IsEnabled or f:IsEnabled()
            local c = on and GOLD or DIM
            d.glyph:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
        end
    end)
end

-- A vertical shade on a texture: top's colour to bottom's ({ r, g, b, a })
function R.Shade(t, top, bottom)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1))
    else
        t:SetColorTexture((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2,
            ((top[4] or 1) + (bottom[4] or 1)) / 2)
    end
end

-- The chamfered engraved frame round a slot or a button (the zone tray's,
-- strips/zonecontrols.lua; the macros' tray): its dark line on the
-- outermost pixels, a faint gold lip a row under. The texture's own 32
-- rows hang from the top (the frame's 27, then clear), so f is 26 or 27
-- tall. f.frame holds its three slices.
local FRAME_TEX, FRAME_END = 64, 8      -- tray-frame: 64x32, the ends sliced 8 wide
R.ENGRAVED_IN = 2                       -- a face inside the frame's chamfer
function R.Engrave(f)
    f.frame = {}
    local cut = FRAME_TEX - FRAME_END
    for k, u in ipairs({ { 0, FRAME_END }, { FRAME_END, cut }, { cut, FRAME_TEX } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetTexture(ns.media .. "strips\\tray-frame")
        t:SetTexCoord(u[1] / FRAME_TEX, u[2] / FRAME_TEX, 0, 1)
        t:SetHeight(FRAME_TEX / 2)
        f.frame[k] = t
    end
    f.frame[1]:SetWidth(FRAME_END)
    f.frame[3]:SetWidth(FRAME_END)
    f.frame[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.frame[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.frame[2]:SetPoint("TOPLEFT", f.frame[1], "TOPRIGHT")
    f.frame[2]:SetPoint("TOPRIGHT", f.frame[3], "TOPLEFT")
end

-- a texture inside an engraved frame's chamfer
function R.Inside(f, draw, sub)
    local t = f:CreateTexture(nil, draw, nil, sub)
    t:SetPoint("TOPLEFT", R.ENGRAVED_IN, -R.ENGRAVED_IN)
    t:SetPoint("BOTTOMRIGHT", -R.ENGRAVED_IN, R.ENGRAVED_IN)
    return t
end

-- ------------------------------------------------------------ the slots
-- (2026-11-25, the user's pick A of /workspace/tabs-mock-sheet.png) a
-- window's tabs, under its head and in its foot band, as engraved slots
-- in a sunk tray: each a chamfered frame of any height (a nine-slice of
-- strips\slot-frame, its corners 8), its lip gold_d, gold when held; held,
-- its face a gold shade and a gold underline under its words, bright at
-- the middle and fading out at both ends.
--
--   R.Slot(f)                  the slot on f; returns the hover glow.
--                              f.slotHeld is the held face (a button's mark)
--   R.Under(f, width, cx, foot) the held underline's span
--   R.Held(f, on)              held or not
--   R.Recess(f)                the sunk tray behind a row of them, in a
--                              gold edge (the panel the slots fit in)
local SLOT_TEX, SLOT_END = 32, 8
local SLOT_FACE = { 0.102, 0.094, 0.078 }
function R.Slot(f)
    f.slot = {}
    local E = SLOT_END
    local cuts = { { 0, E }, { E, SLOT_TEX - E }, { SLOT_TEX - E, SLOT_TEX } }
    -- each piece's two corners on f (the middle, clear, not drawn)
    local at = {
        { { "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", "TOPLEFT", E, -E } },
        { { "TOPLEFT", E, 0 }, { "BOTTOMRIGHT", "TOPRIGHT", -E, -E } },
        { { "TOPRIGHT", 0, 0 }, { "BOTTOMLEFT", "TOPRIGHT", -E, -E } },
        { { "TOPLEFT", 0, -E }, { "BOTTOMRIGHT", "BOTTOMLEFT", E, E } },
        false,
        { { "TOPRIGHT", 0, -E }, { "BOTTOMLEFT", "BOTTOMRIGHT", -E, E } },
        { { "BOTTOMLEFT", 0, 0 }, { "TOPRIGHT", "BOTTOMLEFT", E, E } },
        { { "BOTTOMLEFT", E, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", -E, E } },
        { { "BOTTOMRIGHT", 0, 0 }, { "TOPLEFT", "BOTTOMRIGHT", -E, E } },
    }
    for r = 1, 3 do
        for c = 1, 3 do
            local p = at[(r - 1) * 3 + c]
            if p then
                local t = f:CreateTexture(nil, "BORDER")
                t:SetTexture(ns.media .. "strips\\slot-frame")
                t:SetTexCoord(cuts[c][1] / SLOT_TEX, cuts[c][2] / SLOT_TEX, cuts[r][1] / SLOT_TEX,
                    cuts[r][2] / SLOT_TEX)
                t:SetPoint(p[1][1], f, p[1][1], p[1][2], p[1][3])
                t:SetPoint(p[2][1], f, p[2][2], p[2][3], p[2][4])
                table.insert(f.slot, t)
            end
        end
    end
    local face = R.Inside(f, "BACKGROUND", 2)
    face:SetColorTexture(SLOT_FACE[1], SLOT_FACE[2], SLOT_FACE[3], 1)
    f.slotHeld = R.Inside(f, "BACKGROUND", 3)
    R.Shade(f.slotHeld, { GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.42 }, { GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.2 })
    f.slotHeld:Hide()
    f.slotUnder = {}
    for k = 1, 2 do
        local half = f:CreateTexture(nil, "ARTWORK")
        half:SetHeight(2)
        if half.SetGradient and CreateColor then
            half:SetColorTexture(1, 1, 1, 1)
            local lo, hi = CreateColor(GOLD[1], GOLD[2], GOLD[3], 0), CreateColor(GOLD[1], GOLD[2], GOLD[3], 1)
            half:SetGradient("HORIZONTAL", k == 1 and lo or hi, k == 1 and hi or lo)
        else
            half:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.6)
        end
        half:Hide()
        f.slotUnder[k] = half
    end
    R.Under(f)
    local glow = R.Inside(f, "HIGHLIGHT")
    glow:SetColorTexture(1, 1, 1, 0.06)
    R.Held(f, false)
    return glow
end

-- the held underline: as wide as the words (width) and 14 past each end,
-- its middle cx right of f's (0), foot above f's bottom (5); no width:
-- across f but 10 at each end
function R.Under(f, width, cx, foot)
    local l, r = f.slotUnder[1], f.slotUnder[2]
    cx, foot = cx or 0, foot or 5
    l:ClearAllPoints()
    r:ClearAllPoints()
    l:SetPoint("BOTTOMRIGHT", f, "BOTTOM", cx, foot)
    r:SetPoint("BOTTOMLEFT", f, "BOTTOM", cx, foot)
    if width then
        l:SetWidth(width / 2 + 14)
        r:SetWidth(width / 2 + 14)
    else
        l:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, foot)
        r:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, foot)
    end
end

function R.Held(f, on)
    on = on and true or false
    f.slotOn = on
    local c = on and GOLD or GOLD_D
    for _, t in ipairs(f.slot) do t:SetVertexColor(c[1], c[2], c[3]) end
    f.slotHeld:SetShown(on)
    for _, t in ipairs(f.slotUnder) do t:SetShown(on) end
end

function R.Recess(f)
    if f.recess then return f.recess end
    local floor = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    floor:SetAllPoints()
    floor:SetColorTexture(0.04, 0.035, 0.03, 0.85)
    local sink = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    sink:SetPoint("TOPLEFT")
    sink:SetPoint("TOPRIGHT")
    sink:SetHeight(8)
    R.Shade(sink, { 0, 0, 0, 0.6 }, { 0, 0, 0, 0 })
    f.recess = { floor, sink }
    -- (2026-11-25, the user's: fit into the gold panel) the gold edge the
    -- joined buttons drew round the row, kept round the tray: the slots
    -- stand inside it
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -5)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[1] == "TOPLEFT" and side[2] == "TOPRIGHT" or side[1] == "BOTTOMLEFT" then
            t:SetHeight(1)
        else
            t:SetWidth(1)
        end
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        table.insert(f.recess, t)
    end
    return f.recess
end

-- ------------------------------------------------------------ the plates
-- (2026-11-25, the user's pick A of /workspace/lfg-mock-A-plates.png, the
-- macro cards' look) a plate on f: its face the window's ink, fading
-- left to right as the window's own (ns.window.FADE; 2026-11-25, the
-- user's: no shadow, the background's fade), a gold_d edge (its top line
-- full); held (R.Lift), the edge gold and a soft glow round it.
--   R.Plate(f)      the plate, f.plate its parts
--   R.Lift(f, on)   held or not
function R.Plate(f)
    local p = {}
    f.plate = p
    local ink, fade = ns.colors.ink, ns.window.FADE or { 1, 0.1 }
    p.face = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    p.face:SetAllPoints()
    if p.face.SetGradient and CreateColor then
        p.face:SetColorTexture(1, 1, 1, 1)
        p.face:SetGradient("HORIZONTAL", CreateColor(ink[1], ink[2], ink[3], fade[1]),
            CreateColor(ink[1], ink[2], ink[3], fade[2]))
    else
        p.face:SetColorTexture(ink[1], ink[2], ink[3], (fade[1] + fade[2]) / 2)
    end
    p.edges, p.halo = {}, {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local across = i <= 2
        local t = f:CreateTexture(nil, "BORDER", nil, -2)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if across then t:SetHeight(1) else t:SetWidth(1) end
        p.edges[i] = t
        -- the glow: a line 2 out from the edge
        local g = f:CreateTexture(nil, "BACKGROUND", nil, -6)
        local dx = i == 3 and -2 or i == 4 and 2 or 0
        local dy = i == 1 and 2 or i == 2 and -2 or 0
        g:SetPoint(side[1], dx - (across and 2 or 0), dy + (across and 0 or 2))
        g:SetPoint(side[2], dx + (across and 2 or 0), dy - (across and 0 or 2))
        if across then g:SetHeight(2) else g:SetWidth(2) end
        g:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
        p.halo[i] = g
    end
    R.Lift(f, false)
    return p
end

function R.Lift(f, on)
    local p = f.plate
    on = on and true or false
    p.on = on
    for i, t in ipairs(p.edges) do
        local c = on and GOLD or GOLD_D
        t:SetColorTexture(c[1], c[2], c[3], (on or i == 1) and 1 or 0.6)
    end
    for _, g in ipairs(p.halo) do g:SetShown(on) end
end

-- a button's own states' art (normal, pushed, lit, disabled): put away
function R.Plain(b)
    R.Bare(b)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
end

-- An icon as a medallion: its square border cut off (once, before the
-- mask: the game refuses tex coords after), masked round (inset from its
-- edge), the medallions' bezel (bezel.lua) on its edge, an ink well under
-- it. Returns its dress.
-- layer: the ring's and well's draw layer, sublevels 1 and 2 (the icon then
-- above 2); unless given, BACKGROUND -6 and -5.
function R.Medal(owner, icon, inset, layer)
    local d = deco[owner] or {}
    deco[owner] = d
    if d.rim then return d end
    inset = inset or 3
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if owner.CreateMaskTexture and icon.AddMaskTexture then
        d.mask = owner:CreateMaskTexture()
        d.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        d.mask:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
        d.mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
        icon:AddMaskTexture(d.mask)
    end
    d.rim = ns.Bezel(owner, icon:GetWidth() or 28, layer or "OVERLAY", layer and 4 or 6)
    d.rim:ClearAllPoints()
    d.rim:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    d.rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    d.well = owner:CreateTexture(nil, layer or "BACKGROUND", nil, layer and 2 or -5)
    d.well:SetTexture(ROUND)
    d.well:SetPoint("TOPLEFT", icon, "TOPLEFT", 1.5, -1.5)
    d.well:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1.5, 1.5)
    local ink = ns.colors.ink
    d.well:SetVertexColor(ink[1], ink[2], ink[3], 1)
    return d
end

-- ---------------------------------------------------------------- the frame
-- The game's frame art gone, ours (the windows' Dress) under its content:
-- the title in gold, a hair and a fainter one under the head at hairAt,
-- gold rules edge to edge at rules ({ "TOP" | "BOTTOM", y }: the cell
-- rows' lines, the chat's tab row's hairline), our close glyph on its
-- close button (its click the game's). Returns the skin.
function R.Chrome(f, title, rules, hairAt)
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer" }) do
        if f[key] then f[key]:Hide() end
    end
    for _, key in ipairs({ "Background", "Bg", "TopTileStreaks" }) do
        if f[key] then f[key]:SetAlpha(0) end
    end
    if f.Inset then
        f.Inset:SetAlpha(0)
        f.Inset:EnableMouse(false)
    end
    local skin = CreateFrame("Frame", nil, f)
    skin:SetAllPoints()
    skin:SetFrameLevel(f:GetFrameLevel())       -- under its content, over its own art
    local dress = ns.window.Dress(skin, 0)
    if dress.rule then dress.rule:Hide() end
    skin.title = ns.Text(skin, 16)
    skin.title:SetPoint("TOPLEFT", PAD + 2, -12)
    skin.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    skin.title:SetText(title)
    local hair = ns.window.Hair(skin)
    hair:SetPoint("TOPLEFT", PAD, -hairAt)
    hair:SetPoint("TOPRIGHT", -PAD, -hairAt)
    local faint = ns.window.Hair(skin, false, 0.5)
    faint:SetPoint("TOPLEFT", PAD + 30, -(hairAt + 3))
    faint:SetPoint("TOPRIGHT", -PAD - 30, -(hairAt + 3))
    for _, at in ipairs(rules or {}) do
        local rule = skin:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetHeight(1)
        rule:SetPoint(at[1] .. "LEFT", 1, at[2])
        rule:SetPoint(at[1] .. "RIGHT", -1, at[2])
    end
    local close = f.CloseButton
    if close then
        R.Bare(close)
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local t = close[get] and close[get](close)
            if t then t:SetAlpha(0) end
        end
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -PAD, -6)
        close:SetSize(26, 26)
        local g = R.Glyph(close, "close", 16)
        close:HookScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
        close:HookScript("OnLeave", function() g:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
    end
    return skin
end

-- --------------------------------------------------------------- the place
-- Where the LFG window stands: its box (built or not shown) when there is
-- one, else the chat box's top to the screen's
local placing = false
function R.Place(f)
    if not f or placing then return end
    placing = true
    f:ClearAllPoints()
    local box = ns.lfg and ns.lfg.box
    if box then
        f:SetPoint("TOPLEFT", box, "TOPLEFT")
        f:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
    else
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        if ns.chat and ns.chat.box then
            f:SetPoint("BOTTOMLEFT", ns.chat.box, "TOPLEFT", 0, -1)
        else
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 260)
        end
        f:SetWidth(WIDTH)
    end
    placing = false
end

-- its own place, whenever the panel manager or the game moves it: ours
function R.Hold(f, place)
    place = place or function() R.Place(f) end
    hooksecurefunc(f, "SetPoint", function()
        if not placing then ns.OutOfCombat(place) end
    end)
end

-- ---------------------------------------------------------------- the spot
-- The LFG window's place holds one window at a time: each of ours there
-- closes the others as it opens (the LFG window too), and the LFG window,
-- an NPC window or the character window opening closes it. While it is
-- open the chat holds still and the quest tracker steps aside; its
-- tooltips stand beside it. shown: run first as it shows (its place, its
-- dress).
local spot = {}

local function Close(f)
    if f:IsShown() then
        if HideUIPanel then HideUIPanel(f) else f:Hide() end
    end
end

function R.Stand(f, who, shown)
    table.insert(spot, f)
    f:HookScript("OnShow", function()
        if shown then shown() end
        if ns.chat then ns.chat.Hold(true, who) end
        -- the LFG window and the others share the place: closed
        if ns.lfg and ns.lfg.IsShown and ns.lfg.IsShown() then ns.lfg.Close() end
        for _, other in ipairs(spot) do
            if other ~= f then Close(other) end
        end
    end)
    f:HookScript("OnHide", function()
        if ns.chat then ns.chat.Hold(false, who) end
    end)
    if ns.quests and ns.quests.Cover then ns.quests.Cover(f) end
    -- its tooltips beside it, as the LFG window's: the game's own (its
    -- SetOwner, placed again by the shell) and ours
    if ns.window.Mark then ns.window.Mark(f, -1) end
    -- the LFG window and an NPC window opening close it: the last opened wins
    local function CloseOurs() Close(f) end
    if ns.lfg and ns.lfg.box then ns.lfg.box:HookScript("OnShow", CloseOurs) end
    if ns.npc and ns.npc.box then ns.npc.box:HookScript("OnShow", CloseOurs) end
    if ns.character and ns.character.window then ns.character.window:HookScript("OnShow", CloseOurs) end
end

-- ------------------------------------------------------------------ menus
-- A dropdown's menu (the game's shared menus, Blizzard_Menu): an ink panel
-- with a gold edge over their art, their radio and check marks, dividers
-- and hover glow in gold, while ours is open. Their frames and parts are
-- the game's, pooled and lent to every other menu after: each change is
-- noted and undone as ours closes, ours hidden. Fonts and text colours are
-- left (the game sizes each line to its words as it opens; a class colour
-- or a green New Layout is the game's meaning).
local worn = {}                 -- the changes on the open menu, to undo
local panels = {}               -- ours, by the game's menu frame

local function Wear(r, how)
    if how == "hide" then
        table.insert(worn, { r, "alpha", r:GetAlpha() })
        r:SetAlpha(0)
    else
        local vr, vg, vb, va = r:GetVertexColor()
        table.insert(worn, { r, "tint", vr, vg, vb, va, r.IsDesaturated and r:IsDesaturated() })
        if r.SetDesaturated then r:SetDesaturated(true) end
        r:SetVertexColor(how[1], how[2], how[3], how[4] or 1)
    end
end

local function Undo()
    for i = #worn, 1, -1 do
        local w = worn[i]
        local r = w[1]
        if w[2] == "alpha" then
            r:SetAlpha(w[3] or 1)
        else
            r:SetVertexColor(w[3] or 1, w[4] or 1, w[5] or 1, w[6] or 1)
            if r.SetDesaturated then r:SetDesaturated(w[7] and true or false) end
        end
    end
    wipe(worn)
    for _, p in pairs(panels) do p:Hide() end
end

-- a part's look by its art: the marks gold, the glow faint gold, the rule
-- dark gold; anything else (an icon of the game's meaning) left
local function Part(r)
    if not (r.GetObjectType and r:GetObjectType() == "Texture") then return end
    local atlas = r.GetAtlas and r:GetAtlas()
    local file = r.GetTexture and r:GetTexture()
    atlas = type(atlas) == "string" and atlas:lower() or ""
    file = type(file) == "string" and file:lower() or ""
    if atlas:find("tick") or atlas:find("radial") or atlas:find("checkmark") then
        Wear(r, GOLD)
    elseif atlas:find("highlight") or file:find("highlight") then
        Wear(r, { GOLD[1], GOLD[2], GOLD[3], 0.35 })
    elseif file:find("divider") then
        Wear(r, GOLD_D)
    end
end

function R.Menu(menu)
    if not menu or not menu.GetRegions then return end
    Undo()
    -- its background (the style's art on the menu itself): under our panel
    for _, r in ipairs({ menu:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then Wear(r, "hide") end
    end
    local p = panels[menu]
    if not p then
        p = CreateFrame("Frame", nil, menu)
        p:SetPoint("TOPLEFT", -2, 2)
        p:SetPoint("BOTTOMRIGHT", 2, 5)
        p:SetFrameLevel(menu:GetFrameLevel())
        local edge = p:CreateTexture(nil, "BACKGROUND", nil, -8)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        local well = p:CreateTexture(nil, "BACKGROUND", nil, -7)
        well:SetPoint("TOPLEFT", 1, -1)
        well:SetPoint("BOTTOMRIGHT", -1, 1)
        local ink = ns.colors.ink
        well:SetColorTexture(ink[1], ink[2], ink[3], 0.97)
        panels[menu] = p
    end
    p:Show()
    -- its lines: their marks, rules and glow
    local function Walk(f, depth)
        for _, r in ipairs({ f:GetRegions() }) do Part(r) end
        if f.GetHighlightTexture then
            local h = f:GetHighlightTexture()
            if h then Part(h) end
        end
        if depth < 4 then
            for _, c in ipairs({ f:GetChildren() }) do
                if c ~= p then Walk(c, depth + 1) end
            end
        end
    end
    for _, c in ipairs({ menu:GetChildren() }) do
        if c ~= p then Walk(c, 1) end
    end
end
R.Undo = Undo

function R.Dropdown(button)
    if not button or deco[button] and deco[button].menu then return end
    local d = deco[button] or {}
    deco[button] = d
    d.menu = true
    if button.OnMenuOpened then hooksecurefunc(button, "OnMenuOpened", function(_, menu) R.Menu(menu) end) end
    if button.OnMenuClosed then hooksecurefunc(button, "OnMenuClosed", Undo) end
end
