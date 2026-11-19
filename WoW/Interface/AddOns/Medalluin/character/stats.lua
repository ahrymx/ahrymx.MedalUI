-- The Character page's details: the stats, as the reference draws them.
--
--     Crit      Haste    [ 322 ]    Mastery    Vers       <- the ribbon
--     39%       25%        ilvl     14%        12%
--   Agility        2,505          Parry               3%
--   Stamina       38,553          Leech               9%
--   ...                           ...
--   [arcane] 0  [fire] 0  [frost] 0  [nature] 0  [shadow] 0   <- Forever
--
-- The ribbon has four of the stats that matter most on the client around
-- the item level: retail's secondary stats, or Forever's hit, crit, haste
-- and armour. Under it, two columns of the rest, read by the functions
-- Blizzard's own pane calls; a row whose function this client lacks (or
-- that raises) is left out, and its column closes up. Forever adds the
-- five resistances.
--
-- Crit, hit and haste are the best of melee, ranged and spell, as one
-- number serves every class.
local _, ns = ...

local ROW, RIBBON, BADGE, GAP = 22, 50, 54, 10
-- (2026-11-19, /workspace/sleek-character.png) the ribbon a gold band with
-- hairlines, the item level in a medallion's ring, the rows on hairlines,
-- each resistance an ink cell: its gem, its school, its value, its tint under
local HAIR = { 0.204, 0.176, 0.129 }
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local SCHOOLS = { "Arcane", "Fire", "Frost", "Nature", "Shadow" }
-- each school's box: its tint
local SCHOOL_COLOR = { Arcane = { 0.6, 0.45, 1 }, Fire = { 1, 0.36, 0.16 }, Frost = { 0.36, 0.66, 1 },
    Nature = { 0.32, 0.86, 0.36 }, Shadow = { 0.67, 0.3, 0.84 } }
local BOX, LABEL = 34, 16                       -- a resistance's cell, its height; the label over them
local SCHOOL_CLASS = { Arcane = 6, Fire = 2, Frost = 4, Nature = 3, Shadow = 5 }   -- Enum.Damageclass

local function Best(...)
    local best
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" and (not best or v > best) then best = v end
    end
    return best
end

local function Percent(v) return format("%.0f%%", v) end
local function Whole(v)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(math.floor(v + 0.5)) end
    return tostring(math.floor(v + 0.5))
end

local function SpellSchools(fn)
    if not fn then return end
    local best
    for school = 2, 7 do best = Best(best, fn(school)) end
    return best
end

local function Rating(cr)
    if not (cr and GetCombatRatingBonus) then return 0 end
    return GetCombatRatingBonus(cr) or 0
end

local function Crit()
    return Best(GetCritChance and GetCritChance(), GetRangedCritChance and GetRangedCritChance(),
        SpellSchools(GetSpellCritChance))
end

local function Haste()
    return Best(GetHaste and GetHaste(), GetMeleeHaste and GetMeleeHaste(), GetRangedHaste and GetRangedHaste(),
        UnitSpellHaste and UnitSpellHaste("player"))
end

local function Hit()
    local melee = (GetHitModifier and GetHitModifier() or 0) + Rating(CR_HIT_MELEE)
    local spell = (GetSpellHitModifier and GetSpellHitModifier() or 0) + Rating(CR_HIT_SPELL)
    return Best(melee, spell)
end

local function Armor() return select(2, UnitArmor("player")) end
local function Stat(i) return function() return select(2, UnitStat("player", i)) end end

local function PrimaryName()
    local best, at = -1, 1
    for _, i in ipairs({ 1, 2, 4 }) do
        local v = select(2, UnitStat("player", i))
        if v > best then best, at = v, i end
    end
    return _G["SPELL_STAT" .. at .. "_NAME"] or ({ "Strength", "Agility", "", "Intellect" })[at], at
end

local function Speed()
    local _, run = GetUnitSpeed("player")
    return run / (BASE_MOVEMENT_SPEED or 7) * 100
end

local function Power() return UnitPowerMax("player") end
local function PowerName()
    local _, token = UnitPowerType("player")
    return token and _G[token] or "Power"
end

-- { label, value (a function), format }; a label may be a function too
local FOREVER = {
    ribbon = {
        { "Hit", Hit, Percent }, { "Crit", Crit, Percent },
        { "Haste", Haste, Percent }, { "Armor", Armor, Whole },
    },
    left = {
        { "Health", function() return UnitHealthMax("player") end, Whole },
        { PowerName, Power, Whole },
        { "Strength", Stat(1), Whole }, { "Agility", Stat(2), Whole }, { "Stamina", Stat(3), Whole },
        { "Intellect", Stat(4), Whole }, { "Spirit", Stat(5), Whole },
    },
    right = {
        { "Attack Power", function()
            local base, pos, neg = UnitAttackPower("player")
            return base + pos + neg
        end, Whole },
        { "Spell Power", function() return SpellSchools(GetSpellBonusDamage) end, Whole },
        { "Healing", function() return GetSpellBonusHealing() end, Whole },
        { "Defense", function()
            local base, mod = UnitDefenseSkill("player")
            return base + mod
        end, Whole },
        { "Dodge", function() return GetDodgeChance() end, Percent },
        { "Parry", function() return GetParryChance() end, Percent },
        { "Block", function() return GetBlockChance() end, Percent },
    },
    resist = true,
}

local RETAIL = {
    ribbon = {
        { "Crit", Crit, Percent }, { "Haste", Haste, Percent },
        { "Mastery", function() return GetMasteryEffect() end, Percent },
        { "Vers", function()
            return Rating(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
        end, Percent },
    },
    left = {
        { PrimaryName, function() return select(2, UnitStat("player", select(2, PrimaryName()))) end, Whole },
        { "Stamina", Stat(3), Whole },
        { "Armor", Armor, Whole },
        { "Dodge", function() return GetDodgeChance() end, Percent },
    },
    right = {
        { "Parry", function() return GetParryChance() end, Percent },
        { "Leech", function() return GetLifesteal() end, Percent },
        { "Avoidance", function() return GetAvoidance() end, Percent },
        { "Movement Speed", Speed, Percent },
    },
}

local layout, ribbon, badge, columns, resist
local stats = { height = 0 }
ns.character.stats = stats

-- a value, or nothing when this client cannot give it; a secret one (the
-- player's health and power on the clients that hide them) shortened by
-- the one formatter that takes it, or shown as it is
local function Read(entry)
    local ok, v = pcall(entry[2])
    if not ok then return end
    if ns.IsSecret(v) then
        local fine, text = pcall(AbbreviateLargeNumbers, v)
        return fine and text or v
    end
    if type(v) ~= "number" then return end
    local ok2, text = pcall(entry[3], v)
    if ok2 then return text end
end

local function Label(entry)
    local l = entry[1]
    return type(l) == "function" and l() or l
end

-- ------------------------------------------------------------- the ribbon
local function Cell(foot, i)
    local c = CreateFrame("Frame", nil, foot)
    c.label = ns.Text(c, 10)
    c.label:SetPoint("TOP", 0, -9)
    c.label:SetTextColor(unpack(ns.colors.dim))
    c.value = ns.Text(c, 17)
    c.value:SetPoint("BOTTOM", 0, 8)
    c.index = i
    return c
end

local function Ribbon(foot)
    local frame = CreateFrame("Frame", nil, foot)
    frame:SetPoint("TOPLEFT")
    frame:SetPoint("TOPRIGHT")
    frame:SetHeight(RIBBON)
    -- a gold band, bright at the middle, a hairline on each edge
    for k, at in ipairs({ "LEFT", "RIGHT" }) do
        local half = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        half:SetPoint("TOP" .. at)
        half:SetPoint("BOTTOM")
        half:SetPoint(at == "LEFT" and "BOTTOMRIGHT" or "BOTTOMLEFT", frame, "BOTTOM")
        if half.SetGradient and CreateColor then
            half:SetColorTexture(1, 1, 1, 1)
            local lo = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.04)
            local hi = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.3)
            half:SetGradient("HORIZONTAL", k == 1 and lo or hi, k == 1 and hi or lo)
        else
            half:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.15)
        end
    end
    frame.edges = {}
    for _, at in ipairs({ "TOP", "BOTTOM" }) do
        local e = frame:CreateTexture(nil, "BORDER")
        e:SetHeight(1)
        e:SetPoint(at .. "LEFT")
        e:SetPoint(at .. "RIGHT")
        e:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        table.insert(frame.edges, e)
    end
    -- the item level in a medallion's ring in the middle, over the band's
    -- edges: the gold rim, a dark line in it, the ink well
    local b = CreateFrame("Frame", nil, frame)
    b:SetSize(BADGE, BADGE)
    b:SetPoint("CENTER")
    b:SetFrameLevel(frame:GetFrameLevel() + 2)
    b.rings = {}
    for k, ring in ipairs({ { BADGE, GOLD }, { BADGE - 3, ns.colors.ink }, { BADGE - 5, GOLD_D },
        { BADGE - 7, ns.colors.ink } }) do
        local t = b:CreateTexture(nil, "BACKGROUND", nil, k)
        t:SetSize(ring[1], ring[1])
        t:SetPoint("CENTER")
        t:SetTexture(ns.media .. "strips\\round")
        t:SetVertexColor(ring[2][1], ring[2][2], ring[2][3], 1)
        b.rings[k] = t
    end
    b.value = ns.Text(b, 19)
    b.value:SetPoint("CENTER", 0, 4)
    b.value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    b.label = ns.Text(b, 8)
    b.label:SetPoint("CENTER", 0, -12)
    b.label:SetText("ilvl")
    b.label:SetTextColor(unpack(ns.colors.dim))
    -- two cells each side, each a quarter of what the badge leaves
    local cells = {}
    local width = ns.character.width
    local cell = (width - BADGE) / 4
    for i = 1, 4 do
        local c = Cell(frame, i)
        c:SetSize(cell, RIBBON)
        local x = (i - 1) * cell + (i > 2 and BADGE or 0)
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        cells[i] = c
        if i == 1 or i == 3 then
            -- a hairline between the pair
            c.split = frame:CreateTexture(nil, "BORDER")
            c.split:SetSize(1, RIBBON - 20)
            c.split:SetPoint("CENTER", c, "RIGHT", 0, 0)
            c.split:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
        end
    end
    return frame, cells, b
end

-- -------------------------------------------------------------- columns
local function Rows(foot, entries, side)
    local list = {}
    for i = 1, #entries do
        local r = CreateFrame("Frame", nil, foot)
        r:SetHeight(ROW)
        local half = ns.character.width / 2
        r:SetWidth(half - 8)
        r.side = side
        -- a hairline at its foot (Fill hides the column's last)
        r.hair = r:CreateTexture(nil, "BACKGROUND")
        r.hair:SetHeight(1)
        r.hair:SetPoint("BOTTOMLEFT")
        r.hair:SetPoint("BOTTOMRIGHT")
        r.hair:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
        r.label = ns.Text(r, 13)
        r.label:SetPoint("LEFT", 4, 0)
        r.label:SetTextColor(unpack(ns.colors.text))
        r.value = ns.Text(r, 13)
        r.value:SetPoint("RIGHT", -4, 0)
        list[i] = r
    end
    return list
end

-- The five resistances: a label and a hairline, then a row of ink cells
-- across the panel, each with its school's gem, its name and its value, a
-- line of its tint along its foot; the school in its tooltip too.
local function Resist(foot)
    local frame = CreateFrame("Frame", nil, foot)
    frame:SetHeight(LABEL + BOX)
    frame:SetPoint("BOTTOMLEFT")
    frame:SetPoint("BOTTOMRIGHT")
    frame.cells = {}
    frame.label = ns.Text(frame, 10)
    frame.label:SetPoint("TOPLEFT", 0, 0)
    frame.label:SetText("Resistances")
    frame.label:SetTextColor(unpack(ns.colors.dim))
    frame.hair = frame:CreateTexture(nil, "BACKGROUND")
    frame.hair:SetHeight(1)
    frame.hair:SetPoint("LEFT", frame.label, "RIGHT", 8, 0)
    frame.hair:SetPoint("RIGHT", frame, "TOPRIGHT", 0, -6)
    frame.hair:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
    local gap = 6
    local w = math.floor((ns.character.width - (#SCHOOLS - 1) * gap) / #SCHOOLS)
    local x = math.floor((ns.character.width - #SCHOOLS * w - (#SCHOOLS - 1) * gap) / 2)
    for i, school in ipairs(SCHOOLS) do
        local c = CreateFrame("Frame", nil, frame)
        c:SetSize(w, BOX)
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -LABEL)
        x = x + w + gap
        local col = SCHOOL_COLOR[school]
        c.edge = c:CreateTexture(nil, "BACKGROUND", nil, -2)
        c.edge:SetAllPoints()
        c.edge:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
        c.well = c:CreateTexture(nil, "BACKGROUND", nil, -1)
        c.well:SetPoint("TOPLEFT", 1, -1)
        c.well:SetPoint("BOTTOMRIGHT", -1, 1)
        c.well:SetColorTexture(0.094, 0.086, 0.075, 1)
        c.tint = c:CreateTexture(nil, "ARTWORK")
        c.tint:SetHeight(2)
        c.tint:SetPoint("BOTTOMLEFT")
        c.tint:SetPoint("BOTTOMRIGHT")
        c.tint:SetColorTexture(col[1] * 0.75, col[2] * 0.75, col[3] * 0.75, 1)
        -- the gem: a square on its corner, gold under the school's colour
        c.gem = c:CreateTexture(nil, "ARTWORK", nil, 2)
        c.gem:SetSize(7, 7)
        c.gem:SetPoint("CENTER", c, "LEFT", 13, 0)
        c.gem:SetColorTexture(col[1], col[2], col[3], 1)
        c.gemRim = c:CreateTexture(nil, "ARTWORK", nil, 1)
        c.gemRim:SetSize(9, 9)
        c.gemRim:SetPoint("CENTER", c.gem)
        c.gemRim:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        if c.gem.SetRotation then
            c.gem:SetRotation(math.pi / 4)
            c.gemRim:SetRotation(math.pi / 4)
        end
        c.name = ns.Text(c, 10)
        c.name:SetPoint("LEFT", 22, 0)
        c.name:SetText(school)
        c.name:SetTextColor(unpack(ns.colors.dim))
        c.value = ns.Text(c, 14)
        c.value:SetPoint("RIGHT", -8, 0)
        c.school = school
        c:EnableMouse(true)
        c:SetScript("OnEnter", function(self)
            ns.Tip(self, ns.window.OutsideTop, { title = format("%s resistance", school), color = col })
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.cells[i] = c
    end
    return frame
end

function stats.Build(foot)
    layout = SkillsFrame and FOREVER or RETAIL
    local cells
    ribbon, cells, badge = Ribbon(foot)
    ribbon.cells = cells
    columns = { left = Rows(foot, layout.left, -1), right = Rows(foot, layout.right, 1) }
    local rows = math.max(#layout.left, #layout.right)
    stats.height = RIBBON + 3 + GAP + rows * ROW
    -- a gold rule down between the two columns, fading at both ends
    local split = ns.window.Hair(foot, true)
    split:SetHeight(rows * ROW - 4)
    split:SetPoint("TOP", foot, "TOP", 0, -(RIBBON + 3 + GAP + 2))
    stats.split = split
    if layout.resist then
        resist = Resist(foot)
        stats.height = stats.height + GAP + LABEL + BOX
    end
    stats.ribbon, stats.badge, stats.columns, stats.resist = ribbon, badge, columns, resist
    stats.forever = layout == FOREVER
end

-- the ribbon and the rows, for the inspect window's summary (inspect/page.lua)
ns.character.Ribbon, ns.character.Rows = Ribbon, Rows
ns.character.ribbon = { height = RIBBON, row = ROW, gap = GAP }

-- One column: the rows that read, top down; the rest hidden.
local function Fill(rows, entries, side)
    local y, k, last = RIBBON + 3 + GAP, 0, nil
    for i, entry in ipairs(entries) do
        local r = rows[i]
        local text = Read(entry)
        r:SetShown(text ~= nil)
        if text then
            k = k + 1
            r.hair:Show()
            last = r
            r.label:SetText(Label(entry))
            r.value:SetText(text)
            r:ClearAllPoints()
            r:SetPoint(side < 0 and "TOPLEFT" or "TOPRIGHT", r:GetParent(), side < 0 and "TOPLEFT" or "TOPRIGHT",
                0, -y)
            y = y + ROW
        end
    end
    if last then last.hair:Hide() end
end

function stats.Refresh()
    for i, entry in ipairs(layout.ribbon) do
        local c = ribbon.cells[i]
        c.label:SetText(Label(entry))
        c.value:SetText(Read(entry) or "--")
    end
    local avg, equipped
    if GetAverageItemLevel then avg, equipped = GetAverageItemLevel() end
    local level = equipped or avg
    badge.value:SetText(level and tostring(math.floor(level)) or "--")
    Fill(columns.left, layout.left, -1)
    Fill(columns.right, layout.right, 1)
    if resist then
        for _, c in ipairs(resist.cells) do
            -- base, real, effective, bonus: the effective one, as Blizzard's pane shows
            local ok, _, _, total = pcall(UnitResistance, "player", SCHOOL_CLASS[c.school])
            local has = ok and type(total) == "number"
            c.value:SetText(has and Whole(total) or "--")
            local tc = has and total > 0 and ns.colors.text or ns.colors.dim
            c.value:SetTextColor(tc[1], tc[2], tc[3])
        end
    end
end
