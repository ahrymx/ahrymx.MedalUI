-- The panel that replaces tooltips. The game's tooltip stays
-- underneath, hidden, and shows while the modifier is held or a line cannot be read.
local _, ns = ...
if not ns.Locale.supported or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, pack = util.isSecret, util.pack
local uncolored = util.uncolored
local ITEM = Enum.TooltipDataType.Item
local ART = "Interface\\AddOns\\mdlui_Tooltips\\art\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- Read at use time, so a UI addon's replacement font is followed.
local function fontOf(object)
    local path = object and object.GetFont and object:GetFont()
    return path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
local function bodyFont() return ns.fontPath(ns.option("bodyFont")) or fontOf(GameTooltipText) end
-- A file that fails to load leaves the string without a font, and SetText errors.
-- Each string remembers the font it was given: redrawing a panel mostly sets
-- the font a string already has, and the call costs the same either way.
local function setFont(object, path, size, flags)
    flags = flags or ""
    if object.prettyTooltipFont == path and object.prettyTooltipSize == size
        and object.prettyTooltipFlags == flags then return end
    if not object:SetFont(path, size, flags) then
        object:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
    end
    object.prettyTooltipFont, object.prettyTooltipSize, object.prettyTooltipFlags = path, size, flags
end
-- A commercial font: used from EllesmereUI's folder, never copied here.
local ELLESMERE_BOLD = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf"
local MEDALUI_FONT = "Interface\\AddOns\\MedalUI\\media\\fonts\\MarcellusSC-Regular.ttf"
-- MedalUI's face for Cyrillic: Marcellus has none (MedalUI's core.lua
-- chooses the same)
local MEDALUI_CYRILLIC = "Interface\\AddOns\\MedalUI\\media\\fonts\\Forum-Regular.ttf"
local MAX_WIDTH = 408
-- Wrapping prose is capped at this inner width; other rows fit on one line.
local PROSE_WIDTH = 270
local COLUMN_GAP = 12
local ICON_SIZE = 43
-- The padding at the sides; the top has 2 more, the bottom 2 less.
local function pad() return ns.option("padding") end
local function titleTop() return pad() + 2 end
local function minWidth() return ns.option("minWidth") end

-- One screen pixel in a region's units. A line one unit thick covers one
-- pixel only at some UI scales; elsewhere its edges round apart, and alike
-- lines come out one or two pixels. The game's PixelUtil where the client has
-- it; the same math where not; 1 where the screen size is unknown.
local function pixelFactor()
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() end
    if not GetPhysicalScreenSize then return end
    local _, height = GetPhysicalScreenSize()
    if not isSecret(height) and type(height) == "number" and height > 0 then return 768 / height end
end

local function scaleOf(region)
    local scale = region and region:GetEffectiveScale()
    if not isSecret(scale) and type(scale) == "number" and scale > 0 then return scale end
end

local function pixel(region)
    local factor, scale = pixelFactor(), scaleOf(region)
    if not (factor and scale) then return 1 end
    return factor / scale
end

-- A position or size on whole pixels.
local function snap(region, value)
    local scale = scaleOf(region)
    if scale and PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(value, scale)
    end
    local px = pixel(region)
    return math.floor(value / px + .5) * px
end
local BADGE_GAP = 5
local BADGE_HEIGHT = 16
local EXTRA_COLOR = colors.extras
local GOLD_RULE = { .78, .59, .32 }
-- MedalUI's palette (MedalUI/options/theme.lua): the Gilded look's frame,
-- wells, and plates.
local INK = { .043, .039, .035 }
local GOLD_DARK = { .541, .439, .204 }
local LINE_STRONG = { .239, .212, .165 }
local FLAVOR_GOLD = colors.flavor
local HEADER_ALPHA_TEXTURED, HEADER_ALPHA_PLAIN = .72, .96
local HALO_SPREAD = 16
-- Must match MARGIN in art/make_glow.py.
local HALO_MARGIN = 24
-- Must match --margin for band.tga in art/README.md's make_glow.py command.
local BAND_MARGIN = 16
-- Another author's art: used from DialogueUI's folder, never copied here.
local DIALOGUE_BACKDROP = "Interface\\AddOns\\DialogueUI\\Art\\Theme_Dark\\TooltipBackground-Temp.png"
local QUEST_PARCHMENT = "Interface\\AddOns\\DialogueUI\\Art\\Theme_Brown\\GenericFrame-Tiled-Large.png"
local panels = setmetatable({}, { __mode = "k" })

-- /mdltip perf: how often the panel's work runs and how long it takes. While no
-- capture runs, a probed call costs one check.
local perf = { on = false, calls = {}, time = {}, max = {}, depth = 0, total = 0 }

local function tally(name)
    if perf.on then perf.calls[name] = (perf.calls[name] or 0) + 1 end
end

-- Adds the time since start, from debugprofilestop, to a part of a call.
local function timed(name, start)
    if not (perf.on and start) then return end
    local elapsed = debugprofilestop() - start
    perf.calls[name] = (perf.calls[name] or 0) + 1
    perf.time[name] = (perf.time[name] or 0) + elapsed
    perf.max[name] = math.max(perf.max[name] or 0, elapsed)
end

local function probe(name, fn)
    return function(...)
        if not perf.on then return fn(...) end
        local start = debugprofilestop()
        local depth = perf.depth
        perf.depth = depth + 1
        local results = pack(pcall(fn, ...))
        local elapsed = debugprofilestop() - start
        perf.depth = depth
        if depth == 0 then perf.total = perf.total + elapsed end
        perf.calls[name] = (perf.calls[name] or 0) + 1
        perf.time[name] = (perf.time[name] or 0) + elapsed
        perf.max[name] = math.max(perf.max[name] or 0, elapsed)
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, results.n)
    end
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
local function formatMoney(copper)
    local format = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
        or GetCoinTextureString
    if format then
        local ok, text = pcall(format, copper)
        if ok and not isSecret(text) and type(text) == "string" then return text end
    end
    local parts = {}
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 then parts[#parts + 1] = gold .. COIN:format("Gold") end
    if silver > 0 then parts[#parts + 1] = silver .. COIN:format("Silver") end
    if copper % 100 > 0 or #parts == 0 then
        parts[#parts + 1] = copper % 100 .. COIN:format("Copper")
    end
    return table.concat(parts, " ")
end

local ENCHANT_VALUE, ENCHANT_LABEL = "4CE64C", "A6EBA6"
-- One row per bonus; named enchants ("Crusader") stay whole.
-- An enchant's stats, which its name lists ("Stamina +2 and Armor +16"),
-- each printed as the game prints a stat.
local function enchantRows(text)
    local list = text
    for _, separator in ipairs(ns.Locale.listSeparators) do
        local following = type(separator) == "table" and separator[2] or ""
        separator = type(separator) == "table" and separator[1] or separator
        list = list:gsub(((separator .. following):gsub("%p", "%%%0")), "\031" .. following)
    end
    local rows = {}
    for piece in (list .. "\031"):gmatch("(.-)\031") do
        local name, amount = piece:match("^(.-) %+(%d+%%?)$")
        if not name then amount, name = piece:match("^%+(%d+%%?) (.+)$") end
        -- Some clients join name and amount, with a suffix on the amount:
        -- Traditional Chinese's "耐力+16點".
        if not name then
            name, amount = util.unformat(piece, ns.Locale.formats.enchantBonus)
            name = name and util.trim(name)
        end
        if not name or name == "" or not (amount and amount:match("^%d+%%?$")) then
            return { "|cff" .. ENCHANT_VALUE .. text .. "|r" }
        end
        rows[#rows + 1] = util.fill(TOOLTIP_ITEM_STAT_FORMAT, "|cff" .. ENCHANT_VALUE .. "+", amount .. "|r",
            "|cff" .. ENCHANT_LABEL .. name .. "|r")
    end
    return rows
end

local function isComparison(tooltip)
    local name = tooltip:GetName()
    return name ~= nil and name:find("ShoppingTooltip%d$") ~= nil
end

local function hasDialogueBackdrop()
    return ns.Game.addonInstalled("DialogueUI")
end

local hasEllesmere
local function ellesmereInstalled()
    if hasEllesmere == nil then hasEllesmere = ns.Game.addonInstalled("EllesmereUI") end
    return hasEllesmere
end

local hasMedalUI
local function medaluiInstalled()
    if hasMedalUI == nil then hasMedalUI = ns.Game.addonInstalled("MedalUI") end
    return hasMedalUI
end

local function titleFont()
    local chosen = ns.fontPath(ns.option("titleFont"))
    if chosen then return chosen end
    -- Expressway and Marcellus SC have no Hangul or Chinese; use the client's header font there.
    local locale = GetLocale()
    if locale == "koKR" or locale == "zhCN" or locale == "zhTW" then return fontOf(GameTooltipHeaderText) end
    if medaluiInstalled() then
        -- the face MedalUI settled on (its General > Font)
        if type(MedalUIFontFace) == "string" then return MedalUIFontFace end
        return locale == "ruRU" and MEDALUI_CYRILLIC or MEDALUI_FONT
    end
    -- (Expressway has no Cyrillic either)
    if locale == "ruRU" then return fontOf(GameTooltipHeaderText) end
    return ellesmereInstalled() and ELLESMERE_BOLD or fontOf(GameTooltipHeaderText)
end

-- "gilded", "slate", "dialogue", "flat", or "native". Unchosen, Gilded:
-- MedalUI's gold frame and ink. DialogueUI's art only while it is installed.
local function backdropStyle()
    local chosen = ns.option("backdropStyle")
    if chosen == "dialogue" then return hasDialogueBackdrop() and "dialogue" or "gilded" end
    if chosen == "slate" or chosen == "flat" or chosen == "native" then return chosen end
    return "gilded"
end

local function styleOf(key)
    local style = ns.style(key)
    style.customFont = style.font ~= nil
    style.font = style.font or (style.title and titleFont() or bodyFont())
    return style
end

-- Escape codes are case sensitive ("|r", "|t", link data), so only the text
-- between them is uppercased.
local ESCAPE_ENDS = { T = "|t", A = "|a", H = "|h", K = "|k", ["4"] = ";" }

local function capitalize(text)
    local out, pos = {}, 1
    while true do
        local bar = text:find("|", pos, true)
        if not bar then break end
        out[#out + 1] = util.upper(text:sub(pos, bar - 1))
        local code, stop = text:sub(bar + 1, bar + 1), bar + 1
        if code == "c" then
            stop = bar + 9
        elseif ESCAPE_ENDS[code] then
            local _, found = text:find(ESCAPE_ENDS[code], bar + 2, true)
            stop = found or #text
        end
        out[#out + 1] = text:sub(bar, stop)
        pos = stop + 1
    end
    out[#out + 1] = util.upper(text:sub(pos))
    return table.concat(out)
end

local function asStyle(style)
    if type(style) == "table" then return style end
    return { size = style, font = bodyFont(), flags = "" }
end

-- Rounding is per region, not inherited. Configure each owned region once,
-- including those created later when a text or texture pool grows.
local function roundLayout(region)
    region:SetRoundLayoutToNearestPixel(true)
    return region
end

-- Rows other addons append are absent from the data. Nil when one is unreadable.
local function makeTexture(parent, layer, path)
    local tex = roundLayout(parent:CreateTexture(nil, layer))
    tex:SetTexture(path or WHITE)
    return tex
end

-- Four lines around the panel, one pixel thick: a ring `out` pixels outside
-- its edge (0 on the edge, negative inside it). Placed again on every draw, as
-- a pixel's size follows the scale.
local function frameLines(panel, layer, sublevel)
    local lines = {}
    for index = 1, 4 do
        lines[index] = makeTexture(panel, layer)
        lines[index]:SetDrawLayer(layer, sublevel)
    end
    return lines
end

local function placeLines(panel, lines, out, px)
    local o = out * px
    local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
    for _, line in ipairs(lines) do line:ClearAllPoints() end
    top:SetPoint("TOPLEFT", panel, "TOPLEFT", -o, o)
    top:SetPoint("TOPRIGHT", panel, "TOPRIGHT", o, o)
    top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -o, -o)
    bottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", o, -o)
    bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", -o, o)
    left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -o, -o)
    left:SetWidth(px)
    right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", o, o)
    right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", o, -o)
    right:SetWidth(px)
end

local function colorLines(lines, color, alpha)
    for _, line in ipairs(lines) do line:SetVertexColor(color[1], color[2], color[3], alpha) end
end

local function showLines(lines, shown)
    for _, line in ipairs(lines) do line:SetShown(shown) end
end

local function createPanel(parent)
    local panel = roundLayout(CreateFrame("Frame", nil, parent))
    panel:SetFrameStrata("TOOLTIP")
    panel.width = MAX_WIDTH
    panel:SetWidth(MAX_WIDTH)
    panel.measure = roundLayout(panel:CreateFontString(nil, "OVERLAY"))
    panel.measure:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.measure:SetAlpha(0)
    panel:SetClampedToScreen(true)
    panel:Hide()
    panel.pool, panel.used = {}, 0
    panel.texturePool, panel.texturesUsed = {}, 0
    if panel.SetIgnoreParentAlpha then panel:SetIgnoreParentAlpha(true) end
    panel.halo = roundLayout(panel:CreateTexture(nil, "BACKGROUND", nil, -8))
    panel.halo:SetPoint("TOPLEFT", panel, "TOPLEFT", -HALO_SPREAD, HALO_SPREAD)
    panel.halo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", HALO_SPREAD, -HALO_SPREAD)
    panel.halo:SetTexture(ART .. "glow")
    if panel.halo.SetTextureSliceMargins then
        panel.halo:SetTextureSliceMargins(HALO_MARGIN, HALO_MARGIN, HALO_MARGIN, HALO_MARGIN)
    end
    panel.halo:SetBlendMode("ADD")
    panel.background = roundLayout(panel:CreateTexture(nil, "BACKGROUND", nil, -7))
    panel.background:SetAllPoints()
    if panel.background.SetTextureSliceMargins then
        -- Multiplying barely tints the near-black backdrop; an additive copy carries the glow.
        panel.glow = roundLayout(panel:CreateTexture(nil, "BACKGROUND", nil, -6))
        panel.glow:SetAllPoints()
        panel.glow:SetTexture(DIALOGUE_BACKDROP)
        panel.glow:SetTextureSliceMargins(32, 32, 32, 32)
        panel.glow:SetTextureSliceMode(1)
        panel.glow:SetBlendMode("ADD")
    end
    local function shade(orientation, from, to, a1, a2)
        local tex = roundLayout(panel:CreateTexture(nil, "BORDER", nil, 2))
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetPoint(from, panel, from)
        tex:SetPoint(to, panel, to)
        tex:SetGradient(orientation, CreateColor(0, 0, 0, a1), CreateColor(0, 0, 0, a2))
        return tex
    end
    panel.shades = {
        shade("VERTICAL", "TOPLEFT", "TOPRIGHT", 0, .30),
        shade("VERTICAL", "BOTTOMLEFT", "BOTTOMRIGHT", .45, 0),
        shade("HORIZONTAL", "TOPLEFT", "BOTTOMLEFT", .35, 0),
        shade("HORIZONTAL", "TOPRIGHT", "BOTTOMRIGHT", 0, .35),
    }
    panel.shades[1]:SetHeight(10)
    panel.shades[2]:SetHeight(10)
    panel.shades[3]:SetWidth(8)
    panel.shades[4]:SetWidth(8)
    panel.header = makeTexture(panel, "BORDER")
    -- Gilded: a gold line under the header, ink under it; Slate: the tint's wash
    -- down the panel's top.
    panel.headerRule = makeTexture(panel, "BORDER")
    panel.headerRule:SetDrawLayer("BORDER", 3)
    panel.headerShadow = makeTexture(panel, "BORDER")
    panel.headerShadow:SetDrawLayer("BORDER", 3)
    panel.wash = makeTexture(panel, "BACKGROUND")
    panel.wash:SetDrawLayer("BACKGROUND", -5)
    -- The footer's sunken band (Gilded) or its rule (Slate), placed by footerBand.
    panel.footerBand = makeTexture(panel, "BORDER")
    panel.footerBand:SetDrawLayer("BORDER", 1)
    panel.footerLine = makeTexture(panel, "BORDER")
    panel.footerLine:SetDrawLayer("BORDER", 3)
    panel.footerShadow = makeTexture(panel, "BORDER")
    panel.footerShadow:SetDrawLayer("BORDER", 2)
    -- Gilded's frame: ink, then a tinted line, outside the gold edge; a
    -- highlight and ink just inside it. Slate keeps only the highlight.
    panel.outerInk = frameLines(panel, "BORDER", 4)
    panel.outerTint = frameLines(panel, "BORDER", 4)
    panel.innerTop = makeTexture(panel, "BORDER")
    panel.innerTop:SetDrawLayer("BORDER", 4)
    panel.innerLines = frameLines(panel, "BORDER", 4)
    panel.icon = makeTexture(panel, "OVERLAY")
    panel.icon:SetSize(ICON_SIZE, ICON_SIZE)
    panel.iconBorder = makeTexture(panel, "OVERLAY")
    panel.iconBorder:SetSize(45, 45)
    panel.iconBorder:SetPoint("CENTER", panel.icon, "CENTER")
    panel.iconBorder:SetVertexColor(.55, .45, .37, .9)
    panel.iconBorder:SetDrawLayer("OVERLAY", 1)
    -- The icon's frame: its accent line, then ink, then a dark gold ring.
    panel.iconGap = makeTexture(panel, "OVERLAY")
    panel.iconGap:SetDrawLayer("OVERLAY", -1)
    panel.iconGap:SetPoint("CENTER", panel.icon, "CENTER")
    panel.iconRing = makeTexture(panel, "OVERLAY")
    panel.iconRing:SetDrawLayer("OVERLAY", -2)
    panel.iconRing:SetPoint("CENTER", panel.icon, "CENTER")
    panel.icon:SetDrawLayer("OVERLAY", 2)
    panel.badge = makeTexture(panel, "OVERLAY")
    panel.badge:SetDrawLayer("OVERLAY", 1)
    panel.badge:SetPoint("TOP", panel.icon, "BOTTOM", 0, -BADGE_GAP)
    panel.badgeFill = makeTexture(panel, "OVERLAY")
    panel.badgeFill:SetDrawLayer("OVERLAY", 2)
    panel.badgeFill:SetPoint("TOPLEFT", panel.badge, "TOPLEFT", 1, -1)
    panel.badgeFill:SetPoint("BOTTOMRIGHT", panel.badge, "BOTTOMRIGHT", -1, 1)
    panel.badgeText = roundLayout(panel:CreateFontString(nil, "OVERLAY"))
    panel.badgeText:SetDrawLayer("OVERLAY", 3)
    panel.badgeText:SetPoint("CENTER", panel.badge, "CENTER", 0, 0)
    panel.edges = {}
    for i = 1, 4 do panel.edges[i] = makeTexture(panel, "OVERLAY") end
    panel.edges[1]:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.edges[1]:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    panel.edges[1]:SetHeight(2)
    panel.edges[2]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
    panel.edges[2]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.edges[2]:SetHeight(1)
    panel.edges[3]:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.edges[3]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
    panel.edges[3]:SetWidth(1)
    panel.edges[4]:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    panel.edges[4]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.edges[4]:SetWidth(1)
    return panel
end

local function getPanel(tooltip)
    local panel = panels[tooltip]
    if panel then return panel end
    -- Shown and hidden with the tooltip's parent (Integration/Native.lua).
    local host = CreateFrame("Frame", nil, UIParent)
    panel = createPanel(host)
    panel.host = host
    panels[tooltip] = panel
    return panel
end

-- The game's own tooltip border, from the layout GameTooltip uses, on a frame
-- over the panel; its center is left out, so the panel's backdrop shows.
-- False when the game cannot build one, and the panel stays flat.
local NATIVE_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
local NATIVE_INSET = 4

local function nativeBorder(panel)
    if panel.nativeBorder ~= nil then return panel.nativeBorder or nil end
    panel.nativeBorder = false
    if not (NineSliceUtil and NineSliceUtil.ApplyLayoutByName) then return end
    local slice = GameTooltip and GameTooltip.NineSlice
    local layout = slice and type(slice.layoutType) == "string" and slice.layoutType or "TooltipDefaultLayout"
    local frame = roundLayout(CreateFrame("Frame", nil, panel))
    frame:SetAllPoints()
    if not pcall(NineSliceUtil.ApplyLayoutByName, frame, layout) then
        frame:Hide()
        return
    end
    -- These textures are created by Blizzard's layout on our border frame.
    for _, region in ipairs({ frame:GetRegions() }) do roundLayout(region) end
    if frame.Center then frame.Center:Hide() end
    panel.nativeBorder = frame
    return frame
end

-- The accent when the panel has one, as items their quality and spells their
-- school; else the color the game gives its own tooltip's border.
local function colorNativeBorder(border, tint, gradient)
    if gradient then
        local left, right = gradient[1], gradient[2]
        for _, name in ipairs({ "TopLeftCorner", "BottomLeftCorner", "LeftEdge" }) do
            if border[name] then border[name]:SetVertexColor(left[1], left[2], left[3], 1) end
        end
        for _, name in ipairs({ "TopRightCorner", "BottomRightCorner", "RightEdge" }) do
            if border[name] then border[name]:SetVertexColor(right[1], right[2], right[3], 1) end
        end
        for _, name in ipairs({ "TopEdge", "BottomEdge" }) do
            if border[name] then
                border[name]:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], 1),
                    CreateColor(right[1], right[2], right[3], 1))
            end
        end
        return
    end
    local r, g, b, a
    if tint then
        r, g, b, a = tint[1], tint[2], tint[3], 1
    else
        local slice = GameTooltip and GameTooltip.NineSlice
        if slice and slice.GetBorderColor then r, g, b, a = util.call(slice.GetBorderColor, slice) end
    end
    if type(r) ~= "number" then r, g, b, a = 1, 1, 1, 1 end
    for _, name in ipairs(NATIVE_PIECES) do
        local piece = border[name]
        if piece then piece:SetVertexColor(r, g, b, a or 1) end
    end
end

-- Chosen per render so the option applies without a reload.
local function applyBackdrop(panel, chrome)
    local parchment = chrome.quest and ns.option("questParchment") and hasDialogueBackdrop()
        and panel.background.SetTextureSliceMargins ~= nil
    local style = parchment and "parchment" or backdropStyle()
    local textured = style == "dialogue" and panel.glow ~= nil
    local border = style == "native" and nativeBorder(panel) or nil
    local mode = parchment and "parchment" or textured and "dialogue" or border and "native"
        or (style == "gilded" or style == "slate") and style or "flat"
    if panel.backdropMode == mode then return end
    panel.backdropMode = mode
    panel.textured = textured
    panel.parchment = parchment and true or false
    panel.halo:SetShown(not parchment)
    -- Slate's halo is a shadow cast down; the others' a glow around.
    panel.halo:ClearAllPoints()
    local drop = mode == "slate" and 4 or 0
    panel.halo:SetPoint("TOPLEFT", panel, "TOPLEFT", -HALO_SPREAD, HALO_SPREAD - drop)
    panel.halo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", HALO_SPREAD, -HALO_SPREAD - drop)
    panel.halo:SetBlendMode(mode == "slate" and "BLEND" or "ADD")
    if panel.nativeBorder then panel.nativeBorder:SetShown(mode == "native") end
    -- Inside the game's border, the backdrop takes the place of the game's own
    -- background, so none of it shows past the border's rounded corners.
    panel.background:ClearAllPoints()
    if border and border.Center then
        panel.background:SetAllPoints(border.Center)
    else
        panel.background:SetAllPoints()
    end
    if textured or parchment then
        panel.background:SetTexture(parchment and QUEST_PARCHMENT or DIALOGUE_BACKDROP)
        panel.background:SetTextureSliceMargins(32, 32, 32, 32)
        panel.background:SetTextureSliceMode(1)
        if parchment and panel.glow then panel.glow:Hide() end
    else
        if panel.background.SetTextureSliceMargins then
            panel.background:SetTextureSliceMargins(0, 0, 0, 0)
            panel.background:SetTextureSliceMode(0)
        end
        panel.background:SetColorTexture(1, 1, 1, 1)
        if panel.glow then panel.glow:Hide() end
    end
    local band = panel.header
    band:SetShown(not parchment and mode ~= "slate")
    if textured then
        band:SetTexture(ART .. "band")
        band:SetTextureSliceMargins(BAND_MARGIN, BAND_MARGIN, BAND_MARGIN, BAND_MARGIN)
    else
        if band.SetTextureSliceMargins then band:SetTextureSliceMargins(0, 0, 0, 0) end
        band:SetTexture(mode == "gilded" and ART .. "header-glow" or WHITE)
    end
    local gilded, slate = mode == "gilded", mode == "slate"
    local framed = mode == "flat" or gilded or slate
    for _, region in ipairs(panel.shades) do region:SetShown(mode == "flat" or gilded) end
    for _, region in ipairs(panel.edges) do region:SetShown(framed) end
    panel.headerRule:SetShown(gilded)
    panel.headerShadow:SetShown(gilded)
    panel.wash:SetShown(slate)
    showLines(panel.outerInk, gilded)
    showLines(panel.outerTint, gilded)
    showLines(panel.innerLines, gilded)
    panel.innerTop:SetShown(gilded or slate)
    panel.inset = (textured or parchment) and 6 or border and NATIVE_INSET or 1
    local inset = panel.inset
    panel.header:ClearAllPoints()
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -inset)
    panel.headerRule:ClearAllPoints()
    panel.headerRule:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT")
    panel.headerRule:SetPoint("TOPRIGHT", panel.header, "BOTTOMRIGHT")
    panel.headerShadow:ClearAllPoints()
    panel.headerShadow:SetPoint("TOPLEFT", panel.headerRule, "BOTTOMLEFT")
    panel.headerShadow:SetPoint("TOPRIGHT", panel.headerRule, "BOTTOMRIGHT")
    panel.wash:ClearAllPoints()
    panel.wash:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
    panel.wash:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -inset)
    panel.wash:SetHeight(64)
end

-- The footer's band from top (Gilded: sunken, a gold line over it) or its rule
-- (Slate), down to the panel's bottom edge. Whether one shows: the panel's end
-- below the footer is then the band's own padding.
local function footerBand(panel, top)
    local mode = panel.backdropMode
    local band = top and (mode == "gilded" or mode == "slate")
    panel.footerBand:SetShown(band and mode == "gilded")
    panel.footerShadow:SetShown(band and mode == "gilded")
    panel.footerLine:SetShown(band)
    if not band then return false end
    local inset, px = panel.inset, pixel(panel)
    local y = snap(panel, top)
    panel.footerBand:ClearAllPoints()
    panel.footerBand:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -y)
    panel.footerBand:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, inset)
    panel.footerBand:SetGradient("VERTICAL", CreateColor(.059, .051, .043, .9), CreateColor(.047, .043, .035, .9))
    panel.footerLine:ClearAllPoints()
    panel.footerLine:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -y)
    panel.footerLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -y)
    panel.footerLine:SetHeight(px)
    if mode == "gilded" then
        panel.footerLine:SetVertexColor(GOLD_DARK[1], GOLD_DARK[2], GOLD_DARK[3], .45)
    else
        panel.footerLine:SetVertexColor(1, 1, 1, .06)
    end
    panel.footerShadow:ClearAllPoints()
    panel.footerShadow:SetPoint("TOPLEFT", panel.footerLine, "BOTTOMLEFT")
    panel.footerShadow:SetPoint("TOPRIGHT", panel.footerLine, "BOTTOMRIGHT")
    panel.footerShadow:SetHeight(4)
    panel.footerShadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, .55))
    return true
end

local function clearPool(panel)
    for _, font in ipairs(panel.pool) do font:Hide() end
    for _, tex in ipairs(panel.texturePool) do tex:Hide() end
    for _, font in ipairs(panel.hiddenPool or {}) do font:Hide() end
    panel.used, panel.texturesUsed, panel.hiddenUsed = 0, 0, 0
    if panel.hits then panel.hits = {} end
end

local function textAt(panel, content, x, y, width, size, color, fontPath, align, flags)
    panel.used = panel.used + 1
    local font = panel.pool[panel.used]
    if not font then
        font = roundLayout(panel:CreateFontString(nil, "OVERLAY"))
        -- The same for every row, so set once.
        font:SetJustifyV("TOP")
        font:SetShadowColor(0, 0, 0, 0)
        font:SetShadowOffset(0, 0)
        panel.pool[panel.used] = font
    end
    font:ClearAllPoints()
    font:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    font:SetWidth(width)
    setFont(font, fontPath or bodyFont(), size, flags)
    align = align or "LEFT"
    if font.prettyTooltipAlign ~= align then
        font:SetJustifyH(align)
        font.prettyTooltipAlign = align
    end
    local r, g, b = color[1], color[2], color[3]
    if font.prettyTooltipR ~= r or font.prettyTooltipG ~= g or font.prettyTooltipB ~= b then
        font:SetTextColor(r, g, b)
        font.prettyTooltipR, font.prettyTooltipG, font.prettyTooltipB = r, g, b
    end
    font:SetText(content)
    font:Show()
    return math.max(size + 2, font:GetStringHeight() or 0)
end

-- Bright tooltip colors become readable ink on paper. Neutral text takes
-- Deep brown ink for neutral text; colored states keep their hue in a darker shade.
local function inkColor(color)
    local r, g, b = color[1], color[2], color[3]
    local high, low = math.max(r, g, b), math.min(r, g, b)
    if high - low < .14 then return { .11, .085, .055 } end
    local brightness = .2126 * r + .7152 * g + .0722 * b
    local scale = math.min(1, .19 / brightness, .4 / high)
    return { r * scale, g * scale, b * scale }
end

local function inkText(content)
    return (content:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(alpha, r, g, b)
        local color = inkColor({ tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 })
        return "|c" .. alpha .. util.hex(color)
    end))
end

-- A custom color replaces every color, inline codes included.
local function styledAt(panel, content, x, y, width, style, color, align)
    if style.caps then content = capitalize(content) end
    if style.color then
        content, color = uncolored(content), style.color
    elseif panel.parchment then
        content, color = inkText(content), inkColor(color)
    end
    local height = textAt(panel, content, x, y, width, style.size, color, style.font, align,
        style.flags)
    if panel.hits and style.key then
        panel.hits[#panel.hits + 1] = { key = style.key, region = panel.pool[panel.used] }
    end
    return height
end

-- Text the game hides (a secret value), shown but never read or measured: one
-- line at the width given, its height left by the caller. It gets font strings
-- of its own, as one that showed a secret can keep reporting its size hidden.
local function hiddenTextAt(panel, content, x, y, width, style, color)
    style = asStyle(style)
    panel.hiddenPool = panel.hiddenPool or {}
    panel.hiddenUsed = (panel.hiddenUsed or 0) + 1
    local font = panel.hiddenPool[panel.hiddenUsed]
    if not font then
        font = roundLayout(panel:CreateFontString(nil, "OVERLAY"))
        font:SetJustifyV("TOP")
        font:SetJustifyH("LEFT")
        font:SetShadowColor(0, 0, 0, 0)
        font:SetShadowOffset(0, 0)
        if font.SetWordWrap then font:SetWordWrap(false) end
        if font.SetMaxLines then font:SetMaxLines(1) end
        panel.hiddenPool[panel.hiddenUsed] = font
    end
    color = style.color or (panel.parchment and inkColor(color)) or color
    font:ClearAllPoints()
    font:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    font:SetWidth(width)
    setFont(font, style.font or bodyFont(), style.size, style.flags)
    font:SetTextColor(color[1], color[2], color[3])
    if not pcall(font.SetText, font, content) then
        font:Hide()
        return 0
    end
    font:Show()
    return style.size + 2
end

local function textWidth(font, text)
    font:SetText(text)
    return (font.GetUnboundedStringWidth and font:GetUnboundedStringWidth() or font:GetStringWidth()) or 0
end

-- Some clients leave inline textures out of a string's width; asked once.
local texturesCounted
local function measure(panel, text, size, fontPath, flags)
    local font = panel.measure
    setFont(font, fontPath or bodyFont(), size, flags)
    if texturesCounted == nil then
        texturesCounted = textWidth(font, "|TInterface\\Icons\\INV_Misc_QuestionMark:12|t") > 6
    end
    local width = textWidth(font, text)
    if texturesCounted then return width end
    local _, textures = text:gsub("|T", "")
    return width + textures * (size + 2)
end

local function measureStyled(panel, text, style)
    if style.caps then text = capitalize(text) end
    return measure(panel, text, style.size, style.font, style.flags)
end

-- MedalUI's key lines (its quest tooltips' clicks, "Shift + (mouse) Link"),
-- two cells to a row: rows with its mouse glyph in them, as a grid, the
-- second column starting where the widest first cell ends. keyGrid marks a
-- list's key rows with their columns (grid); drawRow and rowWidth follow it.
local function isKeyRow(row)
    if row.blank then return false end
    local mark = "strips\\mouse-"
    return ((row.left or ""):find(mark, 1, true) or (row.right or ""):find(mark, 1, true)) and true or false
end

-- a cell as its modifier ("Shift + ") and the rest (the glyph and its word)
local function keySplit(cell)
    local mod, rest = (cell or ""):match("^(.-)(|T.*)$")
    if not rest then return "", cell or "" end
    return mod, rest
end

-- Each column is two: the modifiers, set right against the glyphs, then the
-- glyphs with their words, so every glyph of a column stands in one line.
-- row.grid = { first column's modifiers' width, where the second column
-- starts, its modifiers' width }.
local function keyGrid(panel, rows, style)
    style = asStyle(style)
    local modL, restL, modR, any = 0, 0, 0, false
    for _, row in ipairs(rows) do
        if isKeyRow(row) then
            any = true
            local m, r = keySplit(row.left)
            modL = math.max(modL, measureStyled(panel, m, style))
            restL = math.max(restL, measureStyled(panel, r, style))
            modR = math.max(modR, measureStyled(panel, (keySplit(row.right)), style))
        end
    end
    if not any then return end
    for _, row in ipairs(rows) do
        if isKeyRow(row) then
            row.grid = { modL, modL + restL + 2 * COLUMN_GAP, modR }
        end
    end
end

-- one cell of the grid at x: its modifier right against the glyph, then the rest
local function keyCellAt(panel, cell, x, y, modWidth, width, style, color)
    local mod, rest = keySplit(cell)
    local height = 0
    if mod ~= "" then
        height = styledAt(panel, mod, x, y, modWidth, style, color, "RIGHT")
    end
    if rest ~= "" then
        height = math.max(height, styledAt(panel, rest, x + modWidth, y, math.max(1, width - modWidth), style, color))
    end
    return height
end

-- A list of stats as two columns: each value, in its own color, set right
-- in a column as wide as the widest, then its name; a stat marker before it
-- stays at the left. Marks rows whose text starts with its value: row.statColumn =
-- { marker, value, rest, where the value's column starts, its width }. A list
-- with any row that does not, as in Korean with the name first, is left as
-- the game prints it.
local VALUE_FIRST = "^(|T.-|t%s*)(|c%x%x%x%x%x%x%x%x[%+%-]?[%d%.,]+%%?|r)(%s.+)$"
local VALUE_ONLY = "^()(|c%x%x%x%x%x%x%x%x[%+%-]?[%d%.,]+%%?|r)(%s.+)$"

local function valueGrid(panel, rows, style)
    style = asStyle(style)
    local markerWidth, widest, parts = 0, 0, {}
    for index, row in ipairs(rows) do
        local left = row.left or ""
        local marker, value, rest = left:match(VALUE_FIRST)
        if not marker then
            _, value, rest = left:match(VALUE_ONLY)
            marker = ""
        end
        if not value or (row.right and row.right ~= "") then
            for _, other in ipairs(rows) do other.statColumn = nil end
            return
        end
        parts[index] = { marker, value, rest }
        if marker ~= "" then markerWidth = math.max(markerWidth, measureStyled(panel, marker, style)) end
        widest = math.max(widest, measureStyled(panel, value, style))
    end
    for index, row in ipairs(rows) do
        local part = parts[index]
        row.statColumn = { part[1], part[2], part[3], math.ceil(markerWidth), math.ceil(widest) }
    end
end

local function rowWidth(panel, row, style)
    if row.blank then return 0 end
    style = asStyle(style)
    if row.statColumn then return row.statColumn[4] + row.statColumn[5] + measureStyled(panel, row.statColumn[3], style) + 2 end
    if row.grid then
        local _, rest = keySplit(row.right)
        return row.grid[2] + row.grid[3] + measureStyled(panel, rest, style) + 2
    end
    local width = measureStyled(panel, row.left, style)
    if row.right and row.right ~= "" then
        -- The 2 matches the slack drawRow gives the right column.
        return width + COLUMN_GAP + measureStyled(panel, row.right, style) + 2
    end
    return width
end

local function headerInsets(indent)
    if ns.option("iconRight") then return 0, indent end
    return indent, 0
end

local function drawRow(panel, row, y, style, color, indent, gap, rightIndent)
    style = asStyle(style)
    local left = row.left
    local right = row.right
    local leftColor = row.color or color
    indent, gap, rightIndent = indent or 0, gap or 3, rightIndent or 0
    -- What the row leaves under its letters, its line's leading and the gap:
    -- a divider or rule after it counts this in (Panel/Render.lua).
    local lineHeight = math.floor(style.size * 1.15 + .5)
    panel.rowTail = lineHeight - style.size + gap
    -- A blank row, as another addon's between its sections: one empty line.
    if row.blank then return y + lineHeight + gap end
    local w = panel.width - 2 * pad() - indent - rightIndent
    if row.statColumn then
        local marker, value, rest, markerWidth, column = unpack(row.statColumn)
        local x = pad() + indent
        local height = 0
        if marker ~= "" then height = styledAt(panel, marker, x, y, markerWidth + 1, style, leftColor) end
        height = math.max(height, styledAt(panel, value, x + markerWidth, y, column + 1, style, leftColor, "RIGHT"))
        local after = x + markerWidth + column
        height = math.max(height, styledAt(panel, rest, after, y, math.max(1, x + w - after), style, leftColor))
        return y + height + gap
    end
    if row.grid then
        -- a key row: both cells from the left, the second at the grid's column
        local x, grid = pad() + indent, row.grid
        local leftHeight = keyCellAt(panel, left, x, y, grid[1], grid[2], style, leftColor)
        local rightHeight = keyCellAt(panel, right, x + grid[2], y, grid[3],
            math.max(1, w - grid[2]), style, row.rightColor or leftColor)
        return y + math.max(leftHeight, rightHeight) + gap
    end
    if right and right ~= "" then
        local rightWidth = math.min(measureStyled(panel, right, style) + 2,
            math.max(w * .5, w - measureStyled(panel, left, style) - COLUMN_GAP))
        local leftHeight = styledAt(panel, left, pad() + indent, y,
            w - rightWidth - COLUMN_GAP, style, leftColor)
        local rightHeight = styledAt(panel, right, panel.width - pad() - rightIndent - rightWidth, y,
            rightWidth, style, row.rightColor or leftColor, "RIGHT")
        return y + math.max(leftHeight, rightHeight) + gap
    end
    return y + styledAt(panel, left, pad() + indent, y, w, style, leftColor) + gap
end

local function acquireTexture(panel, path, sublevel)
    panel.texturesUsed = panel.texturesUsed + 1
    local tex = panel.texturePool[panel.texturesUsed]
    if not tex then
        tex = roundLayout(panel:CreateTexture(nil, "OVERLAY"))
        panel.texturePool[panel.texturesUsed] = tex
    end
    tex:SetDrawLayer("OVERLAY", sublevel or 0)
    tex:SetTexture(path or WHITE)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

local function lighter(c, k) return c + (1 - c) * k end

-- The bars' shared options: the style, the height (whole, well included),
-- and the inset of the fill from the bar's edge.
local TRACK = { .16, .14, .13 }
local function barStyle()
    return ns.option("barStyle") == "plain" and "plain" or "well"
end
local function barHeight()
    return math.max(4, math.min(16, tonumber(ns.option("barHeight")) or 8))
end
local function barInset(panel)
    return barStyle() == "well" and pixel(panel) or 0
end

-- A bar, as the options say: in a sunken well (a strong line around ink, the
-- fill lit from above with a bright tip), or plain (a flat track, a flat fill).
-- Its height defaults to the shared one. Returns its setter: set(ratio, color),
-- ratio 0 to 1.
local function drawBar(panel, x, y, width, height)
    local px, plain = pixel(panel), barStyle() == "plain"
    width, height = snap(panel, width), snap(panel, height or barHeight())
    local inset = plain and 0 or px
    local well = acquireTexture(panel, nil, 0)
    well:SetPoint("TOPLEFT", panel, "TOPLEFT", snap(panel, x), -snap(panel, y))
    well:SetSize(width, height)
    if plain then
        well:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], 1)
    else
        well:SetVertexColor(LINE_STRONG[1], LINE_STRONG[2], LINE_STRONG[3], 1)
    end
    local inside = acquireTexture(panel, nil, 1)
    inside:SetPoint("TOPLEFT", well, "TOPLEFT", inset, -inset)
    inside:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -inset, inset)
    inside:SetVertexColor(INK[1], INK[2], INK[3], 1)
    inside:SetShown(not plain)
    local fill = acquireTexture(panel, nil, 2)
    fill:SetTexture(ns.barTexturePath(ns.option("barTexture")) or WHITE)
    fill:SetPoint("TOPLEFT", inside, "TOPLEFT")
    fill:SetPoint("BOTTOMLEFT", inside, "BOTTOMLEFT")
    local gloss = acquireTexture(panel, nil, 3)
    gloss:SetPoint("TOPLEFT", fill, "TOPLEFT")
    gloss:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    gloss:SetHeight(px)
    gloss:SetVertexColor(1, 1, 1, .25)
    local tip = acquireTexture(panel, nil, 3)
    tip:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    tip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    tip:SetWidth(px)
    tip:SetVertexColor(1, 1, 1, .35)
    local inner = width - 2 * inset
    return function(ratio, color)
        ratio = math.max(0, math.min(1, ratio or 0))
        local shown = ratio > 0
        fill:SetWidth(math.max(px, inner * ratio))
        local r, g, b = color[1], color[2], color[3]
        if plain then
            fill:SetVertexColor(r, g, b, 1)
        else
            fill:SetGradient("VERTICAL", CreateColor(r * .7, g * .7, b * .7, 1),
                CreateColor(lighter(r, .25), lighter(g, .25), lighter(b, .25), 1))
        end
        fill:SetShown(shown)
        gloss:SetShown(shown and not plain)
        tip:SetShown(shown and not plain)
    end
end

-- before is the gap above a separator; a hidden one takes its gap with it.
local function rule(panel, y, color, before)
    if not ns.option("separators") then return y end
    if panel.parchment then color = inkColor(color) end
    y = y + (before or 0)
    local line = acquireTexture(panel)
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -snap(panel, y))
    line:SetSize(panel.width - 2 * pad(), pixel(panel))
    line:SetVertexColor(color[1], color[2], color[3], .45)
    return y + 9
end

local function divider(panel, y, color, before)
    if not ns.option("separators") then return y end
    if panel.parchment then color = inkColor(color) end
    y = y + (before or 0)
    -- One gold line, fading in over its first fifth and out over its last.
    local px, inner, top = pixel(panel), panel.width - 2 * pad(), -snap(panel, y + 5)
    local ramp = snap(panel, inner * .18)
    local r, g, b = color[1], color[2], color[3]
    local left = acquireTexture(panel)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), top)
    left:SetSize(ramp, px)
    left:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, .8))
    local right = acquireTexture(panel)
    right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad(), top)
    right:SetSize(ramp, px)
    right:SetGradient("HORIZONTAL", CreateColor(r, g, b, .8), CreateColor(r, g, b, 0))
    local middle = acquireTexture(panel)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    middle:SetHeight(px)
    middle:SetVertexColor(r, g, b, .8)
    return y + 18
end

-- A section's name centered between two rules.
local function caption(panel, y, text, style, color)
    y = y + 4
    local width = measureStyled(panel, text, style) + 2
    styledAt(panel, text, (panel.width - width) / 2, y, width, style, color or colors.caption, "CENTER")
    if ns.option("separators") then
        local side = (panel.width - 2 * pad() - width) / 2 - 8
        local middle = y + math.floor(style.size / 2) + 1
        for _, point in ipairs({ { "TOPLEFT", pad() }, { "TOPRIGHT", -pad() } }) do
            local line = acquireTexture(panel)
            line:SetPoint(point[1], panel, point[1], point[2], -snap(panel, middle))
            line:SetSize(snap(panel, side), pixel(panel))
            line:SetVertexColor(GOLD_RULE[1] * .52, GOLD_RULE[2] * .52, GOLD_RULE[3] * .52, .8)
        end
    end
    return y + style.size + 9
end

-- (2026-11-22) A section's name on a band of its colour: the panel's inner
-- width, fading from left to right, a bar at its left edge, the name left in
-- it. Without separators, the name alone. A custom color is the name's and
-- the band's.
local BAND_BAR, BAND_INSET, BAND_PAD = 3, 8, 4
local function band(panel, y, text, style, color, before)
    y = y + (before or 0)
    color = style.color or color or colors.caption
    local tint = panel.parchment and inkColor(color) or color
    local height = style.size + 2 * BAND_PAD
    -- the band reaches a little into the padding, so the name lines up
    -- with the rows under it
    local left = math.max(2, pad() - BAND_INSET)
    if ns.option("separators") then
        local width = panel.width - 2 * left
        -- under the name's font string, which shares the OVERLAY layer
        local fill = acquireTexture(panel)
        fill:SetDrawLayer("ARTWORK", 6)
        fill:SetPoint("TOPLEFT", panel, "TOPLEFT", snap(panel, left), -snap(panel, y))
        fill:SetSize(snap(panel, width), snap(panel, height))
        local r, g, b = tint[1], tint[2], tint[3]
        fill:SetGradient("HORIZONTAL", CreateColor(r, g, b, .22), CreateColor(r, g, b, .04))
        local bar = acquireTexture(panel)
        bar:SetDrawLayer("ARTWORK", 7)
        bar:SetPoint("TOPLEFT", fill, "TOPLEFT")
        bar:SetSize(snap(panel, BAND_BAR), snap(panel, height))
        bar:SetVertexColor(r, g, b, 1)
    end
    local width = measureStyled(panel, text, style) + 2
    styledAt(panel, text, pad(), y + BAND_PAD, width, style, color)
    return y + height + 7
end

local function drawGroup(panel, list, y, style, color, indent, gap, rightIndent)
    for _, row in ipairs(list) do
        y = drawRow(panel, row, y, style, color, indent, gap, rightIndent)
    end
    return y
end

-- The chat-link tooltip's close button is a child of the hidden tooltip, so
-- the panel draws its own and clicks the game's.
local function nativeCloseButton(tooltip)
    local button = tooltip.CloseButton
    if not button and tooltip == ItemRefTooltip then button = _G.ItemRefCloseButton end
    return button
end

local function getCloseButton(panel, tooltip)
    if panel.close then return panel.close end
    local close = roundLayout(CreateFrame("Button", nil, panel))
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    local lines = {}
    for index, angle in ipairs({ 45, -45 }) do
        local line = roundLayout(close:CreateTexture(nil, "ARTWORK"))
        line:SetTexture(WHITE)
        line:SetSize(11, 1.5)
        line:SetPoint("CENTER")
        if line.SetRotation then line:SetRotation(math.rad(angle)) end
        lines[index] = line
    end
    local function tint(r, g, b, a)
        for _, line in ipairs(lines) do line:SetVertexColor(r, g, b, a) end
    end
    tint(.78, .72, .63, .8)
    close:SetScript("OnEnter", function() tint(1, .92, .78, 1) end)
    close:SetScript("OnLeave", function() tint(.78, .72, .63, .8) end)
    close:SetScript("OnClick", function()
        local native = nativeCloseButton(tooltip)
        if native then native:Click() else tooltip:Hide() end
    end)
    panel.close = close
    return close
end

local EQUIPPED_TAG_GAP = 2
local function getEquippedTag(panel)
    if panel.equipped then return panel.equipped end
    local tag = roundLayout(CreateFrame("Frame", nil, panel))
    tag:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, EQUIPPED_TAG_GAP)
    tag:SetHeight(BADGE_HEIGHT)
    tag.border = roundLayout(tag:CreateTexture(nil, "BACKGROUND"))
    tag.border:SetAllPoints()
    tag.border:SetTexture(WHITE)
    tag.border:SetVertexColor(.55, .45, .30, .9)
    tag.fill = roundLayout(tag:CreateTexture(nil, "BORDER"))
    tag.fill:SetPoint("TOPLEFT", 1, -1)
    tag.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    tag.fill:SetTexture(WHITE)
    tag.fill:SetVertexColor(.07, .055, .05, 1)
    tag.text = roundLayout(tag:CreateFontString(nil, "OVERLAY"))
    tag.text:SetFont(bodyFont(), 10)
    tag.text:SetTextColor(.93, .80, .52)
    tag.text:SetPoint("CENTER")
    panel.equipped = tag
    return tag
end

-- The comparison label sits outside the body. Include its visible bounds in
-- frame clamping and column width without changing the body's layout size.
local function clampInsets(panel)
    local tag = panel.equipped
    if not (tag and tag:IsShown()) then return 0, 0, 0, 0 end
    return 0, math.max(0, tag:GetWidth() - panel:GetWidth()), tag:GetHeight() + EQUIPPED_TAG_GAP, 0
end

-- Returns the header height the icon and badge need.
local function drawChrome(panel, tooltip, style)
    applyBackdrop(panel, style)
    local px = pixel(panel)
    local mode = panel.backdropMode
    local gilded, slate = mode == "gilded", mode == "slate"
    footerBand(panel, nil)
    panel.edges[1]:SetHeight((gilded or slate) and px or 2 * px)
    panel.edges[2]:SetHeight(px)
    panel.edges[3]:SetWidth(px)
    panel.edges[4]:SetWidth(px)
    panel.badgeFill:ClearAllPoints()
    panel.badgeFill:SetPoint("TOPLEFT", panel.badge, "TOPLEFT", px, -px)
    panel.badgeFill:SetPoint("BOTTOMRIGHT", panel.badge, "BOTTOMRIGHT", -px, px)
    -- Panels are shared across tooltip types; the one that wants a watermark shows it.
    if panel.watermark then panel.watermark:Hide() end
    local color = style.color
    panel:SetFrameLevel(tooltip:GetFrameLevel() + 5)
    local tinted = style.tint and ns.option("qualityTint")
    local tint = tinted and style.tint or { .5, .5, .5 }
    local strength = tinted and (style.strength or 1) or 0
    local suffix = ns.TYPE_SUFFIX[style.tooltipType] or ""
    local body = ns.option("backdropAlpha" .. suffix) or ns.BACKDROP_ALPHA
    local glow = ns.option("glowAlpha" .. suffix) or 1
    if panel.parchment then
        panel.background:SetVertexColor(1, 1, 1, body)
    elseif panel.textured then
        panel.background:SetVertexColor(1 - .45 * strength + .45 * strength * tint[1],
            1 - .45 * strength + .45 * strength * tint[2],
            1 - .45 * strength + .45 * strength * tint[3], body)
        panel.glow:SetVertexColor(tint[1], tint[2], tint[3], .35 * strength * body)
        panel.glow:SetShown(strength > 0)
    elseif gilded then
        -- Warm ink, lighter under the header; the tint is the header's glow.
        panel.background:SetGradient("VERTICAL", CreateColor(.059, .055, .047, body),
            CreateColor(.110, .098, .082, body))
    elseif slate then
        -- Flat ink; the tint washes down from the top.
        local base = { .082, .078, .071 }
        panel.background:SetGradient("VERTICAL", CreateColor(base[1], base[2], base[3], body),
            CreateColor(base[1], base[2], base[3], body))
        local function toward(index) return base[index] + (tint[index] * .16 - base[index]) * strength end
        panel.wash:SetGradient("VERTICAL", CreateColor(base[1], base[2], base[3], body),
            CreateColor(toward(1), toward(2), toward(3), body))
    else
        panel.background:SetGradient("VERTICAL",
            CreateColor(.016 + tint[1] * .02 * strength, .012 + tint[2] * .02 * strength,
                .016 + tint[3] * .02 * strength, body),
            CreateColor(.052 + tint[1] * .06 * strength, .040 + tint[2] * .06 * strength,
                .050 + tint[3] * .06 * strength, body))
    end
    local gradient = style.gradient
    if slate then
        panel.halo:SetVertexColor(0, 0, 0, .5 * glow)
    elseif gilded and strength > 0 and gradient then
        local left, right, alpha = gradient[1], gradient[2], .3 * strength * glow
        panel.halo:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], alpha),
            CreateColor(right[1], right[2], right[3], alpha))
    elseif gilded and strength > 0 then
        panel.halo:SetVertexColor(tint[1], tint[2], tint[3], .3 * strength * glow)
    elseif strength > 0 and gradient then
        local left, right, alpha = gradient[1], gradient[2], .55 * strength * glow
        panel.halo:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], alpha),
            CreateColor(right[1], right[2], right[3], alpha))
    elseif strength > 0 then
        panel.halo:SetVertexColor(tint[1], tint[2], tint[3], .55 * strength * glow)
    else
        panel.halo:SetVertexColor(.6, .6, .6, .18 * glow)
    end
    local headerAlpha = panel.textured and HEADER_ALPHA_TEXTURED or HEADER_ALPHA_PLAIN
    local bottomAlpha = ns.headerAlpha(style.tooltipType, "Bottom") or headerAlpha
    local topAlpha = ns.headerAlpha(style.tooltipType, "Top") or headerAlpha
    if gilded then
        -- The tint's glow from the top left, as strong as the header's top is set.
        local glowColor = gradient and gradient[1] or tint
        panel.header:SetVertexColor(glowColor[1], glowColor[2], glowColor[3],
            .34 * strength * topAlpha / HEADER_ALPHA_PLAIN)
        panel.headerRule:SetVertexColor(GOLD_DARK[1], GOLD_DARK[2], GOLD_DARK[3], .55)
        panel.headerRule:SetHeight(px)
        panel.headerShadow:SetVertexColor(0, 0, 0, .6)
        panel.headerShadow:SetHeight(px)
    elseif gradient then
        local left, right, alpha = gradient[1], gradient[2], (bottomAlpha + topAlpha) / 2
        panel.header:SetGradient("HORIZONTAL", CreateColor(left[1] * .25, left[2] * .25, left[3] * .25, alpha),
            CreateColor(right[1] * .25, right[2] * .25, right[3] * .25, alpha))
    else
        panel.header:SetGradient("VERTICAL",
            CreateColor(color[1] * .12, color[2] * .12, color[3] * .12, bottomAlpha),
            CreateColor(color[1] * .38, color[2] * .38, color[3] * .38, topAlpha))
    end
    if gilded then
        -- Gold on the edge; ink, then the tint, outside it; a highlight and ink inside.
        colorLines(panel.edges, GOLD_DARK, 1)
        placeLines(panel, panel.outerInk, 1, px)
        colorLines(panel.outerInk, INK, 1)
        placeLines(panel, panel.outerTint, 2, px)
        local ring = strength > 0 and tint or GOLD_DARK
        colorLines(panel.outerTint, ring, strength > 0 and .28 * strength or .2)
        placeLines(panel, panel.innerLines, -1, px)
        colorLines(panel.innerLines, INK, .6)
    end
    if gilded or slate then
        panel.innerTop:ClearAllPoints()
        panel.innerTop:SetPoint("TOPLEFT", panel, "TOPLEFT", px, -px)
        panel.innerTop:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -px, -px)
        panel.innerTop:SetHeight(px)
        panel.innerTop:SetVertexColor(gilded and .95 or 1, gilded and .92 or 1, gilded and .82 or 1,
            gilded and .10 or .05)
        panel.innerTop:SetDrawLayer("BORDER", 5)
    end
    for index, edge in ipairs(gilded and {} or panel.edges) do
        local edgeStrength = slate and .9 or index == 1 and .8 or .36
        local edgeColor = gradient and (index == 3 and gradient[1] or index == 4 and gradient[2]) or color
        if gradient and index <= 2 then
            local left, right = gradient[1], gradient[2]
            edge:SetGradient("HORIZONTAL",
                CreateColor(left[1] * edgeStrength, left[2] * edgeStrength, left[3] * edgeStrength, .95),
                CreateColor(right[1] * edgeStrength, right[2] * edgeStrength, right[3] * edgeStrength, .95))
        else
            edge:SetVertexColor(edgeColor[1] * edgeStrength, edgeColor[2] * edgeStrength,
                edgeColor[3] * edgeStrength, slate and .45 or .95)
        end
    end
    if panel.backdropMode == "native" then
        panel.nativeBorder:SetFrameLevel(panel:GetFrameLevel() + 1)
        colorNativeBorder(panel.nativeBorder, style.tint, style.tint and gradient)
    end
    local iconColor = gradient and (ns.option("iconRight") and gradient[2] or gradient[1]) or color
    panel.iconBorder:SetVertexColor(iconColor[1], iconColor[2], iconColor[3], .85)
    local native = nativeCloseButton(tooltip)
    if native and native:IsShown() then
        getCloseButton(panel, tooltip):Show()
    elseif panel.close then
        panel.close:Hide()
    end
    if style.tag then
        local tag = getEquippedTag(panel)
        tag.text:SetText(style.tag)
        tag:SetWidth(tag.text:GetStringWidth() + 16)
        tag:Show()
    elseif panel.equipped then
        panel.equipped:Hide()
    end
    local iconSize = snap(panel, style.iconSize or ICON_SIZE)
    panel.icon:SetSize(iconSize, iconSize)
    panel.icon:ClearAllPoints()
    if ns.option("iconRight") then
        panel.icon:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad(), -titleTop())
    else
        panel.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -titleTop())
    end
    panel.iconBorder:SetSize(iconSize + 2 * px, iconSize + 2 * px)
    panel.iconGap:SetSize(iconSize + 4 * px, iconSize + 4 * px)
    panel.iconGap:SetVertexColor(INK[1], INK[2], INK[3], 1)
    panel.iconRing:SetSize(iconSize + 6 * px, iconSize + 6 * px)
    panel.iconRing:SetVertexColor(GOLD_DARK[1], GOLD_DARK[2], GOLD_DARK[3], 1)
    -- Icons carry their own dark frame in the outer texels; cropping it lets
    -- the art meet the panel's colored border directly.
    panel.icon:SetTexCoord(.08, .92, .08, .92)
    if style.icon then
        panel.icon:SetTexture(style.icon)
        panel.icon:Show()
        panel.iconBorder:Show()
    else
        panel.icon:Hide()
        panel.iconBorder:Hide()
    end
    panel.iconGap:SetShown(style.icon ~= nil)
    panel.iconRing:SetShown(style.icon ~= nil)
    local headerMin = style.icon and titleTop() + iconSize + 12 or 0
    if style.badge then
        local badge = panel.badge
        local text = styleOf("badge")
        -- The plate takes the panel's accent unless given its own color.
        local plate = style.badgeColor or color
        local textColor = text.color or { plate[1] * .45 + .55, plate[2] * .45 + .55,
            plate[3] * .45 + .55 }
        setFont(panel.badgeText, text.font, text.size, text.flags)
        panel.badgeText:SetTextColor(textColor[1], textColor[2], textColor[3])
        panel.badgeText:SetText(style.badge)
        local height = math.max(BADGE_HEIGHT, text.size + 6)
        badge:SetSize(snap(panel, math.max(iconSize + 2 * px, panel.badgeText:GetStringWidth() + 10)), snap(panel, height))
        -- A dark gold plate, lit from above; the number keeps the plate's color.
        badge:SetVertexColor(GOLD_DARK[1], GOLD_DARK[2], GOLD_DARK[3], 1)
        panel.badgeFill:SetGradient("VERTICAL", CreateColor(.071, .063, .051, 1), CreateColor(.145, .129, .106, 1))
        badge:Show()
        panel.badgeFill:Show()
        panel.badgeText:Show()
        if panel.hits then panel.hits[#panel.hits + 1] = { key = "badge", region = badge } end
        headerMin = titleTop() + iconSize + BADGE_GAP + height + 10
    else
        panel.badge:Hide()
        panel.badgeFill:Hide()
        panel.badgeText:Hide()
    end
    return headerMin
end
drawChrome = probe("chrome", drawChrome)

-- Preview panels belong to the editor's anchor. Live panels are positioned
-- by the single Pretty placement backend, independently of native dimensions.
local function alignPanel(panel, tooltip, force)
    if panel.parked then return end
    if panel.isPreview then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, 0)
    else
        return ns.Placement.align(panel, tooltip, force)
    end
end
alignPanel = probe("align panel", alignPanel)

-- Keep a visible panel still while cursor following restores native anchors.
local function pinPanel(panel)
    local left, top = util.number(panel:GetLeft()), util.number(panel:GetTop())
    if not (left and top) then return false end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    return true
end

-- bottom: the room under the last row; the padding less 2 unless given.
local function finishPanel(panel, tooltip, y, bottom)
    panel:SetHeight(snap(panel, y + (bottom or pad() - 2)))
    alignPanel(panel, tooltip)
    panel:Show()
end

-- Each tooltip data type the panel draws: read(tooltip, data, game) -> model,
-- render(panel, tooltip, model), key(tooltip, data) naming what is shown,
-- option, the setting that turns the tooltip type on, and optionally
-- details(model, context), the detail rows the game's own tooltip gets in its
-- place (context passed on to ns.showsDetail), with detailKeys, the settings
-- that turn them on.
local TooltipTypes = {}

-- Records a tooltip type, its reader and renderer profiled; the entry file
-- installs the hooks that use it.
local function defineTooltipType(dataType, tooltipType)
    tooltipType.read = probe("read " .. dataType, tooltipType.read)
    tooltipType.render = probe("render " .. dataType, tooltipType.render)
    TooltipTypes[dataType] = tooltipType
end

-- The editor's sample, drawn inside anchor; hits record where each part landed.
local function renderPreview(anchor, model, dataType)
    local panel = anchor.prettyTooltipPreview
    if not panel then
        panel = createPanel(anchor)
        panel:SetFrameStrata(anchor:GetFrameStrata())
        panel:SetClampedToScreen(false)
        -- What a tooltip type draws from the game, the editor's samples stand in for.
        panel.isPreview = true
        anchor.prettyTooltipPreview = panel
    end
    panel.hits = {}
    TooltipTypes[dataType or ITEM].render(panel, anchor, model)
    return panel
end

local function defaultHeaderAlpha()
    if backdropStyle() == "dialogue" then return HEADER_ALPHA_TEXTURED end
    return HEADER_ALPHA_PLAIN
end

-- Each tooltip type's reader and renderer, by the game's tooltip data type.
ns.TooltipTypes = TooltipTypes

ns.ui = {
    COLUMN_GAP = COLUMN_GAP,
    ICON_SIZE = ICON_SIZE,
    probe = probe,
    bodyFont = bodyFont,
    isComparison = isComparison,
    defineTooltipType = defineTooltipType,
    panels = panels,
    getPanel = getPanel,
    perf = perf,
    tally = tally,
    timed = timed,
    renderPreview = renderPreview,
    defaultHeaderAlpha = defaultHeaderAlpha,
    styleOf = styleOf,
    alignPanel = alignPanel,
    pinPanel = pinPanel,
    shownPanel = function(tooltip)
        local panel = panels[tooltip]
        if panel and panel:IsShown() then return panel end
    end,
    styledAt = styledAt,
    inkColor = inkColor,
    hiddenTextAt = hiddenTextAt,
    measureStyled = measureStyled,
    enchantRows = enchantRows,
    formatMoney = formatMoney,
    setFont = setFont,
    FLAVOR_GOLD = FLAVOR_GOLD,
    clearPool = clearPool,
    rowWidth = rowWidth,
    keyGrid = keyGrid,
    drawRow = drawRow,
    drawGroup = drawGroup,
    headerInsets = headerInsets,
    acquireTexture = acquireTexture,
    rule = rule,
    divider = divider,
    drawBar = drawBar,
    barHeight = barHeight,
    barInset = barInset,
    footerBand = footerBand,
    valueGrid = valueGrid,
    INK = INK,
    GOLD_DARK = GOLD_DARK,
    LINE_STRONG = LINE_STRONG,
    drawChrome = drawChrome,
    clampInsets = clampInsets,
    finishPanel = finishPanel,
    caption = caption,
    band = band,
    isKeyRow = isKeyRow,
    pad = pad,
    pixel = pixel,
    snap = snap,
    titleTop = titleTop,
    minWidth = minWidth,
    MAX_WIDTH = MAX_WIDTH,
    PROSE_WIDTH = PROSE_WIDTH,
    EXTRA_COLOR = EXTRA_COLOR,
    GOLD_RULE = GOLD_RULE,
}
