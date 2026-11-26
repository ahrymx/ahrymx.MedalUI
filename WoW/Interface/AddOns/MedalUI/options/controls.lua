-- The settings window's controls, in the console's ink and gold: a
-- checkbox, a switch, a dropdown and the list it opens, a colour swatch, a
-- slider, a key box and a button. Each option control reads ns.db and
-- writes through ns.SetOption, so the modules hear about the change the
-- way they always have; Refresh(enabled) redraws one from ns.db.
--
-- In a row (row true: the window's sections) a control is its label at
-- the left, a line in dim under it saying what it does (UI.Line), and its
-- box at the right; a label too long for its room wraps, and the row grows
-- to hold it. A row's on/off is a pill, as a switch; a choice of two or
-- three short answers is a segmented control (UI.Segment), every answer in
-- sight.
--
-- Nothing here is Blizzard's settings machinery or its dropdown menu: the
-- window's frames are MedalUI's own, so they can taint nothing the game's
-- secure code reads.
local _, ns = ...
local Tr = ns.L

local C = {
    gold = ns.gold.mid,
    goldDark = ns.gold.dark,
    goldBright = ns.gold.bright,
    ink = ns.colors.ink,
    panel = { 0.102, 0.094, 0.082 },
    well = { 0.051, 0.047, 0.039 },     -- #0d0c0a: a control's well (sunken)
    selected = ns.Themed({ 0.204, 0.165, 0.086 }),
    hover = ns.Themed({ 0.271, 0.220, 0.114 }),
    red = { 0.471, 0.094, 0.078 },
    redHover = { 0.580, 0.125, 0.098 },
    text = ns.colors.text,
    dim = ns.colors.dim,
    -- the surfaces, darkest out: the window's chrome (its head, sidebar and
    -- footer), the page, a card on it
    chrome = ns.colors.ink,
    page = { 0.090, 0.082, 0.063 },     -- #171510
    raised = { 0.118, 0.106, 0.086 },   -- #1e1b16
    -- neutral hairlines (gold is kept for what is on, chosen or primary)
    line = { 0.169, 0.153, 0.125 },     -- #2b2720
    lineStrong = { 0.239, 0.212, 0.165 }, -- #3d362a: a control's edge
    faint = { 0.490, 0.459, 0.384 },    -- #7d7562: the least of the text
    -- a lift under the pointer, a press, a lit row: translucent, over any surface
    lift = { 0.949, 0.918, 0.824, 0.045 },
    lift2 = { 0.949, 0.918, 0.824, 0.08 },
    lit = ns.Themed({ 0.878, 0.722, 0.290, 0.11 }),
}
local MEDIA = ns.media .. "options\\"

local UI = { colors = C }
ns.OptionsUI = UI

local function Fill(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end
UI.Fill = Fill
-- a texture (or each of an outline's) recoloured
local function Paint(t, color)
    if t.SetColorTexture then
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        return
    end
    for _, e in ipairs(t) do e:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
end
UI.Paint = Paint

-- A one-pixel line round a frame, inset.
local function Outline(parent, layer, color, inset, sub)
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
UI.Outline = Outline

-- The suite's frame: a fill, a dark gold edge (two pixels, or one), a
-- hairline inside it.
function UI.Skin(frame, color, edge)
    edge = edge or 2
    local bg = Fill(frame, "BACKGROUND", color, 1)
    bg:SetAllPoints()
    for i = 0, edge - 1 do Outline(frame, "BORDER", i == 0 and C.goldDark or C.lineStrong, i, 1) end
    Outline(frame, "BORDER", C.line, edge, 2)
    return bg
end

-- A heading's face (the console's serif) or the plain one, for reading.
function UI.Serif(parent, size, color)
    local fs = ns.Text(parent, size)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end
function UI.Plain(parent, size, color)
    local fs = ns.PlainText(parent, size)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

-- The game's tooltip: the title in gold, then the text, wrapped.
function UI.Tip(owner, title, text)
    if not GameTooltip then return end
    ns.Tip(owner, "ANCHOR_RIGHT", { title = title, color = C.goldBright, text and { "body", text } or false })
end
local function Untip() if GameTooltip then GameTooltip:Hide() end end

-- An option's value, and a change to it: ns.db and ns.SetOption, unless the
-- spec reads and writes its own (the unit-frame editor's, whose values sit
-- inside one option per frame: options/editor.lua).
local function Get(spec)
    if spec.get then return spec.get() end
    return ns.db[spec.key]
end
local function Set(spec, value)
    if spec.set then spec.set(value) else ns.SetOption(spec.key, value) end
end
UI.Get, UI.Set = Get, Set

local function Tipped(frame, title, text)
    frame:SetScript("OnEnter", function(self) UI.Tip(self, title, text) end)
    frame:SetScript("OnLeave", Untip)
end

-- An option's line under its label: spec.line (false for none), or its
-- tip's first sentence, the reload note left to the tip.
function UI.Line(spec)
    if spec.line ~= nil then return spec.line or nil end
    local tip = spec.tip
    if type(tip) ~= "string" or tip == "" then return nil end
    tip = tip:gsub(" Takes effect after a reload%.$", "")
    return tip:match("^(.-[%.!?])%s") or tip
end

-- a row's label: the room left of its box, wrapped; its line under it, one
-- line ending in "..." where it is longer; the row as tall as the two
UI.ROW_H, UI.LINE_SIZE = 24, 11
local function Fit(f, label, room, spec)
    room = math.max(20, room)
    label:SetWidth(room)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    local line = spec and UI.Line(spec)
    if not line then
        f:SetHeight(math.max(UI.ROW_H, math.ceil(label:GetStringHeight() or 0) + 8))
        return
    end
    f.line = f.line or UI.Plain(f, UI.LINE_SIZE, C.dim)
    f.line:SetWordWrap(false)
    f.line:SetJustifyH("LEFT")
    f.line:SetWidth(room)
    f.line:SetText(line)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", 0, -5)
    f.line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    f:SetHeight(math.ceil(label:GetStringHeight() or 0) + 2 + math.ceil(f.line:GetStringHeight() or 0) + 10)
end

-- A text's width in the rows' face, before anything is made for it.
local ruler
local function TextWidth(text)
    if not ruler then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        ruler = UI.Plain(holder, 12)
    end
    ruler:SetText(text)
    return math.ceil(ruler:GetStringWidth() or 0)
end

-- ------------------------------------------------------------ button
-- A button in one of four styles: "primary" (gold, the one main action),
-- "secondary" (every other), "quiet" (no box until the pointer is on it)
-- and "danger" (red; true, the old argument, means it too). Each lifts
-- under the pointer, darkens pressed (its text down a pixel) and fades
-- disabled. b:SetStyle(style) changes it (the footer's Reload UI goes
-- primary while a reload waits).
local INK = { 0.086, 0.075, 0.047 }
local NONE = { 0, 0, 0, 0 }
UI.BUTTON = {
    primary = { rest = C.gold, hover = C.goldBright, press = ns.Themed({ 0.659, 0.541, 0.259 }),
        edge = C.goldBright, text = INK, lit = INK },
    secondary = { rest = C.raised, hover = { 0.149, 0.133, 0.106 }, press = { 0.078, 0.071, 0.055 },
        edge = C.lineStrong, edgeLit = C.goldDark, text = C.gold, lit = C.goldBright },
    quiet = { rest = NONE, hover = C.lift, press = C.lift2, edge = NONE, text = C.dim, lit = C.text },
    danger = { rest = C.red, hover = C.redHover, press = { 0.369, 0.071, 0.059 },
        edge = { 0.604, 0.200, 0.149 }, text = { 0.949, 0.847, 0.784 }, lit = { 0.949, 0.847, 0.784 } },
}
function UI.Button(parent, label, width, height, click, tip, style)
    if style == true then style = "danger" end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local bg = Fill(b, "BACKGROUND", C.raised, 1)
    bg:SetAllPoints()
    b.bg = bg
    b.edge = Outline(b, "BORDER", C.lineStrong, 0)
    b.text = UI.Serif(b, 12, C.gold)
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label)
    -- its look in a state: "rest", "hover" or "press"
    function b:Show_(state)
        local s = UI.BUTTON[self.style]
        self.state = state
        Paint(bg, s[state])
        Paint(self.edge, state ~= "rest" and s.edgeLit or s.edge)
        local c = self.off and C.dim or state == "rest" and s.text or s.lit
        self.text:SetTextColor(c[1], c[2], c[3])
        self.text:ClearAllPoints()
        self.text:SetPoint("CENTER", 0, state == "press" and -1 or 0)
    end
    function b:SetStyle(to)
        self.style = UI.BUTTON[to] and to or "secondary"
        self:Show_(self.state or "rest")
    end
    b:SetScript("OnClick", function() click() end)
    b:SetScript("OnEnter", function(self)
        self:Show_("hover")
        if tip then UI.Tip(self, label, tip) end
    end)
    b:SetScript("OnLeave", function(self)
        self:Show_("rest")
        Untip()
    end)
    b:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then self:Show_("press") end
    end)
    b:SetScript("OnMouseUp", function(self)
        self:Show_(self:IsMouseOver() and "hover" or "rest")
    end)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        self.off = not enabled or nil
        self:Show_(enabled and self.state or "rest")
        self:SetAlpha(enabled and 1 or 0.4)
    end
    b:SetStyle(style)
    b.spec = { kind = "button", label = label }
    return b
end

-- ------------------------------------------------------------ pill
-- An on/off pill (a page's master, a module's card, a row's on/off): a
-- track gold-edged, filled while on, its knob at the right while on and at
-- the left while off. Its tick is the fill, as a checkbox's.
UI.SWITCH_W, UI.SWITCH_H = 36, 18

local function Pill(b)
    local track = CreateFrame("Frame", nil, b)
    track:SetSize(UI.SWITCH_W, UI.SWITCH_H)
    track:SetPoint("RIGHT", 0, 0)
    local well = Fill(track, "BACKGROUND", C.well, 1)
    well:SetAllPoints()
    b.edge = Outline(track, "BORDER", C.lineStrong, 0)
    b.tick = Fill(track, "ARTWORK", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.28 }, 1)
    b.tick:SetPoint("TOPLEFT", 1, -1)
    b.tick:SetPoint("BOTTOMRIGHT", -1, 1)
    b.knob = track:CreateTexture(nil, "OVERLAY")
    b.knob:SetTexture(ns.media .. "strips\\round")
    b.knob:SetSize(UI.SWITCH_H - 6, UI.SWITCH_H - 6)
    b.track = track
end

local function PillShows(b, on)
    b.tick:SetShown(on)
    b.knob:ClearAllPoints()
    b.knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
    local k = on and C.goldBright or C.dim
    b.knob:SetVertexColor(k[1], k[2], k[3], 1)
    Paint(b.edge, on and C.gold or C.lineStrong)
end

-- ------------------------------------------------------------ checkbox
-- In a row, a pill at its right; elsewhere (a grid's box) a box, its label
-- right of it.
local CHECK = 16
UI.CHECK_H = 22

function UI.Check(parent, spec, width, row)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, UI.CHECK_H)
    b.spec = spec
    b.label = UI.Plain(b, 12)
    b:SetScript("OnClick", function() Set(spec, not Get(spec)) end)
    Tipped(b, spec.label, spec.tip)
    if row then
        Pill(b)
        b.label:SetPoint("LEFT", 0, 0)
        b.label:SetText(spec.label)
        Fit(b, b.label, width - UI.SWITCH_W - 12, spec)
        function b:Refresh(enabled)
            self:SetEnabled(enabled)
            PillShows(self, Get(spec) and true or false)
            local c = enabled and C.text or C.dim
            self.label:SetTextColor(c[1], c[2], c[3])
            self:SetAlpha(enabled and 1 or 0.55)
        end
        return b
    end
    local box = Fill(b, "BACKGROUND", C.lineStrong, 1)
    box:SetSize(CHECK, CHECK)
    box:SetPoint("LEFT", 0, 0)
    local well = Fill(b, "BACKGROUND", C.well, 2)
    well:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    b.tick = b:CreateTexture(nil, "ARTWORK")
    b.tick:SetTexture(MEDIA .. "check")
    b.tick:SetSize(CHECK + 4, CHECK + 4)
    b.tick:SetPoint("CENTER", box, "CENTER", 1, 1)
    b.label:SetPoint("LEFT", box, "RIGHT", 7, 0)
    b.label:SetPoint("RIGHT", 0, 0)
    b.label:SetJustifyH("LEFT")
    b.label:SetText(spec.label)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        self.tick:SetShown(Get(spec) and true or false)
        local c = enabled and C.text or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return b
end

-- ------------------------------------------------------------ switch
-- A pill with its label (optional) left of it: a page's master, a card's
-- switch.
function UI.Switch(parent, spec, label)
    local b = CreateFrame("Button", nil, parent)
    b.spec = spec
    Pill(b)
    local track = b.track
    local w = UI.SWITCH_W
    if label then
        b.label = UI.Serif(b, 12, C.gold)
        b.label:SetPoint("RIGHT", track, "LEFT", -8, 0)
        b.label:SetText(label)
        w = w + 8 + math.ceil(b.label:GetStringWidth())
    end
    b:SetSize(w, UI.SWITCH_H + 4)
    b:SetScript("OnClick", function() Set(spec, not Get(spec)) end)
    Tipped(b, spec.label, spec.tip)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        PillShows(self, Get(spec) and true or false)
        self:SetAlpha(enabled and 1 or 0.45)
    end
    return b
end

-- ------------------------------------------------------------ key
-- A key binding: the label, and a box with the key bound to the command.
-- Click the box, then press a key (with any modifiers) to bind it; Esc
-- while it listens leaves the key as it was; a right-click unbinds.
-- Bindings only change out of combat. spec.command is the binding's name
-- (Bindings.xml); keybind.lua does the binding.
function UI.Key(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.CHECK_H)
    f.spec = spec
    f.label = UI.Plain(f, 12)
    f.label:SetPoint("LEFT", 0, 0)
    f.label:SetText(spec.label)
    local box = CreateFrame("Button", nil, f)
    box:SetSize(math.min(140, math.floor(width / 2)), UI.CHECK_H)
    box:SetPoint("RIGHT", 0, 0)
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = Fill(box, "BACKGROUND", C.well, 1)
    bg:SetAllPoints()
    Outline(box, "BORDER", C.lineStrong, 0)
    box.text = UI.Plain(box, 12)
    box.text:SetPoint("CENTER", 0, 0)
    f.box = box

    local function Shown()
        if box.listening then return Tr["Press a key"] end
        local keys = ns.BindingKeys and ns.BindingKeys(spec.command) or {}
        if #keys == 0 then return Tr["Not bound"] end
        return ns.KeyText and ns.KeyText(keys[1]) or keys[1]
    end
    local function Listen(on)
        box.listening = on or nil
        box:EnableKeyboard(on and true or false)
        f:Refresh(true)
    end
    box:SetScript("OnClick", function(_, button)
        if InCombatLockdown() then return end
        if button == "RightButton" then
            Listen(false)
            if ns.Rebind then ns.Rebind(spec.command) end
            f:Refresh(true)
            return
        end
        Listen(not box.listening)
    end)
    box:SetScript("OnKeyDown", function(self, key)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        if key == "ESCAPE" then Listen(false) return end
        local chord = ns.KeyChord and ns.KeyChord(key)
        if not chord then return end        -- a modifier alone: keep listening
        if ns.Rebind and not InCombatLockdown() then ns.Rebind(spec.command, chord) end
        Listen(false)
    end)
    box:SetScript("OnHide", function() if box.listening then Listen(false) end end)
    box:SetScript("OnEnter", function(self)
        UI.Tip(self, spec.label, (spec.tip and spec.tip .. "\n\n" or "")
            .. Tr["Click, then press a key. Right-click unbinds it."])
    end)
    box:SetScript("OnLeave", Untip)
    function f:Refresh(enabled)
        box:SetEnabled(enabled)
        box.text:SetText(Shown())
        local c = box.listening and C.goldBright or enabled and C.text or C.dim
        box.text:SetTextColor(c[1], c[2], c[3])
        local l = enabled and C.text or C.dim
        self.label:SetTextColor(l[1], l[2], l[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return f
end

-- ------------------------------------------------------------ the list
-- One list for every dropdown, over everything; a click anywhere off it
-- closes it.
local menu, catcher
local ROW_H = 20
local MENU_ROWS = 16                    -- a list's rows before it flows into another column

local function Menu()
    if menu then return menu end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetAllPoints(UIParent)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() UI.CloseMenu() end)
    catcher:Hide()
    menu = CreateFrame("Frame", "MedalUIOptionsMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    UI.Skin(menu, C.well, 1)
    menu.rows = {}
    menu:Hide()
    return menu
end

local function Row(i)
    local row = menu.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, menu)
    row:SetHeight(ROW_H)
    row.lit = Fill(row, "BACKGROUND", C.lift2, 1)
    row.lit:SetAllPoints()
    row.lit:Hide()
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetTexture(MEDIA .. "check")
    row.mark:SetSize(14, 14)
    row.mark:SetPoint("LEFT", 4, 0)
    row.text = UI.Plain(row, 12)
    menu.font = menu.font or { row.text:GetFont() }
    row.text:SetPoint("LEFT", 22, 0)
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function(self)
        self.lit:SetShown(not self.wip)
        if self.tip then UI.Tip(self, self.label, self.tip) end
    end)
    row:SetScript("OnLeave", function(self)
        self.lit:Hide()
        Untip()
    end)
    row:SetScript("OnClick", function(self)
        if self.wip then return end         -- a choice not ready to be picked
        local spec, value = menu.spec, self.value
        -- a list of several picks stays open, each click toggling one
        if spec.multi then
            Set(spec, value)
            UI.MarkMenu()
            return
        end
        UI.CloseMenu()
        Set(spec, value)
    end)
    menu.rows[i] = row
    return row
end

function UI.CloseMenu()
    if menu then
        menu:Hide()
        menu.owner = nil
        catcher:Hide()
    end
end

-- a choice's mark: the value chosen, or each of a multi list's (spec.on)
local function Chosen(spec, value)
    if spec.multi then return spec.on(value) and true or false end
    return Get(spec) == value
end

function UI.MarkMenu()
    if not (menu and menu:IsShown()) then return end
    for _, row in ipairs(menu.rows) do
        if row:IsShown() then
            local on = Chosen(menu.spec, row.value)
            row.mark:SetShown(on)
            local c = row.wip and C.dim or on and C.goldBright or C.text
            row.text:SetTextColor(c[1], c[2], c[3])
        end
    end
end

-- The list of a dropdown's choices under it; again on the same dropdown
-- closes it (a choice with wip = true dimmed and not picked). spec:
-- { choices = { { value, label, tip, font, wip = } }, key or
-- get/set; multi (several picks: on(value) says which, set(value) toggles
-- one, and the list stays open) }.
function UI.OpenMenu(owner, spec)
    Menu()
    if menu.owner == owner and menu:IsShown() then
        UI.CloseMenu()
        return
    end
    menu.owner, menu.spec = owner, spec
    -- choices that change while the game runs (fonts other addons share)
    if spec.list then spec.choices = spec.list() end
    local width = owner:GetWidth()
    for i, choice in ipairs(spec.choices) do
        local row = Row(i)
        -- a tip may be a function: what the choice does can depend on the profile
        local tip = choice[3]
        if type(tip) == "function" then tip = tip() end
        row.value, row.label, row.tip, row.wip = choice[1], choice[2], tip, choice.wip and true or nil
        -- a font's choice drawn in that font
        row.text:SetFont(choice[4] or menu.font[1], menu.font[2], menu.font[3])
        row.text:SetText(choice[2])
        local on = Chosen(spec, choice[1])
        row.mark:SetShown(on)
        local c = row.wip and C.dim or on and C.goldBright or C.text
        row.text:SetTextColor(c[1], c[2], c[3])
        width = math.max(width, math.ceil(row.text:GetStringWidth()) + 40)
        row:Show()
    end
    for i = #spec.choices + 1, #menu.rows do menu.rows[i]:Hide() end
    -- a long list flows into columns, each MENU_ROWS deep
    local n = #spec.choices
    local columns = math.max(1, math.ceil(n / MENU_ROWS))
    local deep = math.min(n, MENU_ROWS)
    for i = 1, n do
        local row, col, at = menu.rows[i], math.floor((i - 1) / MENU_ROWS), (i - 1) % MENU_ROWS
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 3 + col * width, -3 - at * ROW_H)
        row:SetWidth(width - 6)
    end
    menu:SetSize(columns * width, deep * ROW_H + 6)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    menu:Show()
end

-- ------------------------------------------------------------ dropdown
UI.CHOICE_H = 40

local function ChoiceLabel(spec)
    local value = Get(spec)
    if spec.list then spec.choices = spec.list() end
    for _, choice in ipairs(spec.choices) do
        if choice[1] == value then return choice[2] end
    end
    return tostring(value)
end

UI.CHOICE_W = 150                       -- a row's dropdown, at least
local VALUE_PAD = 8 + 24                -- the value's room: its inset, the arrow's

function UI.Choice(parent, spec, width, row)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.CHOICE_H)
    f.spec = spec
    local b = CreateFrame("Button", nil, f)
    -- one line: a value too long for its box ends in "...", never wraps
    b.value = UI.Plain(b, 12)
    b.value:SetWordWrap(false)
    if row then
        -- as wide as its longest choice, right of its label; where the two
        -- cannot share a line, under the label, as wide as the row
        f.label = UI.Plain(f, 12)
        f.label:SetText(spec.label)
        local least = math.min(UI.CHOICE_W, math.floor(width * 0.55))
        local need = least
        for _, choice in ipairs(spec.choices or {}) do
            b.value:SetText(choice[2])
            need = math.max(need, math.ceil(b.value:GetStringWidth()) + VALUE_PAD)
        end
        if need <= width - math.ceil(f.label:GetStringWidth()) - 10 or need <= least then
            f.label:SetPoint("LEFT", 0, 0)
            Fit(f, f.label, width - need - 10, spec)
            b:SetPoint("RIGHT", 0, 0)
            b:SetWidth(need)
        else
            f.stacked = true
            f.label:SetPoint("TOPLEFT", 0, -4)
            f.label:SetWidth(width)
            f.label:SetJustifyH("LEFT")
            b:SetPoint("BOTTOMLEFT", 0, 0)
            b:SetPoint("BOTTOMRIGHT", 0, 0)
            f:SetHeight(math.ceil(f.label:GetStringHeight() or 0) + 8 + 22)
        end
    else
        f.label = UI.Serif(f, 11, C.goldBright)
        f.label:SetPoint("TOPLEFT", 0, 0)
        f.label:SetText(spec.label)
        b:SetPoint("BOTTOMLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    f.row = row
    b:SetHeight(22)
    local bg = Fill(b, "BACKGROUND", C.well, 1)
    bg:SetAllPoints()
    b.edge = Outline(b, "BORDER", C.lineStrong, 0)
    b.value:SetPoint("LEFT", 8, 0)
    b.value:SetPoint("RIGHT", -24, 0)
    b.value:SetJustifyH("LEFT")
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture(MEDIA .. "arrow")
    b.arrow:SetSize(16, 16)
    b.arrow:SetPoint("RIGHT", -5, 0)
    b:SetScript("OnClick", function(self) UI.OpenMenu(self, spec) end)
    b:SetScript("OnEnter", function(self)
        Paint(self.edge, C.goldDark)
        UI.Tip(self, spec.label, spec.tip)
    end)
    b:SetScript("OnLeave", function(self)
        Paint(self.edge, C.lineStrong)
        Untip()
    end)
    f.button = b
    function f:Refresh(enabled)
        b:SetEnabled(enabled)
        b.value:SetText(ChoiceLabel(spec))
        local c = enabled and C.text or C.dim
        b.value:SetTextColor(c[1], c[2], c[3])
        if self.row then self.label:SetTextColor(c[1], c[2], c[3]) end
        self:SetAlpha(enabled and 1 or 0.55)
        if not enabled and menu and menu.owner == b then UI.CloseMenu() end
    end
    return f
end


-- ------------------------------------------------------------ segmented
-- A choice of two or three short answers, side by side in one well, the
-- one chosen lit with a gold foot: one click, every answer in sight. A
-- choice's row takes one where its answers fit in half the row
-- (UI.Segmentable); spec.menu keeps the dropdown. Its kind stays "choice".
UI.SEG_H, UI.SEG_MIN, UI.SEG_PAD = 22, 44, 18

local function SegWidths(spec)
    local widths, total = {}, 0
    for i, choice in ipairs(spec.choices) do
        widths[i] = math.max(UI.SEG_MIN, TextWidth(choice[2]) + UI.SEG_PAD)
        total = total + widths[i]
    end
    return widths, total
end

-- its answers' width together; a text's width (the window's header)
function UI.SegmentTotal(spec)
    local _, total = SegWidths(spec)
    return total
end
UI.TextWidth = TextWidth

function UI.Segmentable(spec, width)
    if spec.menu or spec.list or spec.multi or type(spec.choices) ~= "table" then return false end
    local n = #spec.choices
    if n < 2 or n > 3 then return false end
    local _, total = SegWidths(spec)
    return total <= math.floor(width * 0.5)
end

function UI.Segment(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.ROW_H)
    f.spec, f.segment, f.row = spec, true, true
    f.buttons = {}
    local widths, total = SegWidths(spec)
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(total, UI.SEG_H)
    box:SetPoint("RIGHT", 0, 0)
    Fill(box, "BACKGROUND", C.well, 1):SetAllPoints()
    Outline(box, "BORDER", C.lineStrong, 0)
    f.box = box
    local x = 0
    for i, choice in ipairs(spec.choices) do
        local b = CreateFrame("Button", nil, box)
        b:SetSize(widths[i], UI.SEG_H)
        b:SetPoint("TOPLEFT", x, 0)
        b.value, b.name, b.wip = choice[1], choice[2], choice.wip and true or nil
        b.lit = Fill(b, "ARTWORK", C.lit, 1)
        b.lift = Fill(b, "ARTWORK", C.lift, 0)
        b.lift:SetPoint("TOPLEFT", 1, -1)
        b.lift:SetPoint("BOTTOMRIGHT", -1, 1)
        b.lift:Hide()
        b.lit:SetPoint("TOPLEFT", 1, -1)
        b.lit:SetPoint("BOTTOMRIGHT", -1, 1)
        b.foot = Fill(b, "ARTWORK", C.goldBright, 2)
        b.foot:SetHeight(2)
        b.foot:SetPoint("BOTTOMLEFT", 1, 1)
        b.foot:SetPoint("BOTTOMRIGHT", -1, 1)
        if i > 1 then
            local sep = Fill(b, "ARTWORK", C.line, 3)
            sep:SetWidth(1)
            sep:SetPoint("TOPLEFT", 0, -1)
            sep:SetPoint("BOTTOMLEFT", 0, 1)
        end
        b.text = UI.Plain(b, 12)
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetText(choice[2])
        b:SetScript("OnClick", function(self) if not self.wip then Set(spec, self.value) end end)
        b:SetScript("OnEnter", function(self)
            if not self.chosen and not self.wip then
                self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
                self.lift:Show()
            end
            local tip = choice[3]
            if type(tip) == "function" then tip = tip() end
            UI.Tip(self, spec.label .. ": " .. choice[2], tip or spec.tip)
        end)
        b:SetScript("OnLeave", function(self)
            self.lift:Hide()
            f:Paint()
            Untip()
        end)
        f.buttons[i] = b
        x = x + widths[i]
    end
    f.label = UI.Plain(f, 12)
    f.label:SetPoint("LEFT", 0, 0)
    f.label:SetText(spec.label)
    Fit(f, f.label, width - total - 12, spec)
    function f:Paint()
        for _, b in ipairs(self.buttons) do
            local c = b.chosen and C.goldBright or C.dim
            b.text:SetTextColor(c[1], c[2], c[3])
            b.text:SetAlpha(b.wip and 0.5 or 1)
        end
    end
    -- the answer chosen, in words
    function f:Shown()
        for _, b in ipairs(self.buttons) do if b.chosen then return b.name end end
        return tostring(Get(spec))
    end
    function f:IsEnabled() return not self.off end
    function f:Refresh(enabled)
        self.off = not enabled
        local v = Get(spec)
        for _, b in ipairs(self.buttons) do
            b:SetEnabled(enabled)
            b.chosen = b.value == v
            b.lit:SetShown(b.chosen)
            b.foot:SetShown(b.chosen)
        end
        self:Paint()
        local c = enabled and C.text or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return f
end

-- ------------------------------------------------------------ grid
-- One option for many frames, a box each: a column per frame (cols, each
-- { label }), a row per option (rows, each { label, keys, tip }, keys one
-- per column, false where that frame has no such option: a dash). A box
-- whose frame chose its own over the shared one (the row's key in the
-- first column) wears a gold corner.
UI.GRID_COL = 58
function UI.Grid(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f.spec = spec
    local n = #spec.cols
    local left = width - n * UI.GRID_COL
    f.heads, f.cells, f.labels, f.dashes = {}, {}, {}, {}
    for i, col in ipairs(spec.cols) do
        local h = UI.Plain(f, 10, C.goldDark)
        h:SetPoint("TOP", f, "TOPLEFT", left + (i - 0.5) * UI.GRID_COL, -2)
        h:SetWidth(UI.GRID_COL - 2)
        h:SetText(col.label)
        f.heads[i] = h
    end
    local y = -18
    for r, row in ipairs(spec.rows) do
        local label = UI.Plain(f, 12, C.text)
        label:SetPoint("LEFT", f, "TOPLEFT", 0, y - UI.CHECK_H / 2)
        label:SetWidth(left - 8)
        label:SetJustifyH("LEFT")
        label:SetText(row.label)
        f.labels[r] = label
        f.cells[r] = {}
        for i, key in ipairs(row.keys) do
            local x = left + (i - 0.5) * UI.GRID_COL
            if key then
                local cell = UI.Check(f, { kind = "check", key = key,
                    label = row.label .. ": " .. spec.cols[i].label, tip = row.tip }, CHECK, false)
                cell.label:SetText("")
                cell:SetPoint("CENTER", f, "TOPLEFT", x, y - UI.CHECK_H / 2)
                cell.corner = Fill(cell, "OVERLAY", C.gold)
                cell.corner:SetSize(5, 5)
                cell.corner:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 1, 1)
                cell.corner:Hide()
                f.cells[r][i] = cell
            else
                local dash = UI.Plain(f, 12, C.dim)
                dash:SetPoint("CENTER", f, "TOPLEFT", x, y - UI.CHECK_H / 2)
                dash:SetText("-")
                f.dashes[#f.dashes + 1] = dash
            end
        end
        y = y - UI.CHECK_H - 4
    end
    f:SetSize(width, -y)
    function f:Refresh(enabled)
        for _, cells in pairs(self.cells) do
            for _, cell in pairs(cells) do
                cell:Refresh(enabled)
                cell.corner:SetShown(ns.SharedOf(cell.spec.key) ~= nil and ns.OptionOwn(cell.spec.key))
            end
        end
        local c = enabled and C.text or C.dim
        for _, l in ipairs(self.labels) do l:SetTextColor(c[1], c[2], c[3]) end
    end
    return f
end

-- ------------------------------------------------------------ note
-- Words the page reads as it draws (spec.text(), two lines at most): what
-- the game says of the player, such as the dispels they know.
function UI.Note(parent, spec, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 32)
    f.spec = spec
    f.text = UI.Plain(f, 12, C.text)
    f.text:SetPoint("TOPLEFT", 0, -2)
    f.text:SetWidth(width)
    f.text:SetJustifyH("LEFT")
    function f:Refresh()
        self.text:SetText(spec.text())
    end
    return f
end

-- ------------------------------------------------------------ colour
-- A swatch opening the game's colour picker; the option is "ffRRGGBB".
local function Hex(r, g, b)
    return ("ff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end
UI.Hex = Hex

-- The picker's own setup call (10.2.5 and Forever's client); writing its
-- fields, the older way, would leave them MedalUI's.
local function Pick(key)
    local picker = ColorPickerFrame
    if not (picker and picker.SetupColorPickerAndShow) then return end
    local before = ns.db[key]
    local r, g, b = ns.HexColor(before)
    local function Changed()
        local nr, ng, nb = picker:GetColorRGB()
        ns.SetOption(key, Hex(nr, ng, nb))
    end
    local function Cancel() ns.SetOption(key, before) end
    picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = Changed, cancelFunc = Cancel })
end

function UI.Color(parent, spec, width, row)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, UI.CHECK_H)
    b.spec = spec
    local edge = Fill(b, "BACKGROUND", C.lineStrong, 1)
    edge:SetSize(CHECK, CHECK)
    edge:SetPoint(row and "RIGHT" or "LEFT", 0, 0)
    b.swatch = Fill(b, "ARTWORK", { 1, 1, 1 })
    b.swatch:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    b.swatch:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    b.label = UI.Plain(b, 12)
    if row then
        b.label:SetPoint("LEFT", 0, 0)
        b.label:SetText(spec.label)
        Fit(b, b.label, width - CHECK - 12, spec)
    else
        b.label:SetPoint("LEFT", edge, "RIGHT", 7, 0)
        b.label:SetText(spec.label)
    end
    b:SetScript("OnClick", function() Pick(spec.key) end)
    Tipped(b, spec.label, spec.tip)
    function b:Refresh(enabled)
        self:SetEnabled(enabled)
        local r, g, bl = ns.HexColor(ns.db[spec.key])
        self.swatch:SetColorTexture(r, g, bl, 1)
        local c = enabled and C.text or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return b
end

-- ------------------------------------------------------------ slider
-- A number between spec.min and spec.max, by spec.step: the label and the
-- value over a track, a thumb to drag along it, and a step either way at
-- its ends. spec.text, when there is one, says the value ("No limit").
-- With spec.fast (a mover's place and scale, movers.lua) the steps go
-- further: Shift five at a time, Ctrl ten, and held down they go on by
-- themselves, after a pause, while the pointer stays on the button.
UI.SLIDER_H = 40
UI.HOLD, UI.REPEAT = 0.4, 0.05          -- seconds: before a held step repeats, and between repeats

UI.SLIDER_W, UI.VALUE_W = 140, 44      -- a row's slider (its buttons and track), and its value

function UI.Slider(parent, spec, width, row)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, UI.SLIDER_H)
    f.spec = spec
    f.row = row
    local room = row and math.min(UI.SLIDER_W, math.floor(width * 0.45)) or width
    if row then
        f.label = UI.Plain(f, 12)
        f.label:SetPoint("LEFT", 0, 0)
        f.label:SetText(spec.label)
        Fit(f, f.label, width - room - UI.VALUE_W - 12, spec)
        f.value = UI.Plain(f, 11)
        f.value:SetPoint("RIGHT", f, "RIGHT", -(room + 6), 0)
        f.value:SetWidth(UI.VALUE_W)
        f.value:SetJustifyH("RIGHT")
    else
        f.label = UI.Serif(f, 11, C.goldBright)
        f.label:SetPoint("TOPLEFT", 0, 0)
        f.label:SetText(spec.label)
        f.value = UI.Plain(f, 11)
        f.value:SetPoint("TOPRIGHT", 0, 0)
    end
    local step = spec.step or 1
    local function Clamp(v)
        v = math.floor(v / step + 0.5) * step
        return math.max(spec.min, math.min(spec.max, v))
    end
    local function Nudge(by)
        Set(spec, Clamp((Get(spec) or spec.min) + by))
    end
    -- how many steps a press goes: Ctrl ten, Shift five
    local function Steps()
        if not spec.fast then return 1 end
        if IsControlKeyDown and IsControlKeyDown() then return 10 end
        if IsShiftKeyDown and IsShiftKeyDown() then return 5 end
        return 1
    end
    local function Stepper(label, sign)
        local held = false     -- repeated while held: the click that ends it steps no more
        local b = UI.Button(f, label, 18, 18, function()
            if held then
                held = false
                return
            end
            Nudge(sign * step * Steps())
        end, nil, "quiet")
        if spec.fast then
            -- a timer only while held: no button ticks at rest
            local wait
            local function Tick(self, dt)
                if not self:IsEnabled() then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                wait = wait - dt
                if wait > 0 then return end
                wait = UI.REPEAT
                -- off the button, it waits for the pointer to come back
                if not self:IsMouseOver() then return end
                held = true
                Nudge(sign * step * Steps())
            end
            b:SetScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" or not self:IsEnabled() then return end
                wait, held = UI.HOLD, false
                self:SetScript("OnUpdate", Tick)
            end)
            b:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
            b:HookScript("OnHide", function(self)
                self:SetScript("OnUpdate", nil)
                held = false
            end)
        end
        return b
    end
    f.less = Stepper("-", -1)
    f.more = Stepper("+", 1)
    if row then
        f.less:SetPoint("RIGHT", f, "RIGHT", -(room - 18), 0)
        f.more:SetPoint("RIGHT", 0, 0)
    else
        f.less:SetPoint("BOTTOMLEFT", 0, 0)
        f.more:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    local track = CreateFrame("Button", nil, f)
    track:SetPoint("BOTTOMLEFT", f.less, "BOTTOMRIGHT", 6, 0)
    track:SetPoint("BOTTOMRIGHT", f.more, "BOTTOMLEFT", -6, 0)
    track:SetHeight(18)
    local rail = Fill(track, "BACKGROUND", C.lineStrong, 1)
    rail:SetPoint("LEFT", 0, 0)
    rail:SetPoint("RIGHT", 0, 0)
    rail:SetHeight(4)
    f.thumb = Fill(track, "ARTWORK", C.gold)
    f.thumb:SetSize(8, 14)
    -- the rail lit gold up to the thumb
    f.fill = Fill(track, "BACKGROUND", C.goldDark, 2)
    f.fill:SetHeight(4)
    f.fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    f.fill:SetPoint("RIGHT", f.thumb, "CENTER", 0, 0)
    f.track = track
    -- where the pointer is on the track, as a value
    local function AtCursor()
        local x = GetCursorPosition() / track:GetEffectiveScale()
        local left, w = track:GetLeft() or 0, track:GetWidth()
        if w <= 0 then return Get(spec) end
        return Clamp(spec.min + (x - left) / w * (spec.max - spec.min))
    end
    track:SetScript("OnMouseDown", function(self)
        self.dragging = true
        Set(spec, AtCursor())
    end)
    track:SetScript("OnMouseUp", function(self) self.dragging = nil end)
    track:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local v = AtCursor()
        if v ~= Get(spec) then Set(spec, v) end
    end)
    Tipped(track, spec.label, spec.tip)
    function f:Refresh(enabled)
        local v = Get(spec) or spec.min
        self.value:SetText(spec.text and spec.text(v) or tostring(v))
        local at = (v - spec.min) / (spec.max - spec.min)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("CENTER", track, "LEFT", math.max(0, math.min(1, at)) * track:GetWidth(), 0)
        track:EnableMouse(enabled)
        self.less:Refresh(enabled)
        self.more:Refresh(enabled)
        local c = enabled and C.text or C.dim
        self.value:SetTextColor(c[1], c[2], c[3])
        if self.row then self.label:SetTextColor(c[1], c[2], c[3]) end
        self:SetAlpha(enabled and 1 or 0.55)
    end
    return f
end
