-- The Character page: the name and title, the gear down both sides of the
-- player's model, the weapons under it, and in the details a switch
-- between the stats, the titles and the equipment sets
-- (character/stats.lua, titles.lua, sets.lua).
--
--   Name, Title of the Realm
--   Class (Spec)  Level N
--   [head]  +----------------------+  [hands]
--   [neck] -|                      |- [waist]
--    ...    |      the model       |    ...
--   [wrist] +----------------------+  [trinket]
--            [main] [off] [ranged] [ammo]
--   ...the details...
--   (medallion)  [Talents] [Spellbook] [Professions]
--
-- The window is the screen's height, and the page spreads out over what it
-- has (Fit): bigger slots first, then room between them, then what is left
-- under the weapons; the name stays at the top.
--
-- The gear slots are Blizzard's own (CharacterHeadSlot and the rest), taken
-- off its hidden window as the bags window takes the bag slots off the bag
-- bar: equipping, swapping, the tooltips and a right click's use are the
-- client's, and the use is protected, so it must be. Blizzard decides which
-- of the ranged and ammo slots this character has; the weapons row closes
-- up over the ones it hides.
local _, ns = ...
local Tr = ns.L

local SLOT, PITCH, GAP = 34, 39, 6             -- the least: a slot, a row, the weapons' gap
local SLOT_MAX, SPREAD = 46, 26                 -- the most: a slot, and room added between rows
local HEAD = 40                                 -- the name and the class line
-- (2026-11-19, as the spellbook's tabs and the talents' console) the name
-- and the class line in the panel the shell joins under the head: its
-- height (page.under); the columns then start at the body's top
local JOIN = 44
local STAGE = 10                                -- between a column and the stage, a hairline across
local BRACKET = 14                              -- the stage's corner brackets' arms
local LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local BOTTOM = { "MainHand", "SecondaryHand", "Ranged", "Ammo" }
-- no item level on these: a shirt, a tabard and ammo have none worth reading
local PLAIN = { Shirt = true, Tabard = true, Ammo = true }
local GOLD = ns.gold.light
local GOLD_D = ns.gold.dark
local LINE = { 0.227, 0.196, 0.141 }            -- an empty slot's edge
-- the stage's soft light (art/character/gen_glow.py): white, fading out
-- smoothly from its middle, tinted and stretched as each light needs
local GLOW = "character\\glow"
local TURN = 0.012                              -- the model's turn, in radians per pixel dragged
local SWITCH = 26 + 10                          -- the details' switch, and the gap under it
local VIEWS = { { "stats", Tr["Stats"], Tr["Your stats."] }, { "titles", Tr["Titles"],
    Tr["Wear a title you have earned."] },
    { "sets", Tr["Sets"], Tr["Your equipment sets."] } }

local page, doll
local views, view = {}, "stats"                 -- the details' parts, and the one shown

-- The level of what a unit wears in a slot, nil for an empty one: the
-- item's own place reads it as worn (the player's only), else its link.
-- The paperdoll's plates and the Rolls window's upgrade line (strips/rolls.lua).
function ns.WornItemLevel(slot, unit)
    unit = unit or "player"
    local link = GetInventoryItemLink(unit, slot)
    if not link then return end
    if unit == "player" and C_Item and C_Item.GetCurrentItemLevel and ItemLocation
        and ItemLocation.CreateFromEquipmentSlot then
        local loc = ItemLocation:CreateFromEquipmentSlot(slot)
        if loc and loc:IsValid() then return C_Item.GetCurrentItemLevel(loc) end
    end
    local detailed = GetDetailedItemLevelInfo or (C_Item and C_Item.GetDetailedItemLevelInfo)
    if detailed then return (detailed(link)) end
end

-- ------------------------------------------------------------------ doll
-- The name, the class line, the gear round the model and the weapons
-- under it, fitted to the height there is: the character page's, and the
-- inspect window's (inspect/page.lua), each its own.
--   ns.character.Doll{ prefix ("Character": Blizzard's CharacterHeadSlot
--     and the rest; "Inspect": InspectHeadSlot...), Unit() -> the unit,
--     page (its height; Fit writes page.fit) }
--   -> { Build(body), Fit(h), Refresh(), SetModel(), slots, weapons, model }
function ns.character.Doll(spec)
    local d = {}
    local body, name, line, model, wash
    local size, pitch, cols = SLOT, PITCH, HEAD     -- a slot, a row, the columns' top: Fit's
    local slots, weapons = {}, {}
    local placing = false
    local function Unit() return spec.Unit() or "player" end

    -- ------------------------------------------------------------ slots
    local function Icon(btn)
        return btn.icon or _G[btn:GetName() .. "IconTexture"]
    end

    local function Quality(slot)
        local q = GetInventoryItemQuality(Unit(), slot)
        if q and q > 1 then
            local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            if c then return c.r, c.g, c.b end
        end
        return GOLD_D[1], GOLD_D[2], GOLD_D[3]
    end

    local function ItemLevel(slot) return ns.WornItemLevel(slot, Unit()) end
    d.ItemLevel = ItemLevel

    -- The edge in the item's quality, its level on a plate at the slot's inner foot; an empty slot's
    -- (Blizzard's empty art) dimmed, its edge a plain line.
    local function Paint(btn)
        local slot = btn:GetID()
        local q = GetInventoryItemLink(Unit(), slot) and GetInventoryItemQuality(Unit(), slot)
        local r, g, b = Quality(slot)
        local filled = q ~= nil
        if filled then btn.edge:SetColorTexture(r, g, b) else btn.edge:SetColorTexture(LINE[1], LINE[2], LINE[3]) end
        local icon = Icon(btn)
        if icon then
            icon:SetDesaturated(not filled)
            icon:SetAlpha(filled and 1 or 0.45)
        end
        local level = not PLAIN[btn.slotName] and ItemLevel(slot)
        local text = level and level > 0 and tostring(level) or ""
        btn.level:SetText(text)
        btn.plate:SetShown(text ~= "")
        btn.plate:SetWidth(math.floor((btn.level:GetStringWidth() or 0) + 8))
    end

    -- the level's plate at the slot's foot, hanging half out on the side
    -- toward the model (a weapon's toward the row's middle)
    local function PlatePlace(btn, inward)
        btn.plate:ClearAllPoints()
        if inward == 0 then
            btn.plate:SetPoint("CENTER", btn, "BOTTOM", 0, 1)
        else
            btn.plate:SetPoint("CENTER", btn, inward < 0 and "BOTTOMLEFT" or "BOTTOMRIGHT", inward < 0 and 2 or -2, 1)
        end
    end

    -- Blizzard's slot art (its frame, its quality ring) gives way to an edge
    -- like the bag slots'; put back whenever Blizzard re-sets it.
    local function Restyle(btn)
        ns.Mute(btn:GetNormalTexture())
        ns.Mute(btn.IconBorder)
        -- the slot's own frame art (its corner pips)
        ns.Mute(_G[btn:GetName() .. "Frame"])
    end

    local function Style(btn, slotName)
        btn.slotName = slotName
        local icon = Icon(btn)
        if icon then
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", -1, 1)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        btn.edge = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        btn.edge:SetAllPoints()
        btn.plate = CreateFrame("Frame", nil, btn)
        btn.plate:SetSize(20, 13)
        btn.plate:SetFrameLevel(btn:GetFrameLevel() + 3)
        local plateEdge = btn.plate:CreateTexture(nil, "BACKGROUND")
        plateEdge:SetAllPoints()
        plateEdge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        local plateWell = btn.plate:CreateTexture(nil, "BACKGROUND", nil, 1)
        plateWell:SetPoint("TOPLEFT", 1, -1)
        plateWell:SetPoint("BOTTOMRIGHT", -1, 1)
        plateWell:SetColorTexture(0.055, 0.05, 0.04, 0.95)
        btn.level = ns.Text(btn.plate, 10)
        btn.level:SetPoint("CENTER", 0, 0)
        btn.level:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        PlatePlace(btn, 1)
        Restyle(btn)
        -- Shift-click with no chat box open: the chat opened with its link (the
        -- game's slot puts it only into a box being typed in)
        btn:HookScript("OnClick", function(self, button)
            if not ns.Linking(button) or ns.ChatOpen() or CursorHasItem() then return end
            ns.LinkInChat(GetInventoryItemLink(Unit(), self:GetID()))
        end)
        for _, method in ipairs({ "SetNormalTexture", "SetNormalAtlas" }) do
            if btn[method] then hooksecurefunc(btn, method, Restyle) end
        end
    end

    -- The columns, and the weapons row closed up and centred under the model.
    -- the weapons row's top: under the columns' last slot
    local function WeaponsTop()
        return cols + (#LEFT - 1) * pitch + size + (PITCH - SLOT) + GAP
    end

    local function Place()
        placing = true
        local width = ns.character.width
        for _, btn in ipairs(slots) do
            local col = btn.side
            btn:ClearAllPoints()
            btn:SetSize(size, size)
            btn:SetPoint(col < 0 and "TOPLEFT" or "TOPRIGHT", body, col < 0 and "TOPLEFT" or "TOPRIGHT",
                0, -(cols + (btn.row - 1) * pitch))
            PlatePlace(btn, -col)
            -- a hairline from the slot across to the stage
            btn.wire:ClearAllPoints()
            btn.wire:SetPoint(col < 0 and "LEFT" or "RIGHT", btn, col < 0 and "RIGHT" or "LEFT", 0, 0)
        end
        local shown = {}
        for _, btn in ipairs(weapons) do
            if btn:IsShown() then table.insert(shown, btn) end
        end
        local across = #shown * size + math.max(0, #shown - 1) * GAP
        local x = (width - across) / 2
        local y = WeaponsTop()
        for _, btn in ipairs(shown) do
            btn:ClearAllPoints()
            btn:SetSize(size, size)
            btn:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
            x = x + size + GAP
            -- the plate under the weapon's middle: at a corner, the
            -- next weapon's would meet it
            PlatePlace(btn, 0)
        end
        placing = false
    end
    d.Place = Place

    local function Take(slotName, side, row)
        local btn = _G[spec.prefix .. slotName .. "Slot"]
        if not btn then return end
        btn:SetParent(body)
        btn:SetFrameLevel(body:GetFrameLevel() + 2)
        Style(btn, slotName)
        btn.side, btn.row = side, row
        if side then
            btn.wire = body:CreateTexture(nil, "ARTWORK")
            btn.wire:SetSize(STAGE, 1)
            btn.wire:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
            table.insert(slots, btn)
        else
            table.insert(weapons, btn)
        end
        hooksecurefunc(btn, "SetPoint", function()
            if not placing then Place() end
        end)
        return btn
    end

    -- ------------------------------------------------------------ model
    -- The unit, turned by dragging across it, on a stage: dark at its top
    -- and warming down, a light in the class's colour behind them; framed
    -- in gold, a bracket at each corner, a hairline across from each slot.
    local stage
    local function Frame()
        model:ClearAllPoints()
        model:SetPoint("TOPLEFT", body, "TOPLEFT", size + STAGE, -cols)
        model:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", -(size + STAGE), -(cols + (#LEFT - 1) * pitch + size))
    end

    -- a soft light on the stage: the glow texture, tinted (Light sizes and
    -- places it)
    local function Glow(parent, sub, alpha)
        local t = parent:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetTexture(ns.media .. GLOW)
        t:SetBlendMode("ADD")
        t.alpha = alpha
        return t
    end

    local function Stage()
        stage = CreateFrame("Frame", nil, body)
        stage:SetAllPoints(model)
        stage:SetFrameLevel(body:GetFrameLevel())
        local ground = stage:CreateTexture(nil, "BACKGROUND", nil, -8)
        ground:SetAllPoints()
        if ground.SetGradient and CreateColor then
            ground:SetColorTexture(1, 1, 1, 1)
            -- VERTICAL runs bottom to top: warm at the floor, dark above
            ground:SetGradient("VERTICAL", CreateColor(0.15, 0.13, 0.1, 1), CreateColor(0.047, 0.043, 0.035, 1))
        else
            ground:SetColorTexture(0.1, 0.09, 0.07, 1)
        end
        stage.ground = ground
        stage.light = Glow(stage, 1, 0.16)
        -- the frame: a line round it, a bracket at each corner
        stage.edges = {}
        for i, at in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = stage:CreateTexture(nil, "BORDER")
            t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.7)
            if i <= 2 then
                t:SetHeight(1)
                t:SetPoint(at .. "LEFT")
                t:SetPoint(at .. "RIGHT")
            else
                t:SetWidth(1)
                t:SetPoint("TOP" .. at)
                t:SetPoint("BOTTOM" .. at)
            end
            stage.edges[i] = t
        end
        stage.brackets = {}
        for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
            for _, across in ipairs({ true, false }) do
                local t = stage:CreateTexture(nil, "ARTWORK")
                t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
                t:SetSize(across and BRACKET or 2, across and 2 or BRACKET)
                t:SetPoint(corner)
                table.insert(stage.brackets, t)
            end
        end
    end

    -- the stage's light, laid to its size (Fit's numbers: the
    -- frame may not be laid out yet), the light in the unit's class colour
    local function Light()
        local w = ns.character.width - 2 * (size + STAGE)
        local h = (#LEFT - 1) * pitch + size
        stage.w, stage.h = w, h
        local _, class = UnitClass(Unit())
        -- an inspected unit's class can be secret: no colour then, gold
        local c = class and not ns.IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        local light = stage.light
        light:ClearAllPoints()
        light:SetSize(w * 0.95, h * 0.8)
        light:SetPoint("CENTER", stage, "CENTER", 0, h * 0.06)
        local r, g, b = c and c.r or GOLD[1], c and c.g or GOLD[2], c and c.b or GOLD[3]
        light:SetVertexColor(r, g, b, light.alpha)
    end

    local function Model()
        model = CreateFrame("PlayerModel", nil, body)
        model:SetFrameLevel(body:GetFrameLevel() + 1)
        Frame()
        Stage()
        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then self.from = GetCursorPosition() end
        end)
        model:SetScript("OnMouseUp", function(self) self.from = nil end)
        model:SetScript("OnUpdate", function(self)
            if not self.from then return end
            local x = GetCursorPosition()
            self:SetFacing((self:GetFacing() or 0) + (x - self.from) * TURN)
            self.from = x
        end)
    end

    function d.SetModel()
        if model then model:SetUnit(Unit()) end
    end

    -- a gold wash fading down the head
    local function Wash()
        wash = body:CreateTexture(nil, "BACKGROUND", nil, -7)
        wash:SetPoint("TOPLEFT")
        wash:SetPoint("TOPRIGHT")
        if wash.SetGradient and CreateColor then
            wash:SetColorTexture(1, 1, 1, 1)
            wash:SetGradient("VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0),
                CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.12))
        else
            wash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.05)
        end
    end

    -- -------------------------------------------------------------- fit
    -- The page has h, at least page.height: bigger slots first (nine of
    -- them stand in a column with the weapons), then room between the rows
    -- (seven gaps), up to twice the usual most; what is left goes under the
    -- weapons. The name stays at the top, so it stands where it does in
    -- every window the doll is in.
    function d.Fit(h)
        d.height = h
        local p = spec.page
        local extra = math.max(0, h - p.height)
        size = math.min(SLOT_MAX, SLOT + math.floor(extra / 9))
        extra = extra - 9 * (size - SLOT)
        local spare = math.min(2 * SPREAD, math.floor(extra / 7))
        pitch = size + (PITCH - SLOT) + spare
        local top = 1
        if p.panel then
            -- joined: the name and its line centred in the panel; no wash
            -- of their own (the panel's rises from its foot)
            cols = top
            name:ClearAllPoints()
            name:SetPoint("TOP", p.panel, "TOP", 0, -((JOIN - HEAD) / 2 + 3))
            wash:Hide()
        else
            cols = top + HEAD + top
            name:ClearAllPoints()
            name:SetPoint("TOP", 0, -(top + 2))
            wash:SetHeight(top + HEAD + top / 2)
        end
        Frame()
        Light()
        Place()
        p.fit = { size = size, pitch = pitch, top = top, cols = cols }
    end

    -- ------------------------------------------------------------- head
    -- the spec: the player's own, or what the inspection told
    local function Spec(unit)
        if unit == "player" then
            if GetSpecialization and GetSpecializationInfo then
                local i = GetSpecialization()
                return i and select(2, GetSpecializationInfo(i))
            end
        elseif GetInspectSpecialization and GetSpecializationInfoByID then
            local id = GetInspectSpecialization(unit)
            local s = id and id > 0 and select(2, GetSpecializationInfoByID(id)) or nil
            -- before a spec is chosen the game names the class's starter one
            -- after the class: "Warrior (Warrior)" says nothing
            local className = UnitClass(unit)
            if s and (ns.IsSecret(s) or ns.IsSecret(className) or s ~= className) then return s end
        end
    end

    -- the class (and spec) in the class's colour, the level dim after it
    local function ClassLine()
        local unit = Unit()
        local className, class = UnitClass(unit)
        local s = Spec(unit)
        local who = s and format("%s (%s)", className, s) or className or ""
        local c = class and not ns.IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then who = format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, who) end
        return format(Tr["%s  Level %d"], who, UnitLevel(unit) or 0)
    end

    function d.Refresh()
        local unit = Unit()
        name:SetText(UnitPVPName(unit) or UnitName(unit))
        line:SetText(ClassLine())
        Light()
        for _, btn in ipairs(slots) do Paint(btn) end
        for _, btn in ipairs(weapons) do Paint(btn) end
        Place()
    end

    function d.Build(frame)
        body = frame
        -- (in the joined panel, when the page has one)
        local holder = spec.page.panel or body
        name = ns.Text(holder, 18)
        name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        line = ns.Text(holder, 12)
        line:SetPoint("TOP", name, "BOTTOM", 0, -4)
        line:SetTextColor(unpack(ns.colors.dim))
        Wash()
        for i, s in ipairs(LEFT) do Take(s, -1, i) end
        for i, s in ipairs(RIGHT) do Take(s, 1, i) end
        for _, s in ipairs(BOTTOM) do
            local btn = Take(s)
            -- Blizzard shows and hides the ranged and ammo slots by the character
            if btn then
                hooksecurefunc(btn, "Show", Place)
                hooksecurefunc(btn, "Hide", Place)
            end
        end
        Model()
        d.Fit(spec.page.height)
        d.slots, d.weapons, d.model = slots, weapons, model
        d.name, d.line, d.stage, d.wash = name, line, stage, wash
    end

    return d
end

-- the least a page with the doll needs; its panel joined under the head,
-- and the least then (the name and its line in the panel)
ns.character.dollHeight = HEAD + #LEFT * PITCH + GAP + SLOT
ns.character.dollJoin = { under = JOIN, height = #LEFT * PITCH + GAP + SLOT + 2 }

-- ------------------------------------------------------------- details
-- Stats, Titles, Sets across the top; each part has the same room, the
-- stats' (the tallest), so the window keeps its height between them. A
-- client without titles or sets has no button for them.
local switch                                    -- the details' switch: joined segments
local function Mark(key)
    view = key
    for k, v in pairs(views) do
        v.frame:SetShown(k == key)
        switch:Set(k, { selected = k == key })
    end
end

local function Show(key)
    Mark(key)
    ns.character[key].Refresh()
end

local function Details(foot)
    local stats = ns.character.stats
    local keys = {}
    for _, v in ipairs(VIEWS) do
        local part = ns.character[v[1]]
        if v[1] == "stats" or part.available then table.insert(keys, v) end
    end
    -- Stats, Titles, Sets joined, centred over the details
    local items = {}
    for _, v in ipairs(keys) do
        table.insert(items, { key = v[1], label = v[2], group = "views", click = function() Show(v[1]) end,
            tip = function() return v[3] end })
    end
    -- (2026-11-19, /workspace/sleek-character.png) words over a hairline,
    -- the held one underlined, the hairline across the page
    switch = ns.window.Segments(foot, { height = 26, tabs = true, items = items })
    switch:SetHeight(26)
    switch:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
    switch:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
    local height
    for _, v in ipairs(keys) do
        local key = v[1]
        local frame = CreateFrame("Frame", nil, foot)
        frame:SetPoint("TOPLEFT", 0, -SWITCH)
        views[key] = { frame = frame, button = switch.byKey[key] }
        if key == "stats" then
            -- the stats draw first: their height is everyone's
            stats.Build(frame)
            height = stats.height
        else
            ns.character[key].Build(frame, height)
        end
        frame:SetSize(ns.character.width, height)
    end
    page.footHeight = SWITCH + height
    page.views, page.switch = views, switch
    Mark(view)
end

-- ------------------------------------------------------------ shortcuts
-- Talents, Spellbook and Professions, in the window's margin beside the
-- medallion: flush, as a window's tabs, joined buttons from 5 short of the
-- medallion's ring to the window's border, from its foot up over the
-- margin's rule (as the strip's cells under them). Each clicks Blizzard's own micro button through a secure
-- button, so the book or the talents open as the micro menu opens them,
-- with no addon's hand on them.
--
-- Neither a secure button nor a frame holding one may be shown or hidden
-- in combat, so the row is not the window's (the window opens and closes
-- in combat): it stands on the strip over the margin and follows the window
-- out of combat; in combat a state driver hides it, and when combat ends
-- it follows the window again.
local SHORTCUTS = {
    { Tr["Talents"], Tr["Open your talents."], "talents", { "TalentMicroButton", "PlayerSpellsMicroButton" } },
    { Tr["Spellbook"], Tr["Open your spellbook."], "spellbook", { "SpellbookMicroButton", "PlayerSpellsMicroButton" } },
    { Tr["Professions"], Tr["Open your professions."], "profession", { "ProfessionMicroButton" } },
}
local row
local open = false                              -- the window open on this page

-- the micro button a shortcut clicks: the first this client shows, or has
local function Target(names)
    local had
    for _, n in ipairs(names) do
        local b = _G[n]
        if b then
            if b:IsShown() then return b end
            had = had or b
        end
    end
    return had
end

local function Follow()
    if InCombatLockdown() then return end
    if open then
        RegisterStateDriver(row, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(row, "visibility")
        row:Hide()
    end
end

local function Shortcuts(band)
    local strip = ns.strips[-1]
    local window = band:GetParent()
    local from = ns.stripCells.from
    row = CreateFrame("Frame", "MedalUICharacterShortcuts", strip)
    row:SetFrameStrata("MEDIUM")
    row:SetFrameLevel(window:GetFrameLevel() + 10)
    row:SetIgnoreParentAlpha(true)
    row:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", from, ns.stripLayout.stripHeight)
    row:SetSize(ns.character.width + 2 * ns.window.pad - from, ns.window.band + 1)
    row:Hide()
    -- (2026-11-25) engraved slots, SLOT_GAP apart in a sunk tray
    ns.reskin.Recess(row)
    local SLOT_GAP = 3
    local list = {}
    for _, s in ipairs(SHORTCUTS) do
        local target = Target(s[4])
        if target then table.insert(list, { s, target }) end
    end
    local n = math.max(1, #list)
    local total = math.floor(row:GetWidth()) - (n + 1) * SLOT_GAP
    local x = SLOT_GAP
    row.buttons = {}
    for i, e in ipairs(list) do
        local s, target = e[1], e[2]
        local w = math.floor(i * total / n) - math.floor((i - 1) * total / n)
        local b = ns.character.Button(row, w, nil, function() return s[2] end, "SecureActionButtonTemplate",
            "engraved")
        b:SetHeight(row:GetHeight() - 2 * SLOT_GAP)
        b:SetPoint("TOPLEFT", x, -SLOT_GAP)
        x = x + w + SLOT_GAP
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "click")
        b:SetAttribute("clickbutton", target)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetTexture(ns.media .. "strips\\" .. s[3])
        b.label:SetText(s[1])
        b.label:ClearAllPoints()
        b.label:SetPoint("CENTER", 10, 0)
        b.icon:SetPoint("RIGHT", b.label, "LEFT", -5, 0)
        b.target = target
        row.buttons[i] = b
    end
    ns.On("PLAYER_REGEN_ENABLED", Follow)
    page.shortcuts = row
end

local function Refresh()
    doll.Refresh()
    ns.character[view].Refresh()
end

local function Build(frame, foot, band)
    -- Blizzard's slot hover opens the equipment flyout (Alt) with the
    -- settings its parent holds: the slots' parent is this page now, so it
    -- holds a copy of Blizzard's, the flyout shown over this window (theirs
    -- is only read; the 0.20 flyoutSettings error)
    local theirs = PaperDollItemsFrame and PaperDollItemsFrame.flyoutSettings
    if type(theirs) == "table" then
        local mine = {}
        for k, v in pairs(theirs) do mine[k] = v end
        mine.parent = frame
        frame.flyoutSettings = mine
    end
    doll.Build(frame)
    ns.character.slots = { columns = doll.slots, weapons = doll.weapons, model = doll.model }
    Details(foot)
    Shortcuts(band)
end

page = {
    key = "character", label = Tr["Character"], frame = "PaperDollFrame", order = 1,
    height = ns.character.dollJoin.height, under = ns.character.dollJoin.under, bandUsed = true,
    -- the window's linen backdrop behind it (window/shell.lua), woven in the
    -- theme's colour (theme.lua): a cream gold, or the class's
    linen = function() return ns.gold.linen end,
    events = { "PLAYER_EQUIPMENT_CHANGED", "UNIT_MODEL_CHANGED", "UNIT_NAME_UPDATE", "PLAYER_LEVEL_UP",
        "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
        "UNIT_ATTACK_SPEED", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED",
        "PLAYER_AVG_ITEM_LEVEL_UPDATE", "KNOWN_TITLES_UPDATE", "SKILL_LINES_CHANGED",
        "EQUIPMENT_SETS_CHANGED" },
    Build = Build, Fit = function(h) doll.Fit(h) end, Refresh = Refresh,
    Shown = function() doll.SetModel() end,
    Showing = function(on)
        open = on
        Follow()
    end,
    OnEvent = function(event)
        if event == "UNIT_MODEL_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then doll.SetModel() end
    end,
}
doll = ns.character.Doll{ prefix = "Character", Unit = function() return "player" end, page = page }
page.doll = doll
ns.CharacterPage(page)
