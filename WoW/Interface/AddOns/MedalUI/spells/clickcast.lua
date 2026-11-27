-- Click Casting (/cc): the game's own window (ClickBindingFrame,
-- Blizzard_ClickBindingUI) dressed as the Cooldown Manager is, standing in
-- the LFG window's spot (window/reskin.lua) while the spellbook opens on
-- the right strip beside it.
--
--   Click Casting                                          [x]
--   ---------------------------------------------------------
--   [v] Mouseover cast   with Shift v                 | (book) (macros)
--   - DEFAULT ------------------------------------------
--   +----------------------------------------------+(o)
--   | Target unit frame                              (o)    a binding: a glass
--   | [Left]                                       |        plate, its medallion
--   +----------------------------------------------+        in its cut corner
--   - CUSTOM -------------------------------------------
--   +----------------------------------------------+(o)
--   | Healing Wave                     (pen) (x)     (o)
--   | [Shift] + [Middle]                           |        its click as keycaps
--   +----------------------------------------------+
--   | Click on a spell or macro to get started       (+)    the slot waiting for one
--   ---------------------------------------------------------
--   BINDER  (1) Pick a spell - (2) Click the pad - (3) Save
--     (o) Healing Wave   [ (mouse) Click here with the click you want ]
--   ---------------------------------------------------------
--   [<-] | [ + Add binding ]                        | [ Save ]
--
-- Every click, drop, menu and save is the game's own code; ours is its look,
-- its place, and the binder, whose pad passes its click to the game's own
-- click on the binding's line.
--
-- ns.clickcast.Keys(info) and ns.clickcast.Bound() serve the spellbook too
-- (spells/spellbook.lua): a binding's click as words, and the bindings by
-- spell.
local _, ns = ...
local Tr = ns.L

local R = ns.reskin
local deco = R.deco
local PAD, ROW, EDGE = R.PAD, R.ROW, R.EDGE
local GOLD, GOLD_D, DIM = R.GOLD, R.GOLD_D, R.DIM
local GLYPHS, ROUND = R.GLYPHS, R.ROUND
local HEAD = 36
local TOP = -(HEAD + 18)            -- the top row's top, under the head's hairs
local LIST = TOP - ROW - 12         -- the list's top, under it
local FOOT = 1 + ROW + 12           -- the list's foot, over the foot row
local BINDER = 128                  -- the binder, over the foot
-- (2026-11-27, the user's: the rails' look and feel) the top row and the
-- foot each a sunk tray (ns.reskin.Recess), its cells engraved slots
-- apart in it (ns.reskin.Slot, the window bands' look), the window open
-- beside it and Save with changes held (ns.reskin.Held)
local SLOT_GAP = 3                  -- between the slots, and round them in the tray
local SLOT = ROW - 2 * SLOT_GAP     -- a slot's height (a square slot's side)
-- (2026-11-27, the user's: the macros' plates, see-through, mirrored;
-- then square ends and a square icon) a binding is a glass plate, its
-- spell's icon a square closing its right end, a gold line between
local PLATE = { top = 1, foot = 3 } -- the plate in from its line's top and foot (the gap between)
local ICON = 40                     -- the icon: the plate's height inside its edges (from the line's, Size)
local GLASS = { fill = 0.45, head = { 0.16, 0.14, 0.11, 0.55 }, wash = 0.14 }
local CONTROL = { size = 26, edit = 16, delete = 15, lock = 18, gap = 2 }  -- its edit, lock, delete: the button, glyphs
local TEXT_X = 10                   -- its words, in from its left edge
local CONTROLS = 8                  -- its edit, lock and delete, left of the icon (plus its size)
-- (2026-11-27, the user's) a binding locked: its plate tinted blue, its
-- padlock lit, the item locks' blue (inventory/slots.lua)
local BLUE = { 0.45, 0.75, 1 }
local TINT = 0.10                   -- the plate's blue
local TYPE = Enum and Enum.ClickBindingType or { None = 0, Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 }
local NEW_SLOT = 5                  -- the game's ElementDataTypes.NewSlot
local DEFAULT_LINE = 2              -- its ElementDataTypes.DefaultBinding (no delete)

local cc = {}
ns.clickcast = cc

local skin

local function Frame() return _G.ClickBindingFrame end

-- ---------------------------------------------------------------- the keys
-- A binding's click as words: its modifiers (the game's own names for them)
-- and its button, short. { "Shift", "Middle" }, "Shift+Middle"; nil when
-- it has no button (unbound).
local BUTTONS = { LeftButton = Tr["Left##mouse"], Button1 = Tr["Left##mouse"], RightButton = Tr["Right##mouse"],
    Button2 = Tr["Right##mouse"], MiddleButton = Tr["Middle##mouse"], Button3 = Tr["Middle##mouse"] }

local function Mods(m)
    if not m or m == 0 then return "" end
    local f = C_ClickBindings and C_ClickBindings.GetStringFromModifiers or _G.GetStringFromModifiers
    if not f then return "" end
    local ok, s = pcall(f, m)
    return ok and type(s) == "string" and s or ""
end

function cc.Keys(info)
    if type(info) ~= "table" or type(info.button) ~= "string" then return nil end
    local keys = {}
    for word in Mods(info.modifiers):gmatch("[^%-%+%s]+") do
        table.insert(keys, word:sub(1, 1):upper() .. word:sub(2):lower())
    end
    table.insert(keys, BUTTONS[info.button] or (info.button:gsub("^Button(%d+)$",
        function(n) return format(Tr["Mouse %s"], n) end)))
    return keys, table.concat(keys, "+")
end

-- The profile's spell and pet bindings: by spell ID, and by name (a binding
-- set on another rank of a spell still marks the rank the book shows).
-- Each a list of { text, pet }.
function cc.Bound()
    local ids, names = {}, {}
    local get = C_ClickBindings and C_ClickBindings.GetProfileInfo
    if not get then return ids, names end
    local ok, profile = pcall(get)
    if not ok or type(profile) ~= "table" then return ids, names end
    for _, info in ipairs(profile) do
        local pet = info.type == TYPE.PetAction
        if (info.type == TYPE.Spell or pet) and info.actionID then
            local _, text = cc.Keys(info)
            if text then
                local b = { text = text, pet = pet }
                ids[info.actionID] = ids[info.actionID] or {}
                table.insert(ids[info.actionID], b)
                local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(info.actionID)
                if name then
                    names[name] = names[name] or {}
                    table.insert(names[name], b)
                end
            end
        end
    end
    return ids, names
end

-- The profile's macro bindings: by macro index, their clicks as words
-- ("Shift+Middle, Left")
function cc.Macros()
    local out = {}
    local get = C_ClickBindings and C_ClickBindings.GetProfileInfo
    if not get then return out end
    local ok, profile = pcall(get)
    if not ok or type(profile) ~= "table" then return out end
    for _, info in ipairs(profile) do
        if info.type == TYPE.Macro and info.actionID then
            local _, text = cc.Keys(info)
            if text then out[info.actionID] = out[info.actionID] and out[info.actionID] .. ", " .. text or text end
        end
    end
    return out
end

-- ---------------------------------------------------------------- the locks
-- (2026-11-27, the user's: "so they can't be accidentally assigned
-- elsewhere") A binding locked keeps its click: a click on its own line
-- (or on the binder's pad with it loaded) does not change it, and no other
-- binding can take it (the game unbinds a clash). On this character, by
-- the binding and its click: "type:actionID:button:modifiers". Deleting it
-- stays the cross's to do.
local SAME = { Button1 = "LeftButton", Button2 = "RightButton", Button3 = "MiddleButton" }
local function Click(button) return SAME[button] or button end

local function LockKey(info)
    if type(info) ~= "table" or not info.type or not info.actionID or type(info.button) ~= "string" then
        return nil
    end
    return format("%s:%s:%s:%d", info.type, info.actionID, Click(info.button), info.modifiers or 0)
end

function cc.Locked(info)
    local key = LockKey(info)
    local store = MedalUICharDB and MedalUICharDB.lockedClicks
    return key ~= nil and store ~= nil and store[key] == true
end

function cc.Lock(info, on)
    local key = LockKey(info)
    if not key then return end
    MedalUICharDB = MedalUICharDB or {}
    local store = MedalUICharDB.lockedClicks or {}
    MedalUICharDB.lockedClicks = store
    store[key] = on and true or nil
end

-- the modifiers held now, as the game reads them for a line's click
local function HeldMods()
    local make = C_ClickBindings and C_ClickBindings.MakeModifiers
    if make then
        local ok, m = pcall(make)
        if ok and type(m) == "number" then return m end
    end
    return (IsShiftKeyDown() and 1 or 0) + (IsControlKeyDown() and 2 or 0) + (IsAltKeyDown() and 4 or 0)
end

-- What a click with button on element e would break: e itself (locked, its
-- click to change), or the locked binding holding that click; nil when
-- the click may go on
function cc.Blocker(e, button)
    local f = Frame()
    local info = e and e.bindingInfo
    if not (f and info and button) then return nil end
    local click, mods = Click(button), HeldMods()
    -- its own click again: the game changes nothing
    if info.button and Click(info.button) == click and (info.modifiers or 0) == mods then return nil end
    if cc.Locked(info) then return e end
    local by
    local dp = f.dataProvider
    if dp and dp.ForEach then
        dp:ForEach(function(o)
            local oi = o.bindingInfo
            if not by and o ~= e and oi and type(oi.button) == "string" and Click(oi.button) == click
                and (oi.modifiers or 0) == mods and cc.Locked(oi) then
                by = o
            end
        end)
    end
    return by
end

-- In the game's bind mode: its window open
function cc.Binding()
    return _G.InClickBindingMode ~= nil and _G.InClickBindingMode() and true or false
end

-- ---------------------------------------------------------------- the place
local function Place() R.Place(Frame()) end
cc.Place = Place

-- A cell's words: ours, over the game's (its font objects reset a font of
-- ours each time its state changes)
local function Words(b, text, size)
    local d = deco[b]
    if not d.words then
        d.words = ns.Text(b, size or 13)
        d.words:SetPoint("CENTER", 0, 0)
        -- the game's own words emptied, not only hidden: its button states
        -- draw them again (nothing reads them back)
        local fs = b.GetFontString and b:GetFontString()
        if fs then fs:SetAlpha(0) end
        if b.Text then b.Text:SetAlpha(0) end
        if b.SetText then b:SetText("") end
    end
    d.words:SetText(text)
    return d.words
end

local function Shade(b)
    local d = deco[b]
    if not d or not d.words then return end
    local on = not b.IsEnabled or b:IsEnabled()
    local c = d.marked and GOLD or on and ns.colors.text or DIM
    d.words:SetTextColor(c[1], c[2], c[3])
end

-- ---------------------------------------------------------------- the rows
-- An engraved slot on f (once), its glyph (if any) lit white under the
-- mouse, gold again after (dim while f is off)
local function Engraved(f)
    local d = deco[f] or {}
    deco[f] = d
    if f.slot then return d end
    R.Slot(f)
    f:HookScript("OnEnter", function()
        if d.glyph then d.glyph:SetVertexColor(1, 1, 1) end
    end)
    f:HookScript("OnLeave", function()
        if d.glyph then
            local on = not f.IsEnabled or f:IsEnabled()
            local c = on and GOLD or DIM
            d.glyph:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
        end
    end)
    return d
end

-- a rail's tray (once), over the window's rect from x1, y1 to x2, y2
-- (TOPLEFT and BOTTOMRIGHT offsets from the window's corners named)
local function Tray(d, key, from, x1, y1, to, x2, y2)
    if not d[key] then
        d[key] = CreateFrame("Frame", nil, skin)
        R.Recess(d[key])
    end
    local t = d[key]
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", Frame(), from, x1, y1)
    t:SetPoint("BOTTOMRIGHT", Frame(), to, x2, y2)
    return t
end

-- (2026-11-27, the user's: "not needed") the game's buttons for the
-- windows it opens beside it (the spellbook, the macros): away, as the
-- tutorial's (they still open with it)
local function Away(b)
    if not b then return end
    b:SetAlpha(0)
    b:EnableMouse(false)
end

-- The top row, a tray: a slot holding the mouseover tick and its key.
local function Top(f)
    -- the windows it opens beside it: the macros on the edge, the book in
    -- from it (sharing an edge), a gap before them
    local d = deco[f] or {}
    deco[f] = d
    Tray(d, "topTray", "TOPLEFT", 1, TOP, "TOPRIGHT", -EDGE, TOP - ROW)
    Away(f.MacrosPortrait)
    Away(f.PlayerSpellsPortrait)
    -- the cell: the tick and its key, the tray's length
    if not d.cell then
        d.cell = CreateFrame("Frame", nil, skin)
        R.Slot(d.cell)
    end
    d.cell:ClearAllPoints()
    d.cell:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + SLOT_GAP, TOP - SLOT_GAP)
    d.cell:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -EDGE - SLOT_GAP, TOP - ROW + SLOT_GAP)
    local check = f.EnableMouseoverCastCheckbox
    if type(check) == "table" then
        R.Plain(check)
        R.Box(check, 1)
        for _, get in ipairs({ "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
            local t = check[get] and check[get](check)
            if t then
                t:SetDesaturated(true)
                t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", -3, 3)
                t:SetPoint("BOTTOMRIGHT", 3, -3)
            end
        end
        R.Lit(check)
        check:ClearAllPoints()
        check:SetPoint("LEFT", d.cell, "LEFT", 10, 0)
        -- over the slot's face (at one level, its face would cover the box)
        check:SetFrameLevel(d.cell:GetFrameLevel() + 2)
        check:SetSize(14, 14)
        if check.Label then
            R.Font(check.Label, 14, ns.colors.text)
            check.Label:ClearAllPoints()
            check.Label:SetPoint("LEFT", check, "RIGHT", 8, 0)
        end
    end
    -- its key: shown while mouseover cast is on (the game's), after a
    -- faint parting
    local key = f.MouseoverCastKeyDropdown
    if key then
        R.Bare(key)
        for _, k in ipairs({ "Background", "Arrow" }) do
            if key[k] then key[k]:SetAlpha(0) end
        end
        if key.Label then key.Label:SetAlpha(0) end
        local e = deco[key]
        if not e.with then
            e.part = key:CreateTexture(nil, "ARTWORK")
            e.part:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.55)
            e.part:SetSize(1, SLOT - 8)
            e.part:SetPoint("LEFT", -8, 0)
            e.with = ns.Text(key, 12)
            e.with:SetPoint("LEFT", 0, 0)
            e.with:SetTextColor(DIM[1], DIM[2], DIM[3])
            e.with:SetText(Tr["with"])
            e.arrow = key:CreateTexture(nil, "OVERLAY")
            e.arrow:SetTexture(GLYPHS .. "chevron-down")
            e.arrow:SetSize(10, 10)
            e.arrow:SetPoint("RIGHT", -6, 0)
            e.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            key:HookScript("OnEnter", function() e.arrow:SetVertexColor(1, 1, 1) end)
            key:HookScript("OnLeave", function() e.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
        end
        if key.Text then
            R.Font(key.Text, 13, ns.colors.text)
            key.Text:ClearAllPoints()
            key.Text:SetPoint("LEFT", e.with, "RIGHT", 8, 0)
            key.Text:SetPoint("RIGHT", e.arrow, "LEFT", -4, 0)
            if key.Text.SetJustifyH then key.Text:SetJustifyH("LEFT") end
        end
        key:ClearAllPoints()
        key:SetPoint("LEFT", d.cell, "LEFT", 168, 0)
        key:SetSize(120, SLOT)
        key:SetFrameLevel(d.cell:GetFrameLevel() + 2)
        R.Dropdown(key)
    end
    -- the tutorial's button: away (its page still opens the first time)
    if f.TutorialButton then
        f.TutorialButton:SetAlpha(0)
        f.TutorialButton:EnableMouse(false)
    end
end

-- The foot, a tray: Reset (a rounded arrow back), Add binding; at the
-- edge Save, held while there are changes to save. Each an engraved slot.
local function Cell(b, width)
    R.Plain(b)
    for _, k in ipairs({ "Left", "Right", "Middle" }) do
        if b[k] then b[k]:SetAlpha(0) end
    end
    local d = Engraved(b)
    if not d.cell then
        d.cell = true
        if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
        b:HookScript("OnEnable", function() Shade(b) end)
        b:HookScript("OnDisable", function() Shade(b) end)
        -- the game fitting a button to its words: back to the cell
        hooksecurefunc(b, "SetWidth", function(self, w)
            if w ~= width then self:SetWidth(width) end
        end)
    end
    b:SetSize(width, SLOT)
    return d
end

function cc.Pending()
    local f = Frame()
    local save = f and f.SaveButton
    local d = save and deco[save]
    if not d or not d.mark then return end
    d.marked = f.pendingChanges and true or false
    R.Held(save, d.marked)
    Shade(save)
end

local function Foot(f)
    local fd = deco[f] or {}
    deco[f] = fd
    Tray(fd, "footTray", "BOTTOMLEFT", 1, 1 + ROW, "BOTTOMRIGHT", -EDGE, 1)
    local reset = f.ResetButton
    if reset then
        local d = Cell(reset, SLOT)
        if not d.glyph then
            d.glyph = reset:CreateTexture(nil, "OVERLAY")
            d.glyph:SetTexture(GLYPHS .. "side-reset")
            d.glyph:SetTexCoord(1, 0, 0, 1)
            d.glyph:SetSize(16, 16)
            d.glyph:SetPoint("CENTER")
            d.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            local fs = reset.GetFontString and reset:GetFontString()
            if fs then fs:SetAlpha(0) end
            reset:HookScript("OnEnter", function(self)
                ns.Tip(self, ns.window.Outside, { title = Tr["Reset to default"], color = GOLD,
                    { "body", Tr["Back to the game's own bindings: your custom ones are kept, unbound."] } })
            end)
            reset:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        reset:ClearAllPoints()
        reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1 + SLOT_GAP, 1 + SLOT_GAP)
    end
    local add = f.AddBindingButton
    if type(add) == "table" then
        Cell(add, 130)
        Words(add, Tr["+  Add binding"])
        Shade(add)
        add:ClearAllPoints()
        add:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1 + 2 * SLOT_GAP + SLOT, 1 + SLOT_GAP)
    end
    local save = f.SaveButton
    if save then
        local d = Cell(save, 90)
        Words(save, Tr["Save"])
        if not d.mark then
            -- with changes to save: held, its underline as wide as its word
            d.mark = save.slotHeld
            R.Under(save, d.words:GetStringWidth() or 0)
        end
        save:ClearAllPoints()
        save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -EDGE - SLOT_GAP, 1 + SLOT_GAP)
        cc.Pending()
    end
    -- what a binding taken from another left unbound: over the foot
    if f.UnboundText then
        R.Font(f.UnboundText, 13)
        f.UnboundText:ClearAllPoints()
        f.UnboundText:SetPoint("BOTTOM", f, "BOTTOM", 0, FOOT - 4)
    end
end

-- -------------------------------------------------------------- the list
-- Its headings as ours: gold small capitals, a rule fading right
local function Heading(h)
    local d = deco[h] or {}
    deco[h] = d
    if not d.rule then
        if h.Init then hooksecurefunc(h, "Init", function() Heading(h) end) end
        d.rule = h:CreateTexture(nil, "ARTWORK")
        d.rule:SetHeight(1)
        d.rule:SetPoint("RIGHT", h, "RIGHT", -4, 0)
        R.Fade(d.rule, GOLD_D, 1)
    end
    if h.Name then
        R.Font(h.Name, 13, GOLD)
        h.Name:ClearAllPoints()
        h.Name:SetPoint("LEFT", 4, 0)
        if h.Name.SetWidth then h.Name:SetWidth(0) end
        d.rule:SetPoint("LEFT", h.Name, "RIGHT", 10, 0)
    end
end

-- a keycap: its word in a small gold-edged box
local function Cap(line, d, i)
    local k = d.caps[i]
    if not k then
        k = CreateFrame("Frame", nil, line)
        k:SetHeight(18)
        R.Box(k, 0.95)
        k.word = ns.Text(k, 12)
        k.word:SetPoint("CENTER", 0, 0)
        k.plus = ns.Text(line, 12)
        k.plus:SetText("+")
        k.plus:SetTextColor(DIM[1], DIM[2], DIM[3])
        d.caps[i] = k
    end
    return k
end

local function Caps(line, d)
    local info = d.data and d.data.bindingInfo
    local keys = d.data and d.data.elementType ~= NEW_SLOT and cc.Keys(info)
    local x = 0
    for i = 1, math.max(#(keys or {}), #d.caps) do
        local key = keys and keys[i]
        if key then
            local k = Cap(line, d, i)
            k.word:SetText(key)
            local w = (k.word:GetStringWidth() or 0) + 12
            k:SetWidth(w)
            k:ClearAllPoints()
            k:SetPoint("TOPLEFT", line.Name, "BOTTOMLEFT", x, -3)
            local c = d.hot and GOLD or GOLD_D
            R.Edge(deco[k], c)
            local t = d.hot and GOLD or ns.colors.text
            k.word:SetTextColor(t[1], t[2], t[3])
            k:Show()
            x = x + w
            k.plus:SetShown(keys[i + 1] ~= nil)
            if keys[i + 1] then
                k.plus:ClearAllPoints()
                k.plus:SetPoint("LEFT", k, "RIGHT", 3, 0)
                x = x + 14
            end
        elseif d.caps[i] then
            d.caps[i]:Hide()
            d.caps[i].plus:Hide()
        end
    end
    -- the game's words where there are no keys: unbound (red), the slot's
    -- prompt (green)
    if line.BindingText then line.BindingText:SetAlpha(keys and 0 or 1) end
end

-- a control's square lit faintly under the mouse
local function Hover(b)
    local t = b:CreateTexture(nil, "HIGHLIGHT")
    t:SetAllPoints()
    t:SetColorTexture(1, 1, 1, 0.08)
end

-- A plate on a line (drawn on the line itself, under the game's words):
-- glass, its head lit from above, its edges, its icon's square at its
-- right end (an ink well under it, a gold line at its left), the light
-- under the mouse and the waiting slot's wash over the rest. Returns its
-- parts.
-- the icon's side: the line's height inside the plate's edges
local function Size(line)
    local h = line:GetHeight() or 0
    return h > PLATE.top + PLATE.foot + 10 and h - PLATE.top - PLATE.foot - 2 or ICON
end

local function Plate(line)
    local p = {}
    local side = Size(line)
    p.size = side
    local ink = ns.colors.ink
    local function Body(sub, r, g, b, a)
        local t = line:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetPoint("TOPLEFT", 0, -PLATE.top)
        t:SetPoint("BOTTOMRIGHT", -(side + 1), PLATE.foot)
        t:SetColorTexture(r, g, b, a)
        return t
    end
    p.fill = Body(-8, ink[1], ink[2], ink[3], GLASS.fill)
    p.wash = Body(-7, GOLD_D[1], GOLD_D[2], GOLD_D[3], GLASS.wash)
    p.lit = Body(-7, 1, 1, 1, 0.05)
    p.lock = Body(-7, BLUE[1], BLUE[2], BLUE[3], TINT)
    p.lock:Hide()
    p.head = line:CreateTexture(nil, "BACKGROUND", nil, -6)
    p.head:SetPoint("TOPLEFT", 1, -(PLATE.top + 1))
    p.head:SetPoint("TOPRIGHT", -(side + 2), -(PLATE.top + 1))
    p.head:SetHeight(side / 2)
    R.Shade(p.head, GLASS.head, { ink[1], ink[2], ink[3], 0 })
    -- the icon's square: an ink well, the gold line at its left
    p.well = line:CreateTexture(nil, "BACKGROUND", nil, -8)
    p.well:SetSize(side, side)
    p.well:SetPoint("TOPRIGHT", -1, -(PLATE.top + 1))
    p.well:SetColorTexture(ink[1], ink[2], ink[3], 1)
    p.edges = {}
    for i, e in ipairs({ { "TOPLEFT", 0, -PLATE.top, "TOPRIGHT", 0, -PLATE.top },
        { "BOTTOMLEFT", 0, PLATE.foot, "BOTTOMRIGHT", 0, PLATE.foot },
        { "TOPLEFT", 0, -PLATE.top, "BOTTOMLEFT", 0, PLATE.foot },
        { "TOPRIGHT", 0, -PLATE.top, "BOTTOMRIGHT", 0, PLATE.foot },
        { "TOPRIGHT", -(side + 1), -PLATE.top, "BOTTOMRIGHT", -(side + 1), PLATE.foot } }) do
        local t = line:CreateTexture(nil, "BORDER")
        t:SetPoint(e[1], e[2], e[3])
        t:SetPoint(e[4], e[5], e[6])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        p.edges[i] = t
    end
    return p
end

-- A binding: a plate (Plate), its icon a medallion of ours in the plate's
-- cut corner (the game's own texture, which it sets again and again, an
-- atlas on the waiting slot, left unmasked and hidden), its name, its
-- click as keycaps; the slot waiting for a spell a plate washed gold, its
-- edges lit, a + in its ring.
local function Line(line)
    local d = deco[line] or {}
    deco[line] = d
    if not d.icon then
        d.caps = {}
        for _, k in ipairs({ "Background", "FrameHighlight", "NewOutline", "EmptySlotIconHighlight" }) do
            if line[k] then line[k]:SetAlpha(0) end
        end
        d.plate = Plate(line)
        -- under the mouse (or held): lit; the slot waiting for a spell: washed gold
        d.row, d.slot = d.plate.lit, d.plate.wash
        d.icon = line:CreateTexture(nil, "ARTWORK")
        d.icon:SetAllPoints(d.plate.well)
        d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        d.plus = ns.Text(line, 16)
        d.plus:SetPoint("CENTER", d.icon, "CENTER", 0, 1)
        d.plus:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        d.plus:SetText("+")
        if line.IconHighlight then
            -- the game's glow as it waits for a spell, round the icon's square
            line.IconHighlight:ClearAllPoints()
            line.IconHighlight:SetPoint("TOPLEFT", d.icon, "TOPLEFT", -6, 6)
            line.IconHighlight:SetPoint("BOTTOMRIGHT", d.icon, "BOTTOMRIGHT", 6, -6)
        end
        local del = line.DeleteButton
        if del then
            R.Plain(del)
            if del.Icon then del.Icon:SetAlpha(0) end
            local g = R.Glyph(del, "close", CONTROL.delete)
            g:SetVertexColor(DIM[1], DIM[2], DIM[3])
            del:HookScript("OnEnter", function() g:SetVertexColor(1, 1, 1) end)
            del:HookScript("OnLeave", function() g:SetVertexColor(DIM[1], DIM[2], DIM[3]) end)
            del:ClearAllPoints()
            del:SetPoint("RIGHT", line, "RIGHT", -(d.plate.size + CONTROLS), 0)
            del:SetSize(CONTROL.size, CONTROL.size)
            Hover(del)
        end
        -- the mouse onto the edit or the lock leaves the line, and the game
        -- puts a custom binding's delete away: kept beside them; off the
        -- line's square altogether, away again (2026-11-27, the lock jumped)
        local function Near(on)
            if del and d.data and d.data.elementType ~= DEFAULT_LINE and d.data.elementType ~= NEW_SLOT then
                if on then
                    del:Show()
                elseif not line:IsMouseOver() then
                    del:Hide()
                end
            end
            cc.Line(line)
        end
        -- lock: between the edit and the game's delete (in the delete's
        -- place on a default binding, which has none)
        local lock = CreateFrame("Button", nil, line)
        d.lock = lock
        lock:SetSize(CONTROL.size, CONTROL.size)
        lock:RegisterForClicks("LeftButtonUp")
        local lg = lock:CreateTexture(nil, "OVERLAY")
        lg:SetPoint("CENTER")
        lg:SetSize(CONTROL.lock, CONTROL.lock)
        lg:SetAtlas("QuestSharing-Padlock")
        lg:SetDesaturated(true)
        d.lockGlyph = lg
        Hover(lock)
        lock:SetScript("OnEnter", function(self)
            d.lockOver = true
            Near(true)
            local on = cc.Locked(d.data and d.data.bindingInfo)
            ns.Tip(self, ns.window.Outside, { title = on and Tr["Unlock"] or Tr["Lock"], color = on and BLUE or GOLD,
                { "body", on and Tr["Locked: its click stays its own. Click to unlock it."]
                    or Tr["Keep its click: no other binding can take it, and it cannot be changed by accident."] } })
        end)
        lock:SetScript("OnLeave", function()
            d.lockOver = false
            GameTooltip:Hide()
            Near(false)
        end)
        lock:SetScript("OnClick", function(self)
            local info = d.data and d.data.bindingInfo
            if not info then return end
            cc.Lock(info, not cc.Locked(info))
            cc.Line(line)
            -- its tip again, saying the other way round
            if d.lockOver then self:GetScript("OnEnter")(self) end
        end)
        lock:Hide()
        -- edit: into the binder (left of the lock)
        local edit = CreateFrame("Button", nil, line)
        d.edit = edit
        edit:SetSize(CONTROL.size, CONTROL.size)
        local eg = R.Glyph(edit, "edit", CONTROL.edit)
        Hover(edit)
        eg:SetVertexColor(DIM[1], DIM[2], DIM[3])
        edit:SetScript("OnEnter", function(self)
            d.editOver = true
            Near(true)
            local on = cc.Locked(d.data and d.data.bindingInfo)
            eg:SetVertexColor(on and DIM[1] or 1, on and DIM[2] or 1, on and DIM[3] or 1)
            ns.Tip(self, ns.window.Outside, { title = Tr["Edit"], color = GOLD,
                { "body", on and Tr["Locked: unlock it to change its click."]
                    or Tr["Into the binder: click its pad with the new click."] } })
        end)
        edit:SetScript("OnLeave", function()
            d.editOver = false
            eg:SetVertexColor(DIM[1], DIM[2], DIM[3])
            GameTooltip:Hide()
            Near(false)
        end)
        edit:SetScript("OnClick", function()
            if cc.Locked(d.data and d.data.bindingInfo) then return end
            cc.Load(line.GetElementData and line:GetElementData(), line)
        end)
        edit:Hide()
        -- the line's click (the game's, setting the binding's click): held
        -- back when it would change a locked binding's click or take one's,
        -- however often the game sets it again
        d.guard = function(self, button, ...)
            if cc.Refuse(self:GetElementData(), button) then return end
            if d.click then return d.click(self, button, ...) end
        end
        local function Guard()
            local click = line:GetScript("OnClick")
            if click ~= d.guard then
                d.click = click
                line:SetScript("OnClick", d.guard)
            end
        end
        hooksecurefunc(line, "SetScript", function(_, kind)
            if kind == "OnClick" then Guard() end
        end)
        Guard()
        line:HookScript("OnEnter", function()
            d.hot = true
            cc.Line(line)
        end)
        line:HookScript("OnLeave", function()
            d.hot = false
            cc.Line(line)
        end)
        if line.Init then hooksecurefunc(line, "Init", function() cc.Line(line) end) end
    end
    d.data = line.GetElementData and line:GetElementData() or nil
    local new = d.data and d.data.elementType == NEW_SLOT
    local icon = line.Icon
    local atlas = icon and icon.GetAtlas and icon:GetAtlas()
    if icon then icon:SetAlpha(0) end
    local empty = new and not (d.data and d.data.bindingInfo)
    if icon and not atlas and not empty then
        d.icon:SetTexture(icon:GetTexture())
        d.icon:SetDesaturated(icon.IsDesaturated and icon:IsDesaturated() or false)
        d.icon:Show()
    else
        d.icon:Hide()
    end
    d.plus:SetShown(empty)
    d.plate.wash:SetShown(new and true or false)
    -- the binding in the binder: lit as under the mouse
    local held = d.data ~= nil and d.data == cc.target
    d.plate.lit:SetShown((d.hot or held) and not new or false)
    local info = d.data and d.data.bindingInfo
    local locked = not new and cc.Locked(info)
    local over = d.editOver or d.lockOver
    local near = (d.hot or over) and not new and info ~= nil
    d.edit:SetShown(near and true or false)
    -- the lock: under the mouse (a binding with a click), and always when on
    d.lock:SetShown((locked or (near and type(info.button) == "string")) and true or false)
    local lc = locked and BLUE or d.lockOver and { 1, 1, 1 } or DIM
    d.lockGlyph:SetVertexColor(lc[1], lc[2], lc[3])
    d.plate.lock:SetShown(locked)
    -- the controls from the right: the delete (custom bindings), the lock,
    -- the edit; a default binding's lock in the delete's place. By the
    -- binding's kind, not the delete's being shown: the game shows it only
    -- under the mouse (2026-11-27, the lock jumped into its place)
    local del = line.DeleteButton
    local custom = del ~= nil and d.data ~= nil and d.data.elementType ~= DEFAULT_LINE
    local x = d.plate.size + CONTROLS
    if custom then x = x + CONTROL.size + CONTROL.gap end

    d.lock:ClearAllPoints()
    d.lock:SetPoint("RIGHT", line, "RIGHT", -x, 0)
    d.edit:ClearAllPoints()
    d.edit:SetPoint("RIGHT", line, "RIGHT", -(x + CONTROL.size + CONTROL.gap), 0)
    local lit = d.hot or held or new
    local rim = lit and GOLD or GOLD_D
    -- its edges: gold when lit, else a dark gold (the top brighter, as
    -- the macros' plates)
    for i, t in ipairs(d.plate.edges) do
        t:SetColorTexture(rim[1], rim[2], rim[3], (lit or i == 1) and 1 or 0.6)
    end
    if line.Name then
        R.Font(line.Name, 14, ns.colors.text)
        line.Name:ClearAllPoints()
        line.Name:SetPoint("TOPLEFT", line, "TOPLEFT", TEXT_X, -(PLATE.top + 4))
        line.Name:SetPoint("RIGHT", line, "RIGHT", -(d.plate.size + CONTROLS + 3 * CONTROL.size), 0)
    end
    if line.BindingText then
        R.Font(line.BindingText, 13)
        line.BindingText:ClearAllPoints()
        line.BindingText:SetPoint("TOPLEFT", line.Name, "BOTTOMLEFT", 0, -5)
        line.BindingText:SetPoint("RIGHT", line, "RIGHT", -(d.plate.size + CONTROLS + 3 * CONTROL.size), 0)
    end
    if empty and line.Name then
        -- the waiting slot: its prompt alone, level with the + in the icon's square
        line.Name:SetText("")
        line.BindingText:ClearAllPoints()
        line.BindingText:SetPoint("LEFT", line, "LEFT", TEXT_X, (PLATE.foot - PLATE.top) / 2)
        line.BindingText:SetPoint("RIGHT", line, "RIGHT", -(d.plate.size + CONTROLS), 0)
    end
    Caps(line, d)
end
cc.Line = Line

local function Element(frame)
    if not frame then return end
    if frame.BindingText then Line(frame) elseif frame.Name then Heading(frame) end
end

local function List(f)
    if f.ScrollBoxBackground then f.ScrollBoxBackground:SetAlpha(0) end
    local box = f.ScrollBox
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, LIST)
        box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 16, FOOT + BINDER + 16)
        if box.ForEachFrame then box:ForEachFrame(Element) end
    end
    local bar = f.ScrollBar
    if bar and box then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
    end
end

-- ------------------------------------------------------------- the binder
-- Over the foot: what to do next, and a pad that takes the click. A binding
-- loads into it (a spell clicked in the book, the slot filled, a line's
-- edit glyph); a click on the pad is the click on that binding's line, the
-- game's own (its modifiers read as it reads them, a clash unbound, the
-- list sorted, Save marked).
--
--   BINDER ---------------------------------------------------
--   (1) Pick a spell - (2) Click the pad - (3) Save
--   (o) Healing Wave   [ (mouse) Click here with the click you want    ]
--       Rank 4         [         hold Shift, Ctrl or Alt as you click  ]
--   Or click its line in the list.
local STEPS = { Tr["Pick a spell"], Tr["Click the pad"], Tr["Save"] }
local HELP = { Tr["Click a spell in the spellbook: the ones that glow can be bound."],
    Tr["Click the pad here with the mouse button and keys you want."], Tr["Save."] }
local GREEN = { 0.45, 0.85, 0.40 }
local binder
local loaded            -- the target's click when it loaded, and its look

local function Alive(f, data)
    local dp = f and f.dataProvider
    if not data or not dp or not dp.ForEach then return false end
    local found = false
    dp:ForEach(function(e) if e == data then found = true end end)
    return found
end

local function Plain(s) return s and (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- A binding's name, icon (a texture or an atlas) and what it is
local function Describe(data, line)
    local info = data.bindingInfo
    local id = info.actionID
    local name, icon, atlas, sub
    if info.type == TYPE.Spell or info.type == TYPE.PetAction then
        name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
        if (not sub or sub == "") and info.type == TYPE.PetAction then sub = Tr["Pet"] end
    elseif info.type == TYPE.Macro then
        if _G.GetMacroInfo then name, icon = _G.GetMacroInfo(id) end
        sub = Tr["Macro"]
    elseif info.type == TYPE.Interaction then
        sub = Tr["Default"]
    end
    if not name and line then
        name = Plain(line.Name and line.Name:GetText())
        local ic = line.Icon
        atlas = ic and ic.GetAtlas and ic:GetAtlas()
        icon = not atlas and ic and ic:GetTexture() or nil
    end
    return name or "", icon, atlas, sub or ""
end

-- A click on element e held back by a lock (cc.Blocker): said under the
-- list, where the game says what a click unbound. True when held back.
function cc.Refuse(e, button)
    local by = cc.Blocker(e, button)
    if not by then return false end
    local f = Frame()
    local box = f.ScrollBox
    local line = box and box.FindFrame and box:FindFrame(by)
    local name = Describe(by, line)
    local _, keys = cc.Keys(by.bindingInfo)
    local text = by == e and format(Tr["%s is locked to %s: unlock it to change its click."], name, keys)
        or format(Tr["%s is locked to %s: that click stays with it."], name, keys)
    if f.UnboundText then
        f.UnboundText:SetText(text)
        f.UnboundText:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
        f.UnboundText:Show()
    end
    cc.refused = text
    return true
end

-- Where the binder is: 1 nothing loaded, 2 waiting for its click, 3 a new
-- click set and not yet saved
function cc.Step()
    local t = cc.target
    if not (t and t.bindingInfo) then return 1 end
    return cc.set and 3 or 2
end

local function Dashes(pad, lit)
    local d = deco[pad]
    local w, h = pad:GetWidth() or 0, pad:GetHeight() or 0
    local n = 0
    local function Dash(x, y, dw, dh)
        n = n + 1
        local t = d.dashes[n]
        if not t then
            t = pad:CreateTexture(nil, "BORDER")
            d.dashes[n] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", pad, "TOPLEFT", x, -y)
        t:SetSize(dw, dh)
        t:Show()
    end
    for x = 0, w - 3, 6 do
        Dash(x, 0, 3, 1)
        Dash(x, h - 1, 3, 1)
    end
    for y = 0, h - 3, 6 do
        Dash(0, y, 1, 3)
        Dash(w - 1, y, 1, 3)
    end
    for i = n + 1, #d.dashes do d.dashes[i]:Hide() end
    local c = lit and GOLD or GOLD_D
    for i = 1, n do d.dashes[i]:SetColorTexture(c[1], c[2], c[3], 1) end
end

local shown           -- the step last painted
local function Paint()
    local b = binder
    local f = Frame()
    if not b or not f then return end
    local step = cc.Step()
    -- the spellbook's halo follows the step (spells/spellbook.lua)
    if step ~= shown then
        shown = step
        if cc.Stepped then cc.Stepped(step) end
    end
    local t = cc.target
    local idle = step == 1
    for _, fs in ipairs(b.help) do fs:SetShown(idle) end
    for i, s in ipairs(b.steps) do
        s.ring:SetShown(not idle)
        s.well:SetShown(not idle)
        s.num:SetShown(not idle)
        s.word:SetShown(not idle)
        if s.dash then s.dash:SetShown(not idle) end
        local c = i == step and GOLD or i < step and ns.colors.text or DIM
        s.ring:SetVertexColor((i == step and GOLD or GOLD_D)[1], (i == step and GOLD or GOLD_D)[2],
            (i == step and GOLD or GOLD_D)[3], 1)
        s.num:SetTextColor(c[1], c[2], c[3])
        s.word:SetTextColor(c[1], c[2], c[3])
    end
    b.spell:SetShown(not idle)
    b.pad:SetShown(not idle)
    b.pad:EnableMouse(not idle)
    b.cancel:SetShown(not idle)
    if idle then
        b.hint:SetText("")
        return
    end
    b.name:SetText(loaded.name)
    b.sub:SetText(loaded.sub)
    if loaded.atlas then
        b.icon:SetAtlas(loaded.atlas)
    else
        b.icon:SetTexture(loaded.icon)
    end
    -- the pad: its click once set (keycaps), else what to do
    local hot = b.pad.hot
    local keys = step == 3 and cc.Keys(t.bindingInfo)
    local word = hot and { 1, 1, 1 } or GOLD
    b.line1:SetTextColor(word[1], word[2], word[3])
    b.line1:SetText(keys and "" or Tr["Click here with the click you want"])
    b.line2:SetText(keys and Tr["Click again to change it"] or Tr["hold Shift, Ctrl or Alt as you click"])
    local x = 0
    local pd = deco[b.pad]
    for i = 1, math.max(#(keys or {}), #pd.caps) do
        local key = keys and keys[i]
        if key then
            local k = Cap(b.pad, pd, i)
            k.word:SetText(key)
            local w = (k.word:GetStringWidth() or 0) + 12
            k:SetWidth(w)
            k:ClearAllPoints()
            k:SetPoint("TOPLEFT", b.pad, "TOPLEFT", 38 + x, -5)
            R.Edge(deco[k], GOLD)
            k.word:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            k:Show()
            x = x + w
            k.plus:SetShown(keys[i + 1] ~= nil)
            if keys[i + 1] then
                k.plus:ClearAllPoints()
                k.plus:SetPoint("LEFT", k, "RIGHT", 3, 0)
                x = x + 14
            end
        elseif pd.caps[i] then
            pd.caps[i]:Hide()
            pd.caps[i].plus:Hide()
        end
    end
    Dashes(b.pad, hot)
    if step == 3 then
        b.hint:SetText(Tr["Save to keep it."])
        b.hint:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    else
        b.hint:SetText(Tr["Or click its line in the list."])
        b.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
    end
end

-- The binder again, as the game changes its list: the target gone (deleted,
-- the list read afresh), its click changed (here or on its line), saved
function cc.Binder()
    local f = Frame()
    local t = cc.target
    if t and not (Alive(f, t) and t.bindingInfo) then t = nil end
    if t and loaded then
        local info = t.bindingInfo
        if info.button ~= loaded.button or (info.modifiers or 0) ~= loaded.modifiers then cc.set = true end
    end
    -- set, then saved (or the changes dropped): done
    if t and cc.set and not (f and f.pendingChanges) then t = nil end
    if not t then
        cc.set, loaded = false, nil
    end
    local was = cc.target
    cc.target = t
    Paint()
    if was ~= t and f and f.ScrollBox and f.ScrollBox.ForEachFrame then f.ScrollBox:ForEachFrame(Element) end
end

-- A binding into the binder: the slot filled, a spell clicked in the book,
-- a line's edit glyph
function cc.Load(data, line)
    local f = Frame()
    if not (data and data.bindingInfo and Alive(f, data)) then return end
    if not line and f.ScrollBox and f.ScrollBox.FindFrame then line = f.ScrollBox:FindFrame(data) end
    local name, icon, atlas, sub = Describe(data, line)
    loaded = { button = data.bindingInfo.button, modifiers = data.bindingInfo.modifiers or 0,
        name = name, icon = icon, atlas = atlas, sub = sub }
    cc.set = false
    cc.target = data
    Paint()
    if f.ScrollBox and f.ScrollBox.ForEachFrame then f.ScrollBox:ForEachFrame(Element) end
end

-- The binding loaded whose spell is one of ids (or of that name): the
-- spellbook's click on a spell already bound
function cc.Find(ids, name)
    local f = Frame()
    local dp = f and f.dataProvider
    if not dp or not dp.ForEach then return nil end
    local found
    dp:ForEach(function(e)
        local info = e.bindingInfo
        if found or not info or not (info.type == TYPE.Spell or info.type == TYPE.PetAction) then return end
        local n = name and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(info.actionID)
        if ids[info.actionID] or (n and n == name) then found = e end
    end)
    return found
end

-- The pad's click: the click on the target's line
local function Press(_, button)
    local f = Frame()
    local t = cc.target
    if not (f and t and Alive(f, t)) then return end
    local box = f.ScrollBox
    -- (elementData, alignment, offset, noInterpolation); a client without
    -- offset reads the 0 as noInterpolation, truthy all the same
    if box.ScrollToElementData then box:ScrollToElementData(t, nil, 0, true) end
    local line = box.FindFrame and box:FindFrame(t)
    local click = line and line:GetScript("OnClick")
    if click then click(line, button) end
    cc.Binder()
end

local function Binder(f)
    if binder then return binder end
    local b = CreateFrame("Frame", nil, f)
    binder = b
    cc.binder = b
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, FOOT)
    b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOT)
    b:SetHeight(BINDER)
    -- its rule over it, the window's width
    b.rule = b:CreateTexture(nil, "ARTWORK")
    b.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    b.rule:SetHeight(1)
    b.rule:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 1, FOOT + BINDER + 8)
    b.rule:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -1, FOOT + BINDER + 8)
    b.title = ns.Text(b, 13)
    R.Font(b.title, 13, GOLD)
    b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.title:SetText(Tr["Binder"])
    b.fade = b:CreateTexture(nil, "ARTWORK")
    b.fade:SetHeight(1)
    b.fade:SetPoint("LEFT", b.title, "RIGHT", 10, 0)
    b.fade:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    R.Fade(b.fade, GOLD_D, 1)
    -- nothing loaded: what to do
    b.help = {}
    local intro = ns.Text(b, 13)
    intro:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -24)
    intro:SetText(Tr["Bind a spell to a click on unit frames:"])
    table.insert(b.help, intro)
    for i, s in ipairs(HELP) do
        local fs = ns.Text(b, 12)
        fs:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -26 - i * 18)
        fs:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetText(i .. ".  " .. s)
        fs:SetTextColor(DIM[1], DIM[2], DIM[3])
        table.insert(b.help, fs)
    end
    local drag = ns.Text(b, 12)
    drag:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -26 - 4 * 18 - 4)
    drag:SetText(Tr["Or drag a spell or macro into the list."])
    drag:SetTextColor(DIM[1], DIM[2], DIM[3])
    table.insert(b.help, drag)
    -- the steps: ringed numerals, their words, dashes between
    b.steps = {}
    local prev
    for i, s in ipairs(STEPS) do
        local st = {}
        st.ring = b:CreateTexture(nil, "ARTWORK")
        st.ring:SetTexture(ROUND)
        st.ring:SetSize(18, 18)
        if prev then
            st.dash = b:CreateTexture(nil, "ARTWORK")
            st.dash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            st.dash:SetSize(8, 1)
            st.dash:SetPoint("LEFT", prev.word, "RIGHT", 6, 0)
            st.ring:SetPoint("LEFT", st.dash, "RIGHT", 6, 0)
        else
            st.ring:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -24)
        end
        st.well = b:CreateTexture(nil, "ARTWORK", nil, 1)
        st.well:SetTexture(ROUND)
        st.well:SetPoint("TOPLEFT", st.ring, "TOPLEFT", 1.5, -1.5)
        st.well:SetPoint("BOTTOMRIGHT", st.ring, "BOTTOMRIGHT", -1.5, 1.5)
        st.well:SetVertexColor(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
        st.num = ns.Text(b, 11)
        st.num:SetPoint("CENTER", st.ring, "CENTER", 0, 0)
        st.num:SetText(tostring(i))
        st.word = ns.Text(b, 13)
        st.word:SetPoint("LEFT", st.ring, "RIGHT", 6, 0)
        st.word:SetText(s)
        b.steps[i] = st
        prev = st
    end
    -- the binding loaded: its medallion, name and what it is
    b.spell = CreateFrame("Frame", nil, b)
    b.spell:SetSize(32, 32)
    b.spell:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -52)
    b.icon = b.spell:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    R.Medal(b.spell, b.icon, 2.5)
    deco[b.spell].rim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    b.name = ns.Text(b.spell, 14)
    b.name:SetPoint("TOPLEFT", b.spell, "TOPRIGHT", 8, -1)
    b.name:SetWidth(84)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = ns.Text(b.spell, 12)
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
    b.sub:SetWidth(84)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)
    b.sub:SetTextColor(DIM[1], DIM[2], DIM[3])
    -- the pad
    local pad = CreateFrame("Button", nil, b)
    b.pad = pad
    pad:SetPoint("TOPLEFT", b, "TOPLEFT", 134, -48)
    pad:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -48)
    pad:SetHeight(42)
    pad:RegisterForClicks("AnyUp")
    local pd = deco[pad] or {}
    deco[pad] = pd
    pd.dashes, pd.caps = {}, {}
    pd.wash = pad:CreateTexture(nil, "BACKGROUND")
    pd.wash:SetAllPoints()
    pd.wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.14)
    pd.glyph = pad:CreateTexture(nil, "ARTWORK")
    pd.glyph:SetTexture(GLYPHS .. "mouse")
    pd.glyph:SetSize(18, 18)
    pd.glyph:SetPoint("LEFT", pad, "LEFT", 11, 0)
    pd.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    b.line1 = ns.Text(pad, 13)
    b.line1:SetPoint("TOPLEFT", pad, "TOPLEFT", 38, -7)
    b.line2 = ns.Text(pad, 12)
    b.line2:SetPoint("TOPLEFT", pad, "TOPLEFT", 38, -24)
    b.line2:SetTextColor(DIM[1], DIM[2], DIM[3])
    pad:SetScript("OnClick", Press)
    pad:SetScript("OnEnter", function(self)
        self.hot = true
        Paint()
    end)
    pad:SetScript("OnLeave", function(self)
        self.hot = false
        Paint()
    end)
    pad:SetScript("OnSizeChanged", function() Paint() end)
    -- under it: the next thing to know, and the binding dropped
    b.hint = ns.Text(b, 12)
    b.hint:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 8)
    local cancel = CreateFrame("Button", nil, b)
    b.cancel = cancel
    cancel:SetSize(20, 20)
    cancel:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 4)
    local g = R.Glyph(cancel, "close", 10)
    g:SetVertexColor(DIM[1], DIM[2], DIM[3])
    cancel:SetScript("OnEnter", function(self)
        g:SetVertexColor(1, 1, 1)
        ns.Tip(self, ns.window.Outside, { title = Tr["Put it down"], color = GOLD,
            { "body", Tr["Leaves the binder empty; the list keeps what you set."] } })
    end)
    cancel:SetScript("OnLeave", function()
        g:SetVertexColor(DIM[1], DIM[2], DIM[3])
        GameTooltip:Hide()
    end)
    cancel:SetScript("OnClick", function()
        local was = cc.target
        cc.target, cc.set, loaded = nil, false, nil
        Paint()
        local fr = Frame()
        if was and fr and fr.ScrollBox and fr.ScrollBox.ForEachFrame then fr.ScrollBox:ForEachFrame(Element) end
    end)
    Paint()
    return b
end

-- ------------------------------------------------------------- the dressing
local function Dress()
    local f = Frame()
    if not f or not ns.db.ccWindow then return end
    Top(f)
    List(f)
    Foot(f)
    Binder(f)
    cc.Binder()
end
cc.Dress = Dress

local adopted = false
local function Adopt()
    local f = Frame()
    if adopted or not f then return end
    adopted = true
    skin = R.Chrome(f, Tr["Click Casting"], { { "TOP", TOP }, { "BOTTOM", ROW } }, HEAD + 4)
    cc.frame = f
    cc.skin = skin
    Dress()
    -- each binding as the list gives it out (and as the game fills it again)
    local box = f.ScrollBox
    if box and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        ScrollUtil.AddAcquiredFrameCallback(box, function(_, frame) Element(frame) end, cc, true)
    end
    -- what there is to save, and the binder, as the game changes its list
    local function Changed()
        cc.Pending()
        cc.Binder()
    end
    for _, method in ipairs({ "AddNewAction", "Refresh", "ResetToDefaultProfile", "SetHasNewSlot",
        "CleanDataProvider", "ClearUnboundText", "SetUnboundText" }) do
        if f[method] then hooksecurefunc(f, method, Changed) end
    end
    -- the slot filled (a spell clicked in the book, one dropped on it): into
    -- the binder
    if f.FillNewSlot then
        hooksecurefunc(f, "FillNewSlot", function(self)
            cc.Pending()
            if self.GetLastElement then cc.Load(self:GetLastElement()) end
        end)
    end
    f:HookScript("OnHide", function()
        cc.target, cc.set = nil, false
        cc.Binder()
    end)
    if f.UpdateMouseoverCastUI then hooksecurefunc(f, "UpdateMouseoverCastUI", Place) end
    Place()
    R.Hold(f, Place)
    R.Stand(f, "cc", function()
        Place()
        Dress()
    end)
end
cc.Adopt = Adopt

local function Start()
    if not ns.db.ccWindow then return end
    if Frame() then Adopt() end
    if not adopted then
        ns.On("ADDON_LOADED", function(_, name)
            if name == "Blizzard_ClickBindingUI" then Adopt() end
        end)
    end
end

ns.On("PLAYER_LOGIN", Start)
