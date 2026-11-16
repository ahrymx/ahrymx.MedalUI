-- The "tooltips" pass: mdlui_Tooltips, loaded after Medalluin (tools/harness.lua
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
-- installed: Medalluin (its font names the panels) and the two companions
C_AddOns.GetAddOnInfo = function(name)
    local here = name == "Medalluin" or name == "mdlui_Tooltips" or name == "mdlui_RadialMenu"
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
    end
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
    bars("options " .. label .. " medalluin", ui.renderPreview(anchor,
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

-- Medalluin's own tooltips (mdlui/Medalluin.lua): a bar part, value of max
local medalluin = ui.renderPreview(anchor, { title = "Experience", { "bar", 30, 120, "30 / 120", { .85, .72, .42 } } },
    "mdlui")
bars("medalluin xp", medalluin)

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
        print("tooltips questie " .. label, table.concat(out, " | "))
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
    QuestieLoader, C_Map.GetAreaInfo, C_Reputation.GetFactionDataByID = nil, area, faction
end
