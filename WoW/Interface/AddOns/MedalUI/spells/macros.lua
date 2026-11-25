-- The spellbook's Macros page (spells/spellbook.lua): the game's own macro
-- window (MacroFrame, Blizzard_MacroUI, loaded as the page first shows)
-- inside the page, dressed as Click Casting is (spells/clickcast.lua).
--
--   [ General  4 / 120 ][ Ahrymx  2 / 18 ]
--  (o)+--------------------------------------------------------+
--  (o)| Heal                                                 + |   a raised plate, its
--     | /cast [@mouseover,help] Flash Heal                     |   icon a medallion
--     +--------------------------------------------------------+   over its left edge
--  (o)+--------------------------------------------------------+
--  (o)| Focus                                                - |   opened
--     | ------------------------------------------------------ |
--     | /focus                                                 |
--     | /cast [@focus] Polymorph                        Delete |
--     +--------------------------------------------------------+
--   ...                       (the floor: a faint engraved hatch, a vignette)
--   (o) Focus (pencil)          ~~[+ New][v Save][<- Cancel]    the engraved tray
--   +-                                                       -+
--     1 | /focus                                                  a page: gold
--     2 | /cast [@focus] Polymorph                                corner brackets,
--   +-                                                       -+   line numbers
--   Casts [ic] Polymorph                         ===---  32 / 255
--
-- (The plates look: mockup C, /workspace/macros-mock-C-plates.png,
-- the user's choice 2026-11-25.)
--
-- Tabs (joined under the head) for the account's macros and the character's, a card for
-- each macro of the set (folded, its name and first line; opened, the
-- whole text, MedalUICharDB.macroOpen by name), and the editor under
-- them. A left click on a card opens or closes it and puts it in the
-- editor; the right runs it (a secure button over its head, as the book's
-- rows cast); the left dragged puts it on a bar. Click Casting open,
-- either button binds it. New and the pencil show the game's name and
-- icon picker (MacroPopupFrame) floating left of the book, over it if
-- dragged there.
--
-- Every save, delete, new and icon pick is the game's own code: ours calls
-- the game's buttons, which stay, hidden. Its art is put away, ours drawn
-- beside it (window/reskin.lua), nothing written on the game's frames.
-- The game's ways in (/macro, the game menu) open the book on this page.
local _, ns = ...
local Tr = ns.L

local R = ns.reskin
local GOLD, GOLD_D = R.GOLD, R.GOLD_D
local PLAIN = "Fonts\\ARIALN.TTF"       -- the macros' own words
local OFF = { 0.37, 0.345, 0.29 }       -- a tab's count, not held (the book's)
local HEAD, LINE = 44, 13               -- a card folded; a line of its text
local SPACE = 10                        -- between the cards
local MEDAL = 42                        -- a card's icon, a medallion in its plate's top left corner
local TEXT_X = MEDAL + 10               -- a card's words, in from its plate's left edge
-- (2026-11-25, the user's: the icon in, the corner curved) the plate's top
-- left corner cut away to the medallion's middle: the medallion touches its
-- top and left edges, its rim the corner
local CUT = { x = MEDAL / 2, y = MEDAL / 2 }
local MARGIN = 10                       -- the plates in from the floor's edges, each side alike
local GLOW = 2                          -- the held plate's glow, out from its edge
local PLATE_TOP = { 0.16, 0.14, 0.11, 1 } -- a plate's head, lit from above
local FLOOR = { hatch = 0.05, vignette = 0.6, edge = 0.3 } -- the list's floor: its hatch, its edges' dark, its edge
-- the editor's tray: a button's width and height (the engraved frame's 26),
-- its glyph, between them, round them, the ink's fade out to the left
local TRAY = { button = 84, height = 26, glyph = 14, gap = 4, pad = 3, fade = 40 }
local PAGE = { inset = 4, bracket = 18 }  -- the text's page: its inner line, its corner brackets
local GUTTER_W = 28                       -- the line numbers' gutter
local GAUGE = 90                          -- the letters' gauge
local EDITOR = 232                      -- the editor, under the list
local BAR = 34                          -- the editor's header
local GUTTER = 10                       -- the scroll bar, left of the list
local STEP = HEAD * 1.5                 -- a turn of the wheel
local LETTERS = 255
local TYPE = Enum and Enum.ClickBindingType or { Macro = 2 }

local M = {}
ns.macros = M

local W = ns.spellbook
local page, body, switch, list, scroller, editor, layer
local cards = {}
M.cards = cards
local adopted, placing, shown = false, false, false
local edited = false                    -- the editor's text typed into since it was loaded
local fight = false                     -- in combat: from PLAYER_REGEN_DISABLED, which runs before the lockdown

local function Binding()
    return ns.db.spellbookClickCast and ns.clickcast ~= nil and ns.clickcast.Binding()
end

local function Plain(fs, size, color)
    fs:SetFont(PLAIN, size, "")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- the opened cards, by their macros' names
local function Opened(name)
    local t = MedalUICharDB and MedalUICharDB.macroOpen
    return type(t) == "table" and t[name] == true
end

local function Toggle(name)
    if not name then return end
    MedalUICharDB = MedalUICharDB or {}
    MedalUICharDB.macroOpen = type(MedalUICharDB.macroOpen) == "table" and MedalUICharDB.macroOpen or {}
    MedalUICharDB.macroOpen[name] = not Opened(name) or nil
end

-- The set shown: its tab (1 the account's, 2 the character's), how many
-- macros it holds, and the index before its first
local function Set()
    local f = MacroFrame
    local tab = PanelTemplates_GetSelectedTab(f) or 1
    local account, character = GetNumMacros()
    return tab, (tab == 1 and account or character) or 0, f.macroBase or 0
end

-- one of the game's buttons pressed, as its click would (while enabled)
local function Press(b)
    if not (b and b:IsEnabled()) then return end
    local click = b:GetScript("OnClick")
    if click then click(b, "LeftButton") end
end

-- Macros cannot change in combat. The game's save, new, rename and delete
-- call EditMacro, CreateMacro and DeleteMacro, which the game blocks in
-- combat for code an addon started, and pressing its buttons from ours is
-- that. So in combat: those buttons are off; the game's "text changed" mark
-- is held back (Adopt), so a switch, a tab or the window closing saves
-- nothing; and a move away from typed text waits until combat ends, so the
-- typing is not lost. Says so and returns true while in combat.
local function Combat() return fight or InCombatLockdown() end
local function Fighting()
    if not Combat() then return false end
    print("|cffe0b84aMedalUI|r: " .. Tr["macros cannot change in combat."])
    return true
end

-- a button of the game's that writes a macro: pressed out of combat only
local function Write(b)
    if Fighting() then return end
    Press(b)
end

-- a macro into the editor, as the game's own grid selects one
local function Select(i)
    local f = MacroFrame
    if not i or f:GetSelectedIndex() == i then return end
    if edited and Fighting() then return end
    f:SaveMacro()
    f:SelectMacro(i, true)
    if MacroPopupFrame then MacroPopupFrame:Hide() end
    MacroFrameText:ClearFocus()
end

-- Click Casting open: the macro into its waiting slot (a slot made first)
local function Bind(index)
    local f = _G.ClickBindingFrame
    if not (f and f.AddNewAction and index) then return end
    if f.HasNewSlot and not f:HasNewSlot() then
        local add = f.AddBindingButton
        local click = type(add) == "table" and add.GetScript and add:GetScript("OnClick")
        if click then click(add, "LeftButton") end
        if not f:HasNewSlot() then return end
    end
    f:AddNewAction(TYPE.Macro, index)
end

-- the first line that is not a #show
local function First(text)
    for line in (text or ""):gmatch("[^\n]+") do
        if not line:match("^%s*#") then return line end
    end
    return ""
end

local function Spell(index)
    local id = GetMacroSpell and GetMacroSpell(index)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local Refresh                           -- below: the page drawn again

-- A card's click: Click Casting open, either button binds it; else the
-- left opens or closes it and puts it in the editor. The right runs it:
-- the secure button's, the client's.
-- a spell's icon by its name (the game's answer, unless secret)
local function SpellIcon(name)
    local get = C_Spell and C_Spell.GetSpellTexture or _G.GetSpellTexture
    if not get or ns.IsSecret(name) then return end
    local ok, tex = pcall(get, name)
    if ok and tex and not ns.IsSecret(tex) then return tex end
end

local function Click(c, button)
    if not c.i then return end
    if Binding() then
        Bind(c.index)
    elseif button == "LeftButton" then
        -- typed text kept in the editor through combat (Fighting): not even folded
        if edited and c.i ~= MacroFrame:GetSelectedIndex() and Fighting() then return end
        Toggle(c.name)
        Select(c.i)
        Refresh()
    end
end

local function Tooltip(owner, c)
    if not c.name then return end
    local spell = Spell(c.index)
    ns.Tip(owner, ns.window.Outside, { title = c.name, color = GOLD,
        spell and { "body", format(Tr["Casts %s"], spell), ns.colors.dim } or false,
        c.clicks and { "body", format(Tr["Click casting: %s"], c.clicks), GOLD } or false,
        Binding() and { "body", Tr["Click to bind it."], GOLD } or false,
        not Binding() and { "body",
            Opened(c.name) and Tr["Left-click to fold it."] or Tr["Left-click to show and edit it."] }
            or false,
        not Binding() and { "body", Tr["Right-click to run it."] } or false,
        { "hint", Tr["Drag it to an action bar."] } })
end

-- ------------------------------------------------------------------ cards
-- A macro's card, pooled: a dark box with a brown edge (gold while it is
-- in the editor, a gold bar at its left), its head a strip fading right.
local function Card(n)
    local c = CreateFrame("Button", nil, scroller.child)
    c:SetFrameLevel(scroller.child:GetFrameLevel() + 1)
    local ink = ns.colors.ink
    -- a plate (2026-11-25, the user's: no shadow, as the LFG's): an ink
    -- body, its head lit from above, a gold line along its top and a dark
    -- one under it; its top left corner (CUT) not there, the medallion's
    -- rim the corner
    c.fill = c:CreateTexture(nil, "BACKGROUND", nil, -7)
    c.fill:SetPoint("TOPLEFT", 0, -CUT.y)
    c.fill:SetPoint("BOTTOMRIGHT")
    c.fill:SetColorTexture(ink[1], ink[2], ink[3], 0.96)
    c.fillTop = c:CreateTexture(nil, "BACKGROUND", nil, -7)
    c.fillTop:SetPoint("TOPLEFT", CUT.x, 0)
    c.fillTop:SetPoint("TOPRIGHT")
    c.fillTop:SetHeight(CUT.y)
    c.fillTop:SetColorTexture(ink[1], ink[2], ink[3], 0.96)
    -- the corner's curve: an ink disc under the medallion, the plate's
    -- body round to its rim
    c.disc = c:CreateTexture(nil, "BACKGROUND", nil, -7)
    c.disc:SetSize(MEDAL, MEDAL)
    c.disc:SetPoint("CENTER", c, "TOPLEFT", CUT.x, -CUT.y)
    c.disc:SetTexture(ns.media .. "strips\\round")
    c.disc:SetVertexColor(ink[1], ink[2], ink[3], 0.96)
    c.band = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.band:SetPoint("TOPLEFT", CUT.x, -1)
    c.band:SetPoint("TOPRIGHT", -1, -1)
    c.band:SetHeight(HEAD - 1)
    R.Shade(c.band, PLATE_TOP, { ink[1], ink[2], ink[3], 0 })
    c.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT", CUT.x, 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT", 0, -CUT.y }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = c:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], side[3] or 0, side[4] or 0)
        t:SetPoint(side[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        c.edges[i] = t
    end
    c.foot = c:CreateTexture(nil, "BORDER", nil, 1)
    c.foot:SetPoint("BOTTOMLEFT", 1, 1)
    c.foot:SetPoint("BOTTOMRIGHT", -1, 1)
    c.foot:SetHeight(1)
    c.foot:SetColorTexture(0, 0, 0, 0.9)
    -- held: a soft gold glow round it, two lines out from its edge
    c.halo = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, -1 },
        { "TOPLEFT", "BOTTOMLEFT", -1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local t = c:CreateTexture(nil, "BACKGROUND", nil, -8)
        local dx, dy = side[3] * GLOW, side[4] * GLOW
        local ex, ey = (side[3] == 0) and GLOW or 0, (side[4] == 0) and GLOW or 0
        -- (the top's and the left's from the cut corner: from where the
        -- ring round it leaves their line, not over it twice)
        local away = math.floor(math.sqrt((MEDAL / 2 + GLOW) ^ 2 - (MEDAL / 2) ^ 2))
        local cx = i == 1 and CUT.x + away or 0
        local cy = i == 3 and -(CUT.y + away) or 0
        t:SetPoint(side[1], dx - ex + cx, dy + ey + cy)
        t:SetPoint(side[2], dx + ex, dy - ey)
        if i <= 2 then t:SetHeight(GLOW) else t:SetWidth(GLOW) end
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
        t:Hide()
        c.halo[i] = t
    end
    -- and round the corner's curve: a ring GLOW out from the medallion's rim
    local curve = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    curve:SetSize(MEDAL + 2 * GLOW, MEDAL + 2 * GLOW)
    curve:SetPoint("CENTER", c, "TOPLEFT", CUT.x, -CUT.y)
    curve:SetTexture(ns.media .. "strips\\round")
    curve:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    curve:Hide()
    c.halo[5] = curve
    -- the icon: a medallion in the plate's cut corner, its rim the corner
    c.icon = c:CreateTexture(nil, "ARTWORK", nil, 3)
    c.icon:SetSize(MEDAL, MEDAL)
    c.icon:SetPoint("CENTER", c, "TOPLEFT", CUT.x, -CUT.y)
    c.medal = R.Medal(c, c.icon, 3, "ARTWORK")
    c.label = ns.Text(c, 12)
    c.label:SetPoint("TOPLEFT", TEXT_X, -8)
    c.label:SetPoint("RIGHT", -30, 0)
    c.label:SetJustifyH("LEFT")
    c.label:SetWordWrap(false)
    c.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    -- its click-cast binding: a small mouse in a gold ring on the icon's
    -- corner (as the book's spells), its click at the head's right
    c.badge = CreateFrame("Frame", nil, c)
    c.badge:SetSize(20, 20)
    c.badge:SetPoint("CENTER", c.icon, "BOTTOMRIGHT", -3, 3)
    local ring = c.badge:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetAllPoints()
    ring:SetTexture(ns.media .. "strips\\round")
    ring:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local disc = c.badge:CreateTexture(nil, "ARTWORK", nil, 2)
    disc:SetPoint("TOPLEFT", 1, -1)
    disc:SetPoint("BOTTOMRIGHT", -1, 1)
    disc:SetTexture(ns.media .. "strips\\round")
    disc:SetVertexColor(ink[1], ink[2], ink[3], 1)
    local mouse = c.badge:CreateTexture(nil, "ARTWORK", nil, 3)
    mouse:SetSize(15, 15)
    mouse:SetPoint("CENTER")
    mouse:SetTexture(ns.media .. "strips\\mouse")
    mouse:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    c.badge:Hide()
    c.keys = ns.Text(c, 11)
    c.keys:SetPoint("TOPRIGHT", -30, -8)
    c.keys:SetJustifyH("RIGHT")
    c.keys:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.first = ns.Text(c, 10)
    Plain(c.first, 11, ns.colors.dim)
    c.first:SetPoint("TOPLEFT", TEXT_X, -26)
    c.first:SetPoint("RIGHT", -30, 0)
    c.first:SetJustifyH("LEFT")
    c.first:SetWordWrap(false)
    c.sign = ns.Text(c, 14)
    c.sign:SetPoint("TOPRIGHT", -12, -14)
    c.sign:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    -- opened: a rule under the head, the whole text, Delete at the foot
    c.rule = c:CreateTexture(nil, "ARTWORK")
    c.rule:SetHeight(1)
    c.rule:SetPoint("TOPLEFT", TEXT_X, -HEAD)
    c.rule:SetPoint("TOPRIGHT", -12, -HEAD)
    c.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    c.text = ns.Text(c, 11)
    Plain(c.text, 12, ns.colors.text)
    c.text:SetPoint("TOPLEFT", TEXT_X, -(HEAD + 7))
    c.text:SetJustifyH("LEFT")
    c.text:SetJustifyV("TOP")
    c.text:SetWordWrap(true)
    c.delete = CreateFrame("Button", nil, c)
    c.delete:SetSize(64, 20)
    c.delete:SetPoint("BOTTOMRIGHT", -8, 6)
    c.delete:SetFrameLevel(c:GetFrameLevel() + 2)
    -- a quiet word, lit gold under the mouse
    c.delete.label = ns.Text(c.delete, 11)
    c.delete.label:SetPoint("RIGHT", -4, 0)
    c.delete.label:SetText(Tr["Delete"])
    c.delete.label:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
    -- the game's own confirm, which deletes the macro in the editor
    c.delete:SetScript("OnClick", function()
        if Fighting() then return end
        Select(c.i)
        Press(MacroDeleteButton)
    end)
    c.delete:SetScript("OnEnter", function(self)
        ns.Tip(self, ns.window.Outside, { title = format(Tr["Delete %s"], c.name or ""), color = GOLD,
            { "body", Tr["Asks first."] } })
    end)
    c.delete:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c.delete:HookScript("OnEnter", function(self) self.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
    c.delete:HookScript("OnLeave", function(self) self.label:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3]) end)
    -- what the secure button covers: the head within the edges, the
    -- medallion with it
    c.hit = CreateFrame("Frame", nil, c)
    c.hit:SetPoint("TOPLEFT", 0, -1)
    c.hit:SetPoint("TOPRIGHT", -1, -1)
    c.hit:SetHeight(HEAD - 1)
    -- under the mouse: the plate's head lit (not the square round the medallion)
    c.glow = c:CreateTexture(nil, "HIGHLIGHT")
    c.glow:SetPoint("TOPLEFT", CUT.x, -1)
    c.glow:SetPoint("TOPRIGHT", -1, -1)
    c.glow:SetHeight(HEAD - 1)
    c.glow:SetColorTexture(1, 1, 1, 0.06)
    -- in combat (the secure layer away), or cut by the scroll's edge: the
    -- left opens it, the right runs nothing
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnClick", function(self, button) Click(self, button) end)
    c:SetScript("OnDragStart", function(self)
        if self.index and not InCombatLockdown() then PickupMacro(self.index) end
    end)
    c:SetScript("OnEnter", function(self) Tooltip(self, self) end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cards[n] = c
    return c
end

-- -------------------------------------------------------- the secure layer
-- One secure button over each card's head wholly in view: the right button
-- runs its macro (type2, so the left runs nothing). Out of combat only;
-- a state driver hides the layer in combat.
local function Secure(n)
    local b = layer.buttons[n]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.card and self.card.index and not InCombatLockdown() then PickupMacro(self.card.index) end
    end)
    b:SetScript("PostClick", function(self, button, down)
        if down and Binding() then return end
        if self.card then Click(self.card, button) end
    end)
    b:SetScript("OnEnter", function(self) if self.card then Tooltip(self, self.card) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- (it covers the medallion too: lit right of its middle, the cut corner clear)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", CUT.x, 0)
    glow:SetPoint("BOTTOMRIGHT")
    glow:SetColorTexture(1, 1, 1, 0.06)
    layer.buttons[n] = b
    return b
end

local function Arm(b, c)
    local run = c and c.index and not Binding()
    b:SetAttribute("type", nil)
    b:SetAttribute("type2", run and "macro" or nil)
    b:SetAttribute("macro", run and c.index or nil)
end

local function Follow()
    if not layer or InCombatLockdown() then return end
    local top = scroller.offset or 0
    local bottom = top + (scroller.scroll:GetHeight() or 0)
    local n = 0
    for _, c in ipairs(shown and cards or {}) do
        if c:IsShown() and c.i and c.y >= top - 0.5 and c.y + HEAD <= bottom + 0.5 then
            n = n + 1
            local b = Secure(n)
            b.card = c
            Arm(b, c)
            if Binding() then
                b:RegisterForClicks("AnyUp", "AnyDown")
            else
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown")
            end
            b:SetShown(W.Over(b, c.hit))
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.card = nil
        Arm(b, nil)
        b:Hide()
    end
    if shown then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ----------------------------------------------------------------- the tabs
-- The two sets as the book's tabs (2026-11-20): in the panel the shell joins
-- under the head, each half of it, its name and its count under; the one
-- shown held, a gold wash and a gold line under its words. The first's
-- words centred in what the medallion's step leaves.
local function Tabs(panel)
    local t = { buttons = {} }
    local function Cell(i)
        local c = CreateFrame("Button", nil, panel)
        c.wash = c:CreateTexture(nil, "BACKGROUND", nil, 3)
        c.wash:SetAllPoints()
        c.wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.3)
        c.line = c:CreateTexture(nil, "ARTWORK")
        c.line:SetHeight(2)
        c.line:SetPoint("BOTTOMLEFT", 10, 1)
        c.line:SetPoint("BOTTOMRIGHT", -10, 1)
        c.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        if i > 1 then
            local split = c:CreateTexture(nil, "BORDER")
            split:SetWidth(1)
            split:SetPoint("TOPLEFT", -1, 0)
            split:SetPoint("BOTTOMLEFT", -1, 0)
            split:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        end
        c.label = ns.Text(c, 12)
        c.label:SetWordWrap(false)
        c.count = ns.Text(c, 9)
        local glow = c:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.06)
        c:SetScript("OnClick", function(self) if self.enabled and self.data.click then self.data.click() end end)
        c:SetScript("OnEnter", function(self)
            if self.data and self.data.tip then
                ns.Tip(self, ns.window.OutsideTop,
                    { title = self.data.name, color = GOLD, { "body", self.data.tip() } })
            end
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t.buttons[i] = c
        return c
    end
    function t:Fill(items)
        local width = (panel:GetWidth() or 0) > 0 and panel:GetWidth() or (W.width + 2 * ns.window.pad)
        local clear = (W.step or 40) + 6
        for i, d in ipairs(items) do
            local c = self.buttons[i] or Cell(i)
            local x0, x1 = math.floor((i - 1) * width / #items), math.floor(i * width / #items)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, 0)
            c:SetSize(x1 - x0, panel:GetHeight() > 0 and panel:GetHeight() or 44)
            c.data, c.selected, c.enabled = d, d.selected, d.enabled
            local shift = i == 1 and clear / 2 or 0
            c.label:ClearAllPoints()
            c.label:SetPoint("CENTER", shift, 7)
            c.count:ClearAllPoints()
            c.count:SetPoint("CENTER", shift, -9)
            c.label:SetText(d.name)
            c.count:SetText(d.count)
            c.wash:SetShown(d.selected)
            c.line:SetShown(d.selected)
            local nc = not d.enabled and OFF or d.selected and GOLD or ns.colors.dim
            c.label:SetTextColor(nc[1], nc[2], nc[3])
            local cc = d.selected and ns.colors.dim or OFF
            c.count:SetTextColor(cc[1], cc[2], cc[3])
            c:Show()
        end
        self.items = items
    end
    panel:HookScript("OnSizeChanged", function() if t.items then t:Fill(t.items) end end)
    return t
end

-- ----------------------------------------------------------------- drawing
local function Switch()
    local tab = Set()
    local account, character = GetNumMacros()
    local consts = Constants and Constants.MacroConsts or {}
    local free = not (MacroPopupFrame and MacroPopupFrame:IsShown())
    switch:Fill({
        { key = 1, name = Tr["General##macros"],
            count = format("%d / %d", account or 0, consts.MAX_ACCOUNT_MACROS or 120),
            selected = tab == 1, enabled = free or tab == 1,
            click = function() M.Tab(1) end, tip = function() return Tr["The macros every character shares."] end },
        { key = 2, name = UnitName("player") or Tr["Character"],
            count = format("%d / %d", character or 0, consts.MAX_CHARACTER_MACROS or 18),
            selected = tab == 2, enabled = free or tab == 2,
            click = function() M.Tab(2) end, tip = function() return Tr["This character's own macros."] end },
    })
end

local function Cards()
    local f = MacroFrame
    local _, count, base = Set()
    local selected = f:GetSelectedIndex()
    -- (2026-11-25, the user's: equal margins) MARGIN from the floor's every
    -- edge: the medallion's left the scroll's (the gutter, MARGIN wide, its
    -- bar in it), the plate's right, the first's top, the last's foot
    local width = W.width - GUTTER - MARGIN
    local y = MARGIN
    -- the profile's macro bindings (the book's option, as its spells')
    local bound = ns.db.spellbookClickCast and ns.clickcast and ns.clickcast.Macros and ns.clickcast.Macros() or {}
    local binding = Binding()
    for i = 1, count do
        local c = cards[i] or Card(i)
        local name, icon, text = GetMacroInfo(base + i)
        text = text or ""
        c.i, c.index, c.name = i, base + i, name
        c.icon:SetTexture(icon)
        c.label:SetText(name or "")
        -- bound: the mouse and its click (in bind mode, as the book's, not)
        c.clicks = bound[base + i]
        local keys = c.clicks ~= nil and not binding
        c.badge:SetShown(keys)
        c.keys:SetShown(keys)
        c.keys:SetText(c.clicks or "")
        if keys then
            c.label:SetPoint("RIGHT", c.keys, "LEFT", -8, 0)
        else
            c.label:SetPoint("RIGHT", c, "RIGHT", -30, 0)
        end
        c.first:SetText(First(text))
        local open = name ~= nil and Opened(name)
        c.sign:SetText(open and "-" or "+")
        c.first:SetShown(not open)
        c.rule:SetShown(open)
        c.text:SetShown(open)
        c.delete:SetShown(open)
        local h = HEAD
        if open then
            c.text:SetWidth(width - TEXT_X - 14)
            c.text:SetText(text)
            local lines = select(2, text:gsub("\n", "")) + 1
            h = HEAD + 7 + math.max(lines * LINE, c.text:GetStringHeight() or 0) + 8 + 20 + 6
        end
        -- held: its edge, its top line and its medallion's rim in gold, the glow
        local on = i == selected
        local edge = on and GOLD or GOLD_D
        for k, t in ipairs(c.edges) do
            t:SetColorTexture(edge[1], edge[2], edge[3], (on or k == 1) and 1 or 0.6)
        end
        for _, t in ipairs(c.halo) do t:SetShown(on) end
        c.medal.rim:SetVertexColor(edge[1], edge[2], edge[3], 1)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetSize(width, h)
        c.y, c.h = y, h
        c:Show()
        y = y + h + SPACE
    end
    for i = count + 1, #cards do
        cards[i].i, cards[i].index, cards[i].name = nil, nil, nil
        cards[i]:Hide()
    end
    scroller.child:SetSize(W.width - GUTTER, math.max(1, y - SPACE + MARGIN))
end

-- The editor's header and foot: the macro in it, what the game's buttons
-- allow, Save marked while there is typing to save
local function Paint()
    local f = MacroFrame
    if not (editor and f and adopted) then return end
    local _, count, base = Set()
    local selected = f:GetSelectedIndex()
    local index = selected and base + selected
    local name, icon
    if index then name, icon = GetMacroInfo(index) end
    editor.icon:SetTexture(icon)
    editor.icon:SetShown(name ~= nil)
    editor.medal.rim:SetShown(name ~= nil)
    editor.medal.well:SetShown(name ~= nil)
    editor.name:SetText(name or "")
    editor.pencil:SetShown(name ~= nil)
    local free = not Combat()
    editor.pencil:SetAlpha(free and MacroEditButton:IsEnabled() and 1 or 0.4)
    editor.empty:SetShown(count == 0)
    local can = name ~= nil
    editor.buttons:Set("new", { enabled = free and MacroNewButton:IsEnabled() })
    editor.buttons:Set("save", { enabled = free and can, selected = free and can and edited })
    editor.buttons:Set("cancel", { enabled = can and edited })
    local spell = index and Spell(index)
    -- the spell it casts, its icon before its name
    local tex = spell and SpellIcon(spell)
    local said = spell and (tex and format("|T%s:14:14:0:0:64:64:5:59:5:59|t %s", tex, spell) or spell)
    editor.casts:SetText(said and format(Tr["Casts %s"], said) or "")
    local letters = can and MacroFrameText:GetNumLetters() or 0
    editor.count:SetText(can and format("%d / %d", letters, LETTERS) or "")
    editor.gauge:SetShown(can)
    editor.fill:SetShown(can and letters > 0)
    editor.fill:SetWidth(math.max(1, GAUGE * math.min(1, letters / LETTERS)))
    editor.Number()
end

function Refresh()
    if not (adopted and scroller and MacroFrame:IsShown()) then return end
    Switch()
    Cards()
    scroller.To(scroller.target)
    Paint()
    Follow()
end
M.Refresh = Refresh

-- ---------------------------------------------------------------- editor
-- The editor's buttons: a joined engraved tray at the head's right (the
-- zone tray's recipe, strips/zonecontrols.lua), the ink solid under the
-- buttons and fading out leftwards, a gold line along its top and foot.
-- Each button in the chamfered engraved frame, a glyph and its word; Save
-- filled gold while there is typing to save. t:Set(key, { enabled,
-- selected }) as ns.window.Segments' (Paint), t.byKey its buttons.
local function Tray(parent, items)
    local t = CreateFrame("Frame", nil, parent)
    t.byKey, t.list = {}, {}
    local ink = ns.colors.ink
    local fade = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    fade:SetPoint("TOPRIGHT", t, "TOPLEFT")
    fade:SetPoint("BOTTOMRIGHT", t, "BOTTOMLEFT")
    fade:SetWidth(TRAY.fade)
    fade:SetColorTexture(1, 1, 1, 1)
    if fade.SetGradient and CreateColor then
        fade:SetGradient("HORIZONTAL", CreateColor(ink[1], ink[2], ink[3], 0), CreateColor(ink[1], ink[2], ink[3], 1))
    else
        fade:SetColorTexture(ink[1], ink[2], ink[3], 0.5)
    end
    local solid = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    solid:SetAllPoints()
    solid:SetColorTexture(ink[1], ink[2], ink[3], 1)
    for _, at in ipairs({ "TOP", "BOTTOM" }) do
        local line = t:CreateTexture(nil, "BORDER")
        line:SetPoint(at .. "LEFT", fade, at .. "LEFT")
        line:SetPoint(at .. "RIGHT", t, at .. "RIGHT")
        line:SetHeight(1)
        if line.SetGradient and CreateColor then
            line:SetColorTexture(1, 1, 1, 1)
            line:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1))
        else
            line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
        end
    end
    local x = TRAY.pad
    for _, item in ipairs(items) do
        local b = CreateFrame("Button", nil, t)
        b.key, b.enabled, b.selected = item.key, true, false
        b:SetSize(TRAY.button, TRAY.height)
        b:SetPoint("LEFT", t, "LEFT", x, 0)
        x = x + TRAY.button + TRAY.gap
        R.Engrave(b)
        local face = R.Inside(b, "BACKGROUND", 2)
        face:SetColorTexture(ink[1], ink[2], ink[3], 1)
        b.mark = R.Inside(b, "BACKGROUND", 3)
        b.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
        b.mark:Hide()
        R.Inside(b, "HIGHLIGHT"):SetColorTexture(1, 1, 1, 0.12)
        b.glyph = b:CreateTexture(nil, "ARTWORK")
        b.glyph:SetTexture(R.GLYPHS .. item.glyph)
        b.glyph:SetSize(TRAY.glyph, TRAY.glyph)
        b.glyph:SetPoint("LEFT", 9, 0)
        b.label = ns.Text(b, 12)
        b.label:SetPoint("LEFT", b.glyph, "RIGHT", 4, 0)
        b.label:SetText(item.label)
        -- pressed while off too, as the joined buttons were: the press itself
        -- refuses in a fight, and says so (Fighting)
        b:SetScript("OnClick", function() item.click() end)
        b:SetScript("OnEnter", function(self)
            ns.Tip(self, ns.window.Outside, { title = item.label, color = GOLD, { "body", item.tip() } })
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t.byKey[item.key] = b
        table.insert(t.list, b)
    end
    t:SetSize(x - TRAY.gap + TRAY.pad, TRAY.height + 2 * TRAY.pad)
    local function Look(b)
        local c = b.selected and GOLD or (b.enabled and ns.colors.text or ns.colors.dim)
        b.label:SetTextColor(c[1], c[2], c[3])
        local g = b.selected and GOLD or (b.enabled and GOLD_D or ns.colors.dim)
        b.glyph:SetVertexColor(g[1], g[2], g[3])
        b.mark:SetShown(b.selected)
        b:SetAlpha(b.enabled and 1 or 0.4)
    end
    function t:Set(key, state)
        local b = self.byKey[key]
        if not b then return end
        if state.enabled ~= nil then b.enabled = state.enabled and true or false end
        b.selected = state.selected and true or false
        Look(b)
    end
    for _, b in ipairs(t.list) do Look(b) end
    return t
end

-- The text's line numbers, in a gutter at the well's left: one for each
-- of the text's lines, at the first row it wraps to (a hidden string of
-- the box's font and width measures each), moved with the box's scroll;
-- the cursor's line in gold. Drawn again as the text, the cursor, the
-- scroll or the size change.
local function Numbers(e)
    local g = e.gutter
    local pool = {}
    local meter = g:CreateFontString(nil, "ARTWORK")
    meter:Hide()
    Plain(meter, 13)
    meter:SetWordWrap(true)
    local function Number(k)
        local n = pool[k]
        if n then return n end
        n = g:CreateFontString(nil, "ARTWORK")
        Plain(n, 11)
        n:SetJustifyH("RIGHT")
        n:SetWidth(GUTTER_W - 6)
        pool[k] = n
        return n
    end
    function e.Number()
        local box, scroll = MacroFrameText, MacroFrameScrollFrame
        if not (box and scroll) then return end
        local text = box:GetText() or ""
        if ns.IsSecret(text) then text = "" end
        local width = box:GetWidth() or 0
        meter:SetWidth(width > 0 and width or 1)
        meter:SetText("X")
        local row = meter:GetStringHeight() or 13
        if row <= 0 then row = 13 end
        local cursor = box.GetCursorPosition and box:GetCursorPosition() or 0
        local here = select(2, text:sub(1, cursor):gsub("\n", "")) + 1
        local top = -(scroll:GetVerticalScroll() or 0)
        local rows, k = 0, 0
        for line in (text .. "\n"):gmatch("(.-)\n") do
            k = k + 1
            meter:SetText(line ~= "" and line or " ")
            local n = Number(k)
            n:ClearAllPoints()
            n:SetPoint("TOPRIGHT", g, "TOPRIGHT", -6, top - rows * row)
            n:SetText(k)
            local c = k == here and GOLD or GOLD_D
            n:SetTextColor(c[1], c[2], c[3], k == here and 1 or 0.7)
            n:Show()
            rows = rows + math.max(1, math.floor((meter:GetStringHeight() or row) / row + 0.5))
        end
        if text == "" then pool[1]:Hide() end
        for i = k + 1, #pool do pool[i]:Hide() end
    end
end

local function Editor(parent)
    local e = CreateFrame("Frame", nil, parent)
    e:SetPoint("BOTTOMLEFT")
    e:SetPoint("BOTTOMRIGHT")
    e:SetHeight(EDITOR)
    -- its header: the macro's medallion and name, the pencil, the tray
    e.head = CreateFrame("Frame", nil, e)
    e.head:SetPoint("TOPLEFT")
    e.head:SetPoint("TOPRIGHT")
    e.head:SetHeight(BAR)
    R.Box(e.head, 0.9)
    local band = e.head:CreateTexture(nil, "BACKGROUND", nil, -4)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("BOTTOMRIGHT", -1, 1)
    R.Shade(band, PLATE_TOP, { ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0 })
    e.icon = e.head:CreateTexture(nil, "ARTWORK", nil, 3)
    e.icon:SetSize(28, 28)
    e.icon:SetPoint("LEFT", 6, 0)
    e.medal = R.Medal(e.head, e.icon, 2, "ARTWORK")
    e.medal.rim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    e.ring = e.medal.rim
    e.name = ns.Text(e.head, 13)
    e.name:SetPoint("LEFT", e.icon, "RIGHT", 10, 0)
    e.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    e.name:SetWordWrap(false)
    e.pencil = CreateFrame("Button", nil, e.head)
    e.pencil:SetSize(28, 28)
    e.pencil:SetPoint("LEFT", e.name, "RIGHT", 6, 0)
    R.Glyph(e.pencil, "edit", 18)
    e.pencil:SetScript("OnClick", function() Write(MacroEditButton) end)
    e.pencil:SetScript("OnEnter", function(self)
        ns.Tip(self, ns.window.Outside, { title = Tr["Change its name and icon"], color = GOLD })
    end)
    e.pencil:SetScript("OnLeave", function() GameTooltip:Hide() end)
    e.buttons = Tray(e.head, {
        { key = "new", glyph = "plus", label = Tr["New"], click = function() Write(MacroNewButton) end,
            tip = function()
                return Combat() and Tr["Not in combat."] or Tr["A new macro in this set: its name and icon first."]
            end },
        { key = "save", glyph = "check", label = Tr["Save"], click = function() Write(MacroSaveButton) end,
            tip = function() return Combat() and Tr["Not in combat."] or Tr["Save the text."] end },
        { key = "cancel", glyph = "undo", label = Tr["Cancel"], click = function()
            if not edited then return end
            Press(MacroCancelButton)
            -- the text back as it was saved
            local i = MacroFrame:GetSelectedIndex()
            if i then MacroFrame:SelectMacro(i) end
        end, tip = function() return Tr["Put the text back as it was saved."] end },
    })
    e.buttons:SetPoint("RIGHT", -1, 0)
    -- the text: a page in a double frame, gold brackets at its corners, the
    -- game's own edit box laid in it right of the line numbers' gutter
    e.well = CreateFrame("Frame", nil, e)
    e.well:SetPoint("TOPLEFT", e.head, "BOTTOMLEFT", 0, -6)
    e.well:SetPoint("BOTTOMRIGHT", 0, 20)
    R.Box(e.well, 0.95)
    local inner = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = e.well:CreateTexture(nil, "BORDER")
        local sx = side[1]:find("RIGHT") and -PAGE.inset or PAGE.inset
        local sy = side[1]:find("BOTTOM") and PAGE.inset or -PAGE.inset
        local ex = side[2]:find("RIGHT") and -PAGE.inset or PAGE.inset
        local ey = side[2]:find("BOTTOM") and PAGE.inset or -PAGE.inset
        t:SetPoint(side[1], sx, sy)
        t:SetPoint(side[2], ex, ey)
        if side[3] then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.3)
        table.insert(inner, t)
    end
    e.brackets = {}
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        for _, across in ipairs({ true, false }) do
            local t = e.well:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            t:SetSize(across and PAGE.bracket or 2, across and 2 or PAGE.bracket)
            t:SetPoint(corner)
            table.insert(e.brackets, t)
        end
    end
    e.gutter = CreateFrame("Frame", nil, e.well)
    e.gutter:SetPoint("TOPLEFT", PAGE.inset, -8)
    e.gutter:SetPoint("BOTTOMLEFT", PAGE.inset, 8)
    e.gutter:SetWidth(GUTTER_W)
    e.gutter:SetClipsChildren(true)
    Numbers(e)
    e.empty = ns.Text(e.well, 12)
    e.empty:SetPoint("CENTER")
    e.empty:SetTextColor(unpack(ns.colors.dim))
    e.empty:SetText(Tr["No macros yet: + New to make one."])
    e.casts = ns.Text(e, 11)
    e.casts:SetPoint("BOTTOMLEFT", 4, 3)
    e.casts:SetTextColor(unpack(ns.colors.dim))
    e.count = ns.Text(e, 11)
    e.count:SetPoint("BOTTOMRIGHT", -4, 3)
    e.count:SetTextColor(unpack(ns.colors.dim))
    -- the letters used, as a gauge left of their count
    e.gauge = e:CreateTexture(nil, "ARTWORK")
    e.gauge:SetSize(GAUGE, 3)
    e.gauge:SetPoint("RIGHT", e.count, "LEFT", -10, 0)
    e.gauge:SetColorTexture(0, 0, 0, 1)
    e.fill = e:CreateTexture(nil, "ARTWORK", nil, 1)
    e.fill:SetHeight(3)
    e.fill:SetPoint("LEFT", e.gauge, "LEFT")
    e.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    return e
end

-- ---------------------------------------------------------------- adopting
local function Place()
    local f = MacroFrame
    placing = true
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", body, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
    placing = false
end

-- The game's scroll bar for the text, kept working (its arrows, track and
-- thumb its own), its art put away: ours a thin gold track and a gold
-- thumb on its own. Either kind the game gives: a track with a thumb
-- frame (retail's), or a thumb texture (the older panel bar).
local function ScrollBar(scroll)
    local bar = scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"])
    if not bar then return end
    local track = bar.Track
    local thumb = (track and track.Thumb) or bar.ThumbTexture or (bar.GetThumbTexture and bar:GetThumbTexture())
    for _, part in ipairs({ bar, track, track and track.Thumb, bar.Back, bar.Forward, bar.ScrollUpButton,
        bar.ScrollDownButton }) do
        if part and part.GetRegions then R.Bare(part) end
        if part and part.GetNormalTexture then R.Plain(part) end
    end
    if thumb and thumb.SetAlpha and not thumb.GetRegions then thumb:SetAlpha(0) end
    local line = bar:CreateTexture(nil, "BACKGROUND", nil, 7)
    line:SetPoint("TOP", 0, -4)
    line:SetPoint("BOTTOM", 0, 4)
    line:SetWidth(1)
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    if thumb then
        local host = thumb.CreateTexture and thumb or bar
        local t = host:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetPoint("TOP", thumb, "TOP")
        t:SetPoint("BOTTOM", thumb, "BOTTOM")
        t:SetWidth(3)
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    end
end

-- The game's frame bare: its art, its title and words away; its grid,
-- tabs and buttons hidden but working (ours call them), the ones its
-- details show again faded out instead
local function Strip(f)
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer", "CloseButton" }) do
        if f[key] then f[key]:Hide() end
    end
    for _, key in ipairs({ "Background", "Bg", "TopTileStreaks", "Inset" }) do
        if f[key] then
            f[key]:SetAlpha(0)
            if f[key].EnableMouse then f[key]:EnableMouse(false) end
        end
    end
    for _, r in ipairs({ f:GetRegions() }) do r:SetAlpha(0) end
    for _, part in ipairs({ f.MacroSelector, MacroFrameTab1, MacroFrameTab2, MacroSaveButton, MacroCancelButton,
        MacroDeleteButton, MacroNewButton, MacroExitButton, MacroFrameTextBackground }) do
        part:Hide()
    end
    for _, part in ipairs({ f.SelectedMacroButton, MacroEditButton }) do
        part:SetAlpha(0)
        part:EnableMouse(false)
    end
    f:EnableMouse(false)
    -- its text box in our well
    local scroll = MacroFrameScrollFrame
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", editor.gutter, "TOPRIGHT", 6, 0)
    scroll:SetPoint("BOTTOMRIGHT", editor.well, "BOTTOMRIGHT", -26, 8)
    Plain(MacroFrameText, 13, ns.colors.text)
    -- the line numbers follow the text, the cursor and the scroll
    MacroFrameText:HookScript("OnCursorChanged", function() editor.Number() end)
    if scroll.HookScript then
        scroll:HookScript("OnVerticalScroll", function() editor.Number() end)
        scroll:HookScript("OnScrollRangeChanged", function() editor.Number() end)
    end
    ScrollBar(scroll)
    -- the box as big as the well, so a press anywhere in it lands on the
    -- text and a drag selects; the game's button over it (which only
    -- focuses) out of the mouse's way
    local function Fit(w, h)
        if w and w > 0 then MacroFrameText:SetSize(w, h) end
    end
    MacroFrameText:SetSize(W.width - 36, EDITOR - BAR - 6 - 20 - 16)
    scroll:HookScript("OnSizeChanged", function(_, w, h) Fit(w, h) editor.Number() end)
    MacroFrameTextButton:ClearAllPoints()
    MacroFrameTextButton:SetAllPoints(scroll)
    MacroFrameTextButton:EnableMouse(false)
    -- a multi-line box takes a press only on its lines (2026-11-20: a new
    -- macro, no lines, could hardly be clicked into): under it, the whole
    -- well; a press there off the text focuses the box, its cursor at the
    -- end. On the text the box takes the press itself, its cursor there.
    local catcher = CreateFrame("Frame", nil, editor.well)
    catcher:SetAllPoints(editor.well)
    catcher:SetFrameLevel(math.max(0, math.min(scroll:GetFrameLevel(), MacroFrameText:GetFrameLevel()) - 1))
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function()
        MacroFrameText:SetFocus()
        MacroFrameText:SetCursorPosition(#(MacroFrameText:GetText() or ""))
    end)
    editor.catcher = catcher            -- (the harness reads it)
end

-- The name and icon picker: our box and a title strip it is dragged by,
-- floating left of the book, over it (DIALOG) if dragged there
local function Spot(p)
    p:ClearAllPoints()
    local wt, lt = W.window:GetTop(), list:GetTop()
    -- TOPLEFT: the game reads that point back to size its panel
    p:SetPoint("TOPLEFT", W.window, "TOPLEFT", -(p:GetWidth() + 8), (wt and lt) and lt - wt or 0)
end

-- Its parts in two columns, the grid's edges: the name's header and box
-- on the left, the chosen icon on the right as tall as both; "Choose an
-- Icon:" beside the icon filter; the grid under, OK and Cancel at the foot.
-- The chosen icon's two lines of words (currently selected, click to view
-- in the list) and its glow under the mouse away.
local NAME_HEADER = Tr["Macro Name (16 Characters Max):"]
local edges                             -- the grid's left and right insets, as the game lays it
local function Layout(p)
    local box = p.BorderBox
    local grid = p.IconSelector
    if not box or not grid then return end
    if not edges then
        local pl, pr, gl, gr = p:GetLeft(), p:GetRight(), grid:GetLeft(), grid:GetRight()
        edges = (pl and gl) and { math.floor(gl - pl + 0.5), math.floor(pr - gr + 0.5) } or { 14, 14 }
    end
    local L, Rt = edges[1], edges[2]
    local TOP, CHOSEN, ROW = 40, 42, 22     -- the first row's top; the chosen icon; the name's box
    local header, input = box.EditBoxHeaderText, box.IconSelectorEditBox
    if header then
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", p, "TOPLEFT", L, -TOP)
        header:SetText(NAME_HEADER)
        R.Font(header, 12, ns.colors.text)
    end
    local area = box.SelectedIconArea
    local chosen = area and area.SelectedIconButton
    if chosen then
        chosen:ClearAllPoints()
        chosen:SetPoint("TOPRIGHT", p, "TOPRIGHT", -Rt, -TOP + 2)
        chosen:SetSize(CHOSEN, CHOSEN)
        local glow = chosen.GetHighlightTexture and chosen:GetHighlightTexture()
        if glow then glow:SetAlpha(0) end
        if chosen.Highlight then chosen.Highlight:SetAlpha(0) end
    end
    if area and area.SelectedIconText then
        area.SelectedIconText:SetAlpha(0)
        area.SelectedIconText:Hide()
    end
    if input then
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", p, "TOPLEFT", L + 4, -(TOP + 18))
        input:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(Rt + CHOSEN + 14), -(TOP + 18))
        input:SetHeight(ROW)
    end
    local below = TOP + CHOSEN + 12
    local filter = box.IconTypeDropdown
    local fh = filter and filter:GetHeight() or 0
    if fh <= 0 then fh = 24 end
    if filter then
        filter:ClearAllPoints()
        filter:SetPoint("TOPRIGHT", p, "TOPRIGHT", -Rt, -below)
    end
    local choose = box.IconSelectionText
    if choose then
        choose:ClearAllPoints()
        choose:SetPoint("LEFT", p, "TOPLEFT", L, -(below + fh / 2))
        R.Font(choose, 12, ns.colors.text)
    end
    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", p, "TOPLEFT", L, -(below + fh + 10))
    grid:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -Rt, 44)
    local okay, cancel = box.OkayButton, box.CancelButton
    if okay and cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -Rt, 10)
        okay:ClearAllPoints()
        okay:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
    end
end

local function Popup()
    local p = MacroPopupFrame
    if not p then return end
    R.Bare(p)
    if p.BorderBox then R.Bare(p.BorderBox) end
    R.Box(p, 0.97)
    local top = CreateFrame("Frame", nil, p)
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(28)
    top:SetFrameLevel(p:GetFrameLevel() + 5)
    local band = top:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    R.Fade(band, GOLD_D, 0.55)
    local title = ns.Text(top, 13)
    title:SetPoint("LEFT", 10, 0)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() p:StartMoving() end)
    top:SetScript("OnDragStop", function()
        p:StopMovingOrSizing()
        if p.SetUserPlaced then p:SetUserPlaced(false) end
        -- held by its top left, the point the game reads back
        local x, y = p:GetLeft(), p:GetTop()
        if x and y then
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        end
    end)
    local cross = CreateFrame("Button", nil, top)
    cross:SetSize(22, 22)
    cross:SetPoint("RIGHT", -4, 0)
    local g = R.Glyph(cross, "close", 11)
    cross:SetScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
    cross:SetScript("OnLeave", function() g:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
    local box = p.BorderBox or {}
    cross:SetScript("OnClick", function() Press(box.CancelButton) end)
    for _, b in ipairs({ box.OkayButton, box.CancelButton }) do
        R.Plain(b)
        for _, k in ipairs({ "Left", "Right", "Middle" }) do
            if b[k] then b[k]:SetAlpha(0) end
        end
        R.Box(b, 0.4)
        R.Lit(b)
        R.Font(b.GetFontString and b:GetFontString(), 12, ns.colors.text)
    end
    p:HookScript("OnShow", function(self)
        self:SetFrameStrata("DIALOG")
        Spot(self)
        Layout(self)
        local new = IconSelectorPopupFrameModes and IconSelectorPopupFrameModes.New or "new"
        title:SetText(self.mode == new and Tr["New macro"] or Tr["Change name and icon"])
        Refresh()
    end)
    p:HookScript("OnHide", function() Refresh() end)
end

-- The game's own ways in (/macro, the game menu): its window put back, the
-- book opened on this page
local function Take()
    C_Timer.After(0, function()
        HideUIPanel(MacroFrame)
        Place()
        M.Open()
    end)
end

local function Adopt()
    local f = MacroFrame
    if adopted or not f or not body then return end
    adopted = true
    f:SetParent(body)
    f:SetToplevel(false)
    f:SetFrameLevel(editor:GetFrameLevel() + 4)
    Place()
    hooksecurefunc(f, "SetPoint", function() if not placing then Place() end end)
    Strip(f)
    Popup()
    -- each change of the game's: drawn again
    for _, method in ipairs({ "Update", "SelectMacro", "UpdateButtons" }) do
        hooksecurefunc(f, method, function() Refresh() end)
    end
    -- a macro loaded: nothing typed yet
    hooksecurefunc(f, "SelectMacro", function() edited = false Paint() end)
    hooksecurefunc(f, "ChangeTab", function() edited = false end)
    MacroFrameText:HookScript("OnTextChanged", function(_, user)
        if user then edited = true end
        -- in combat the game's mark is held back (Fighting), ours kept
        if Combat() then f.textChanged = nil end
        Paint()
    end)
    -- the game opens on the account's set: back to the one last shown
    f:HookScript("OnShow", function(self)
        local tab = MedalUICharDB and MedalUICharDB.macroTab
        if tab == 2 and PanelTemplates_GetSelectedTab(self) ~= 2 then self:ChangeTab(2) end
        Refresh()
    end)
    if MacroFrame_Show then hooksecurefunc("MacroFrame_Show", Take) end
end

local function Load()
    if not body then return false end
    if not MacroFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_MacroUI") end
    if MacroFrame then Adopt() end
    return adopted
end

-- ------------------------------------------------------------------ the page
-- The sets' tabs in the joined panel, the cards, the editor at the foot
function M.Build(p, b)
    page, body = p, b
    switch = Tabs(p.panel)
    list = CreateFrame("Frame", nil, b)
    list:SetPoint("TOPLEFT", 0, -4)
    list:SetPoint("BOTTOMRIGHT", 0, EDITOR + 10)
    -- the plates' floor: a faint engraved hatch, darkening to its edges,
    -- a faint gold edge round it
    local hatch = list:CreateTexture(nil, "BACKGROUND", nil, -8)
    hatch:SetAllPoints()
    hatch:SetTexture(ns.media .. "strips\\stripes", "REPEAT", "REPEAT")
    hatch:SetHorizTile(true)
    hatch:SetVertTile(true)
    hatch:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    hatch:SetAlpha(FLOOR.hatch)
    local vignette = list:CreateTexture(nil, "BACKGROUND", nil, -7)
    vignette:SetAllPoints()
    vignette:SetTexture(ns.media .. "gamemenu-vignette")
    vignette:SetVertexColor(0, 0, 0, FLOOR.vignette)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = list:CreateTexture(nil, "BACKGROUND", nil, -6)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[3] then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], FLOOR.edge)
    end
    scroller = ns.window.Scroller(list, GUTTER)
    scroller.Moved = function() Follow() end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) scroller.To(scroller.target - delta * STEP) end)
    editor = Editor(b)
    layer = W.Layer("MedalUISpellbookMacros")
    M.switch, M.list, M.scroller, M.editor, M.layer = switch, list, scroller, editor, layer
    M.page = p
    ns.On("PLAYER_REGEN_ENABLED", Follow)
    -- combat: the game's "text changed" held back, and the name and icon
    -- picker and the delete confirm put away, as neither could save
    ns.On("PLAYER_REGEN_DISABLED", function()
        fight = true
        if not adopted then return end
        MacroFrame.textChanged = nil
        if MacroPopupFrame and MacroPopupFrame:IsShown() then MacroPopupFrame:Hide() end
        if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_DELETE_SELECTED_MACRO") end
        Paint()
    end)
    -- after it: typed text marked again for the game to save
    ns.On("PLAYER_REGEN_ENABLED", function()
        fight = false
        if not adopted then return end
        if edited and MacroFrame:IsShown() then MacroFrame.textChanged = 1 end
        Paint()
    end)
    if MacroFrame then Adopt() end
end

-- the set switched: the game's own tab pressed (which saves the text first)
function M.Tab(n)
    local tab = _G["MacroFrameTab" .. n]
    if not tab or PanelTemplates_GetSelectedTab(MacroFrame) == n then return end
    if MacroPopupFrame and MacroPopupFrame:IsShown() then return end
    if edited and Fighting() then return end
    MedalUICharDB = MedalUICharDB or {}
    MedalUICharDB.macroTab = n
    local click = tab:GetScript("OnClick")
    if click then click(tab, "LeftButton") end
end

-- the window open on the page, or not
function M.Showing(on)
    shown = on and true or false
    if on then
        if Load() then
            Place()
            if not MacroFrame:IsShown() then MacroFrame:Show() end
            Refresh()
        end
    elseif adopted and MacroFrame:IsShown() then
        MacroFrame:Hide()
    end
    Follow()
end

-- the book opened on this page (out of combat: the book's frame is the
-- game's, protected)
function M.Open()
    if not page then return end
    W.Select(page)
    if W.window:IsShown() then return end
    ns.OutOfCombat(function()
        if W.window:IsShown() then return end
        if PlayerSpellsUtil and PlayerSpellsUtil.OpenToSpellBookTab then
            PlayerSpellsUtil.OpenToSpellBookTab()
        elseif PlayerSpellsUtil and PlayerSpellsUtil.TogglePlayerSpellsFrame then
            PlayerSpellsUtil.TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.SpellBook)
        end
    end)
end

ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_MacroUI" then Adopt() end
end)
