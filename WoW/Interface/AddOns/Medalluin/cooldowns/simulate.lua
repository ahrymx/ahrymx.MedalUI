-- The Cooldown Manager's simulation: while "Simulate cooldowns" is on, each
-- viewer's holder shows icons of ours in that viewer's dress (its options,
-- cooldowns/display.lua): its layout, shape, texts, sweep, grey, tint,
-- tooltips and fade, as the real ones would wear them. A small panel on the
-- right of the screen sets what they show:
--
--   Spells        Yours: the spells your Cooldown Manager tracks, each
--                 viewer's own (a viewer with none gets random ones)
--                 Random: a full set, Essential - n +, Utility - n +,
--                 Tracked buffs - n +, Tracked bars - n +, and New spells
--                 for another draw
--   Cooling       sweeps winding, each spell its own cooldown, again and again
--   Charges       some spells with charges, their count on the icon
--   Stacks        some buffs (and bars) with stacks
--   Out of range  some spells tinted
--   Come and go   buffs running out and coming back (Close gaps shows here)
--   In combat     the viewers' Visibility as in a fight
--   [End simulation]
--
-- The game's viewers are faded out while it runs and given back after; their
-- spells are only read (an icon's texture, its spell's name). Nothing here
-- is saved but the switch; a reload draws again.
local _, ns = ...
local Tr = ns.L

local D = ns.cooldownDisplay
local KIT = ns.simKit

-- a random draw's spells: { name, icon }, cooldowns and buffs apart
local SPELLS = {
    { Tr["Fireball"], "Spell_Fire_Fireball02" }, { Tr["Frostbolt"], "Spell_Frost_FrostBolt02" },
    { Tr["Lightning Bolt"], "Spell_Nature_Lightning" }, { Tr["Shadow Bolt"], "Spell_Shadow_ShadowBolt" },
    { Tr["Charge"], "Ability_Warrior_Charge" }, { Tr["Frost Nova"], "Spell_Frost_FrostNova" },
    { Tr["Blink"], "Spell_Arcane_Blink" }, { Tr["Kick"], "Ability_Kick" },
    { Tr["Earth Shock"], "Spell_Nature_EarthShock" }, { Tr["Flame Shock"], "Spell_Fire_FlameShock" },
    { Tr["Death Coil"], "Spell_Shadow_DeathCoil" }, { Tr["Aimed Shot"], "INV_Spear_07" },
    { Tr["Healing Wave"], "Spell_Nature_MagicImmunity" }, { Tr["Holy Light"], "Spell_Holy_HolyBolt" },
    { Tr["Maul"], "Ability_Druid_Maul" }, { Tr["Stoneskin Totem"], "Spell_Nature_StoneSkinTotem" },
    { Tr["Shield Wall"], "Ability_Warrior_ShieldWall" }, { Tr["Divine Shield"], "Spell_Holy_DivineIntervention" },
}
local BUFFS = {
    { Tr["Power Word: Shield"], "Spell_Holy_PowerWordShield" }, { Tr["Rejuvenation"], "Spell_Nature_Rejuvenation" },
    { Tr["Renew"], "Spell_Holy_Renew" }, { Tr["Bloodlust"], "Spell_Nature_BloodLust" },
    { Tr["Sprint"], "Ability_Rogue_Sprint" }, { Tr["Lightning Shield"], "Spell_Nature_LightningShield" },
    { Tr["Battle Shout"], "Ability_Warrior_BattleShout" }, { Tr["Blessing of Might"], "Spell_Holy_FistOfJustice" },
    { Tr["Shadowform"], "Spell_Shadow_Shadowform" }, { Tr["Stealth"], "Ability_Stealth" },
    { Tr["Mark of the Wild"], "Spell_Nature_Regeneration" }, { Tr["Arcane Intellect"], "Spell_Holy_MagicalSentry" },
}
local ICONS = "Interface\\Icons\\"
local BARS = ns.CDM_BARS[2]
-- the four viewers: the icon viewers, then the tracked bars
local VIEWERS = {}
for _, v in ipairs(ns.CDM_VIEWERS) do table.insert(VIEWERS, v) end
table.insert(VIEWERS, ns.CDM_BARS)
-- a buff's viewer: an aura that runs out (the icons' or the bars')
local function Buffs(key) return key == "buffs" or key == BARS end
local MAX = 12                  -- icons a viewer can have in a random draw
local TICK = 0.2                -- seconds between looks at the timers

-- the session's choices (the panel's), and the switch
local S = {
    source = "random", counts = { essential = 8, utility = 6, buffs = 5, [BARS] = 3 },
    cooling = true, charges = true, stacks = true, away = false, comeGo = true, combat = false,
}
ns.sim.cdm = S

local running = false
local sets = {}                 -- by key: { root, items, Resize } as display.Simulate takes them
local pools = {}                -- by key: every icon ever made, reused
local seed

-- ------------------------------------------------------------- the draws
-- A draw from 1..n: the same from the same seed (the harness), another on
-- New spells.
local function Roll(n)
    seed = seed * 16807 % 2147483647
    return seed % n + 1
end
local function Between(lo, hi) return lo + Roll(hi - lo + 1) - 1 end

local function Viewer(key)
    return ns.cooldownDisplay.viewers[key]
end

-- The spells a viewer of yours tracks, in its order: { name, icon }; none
-- when it has none (or none yet: its addon unloaded).
local function Yours(key)
    local v, out = Viewer(key), {}
    if not v then return out end
    local items = {}
    local ok, frames = pcall(function() return v:GetItemFrames() end)
    if ok and type(frames) == "table" then items = frames end
    local list = {}
    for i, item in ipairs(items) do table.insert(list, { item, tonumber(item.layoutIndex) or i, i }) end
    table.sort(list, function(a, b)
        if a[2] ~= b[2] then return a[2] < b[2] end
        return a[3] < b[3]
    end)
    for _, e in ipairs(list) do
        local item = e[1]
        -- a bar's icon is a frame, its texture inside it
        local icon = item.Icon and item.Icon.Icon or item.Icon
        local tex = icon and icon.GetTexture and icon:GetTexture()
        if tex == nil or ns.IsSecret(tex) then tex = ICONS .. "INV_Misc_QuestionMark" end
        local name
        pcall(function()
            local id = item.GetSpellID and item:GetSpellID()
            if id and not ns.IsSecret(id) and C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) end
        end)
        if name == nil or ns.IsSecret(name) then name = Tr["A spell"] end
        table.insert(out, { name, tex })
    end
    return out
end

-- n of a list's entries, none twice while there are enough
local function Pick(from, n)
    local left, out = {}, {}
    for i = 1, #from do left[i] = from[i] end
    for _ = 1, n do
        if #left == 0 then for i = 1, #from do left[i] = from[i] end end
        local e = table.remove(left, Roll(#left))
        table.insert(out, { e[1], ICONS .. e[2] })
    end
    return out
end

-- ------------------------------------------------------------- the icons
local function Size(key)
    for _, v in ipairs(VIEWERS) do
        if v[2] == key then return tonumber(ns.db["cdm" .. v[1] .. "Size"]) or v[4] end
    end
    return 36
end

local function Count(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetAllPoints(parent)
    c:SetFrameLevel(parent:GetFrameLevel() + 3)
    local fs = c:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.font, 13, "OUTLINE")
    return c, fs
end

-- An icon as the game's viewers make theirs (Icon, Cooldown, OutOfRange,
-- ChargeCount.Current or Applications.Applications), so the dress fits it.
local function NewIcon(key, root)
    local item = CreateFrame("Frame", nil, root)
    item.Icon = item:CreateTexture(nil, "ARTWORK")
    item.Icon:SetAllPoints()
    item.OutOfRange = item:CreateTexture(nil, "OVERLAY")
    item.OutOfRange:SetAllPoints()
    item.OutOfRange:Hide()
    item.Cooldown = CreateFrame("Cooldown", nil, item, "CooldownFrameTemplate")
    item.Cooldown:SetAllPoints()
    if item.Cooldown.SetHideCountdownNumbers then item.Cooldown:SetHideCountdownNumbers(false) end
    if key == "buffs" then
        item.Applications = {}
        item.Applications.frame, item.Applications.Applications = Count(item)
    else
        item.ChargeCount = {}
        item.ChargeCount.frame, item.ChargeCount.Current = Count(item)
    end
    item:EnableMouse(true)
    item:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.spellName or "")
        GameTooltip:AddLine(Tr["Simulated"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return item
end

-- A tracked bar as the game makes its (Icon, a frame holding Icon and
-- Applications; Bar, a status bar holding Name and Duration), so the
-- bars' dress fits it. Its size and its parts' places are the display's.
local function NewBar(root)
    local item = CreateFrame("Frame", nil, root)
    item.Icon = CreateFrame("Frame", nil, item)
    item.Icon.Icon = item.Icon:CreateTexture(nil, "ARTWORK")
    item.Icon.Icon:SetAllPoints()
    local count = item.Icon:CreateFontString(nil, "OVERLAY")
    count:SetFont(ns.font, 13, "OUTLINE")
    item.Icon.Applications = count
    item.Bar = CreateFrame("StatusBar", nil, item)
    item.Bar.Name = item.Bar:CreateFontString(nil, "OVERLAY")
    item.Bar.Name:SetFont(ns.font, 12, "OUTLINE")
    item.Bar.Name:SetPoint("LEFT", 5, 0)
    item.Bar.Duration = item.Bar:CreateFontString(nil, "OVERLAY")
    item.Bar.Duration:SetFont(ns.font, 12, "OUTLINE")
    item.Bar.Duration:SetPoint("RIGHT", -6, 0)
    item:EnableMouse(true)
    item:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.spellName or "")
        GameTooltip:AddLine(Tr["Simulated"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return item
end

local function Resizer(key)
    return function()
        local s = Size(key)
        for _, item in ipairs(sets[key].items) do item:SetSize(s, s) end
    end
end

-- A viewer's icons for a draw: the spells, and each its timers
local function Fill(key)
    local want
    if S.source == "yours" then want = Yours(key) end
    if not want or #want == 0 then
        want = Pick(Buffs(key) and BUFFS or SPELLS, S.counts[key])
    end
    local set = sets[key]
    if not set then
        local root = CreateFrame("Frame", nil, D.holders[key])
        root:SetAllPoints(D.holders[key])
        set = { root = root, items = {}, Resize = Resizer(key) }
        sets[key] = set
        pools[key] = {}
    end
    set.root:Show()
    for _, item in ipairs(pools[key]) do item:Hide() end
    set.items = {}
    local now = GetTime()
    for i, spell in ipairs(want) do
        local item = pools[key][i] or (key == BARS and NewBar(set.root) or NewIcon(key, set.root))
        pools[key][i] = item
        item.spellName = spell[1]
        if key == BARS then
            item.Icon.Icon:SetTexture(spell[2])
            item.Bar.Name:SetText(spell[1])
        else
            item.Icon:SetTexture(spell[2])
        end
        item.layoutIndex = i
        item:Show()
        -- its timers: a spell's cooldown, a buff's run, each from a point along it
        local t = { dur = Buffs(key) and Between(6, 20) or Between(8, 45) }
        t.start = now - Between(0, t.dur - 1)
        t.charges = not Buffs(key) and i % 3 == 2 and Between(2, 3) or nil
        t.stacks = Buffs(key) and i % 2 == 0 and Between(2, 5) or nil
        t.away = not Buffs(key) and i % 3 == 0
        item.sim = t
        set.items[i] = item
    end
    set.Resize()
end

-- One icon's look from its timers and the panel's switches. A spell cools
-- down; one with charges keeps one up and so stays in colour; a buff runs
-- out, is away a moment, and comes back.
-- The cooldown set only when it changes, as the game does: the sweep is
-- not restarted each look. The game's own calls, so the dress's hooks answer
-- them as they answer the game's.
local function Cooldown(item, start, dur)
    local t = item.sim
    if t.setStart == start and t.setDur == dur then return end
    t.setStart, t.setDur = start, dur
    item.Cooldown:SetCooldown(start, dur)
    item.Cooldown:SetDrawSwipe(dur > 0)
end

local function Draw(key, item, now)
    local t = item.sim
    if key == BARS then
        -- a bar runs down as its buff does, its time left at its end
        local up = not S.comeGo or now < t.start + t.dur
        if up ~= item:IsShown() then item:SetShown(up) end
        local left = math.max(0, t.start + t.dur - now)
        item.Bar:SetMinMaxValues(0, t.dur)
        item.Bar:SetValue(left)
        item.Bar.Duration:SetText(left > 0 and string.format("%.1f", left) or "")
        local stacks = S.stacks and t.stacks
        item.Icon.Applications:SetText(stacks and tostring(stacks) or "")
        return
    end
    if key == "buffs" then
        local up = not S.comeGo or now < t.start + t.dur
        if up ~= item:IsShown() then item:SetShown(up) end
        Cooldown(item, t.start, t.dur)
        local stacks = S.stacks and t.stacks
        item.Applications.Applications:SetText(stacks and tostring(stacks) or "")
        return
    end
    local cooling = S.cooling and now < t.start + t.dur
    Cooldown(item, S.cooling and t.start or 0, S.cooling and t.dur or 0)
    local grey = cooling and not (S.charges and t.charges)
    if grey ~= t.grey then
        t.grey = grey
        item.Icon:SetDesaturated(grey)
    end
    item.ChargeCount.Current:SetText(S.charges and t.charges and tostring(S.cooling and t.charges - 1
        or t.charges) or "")
    item.OutOfRange:SetShown(S.away and t.away or false)
end

local function DrawAll(now)
    now = now or GetTime()
    for key, set in pairs(sets) do
        if set.root:IsShown() then
            for _, item in ipairs(set.items) do
                local t = item.sim
                -- a buff gone a few seconds before it comes back (at once
                -- while they do not come and go); a spell ready a moment,
                -- then cast again
                t.gone = t.gone or Between(2, 5)
                local buff = Buffs(key)
                local wait = (not buff or S.comeGo) and t.gone or 0
                if (buff or S.cooling) and now >= t.start + t.dur + wait then
                    t.start = now
                    if not buff then t.gone = Between(1, 4) end
                end
                Draw(key, item, now)
            end
        end
    end
end

-- -------------------------------------------------------------- the runs
local driver = CreateFrame("Frame")
driver:Hide()
local since = 0
driver:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < TICK then return end
    since = 0
    DrawAll()
end)

-- Every viewer drawn again and handed to the display
local function Deal()
    for _, v in ipairs(VIEWERS) do
        local key = v[2]
        Fill(key)
    end
    DrawAll()
    for _, v in ipairs(VIEWERS) do D.Simulate(v[2], sets[v[2]]) end
end

local function Start()
    running = true
    seed = seed or (math.floor((GetTime() or 0) * 1000) % 2147483646 + 1)
    D.simCombat = S.combat
    Deal()
    driver:Show()
end

local function Stop()
    running = false
    driver:Hide()
    D.simCombat = false
    for key, set in pairs(sets) do
        set.root:Hide()
        D.Simulate(key, nil)
    end
end

-- -------------------------------------------------------------- the panel
local panel

-- After a switch: the icons from their timers, laid out and faded again
local function Redraw()
    D.simCombat = S.combat
    DrawAll()
    for _, v in ipairs(VIEWERS) do
        D.Arrange(v[2])
        D.Fade(v[2], true)
    end
end

-- each viewer's count: its label, and its tips (simKit's Count)
local SPELL_TIPS = { Tr["One spell fewer."], Tr["One spell more."], Tr["How many spells. Click for %d, or %d."] }
local COUNTS = {
    essential = { Tr["Essential"], SPELL_TIPS },
    utility = { Tr["Utility"], SPELL_TIPS },
    buffs = { Tr["Tracked buffs"], { Tr["One buff fewer."], Tr["One buff more."],
        Tr["How many buffs. Click for %d, or %d."] } },
    [BARS] = { Tr["Tracked bars"], { Tr["One bar fewer."], Tr["One bar more."],
        Tr["How many bars. Click for %d, or %d."] } },
}

local function Build()
    local K = KIT
    panel = K.Chrome("MedalluinCdmSimPanel", Tr["Simulated cooldowns"], "RIGHT", -16, 120)
    local page = CreateFrame("Frame", nil, panel)
    local top = K.PAD + 16 + 6
    page:SetPoint("TOPLEFT", K.PAD, -top)
    page:SetSize(K.IW, 1)
    local half = (K.IW - 4) / 2
    local function Source(x, id, label, tip)
        K.Button(page, x, 0, half, { id = "cdm.source." .. id, label = label, redraw = Deal,
            lit = function() return S.source == id end,
            click = function() S.source = id end,
            tip = function() return tip end })
    end
    Source(0, "yours", Tr["Your spells"], Tr["The spells your Cooldown Manager tracks, each viewer's own, in its "
        .. "order. A viewer with none gets random ones."])
    Source(half + 4, "random", Tr["Random spells"], Tr["A full set of random spells, as many as the counts below."])
    local y = -K.ROW - 4
    local function Random() return S.source == "random" end
    for _, v in ipairs(VIEWERS) do
        local key = v[2]
        y = K.Count(page, y, "cdm.count." .. key, COUNTS[key][1], 1, MAX,
            function() return S.counts[key] end, function(n) S.counts[key] = n end, COUNTS[key][2], Deal, Random)
    end
    K.Button(page, 0, y, K.IW, { id = "cdm.again", label = Tr["New spells"], redraw = Deal, enabled = Random,
        click = function() end, tip = function() return Tr["Another draw: other spells, other timings."] end })
    y = K.Toggles(page, y - K.ROW - 4, "cdm", function() return S end, {
        { "cooling", Tr["Cooling"], Tr["Each spell cooling down, its sweep winding, again and again."] },
        { "charges", Tr["Charges"], Tr["Some spells with charges: one is up, so the icon keeps its colour."] },
        { "stacks", Tr["Stacks"], Tr["Some buffs and bars with stacks."] },
        { "away", Tr["Out of range"], Tr["Some spells out of range, tinted."] },
        { "comeGo", Tr["Come and go"], Tr["Buffs and bars running out and coming back: with Close gaps, the rest "
            .. "close ranks."] },
        { "combat", Tr["In combat"], Tr["The viewers' Visibility as in a fight."] },
    }, Redraw)
    K.Button(panel, K.PAD, -(top - y + 6), K.IW, { id = "cdm.end", label = Tr["End simulation"],
        redraw = function() end,
        click = function() ns.SetOption("simCdm", false) end,
        tip = function() return Tr["Turn off Simulate cooldowns."] end })
    panel:SetHeight(top - y + 6 + K.ROW + K.PAD - 4)
end

-- on with both the Cooldown Manager's window and its dress, whose options it shows
local function Allowed()
    return ns.db and ns.db.simCdm and ns.db.cdmWindow and ns.db.cdmDisplay and true or false
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
for _, key in ipairs({ "simCdm", "cdmWindow", "cdmDisplay" }) do ns.OnSetting(key, Shown) end

-- The switch in the Cooldown Manager window's gear menu too, under the
-- game's own entries, while it can run (both parts on). Added through
-- Menu.ModifyMenu, the game's way for an addon to add to a menu it tags:
-- the menu's own entries and code stay the game's.
if Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("COOLDOWN_VIEWER_SETTINGS_MENU", function(_, root)
        if not (ns.db and ns.db.cdmWindow and ns.db.cdmDisplay) then return end
        root:CreateDivider()
        root:CreateTitle("Medalluin")
        root:CreateCheckbox(Tr["Simulate cooldowns"], function() return ns.db.simCdm and true or false end,
            function() ns.SetOption("simCdm", not ns.db.simCdm) end)
    end)
end
-- a viewer's option changed: its look restyled (display.lua), then ours
-- drawn again over it, as the game's next refresh would
ns.OnAnySetting(function(setting)
    if not running or not tostring(setting):match("^cdm[EUB]%u") then return end
    for _, set in pairs(sets) do
        for _, item in ipairs(set.items) do item.sim.grey, item.sim.setStart = nil, nil end
    end
    DrawAll()
end)

-- for the harness
ns.cdmSim = { state = S, sets = sets, Draw = DrawAll, Running = function() return running end }
