-- Draws a view: a plain table that says what a panel shows, which a tooltip
-- type's view function builds from its model. The width is fitted to what the
-- view holds, so measuring and drawing cannot disagree. Only what several
-- types share lives here; a part one type draws its own way is a custom
-- section in that type's file.
--
-- view = {
--     tooltipType = "aura",              backdrop and header settings by type
--     color, tint, strength,             the accent; the header's tint and its strength
--     gradient = { left, right },        a dual school's accent, drawn across
--     icon, iconSize,                    header lines start beside the icon
--     portrait = "mouseover",            a unit whose portrait fills the icon
--     badge, badgeColor,                 the level plate under the icon
--     header = {                         in order, beside the icon
--         { text = "Name", style = styles.auraName, color = TITLE, gap = 4 },
--         { badges = { { "Buff", BLUE } }, style = styles.auraBadges, before = 1, gap = 4 },
--         { rows = { { left, right } }, style, color, gap = 3 },
--     },
--     tag = "EQUIPPED",                  the comparison's label above the panel
--     sections = {                       in order, below the header
--         { separator = { divider = GOLD } | { rule = color } | { space = 4 }  before = 8 sets the space
--               above a divider or rule; left out, it shows as much as below
--               | { caption = "Reagents", style, before = 4 },
--               | { band = "Where", style, color, before = 8 }, a heading on
--               a band of its colour (the quest's sections)
--           kind = "prose", sentences = { ... }, style, color, numbers = "FFF6E4", gap = 5 },
--         { kind = "rows", rows = { { left, right, color, rightColor, indent } }, style, color, gap = 2,
--           wrap = true },             rows with nothing on the right wrap at prose width
--         { kind = "custom", draw = function(panel, y) return y end,
--           measure = function(panel) return width end },    measure is optional
--     },
--     footer = { rows = { ... }, style, color, gap = 4 },    the dark band at the bottom
--           or { draw = function(panel, y) return y end, measure = function(panel) return width end },
--     minWidth = 0,                      narrower than panels usually are, to fit the content
-- }
local _, medal = ...
local ns = medal.tips
local ui = ns.ui
if not ui then return end

local util = ns.util
local pad = ui.pad

-- Badges -----------------------------------------------------------------------

-- Badges are small boxed chips in a row: each word in capitals, lightened
-- from its badge's color, on a box of that color. The words are two sizes
-- under the style's, as capitals read larger.
local CHIP_PAD, CHIP_GAP, CHIP_ROW_GAP = 6, 4, 3

local function chipStyle(style)
    local chip = {}
    for field, value in pairs(style) do chip[field] = value end
    chip.size = math.max(8, (style.size or 12) - 2)
    return chip
end

-- (2026-11-22) A chip may lead with a glyph (badge[3], a file in art\ named
-- glyph-<name>), tinted as its word; its word may then be empty. A chip
-- with keepCase keeps its word as written ("LvL 38"), not in capitals.
local function chipText(badge)
    local text = badge[1] or ""
    return badge.keepCase and text or util.upper(text)
end
-- (and not in capitals where the player turned them on for the badges)
local function caseStyle(badge, style)
    if not (badge.keepCase and style.caps) then return style end
    local own = {}
    for field, value in pairs(style) do own[field] = value end
    own.caps = false
    return own
end
local GLYPHS = "Interface\\AddOns\\MedalUI\\media\\tooltips\\glyph-"
local GLYPH_GAP = 3
local function glyphSize(style) return style.size + 1 end

local function chipWidth(panel, badge, style)
    local text = badge[1] or ""
    local width = text ~= "" and ui.measureStyled(panel, chipText(badge), caseStyle(badge, style)) or 0
    if badge[3] then width = width + glyphSize(style) + (text ~= "" and GLYPH_GAP or 0) end
    return width + 2 * CHIP_PAD
end

local function badgesWidth(panel, list, style)
    style = chipStyle(style)
    local width = 0
    for index, badge in ipairs(list) do
        width = width + chipWidth(panel, badge, style) + (index > 1 and CHIP_GAP or 0)
    end
    return width
end

local function mixed(color, k, base)
    return { color[1] * k + base * (1 - k), color[2] * k + base * (1 - k), color[3] * k + base * (1 - k) }
end

-- The chips from x, wrapping where the panel ends; returns the y under them.
local function drawBadges(panel, list, x, y, style)
    style = chipStyle(style)
    local height = ui.snap(panel, style.size + 6)
    local px, left, limit = ui.pixel(panel), x, panel.width - pad()
    for _, badge in ipairs(list) do
        local color = badge[2] or ns.Palette.roles.detail
        local width = ui.snap(panel, chipWidth(panel, badge, style))
        if x > left and x + width > limit then
            x, y = left, y + height + CHIP_ROW_GAP
        end
        -- On DialogueUI's parchment, a pale box with a darker edge.
        local paper = panel.parchment
        local edge = paper and mixed(color, .5, .25) or mixed(color, .55, .08)
        local box = ui.acquireTexture(panel, nil, 0)
        box:SetPoint("TOPLEFT", panel, "TOPLEFT", ui.snap(panel, x), -ui.snap(panel, y))
        box:SetSize(width, height)
        box:SetVertexColor(edge[1], edge[2], edge[3], 1)
        local fill = paper and mixed(color, .12, .78) or mixed(color, .14, .07)
        local inside = ui.acquireTexture(panel, nil, 1)
        inside:SetPoint("TOPLEFT", box, "TOPLEFT", px, -px)
        inside:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -px, px)
        inside:SetVertexColor(fill[1], fill[2], fill[3], 1)
        local word = { color[1] + (1 - color[1]) * .35, color[2] + (1 - color[2]) * .35,
            color[3] + (1 - color[3]) * .35 }
        local text = badge[1] or ""
        if badge[3] then
            local size = glyphSize(style)
            local glyph = ui.acquireTexture(panel, GLYPHS .. badge[3], 2)
            glyph:SetPoint("TOPLEFT", panel, "TOPLEFT", ui.snap(panel, x + CHIP_PAD),
                -ui.snap(panel, y + (height - size) / 2))
            glyph:SetSize(ui.snap(panel, size), ui.snap(panel, size))
            -- on parchment, inked as the word is (unless a colour of the player's own)
            local tint = panel.parchment and not style.color and ui.inkColor(word) or style.color or word
            glyph:SetVertexColor(tint[1], tint[2], tint[3], 1)
            if text ~= "" then
                local skip = CHIP_PAD + size + GLYPH_GAP
                ui.styledAt(panel, chipText(badge), x + skip, y + 3, width - skip - CHIP_PAD + 1, caseStyle(badge, style),
                    word, "LEFT")
            end
        else
            ui.styledAt(panel, chipText(badge), x, y + 3, width, caseStyle(badge, style), word, "CENTER")
        end
        x = x + width + CHIP_GAP
    end
    return y + height
end

-- Live parts: updated ten times a second while their panel shows ---------------

-- Each shown panel's update, at most one; a redraw clears it.
local live = setmetatable({}, { __mode = "k" })

local ticker = CreateFrame("Frame")
local elapsedSince = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < .1 then return end
    elapsedSince = 0
    for panel, update in pairs(live) do
        if panel:IsShown() then update() else live[panel] = nil end
    end
end)

local function setLive(panel, update)
    live[panel] = update
end

-- A bar across the panel at y, in its sunken well (Panel/Layout.lua's
-- drawBar); returns its setter, set(ratio, color).
local function drawTrack(panel, y, height)
    return ui.drawBar(panel, pad(), y, panel.width - 2 * pad(), height)
end

-- Sections -------------------------------------------------------------------------

local FOOTER_TOP, FOOTER_BOTTOM = 9, 5

local function indentOf(view)
    return view.icon and view.iconSize + 10 or 0
end

-- The widest thing the view holds, plus the panel's padding, within the limits.
local function fitWidth(panel, view)
    local indent, need = indentOf(view), 0
    local function consider(width) if width > need then need = width end end
    for _, item in ipairs(view.header) do
        if item.text then
            consider(ui.measureStyled(panel, item.text, item.style) + indent)
        elseif item.badges and #item.badges > 0 then
            consider(badgesWidth(panel, item.badges, item.style) + indent)
        elseif item.rows then
            for _, row in ipairs(item.rows) do consider(ui.rowWidth(panel, row, item.style) + indent) end
        end
    end
    for _, section in ipairs(view.sections) do
        if section.kind == "prose" then
            for _, sentence in ipairs(section.sentences) do
                consider(math.min(ui.measureStyled(panel, sentence, section.style), ui.PROSE_WIDTH))
            end
        elseif section.kind == "custom" then
            if section.measure then consider(section.measure(panel)) end
        elseif section.kind == "rows" then
            ui.keyGrid(panel, section.rows, section.style)
            for _, row in ipairs(section.rows) do
                local width = ui.rowWidth(panel, row, section.style)
                if section.wrap and (not row.right or row.right == "") then width = math.min(width, ui.PROSE_WIDTH) end
                consider(width + (row.indent or 0))
            end
        end
    end
    local footer = view.footer
    if footer and footer.measure then consider(footer.measure(panel)) end
    if footer and footer.rows then ui.keyGrid(panel, footer.rows, footer.style) end
    for _, row in ipairs(footer and footer.rows or {}) do
        consider(ui.rowWidth(panel, row, footer.style))
    end
    return math.max(view.minWidth or ui.minWidth(), math.min(ui.MAX_WIDTH, math.ceil(need + 2 * pad())))
end

-- The space a divider shows below its line, and a rule: one after a section
-- shows as much above its line, counting in what the section's last row left
-- under its letters. A separator's own before overrides it.
local DIVIDER_SPACE, RULE_SPACE = 13, 9

local function drawSeparator(panel, y, separator, after)
    if not separator then return y end
    local before = separator.before
    if before == nil and after and panel.rowTail then
        -- A divider draws its line 5 below where it starts.
        before = separator.divider and DIVIDER_SPACE - 5 - panel.rowTail or RULE_SPACE - panel.rowTail
    end
    if separator.divider then return ui.divider(panel, y, separator.divider, before) end
    if separator.rule then return ui.rule(panel, y, separator.rule, before) end
    if separator.band then
        return ui.band(panel, y, separator.band, separator.style, separator.color, separator.before)
    end
    if separator.caption then
        return ui.caption(panel, y + (separator.before or 0), separator.caption, separator.style, separator.color)
    end
    return y + (separator.space or 0)
end

local DRAW = {
    prose = function(panel, y, section)
        for _, sentence in ipairs(section.sentences) do
            local text = section.numbers and util.colorNumbers(sentence, section.numbers) or sentence
            y = ui.drawRow(panel, { left = text }, y, section.style, section.color, 0, section.gap)
        end
        return y
    end,
    rows = function(panel, y, section)
        for _, row in ipairs(section.rows) do
            y = ui.drawRow(panel, row, y, section.style, section.color, row.indent or 0, section.gap)
        end
        return y
    end,
    custom = function(panel, y, section)
        return section.draw(panel, y)
    end,
}

-- The panel ---------------------------------------------------------------------

local function renderView(panel, tooltip, view)
    -- Whatever a tooltip type lent the panel goes back before anything is drawn.
    if panel.release then panel.release(panel) end
    local scale = ns.tooltipScale()
    if panel:GetScale() ~= scale then panel:SetScale(scale) end
    panel:Show()
    ui.clearPool(panel)
    live[panel] = nil
    -- Whole pixels, so the edges away from the aligned corner are on pixels too.
    panel.width = ui.snap(panel, fitWidth(panel, view))
    panel:SetWidth(panel.width)
    local headerMin = ui.drawChrome(panel, tooltip, {
        tooltipType = view.tooltipType,
        quest = view.tooltipType == "quest" or view.questItem,
        color = view.color,
        tint = view.tint,
        strength = view.strength,
        icon = view.icon,
        iconSize = view.iconSize,
        badge = view.badge,
        badgeColor = view.badgeColor,
        gradient = view.gradient,
        tag = view.tag,
    })
    if view.portrait and SetPortraitTexture then pcall(SetPortraitTexture, panel.icon, view.portrait) end

    local indent = indentOf(view)
    local leftIndent, rightIndent = ui.headerInsets(indent)
    local inner = panel.width - 2 * pad()
    local y = ui.titleTop()
    for _, item in ipairs(view.header) do
        if item.text then
            y = y + ui.styledAt(panel, item.text, pad() + leftIndent, y, inner - indent, item.style, item.color)
                + item.gap
        elseif item.badges and #item.badges > 0 then
            y = drawBadges(panel, item.badges, pad() + leftIndent, y + (item.before or 0), item.style) + item.gap
        elseif item.rows then
            for _, row in ipairs(item.rows) do
                y = ui.drawRow(panel, row, y, item.style, item.color, leftIndent, item.gap, rightIndent)
            end
        end
    end
    local footer = view.footer
    local hasFooter = footer and (footer.draw or #footer.rows > 0)
    if #view.header > 0 or view.icon then
        -- A header alone ends as far below its last line as its first is from the top.
        local alone = #view.sections == 0 and not hasFooter
        y = math.max(alone and y or y + 6, headerMin)
        panel.header:SetHeight(y - panel.inset)
    else
        -- Sections alone, as the minimap's list: as much room above as below.
        y = pad() - 2
        panel.header:SetHeight(0)
    end

    -- The header's rows are not a section's: the first separator follows the band.
    panel.rowTail = nil
    for index, section in ipairs(view.sections) do
        y = drawSeparator(panel, y, section.separator, index > 1)
        y = DRAW[section.kind](panel, y, section)
    end
    local bottom
    if hasFooter then
        -- Gilded's sunken band, or Slate's rule, from just under the sections;
        -- with one, the panel ends a band's padding under the footer.
        if ui.footerBand(panel, y + 2) then bottom = FOOTER_BOTTOM end
        y = y + FOOTER_TOP
        if footer.draw then
            y = footer.draw(panel, y)
        else
            for _, row in ipairs(footer.rows) do
                y = ui.drawRow(panel, row, y, footer.style, footer.color, 0, footer.gap)
            end
        end
    end
    ui.finishPanel(panel, tooltip, y, bottom)
end

-- The row naming what the panel shows by its ID, while IDs show.
function ui.idRow(panel, format, id)
    if id and ns.showsDetail("showIDs", panel) then return { left = util.fill(format, id), right = "" } end
end

-- Other addons' rows, then the ID row.
function ui.withID(panel, extras, format, id)
    local idRow = ui.idRow(panel, format, id)
    if not idRow then return extras end
    local rows = {}
    for index, row in ipairs(extras) do rows[index] = row end
    rows[#rows + 1] = idRow
    return rows
end

ui.renderView = renderView
ui.RULE_SPACE = RULE_SPACE
ui.setLive, ui.drawTrack = setLive, drawTrack
ui.drawBadges, ui.badgesWidth = drawBadges, badgesWidth
