-- The professions: Medalluin's own (the shell is window/shell.lua), standing
-- on the right strip as the spellbook does, its margin beside the
-- backpack's medallion. Forever only: its professions book and crafting are
-- one frame, ProfessionsFrame (the book its Overview page); retail keeps
-- Blizzard's.
--
--    Overview   primary   primary                                  x
--   ____                       (open tabs: no boxes, the one in use
--    secondary   secondary      underlined; rows on fading hairs)
--   ---------------------------------------------------------------
--             the character's header, its portrait on its rule
--             (professions/alts.lua)
--   ------------------<> Primary professions <>--------------------
--     (each pillar its craft engraved behind, media/professions)
--               (icon)            :            (icon)
--           Blacksmithing         :            Mining
--      [===|== 142 / 150 =====]   :   [===|== 87 / 150 ====   ]
--          Train Expert now       :   Expert at skill 125, level 20
--          [spell] [spell]     x  :       [spell] [spell]      x
--   -----------------<> Secondary professions <>-------------------
--        .(icon).            .(icon).            .(icon).
--        First Aid           Fishing             Cooking
--         1 / 75              1 / 75              5 / 75
--         [spell]         [spell][spell]          [spell]
--   -----------------------<> Cooldowns <>-------------------------
--   (icon) Transmute: Arcanite      Barkhide              1d 6h
--   (icon) Mooncloth                Medalluin             Ready
--   ------------------------<> Camping <>--------------------------
--   the camp's buffs and objects on its engraving (professions/camping.lua)
--   ---------------------------------------------------------------
--   [Alts 3]  Barkhide, Medalluin  ·  Pyrewood          (the band)
--
-- (/workspace/professions-mock-B-1.png, B-2.) The headings are ribbons
-- (ns.window.Ribbon); the bars notched at each rank's cap. The window runs
-- to the screen's top (window/shell.lua), so Fit shares out the height to
-- spare: the gaps a little wider, the pillars taller, then the rest
-- between Cooldowns and Camping, which stands at the foot.
--
-- Overview is a pillar per primary profession (an empty one when not
-- learned) and a line per secondary learned, under a heading each (none
-- learned: no heading), then the Cooldowns (your characters' cooldown
-- crafts, professions/altdata.lua) and Camping; each other tab is a profession with recipes, crafted here
-- (professions/crafting.lua). The tabs are Overview and one per profession
-- that crafts, six at most: Overview and the primaries on the first row,
-- the secondaries on a second under it (none: no second row); fewer
-- professions, wider tabs. The details are always open (no chevron).
--
-- Under a pillar's bar, or in a line's tooltip, its next rank: gold when its skill and level are met
-- (red when the bar is within 5 of its cap, points about to be wasted),
-- dim with what it asks otherwise. The ranks are the game's (Journeyman at
-- skill 50 and level 10, ...), a trainer's own list preferred once read
-- (spells/trainers.lua); none past what this expansion's level reaches.
--
-- A card's spells (Smelting, Find Herbs) are cast by the client: secure
-- buttons over them in a layer on the strip, as the spellbook's are, gone
-- in combat. Unlearn is Blizzard's own question.
--
-- Blizzard's frame keeps every way in: the key, the micro button, a
-- profession's spell. It opens and closes under a hidden parent, and this
-- window shows while it is open, on the page Blizzard shows: Overview for
-- its book, the open profession's tab for its crafting. A profession's tab
-- opens that profession (out of combat); Overview turns our page alone.
local _, ns = ...
local Tr = ns.L

local GOLD = { 0.941, 0.831, 0.533 }
local RED = { 1, 0.3, 0.25 }
local GAP, ICON, SPELL, SMALL = 6, 40, 30, 24   -- a pillar's icon and spells; a line's both
local PILLAR = 190                      -- a primary's pillar, at the least
local HALF = math.floor((ns.window.width - GAP) / 2)    -- a pillar's width
local SPELL_Y = 140                     -- a pillar's spells' top
-- the art (art/professions/gen_overview.py): a pillar's scene the bottom
-- 400 px of a 256x512, as wide as the pillar; the night's sky the top 346 px
-- of a 512x512 and its land the bottom 401, as wide as the page; between
-- them, on a tall screen, the horizon's colour. One set for each style
-- (the Overview art option, professionsArt), in its folder; the horizons
-- as the generator prints them.
local SCENE_PX, SKY_PX, LAND_PX, TEX = 400, 346, 401, 512
local HORIZON = {
    engraved = { 0.087, 0.075, 0.055 },
    painted = { 0.138, 0.157, 0.259 },
    poster = { 0.098, 0.118, 0.192 },
}
-- a scene's texture in the chosen style
local function Art(name)
    local style = HORIZON[ns.db and ns.db.professionsArt] and ns.db.professionsArt or "engraved"
    return ns.media .. "professions\\" .. style .. "\\" .. name, HORIZON[style]
end
local COOLDOWNS, COOL_ROW = 6, 24       -- the cooldowns listed, at most; a row
local CROSS, FAINT = 16, 0.45           -- Unlearn's cross, and its alpha at rest
local CARDS = 5                         -- two primaries and three secondaries
local BAR_TALL = 18                     -- a pillar's bar
local MEDAL, SEC_H, SEC_SPELL_Y = 44, 126, 100  -- a secondary's ring, its height, its spells' top
local DIAL = 60                         -- the ticks round a secondary's ring, its skill
local THIRD = math.floor(ns.window.width / 3)   -- a secondary's width
local GLASS_ROOM = 60                   -- the empty cooldowns' room to stand the hourglass over its line
local SPARE_GAP, GROW = 16, 120         -- what Fit adds at most to each heading's gap, to the pillars
local NONE = "Interface\\Icons\\INV_Scroll_04"

local W = ns.Window{
    name = "MedalluinProfessions", named = Tr["Professions"], side = 1,
    closeTip = Tr["Close the professions."],
    Close = function() HideUIPanel(ProfessionsFrame) end,
    Open = function(page) if page.Open then page.Open() end end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.professions = W
-- the panel the shell joins under the head on every tab, for its banner
-- (the Overview's, alts.lua; a profession's skill, crafting.lua): the
-- character window's height
W.UNDER = 44

local layer                             -- the cards' spells, secure, on the strip
local open                              -- the window open on Overview
local overview

-- ------------------------------------------------------------- the data
-- The professions learned, in the game's order (the two primaries, then
-- the secondaries), each { index, name, icon, rank, max, modifier, spells,
-- offset, skillLine, primary, crafts, spell (its crafting spell, which
-- opens its window) }.
function W.Learned()
    local out = {}
    local list = { GetProfessions() }
    for i = 1, math.max(2, select("#", GetProfessions())) do
        local index = list[i]
        if index then
            local name, icon, rank, max, spells, offset, skillLine, modifier = GetProfessionInfo(index)
            local item = C_SpellBook.GetSpellBookItemInfo(offset + 1, Enum.SpellBookSpellBank.Player)
            local crafts = item and item.spellID and C_TradeSkillUI.CanTradeSkillShowCraftingUI(item.spellID) or false
            table.insert(out, { index = index, name = name, icon = icon, rank = rank, max = max,
                modifier = modifier or 0, spells = spells, offset = offset, skillLine = skillLine,
                primary = i <= 2, crafts = crafts, spell = item and item.spellID })
        elseif i <= 2 then
            table.insert(out, { primary = true })
        end
    end
    return out
end

-- the profession whose crafting is open, by its base skill line
function W.Skill()
    if Professions and Professions.GetEffectiveSkillLineID then return Professions.GetEffectiveSkillLineID() end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    return info and info.professionID or 0
end

-- The ranks: name (as the game's trainers name it: it is read in their
-- services), cap, the level and skill to learn it
local RANKS = {
    { Tr["Apprentice"], 75, 1, 1 }, { Tr["Journeyman"], 150, 10, 50 }, { Tr["Expert"], 225, 20, 125 },
    { Tr["Artisan"], 300, 35, 200 }, { Tr["Master##rank"], 375, 50, 275 }, { Tr["Grand Master"], 450, 65, 350 },
}

-- each rank's cap: a bar's notches
local NOTCHES = {}
for i, r in ipairs(RANKS) do NOTCHES[i] = r[2] end

-- the highest cap this expansion reaches: Artisan's at 60, a rank a 10 levels
local function Top()
    local level = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60
    return 300 + 75 * math.max(0, math.floor((level - 60) / 10))
end

-- the rank after a profession's: { name, level, skill }, or nil at the top;
-- a trainer's service of that rank's name, when one was read, says instead
function W.NextRank(prof)
    for _, r in ipairs(RANKS) do
        if r[2] > prof.max then
            if r[2] > Top() then return nil end
            local out = { name = r[1], level = r[3], skill = r[4] }
            local list = ns.trainers and ns.trainers.Trade(prof.name) or {}
            for _, e in pairs(list) do
                if e.name:find(out.name, 1, true) or (e.rank and e.rank:find(out.name, 1, true)) then
                    out.level = e.level and e.level > 0 and e.level or out.level
                    out.skill = e.skill and e.skill > 0 and e.skill or out.skill
                    break
                end
            end
            return out
        end
    end
end

-- the line under a card's bar: its text and colour, or nil
function W.RankLine(prof)
    local r = W.NextRank(prof)
    if not r then return nil end
    if prof.rank >= r.skill and UnitLevel("player") >= r.level then
        return format(Tr["Train %s now"], r.name), prof.rank >= prof.max - 5 and RED or GOLD
    end
    return format(Tr["%s at skill %d, level %d"], r.name, r.skill, r.level), ns.colors.dim
end

-- ----------------------------------------------------------------- cards
-- A primary stands as a pillar, half the width, centred top to bottom, its
-- ring glowing; a secondary as a medallion, a third of it, its skill in
-- ticks round its ring and its next rank in its tooltip:
--
--              (icon)                    .(icon).
--            Herbalism                   Fishing
--     [===|== 92 / 150 =====]            1 / 75
--   Expert at skill 125, level 20       [s] [s]
--         [spell] [spell]     x
--
-- Neither has a box: a hair parts the pillars.
local function Spell(card, size)
    local s = CreateFrame("Button", nil, card)
    s:SetSize(size, size)
    s.edge = s:CreateTexture(nil, "BACKGROUND")
    s.edge:SetPoint("TOPLEFT", -1, 1)
    s.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    s.edge:SetColorTexture(0.541, 0.439, 0.204, 1)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetAllPoints()
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s:SetScript("OnEnter", function(self)
        if not self.slot then return end
        W.Beside(self)
        GameTooltip:SetSpellBookItem(self.slot, Enum.SpellBookSpellBank.Player)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return s
end

-- Unlearn, a faint cross that lights under the mouse; Blizzard's question
local function Cross(card)
    local x = CreateFrame("Button", nil, card)
    x:SetSize(CROSS, CROSS)
    x.icon = x:CreateTexture(nil, "ARTWORK")
    x.icon:SetSize(12, 12)
    x.icon:SetPoint("CENTER")
    x.icon:SetTexture(ns.media .. "strips\\close")
    x.icon:SetAlpha(FAINT)
    x:SetScript("OnClick", function(self)
        local p = self:GetParent().prof
        if p and p.name and not InCombatLockdown() then StaticPopup_Show("UNLEARN_SKILL", p.name, nil, p.skillLine) end
    end)
    x:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1)
        local p = self:GetParent().prof
        ns.Tip(self, W.Beside, { title = format(Tr["Unlearn %s: forget it, and every recipe of it."],
            p and p.name or ""), color = ns.colors.white, wrap = true })
    end)
    x:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(FAINT)
        GameTooltip:Hide()
    end)
    return x
end

-- A secondary's skill: ticks round its ring, lit clockwise from the top.
local function Dial(c, ring, radius)
    local d = { ticks = {} }
    for i = 1, DIAL do
        local a = (i - 0.5) / DIAL * 2 * math.pi
        local t = c:CreateTexture(nil, "ARTWORK", nil, 4)
        t:SetSize(2, 5)
        t:SetPoint("CENTER", ring, "CENTER", radius * math.sin(a), radius * math.cos(a))
        t:SetRotation(-a)
        d.ticks[i] = t
    end
    function d.Set(frac)
        local lit = frac > 0 and math.max(1, math.floor(frac * DIAL + 0.5)) or 0
        d.lit = lit
        for i, t in ipairs(d.ticks) do
            if i <= lit then t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            else t:SetColorTexture(0.2, 0.17, 0.11, 1) end
        end
    end
    return d
end

local function Card(body, pillar)
    local c = CreateFrame("Frame", nil, body)
    c.pillar = pillar
    c:SetHeight(pillar and PILLAR or SEC_H)
    c.icon = ns.window.Ring(c, pillar and ICON or MEDAL, pillar)
    c.name = ns.Text(c, 14)
    c.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    if pillar then c.bar = ns.character.Bar(c, HALF - 36, BAR_TALL, true) end
    c.none = ns.Text(c, 12)
    c.none:SetTextColor(unpack(ns.colors.dim))
    c.rank = ns.Text(c, 12)
    c.unlearn = Cross(c)
    c.spells = {}
    if pillar then
        -- its craft's scene behind (professions\<skill line>), standing on
        -- its foot, as much of it as the pillar is tall (Lay); none unlearned
        c.art = c:CreateTexture(nil, "BACKGROUND")
        c.art:SetPoint("BOTTOMLEFT")
        c.art:SetPoint("BOTTOMRIGHT")
        c.icon:SetPoint("TOP", 0, -14)
        c.name:SetPoint("TOP", c.icon, "BOTTOM", 0, -8)
        c.bar:SetPoint("TOP", c.name, "BOTTOM", 0, -6)
        c.none:SetPoint("TOP", c.name, "BOTTOM", 0, -8)
        c.none:SetWidth(HALF - 16)
        c.rank:SetPoint("TOP", c.bar, "BOTTOM", 0, -5)
        c.unlearn:SetPoint("BOTTOMRIGHT", -2, 2)
        for i = 1, 2 do c.spells[i] = Spell(c, SPELL) end
    else
        -- a medallion: its ring in its dial, the name and skill under it,
        -- then its spells
        c:SetWidth(THIRD)
        c.icon:SetPoint("CENTER", c, "TOP", 0, -(7 + MEDAL / 2))
        c.dial = Dial(c, c.icon, MEDAL / 2 + 7)
        c.name:SetPoint("TOP", c.icon, "BOTTOM", 0, -14)
        c.value = ns.Text(c, 12)
        c.value:SetPoint("TOP", c.name, "BOTTOM", 0, -3)
        c.unlearn:SetPoint("TOPRIGHT", -6, -4)
        for i = 1, 2 do c.spells[i] = Spell(c, SMALL) end
        -- the next rank, which a medallion has no room for
        c:EnableMouse(true)
        c:SetScript("OnEnter", function(self)
            local prof = self.prof
            if not prof or not prof.name then return end
            W.Beside(self)
            GameTooltip:SetText(prof.name, GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(self.value:GetText() or "", 1, 1, 1)
            if self.rank:GetText() and self.rank:GetText() ~= "" then
                GameTooltip:AddLine(self.rank:GetText(), unpack(self.rankColor or ns.colors.dim))
            end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return c
end

local function Fill(c, prof)
    c.prof = prof
    local learned = prof.name ~= nil
    if c.art then
        c.art:SetShown(learned and prof.skillLine ~= nil)
        if learned and prof.skillLine then c.art:SetTexture((Art(prof.skillLine))) end
    end
    c.icon:SetTexture(learned and prof.icon or NONE)
    c.icon:SetDesaturated(not learned)
    c.name:SetText(learned and prof.name or Tr["Primary profession"])
    c.name:SetTextColor(unpack(learned and GOLD or ns.colors.dim))
    if c.bar then c.bar:SetShown(learned) end
    c.none:SetShown(not learned)
    c.none:SetText(learned and "" or Tr["Not learned. A trainer teaches one."])
    c.unlearn:SetShown(learned)
    if learned then
        local text = prof.modifier > 0 and format("%d (+%d) / %d", prof.rank, prof.modifier, prof.max)
            or format("%d / %d", prof.rank, prof.max)
        if c.bar then
            c.bar:Fill({ min = 0, max = prof.max, cur = prof.rank, text = text, notches = NOTCHES })
        else
            c.value:SetText(text)
            c.dial.Set(prof.max > 0 and math.min(1, prof.rank / prof.max) or 0)
        end
    end
    local line, color
    if learned then line, color = W.RankLine(prof) end
    c.rank:SetText(line or "")
    c.rankColor = color
    if color then c.rank:SetTextColor(unpack(color)) end
    -- a line's rank is in its tooltip
    c.rank:SetShown(c.pillar and line ~= nil or false)
    local n = learned and math.min(prof.spells or 0, #c.spells) or 0
    for i, s in ipairs(c.spells) do
        local slot = i <= n and prof.offset + i or nil
        local item = slot and C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
        s.slot, s.item = item and slot or nil, item
        s:SetShown(item ~= nil)
        if item then s.icon:SetTexture(item.iconID) end
    end
    if c.pillar then
        -- the spells centred, the first at the left; how far down, Lay's
        c.from = (HALF - (n * SPELL + math.max(0, n - 1) * 8)) / 2
    else
        local from = (THIRD - (n * SMALL + math.max(0, n - 1) * 6)) / 2
        for i, s in ipairs(c.spells) do
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", from + (i - 1) * (SMALL + 6), -SEC_SPELL_Y)
        end
    end
end

-- ------------------------------------------------------ the secure layer
local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type", "spell")
    b:SetScript("OnDragStart", function(self)
        if self.slot and not InCombatLockdown() then
            C_SpellBook.PickupSpellBookItem(self.slot, Enum.SpellBookSpellBank.Player)
        end
    end)
    b:SetScript("OnEnter", function(self) if self.cell then self.cell:GetScript("OnEnter")(self.cell) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.12)
    layer.buttons[i] = b
    return b
end

-- Out of combat only: a button over each card's spell, the rest away; the
-- layer shown while the window is open on Overview (hidden in combat).
local function Follow()
    if not layer or InCombatLockdown() then return end
    local n = 0
    if open then
        for _, c in ipairs(overview.cards) do
            for _, s in ipairs(c.spells) do
                if c:IsShown() and s:IsShown() and s.item then
                    n = n + 1
                    local b = Secure(n)
                    b.slot, b.cell = s.slot, s
                    b:SetAttribute("spell", s.item.spellID or s.item.actionID)
                    b:SetShown(W.Over(b, s))
                end
            end
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.slot, b.cell = nil, nil
        b:SetAttribute("spell", nil)
        b:Hide()
    end
    if open then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ------------------------------------------------------------- Cooldowns
-- The realm's characters' cooldown crafts (ns.alts.Cooldowns): ready
-- first, then the soonest; COOLDOWNS at most, the rest in the heading's
-- tooltip. A row: its icon, its name, whose, and the time left.
local function CoolRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(COOL_ROW)
    r.icon = ns.window.Ring(r, 18)
    r.icon:SetPoint("LEFT", 10, 0)
    r.name = ns.Text(r, 12)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    r.left = ns.Text(r, 12)
    r.left:SetPoint("RIGHT", -10, 0)
    r.who = ns.Text(r, 11)
    r.who:SetPoint("RIGHT", -96, 0)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.05)
    r:SetScript("OnEnter", function(self)
        local c = self.cooldown
        if not c then return end
        W.Beside(self)
        if GameTooltip.SetSpellByID and c.id then
            GameTooltip:SetSpellByID(c.id)
        else
            GameTooltip:SetText(c.name or "?")
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(c.who, (ns.alts.Left(c.ready)), 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and { c.r, c.g, c.b } or ns.colors.text
end

local function Cooldowns(body)
    local f = CreateFrame("Frame", nil, body)
    f.rows = {}
    for i = 1, COOLDOWNS do
        local r = CoolRow(f)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * COOL_ROW)
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * COOL_ROW)
        f.rows[i] = r
    end
    -- none: a line; given room (Room), an hourglass over it, both in the
    -- middle of the room
    f.glass = f:CreateTexture(nil, "ARTWORK")
    f.glass:SetSize(22, 22)
    f.glass:SetPoint("BOTTOM", f, "CENTER", 0, 2)
    f.glass:SetTexture(ns.media .. "strips\\legacy")
    f.glass:SetVertexColor(0.541, 0.439, 0.204, 0.8)
    f.none = ns.Text(f, 11)
    f.none:SetJustifyH("CENTER")
    function f.Room(height)
        local roomy = height >= GLASS_ROOM
        f.glass:SetShown(f.none:IsShown() and roomy)
        f.none:ClearAllPoints()
        if roomy then
            f.none:SetPoint("TOPLEFT", f, "LEFT", 10, -4)
            f.none:SetPoint("TOPRIGHT", f, "RIGHT", -10, -4)
        else
            f.none:SetPoint("TOPLEFT", 10, -4)
            f.none:SetPoint("TOPRIGHT", -10, -4)
        end
    end
    f.none:SetTextColor(unpack(ns.colors.dim))
    f.none:SetText(Tr["Open a profession with a cooldown (Transmute, Mooncloth...) to track it here."])
    -- the height it needs (Lay sets the height, with whatever room to spare)
    function f.Refresh()
        local list = ns.alts and ns.alts.Cooldowns and ns.alts.Cooldowns() or {}
        f.list = list
        for i, r in ipairs(f.rows) do
            local c = list[i]
            r.cooldown = c
            r:SetShown(c ~= nil)
            if c then
                r.icon:SetTexture(c.icon or NONE)
                r.name:SetText(c.name or "?")
                r.who:SetText(c.who)
                r.who:SetTextColor(unpack(ClassColor(c.class)))
                local left, ready = ns.alts.Left(c.ready)
                r.left:SetText(left)
                r.left:SetTextColor(unpack(ready and { 0.25, 0.85, 0.35 } or ns.colors.text))
            end
        end
        f.none:SetShown(#list == 0)
        return #list == 0 and 20 or math.min(#list, COOLDOWNS) * COOL_ROW
    end
    -- the heading's tooltip: the rest
    function f.Tip(owner)
        W.Beside(owner)
        GameTooltip:SetText(Tr["Cooldowns"], GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine(Tr["Your characters' cooldown crafts on this realm, as each last saw them."],
            1, 1, 1, true)
        local list = f.list or {}
        for i = COOLDOWNS + 1, #list do
            local c = list[i]
            local cc = ClassColor(c.class)
            GameTooltip:AddDoubleLine(format("%s  |cff%02x%02x%02x%s|r", c.name or "?", cc[1] * 255, cc[2] * 255,
                cc[3] * 255, c.who), (ns.alts.Left(c.ready)), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end
    return f
end

-- -------------------------------------------------------------- Overview
overview = { key = "overview", label = Tr["Overview"], glyph = "profession", order = 0, frame = "ProfessionsFrame",
    bandUsed = true, under = W.UNDER }
overview.cards = {}
overview.events = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "TRADE_SKILL_LIST_UPDATE", "PLAYER_REGEN_ENABLED",
    "PLAYER_LEVEL_UP", "TRAINER_UPDATE", "BAG_UPDATE_DELAYED" }
function overview.Available() return true end
function overview.Build(body, _, band)
    for i = 1, CARDS do overview.cards[i] = Card(body, i <= 2) end
    overview.split = ns.window.Hair(body, true)
    overview.heads = {
        primary = ns.window.Ribbon(body, Tr["Primary professions"]),
        secondary = ns.window.Ribbon(body, Tr["Secondary professions"]),
        camp = ns.window.Ribbon(body, Tr["Camping"]),
        cooldowns = ns.window.Ribbon(body, Tr["Cooldowns"]),
    }
    overview.cooldowns = Cooldowns(body)
    local head = overview.heads.cooldowns
    head:EnableMouse(true)
    head:SetScript("OnEnter", function(self) overview.cooldowns.Tip(self) end)
    head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    overview.camp = W.Camp(body)
    overview.camp.Changed = function() overview.Refresh() end
    overview.banner = W.Banner(overview.panel)
    overview.alts = W.AltsButton(band)
    -- the night behind the secondaries, the cooldowns and Camping (Night)
    local function Tex(sub)
        local t = body:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetPoint("LEFT")
        t:SetPoint("RIGHT")
        return t
    end
    overview.sky, overview.horizon, overview.land = Tex(-2), Tex(-2), Tex(-1)
    overview.Dress()
    -- what it takes is measured as it is laid out (Refresh); until then, the cards
    overview.height = PILLAR + SEC_H + GAP
end

-- The night and the pillars' scenes in the chosen style (Build, and the
-- Overview art option as it changes)
function overview.Dress()
    local sky, horizon = Art("sky")
    overview.sky:SetTexture(sky)
    overview.land:SetTexture((Art("land")))
    overview.horizon:SetColorTexture(horizon[1], horizon[2], horizon[3], 1)
    for _, c in ipairs(overview.cards) do
        if c.art and c.prof and c.prof.skillLine then c.art:SetTexture((Art(c.prof.skillLine))) end
    end
end
ns.OnSetting("professionsArt", function() if overview.sky then overview.Dress() end end)

-- One scene from the first heading under the pillars down to Camping's
-- foot: the sky hung from the top, the land standing on the foot, the
-- horizon's colour between them when the room is taller than both; each
-- cut to the room, never stretched.
local function Night(top, foot)
    local px = TEX / ns.window.width            -- the art's pixels to a unit
    local room = foot - top
    local function At(t, from, height, v0, v1)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 0, -from)
        t:SetPoint("TOPRIGHT", 0, -from)
        t:SetHeight(height)
        t:SetTexCoord(0, 1, v0, v1)
        t:Show()
    end
    local sky = math.min(SKY_PX / px, room)
    At(overview.sky, top, sky, 0, sky * px / TEX)
    local land = math.min(LAND_PX / px, room)
    At(overview.land, foot - land, land, 1 - land * px / TEX, 1)
    local gap = room - sky - land
    overview.horizon:SetShown(gap > 0)
    if gap > 0 then
        overview.horizon:ClearAllPoints()
        overview.horizon:SetPoint("TOPLEFT", 0, -(top + sky))
        overview.horizon:SetPoint("TOPRIGHT", 0, -(top + sky))
        overview.horizon:SetHeight(gap)
    end
end

-- Top to bottom: the banner, the primaries side by side (W.Learned has
-- both, learned or not) with a hair down between them, the secondaries
-- learned side by side, the cooldowns, Camping. gap: above each heading;
-- grow: the pillars' extra height (their icon a third of it lower, the
-- engraving cropped at its sides to keep its shape); rest: under the
-- cooldowns. Returns the height taken and the headings shown.
local function Lay(gap, grow, rest)
    local learned = overview.learned
    local y, heads = 0, 0
    local function Put(f, height)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", 0, -y)
        f:Show()
        y = y + height
    end
    local function Head(f)
        y = y + gap
        heads = heads + 1
        Put(f, ns.window.RIBBON + 4)
    end
    Head(overview.heads.primary)
    local cards = overview.cards
    local tall, lift = PILLAR + grow, math.floor(grow / 3)
    for i = 1, 2 do
        local c = cards[i]
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", (i - 1) * (HALF + GAP), -y)
        c:SetSize(HALF, tall)
        c:Show()
        c.icon:SetPoint("TOP", 0, -14 - lift)
        -- the scene's foot, as tall as the pillar (its art as wide)
        local px = math.min(SCENE_PX, tall * 256 / HALF)
        c.art:SetHeight(px * HALF / 256)
        c.art:SetTexCoord(0, 1, 1 - px / TEX, 1)
        for k, sp in ipairs(c.spells) do
            sp:ClearAllPoints()
            sp:SetPoint("TOPLEFT", (c.from or 0) + (k - 1) * (SPELL + 8), -(SPELL_Y + lift))
        end
    end
    overview.split:ClearAllPoints()
    overview.split:SetPoint("TOP", 0, -(y + 6))
    overview.split:SetHeight(tall - 12)
    y = y + tall + GAP
    -- the secondaries, centred across the page a third each
    local shown = {}
    for i = 3, CARDS do
        local c = cards[i]
        c:SetShown(learned[i] ~= nil)
        if learned[i] then table.insert(shown, c) end
    end
    overview.heads.secondary:SetShown(#shown > 0)
    local night = y + gap
    if #shown > 0 then
        Head(overview.heads.secondary)
        for k, c in ipairs(shown) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", math.floor(ns.window.width / 2 + (k - (#shown + 1) / 2) * THIRD - THIRD / 2), -y)
        end
        y = y + SEC_H + GAP
    end
    -- the cooldowns, the realm's characters'
    Head(overview.heads.cooldowns)
    overview.cooldowns:SetHeight(overview.coolH + rest)
    overview.cooldowns.Room(overview.coolH + rest)
    Put(overview.cooldowns, overview.coolH + rest + GAP)
    Head(overview.heads.camp)
    local camp = overview.camp
    camp:ClearAllPoints()
    camp:SetPoint("TOPLEFT", 0, -y)
    camp:SetPoint("TOPRIGHT", 0, -y)
    Night(night, y + overview.campH)
    return y + overview.campH, heads
end

-- laid out as it needs, then again with what the page has to spare shared
-- out; the height it needs
local function Place()
    local need, heads = Lay(GAP, 0, 0)
    local spare = math.max(0, (overview.room or 0) - need)
    if spare > 0 then
        local more = math.min(SPARE_GAP, math.floor(spare / heads))
        spare = spare - more * heads
        local grow = math.min(GROW, spare)
        Lay(GAP + more, grow, spare - grow)
    end
    return need
end

function overview.Refresh()
    local learned = W.Learned()
    overview.learned = learned
    overview.banner.Refresh()
    overview.alts.Refresh()
    for i = 1, CARDS do
        if i <= 2 or learned[i] then Fill(overview.cards[i], learned[i]) end
    end
    overview.coolH = overview.cooldowns.Refresh()
    overview.campH = overview.camp.Refresh(learned)
    local need = Place()
    Follow()
    -- the least the window can be: a fixed page taller than the screen
    -- runs the window off its top
    if need ~= overview.height then
        overview.height = need
        W.Retab()
    end
end
-- the height the page has (the window runs to the screen's top)
function overview.Fit(height)
    overview.room = height
    if overview.learned then
        Place()
        Follow()
    end
end
function overview.Showing(on)
    open = on                           -- only Overview has spells to cast
    Follow()
end
W.Page(overview)

-- ----------------------------------------------------- Blizzard's frame
-- The page Blizzard's frame is on: its book, or the open profession.
local function Want()
    local f = ProfessionsFrame
    if f.BookPage and f.BookPage:IsShown() then return overview end
    local skill = W.Skill()
    for _, p in ipairs(W.pages) do
        if p.available and p.skillLine and p.skillLine == skill then return p end
    end
    return overview
end

-- Closing is at once; opening waits for the frame's end, by when Blizzard
-- has turned to the page it opens on. Blizzard reopens on the profession
-- last open, which our Overview tab does not change: closed on Overview,
-- the book's own way in (its key, the micro button: ToggleProfessionsBook)
-- opens on Overview again. A profession's spell opens that profession.
local waiting
local leftOnOverview                    -- the window closed on Overview
local byBook                            -- opened by ToggleProfessionsBook
local function Sync()
    if not ProfessionsFrame:IsShown() then
        if W.window:IsShown() then leftOnOverview = W.Current() == overview end
        byBook = nil
        W.SetShown(false)
        return
    end
    if waiting then return end
    waiting = true
    C_Timer.After(0, function()
        waiting = false
        if not ProfessionsFrame:IsShown() then return end
        W.Retab()
        local p = Want()
        if byBook and leftOnOverview and not W.window:IsShown() then p = overview end
        byBook = nil
        if W.Current() ~= p then W.Select(p) end
        W.SetShown(true)
        -- one window on the right strip: the spellbook's or talents' frame
        -- closes (out of combat), when one of ours stands on it
        local spells = PlayerSpellsFrame
        if spells and spells:IsShown() and spells:GetParent() == ns.hidden and not InCombatLockdown() then
            HideUIPanel(spells)
        end
    end)
end
W.Sync = Sync

local function Adopt()
    local f = ProfessionsFrame
    if not f or W.adopted then return end
    W.adopted = true
    ns.Park(f)
    if ToggleProfessionsBook then
        hooksecurefunc("ToggleProfessionsBook", function() byBook = true; Sync() end)
    end
    for _, frame in ipairs({ f, f.BookPage, f.CraftingPage }) do
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            hooksecurefunc(frame, method, Sync)
        end
    end
    Sync()
end

local function Start()
    if not ns.db.professions or not SpellbookMicroButton or not C_TradeSkillUI or not GetProfessions then return end
    W.Build()
    -- the camp's timers, each second while the Overview shows, and the
    -- cooldowns' each half minute (hooked
    -- once built: the shell sets the window's own OnUpdate as it builds)
    local second
    W.window:HookScript("OnUpdate", function()
        if not (overview.body and overview.body:IsVisible()) then return end
        local now = math.floor(GetTime())
        if now ~= second then
            second = now
            overview.camp.Tick()
            -- the times; a row come or gone, the page laid out again
            if now % 30 == 0 and overview.cooldowns.Refresh() ~= overview.coolH then overview.Refresh() end
        end
    end)
    layer = W.Layer("MedalluinProfessionsCasts")
    W.layer = layer
    W.Select(overview)
    -- a profession learned or forgotten; one opened (its spell, a tab)
    for _, e in ipairs({ "SKILL_LINES_CHANGED", "SPELLS_CHANGED" }) do
        ns.On(e, function() W.Retab() end)
    end
    ns.On("TRADE_SKILL_SHOW", function() if W.window:IsShown() then Sync() end end)
    -- a profession's tab chosen in combat opens it now
    ns.On("PLAYER_REGEN_ENABLED", function()
        Follow()
        local p = W.Current()
        if W.window:IsShown() and p.Open then p.Open() end
    end)
    if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        Adopt()
    else
        ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_Professions" then Adopt() end end)
    end
end

ns.On("PLAYER_LOGIN", Start)
