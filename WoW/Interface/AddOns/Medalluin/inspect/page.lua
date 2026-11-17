-- The inspect window's page (inspect/window.lua): the character page's
-- doll (character/paperdoll.lua, ns.character.Doll) for the unit inspected,
-- and in its details a summary in the stats' look, as a target's stats
-- cannot be read:
--
--     Talents    PvP     [ 62 ]    Health    Mana         <- the ribbon
--     31/20/0    7        ilvl     4,210     3,580
--   Guild      <Guild>          Guild rank     Officer
--   Race       Night Elf        Realm          Pyrewood
--
-- The talents are the points in each tree where the inspection told them
-- (inspect/talents.lua on Forever, or the old trees), else the spec's name;
-- PvP is the honour level the inspection told, else the rank on a client
-- with ranks, else the unit's honour level. The item level is the game's
-- own reckoning where it has one for an inspection, else the slots'
-- average, as the game counts it: every slot but the shirt and the tabard,
-- an empty one as nothing, a two-hander with nothing in the off hand
-- twice. A cell that reads nothing says "--"; a row that reads nothing is
-- left out, and its column closes up.
local _, ns = ...

local Unit = ns.inspect.Unit
local R = ns.character.ribbon
local TWO_HAND = { INVTYPE_2HWEAPON = true }
local MAIN, OFF = 16, 17

local page, doll, ribbon, cells, badge, columns

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
        if name ~= UnitClass(unit) then return name end
    end
end

local function PvP(unit)
    -- the honour level the inspection told (GetInspectHonorData's seventh)
    if GetInspectHonorData then
        local level = select(7, GetInspectHonorData())
        if type(level) == "number" and level > 0 then return tostring(level) end
    end
    if UnitPVPRank and GetPVPRankInfo then
        local _, number = GetPVPRankInfo(UnitPVPRank(unit) or 0, unit)
        if type(number) == "number" and number > 0 then return tostring(number) end
    end
    if UnitHonorLevel then
        local level = UnitHonorLevel(unit)
        if type(level) == "number" and level > 0 then return tostring(level) end
    end
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
    return token and _G[token] or "Power"
end

local RIBBON = {
    { "Talents", Talents },
    { "PvP", PvP },
    { "Health", function(unit) return Whole(UnitHealthMax(unit)) end },
    { PowerName, function(unit) return Whole(UnitPowerMax(unit)) end },
}
local function Guild(unit) return GetGuildInfo and (GetGuildInfo(unit)) or nil end
local LEFT = {
    { "Guild", Guild },
    { "Race", function(unit) return (UnitRace(unit)) end },
}
local RIGHT = {
    { "Guild rank", function(unit) return GetGuildInfo and select(2, GetGuildInfo(unit)) or nil end },
    { "Realm", function(unit)
        local _, realm = UnitName(unit)
        if realm and realm ~= "" then return realm end
        return GetRealmName and GetRealmName() or nil
    end },
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
local function Fill(rows, entries, side, unit)
    local y = R.height + 3 + R.gap
    for i, entry in ipairs(entries) do
        local r = rows[i]
        local text = Read(entry[2], unit)
        r:SetShown(text ~= nil)
        if text then
            r.label:SetText(Label(entry, unit))
            r.value:SetText(text)
            r:ClearAllPoints()
            r:SetPoint(side < 0 and "TOPLEFT" or "TOPRIGHT", r:GetParent(), side < 0 and "TOPLEFT" or "TOPRIGHT",
                0, -y)
            y = y + R.row
        end
    end
end

local function Details(foot)
    ribbon, cells, badge = ns.character.Ribbon(foot)
    columns = { left = ns.character.Rows(foot, LEFT, -1), right = ns.character.Rows(foot, RIGHT, 1) }
    local rows = math.max(#LEFT, #RIGHT)
    local split = foot:CreateTexture(nil, "ARTWORK")
    split:SetColorTexture(0.541, 0.439, 0.204, 1)
    split:SetSize(1, rows * R.row - 4)
    split:SetPoint("TOP", foot, "TOP", 0, -(R.height + 3 + R.gap + 2))
    page.footHeight = R.height + 3 + R.gap + rows * R.row
    page.summary = { ribbon = ribbon, cells = cells, badge = badge, columns = columns }
end

local function Refresh()
    local unit = Unit()
    doll.Refresh()
    for i, entry in ipairs(RIBBON) do
        cells[i].label:SetText(Label(entry, unit))
        cells[i].value:SetText(Read(entry[2], unit) or "--")
    end
    badge.value:SetText(Read(ItemLevel, unit) or "--")
    Fill(columns.left, LEFT, -1, unit)
    Fill(columns.right, RIGHT, 1, unit)
end

page = {
    key = "inspect", label = "Inspect", tip = "Their gear", glyph = "character", frame = "InspectPaperDollFrame",
    order = 1, height = ns.character.dollHeight,
    events = { "INSPECT_READY", "UNIT_INVENTORY_CHANGED", "UNIT_MODEL_CHANGED", "UNIT_NAME_UPDATE",
        "GET_ITEM_INFO_RECEIVED", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "PLAYER_GUILD_UPDATE" },
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
