-- The PvP page (Forever): the season and when it ends, the rank and its
-- emblem, and the rank points toward the next; under them three sections:
--   Season   the season's points on one bar: earned, open up to this
--            week's cap, and locked past it, to the season's top rank
--   Ranks    the season's ranks, two rows of insignia: lit when reached,
--            faint while this week's cap lets them be reached, fainter
--            past it; a diamond on a rank with a reward, a glow behind the
--            rank held; each one's tooltip says what it takes and gives
--   Honorable kills   today's, yesterday's and the lifetime's, and the
--            highest rank ever held
-- The details are the rank's: how far into the season's ranks, this
-- week's rise in the cap, and the next rewards.
--
-- Forever keeps the rank as a renown (C_MajorFactions, faction 2800), and
-- these are the reads and the words Blizzard's own page uses
-- (PVPRankFrame.lua), each word with a plain fallback.
--
-- The page is the window's height: the gaps between the blocks open to an
-- easy width first, then the emblem grows into it, then the insignia,
-- then the gaps again up to their most, and the lot stands in the middle.
local _, ns = ...
local Tr = ns.L

local FACTION = 2800
local EMBLEM, EMBLEM_MAX = 72, 160              -- the rank's emblem
local ICON, ICON_MAX = 40, 52                   -- an insignia on the ladder
local GAP, GAP_MAX, EASY = 8, 36, 24            -- between the blocks: least, most; enough to grow into
local COLUMNS, ROWS = 7, 2
local SIDE = 12                                 -- the sections' margin each side
local HEAD = 22 + 10                            -- a section's ribbon and the room under it
local BAR_H, LEGEND = 16, 12                    -- the season bar, its legend
local NUMBER = 16                               -- a tile's number under its insignia
local CELL = 11 + 3 + 14                        -- a kills cell: its label, its value
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local OPEN, LOCKED = 0.7, 0.3                   -- a rank's insignia not yet reached: open, locked
local DARK = { 0.16, 0.14, 0.11 }               -- the season bar past the cap

local page
local season, rank, emblem, halo, bar, details
local sections, seasonBar, legend, tiles, kills = {}, nil, {}, {}, {}

local function Words(key, fallback) return _G[key] or fallback end

local function RankName(level)
    if not level or level <= 0 then return Words("PVP_RANK_0_NAME", "Civilian") end
    local first = Enum and Enum.PvPRanks and Enum.PvPRanks.Rank_1 or 5
    local key = "PVP_RANK_" .. (first + level - 1) .. "_" .. (UnitFactionGroup("player") == "Alliance" and 1 or 0)
    return GetText and GetText(key, UnitSex("player")) or _G[key] or format(Tr["Rank %d"], level)
end

local function Total(level) return C_MajorFactions.GetTotalReputationForRenownLevel(FACTION, level) or 0 end
local function Rewards(level) return C_MajorFactions.GetRenownRewardsForLevel(FACTION, level) or {} end
local function Number(n) return BreakUpLargeNumbers(n or 0) end

-- the first rank above this one with a reward, and its rewards
local function NextRewards(level, top)
    for r = level + 1, top or level do
        local rewards = Rewards(r)
        if #rewards > 0 then return r, rewards end
    end
end

-- what is left of the season, two units: days and hours, else hours and
-- minutes; nil when the client does not know
local function Left()
    local f = C_SeasonInfo and C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd
    local s = f and f() or 0
    if not s or s <= 0 then return end
    local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
    if d > 0 then return format(Tr["%dd %dh"], d, h) end
    return format(Tr["%dh %dm"], h, m)
end

local function SeasonText()
    local n = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
    local left = Left()
    local text = n > 0 and format(Tr["Season %d"], n) or ""
    if left then text = (text ~= "" and text .. "  ·  " or "") .. format(Tr["Ends in %s"], left) end
    return text, n
end

-- a rank's place: reached, open (this week's cap lets it be reached), or locked
local function State(r, info)
    if r <= (info.renownLevel or 0) then return "reached" end
    if r <= (info.currentWeekProgressiveMaxLevel or 0) then return "open" end
    return "locked"
end
local STATE_WORDS = { reached = Tr["Reached"], open = Tr["Open this week"], locked = Tr["Locked until a later week"] }

-- ---------------------------------------------------------------- the parts
local function Ladder(info)
    local top = info and info.maxLevel or 0
    for i, t in ipairs(tiles) do
        local on = info ~= nil and i <= top
        t:SetShown(on)
        if on then
            local state = State(i, info)
            t.rank, t.state = i, state
            if t.icon:SetAtlas(format("UI-Character-Info-Honor-Icon-%d", i)) == false then
                t.icon:SetAtlas("UI-Character-Info-Honor-Icon-" .. (UnitFactionGroup("player") == "Horde"
                    and "Horde" or "Alliance"))
            end
            t.icon:SetDesaturated(state ~= "reached")
            t.icon:SetAlpha(state == "reached" and 1 or state == "open" and OPEN or LOCKED)
            t.number:SetText(i)
            t.number:SetTextColor(unpack(state == "reached" and GOLD or state == "open" and ns.colors.text
                or ns.colors.dim))
            t.rewards = Rewards(i)
            t.pip:SetShown(#t.rewards > 0)
            t.glow:SetShown(i == (info.renownLevel or 0))
        end
    end
end

local function Season(info)
    if not info then
        seasonBar:Fill({ min = 0, max = 1, cur = 0, text = "" })
        seasonBar.cap:Hide()
        return
    end
    local top = Total(info.maxLevel or 0)
    local cap = math.min(top, Total(info.currentWeekProgressiveMaxLevel or 0))
    local mine = Total(info.renownLevel or 0) + (info.renownReputationEarned or 0)
    seasonBar:Fill({ min = 0, max = top, cur = mine, color = ns.colors.xp,
        text = format("%s / %s", Number(mine), Number(top)), notches = cap > 0 and cap < top and { cap } or nil })
    -- the open stretch: from the start to the cap, under the fill
    local inner = (seasonBar:GetWidth() or 0) - 2
    local w = top > 0 and math.floor(inner * cap / top + 0.5) or 0
    seasonBar.cap:SetShown(w >= 1)
    seasonBar.cap:SetWidth(math.max(1, w))
    seasonBar.capped = cap
    legend[1].text:SetText(format(Tr["Earned %s"], Number(mine)))
    legend[2].text:SetText(format(Tr["Cap this week %s"], Number(cap)))
    legend[3].text:SetText(format(Tr["Season %s"], Number(top)))
    legend:Place()
end

local function Kills()
    local function Get(f) if f then return f() end end
    local hk, dk = Get(GetPVPSessionStats)
    local yhk, ydk = Get(GetPVPYesterdayStats)
    local life, best = Get(GetPVPLifetimeStats)
    local function Day(k, d)
        if not k then return end
        return (d or 0) > 0 and format(Tr["%s (%s dishonorable)"], Number(k), Number(d)) or Number(k)
    end
    local first = Enum and Enum.PvPRanks and Enum.PvPRanks.Rank_1 or 5
    local bestRank = best and best >= first and best - first + 1 or nil
    local values = { Day(hk, dk), Day(yhk, ydk), life and Number(life),
        best and (bestRank and RankName(bestRank) or Tr["No rank yet"]) }
    for i, c in ipairs(kills) do
        c:SetShown(values[i] ~= nil)
        c.value:SetText(values[i] or "")
    end
end

local function Refresh()
    local info = C_MajorFactions.GetMajorFactionProgressionInfo(FACTION)
    season:SetText((SeasonText()))
    Ladder(info)
    Season(info)
    Kills()
    if not info then
        rank:SetText(RankName(0))
        bar:Hide()
        details:Set(nil)
        return
    end
    local level = info.renownLevel or 0
    rank:SetText(level > 0 and format(Tr["Rank %d: %s"], level, RankName(level)) or RankName(0))
    local faction = UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
    emblem:SetAtlas(level > 0 and format("UI-Character-Info-Honor-Icon-%d", level)
        or "UI-Character-Info-Honor-Icon-" .. faction)
    bar:Show()
    bar:Fill({ min = 0, max = info.renownLevelThreshold, cur = info.renownReputationEarned, color = ns.colors.xp,
        text = format(Tr["Rank Points: %s / %s"], Number(info.renownReputationEarned),
            Number(info.renownLevelThreshold)) })

    local top = info.maxLevel or level
    local week = Total(info.currentWeekProgressiveMaxLevel or 0)
    local lastWeek = Total(info.previousWeekProgressiveMaxLevel or 0)
    local mine = Total(level) + (info.renownReputationEarned or 0)
    local lines = {}
    if mine > 0 then
        table.insert(lines, week > 0 and format(Tr["Season progress: %s / %s"], Number(mine), Number(week))
            or format(Tr["Season progress: %s"], Number(mine)))
    end
    if week - lastWeek > 0 then
        table.insert(lines, format(Tr["Cap increase this week: %s"], Number(week - lastWeek)))
    end
    local at, rewards = NextRewards(level, top)
    if at then
        table.insert(lines, format(Tr["Next rewards at Rank %d:"], at))
        for _, r in ipairs(rewards) do
            if r.description then
                table.insert(lines, (r.icon and format("|T%s:14:14|t ", r.icon) or "") .. r.description)
            end
        end
        local vendor = _G[faction == "Horde" and "PVP_RANK_REWARDS_VENDOR_HORDE" or "PVP_RANK_REWARDS_VENDOR_ALLIANCE"]
        if vendor then table.insert(lines, vendor) end
    end
    details:Set({ title = RankName(level), sub = level > 0 and format(Tr["Rank %d"], level) or nil,
        text = format(Tr["Each week the rank points cap rises, up to %s for Rank %d."], Number(Total(top)), top),
        lines = lines })
end

-- a rank's tooltip: its name, what it takes, where it stands, its rewards
local function TileTip(t)
    local info = C_MajorFactions.GetMajorFactionProgressionInfo(FACTION)
    local spec = { title = RankName(t.rank), color = GOLD, { "row", Tr["Rank"], tostring(t.rank) },
        { "row", Tr["Season points"], Number(Total(t.rank)) },
        { "body", STATE_WORDS[t.state], t.state == "reached" and GOLD or t.state == "open" and ns.colors.white
            or ns.colors.dim } }
    for _, r in ipairs(t.rewards or {}) do
        if r.description then table.insert(spec, { "item", r.icon, r.description }) end
    end
    if info and t.rank == info.renownLevel then table.insert(spec, { "hint", Tr["Your rank."] }) end
    ns.Tip(t, ns.window.OutsideTop, spec)
end

-- --------------------------------------------------------------- the layout
-- the blocks' height with an emblem and insignia this big, no gaps
local function Top(e) return 12 + 6 + 18 + 12 + e + 12 + BAR_H end
local function TileH(i) return i + NUMBER end
local function Fixed(e, i)
    return Top(e) + 3 * HEAD + (BAR_H + 8 + LEGEND) + (ROWS * TileH(i) + 6) + (2 * CELL + 10)
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function Fit(h)
    local e = Clamp(h - Fixed(0, ICON) - 4 * EASY, EMBLEM, EMBLEM_MAX)
    local i = Clamp(math.floor((h - Fixed(e, 0) - 4 * EASY) / ROWS), ICON, ICON_MAX)
    local rest = h - Fixed(e, i)
    local gap = Clamp(math.floor(rest / 6), GAP, GAP_MAX)
    local y = math.max(0, math.floor((rest - 4 * gap) / 2))
    emblem:SetSize(e, e)
    halo:SetSize(e * 1.6, e * 1.6)
    season:ClearAllPoints()
    season:SetPoint("TOP", 0, -y)
    y = y + Top(e) + gap
    for n, s in ipairs(sections) do
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", SIDE, -y)
        s:SetPoint("TOPRIGHT", -SIDE, -y)
        y = y + HEAD + s.Content(i) + (n < #sections and gap or 0)
    end
    -- the ladder's tiles, a column's pitch apart, as big as the insignia
    local pitch = math.floor((ns.character.width - 2 * SIDE) / COLUMNS)
    for k, t in ipairs(tiles) do
        local col, row = (k - 1) % COLUMNS, math.floor((k - 1) / COLUMNS)
        t:SetSize(pitch, TileH(i))
        t.icon:SetSize(i, i)
        t.glow:SetSize(i * 2, i * 2)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", sections[2], "TOPLEFT", col * pitch, -(HEAD + row * (TileH(i) + 6)))
    end
    page.emblemSize, page.iconSize, page.gap = e, i, gap
end

-- a section: its ribbon, and how tall its content is with insignia this big
local function Section(body, label, content)
    local s = ns.window.Ribbon(body, label)
    s.Content = content
    table.insert(sections, s)
    return s
end

local function Build(body, foot)
    season = ns.Text(body, 12)
    season:SetTextColor(unpack(ns.colors.dim))
    rank = ns.Text(body, 18)
    rank:SetPoint("TOP", season, "BOTTOM", 0, -6)
    rank:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    emblem = body:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(EMBLEM, EMBLEM)
    emblem:SetPoint("TOP", rank, "BOTTOM", 0, -12)
    halo = body:CreateTexture(nil, "BACKGROUND")
    halo:SetTexture(ns.media .. "character\\glow")
    halo:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    halo:SetPoint("CENTER", emblem)
    bar = ns.character.Bar(body, 220)
    bar:SetPoint("TOP", emblem, "BOTTOM", 0, -12)

    -- Season: one bar, three stretches, and a legend under it
    local width = ns.character.width - 2 * SIDE
    local s1 = Section(body, Tr["Season"], function() return BAR_H + 8 + LEGEND end)
    seasonBar = ns.character.Bar(body, width - 24)
    seasonBar:SetPoint("TOP", s1, "TOP", 0, -HEAD)
    seasonBar.cap = seasonBar.bar:CreateTexture(nil, "BACKGROUND")
    seasonBar.cap:SetPoint("TOPLEFT")
    seasonBar.cap:SetPoint("BOTTOMLEFT")
    seasonBar.cap:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    seasonBar.rest = seasonBar.bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    seasonBar.rest:SetAllPoints()
    seasonBar.rest:SetColorTexture(DARK[1], DARK[2], DARK[3], 1)
    local holder = CreateFrame("Frame", nil, body)
    holder:SetSize(width, LEGEND)
    holder:SetPoint("TOP", seasonBar, "BOTTOM", 0, -8)
    for k, c in ipairs({ ns.colors.xp, { GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6 }, DARK }) do
        local e = { swatch = holder:CreateTexture(nil, "ARTWORK"), text = ns.Text(holder, 11) }
        e.swatch:SetSize(8, 8)
        e.swatch:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        e.text:SetTextColor(unpack(ns.colors.dim))
        legend[k] = e
    end
    -- the three side by side, the lot centred
    function legend:Place()
        local across = 0
        for k, e in ipairs(self) do across = across + 8 + 4 + (e.text:GetStringWidth() or 0) + (k > 1 and 14 or 0) end
        local x = math.floor((width - across) / 2)
        for k, e in ipairs(self) do
            if k > 1 then x = x + 14 end
            e.swatch:ClearAllPoints()
            e.swatch:SetPoint("LEFT", holder, "LEFT", x, 0)
            e.text:ClearAllPoints()
            e.text:SetPoint("LEFT", e.swatch, "RIGHT", 4, 0)
            x = x + 8 + 4 + (e.text:GetStringWidth() or 0)
        end
    end

    -- Ranks: two rows of insignia
    Section(body, Tr["Ranks"], function(i) return ROWS * TileH(i) + 6 end)
    for k = 1, COLUMNS * ROWS do
        local t = CreateFrame("Button", nil, body)
        t.glow = t:CreateTexture(nil, "BACKGROUND")
        t.glow:SetTexture(ns.media .. "character\\glow")
        t.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetPoint("TOP")
        t.glow:SetPoint("CENTER", t.icon)
        t.number = ns.Text(t, 11)
        t.number:SetPoint("TOP", t.icon, "BOTTOM", 0, -3)
        t.pip = t:CreateTexture(nil, "OVERLAY")
        t.pip:SetSize(6, 6)
        t.pip:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        if t.pip.SetRotation then t.pip:SetRotation(math.pi / 4) end
        t.pip:SetPoint("CENTER", t.icon, "TOPRIGHT", -2, -2)
        t:SetScript("OnEnter", TileTip)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t:Hide()
        tiles[k] = t
    end

    -- Honorable kills: two by two, each a word over its number
    local s3 = Section(body, Tr["Honorable kills"], function() return 2 * CELL + 10 end)
    local half = math.floor(width / 2)
    for k, label in ipairs({ Tr["Today"], Tr["Yesterday"], Tr["Lifetime"], Tr["Highest rank"] }) do
        local c = CreateFrame("Frame", nil, body)
        c:SetSize(half, CELL)
        c:SetPoint("TOPLEFT", s3, "TOPLEFT", (k - 1) % 2 * half, -(HEAD + math.floor((k - 1) / 2) * (CELL + 10)))
        c.label = ns.Text(c, 11)
        c.label:SetPoint("TOP")
        c.label:SetTextColor(unpack(ns.colors.dim))
        c.label:SetText(label)
        c.value = ns.Text(c, 14)
        c.value:SetPoint("TOP", c.label, "BOTTOM", 0, -3)
        c.value:SetTextColor(unpack(ns.colors.white))
        c:Hide()
        kills[k] = c
    end

    Fit(page.height)
    details = ns.character.Details(foot, nil, Tr["No rank this season."], 8)
    page.footHeight = details.height
    page.season, page.rank, page.emblem, page.bar, page.details = season, rank, emblem, bar, details
    page.sections, page.seasonBar, page.legend, page.tiles, page.kills = sections, seasonBar, legend, tiles, kills
end

-- the countdown, a minute at a time while the page is open; a new season
-- draws the lot again
local ticker
local function Showing(on)
    if ticker then ticker:Cancel() end
    ticker, page.ticker = nil, nil
    if not (on and C_Timer and C_Timer.NewTicker) then return end
    local _, was = SeasonText()
    ticker = C_Timer.NewTicker(60, function()
        local text, n = SeasonText()
        if n ~= was then Refresh() else season:SetText(text) end
        was = n
    end)
    page.ticker = ticker
end

page = {
    key = "pvp", label = Tr["PvP"], tip = Tr["Player vs. Player"], frame = "PVPRankFrame", order = 5,
    height = Fixed(EMBLEM, ICON) + 6 * GAP,
    events = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_PVP_RANK_CHANGED",
        "PLAYER_PVP_KILLS_CHANGED" },
    Build = Build, Fit = Fit, Refresh = Refresh, Showing = Showing,
}
ns.CharacterPage(page)
