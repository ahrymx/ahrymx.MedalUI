-- A quest's chain from QuestieDB, when it is installed: the quest's page
-- (quests/page.lua) asks the game first (C_QuestLine), and this when the
-- game cannot say, as on Forever for every Classic quest. Read at run
-- time only (## OptionalDeps), nothing of it copied.
--
-- The chain is walked back through each quest's prerequisites and on
-- through its next quest. Where a quest has several (one per race, or a
-- choice of two), the one the player did is taken, else one the player
-- can take, else the first. A next quest the player cannot take ends it.
--
--   ns.questChains.Of(id)     { ids, at }; false: known, alone; nil: unknown
--   ns.questChains.Title(id)  its name in QuestieDB, or nil
--   ns.questChains.Level(id)  its level in QuestieDB, or nil
--   ns.questChains.XP(id)     its xp at the player's level (QuestieDB's quest
--                             xp table, scaled as the game scales it), or nil
--   ns.questChains.Fits(id)   whether your race and class may take it (true
--                             when QuestieDB cannot say)
local _, ns = ...

local qc = {}
ns.questChains = qc

local CONTRACT = 4                      -- the QuestieDB contract this was written against
local MOST = 50                         -- steps walked each way, at most
local floor = math.floor

local cache = {}

local function DB()
    local lib = _G.LibQuestieDB
    local db = _G.QuestDB
    if not (lib and db and lib.RequireContract and db.Get and db.Exists) then return nil end
    if not lib.RequireContract(CONTRACT) then return nil end
    return db
end

local function Get(db, id, key)
    local ok, v = pcall(db.Get, id, key)
    if ok then return v end
end

-- whether bit n (1-based) is set in a mask; by arithmetic, as race masks
-- run past the 32 bits bit.band keeps
local function Has(mask, n)
    return floor(mask / 2 ^ (n - 1)) % 2 == 1
end
qc.Has = Has

local function Fits(db, id)
    local race = UnitRace and select(3, UnitRace("player"))
    local class = UnitClass and select(3, UnitClass("player"))
    local races = Get(db, id, "requiredRaces")
    local classes = Get(db, id, "requiredClasses")
    if type(races) == "number" and races > 0 and type(race) == "number" and not Has(races, race) then return false end
    if type(classes) == "number" and classes > 0 and type(class) == "number" and not Has(classes, class) then
        return false
    end
    return true
end

-- whether the player's race and class may take it (the Guide's, quests/guide.lua)
function qc.Fits(id)
    local db = DB()
    if not db then return true end
    return Fits(db, id)
end

local function Done(id)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) and true
        or false
end

-- the one of several the player did, else could take, else the first
local function Choose(db, list)
    if type(list) ~= "table" or #list == 0 then return nil end
    for _, q in ipairs(list) do
        if Done(q) then return q end
    end
    for _, q in ipairs(list) do
        if Fits(db, q) then return q end
    end
    return list[1]
end

local function Walk(db, id)
    local seen = { [id] = true }
    local back = {}
    local q = id
    for _ = 1, MOST do
        local pre = Choose(db, Get(db, q, "preQuestSingle")) or Choose(db, Get(db, q, "preQuestGroup"))
        if not pre or seen[pre] or not db.Exists(pre) then break end
        seen[pre] = true
        table.insert(back, 1, pre)
        q = pre
    end
    local ids = back
    table.insert(ids, id)
    local at = #ids
    q = id
    for _ = 1, MOST do
        local nxt = Get(db, q, "nextQuestInChain")
        if type(nxt) ~= "number" or nxt == 0 or seen[nxt] or not db.Exists(nxt) or not Fits(db, nxt) then break end
        seen[nxt] = true
        table.insert(ids, nxt)
        q = nxt
    end
    if #ids < 2 then return false end
    return { ids = ids, at = at }
end

function qc.Of(id)
    if type(id) ~= "number" or ns.IsSecret(id) then return nil end
    local db = DB()
    if not db or not db.Exists(id) then return nil end
    local c = cache[id]
    if c == nil then
        c = Walk(db, id)
        cache[id] = c
    end
    return c
end

function qc.Title(id)
    local db = DB()
    if not db then return nil end
    local name = Get(db, id, "name")
    return type(name) == "string" and name ~= "" and name or nil
end

function qc.Level(id)
    local db = DB()
    if not db then return nil end
    local level = Get(db, id, "questLevel")
    return type(level) == "number" and level > 0 and level or nil
end

-- QuestieDB's quest xp table: id -> { level, xp at that level or below }
local function XPTable()
    if not DB() then return nil end
    local support = _G.LibQuestieDB.Support
    local ok, mod = pcall(function() return support and support.Get("QuestXP") end)
    return ok and type(mod) == "table" and type(mod.db) == "table" and mod.db or nil
end

-- As the game gives it: whole up to five levels over the quest's, a fifth
-- less each level past that, a tenth at least; none at the top level.
-- Rounded as the game rounds it: to 5, 10, 25 or 50 as it grows.
function qc.Scale(xp, questLevel, level, top)
    if top and level >= top then return 0 end
    local factor = math.max(1, math.min(10, 2 * (questLevel - level) + 20))
    xp = xp * factor / 10
    if xp <= 100 then return 5 * floor((xp + 2) / 5)
    elseif xp <= 500 then return 10 * floor((xp + 5) / 10)
    elseif xp <= 1000 then return 25 * floor((xp + 12) / 25) end
    return 50 * floor((xp + 25) / 50)
end

function qc.XP(id)
    local db = XPTable()
    local row = db and db[id]
    if type(row) ~= "table" or type(row[1]) ~= "number" or type(row[2]) ~= "number" or row[2] <= 0 then return nil end
    local level = UnitLevel and UnitLevel("player")
    if type(level) ~= "number" or ns.IsSecret(level) then return nil end
    local xp = qc.Scale(row[2], row[1], level, GetMaxPlayerLevel and GetMaxPlayerLevel())
    return xp > 0 and xp or nil
end

-- a quest handed in can change which of several the walk takes
ns.On("QUEST_TURNED_IN", function() cache = {} end)
