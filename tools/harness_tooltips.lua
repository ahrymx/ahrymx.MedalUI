-- The "tooltips" pass: mdlui_Tooltips, loaded after MedalUI (tools/harness.lua
-- hands over what it keeps local). Every sample the style editor offers is drawn
-- into a preview panel, and the panel's chrome, bars, boxes and text are read
-- back as lines.
local H = ...
local events, Region = H.events, H.region
if not CreateColor then function CreateColor(r, g, b, a) return { r, g, b, a } end end
if not Region.SetGradient then function Region:SetGradient(o, a, b) self.gradient = { o, a, b } end end
-- as in the game: a vertex color replaces a gradient, and a gradient a color
function Region:SetGradient(o, a, b) self.gradient, self.vertex = { o, a, b }, nil end
function Region:SetVertexColor(r, g, b, a) self.vertex, self.gradient = { r, g, b, a }, nil end
-- as in the game: true when the font loaded (the companion falls back otherwise)
function Region:SetFont(face, size, flags)
    self.font = { face, size, flags }
    return true
end
-- a status bar's fill texture, as the game keeps it
function Region:SetStatusBarTexture(t) self.statusBarTexture = t end
function Region:GetStatusBarTexture()
    local bar = self
    return { GetTexture = function() return bar.statusBarTexture end }
end
function Region:SetDrawLayer(layer, sub) self.layer, self.sub = layer, sub end
function Region:GetThumbTexture()
    self.thumb = self.thumb or self:CreateTexture()
    return self.thumb
end
local ADDON = "WoW/Interface/AddOns/mdlui_Tooltips/"
-- a dropdown keeps the function that fills its menu (the window's checks read it)
function Region:SetupMenu(fn) self.menuFn = fn end

-- ------------------------------------------------------------ stubs
Enum = Enum or {}
Enum.TooltipDataType = Enum.TooltipDataType or { Item = 0, Spell = 1, Unit = 2, Object = 5, UnitAura = 7,
    Macro = 25, Quest = 23, Minimap = 21, Totem = 16, PetAction = 17, Toy = 4, Mount = 22, Currency = 6,
    Achievement = 9, EquipmentSet = 10, InstanceLock = 11, MinimapMouseover = 21, Flyout = 13, Corpse = 3 }
TooltipDataProcessor = TooltipDataProcessor or { AddTooltipPostCall = function() end, AllTypes = "ALL" }
GetLocale = GetLocale or function() return "enUS" end
-- the real LibStub is a table, called or asked GetLibrary; the base stub is a function
if type(LibStub) == "function" then
    local call = LibStub
    LibStub = setmetatable({ GetLibrary = function(_, name, silent) return call(name, silent) end },
        { __call = function(_, name, silent) return call(name, silent) end })
end
-- installed: MedalUI (its font names the panels) and the two companions
C_AddOns.GetAddOnInfo = function(name)
    local here = name == "MedalUI" or name == "mdlui_Tooltips" or name == "mdlui_RadialMenu"
    return name, name, "", here, here and "" or "MISSING"
end
tinsert, tremove, wipe = tinsert or table.insert, tremove or table.remove, wipe or function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
-- The game's nine-slice layouts: the pieces a layout names, as plain textures.
NineSliceUtil = NineSliceUtil or { ApplyLayoutByName = function(frame)
    for _, name in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }) do
        frame[name] = frame:CreateTexture(nil, "BORDER")
    end
end }
-- The game's global strings the panels read, in English; any other of their
-- families falls back to its own name, so a missing one shows in a line.
local STRINGS = {
    TOOLTIP_ITEM_STAT_FORMAT = "%1$s%2$s %3$s", INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_HEAD = "Head", INVTYPE_CHEST = "Chest", INVTYPE_HAND = "Hands",
    INVTYPE_CLOAK = "Back", INVTYPE_RANGED = "Ranged", INVTYPE_TABARD = "Tabard", INVTYPE_BODY = "Shirt",
    ITEM_BIND_ON_EQUIP = "Binds when equipped", ITEM_BIND_ON_PICKUP = "Binds when picked up",
    ITEM_SOULBOUND = "Soulbound", ITEM_MIN_LEVEL = "Requires Level %d", ITEM_LEVEL = "Item Level %d",
    DAMAGE_PER_SECOND = "damage per second", SPELL_CAST_TIME_INSTANT = "Instant",
    SPELL_CAST_TIME_SEC = "%.3g sec cast", DURABILITY_TEMPLATE = "Durability %d / %d",
    ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:", ITEM_SPELL_TRIGGER_ONUSE = "Use:",
    ITEM_SPELL_TRIGGER_ONPROC = "Chance on hit:", ITEM_SET_NAME = "%s (%d/%d)", ITEM_CREATED_BY = "<Made by %s>",
    ITEM_MOD_STAMINA = "%c%s Stamina", ITEM_MOD_INTELLECT = "%c%s Intellect", ITEM_MOD_SPIRIT = "%c%s Spirit",
    ITEM_MOD_STRENGTH = "%c%s Strength", ITEM_MOD_AGILITY = "%c%s Agility",
    ITEM_MOD_STAMINA_SHORT = "Stamina", ITEM_MOD_INTELLECT_SHORT = "Intellect", ITEM_MOD_SPIRIT_SHORT = "Spirit",
    ITEM_MOD_STRENGTH_SHORT = "Strength", ITEM_MOD_AGILITY_SHORT = "Agility",
    ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power", ITEM_MOD_ATTACK_POWER = "Increases attack power by %s.",
    MANA = "Mana", DAMAGE_SCHOOL2 = "Holy", DAMAGE_SCHOOL3 = "Fire", DAMAGE_SCHOOL4 = "Nature",
    DAMAGE_SCHOOL5 = "Frost", DAMAGE_SCHOOL6 = "Shadow", DAMAGE_SCHOOL7 = "Arcane",
    ARMOR_TEMPLATE = "%s Armor", DAMAGE_TEMPLATE = "%s - %s Damage", ITEM_COOLDOWN_TIME_SEC = "Cooldown remaining: %d sec",
    ITEM_COOLDOWN_TOTAL_MIN = "(%d Min Cooldown)", ITEM_MIN_SKILL = "Requires %s (%d)",
    ITEM_REQ_REPUTATION = "Requires %s - %s", ITEM_SET_BONUS_GRAY = "(%d) Set: %s", LOCKED_WITH_SPELL = "Requires %s",
    SPELL_DURATION_SEC = "%.2f sec", SPELL_EQUIPPED_ITEM = "Requires %s", SPELL_TIME_REMAINING_MIN = "%d min remaining",
    SPELL_TIME_REMAINING_SEC = "%d sec remaining",
    BOSS = "Boss", ELITE = "Elite", DEAD = "Dead", CORPSE = "Corpse", TARGET = "Target", YOU = "You",
    FACTION_ALLIANCE = "Alliance", FACTION_HORDE = "Horde", FACTION_STANDING_LABEL7 = "Revered",
    PVP_ENABLED = "PvP", RAID = "Raid", MELEE = "Melee", LFG_TYPE_DUNGEON = "Dungeon",
    OBJECTIVES_LABEL = "Objectives", ROLL_DISENCHANT = "Disenchant", PROFESSIONS_USED_IN_COOKING = "Cooking",
    DECIMAL_SEPERATOR = ".", LARGE_NUMBER_SEPERATOR = ",",
    PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL = "+%s - %s %s Damage", SLASH_CAST1 = "/cast", SLASH_USE1 = "/use",
    LOCALIZED_CLASS_NAMES_MALE = { SHAMAN = "Shaman", MAGE = "Mage", WARRIOR = "Warrior", PRIEST = "Priest",
        ROGUE = "Rogue", DRUID = "Druid", HUNTER = "Hunter", WARLOCK = "Warlock", PALADIN = "Paladin" },
}
local FAMILIES = { "^INVTYPE_", "^ITEM_", "^SPELL_", "^TOOLTIP_", "_FORMAT$", "^DAMAGE_", "^ARMOR",
    "^DURABILITY", "^SELL_PRICE", "^LEVEL", "^UNIT_", "^QUEST_", "^MINIMAP_", "^ERR_", "^RESIST", "^STAT_",
    "^SHIELD_", "_TEMPLATE$", "^LOCKED", "^EMPTY", "^COOLDOWN", "^MANA", "^RAGE", "^ENERGY", "^FOCUS", "^HEALTH" }
local missing = {}
setmetatable(_G, { __index = function(_, key)
    if type(key) ~= "string" or key:find("%l") then return nil end
    if STRINGS[key] then return STRINGS[key] end
    for _, pattern in ipairs(FAMILIES) do
        if key:find(pattern) then return key end
    end
    missing[key] = true
end })

-- ------------------------------------------------------------ load + login
-- (2026-11-22) the processor's post-calls kept, by data type, so a test can
-- fill a tooltip as the game does
local postCalls = {}
do
    local processorStub = TooltipDataProcessor
    local add = processorStub.AddTooltipPostCall
    processorStub.AddTooltipPostCall = function(kind, fn)
        postCalls[kind] = fn
        if add then return add(kind, fn) end
    end
end
-- values the tests hand over as secrets (the unit's health): the companion
-- keeps the game's issecretvalue as it loads, so it is wrapped before
local HIDDEN = {}
do
    local was = issecretvalue
    issecretvalue = function(v) return getmetatable(v) == HIDDEN or (was ~= nil and was(v)) or false end
end
local function hidden() return setmetatable({}, HIDDEN) end
local ns = {}
for line in io.lines(ADDON .. "mdlui_Tooltips.toc") do
    local file = line:match("^([^#][^%[]-%.lua)")
    -- a translation loads only on its own client
    local only = line:match("%[AllowLoadTextLocale (.-)%]")
    if only and not only:find(GetLocale(), 1, true) then file = nil end
    if file then
        local chunk = assert(loadfile(ADDON .. file:gsub("\\", "/")))
        local ok, err = xpcall(chunk, debug.traceback, "mdlui_Tooltips", ns)
        if not ok then print("tooltips load error", file, err) end
    end
end
for _, f in ipairs(events.ADDON_LOADED or {}) do
    if f.scripts.OnEvent then pcall(f.scripts.OnEvent, f, "ADDON_LOADED", "mdlui_Tooltips") end
end
print("tooltips loaded", "ui=" .. tostring(ns.ui ~= nil), "samples=" .. tostring(ns.editorSampleTypes ~= nil))

-- the game's AddOns list page, its minimap button switch and the button: off at first; on, on the
-- minimap's edge; dragged, round it; off again, gone
local function minimapButton(tag, check, button, saved)
    local function where()
        local p = button.points and button.points.CENTER
        return p and string.format("%s %.0f,%.0f", tostring(p[2]), p[3] or 0, p[4] or 0) or "-"
    end
    -- the stub's check buttons keep no state: this one keeps its own
    function check:SetChecked(on) self.checked = on and true or false end
    function check:GetChecked() return self.checked end
    check.scripts.OnShow(check)
    print(tag .. " minimap", "checked=" .. tostring(check:GetChecked()), "shown=" .. tostring(button.shown ~= false),
        "saved=" .. tostring(saved()))
    check:SetChecked(true)
    check.scripts.OnClick(check)
    print(tag .. " minimap on", "shown=" .. tostring(button.shown ~= false), "at " .. where(), "saved=" .. tostring(saved()))
    local cursor, centre, scale = GetCursorPosition, Minimap.GetCenter, Minimap.GetEffectiveScale
    Minimap.GetCenter = function() return 900, 600 end
    Minimap.GetEffectiveScale = function() return 1 end
    GetCursorPosition = function() return 900, 700 end                 -- straight above the map
    button.scripts.OnDragStart(button)
    button.scripts.OnUpdate(button, 0)
    button.scripts.OnDragStop(button)
    GetCursorPosition, Minimap.GetCenter, Minimap.GetEffectiveScale = cursor, centre, scale
    print(tag .. " minimap dragged", "at " .. where(), "following=" .. tostring(button.scripts.OnUpdate ~= nil))
    -- MedalUI's drawer on the action bar takes it: in its line, no longer placed or dragged here
    local M = H.medalui
    if M and M.drawerScan then
        M.drawerScan()
        local angle = saved and button.points and button.points.CENTER and button.points.CENTER[3]
        button.scripts.OnDragStart(button)
        print(tag .. " minimap drawer", "taken=" .. tostring(button.parent == M.drawer),
            "dragging=" .. tostring(button.scripts.OnUpdate ~= nil), "x=" .. tostring(angle))
    end
    check:SetChecked(false)
    check.scripts.OnClick(check)
    print(tag .. " minimap off", "shown=" .. tostring(button.shown ~= false), "saved=" .. tostring(saved()))
end
minimapButton("tooltips", ns.Options.check, _G.mdlui_TooltipsMinimapButton,
    function() return mdlui_TooltipsDB and mdlui_TooltipsDB.minimapButton end)
-- back as it came, for the window's own lines below
mdlui_TooltipsDB.minimapAngle = nil

-- ------------------------------------------------------------ samples
local ui = ns.ui
local types = ns.editorSampleTypes()
local names, byKey = {}, {}
for _, t in ipairs(types) do
    names[#names + 1] = t.key .. "=" .. #t.samples
    byKey[t.key] = t
end
print("tooltips samples", table.concat(names, " "))
local anchor = CreateFrame("Frame", nil, UIParent)
local function render(key, label)
    for _, sample in ipairs(byKey[key].samples) do
        if sample.label == label then return ui.renderPreview(anchor, sample.build(), byKey[key].dataType) end
    end
    error("no sample " .. key .. "/" .. label)
end
local errors = 0
for _, t in ipairs(types) do
    for _, sample in ipairs(t.samples) do
        local ok, err = xpcall(function() return ui.renderPreview(anchor, sample.build(), t.dataType) end,
            debug.traceback)
        if not ok then
            errors = errors + 1
            print("tooltips render error", t.key, sample.label, err)
        end
    end
end
print("tooltips rendered", "errors=" .. errors)

-- ------------------------------------------------------------ reading a panel
local function n(v) return string.format("%.3g", v) end
local function rgba(c)
    if not c then return "-" end
    return n(c[1]) .. "," .. n(c[2]) .. "," .. n(c[3]) .. (c[4] and "," .. n(c[4]) or "")
end
local function paint(t)
    if t.gradient then
        return t.gradient[1]:sub(1, 1) .. "(" .. rgba(t.gradient[2]) .. ">" .. rgba(t.gradient[3]) .. ")"
    end
    return rgba(t.vertex or t.color)
end
local function tex(t)
    if not t then return "nil" end
    if not t.shown then return "off" end
    local path = type(t.texture) == "string" and (t.texture:match("([^\\]+)$")) or "-"
    return path .. ":" .. paint(t)
end
local function lines(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = tex(t) end
    return table.concat(out, " ")
end
local function point(t, name)
    local q = t.points[name]
    return q and (name .. " " .. n(q[3]) .. "," .. n(q[4])) or "-"
end
-- the pool's textures shown, from first
local function pooled(panel)
    local out = {}
    for i = 1, panel.texturesUsed do out[i] = panel.texturePool[i] end
    return out
end
local function texts(panel)
    local out = {}
    for i = 1, panel.used do
        local f = panel.pool[i]
        local p = f.points.TOPLEFT
        out[i] = { text = f.text, x = p and p[3], y = p and -p[4], w = f.w, align = f.prettyTooltipAlign, f = f }
    end
    return out
end
local function plain(text) return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "<m>")) end

-- ------------------------------------------------------------ Questie's map icons
-- (2026-11-22) Questie's map icon tooltip, its lines as Questie lays them
-- out (indents are blank textures of a width), drawn as a quest panel
do
    local QM = ns.QuestieMap
    local function indent(w) return "|TInterface\\Minimap\\UI-bonusobjectiveblob-inside.blp:1:" .. w .. "|t" end
    local holder = CreateFrame("Frame", nil, UIParent)
    local function tip(list, flagged)
        local t = { lefts = {}, rights = {} }
        for i, l in ipairs(list) do
            local left, right = holder:CreateFontString(), holder:CreateFontString()
            left:SetText(l[1]); left:SetTextColor(unpack(l[2] or { 1, 1, 1 }))
            right:SetText(l[3] or ""); right:SetTextColor(unpack(l[4] or { 1, 1, 1 }))
            if not l[3] then right:Hide() end
            -- (as the game answers: a tooltip's lines are not forbidden)
            left.IsForbidden = function() return false end
            right.IsForbidden = left.IsForbidden
            t.lefts[i], t.rights[i] = left, right
        end
        function t:NumLines() return #self.lefts end
        function t:GetLeftLine(i) return self.lefts[i] end
        function t:GetRightLine(i) return self.rights[i] end
        function t:GetName() return nil end
        local owner = {}
        function t:GetOwner() return owner end
        if flagged ~= false then t.ShownAsMapIcon, t._owner, t._Rebuild = true, owner, function() end end
        return t
    end
    local function show(tag, t)
        local model = QM.read(t)
        if not model then print("tooltips questie map " .. tag, "none") return end
        local panel = ui.renderPreview(anchor, model, "questieMap")
        local out = {}
        for _, x in ipairs(texts(panel)) do
            out[#out + 1] = plain(x.text) .. "@" .. tostring(x.x and math.floor(x.x + 0.5))
        end
        print("tooltips questie map " .. tag, "hint=" .. tostring(model.hint), table.concat(out, " | "))
    end
    local yellow, grey, green = { 1, 1, 0 }, { .43, .43, .43 }, { .2, 1, .2 }
    -- one quest: its title, Questie's hint on the right, one objective
    show("one quest", tip({
        { "|cFFFFFF00[42] It Takes Guts|r", green, "(Hold Shift)", grey },
        { indent(13.5) .. "|cFFEFEFEF0/15 Beast Entrails" },
    }))
    -- an older Questie's bullets: "- " under the title, read without them
    show("bullets", tip({
        { "|cFFFFFF00[42] It Takes Guts|r", green },
        { indent(13.5) .. "|cFFEFEFEF- 0/15 Beast Entrails" },
        { indent(13.5) .. "|cFFEFEFEF- 0/8 Rotflesh Mushroom" },
    }))
    -- with Shift: two quests, a mob a step in, its objective two
    show("shift", tip({
        { "|cFFFFFF00[42] It Takes Guts|r", green, "(4,200xp)", yellow },
        { indent(13.5) .. "|cFFDDDDDDRotting Worg (40-41)" },
        { indent(20.25) .. "|cFFEFEFEF0/15 Beast Entrails" },
        { " " },
        { "|cFFFFFF00[40] Rotflesh|r", green, "(Active)", yellow },
        { indent(13.5) .. "|cFFEFEFEF0/8 Rotflesh Mushroom" },
    }))
    -- not one of Questie's icons (no mark): left to the game
    show("unmarked", tip({ { "Some tooltip" } }, false))
    -- marked, but shown for another owner since (a stale mark)
    local stale = tip({ { "Some tooltip" } })
    stale._owner = {}
    show("stale owner", stale)
    -- the game's tooltip shown: drawn when it is Questie's icon's, not otherwise
    local drawn = {}
    local renderLines = ns.Hooks.renderLines
    ns.Hooks.renderLines = function(tooltip, kind) drawn[#drawn + 1] = kind end
    GameTooltip.IsForbidden = function() return false end
    local owner = {}
    GameTooltip.GetOwner = function() return owner end
    GameTooltip.ShownAsMapIcon, GameTooltip._owner, GameTooltip._Rebuild = true, owner, function() end
    GameTooltip:Show()
    GameTooltip.ShownAsMapIcon = false
    GameTooltip:Show()
    print("tooltips questie map hook", "drawn=" .. table.concat(drawn, ","), "times=" .. #drawn)
    GameTooltip.ShownAsMapIcon, GameTooltip._owner, GameTooltip._Rebuild = nil, nil, nil
    GameTooltip.GetOwner, GameTooltip.IsForbidden = nil, nil
    ns.Hooks.renderLines = renderLines
end


local function chrome(label, panel)
    print("tooltips chrome " .. label, "mode=" .. tostring(panel.backdropMode), "inset=" .. tostring(panel.inset),
        "body=" .. paint(panel.background), "wash=" .. tex(panel.wash))
    print("tooltips chrome " .. label .. " frame", "edges=" .. lines(panel.edges), "outer ink=" .. lines(panel.outerInk),
        "outer tint=" .. lines(panel.outerTint), "inner=" .. lines(panel.innerLines), "highlight=" .. tex(panel.innerTop),
        "shades=" .. lines(panel.shades))
    print("tooltips chrome " .. label .. " halo", tex(panel.halo), "blend=" .. tostring(panel.halo.blend),
        point(panel.halo, "TOPLEFT"), point(panel.halo, "BOTTOMRIGHT"))
    print("tooltips chrome " .. label .. " header", "band=" .. tex(panel.header), "h=" .. n(panel.header.h),
        "rule=" .. tex(panel.headerRule), "shadow=" .. tex(panel.headerShadow))
    local band = panel.footerBand
    print("tooltips chrome " .. label .. " footer", "band=" .. tex(band), band.shown and point(band, "TOPLEFT") or "",
        "line=" .. tex(panel.footerLine), "shadow=" .. tex(panel.footerShadow), "height=" .. n(panel.h))
end

-- ------------------------------------------------------------ the styles
local function style(value)
    mdlui_TooltipsDB = mdlui_TooltipsDB or {}
    mdlui_TooltipsDB.backdropStyle = value
end
style(nil)
local weapon = render("item", "Weapon")
chrome("default weapon", weapon)
style("slate")
chrome("slate weapon", render("item", "Weapon"))
style("dialogue")   -- DialogueUI is not installed here
chrome("dialogue missing weapon", render("item", "Weapon"))
style("flat")
chrome("flat weapon", render("item", "Weapon"))
style(nil)
-- untinted: the tint switch off
mdlui_TooltipsDB.qualityTint = false
chrome("untinted weapon", render("item", "Weapon"))
mdlui_TooltipsDB.qualityTint = nil

-- ------------------------------------------------------------ boxes
weapon = render("item", "Weapon")
print("tooltips icon", "icon=" .. n(weapon.icon.w), "border=" .. n(weapon.iconBorder.w) .. ":" .. tex(weapon.iconBorder),
    "gap=" .. n(weapon.iconGap.w) .. ":" .. tex(weapon.iconGap), "ring=" .. n(weapon.iconRing.w) .. ":" .. tex(weapon.iconRing),
    "layers=" .. tostring(weapon.iconRing.sub) .. "<" .. tostring(weapon.iconGap.sub) .. "<" .. tostring(weapon.iconBorder.sub)
        .. "<" .. tostring(weapon.icon.sub))
print("tooltips plate", "edge=" .. tex(weapon.badge), "fill=" .. tex(weapon.badgeFill), "text=" .. tostring(weapon.badgeText.text))

local function chips(label, panel)
    local out, all = {}, pooled(panel)
    local words = {}
    for _, t in ipairs(texts(panel)) do words[t.f] = t end
    for i, t in ipairs(all) do
        local inside = all[i + 1]
        local fill = all[i + 2]
        if t.shown and t.sub == 0 and inside and inside.sub == 1 and inside.points.TOPLEFT
            and inside.points.TOPLEFT[1] == t and inside.points.BOTTOMRIGHT and not (fill and fill.sub == 2) then
            local p = t.points.TOPLEFT
            out[#out + 1] = n(p[3]) .. "," .. n(-p[4]) .. " " .. n(t.w) .. "x" .. n(t.h) .. " " .. paint(t) .. "/" .. paint(inside)
        end
    end
    local caps = {}
    for _, t in ipairs(texts(panel)) do
        if t.align == "CENTER" and t.text and t.text == t.text:upper() and t.text:find("%u") then caps[#caps + 1] = t.text end
    end
    print("tooltips chips " .. label, #out .. " boxes", table.concat(out, " | "), "words=" .. table.concat(caps, ","))
end
chips("spell", render("spell", byKey.spell.samples[1].label))
chips("aura", render("aura", byKey.aura.samples[1].label))
chips("unit", render("unit", byKey.unit.samples[1].label))

-- ------------------------------------------------------------ bars
local function bars(label, panel)
    local out, all = {}, pooled(panel)
    for i, t in ipairs(all) do
        local inside, fill = all[i + 1], all[i + 2]
        if t.shown and t.sub == 0 and inside and inside.sub == 1 and fill and fill.sub == 2 then
            local gloss, tip = all[i + 3], all[i + 4]
            out[#out + 1] = string.format("well %s %sx%s %s ink=%s fill=%s:%s w=%s gloss=%s tip=%s",
                point(t, "TOPLEFT"), n(t.w), n(t.h), paint(t), inside.shown and paint(inside) or "off", fill.shown and "on" or "off", paint(fill), n(fill.w),
                gloss.shown and paint(gloss) or "off", tip.shown and paint(tip) or "off")
        end
    end
    print("tooltips bars " .. label, #out, table.concat(out, " | "))
end
bars("weapon durability", render("item", "Weapon"))
local aura
for _, sample in ipairs(byKey.aura.samples) do
    local panel = render("aura", sample.label)
    bars("aura " .. sample.label, panel)
    aura = aura or panel
end
for _, sample in ipairs(byKey.unit.samples) do
    local panel = render("unit", sample.label)
    bars("unit " .. sample.label, panel)
    if panel.sampleHealth and panel.sampleHealth.shown then
        local bar = panel.sampleHealth
        print("tooltips health " .. sample.label, "top=" .. n(panel.healthTop), point(bar, "TOPLEFT"), point(bar, "TOPRIGHT"),
            "h=" .. n(bar.h))
        local left, right = panel.healthLeft, panel.healthRight
        print("tooltips health text " .. sample.label, "[" .. tostring(left.text) .. "]", point(left, "TOPLEFT"),
            "[" .. tostring(right.text) .. "]", point(right, "TOPRIGHT"), "shown=" .. tostring(left.shown and right.shown))
    end
end

-- the editor's preview going from a unit to a quest: the sample's words go
do
    local unit = render("unit", "Enemy")
    local before = unit.healthLeft.shown
    local quest = render("quest", byKey.quest.samples[1].label)
    print("tooltips health preview then a quest", "same=" .. tostring(unit == quest), "before=" .. tostring(before),
        "after=" .. tostring(quest.healthLeft and quest.healthLeft.shown))
end

-- (2026-11-22) a unit's health in numbers over the game's bar, lent to the
-- panel: the unit's own, again as the bar moves, hidden values passed on
-- unread, and the word Dead
do
    local was = { UnitHealth, UnitHealthMax, AbbreviateLargeNumbers, GameTooltipStatusBar }
    local now, most = 2400, 6800
    UnitHealth = function() return now end
    UnitHealthMax = function() return most end
    AbbreviateLargeNumbers = function(v)
        if getmetatable(v) == HIDDEN then return "(hidden)" end
        return v >= 1000 and string.format("%.1fK", v / 1000) or tostring(v)
    end
    local bar = CreateFrame("StatusBar", nil, GameTooltip)
    bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 2, 2)
    bar:SetHeight(8)
    bar:Show()
    GameTooltipStatusBar = bar
    -- as in the game: plain answers (the stub's are not booleans)
    local function no() return false end
    local forbidden = { GameTooltip.IsForbidden, GameTooltip.IsProtected }
    bar.IsForbidden, bar.IsProtected = no, no
    GameTooltip.IsForbidden, GameTooltip.IsProtected = no, no
    local panel = ui.getPanel(GameTooltip)
    local model = ui.unitModel({ name = "Kurzen Medicine Man", unit = "mouseover", level = 38, reaction = 2 })
    local function draw(label, dead)
        model.dead = dead
        ns.TooltipTypes[byKey.unit.dataType].render(panel, GameTooltip, model)
    end
    local function show(label)
        local left, right = panel.healthLeft, panel.healthRight
        print("tooltips health live " .. label, "[" .. tostring(left and left.text) .. "]",
            "[" .. tostring(right and right.text) .. "]", "shown=" .. tostring(left and left.shown),
            left and point(left, "TOPLEFT") or "", "bar=" .. (bar:GetParent() == panel and "lent" or "home"))
    end
    draw("hurt")
    show("hurt")
    now = 6800
    bar.scripts.OnValueChanged(bar, 6800)
    show("healed, bar moved")
    now, most = hidden(), hidden()
    bar.scripts.OnValueChanged(bar, now)
    show("hidden")
    now, most = 0, 6800
    draw("dead", true)
    show("dead")
    -- drawn as something else: the words go with the bar
    render("item", "Weapon")
    ns.TooltipTypes[byKey.item.dataType].render(panel, GameTooltip, byKey.item.samples[1].build())
    show("then an item")
    -- the panel hidden with the unit's bar, then a quest drawn: the hiding
    -- gave the bar back, and the words stayed over the quest's rows
    now, most = 2164, 2164
    draw("again")
    show("again")
    panel:Hide()
    show("hidden with the panel")
    panel:Show()
    ns.TooltipTypes[byKey.quest.dataType].render(panel, GameTooltip, byKey.quest.samples[1].build())
    show("then a quest")
    UnitHealth, UnitHealthMax, AbbreviateLargeNumbers, GameTooltipStatusBar = was[1], was[2], was[3], was[4]
    GameTooltip.IsForbidden, GameTooltip.IsProtected = forbidden[1], forbidden[2]
end

-- the shared bar options: style, height, texture
local function healthBar(label)
    local panel = render("unit", "Player")
    local bar = panel.sampleHealth
    print("tooltips health bar " .. label, "top=" .. n(panel.healthTop), point(bar, "TOPLEFT"), "h=" .. n(bar.h),
        "texture=" .. tostring(bar.statusBarTexture):match("([^\\]+)$"))
    return panel
end
local function options(label, style, height, texture)
    mdlui_TooltipsDB.barStyle, mdlui_TooltipsDB.barHeight, mdlui_TooltipsDB.barTexture = style, height, texture
    local buff = render("aura", "Buff")
    bars("options " .. label .. " aura", buff)
    print("tooltips options " .. label .. " aura height", n(buff.h))
    bars("options " .. label .. " medalui", ui.renderPreview(anchor,
        { title = "Experience", { "bar", 30, 120, "30 / 120", { .85, .72, .42 } } }, "mdlui"))
    bars("options " .. label .. " durability", render("item", "Weapon"))
    bars("options " .. label .. " health", healthBar(label))
    local all, fills = pooled(render("aura", "Buff")), {}
    for _, t in ipairs(all) do
        if t.sub == 2 then fills[#fills + 1] = tostring(t.texture):match("([^\\]+)$") end
    end
    print("tooltips bar texture " .. label, table.concat(fills, " "))
end
options("default")
options("plain", "plain")
options("tall", nil, 14)
options("short plain", "plain", 4)
options("raid", nil, nil, "Raid")
options("gone", nil, nil, "No Such Bar")
mdlui_TooltipsDB.barStyle, mdlui_TooltipsDB.barHeight, mdlui_TooltipsDB.barTexture = nil, nil, nil
print("tooltips bar textures", table.concat(ns.barTextureNames(), ","))
-- with LibSharedMedia: its status bars are the list, and a name it lacks is flat
do
    local media = {
        List = function(_, kind) return kind == "statusbar" and { "Blizzard", "Smooth" } or {} end,
        IsValid = function(_, kind, name) return kind == "statusbar" and (name == "Blizzard" or name == "Smooth") end,
        Fetch = function(_, _, name) return "Interface\\AddOns\\SharedMedia\\" .. name end,
    }
    local before = LibStub.GetLibrary
    LibStub.GetLibrary = function(_, name) if name == "LibSharedMedia-3.0" then return media end end
    mdlui_TooltipsDB.barTexture = "Smooth"
    local smooth = ns.barTexturePath(ns.option("barTexture"))
    mdlui_TooltipsDB.barTexture = "Raid"   -- the game's, but not one LibSharedMedia has
    print("tooltips bar textures shared", table.concat(ns.barTextureNames(), ","), "Smooth=" .. tostring(smooth),
        "Raid=" .. tostring(ns.barTexturePath(ns.option("barTexture"))))
    mdlui_TooltipsDB.barTexture = nil
    LibStub.GetLibrary = before
end

-- MedalUI's own tooltips (mdlui/MedalUI.lua): a bar part, value of max
local medalui = ui.renderPreview(anchor, { title = "Experience", { "bar", 30, 120, "30 / 120", { .85, .72, .42 } } },
    "mdlui")
bars("medalui xp", medalui)

-- chips wrap where the panel ends: four in a panel room for two a row
do
    local panel = render("unit", byKey.unit.samples[1].label)
    ui.clearPool(panel)
    panel.width = 150
    local style = ui.styleOf("unitBadges")
    local bottom = ui.drawBadges(panel, { { "Elite", { 1, .8, .2 } }, { "Rare", { .8, .8, .9 } },
        { "Boss", { 1, .3, .2 } }, { "PvP", { 1, .3, .3 } } }, 19, 10, style)
    local at = {}
    for i = 1, panel.texturesUsed do
        local t = panel.texturePool[i]
        if t.sub == 0 then at[#at + 1] = point(t, "TOPLEFT") .. " " .. n(t.w) end
    end
    print("tooltips chips wrap", "width=150", table.concat(at, " | "), "bottom=" .. n(bottom))
end

-- a stat list with a row not led by its value (Korean prints the name
-- first) is left as printed; so is one with a right column
do
    local function rows(list)
        local out = {}
        for i, left in ipairs(list) do out[i] = { left = left, right = "" } end
        return out
    end
    local good = rows({ "|cffE9DDC4+5|r |cffEEE7DAStamina|r", "|cffE9DDC4+12|r |cffEEE7DASpirit|r" })
    local mixed = rows({ "|cffE9DDC4+5|r |cffEEE7DAStamina|r", "|cffEEE7DA체력|r |cffE9DDC4+12|r" })
    local right = rows({ "|cffE9DDC4+5|r |cffEEE7DAStamina|r" })
    right[1].right = "Equipped"
    local style = ui.styleOf("stats")
    for _, case in ipairs({ { "value first", good }, { "name first", mixed }, { "right column", right } }) do
        ui.valueGrid(weapon, case[2], style)
        local out = {}
        for i, row in ipairs(case[2]) do out[i] = row.statColumn and (plain(row.statColumn[2]) .. "|" .. n(row.statColumn[5])) or "plain" end
        print("tooltips stats " .. case[1], table.concat(out, " "))
    end
    -- a list gridded once, then given a right column, loses its old marks
    good[2].right = "Equipped"
    ui.valueGrid(weapon, good, style)
    print("tooltips stats regridded", tostring(good[1].statColumn ~= nil), tostring(good[2].statColumn ~= nil))
end

-- ------------------------------------------------------------ text
local function statRows(label, panel)
    local out = {}
    for _, t in ipairs(texts(panel)) do
        local s = plain(t.text)
        if s:match("^[%+%-]%d") or s == "<m>" or s:match("^ %a") then
            out[#out + 1] = s .. "@" .. n(t.x) .. "+" .. n(t.w) .. (t.align == "RIGHT" and "R" or "")
        end
    end
    print("tooltips stats " .. label, table.concat(out, " "))
end
weapon = render("item", "Weapon")
statRows("weapon", weapon)
statRows("set piece", render("item", "Set piece"))
mdlui_TooltipsDB.statMarkers = false
statRows("set piece unmarked", render("item", "Set piece"))
mdlui_TooltipsDB.statMarkers = nil
local font = function(path) return tostring(path):match("([^\\]+)$") end
weapon = render("item", "Weapon")
for _, t in ipairs(texts(weapon)) do
    if plain(t.text):find("damage per second") then
        print("tooltips dps", plain(t.text), "font=" .. font(t.f.font[1]), "size=" .. n(t.f.font[2]))
    end
end

-- ------------------------------------------------------------ strip and divider
local spell = render("spell", byKey.spell.samples[1].label)
do
    local all, out = pooled(spell), {}
    for _, t in ipairs(all) do
        if t.sub and t.sub < 0 and t.shown then
            out[#out + 1] = n(t.w) .. "x" .. n(t.h) .. ":" .. paint(t) .. "@" .. tostring(t.sub)
        end
    end
    local seps = {}
    for _, t in ipairs(all) do
        if t.shown and t.sub == 0 and t.vertex and n(t.vertex[1]) == "0.169" then seps[#seps + 1] = n(t.w) .. "x" .. n(t.h) end
    end
    local captions = {}
    for _, t in ipairs(texts(spell)) do
        if t.align == "CENTER" and t.f.font then captions[#captions + 1] = plain(t.text) .. ":" .. font(t.f.font[1]) end
    end
    print("tooltips strip", table.concat(out, " "), "separators=" .. table.concat(seps, ","), table.concat(captions, " "))
end
do
    weapon = render("item", "Weapon")
    local all, out = pooled(weapon), {}
    for i, t in ipairs(all) do
        local after = all[i + 1]
        if t.shown and t.gradient and t.gradient[1] == "HORIZONTAL" and t.h and t.h <= 1 then
            out[#out + 1] = n(t.w) .. ":" .. paint(t)
            -- the line between the two ramps
            local middle = all[i + 2]
            if after and after.gradient and middle and middle.points.TOPLEFT and middle.points.TOPLEFT[1] == t then
                out[#out + 1] = "middle " .. point(middle, "TOPLEFT") .. ">" .. tostring(middle.points.TOPRIGHT[1] == after)
                    .. ":" .. paint(middle) .. " h=" .. n(middle.h)
            end
        end
    end
    print("tooltips divider", table.concat(out, " "))
end

local miss = {}
for k in pairs(missing) do miss[#miss + 1] = k end
table.sort(miss)
print("tooltips missing globals", table.concat(miss, " "))
for _, sample in ipairs(byKey.item.samples) do
    local m = sample.build()
    for _, list in ipairs({ "primary", "secondary" }) do
        for _, r in ipairs(m[list] or {}) do print("DEBUG", sample.label, list, (r.left:gsub("|", "!"))) end
    end
end

-- ------------------------------------------------------------ quests from Questie
-- A quest link's lines say little; Questie's database, when it is loaded, gives
-- what they leave out (the zone, the level it needs, who starts and ends it,
-- the quests either side, what it asks, the reputation), under WHERE and CHAIN.
-- Never over what the lines said; without Questie, or with it failing, the card
-- is the lines' alone.
do
    local function card(label, model)
        local panel = ui.renderPreview(anchor, model, byKey.quest.dataType)
        local out = {}
        for _, t in ipairs(texts(panel)) do
            if t.text and t.text ~= "" then out[#out + 1] = plain(t.text) end
        end
        -- (2026-11-22) the chips' glyphs, left to right, each with its tint
        local glyphs = {}
        for i = 1, panel.texturesUsed do
            local tex = panel.texturePool[i]
            local name = tostring(tex.texture):match("glyph%-(%a+)$")
            if name then
                local at = tex.points and tex.points.TOPLEFT
                glyphs[#glyphs + 1] = name .. string.format("(%.2f,%.2f,%.2f %dx%d @%d)", tex.vertex[1], tex.vertex[2],
                    tex.vertex[3], tex.w, tex.h, at and at[3] or -1)
            end
        end
        print("tooltips questie " .. label, table.concat(out, " | "), "glyphs=" .. table.concat(glyphs, " "))
    end
    -- the screenshot's link: a title, completed, and the date
    local function link()
        return { name = "Bride of the Embalmer", completed = true,
            extras = { { left = "Completed on", right = "Thursday, November 12, 2026 at 20:20" } } }
    end
    card("none", ui.questModel(link(), 253))
    local quests = {
        [253] = { name = "Bride of the Embalmer", level = 30, requiredLevel = 25, zoneOrSort = 10,
            objectivesText = { "Find Eliza's grave. Retrieve the Embalmer's Heart from her." },
            ObjectiveData = { { Type = "item", Id = 2 } }, Starts = { NPC = { 264 } }, Finisher = { NPC = { 264 } },
            preQuestSingle = { 252 }, nextQuestInChain = 0, reputationReward = { { 72, 250 } } },
        [66] = { name = "The Legend of Stalvan", level = 26, requiredLevel = 20, zoneOrSort = 10, specialFlags = 1,
            IsRepeatable = true, ObjectiveData = { { Type = "monster", Id = 313, Text = nil } },
            Starts = { NPC = { 265 } }, Finisher = { GameObject = { 61 } }, preQuestSingle = {}, nextQuestInChain = 67 },
    }
    local npcs = { [264] = { name = "Ello Ebonlocke", zoneID = 42 }, [265] = { name = "Madame Eva", zoneID = 10 },
        [313] = { name = "Theocritus" } }
    local db = {
        GetQuest = function(id) return quests[id] end,
        QueryQuestSingle = function(id, field)
            if field == "name" then return ({ [252] = "The Embalmer's Revenge", [67] = "The Legend of Stalvan (part 3)" })[id] end
        end,
        QueryNPCSingle = function(id, field) return npcs[id] and npcs[id][field] end,
        QueryObjectSingle = function(id, field) if id == 61 and field == "name" then return "A Weathered Grave" end end,
        QueryItemSingle = function(id, field) if id == 2 and field == "name" then return "Embalmer's Heart" end end,
    }
    QuestieLoader = { _modules = { QuestieDB = db } }
    C_Map = C_Map or {}
    C_Reputation = C_Reputation or {}
    local area, faction = C_Map.GetAreaInfo, C_Reputation.GetFactionDataByID
    C_Map.GetAreaInfo = function(id) return ({ [10] = "Duskwood", [42] = "Darkshire" })[id] end
    C_Reputation.GetFactionDataByID = function(id) return id == 72 and { name = "Stormwind" } or nil end
    card("completed", ui.questModel(link(), 253))
    card("not taken", ui.questModel({ name = "The Legend of Stalvan" }, 66))
    -- what the lines said stays: their zone, their objectives, their Started by
    card("lines said more", ui.questModel({ name = "Bride of the Embalmer", zone = "The Stockade", active = true,
        objectives = { { left = "Embalmer's Heart", right = "0/1", completed = false } },
        extras = { { left = "Started by", right = "Someone Else" }, { left = "Found in", right = "Raven Hill" } } }, 253))
    -- a quest Questie does not have, and a database that fails
    card("unknown quest", ui.questModel(link(), 999))
    db.GetQuest = function() error("broken") end
    card("failing", ui.questModel(link(), 253))
    -- the editor's sample: its Started by and Found in under WHERE
    for _, sample in ipairs(byKey.quest.samples) do
        if sample.label == "New" then card("sample New", sample.build()) end
    end
    -- (2026-11-22) a quest's marker on the world map (the game's quest pin):
    -- the game's lines (the title, what is left to do), every objective from
    -- the quest log ticked as it stands, Questie's WHERE and CHAIN under them
    db.GetQuest = function(id) return quests[id] end
    do
        local QP = ns.QuestPin
        local holder = CreateFrame("Frame", nil, UIParent)
        local map = WorldMapFrame or CreateFrame("Frame", nil, UIParent)
        local mapWas = WorldMapFrame
        WorldMapFrame = map
        local pin = { GetQuestID = function() return 253 end, GetMap = function() return map end,
            IsForbidden = function() return false end, GetWidth = function() return 20 end }
        local function tip(owner, list)
            local tt = { lefts = {}, rights = {} }
            for i, text in ipairs(list) do
                local left, right = holder:CreateFontString(), holder:CreateFontString()
                left:SetText(text); left:SetTextColor(1, 1, 1); right:SetText(""); right:Hide()
                left.IsForbidden = function() return false end
                right.IsForbidden = left.IsForbidden
                tt.lefts[i], tt.rights[i] = left, right
            end
            function tt:NumLines() return #self.lefts end
            function tt:GetLeftLine(i) return self.lefts[i] end
            function tt:GetRightLine(i) return self.rights[i] end
            function tt:GetName() return nil end
            function tt:GetOwner() return owner end
            return tt
        end
        local log = { on = true, ready = false, objectives = {
            { text = "6/15 Beast Entrails", finished = false }, { text = "8/8 Rotflesh Mushroom", finished = true } } }
        local CQ = C_QuestLog
        C_QuestLog = setmetatable({
            IsOnQuest = function() return log.on end,
            ReadyForTurnIn = function() return log.ready end,
            GetQuestObjectives = function() return log.objectives end,
            IsQuestFlaggedCompleted = function() return false end,
        }, { __index = CQ })
        local function pinCard(label, owner, list)
            local model = QP.read(tip(owner, list), 253)
            if not model then print("tooltips questie pin " .. label, "none") return end
            local ticks = {}
            for _, o in ipairs(model.objectives) do ticks[#ticks + 1] = o.left .. "=" .. tostring(o.completed) end
            print("tooltips questie pin " .. label, "ticks=" .. table.concat(ticks, ","), "ready=" .. tostring(model.ready),
                "active=" .. tostring(model.active))
            card("pin " .. label, model)
        end
        -- in progress: the game lists only the one left; the log gives both
        pinCard("in progress", pin, { "[30+] Bride of the Embalmer", "- 6/15 Beast Entrails" })
        -- the log's word for done, where no count says it: "Ghostmaw slain"
        table.insert(log.objectives, { text = "Ghostmaw slain", finished = true })
        pinCard("done without a count", pin, { "[30+] Bride of the Embalmer", "- 6/15 Beast Entrails" })
        table.remove(log.objectives)
        -- the log names none (not yet loaded): the game's lines stay
        local kept = log.objectives
        log.objectives = {}
        pinCard("log names none", pin, { "[30+] Bride of the Embalmer", "- 6/15 Beast Entrails" })
        log.objectives = kept
        -- not in the log (no longer): the game's lines alone, not ready
        log.on, log.ready = false, true
        pinCard("not in the log", pin, { "[30+] Bride of the Embalmer", "- 6/15 Beast Entrails" })
        log.on, log.ready = true, false
        -- ready to turn in: the game lists none; the log's, all ticked
        log.ready, log.objectives[1] = true, { text = "15/15 Beast Entrails", finished = true }
        pinCard("ready", pin, { "[30+] Bride of the Embalmer" })
        -- ready, with no objectives in the log: Questie's, ticked
        log.objectives = {}
        pinCard("ready, none in the log", pin, { "[30+] Bride of the Embalmer" })
        -- the same lines with another owner (not on the map): as a quest link's
        local other = { GetQuestID = pin.GetQuestID, GetMap = function() return nil end,
            IsForbidden = pin.IsForbidden, GetWidth = pin.GetWidth }
        pinCard("not a map pin", other, { "[30+] Bride of the Embalmer" })
        print("tooltips questie pin owner", "pin=" .. tostring((QP.quest(pin))), "other=" .. tostring((QP.quest(other))),
            "no id=" .. tostring((QP.quest({ GetQuestID = function() return 0 end, GetMap = pin.GetMap,
                IsForbidden = pin.IsForbidden, GetWidth = pin.GetWidth }))))
        -- the game's tooltip shown over the marker: drawn as that quest
        local drawn = {}
        local renderLines = ns.Hooks.renderLines
        ns.Hooks.renderLines = function(_, kind, id) drawn[#drawn + 1] = tostring(kind) .. ":" .. tostring(id) end
        GameTooltip.IsForbidden = function() return false end
        GameTooltip.NumLines = function() return 1 end
        GameTooltip.GetOwner = function() return pin end
        GameTooltip.shown = true
        GameTooltip:Show()
        GameTooltip.GetOwner = function() return other end
        GameTooltip:Show()
        print("tooltips questie pin hook", "drawn=" .. table.concat(drawn, ","))
        GameTooltip.IsForbidden, GameTooltip.NumLines, GameTooltip.GetOwner = nil, nil, nil
        ns.Hooks.renderLines = renderLines
        C_QuestLog, WorldMapFrame = CQ, mapWas
    end
    -- (2026-11-22) the chain's chip: the quests still to come after this
    -- one, along Questie's next in chain; none after it, the glyph alone; a
    -- loop in the data counted once round
    do
        local function chainLeft(label, id)
            local model = ui.questModel({ name = quests[id].name }, id)
            print("tooltips quest chain " .. label, "left=" .. tostring(model.chain and model.chain.left))
            card("chain " .. label, model)
        end
        quests[67] = { name = "The Legend of Stalvan II", level = 26, preQuestSingle = { 66 }, nextQuestInChain = 68 }
        quests[68] = { name = "The Legend of Stalvan III", level = 27, preQuestSingle = { 67 }, nextQuestInChain = 0 }
        quests[69] = { name = "Round One", level = 10, preQuestSingle = {}, nextQuestInChain = 70 }
        quests[70] = { name = "Round Two", level = 10, preQuestSingle = { 69 }, nextQuestInChain = 69 }
        chainLeft("two to come", 66)
        -- "LvL" as written, with capitals turned on for the badges too
        local styles = mdlui_TooltipsDB.styles
        local own = ns.elementSetting("questBadges", "caps")
        ns.setElementSetting("questBadges", "caps", true)
        chainLeft("in capitals", 66)
        ns.setElementSetting("questBadges", "caps", own)
        if styles == nil then mdlui_TooltipsDB.styles = nil end
        chainLeft("the last", 68)
        chainLeft("a loop", 69)
        for _, id in ipairs({ 67, 68, 69, 70 }) do quests[id] = nil end
    end
    -- (2026-11-22) the sections told apart: each heading on a band of its
    -- colour, the reputation under a heading of its own (faction, then what
    -- it gives), MedalUI's clicks in the key band at the foot
    do
        local holder = CreateFrame("Frame", nil, UIParent)
        local MOUSE = "|TInterface\\AddOns\\MedalUI\\media\\strips\\mouse-left:16:16:0:0:32:32:5:27:5:27|t "
        local owner = { IsForbidden = function() return false end, GetWidth = function() return 20 end }
        local function lines(list)
            local tt = { lefts = {}, rights = {} }
            for i, pair in ipairs(list) do
                local left, right = holder:CreateFontString(), holder:CreateFontString()
                left:SetText(pair[1]); left:SetTextColor(.6, .6, .6); right:SetText(pair[2] or "")
                if (pair[2] or "") == "" then right:Hide() else right:Show() end
                left.IsForbidden = function() return false end
                right.IsForbidden = left.IsForbidden
                -- (the stub has no GetTextColor)
                left.GetTextColor = function() return .6, .6, .6, 1 end
                right.GetTextColor = left.GetTextColor
                tt.lefts[i], tt.rights[i] = left, right
            end
            function tt:NumLines() return #self.lefts end
            function tt:GetLeftLine(i) return self.lefts[i] end
            function tt:GetRightLine(i) return self.rights[i] end
            function tt:GetName() return nil end
            function tt:GetOwner() return owner end
            return tt
        end
        local function r2(c) return string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) end
        -- the bands drawn: each fill's colour and whether it spans the panel,
        -- and the bars at their left edges
        local function bands(label, panel)
            local fills, bars = {}, 0
            local left = math.max(2, ui.pad() - 8)
            for i = 1, panel.texturesUsed do
                local tex = panel.texturePool[i]
                local g = tex.gradient
                if g and g[1] == "HORIZONTAL" and g[2][4] == .22 and g[3][4] == .04 then
                    fills[#fills + 1] = r2(g[2]) .. (math.abs(tex.w - (panel.width - 2 * left)) < 1 and " full" or " short")
                -- (a pooled texture keeps an old width: a bar is on its own layer too)
                elseif tex.w == 3 and tex.layer == "ARTWORK" and tex.sub == 7 then
                    bars = bars + 1
                end
            end
            print("tooltips quest bands " .. label, "fills=" .. table.concat(fills, " | "), "bars=" .. bars)
        end
        local game = {
            { "[30+] Bride of the Embalmer" }, { "- 0/1 Embalmer's Heart" },
            { "Some addon's line", "its value" },
            { MOUSE .. "Page", "Shift + " .. MOUSE .. "Link" }, { "Ctrl + " .. MOUSE .. "Waypoint", "" },
        }
        local model = ns.QuestPin.read(lines(game), 253)
        local extras, keys = {}, {}
        for _, row in ipairs(model.extras) do extras[#extras + 1] = row.left .. "=" .. tostring(row.right) end
        for _, row in ipairs(model.keys or {}) do keys[#keys + 1] = plain(row.left) .. "/" .. plain(row.right) end
        print("tooltips quest sections read", "extras=" .. table.concat(extras, ","), "keys=" .. table.concat(keys, ","))
        local panel = ui.renderPreview(anchor, model, byKey.quest.dataType)
        local out = {}
        for _, t in ipairs(texts(panel)) do
            if t.text and t.text ~= "" then out[#out + 1] = plain(t.text) end
        end
        print("tooltips quest sections", table.concat(out, " | "))
        bands("default", panel)
        -- two reputations, neither row the word "Reputation"
        quests[254] = { name = "A Taste of the Sea", level = 40, requiredLevel = 36, zoneOrSort = 10,
            Starts = { NPC = { 264 } }, Finisher = { NPC = { 264 } }, reputationReward = { { 72, 50 }, { 72, -25 } } }
        local sea = ui.questModel({ name = "A Taste of the Sea" }, 254)
        local reps = {}
        for _, row in ipairs(sea.extras) do
            reps[#reps + 1] = row.left .. "=" .. plain(row.right) .. (row.rep and "(rep)" or "")
        end
        print("tooltips quest reputation", table.concat(reps, ","))
        panel = ui.renderPreview(anchor, sea, byKey.quest.dataType)
        bands("reputation", panel)
        quests[254] = nil
        -- the player's own colour for the captions: every band in it
        local styles = mdlui_TooltipsDB.styles
        local own = ns.elementSetting("questCaption", "color")
        ns.setElementSetting("questCaption", "color", { .2, .4, .6 })
        panel = ui.renderPreview(anchor, model, byKey.quest.dataType)
        bands("own colour", panel)
        ns.setElementSetting("questCaption", "color", own)
        if styles == nil then mdlui_TooltipsDB.styles = nil end
        -- (2026-11-22) where, the chain and the reputation only with Shift
        -- held, as Questie's tooltips; "Hold Shift" at the foot in their
        -- place. (The editor's sample has them all.)
        local function game(label, m)
            local preview = anchor.prettyTooltipPreview
            preview.isPreview = false
            local p = ui.renderPreview(anchor, m or model, byKey.quest.dataType)
            preview.isPreview = true
            local words = {}
            for _, t in ipairs(texts(p)) do
                if t.text and t.text ~= "" then words[#words + 1] = plain(t.text) end
            end
            print("tooltips quest held " .. label, table.concat(words, " | "))
        end
        local shift = IsShiftKeyDown
        IsShiftKeyDown = function() return false end
        game("up")
        IsShiftKeyDown = function() return true end
        game("down")
        IsShiftKeyDown = function() return false end
        local key = mdlui_TooltipsDB.detailsKey
        mdlui_TooltipsDB.detailsKey = "ALWAYS"
        game("always")
        mdlui_TooltipsDB.detailsKey = key
        local modules = QuestieLoader._modules
        modules.l10n = function(phrase) return phrase == "Hold Shift" and "Shift halten" or phrase end
        game("questie's words")
        modules.l10n = nil
        -- nothing to hide: no hint
        game("nothing held", ui.questModel({ name = "Plain Quest", objectives = { { left = "A thing", right = "0/1" } } }))
        -- (2026-11-22) the reward's experience as a chip after the level
        -- ("ExP 2.4k"): Questie's figure, else the game's; none once done
        do
            local xps, gameXP = {}, {}
            local QX = { GetQuestLogRewardXP = function(_, id) return xps[id] or 0 end }
            local gq = GetQuestLogRewardXP
            GetQuestLogRewardXP = function(id) return gameXP[id] or 0 end
            modules.QuestXP = QX
            local function chip(label, xp, from, fields)
                xps[253], gameXP[253] = nil, nil
                if from == "game" then gameXP[253] = xp else xps[253] = xp end
                local m = ui.questModel(fields or { name = "Bride of the Embalmer" }, 253)
                local p = ui.renderPreview(anchor, m, byKey.quest.dataType)
                local found = "none"
                for _, t in ipairs(texts(p)) do
                    if t.text and plain(t.text):find("ExP", 1, true) then found = plain(t.text) end
                end
                print("tooltips quest xp " .. label, "model=" .. tostring(m.xp), "chip=" .. found)
            end
            chip("small", 850)
            chip("thousands", 2400)
            chip("round thousands", 2000)
            chip("tens of thousands", 12345)
            chip("game's figure", 300, "game")
            chip("none", 0)
            chip("completed", 2400, nil, { name = "Done Quest", completed = true })
            modules.QuestXP = nil
            chip("no questie", 300, "game")
            GetQuestLogRewardXP = gq
        end
        -- (2026-11-22) over a quest's marker on the world map, MedalUI's
        -- right click (its page) at the foot, opposite the hint
        do
            local map = WorldMapFrame or CreateFrame("Frame", nil, UIParent)
            local mapWas, getOwner, pageWas = WorldMapFrame, anchor.GetOwner, MedalUI_MapQuestPage
            WorldMapFrame = map
            local pin = { GetQuestID = function() return 253 end, GetMap = function() return map end,
                IsForbidden = function() return false end, GetWidth = function() return 20 end }
            local asked = {}
            MedalUI_MapQuestPage = function(id) asked[#asked + 1] = id return id == 253 end
            local function foot(label, owner, m)
                anchor.GetOwner = function() return owner end
                asked = {}
                game(label, m)
                -- (the right button's glyph: the page key, not MedalUI's own left-click Page)
                local p, right, at = anchor.prettyTooltipPreview, 0, ""
                for _, t in ipairs(texts(p)) do
                    if t.text and t.text:find("mouse-right", 1, true) then
                        right = right + 1
                        at = at .. " page@" .. math.floor(t.x + .5) .. "+" .. math.floor((t.w or 0) + .5)
                    elseif t.text and plain(t.text) == "Hold Shift" then
                        at = at .. " hint@" .. math.floor(t.x + .5)
                    end
                end
                print("tooltips quest page asked " .. label, table.concat(asked, ","), "right=" .. right,
                    "width=" .. math.floor(p.width + .5) .. at)
            end
            foot("pin", pin)
            -- as a marker's tooltip is: no MedalUI clicks under it
            local bare = ui.questModel({ name = "Bride of the Embalmer", zone = "Duskwood",
                objectives = { { left = "Embalmer's Heart", right = "0/1" } } }, 253)
            foot("pin, no clicks", pin, bare)
            foot("pin, nothing held", pin, ui.questModel({ name = "Plain Quest", objectives = { { left = "A thing", right = "0/1" } } }))
            IsShiftKeyDown = function() return true end
            foot("pin, shift", pin)
            IsShiftKeyDown = function() return false end
            foot("pin, other quest", { GetQuestID = function() return 254 end, GetMap = pin.GetMap,
                IsForbidden = pin.IsForbidden, GetWidth = pin.GetWidth })
            foot("not on the map", { GetQuestID = pin.GetQuestID, GetMap = function() return nil end,
                IsForbidden = pin.IsForbidden, GetWidth = pin.GetWidth })
            -- the style editor's preview names no click, whatever its anchor's owner
            anchor.GetOwner = function() return pin end
            local p, right = ui.renderPreview(anchor, bare, byKey.quest.dataType), 0
            for _, t in ipairs(texts(p)) do
                if t.text and t.text:find("mouse-right", 1, true) then right = right + 1 end
            end
            print("tooltips quest page preview", "right=" .. right)
            MedalUI_MapQuestPage = nil
            foot("no medalui", pin)
            anchor.GetOwner, WorldMapFrame, MedalUI_MapQuestPage = getOwner, mapWas, pageWas
        end
        IsShiftKeyDown = shift
        -- separators off: the names alone
        local seps = mdlui_TooltipsDB.separators
        mdlui_TooltipsDB.separators = false
        panel = ui.renderPreview(anchor, model, byKey.quest.dataType)
        bands("no separators", panel)
        out = {}
        for _, t in ipairs(texts(panel)) do
            if t.text and t.text ~= "" then out[#out + 1] = plain(t.text) end
        end
        print("tooltips quest sections no separators", table.concat(out, " | "))
        mdlui_TooltipsDB.separators = seps
    end
    -- (2026-11-22) the party's progress: the game's own account (Thalric,
    -- two objectives, one done), Questie's sharing (Brannoc, both done:
    -- Ready), and only that one has the quest (Mira); Osk is not on it.
    -- The quest log's own party lines are not read as the quest's.
    do
        local was = { IsInGroup = IsInGroup, UnitName = UnitName, UnitClass = UnitClass, CQ = C_QuestLog,
            CT = C_TooltipInfo, types = Enum.TooltipDataLineType, on = PARTY_QUEST_STATUS_ON }
        local P = { grouped = true, names = { party1 = { "Thalric" }, party2 = { "Brannoc", "Argent Dawn" },
            party3 = { "Mira" }, party4 = { "Osk" } },
            classes = { party1 = "PRIEST", party2 = "WARRIOR", party3 = "MAGE", party4 = "ROGUE" },
            on = { party3 = true }, native = true, shared = true }
        function IsInGroup() return P.grouped end
        function UnitName(u)
            local n = P.names[u]
            if n then return n[1], n[2] end
            return was.UnitName(u)
        end
        function UnitClass(u)
            if P.classes[u] then return P.classes[u], P.classes[u] end
            return was.UnitClass(u)
        end
        RAID_CLASS_COLORS = setmetatable({ PRIEST = { r = 1, g = 1, b = 1 }, WARRIOR = { r = .78, g = .61, b = .43 },
            MAGE = { r = .25, g = .78, b = .92 } }, getmetatable(RAID_CLASS_COLORS))
        Enum.TooltipDataLineType = setmetatable({ QuestObjective = 8, QuestPlayer = 18 }, { __index = was.types })
        C_QuestLog = setmetatable({ IsUnitOnQuest = function(u) return P.on[u] == true end }, { __index = was.CQ })
        C_TooltipInfo = setmetatable({ GetQuestPartyProgress = function(id, omit, ignore)
            if not P.native then return end
            P.asked = tostring(id) .. "," .. tostring(omit) .. "," .. tostring(ignore)
            return { lines = { { type = 18, leftText = "|cffffffffThalric|r" },
                { type = 8, leftText = "Embalmer's Heart: 1/1", completed = true },
                { type = 8, leftText = "0/3 Grave Moss", completed = false },
                -- one from another realm, by name alone; a done objective with no count
                { type = 18, leftText = "Brannoc" }, { type = 8, leftText = "Find the grave", completed = true },
                -- someone not in the party: left out
                { type = 18, leftText = "Stranger" }, { type = 8, leftText = "0/1 Something", completed = false } } }
        end }, { __index = was.CT })
        local modules = QuestieLoader._modules
        modules.QuestieComms = { remoteQuestLogs = { [253] = {
            ["Brannoc-Argent Dawn"] = { { fulfilled = 1, required = 1, finished = true },
                { fulfilled = 3, required = 3, finished = true } },
            -- one count, and one only finished (no counts)
            Thalric = { { fulfilled = 0, required = 1, finished = false }, { finished = true } } } } }
        local function party(label, model)
            local list = {}
            for _, m in ipairs(model.party or {}) do
                local objs = {}
                for _, o in ipairs(m.objectives) do objs[#objs + 1] = o.left .. "=" .. o.right .. (o.completed and "+" or "") end
                list[#list + 1] = m.name .. "(" .. tostring(m.classFile) .. ") " .. m.done .. "/" .. m.total
                    .. (m.ready and " ready" or "") .. " [" .. table.concat(objs, ",") .. "]"
            end
            print("tooltips quest party " .. label, model.party == false and "none" or table.concat(list, " | "))
            card("party " .. label, model)
            -- the party's rows: where each starts, and its colour (a member's
            -- name in the class's; the objectives under it a step in)
            local panel, after, rows = anchor.prettyTooltipPreview, false, {}
            for _, t in ipairs(texts(panel)) do
                if t.text == (PARTY or "Party") or t.text == "PARTY" then after = true
                elseif after and (t.text == "WHERE" or t.text == "Where") then break
                elseif after and t.text and t.text ~= "" then
                    local c = t.f.color or t.f.textColor or {}
                    rows[#rows + 1] = string.format("%s@%d(%.2f,%.2f,%.2f)", plain(t.text), t.x or -1, c[1] or -1, c[2] or -1,
                        c[3] or -1)
                end
            end
            print("tooltips quest party rows " .. label, table.concat(rows, " "))
        end
        local function lines()
            return { name = "Bride of the Embalmer", active = true,
                objectives = { { left = "Embalmer's Heart", right = "0/1", completed = false },
                    { left = "Grave Moss", right = "1/3", completed = false } } }
        end
        party("all three", ui.questModel(lines(), 253))
        for _, sample in ipairs(byKey.quest.samples) do
            if sample.label == "Active" then party("sample Active", sample.build()) end
        end
        print("tooltips quest party asked", tostring(P.asked))
        -- the game says nothing: Questie's for Thalric too, named by our objectives
        P.native = false
        party("questie only", ui.questModel(lines(), 253))
        -- no Questie either: only who has it
        modules.QuestieComms = nil
        party("on only", ui.questModel(lines(), 253))
        -- no one on it, and out of a party
        P.on = {}
        party("no one", ui.questModel(lines(), 253))
        P.on, P.grouped = { party3 = true }, false
        party("solo", ui.questModel(lines(), 253))
        P.grouped = true
        -- the quest log's lines with its party lines under them: they are
        -- not the quest's objectives
        PARTY_QUEST_STATUS_ON = "Party members on this quest:"
        local CL = C_QuestLog
        C_QuestLog = setmetatable({ IsOnQuest = function() return false end }, { __index = CL })
        local holder = CreateFrame("Frame", nil, UIParent)
        local tt = { lefts = {}, rights = {} }
        for i, text in ipairs({ "Bride of the Embalmer", "- Embalmer's Heart: 0/1", "Party members on this quest:",
            "Thalric", "1/1 Embalmer's Heart" }) do
            local left, right = holder:CreateFontString(), holder:CreateFontString()
            left:SetText(text); left:SetTextColor(1, 1, 1); right:SetText(""); right:Hide()
            left.IsForbidden = function() return false end
            right.IsForbidden = left.IsForbidden
            tt.lefts[i], tt.rights[i] = left, right
        end
        function tt:NumLines() return #self.lefts end
        function tt:GetLeftLine(i) return self.lefts[i] end
        function tt:GetRightLine(i) return self.rights[i] end
        function tt:GetName() return nil end
        function tt:GetOwner() return holder end
        local read = ns.QuestPin.read(tt, 253)
        local objs = {}
        for _, o in ipairs(read and read.objectives or {}) do objs[#objs + 1] = o.left .. "=" .. o.right end
        local extras = {}
        for _, e in ipairs(read and read.extras or {}) do extras[#extras + 1] = e.left end
        print("tooltips quest party log lines", "objectives=" .. table.concat(objs, ","), "extras=" .. table.concat(extras, ","))
        C_QuestLog = CL
        IsInGroup, UnitName, UnitClass, C_QuestLog, C_TooltipInfo = was.IsInGroup, was.UnitName, was.UnitClass, was.CQ, was.CT
        Enum.TooltipDataLineType, PARTY_QUEST_STATUS_ON = was.types, was.on
    end
    QuestieLoader, C_Map.GetAreaInfo, C_Reputation.GetFactionDataByID = nil, area, faction
end

-- ------------------------------------------------------------ the window (UI/Editor.lua)
-- What its controls read of the client, stubbed only from here on, so the lines above stay
-- as they were: a dropdown's menu, a button's font string, an edit box's focus.
if not Region.GenerateMenu then function Region:GenerateMenu() end end
if not Region.SetChecked then function Region:SetChecked(on) self.checked = on and true or false end end
if not Region.GetChecked then function Region:GetChecked() return self.checked end end
if not Region.HasFocus then function Region:HasFocus() return false end end
-- a slider as the game's: its value 0 until set, kept in its range, OnValueChanged told
local setValue = Region.SetValue
function Region:SetValue(v)
    if self.kind ~= "Slider" then return setValue(self, v) end
    v = math.max(self.min or v, math.min(self.max or v, v))
    local was = self.value
    setValue(self, v)
    if was ~= v and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function Region:GetValue() return self.value or (self.kind == "Slider" and 0 or nil) end
local function menuOf(drop)
    local out, root = {}, {}
    function root:CreateRadio(text, isSelected, pick)
        out[#out + 1] = { text = text, on = isSelected(), pick = pick }
    end
    function root:SetScrollMode() end
    drop.menuFn(drop, root)
    return out
end
local E = ns.editorWindow
if not E then
    print("tooltips window missing")
    return
end
local DB = function() return mdlui_TooltipsDB or {} end
local function shown(r) return r:IsShown() and "on" or "off" end
-- as the game: a check button turns itself over before its OnClick
local function click(b, mouse)
    if b.kind == "CheckButton" then b:SetChecked(not b:GetChecked()) end
    if b.scripts.OnClick then b.scripts.OnClick(b, mouse or "LeftButton") end
end
-- the card rows of a frame, by label
local function rowsOf(frame, out)
    out = out or {}
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.label and child.label.GetText and (child.label:GetText() or "") ~= "" then
            out[(child.label:GetText() or ""):gsub("  \194\183$", "")] = child
        end
        rowsOf(child, out)
    end
    return out
end
SlashCmdList.MDLUI_TOOLTIPS("")
print("tooltips window", "shown=" .. shown(E.frame), "page=" .. E.state.page, "sheet=" .. E.state.sheet,
    "nav=" .. (function() local n = 0 for _ in pairs(E.nav) do n = n + 1 end return n end)())
-- every kind's two sheets, All tooltips and Options
for _, key in ipairs(ns.editorSamples.order) do
    if E.nav[key] then
        E.show(key, "style")
        local seg = E.examples[key]
        local panel = E.kindPanels[key]
        E.show(key, "panel")
        panel = E.kindPanels[key]
        local labels = {}
        for label in pairs(rowsOf(panel)) do labels[#labels + 1] = label end
        table.sort(labels)
        print("tooltips window kind", key, "examples=" .. #seg.buttons, "rows=" .. table.concat(labels, ","))
    end
end
E.show("item", "style")
print("tooltips window style", "part=" .. tostring(E.state.selected), "card=" .. tostring(E.partCard.title:GetText()),
    "picker=" .. #menuOf(E.partPicker), "lookup=" .. shown(E.lookupCard))
-- a part picked from the card's list
local entries = menuOf(E.partPicker)
for _, e in ipairs(entries) do if e.text == "Stats" then e.pick() end end
print("tooltips window picked", "part=" .. tostring(E.state.selected), "card=" .. tostring(E.partCard.title:GetText()))
-- the part card writes its part's settings
local part = rowsOf(E.partCard)
click(part["All caps"].switch)
part.Size.slider.plus.scripts.OnClick(part.Size.slider.plus)
click(part.Outline.segment.buttons[3])
local fonts = menuOf(part.Font.choice)
fonts[2].pick()
local style = DB().styles and DB().styles[E.state.selected] or {}
print("tooltips window part wrote", "caps=" .. tostring(style.caps), "size=" .. tostring(style.size),
    "outline=" .. tostring(style.outline), "font=" .. tostring(style.font),
    "gold=" .. table.concat(part.Size.label.textColor, ",", 1, 2))
-- a kind's Panel sheet: Restyle, a band, its details
E.show("item", "panel")
local itemRows = rowsOf(E.kindPanels.item)
click(itemRows.Restyle.switch)
click(itemRows["Sell price"].switch)
itemRows["Band top"].slider.minus.scripts.OnClick(itemRows["Band top"].slider.minus)
print("tooltips window panel wrote", "itemPanels=" .. tostring(DB().itemPanels), "sellPrice=" .. tostring(DB().sellPrice),
    "bandTop=" .. tostring(DB().headerTopAlphaItems), "dimmed=" .. tostring(E.nav.item.note:GetText()))
-- a colour: the picker, then right-click to its default
local stat = itemRows["Stat colors"]
local first
for key, sw in pairs(stat.swatches) do first = first or key click(sw) break end
ColorPickerFrame.rgb = { .1, .2, .3 }
ColorPickerFrame.info.swatchFunc()
local picked = DB()["statColor" .. first]
click(stat.swatches[first], "RightButton")
print("tooltips window swatch", "picked=" .. (picked and table.concat(picked, ",") or "nil"),
    "after right click=" .. tostring(DB()["statColor" .. first]))
-- DialogueUI missing: Quest parchment off, with its reason
local parchment = itemRows["Quest parchment"]
print("tooltips window parchment", "enabled=" .. tostring(parchment.switch:IsEnabled()),
    "alpha=" .. tostring(parchment:GetAlpha()))
-- All tooltips and Options
E.show("all")
local all = rowsOf(E.allPage)
click(all.Separators.switch)
menuOf(all["Panel style"].choice)[2].pick()
print("tooltips window all", "shown=" .. shown(E.allPage), "separators=" .. tostring(DB().separators),
    "backdrop=" .. tostring(DB().backdropStyle))
SlashCmdList.MDLUI_TOOLTIPS("options")
local opts = rowsOf(E.optionsPage)
click(opts.Tooltips.segment.buttons[2])
click(opts["The game's tooltip"].segment.buttons[1])
print("tooltips window options", "page=" .. E.state.page, "shown=" .. shown(E.optionsPage), "layout=" .. tostring(DB().layout),
    "originalKey=" .. tostring(DB().originalKey), "kinds=" .. #E.kindRows,
    "nav item=" .. tostring(E.nav.item.note:GetText()))
-- Undo: as it was opened (the place kept)
DB().editorPoint = { "CENTER", "CENTER", 10, 20 }
print("tooltips window changed", "pill=" .. shown(E.changed))
click(E.undo)
local left = {}
for k in pairs(DB()) do left[#left + 1] = k end
table.sort(left)
print("tooltips window undo", "saved=" .. table.concat(left, ","), "pill=" .. shown(E.changed))
-- the AddOns page's button, and the close
E.frame:Hide()
ns.openSettings()
print("tooltips window settings", "shown=" .. shown(E.frame), "page=" .. E.state.page)

-- (2026-11-22) Follow cursor across a redraw. An action button redraws its
-- tooltip every 0.2 s: the clear hands the tooltip back to its own anchor
-- before the game sets it again, and the cursor takes it back once filled.
-- An equipped item's comparison holds the panel's placement meanwhile, so the
-- panel must stay where it stands through the clear, or it is drawn a frame
-- in the default corner (the trace: frame 257 at 2531,461, then back).
do
    local placement, ui = ns.Placement, ns.ui
    mdlui_TooltipsDB.cursorCurrencies, mdlui_TooltipsDB.cursorDisableInCombat = true, false
    ns.Cursor.register()
    local fill = postCalls[Enum.TooltipDataType.Currency]
    -- Hooks' own SetPoint hook, as installed once a panel has drawn
    local held = {}
    hooksecurefunc(GameTooltip, "SetPoint", function(moved)
        held[#held + 1] = tostring(ns.Cursor.restoring())
        if placement.owns(moved) then placement.moved(moved) end
    end)
    local refreshes = 0
    local realRefresh = placement.refresh
    placement.refresh = function(...)
        refreshes = refreshes + 1
        return realRefresh(...)
    end
    local function anchorOf(frame)
        local point = frame.points and (frame.points.TOPLEFT or frame.points.BOTTOMRIGHT)
        if not point then return "-" end
        local to = point[1] == UIParent and "UIParent" or point[1] == GameTooltip and "GameTooltip" or "other"
        return (frame.points.TOPLEFT and "TOPLEFT>" or "BOTTOMRIGHT>") .. to
    end
    local button = CreateFrame("Button", nil, UIParent)          -- an action button
    -- as in the game: a frame says plainly it is not forbidden
    local forbidden = rawget(GameTooltip, "IsForbidden")
    GameTooltip.IsForbidden = function() return false end
    local function redraw(label)
        GameTooltip_SetDefaultAnchor(GameTooltip, button)
        GameTooltip:Show()
        if fill then fill(GameTooltip, { lines = {} }) end
        local panel = ui.getPanel(GameTooltip)
        panel:Show()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", GameTooltip, "TOPLEFT", 0, 0)
        local before = anchorOf(GameTooltip)
        refreshes, held = 0, {}
        GameTooltip:ClearLines()        -- the redraw's clear
        print("tooltips cursor redraw " .. label, "followed=" .. before, "tooltip=" .. anchorOf(GameTooltip),
            "panel=" .. anchorOf(panel), "refreshes=" .. refreshes,
            "held=" .. table.concat(held, ","), "after=" .. tostring(ns.Cursor.restoring()))
        panel:Hide()
        GameTooltip:Hide()
    end
    redraw("item on a bar")
    placement.refresh = realRefresh
    GameTooltip.IsForbidden = forbidden
    mdlui_TooltipsDB.cursorCurrencies, mdlui_TooltipsDB.cursorDisableInCombat = nil, nil
end
