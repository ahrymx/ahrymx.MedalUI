-- A talent build from Wowhead's talent calculator (its Forever one), read
-- out of whatever was pasted: the calculator's link, its embed link or its
-- WHML ([talent=...]) all carry the same string. Plain string work, so the
-- talents window (spells/talents.lua) maps it onto the trees in game.
--
-- The string, as Wowhead's TalentCalcClassic.js writes it:
--   <class>/<version><tree>-<tree>-<tree>[_t<n>][_l<level>][_r<race>][/<order>]
--   - version: lower-case letters, Wowhead's stamp of its data; dropped
--   - each tree: a digit a talent, its ranks, the talents by row then
--     column; trailing zeros and empty trees left off
--   - _t, _l, _r: the Talented perk's rank, a level, a race; not read
--   - order: the order the points were taken in. A digit 0-2 moves to that
--     tree; then each character a talent of it, by its index in MIN (one
--     rank) or MAX (every rank it has in the build, at once).
local _, ns = ...

local MIN = "abcdefghjkmnpqrstvwzxyilou468-~!"
local MAX = "ABCDEFGHJKMNPQRSTVWZXYILOU579_^."
local CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }

-- the build's string after its class, up to where the link or tag ends
local function Find(text)
    for _, slug in ipairs(CLASSES) do
        local at = text:find("%f[%a]" .. slug .. "/")
        if at then
            return slug, (text:sub(at + #slug + 1):match("^[^%s%]\"'<?#]*"))
        end
    end
end

-- The build in text: { class = "SHAMAN", trees = { { ranks by talent }, ... },
-- order = { { tree, talent, ranks }, ... } or nil when it has none }, the
-- trees and talents counted from 1. Nil when there is none, or it does not
-- read as one.
function ns.WowheadBuild(text)
    local slug, rest = Find(tostring(text or ""))
    if not slug then return end
    local build, order = rest:match("^([^/]*)/?(.*)$")
    local points = build:match("^%l*([%d%-]*)")
    if not points or not points:find("%d") then return end
    local trees = {}
    for part in (points .. "-"):gmatch("([^-]*)-") do
        local list = {}
        for d in part:gmatch("%d") do table.insert(list, tonumber(d)) end
        table.insert(trees, list)
    end
    if #trees > 3 then return end
    for k = #trees + 1, 3 do trees[k] = {} end
    local out = { class = slug:upper(), trees = trees }
    if order == "" then return out end
    -- the order: each talent's ranks in it must come to the tree's
    local list, tree, counts = {}, nil, { {}, {}, {} }
    for c in order:gmatch(".") do
        if c:find("^[012]$") then
            tree = tonumber(c) + 1
        else
            local i, all = MIN:find(c, 1, true), false
            if not i then i, all = MAX:find(c, 1, true), true end
            if not (i and tree) then return end
            local n = all and (trees[tree][i] or 0) or 1
            if n < 1 then return end
            table.insert(list, { tree, i, n })
            counts[tree][i] = (counts[tree][i] or 0) + n
        end
    end
    for t = 1, 3 do
        for i, n in ipairs(trees[t]) do
            if n ~= (counts[t][i] or 0) then return end
        end
        for i, n in pairs(counts[t]) do
            if (trees[t][i] or 0) ~= n then return end
        end
    end
    out.order = list
    return out
end
