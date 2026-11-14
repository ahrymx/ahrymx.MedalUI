-- Where a Cooldown Manager viewer's icons stand (cooldowns/display.lua):
-- geometry alone, no frames, so the harness prints it exactly.
--
--   Bar    rows of icons, across or down; a row holds Per row of them (0:
--          one row), each row centred, the next row above (across) or to
--          the right (down)
--
--              (5) (3) (1) (2) (4)        middle out: the first in the middle
--
--   Arch   one arc, its icons upright: ∩ (up) or ∪ (down), spanning Span
--          degrees; its radius is what spaces the icons one step apart
--
--                   (3) (1) (2)
--               (5)             (4)
--
-- The order is the Cooldown Manager's own (the order its spells are dragged
-- into in /cdm): its first is the hierarchy's top, and Fill order says
-- where it stands. Offsets are from the set's middle, in the units Size is
-- in; the set's width and height come back with them.
local _, ns = ...

local L = {}
ns.cdmLayout = L

-- A row of m slots, by rank: which slot (1 = left, or top) each takes.
--   start    1, 2, 3 ...
--   finish   m, m-1 ...
--   middle   the middle, then right of it, then left, outward by turns
--            (an even row's middle is its left one of the two)
function L.Fill(m, order)
    local out = {}
    if order == "finish" then
        for r = 1, m do out[r] = m - r + 1 end
    elseif order == "middle" then
        local c = math.floor((m + 1) / 2)
        out[1] = c
        local r, d = 2, 1
        while r <= m do
            if c + d <= m then out[r] = c + d; r = r + 1 end
            if r <= m and c - d >= 1 then out[r] = c - d; r = r + 1 end
            d = d + 1
        end
    else
        for r = 1, m do out[r] = r end
    end
    return out
end

-- The slots of n icons, row by row (one row for an arch), left to right
-- or top to bottom, as { x, y }.
local function Rows(n, s)
    local step = s.size + s.spacing
    local rows = {}
    if s.layout == "arch" and n > 1 then
        local span = math.rad(math.max(1, s.span))
        local r = step * (n - 1) / span
        local sign = s.opens == "down" and -1 or 1
        local row = {}
        for i = 1, n do
            local a = -span / 2 + (i - 1) * span / (n - 1)
            row[i] = { r * math.sin(a), sign * (r * math.cos(a) - r) }
        end
        rows[1] = row
        return rows
    end
    local per = (s.perRow and s.perRow > 0) and s.perRow or n
    local down = s.layout ~= "arch" and s.orient == "down"
    local k = 0
    while k < n do
        local m = math.min(per, n - k)
        local row, line = {}, #rows
        for i = 1, m do
            local along = (i - (m + 1) / 2) * step
            local across = line * step
            row[i] = down and { across, -along } or { along, across }
        end
        rows[#rows + 1] = row
        k = k + m
    end
    return rows
end

-- n icons placed: by rank (the Cooldown Manager's order), { x, y } from the
-- set's middle; and the set's width and height, icons included.
function L.Place(n, s)
    local out = {}
    if n <= 0 then return out, 0, 0 end
    local rank = 0
    local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
    for _, row in ipairs(Rows(n, s)) do
        for _, slot in ipairs(L.Fill(#row, s.order)) do
            rank = rank + 1
            local p = row[slot]
            out[rank] = { p[1], p[2] }
            x0, x1 = math.min(x0, p[1]), math.max(x1, p[1])
            y0, y1 = math.min(y0, p[2]), math.max(y1, p[2])
        end
    end
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for _, p in ipairs(out) do p[1], p[2] = p[1] - cx, p[2] - cy end
    return out, x1 - x0 + s.size, y1 - y0 + s.size
end
