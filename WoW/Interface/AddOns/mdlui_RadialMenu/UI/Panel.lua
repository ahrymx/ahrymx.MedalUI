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

-- a plain button in our face, its text in the game's small font
function Panel.Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    b:SetNormalFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    b:SetText(text or "")
    Face(b)
    return b
end

--------------------------------------------------
-- THE UNIT FRAME EDITOR'S PIECES
-- A control in a row is its label at the left and itself at the right, 24px high; its text is its
-- tooltip (the UFE's rows), not a column beside it.
--------------------------------------------------
local NONE = { 0, 0, 0, 0 }

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

-- a surface: a fill under a dark gold edge, then a strong line and a faint one inside it
function Panel.Skin(frame, color)
    local bg = Fill(frame, "BACKGROUND", color, 1)
    bg:SetAllPoints()
    Outline(frame, "BORDER", C.goldDark, 0, 1)
    Outline(frame, "BORDER", C.lineStrong, 1, 1)
    Outline(frame, "BORDER", C.line, 2, 2)
    return bg
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
-- a small caption in capitals over what it names
function Panel.Caption(parent, text, color)
    local fs = Panel.Plain(parent, 9, color or C.goldDark)
    fs:SetText(text and text:upper() or "")
    return fs
end

-- A button in one of the UFE's four styles; its text a serif in its own font string (b.label), so
-- b:SetText works as on any button. Painted for rest, hover and press; greyed while disabled.
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
        local c = (not self:IsEnabled()) and C.faint or (state == "rest" and s.text or s.lit)
        self.label:SetTextColor(c[1], c[2], c[3])
        self:SetAlpha(self:IsEnabled() and 1 or 0.6)
    end
    b:SetScript("OnEnter", function(self) self:Paint_("hover") end)
    b:SetScript("OnLeave", function(self) self:Paint_("rest") end)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:Paint_("press") end end)
    b:SetScript("OnMouseUp", function(self) self:Paint_(self:IsMouseOver() and "hover" or "rest") end)
    b:SetScript("OnEnable", function(self) self:Paint_("rest") end)
    b:SetScript("OnDisable", function(self) self:Paint_("rest") end)
    b:Paint_("rest")
    return b
end

-- A tab over a strip with a gold rule under it: lit while on (b.mark), its foot then open onto the
-- page it shows. Sized to its text.
function Panel.Tab(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    local bg = Fill(b, "BACKGROUND", C.ink, 1)
    bg:SetAllPoints()
    b.mark = Fill(b, "BACKGROUND", C.selected, 2)
    b.mark:SetPoint("TOPLEFT", 1, -1)
    b.mark:SetPoint("BOTTOMRIGHT", -1, 0)
    b.mark:Hide()
    b.edge = Outline(b, "BORDER", C.goldDark, 0)
    b.foot = Fill(b, "OVERLAY", C.selected)
    b.foot:SetPoint("BOTTOMLEFT", 1, 0)
    b.foot:SetPoint("BOTTOMRIGHT", -1, 0)
    b.foot:SetHeight(1)
    b.foot:Hide()
    local fs = b:CreateFontString(nil, "OVERLAY")
    Panel.Heading(fs, 12, C.dim)
    fs:SetPoint("CENTER", 0, 0)
    b:SetFontString(fs)
    b.label = fs
    b:SetText(label)
    b:SetWidth(math.ceil(fs:GetStringWidth() or 0) + 24)
    local glow = Fill(b, "HIGHLIGHT", C.lift)
    glow:SetAllPoints()
    function b:SetOn(on)
        self.mark:SetShown(on and true or false)
        self.foot:SetShown(on and true or false)
        Paint(self.edge, on and C.gold or C.goldDark)
        local c = on and C.goldBright or C.dim
        self.label:SetTextColor(c[1], c[2], c[3])
    end
    return b
end

-- On or off: a gold track with the knob at the right, or a dark one with it at the left. A
-- CheckButton, so it flips itself on a click; onClick(self) then reads self:GetChecked().
function Panel.Switch(parent, onClick)
    local b = CreateFrame("CheckButton", nil, parent)
    b:SetSize(34, 16)
    local track = Fill(b, "BACKGROUND", C.well, 1)
    track:SetAllPoints()
    local edge = Outline(b, "BORDER", C.lineStrong, 0)
    local knob = Fill(b, "ARTWORK", C.faint)
    knob:SetSize(10, 10)
    function b:Paint_()
        local on = self:GetChecked() and true or false
        Paint(track, on and C.gold or C.well)
        Paint(edge, on and C.goldBright or C.lineStrong)
        Paint(knob, on and C.ink or C.faint)
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

-- Two or three answers side by side, every one in sight; the chosen one lit (its b.mark). The
-- buttons are seg.buttons, in order; onPick(i).
function Panel.Segment(parent, labels, onPick)
    local seg = CreateFrame("Frame", nil, parent)
    seg:SetHeight(22)
    seg.buttons = {}
    local x = 1
    for i, text in ipairs(labels) do
        local b = CreateFrame("Button", nil, seg)
        b:SetHeight(20)
        local bg = Fill(b, "BACKGROUND", C.well, 1)
        bg:SetAllPoints()
        b.mark = Fill(b, "BACKGROUND", C.selected, 2)
        b.mark:SetAllPoints()
        b.mark:Hide()
        b.edge = Outline(b, "BORDER", C.gold, 0)
        for _, e in ipairs(b.edge) do e:Hide() end
        local fs = Panel.Plain(b, 11, C.dim)
        fs:SetPoint("CENTER", 0, 0)
        b:SetFontString(fs)
        b.label = fs
        b:SetText(text)
        b:SetWidth(math.ceil(fs:GetStringWidth() or 0) + 16)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth()
        local glow = Fill(b, "HIGHLIGHT", C.lift)
        glow:SetAllPoints()
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            onPick(i)
        end)
        seg.buttons[i] = b
    end
    seg:SetWidth(x + 1)
    Outline(seg, "BORDER", C.lineStrong, 0)
    function seg:SetValue(at)
        for i, b in ipairs(self.buttons) do
            local on = i == at
            b.mark:SetShown(on)
            for _, e in ipairs(b.edge) do e:SetShown(on) end
            local c = on and C.goldBright or C.dim
            b.label:SetTextColor(c[1], c[2], c[3])
        end
    end
    return seg
end

-- - value +: quiet steps round a value (the UFE's), or other marks; st.minus, st.value, st.plus
function Panel.Stepper(parent, valueWidth, less, more)
    local st = CreateFrame("Frame", nil, parent)
    st:SetSize(18 + (valueWidth or 40) + 18 + 8, 22)
    st.plus = Panel.UButton(st, more or "+", 18, 18, "quiet")
    st.plus:SetPoint("RIGHT", 0, 0)
    st.value = Panel.Plain(st, 11)
    st.value:SetJustifyH("CENTER")
    st.value:SetWidth(valueWidth or 40)
    st.value:SetPoint("RIGHT", st.plus, "LEFT", -4, 0)
    st.minus = Panel.UButton(st, less or "-", 18, 18, "quiet")
    st.minus:SetPoint("RIGHT", st.value, "LEFT", -4, 0)
    return st
end

-- a row across a page at y: its label at the left (row.label); its control goes at the right
function Panel.Row(parent, y, label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    row:SetHeight(24)
    row:EnableMouse(true)
    row.label = Panel.Plain(row, 12)
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetText(label or "")
    return row
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
    local b = Panel.Button(parent, "", 170, 24)
    b:SetNormalFontObject("GameFontHighlight")
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
            self:SetText("|cff808080" .. (NOT_BOUND or L["Not bound"]) .. "|r")
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
