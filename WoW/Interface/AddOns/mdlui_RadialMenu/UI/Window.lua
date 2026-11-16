local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WINDOW
-- The editor window, in Medalluin's look: a head with the title, the two tabs and a close button, then
-- the middle box and the right column FlareUI's settings panel gave its Radials tab.
--   Radials   the editor (Radial/Editor.lua): the radials in the right column, the selected one's
--             buttons and Catalog in the middle
--   Options   how a radial opens and looks, its fonts, the FlareUI import; the hovered option's text
--             in the right column
-- Built on first open. ns.OpenEditor([tab]) opens it.
--------------------------------------------------
local Panel = ns.SettingsPanel
local C = ns.ui
local S = ns.Settings

local EDGE, GAP, HEAD = 14, 8, 44
local INNER, MIDDLE_W, RIGHT_W = Panel.INNER, Panel.MIDDLE_W, Panel.RIGHT_W
local BODY_H = 600
local WIDTH = 2 * EDGE + MIDDLE_W + 2 * INNER + GAP + RIGHT_W
local HEIGHT = HEAD + BODY_H + EDGE
local ROW_H, SECTION_GAP = 30, 14
local SCALES = { 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5 }
local FONT_SIZES = { 8, 32 }

local frame, tabs, current
local radialsHost, radialsColumn, built
local options, info

local function RM() return ns.RadialMenu end
local function DB() return ns.db.profile.radialmenu end

--------------------------------------------------
-- THE RIGHT COLUMN ON OPTIONS: the hovered option's label, description and tip
--------------------------------------------------
local function ShowInfo(row)
    if not info then return end
    if not row then
        info.title:SetText(L["Options"])
        info.desc:SetText(L["Point at an option to read what it does."])
        info.tip:SetText("")
        return
    end
    info.title:SetText(S:Text(row, "label"))
    info.desc:SetText(S:Format(S:Text(row, "desc", true) or ""))
    local tip = S:Text(row, "tip", true)
    info.tip:SetText(tip and (L["Tip:"] .. " " .. S:Format(tip)) or "")
end

--------------------------------------------------
-- OPTIONS ROWS
-- Each row is a frame across the page: its label at the left, its control at the right. Pointing
-- at it shows its text in the right column. row.Fill() shows the saved value.
--------------------------------------------------
local rows = {}

local function Hovered(region, key)
    region:HookScript("OnEnter", function() ShowInfo(key) end)
    region:HookScript("OnLeave", function() ShowInfo(nil) end)
end

local function Row(parent, y, key)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    local wash = row:CreateTexture(nil, "BACKGROUND")
    wash:SetAllPoints()
    wash:SetColorTexture(C.raised[1], C.raised[2], C.raised[3], 0.6)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 10, 0)
    row.label:SetText(S:Text(key, "label"))
    row.key = key
    Hovered(row, key)
    rows[#rows + 1] = row
    return row
end

local function Section(parent, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, 15)
    fs:SetPoint("TOPLEFT", 2, -y)
    fs:SetText(text)
    return y + 24
end

-- after an option changes: the radial reads its options when it opens; these redraw what shows now
local function Applied(opening)
    local rm = RM()
    if not rm then return end
    if opening then rm:ApplyOpening() end
    rm:Refresh()
end

-- one of a few values, as a row of buttons
local function Choice(parent, y, key, field, values)
    local row = Row(parent, y, key)
    local labels = S:Text(key, "choices", true) or values
    local buttons = {}
    local x = -6
    for i = #values, 1, -1 do
        local b = Panel.Button(row, labels[i], 0, 22)
        b:SetWidth(b:GetFontString():GetStringWidth() + 24)
        b:SetPoint("RIGHT", x, 0)
        x = x - b:GetWidth() - 4
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            DB()[field] = values[i]
            row.Fill()
            Applied(true)
        end)
        Hovered(b, key)
        buttons[i] = b
    end
    function row.Fill()
        for i, b in ipairs(buttons) do b:SetSelected(DB()[field] == values[i]) end
    end
    row.buttons = buttons
    return row
end

local function Toggle(parent, y, key, get, set)
    local row = Row(parent, y, key)
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("RIGHT", -6, 0)
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        set(on)
    end)
    Hovered(check, key)
    function row.Fill() check:SetChecked(get() and true or false) end
    row.check = check
    return row
end

-- a value stepped through a list (or a range of whole numbers): − value +
local function Stepper(row, values, get, set, text, right)
    local plus = Panel.Button(row, "+", 22, 22)
    plus:SetPoint("RIGHT", right or -6, 0)
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetWidth(46)
    value:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    local minus = Panel.Button(row, "-", 22, 22)
    minus:SetPoint("RIGHT", value, "LEFT", -4, 0)
    local function At()
        local now = get()
        for i, v in ipairs(values) do if math.abs(v - now) < 0.001 then return i end end
        -- a value between steps: the nearest
        local best, at = math.huge, 1
        for i, v in ipairs(values) do if math.abs(v - now) < best then best, at = math.abs(v - now), i end end
        return at
    end
    local function Step(delta)
        local i = math.max(1, math.min(#values, At() + delta))
        ns.ButtonSound()
        set(values[i])
        row.Fill()
    end
    plus:SetScript("OnClick", function() Step(1) end)
    minus:SetScript("OnClick", function() Step(-1) end)
    Hovered(plus, row.key)
    Hovered(minus, row.key)
    local fill = row.Fill
    function row.Fill()
        if fill then fill() end
        local i = At()
        value:SetText(text(values[i]))
        minus:SetEnabled(i > 1)
        plus:SetEnabled(i < #values)
    end
    row.plus, row.minus, row.value = plus, minus, value
    return minus
end

local function FontName(face)
    if face == nil or face == ns.GLOBAL_FONT then
        return C_AddOns.IsAddOnLoaded("Medalluin") and L["Medalluin"] or L["Game Font"]
    end
    return face
end

-- a font: its face (a menu) and its size
local function Font(parent, y, key, field)
    local row = Row(parent, y, key)
    local sizes = {}
    for s = FONT_SIZES[1], FONT_SIZES[2] do sizes[#sizes + 1] = s end
    local leftOf = Stepper(row, sizes, function() return DB()[field].size or 14 end, function(v)
        DB()[field].size = v
        RM():ApplyFonts()
    end, tostring)
    local drop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    drop:SetWidth(170)
    drop:SetPoint("RIGHT", leftOf, "LEFT", -10, 0)
    drop:SetupMenu(function(_, root)
        for _, face in ipairs(ns.FontNames()) do
            root:CreateRadio(FontName(face), function() return (DB()[field].face or ns.GLOBAL_FONT) == face end,
                function()
                    DB()[field].face = face
                    RM():ApplyFonts()
                    row.Fill()
                end)
        end
    end)
    Hovered(drop, key)
    local fill = row.Fill
    function row.Fill()
        fill()
        drop:SetDefaultText(FontName(DB()[field].face))
        drop:GenerateMenu()
    end
    row.drop = drop
    return row
end

--------------------------------------------------
-- IMPORT
--------------------------------------------------
local IMPORT_ERRORS = {
    combat = L["Try again out of combat."],
    none = L["FlareUI has no radials to import."],
    nostore = L["The radials aren't loaded yet. Try again in a moment."],
}

ns.Dialogs["MDLUI_RADIAL_IMPORT"] = {
    text = "%s",
    button1 = L["Import"],
    button2 = L["Cancel"],
    OnAccept = function()
        local count, why = ns.ImportFromFlare()
        if count then
            ns.Print(L["imported %d radials from FlareUI."]:format(count))
            if ns.RadialEditorEmbed then ns.RadialEditorEmbed.Refresh() end
        else
            ns.Print(IMPORT_ERRORS[why] or IMPORT_ERRORS.none)
        end
    end,
    hideOnEscape = true,
}

local function AskImport()
    local count = ns.FlareRadialCount()
    if count == 0 then
        ns.Print(IMPORT_ERRORS.none)
        return
    end
    ns.ShowDialog("MDLUI_RADIAL_IMPORT",
        L["Import %d radials from FlareUI? They're added after the ones you have here."]:format(count))
end

--------------------------------------------------
-- THE OPTIONS PAGE
--------------------------------------------------
local function BuildOptions(page)
    local y = 0
    y = Section(page, y, L["Opening"])
    Choice(page, y, "rm.position", "position", { "cursor", "center" })
    y = y + ROW_H + 4
    Choice(page, y, "rm.activation", "activation", { "hold", "toggle" })
    y = y + ROW_H + 4
    Choice(page, y, "rm.subRadials", "subRadials", { "reset", "remember" })
    y = y + ROW_H + SECTION_GAP

    y = Section(page, y, L["Look"])
    local scale = Row(page, y, "rm.scale")
    Stepper(scale, SCALES, function() return DB().scale or 1 end, function(v)
        DB().scale = v
        Applied(false)
    end, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
    y = y + ROW_H + 4
    Toggle(page, y, "rm.names", function() return DB().showNames ~= false end, function(on)
        DB().showNames = on
        Applied(false)
    end)
    y = y + ROW_H + 4
    Toggle(page, y, "rm.autoRanks", function() return DB().autoRanks ~= false end, function(on)
        DB().autoRanks = on
        RM().ForgetRanks()
        RM().MarkDirty()
        RM():RadialChanged()
    end)
    y = y + ROW_H + SECTION_GAP

    y = Section(page, y, L["Fonts"])
    Font(page, y, "rm.font.labels", "labelFont")
    y = y + ROW_H + 4
    Font(page, y, "rm.font.counts", "countFont")
    y = y + ROW_H + SECTION_GAP

    -- only while FlareUI is enabled: the game loads its saved radials with it
    local importY = y
    local heading = page:CreateFontString(nil, "OVERLAY")
    Panel.Heading(heading, 15)
    heading:SetPoint("TOPLEFT", 2, -importY)
    heading:SetText(L["FlareUI"])
    local import = Row(page, importY + 24, "rm.import")
    local button = Panel.Button(import, L["Import..."], 110, 22)
    button:SetPoint("RIGHT", -6, 0)
    button:SetScript("OnClick", function()
        ns.ButtonSound()
        AskImport()
    end)
    Hovered(button, "rm.import")
    function import.Fill()
        local shown = ns.FlareRadialStore() ~= nil
        heading:SetShown(shown)
        import:SetShown(shown)
    end
    import.button = button
    page.import = import
end

local function FillOptions()
    for _, row in ipairs(rows) do row.Fill() end
    ShowInfo(nil)
end

--------------------------------------------------
-- TABS
--------------------------------------------------
local function ShowTab(key)
    current = key
    for k, b in pairs(tabs) do b:SetSelected(k == key) end
    local radials = key == "radials"
    if radials and not built then
        built = true
        radialsHost:Show()
        ns.RadialEditorEmbed.Build(radialsHost, radialsColumn)
    end
    radialsHost:SetShown(radials)
    radialsColumn:SetShown(radials)
    options:SetShown(not radials)
    info:SetShown(not radials)
    if radials then ns.RadialEditorEmbed.Refresh() else FillOptions() end
end

--------------------------------------------------
-- BUILD
--------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "mdluiRadialEditor", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:Hide()
    Panel.Dress(frame)
    tinsert(UISpecialFrames, "mdluiRadialEditor")
    frame:SetScript("OnShow", ns.WindowOpenSound)
    frame:SetScript("OnHide", ns.WindowCloseSound)

    -- the head: dragged to move the window
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() frame:StartMoving() end)
    head:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(C.goldDark[1], C.goldDark[2], C.goldDark[3], 0.7)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 1, 0)
    rule:SetPoint("BOTTOMRIGHT", -1, 0)
    local title = head:CreateFontString(nil, "OVERLAY")
    Panel.Heading(title, 18)
    title:SetPoint("LEFT", EDGE + 2, 0)
    title:SetText(L["Radial Menu"])

    tabs = {}
    local left = title
    for _, t in ipairs({ { "radials", L["Radials"] }, { "options", L["Options"] } }) do
        local b = Panel.Button(head, t[2], 96, 24)
        b:SetNormalFontObject("GameFontHighlight")
        b:SetPoint("LEFT", left, "RIGHT", left == title and 24 or 6, 0)
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            ShowTab(t[1])
        end)
        tabs[t[1]] = b
        left = b
    end

    local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -6, 0)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- the middle box (the page) and the right column, as FlareUI's panel had them
    local middleBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    middleBox:SetPoint("TOPLEFT", EDGE, -HEAD - EDGE + 4)
    middleBox:SetSize(MIDDLE_W + 2 * INNER, BODY_H - 4)
    Panel.Box(middleBox, 0.30)
    local rightBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    rightBox:SetPoint("TOPLEFT", middleBox, "TOPRIGHT", GAP, 0)
    rightBox:SetPoint("BOTTOMLEFT", middleBox, "BOTTOMRIGHT", GAP, 0)
    rightBox:SetWidth(RIGHT_W)
    Panel.Box(rightBox, 0.40)
    Panel.middleBox, Panel.rightBox = middleBox, rightBox

    radialsHost = CreateFrame("Frame", nil, middleBox)
    radialsHost:SetPoint("TOPLEFT", INNER, -INNER)
    radialsHost:SetPoint("BOTTOMRIGHT", -INNER, INNER)
    radialsHost:SetSize(MIDDLE_W, BODY_H - 4 - 2 * INNER)
    radialsHost:Hide()
    radialsColumn = CreateFrame("Frame", nil, rightBox)
    radialsColumn:SetAllPoints()
    radialsColumn:SetSize(RIGHT_W, BODY_H - 4)
    radialsColumn:Hide()

    options = CreateFrame("Frame", nil, middleBox)
    options:SetPoint("TOPLEFT", INNER + 4, -INNER - 4)
    options:SetPoint("BOTTOMRIGHT", -INNER - 4, INNER)
    options:Hide()
    BuildOptions(options)
    frame.options = options

    info = CreateFrame("Frame", nil, rightBox)
    info:SetPoint("TOPLEFT", 12, -12)
    info:SetPoint("BOTTOMRIGHT", -12, 12)
    info.title = info:CreateFontString(nil, "OVERLAY")
    Panel.Heading(info.title, 16)
    info.title:SetPoint("TOPLEFT")
    info.title:SetPoint("TOPRIGHT")
    info.title:SetJustifyH("LEFT")
    info.desc = info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info.desc:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -10)
    info.desc:SetPoint("TOPRIGHT", info.title, "BOTTOMRIGHT", 0, -10)
    info.desc:SetJustifyH("LEFT")
    info.desc:SetSpacing(3)
    info.tip = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info.tip:SetPoint("TOPLEFT", info.desc, "BOTTOMLEFT", 0, -10)
    info.tip:SetPoint("TOPRIGHT", info.desc, "BOTTOMRIGHT", 0, -10)
    info.tip:SetJustifyH("LEFT")
    info.tip:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    info:Hide()

    frame.tabs, frame.info, frame.radials, frame.column = tabs, info, radialsHost, radialsColumn
    ns.editorWindow = frame
end

-- opens the window on a tab ("radials" or "options"), or the one it showed last
function ns.OpenEditor(tab)
    if not ns.db then return end
    if not frame then Build() end
    frame:Show()
    ShowTab(tab or current or "radials")
end

function ns.ToggleEditor()
    if frame and frame:IsShown() then frame:Hide() else ns.OpenEditor() end
end
