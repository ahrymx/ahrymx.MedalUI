-- The pieces the window (UI/Editor.lua) is built from: Medalluin's Settings window's
-- (Medalluin/options/controls.lua and window.lua), as mdlui_RadialMenu copies them
-- (its UI/Panel.lua); copied again here, so this addon stands alone. A card is a
-- title band over rows; a row is its label, a line under it saying what it does,
-- and its control at the right. The pill, the segment, the dropdown box, the
-- slider, the search box and the sheet tab are the Settings window's; so is the
-- art in art/ui.
--   ns.Panel         Fill, Paint, Outline, Inset, Heading, Serif, Plain, UButton,
--                    Chip, Card, InBand, CardRow, Switch, Segment, Slider, Choice,
--                    Search, SheetTab; and this addon's own: Swatch, Scroller
--   ns.PanelColors   Medalluin's palette (ns.ui is the panels' renderer)
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\mdlui_Tooltips\\art\\ui\\"
local SERIF = "Interface\\AddOns\\Medalluin\\media\\fonts\\MarcellusSC-Regular.ttf"

-- Medalluin's palette (core.lua and options/controls.lua)
local C = {
    gold = { 0.769, 0.647, 0.341 },
    goldDark = { 0.541, 0.439, 0.204 },
    goldBright = { 0.878, 0.722, 0.290 },
    ink = { 0.071, 0.067, 0.063 },
    well = { 0.051, 0.047, 0.039 },
    page = { 0.090, 0.082, 0.063 },
    raised = { 0.118, 0.106, 0.086 },
    line = { 0.169, 0.153, 0.125 },
    lineStrong = { 0.239, 0.212, 0.165 },
    text = { 0.949, 0.918, 0.824 },
    dim = { 0.70, 0.66, 0.55 },
    selected = { 0.204, 0.165, 0.086 },     -- a chosen row, tab or chip
    faint = { 0.490, 0.459, 0.384 },        -- the least of the text
    red = { 0.471, 0.094, 0.078 },
    redHover = { 0.580, 0.125, 0.098 },
    lift = { 0.949, 0.918, 0.824, 0.045 },  -- under the pointer
    lift2 = { 0.949, 0.918, 0.824, 0.08 },  -- pressed
}
ns.PanelColors = C

local Panel = { ART = ART }
ns.Panel = Panel
local NONE = { 0, 0, 0, 0 }
local BAND_H, CARD_PAD, ROW_H = 36, 12, 44
Panel.BAND_H, Panel.CARD_PAD, Panel.ROW_H = BAND_H, CARD_PAD, ROW_H

function Panel.Sound(kind)
    if not (PlaySound and SOUNDKIT) then return end
    local id = ({ click = SOUNDKIT.U_CHAT_SCROLL_BUTTON, open = SOUNDKIT.IG_CHARACTER_INFO_OPEN,
        close = SOUNDKIT.IG_CHARACTER_INFO_CLOSE, on = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
        off = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF })[kind]
    if id then PlaySound(id) end
end

function Panel.Fill(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end
local Fill = Panel.Fill

-- a texture, or each of an outline's, recoloured
function Panel.Paint(t, color)
    if t.SetColorTexture then
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        return
    end
    for _, e in ipairs(t) do e:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
end
local Paint = Panel.Paint

-- a one-pixel line round a frame, inset
function Panel.Outline(parent, layer, color, inset, sub)
    inset = inset or 0
    local t = {}
    for i = 1, 4 do t[i] = Fill(parent, layer, color, sub) end
    t[1]:SetPoint("TOPLEFT", inset, -inset)
    t[1]:SetPoint("TOPRIGHT", -inset, -inset)
    t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT", inset, inset)
    t[2]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT", inset, -inset)
    t[3]:SetPoint("BOTTOMLEFT", inset, inset)
    t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT", -inset, -inset)
    t[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
    t[4]:SetWidth(1)
    return t
end
local Outline = Panel.Outline

-- a fill inset a pixel from its frame's edges
function Panel.Inset(t, x, y)
    t:SetPoint("TOPLEFT", x or 1, -(y or 1))
    t:SetPoint("BOTTOMRIGHT", -(x or 1), y or 1)
    return t
end
local Inset = Panel.Inset

-- Medalluin's serif for a heading, at size, while Medalluin is there and the
-- client's letters are Latin; else the game's own face.
local LATIN = not ({ koKR = true, zhCN = true, zhTW = true, ruRU = true })[GetLocale and GetLocale() or "enUS"]
function Panel.Heading(fs, size, color)
    local serif = LATIN and ns.Game and ns.Game.addonInstalled and ns.Game.addonInstalled("Medalluin")
    if not (serif and fs:SetFont(SERIF, size or 14, "")) then
        fs:SetFontObject(GameFontNormal)
        local face = fs:GetFont()
        if face then fs:SetFont(face, size or 14, "") end
    end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    color = color or C.goldBright
    fs:SetTextColor(color[1], color[2], color[3])
end

-- the console's serif (headings, buttons, names), or the game's plain face (reading)
function Panel.Serif(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, size, color or C.text)
    fs:SetJustifyH("LEFT")
    return fs
end
function Panel.Plain(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local face, _, flags = fs:GetFont()
    if face then fs:SetFont(face, size or 12, flags) end
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH("LEFT")
    return fs
end
local Plain = Panel.Plain

-- A button in one of the Settings window's four styles: primary (gold, the one main action),
-- secondary, quiet (no box until the pointer is on it) and danger. Its text is a serif in its own
-- font string (b.label), so b:SetText works as on any button. Faded while disabled.
local STYLES = {
    primary = { rest = C.gold, hover = C.goldBright, press = { 0.659, 0.541, 0.259 },
        edge = C.goldBright, edgeLit = C.goldBright, text = C.ink, lit = C.ink },
    secondary = { rest = C.raised, hover = { 0.149, 0.133, 0.106 }, press = { 0.078, 0.071, 0.055 },
        edge = C.lineStrong, edgeLit = C.goldDark, text = C.gold, lit = C.goldBright },
    quiet = { rest = NONE, hover = C.lift, press = C.lift2, edge = NONE, edgeLit = NONE, text = C.dim, lit = C.text },
    danger = { rest = C.red, hover = C.redHover, press = { 0.369, 0.071, 0.059 },
        edge = { 0.604, 0.200, 0.149 }, edgeLit = { 0.604, 0.200, 0.149 },
        text = { 0.949, 0.847, 0.784 }, lit = { 0.949, 0.847, 0.784 } },
}
function Panel.UButton(parent, label, width, height, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height or 24)
    b.bg = Fill(b, "BACKGROUND", C.raised, 1)
    b.bg:SetAllPoints()
    b.edge = Outline(b, "BORDER", C.lineStrong, 0)
    local fs = b:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, 12, C.gold)
    fs:SetPoint("CENTER", 0, 0)
    b:SetFontString(fs)
    b.label = fs
    b:SetText(label or "")
    b.style = STYLES[style] and style or "secondary"
    function b:Paint_(state)
        local s = STYLES[self.style]
        state = state or "rest"
        Paint(self.bg, s[state])
        Paint(self.edge, state ~= "rest" and s.edgeLit or s.edge)
        local c = state == "rest" and s.text or s.lit
        self.label:SetTextColor(c[1], c[2], c[3])
        self.label:ClearAllPoints()
        self.label:SetPoint("CENTER", 0, state == "press" and -1 or 0)
        self:SetAlpha(self:IsEnabled() and 1 or 0.4)
    end
    b:SetScript("OnEnter", function(self) if self:IsEnabled() then self:Paint_("hover") end end)
    b:SetScript("OnLeave", function(self) self:Paint_("rest") end)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:Paint_("press") end end)
    b:SetScript("OnMouseUp", function(self) self:Paint_(self:IsMouseOver() and "hover" or "rest") end)
    b:SetScript("OnEnable", function(self) self:Paint_("rest") end)
    b:SetScript("OnDisable", function(self) self:Paint_("rest") end)
    b:Paint_("rest")
    return b
end

-- a small word in a gold outline, after a page's title (a kind restyled, following the cursor)
function Panel.Chip(parent, text)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(16)
    Outline(chip, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.45 }, 0)
    chip.text = Plain(chip, 10, C.gold)
    chip.text:SetPoint("CENTER", 0, 0)
    function chip:SetText(t)
        self.text:SetText(t or "")
        self:SetWidth(math.ceil(self.text:GetStringWidth() or 0) + 12)
    end
    chip:SetText(text)
    return chip
end

-- A card, a step lighter than the page: its title in a band across its top, a hairline under the
-- band; card.note, faint, after the title. Sized by the caller before its rows go in.
function Panel.Card(parent, title, width, height)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, height)
    Fill(card, "BACKGROUND", C.raised, 1):SetAllPoints()
    Outline(card, "BORDER", C.line, 0)
    local rule = Fill(card, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 1, -BAND_H)
    rule:SetPoint("TOPRIGHT", -1, -BAND_H)
    card.title = Panel.Serif(card, 14, C.text)
    card.title:SetPoint("LEFT", card, "TOPLEFT", CARD_PAD, -BAND_H / 2)
    card.title:SetText(title or "")
    card.note = Plain(card, 10, C.faint)
    card.note:SetPoint("LEFT", card.title, "RIGHT", 10, 0)
    card.note:SetWordWrap(false)
    return card
end

-- a region in a card's band: at its right (x in from the edge), or after its title (after = true)
function Panel.InBand(card, region, x, after)
    region:ClearAllPoints()
    if after then
        region:SetPoint("LEFT", card.title, "RIGHT", x or 8, 0)
    else
        region:SetPoint("RIGHT", card, "TOPRIGHT", -(x or CARD_PAD), -BAND_H / 2)
    end
end

-- Row n of a card (from 1, under its band): its label, its line in dim under it, a hairline over
-- it after the first; it lifts under the pointer. row:Hold(control, width) puts the control at the
-- right and keeps the words clear of it. height: a row of its own height (rows under it then start
-- at top, in pixels under the band, instead of at n).
function Panel.CardRow(card, n, label, line, top, height)
    local row = CreateFrame("Frame", nil, card)
    top = BAND_H + 4 + (top or (n - 1) * ROW_H)
    row:SetPoint("TOPLEFT", CARD_PAD, -top)
    row:SetPoint("TOPRIGHT", -CARD_PAD, -top)
    row:SetHeight(height or ROW_H)
    row:EnableMouse(true)
    if n > 1 then
        local hair = Fill(row, "BACKGROUND", C.line, 2)
        hair:SetHeight(1)
        hair:SetPoint("TOPLEFT", -(CARD_PAD - 1), 0)
        hair:SetPoint("TOPRIGHT", CARD_PAD - 1, 0)
    end
    row.lift = Fill(row, "BACKGROUND", C.lift, 1)
    row.lift:SetPoint("TOPLEFT", -(CARD_PAD - 1), 0)
    row.lift:SetPoint("BOTTOMRIGHT", CARD_PAD - 1, 0)
    row.lift:Hide()
    row:SetScript("OnEnter", function(self) self.lift:Show() end)
    row:SetScript("OnLeave", function(self) self.lift:Hide() end)
    row.label = Plain(row, 12, C.text)
    row.label:SetWordWrap(false)
    row.line = Plain(row, 11, C.dim)
    row.line:SetWordWrap(false)
    if line then
        row.label:SetPoint("TOPLEFT", 0, -8)
        row.line:SetPoint("TOPLEFT", 0, -25)
    else
        row.label:SetPoint("LEFT", 0, 0)
    end
    row.label:SetText(label or "")
    row.line:SetText(line or "")
    local room = card:GetWidth() - 2 * CARD_PAD
    row.label:SetWidth(room)
    row.line:SetWidth(room)
    function row:Hold(control, width)
        control:SetParent(self)
        control:ClearAllPoints()
        control:SetPoint("RIGHT", 0, 0)
        self.control = control
        local left = room - (width or control:GetWidth() or 0) - 12
        self.label:SetWidth(left)
        self.line:SetWidth(left)
    end
    return row
end

-- On or off, the Settings window's pill: a gold-edged track, filled while on, its round knob at
-- the right while on and the left while off. A CheckButton, so it flips itself on a click;
-- onClick(self) then reads self:GetChecked().
function Panel.Switch(parent, onClick)
    local b = CreateFrame("CheckButton", nil, parent)
    b:SetSize(36, 18)
    Fill(b, "BACKGROUND", C.well, 1):SetAllPoints()
    local edge = Outline(b, "BORDER", C.lineStrong, 0)
    local tick = Inset(Fill(b, "ARTWORK", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.28 }, 1))
    local knob = b:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(ART .. "Round")
    knob:SetSize(12, 12)
    b.knob = knob
    function b:Paint_()
        local on = self:GetChecked() and true or false
        tick:SetShown(on)
        Paint(edge, on and C.gold or C.lineStrong)
        local k = on and C.goldBright or C.dim
        knob:SetVertexColor(k[1], k[2], k[3], 1)
        knob:ClearAllPoints()
        if on then knob:SetPoint("RIGHT", -3, 0) else knob:SetPoint("LEFT", 3, 0) end
        self:SetAlpha(self:IsEnabled() and 1 or 0.4)
    end
    function b:SetOn(on)
        self:SetChecked(on and true or false)
        self:Paint_()
    end
    b:SetScript("OnClick", function(self)
        self:Paint_()
        Panel.Sound(self:GetChecked() and "on" or "off")
        if onClick then onClick(self) end
    end)
    b:Paint_()
    return b
end

-- Short answers side by side in one well, the chosen one lit with a gold foot (b.mark and b.foot):
-- seg:SetValue(i), none lit for nil. onPick(i, b). size: the words' size (12), least: a button's
-- least width (44), pad: the room round its word (18).
function Panel.Segment(parent, labels, onPick, size, least, pad)
    local seg = CreateFrame("Frame", nil, parent)
    seg:SetHeight(22)
    Fill(seg, "BACKGROUND", C.well, 1):SetAllPoints()
    seg.buttons = {}
    local x = 0
    for i, text in ipairs(labels) do
        local b = CreateFrame("Button", nil, seg)
        b:SetHeight(22)
        b.mark = Inset(Fill(b, "ARTWORK", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.11 }, 1))
        b.mark:Hide()
        b.foot = Fill(b, "ARTWORK", C.goldBright, 2)
        b.foot:SetHeight(2)
        b.foot:SetPoint("BOTTOMLEFT", 1, 1)
        b.foot:SetPoint("BOTTOMRIGHT", -1, 1)
        b.foot:Hide()
        if i > 1 then
            local sep = Fill(b, "ARTWORK", C.line, 3)
            sep:SetWidth(1)
            sep:SetPoint("TOPLEFT", 0, -1)
            sep:SetPoint("BOTTOMLEFT", 0, 1)
        end
        Inset(Fill(b, "HIGHLIGHT", C.lift))
        local fs = Plain(b, size or 12, C.dim)
        fs:SetPoint("CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        b:SetFontString(fs)
        b.label = fs
        b:SetText(text)
        b:SetWidth(math.max(least or 44, math.ceil(fs:GetStringWidth() or 0) + (pad or 18)))
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth()
        b:SetScript("OnClick", function(self)
            Panel.Sound("click")
            onPick(i, self)
        end)
        seg.buttons[i] = b
    end
    seg:SetWidth(x)
    Outline(seg, "OVERLAY", C.lineStrong, 0)
    function seg:SetOn(i, on)
        local b = self.buttons[i]
        b.on = on and true or nil
        b.mark:SetShown(b.on == true)
        b.foot:SetShown(b.on == true)
        local c = b.on and C.goldBright or C.dim
        b.label:SetTextColor(c[1], c[2], c[3])
    end
    function seg:SetValue(at)
        for i in ipairs(self.buttons) do self:SetOn(i, i == at) end
    end
    return seg
end

-- A value from a list on a rail (the Settings window's slider): its value, - , the rail lit gold up
-- to its thumb, + . A click or a drag on the rail picks the nearest step. set(value), then st:Fill().
local RAIL_W = 92
function Panel.Slider(parent, values, text, get, set)
    local st = CreateFrame("Frame", nil, parent)
    st:SetSize(40 + 6 + 18 + 6 + RAIL_W + 6 + 18, 22)
    st.plus = Panel.UButton(st, "+", 18, 18, "quiet")
    st.plus:SetPoint("RIGHT", 0, 0)
    local track = CreateFrame("Button", nil, st)
    track:SetSize(RAIL_W, 18)
    track:SetPoint("RIGHT", st.plus, "LEFT", -6, 0)
    local rail = Fill(track, "BACKGROUND", C.lineStrong, 1)
    rail:SetHeight(4)
    rail:SetPoint("LEFT", 0, 0)
    rail:SetPoint("RIGHT", 0, 0)
    local lit = Fill(track, "BACKGROUND", C.goldDark, 2)
    lit:SetHeight(4)
    lit:SetPoint("LEFT", 0, 0)
    st.thumb = Fill(track, "ARTWORK", C.gold)
    st.thumb:SetSize(8, 14)
    st.track = track
    st.minus = Panel.UButton(st, "-", 18, 18, "quiet")
    st.minus:SetPoint("RIGHT", track, "LEFT", -6, 0)
    st.value = Plain(st, 11)
    st.value:SetJustifyH("RIGHT")
    st.value:SetWidth(40)
    st.value:SetPoint("RIGHT", st.minus, "LEFT", -6, 0)
    local function At()
        local now, best, at = get(), math.huge, 1
        for i, v in ipairs(values) do
            if math.abs(v - now) < best then best, at = math.abs(v - now), i end
        end
        return at
    end
    function st:Fill()
        local i = At()
        self.value:SetText(text(values[i]))
        local x = #values > 1 and (i - 1) / (#values - 1) * RAIL_W or 0
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("CENTER", track, "LEFT", x, 0)
        lit:SetWidth(math.max(1, x))
        self.minus:SetEnabled(i > 1)
        self.plus:SetEnabled(i < #values)
    end
    local function To(i)
        i = math.max(1, math.min(#values, i))
        if i == At() then return end
        set(values[i])
        st:Fill()
    end
    st.To = To
    st.plus:SetScript("OnClick", function() Panel.Sound("click") To(At() + 1) end)
    st.minus:SetScript("OnClick", function() Panel.Sound("click") To(At() - 1) end)
    local function UnderCursor()
        local left = track:GetLeft()
        if not left then return At() end
        local x = GetCursorPosition() / track:GetEffectiveScale() - left
        return math.floor(x / RAIL_W * (#values - 1) + 0.5) + 1
    end
    track:SetScript("OnMouseDown", function(self)
        self.dragging = true
        To(UnderCursor())
    end)
    track:SetScript("OnMouseUp", function(self) self.dragging = nil end)
    track:SetScript("OnUpdate", function(self) if self.dragging then To(UnderCursor()) end end)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta) To(At() + delta) end)
    return st
end

-- The Settings window's dropdown box: the value, an arrow; a gold edge under the pointer. A
-- DropdownButton, so Blizzard's menu opens from it: setup(owner, root) as SetupMenu's.
-- b:SetValueText(text) shows the value.
function Panel.Choice(parent, width, setup)
    local b = CreateFrame("DropdownButton", nil, parent)
    b:SetSize(width, 22)
    Fill(b, "BACKGROUND", C.well, 1):SetAllPoints()
    b.edge = Outline(b, "BORDER", C.lineStrong, 0)
    b.value = Plain(b, 12)
    b.value:SetWordWrap(false)
    b.value:SetPoint("LEFT", 8, 0)
    b.value:SetPoint("RIGHT", -24, 0)
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture(ART .. "Arrow")
    b.arrow:SetSize(16, 16)
    b.arrow:SetPoint("RIGHT", -5, 0)
    b:HookScript("OnEnter", function(self) Paint(self.edge, C.goldDark) end)
    b:HookScript("OnLeave", function(self) Paint(self.edge, C.lineStrong) end)
    if b.SetupMenu then b:SetupMenu(setup) end
    function b:SetValueText(text) self.value:SetText(text or "") end
    return b
end

-- The Settings window's search box: a well, its hint while empty, Escape clears it.
-- onChange(box) after each change.
function Panel.Search(parent, width, height, hint, onChange)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, height or 26)
    box:SetAutoFocus(false)
    Fill(box, "BACKGROUND", C.well, 1):SetAllPoints()
    local edge = Outline(box, "BORDER", C.lineStrong, 0)
    box.hint = Plain(box, 12, C.faint)
    box.hint:SetPoint("LEFT", 8, 0)
    box.hint:SetText(hint or "")
    local face = box.hint:GetFont()
    if face then box:SetFont(face, 12, "") end
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    box:SetTextInsets(8, 8, 0, 0)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() Paint(edge, C.goldDark) end)
    box:SetScript("OnEditFocusLost", function() Paint(edge, C.lineStrong) end)
    box:SetScript("OnTextChanged", function(self)
        self.hint:SetShown((self:GetText() or "") == "")
        if onChange then onChange(self) end
    end)
    return box
end

-- A sheet's tab under a page's header: its name in the serif, lit gold with a gold foot while shown
-- (b.foot, also b.mark); another lifts under the pointer.
function Panel.SheetTab(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    b.lift = Fill(b, "BACKGROUND", C.lift, 1)
    b.lift:SetAllPoints()
    b.lift:Hide()
    local fs = b:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, 13, C.dim)
    fs:SetPoint("CENTER", 0, 1)
    b:SetFontString(fs)
    b.label = fs
    b:SetText(label)
    b:SetWidth(math.ceil(fs:GetStringWidth() or 0) + 28)
    b.foot = Fill(b, "OVERLAY", C.goldBright)
    b.foot:SetHeight(2)
    b.foot:SetPoint("BOTTOMLEFT", 8, 0)
    b.foot:SetPoint("BOTTOMRIGHT", -8, 0)
    b.mark = b.foot
    function b:SetOn(on)
        self.on = on and true or nil
        self.foot:SetShown(self.on == true)
        local c = self.on and C.goldBright or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
    end
    b:SetScript("OnEnter", function(self)
        if self.on then return end
        self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        self.lift:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.lift:Hide()
        self:SetOn(self.on)
    end)
    b:SetOn(false)
    return b
end

-- A colour in a well, a click its picker's (onClick(self, mouse)); sw:SetColor(r, g, b, a). Lifts
-- under the pointer.
function Panel.Swatch(parent, onClick)
    local sw = CreateFrame("Button", nil, parent)
    sw:SetSize(22, 18)
    Fill(sw, "BACKGROUND", C.well, 1):SetAllPoints()
    sw.edge = Outline(sw, "BORDER", C.lineStrong, 0)
    sw.chip = Inset(sw:CreateTexture(nil, "ARTWORK"), 3, 3)
    sw.chip:SetTexture(WHITE)
    sw:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    sw:SetScript("OnClick", function(self, mouse)
        Panel.Sound("click")
        if onClick then onClick(self, mouse) end
    end)
    sw:HookScript("OnEnter", function(self) Paint(self.edge, C.gold) end)
    sw:HookScript("OnLeave", function(self) Paint(self.edge, C.lineStrong) end)
    function sw:SetColor(r, g, b, a) self.chip:SetVertexColor(r, g, b, a or 1) end
    return sw
end

-- A page that scrolls: sc.content holds what it shows (as wide as the page, less the bar);
-- sc:SetContentHeight(h) after laying it out. The wheel scrolls it; a thin gold bar shows where.
local STEP = 40
function Panel.Scroller(parent, width, height)
    local sc = CreateFrame("ScrollFrame", nil, parent)
    sc:SetSize(width, height)
    sc:SetClipsChildren(true)
    local content = CreateFrame("Frame", nil, sc)
    content:SetSize(width - 12, 1)
    sc:SetScrollChild(content)
    sc.content = content
    local bar = CreateFrame("Slider", nil, sc)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetWidth(4)
    bar:SetValueStep(1)
    Fill(bar, "BACKGROUND", C.well, 1):SetAllPoints()
    bar:SetThumbTexture(WHITE)
    local thumb = bar:GetThumbTexture()
    thumb:SetWidth(4)
    thumb:SetVertexColor(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1)
    bar:Hide()
    sc.bar = bar
    bar:SetScript("OnValueChanged", function(_, offset) sc:SetVerticalScroll(math.floor(offset + .5)) end)
    sc:EnableMouseWheel(true)
    sc:SetScript("OnMouseWheel", function(_, delta)
        if bar:IsShown() then bar:SetValue(bar:GetValue() - delta * STEP) end
    end)
    function sc:SetContentHeight(h)
        content:SetHeight(math.max(1, h))
        local view = self:GetHeight()
        local range = math.max(0, math.ceil(h - view))
        bar:SetMinMaxValues(0, range)
        bar:SetShown(range > 0)
        if range > 0 then thumb:SetHeight(math.max(24, view * view / h)) end
        local at = math.min(bar:GetValue() or 0, range)
        bar:SetValue(at)
        self:SetVerticalScroll(at)
        self.range = range
    end
    function sc:ToTop()
        bar:SetValue(0)
        self:SetVerticalScroll(0)
    end
    return sc
end
