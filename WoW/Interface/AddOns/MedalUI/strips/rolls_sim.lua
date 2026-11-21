-- The Rolls window's simulation: while "Simulate rolls" is on (with the
-- Roll window), simulated items drop and the window pops up as for a real
-- roll. Its choices work, and the group rolls on the items too: a member
-- answers every STEP seconds, the log tallying them, a leader then a winner.
-- A small panel on the right sets what drops:
--
--   Rolls        - n +   items to roll on at once
--   Transmog  Disenchant   the extra choices offered
--   Need refused  Raid     the first item refused a need; twenty members
--   [New rolls]            drop them again
--   [End simulation]
--
-- It stands in for the game's roll API through rolls.lua's door (ns.rolls.Use):
-- no global is touched, nothing is sent to the game, and a real roll keeps
-- working underneath (its ids are the game's, ours are below 0). Nothing here
-- is saved but the switch.
local _, ns = ...
local Tr = ns.L

local KIT = ns.simKit
local LENGTH = 60               -- seconds a roll lasts
local MAX = 4                   -- items at once
local WAIT, PASS = 4, 5         -- Enum.EncounterLootDropRollState: not chosen, passed
-- a choice made (RollOnLoot's type) as the history's state
local STATE = { [0] = PASS, [1] = 0, [2] = 3, [3] = 3, [4] = 2 }
-- the items, Molten Core's (Forever is Classic+: an item of a later expansion
-- is unknown to it, its icon and details blank): the game's own name, icon
-- and link once it has them; ours until then
local ITEMS = {
    { 17076, "Bonereaver's Edge" },
    { 17104, "Spinal Reaper" },
    { 18814, "Choker of the Fire Lord" },
    { 17063, "Band of Accuria" },
    { 18815, "Essence of the Pure Flame" },
}
-- the bosses, one a deal, in turn (their encounter ids below 0)
local BOSSES = { Tr["Lucifron"], Tr["Magmadar"], Tr["Gehennas"], Tr["Garr"], Tr["Baron Geddon"],
    Tr["Shazzrah"], Tr["Sulfuron Harbinger"], Tr["Golemagg the Incinerator"], Tr["Majordomo Executus"],
    Tr["Ragnaros"] }
local NAMES = { "Alfa", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliett",
    "Kilo", "Lima", "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- the panel's choices, and the session
local S = { count = 2, mog = false, shard = false, refused = false, raid = false }
local panel, ticker, running
local rolls = {}                -- by id: { item, start, drop, queue, next, cancelled }
local boss                      -- this deal's boss: the history's encounter
local past = {}                 -- earlier deals, newest first: { info, drops }
local deal = 0                  -- deals so far: each starts one item further on the list

-- ------------------------------------------------------------- the items
local function ItemOf(i)
    local it = ITEMS[(deal + i - 2) % #ITEMS + 1]
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local info = get and { get(it[1]) } or {}
    local name, link, quality, icon = info[1], info[2], info[3], info[10]
    return { id = it[1], name = name or it[2], quality = quality or 4,
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        link = link or string.format("|cffa335ee|Hitem:%d::::::::60:::::|h[%s]|h|r", it[1], name or it[2]) }
end

-- the history's leader: the best choice, then the highest roll
local ORDER = { [0] = 1, 2, 3, 4 }
local function Leader(d)
    local best
    for _, r in ipairs(d.rollInfos) do
        if ORDER[r.state] and r.roll then
            if not best or ORDER[r.state] < ORDER[best.state]
                or (ORDER[r.state] == ORDER[best.state] and r.roll > best.roll) then
                best = r
            end
        end
    end
    return best
end

-- a member's answer: its state and, unless a pass, its roll
local function Answer(d, r, state)
    r.state = state
    r.roll = state ~= PASS and math.random(1, 100) or nil
    d.currentLeader = Leader(d)
end

-- every member answered (or the time ran out): the winner, or all passed;
-- the roll ends, as the game's CANCEL_LOOT_ROLL ends it
local function Decide(id, roll)
    local d = roll.drop
    for _, r in ipairs(d.rollInfos) do if r.state == WAIT then r.state = PASS end end
    local w = Leader(d)
    d.currentLeader = nil
    if w then
        w.isWinner = true
        d.winner = w
    else
        d.allPassed = true
    end
    roll.cancelled = true
    ns.rolls.Cancel(id)
    ns.rolls.Redraw()
end

-- the group's members on a drop, you among them, all still choosing
local function Members()
    local list = {}
    local _, class = UnitClass("player")
    table.insert(list, { playerName = UnitName("player"), playerClass = class, isSelf = true, state = WAIT })
    for k = 1, S.raid and #NAMES or 4 do
        table.insert(list, { playerName = NAMES[k], playerClass = CLASSES[(k - 1) % #CLASSES + 1], state = WAIT })
    end
    return list
end

-- one member answers every STEP seconds, in a shuffled order, you aside
local function Step() return S.raid and 0.35 or 0.9 end

local function Tick()
    local now = GetTime()
    local moved = false
    for id, roll in pairs(rolls) do
        if not roll.cancelled then
            local d = roll.drop
            while roll.queue[1] and now >= roll.next do
                local r = table.remove(roll.queue, 1)
                local pick = math.random(100)
                local state = pick <= 30 and 0 or (S.mog and pick <= 42) and 2 or pick <= 72 and 3 or PASS
                Answer(d, r, state)
                roll.next = roll.next + Step()
                moved = true
            end
            local waiting = false
            for _, r in ipairs(d.rollInfos) do if r.state == WAIT then waiting = true end end
            if not waiting or now >= roll.start + LENGTH then Decide(id, roll) end
        end
    end
    if moved then ns.rolls.Redraw() end
end

-- ----------------------------------------------------------- the source
-- rolls.lua's GAME in shape: ours below 0, the game's through to the game
local G = ns.rolls.GAME
local SIM = { history = true }

function SIM.Info(id)
    if id >= 0 then return G.Info(id) end
    local roll = rolls[id]
    if not roll then return end
    local it, need = roll.item, not (S.refused and id == -1)
    return it.icon, it.name, 1, it.quality, true, need, true, S.shard, not need and 1 or nil, nil,
        nil, 0, S.mog
end

function SIM.Link(id)
    if id >= 0 then return G.Link(id) end
    return rolls[id] and rolls[id].item.link
end

function SIM.Left(id)
    if id >= 0 then return G.Left(id) end
    local roll = rolls[id]
    if not roll or roll.cancelled then return 0 end
    return math.max(0, roll.start + LENGTH - GetTime()) * 1000
end

function SIM.Roll(id, kind)
    if id >= 0 then return G.Roll(id, kind) end
    local roll = rolls[id]
    if not roll or roll.cancelled then return end
    for _, r in ipairs(roll.drop.rollInfos) do
        if r.isSelf then Answer(roll.drop, r, STATE[kind] or PASS) end
    end
    ns.rolls.Redraw()
end

function SIM.Encounters()
    local list = {}
    if boss then table.insert(list, boss) end
    for _, p in ipairs(past) do table.insert(list, p.info) end
    if G.history then
        for _, info in ipairs(G.Encounters() or {}) do table.insert(list, info) end
    end
    return list
end

function SIM.Drops(id)
    if id >= 0 then return G.history and G.Drops(id) or {} end
    if boss and id == boss.encounterID then
        local list = {}
        for k = -1, -MAX, -1 do if rolls[k] then table.insert(list, rolls[k].drop) end end
        return list
    end
    for _, p in ipairs(past) do if p.info.encounterID == id then return p.drops end end
    return {}
end

-- ----------------------------------------------------------------- deal
-- the rolls dropped again: S.count items, the group choosing from scratch
local function Deal()
    -- this deal's boss joins the past (its rolls decided now, if not yet)
    if boss then
        local drops = {}
        for k = -1, -MAX, -1 do
            local roll = rolls[k]
            if roll then
                if not roll.cancelled then Decide(k, roll) end
                table.insert(drops, roll.drop)
            end
        end
        table.insert(past, 1, { info = boss, drops = drops })
        while #past > 8 do table.remove(past) end
    end
    rolls = {}
    deal = deal + 1
    -- above the game's bosses: the newest
    boss = { encounterID = -deal, encounterName = BOSSES[(deal - 1) % #BOSSES + 1], startTime = 1e12 + deal }
    ns.rolls.Use(SIM)
    local now = GetTime()
    for i = 1, S.count do
        local id = -i
        local item = ItemOf(i)
        local members = Members()
        local queue = {}
        for k = 2, #members do table.insert(queue, math.random(1, #queue + 1), members[k]) end
        rolls[id] = { item = item, start = now, queue = queue, next = now + 0.6 + (i - 1) * 0.3,
            drop = { lootListKey = i, itemHyperlink = item.link, startTime = now, duration = LENGTH,
                rollInfos = members, allPassed = false } }
    end
    for i = 1, S.count do ns.rolls.Start(-i, LENGTH * 1000) end
end

local function Start()
    running = true
    for _, it in ipairs(ITEMS) do
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(it[1]) end
    end
    if not ticker then
        ticker = CreateFrame("Frame")
        local acc = 0
        ticker:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.1 then return end
            acc = 0
            Tick()
        end)
    end
    ticker:Show()
    Deal()
end

local function Stop()
    running = false
    if ticker then ticker:Hide() end
    rolls, past, boss = {}, {}, nil
    ns.rolls.Use(nil)
end

-- ---------------------------------------------------------------- panel
local function Build()
    local K = KIT
    panel = K.Chrome("MedalUIRollsSimPanel", Tr["Simulated rolls"], "RIGHT", -16, -160)
    local page = CreateFrame("Frame", nil, panel)
    local top = K.PAD + 16 + 6
    page:SetPoint("TOPLEFT", K.PAD, -top)
    page:SetSize(K.IW, 1)
    local y = K.Count(page, 0, "rolls.count", Tr["Rolls"], 1, MAX,
        function() return S.count end, function(n) S.count = n end,
        { Tr["One item fewer."], Tr["One item more."], Tr["How many items to roll on. Click for %d, or %d."] },
        Deal)
    y = K.Toggles(page, y - 4, "rolls", function() return S end, {
        { "mog", Tr["Transmog"], Tr["Transmog offered on every item, beside need and greed."] },
        { "shard", Tr["Disenchant"], Tr["Disenchant offered on every item."] },
        { "refused", Tr["Need refused"], Tr["The first item cannot be needed: its Need greyed, with the "
            .. "game's reason."] },
        { "raid", Tr["Raid"], Tr["Twenty roll on each item instead of five: the log stops short, the rest "
            .. "counted."] },
    }, Deal)
    K.Button(page, 0, y - 4, K.IW, { id = "rolls.again", label = Tr["New rolls"], redraw = Deal,
        click = function() end,
        tip = function() return Tr["Drop the items again, the group choosing from scratch."] end })
    y = y - 4 - K.ROW
    K.Button(panel, K.PAD, -(top - y + 6), K.IW, { id = "rolls.end", label = Tr["End simulation"],
        redraw = function() end,
        click = function() ns.SetOption("simRolls", false) end,
        tip = function() return Tr["Turn off Simulate rolls."] end })
    panel:SetHeight(top - y + 6 + K.ROW + K.PAD - 4)
end

-- on with the Roll window, which it shows
local function Allowed()
    return ns.db and ns.db.simRolls and ns.db.rollFrame and ns.rolls.frame ~= nil and true or false
end

local function Shown()
    local on = Allowed()
    if on and not panel then Build() end
    if on and not running then Start() end
    if not on and running then Stop() end
    if not panel then return end
    panel:SetShown(on)
    KIT.Paint()
end

ns.On("PLAYER_LOGIN", Shown)
for _, key in ipairs({ "simRolls", "rollFrame" }) do ns.OnSetting(key, Shown) end

-- for the harness
ns.rollsSim = { S = S, rolls = function() return rolls end, Tick = Tick, Deal = Deal,
    panel = function() return panel end }
