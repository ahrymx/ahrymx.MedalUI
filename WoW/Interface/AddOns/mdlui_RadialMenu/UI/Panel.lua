local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PANEL
-- What the radial editor (Radial/Editor.lua, from FlareUI's RadialEditor.lua) reads of FlareUI's
-- settings panel, drawn in Medalluin's look: a gold edge on an ink well, Marcellus headings; and the
-- Unit Frame Editor's pieces (Medalluin/options/controls.lua, copied: this addon stands alone), which
-- the window (UI/Window.lua) is built from.
--   ns.SettingsPanel   Rounded, Box, ScrollLine, KeyButton, Dress; Fill, Outline, Paint, Skin,
--                      Serif, Plain, Caption, UButton, Tab, Switch, Segment, Stepper, Row
--   ns.Settings        Text(row, field[, optional]) and Format(text): the editor's copy
--   ns.OwnGameTooltip, ns.SkinButton
--------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Medalluin's palette (options/controls.lua; copied: this addon stands alone)
local C = {
    gold = { 0.769, 0.647, 0.341 },
    goldDark = { 0.541, 0.439, 0.204 },
    goldBright = { 0.878, 0.722, 0.290 },
    ink = ns.colors.ink,
    well = { 0.051, 0.047, 0.039 },
    page = { 0.090, 0.082, 0.063 },
    raised = { 0.118, 0.106, 0.086 },
    line = { 0.169, 0.153, 0.125 },
    lineStrong = { 0.239, 0.212, 0.165 },
    text = ns.colors.text,
    dim = ns.colors.dim,
    panel = { 0.102, 0.094, 0.082 },        -- the window
    selected = { 0.204, 0.165, 0.086 },     -- a chosen row, tab or chip
    faint = { 0.490, 0.459, 0.384 },        -- the least of the text
    red = { 0.471, 0.094, 0.078 },
    redHover = { 0.580, 0.125, 0.098 },
    clash = { 0.910, 0.573, 0.227 },        -- a key two radials share
    lift = { 0.949, 0.918, 0.824, 0.045 },  -- under the pointer
    lift2 = { 0.949, 0.918, 0.824, 0.08 },  -- pressed
}
ns.ui = C

local Panel = {}
ns.SettingsPanel = Panel

--------------------------------------------------
-- SURFACES
--------------------------------------------------
-- a flat fill; FlareUI's was a rounded plate
function Panel.Rounded(tex, r, g, b, a)
    tex:SetTexture(WHITE)
    if r then tex:SetVertexColor(r, g, b, a or 1) end
    return tex
end

-- a box: a thin edge and an ink fill (alpha), as a BackdropTemplate frame, so the editor can
-- clear and restore its colours
function Panel.Box(f, alpha)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(C.ink[1], C.ink[2], C.ink[3], alpha or 0.3)
    f:SetBackdropBorderColor(C.lineStrong[1], C.lineStrong[2], C.lineStrong[3], 1)
end

-- a window's dress: an ink well under a gold edge (four lines)
function Panel.Dress(f, fill)
    if f.mdlEdges then return end
    f.mdlEdges = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "BORDER", nil, 7)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[1]:sub(1, 3) == side[2]:sub(1, 3) then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1)
        f.mdlEdges[#f.mdlEdges + 1] = t
    end
    local well = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], fill or 0.96)
    f.mdlWell = well
end

-- Medalluin's font for a heading, at size; the game's font keeps the client's letters elsewhere
function Panel.Heading(fs, size, color)
    ns.SetFont(fs, ns.GetFontPath(ns.GLOBAL_FONT), size or 14, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    color = color or C.goldBright
    fs:SetTextColor(color[1], color[2], color[3])
end

--------------------------------------------------
-- BUTTONS
-- As Medalluin's windows': a dark gold edge, an ink well, a white glow under the mouse; b.mark lit
-- while it is selected (b:SetSelected).
--------------------------------------------------
local function Face(b)
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 1)
    b.mark = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.mark:SetPoint("TOPLEFT", 1, -1)
    b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
    b.mark:SetColorTexture(C.goldDark[1], C.goldDark[2], C.goldDark[3], 0.45)
    b.mark:Hide()
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.12)
    b.mdlEdge = edge
    function b:SetSelected(on)
        self.mark:SetShown(on and true or false)
        local fs = self:GetFontString()
        if fs then
            local c = on and C.goldBright or C.text
            fs:SetTextColor(c[1], c[2], c[3])
        end
    end
    return b
end
Panel.Face = Face

-- a template button's own art put away and our face on it (UIPanelButtonTemplate)
function ns.SkinButton(b)
    if b.mdlSkinned then return end
    b.mdlSkinned = true
    for _, r in ipairs({ b:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    Face(b)
    local fs = b:GetFontString()
    if fs then fs:SetTextColor(C.text[1], C.text[2], C.text[3]) end
end

--------------------------------------------------
-- THE SETTINGS WINDOW'S PIECES
-- Medalluin's Settings window (Medalluin/options/controls.lua and window.lua), copied: this addon
-- stands alone. A card is a title band over rows; a row is its label, a line under it saying what it
-- does, and its control at the right. The pill, the segment, the dropdown box, the slider, the
-- search box and the sheet tab are the Settings window's; so is the art in art/ui.
--------------------------------------------------
local ART = "Interface\\AddOns\\mdlui_RadialMenu\\art\\ui\\"
Panel.ART = ART
local NONE = { 0, 0, 0, 0 }
local BAND_H, CARD_PAD, ROW_H = 36, 12, 44
Panel.BAND_H, Panel.CARD_PAD, Panel.ROW_H = BAND_H, CARD_PAD, ROW_H

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
local function Inset(t, x, y)
    t:SetPoint("TOPLEFT", x or 1, -(y or 1))
    t:SetPoint("BOTTOMRIGHT", -(x or 1), y or 1)
    return t
end

-- the console's serif (headings, buttons, names), or the game's plain face (reading)
function Panel.Serif(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, size, color or C.text)
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

-- a small word in a gold outline, after a card's title (a radial's key, a slot's place)
function Panel.Chip(parent, text)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(14)
    Outline(chip, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.45 }, 0)
    chip.text = Plain(chip, 10, C.gold)
    chip.text:SetPoint("CENTER", 0, 0)
    function chip:SetText(t)
        self.text:SetText(t or "")
        self:SetWidth(math.ceil(self.text:GetStringWidth() or 0) + 10)
    end
    chip:SetText(text)
    return chip
end

-- A card, a step lighter than the page: its title in a band across its top, a hairline under the
-- band. Sized by the caller before its rows go in.
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
    return card
end

-- a region in a card's band: at its right (x in from the edge), or after its title (after = true)
function Panel.InBand(card, region, x, after)
    if after then
        region:SetPoint("LEFT", card.title, "RIGHT", x or 8, 0)
    else
        region:SetPoint("RIGHT", card, "TOPRIGHT", -(x or CARD_PAD), -BAND_H / 2)
    end
end

-- Row n of a card (from 1, under its band): its label, its line in dim under it, a hairline over
-- it after the first; it lifts under the pointer. row:Hold(control, width) puts the control at the
-- right and keeps the words clear of it.
function Panel.CardRow(card, n, label, line)
    local row = CreateFrame("Frame", nil, card)
    local top = BAND_H + 4 + (n - 1) * ROW_H
    row:SetPoint("TOPLEFT", CARD_PAD, -top)
    row:SetPoint("TOPRIGHT", -CARD_PAD, -top)
    row:SetHeight(ROW_H)
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
    end
    function b:SetOn(on)
        self:SetChecked(on and true or false)
        self:Paint_()
    end
    b:SetScript("OnClick", function(self)
        self:Paint_()
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if onClick then onClick(self) end
    end)
    b:Paint_()
    return b
end

-- Short answers side by side in one well, the chosen one lit with a gold foot (b.mark and b.foot):
-- seg:SetValue(i). As toggles (each on or off: the canvas's Show), seg:SetOn(i, on). onPick(i, b).
function Panel.Segment(parent, labels, onPick)
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
        local fs = Plain(b, 12, C.dim)
        fs:SetPoint("CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        b:SetFontString(fs)
        b.label = fs
        b:SetText(text)
        b:SetWidth(math.max(44, math.ceil(fs:GetStringWidth() or 0) + 18))
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth()
        b:SetScript("OnClick", function(self)
            ns.ButtonSound()
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

-- < value > in one well: st.minus, st.value, st.plus (a slot's place on the wheel)
function Panel.Stepper(parent, valueWidth, less, more)
    local st = CreateFrame("Frame", nil, parent)
    valueWidth = valueWidth or 52
    st:SetSize(22 + valueWidth + 22, 22)
    Fill(st, "BACKGROUND", C.well, 1):SetAllPoints()
    st.minus = Panel.UButton(st, less or "-", 22, 22, "quiet")
    st.minus:SetPoint("LEFT", 0, 0)
    st.plus = Panel.UButton(st, more or "+", 22, 22, "quiet")
    st.plus:SetPoint("RIGHT", 0, 0)
    st.value = Plain(st, 12)
    st.value:SetJustifyH("CENTER")
    st.value:SetWidth(valueWidth)
    st.value:SetPoint("CENTER", 0, 0)
    for _, x in ipairs({ 22, 22 + valueWidth }) do
        local sep = Fill(st, "ARTWORK", C.line)
        sep:SetSize(1, 20)
        sep:SetPoint("LEFT", x, 0)
    end
    Outline(st, "OVERLAY", C.lineStrong, 0)
    return st
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
    st.plus:SetScript("OnClick", function() ns.ButtonSound() To(At() + 1) end)
    st.minus:SetScript("OnClick", function() ns.ButtonSound() To(At() - 1) end)
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
    b:SetupMenu(setup)
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

--------------------------------------------------
-- SCROLL LINE
-- FlareUI's API on Blizzard's MinimalScrollBar: line:SetValues(visible, position) takes 0..1 shares;
-- line.onScroll(position) fires when the player drags it, clicks its track or arrows.
--------------------------------------------------
local SCROLL_SCALE = 0.7
function Panel.ScrollLine(parent)
    local line = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    line:SetScale(SCROLL_SCALE)
    line.visible, line.position = 1, 0
    local setting = false
    function line:SetValues(visible, position)
        self.visible, self.position = visible or 1, math.max(0, math.min(1, position or 0))
        if self.visible >= 0.999 then self:Hide() return end
        self:Show()
        setting = true
        self:SetVisibleExtentPercentage(self.visible)
        self:SetPanExtentPercentage(math.max(0.01, self.visible * 0.25))
        self:SetScrollPercentage(self.position, true)
        setting = false
    end
    line:RegisterCallback("OnScroll", function(_, position)
        if setting or not line.onScroll then return end
        line.onScroll(math.max(0, math.min(1, position or 0)))
    end, line)
    return line
end

--------------------------------------------------
-- KEY BUTTON (FlareUI's Panel.KeyButton, keyboard and mouse only: controller keys wait for 2.0)
-- Click, then press a key with its modifiers. Escape, right-click or a second click cancel;
-- right-click when not listening clears (onSet gets "").
--------------------------------------------------
local MOD_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
                   LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

function Panel.KeyButton(parent, onSet, onCancel)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(120, 22)
    Fill(b, "BACKGROUND", C.well, 1):SetAllPoints()
    local edge = Outline(b, "BORDER", C.goldDark, 0)
    local lit = Inset(Fill(b, "BACKGROUND", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.11 }, 2))
    lit:Hide()
    Inset(Fill(b, "HIGHLIGHT", C.lift))
    local fs = b:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, 12, C.goldBright)
    fs:SetPoint("CENTER", 0, 0)
    b:SetFontString(fs)
    -- listening: lit, a bright edge
    function b:SetSelected(on)
        lit:SetShown(on and true or false)
        Paint(edge, on and C.goldBright or C.goldDark)
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function Stop()
        b.waiting = nil
        b:EnableKeyboard(false)
        b:SetSelected(false)
    end
    local function Finish(key)
        local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown() and "SHIFT-" or "")
        Stop()
        onSet(mods .. key)
    end
    local function Cancel()
        Stop()
        if onCancel then onCancel(b) end
    end
    b:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            if self.waiting then Cancel() else onSet("") end
            return
        end
        if self.waiting then Cancel() return end
        self.waiting = true
        self:SetText(L["Press a key"])
        self:SetSelected(true)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
    end)
    b:SetScript("OnKeyDown", function(self, key)
        if not self.waiting or MOD_KEYS[key] then return end
        if key == "ESCAPE" then Cancel() return end
        Finish(key)
    end)
    b:SetScript("OnMouseDown", function(self, mouse)
        if self.waiting and MOUSE_KEYS[mouse] then Finish(MOUSE_KEYS[mouse]) end
    end)
    b:SetScript("OnHide", Stop)
    function b:ShowKey(key)
        if key and key ~= "" then
            self:SetText(ns.KeyText(key))
        else
            self:SetText("|cff7d7562" .. (NOT_BOUND or L["Not bound"]) .. "|r")
        end
    end
    return b
end

function ns.OwnGameTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
end

--------------------------------------------------
-- COPY
-- FlareUI's Settings/Copy.lua rows the editor and the Options tab read: label, desc, tip, choices.
-- Backticks in a text mark a word in gold (Format).
--------------------------------------------------
local COPY = {
    ["rm.activation"] = {
        choices = { L["Hold"], L["Toggle"] },
        desc = L["How a key opens the radial:\n* Hold: hold the key, point, release to use\n* Toggle: press to open, left-click to use; press again or right-click to close (right-click goes back from a nested radial)"],
        label = L["Activation"],
        tip = L["Toggle: middle-click a nested radial to open it in place. The mouse wheel still steps through it."],
    },
    ["rm.autoRanks"] = {
        desc = L["A spell button casts the best rank you know. A button you put on a lower rank stays on it."],
        label = L["Follow Spell Ranks"],
    },
    ["rm.copy"] = {
        desc = L["Copies the radial with its buttons and reach, without a key. Handy for a Horde or class version."],
        label = L["Copy"],
    },
    ["rm.font.counts"] = {
        desc = L["Item counts and spell charges on the buttons."],
        label = L["Counts"],
    },
    ["rm.font.labels"] = {
        desc = L["The name of the button you point at."],
        label = L["Button Names"],
    },
    ["rm.import"] = {
        desc = L["Copies FlareUI's radials, their groups and each character's keys into this addon. FlareUI's own settings are only read."],
        label = L["Import from FlareUI"],
        tip = L["Radials you already have here stay; the imported ones are added after them."],
    },
    ["rm.key"] = {
        desc = L["Opens this radial on every character that gets it."],
        label = L["Key"],
        tip = L["Right-click to clear it. On a shared key, the narrower radial wins: this character, then class, then faction."],
    },
    ["rm.macroCreate"] = {
        desc = L["Puts a macro on your cursor that opens this radial from an action bar or another radial:\n* Press the macro: opens it\n* Click: uses the button you point at\n* Press it again, right-click or Escape: closes it"],
        done = L["Macro \"{name}\" created and on your cursor. Drop it on a bar."],
        errorInCombat = L["You can't create macros in combat."],
        errorMacrosFull = L["Your macro list is full. Delete one and try again."],
        label = L["Create Macro"],
        tip = L["Macro conditionals work."],
    },
    ["rm.names"] = {
        desc = L["The button you point at shows its action's name."],
        label = L["Show Button Names"],
    },
    ["rm.new"] = {
        desc = L["Creates an empty radial. Choose who gets it as you name it."],
        label = L["New Radial"],
    },
    ["rm.overview"] = {
        desc = L["Every key that opens a radial on the character you're playing."],
        label = L["On This Character"],
        tip = L["A clash means two radials share a key. The first in the list wins."],
    },
    ["rm.ownKey"] = {
        desc = L["This character gets its own key for this radial. Your other characters keep the shared key."],
        label = L["Only This Character"],
        tip = L["It wins over any other radial on the same key."],
    },
    ["rm.position"] = {
        choices = { L["Mouse Cursor"], L["Screen Centre"] },
        desc = L["Where the radial opens:\n* Mouse Cursor: where your mouse is\n* Screen Centre: the middle of the screen"],
        label = L["Menu Position"],
        tip = L["Radial macros open there too."],
    },
    ["rm.scale"] = {
        desc = L["The size of the whole radial, buttons and ring."],
        label = L["Radial Scale"],
    },
    ["rm.scope"] = {
        desc = L["Which of your characters get this radial. Each picks it up at login."],
        label = L["Available To"],
        tip = L["A new radial starts on every character."],
    },
    ["rm.subRadials"] = {
        choices = { L["Reset on Close"], L["Remember"] },
        desc = L["Which button a sub-radial shows when you open the radial again:\n* Reset on Close: its first button\n* Remember: the one you scrolled to last"],
        label = L["Sub-Radials"],
    },
}
ns.COPY = COPY

local Settings = {}
ns.Settings = Settings

-- a row's field; a missing one is the row key itself unless optional (then nil)
function Settings:Text(row, field, optional)
    local entry = COPY[row]
    local value = entry and entry[field]
    if value == nil and not optional then return row end
    return value
end

function Settings:Format(text)
    if not text then return text end
    return (text:gsub("`([^`]+)`", "|cffffd100%1|r"))
end
