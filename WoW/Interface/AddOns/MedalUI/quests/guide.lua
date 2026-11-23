-- The Zone tab's Guide (strips/zone.lua, zoneSort "guide"): what to do next
-- for experience. The quests worth taking here at your level, and the ones
-- in your log, put in the order to do them in, nearest first within each
-- kind of work. Forever Quest Routes was the model for the idea (a plan
-- looked at again from where you stand); none of its code or data is here.
--
-- Where things are comes from QuestieDB, read at run time only (## OptionalDeps,
-- as quests/chains.lua and quests/drops.lua read it): who gives and takes
-- each quest, where they stand, where its creatures and objects are. Without
-- it the Guide has nothing to show and says so.
--
-- The order (the user's, 2026-11-23), tier by tier:
--   0 near    quests done whose hand-in is within NEAR yards, or NEAR_CHAIN
--             when their chain goes on after them: before anything else
--             ("prioritise quest turn ins when they're close to the player")
--   1 pick    quests to take: in reach, at your level (a green one only when
--             its chain comes back to your level)
--     small   and quests whose work left is one of each, or all in one spot
--             (every place it is done within SMALL yards of their middle):
--             one tier, the nearest first ("short objectives or pickup
--             depending on which is closest"; picks first had a tier of
--             their own, ahead, and that was too keen on them)
--   2 turnin  quests done, to hand in
--   3 large   the rest: counts of kills or loot over a wide area
-- Within a tier the nearest first, in steps of STEP yards; in one step,
-- quests to take by experience for the trip ((xp + half the chain's xp to
-- come) / (seconds + 30)), then the order they had. The one at the head
-- keeps its place while another in its tier is not clearly better (KEEP:
-- twice as near and a minute sooner). In combat the order is the last one;
-- quests new to it go last.
--
--   G.Ready()          whether QuestieDB is there to plan with
--   G.Plan(frozen)     the list: the log's quests (Q.Log's, each with .guide)
--                      and quests to take (pick = true), each .guide =
--                      { kind, yards, where = { map, x, y }, npc, xp, steps,
--                      chainXP, score }; and whether its order moved
--   G.Steer(entry)     the waypoint at the entry (zoneGuideWaypoint), unless
--                      the player set another themselves
--   G.Suggest()        the nearest zone at your level on this continent: its name
--   G.Head(list)       the entry the waypoint is for: the one stepped to, or the
--                      first not ignored
--   G.Ignore(e), G.Ignored(e)  a quest to take ignored (Ctrl+right-click), or not
--   G.Next(cur), G.Back(cur)  the waypoint a row down or up the list (the Zone
--                      tab's controls; cur: the row it is at); G.CanNext(cur),
--                      G.CanBack(cur) whether there is one
--
-- Steps (2026-11-23, the user's: "the list should be static, but the
-- focused quest should move"): Next and Back move the waypoint a row down
-- the list or up, the list as it is. The Guide points at the one stepped
-- to (G.Head) until it leaves the list or changes kind (its work done, it
-- is a hand-in), or the player sets a waypoint of their own; then at the
-- head again. A step takes the waypoint back for the Guide, from a waypoint
-- the player set too. Quests to take are left out
-- while zoneGuidePicks is off.
local _, ns = ...

local G = {}
ns.questGuide = G

local CONTRACT = 4                      -- the QuestieDB contract this was written against
local SPEED = 7                         -- yards a second, on foot
local REACH = 1500                      -- yards to a quest's giver, at most
local SMALL = 100                       -- yards around the middle of a quest's places: one spot
local STEP = 10                         -- yards a distance counts in
local KEEP_RATIO, KEEP_SECONDS = 2, 60  -- clearly better: twice as near and a minute sooner
local BELOW, ABOVE = 2, 3               -- the levels of quests to take, from yours
local ZONE_BELOW, ZONE_ABOVE = 5, 5     -- a zone's middle level, from yours
local MOST = 60                         -- places kept of each creature or object
local NEAR, NEAR_CHAIN = 300, 700      -- yards to a hand-in that goes first; its chain going on
local TIER = { pick = 1, small = 1, turnin = 2, large = 3 }
G.TIER = TIER
-- a hand-in near enough goes ahead of every tier
local function Tier(g) return g.near and 0 or TIER[g.kind] end
local floor, sqrt, huge = math.floor, math.sqrt, math.huge

local function Try(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

-- ------------------------------------------------------------ QuestieDB
local db
local function DB()
    if db ~= nil then return db or nil end
    local lib = _G.LibQuestieDB
    local quests, npcs, objects, items = _G.QuestDB, _G.NpcDB, _G.ObjectDB, _G.ItemDB
    if not (lib and lib.RequireContract and quests and quests.Get and quests.GetAllIds and npcs and npcs.Get) then
        return nil      -- (not loaded yet, or not there: asked again next time)
    end
    if not Try(lib.RequireContract, CONTRACT) then db = false return nil end
    db = { lib = lib, quests = quests, npcs = npcs, objects = objects, items = items }
    return db
end
function G.Ready() return DB() ~= nil end

local function Get(t, id, key)
    if not (t and t.Get) then return nil end
    return (Try(t.Get, id, key))
end

local function Num(v) return type(v) == "number" and v or 0 end
local function List(v) return type(v) == "table" and v or {} end

-- QuestieDB's area ids (its spawns' zones) to the game's maps: its own
-- table, kept as Lua source; the overrides over it
local areas
local function AreaMap(area)
    if not areas then
        areas = {}
        local zones = DB() and Try(db.lib.Support and db.lib.Support.Get, "ZoneDB")
        local private = type(zones) == "table" and zones.private or {}
        local function Load(src)
            if type(src) == "table" then return src end
            if type(src) ~= "string" or not loadstring then return {} end
            local fn = loadstring(src)
            return fn and Try(fn) or {}
        end
        for k, v in pairs(Load(private.areaIdToUiMapId)) do areas[k] = v end
        for k, v in pairs(Load(private.areaIdToUiMapIdOverride)) do areas[k] = v end
    end
    local map = areas[area]
    return map and map > 0 and map or nil
end

-- ---------------------------------------------------------------- places
-- A place on a map (x, y out of 100) in the world: continent, and yards.
local function World(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local cont, pos = Try(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if not (cont and pos and pos.GetXY) then return end
    local wx, wy = pos:GetXY()
    if not (wx and wy) or ns.IsSecret(wx) then return end
    return cont, wx, wy
end

-- where you stand, as World's (measured as the places are, so the two agree)
local function Me()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not (x and y) or ns.IsSecret(x) or (x == 0 and y == 0) then return end
    return World(map, x * 100, y * 100)
end
G.Me = Me

-- An entity's places (QuestieDB's spawns: area -> { { x, y }, ... }), each
-- { map, x, y, cont, wx, wy }; at most MOST, taken evenly
local spotsOf = {}
local function Spots(t, id)
    local key = tostring(t) .. id
    if spotsOf[key] then return spotsOf[key] end
    local out = {}
    for area, list in pairs(List(Get(t, id, "spawns"))) do
        local map = type(area) == "number" and AreaMap(area)
        if map and type(list) == "table" then
            local step = math.max(1, floor(#list / MOST))
            for i = 1, #list, step do
                local p = list[i]
                local x, y = type(p) == "table" and p[1], type(p) == "table" and p[2]
                if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
                    local cont, wx, wy = World(map, x, y)
                    if cont then out[#out + 1] = { map = map, x = x, y = y, cont = cont, wx = wx, wy = wy } end
                end
            end
        end
    end
    spotsOf[key] = out
    return out
end

local function Add(out, list) for _, p in ipairs(list) do out[#out + 1] = p end end

-- where a quest is given ("startedBy") or taken back ("finishedBy"): its
-- creatures' and objects' places; and the first creature's name
local function People(id, key)
    local by, out = Get(db.quests, id, key), {}
    by = List(by)
    local name
    for _, npc in ipairs(List(by[1])) do
        Add(out, Spots(db.npcs, npc))
        name = name or Get(db.npcs, npc, "name")
    end
    for _, obj in ipairs(List(by[2])) do
        Add(out, Spots(db.objects, obj))
        name = name or Get(db.objects, obj, "name")
    end
    return out, name
end

-- where a quest's work is done: its creatures, its objects, the creatures
-- and objects that drop its items, its places to reach
local workOf = {}
local function Work(id)
    if workOf[id] then return workOf[id] end
    local out = {}
    local o = List(Get(db.quests, id, "objectives"))
    for _, c in ipairs(List(o[1])) do if type(c) == "table" then Add(out, Spots(db.npcs, c[1])) end end
    for _, c in ipairs(List(o[2])) do if type(c) == "table" then Add(out, Spots(db.objects, c[1])) end end
    for _, c in ipairs(List(o[3])) do
        local item = type(c) == "table" and c[1]
        if item then
            for _, npc in ipairs(List(Get(db.items, item, "npcDrops"))) do Add(out, Spots(db.npcs, npc)) end
            for _, obj in ipairs(List(Get(db.items, item, "objectDrops"))) do Add(out, Spots(db.objects, obj)) end
        end
    end
    for _, c in ipairs(List(o[5])) do
        if type(c) == "table" then
            for _, npc in ipairs(List(c[1])) do Add(out, Spots(db.npcs, npc)) end
        end
    end
    local trigger = List(Get(db.quests, id, "triggerEnd"))
    for area, list in pairs(List(trigger[2])) do
        local map = type(area) == "number" and AreaMap(area)
        for _, p in ipairs(map and List(list) or {}) do
            local cont, wx, wy = World(map, p[1], p[2])
            if cont then out[#out + 1] = { map = map, x = p[1], y = p[2], cont = cont, wx = wx, wy = wy } end
        end
    end
    workOf[id] = out
    return out
end

-- the nearest of the places on your continent: it and its yards
local function Nearest(points, cont, wx, wy)
    local best, d2
    for _, p in ipairs(points) do
        if p.cont == cont then
            local dx, dy = p.wx - wx, p.wy - wy
            local d = dx * dx + dy * dy
            if not d2 or d < d2 then best, d2 = p, d end
        end
    end
    return best, d2 and sqrt(d2)
end
G.Nearest = Nearest

-- how far the places on your continent reach from their middle, in yards
local function Spread(points, cont)
    local n, sx, sy = 0, 0, 0
    for _, p in ipairs(points) do
        if p.cont == cont then n, sx, sy = n + 1, sx + p.wx, sy + p.wy end
    end
    if n == 0 then return nil end
    local cx, cy, far = sx / n, sy / n, 0
    for _, p in ipairs(points) do
        if p.cont == cont then
            local dx, dy = p.wx - cx, p.wy - cy
            far = math.max(far, sqrt(dx * dx + dy * dy))
        end
    end
    return far
end
G.Spread = Spread

-- ----------------------------------------------------------- quests to take
-- Every quest given somewhere on a continent, once: { id, level, need,
-- points, npc, map }; and the middle level of each map's quests.
local index, middles = {}, {}
local function Index(cont)
    if index[cont] then return index[cont] end
    local out, levels = {}, {}
    for _, id in ipairs(List(Try(db.quests.GetAllIds))) do
        local special = Num(Get(db.quests, id, "specialFlags"))
        -- (not a repeatable one, nor one needing a trade or a standing)
        if special % 2 == 0 and not Get(db.quests, id, "requiredSkill")
            and not Get(db.quests, id, "requiredMinRep") then
            local points, npc = People(id, "startedBy")
            local here = {}
            for _, p in ipairs(points) do if p.cont == cont then here[#here + 1] = p end end
            local level = Num(Get(db.quests, id, "questLevel"))
            if #here > 0 and level > 0 then
                out[#out + 1] = { id = id, level = level, need = Num(Get(db.quests, id, "requiredLevel")),
                    points = here, npc = npc, map = here[1].map }
                local l = levels[here[1].map] or {}
                levels[here[1].map] = l
                l[#l + 1] = level
            end
        end
    end
    for map, l in pairs(levels) do
        table.sort(l)
        middles[map] = l[floor((#l + 1) / 2)]
    end
    index[cont] = out
    return out
end

-- (2026-11-23) handed in this session: done at once, though the game's
-- flag may come a moment after the log's update (else the quest just
-- handed in is one to take again until it does)
local handed = {}
local function Done(id)
    if handed[id] then return true end
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) and true
        or false
end

-- whether the player may take it now: not done, not held, its quests
-- before it done, none that shuts it out done or held, race and class
local function Offered(id, held)
    if Done(id) or held[id] then return false end
    local single = List(Get(db.quests, id, "preQuestSingle"))
    if #single > 0 then
        local any = false
        for _, q in ipairs(single) do if Done(q) then any = true break end end
        if not any then return false end
    end
    for _, q in ipairs(List(Get(db.quests, id, "preQuestGroup"))) do
        if not Done(q) then return false end
    end
    for _, q in ipairs(List(Get(db.quests, id, "exclusiveTo"))) do
        if Done(q) or held[q] then return false end
    end
    return ns.questChains.Fits(id)
end
G.Offered = Offered

-- its chain's steps after it, and their xp
local function Ahead(id)
    local c = ns.questChains.Of(id)
    if not c then return 0, 0, nil end
    local xp, top = 0, nil
    for i = c.at + 1, #c.ids do
        xp = xp + (ns.questChains.XP(c.ids[i]) or 0)
        local l = ns.questChains.Level(c.ids[i])
        if l then top = math.max(top or 0, l) end
    end
    return #c.ids - c.at, xp, top
end

local function Picks(cont, wx, wy, level, held)
    local out = {}
    for _, e in ipairs(Index(cont)) do
        local middle = middles[e.map]
        if e.need <= level and e.level <= level + ABOVE
            and (not middle or (middle >= level - ZONE_BELOW and middle <= level + ZONE_ABOVE)) then
            local at, yards = Nearest(e.points, cont, wx, wy)
            if yards and yards <= REACH and Offered(e.id, held) then
                local steps, chainXP, top = Ahead(e.id)
                -- below the window: only when its chain comes back to your level
                if e.level >= level - BELOW or (top and top >= level - BELOW) then
                    local xp = ns.questChains.XP(e.id) or 0
                    local seconds = yards / SPEED
                    out[#out + 1] = { id = e.id, pick = true, title = ns.questChains.Title(e.id) or ("#" .. e.id),
                        level = e.level, state = 0, tracked = true, objectives = {},
                        guide = { kind = "pick", yards = yards, where = at, npc = e.npc, xp = xp, steps = steps,
                            chainXP = chainXP, score = (xp + chainXP / 2 + 1) / (seconds + 30) } }
                end
            end
        end
    end
    return out
end

-- ------------------------------------------------------- the log's quests
-- Whether every objective left needs one more: "x/1", or no count at all.
local function OneEach(q)
    for _, o in ipairs(q.objectives or {}) do
        if not o.done then
            local _, need = ns.questSource.Count(o)
            if need > 1 then return false end
        end
    end
    return true
end
G.OneEach = OneEach

local function Held(q, cont, wx, wy)
    local g = { kind = "large" }
    if q.state == 1 then
        g.kind = "turnin"
        local points, npc = People(q.id, "finishedBy")
        g.where, g.yards = Nearest(points, cont, wx, wy)
        g.npc = npc
    else
        local points = Work(q.id)
        g.where, g.yards = Nearest(points, cont, wx, wy)
        local spread = Spread(points, cont)
        if OneEach(q) or (spread and spread <= SMALL) then g.kind = "small" end
    end
    if not g.yards then g.yards = ns.questSource.Distance(q.id) end     -- the game's marker, at least
    if g.kind == "turnin" and g.yards then
        g.steps = Ahead(q.id)
        g.near = g.yards <= (g.steps > 0 and NEAR_CHAIN or NEAR)
    end
    q.guide = g
    return q
end

-- ------------------------------------------------------------- the order
local rank, lead = {}, nil      -- the last order (key -> place); its head's key
local seen = {}                 -- the last order's kinds (id -> EntryKey, ! when near)

local function Before(a, b)
    local ga, gb = a.guide, b.guide
    local ta, tb = Tier(ga), Tier(gb)
    if ta ~= tb then return ta < tb end
    local ka, kb = ga.yards and floor(ga.yards / STEP), gb.yards and floor(gb.yards / STEP)
    if (ka == nil) ~= (kb == nil) then return kb == nil end
    if ka and ka ~= kb then return ka < kb end
    if ga.score and gb.score and ga.score ~= gb.score then return ga.score > gb.score end
    local ra, rb = rank[a.id] or huge, rank[b.id] or huge
    if ra ~= rb then return ra < rb end
    return a.id < b.id
end

-- whether n is clearly better than o at the head (both of one tier)
local function Better(n, o)
    local gn, go = n.guide, o.guide
    if not go.yards then return gn.yards ~= nil end
    if not gn.yards then return false end
    local sn, so = gn.yards / SPEED, go.yards / SPEED
    return sn * KEEP_RATIO <= so and so - sn > KEEP_SECONDS
end
G.Better = Better

-- ----------------------------------------------------------------- steps
local focus                     -- the entry key stepped to: the waypoint's, the list left as it is
local claim = false             -- a step was taken: the waypoint is the Guide's again
local order = {}                -- the last list handed out

local function EntryKey(e) return e.guide.kind .. ":" .. e.id end

local function Place(key)
    if not key then return nil end
    for i, e in ipairs(order) do
        if EntryKey(e) == key then return i end
    end
end

local function Ranked(out)
    order = out
    if not Place(focus) then focus = nil end     -- gone from the list, or of another kind now
    local now, moved, kinds = {}, false, {}
    for i, e in ipairs(out) do
        now[e.id] = i
        -- (2026-11-23) its place, or what it is: its work done (a hand-in
        -- now), or near enough to hand in first
        kinds[e.id] = EntryKey(e) .. (e.guide.near and "!" or "")
        if rank[e.id] ~= i or seen[e.id] ~= kinds[e.id] then moved = true end
    end
    for id in pairs(rank) do if not now[id] then moved = true end end
    rank, seen = now, kinds
    lead = out[1] and out[1].id
    return out, moved
end

local last = {}                 -- id -> the last plan's guide (frozen: kept)

function G.Plan(frozen)
    if not DB() then return {}, false end
    local level = UnitLevel and UnitLevel("player")
    if type(level) ~= "number" or ns.IsSecret(level) then return {}, false end
    local log = ns.questSource.Log()
    local held = {}
    for _, q in ipairs(log) do held[q.id] = true end
    if frozen then
        -- the last order: the log's quests as they are now, the quests to
        -- take as they were; those new to it last
        local out = {}
        for _, q in ipairs(log) do
            if q.state ~= -1 then
                q.guide = last[q.id] or { kind = q.state == 1 and "turnin" or "large" }
                out[#out + 1] = q
            end
        end
        for id, g in pairs(last) do
            if g.kind == "pick" and not held[id] and g.entry and ns.db.zoneGuidePicks ~= false then
                out[#out + 1] = g.entry
            end
        end
        table.sort(out, function(a, b)
            local ra, rb = rank[a.id] or huge, rank[b.id] or huge
            if ra ~= rb then return ra < rb end
            return a.id < b.id
        end)
        return Ranked(out)
    end
    local cont, wx, wy = Me()
    local out = {}
    for _, q in ipairs(log) do
        if q.state ~= -1 then out[#out + 1] = Held(q, cont, wx, wy) end
    end
    if cont and ns.db.zoneGuidePicks ~= false then
        for _, e in ipairs(Picks(cont, wx, wy, level, held)) do out[#out + 1] = e end
    end
    table.sort(out, Before)
    -- the head keeps its place while none of its tier is clearly better
    if lead and out[1] and out[1].id ~= lead then
        for i = 2, #out do
            local e = out[i]
            if e.id == lead then
                if Tier(e.guide) == Tier(out[1].guide) and not Better(out[1], e) then
                    table.remove(out, i)
                    table.insert(out, 1, e)
                end
                break
            end
        end
    end
    last = {}
    for _, e in ipairs(out) do
        last[e.id] = e.guide
        if e.pick then e.guide.entry = e end
    end
    return Ranked(out)
end

-- The entry the waypoint is for: the one stepped to, else the list's head
-- (2026-11-23, the user's) Quests to take the player has ignored
-- (Ctrl+right-click on the row): they stay in the list where they are, but
-- the waypoint never goes to one by itself; a step or a click still does.
-- This character's, in MedalUICharDB.guideIgnored (quest id -> true).
local function Ignores()
    MedalUICharDB = MedalUICharDB or {}
    MedalUICharDB.guideIgnored = MedalUICharDB.guideIgnored or {}
    return MedalUICharDB.guideIgnored
end
function G.Ignored(e)
    return e ~= nil and e.pick and Ignores()[e.id] == true or false
end
function G.Ignore(e)
    if not (e and e.pick) then return end
    local t = Ignores()
    t[e.id] = not t[e.id] or nil
end

-- the head: the one stepped to; else the first the waypoint may go to by itself
function G.Head(list)
    list = list or order
    for _, e in ipairs(list) do
        if focus and EntryKey(e) == focus then return e end
    end
    for _, e in ipairs(list) do
        if not G.Ignored(e) then return e end
    end
end

-- where a step goes from: the one stepped to; else cur (the tab's row the
-- waypoint is at: the player's own, say); else the head
local function From(cur)
    local i = Place(focus)
    if i then return i end
    for n, e in ipairs(order) do if e == cur then return n end end
    return 1
end

function G.CanNext(cur) return From(cur) < #order end
function G.CanBack(cur) return #order > 0 and From(cur) > 1 end

-- the waypoint a row down the list, or up (the list drawn again by the caller)
local function Step(cur, by)
    local e = order[From(cur) + by]
    if not e then return false end
    focus, claim = EntryKey(e), true
    return true
end
function G.Next(cur) return Step(cur, 1) end
function G.Back(cur) return Step(cur, -1) end

-- ----------------------------------------------------------- the waypoint
-- What the Guide set last: { quest } or { map, x, y }. The waypoint is the
-- Guide's to move while it is that, or none; one the player set is theirs.
--
-- (2026-11-23, a C stack overflow in game) Never written from inside a
-- waypoint event: the game fires USER_WAYPOINT_UPDATED and
-- SUPER_TRACKING_CHANGED while a waypoint is being set, part way through
-- (the old one cleared, the new one not yet pointed to). Read then, the
-- waypoint looks like none, so the Guide set its own, whose events came
-- back to it before that call had returned, without end; and a waypoint
-- the player was moving to another quest was taken back. So Steer only
-- says what the Guide would point to; Settle decides a frame later, when
-- the game is done. A waypoint that is not the Guide's is the player's (or
-- the game's): the Guide yields until it is cleared. A target the game
-- would not keep is not set again until the head moves.
local mine, want, tried, wroteAt
local yielded, foreign, pending = false, false, false
local REFUSED = 1               -- seconds: a clear this soon after a write is the game refusing it

local function Now() return GetTime and GetTime() or 0 end

local function Key(e)
    if not e then return nil end
    if e.pick then
        local p = e.guide.where
        return p and ("p" .. p.map .. ":" .. p.x .. ":" .. p.y)
    end
    return "q" .. e.id
end

local function Settle()
    pending = false
    local W = ns.waypoint
    if not (W and W.Has()) then return end
    local wq, pm = W.Quest(), W.PointAt()
    local any = wq ~= nil or pm ~= nil
    local ours = mine and (mine.quest and wq == mine.quest
        or mine.map and W.IsPoint(mine.map, mine.x, mine.y)) or false
    if foreign then
        foreign = false
        if not any then
            yielded = false
            -- cleared by the player: the Guide may point again; cleared at
            -- once after the Guide's write: the game would not keep it
            if Now() - (wroteAt or -REFUSED) > REFUSED then tried = nil end
        end
    end
    -- a step taken: the waypoint is the Guide's again, whoever set it
    if claim then
        claim, yielded, tried, ours = false, false, nil, true
    end
    local e = want
    if yielded or not (ns.db.zoneGuideWaypoint and e) then return end
    if any and not ours then
        yielded, mine, focus = true, nil, nil   -- someone else's (no step taken holds)
        return
    end
    local key = Key(e)
    if not key or key == tried then return end
    if e.pick then
        local p = e.guide.where
        if W.IsPoint(p.map, p.x, p.y) then return end
        -- (named first: the game's events from the write, looked at a
        -- frame later, find it the Guide's)
        tried, wroteAt, mine = key, Now(), { map = p.map, x = p.x, y = p.y }
        pcall(W.Point, p.map, p.x, p.y)
    else
        if wq == e.id then return end
        tried, wroteAt, mine = key, Now(), { quest = e.id }
        pcall(W.Set, e.id)
    end
end
G.Settle = Settle

local function Soon()
    if pending then return end
    pending = true
    if C_Timer and C_Timer.After then C_Timer.After(0, Settle) else Settle() end
end

-- the entry the waypoint should be at (the list's head), set a frame later
function G.Steer(e)
    want = e
    if Key(e) ~= tried or foreign or claim then Soon() end
end

-- any change, the Guide's own too: looked at a frame later
if ns.waypoint then
    ns.waypoint.OnChange(function()
        foreign = true
        Soon()
    end)
end

-- forgotten with the plan: a new character's, a reload's
function G.Mine() return mine end
function G.Yielded() return yielded end

-- --------------------------------------------------------------- suggest
-- The nearest map on this continent whose quests' middle level is yours:
-- its name (from the maps the index has seen)
function G.Suggest()
    if not DB() then return nil end
    local level = UnitLevel and UnitLevel("player")
    local cont, wx, wy = Me()
    if not cont or type(level) ~= "number" then return nil end
    Index(cont)
    local best, bd
    for map, middle in pairs(middles) do
        if math.abs(middle - level) <= 2 then
            local c, mx, my = World(map, 50, 50)
            if c == cont then
                local d = (mx - wx) ^ 2 + (my - wy) ^ 2
                if not bd or d < bd then best, bd = map, d end
            end
        end
    end
    local info = best and C_Map.GetMapInfo and C_Map.GetMapInfo(best)
    return info and info.name
end

-- (the harness's way back to a first look)
function G.Reset()
    db, areas, spotsOf, workOf, index, middles = nil, nil, {}, {}, {}, {}
    rank, lead, last, mine, seen, handed = {}, nil, {}, nil, {}, {}
    want, tried, wroteAt, yielded, foreign, pending = nil, nil, nil, false, false, false
    focus, claim, order = nil, false, {}
end

-- what can be taken changes with what was handed in, and with your level
ns.On("PLAYER_LEVEL_UP", function() lead = nil end)
ns.On("QUEST_TURNED_IN", function(_, id) if type(id) == "number" then handed[id] = true end end)
