-- The gauges round the medallions (2026-11-10, mockup A of
-- /workspace/rings-mockups.png): an arc on a medallion's border, from 7
-- o'clock clockwise round to 5 (mirrored on the right), on a dark track
-- all the way round; green, amber or red by how well things stand. The
-- numbers are in the medallion's tooltip (strips/status.lua). The arcs are
-- frames of one atlas (art/strips/gen_strips.py, rings).
--
-- (2026-11-26, the user's picks) the ring is the medallions' slim bezel
-- widened for a dark channel, the gauge a lit bar in it, notched at each
-- tenth ("C · Ticked" of /workspace/gauge-mock-sheet.png; "D · Ember" first,
-- too plain and hard to read in game, the user's): the bezel (ring-track,
-- the dark gold; ring-glint over it, the light) and the gauge (ring-arc).
-- The strip's art has no ring of its own now. They
-- stand on a frame of their own over the strip's art, under its keys;
-- while a docked window is open on the strip, the window lifts it over
-- its copy of the medallion (window/shell.lua, Lift), so the gauge shows
-- with a window open as without (the user's: they were hidden).
local _, ns = ...

local STEPS, COLS, ROWS = 32, 8, 4               -- the atlas: frame k spans k/STEPS of the arc
local BOX = 64                                   -- the arc's box, art px, centred on the well
local GREEN, AMBER, RED = { 0.373, 0.749, 0.29 }, { 0.851, 0.627, 0.188 }, { 0.847, 0.267, 0.18 }

local function Colour(v)
    return v > 0.5 and GREEN or v > 0.2 and AMBER or RED
end

-- Frame k of the atlas, flipped for the right strip.
local function Frame(tex, k, side)
    local l, t = ((k - 1) % COLS) / COLS, math.floor((k - 1) / COLS) / ROWS
    local r, b = l + 1 / COLS, t + 1 / ROWS
    if side < 0 then tex:SetTexCoord(l, r, t, b) else tex:SetTexCoord(r, l, t, b) end
end

local function Set(ring, frac, v)
    frac = math.max(0, math.min(1, frac))
    local k = math.floor(frac * STEPS + 0.5)
    local c = Colour(v)
    ring.k, ring.color = k, c
    if k > 0 then Frame(ring.arc, k, ring.side) end
    ring.arc:SetShown(k > 0)
    ring.arc:SetVertexColor(c[1], c[2], c[3])
end

-- A gauge round side's medallion. ring:Set(frac, v): frac how much of the
-- arc, v how well (its colour). ns.stripRings[side] is it; ring.frame what
-- a window lifts.
ns.stripRings = {}
function ns.Ring(side)
    local strip = ns.strips[side]
    local w = ns.stripWell
    local ring = { side = side, Set = Set }
    local f = CreateFrame("Frame", nil, strip)
    f:SetAllPoints()
    f:SetFrameLevel(ns.levels.stripArt + 1)
    local function Tex(name, layer, sub)
        local t = f:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(ns.media .. "strips\\" .. name)
        ns.OnStrip(t, side, w.x, w.y, BOX, BOX)
        return t
    end
    local dark, light = ns.gold.dark, ns.gold.light
    ring.track = Tex("ring-track", "ARTWORK", 1)
    ring.track:SetVertexColor(dark[1], dark[2], dark[3], 1)
    ring.glint = Tex("ring-glint", "ARTWORK", 2)
    ring.glint:SetBlendMode("ADD")
    ring.glint:SetVertexColor(light[1], light[2], light[3], 0.55)
    ring.arc = Tex("ring-arc", "OVERLAY", 1)
    ring.frame = f
    ns.stripRings[side] = ring
    return ring
end
