-- The inspect window's PvP page: what Blizzard's inspect PvP page reads
-- (InspectPVPFrame.lua), in the character window's PvP page's look
-- (character/pvp.lua): the honour level over the faction's emblem, the
-- lifetime honourable kills under it, and in the details the rated
-- brackets where the client has them (C_SpecializationInfo
-- .CanPlayerUsePVPTalentUI, as Blizzard's page asks).
--
-- The inspection asks for these itself (NotifyInspect); they come with
-- INSPECT_HONOR_UPDATE.
local _, ns = ...

local EMBLEM, EMBLEM_MAX = 96, 192
local FRAME = 32                                -- a divider and its room, above and below
local GOLD = { 0.941, 0.831, 0.533 }
local page, season, level, emblem, kills, details, above, below

local function Number(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

-- a bracket's line: its rating and its season's record
local function Bracket(name, rating, won, played)
    if type(rating) ~= "number" or ((played or 0) == 0 and rating == 0) then return end
    return format("%s: %s  (%d–%d)", name, Number(rating), won or 0, math.max(0, (played or 0) - (won or 0)))
end

local function Rated()
    local lines = {}
    if not (C_SpecializationInfo and C_SpecializationInfo.CanPlayerUsePVPTalentUI
        and C_SpecializationInfo.CanPlayerUsePVPTalentUI()) then return lines end
    local P = C_PaperDollInfo or {}
    local function Add(line) if line then table.insert(lines, line) end end
    if GetInspectArenaData then
        for i, name in ipairs({ "Arena 2v2", "Arena 3v3" }) do
            local ok, rating, played, won = pcall(GetInspectArenaData, i)
            if ok then Add(Bracket(name, rating, won, played)) end
        end
    end
    if P.GetInspectRatedSoloShuffleData then
        local d = P.GetInspectRatedSoloShuffleData()
        if d then Add(Bracket("Solo Shuffle", d.rating, d.roundsWon, d.roundsPlayed)) end
    end
    if P.GetInspectRatedBGBlitzData then
        local d = P.GetInspectRatedBGBlitzData()
        if d then Add(Bracket("Battleground Blitz", d.rating, d.gamesWon, d.gamesPlayed)) end
    end
    if P.GetInspectRatedBGData then
        local d = P.GetInspectRatedBGData()
        if d then Add(Bracket("Rated Battlegrounds", d.rating, d.won, d.played)) end
    end
    return lines
end

local function Refresh()
    local unit = ns.inspect.Unit()
    local n = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
    season:SetText(n > 0 and format("Season %d", n) or "")
    local hks, honor
    if GetInspectHonorData then
        local r = { GetInspectHonorData() }
        hks, honor = r[5], r[7]
    end
    if type(honor) ~= "number" and UnitHonorLevel then honor = UnitHonorLevel(unit) end
    level:SetText(type(honor) == "number" and honor > 0 and format("Honor Level %d", honor) or "Honor")
    local faction = UnitFactionGroup(unit) == "Horde" and "Horde" or "Alliance"
    emblem:SetAtlas("UI-Character-Info-Honor-Icon-" .. faction)
    kills:SetText(format("Lifetime honorable kills: %s", type(hks) == "number" and Number(hks) or "--"))
    local lines = Rated()
    if #lines > 0 then
        details:Set({ title = "Rated", sub = n > 0 and format("Season %d", n) or nil, lines = lines })
    else
        details:Set(nil)
    end
end

-- the block's height with an emblem this big
local function Block(size) return 10 + 12 + 6 + 18 + 14 + size + 14 + 14 + 10 end

local function Fit(h)
    local size = math.max(EMBLEM, math.min(EMBLEM_MAX, h - 2 * FRAME - Block(0)))
    emblem:SetSize(size, size)
    local top = math.max(0, math.floor((h - Block(size)) / 2))
    season:ClearAllPoints()
    season:SetPoint("TOP", 0, -(top + 10))
    local room = top >= FRAME
    above:SetShown(room)
    below:SetShown(room)
    above:ClearAllPoints()
    above:SetPoint("TOPLEFT", 60, -(top - FRAME / 2 - 6))
    above:SetPoint("TOPRIGHT", -60, -(top - FRAME / 2 - 6))
    below:ClearAllPoints()
    below:SetPoint("TOPLEFT", 60, -(top + Block(size) + FRAME / 2 - 6))
    below:SetPoint("TOPRIGHT", -60, -(top + Block(size) + FRAME / 2 - 6))
    page.emblemSize = size
end

local function Build(body, foot)
    season = ns.Text(body, 12)
    season:SetTextColor(unpack(ns.colors.dim))
    level = ns.Text(body, 18)
    level:SetPoint("TOP", season, "BOTTOM", 0, -6)
    level:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    emblem = body:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(EMBLEM, EMBLEM)
    emblem:SetPoint("TOP", level, "BOTTOM", 0, -14)
    kills = ns.Text(body, 13)
    kills:SetPoint("TOP", emblem, "BOTTOM", 0, -14)
    above, below = ns.character.Ornament(body), ns.character.Ornament(body)
    Fit(page.height)
    details = ns.character.Details(foot, nil, "No rated games this season.", 5)
    page.footHeight = details.height
    page.level, page.kills, page.emblem, page.details = level, kills, emblem, details
end

page = {
    key = "inspectPvp", label = "PvP", tip = "Player vs. Player", glyph = "pvp", order = 3,
    height = Block(EMBLEM),
    events = { "INSPECT_HONOR_UPDATE", "INSPECT_READY" },
    Available = function() return GetInspectHonorData ~= nil end,
    Build = Build, Fit = Fit, Refresh = Refresh,
}
ns.inspect.InspectPage(page)
ns.inspect.pvp = page
