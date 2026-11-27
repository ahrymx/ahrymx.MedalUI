-- Themes: the colour MedalUI's gold accents wear (General > Theme).
--
-- Every gold MedalUI draws in code is a table made through ns.Themed (the
-- named ones are ns.gold's). Once the settings load, ns.ApplyTheme rewrites
-- each in place: its lightness and depth kept, its hue the theme's. A frame
-- reads its gold when it is built, after that, so a switch asks for a reload.
--
-- The gold drawn into the art (the strips' glyphs, the tabs, the medallion
-- strip, the options' arrow and tick) cannot be recoloured by a vertex colour
-- alone: under a theme each such texture is shown desaturated and tinted, its
-- own vertex colours (lit, dim, hover) multiplied by the tint.
--
-- Golden is the gold as drawn: nothing is rewritten and nothing hooked.
-- A new theme is one entry in ns.themes (and a row in the option).
local _, ns = ...

local themed = {}       -- each gold table made through ns.Themed: its gold as drawn
local drawn = {}        -- the same golds by value ("r g b"), to know a paint for one
local tint              -- the theme's colour ({ h, s }), nil under Golden
-- (2026-11-27) a value the game keeps secret (a damage meter's icon, a
-- colour read off a unit) cannot key a table: never ours, so never gold
local secret = issecretvalue or function() return false end
local function Key(r, g, b)
    if secret(r) or secret(g) or secret(b) then return nil end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return ("%.3f %.3f %.3f"):format(r, g, b)
end

local function HSV(r, g, b)
    local hi, lo = math.max(r, g, b), math.min(r, g, b)
    local d = hi - lo
    local h = 0
    if d > 0 then
        if hi == r then h = ((g - b) / d) % 6
        elseif hi == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, hi > 0 and d / hi or 0, hi
end
local function RGB(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    i = i % 6
    if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v end
    return v, p, q
end
ns.HSV, ns.RGB = HSV, RGB

-- The gold's own depth (the mid gold's): a theme as saturated as this or
-- more keeps each gold's saturation; a paler one (a priest's white) pales it.
local DEPTH = 0.55
local function Recolour(r, g, b)
    local _, s, v = HSV(r, g, b)
    return RGB(tint[1], s * math.min(1, tint[2] / DEPTH), v)
end

-- ns.Themed(t): t, a gold { r, g, b [, a] } as drawn, recoloured with the
-- theme (now, if it is applied already, else when it is).
function ns.Themed(t)
    themed[t] = { t[1], t[2], t[3] }
    drawn[Key(t[1], t[2], t[3])] = true
    if tint then t[1], t[2], t[3] = Recolour(t[1], t[2], t[3]) end
    return t
end

-- MedalUI's golds by role. A file keeps the table, never its numbers.
ns.gold = {
    light = ns.Themed({ 0.941, 0.831, 0.533 }),     -- #f0d488: titles, lit glyphs, values
    mid = ns.Themed({ 0.769, 0.647, 0.341 }),       -- #c4a557: the settings' gold, frames' edges
    bright = ns.Themed({ 0.878, 0.722, 0.290 }),    -- #e0b84a: what is chosen
    dark = ns.Themed({ 0.541, 0.439, 0.204 }),      -- #8a7034: rules, rims, quiet labels
    glow = ns.Themed({ 1, 0.9, 0.6 }),              -- a round button's warm hover glow
    -- the linen's thread (window/shell.lua): a cream gold, or the theme's own colour
    linen = { 0.95, 0.88, 0.72 },
}

-- The gold as drawn, whatever the theme, and ns.KeepGold(region, ...) to
-- keep a region in it: never repainted, a gilt glyph never tinted. The
-- folding headings keep theirs (2026-11-26, the user's: "coloured
-- independently of the theme").
ns.goldKept = {
    light = { 0.941, 0.831, 0.533 }, mid = { 0.769, 0.647, 0.341 },
    bright = { 0.878, 0.722, 0.290 }, dark = { 0.541, 0.439, 0.204 },
}
function ns.KeepGold(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region then region.themeKeep = true end
    end
end

-- ns.GoldHex(t): "|cffrrggbb" for a gold table, for text.
function ns.GoldHex(t)
    return ("|cff%02x%02x%02x"):format(t[1] * 255 + 0.5, t[2] * 255 + 0.5, t[3] * 255 + 0.5)
end

-- The themes: each returns its colour ({ r, g, b }), or nil for the gold as drawn.
-- "class" is the player's class; "class:MAGE" (2026-11-26, the user's: every
-- class to pick from) a class's by its file name, whoever plays.
-- (2026-11-27) Warrior's is no theme: its tan is the gold's own palette, so a
-- warrior's class theme is the gold as drawn, and "class:WARRIOR" (saved
-- before) falls back to golden.
local SAME = { WARRIOR = true }
local function ClassColour(file)
    if not file or ns.IsSecret(file) or SAME[file] then return nil end
    local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[file]
    return c and { c.r, c.g, c.b }
end
ns.themes = setmetatable({
    golden = function() return nil end,
    class = function()
        local _, class = UnitClass("player")
        return ClassColour(class)
    end,
}, { __index = function(_, key)
    local file = type(key) == "string" and key:match("^class:(%u+)$")
    if file and not SAME[file] then return function() return ClassColour(file) end end
end })

-- The classes this client has, for the option's list: { file, name },
-- by name (a class id the client lacks, Forever's gaps, skipped).
function ns.ThemeClasses()
    local out = {}
    for i = 1, (GetNumClasses and GetNumClasses() or 0) do
        local name, file = GetClassInfo(i)
        if name and file and not SAME[file] then table.insert(out, { file, name }) end
    end
    table.sort(out, function(a, b) return a[2] < b[2] end)
    return out
end

-- ------------------------------------------------------------ the art
-- The textures whose gold is drawn in (under media\): the strips' glyphs,
-- the tabs and frames, the medallion strip, and the Reticule's console
-- (2026-11-27: its plate, action bar, hybrid strip and wings are gold
-- strokes on a near-black ink, nothing else coloured, so they tint as a
-- glyph does). Pictures (the minimap button, the mailbox, the dungeon's
-- gate) and the Medallion's painted stone keep theirs.
local GILT_STRIPS = {
    "achievement", "channels", "character", "chat-tools", "chat", "check", "chevron-double", "chevron-down",
    "chevron-up", "close", "collections", "currency", "edit", "guild", "help", "housing", "journal", "legacy",
    "lfg", "log", "map", "menu", "misc", "mouse-left", "mouse-middle", "mouse-right", "mouse", "plans", "plus",
    "profession", "pvp", "questlog", "quests", "radial", "reputation", "role-damage", "role-healer", "role-tank",
    "side-auras", "side-controls", "side-current", "side-filter", "side-group", "side-loot", "side-meter",
    "side-mine", "side-one", "side-overall", "side-rate", "side-reset", "side-roll", "side-sort", "side-timeless",
    "side-trackall", "side-tracking", "side-two", "side-well-on", "side-well", "side-worldmap", "side-zone",
    "skills", "social", "sort", "sound-off", "sound", "spellbook", "statistics", "store", "tab-selected", "tab",
    "talents", "track-off", "track", "undo", "view-bags", "view-full", "view-grid", "view-groups",
    "view-minimal", "waypoint", "cell-tab", "drawer-frame", "tray-frame",
}
local gilt = {}
for _, name in ipairs(GILT_STRIPS) do gilt[ns.media .. "strips\\" .. name] = true end
for _, path in ipairs({ "strip", "options\\arrow", "options\\check", "tooltips\\ui\\Arrow", "tooltips\\ui\\Close",
    "tooltips\\stat-marker",
    "console-light-explore", "console-light-combat", "actionbar-light", "hybrid-light", "bar-wing-light" }) do
    gilt[ns.media .. path] = true
end
function ns.IsGilt(path) return not secret(path) and type(path) == "string" and gilt[path] == true end

local artTint           -- what a desaturated gold glyph is multiplied by
local methods           -- the textures' own methods
local textMethods       -- the font strings'

-- A texture showing gilt art: its own SetVertexColor and SetDesaturated
-- remembered and applied through the tint while it does.
local function Apply(tex)
    local c = tex.themeVertex
    if tex.themeGilt then
        methods.SetDesaturated(tex, true)
        methods.SetVertexColor(tex, c[1] * artTint[1], c[2] * artTint[2], c[3] * artTint[3], c[4])
    else
        methods.SetDesaturated(tex, tex.themeDesat or false)
        methods.SetVertexColor(tex, c[1], c[2], c[3], c[4])
    end
end
local function Adopt(tex)
    if tex.themeVertex then return end
    local r, g, b, a = tex:GetVertexColor()
    tex.themeVertex = { r or 1, g or 1, b or 1, a or 1 }
    tex.themeDesat = tex.IsDesaturated and tex:IsDesaturated() or false
    tex.SetVertexColor = function(self, r2, g2, b2, a2)
        self.themeVertex = { r2, g2, b2, a2 or 1 }
        Apply(self)
    end
    tex.SetDesaturated = function(self, on)
        self.themeDesat = on and true or false
        Apply(self)
    end
end
local function Gild(tex, path)
    local on = ns.IsGilt(path)
    if on then Adopt(tex) elseif not tex.themeVertex then return end
    if tex.themeGilt == on then return end
    tex.themeGilt = on
    Apply(tex)
end

-- Before the settings load, a frame built as its file loads paints with the
-- gold as drawn: each such paint (and each gilt texture) is noted, and
-- painted again once a theme is applied. Once it is, the hooks only gild.
-- a colour object's channels (a ColorMixin's r, g, b, a; or a list)
local function Channels(c)
    if type(c) ~= "table" then return nil end
    if c.r then return c.r, c.g, c.b, c.a end
    return c[1], c[2], c[3], c[4]
end
local early = setmetatable({}, { __mode = "k" })    -- region -> { method -> its arguments }
local earlyArt = setmetatable({}, { __mode = "k" }) -- texture -> its gilt path
local settled                                       -- the theme applied (or Golden: nothing to do)
local function Note(method)
    return function(region, ...)
        if settled or region.themeKeep then return end
        local first = select(method == "SetGradient" and 2 or 1, ...)
        local gold
        if method == "SetGradient" then
            local _, a, b = ...
            gold = drawn[Key(Channels(a)) or ""] or drawn[Key(Channels(b)) or ""]
        else
            gold = drawn[Key(first, select(2, ...)) or ""]
        end
        local calls = early[region]
        if gold then
            calls = calls or {}
            early[region] = calls
            calls[method] = { n = select("#", ...), ... }
        elseif calls then
            calls[method] = nil
        end
    end
end
do
    local probe = UIParent:CreateTexture()
    local mt = getmetatable(probe)
    methods = type(mt.__index) == "table" and mt.__index or mt
    probe:Hide()
    local text = UIParent:CreateFontString()
    mt = getmetatable(text)
    textMethods = type(mt.__index) == "table" and mt.__index or mt
    hooksecurefunc(methods, "SetTexture", function(tex, path)
        if tex.themeKeep then return end
        if artTint then return Gild(tex, path) end
        if settled then return end
        earlyArt[tex] = ns.IsGilt(path) and path or nil
    end)
    for _, m in ipairs({ "SetColorTexture", "SetVertexColor", "SetGradient" }) do
        if methods[m] then hooksecurefunc(methods, m, Note(m)) end
    end
    if textMethods ~= methods and textMethods.SetTextColor then
        hooksecurefunc(textMethods, "SetTextColor", Note("SetTextColor"))
    elseif methods.SetTextColor then
        hooksecurefunc(methods, "SetTextColor", Note("SetTextColor"))
    end
end

local function Repaint(r, g, b)
    if drawn[Key(r, g, b) or ""] then return Recolour(r, g, b) end
    return r, g, b
end
local function RepaintColor(c)
    local r, g, b, a = Channels(c)
    if not drawn[Key(r, g, b) or ""] then return c end
    r, g, b = Recolour(r, g, b)
    return CreateColor(r, g, b, a)
end

-- Once the settings load (settings.lua), before any window is built.
function ns.ApplyTheme()
    -- a retired class theme saved: golden, written back so the option says so
    local file = type(ns.db.theme) == "string" and ns.db.theme:match("^class:(%u+)$")
    if file and SAME[file] then ns.db.theme = "golden" end
    ns.themeKey = ns.themes[ns.db.theme] and ns.db.theme or "golden"
    local c = ns.themes[ns.themeKey]()
    settled = true
    if not c then
        early, earlyArt = nil, nil
        return
    end
    local h, s = HSV(c[1], c[2], c[3])
    tint = { h, s }
    for t, was in pairs(themed) do t[1], t[2], t[3] = Recolour(was[1], was[2], was[3]) end
    ns.gold.linen = { c[1], c[2], c[3] }
    -- a glyph's gold desaturates to about its lightness: the tint lifts it
    -- back to the light gold's, in the theme's hue
    local lr, lg, lb = 0.941, 0.831, 0.533
    local grey = 0.299 * lr + 0.587 * lg + 0.114 * lb
    local r, g, b = Recolour(lr, lg, lb)
    artTint = { math.min(1, r / grey), math.min(1, g / grey), math.min(1, b / grey) }
    -- what was painted before now: in the theme's colour
    for region, calls in pairs(early) do
        for method, a in pairs(calls) do
            local fn = (method == "SetTextColor" and textMethods[method]) or methods[method]
            if method == "SetGradient" then
                fn(region, a[1], RepaintColor(a[2]), RepaintColor(a[3]))
            else
                local r2, g2, b2 = Repaint(a[1], a[2], a[3])
                local tex = region.themeVertex and method == "SetVertexColor"
                if tex then region:SetVertexColor(r2, g2, b2, a[4]) else fn(region, r2, g2, b2, a[4]) end
            end
        end
    end
    for tex, path in pairs(earlyArt) do Gild(tex, path) end
    early, earlyArt = nil, nil
end
