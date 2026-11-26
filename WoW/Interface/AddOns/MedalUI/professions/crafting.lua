-- A profession's tab of the professions window (professions/window.lua):
-- its recipes, the chosen one's reagents, and Create.
--
--   [icon] Mining                          Expert at skill 125, level 20
--          [================ 142 / 150 ================]
--   ------------------------------ <> ------------------------------
--   [search........................]
--   - Favourites                                  (right-click stars one)
--     [icon] Rough Sharpening Stone                          [3]
--   - Armor                                                    (a heading)
--     [icon] Copper Chain Vest                               [3]
--     [icon] Runed Copper Belt
--   - Nodes (13)                     (Mining and Herbalism: what it gathers)
--     [icon] Tin Vein                                   Skill 65
--   - At the trainer (2)              (what its trainer teaches, unlearned)
--     [icon] Copper Mace                               Skill 15
--   ---------------------------------------------------------------
--   the chosen recipe: its reagents as slots, had / needed, an arrow to
--   what it makes
--     [ico]   [ico]        [ICON] Roast Raptor
--      9/1     9/1    --->        Makes 1
--     Raptor  Hot                 You can make 9
--   [- | 1 | +]   [Create] [Create all (9)]
--   ---------------------------------------------------------------
--   (backpack)     [x] Have materials  [x] Show unknown
--
-- A recipe's colour is its difficulty, as the game's (orange, yellow,
-- green, grey), and its count how many the bags can make. The list is the
-- open profession's: a tab opens its profession (out of combat), and the
-- page waits for it. Search and Have materials are the game's own filters.
--
-- Favourites are MedalUI's, per character (MedalUICharDB.
-- recipeFavourites, by recipe), listed first and not again in their
-- category. At the trainer closes the list: the profession trainer's
-- services as last read (spells/trainers.lua) not learned yet, those your
-- skill and level allow first; one is read in the details, never made.
-- Have materials leaves it out, as Show unknown unticked does (per
-- character: MedalUICharDB.recipesUnknownHidden), and the search filters
-- it as the recipes.
--
-- Over it all, in the panel joined under the head (as the Overview's
-- banner and the character window's name): the profession's skill as a
-- bar, centred, and under it its next rank as the Overview's pillar says
-- it ("Highest rank this expansion" at the top).
--
--   (the head: the profession's medallion and name)
--                   [======== 179 / 225 ====     ]
--                 Artisan at skill 200, level 35
-- Mining's and Herbalism's pages list the nodes they gather (character/
-- nodes.lua), coloured by the chance one gives a skill point; one is read
-- in the details: the skill it needs and where it grows.
-- The details say where a recipe greys (maxTrivialLevel) and what a craft
-- is worth (numSkillUps); the yellow and green marks are not the API's,
-- so only smelting has them, from the Classic-era record (SMELTING): its
-- recipes say where they turn yellow, green and grey, in those colours.
local _, ns = ...
local Tr = ns.L

local W = ns.professions
local GOLD = ns.gold.light
local GOLD_D = ns.gold.dark
local Money = function(c) return ns.npc and ns.npc.Money(c) or tostring(c) end
local SLOTS = 5                         -- with Overview, six tabs at most
local SEARCH = 24
local BANNER_BAR, BAR_MARGIN = 300, 20          -- the banner's bar: its width at most, its room either side
local HEAD = SEARCH + 2                         -- the list's top
-- the game's colours, by Enum.TradeskillRelativeDifficulty
local DIFFICULTY = {
    [0] = { 1, 0.5, 0.25 },             -- optimal
    [1] = { 1, 1, 0 },                  -- medium
    [2] = { 0.25, 0.75, 0.25 },         -- easy
    [3] = { 0.5, 0.5, 0.5 },            -- trivial
}

-- the profession is open, its list built
local function Ready(p)
    return p.skillLine and W.Skill() == p.skillLine and not C_TradeSkillUI.IsDataSourceChanging()
end

-- the open last asked for, and when: on its way until it has come, or for
-- WAIT seconds (an open the game drops is asked again after that)
local asked, askedAt, WAIT = nil, 0, 2

local function Count(recipe) return C_TradeSkillUI.GetCraftableCount(recipe) or 0 end

-- the item a recipe makes, or nil (an enchant makes none)
local function Made(recipe)
    local schematic = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipe, false)
    return schematic and schematic.outputItemID
end

-- (2026-11-23, the user's) what a recipe makes, as the item's own
-- tooltip; a craft with no item (an enchant) its spell's
local function MadeTip(recipe)
    local made = Made(recipe)
    if made then GameTooltip:SetItemByID(made) else GameTooltip:SetSpellByID(recipe) end
end

-- ----------------------------------------------------------------- list
local function Favourites()
    MedalUICharDB = MedalUICharDB or {}
    if type(MedalUICharDB.recipeFavourites) ~= "table" then MedalUICharDB.recipeFavourites = {} end
    return MedalUICharDB.recipeFavourites
end

-- a heading, folded by key
local function Heading(p, rows, key, label)
    local folded = p.folded[key]
    table.insert(rows, { header = true, label = label, collapsed = folded, click = function()
        p.folded[key] = not p.folded[key] or nil
        p.Refresh()
    end })
    return not folded
end

local function Recipe(p, info)
    local n = Count(info.recipeID)
    return { label = info.name, icon = info.icon, depth = 1,
        value = n > 0 and format("[%d]", n) or nil,
        color = DIFFICULTY[info.relativeDifficulty] or ns.colors.text,
        selected = info.recipeID == p.chosen,
        click = function(button)
            if ns.Linking(button) and C_TradeSkillUI.GetRecipeLink then
                ns.LinkInChat(C_TradeSkillUI.GetRecipeLink(info.recipeID))
                return
            end
            if button == "RightButton" then
                local favs = Favourites()
                favs[info.recipeID] = not favs[info.recipeID] or nil
            else
                p.chosen, p.trained, p.node = info.recipeID, nil, nil
            end
            p.Refresh()
        end,
        enter = function(row)
            W.Beside(row)
            MadeTip(info.recipeID)
            GameTooltip:AddLine(Favourites()[info.recipeID] and Tr["Right-click: take its star off."]
                or Tr["Right-click: star it, to list it first."], unpack(ns.colors.dim))
            GameTooltip:Show()
        end }
end

local function Label(e) return e.rank and format("%s (%s)", e.name, e.rank) or e.name end

-- a trainer's service: the item it makes, as the item's tooltip (its id
-- kept when the trainer was read; for a list read before that, the item of
-- its name when the game knows it); else its name and what it asks
local function TrainedTip(row, e)
    W.Beside(row)
    local link = not e.item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(e.name))
    if e.item then
        GameTooltip:SetItemByID(e.item)
    elseif type(link) == "string" then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(Label(e))
        GameTooltip:AddLine(Tr["At the trainer"], unpack(ns.colors.dim))
    end
    GameTooltip:Show()
end

-- the profession trainer's services not learned, matching the search:
-- { key, entry, now }, those you can learn now first, then by skill
local function Untrained(p, learned)
    local out = {}
    local prof = p.prof
    if not prof then return out end
    local text = p.search and p.search:GetText() or ""
    text = text:lower()
    local level = UnitLevel("player")
    for key, e in pairs(ns.trainers.Trade(prof.name)) do
        if not e.known and not learned[e.name] and (text == "" or e.name:lower():find(text, 1, true)) then
            table.insert(out, { key = key, entry = e,
                now = (e.skill or 0) <= prof.rank and (e.level or 0) <= level })
        end
    end
    table.sort(out, function(a, b)
        if a.now ~= b.now then return a.now end
        if (a.entry.skill or 0) ~= (b.entry.skill or 0) then return (a.entry.skill or 0) < (b.entry.skill or 0) end
        return a.key < b.key
    end)
    return out
end

-- the nodes this profession gathers, matching the search
local function Nodes(p)
    local out = {}
    local text = (p.search and p.search:GetText() or ""):lower()
    for _, prof in ipairs(ns.gatheringNodes) do
        if p.prof and prof.skillID == p.prof.skillLine then
            for _, n in ipairs(prof.nodes) do
                if text == "" or n[1]:lower():find(text, 1, true) then table.insert(out, n) end
            end
        end
    end
    return out
end

local function Rows(p)
    local rows, heads, order, favs, learned = {}, {}, {}, {}, {}
    local starred = Favourites()
    for _, id in ipairs(C_TradeSkillUI.GetFilteredRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then
            learned[info.name] = id
            if starred[id] then
                table.insert(favs, info)
            else
                local cat = info.categoryID or 0
                if not heads[cat] then
                    local c = C_TradeSkillUI.GetCategoryInfo(cat)
                    heads[cat] = { name = c and c.name or Tr["Other"], recipes = {} }
                    table.insert(order, cat)
                end
                table.insert(heads[cat].recipes, info)
            end
        end
    end
    -- a recipe the filters hide is still learned
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then learned[info.name] = id end
    end
    W.CampLearned(p.skillLine, learned)            -- the camp objects it knows (camping.lua)
    if #favs > 0 and Heading(p, rows, "favourites", Tr["Favourites"]) then
        for _, info in ipairs(favs) do table.insert(rows, Recipe(p, info)) end
    end
    for _, cat in ipairs(order) do
        if Heading(p, rows, cat, heads[cat].name) then
            for _, info in ipairs(heads[cat].recipes) do table.insert(rows, Recipe(p, info)) end
        end
    end
    local makeable = C_TradeSkillUI.GetOnlyShowMakeableRecipes()
    local nodes = not makeable and Nodes(p) or {}
    if #nodes > 0 and Heading(p, rows, "nodes", format(Tr["Nodes (%d)"], #nodes)) then
        for _, n in ipairs(nodes) do
            table.insert(rows, { label = n[1], icon = p.prof.icon, depth = 1, value = format(Tr["Skill %d"], n[2]),
                color = (ns.GatheringChance(p.prof.rank or 0, n[2])), selected = n[1] == p.node,
                click = function(button)
                    if button == "RightButton" then return end
                    p.chosen, p.trained, p.node = nil, nil, n[1]
                    p.Refresh()
                end })
        end
    end
    p.nodes = nodes
    local unknown = not (MedalUICharDB and MedalUICharDB.recipesUnknownHidden)
    local untrained = not makeable and unknown and Untrained(p, learned) or {}
    if #untrained > 0 and Heading(p, rows, "trainer", format(Tr["At the trainer (%d)"], #untrained)) then
        for _, u in ipairs(untrained) do
            local e = u.entry
            table.insert(rows, { label = Label(e), icon = e.icon, depth = 1,
                value = (e.skill or 0) > 0 and format(Tr["Skill %d"], e.skill) or nil,
                color = u.now and ns.colors.text or ns.colors.dim,
                selected = u.key == p.trained,
                enter = function(row) TrainedTip(row, e) end,
                click = function(button)
                    if button == "RightButton" then return end
                    p.chosen, p.trained, p.node = nil, u.key, nil
                    p.Refresh()
                end })
        end
    end
    p.untrained = untrained
    return rows
end

-- ------------------------------------------------------------- details
-- An item's name; one the game has not loaded yet (none in the bags, not
-- seen this session) is asked for, and the page redraws when it comes
-- (GET_ITEM_INFO_RECEIVED, an event of the page's): "Item <id>" till then.
local function ItemName(id)
    local name = C_Item.GetItemNameByID(id)
    if name then return name end
    if C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
    elseif GetItemInfo then
        GetItemInfo(id)
    end
    return format(Tr["Item %d"], id)
end

-- had / needed, green when the first covers the second
local function Have(have, need)
    return format("%s%d/%d|r", have >= need and "|cff40c040" or "|cffe04040", have, need)
end

-- the required reagents: { id, have, need } each
local function Reagents(recipe)
    local list = {}
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipe, false)
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local r = slot.reagents and slot.reagents[1]
        if r and r.itemID and slot.required ~= false then
            table.insert(list, { id = r.itemID, have = C_Item.GetItemCount(r.itemID),
                need = slot.quantityRequired or 1 })
        end
    end
    return list, schematic
end

-- The strip: the reagents as slots (the icon, had / needed under it, the
-- name under that), an arrow, and what they make (its icon, its name, how
-- many a craft and how many the bags allow). Each slot is SLOT_W wide, all
-- narrowed alike when they and the product do not fit. A slot's tooltip is
-- its item's, and its clicks an item's (ns.ItemClick: Shift links, Ctrl
-- previews); the product's are the recipe row's.
local STRIP_TOP, SLOT_W, SLOT_MIN, SLOT_ICON, MADE_ICON = 43, 64, 38, 34, 40
local COUNT_H, NAME_H, ARROW_W, MADE_TEXT = 14, 26, 34, 130
local MID = MADE_ICON / 2                       -- the icons' middle, from the strip's top
local STRIP_H = MID + SLOT_ICON / 2 + 2 + COUNT_H + NAME_H

local function ItemIcon(id)
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    if not icon and GetItemIcon then icon = GetItemIcon(id) end
    return icon
end

local function IconOf(b, size)
    b.edge = b:CreateTexture(nil, "BORDER")
    b.edge:SetSize(size, size)
    b.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b.edge, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b.edge, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(b.edge)
    glow:SetColorTexture(1, 1, 1, 0.12)
end

local function Slot(strip)
    local b = CreateFrame("Button", nil, strip)
    b:SetSize(SLOT_W, STRIP_H)
    IconOf(b, SLOT_ICON)
    b.edge:SetPoint("TOP", 0, -(MID - SLOT_ICON / 2))
    b.count = ns.PlainText(b, 11)
    b.count:SetPoint("TOP", b.edge, "BOTTOM", 0, -2)
    b.name = ns.PlainText(b, 11)
    b.name:SetPoint("TOPLEFT", 0, -(MID + SLOT_ICON / 2 + 2 + COUNT_H))
    b.name:SetPoint("TOPRIGHT", 0, -(MID + SLOT_ICON / 2 + 2 + COUNT_H))
    b.name:SetHeight(NAME_H)                    -- two lines; more trail off
    b.name:SetJustifyH("CENTER")
    b.name:SetJustifyV("TOP")
    b.name:SetTextColor(unpack(ns.colors.text))
    b:SetScript("OnEnter", function(self)
        if not self.id then return end
        W.Beside(self)
        GameTooltip:SetItemByID(self.id)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button) ns.ItemClick(self.id, button) end)
    return b
end

local function Strip(foot)
    local t = CreateFrame("Frame", nil, foot)
    t:SetPoint("TOPLEFT", 4, -STRIP_TOP)
    t:SetPoint("TOPRIGHT", -4, -STRIP_TOP)
    t:SetHeight(STRIP_H)
    t.slots = {}
    -- the arrow: a shaft and a chevron's two strokes
    t.shaft = t:CreateTexture(nil, "ARTWORK")
    t.shaft:SetHeight(1)
    t.tips = {}
    for i, turn in ipairs({ -1, 1 }) do
        local stroke = t:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(7, 1)
        stroke:SetRotation(turn * math.pi / 4)
        t.tips[i] = stroke
    end
    for _, line in ipairs({ t.shaft, t.tips[1], t.tips[2] }) do
        line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    end
    -- what it makes
    local m = CreateFrame("Button", nil, t)
    m:SetSize(MADE_ICON, MADE_ICON)
    IconOf(m, MADE_ICON)
    m.edge:SetPoint("TOPLEFT")
    m.name = ns.Text(t, 12)
    m.name:SetPoint("TOPLEFT", m, "TOPRIGHT", 7, -1)
    m.name:SetPoint("RIGHT", t, "RIGHT", 0, 0)
    m.name:SetJustifyH("LEFT")
    m.name:SetWordWrap(false)
    m.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    m.makes = ns.PlainText(t, 11)
    m.makes:SetPoint("TOPLEFT", m.name, "BOTTOMLEFT", 0, -2)
    m.makes:SetTextColor(unpack(ns.colors.dim))
    m.can = ns.PlainText(t, 11)
    m.can:SetPoint("TOPLEFT", m.makes, "BOTTOMLEFT", 0, -1)
    m:SetScript("OnEnter", function(self)
        if not self.recipe then return end
        W.Beside(self)
        MadeTip(self.recipe)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:SetScript("OnClick", function(self, button)
        local made = self.recipe and Made(self.recipe)
        if made then
            ns.ItemClick(made, button)
        elseif self.recipe and ns.Linking(button) and C_TradeSkillUI.GetRecipeLink then
            ns.LinkInChat(C_TradeSkillUI.GetRecipeLink(self.recipe))
        end
    end)
    t.made = m
    -- narrowed or widened, laid again
    t:SetScript("OnSizeChanged", function() if t:IsShown() then t.Fit() end end)
    function t.Fit()
        local n = t.n or 0
        -- its edges, not GetWidth: what two points place has its width
        -- from them only once laid out
        local l, r = t:GetLeft(), t:GetRight()
        local room = (l and r and r - l or t:GetWidth() or 0) - ARROW_W - MADE_ICON - 7 - MADE_TEXT
        local w = math.max(SLOT_MIN, math.min(SLOT_W, math.floor(room / math.max(n, 1))))
        for i = 1, n do
            local b = t.slots[i]
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", (i - 1) * w, 0)
            b:SetWidth(w)
        end
        local x = n * w
        t.shaft:ClearAllPoints()
        t.shaft:SetPoint("TOPLEFT", x + 6, -MID)
        t.shaft:SetWidth(ARROW_W - 12)
        for i, stroke in ipairs(t.tips) do
            stroke:ClearAllPoints()
            stroke:SetPoint("CENTER", t, "TOPLEFT", x + ARROW_W - 8, -MID + (i == 1 and 2 or -2))
        end
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", x + ARROW_W, 0)
    end
    t:Hide()
    return t
end

-- the strip for a recipe: its reagents, what it makes, n makeable
local function Lay(t, recipe, info, reagents, schematic, n)
    for i, r in ipairs(reagents) do
        local b = t.slots[i] or Slot(t)
        t.slots[i] = b
        b.id = r.id
        b.icon:SetTexture(ItemIcon(r.id))
        b.count:SetText(Have(r.have, r.need))
        b.name:SetText(ItemName(r.id))
        b:Show()
    end
    for i = #reagents + 1, #t.slots do t.slots[i]:Hide() end
    t.n = #reagents
    local m, made = t.made, schematic and schematic.outputItemID
    m.recipe = recipe
    m.icon:SetTexture(made and ItemIcon(made) or info.icon)
    m.name:SetText(made and ItemName(made) or info.name)
    local least, most = schematic and schematic.quantityMin or 1, schematic and schematic.quantityMax or 1
    m.makes:SetText(least < most and format(Tr["Makes %d\226\128\147%d"], least, most)
        or format(Tr["Makes %d"], math.max(1, most)))
    m.can:SetText(format(Tr["You can make %d"], n))
    m.can:SetTextColor(unpack(n > 0 and ns.colors.dim or { 0.878, 0.251, 0.251 }))
    t:Show()
    t.Fit()
end

-- Smelting's yellow and green, by recipe name (in English; by its id in
-- any language): the skill each turns at
local SMELTING = {
    ["Smelt Copper"] = { 25, 47 }, ["Smelt Tin"] = { 65, 70 }, ["Smelt Bronze"] = { 65, 90 },
    ["Smelt Silver"] = { 115, 122 }, ["Smelt Iron"] = { 130, 145 }, ["Smelt Gold"] = { 170, 177 },
    ["Smelt Steel"] = { 165, 165 }, ["Smelt Mithril"] = { 175, 202 }, ["Smelt Truesilver"] = { 235, 242 },
    ["Smelt Dark Iron"] = { 300, 305 }, ["Smelt Thorium"] = { 250, 270 },
}
for id, name in pairs({ [2657] = "Smelt Copper", [3304] = "Smelt Tin", [2659] = "Smelt Bronze", [2658] = "Smelt Silver",
    [3307] = "Smelt Iron", [3308] = "Smelt Gold", [3569] = "Smelt Steel", [10097] = "Smelt Mithril",
    [10098] = "Smelt Truesilver", [14891] = "Smelt Dark Iron", [16153] = "Smelt Thorium" }) do
    SMELTING[id] = SMELTING[name]
end

-- what a craft is worth: where it greys (or turns yellow, green and grey),
-- its points
local function Worth(info)
    if info.canSkillUp == false or info.relativeDifficulty == 3 then return Tr["No more points"] end
    if not info.maxTrivialLevel or info.maxTrivialLevel <= 0 then return nil end
    local marks = SMELTING[info.name] or SMELTING[info.recipeID]
    local at = marks and format("|cffffff00%d|r/|cff40c040%d|r/|cff808080%d|r", marks[1], marks[2],
        info.maxTrivialLevel) or format(Tr["Grey at %d"], info.maxTrivialLevel)
    local n = info.numSkillUps or 0
    return n > 0 and format(Tr["%s  ·  %d |4point:points; a craft"], at, n) or at
end

-- a service at the trainer: what it asks, and its price
local function Untaught(p)
    for _, u in ipairs(p.untrained or {}) do
        if u.key == p.trained then
            local e, sub = u.entry, { Tr["At the trainer"] }
            if (e.skill or 0) > 0 then table.insert(sub, format(Tr["Skill %d"], e.skill)) end
            if (e.level or 0) > 1 then table.insert(sub, format(Tr["Level %d"], e.level)) end
            if (e.cost or 0) > 0 then table.insert(sub, Money(e.cost)) end
            p.details:Set({ title = Label(e), sub = table.concat(sub, "  ·  "),
                text = u.now and Tr["You can learn it now, at its trainer."]
                    or Tr["Not yet: it needs more skill or level."] })
            return true
        end
    end
    p.trained = nil
end

-- a node: the skill it needs, the chance it gives, where it grows
local function Gathered(p)
    for _, n in ipairs(p.nodes or {}) do
        if n[1] == p.node then
            local _, say = ns.GatheringChance(p.prof.rank or 0, n[2])
            p.details:Set({ title = n[1], sub = format(Tr["Needs %s %d"], p.prof.name, n[2]),
                text = say .. "\n" .. format(Tr["Found in: %s"], n[3]) })
            return true
        end
    end
    p.node = nil
end

local function Details(p)
    p.strip:Hide()
    if p.trained and Untaught(p) then return end
    if p.node and Gathered(p) then return end
    local info = p.chosen and C_TradeSkillUI.GetRecipeInfo(p.chosen)
    if not info then p.details:Set(nil) return end
    local reagents, schematic = Reagents(p.chosen)
    local n = Count(p.chosen)
    local sub = {}
    local cooldown = C_TradeSkillUI.GetRecipeCooldown(p.chosen)
    if cooldown and cooldown > 0 then table.insert(sub, format(Tr["Ready in %s"], SecondsToTime(cooldown))) end
    local worth = Worth(info)
    if worth then table.insert(sub, worth) end
    p.details:Set({ title = info.name, sub = table.concat(sub, "  ·  ") })
    Lay(p.strip, p.chosen, info, reagents, schematic, n)
end

-- ------------------------------------------------------------- the band
-- the most the count can say: as many as the bags can make, one at least
local function Most(p)
    return math.max(1, p.chosen and Ready(p) and Count(p.chosen) or 1)
end

local function SetCount(p, n)
    p.count = math.max(1, math.min(Most(p), math.floor(tonumber(n) or p.count)))
    p.Refresh()
end

-- The count: [- | n | +] joined in one gold-edged frame, n typed (Enter or
-- leaving it takes it, Escape gives the last back), the wheel over any of
-- it a step either way
local STEP, BOX = 24, 40
local function Stepper(p, foot)
    local s = CreateFrame("Frame", nil, foot)
    s:SetSize(2 * STEP + BOX, STEP)
    local fill = s:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.067, 0.059, 0.043, 1)
    local edges = {}
    for i = 1, 6 do
        edges[i] = s:CreateTexture(nil, "BORDER")
        edges[i]:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    -- the hairlines between the cells
    edges[5]:SetPoint("TOPLEFT", STEP, 0); edges[5]:SetPoint("BOTTOMLEFT", STEP, 0); edges[5]:SetWidth(1)
    edges[6]:SetPoint("TOPRIGHT", -STEP, 0); edges[6]:SetPoint("BOTTOMRIGHT", -STEP, 0); edges[6]:SetWidth(1)
    local function Wheel(_, delta) SetCount(p, p.count + (delta > 0 and 1 or -1)) end
    local function Cell(by, label, tip)
        local b = CreateFrame("Button", nil, s)
        b:SetSize(STEP, STEP)
        b.label = ns.Text(b, 14)
        b.label:SetPoint("CENTER", 0, 1)
        b.label:SetText(label)
        b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        local glow = b:CreateTexture(nil, "HIGHLIGHT")
        glow:SetPoint("TOPLEFT", 1, -1)
        glow:SetPoint("BOTTOMRIGHT", -1, 1)
        glow:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function() SetCount(p, p.count + by) end)
        b:SetScript("OnEnter", function(self) ns.Tip(self, W.Beside, { title = tip }) end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", Wheel)
        return b
    end
    p.less = Cell(-1, "\226\136\146", Tr["One fewer."])
    p.less:SetPoint("LEFT")
    p.more = Cell(1, "+", Tr["One more."])
    p.more:SetPoint("RIGHT")
    local box = CreateFrame("EditBox", nil, s)
    box:SetSize(BOX - 2, STEP - 2)
    box:SetPoint("CENTER")
    box:SetFont(ns.font, 13, "")
    box:SetJustifyH("CENTER")
    box:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) SetCount(p, self:GetText()) end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(p.count)
        self:ClearFocus()
    end)
    box:SetScript("OnEnter", function(self) ns.Tip(self, W.Beside, { title = Tr["Type a count, or scroll."] }) end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", Wheel)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", Wheel)
    p.counter = box
    return s
end

local function Craft(p, all)
    if InCombatLockdown() or not p.chosen then return end
    local n = all and Count(p.chosen) or p.count
    if n < 1 or n > Count(p.chosen) then return end
    C_TradeSkillUI.CraftRecipe(p.chosen, n)
end

-- The craft buttons along the foot's bottom, under the details; the band
-- holds Have materials.
local function Band(p, foot, band)
    p.have = ns.character.Tick(band, { label = Tr["Have materials"],
        tip = Tr["Only the recipes the bags hold the reagents for."], at = W.Beside,
        click = function(on)
            C_TradeSkillUI.SetOnlyShowMakeableRecipes(on)
            p.Refresh()
        end })
    p.have:SetPoint("LEFT", 4, 0)
    p.unknown = ns.character.Tick(band, { label = Tr["Show unknown"],
        tip = Tr["The recipes its trainer teaches that you have not learned, at the list's end."], at = W.Beside,
        click = function(on)
            MedalUICharDB = MedalUICharDB or {}
            MedalUICharDB.recipesUnknownHidden = not on or nil
            p.Refresh()
        end })
    p.unknown:SetPoint("LEFT", p.have, "RIGHT", 12, 0)
    p.stepper = Stepper(p, foot)
    p.stepper:SetPoint("BOTTOMLEFT", 4, 2)
    p.create = ns.window.Button(foot, 72, function() Craft(p, false) end,
        function() return InCombatLockdown() and Tr["Not in combat."] or Tr["Make as many as the count says."] end)
    p.create:SetHeight(24)
    p.create.tipAt = W.Beside
    p.create.label:SetText(Tr["Create"])
    p.create:SetPoint("LEFT", p.stepper, "RIGHT", 10, 0)
    p.createAll = ns.window.Button(foot, 88, function() Craft(p, true) end,
        function() return InCombatLockdown() and Tr["Not in combat."] or Tr["Make as many as the bags can."] end)
    p.createAll:SetHeight(24)
    p.createAll.tipAt = W.Beside
    p.createAll.label:SetText(Tr["Create all"])
    p.createAll:SetPoint("LEFT", p.create, "RIGHT", 4, 0)
end

-- ------------------------------------------------------------------ page
-- the profession's banner: name, next rank, skill
local function Banner(p)
    local b, prof = p.banner, p.prof
    if not prof then return end
    local text = prof.modifier and prof.modifier > 0
        and format("%d (+%d) / %d", prof.rank, prof.modifier, prof.max) or format("%d / %d", prof.rank, prof.max)
    b.bar:Fill({ min = 0, max = prof.max, cur = prof.rank, text = text })
    local line, color = W.RankLine(prof)
    b.rank:SetText(line or Tr["Highest rank this expansion"])
    b.rank:SetTextColor(unpack(line and color or ns.colors.dim))
end

local function Refresh(p)
    Banner(p)
    -- the bags may now make fewer than the count says
    if Ready(p) then p.count = math.min(p.count, Most(p)) end
    if not p.counter:HasFocus() then p.counter:SetText(p.count) end
    if asked and W.Skill() == asked then asked = nil end      -- it came
    if not Ready(p) then
        -- chosen while another profession was opening: open it now
        if W.window:IsShown() and W.Current() == p then p.Open() end
        p.list.empty:SetText(InCombatLockdown() and Tr["Opens out of combat."] or Tr["Opening…"])
        p.list:Set({})
        p.details:Set(nil)
        p.create:SetAlpha(0.4)
        p.createAll:SetAlpha(0.4)
        p.createAll.label:SetText(Tr["Create all"])
        return
    end
    p.list.empty:SetText(Tr["No recipes."])
    p.list:Set(Rows(p))
    Details(p)
    local makeable = C_TradeSkillUI.GetOnlyShowMakeableRecipes()
    p.have:Set(makeable, true)
    -- Have materials leaves the unknown out whatever this says
    p.unknown:Set(not (MedalUICharDB and MedalUICharDB.recipesUnknownHidden), not makeable)
    local can = not InCombatLockdown() and p.chosen and Count(p.chosen) > 0
    p.create:SetAlpha(can and p.count <= Count(p.chosen) and 1 or 0.4)
    p.createAll:SetAlpha(can and 1 or 0.4)
    -- how many Create all makes, the button as wide as it says
    local all = p.chosen and Count(p.chosen) or 0
    p.createAll.label:SetText(all > 0 and format(Tr["Create all (%d)"], all) or Tr["Create all"])
    p.createAll:SetWidth(math.max(88, math.ceil(p.createAll.label:GetStringWidth()) + 24))
end

for i = 1, SLOTS do
    local p = { key = "craft" .. i, order = i, label = "", frame = "ProfessionsFrame" }
    p.folded, p.count = {}, 1
    p.flex, p.height, p.bandUsed, p.under = true, 0, true, W.UNDER
    p.events = { "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_SHOW",
        "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "TRAINER_UPDATE", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED" }
    -- the i-th profession that crafts
    function p.Available()
        local n = 0
        for _, prof in ipairs(W.Learned()) do
            if prof.crafts then
                n = n + 1
                if n == i then
                    if p.skillLine ~= prof.skillLine then p.chosen, p.trained, p.node, p.folded = nil, nil, nil, {} end
                    p.label, p.icon, p.skillLine, p.prof = prof.name, prof.icon, prof.skillLine, prof
                    -- the pages' list opens it by casting this, securely
                    -- (OpenTradeSkill is the game's to call: window/shell.lua)
                    p.cast = prof.spell
                    p.row = not prof.primary and 2 or nil       -- the secondaries' tabs: a row of their own
                    return true
                end
            end
        end
        p.skillLine = nil
        return false
    end
    -- One open at a time. While one is on its way the game says no
    -- profession is open; opening this one again then is taken as closing
    -- it, and Blizzard's frame, standing on its crafting page, closes with
    -- it. A tab chosen meanwhile opens when the first has come (Refresh).
    function p.Open()
        if not p.skillLine or InCombatLockdown() or C_TradeSkillUI.IsDataSourceChanging() then return end
        local skill = W.Skill()
        if skill == p.skillLine then return end
        if asked and asked ~= skill and GetTime() - askedAt < WAIT then return end
        asked, askedAt = p.skillLine, GetTime()
        C_TradeSkillUI.OpenTradeSkill(p.skillLine)
    end
    function p.Build(body, foot, band)
        local banner = CreateFrame("Frame", nil, p.panel)
        banner:SetAllPoints()
        banner.bar = ns.character.Bar(banner, BANNER_BAR, 16, true)
        banner.bar:SetPoint("TOP", 0, -7)
        banner.rank = ns.Text(banner, 12)
        banner.rank:SetPoint("TOP", banner.bar, "BOTTOM", 0, -5)
        -- the bar at its width, narrower in a narrow window
        banner:SetScript("OnSizeChanged", function(_, w)
            banner.bar:SetWidth(math.max(80, math.min(BANNER_BAR, (w or 0) - 2 * BAR_MARGIN)))
        end)
        p.banner = banner
        local search = CreateFrame("EditBox", "MedalUIProfessionsSearch" .. i, body, "SearchBoxTemplate")
        search:SetHeight(20)
        search:SetPoint("TOPLEFT", 6, 0)
        search:SetPoint("TOPRIGHT", -2, 0)
        search:SetAutoFocus(false)
        search:HookScript("OnTextChanged", function(self)
            local text = self:GetText()
            if Ready(p) then
                C_TradeSkillUI.SetRecipeItemNameFilter(text ~= "" and text or nil)
                p.Refresh()
            end
        end)
        p.search = search
        local holder = CreateFrame("Frame", nil, body)
        holder:SetPoint("TOPLEFT", 0, -HEAD)
        holder:SetPoint("TOPRIGHT", 0, -HEAD)
        p.holder = holder
        p.list = ns.character.List(holder, Tr["No recipes."])
        p.details = ns.character.Details(foot, nil, Tr["Choose a recipe to read it."], 4)
        p.strip = Strip(foot)
        -- the details, the strip, and the craft buttons' row
        p.footHeight = math.max(p.details.height, STRIP_TOP + STRIP_H) + 6 + 24 + 2
        Band(p, foot, band)
    end
    function p.Fit(height) p.holder:SetHeight(height - HEAD) end
    function p.Refresh() Refresh(p) end
    W.Page(p)
end
