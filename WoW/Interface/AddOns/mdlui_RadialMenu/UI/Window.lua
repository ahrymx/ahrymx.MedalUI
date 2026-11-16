local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WINDOW
-- The editor window, laid out as Medalluin's Unit Frame Editor (Medalluin/options/editor.lua): a
-- serif plate on its top edge and an x; a caption over each column on a gold rule; down the left, the
-- radials in an ink box (Radial/Editor.lua); in the middle, the canvas, the chosen radial's wheel
-- drawn large (UI/Canvas.lua); at the right, the radial's name and Delete over its tabs:
--   Radial    who gets it, its key, Macro, Copy, Rename (Radial/Editor.lua)
--   Slot      the button chosen on the wheel (Radial/Editor.lua)
--   Catalog   what to put on it; the tab the window opens on (Radial/Editor.lua)
--   Look      how every radial opens and looks, its fonts (here)
-- The footer: + New radial and Import... (while FlareUI's radials are loaded) | what the canvas
-- shows | Undo changes, Close. Built on first open; it remembers where it was moved to
-- (ns.db.global.editorPoint). ns.OpenEditor([tab]) opens it.
--------------------------------------------------
local Panel = ns.SettingsPanel
local C = ns.ui
local S = ns.Settings

-- the Unit Frame Editor's measures
local W, H = 1000, 620
local PAD, LIST_W, BODY_W, TAB_H, FOOT = 14, 160, 270, 24, 58
local TAB_Y = PAD + 24                  -- the caption row's top
local TOP = TAB_Y + TAB_H + 10          -- the list's, the canvas's and the body's top
local BODY_TOP = 64                     -- the tabs' pages, under the name and the tab strip
local PAGE_H = H - TOP - 4 - FOOT - BODY_TOP
local CHIP_W, CHIP_H = 96, 24
local ROW_GAP = 30
local SCALES = { 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5 }
local FONT_SIZES = { 8, 32 }
local TABS = { { "radial", L["Radial"] }, { "slot", L["Slot"] }, { "catalog", L["Catalog"] }, { "look", L["Look"] } }

local frame, tabs, pages, current

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
-- THE LOOK TAB
-- Each option a row: its label at the left, its control at the right, its text in its tooltip.
-- row.Fill() shows the saved value.
--------------------------------------------------
local rows = {}

local function Row(page, y, key)
    local row = Panel.Row(page, y, S:Text(key, "label"))
    row.key = key
    Tipped(row, key)
    rows[#rows + 1] = row
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
local function Choice(page, y, key, field, values, labels)
    local row = Row(page, y, key)
    local seg = Panel.Segment(row, labels, function(i)
        DB()[field] = values[i]
        row.Fill()
        Applied(true)
    end)
    seg:SetPoint("RIGHT", 0, 0)
    for _, b in ipairs(seg.buttons) do Tipped(b, key) end
    function row.Fill()
        local at = 1
        for i, v in ipairs(values) do if DB()[field] == v then at = i end end
        seg:SetValue(at)
    end
    row.buttons = seg.buttons
    return row
end

local function Toggle(page, y, key, get, set)
    local row = Row(page, y, key)
    local check = Panel.Switch(row, function(self) set(self:GetChecked() and true or false) end)
    check:SetPoint("RIGHT", -2, 0)
    Tipped(check, key)
    function row.Fill() check:SetOn(get() and true or false) end
    row.check = check
    return row
end

-- a value stepped through a list (or a range of whole numbers): - value +
local function Stepper(row, values, get, set, text)
    local st = Panel.Stepper(row, 36)
    st:SetPoint("RIGHT", 0, 0)
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
    st.plus:SetScript("OnClick", function() Step(1) end)
    st.minus:SetScript("OnClick", function() Step(-1) end)
    Tipped(st.plus, row.key)
    Tipped(st.minus, row.key)
    local fill = row.Fill
    function row.Fill()
        if fill then fill() end
        local i = At()
        st.value:SetText(text(values[i]))
        st.minus:SetEnabled(i > 1)
        st.plus:SetEnabled(i < #values)
    end
    row.plus, row.minus, row.value = st.plus, st.minus, st.value
    return st
end

local function FontName(face)
    if face == nil or face == ns.GLOBAL_FONT then
        return C_AddOns.IsAddOnLoaded("Medalluin") and L["Medalluin"] or L["Game Font"]
    end
    return face
end

-- a font: its face (a menu) and its size
local function Font(page, y, key, field)
    local row = Row(page, y, key)
    local sizes = {}
    for s = FONT_SIZES[1], FONT_SIZES[2] do sizes[#sizes + 1] = s end
    local st = Stepper(row, sizes, function() return DB()[field].size or 14 end, function(v)
        DB()[field].size = v
        RM():ApplyFonts()
    end, tostring)
    local drop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    drop:SetWidth(104)
    drop:SetPoint("RIGHT", st, "LEFT", -4, 0)
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
    Tipped(drop, key)
    local fill = row.Fill
    function row.Fill()
        fill()
        drop:SetDefaultText(FontName(DB()[field].face))
        drop:GenerateMenu()
    end
    row.drop = drop
    return row
end

local function Caption(page, y, text)
    local cap = Panel.Caption(page, text)
    cap:SetPoint("TOPLEFT", 0, -y)
    return y + 16
end

local function BuildLook(page)
    local note = Panel.Plain(page, 11, C.dim)
    note:SetPoint("TOPLEFT", 0, -2)
    note:SetText(L["These apply to every radial."])
    local y = Caption(page, 24, L["Opening"])
    Choice(page, y, "rm.position", "position", { "cursor", "center" }, { L["Cursor"], L["Centre"] })
    y = y + ROW_GAP
    Choice(page, y, "rm.activation", "activation", { "hold", "toggle" }, S:Text("rm.activation", "choices"))
    y = y + ROW_GAP
    Choice(page, y, "rm.subRadials", "subRadials", { "reset", "remember" }, { L["Reset"], L["Remember"] })
    y = Caption(page, y + ROW_GAP + 6, L["Look"])
    local scale = Row(page, y, "rm.scale")
    Stepper(scale, SCALES, function() return DB().scale or 1 end, function(v)
        DB().scale = v
        Applied(false)
    end, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
    y = y + ROW_GAP
    Toggle(page, y, "rm.names", function() return DB().showNames ~= false end, function(on)
        DB().showNames = on
        Applied(false)
    end)
    y = y + ROW_GAP
    Toggle(page, y, "rm.autoRanks", function() return DB().autoRanks ~= false end, function(on)
        DB().autoRanks = on
        RM().ForgetRanks()
        RM().MarkDirty()
        RM():RadialChanged()
    end)
    y = Caption(page, y + ROW_GAP + 6, L["Fonts"])
    Font(page, y, "rm.font.labels", "labelFont")
    Font(page, y + ROW_GAP, "rm.font.counts", "countFont")
end

local function FillLook()
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
-- TABS
--------------------------------------------------
local function ShowTab(key)
    if not pages[key] then key = "catalog" end
    current = key
    for k, b in pairs(tabs) do b:SetOn(k == key) end
    for k, p in pairs(pages) do p:SetShown(k == key) end
    if key == "look" then FillLook() end
    ShowImport()
end

--------------------------------------------------
-- THE CANVAS'S CHIPS (the footer's "Show on the canvas")
--------------------------------------------------
local CHIPS = {
    { "names", L["Names"],
        L["Every slot's name under it. Off: only the chosen slot's, as the wheel names the one you point at."] },
    { "numbers", L["Numbers"], L["Each slot's place: 1 at the top, then clockwise."] },
    { "empty", L["Empty slot"], L["The next free slot, to drop something on, until the radial is full."] },
}

local function PaintChip(b)
    local on = frame.show[b.key]
    Panel.Paint(b.bg, on and C.selected or C.ink)
    for _, e in ipairs(b.lit) do e:SetShown(on) end
    Panel.Paint(b.swatch, on and C.gold or C.lineStrong)
    local c = on and C.goldBright or C.dim
    b.label:SetTextColor(c[1], c[2], c[3])
end

local function Chips(from)
    frame.show = { names = true, numbers = false, empty = true }
    frame.chips = {}
    for i, chip in ipairs(CHIPS) do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(CHIP_W, CHIP_H)
        b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", from + (i - 1) * (CHIP_W + 4), 10)
        b.key = chip[1]
        b.bg = Panel.Fill(b, "BACKGROUND", C.ink, 1)
        b.bg:SetAllPoints()
        Panel.Outline(b, "BORDER", C.goldDark, 0)
        b.lit = Panel.Outline(b, "OVERLAY", C.goldBright, 0)
        b.swatch = Panel.Fill(b, "ARTWORK", C.gold)
        b.swatch:SetSize(6, 6)
        b.swatch:SetPoint("LEFT", 8, 0)
        b.label = Panel.Serif(b, 11, C.dim)
        b.label:SetPoint("LEFT", b.swatch, "RIGHT", 4, 0)
        b.label:SetPoint("RIGHT", -4, 0)
        b.label:SetText(chip[2])
        b:SetScript("OnClick", function(self)
            ns.ButtonSound()
            frame.show[self.key] = not frame.show[self.key]
            PaintChip(self)
            ns.RadialEditorEmbed.Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            ns.OwnGameTooltip(self, "ANCHOR_TOP")
            GameTooltip:AddLine(chip[2], 1, 1, 1)
            GameTooltip:AddLine(chip[3], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        PaintChip(b)
        frame.chips[i] = b
    end
end

--------------------------------------------------
-- BUILD
--------------------------------------------------
local function Remember()
    local point, _, relative, x, y = frame:GetPoint()
    if not (point and x and y) then return end
    ns.db.global.editorPoint = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
end

local function Build()
    frame = CreateFrame("Frame", "mdluiRadialEditor", UIParent)
    frame:SetSize(W, H)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    -- dragged by any bare part of it to move; where it was left is kept
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
        Remember()
    end)
    local at = ns.db.global.editorPoint
    if type(at) == "table" and at[1] then
        frame:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    Panel.Skin(frame, C.panel)
    frame:Hide()
    tinsert(UISpecialFrames, "mdluiRadialEditor")
    frame:SetScript("OnShow", function()
        ns.WindowOpenSound()
        ShowImport()
    end)
    frame:SetScript("OnHide", ns.WindowCloseSound)

    -- the head: the title on a plate across the top edge, the x
    local plate = CreateFrame("Frame", nil, frame)
    plate:SetHeight(28)
    plate:SetPoint("CENTER", frame, "TOP", 0, 0)
    plate:SetFrameLevel(frame:GetFrameLevel() + 10)
    Panel.Skin(plate, C.ink)
    local title = Panel.Serif(plate, 15, C.goldBright)
    title:SetPoint("CENTER", 0, 0)
    title:SetText(L["Radial Menu"])
    plate:SetWidth(math.ceil(title:GetStringWidth() or 0) + 44)
    frame.title = title
    local close = Panel.UButton(frame, "x", 20, 20, "quiet")
    close.label:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    close:SetPoint("TOPRIGHT", -8, -6)
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.closeX = close

    -- a caption over each column, on the gold rule
    frame.captions = {}
    for i, cap in ipairs({ { PAD + 2, L["Radials"] }, { PAD + LIST_W + 10 + 2, L["Wheel"] },
        { W - PAD - 4 - BODY_W + 2, L["Chosen radial"] } }) do
        local fs = Panel.Caption(frame, cap[2])
        fs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", cap[1], -(TAB_Y + TAB_H - 3))
        frame.captions[i] = fs
    end
    local rule = Panel.Fill(frame, "ARTWORK", C.gold)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", PAD, -(TAB_Y + TAB_H))
    rule:SetPoint("TOPRIGHT", -PAD, -(TAB_Y + TAB_H))

    -- left: the radials' ink box
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", PAD, -TOP)
    list:SetPoint("BOTTOMLEFT", PAD, FOOT)
    list:SetWidth(LIST_W)
    Panel.Skin(list, C.ink)
    frame.list = list

    -- the middle: the canvas
    local stage = CreateFrame("Frame", nil, frame)
    stage:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    stage:SetSize(W - 2 * PAD - LIST_W - 10 - 14 - BODY_W - 4, H - TOP - FOOT)
    frame.stage = stage

    -- right: the body, its tabs under the radial's name
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD - 4, -(TOP + 4))
    body:SetPoint("BOTTOMRIGHT", -PAD - 4, FOOT)
    body:SetWidth(BODY_W)
    frame.body = body
    local strip = CreateFrame("Frame", nil, body)
    strip:SetHeight(22)
    strip:SetPoint("TOPLEFT", 0, -32)
    strip:SetPoint("TOPRIGHT", 0, -32)
    local stripRule = Panel.Fill(strip, "ARTWORK", C.gold)
    stripRule:SetHeight(1)
    stripRule:SetPoint("BOTTOMLEFT", 0, 0)
    stripRule:SetPoint("BOTTOMRIGHT", 0, 0)
    tabs, pages = {}, {}
    local x = 0
    for _, t in ipairs(TABS) do
        local b = Panel.Tab(strip, t[2])
        b:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, 0)
        x = x + b:GetWidth() + 3
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            ShowTab(t[1])
        end)
        tabs[t[1]] = b
        local page = CreateFrame("Frame", nil, body)
        page:SetPoint("TOPLEFT", 0, -BODY_TOP)
        page:SetPoint("BOTTOMRIGHT", 0, 0)
        page:Hide()
        pages[t[1]] = page
    end
    frame.tabs, frame.pages, frame.PAGE_H = tabs, pages, PAGE_H
    frame.look = pages.look
    BuildLook(pages.look)

    -- the footer: + New radial, Import... | what the canvas shows | Undo changes, Close
    local foot = Panel.Fill(frame, "ARTWORK", C.line)
    foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", PAD, FOOT - 8)
    foot:SetPoint("BOTTOMRIGHT", -PAD, FOOT - 8)
    frame.newButton = Panel.UButton(frame, L["+ New radial"], 104, 24, "primary")
    frame.newButton:SetPoint("BOTTOMLEFT", PAD, 10)
    frame.importButton = Panel.UButton(frame, L["Import..."], 80, 24)
    frame.importButton:SetPoint("LEFT", frame.newButton, "RIGHT", 6, 0)
    frame.importButton:SetScript("OnClick", function()
        ns.ButtonSound()
        AskImport()
    end)
    Tipped(frame.importButton, "rm.import")
    local closeFoot = Panel.UButton(frame, L["Close"], 96, 24, "quiet")
    closeFoot:SetPoint("BOTTOMRIGHT", -PAD, 10)
    closeFoot:SetScript("OnClick", function() frame:Hide() end)
    frame.closeButton = closeFoot
    frame.undoButton = Panel.UButton(frame, L["Undo changes"], 110, 24)
    frame.undoButton:SetPoint("RIGHT", closeFoot, "LEFT", -8, 0)
    local from, to = PAD + 104 + 6 + 80 + 18, W - PAD - 96 - 8 - 110 - 18
    for _, dx in ipairs({ from - 9, to + 9 }) do
        local d = Panel.Fill(frame, "ARTWORK", C.line)
        d:SetSize(1, 20)
        d:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", dx, 12)
    end
    Chips(from)
    frame.chipsCaption = Panel.Caption(frame, L["Show on the canvas"])
    frame.chipsCaption:SetPoint("BOTTOMLEFT", frame.chips[1], "TOPLEFT", 2, 4)

    frame.ShowTab = ShowTab
    ns.RadialEditorEmbed.Build(frame)
    ns.editorWindow = frame
end

-- opens the window on a tab ("radial", "slot", "catalog", "look"), or the one it showed last (the
-- Catalog the first time). "options" is Look; "radials" is the radials' tab it showed last, else
-- the Catalog.
function ns.OpenEditor(tab)
    if not ns.db then return end
    if not frame then Build() end
    if tab == "options" then
        tab = "look"
    elseif tab == "radials" then
        tab = current ~= "look" and current or "catalog"
    end
    frame:Show()
    ShowTab(tab or current)   -- (nothing yet: the Catalog)
    ns.RadialEditorEmbed.Refresh()
end

function ns.ToggleEditor()
    if frame and frame:IsShown() then frame:Hide() else ns.OpenEditor() end
end
