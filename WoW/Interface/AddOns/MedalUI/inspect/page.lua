-- The inspect window's page (inspect/window.lua): the character page's
-- doll (character/paperdoll.lua, ns.character.Doll) for the unit inspected,
-- and in its details, as a target's stats cannot be read, what can be, in
-- the stats' rows (two columns, striped), each part under its heading:
--
--   ------------------------- < Summary > -------------------------
--   Item level        23       |   Talents           0/4/22
--   Health         1,183       |   Energy               100
--   Race           Dwarf       |   Faction         Alliance
--   Guild                         <Silver Hand>  Officer
--   --------------------------- < PvP > ---------------------------
--   Honor level        1       |   Honorable kills      234
--   Rank                                        Knight (6)    (ranks only)
--   Best rating                                  3v3 1,840    (rated only)
--
-- Each client has its own lines, so the details keep one height and the
-- doll the rest: a line that reads nothing says "--".
--
-- The talents are the points in each tree where the inspection told them
-- (inspect/talents.lua on Forever, or the old trees), else the spec's name.
-- The honour level is the one the inspection told, else the unit's; the
-- kills are the inspection's lifetime honourable kills (they come with
-- INSPECT_HONOR_UPDATE). The rank is the old ranks' title, on a client
-- with them. The best rating is the best of the inspection's
-- rated brackets, where the client has them (CanPlayerUsePVPTalentUI, as
-- Blizzard's inspect PvP page asks). The item level is the game's own
-- reckoning where it has one for an inspection, else the slots' average, as
-- the game counts it: every slot but the shirt and the tabard, an empty one
-- as nothing, a two-hander with nothing in the off hand twice.
local _, ns = ...
local Tr = ns.L

local Unit = ns.inspect.Unit
local R = ns.character.ribbon
local TWO_HAND = { INVTYPE_2HWEAPON = true }
local MAIN, OFF = 16, 17

local page, doll, columns

local function Whole(v)
    if ns.IsSecret(v) then
        local ok, text = pcall(AbbreviateLargeNumbers, v)
        return ok and text or nil
    end
    if type(v) ~= "number" then return end
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(math.floor(v + 0.5)) end
    return tostring(math.floor(v + 0.5))
end

-- --------------------------------------------------------------- reads
local function Talents(unit)
    -- the trees' points, as the inspect talents page reads them (Forever)
    local traits = ns.inspect.TalentSplit and ns.inspect.TalentSplit()
    if traits then return traits end
    if GetNumTalentTabs and GetTalentTabInfo then
        local split = {}
        for i = 1, GetNumTalentTabs(true) or 0 do
            -- name, icon, points (Classic Era) or id, name, text, icon, points (later)
            local r = { GetTalentTabInfo(i, true) }
            local points = type(r[5]) == "number" and r[5] or r[3]
            if type(points) ~= "number" then split = nil break end
            split[i] = points
        end
        if split and #split > 0 then return table.concat(split, "/") end
    end
    if GetInspectSpecialization and GetSpecializationInfoByID then
        local id = GetInspectSpecialization(unit)
        local name = id and id > 0 and select(2, GetSpecializationInfoByID(id)) or nil
        local className = UnitClass(unit)
        if ns.IsSecret(name) or ns.IsSecret(className) or name ~= className then return name end
    end
end

local function Honor(unit)
    -- the honour level the inspection told (GetInspectHonorData's seventh)
    if GetInspectHonorData then
        local level = select(7, GetInspectHonorData())
        if type(level) == "number" and level > 0 then return tostring(level) end
    end
    if UnitHonorLevel then
        local level = UnitHonorLevel(unit)
        if type(level) == "number" and level > 0 then return tostring(level) end
    end
end

local function Kills()
    local hks = GetInspectHonorData and select(5, GetInspectHonorData())
    if type(hks) == "number" then return Whole(hks) end
end

-- the old ranks' title and number
local function Rank(unit)
    local name, number = GetPVPRankInfo(UnitPVPRank(unit) or 0, unit)
    if type(number) == "number" and number > 0 and name then return format("%s (%d)", name, number) end
end

-- the best of the rated brackets, with its name
local function Rated()
    if not (C_SpecializationInfo and C_SpecializationInfo.CanPlayerUsePVPTalentUI
        and C_SpecializationInfo.CanPlayerUsePVPTalentUI()) then return end
    local best, which
    local function Add(name, rating)
        if type(rating) == "number" and rating > 0 and (not best or rating > best) then best, which = rating, name end
    end
    if GetInspectArenaData then
        for i, name in ipairs({ "2v2", "3v3" }) do
            local ok, rating = pcall(GetInspectArenaData, i)
            if ok then Add(name, rating) end
        end
    end
    local P = C_PaperDollInfo or {}
    for name, fn in pairs({ Shuffle = P.GetInspectRatedSoloShuffleData, Blitz = P.GetInspectRatedBGBlitzData,
        RBG = P.GetInspectRatedBGData }) do
        local d = fn()
        if d then Add(name, d.rating) end
    end
    if best then return format("%s  %s", which, Whole(best)) end
end

local function EquipLoc(link)
    local info = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    return info and select(9, info(link))
end

-- the slots' average: every slot the doll holds but the plain ones
local function Average(unit)
    local sum, count, any = 0, 0, false
    local function Add(btn)
        if btn.slotName == "Shirt" or btn.slotName == "Tabard" or btn.slotName == "Ammo" then return end
        count = count + 1
        local level = doll.ItemLevel(btn:GetID())
        if level and level > 0 then sum, any = sum + level, true end
    end
    for _, btn in ipairs(doll.slots) do Add(btn) end
    for _, btn in ipairs(doll.weapons) do Add(btn) end
    local main = GetInventoryItemLink(unit, MAIN)
    if main and not GetInventoryItemLink(unit, OFF) and TWO_HAND[EquipLoc(main) or ""] then
        sum = sum + (doll.ItemLevel(MAIN) or 0)
    end
    if any and count > 0 then return sum / count end
end

local function ItemLevel(unit)
    local reckon = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
    local level = reckon and reckon(unit)
    if type(level) ~= "number" or level <= 0 then level = Average(unit) end
    return level and level > 0 and tostring(math.floor(level)) or nil
end

local function PowerName(unit)
    local _, token = UnitPowerType(unit)
    return token and _G[token] or Tr["Power"]
end

-- the guild and the rank there, on one line
local function Guild(unit)
    if not GetGuildInfo then return end
    local name, rank = GetGuildInfo(unit)
    if type(name) ~= "string" or name == "" then return Tr["No guild"] end
    if type(rank) == "string" and rank ~= "" then
        local d = ns.colors.dim
        return format("<%s>  |cff%02x%02x%02x%s|r", name, d[1] * 255, d[2] * 255, d[3] * 255, rank)
    end
    return format("<%s>", name)
end

-- the old ranks, on a client that has them and not the honour levels that
-- followed them
local function Ranked() return UnitPVPRank ~= nil and GetPVPRankInfo ~= nil and UnitHonorLevel == nil end
local function RatedHere()
    return C_SpecializationInfo and C_SpecializationInfo.CanPlayerUsePVPTalentUI ~= nil
end

-- each part: its heading, and its lines: a pair (left, right), or one
-- entry across the whole width; a line with a "when" that says no on this
-- client is left out
local PARTS = {
    { Tr["Summary"], {
        { { Tr["Item level"], function(unit) return ItemLevel(unit) end }, { Tr["Talents"], Talents } },
        { { Tr["Health"], function(unit) return Whole(UnitHealthMax(unit)) end },
            { PowerName, function(unit) return Whole(UnitPowerMax(unit)) end } },
        { { Tr["Race"], function(unit) return (UnitRace(unit)) end },
            { Tr["Faction"], function(unit)
                -- its name in the client's language, else the English one
                local faction, name = UnitFactionGroup(unit)
                return name or faction
            end } },
        { wide = { Tr["Guild"], Guild } },
    } },
    { Tr["PvP"], {
        { { Tr["Honor level"], Honor }, { Tr["Honorable kills"], Kills } },
        { wide = { Tr["Rank"], Rank }, when = Ranked },
        { wide = { Tr["Best rating"], Rated }, when = RatedHere },
    } },
}

-- a secret (a health on the clients that hide it) is shown as it is: it
-- may not even be compared, so it is let through before the empty check
local function Read(fn, unit)
    local ok, v = pcall(fn, unit)
    if not ok or v == nil then return end
    if ns.IsSecret(v) or v ~= "" then return v end
end

local function Label(entry, unit)
    local l = entry[1]
    return type(l) == "function" and l(unit) or l
end

-- -------------------------------------------------------------- details
local HEADING = 22 + 8                          -- a heading, and the gap under it
local BETWEEN = 14                              -- between one part and the next

local function Fill(row, unit)
    row.label:SetText(Label(row.entry, unit))
    row.value:SetText(Read(row.entry[2], unit) or "--")
end

local function Details(foot)
    columns = {}
    local y = 0
    for i, part in ipairs(PARTS) do
        if i > 1 then y = y + BETWEEN end
        local heading = ns.window.Ribbon(foot, part[1])
        heading:SetPoint("TOPLEFT", 0, -y)
        heading:SetPoint("TOPRIGHT", 0, -y)
        y = y + HEADING
        local rows, k = {}, 0
        for _, line in ipairs(part[2]) do
            if not line.when or line.when() then
                k = k + 1
                local entries = line.wide and { line.wide } or line
                for j, entry in ipairs(entries) do
                    local side = j == 1 and -1 or 1
                    local r = ns.character.Rows(foot, { entry }, side)[1]
                    r.entry = entry
                    r.line = k
                    if line.wide then r:SetWidth(ns.character.width) end
                    r:SetPoint(side < 0 and "TOPLEFT" or "TOPRIGHT", 0, -y)
                    table.insert(rows, r)
                end
                if not line.wide then
                    local split = ns.window.Hair(foot, true)
                    split:SetHeight(R.row - 4)
                    split:SetPoint("TOP", foot, "TOP", 0, -(y + 2))
                end
                y = y + R.row
            end
        end
        -- a hairline under each row but a part's last
        for _, r in ipairs(rows) do r.hair:SetShown(r.line < k) end
        columns[i] = { name = part[1], rows = rows }
    end
    page.footHeight = y
    page.summary = { parts = columns }
end

local function Refresh()
    local unit = Unit()
    doll.Refresh()
    for _, part in ipairs(columns) do
        for _, r in ipairs(part.rows) do Fill(r, unit) end
    end
end

page = {
    key = "inspect", label = Tr["Inspect"], tip = Tr["Their gear"], glyph = "character",
        frame = "InspectPaperDollFrame",
    order = 1, height = ns.character.dollJoin.height, under = ns.character.dollJoin.under,
    events = { "INSPECT_READY", "UNIT_INVENTORY_CHANGED", "UNIT_MODEL_CHANGED", "UNIT_NAME_UPDATE",
        "GET_ITEM_INFO_RECEIVED", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "PLAYER_GUILD_UPDATE",
        "INSPECT_HONOR_UPDATE" },
    Build = function(body, foot)
        doll.Build(body)
        Details(foot)
    end,
    Fit = function(h) doll.Fit(h) end,
    Refresh = Refresh,
    Shown = function() doll.SetModel() end,
    OnEvent = function(event)
        if event == "INSPECT_READY" or event == "UNIT_MODEL_CHANGED" then doll.SetModel() end
    end,
}
doll = ns.character.Doll{ prefix = "Inspect", Unit = Unit, page = page }
page.doll = doll
ns.inspect.InspectPage(page)
