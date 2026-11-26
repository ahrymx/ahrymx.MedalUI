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
local Tr = ns.L

local ROW, RIBBON, BADGE, GAP = 22, 50, 54, 10
-- (2026-11-19, /workspace/sleek-character.png) the ribbon a gold band with
-- hairlines, the item level in a medallion's ring, the rows on hairlines,
-- each resistance an ink cell: its gem, its school, its value, its tint under
local HAIR = { 0.204, 0.176, 0.129 }
local GOLD = ns.gold.light
local GOLD_D = ns.gold.dark
local SCHOOLS = { "Arcane", "Fire", "Frost", "Nature", "Shadow" }
-- each school's box: its tint
local SCHOOL_COLOR = { Arcane = { 0.6, 0.45, 1 }, Fire = { 1, 0.36, 0.16 }, Frost = { 0.36, 0.66, 1 },
    Nature = { 0.32, 0.86, 0.36 }, Shadow = { 0.67, 0.3, 0.84 } }
local BOX, LABEL = 34, 16                       -- a resistance's cell, its height; the label over them
local SCHOOL_CLASS = { Arcane = 6, Fire = 2, Frost = 4, Nature = 3, Shadow = 5 }   -- Enum.Damageclass
-- each school's name as shown, and as the object of "Reduces %s damage"
local SCHOOL_NAME = { Arcane = Tr["Arcane"], Fire = Tr["Fire"], Frost = Tr["Frost"], Nature = Tr["Nature"],
    Shadow = Tr["Shadow"] }
local SCHOOL_DAMAGE = { Arcane = Tr["arcane"], Fire = Tr["fire"], Frost = Tr["frost"], Nature = Tr["nature"],
    Shadow = Tr["shadow"] }

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
    return _G["SPELL_STAT" .. at .. "_NAME"] or ({ Tr["Strength"], Tr["Agility"], "", Tr["Intellect"] })[at], at
end

local function Speed()
    local _, run = GetUnitSpeed("player")
    return run / (BASE_MOVEMENT_SPEED or 7) * 100
end

local function Power() return UnitPowerMax("player") end
local function PowerName()
    local _, token = UnitPowerType("player")
    return token and _G[token] or Tr["Power"]
end

-- ------------------------------------------------------------ tooltips
-- (2026-11-19) each stat's tooltip, as Blizzard's own pane's: the stat and
-- its value, what makes it up, and what it does, from the game's own
-- functions; a line whose function this client lacks is left out.
local GOOD, BAD = "|cff40ff40", "|cffff4d40"

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end
local function Num(v) return type(v) == "number" and not ns.IsSecret(v) and v or nil end
local function Pct(v) return format("%.2f%%", v) end

-- "100 +8 -3", the bonus green, the loss red
local function Made(base, pos, neg)
    local s = Whole(base)
    if Num(pos) and pos > 0 then s = s .. "  " .. GOOD .. "+" .. Whole(pos) .. "|r" end
    if Num(neg) and neg < 0 then s = s .. "  " .. BAD .. Whole(neg) .. "|r" end
    return s
end
local function Line(fmt, v, ...) return Num(v) and { "body", format(fmt, v, ...) } or false end
local function Level() return Call(UnitLevel, "player") or 60 end

-- a primary stat: its parts, then what it gives
local function PrimaryTip(i, name)
    return function()
        local base, stat, pos, neg = Call(UnitStat, "player", i)
        stat = Num(stat) or 0
        local spec = { title = format("%s %s", name, Whole(stat)) }
        if Num(base) then table.insert(spec, { "row", Tr["Base"], Whole(base) }) end
        if Num(pos) and pos > 0 then table.insert(spec, { "row", Tr["Bonus"], GOOD .. "+" .. Whole(pos) .. "|r" }) end
        if Num(neg) and neg < 0 then table.insert(spec, { "row", Tr["Penalty"], BAD .. Whole(neg) .. "|r" }) end
        local _, token = Call(UnitPowerType, "player")
        if i == 1 or i == 2 then
            local ap = Num(Call(GetAttackPowerForStat, i, stat))
            if ap and ap > 0 then table.insert(spec, Line(Tr["Increases attack power by %d."], ap)) end
        end
        if i == 2 then
            table.insert(spec, Line(Tr["Increases critical strike chance by %.2f%%."],
                Num(Call(GetCritChanceFromAgility, "player"))))
            table.insert(spec, Line(Tr["Increases armor by %d."], stat * 2))
        elseif i == 3 then
            table.insert(spec, Line(Tr["Increases health by %d."], math.max(0, stat - 20) * 10 + math.min(stat, 20)))
        elseif i == 4 then
            if token == "MANA" then
                table.insert(spec, Line(Tr["Increases mana by %d."], math.max(0, stat - 20) * 15 + math.min(stat, 20)))
            end
            table.insert(spec, Line(Tr["Increases spell critical strike chance by %.2f%%."],
                Num(Call(GetSpellCritChanceFromIntellect, "player"))))
        elseif i == 5 then
            table.insert(spec, Line(Tr["Regenerates %.1f health per second out of combat."],
                Num(Call(GetUnitHealthRegenRateFromSpirit, "player"))))
            if token == "MANA" then
                local regen = Num(Call(GetUnitManaRegenRateFromSpirit, "player"))
                table.insert(spec, Line(Tr["Regenerates %d mana every 5 seconds while not casting."],
                    regen and regen * 5))
            end
        end
        return spec
    end
end

local function HealthTip()
    local now, most = Num(Call(UnitHealth, "player")), Num(Call(UnitHealthMax, "player"))
    return { title = Tr["Health"], now and { "row", Tr["Current"], Whole(now) } or false,
        most and { "row", Tr["Maximum"], Whole(most) } or false }
end

local function PowerTip()
    local most = Num(Call(UnitPowerMax, "player"))
    local spec = { title = format("%s %s", PowerName(), most and Whole(most) or "") }
    local base, casting = Call(GetManaRegen)
    local _, token = Call(UnitPowerType, "player")
    if token == "MANA" and Num(base) then
        table.insert(spec, { "row", Tr["Regeneration"], format(Tr["%d per 5 sec"], base * 5) })
        if Num(casting) then table.insert(spec, { "row", Tr["While casting"], format(Tr["%d per 5 sec"],
            casting * 5) }) end
    end
    return spec
end

local function AttackTip()
    local base, pos, neg = Call(UnitAttackPower, "player")
    local total = (Num(base) or 0) + (Num(pos) or 0) + (Num(neg) or 0)
    local spec = { title = format("%s %s", Tr["Attack Power"], Whole(total)), { "row", Tr["Melee"], Made(base or 0,
        pos, neg) },
        Line(Tr["Increases melee damage by %.1f damage per second."],
            math.max(total, 0) / (ATTACK_POWER_MAGIC_NUMBER or 14)) }
    local rb, rp, rn = Call(UnitRangedAttackPower, "player")
    local ranged = (Num(rb) or 0) + (Num(rp) or 0) + (Num(rn) or 0)
    if ranged > 0 then
        table.insert(spec, { "row", Tr["Ranged"], Made(rb, rp, rn) })
        table.insert(spec, Line(Tr["Increases ranged damage by %.1f damage per second."],
            ranged / (ATTACK_POWER_MAGIC_NUMBER or 14)))
    end
    return spec
end

local SPELL_SCHOOLS = { { Tr["Holy"], 2 }, { Tr["Fire"], 3 }, { Tr["Nature"], 4 }, { Tr["Frost"], 5 },
    { Tr["Shadow"], 6 }, { Tr["Arcane"], 7 } }
local function SpellTip()
    local spec = { title = format("%s %s", Tr["Spell Power"], Whole(SpellSchools(GetSpellBonusDamage) or 0)) }
    local list = {}
    for _, sc in ipairs(SPELL_SCHOOLS) do
        local v = Num(Call(GetSpellBonusDamage, sc[2]))
        if v then list[#list + 1] = { sc[1], v } end
    end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for _, e in ipairs(list) do table.insert(spec, { "row", e[1], Whole(e[2]) }) end
    table.insert(spec, { "hint", Tr["Bonus damage to your spells, by school"] })
    return spec
end

local function HealingTip()
    local v = Num(Call(GetSpellBonusHealing)) or 0
    return { title = format("%s %s", Tr["Healing"], Whole(v)),
        Line(Tr["Increases healing done by spells by up to %d."], v) }
end

local function DefenseTip()
    local base, mod = Call(UnitDefenseSkill, "player")
    base, mod = Num(base) or 0, Num(mod) or 0
    local total = base + mod
    local extra = (total - Level() * 5) * 0.04
    local spec = { title = format("%s %s", Tr["Defense"], Whole(total)), { "row", Tr["Skill"], Whole(base) },
        mod ~= 0 and { "row", Tr["Bonus"], (mod > 0 and GOOD .. "+" or BAD) .. Whole(mod) .. "|r" } or false }
    if extra > 0 then
        table.insert(spec, Line(Tr["Increases chance to be missed, dodged, parried and blocked by %.2f%%."], extra))
        table.insert(spec, Line(Tr["Decreases chance to be hit and critically hit by %.2f%%."], extra))
    end
    return spec
end

local function ChanceTip(name, fn, says)
    return function()
        local v = Num(Call(fn)) or 0
        return { title = format("%s %s", name, Pct(v)), Line(says, v) }
    end
end

local function BlockTip()
    local v = Num(Call(GetBlockChance)) or 0
    local spec = { title = format("%s %s", Tr["Block"], Pct(v)),
        Line(Tr["%.2f%% chance to block an attack with a shield."], v) }
    table.insert(spec, Line(Tr["A block stops %d damage."], Num(Call(GetShieldBlock))))
    return spec
end

local function HitTip()
    local melee = (Num(Call(GetHitModifier)) or 0) + Rating(CR_HIT_MELEE)
    local spell = (Num(Call(GetSpellHitModifier)) or 0) + Rating(CR_HIT_SPELL)
    return { title = format("%s %s", Tr["Hit"], Percent(math.max(melee, spell))), { "row", Tr["Melee and ranged"],
        Pct(melee) },
        { "row", Tr["Spells"], Pct(spell) }, { "hint", Tr["Lowers the chance your attacks and spells miss"] } }
end

local function CritTip()
    local melee, ranged = Num(Call(GetCritChance)), Num(Call(GetRangedCritChance))
    local spell = Num(SpellSchools(GetSpellCritChance))
    return { title = format("%s %s", Tr["Crit"], Percent(Crit() or 0)), melee and { "row", Tr["Melee"],
        Pct(melee) } or false,
        ranged and { "row", Tr["Ranged"], Pct(ranged) } or false, spell and { "row", Tr["Spells"],
            Pct(spell) } or false }
end

local function HasteTip()
    local melee = Num(Call(GetMeleeHaste)) or Num(Call(GetHaste))
    local ranged, spell = Num(Call(GetRangedHaste)), Num(Call(UnitSpellHaste, "player"))
    return { title = format("%s %s", Tr["Haste"], Percent(Haste() or 0)), melee and { "row", Tr["Melee"],
        Pct(melee) } or false,
        ranged and { "row", Tr["Ranged"], Pct(ranged) } or false, spell and { "row", Tr["Spells"],
            Pct(spell) } or false }
end

local function ArmorTip()
    local base, effective, _, pos, neg = Call(UnitArmor, "player")
    effective = Num(effective) or 0
    local level = Level()
    local cut = Num(Call(PaperDollFrame_GetArmorReduction, effective, level))
        or effective / (effective + 400 + 85 * level) * 100
    return { title = format("%s %s", Tr["Armor"], Whole(effective)), Num(base) and { "row", Tr["Base"], Made(base,
        pos, neg) } or false,
        Line(Tr["Reduces physical damage taken by %.2f%%"], cut),
        { "hint", format(Tr["Against a level %d attacker"], level) } }
end

-- retail: the value, and its rating where it has one
local function RatedTip(name, cr, fmt)
    return function(text)
        local rating = cr and Num(Call(GetCombatRating, cr))
        return { title = format("%s %s", name, text or ""), rating and { "row", Tr["Rating"], Whole(rating) } or false,
            fmt and { "hint", fmt } or false }
    end
end

local function ItemLevelTip()
    local avg, equipped = Call(GetAverageItemLevel)
    return { title = Tr["Item Level"], Num(equipped) and { "row", Tr["Equipped"], format("%.1f", equipped) } or false,
        Num(avg) and { "row", Tr["Overall"], format("%.1f", avg) } or false,
        { "hint", Tr["The average of your gear's item levels"] } }
end

local function ResistTip(school, col)
    local base, total = Call(UnitResistance, "player", SCHOOL_CLASS[school])
    local _, _, _, shown = Call(UnitResistance, "player", SCHOOL_CLASS[school])
    total = Num(shown) or Num(total) or 0
    local cut = math.min(75, total / (Level() * 5) * 75)
    return { title = format(Tr["%s resistance %s"], SCHOOL_NAME[school], Whole(total)), color = col,
        Num(base) and { "row", Tr["Base"], Whole(base) } or false,
        total > 0 and { "body", format(Tr["Reduces %s damage taken by about %.0f%% on average."],
            SCHOOL_DAMAGE[school], cut) } or false,
        { "hint", format(Tr["Against a level %d caster"], Level()) } }
end

-- { label, value (a function), format, tooltip (a function of the shown
-- text, its spec) }; a label may be a function too
local FOREVER = {
    ribbon = {
        { Tr["Hit"], Hit, Percent, HitTip }, { Tr["Crit"], Crit, Percent, CritTip },
        { Tr["Haste"], Haste, Percent, HasteTip }, { Tr["Armor"], Armor, Whole, ArmorTip },
    },
    left = {
        { Tr["Health"], function() return UnitHealthMax("player") end, Whole, HealthTip },
        { PowerName, Power, Whole, PowerTip },
        { Tr["Strength"], Stat(1), Whole, PrimaryTip(1, Tr["Strength"]) },
        { Tr["Agility"], Stat(2), Whole, PrimaryTip(2, Tr["Agility"]) },
        { Tr["Stamina"], Stat(3), Whole, PrimaryTip(3, Tr["Stamina"]) },
        { Tr["Intellect"], Stat(4), Whole, PrimaryTip(4, Tr["Intellect"]) },
        { Tr["Spirit"], Stat(5), Whole, PrimaryTip(5, Tr["Spirit"]) },
    },
    right = {
        { Tr["Attack Power"], function()
            local base, pos, neg = UnitAttackPower("player")
            return base + pos + neg
        end, Whole, AttackTip },
        { Tr["Spell Power"], function() return SpellSchools(GetSpellBonusDamage) end, Whole, SpellTip },
        { Tr["Healing"], function() return GetSpellBonusHealing() end, Whole, HealingTip },
        { Tr["Defense"], function()
            local base, mod = UnitDefenseSkill("player")
            return base + mod
        end, Whole, DefenseTip },
        { Tr["Dodge"], function() return GetDodgeChance() end, Percent,
            ChanceTip(Tr["Dodge"], function() return GetDodgeChance() end,
                Tr["%.2f%% chance to dodge melee attacks."]) },
        { Tr["Parry"], function() return GetParryChance() end, Percent,
            ChanceTip(Tr["Parry"], function() return GetParryChance() end,
                Tr["%.2f%% chance to parry melee attacks."]) },
        { Tr["Block"], function() return GetBlockChance() end, Percent, BlockTip },
    },
    resist = true,
}

local RETAIL = {
    ribbon = {
        { Tr["Crit"], Crit, Percent, RatedTip(Tr["Critical Strike"], CR_CRIT_MELEE) },
        { Tr["Haste"], Haste, Percent, RatedTip(Tr["Haste"], CR_HASTE_MELEE) },
        { Tr["Mastery"], function() return GetMasteryEffect() end, Percent, RatedTip(Tr["Mastery"], CR_MASTERY) },
        { Tr["Vers"], function()
            return Rating(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
        end, Percent, RatedTip(Tr["Versatility"], CR_VERSATILITY_DAMAGE_DONE) },
    },
    left = {
        { PrimaryName, function() return select(2, UnitStat("player", select(2, PrimaryName()))) end, Whole,
            function() local name, at = PrimaryName() return PrimaryTip(at, name)() end },
        { Tr["Stamina"], Stat(3), Whole, PrimaryTip(3, Tr["Stamina"]) },
        { Tr["Armor"], Armor, Whole, ArmorTip },
        { Tr["Dodge"], function() return GetDodgeChance() end, Percent, RatedTip(Tr["Dodge"], CR_DODGE) },
    },
    right = {
        { Tr["Parry"], function() return GetParryChance() end, Percent, RatedTip(Tr["Parry"], CR_PARRY) },
        { Tr["Leech"], function() return GetLifesteal() end, Percent, RatedTip(Tr["Leech"], CR_LIFESTEAL) },
        { Tr["Avoidance"], function() return GetAvoidance() end, Percent, RatedTip(Tr["Avoidance"], CR_AVOIDANCE) },
        { Tr["Movement Speed"], Speed, Percent, RatedTip(Tr["Movement Speed"], CR_SPEED) },
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

-- a stat's frame shows its tooltip (self.tip, set when filled; none in
-- the inspect window), a faint gold wash under it while it does
local function Hover(f)
    f:EnableMouse(true)
    f.wash = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.wash:SetAllPoints()
    f.wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.14)
    f.wash:Hide()
    f:SetScript("OnEnter", function(self)
        if not self.tip then return end
        local ok, spec = pcall(self.tip, self.value and self.value:GetText())
        if not (ok and type(spec) == "table") then return end
        self.wash:Show()
        ns.Tip(self, ns.window.OutsideTop, spec)
    end)
    f:SetScript("OnLeave", function(self)
        self.wash:Hide()
        GameTooltip:Hide()
    end)
end

-- ------------------------------------------------------------- the ribbon
local function Cell(foot, i)
    local c = CreateFrame("Frame", nil, foot)
    Hover(c)
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
    -- the item level in a medallion in the middle, over the band's edges:
    -- the medallions' bezel (bezel.lua) round an ink face
    local b = CreateFrame("Frame", nil, frame)
    b:SetSize(BADGE, BADGE)
    b:SetPoint("CENTER")
    b:SetFrameLevel(frame:GetFrameLevel() + 2)
    b.face = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.face:SetSize(BADGE - 2, BADGE - 2)
    b.face:SetPoint("CENTER")
    b.face:SetTexture(ns.media .. "strips\\round")
    b.face:SetVertexColor(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    b.rim = ns.Bezel(b, BADGE, "BORDER", 1)
    b.rim:SetPoint("CENTER")
    b.rings = { b.face, b.rim }
    b.value = ns.Text(b, 19)
    b.value:SetPoint("CENTER", 0, 4)
    b.value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    b.label = ns.Text(b, 8)
    b.label:SetPoint("CENTER", 0, -12)
    b.label:SetText(Tr["ilvl"])
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
        Hover(r)
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
    frame.label:SetText(Tr["Resistances"])
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
        c.name:SetText(SCHOOL_NAME[school])
        c.name:SetTextColor(unpack(ns.colors.dim))
        c.value = ns.Text(c, 14)
        c.value:SetPoint("RIGHT", -8, 0)
        c.school = school
        c:EnableMouse(true)
        c:SetScript("OnEnter", function(self)
            local ok, spec = pcall(ResistTip, school, col)
            ns.Tip(self, ns.window.OutsideTop, ok and spec or { title = format(Tr["%s resistance"],
                SCHOOL_NAME[school]),
                color = col })
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
    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(self) ns.Tip(self, ns.window.OutsideTop, ItemLevelTip()) end)
    badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
            r.tip = entry[4]
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
        c.tip = entry[4]
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
