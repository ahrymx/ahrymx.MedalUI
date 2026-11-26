-- A quest item's drop rates, from QuestieDB when it is installed: the
-- tracker and the quest page put them after an item objective that is not
-- done yet ("Gnoll Paw: 3/8  · 12-18% drop"), and list each creature's in
-- the objective's tooltip. Read at run time only (## OptionalDeps), nothing
-- of it copied; without QuestieDB, nothing shows.
--
-- QuestieDB keeps three tables (LibQuestieDB.Support): Questie's own
-- corrections, the CMaNGOS server's loot tables and a Wowhead snapshot. A
-- creature's rate is the correction's where there is one (or the table it
-- points to), else the server's, else Wowhead's, as Questie reads them.
--
--   ns.questDrops.For(questID, text, kind)  { lo, hi, item, rates = { { name, rate } } }
--                                     for the objective of that text (kind: the
--                                     game's type for it, "item" ...); nil when
--                                     it is no item's or no rate is known
local _, ns = ...
local Tr = ns.L

local qd = {}
ns.questDrops = qd

local CONTRACT = 4                      -- the QuestieDB contract this was written against
local MOST = 6                          -- creatures listed in a tooltip, at most

local function Try(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, v = pcall(fn, ...)
    if ok then return v end
end

-- QuestieDB's entities and its drop tables, once; false when it is not there
local db
local function DB()
    if db ~= nil then return db or nil end
    local lib = _G.LibQuestieDB
    local quests, items, npcs = _G.QuestDB, _G.ItemDB, _G.NpcDB
    if not (lib and lib.RequireContract and lib.Support and lib.Support.Get and quests and items and npcs) then
        return nil      -- (not loaded yet, or not installed: asked again next time)
    end
    if not Try(lib.RequireContract, CONTRACT) then db = false return nil end
    local function Module(name) return Try(lib.Support.Get, name) or {} end
    local drops, fixes, dropDB = Module("QuestieClassicItemDrops"), Module("QuestieItemDropCorrections"),
        Module("DropDB")
    -- the tables are kept as Lua source: read once, on first use
    local function Load(src)
        if type(src) == "table" then return src end
        if type(src) ~= "string" then return {} end
        local fn = loadstring and loadstring(src)
        return fn and Try(fn) or {}
    end
    local keys = dropDB.correctionKeys or {}
    db = { quests = quests, items = items, npcs = npcs, raw = drops, fixes = fixes.Era or {},
        WOWHEAD = keys.WOWHEAD or -1, PSERVER = keys.PSERVER or -2, Load = Load }
    return db
end
qd.DB = DB

local function Tables(d)
    if not d.wowhead then
        d.wowhead = d.Load(d.raw.wowheadData)
        d.pserver = d.Load(d.raw.cmangosData)
    end
    return d.wowhead, d.pserver
end

-- the rate one creature drops an item at, in percent, or nil
local function Rate(d, item, npc)
    local wowhead, pserver = Tables(d)
    local function From(t) return t[item] and tonumber(t[item][npc]) end
    local fix = d.fixes[item] and d.fixes[item][npc]
    if fix == d.WOWHEAD then return From(wowhead) end
    if fix == d.PSERVER then return From(pserver) end
    if type(fix) == "number" and fix >= 0 then return fix end
    return From(pserver) or From(wowhead)
end

-- the item's rates, highest first: each creature that drops it
local byItem = {}
local function Rates(d, item)
    if byItem[item] ~= nil then return byItem[item] or nil end
    local wowhead, pserver = Tables(d)
    local npcs, seen = {}, {}
    local function Add(id) if type(id) == "number" and not seen[id] then seen[id] = true; npcs[#npcs + 1] = id end end
    for _, id in ipairs(Try(d.items.Get, item, "npcDrops") or {}) do Add(id) end
    for _, t in ipairs({ d.fixes, pserver, wowhead }) do
        for id in pairs(t[item] or {}) do Add(id) end
    end
    local list = {}
    for _, npc in ipairs(npcs) do
        local rate = Rate(d, item, npc)
        if rate and rate > 0 then
            list[#list + 1] = { name = Try(d.npcs.Get, npc, "name") or ("#" .. npc), rate = rate }
        end
    end
    table.sort(list, function(a, b)
        if a.rate ~= b.rate then return a.rate > b.rate end
        return a.name < b.name
    end)
    byItem[item] = #list > 0 and list or false
    return byItem[item] or nil
end

-- the quest's item objectives in QuestieDB: { item, name }
local function Items(d, quest)
    local objectives = Try(d.quests.Get, quest, "objectives")
    local out = {}
    for _, o in ipairs(type(objectives) == "table" and objectives[3] or {}) do
        local item = type(o) == "table" and tonumber(o[1])
        if item then
            out[#out + 1] = { item = item, name = Try(d.items.Get, item, "name") }
        end
    end
    return out
end

-- The objective "Gnoll Paw: 3/8" is the quest's item whose name begins it
-- (the game's own objective text, in the client's language as QuestieDB's
-- names are); else, where the game says it is an item and the quest has one
-- item objective, that one ("Fins collected: 2/12").
local function Find(list, text, kind)
    local best
    for _, o in ipairs(list) do
        if o.name and text:sub(1, #o.name) == o.name and (not best or #o.name > #best.name) then best = o end
    end
    if best then return best.item end
    if kind == "item" and #list == 1 then return list[1].item end
end

local cache = {}
function qd.For(quest, text, kind)
    if type(quest) ~= "number" or type(text) ~= "string" or text == "" then return nil end
    local d = DB()
    if not d then return nil end
    local key = quest .. "\0" .. tostring(kind) .. "\0" .. text:gsub("%d+%s*/%s*%d+", "")
    if cache[key] ~= nil then return cache[key] or nil end
    local item = Find(Items(d, quest), text, kind)
    local rates = item and Rates(d, item)
    local out = false
    if rates then
        out = { item = item, lo = rates[#rates].rate, hi = rates[1].rate, rates = rates }
    end
    cache[key] = out
    return out or nil
end

-- "12-18%" or "41%", rounded; under 1% as "<1%"
local function Pct(v)
    if v < 1 then return "<1" end
    return tostring(math.floor(v + 0.5))
end
function qd.Range(info)
    local lo, hi = Pct(info.lo), Pct(info.hi)
    return (lo == hi and hi or (lo .. "\226\128\147" .. hi)) .. "%"
end

-- The objective's line with its rate after it (dim), when it has one and
-- is not done.
local DIM = "|cff8c8473"
function qd.Tag(quest, o)
    if not o or o.done then return o and o.text end
    local info = qd.For(quest, o.text, o.kind)
    if not info then return o.text end
    return o.text .. "  " .. DIM .. "\194\183 " .. format(Tr["%s drop"], qd.Range(info)) .. "|r"
end

-- Its creatures in a tooltip: the item's name, each creature's rate
function qd.AddTooltip(tip, quest, o)
    if not o or o.done then return false end
    local info = qd.For(quest, o.text, o.kind)
    if not info then return false end
    local d = DB()
    tip:AddLine(" ")
    tip:AddLine(format(Tr["%s: drop rates"], d and Try(d.items.Get, info.item, "name") or Tr["Drops"]),
        ns.gold.light[1], ns.gold.light[2], ns.gold.light[3])
    for i, r in ipairs(info.rates) do
        if i > MOST then
            tip:AddLine(string.format(Tr["and %d more"], #info.rates - MOST), 0.55, 0.52, 0.45)
            break
        end
        tip:AddDoubleLine(r.name, Pct(r.rate) .. "%", 0.95, 0.92, 0.82, 0.95, 0.92, 0.82)
    end
    tip:AddLine(Tr["From QuestieDB."], 0.49, 0.46, 0.38)
    return true
end
