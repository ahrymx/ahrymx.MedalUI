local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PANEL
-- What the radial editor (Radial/Editor.lua, from FlareUI's RadialEditor.lua) reads of FlareUI's
-- settings panel, drawn in Medalluin's look: a gold edge on an ink well, Marcellus headings.
--   ns.SettingsPanel   Rounded, Box, ScrollLine, KeyButton, Dress; INNER, MIDDLE_W; middleBox and
--                      rightBox (UI/Window.lua sets them)
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
}
ns.ui = C

local Panel = {}
ns.SettingsPanel = Panel

-- the window's measures (UI/Window.lua): the editor's middle is FlareUI's width
Panel.INNER = 10
Panel.MIDDLE_W = 636
Panel.RIGHT_W = 280

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
