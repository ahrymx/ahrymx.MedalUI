-- The mdlui_Tooltips window (/mdltip), laid out as MedalUI's Settings window, as the radial
-- editor and the Unit Frame Editor are:
--   the head       the title, a faint line saying what the page is for, the x in its own cell
--   the sidebar    TOOLTIPS: each kind there are samples of (one the game keeps, by the layout
--                  or its own Restyle, dimmed); SETTINGS: All tooltips, Options
--   a kind's page  its name, chips (Restyled, Follows cursor), a line; two sheets:
--                    Style  the sample, its examples in its card's band (click a part of it to
--                           pick that part); the part chosen: font, size, colour, outline,
--                           caps; Look up, a tooltip by ID or a shift-clicked link
--                    Panel  Restyle & place, the kind's panel, its details, its colours
--   All tooltips   fonts, the panel, bars, school colours: what every kind shares
--   Options        the layout, the modifiers, placement and scale, every kind's two switches
--   the footer     Reset all fonts and colors; "Changed since it opened", Undo changes, Close
-- Each group is a card of rows (UI/Panel.lua): a label, a line saying what it does, the
-- control; the long explanation in the row's tooltip. A changed row's label is gold, with a
-- reset beside its control. Dragged by its head or any bare part; where it is left is kept
-- (mdlui_TooltipsDB.editorPoint). ns.openEditor([where]): a kind ("item", ...), "all" or
-- "options"; nothing: the page shown last.
local _, medal = ...
local ns = medal.tips
local ui = ns.ui
local L, fillText = ns.L, ns.util.fill
if not (ui and ui.renderPreview and ns.Panel) then
    return
end
local Panel, C = ns.Panel, ns.PanelColors

local WHITE = "Interface\\Buttons\\WHITE8X8"
local RESET_ICON = "Interface\\Buttons\\UI-RefreshButton"
-- the Settings window's measures (as mdlui_RadialMenu/UI/Window.lua's)
local W, H = 1040, 680
local EDGE, BAR_H, SIDE_W, FOOT = 1, 34, 200, 40
local X, RIGHT = EDGE + SIDE_W + 18, 16                  -- the page's left, its right margin
local HEAD_TOP, HEAD_H, STRIP_H = EDGE + BAR_H + 14, 50, 26
local SHEET_TOP = HEAD_TOP + HEAD_H + STRIP_H - 4 + 12   -- a kind's sheets, under the tabs
local PAGE_TOP = HEAD_TOP + HEAD_H + 12                  -- All tooltips and Options, under the header
local BOTTOM = EDGE + FOOT + 14
local PAGE_W = W - X - RIGHT
local GAP = 12
local COL_W = math.floor((PAGE_W - GAP) / 2)
local SAMPLE_W = 470
local SIDE_CARD_W = PAGE_W - SAMPLE_W - GAP
local BAND_H, PAD, ROW_H = Panel.BAND_H, Panel.CARD_PAD, Panel.ROW_H
-- Room around the panel for its rarity halo and the Equipped tag above it.
local PREVIEW_MARGIN = 26
local SCROLL_STEP = 40
local KIND_ROW = 30                                      -- a row of Options' Every kind

local function Range(low, high, step)
    local t = {}
    for v = low, high, step or 1 do t[#t + 1] = v end
    return t
end
local PERCENT = function(v) return v .. "%" end
local PLAIN = function(v) return tostring(v) end

local BACKDROP_STYLES = {
    { text = "Gilded" },
    { value = "slate", text = "Slate" },
    { value = "native", text = "Blizzard border" },
    { value = "flat", text = "Flat" },
    { value = "dialogue", text = "DialogueUI" },
}

-- The samples, from UI/Samples.lua, for the types this client has.
local TOOLTIP_TYPES, TYPE_ORDER = {}, {}
for _, sampleType in ipairs(ns.editorSampleTypes and ns.editorSampleTypes() or {}) do
    TOOLTIP_TYPES[sampleType.key] = sampleType
    TYPE_ORDER[#TYPE_ORDER + 1] = sampleType.key
end
-- For tests/: every tooltip type's samples, in the editor's order.
ns.editorSamples = { tooltipTypes = TOOLTIP_TYPES, order = TYPE_ORDER }

-- The kinds in the sidebar, each its line under the page's title and the setting that restyles
-- it; its Follow cursor is that setting's entry's (ns.TOOLTIP_TYPES).
local KINDS = {
    { "item", "itemPanels", "Bags, links, loot and equipment." },
    { "spell", "spellPanels", "The spellbook, action bars and talents." },
    { "unit", "unitPanels", "Players, NPCs and creatures." },
    { "object", "objectPanels", "Herbs, ore, chests and other objects." },
    { "aura", "auraPanels", "Buffs and debuffs, yours and others'." },
    { "quest", "questPanels", "Quest links, the quest log and quest givers." },
    { "macro", "macroPanels", "Macros on your bars." },
    { "mail", "mailPanels", "Letters in your mailbox." },
}
local SIDEBAR, KIND = {}, {}
for _, k in ipairs(KINDS) do
    if TOOLTIP_TYPES[k[1]] then
        local kind = { key = k[1], restyle = k[2], line = k[3], label = TOOLTIP_TYPES[k[1]].label }
        for _, entry in ipairs(ns.TOOLTIP_TYPES) do
            if entry.restyle == k[2] then kind.cursor = entry.cursor end
        end
        SIDEBAR[#SIDEBAR + 1] = kind.key
        KIND[kind.key] = kind
    end
end

-- What the window shows: the page (a kind's key, "all" or "options"), a kind's sheet, and the
-- kind's sample, the part chosen and an ID looked up; each kind's kept while another shows.
local state = { page = SIDEBAR[1], sheet = "style", tooltipType = SIDEBAR[1], sample = 1,
    selected = TOOLTIP_TYPES[SIDEBAR[1]] and TOOLTIP_TYPES[SIDEBAR[1]].first, saved = {} }
local controls = {}
local refresh, refreshLookup

local function samples()
    return TOOLTIP_TYPES[state.tooltipType].samples
end

local function switchTooltipType(tooltipType)
    if tooltipType == state.tooltipType then return end
    state.saved[state.tooltipType] = { sample = state.sample, selected = state.selected, lookup = state.lookup }
    local saved = state.saved[tooltipType] or {}
    state.tooltipType = tooltipType
    state.sample = saved.sample or 1
    state.selected = saved.selected or TOOLTIP_TYPES[tooltipType].first
    state.lookup = saved.lookup
end

-- A region's tooltip: its title, the explanation, a gold warning under it (each text, or a
-- function giving it, or nil).
local function Tip(region, title, text, warning)
    region:HookScript("OnEnter", function(self)
        local function read(v) if type(v) == "function" then return v() end return v end
        local t, said, warn = read(title), read(text), read(warning)
        if not (t or said) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[t or ""], 1, 1, 1)
        if said then GameTooltip:AddLine(L[said], nil, nil, nil, true) end
        if warn then GameTooltip:AddLine(L[warn], 1, .82, 0, true) end
        GameTooltip:Show()
    end)
    region:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The window -----------------------------------------------------------------

local editor = CreateFrame("Frame", "mdlui_TooltipsEditor", UIParent)
editor:SetSize(W, H)
-- Below the color picker, which the editor opens.
editor:SetFrameStrata("HIGH")
editor:SetToplevel(true)
editor:SetClampedToScreen(true)
editor:EnableMouse(true)
editor:SetMovable(true)
editor:Hide()
tinsert(UISpecialFrames, "mdlui_TooltipsEditor")
-- the page's tone; a hairline edge, a faint gold ring outside it
Panel.Fill(editor, "BACKGROUND", C.page, 1):SetAllPoints()
Panel.Outline(editor, "BORDER", C.lineStrong, 0)
Panel.Outline(editor, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.35 }, -1)

local function Remember()
    local point, _, relative, x, y = editor:GetPoint()
    if not (point and x and y) then return end
    if type(mdlui_TooltipsDB) ~= "table" then mdlui_TooltipsDB = {} end
    mdlui_TooltipsDB.editorPoint = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
end

-- where it was left, else a little above the screen's middle
local placed = false
local function Place()
    if placed then return end
    placed = true
    editor:ClearAllPoints()
    local at = type(mdlui_TooltipsDB) == "table" and mdlui_TooltipsDB.editorPoint
    if type(at) == "table" and type(at[1]) == "string" and tonumber(at[3]) and tonumber(at[4]) then
        editor:SetPoint(at[1], UIParent, at[2] or at[1], at[3], at[4])
    else
        editor:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

-- a region that drags the window; where it is left is kept
local function Grip(region)
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function() editor:StartMoving() end)
    region:SetScript("OnDragStop", function()
        editor:StopMovingOrSizing()
        if editor.SetUserPlaced then editor:SetUserPlaced(false) end
        Remember()
    end)
end
Grip(editor)

-- a bar of the window's chrome (its head or footer), a hairline on its inner edge
local function Bar(top)
    local bar = CreateFrame("Frame", nil, editor)
    bar:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", EDGE, top and -EDGE or EDGE)
    bar:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", -EDGE, top and -EDGE or EDGE)
    bar:SetHeight(top and BAR_H or FOOT)
    bar:SetFrameLevel(editor:GetFrameLevel() + 5)
    Panel.Fill(bar, "BACKGROUND", C.ink, 1):SetAllPoints()
    local rule = Panel.Fill(bar, "BORDER", C.line)
    rule:SetHeight(1)
    rule:SetPoint(top and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
    rule:SetPoint(top and "BOTTOMRIGHT" or "TOPRIGHT", 0, 0)
    return bar
end

-- the head: the title, the subtitle, the x (red under the pointer)
local headBar = Bar(true)
Grip(headBar)
local title = Panel.Serif(headBar, 15, C.goldBright)
title:SetPoint("LEFT", 14, 0)
title:SetText("mdlui_Tooltips")
local subtitle = Panel.Plain(headBar, 11, C.faint)
subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
local closeX = CreateFrame("Button", nil, headBar)
closeX:SetSize(BAR_H, BAR_H - 1)
closeX:SetPoint("TOPRIGHT", 0, 0)
local closeLit = Panel.Fill(closeX, "BACKGROUND", C.red, 1)
closeLit:SetAllPoints()
closeLit:Hide()
local closeSeam = Panel.Fill(closeX, "BORDER", C.line)
closeSeam:SetWidth(1)
closeSeam:SetPoint("TOPLEFT", 0, 0)
closeSeam:SetPoint("BOTTOMLEFT", 0, 0)
closeX.glyph = closeX:CreateTexture(nil, "ARTWORK")
closeX.glyph:SetTexture(Panel.ART .. "Close")
closeX.glyph:SetSize(14, 14)
closeX.glyph:SetPoint("CENTER", 0, 0)
closeX.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
closeX:SetScript("OnClick", function() editor:Hide() end)
closeX:SetScript("OnEnter", function(self)
    closeLit:Show()
    self.glyph:SetVertexColor(0.949, 0.847, 0.784, 1)
end)
closeX:SetScript("OnLeave", function(self)
    closeLit:Hide()
    self.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
end)

-- The sidebar ----------------------------------------------------------------

local side = CreateFrame("Frame", nil, editor)
side:SetPoint("TOPLEFT", EDGE, -(EDGE + BAR_H))
side:SetPoint("BOTTOMLEFT", EDGE, EDGE + FOOT)
side:SetWidth(SIDE_W)
Panel.Fill(side, "BACKGROUND", C.ink, 1):SetAllPoints()
local sideRule = Panel.Fill(side, "BORDER", C.line)
sideRule:SetWidth(1)
sideRule:SetPoint("TOPRIGHT", 0, 0)
sideRule:SetPoint("BOTTOMRIGHT", 0, 0)

local nav = {}
local ShowPage
local navY = 18
local function NavHeading(text)
    local fs = Panel.Serif(side, 11, C.goldDark)
    fs:SetPoint("LEFT", side, "TOPLEFT", 16, -navY)
    fs:SetText(L[text]:upper())
    local rule = Panel.Fill(side, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", side, "TOPRIGHT", -14, -navY)
    navY = navY + 22
end
local function NavButton(key, label)
    local b = CreateFrame("Button", nil, side)
    b:SetPoint("TOPLEFT", 1, -(navY - 12))
    b:SetPoint("TOPRIGHT", -1, -(navY - 12))
    b:SetHeight(24)
    b.mark = Panel.Fill(b, "BACKGROUND", C.selected, 1)
    b.mark:SetAllPoints()
    b.bar = Panel.Fill(b, "ARTWORK", C.gold)
    b.bar:SetWidth(3)
    b.bar:SetPoint("TOPLEFT", 0, 0)
    b.bar:SetPoint("BOTTOMLEFT", 0, 0)
    Panel.Inset(Panel.Fill(b, "HIGHLIGHT", C.lift), 0, 0)
    b.label = Panel.Serif(b, 13, C.text)
    b.label:SetPoint("LEFT", 24, 0)
    b.label:SetText(L[label])
    b.note = Panel.Plain(b, 10, C.faint)
    b.note:SetPoint("RIGHT", -12, 0)
    b:SetScript("OnClick", function()
        Panel.Sound("click")
        ShowPage(key)
    end)
    nav[key] = b
    navY = navY + 26
    return b
end
NavHeading("Tooltips")
for _, key in ipairs(SIDEBAR) do
    local b = NavButton(key, KIND[key].label)
    Tip(b, KIND[key].label, function()
        if ns.option("layout") == "blizzard" then
            return "The Blizzard layout (Options) keeps the game's own tooltip for every kind."
        elseif not ns.restyles(KIND[key].restyle) then
            return "Not restyled: this kind keeps the game's own tooltip. Its Panel sheet turns it on."
        end
    end)
end
navY = navY + 12
NavHeading("Settings")
NavButton("all", "All tooltips")
NavButton("options", "Options")

-- The header -------------------------------------------------------------------

local head = CreateFrame("Frame", nil, editor)
head:SetPoint("TOPLEFT", editor, "TOPLEFT", X, -HEAD_TOP)
head:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -RIGHT, -HEAD_TOP)
head:SetHeight(HEAD_H + STRIP_H - 4)
local pageTitle = Panel.Serif(head, 20, C.text)
pageTitle:SetPoint("TOPLEFT", 0, -2)
pageTitle:SetWordWrap(false)
local chips = { Panel.Chip(head, ""), Panel.Chip(head, "") }
chips[1]:SetPoint("LEFT", pageTitle, "RIGHT", 12, 0)
chips[2]:SetPoint("LEFT", chips[1], "RIGHT", 6, 0)
local crumb = Panel.Plain(head, 12, C.faint)
crumb:SetPoint("TOPLEFT", 0, -28)
crumb:SetWordWrap(false)
local headRule = Panel.Fill(head, "ARTWORK", C.line)
headRule:SetHeight(1)
headRule:SetPoint("BOTTOMLEFT", 0, 0)
headRule:SetPoint("BOTTOMRIGHT", 0, 0)
local sheetTabs = {}
do
    local x = 0
    for _, s in ipairs({ { "style", "Style" }, { "panel", "Panel" } }) do
        local b = Panel.SheetTab(head, L[s[2]])
        b:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", x, 1)
        x = x + b:GetWidth() + 2
        b:SetScript("OnClick", function()
            Panel.Sound("click")
            ShowPage(state.tooltipType, s[1])
        end)
        sheetTabs[s[1]] = b
    end
end

-- The footer -------------------------------------------------------------------

local footBar = Bar(false)
local resetAll = Panel.UButton(footBar, L["Reset all fonts and colors"], 190, 26, "danger")
resetAll:SetPoint("LEFT", 11, 0)
Tip(resetAll, "Reset all fonts and colors", "Every part's font, size, color, outline and caps; the fonts, outline "
    .. "and band strengths every kind shares; each kind's panel; and the stat, armor, class and school colors. "
    .. "Which kinds are restyled and the details shown stay as they are.")
local closeButton = Panel.UButton(footBar, L["Close"], 64, 26, "quiet")
closeButton:SetPoint("RIGHT", -8, 0)
closeButton:SetScript("OnClick", function() editor:Hide() end)
local undoButton = Panel.UButton(footBar, L["Undo changes"], 120, 26)
undoButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)
Tip(undoButton, "Undo changes", "Every setting back as it was when the window opened.")
local changedPill = CreateFrame("Frame", nil, footBar)
changedPill:SetHeight(24)
changedPill:SetPoint("RIGHT", undoButton, "LEFT", -10, 0)
Panel.Fill(changedPill, "BACKGROUND", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.10 }, 1):SetAllPoints()
Panel.Outline(changedPill, "BORDER", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.35 }, 0)
do
    local dot = changedPill:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(Panel.ART .. "Round")
    dot:SetSize(7, 7)
    dot:SetPoint("LEFT", 10, 0)
    dot:SetVertexColor(C.goldBright[1], C.goldBright[2], C.goldBright[3], 1)
    changedPill.text = Panel.Plain(changedPill, 11, C.goldBright)
    changedPill.text:SetPoint("LEFT", dot, "RIGHT", 7, 0)
    changedPill.text:SetText(L["Changed since it opened"])
    changedPill:SetWidth(10 + 7 + 7 + math.ceil(changedPill.text:GetStringWidth() or 0) + 10)
end
changedPill:Hide()

-- Since the window opened: what was saved then (Undo puts it back), and the settings' count.
local opened, openedVersion
local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end
undoButton:SetScript("OnClick", function()
    local point = type(mdlui_TooltipsDB) == "table" and mdlui_TooltipsDB.editorPoint
    local saved = Copy(opened) or {}
    saved.editorPoint = point
    ns.restoreOptions(saved)
    openedVersion = ns.settingsVersion
    refresh()
end)
resetAll:SetScript("OnClick", function()
    ns.resetStyles()
    refresh()
end)

-- The pages ----------------------------------------------------------------------

local SHEET_H = H - SHEET_TOP - BOTTOM
local PAGE_H = H - PAGE_TOP - BOTTOM
local styleSheet = CreateFrame("Frame", nil, editor)
styleSheet:SetPoint("TOPLEFT", editor, "TOPLEFT", X, -SHEET_TOP)
styleSheet:SetSize(PAGE_W, SHEET_H)
-- the pages that scroll: their bar in the right margin
local panelSheet = Panel.Scroller(editor, PAGE_W + 12, SHEET_H)
panelSheet:SetPoint("TOPLEFT", editor, "TOPLEFT", X, -SHEET_TOP)
local allPage = Panel.Scroller(editor, PAGE_W + 12, PAGE_H)
allPage:SetPoint("TOPLEFT", editor, "TOPLEFT", X, -PAGE_TOP)
local optionsPage = Panel.Scroller(editor, PAGE_W + 12, PAGE_H)
optionsPage:SetPoint("TOPLEFT", editor, "TOPLEFT", X, -PAGE_TOP)

-- The sample (the Style sheet's left) ------------------------------------------------

local sampleCard = Panel.Card(styleSheet, L["Sample"], SAMPLE_W, SHEET_H)
sampleCard:SetPoint("TOPLEFT")
local host = CreateFrame("Frame", nil, sampleCard)
host:SetPoint("TOPLEFT", 8, -(BAND_H + 8))
host:SetPoint("BOTTOMRIGHT", -8, 8)
host:SetClipsChildren(true)
Panel.Fill(host, "BACKGROUND", { .02, .016, .02 }, 1):SetAllPoints()
Panel.Outline(host, "BORDER", C.line, 0)
-- Stands in for the game's tooltip; the panel pins itself to it.
local anchor = CreateFrame("Frame", nil, host)
anchor:SetSize(1, 1)
anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN, -PREVIEW_MARGIN)

-- each kind's examples, a segment in the sample card's band; none lit while an ID is looked up
local examples = {}
for _, key in ipairs(SIDEBAR) do
    local labels = {}
    for i, sample in ipairs(TOOLTIP_TYPES[key].samples) do labels[i] = L[sample.label] end
    local function pick(i)
        state.sample, state.lookup = i, nil
        refresh()
    end
    local seg = Panel.Segment(sampleCard, labels, pick, 11, 36, 14)
    -- a long row of examples, smaller, to stay clear of the card's title
    if seg:GetWidth() > SAMPLE_W - 110 then
        seg:Hide()
        seg = Panel.Segment(sampleCard, labels, pick, 10, 28, 10)
    end
    Panel.InBand(sampleCard, seg)
    seg:Hide()
    examples[key] = seg
end

local overlay = CreateFrame("Frame", nil, host)
overlay:SetAllPoints()
overlay:EnableMouse(true)
local failure = Panel.Plain(overlay, 11, { 1, .3, .25 })
failure:SetPoint("TOPLEFT", 12, -12)
failure:SetWidth(SAMPLE_W - 40)
local hint = Panel.Plain(overlay, 10, C.faint)
hint:SetPoint("BOTTOMLEFT", 10, 8)

local function ScrollBar(vertical)
    local bar = CreateFrame("Slider", nil, host)
    bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    if vertical then
        bar:SetPoint("TOPRIGHT", -3, -3)
        bar:SetPoint("BOTTOMRIGHT", -3, 3)
        bar:SetWidth(6)
    else
        bar:SetPoint("BOTTOMLEFT", 8, 4)
        bar:SetPoint("BOTTOMRIGHT", -20, 4)
        bar:SetHeight(6)
    end
    bar:SetValueStep(1)
    Panel.Fill(bar, "BACKGROUND", C.line, 1):SetAllPoints()
    bar:SetThumbTexture(WHITE)
    local thumb = bar:GetThumbTexture()
    if vertical then thumb:SetWidth(6) else thumb:SetHeight(6) end
    thumb:SetVertexColor(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1)
    bar:Hide()
    return bar, thumb
end
local scrollBar, scrollThumbTexture = ScrollBar(true)
local horizontalBar, horizontalThumb = ScrollBar(false)
local scrolledFor

local function scrollTo(offset)
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN - horizontalBar:GetValue(), -PREVIEW_MARGIN + offset)
end
scrollBar:SetScript("OnValueChanged", function(_, offset) scrollTo(math.floor(offset + .5)) end)
horizontalBar:SetScript("OnValueChanged", function() scrollTo(scrollBar:GetValue()) end)
overlay:EnableMouseWheel(true)
overlay:SetScript("OnMouseWheel", function(_, delta)
    if IsShiftKeyDown() and horizontalBar:IsShown() then
        horizontalBar:SetValue(horizontalBar:GetValue() - delta * SCROLL_STEP)
    elseif scrollBar:IsShown() then
        scrollBar:SetValue(scrollBar:GetValue() - delta * SCROLL_STEP)
    end
end)
local highlights = {}
local hovered

local function preview()
    return anchor.prettyTooltipPreview
end

local function hasPart(key)
    local panel = preview()
    for _, hit in ipairs(panel and panel.hits or {}) do
        if hit.key == key then return true end
    end
    return false
end

local function partAtCursor()
    local panel = preview()
    if not (panel and panel:IsShown() and panel.hits) then return end
    local x, y = GetCursorPosition()
    for _, hit in ipairs(panel.hits) do
        local region = hit.region
        local scale = region:GetEffectiveScale()
        local cursorX, cursorY = x / scale, y / scale
        local left, right = region:GetLeft(), region:GetRight()
        local top, bottom = region:GetTop(), region:GetBottom()
        if left and region:IsShown() and cursorX >= left - 2 and cursorX <= right + 2
            and cursorY <= top + 1 and cursorY >= bottom - 1 then
            return hit.key
        end
    end
end

local function paintHighlights()
    for _, tex in ipairs(highlights) do tex:Hide() end
    local panel = preview()
    if not (panel and panel.hits) then return end
    local used = 0
    for _, hit in ipairs(panel.hits) do
        local selected = hit.key == state.selected
        if selected or hit.key == hovered then
            used = used + 1
            local tex = highlights[used]
            if not tex then
                tex = overlay:CreateTexture(nil, "OVERLAY")
                tex:SetTexture(WHITE)
                highlights[used] = tex
            end
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", hit.region, "TOPLEFT", -3, 2)
            tex:SetPoint("BOTTOMRIGHT", hit.region, "BOTTOMRIGHT", 3, -2)
            if selected then
                tex:SetVertexColor(C.goldBright[1], C.goldBright[2], C.goldBright[3], .16)
            else
                tex:SetVertexColor(1, 1, 1, .07)
            end
            tex:Show()
        end
    end
end

local function showHint()
    local element = hovered and ns.ELEMENT_BY_KEY[hovered]
    hint:SetText(element and fillText(L["%s: click to edit"], L[element.label])
        or L["Click any part of the sample to edit it."])
end

overlay:SetScript("OnUpdate", function(self)
    local key = self:IsMouseOver() and partAtCursor() or nil
    if key == hovered then return end
    hovered = key
    paintHighlights()
    showHint()
end)

-- The editor's lookup by ID reads this hidden tooltip; it never gets a panel.
local scanner
local function previewByID(target, dataType, id)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "mdlui_TooltipsScanner", UIParent, "GameTooltipTemplate")
        scanner.prettyTooltipScanner = true
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    if dataType == Enum.TooltipDataType.Item then scanner:SetItemByID(id) else scanner:SetSpellByID(id) end
    local data = scanner:GetTooltipData()
    local tooltipType = ns.TooltipTypes[dataType]
    local ok, model = pcall(tooltipType.read, scanner, data, ns.Game)
    scanner:Hide()
    if not (ok and model) then return end
    return ui.renderPreview(target, model, dataType)
end

-- Uncached items are requested; GET_ITEM_INFO_RECEIVED redraws.
local function lookupProblem(tooltipType, id)
    if tooltipType.dataType ~= Enum.TooltipDataType.Item or not C_Item then return end
    if C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(id) == false then
        return fillText(L["There is no item with ID %s."], id)
    end
    if C_Item.GetItemInfo and not C_Item.GetItemInfo(id) then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return fillText(L["Loading item %s..."], id)
    end
end

local function drawSample()
    local tooltipType = TOOLTIP_TYPES[state.tooltipType]
    local problem = state.lookup and lookupProblem(tooltipType, state.lookup)
    if not problem then
        local ok, panel = pcall(function()
            if state.lookup then return previewByID(anchor, tooltipType.dataType, state.lookup) end
            return ui.renderPreview(anchor, tooltipType.samples[state.sample].build(), tooltipType.dataType)
        end)
        if not ok then
            problem = fillText(L["The sample failed to draw: %s"], tostring(panel))
        elseif not panel then
            problem = fillText(L["Nothing to show for %s ID %s."], L[tooltipType.noun], state.lookup)
        end
    end
    failure:SetText(problem or "")
    local shown = preview()
    if shown then
        shown:SetShown(problem == nil)
        overlay:SetFrameLevel(shown:GetFrameLevel() + 20)
        scrollBar:SetFrameLevel(overlay:GetFrameLevel() + 5)
        horizontalBar:SetFrameLevel(overlay:GetFrameLevel() + 5)
    end
    local showing = state.tooltipType .. ":" .. state.sample .. ":" .. tostring(state.lookup)
    local offset = showing == scrolledFor and scrollBar:GetValue() or 0
    local horizontalOffset = showing == scrolledFor and horizontalBar:GetValue() or 0
    scrolledFor = showing
    local sampleWidth = (shown and shown:IsShown())
        and shown:GetWidth() * shown:GetEffectiveScale() / host:GetEffectiveScale() + 2 * PREVIEW_MARGIN or 0
    local horizontalRange = math.max(0, math.ceil(sampleWidth - host:GetWidth()))
    horizontalBar:SetMinMaxValues(0, horizontalRange)
    horizontalBar:SetShown(horizontalRange > 0)
    if horizontalRange > 0 then
        horizontalThumb:SetWidth(math.max(24, horizontalBar:GetWidth() * host:GetWidth() / sampleWidth))
    end
    horizontalBar:SetValue(math.min(horizontalOffset, horizontalRange))
    local sampleHeight = (shown and shown:IsShown())
        and shown:GetHeight() * shown:GetEffectiveScale() / host:GetEffectiveScale() + 2 * PREVIEW_MARGIN or 0
    local range = math.max(0, math.ceil(sampleHeight - host:GetHeight()))
    scrollBar:SetMinMaxValues(0, range)
    scrollBar:SetShown(range > 0)
    if range > 0 then
        scrollThumbTexture:SetHeight(math.max(24, scrollBar:GetHeight() * host:GetHeight() / sampleHeight))
    end
    offset = math.min(offset, range)
    scrollBar:SetValue(offset)
    scrollTo(offset)
end

-- A part picked: in the sample, or from the part card's list. One the example shown lacks
-- is looked for in the kind's others.
local function selectPart(key)
    state.selected = key
    if not hasPart(key) and not state.lookup then
        for index = 1, #samples() do
            if index ~= state.sample then
                state.sample = index
                drawSample()
                if hasPart(key) then break end
            end
        end
    end
    refresh()
end

overlay:SetScript("OnMouseDown", function()
    if hovered then selectPart(hovered) end
end)

-- Rows -----------------------------------------------------------------------------

-- What a row's reset clears: saved gives the stored value, nil while the setting is at its default.
local function partSetting(field)
    return {
        saved = function() return ns.elementSetting(state.selected, field) end,
        reset = function() ns.setElementSetting(state.selected, field, nil) end,
    }
end

local function optionSetting(key)
    return {
        saved = function() return ns.savedOption(key) end,
        reset = function() ns.setOption(key, nil) end,
    }
end

-- A row's control put at its right, after a reset while it is changed (setting), its words
-- clear of both; fill() shows the saved value. available(): false fades the row and turns its
-- control off (control.SetEnabled), as a kind left to the game, or DialogueUI missing.
local function Finish(row, control, width, fill, setting, available)
    local reset
    if setting then
        reset = CreateFrame("Button", nil, row)
        reset:SetSize(14, 14)
        reset:SetNormalTexture(RESET_ICON)
        reset:SetHighlightTexture(RESET_ICON, "ADD")
        reset:SetScript("OnClick", function()
            Panel.Sound("click")
            setting.reset()
            refresh()
        end)
        Tip(reset, "Reset to default")
    end
    row:Hold(control, width + (setting and 22 or 0))
    if reset then reset:SetPoint("RIGHT", row, "RIGHT", -(width + 8), 0) end
    controls[#controls + 1] = {
        refresh = function()
            local on = not available or available()
            if fill then fill() end
            if control.SetEnabled then control:SetEnabled(on) end
            if control.Paint_ then control:Paint_() end
            row:SetAlpha(on and 1 or 0.45)
            local changed = setting and setting.saved() ~= nil
            if reset then reset:SetShown(changed and on) end
            local c = changed and C.gold or C.text
            row.label:SetTextColor(c[1], c[2], c[3])
        end,
    }
end

-- spec: { label, line, tip, warning, setting, available }
local function NewRow(card, n, spec)
    local row = Panel.CardRow(card, n, L[spec[1]], spec[2] and L[spec[2]])
    Tip(row, spec[1], spec.tip, spec.warning)
    return row
end

local function SwitchRow(card, n, spec, get, set)
    local row = NewRow(card, n, spec)
    local switch = Panel.Switch(row, function(self)
        set(self:GetChecked() and true or false)
        refresh()
    end)
    Tip(switch, spec[1], spec.tip, spec.warning)
    Finish(row, switch, 36, function() switch:SetOn(get()) end, spec.setting, spec.available)
    row.switch = switch
    return row
end

-- An option on or off; its default is saved as no setting.
local function OptionSwitch(card, n, spec, key)
    spec.setting = spec.setting or optionSetting(key)
    return SwitchRow(card, n, spec, function() return ns.option(key) end, function(on)
        ns.setOption(key, nil)
        if ns.option(key) ~= on then ns.setOption(key, on) end
    end)
end

-- values: the answers saved (nil the default), labels: their short words
local function SegmentRow(card, n, spec, values, labels, get, set)
    local row = NewRow(card, n, spec)
    local translated = {}
    for i, label in ipairs(labels) do translated[i] = L[label] end
    local seg = Panel.Segment(row, translated, function(i)
        set(values[i])
        refresh()
    end, 11, 40, 16)
    for _, b in ipairs(seg.buttons) do Tip(b, spec[1], spec.tip, spec.warning) end
    Finish(row, seg, seg:GetWidth(), function()
        local now, at = get(), nil
        for i = 1, #labels do if values[i] == now then at = i end end
        seg:SetValue(at)
    end, spec.setting, spec.available)
    row.segment = seg
    return row
end

local function SliderRow(card, n, spec, values, text, get, set)
    local row = NewRow(card, n, spec)
    local st = Panel.Slider(row, values, text, get, function(v)
        set(v)
        refresh()
    end)
    for _, region in ipairs({ st.plus, st.minus, st.track }) do Tip(region, spec[1], spec.tip, spec.warning) end
    Finish(row, st, st:GetWidth(), function() st:Fill() end, spec.setting, spec.available)
    row.slider = st
    return row
end

-- items() lists { value, text, font }; current() is the chosen value, nil for the default;
-- pick(value) saves a choice. Each font is shown in its own face.
local MENU_ROWS = 16
-- A font object for each face the menus show: the game's menus forbid
-- SetFont on their own texts ("Use of function 'SetFont' is disallowed",
-- Blizzard_Menu's Compositor), but take a font object.
local menuFonts, menuFontCount = {}, 0
local function MenuFont(path)
    if menuFonts[path] == nil then
        menuFonts[path] = false
        if CreateFont then
            menuFontCount = menuFontCount + 1
            local font = CreateFont("mdlui_TooltipsMenuFont" .. menuFontCount)
            if font and font:SetFont(path, 13, "") ~= false then menuFonts[path] = font end
        end
    end
    return menuFonts[path] or nil
end
local function ChoiceRow(card, n, spec, width, items, current, pick)
    local row = NewRow(card, n, spec)
    local drop = Panel.Choice(row, width, function(_, root)
        local list = items()
        if root.SetScrollMode and #list > MENU_ROWS then root:SetScrollMode(MENU_ROWS * 20) end
        for _, item in ipairs(list) do
            local entry = root:CreateRadio(L[item.text], function() return item.value == current() end, function()
                pick(item.value)
                refresh()
            end)
            if item.font and entry and entry.AddInitializer then
                entry:AddInitializer(function(button)
                    local fs, font = button.fontString, MenuFont(item.font)
                    if fs and font and fs.SetFontObject then fs:SetFontObject(font) end
                end)
            end
        end
    end)
    Tip(drop, spec[1], spec.tip, spec.warning)
    Finish(row, drop, width, function()
        local value, shown = current(), nil
        for _, item in ipairs(items()) do
            if item.value == value then shown = item break end
        end
        drop:SetValueText(shown and L[shown.text] or fillText(L["%s (not installed)"], tostring(value)))
    end, spec.setting, spec.available)
    row.choice, row.items = drop, items
    return row
end

-- Colors -------------------------------------------------------------------------

-- Both color picker interfaces; cancelling restores the saved color.
local function pickColor(start, apply, restore)
    local function changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply({ r, g, b })
        refresh()
    end
    local function cancelled()
        restore()
        refresh()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = start[1], g = start[2], b = start[3], hasOpacity = false,
            swatchFunc = changed, cancelFunc = cancelled,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r = start[1], g = start[2], b = start[3] }
        ColorPickerFrame.func = changed
        ColorPickerFrame.cancelFunc = cancelled
        ColorPickerFrame:SetColorRGB(start[1], start[2], start[3])
        ShowUIPanel(ColorPickerFrame)
    end
end

local function hexColor(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- A group of colors as a row of swatches, each its own setting (prefix .. key): a click picks
-- one, a right-click puts back its default. note(), if given, says why the colors shown may not
-- be the ones chosen.
local function SwatchRow(card, n, spec, list, prefix, colorOf, note)
    spec.setting = {
        saved = function()
            for _, choice in ipairs(list) do
                if ns.savedOption(prefix .. choice.key) ~= nil then return true end
            end
        end,
        reset = function()
            for _, choice in ipairs(list) do ns.setOption(prefix .. choice.key, nil) end
        end,
    }
    local row = NewRow(card, n, spec)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(#list * 26 - 4, 18)
    local swatches = {}
    for index, choice in ipairs(list) do
        local key = prefix .. choice.key
        local sw = Panel.Swatch(holder, function(_, mouse)
            if mouse == "RightButton" then
                ns.setOption(key, nil)
                refresh()
                return
            end
            local saved = ns.savedOption(key)
            pickColor(colorOf(choice.key) or ns.Palette.roles.neutral,
                function(color) ns.setOption(key, color) end,
                function() ns.setOption(key, saved) end)
        end)
        sw:SetPoint("LEFT", (index - 1) * 26, 0)
        Tip(sw, choice.label, "Click to choose its color; right-click for the default.", note)
        swatches[choice.key] = sw
    end
    Finish(row, holder, holder:GetWidth(), function()
        for key, sw in pairs(swatches) do
            local color = colorOf(key) or ns.Palette.roles.neutral
            sw:SetColor(color[1], color[2], color[3], 1)
        end
    end, spec.setting, spec.available)
    row.swatches = swatches
    return row
end

-- Cards -----------------------------------------------------------------------------

local function CardHeight(rows) return BAND_H + 4 + rows * ROW_H + 8 end

-- a card of rows: build(card, n) adds row n of count
local function RowsCard(parent, cardTitle, width, count, build)
    local card = Panel.Card(parent, L[cardTitle], width, CardHeight(count))
    for n = 1, count do build(card, n) end
    return card
end

-- The part chosen (the Style sheet's right) -----------------------------------------

local function selectedElement()
    return ns.ELEMENT_BY_KEY[state.selected]
end

local function fontItems(defaultText)
    local items = { { text = defaultText } }
    for _, name in ipairs(ns.fontNames()) do
        items[#items + 1] = { value = name, text = name, font = ns.fontPath(name) }
    end
    return items
end

local PART_FOOT = 48
local partCard = Panel.Card(styleSheet, "", SIDE_CARD_W, CardHeight(5) + PART_FOOT)
partCard:SetPoint("TOPRIGHT")
partCard.note:SetText(L["the part chosen"])
-- every part this kind has, and the ones every kind shares
local partPicker = Panel.Choice(partCard, 130, function(_, root)
    for _, element in ipairs(ns.ELEMENTS) do
        local kind = element.tooltipType or "item"
        if kind == state.tooltipType or kind == "shared" then
            local key = element.key
            root:CreateRadio(L[element.label], function() return state.selected == key end, function()
                selectPart(key)
            end)
        end
    end
end)
Panel.InBand(partCard, partPicker)
Tip(partPicker, "Part", "Every part this kind of tooltip has. Or click one in the sample.")
controls[#controls + 1] = { refresh = function()
    local element = selectedElement()
    partCard.title:SetText(element and L[element.label] or "")
    partPicker:SetValueText(fillText(L["Part: %s"], element and L[element.label] or "?"))
end }

ChoiceRow(partCard, 1, { "Font", "Its typeface", tip = "The part's font. The first choice follows the text or name "
    .. "font every kind shares (All tooltips).", setting = partSetting("font") }, 150, function()
    return fontItems(selectedElement().title and "Name font" or "Text font")
end, function()
    return ns.elementSetting(state.selected, "font")
end, function(name)
    ns.setElementSetting(state.selected, "font", name)
end)

SliderRow(partCard, 2, { "Size", "In points", tip = "The part's text size, before the text size every kind "
    .. "shares (All tooltips) scales it.", setting = partSetting("size") }, Range(8, 30), PLAIN, function()
    return ns.elementSetting(state.selected, "size") or selectedElement().size
end, function(size)
    ns.setElementSetting(state.selected, "size", size ~= selectedElement().size and size or nil)
end)

-- the part's color: its own, or Automatic (the quality's, the school's, its kind's), faint
do
    local row = NewRow(partCard, 3, { "Color", "Automatic unless chosen",
        tip = "A color of its own for the part. Automatic takes what the tooltip says: the item's quality, "
            .. "the spell's school, the unit's reaction." })
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(150, 22)
    local swatch = Panel.Swatch(holder, function()
        local key = state.selected
        local saved = ns.elementSetting(key, "color")
        local start = type(saved) == "table" and saved or ns.ELEMENT_BY_KEY[key].color
        pickColor(start,
            function(color) ns.setElementSetting(key, "color", color) end,
            function() ns.setElementSetting(key, "color", saved) end)
    end)
    swatch:SetPoint("RIGHT")
    Tip(swatch, "Color", "Click to choose the part's color.")
    local automatic = Panel.UButton(holder, L["Automatic"], 74, 20, "quiet")
    automatic:SetPoint("RIGHT", swatch, "LEFT", -6, 0)
    automatic:SetScript("OnClick", function()
        ns.setElementSetting(state.selected, "color", nil)
        refresh()
    end)
    Tip(automatic, "Automatic", "The color the tooltip gives the part, not one of its own.")
    local status = Panel.Plain(holder, 11, C.dim)
    status:SetPoint("RIGHT", swatch, "LEFT", -8, 0)
    Finish(row, holder, 150, function()
        local saved = ns.elementSetting(state.selected, "color")
        local custom = type(saved) == "table"
        local color = custom and saved or selectedElement().color
        swatch:SetColor(color[1], color[2], color[3], custom and 1 or .35)
        status:SetText(custom and "" or L["Automatic"])
        automatic:SetShown(custom)
    end, partSetting("color"))
    row.swatch, row.automatic = swatch, automatic
end

SegmentRow(partCard, 4, { "Outline", "Round its letters", tip = "An outline round the part's letters. Global "
    .. "follows the outline every kind shares (All tooltips).", setting = partSetting("outline") },
    { nil, "NONE", "OUTLINE", "THICKOUTLINE" }, { "Global", "None", "Thin", "Thick" },
    function() return ns.elementSetting(state.selected, "outline") end,
    function(value) ns.setElementSetting(state.selected, "outline", value) end)

-- the part's default is saved as no setting
SwitchRow(partCard, 5, { "All caps", "Capital letters only", tip = "The part in capital letters. Names are, "
    .. "by default.", setting = partSetting("caps") }, function()
    local caps = ns.elementSetting(state.selected, "caps")
    if caps == nil then caps = selectedElement().title == true end
    return caps
end, function(on)
    ns.setElementSetting(state.selected, "caps", on ~= (selectedElement().title == true) and on or nil)
end)

local resetPart = Panel.UButton(partCard, L["Reset part"], 90, 24, "secondary")
resetPart:SetPoint("BOTTOMLEFT", PAD, 12)
resetPart:SetScript("OnClick", function()
    ns.resetElement(state.selected)
    refresh()
end)
Tip(resetPart, "Reset part", "The part's font, size, color, outline and caps back to their defaults.")
local partNote = Panel.Plain(partCard, 10, C.faint)
partNote:SetPoint("LEFT", resetPart, "RIGHT", 10, 0)
partNote:SetPoint("RIGHT", partCard, "RIGHT", -PAD, 0)
partNote:SetHeight(PART_FOOT - 8)
partNote:SetJustifyV("MIDDLE")
controls[#controls + 1] = { refresh = function() partNote:SetText(L[selectedElement().note or ""]) end }

-- Looking up by ID ---------------------------------------------------------------------

local function applyLookup(entry)
    local tooltipType = state.tooltipType
    local id = entry:match("^%s*(%d+)%s*$")
    for _, candidate in ipairs(TYPE_ORDER) do
        local linked = entry:match(TOOLTIP_TYPES[candidate].noun .. ":(%d+)")
        if linked then id, tooltipType = linked, candidate break end
    end
    if tooltipType ~= state.tooltipType and KIND[tooltipType] then
        ShowPage(tooltipType, "style")
    end
    state.lookup = id and tonumber(id) or nil
    refresh()
end

local lookupCard = Panel.Card(styleSheet, L["Look up"], SIDE_CARD_W, CardHeight(1))
lookupCard:SetPoint("TOPRIGHT", partCard, "BOTTOMRIGHT", 0, -GAP)
local lookupRow = Panel.CardRow(lookupCard, 1, "", L["Or shift-click a link into it"])
local lookupBox = Panel.Search(lookupRow, 120, 22, L["ID"])
lookupBox:SetMaxLetters(255)
lookupRow:Hold(lookupBox, 120)
lookupBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    applyLookup(self:GetText())
end)
lookupBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    refresh()
end)
Tip(lookupBox, "Look up", "Type an ID and press Enter, or shift-click a link while the box has the cursor: "
    .. "the sample shows that tooltip.")
local lookupClear = Panel.UButton(lookupCard, L["Clear"], 56, 20, "quiet")
Panel.InBand(lookupCard, lookupClear)
lookupClear:SetScript("OnClick", function()
    state.lookup = nil
    refresh()
end)

if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if lookupBox:HasFocus() and type(link) == "string" then
            lookupBox:ClearFocus()
            applyLookup(link)
        end
    end)
end

refreshLookup = function()
    local tooltipType = TOOLTIP_TYPES[state.tooltipType]
    lookupCard:SetShown(tooltipType.noLookup ~= true)
    lookupCard.note:SetText(fillText(L["any %s by its ID"], L[tooltipType.noun]))
    lookupRow.label:SetText(L[tooltipType.label:sub(1, -2) .. " ID"])
    if not lookupBox:HasFocus() then
        lookupBox:SetText(state.lookup and tostring(state.lookup) or "")
    end
    lookupClear:SetShown(state.lookup ~= nil)
end

-- A kind's Panel sheet ------------------------------------------------------------------

-- What only some kinds have, each { label, key, line, explanation, kinds, available, warning }.
-- The spell power rows read spell descriptions, which not every language's reading covers yet.
local function coefficients() return ns.Locale.features.coefficients == true end
local function dialogue() return ns.Game.addonInstalled("DialogueUI") end
local DETAILS = {
    { "Quest parchment", "questParchment", "DialogueUI's parchment", "DialogueUI's brown parchment for quest "
        .. "tooltips, Quest Items, and items that begin a quest, with darker ink for readability. Requires "
        .. "DialogueUI to be installed.", { item = true, quest = true }, dialogue },
    { "Level badge", "itemLevelBadge", "The item level under the icon",
        "The item level on a plate under the icon, for equipment.", { item = true } },
    { "Level badge", "unitLevelBadge", "The level under the portrait",
        "The level on a plate under the portrait. Off, the level stays in the info line.", { unit = true } },
    { "Stat markers", "statMarkers", "A diamond before each stat",
        "The small diamond before each stat; enchants use a green one.", { item = true } },
    { "Stat colors", "statColors", "Each kind of stat in its color",
        "Each kind of stat in its color (Colors, below), and the school colors. Off, every stat is parchment.",
        { item = true } },
    { "Armor colors", "armorColors", "Cloth, leather, mail and plate", "Cloth, leather, mail, and plate under "
        .. "the item's name, each in its color (Colors, below). A type you cannot wear stays red. Off, they take "
        .. "the quality color.", { item = true } },
    { "Abbreviated Equip Effects", "liteWording", "+1% Critical Strike Chance", "Where the game's own item "
        .. "tooltip shows, in the Blizzard layout or with items not restyled, its Equip effects are shortened, as "
        .. "+1% Critical Strike Chance, and the game's colors kept, but for spell power and chance on hit effects "
        .. "in their stat colors. Hold the default tooltip modifier for the full wording.", { item = true } },
    { "Swap Damage Stats", "swapDamage", "Damage large, speed under it", "A weapon's damage on the large line, "
        .. "with its speed and damage per second on the small one under it.", { item = true } },
    { "Disenchant", "disenchant", "What it breaks into", "Green, blue, and purple armor and weapons list what "
        .. "they disenchant into, with each result's chance and the Enchanting it needs; with Auctionator, the "
        .. "expected value.", { item = true } },
    { "Sell price", "sellPrice", "The vendor's price in the footer", "The vendor price in the footer; for a "
        .. "stack, the price of one and of the whole stack.", { item = true } },
    { "Spell power (Experimental)", "spellPower", "Coefficients, base and bonus", "Under the description, each "
        .. "amount's spell power coefficient and its split into base and spell power. No game API has "
        .. "coefficients: they come from Forever's client data, and ones marked ~ are estimates.",
        { spell = true }, coefficients, "Experimental: not all values are correct yet." },
    { "Rates", "spellRates", "Per second and per mana", "Under the spell power breakdown, the average a cast "
        .. "deals or heals per second and per mana. Per second, what lands at once counts over the cast time "
        .. "(instants as the 1.5 sec global cooldown) and what comes over time over its duration. Crits and "
        .. "talents do not count.", { spell = true }, coefficients },
    { "Health bar", "unitHealthBar", "The game's bar at the foot", "The game's own health bar at the bottom of "
        .. "player and NPC panels, with the health above it: current and most on the left, the percentage on the "
        .. "right. The game fills the bar, so it stays live in combat too.", { unit = true } },
    { "Gathering", "gatheringLoot", "What a node or a skinning holds", "What a herb or ore node holds: its "
        .. "yield over all the times it can be gathered, then the stone, gems, and other herbs it may give and "
        .. "the chance each time. On a dead creature that can be skinned, the Skinning it needs and the leather, "
        .. "hides, and scales it may give. From Classic's loot tables.", { object = true, unit = true } },
    { "IDs", "showIDs", "Its ID at the foot", "The item's, spell's, or NPC's ID at the bottom of its panel, under "
        .. "other addons' rows.", { item = true, spell = true, unit = true } },
}
-- The rows that show only while the details key is held.
local HELD = { disenchant = true, spellPower = true, spellRates = true, gatheringLoot = true, showIDs = true }

local COLORS = {
    item = {
        { "Stat colors", "Each kind of stat", ns.Stats.CATEGORIES, "statColor", function(key)
            return hexColor((ns.Stats.categoryColors(key)))
        end },
        { "Armor colors", "Cloth, leather, mail, plate", ns.Palette.ARMOR, "armorColor", ns.Palette.armorColor },
    },
    unit = {
        { "Class colors", "Each class's names and bars", ns.Palette.CLASSES, "classColor", ns.Palette.classColor,
            function()
                if ns.Palette.addonClassColors() then
                    return L["Your class colors addon sets these; the colors chosen here apply without it."]
                end
            end },
    },
}

local function notBlizzard() return ns.option("layout") ~= "blizzard" end
local BLIZZARD_WARNING = function()
    if not notBlizzard() then return "The Blizzard layout (Options) keeps the game's tooltip for every kind." end
end

local kindPanels = {}
local function BuildKindPanel(key)
    local kind = KIND[key]
    local suffix = ns.TYPE_SUFFIX[key]
    local f = CreateFrame("Frame", nil, panelSheet.content)
    f:SetPoint("TOPLEFT")
    f:SetSize(PAGE_W, 1)
    -- the left: Restyle & place, then the kind's panel
    local placeRows = kind.cursor and 2 or 1
    local place = RowsCard(f, "Restyle & place", COL_W, placeRows, function(card, n)
        if n == 1 then
            OptionSwitch(card, 1, { "Restyle", "The mdlui panel; off, the game's tooltip",
                tip = "Draws the mdlui_Tooltips panel for this kind. Off, it keeps the game's own tooltip, with the "
                    .. "details modifier's rows added to it.", available = notBlizzard, warning = BLIZZARD_WARNING },
                kind.restyle)
        else
            OptionSwitch(card, 2, { "Follow cursor", "At the pointer, not the corner",
                tip = "Shows this kind's tooltip at the cursor when the game would put it in its default corner; bags "
                    .. "and other panels keep theirs. Off, its position is left to the game and other addons." },
                kind.cursor)
        end
    end)
    place:SetPoint("TOPLEFT")
    local function bandOpacity(edge)
        local own = "header" .. edge .. "Alpha" .. suffix
        -- what the kind shows with no setting of its own
        local function fallback() return ns.option("header" .. edge .. "Alpha") or ui.defaultHeaderAlpha() end
        return function()
            return math.floor((ns.headerAlpha(key, edge) or ui.defaultHeaderAlpha()) * 100 + .5)
        end, function(percent)
            local alpha = percent / 100
            ns.setOption(own, math.abs(alpha - fallback()) > .001 and alpha or nil)
        end, own
    end
    local function opacity(name, default)
        local own = name .. suffix
        return function()
            return math.floor((ns.option(own) or default) * 100 + .5)
        end, function(percent)
            ns.setOption(own, math.abs(percent / 100 - default) > .001 and percent / 100 or nil)
        end, own
    end
    local panelCard = RowsCard(f, fillText(L["%s panel"], L[kind.label]), COL_W, 5, function(card, n)
        if n == 1 then
            OptionSwitch(card, 1, { "Show icon", "The icon or portrait in the header",
                tip = "The icon or portrait in the header, for this kind of tooltip." }, "icon" .. suffix)
        elseif n <= 3 then
            local edge = n == 2 and "Top" or "Bottom"
            local get, set, own = bandOpacity(edge)
            SliderRow(card, n, { n == 2 and "Band top" or "Band bottom",
                n == 2 and "The header band's strength" or "The footer band's strength",
                tip = "How strong the band of shade is at the panel's " .. (n == 2 and "top" or "bottom")
                    .. ". With none of its own, this kind follows the strength every kind shares.",
                setting = optionSetting(own) }, Range(0, 100, 5), PERCENT, get, set)
        else
            local name, default = n == 4 and "backdropAlpha" or "glowAlpha", n == 4 and ns.BACKDROP_ALPHA or 1
            local get, set, own = opacity(name, default)
            SliderRow(card, n, { n == 4 and "Backdrop" or "Glow", n == 4 and "The panel's ink" or "The halo round it",
                tip = n == 4 and "How solid the panel's ink is." or "How bright the halo round the panel is: an "
                    .. "item's quality, a spell's school.", setting = optionSetting(own) },
                Range(0, 100, 5), PERCENT, get, set)
        end
    end)
    panelCard:SetPoint("TOPLEFT", place, "BOTTOMLEFT", 0, -GAP)
    local leftH = place:GetHeight() + GAP + panelCard:GetHeight()
    -- the right: the kind's details, then its colors
    local rows = {}
    for _, d in ipairs(DETAILS) do
        if d[5][key] then rows[#rows + 1] = d end
    end
    local rightH, above = 0, nil
    if #rows > 0 then
        local details = RowsCard(f, "Details", COL_W, #rows, function(card, n)
            local d = rows[n]
            local function warning()
                if d[6] and not d[6]() then
                    return d[7] or (d[2] == "questParchment" and "DialogueUI is not installed."
                        or "This language's spell descriptions are not read yet.")
                end
                return d[7]
            end
            local row = OptionSwitch(card, n, { d[1], d[3], tip = d[4], available = d[6], warning = warning }, d[2])
            if HELD[d[2]] then row.held = true end
        end)
        details:SetPoint("TOPLEFT", f, "TOPLEFT", COL_W + GAP, 0)
        controls[#controls + 1] = { refresh = function()
            details.note:SetText(ns.option("detailsKey") == "ALWAYS" and L["the marked ones always shown"]
                or L["the marked ones while the details key is held"])
        end }
        rightH, above = details:GetHeight(), details
    end
    local groups = COLORS[key]
    if groups then
        local colors = RowsCard(f, "Colors", COL_W, #groups, function(card, n)
            local g = groups[n]
            SwatchRow(card, n, { g[1], g[2], tip = "Click a swatch to choose its color; right-click for its "
                .. "default." }, g[3], g[4], g[5], g[6])
        end)
        if above then
            colors:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -GAP)
            rightH = rightH + GAP + colors:GetHeight()
        else
            colors:SetPoint("TOPLEFT", f, "TOPLEFT", COL_W + GAP, 0)
            rightH = colors:GetHeight()
        end
    end
    f.height = math.max(leftH, rightH)
    -- the details shown only while the key is held carry a mark after their label
    for _, card in ipairs({ f:GetChildren() }) do
        for _, row in ipairs({ card:GetChildren() }) do
            if row.held and row.label then row.label:SetText(row.label:GetText() .. "  \194\183") end
        end
    end
    kindPanels[key] = f
    return f
end

-- All tooltips -------------------------------------------------------------------------

do
    local at = allPage.content
    local fonts = RowsCard(at, "Fonts", COL_W, 4, function(card, n)
        if n == 1 then
            ChoiceRow(card, 1, { "Text font", "Every kind's body text", tip = "The font of every tooltip's text, "
                .. "where a part has none of its own.", setting = optionSetting("bodyFont") }, 150, function()
                return fontItems("Game default")
            end, function() return ns.option("bodyFont") end, function(name) ns.setOption("bodyFont", name) end)
        elseif n == 2 then
            ChoiceRow(card, 2, { "Name font", "Names and titles", tip = "The font of every tooltip's name, where a "
                .. "part has none of its own.", setting = optionSetting("titleFont") }, 150, function()
                local locale = GetLocale()
                return fontItems(locale ~= "koKR" and locale ~= "zhCN" and locale ~= "zhTW"
                    and (ns.Game.addonInstalled("MedalUI")
                        and (tostring(MedalUIFontFace):find("Forum") and "Forum (MedalUI)" or "Marcellus SC (MedalUI)")
                        or ns.Game.addonInstalled("EllesmereUI") and "Expressway Bold (EllesmereUI)")
                    or "Game default")
            end, function() return ns.option("titleFont") end, function(name) ns.setOption("titleFont", name) end)
        elseif n == 3 then
            SegmentRow(card, 3, { "Outline", "Round every part's letters", tip = "An outline round the letters of "
                .. "every part without its own.", setting = optionSetting("outline") },
                { "NONE", "OUTLINE", "THICKOUTLINE" }, { "None", "Thin", "Thick" },
                function() return ns.option("outline") end,
                function(value) ns.setOption("outline", value ~= "NONE" and value or nil) end)
        else
            -- a scale on every part's own size, in steps of 5%; the default is saved as no setting
            SliderRow(card, 4, { "Text size", "Every part's size, scaled", tip = "Scales every part's own text "
                .. "size.", setting = optionSetting("fontScale") }, Range(80, 150, 5), PERCENT, function()
                return math.floor(ns.option("fontScale") * 100 + .5)
            end, function(percent)
                ns.setOption("fontScale", percent ~= 100 and percent / 100 or nil)
            end)
        end
    end)
    fonts:SetPoint("TOPLEFT")
    -- One look for every bar: health, time left, durability, MedalUI's. Each keeps its own
    -- color, which says what the bar is for.
    local bars = RowsCard(at, "Bars", COL_W, 3, function(card, n)
        if n == 1 then
            SegmentRow(card, 1, { "Bar style", "Health, time left, durability", tip = "Well: sunken, with a lit "
                .. "fill. Plain: a flat track.", setting = optionSetting("barStyle") }, { "well", "plain" },
                { "Well", "Plain" }, function() return ns.option("barStyle") end,
                function(value) ns.setOption("barStyle", value ~= "well" and value or nil) end)
        elseif n == 2 then
            SliderRow(card, 2, { "Bar height", "In pixels", tip = "How tall every bar is.",
                setting = optionSetting("barHeight") }, Range(4, 16), PLAIN, function()
                return ns.option("barHeight")
            end, function(value) ns.setOption("barHeight", value ~= 8 and value or nil) end)
        else
            ChoiceRow(card, 3, { "Bar texture", "The fill's texture", tip = "The texture every bar's fill is drawn "
                .. "with; the game's own health bar keeps its own.", setting = optionSetting("barTexture") }, 150,
                function()
                    local items = { { text = "Flat" } }
                    for _, name in ipairs(ns.barTextureNames()) do
                        if name ~= "Flat" then items[#items + 1] = { value = name, text = name } end
                    end
                    return items
                end, function() return ns.option("barTexture") end, function(name) ns.setOption("barTexture", name) end)
        end
    end)
    bars:SetPoint("TOPLEFT", fonts, "BOTTOMLEFT", 0, -GAP)
    -- Shared by every kind; the default is saved as no setting.
    local function panelSize(key)
        return function() return ns.option(key) end, function(value)
            ns.setOption(key, nil)
            if ns.option(key) ~= value then ns.setOption(key, value) end
        end
    end
    local panel = RowsCard(at, "Panel", COL_W, 6, function(card, n)
        if n == 1 then
            -- Gilded, the default, is MedalUI's gold frame and ink; Slate its quieter shading.
            -- DialogueUI's art shows only while that addon is installed.
            ChoiceRow(card, 1, { "Panel style", "Its frame and ink", tip = "Gilded: MedalUI's gold frame and "
                .. "ink. Slate: its quieter shading. DialogueUI's art shows only while that addon is installed.",
                setting = optionSetting("backdropStyle") }, 150, function() return BACKDROP_STYLES end,
                function() return ns.option("backdropStyle") end,
                function(value) ns.setOption("backdropStyle", value) end)
        elseif n == 2 then
            local get, set = panelSize("padding")
            SliderRow(card, 2, { "Padding", "Inside the panel's edge", tip = "The room between the panel's edge "
                .. "and what it shows.", setting = optionSetting("padding") }, Range(8, 32), PLAIN, get, set)
        elseif n == 3 then
            local get, set = panelSize("minWidth")
            SliderRow(card, 3, { "Min width", "The least a panel is", tip = "How wide a panel is at least, "
                .. "however little it shows.", setting = optionSetting("minWidth") }, Range(120, 400, 10), PLAIN,
                get, set)
        elseif n == 4 then
            OptionSwitch(card, 4, { "Icon on the right", "The icon and its badge", tip = "Moves the item or spell "
                .. "icon, and the item level badge under it, to the right of the name." }, "iconRight")
        elseif n == 5 then
            OptionSwitch(card, 5, { "Tint the panel", "In the quality's color", tip = "Washes the panel in the "
                .. "item's quality color, or the spell's school or resource. Off, every panel is neutral; the name "
                .. "keeps its quality color." }, "qualityTint")
        else
            OptionSwitch(card, 6, { "Separators", "The gold dividers", tip = "The gold dividers between sections "
                .. "and the thin rules above other addons' rows. Off, they are hidden along with the space around "
                .. "them." }, "separators")
        end
    end)
    panel:SetPoint("TOPLEFT", at, "TOPLEFT", COL_W + GAP, 0)
    local schools = RowsCard(at, "Colors", COL_W, 1, function(card)
        SwatchRow(card, 1, { "School colors", "Holy, fire, nature, frost...", tip = "Each school's color: "
            .. "spells, damage, resistances." }, ns.Palette.SCHOOLS, "schoolColor", ns.Palette.school)
    end)
    schools:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -GAP)
    allPage:SetContentHeight(math.max(fonts:GetHeight() + GAP + bars:GetHeight(),
        panel:GetHeight() + GAP + schools:GetHeight()))
end

-- Options -------------------------------------------------------------------------------

local kindRows = {}
do
    local at = optionsPage.content
    local layout = RowsCard(at, "Layout", COL_W, 1, function(card)
        SegmentRow(card, 1, { "Tooltips", "Restyled, or the game's", tip = "mdlui_Tooltips: the panel for each "
            .. "kind turned on (its page, or Every kind). Blizzard: the game's own tooltips. Item Equip effects "
            .. "are shortened, and the details modifier adds disenchant results, the spell power breakdown and "
            .. "rates, gathering contents, and IDs.", setting = optionSetting("layout") }, { "pretty", "blizzard" },
            { "mdlui_Tooltips", "Blizzard" }, function() return ns.option("layout") end,
            function(value) ns.setOption("layout", value ~= "pretty" and value or nil) end)
    end)
    layout:SetPoint("TOPLEFT")
    local modifiers = RowsCard(at, "Modifiers", COL_W, 2, function(card, n)
        if n == 1 then
            SegmentRow(card, 1, { "The game's tooltip", "Held, it shows instead", tip = "Hold it to see the game's "
                .. "own tooltip instead of the panel. Never: the panel always.", setting = optionSetting("originalKey") },
                { "CTRL", "ALT", "NONE" }, { "Ctrl", "Alt", "Never" }, function() return ns.option("originalKey") end,
                function(value) ns.setOption("originalKey", value ~= "ALT" and value or nil) end)
        else
            SegmentRow(card, 2, { "Details", "Disenchant, coefficients, IDs", tip = "Shift: hold it to see "
                .. "disenchant results, the spell power breakdown and rates, gathering contents, and IDs. Always: "
                .. "they always show. Each can still be turned off on its kind's Panel sheet.",
                setting = optionSetting("detailsKey") }, { "SHIFT", "ALWAYS" }, { "Shift", "Always" },
                function() return ns.option("detailsKey") end,
                function(value) ns.setOption("detailsKey", value ~= "SHIFT" and value or nil) end)
        end
    end)
    modifiers:SetPoint("TOPLEFT", layout, "BOTTOMLEFT", 0, -GAP)
    local placement = RowsCard(at, "Placement", COL_W, 2, function(card, n)
        if n == 1 then
            OptionSwitch(card, 1, { "Not in combat", "Following the cursor pauses", tip = "Use the default tooltip "
                .. "position during combat, then resume following the cursor afterward." }, "cursorDisableInCombat")
        else
            SliderRow(card, 2, { "Global scale", "Every panel's size", tip = "Scales every mdlui_Tooltips panel, "
                .. "including text, icons, spacing, and bars. 100% is the default. Individual text settings are "
                .. "preserved.", setting = optionSetting("tooltipScale") }, Range(50, 150, 5), PERCENT, function()
                return math.floor(ns.tooltipScale() * 100 + .5)
            end, function(percent)
                ns.setOption("tooltipScale", percent ~= 100 and percent / 100 or nil)
            end)
        end
    end)
    placement:SetPoint("TOPLEFT", modifiers, "BOTTOMLEFT", 0, -GAP)

    -- Every kind of tooltip, its Restyle and its Follow cursor: a row each, the two switches in
    -- columns headed in the band. A kind without one of them shows a dash there.
    local list = ns.TOOLTIP_TYPES
    local every = Panel.Card(at, L["Every kind"], COL_W, BAND_H + 4 + #list * KIND_ROW + 8)
    every:SetPoint("TOPLEFT", at, "TOPLEFT", COL_W + GAP, 0)
    local CURSOR_X, RESTYLE_X = PAD, PAD + 36 + 26
    for i, label in ipairs({ "Cursor", "Restyle" }) do
        local fs = Panel.Plain(every, 10, C.faint)
        fs:SetText(L[label])
        fs:SetPoint("CENTER", every, "TOPRIGHT", -((i == 1 and CURSOR_X or RESTYLE_X) + 18), -BAND_H / 2)
    end
    for i, entry in ipairs(list) do
        local row = Panel.CardRow(every, i, L[entry.label], nil, (i - 1) * KIND_ROW, KIND_ROW)
        row.entry = entry
        local function switchFor(key, x, tip, available)
            if not key then
                local dash = Panel.Plain(row, 12, C.faint)
                dash:SetText("-")
                dash:SetPoint("CENTER", row, "RIGHT", -(x - PAD + 18), 0)
                return
            end
            local switch = Panel.Switch(row, function(self)
                local on = self:GetChecked() and true or false
                ns.setOption(key, nil)
                if ns.option(key) ~= on then ns.setOption(key, on) end
                refresh()
            end)
            switch:SetPoint("RIGHT", row, "RIGHT", -(x - PAD), 0)
            Tip(switch, entry.label, tip, available and BLIZZARD_WARNING)
            controls[#controls + 1] = { refresh = function()
                local on = not available or available()
                switch:SetEnabled(on)
                switch:SetOn(ns.option(key))
            end }
            return switch
        end
        row.restyle = switchFor(entry.restyle, RESTYLE_X, entry.restyle
            and "Draws the mdlui_Tooltips panel. Off, this kind keeps the game's own tooltip, with the details "
                .. "modifier's rows added to it." or nil, notBlizzard)
        row.cursor = switchFor(entry.cursor, CURSOR_X, "Shows this kind's tooltip at the cursor when the game "
            .. "would put it in its default corner; bags and other panels keep theirs. Off, its position is left "
            .. "to the game and other addons.")
        row.label:SetWidth(COL_W - 2 * PAD - 120)
        if not entry.restyle then
            row.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
            Tip(row, entry.label, "Not restyled yet; this kind keeps the game's own tooltip.")
        end
        kindRows[i] = row
    end
    optionsPage:SetContentHeight(math.max(every:GetHeight(),
        layout:GetHeight() + modifiers:GetHeight() + placement:GetHeight() + 2 * GAP))
end

-- Pages ------------------------------------------------------------------------------------

local PAGE_LINES = {
    all = { "All tooltips", "What every kind shares: fonts, the panel, bars and the school colors.",
        "Click any part of the sample to restyle it" },
    options = { "Options", "Which tooltips are restyled, where they open, and the keys that change them.",
        "How every tooltip behaves" },
}

-- a kind's page (on a sheet: "style" or "panel"; the one shown last when nil), "all" or "options"
ShowPage = function(to, sheet)
    if KIND[to] then
        switchTooltipType(to)
        state.page = to
        state.sheet = sheet or state.sheet
    elseif to == "all" or to == "options" then
        state.page = to
    end
    refresh()
end

local function Chip(chip, text)
    chip:SetShown(text ~= nil)
    if text then chip:SetText(L[text]) end
end

refresh = function()
    local page = state.page
    local kind = KIND[page]
    -- the header
    head:SetHeight(kind and HEAD_H + STRIP_H - 4 or HEAD_H)
    for key, b in pairs(sheetTabs) do
        b:SetShown(kind ~= nil)
        b:SetOn(key == state.sheet)
    end
    if kind then
        pageTitle:SetText(L[kind.label])
        crumb:SetText(L[kind.line])
        subtitle:SetText(L["Click any part of the sample to restyle it"])
        local restyled = ns.restyles(kind.restyle)
        Chip(chips[1], restyled and "Restyled" or "The game's tooltip")
        Chip(chips[2], restyled and kind.cursor and ns.option(kind.cursor) and "Follows cursor" or nil)
    else
        local lines = PAGE_LINES[page]
        pageTitle:SetText(L[lines[1]])
        crumb:SetText(L[lines[2]])
        subtitle:SetText(L[lines[3]])
        Chip(chips[1], nil)
        Chip(chips[2], nil)
    end
    -- the pages
    local style, panel = kind and state.sheet == "style", kind and state.sheet == "panel"
    styleSheet:SetShown(style and true or false)
    panelSheet:SetShown(panel and true or false)
    allPage:SetShown(page == "all")
    optionsPage:SetShown(page == "options")
    for key, seg in pairs(examples) do
        seg:SetShown(key == state.tooltipType)
        if key == state.tooltipType then seg:SetValue(not state.lookup and state.sample or nil) end
    end
    if panel then
        local f = kindPanels[page] or BuildKindPanel(page)
        for key, other in pairs(kindPanels) do other:SetShown(key == page) end
        panelSheet:SetContentHeight(f.height)
    end
    -- the sidebar: the page shown lit; a kind left to the game dimmed
    for key, b in pairs(nav) do
        local on = key == page
        b.mark:SetShown(on)
        b.bar:SetShown(on)
        local game = KIND[key] and not ns.restyles(KIND[key].restyle)
        local c = on and C.goldBright or game and C.faint or C.text
        b.label:SetTextColor(c[1], c[2], c[3])
        b.note:SetText(game and L["game's"] or "")
    end
    if style then
        drawSample()
        refreshLookup()
    end
    for _, control in ipairs(controls) do control.refresh() end
    if style then
        paintHighlights()
        showHint()
    end
    changedPill:SetShown(openedVersion ~= nil and ns.settingsVersion ~= openedVersion)
end

editor:SetScript("OnShow", function()
    opened = Copy(type(mdlui_TooltipsDB) == "table" and mdlui_TooltipsDB or {})
    openedVersion = ns.settingsVersion
    Panel.Sound("open")
    refresh()
end)
editor:SetScript("OnHide", function()
    Panel.Sound("close")
    GameTooltip:Hide()
end)
editor:RegisterEvent("GET_ITEM_INFO_RECEIVED")
editor:RegisterEvent("QUEST_DATA_LOAD_RESULT")
editor:SetScript("OnEvent", function(_, event, id, success)
    if not editor:IsShown() then return end
    if ns.util.isSecret(id) or ns.util.isSecret(success) then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if state.tooltipType == "item" and id == state.lookup then refresh() end
    elseif event == "QUEST_DATA_LOAD_RESULT" and success and state.tooltipType == "quest" then
        local sample = samples()[state.sample]
        if sample and sample.questID == id then refresh() end
    end
end)

-- For tests/: the window's pages and pieces.
ns.editorWindow = { frame = editor, state = state, nav = nav, sheetTabs = sheetTabs, examples = examples,
    partCard = partCard, partPicker = partPicker, lookupCard = lookupCard, lookupBox = lookupBox,
    kindPanels = kindPanels, allPage = allPage, optionsPage = optionsPage, kindRows = kindRows,
    undo = undoButton, resetAll = resetAll, changed = changedPill, overlay = overlay,
    select = function(key) selectPart(key) end, show = function(to, sheet) ShowPage(to, sheet) end }

-- Opens the window: a kind's page ("item", ...; on its sheet shown last), "all", "options", or
-- nothing for the page shown last.
function ns.openEditor(where)
    Place()
    if KIND[where] then
        switchTooltipType(where)
        state.page = where
    elseif where == "all" or where == "options" then
        state.page = where
    end
    -- shown already: what it was opened with stays Undo's
    if not editor:IsShown() then editor:Show() end
    editor:Raise()
    refresh()
end
