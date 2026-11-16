local _, ns = ...

--------------------------------------------------
-- IMPORT FROM FLAREUI
-- FlareUI keeps its radials in FlareUI2_DB.global.radialmenu, in the same shape as ours, and each
-- character's own keys in FlareUI2_DB.global.characters[GUID]. The game loads FlareUI2_DB only while
-- FlareUI is enabled. An import adds copies after the radials already here: new ids for the radials
-- and groups, sub-radials pointed at the copies. FlareUI's tables are only read.
--------------------------------------------------

-- FlareUI's radial store and its global table, or nil when it has no radials
function ns.FlareRadialStore()
    local db = _G.FlareUI2_DB
    local global = type(db) == "table" and type(db.global) == "table" and db.global
    local store = global and type(global.radialmenu) == "table" and global.radialmenu
    if not store then return nil end
    local radials = store.radials or store.rings   -- (FlareUI's older names)
    if type(radials) ~= "table" or not next(radials) then return nil end
    return store, global
end

-- how many radials an import would add
function ns.FlareRadialCount()
    local store = ns.FlareRadialStore()
    if not store then return 0 end
    local count = 0
    for _, data in pairs(store.radials or store.rings) do
        if type(data) == "table" then count = count + 1 end
    end
    return count
end

-- FlareUI's radial ids in its list order, then any the order missed
local function OrderOf(from)
    local radials = from.radials or from.rings
    local ids, seen = {}, {}
    for _, id in ipairs(from.radialOrder or from.ringOrder or {}) do
        if type(radials[id]) == "table" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    local rest = {}
    for id, data in pairs(radials) do
        if type(data) == "table" and not seen[id] then rest[#rest + 1] = id end
    end
    table.sort(rest, function(a, b) return tostring(a) < tostring(b) end)
    for _, id in ipairs(rest) do ids[#ids + 1] = id end
    return ids
end

-- Adds FlareUI's radials, groups and per-character keys. The number added, or nil and why
-- ("none", "combat", "nostore").
function ns.ImportFromFlare()
    local from, fromGlobal = ns.FlareRadialStore()
    if not from then return nil, "none" end
    if InCombatLockdown() then return nil, "combat" end
    local RM = ns.RadialMenu
    local store = RM.GetStore()
    if not store then return nil, "nostore" end
    local radials = from.radials or from.rings
    local ids = OrderOf(from)

    local map = {}
    for _, old in ipairs(ids) do
        map[old] = "r" .. store.nextRadialID
        store.nextRadialID = store.nextRadialID + 1
    end

    -- the groups the imported radials use
    local groupMap = {}
    local fromGroups = type(from.groups) == "table" and from.groups or {}
    for _, old in ipairs(ids) do
        local gid = radials[old].group
        if gid ~= nil and not groupMap[gid] and type(fromGroups[gid]) == "table" then
            store.groups = store.groups or {}
            store.nextGroupID = store.nextGroupID or 1
            local new = "g" .. store.nextGroupID
            store.nextGroupID = store.nextGroupID + 1
            store.groups[new] = { name = fromGroups[gid].name or tostring(gid) }
            groupMap[gid] = new
        end
    end

    for _, old in ipairs(ids) do
        local data = CopyTable(radials[old])
        data.buttons = data.buttons or data.slices or {}
        data.slices = nil
        for _, entry in ipairs(data.buttons) do
            if entry.kind == "ring" then entry.kind, entry.radial, entry.ring = "subradial", entry.ring, nil end
            -- a sub-radial whose radial is gone keeps an id that resolves to nothing, as in FlareUI
            if entry.kind == "subradial" then entry.radial = map[entry.radial] or entry.radial end
        end
        data.group = data.group ~= nil and groupMap[data.group] or nil
        store.radials[map[old]] = data
        store.radialOrder[#store.radialOrder + 1] = map[old]
    end

    -- each character's own keys, and which groups it keeps closed
    local characters = type(fromGlobal.characters) == "table" and fromGlobal.characters or {}
    for guid, theirs in pairs(characters) do
        if type(theirs) == "table" then
            ns.db.global.characters = ns.db.global.characters or {}
            local ours = ns.db.global.characters[guid] or {}
            ns.db.global.characters[guid] = ours
            for id, key in pairs(type(theirs.radialKeyOverride) == "table" and theirs.radialKeyOverride or {}) do
                if map[id] then
                    ours.radialKeyOverride = ours.radialKeyOverride or {}
                    ours.radialKeyOverride[map[id]] = key
                end
            end
            for gid, closed in pairs(type(theirs.radialGroupsClosed) == "table" and theirs.radialGroupsClosed or {}) do
                if groupMap[gid] then
                    ours.radialGroupsClosed = ours.radialGroupsClosed or {}
                    ours.radialGroupsClosed[groupMap[gid]] = closed
                end
            end
        end
    end

    RM:RadialChanged()
    RM:AvailabilityChanged()
    return #ids
end
