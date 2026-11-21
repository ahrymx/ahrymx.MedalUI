-- What the quest tracker (quests/tracker.lua) shows: the quests in the log
-- that are tracked, each with its zone heading, level, state, objectives
-- and usable item.
--
-- The game's own quest log is the source. Questie, when it is loaded and
-- ready, is asked too, so the two trackers agree: which quests are tracked
-- (Questie keeps its own set), the items its database knows a quest needs,
-- and its quest log, focus and arrow. Questie's tracker itself is left
-- alone; its own options show it.
--
-- Questie is never needed. Its modules are its internals, not its API, so
-- every call is made through pcall, and a call that fails answers as if
-- Questie were not there.
local _, ns = ...
local Tr = ns.L

local Q = {}
ns.questSource = Q

-- A call that may fail: its first two answers, or nothing.
local function Try(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

-- Questie's modules, once it is ready; nothing otherwise.
local modules
local function Questie()
    if modules then return modules end
    local Q_ = _G.Questie
    if not (QuestieLoader and Q_ and Q_.API and Q_.API.isReady) then return end
    local function Import(name) return Try(QuestieLoader.ImportModule, QuestieLoader, name) end
    local tracker, utils, data = Import("QuestieTracker"), Import("TrackerUtils"), Import("TrackerData")
    if not (tracker and utils and data) then return end
    modules = { tracker = tracker, utils = utils, data = data }
    return modules
end
Q.Questie = Questie

-- Questie's record of a quest, for its own calls.
local function Record(id)
    local m = Questie()
    return m and Try(m.data.GetQuest, id)
end

-- Questie keeps the tracked set only while its own tracker is on. Off, it
-- no longer hears the quest log's track box (its watch hooks return early),
-- so its set goes stale and the game's watch is the truth.
local function Keeps()
    local Q_ = _G.Questie
    local db = type(Q_) == "table" and type(Q_.db) == "table" and Q_.db
    local profile = db and type(db.profile) == "table" and db.profile
    return profile and profile.trackerEnabled and Questie() or nil
end

local function Tracked(id)
    local m = Keeps()
    if m then
        local on = Try(m.tracker.IsTrackedByQuestie, id)
        if on ~= nil then return on and true or false end
    end
    return C_QuestLog.GetQuestWatchType(id) ~= nil
end

-- The usable item: the game's own for the quest, else Questie's first.
local function Item(index, id, state)
    if GetQuestLogSpecialItemInfo then
        local link, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(index)
        local item = link and tonumber(link:match("item:(%d+)"))
        if item and (state ~= 1 or showWhenComplete) then return item end
    end
    local m, record = Questie(), Record(id)
    if m and record then
        local items = Try(m.utils.GetQuestItemIds, record, state)
        if type(items) == "table" and items[1] then return items[1] end
    end
end

-- What sort of quest: "dungeon" (a dungeon's or a raid's), "group" (for a
-- group, or elite), or nothing. The tag is the game's: C_QuestLog's where
-- the client has it, the global's otherwise.
-- raid, dungeon, heroic, raid 10 and 25
local INSTANCE = { [62] = true, [81] = true, [85] = true, [88] = true, [89] = true }
local function Kind(id, info)
    local tag, elite
    if C_QuestLog.GetQuestTagInfo then
        local t = C_QuestLog.GetQuestTagInfo(id)
        tag, elite = t and t.tagID, t and t.isElite
    elseif GetQuestTagInfo then
        tag = GetQuestTagInfo(id)
    end
    if INSTANCE[tag] then return "dungeon" end
    if tag == 1 or elite or (info.suggestedGroup or 0) > 1 then return "group" end
end

-- The quests that keep(id) takes, in the log's order: { id, index, title,
-- level, zone, state (1 complete, -1 failed, 0), objectives { text, done },
-- item, daily (daily or weekly), kind (Kind's) }.
local function Walk(keep)
    local out, zone = {}, nil
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then
            zone = info.title
        elseif info and info.questID and not info.isHidden and keep(info.questID) then
            local id = info.questID
            local state = C_QuestLog.IsFailed(id) and -1 or C_QuestLog.IsComplete(id) and 1 or 0
            local objectives = {}
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
                if o.text and o.text ~= "" then
                    table.insert(objectives, { text = o.text, done = o.finished, kind = o.type })
                end
            end
            table.insert(out, { id = id, index = index, title = info.title, level = info.level or 0,
                zone = zone or Tr["Other"], state = state, objectives = objectives, item = Item(index, id, state),
                daily = (info.frequency or 0) > 0, kind = Kind(id, info) })
        end
    end
    return out
end

-- The tracked quests (the tracker's).
function Q.Read() return Walk(Tracked) end

-- ---------------------------------------------------------- the whole log
-- The quest log's reward calls read the quest it has selected (Classic's
-- take no quest at all; retail's take the id too): so the quest is selected
-- for them, and the selection put back after.
local function Selected()
    if C_QuestLog.GetSelectedQuest then return C_QuestLog.GetSelectedQuest() end
    return GetQuestLogSelection and GetQuestLogSelection()
end

local function Select(q)
    if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(q.id) end
    if SelectQuestLogEntry then SelectQuestLogEntry(q.index) end
end

local function Restore(was)
    if not was then return end
    if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(was) end
    if SelectQuestLogEntry and not C_QuestLog.GetSelectedQuest then SelectQuestLogEntry(was) end
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return fn(...)
end

-- What a quest gives: xp, money (copper), items (any to have or to choose).
-- They do not change while the quest is in the log, but for the xp as the
-- player levels, so they are kept until then.
local rewards = {}
local function Rewards(q)
    local r = rewards[q.id]
    if r then return r end
    local was = Selected()
    Select(q)
    local given = Call(GetNumQuestLogRewards, q.id) or 0
    local chosen = Call(GetNumQuestLogChoices, q.id) or 0
    r = { xp = Call(GetQuestLogRewardXP, q.id) or 0, money = Call(GetQuestLogRewardMoney, q.id) or 0,
        items = given + chosen > 0 }
    Restore(was)
    rewards[q.id] = r
    return r
end
ns.On("PLAYER_LEVEL_UP", function() wipe(rewards) end)
local details

-- Every quest in the log, each as Read's, with tracked and rewards.
function Q.All()
    local out = Walk(function() return true end)
    for _, q in ipairs(out) do
        q.tracked = Tracked(q.id)
        q.rewards = Rewards(q)
    end
    return out
end

-- Every quest in the log, each as Read's, with tracked: All's without the
-- rewards, which select each quest in turn (the side panel's Zone tab,
-- strips/zone.lua, reads it on every change).
function Q.Log()
    local out = Walk(function() return true end)
    for _, q in ipairs(out) do q.tracked = Tracked(q.id) end
    return out
end

-- A quest's page: { text, goal (the objectives' summary), given, chosen },
-- each reward item { name, icon, count, quality, link, index, type }. Kept
-- as the rewards are: selecting a quest may tell the log it changed, and
-- the page drawn again must not select it again.
details = {}
function Q.Details(q)
    if details[q.id] then return details[q.id] end
    local was = Selected()
    Select(q)
    local d = { given = {}, chosen = {} }
    if GetQuestLogQuestText then d.text, d.goal = GetQuestLogQuestText(q.index) end
    local kinds = { { "given", GetNumQuestLogRewards, "reward" }, { "chosen", GetNumQuestLogChoices, "choice" } }
    for _, kind in ipairs(kinds) do
        for i = 1, Call(kind[2], q.id) or 0 do
            local name, icon, count, quality
            if kind[3] == "reward" then
                name, icon, count, quality = Call(GetQuestLogRewardInfo, i, q.id)
            else
                name, icon, count, quality = Call(GetQuestLogChoiceInfo, i, q.id)
            end
            if name then
                table.insert(d[kind[1]], { name = name, icon = icon, count = count or 1, quality = quality,
                    link = Call(GetQuestLogItemLink, kind[3], i, q.id), index = i, type = kind[3] })
            end
        end
    end
    Restore(was)
    details[q.id] = d
    return d
end

-- -------------------------------------------------------------- actions
-- The quest's page: Medalluin's own (quests/page.lua) while its quest log
-- is on; else the quest log, Questie's way when it is there (it knows the
-- log addons), the game's otherwise; not in combat.
function Q.Show(quest)
    if ns.questPage and ns.questLog and ns.questLog.On() then
        ns.questPage.Open(quest.id)
        return
    end
    local m, record = Questie(), Record(quest.id)
    if m and record and pcall(m.utils.ShowQuestLog, m.utils, record) then return end
    if InCombatLockdown() then return end
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(quest.id)
    elseif QuestLogFrame then
        C_QuestLog.SetSelectedQuest(quest.id)
        ShowUIPanel(QuestLogFrame)
    end
end

-- Questie's focus on the quest and its arrow to it; false when it cannot
function Q.Focus(quest)
    local m = Questie()
    if not (m and pcall(m.utils.FocusQuest, m.utils, quest.id)) then return false end
    Try(m.utils.SetQuestTomTomTarget, quest.id)
    return true
end

-- Questie's own page for any quest, in its log or not: its Journey's
-- search, at the quest, as Questie's own quest links open it. Started,
-- not ready: the Journey needs only Questie loaded.
local function Journey()
    local Q_ = _G.Questie
    if not (QuestieLoader and type(Q_) == "table" and Q_.started) then return end
    local journey = Try(QuestieLoader.ImportModule, QuestieLoader, "QuestieJourney")
    local results = Try(QuestieLoader.ImportModule, QuestieLoader, "QuestieSearchResults")
    if journey and results then return journey, results end
end

function Q.CanShowInQuestie() return Journey() ~= nil end

function Q.ShowInQuestie(id)
    local journey, results = Journey()
    if not journey then return false end
    return pcall(function()
        if not journey:IsShown() then journey:ToggleJourneyWindow() end
        journey.tabGroup:SelectTab("search")
        results:SetSearch("quest", id)
    end) and true or false
end

-- An objective's count, "3/10" anywhere in its text; one with none counts
-- as one thing, done or not. Its words without the count. (The Zone tab's
-- rows and the quest's page.)
function Q.Count(o)
    local have, need = o.text:match("(%d+)%s*/%s*(%d+)")
    if have then return tonumber(have), tonumber(need) end
    return o.done and 1 or 0, 1
end

function Q.Words(o)
    local s = o.text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub(":?%s*%d+%s*/%s*%d+%s*$", "")
    return s
end

-- ------------------------------------------------------------- the map
-- A zone's map, by its name (the log's heading for the quest): every map
-- under the world the player is in, a zone's first. Kept once read from
-- the whole world; read again while only a continent's (or less) is known.
local maps, whole
local function MapByName(name)
    if not (name and C_Map and C_Map.GetMapChildrenInfo) then return end
    if not whole then
        local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            or C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID()
        if not here then return end
        local top = here
        local T = Enum and Enum.UIMapType
        if MapUtil and MapUtil.GetMapParentInfo and T then
            local world = MapUtil.GetMapParentInfo(here, T.Cosmic, true)
                or MapUtil.GetMapParentInfo(here, T.World, true)
            local info = world or MapUtil.GetMapParentInfo(here, T.Continent, true)
            if info and info.mapID then top = info.mapID end
            whole = world ~= nil
        end
        maps = {}
        local zone = T and T.Zone
        for _, m in ipairs(C_Map.GetMapChildrenInfo(top, nil, true) or {}) do
            local had = maps[m.name]
            if m.name and (not had or (m.mapType == zone and had.mapType ~= zone)) then maps[m.name] = m end
        end
    end
    return maps[name] and maps[name].mapID
end

-- The quest's map: the game's own for it (retail), else its zone's.
function Q.MapOf(quest)
    local id = GetQuestUiMapID and Try(GetQuestUiMapID, quest.id)
    if id and id > 0 then return id end
    return MapByName(quest.zone)
end

-- Questie's places for the quest: its objectives not yet done, or, ready
-- to hand in, who takes it; nil when it knows none.
local function Places(quest)
    local m, record = Questie(), Record(quest.id)
    if not (m and record) then return end
    if quest.state == 1 then
        if record.Finisher and m.utils.ShowFinisherOnMap then return m, record end
        return
    end
    local list = {}
    for _, set in ipairs({ record.Objectives or {}, record.SpecialObjectives or {} }) do
        for _, o in pairs(set) do
            if type(o) == "table" and not o.Completed and type(o.spawnList) == "table" and next(o.spawnList) then
                table.insert(list, o)
            end
        end
    end
    if #list > 0 then return m, nil, list end
end

-- Whether the map can show it.
function Q.CanMap(quest)
    return Places(quest) ~= nil or Q.MapOf(quest) ~= nil
end

-- The world map at the quest: Questie's way when it knows the places (the
-- nearest's zone, its icons flashing), else the quest's map (retail pings
-- the quest on it). True when the map was opened.
function Q.ShowOnMap(quest)
    local m, finisher, list = Places(quest)
    local u = m and m.utils
    if finisher and pcall(u.ShowFinisherOnMap, u, finisher) then return true end
    if list then
        local ok
        if u.ShowQuestObjectivesOnMap then
            ok = pcall(u.ShowQuestObjectivesOnMap, u, list)
        else
            ok = pcall(u.ShowObjectiveOnMap, u, list[1])
        end
        if ok then return true end
    end
    local id = Q.MapOf(quest)
    if not (id and WorldMapFrame) then return false end
    if OpenWorldMap then
        OpenWorldMap(id)
    else
        if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
        WorldMapFrame:SetMapID(id)
    end
    if WorldMapFrame.PingQuestID then Try(WorldMapFrame.PingQuestID, WorldMapFrame, quest.id) end
    return true
end

-- ------------------------------------------------------------ distance
-- From you to the quest's nearest objective marker on the game's map, in
-- yards: the game's own measure (as the waypoint's, quests/waypoint.lua,
-- less its navigation's). nil: no marker, another continent, or secret.
function Q.Distance(id)
    local sq = C_QuestLog and C_QuestLog.GetDistanceSqToQuest
    if not sq or type(id) ~= "number" then return nil end
    local ok, d2, near = pcall(sq, id)
    if not ok or d2 == nil or ns.IsSecret(d2) or ns.IsSecret(near) or not near then return nil end
    if type(d2) ~= "number" or d2 < 0 then return nil end
    return math.sqrt(d2)
end

-- The quests nearest first, for the tracker and the Zone tab. A distance
-- counts in steps of STEP yards, and quests in one step keep the order they
-- had (rank: id -> place, the last call's), so walking does not swap two
-- quests about each tick; then by title. Those without a distance come
-- after, by level. frozen (in combat): the last order only, no distances;
-- a quest new to it goes last.
-- Gives the list, its ranks (for the next call), and whether it moved.
local STEP = 10
Q.DISTANCE_STEP = STEP
function Q.ByDistance(list, rank, frozen)
    rank = rank or {}
    local key = {}
    for _, q in ipairs(list) do
        local d = not frozen and Q.Distance(q.id)
        key[q] = d and math.floor(d / STEP) or false
    end
    local out = {}
    for i, q in ipairs(list) do out[i] = q end
    local huge = math.huge
    table.sort(out, function(a, b)
        local ka, kb = key[a], key[b]
        if (ka == false) ~= (kb == false) then return kb == false end
        if ka and ka ~= kb then return ka < kb end
        if not ka and not frozen and (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        local ra, rb = rank[a.id] or huge, rank[b.id] or huge
        if ra ~= rb then return ra < rb end
        if a.title ~= b.title then return tostring(a.title) < tostring(b.title) end
        return a.id < b.id
    end)
    local now, moved, n = {}, false, 0
    for i, q in ipairs(out) do
        now[q.id] = i
        if rank[q.id] ~= i then moved = true end
    end
    for _ in pairs(rank) do n = n + 1 end
    if n ~= #out then moved = true end
    return out, now, moved
end

-- A right click on a quest on the world map opens its page (Q.Show): the
-- game's quest pins and Questie's icons both let right clicks through to
-- the map (where they zoom out), so the map's own click handlers are where
-- it is caught, the quest found among the frames under the mouse. Only a
-- quest in the log is taken; any other right click zooms out as before.
local MAP_PRIORITY = 100                        -- over the game's own (the waypoint's is 90)

-- the quest of a frame under the mouse, or of its parents (a pin's parts)
local function QuestOf(f)
    for _ = 1, 3 do
        if type(f) ~= "table" then return nil end
        local data = rawget(f, "data")
        if type(data) == "table" and type(data.Id) == "number" and data.QuestData then return data.Id end
        local get = f.GetQuestID
        if type(get) == "function" then
            local ok, id = pcall(get, f)
            if ok and type(id) == "number" and not ns.IsSecret(id) and id > 0 then return id end
        end
        f = f.GetParent and f:GetParent()
    end
end

function Q.MapQuestAtMouse()
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    for _, f in ipairs(foci or {}) do
        local id = QuestOf(f)
        if id then
            for _, q in ipairs(Q.All()) do
                if q.id == id then return q end
            end
        end
    end
end

local mapHooked
local function MapClicks()
    local map = WorldMapFrame
    if mapHooked or not (map and map.AddCanvasClickHandler) then return end
    mapHooked = true
    map:AddCanvasClickHandler(function(_, button)
        if button ~= "RightButton" then return false end
        local ok, q = pcall(Q.MapQuestAtMouse)
        if not (ok and q) then return false end
        Q.Show(q)
        return true
    end, MAP_PRIORITY)
end
Q.MapClicks = MapClicks
ns.On("PLAYER_LOGIN", MapClicks)
ns.On("ADDON_LOADED", MapClicks)

-- How many quests the game lets be watched at once (none known: no limit).
function Q.WatchLimit()
    if C_QuestLog.GetMaxNumQuestsCanWatch then return C_QuestLog.GetMaxNumQuestsCanWatch() end
    return MAX_WATCHABLE_QUESTS
end

-- How many the game watches now.
local function Watched()
    if C_QuestLog.GetNumQuestWatches then return C_QuestLog.GetNumQuestWatches() end
    if GetNumQuestWatches then return GetNumQuestWatches() end
    local n = 0
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.questID and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then n = n + 1 end
    end
    return n
end

-- Tracked by the game's watch, which Questie hears too while it keeps its
-- own set (its watch hooks); false when the game's limit is reached.
function Q.Track(quest)
    if Tracked(quest.id) then return true end
    local limit = Q.WatchLimit()
    if limit and Watched() >= limit then return false end
    if C_QuestLog.AddQuestWatch then
        C_QuestLog.AddQuestWatch(quest.id)
    elseif AddQuestWatch then
        AddQuestWatch(quest.index)
    end
    return true
end

Q.Tracked = Tracked

-- The quests abandoned, one by one: each selected, marked and dropped. The
-- log's indices move as quests go, so each is found again by its id.
local function Index(id)
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.questID == id then return index end
    end
end

function Q.Abandon(ids)
    for _, id in ipairs(ids) do
        local index = Index(id)
        if index then
            if C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
                C_QuestLog.SetSelectedQuest(id)
                C_QuestLog.SetAbandonQuest()
                C_QuestLog.AbandonQuest()
            elseif SetAbandonQuest and AbandonQuest then
                if SelectQuestLogEntry then SelectQuestLogEntry(index) end
                if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id) end
                SetAbandonQuest()
                AbandonQuest()
            end
            rewards[id] = nil
            details[id] = nil
        end
    end
end

-- Whether a quest can be shared now, and its sharing.
function Q.CanShare(quest)
    if not (IsInGroup and IsInGroup()) then return false end
    if C_QuestLog.IsPushableQuest then return C_QuestLog.IsPushableQuest(quest.id) and true or false end
    if GetQuestLogPushable then
        local was = Selected()
        Select(quest)
        local can = GetQuestLogPushable()
        Restore(was)
        return can and true or false
    end
    return false
end

function Q.Share(quest)
    local was = Selected()
    Select(quest)
    if QuestLogPushQuest then QuestLogPushQuest() end
    Restore(was)
end

-- No longer tracked: Questie's untrack when Questie keeps the set and tracks
-- it, the game's watch otherwise.
function Q.Untrack(quest)
    local m = Keeps()
    if m and Try(m.tracker.IsTrackedByQuestie, quest.id) then
        Try(m.tracker.UntrackQuestId, m.tracker, quest.id)
    elseif C_QuestLog.GetQuestWatchType(quest.id) ~= nil then
        C_QuestLog.RemoveQuestWatch(quest.id)
    end
end

-- ---------------------------------------------------------------- clicks
-- One set of clicks on a quest, in the tracker, the quest log and the side
-- panel's Zone tab alike (2026-11-15):
--   click          its page (quests/page.lua; the game's log while ours is off)
--   Shift-click    a link to it in chat
--   Ctrl-click     the waypoint to it, or cleared (while there is one to set)
--   Alt-click      focused, with Questie's arrow (with Questie)
--   right click    tracked, or no longer
--   middle click   the world map at it
-- Q.Keys gives them as the tooltips' key lines (core.lua's "key" part).
function Q.Page(quest)
    if ns.questPage and ns.questLog and ns.questLog.On() then
        ns.questPage.Toggle(quest.id)
    else
        Q.Show(quest)
    end
end

local function Linking()
    if IsModifiedClick then return IsModifiedClick("CHATLINK") end
    return IsShiftKeyDown()
end

-- a quest linked in chat (core.lua)
function Q.LinkInChat(link) ns.LinkInChat(link) end

-- tracked: the field the log's quests carry, or asked (the tracker's, from Read)
local function IsTracked(quest)
    if quest.tracked ~= nil then return quest.tracked end
    return Tracked(quest.id) and true or false
end

-- what a click did: "track" when it tracked or stopped tracking, so a list
-- may draw again at once
function Q.Click(quest, mouse)
    local WP = ns.waypoint
    if mouse == "MiddleButton" then
        Q.ShowOnMap(quest)
    elseif mouse == "RightButton" then
        if IsTracked(quest) then Q.Untrack(quest) else Q.Track(quest) end
        return "track"
    elseif Linking() and GetQuestLink then
        Q.LinkInChat(GetQuestLink(quest.id))
    elseif IsControlKeyDown() and WP and WP.Has() then
        WP.Toggle(quest)
    elseif IsAltKeyDown() and Q.Focus(quest) then
        return
    else
        Q.Page(quest)
    end
end

-- An objective as a line for the chat ("0/1 Old Murk-Eye slain"): its
-- count first, as the quest page's chat button puts it (quests/page.lua)
function Q.ObjectiveLine(o)
    if not o.text:match("%d+%s*/%s*%d+") then return o.text end
    local have, need = Q.Count(o)
    return have .. "/" .. need .. " " .. Q.Words(o)
end

-- An objective's row clicks as its quest's, but a Shift-click puts the
-- objective's line in the chat box, not the quest's link
function Q.ClickObjective(quest, o, mouse)
    if o and ns.Linking(mouse) then
        Q.LinkInChat(Q.ObjectiveLine(o))
        return
    end
    return Q.Click(quest, mouse)
end

-- objective: the row is one of the quest's objectives (Shift puts it in chat)
function Q.Keys(quest, objective)
    local WP = ns.waypoint
    -- a word each, in the tooltip's grid of two by three, each in its place:
    -- one that does nothing here leaves its slot empty ({ "key" })
    local none = { "key" }
    return {
        { "key", "left", nil, Tr["Page"] },
        { "key", "left", "Shift", objective and Tr["Objective"] or Tr["Link"] },
        WP and WP.Has() and { "key", "left", "Ctrl", Tr["Waypoint"] } or none,
        Questie() and { "key", "left", "Alt", Tr["Focus"] } or none,
        { "key", "right", nil, IsTracked(quest) and Tr["Untrack"] or Tr["Track"] },
        Q.CanMap(quest) and { "key", "middle", nil, Tr["Map"] } or none,
    }
end

-- -------------------------------------------------------------- changes
-- fn() whenever what Read returns may have changed: the game's quest
-- events, and Questie's own updates (its tracked set lives in Questie).
function Q.Listen(fn)
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED",
        "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED" }) do
        ns.On(e, fn)
    end
    local Q_ = _G.Questie
    if Q_ and Q_.API and Q_.API.RegisterOnReady then
        Try(Q_.API.RegisterOnReady, function()
            modules = nil
            Try(Q_.API.RegisterForQuestUpdates, function() fn() end)
            local m = Questie()
            if m then Try(hooksecurefunc, m.tracker, "Update", function() fn() end) end
            fn()
        end)
    end
end
