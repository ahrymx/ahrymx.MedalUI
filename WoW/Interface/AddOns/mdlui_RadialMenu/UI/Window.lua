local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WINDOW
-- The editor window, laid out as MedalUI's Settings window (MedalUI/options/window.lua):
--   the head      a bar across the top: the title, a faint subtitle, the x in its own cell
--   the sidebar   a search over the radials, then the radials under their groups' headings, the
--                 ones not on this character, and Options > Every radial (Radial/Editor.lua)
--   the page      a header (its title, where it sits, a (?)) over the page:
--                   a radial: two sheets under the header, Wheel (the wheel, the chosen slot, the
--                   Catalog) and Radial (who gets it, its key, Macro, Copy, Rename, Delete, the keys
--                   on this character), Radial/Editor.lua's; Show at the sheets' right
--                   Every radial: how every radial opens and looks, its fonts (here)
--   the footer    + New radial, Import... (while FlareUI's radials are loaded); "Changed since it
--                 opened", Undo changes, Close
-- Each group of options is a card of rows: a label, a line saying what it does, the control.
-- Built on first open; dragged by its head or any bare part, and it remembers where
-- (ns.db.global.editorPoint). ns.OpenEditor([where]) opens it.
--------------------------------------------------
local Panel = ns.SettingsPanel
local C = ns.ui
local S = ns.Settings

-- the Settings window's measures
local W, H = 1040, 680
local EDGE, BAR_H, SIDE_W, FOOT = 1, 34, 200, 40
local X, RIGHT = EDGE + SIDE_W + 18, 16                  -- the page's left, its right margin
local HEAD_TOP, HEAD_H, STRIP_H = EDGE + BAR_H + 14, 50, 26
local SHEET_TOP = HEAD_TOP + HEAD_H + STRIP_H - 4 + 12   -- a radial's sheets, under the tabs
local PAGE_TOP = HEAD_TOP + HEAD_H + 12                  -- Every radial, under its header
local BOTTOM = EDGE + FOOT + 14
local PAGE_W = W - X - RIGHT
local COL_GAP = 12
local COL_W = math.floor((PAGE_W - COL_GAP) / 2)
local SCALES = { 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5 }
local SIZES = {}
for s = 8, 32 do SIZES[#SIZES + 1] = s end
local SHEETS = { { "wheel", L["Wheel"] }, { "radial", L["Radial"] } }
-- older names for where to open: the tabs the window had
local SHEET_OF = { wheel = "wheel", slot = "wheel", catalog = "wheel", radial = "radial" }

local frame
local page, sheet = "radial", "wheel"

local function RM() return ns.RadialMenu end
local function DB() return ns.db.profile.radialmenu end

-- a control's tooltip from the copy: label, description, tip
local function Tipped(region, key)
    region:HookScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(S:Text(key, "label"), 1, 1, 1)
        local desc, tip = S:Text(key, "desc", true), S:Text(key, "tip", true)
        if desc then GameTooltip:AddLine(S:Format(desc), nil, nil, nil, true) end
        if tip then GameTooltip:AddLine(L["Tip:"] .. " " .. S:Format(tip), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    region:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

--------------------------------------------------
-- EVERY RADIAL (the Options page)
-- A card for each group; each option a row, its copy in its tooltip. row.Fill() shows the saved
-- value; frame.lookRows[key] is each row.
--------------------------------------------------
local rows = {}

-- name: the row's own (a font's size row shares its font's copy), else the copy's key
local function Row(card, n, key, line, name)
    local row = Panel.CardRow(card, n, S:Text(key, "label"), line)
    row.key = name or key
    Tipped(row, key)
    rows[#rows + 1] = row
    frame.lookRows[row.key] = row
    return row
end

-- after an option changes: the radial reads its options when it opens; these redraw what shows now
local function Applied(opening)
    local rm = RM()
    if not rm then return end
    if opening then rm:ApplyOpening() end
    rm:Refresh()
end

-- one of two answers, side by side (short words; the tooltip has the long ones)
local function Choice(card, n, key, line, field, values, labels)
    local row = Row(card, n, key, line)
    local seg = Panel.Segment(row, labels, function(i)
        DB()[field] = values[i]
        row.Fill()
        Applied(true)
    end)
    row:Hold(seg)
    for _, b in ipairs(seg.buttons) do Tipped(b, key) end
    function row.Fill()
        local at = 1
        for i, v in ipairs(values) do if DB()[field] == v then at = i end end
        seg:SetValue(at)
    end
    row.buttons = seg.buttons
    return row
end

local function Toggle(card, n, key, line, get, set)
    local row = Row(card, n, key, line)
    local check = Panel.Switch(row, function(self) set(self:GetChecked() and true or false) end)
    row:Hold(check)
    Tipped(check, key)
    function row.Fill() check:SetOn(get() and true or false) end
    row.check = check
    return row
end

-- a value on a rail: - value +
local function Slider(card, n, key, line, values, get, set, text, name)
    local row = Row(card, n, key, line, name)
    local st = Panel.Slider(row, values, text, get, set)
    row:Hold(st)
    Tipped(st.plus, key)
    Tipped(st.minus, key)
    Tipped(st.track, key)
    function row.Fill() st:Fill() end
    row.plus, row.minus, row.value = st.plus, st.minus, st.value
    return row
end

local function FontName(face)
    if face == nil or face == ns.GLOBAL_FONT then
        return C_AddOns.IsAddOnLoaded("MedalUI") and L["MedalUI"] or L["Game Font"]
    end
    return face
end

-- a font's face, from a menu; its size is the row under it
local function Font(card, n, key, line, field)
    local row = Row(card, n, key, line)
    local drop = Panel.Choice(row, 150, function(_, root)
        for _, face in ipairs(ns.FontNames()) do
            root:CreateRadio(FontName(face), function() return (DB()[field].face or ns.GLOBAL_FONT) == face end,
                function()
                    DB()[field].face = face
                    RM():ApplyFonts()
                    row.Fill()
                end)
        end
    end)
    row:Hold(drop)
    Tipped(drop, key)
    function row.Fill()
        drop:SetValueText(FontName(DB()[field].face))
        drop:GenerateMenu()
    end
    row.drop = drop
    return row
end

local function CardHeight(n) return Panel.BAND_H + 4 + n * Panel.ROW_H + 8 end

local function BuildOptions(at)
    local opening = Panel.Card(at, L["Opening"], COL_W, CardHeight(3))
    opening:SetPoint("TOPLEFT", 0, 0)
    Choice(opening, 1, "rm.position", L["Where the wheel opens"], "position",
        { "cursor", "center" }, { L["Cursor"], L["Centre"] })
    Choice(opening, 2, "rm.activation", L["Hold the key, or press it once"], "activation",
        { "hold", "toggle" }, S:Text("rm.activation", "choices"))
    Choice(opening, 3, "rm.subRadials", L["Its first button again, or the one you left"], "subRadials",
        { "reset", "remember" }, { L["Reset"], L["Remember"] })

    local look = Panel.Card(at, L["Look"], COL_W, CardHeight(3))
    look:SetPoint("TOPLEFT", opening, "BOTTOMLEFT", 0, -COL_GAP)
    Slider(look, 1, "rm.scale", L["The whole radial's size"], SCALES,
        function() return DB().scale or 1 end,
        function(v)
            DB().scale = v
            Applied(false)
        end,
        function(v) return math.floor(v * 100 + 0.5) .. "%" end)
    Toggle(look, 2, "rm.names", L["The button you point at shows its name"],
        function() return DB().showNames ~= false end,
        function(on)
            DB().showNames = on
            Applied(false)
        end)
    Toggle(look, 3, "rm.autoRanks", L["A spell casts the best rank you know"],
        function() return DB().autoRanks ~= false end,
        function(on)
            DB().autoRanks = on
            RM().ForgetRanks()
            RM().MarkDirty()
            RM():RadialChanged()
        end)

    local fonts = Panel.Card(at, L["Fonts"], PAGE_W - COL_W - COL_GAP, CardHeight(4))
    fonts:SetPoint("TOPRIGHT", 0, 0)
    for i, f in ipairs({ { "rm.font.labels", "labelFont", L["The name of the button you point at"] },
        { "rm.font.counts", "countFont", L["Item counts and spell charges"] } }) do
        Font(fonts, 2 * i - 1, f[1], f[3], f[2])
        local size = Slider(fonts, 2 * i, f[1], nil, SIZES,
            function() return DB()[f[2]].size or 14 end,
            function(v)
                DB()[f[2]].size = v
                RM():ApplyFonts()
            end, tostring, f[1] .. ".size")
        size.label:SetText(L["Size"])
    end
end

local function FillOptions()
    for _, row in ipairs(rows) do row.Fill() end
end

--------------------------------------------------
-- IMPORT (the footer's Import...)
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

-- only while FlareUI is enabled: the game loads its saved radials with it
local function ShowImport()
    if frame then frame.importButton:SetShown(ns.FlareRadialStore() ~= nil) end
end

--------------------------------------------------
-- PAGES AND SHEETS
--------------------------------------------------
-- a radial (on a sheet: "wheel" or "radial"; the one shown last when nil), or "options"
local function ShowPage(to, toSheet)
    page = to == "options" and "options" or "radial"
    sheet = toSheet or sheet
    local radial = page == "radial"
    frame.page, frame.sheet = page, sheet
    frame.head:SetHeight(radial and HEAD_H + STRIP_H - 4 or HEAD_H)
    for k, b in pairs(frame.tabs) do
        b:SetShown(radial)
        b:SetOn(k == sheet)
    end
    frame.showLabel:SetShown(radial and sheet == "wheel")
    frame.showSeg:SetShown(radial and sheet == "wheel")
    for k, f in pairs(frame.sheets) do f:SetShown(radial and k == sheet) end
    frame.options:SetShown(not radial)
    if not radial then
        frame.pageTitle:SetText(L["Every radial"])
        frame.crumb:SetText(L["Options"] .. "   \194\183   " .. L["Shared by every radial"])
        frame.moreText = L["How every radial opens and looks. Each radial's own buttons, who gets it and its key "
            .. "are on its page."]
        FillOptions()
    end
    ShowImport()
    ns.RadialEditorEmbed.Refresh()
end

--------------------------------------------------
-- SHOW (the canvas's: the Wheel sheet's, at the tabs' right)
--------------------------------------------------
local SHOW = {
    { "names", L["Names"],
        L["Every slot's name under it. Off: only the chosen slot's, as the wheel names the one you point at."] },
    { "numbers", L["Numbers"], L["Each slot's place: 1 at the top, then clockwise."] },
    { "empty", L["Empty slot"], L["The next free slot, to drop something on, until the radial is full."] },
}

local function BuildShow(head)
    frame.show = { names = true, numbers = false, empty = true }
    local labels = {}
    for i, s in ipairs(SHOW) do labels[i] = s[2] end
    local seg
    seg = Panel.Segment(head, labels, function(i, b)
        frame.show[b.key] = not frame.show[b.key]
        seg:SetOn(i, frame.show[b.key])
        ns.RadialEditorEmbed.Refresh()
    end)
    seg:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 3)
    for i, b in ipairs(seg.buttons) do
        b.key = SHOW[i][1]
        seg:SetOn(i, frame.show[b.key])
        b:SetScript("OnEnter", function(self)
            ns.OwnGameTooltip(self, "ANCHOR_TOP")
            GameTooltip:AddLine(SHOW[i][2], 1, 1, 1)
            GameTooltip:AddLine(SHOW[i][3], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    frame.showSeg, frame.chips = seg, seg.buttons
    frame.showLabel = Panel.Plain(head, 12, C.dim)
    frame.showLabel:SetText(L["Show"])
    frame.showLabel:SetPoint("RIGHT", seg, "LEFT", -8, 0)
end

--------------------------------------------------
-- BUILD
--------------------------------------------------
local function Remember()
    local point, _, relative, x, y = frame:GetPoint()
    if not (point and x and y) then return end
    ns.db.global.editorPoint = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
end

-- a region that drags the window; where it is left is kept
local function Grip(region)
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function() frame:StartMoving() end)
    region:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
        Remember()
    end)
end

-- a bar of the window's chrome (its head or footer), a hairline on its inner edge
local function Bar(top)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", EDGE, top and -EDGE or EDGE)
    bar:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", -EDGE, top and -EDGE or EDGE)
    bar:SetHeight(top and BAR_H or FOOT)
    bar:SetFrameLevel(frame:GetFrameLevel() + 5)
    Panel.Fill(bar, "BACKGROUND", C.ink, 1):SetAllPoints()
    local rule = Panel.Fill(bar, "BORDER", C.line)
    rule:SetHeight(1)
    rule:SetPoint(top and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
    rule:SetPoint(top and "BOTTOMRIGHT" or "TOPRIGHT", 0, 0)
    return bar
end

-- the head: the title, the subtitle, the x (red under the pointer)
local function Head()
    local bar = Bar(true)
    Grip(bar)
    frame.title = Panel.Serif(bar, 15, C.goldBright)
    frame.title:SetPoint("LEFT", 14, 0)
    frame.title:SetText(L["Radial Menu"])
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = get and get("mdlui_RadialMenu", "Version")
    frame.subtitle = Panel.Plain(bar, 11, C.faint)
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 10, -1)
    frame.subtitle:SetText(L["Editor"] .. (version and ("  \194\183  " .. version) or ""))
    local x = CreateFrame("Button", nil, bar)
    x:SetSize(BAR_H, BAR_H - 1)
    x:SetPoint("TOPRIGHT", 0, 0)
    local lit = Panel.Fill(x, "BACKGROUND", C.red, 1)
    lit:SetAllPoints()
    lit:Hide()
    local seam = Panel.Fill(x, "BORDER", C.line)
    seam:SetWidth(1)
    seam:SetPoint("TOPLEFT", 0, 0)
    seam:SetPoint("BOTTOMLEFT", 0, 0)
    x.glyph = x:CreateTexture(nil, "ARTWORK")
    x.glyph:SetTexture(Panel.ART .. "Close")
    x.glyph:SetSize(14, 14)
    x.glyph:SetPoint("CENTER", 0, 0)
    x.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    x:SetScript("OnClick", function() frame:Hide() end)
    x:SetScript("OnEnter", function(self)
        lit:Show()
        self.glyph:SetVertexColor(0.949, 0.847, 0.784, 1)
    end)
    x:SetScript("OnLeave", function(self)
        lit:Hide()
        self.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    end)
    frame.closeX = x
end

-- the sidebar: its search; the editor fills frame.nav with the radials
local function Sidebar()
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", EDGE, -(EDGE + BAR_H))
    side:SetPoint("BOTTOMLEFT", EDGE, EDGE + FOOT)
    side:SetWidth(SIDE_W)
    Panel.Fill(side, "BACKGROUND", C.ink, 1):SetAllPoints()
    local rule = Panel.Fill(side, "BORDER", C.line)
    rule:SetWidth(1)
    rule:SetPoint("TOPRIGHT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.side = side
    frame.sideSearch = Panel.Search(side, SIDE_W - 23, 26, L["Search radials"], function()
        if frame:IsShown() then ns.RadialEditorEmbed.Refresh() end
    end)
    frame.sideSearch:SetPoint("TOPLEFT", 11, -10)
    local nav = CreateFrame("Frame", nil, side)
    nav:SetPoint("TOPLEFT", 0, -(10 + 26 + 4))
    nav:SetPoint("BOTTOMRIGHT", -1, 4)
    frame.nav = nav
    frame.navRows = math.floor((H - 2 * EDGE - BAR_H - FOOT - (10 + 26 + 4) - 4) / 24)
end

-- the page's header: its title, where it sits and a (?), a hairline under; the sheets' tabs and
-- Show along its foot on a radial's page
local function Header()
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", X, -HEAD_TOP)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -RIGHT, -HEAD_TOP)
    head:SetHeight(HEAD_H + STRIP_H - 4)
    frame.head = head
    frame.pageTitle = Panel.Serif(head, 20, C.text)
    frame.pageTitle:SetPoint("TOPLEFT", 0, -2)
    frame.pageTitle:SetWordWrap(false)
    frame.crumb = Panel.Plain(head, 12, C.faint)
    frame.crumb:SetPoint("TOPLEFT", 0, -28)
    frame.crumb:SetWordWrap(false)
    local q = CreateFrame("Button", nil, head)
    q:SetSize(22, 16)
    q:SetPoint("LEFT", frame.crumb, "RIGHT", 6, 0)
    q.text = Panel.Plain(q, 12, C.gold)
    q.text:SetPoint("CENTER", 0, 0)
    q.text:SetText("(?)")
    q:SetScript("OnEnter", function(self)
        self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3])
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(frame.pageTitle:GetText() or "", 1, 1, 1)
        GameTooltip:AddLine(frame.moreText or "", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    q:SetScript("OnLeave", function(self)
        self.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        GameTooltip:Hide()
    end)
    frame.more = q
    local rule = Panel.Fill(head, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.tabs = {}
    local x = 0
    for _, s in ipairs(SHEETS) do
        local b = Panel.SheetTab(head, s[2])
        b:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", x, 1)
        x = x + b:GetWidth() + 2
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            ShowPage("radial", s[1])
        end)
        frame.tabs[s[1]] = b
    end
    BuildShow(head)
end

-- the footer: + New radial, Import... at the left; while something changed, a pill saying so;
-- Undo changes, Close at the right
local function Footer()
    local bar = Bar(false)
    frame.foot = bar
    frame.newButton = Panel.UButton(bar, L["+ New radial"], 112, 26, "primary")
    frame.newButton:SetPoint("LEFT", 11, 0)
    frame.importButton = Panel.UButton(bar, L["Import..."], 84, 26)
    frame.importButton:SetPoint("LEFT", frame.newButton, "RIGHT", 6, 0)
    frame.importButton:SetScript("OnClick", function()
        ns.ButtonSound()
        AskImport()
    end)
    Tipped(frame.importButton, "rm.import")
    frame.closeButton = Panel.UButton(bar, L["Close"], 64, 26, "quiet")
    frame.closeButton:SetPoint("RIGHT", -8, 0)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)
    frame.undoButton = Panel.UButton(bar, L["Undo changes"], 120, 26)
    frame.undoButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -6, 0)
    local pill = CreateFrame("Frame", nil, bar)
    pill:SetHeight(24)
    pill:SetPoint("RIGHT", frame.undoButton, "LEFT", -10, 0)
    Panel.Fill(pill, "BACKGROUND", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.10 }, 1):SetAllPoints()
    Panel.Outline(pill, "BORDER", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.35 }, 0)
    local dot = pill:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(Panel.ART .. "Round")
    dot:SetSize(7, 7)
    dot:SetPoint("LEFT", 10, 0)
    dot:SetVertexColor(C.goldBright[1], C.goldBright[2], C.goldBright[3], 1)
    pill.text = Panel.Plain(pill, 11, C.goldBright)
    pill.text:SetPoint("LEFT", dot, "RIGHT", 7, 0)
    pill.text:SetText(L["Changed since it opened"])
    pill:SetWidth(10 + 7 + 7 + math.ceil(pill.text:GetStringWidth() or 0) + 10)
    pill:Hide()
    frame.changed = pill
end

local function Build()
    frame = CreateFrame("Frame", "mdluiRadialEditor", UIParent)
    frame:SetSize(W, H)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    Grip(frame)
    local at = ns.db.global.editorPoint
    if type(at) == "table" and at[1] then
        frame:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    -- the page's tone; a hairline edge, a faint gold ring outside it
    Panel.Fill(frame, "BACKGROUND", C.page, 1):SetAllPoints()
    Panel.Outline(frame, "BORDER", C.lineStrong, 0)
    Panel.Outline(frame, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.35 }, -1)
    frame:Hide()
    tinsert(UISpecialFrames, "mdluiRadialEditor")
    frame:SetScript("OnShow", function()
        ns.WindowOpenSound()
        ShowImport()
    end)
    frame:SetScript("OnHide", ns.WindowCloseSound)

    Head()
    Sidebar()
    Header()
    Footer()

    -- a radial's sheets, and Every radial
    frame.sheets = {}
    for _, s in ipairs(SHEETS) do
        local f = CreateFrame("Frame", nil, frame)
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", X, -SHEET_TOP)
        f:SetSize(PAGE_W, H - SHEET_TOP - BOTTOM)
        f:Hide()
        frame.sheets[s[1]] = f
    end
    local options = CreateFrame("Frame", nil, frame)
    options:SetPoint("TOPLEFT", frame, "TOPLEFT", X, -PAGE_TOP)
    options:SetSize(PAGE_W, H - PAGE_TOP - BOTTOM)
    options:Hide()
    frame.options, frame.look, frame.lookRows = options, options, {}
    BuildOptions(options)

    frame.ShowPage = ShowPage
    frame.page, frame.sheet = page, sheet
    ns.RadialEditorEmbed.Build(frame)
    ns.editorWindow = frame
end

-- opens the window: "options" (or "look") on Every radial; a sheet ("wheel", "radial"; the old
-- tabs "slot" and "catalog" are the Wheel's) on the chosen radial; "radials" on the chosen radial's
-- sheet shown last; nothing on the page shown last (the Wheel the first time)
function ns.OpenEditor(where)
    if not ns.db then return end
    if not frame then Build() end
    frame:Show()
    if where == "options" or where == "look" then
        ShowPage("options")
    elseif SHEET_OF[where] then
        ShowPage("radial", SHEET_OF[where])
    elseif where == "radials" then
        ShowPage("radial")
    else
        ShowPage(page)
    end
end

function ns.ToggleEditor()
    if frame and frame:IsShown() then frame:Hide() else ns.OpenEditor() end
end
