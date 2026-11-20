-- The talents: Medalluin's own (the shell is window/shell.lua), standing on
-- the right strip as the spellbook does, its margin beside the backpack's
-- medallion. Forever only: its talents are one tree of three groups, the
-- old trees, drawn by Blizzard side by side; retail's keep Blizzard's.
--
--   [tree][tree][tree]                                          [x]
--   ---------------------------------------------------------------
--   +---------------------------------------------------------------+
--   |    Elemental      |    12  points    |     Next in plan      |
--   | 5 points in tree  |        left      |   Concussion 2/5      |
--   |-------------------+------------------+-----------------------|
--   |      Reset        |      Follow      |        Apply          |
--   +---------------------------------------------------------------+
--        [o]     [o]                (a tree's talents, where the
--         |                          tree puts them, with the
--        [o] 2/5 [o]     [o]         lines between them)
--   ...
--   ---------------------------------------------------------------
--   the chosen talent's name, rank and what each rank gives; in the
--   plan's mode, [Exit plan] [Checkpoint] [Save plan]         [name]
--        and a hint: why a click was refused, or what comes next
--   ---------------------------------------------------------------
--   (backpack)   [Primary] [Secondary] | [Plans] [Activate]
--
-- Behind the tree, its ground (Ground): a faint cloudy wash in the colour
-- of the tree's role (damage ember, tank blue, healer green), its edges
-- shaded. In the plan's mode the clouds give way to a faint blue drafting
-- grid (a cell an icon wide), the console's row is the mode's own: Exit
-- plan, Checkpoint, Save plan (its name asked for in the console), the
-- foot reads the chosen talent with the hint under it, and only the
-- talent being drafted glows.
--
-- Over the tree, the console (Console): one plate the window's width under
-- its tabs, three readouts parted by hairlines (the tree and its points;
-- the points left, large, or in the plan's mode the points planned; the
-- status: points chosen and not applied, else the plan's next, or in the
-- mode the plan's name), and under them the controls joined across, each
-- a third: Reset, Follow, Apply, dimmed while they cannot be used. The
-- inspect window's talents wear the plate without the controls: the tree,
-- their points, their trees' split.
--
-- A tab per tree, the game's own icons. A click spends a rank, a right-click
-- takes one back: both only staged, until Apply commits them (Reset
-- forgets them). A talent's tooltip and the details say what each rank
-- gives: "by 33% / 66% / 100%", the rank it is at in green. In the plan's
-- mode the foot is the plan's controls instead, and it never folds. The
-- margin views the Primary or the Secondary talents; the one not in use
-- reads only, and Activate switches to it (a cast).
--
-- A plan: the order to learn talents in, as checkpoints, one talent and
-- the ranks it takes each. Plans are named, several for each
-- specialisation, one of them active (MedalluinCharDB.talentPlans
-- [specGroup] = { active, list = { { name, steps } } }, steps the node IDs,
-- a rank an entry). Create Plan, on the plans' page, turns the plan's mode
-- on over a tree, the tree's ground blue: a
-- simulation from nothing, the talents learned left out. A click adds a
-- point, a right-click takes the talent's last off (and whatever after it
-- no longer follows). The points clicked since the last Checkpoint are its
-- draft, of one talent only: Checkpoint keeps them as a step, and another
-- talent waits for it. Save plan names the plan and keeps it (a name
-- already kept is replaced), the plan saved becoming the active one;
-- nothing is kept before, so leaving the mode, the window or the
-- specialisation unsaved loses it. The game will not judge a plan, so the
-- rules are ours: a tier's points in its tree (the node's condition, or 5
-- a tier), the talent before it planned to its last rank, a talent's
-- ranks, and the points a character ever has (the top level less 9). Out
-- of the mode, the active plan's talents not learned glow, the next the
-- brightest; Follow stages its next entries, as many as the points left,
-- for Apply to learn. Plans, in the margin, lists the plans kept, each
-- under a head that folds it (Use makes one active), with its checkpoints
-- (the levels each comes at, the learned ticked, the active one's next
-- marked; a click opens its talent); its foot has Create Plan, Edit (the
-- active plan drawn again, from its last checkpoint), Remove and Import: a
-- build from Wowhead's talent calculator, its link or WHML pasted
-- (spells/wowhead.lua), opened in the plan's mode as a plan to look over
-- and save, the points the rules refuse left out and counted.
--
-- The talents glow, softly: one with points allocated and not yet applied
-- (staged; in the plan's mode, the draft's) pulses, green, or blue when
-- the points allocated fill it, and flashes as a point goes in; one whose
-- points are learned (planned, in the mode) keeps a still aura, green, or
-- blue when it is full. A maxed one has a line inside its edge and a sheen
-- across it; a lit line has a soft gold halo under it. A point staged or
-- planned plays the game's spend sound, one taken back its refund sound;
-- Apply plays the game's apply sound, and its complete sound when the
-- talents are learned, each talent that rose flashing.
--
-- Nothing here is secure: the window opens and reads in combat, where the
-- game refuses every change, so they wait for its end.
--
-- Blizzard's talents are a tab of PlayerSpellsFrame, which the spellbook
-- shares: this window shows while the frame is open on it (spells/frame.lua).
local _, ns = ...
local Tr = ns.L

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local LIT = { 0.4, 0.85, 0.35 }         -- ranks still to spend where they can be
local BRIGHT = { 1, 0.97, 0.85 }        -- a maxed talent's inner line
-- the effects (art/talents/gen_talents.py)
local GLOW, SHEEN, BEAM = ns.media .. "talents\\glow", ns.media .. "talents\\sheen", ns.media .. "talents\\beam"
-- The glow is full round the icon's square, then fades out beyond it; at
-- AURA icons wide, half an icon past each edge. Subtle: an aura, not a
-- lamp.
local AURA = 2                          -- a glow's size, in icons
local BLUE = { 0.4, 0.7, 1 }            -- a talent's glow when its points fill it
local PULSE = { 0.55, 0.2, 1.6 }        -- staged: its alpha, how far it swings, a beat's seconds
local STILL = 0.4                       -- learned: the aura's alpha
local HALO_ALPHA, HALO = 0.45, 10       -- a lit line's halo, its thickness
local FLASH, FLASH_ALPHA = 0.4, 0.95    -- a point spent: seconds the flash fades over, and its start
-- the game's own talent sounds (Blizzard_ClassTalentButtonTemplates.lua,
-- Blizzard_ClassTalentsFrame.lua)
local SOUNDS = { spend = "UI_CLASS_TALENT_NODE_SPEND", refund = "UI_CLASS_TALENT_NODE_REFUND",
    apply = "UI_CLASS_TALENT_APPLY_CHANGES", complete = "UI_CLASS_TALENT_APPLY_COMPLETE" }
local function Sound(which)
    local kit = SOUNDKIT and SOUNDKIT[SOUNDS[which]]
    if kit and PlaySound then PlaySound(kit) end
end
local committing                        -- Apply pressed: the next config update is its landing
local TREES = 3
local ICON, MARGIN = 36, 10             -- a talent's icon, the room round the tree
local STRIP = 26                        -- a row of controls: the points' over the tree, the plan's under it
local READOUTS, CONTROLS = 84, 34       -- the console's readouts, and its row of controls under them
local CONSOLE = READOUTS + CONTROLS     -- the console over the tree
local LIFT = 4                          -- the console raised to meet the tabs (the page starts under a gap)
local HEAD = CONSOLE - LIFT + 16        -- what stands over the tree (a page may say its own: p.over)
local FOOT = 6 + STRIP + 6 + 2 * 15     -- the plan's row and two lines of hint under it
local PLAN_ROW = 8 + 1 + 6 + 15         -- out of the plan's mode: a gap, a rule, a gap, the plan's line

local W = ns.Window{
    name = "MedalluinTalents", named = Tr["Talents"], side = 1,
    closeTip = Tr["Close the talents."],
    Close = function() HideUIPanel(PlayerSpellsFrame) end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.talents = W

local view                              -- the spec group in view (1 Primary, 2 Secondary)

-- ------------------------------------------------------------- the tree
local function Active() return C_SpecializationInfo.GetActiveSpecGroup() end
local function Viewed() return view or Active() end
local function Config() return C_SpecializationInfo.GetCombatConfigIDForSpecGroup(Viewed()) end
-- the talents in view can change now: the ones in use, out of combat
local function Editable() return Viewed() == Active() and not InCombatLockdown() end

local function Tree(config)
    local info = config and C_Traits.GetConfigInfo(config)
    return info and info.treeIDs and info.treeIDs[1]
end

-- the three trees, in their order (the talents in view, or config's: an
-- inspection's, inspect/talents.lua)
local function Groups(config)
    local tree = Tree(config or Config())
    if not tree then return {} end
    local list = {}
    for _, g in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(tree) or {}) do table.insert(list, g) end
    table.sort(list, function(a, b) return a.orderIndex < b.orderIndex end)
    return list
end

-- points spent in each tree, by group ID
local function Spent(config, groups)
    local ids, out = {}, {}
    for _, g in ipairs(groups) do table.insert(ids, g.groupID) end
    for _, info in ipairs(config and C_Traits.GetGroupCurrencyInfo(config, ids) or {}) do
        local c = info.currencyInfos and info.currencyInfos[1]
        out[info.traitNodeGroupID] = c and c.spent or 0
    end
    return out
end

local function Left(config)
    local tree = Tree(config)
    local c = tree and C_Traits.GetTreeCurrencyInfo(config, tree, false)
    return c and c[1] and c[1].quantity or 0
end

local function InGroup(node, id)
    for _, g in ipairs(node.groupIDs or {}) do
        if g == id then return true end
    end
    return false
end

-- a talent's entry, spell, name and icon
local function Entry(config, node)
    local entry = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
    local e = entry and C_Traits.GetEntryInfo(config, entry)
    local def = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
    local spell = def and (def.overriddenSpellID or def.spellID)
    local name = def and def.overrideName ~= "" and def.overrideName or (spell and C_Spell.GetSpellName(spell)) or "?"
    local icon = def and def.overrideIcon and def.overrideIcon ~= 0 and def.overrideIcon
        or (spell and C_Spell.GetSpellTexture(spell))
    return { entry = entry, spell = spell, name = name, icon = icon }
end

-- what keeps a talent locked, if anything does
local function Lock(node)
    if node.ranksPurchased >= node.maxRanks then return nil end
    if not node.meetsEdgeRequirements then return Tr["Needs the talent before it."] end
    if not node.isAvailable then return Tr["Needs more points in this tree."] end
    return nil
end

-- ------------------------------------------------------------- the plan
local planning                          -- the plan's mode: clicks plan instead of staging
-- the plan being drawn in the mode, kept nowhere until saved: its
-- checkpoints' ranks, the draft (one talent's ranks since the last), and
-- the name it was saved or opened under
local sim

-- the plans kept for the talents in view; the one unnamed plan of before
-- (MedalluinCharDB.talentPlan) becomes the first, "Plan", and active
local function Book()
    MedalluinCharDB = MedalluinCharDB or {}
    if type(MedalluinCharDB.talentPlans) ~= "table" then MedalluinCharDB.talentPlans = {} end
    local all, spec = MedalluinCharDB.talentPlans, Viewed()
    if type(all[spec]) ~= "table" then
        all[spec] = { list = {} }
        local old = type(MedalluinCharDB.talentPlan) == "table" and MedalluinCharDB.talentPlan[spec]
        if type(old) == "table" and #old > 0 then
            all[spec].list[1], all[spec].active = { name = Tr["Plan"], steps = old }, 1
        end
        if type(MedalluinCharDB.talentPlan) == "table" then MedalluinCharDB.talentPlan[spec] = nil end
    end
    return all[spec]
end
-- the active plan, and its ranks in order (none: an empty list)
local function Chosen()
    local b = Book()
    return b.active and b.list[b.active]
end
local function Plan()
    local plan = Chosen()
    return plan and plan.steps or {}
end
local function Copy(list)
    local out = {}
    for k, v in ipairs(list) do out[k] = v end
    return out
end

-- the points a character ever has: one a level from 10
local function Cap() return (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60) - 9 end

-- The trees as the plan reads them: each talent's tree, its tier (its
-- height over its tree's first, in the steps the trees are drawn in), the
-- points its tree needs first, and the talents that lead to it.
local function Model(config)
    local groups = Groups(config)
    local tree = Tree(config)
    local m = {}
    for _, id in ipairs(tree and C_Traits.GetTreeNodes(tree) or {}) do
        local node = C_Traits.GetNodeInfo(config, id)
        if node and node.isVisible then
            for _, g in ipairs(groups) do
                if not m[id] and InGroup(node, g.groupID) then
                    m[id] = { node = node, group = g.groupID, sources = {} }
                end
            end
        end
    end
    local top, heights = {}, {}
    for _, t in pairs(m) do
        top[t.group] = math.min(top[t.group] or math.huge, t.node.posY)
        heights[t.node.posY] = true
    end
    local list, step = {}, nil
    for y in pairs(heights) do table.insert(list, y) end
    table.sort(list)
    for k = 2, #list do step = math.min(step or math.huge, list[k] - list[k - 1]) end
    for id, t in pairs(m) do
        t.tier = step and math.floor((t.node.posY - top[t.group]) / step + 0.5) or 0
        local need
        for _, cond in ipairs(t.node.conditionIDs or {}) do
            local c = C_Traits.GetConditionInfo and C_Traits.GetConditionInfo(config, cond)
            if c and c.spentAmountRequired and c.spentAmountRequired > 0 then
                need = math.max(need or 0, c.spentAmountRequired)
            end
        end
        t.need = need or 5 * t.tier
        for _, out in ipairs(t.node.visibleEdges or {}) do
            if m[out.targetNode] then table.insert(m[out.targetNode].sources, id) end
        end
    end
    return m
end

-- why one more rank of a talent cannot follow the plan so far; nil: it can
local function Refuse(m, s, id)
    local t = m[id]
    if not t then return Tr["Not in these trees."] end
    if (s.counts[id] or 0) >= t.node.maxRanks then return Tr["Every rank is planned."] end
    if #s.kept >= Cap() then return format(Tr["All %d points are planned."], Cap()) end
    if (s.spent[t.group] or 0) < t.need then return format(Tr["Needs %d points in this tree first."], t.need) end
    for _, from in ipairs(t.sources) do
        if (s.counts[from] or 0) < m[from].node.maxRanks then return Tr["Needs the talent before it."] end
    end
end

-- a rank added to a walk
local function Push(m, s, id)
    table.insert(s.kept, id)
    s.counts[id] = (s.counts[id] or 0) + 1
    s.spent[m[id].group] = (s.spent[m[id].group] or 0) + 1
end

-- the plan walked: each entry kept while it can follow those before it
local function Walk(m, plan)
    local s = { kept = {}, counts = {}, spent = {} }
    for _, id in ipairs(plan) do
        if not Refuse(m, s, id) then Push(m, s, id) end
    end
    return s
end

-- the plan being drawn: its checkpoints' ranks, then the draft's
local function Drawn()
    local list = Copy(sim.steps)
    for _ = 1, sim.draft and sim.draft.n or 0 do table.insert(list, sim.draft.id) end
    return list
end

-- why a point cannot be added to the plan being drawn: the draft holds
-- another talent, or the rules refuse it
local function Why(m, s, id)
    local d = sim and sim.draft
    if d and d.id ~= id and m[d.id] then
        return format(Tr["Checkpoint %s first."], Entry(Config(), m[d.id].node).name)
    end
    return Refuse(m, s, id)
end

-- the first entry not learned yet: its place (the point it is, at level
-- place + 9), its talent and the rank it brings that talent to
local function Next(m, plan)
    local counts = {}
    for k, id in ipairs(plan) do
        counts[id] = (counts[id] or 0) + 1
        if m[id] and m[id].node.ranksPurchased < counts[id] then return k, id, counts[id] end
    end
end

-- a point added to the draft
local function Add(id)
    local m = Model(Config())
    if Why(m, Walk(m, Drawn()), id) then return end
    sim.draft = { id = id, n = (sim.draft and sim.draft.n or 0) + 1 }
    sim.saved, sim.note = false, nil
    return true
end

-- the talent's last point taken off: from the draft when it is the
-- draft's, else from its last checkpoint, with whatever no longer follows
-- (the draft too, as far as it no longer does)
local function Remove(id)
    local m = Model(Config())
    local steps, d = sim.steps, sim.draft
    local n = d and d.n or 0
    if d and d.id == id then
        n = n - 1
    else
        local list, found = Copy(steps), false
        for k = #list, 1, -1 do
            if list[k] == id then table.remove(list, k); found = true; break end
        end
        if not found then return false end
        steps = Walk(m, list).kept
    end
    local s, kept = Walk(m, steps), 0
    while kept < n and not Refuse(m, s, d.id) do
        Push(m, s, d.id)
        kept = kept + 1
    end
    sim.steps = steps
    sim.draft = kept > 0 and { id = d.id, n = kept } or nil
    sim.saved, sim.note = false, nil
    return true
end

-- the draft kept as a checkpoint
local function Checkpoint()
    local d = sim.draft
    if not d then return end
    for _ = 1, d.n do table.insert(sim.steps, d.id) end
    sim.draft, sim.note = nil, nil
end

-- the plan drawn kept under a name, replacing one of that name, and made
-- the active plan
local function Save(name)
    local b = Book()
    local at
    for k, plan in ipairs(b.list) do
        if plan.name == name then at = k end
    end
    if at then
        b.list[at].steps = Copy(sim.steps)
    else
        table.insert(b.list, { name = name, steps = Copy(sim.steps) })
        at = #b.list
    end
    b.active = at
    sim.name, sim.saved, sim.note = name, true, nil
end

-- the mode on, drawing a plan from nothing or from one kept; off, the
-- plan drawn is forgotten (nothing reads it out of the mode, and the next
-- Begin replaces it). A plan kept is opened at its last checkpoint: that
-- talent's run is the draft again, so going on takes a Checkpoint first;
-- whole (an import), every run is a checkpoint already, to save as it is.
-- note: said in the console's status until the plan drawn changes
local function Begin(steps, name, note, whole)
    planning = true
    sim = { steps = Copy(steps or {}), name = name, saved = name ~= nil, note = note }
    if whole then return end
    local list, id, n = sim.steps, sim.steps[#sim.steps], 0
    while id and list[#list] == id do
        table.remove(list)
        n = n + 1
    end
    if n > 0 then sim.draft = { id = id, n = n } end
end
local function End()
    planning = nil
end

-- ------------------------------------------------------- Wowhead's builds
-- A build from Wowhead's talent calculator (spells/wowhead.lua) as a plan's
-- ranks, for the talents in view: each tree's talents by row then column,
-- as Wowhead counts them (the Talented perk, a node of its own, is none of
-- them). Its order where it has one, else tree by tree, each top down.
-- Returns the ranks and how many of them the rules left out, or nil and
-- why it cannot be read onto these trees.
local TALENTED = 110298                 -- Forever's Talented perk
local function Imported(build)
    local config = Config()
    local _, token = UnitClass("player")
    if build.class ~= token then
        local names = LOCALIZED_CLASS_NAMES_MALE or {}
        return nil, format(Tr["That build is for a %s, not these talents."],
            names[build.class] or build.class:sub(1, 1) .. build.class:sub(2):lower())
    end
    local m = Model(config)
    local trees = {}
    for k, g in ipairs(Groups(config)) do
        local list = {}
        for id, t in pairs(m) do
            if t.group == g.groupID and id ~= TALENTED then table.insert(list, id) end
        end
        table.sort(list, function(a, b)
            local ta, tb = m[a], m[b]
            if ta.tier ~= tb.tier then return ta.tier < tb.tier end
            if ta.node.posX ~= tb.node.posX then return ta.node.posX < tb.node.posX end
            return a < b
        end)
        trees[k] = list
    end
    local misfit = Tr["That build does not fit these trees: Wowhead's may be newer or older."]
    local order = build.order
    if not order then
        order = {}
        for t, ranks in ipairs(build.trees) do
            for i, n in ipairs(ranks) do
                if n > 0 then table.insert(order, { t, i, n }) end
            end
        end
    end
    for t, ranks in ipairs(build.trees) do
        for i, n in ipairs(ranks) do
            local id = n > 0 and (trees[t] or {})[i]
            if n > 0 and not (id and n <= m[id].node.maxRanks) then return nil, misfit end
        end
    end
    local steps = {}
    for _, o in ipairs(order) do
        for _ = 1, o[3] do table.insert(steps, trees[o[1]][o[2]]) end
    end
    local kept = Walk(m, steps).kept
    return kept, #steps - #kept
end

-- Follow: the plan's next entries staged while points are left, stopping
-- at the first the game refuses
local function Follow()
    local config = Config()
    if not (config and Editable()) then return end
    local any = false
    for _ = 1, Cap() do
        if Left(config) <= 0 then break end
        local _, id = Next(Model(config), Plan())
        if not id or not C_Traits.PurchaseRank(config, id) then break end
        any = true
    end
    if any then Sound("spend") end
end

-- ------------------------------------------------------------ the ranks
-- What a talent gives at a rank: the description its tooltip writes for
-- that rank, before the next rank's. Nil when the game cannot say.
local NUMBER = "%d+%.?%d*"
local function AtRank(entry, rank)
    local data = entry and C_TooltipInfo and C_TooltipInfo.GetTraitEntry
        and C_TooltipInfo.GetTraitEntry(entry, rank)
    local DESCRIPTION = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SpellDescription
    local next1 = TOOLTIP_TALENT_NEXT_RANK and TOOLTIP_TALENT_NEXT_RANK:gsub("%%s", "")
    local best
    for i, line in ipairs(data and data.lines or {}) do
        local text = type(line.leftText) == "string" and line.leftText or ""
        if (next1 and next1 ~= "" and text:find(next1, 1, true))
            or (NEXT_RANK_COLON and text == NEXT_RANK_COLON) then break end
        if i > 1 and DESCRIPTION and line.type == DESCRIPTION then return text end
        if i > 1 and (not best or #text > #best) then best = text end
    end
    return best ~= "" and best or nil
end

-- a number as a description writes it, without a sentence's full stop
local function Number(n)
    local bare = n:gsub("%.$", "")
    return bare, n:sub(#bare + 1)
end

-- Each rank's description as one: where the ranks differ only in their
-- numbers, the numbers side by side ("by 33% / 66% / 100%"), the rank at
-- in green; otherwise a line per rank.
local function Ranks(texts, at)
    if #texts < 2 then return texts[1] end
    local shape, numbers = texts[1]:gsub(NUMBER, "#"), {}
    for r, t in ipairs(texts) do
        if t:gsub(NUMBER, "#") ~= shape then
            local lines = {}
            for i, line in ipairs(texts) do
                local c = i == at and "|cff66d959" or "|cffb3a88c"
                table.insert(lines, c .. format(Tr["Rank %d:"], i) .. "|r " .. line)
            end
            return table.concat(lines, "\n")
        end
        numbers[r] = {}
        for n in t:gmatch(NUMBER) do table.insert(numbers[r], (Number(n))) end
    end
    local k = 0
    return (texts[1]:gsub(NUMBER, function(n)
        k = k + 1
        local _, stop = Number(n)
        local list, same = {}, true
        for r = 1, #texts do
            list[r] = numbers[r][k]
            same = same and list[r] == list[1]
        end
        if same then return n end
        if list[at] then list[at] = "|cff66d959" .. list[at] .. "|r" end
        return table.concat(list, " / ") .. stop
    end))
end

-- a talent's description, every rank's, or its spell's when the game
-- cannot say one rank's
local function Describe(n)
    local node, texts = n.node, {}
    for r = 1, node.maxRanks do
        local t = AtRank(n.talent.entry, r)
        if not t then texts = {}; break end
        texts[r] = t
    end
    return Ranks(texts, node.ranksPurchased)
        or (n.talent.spell and C_Spell.GetSpellDescription(n.talent.spell)) or ""
end

-- --------------------------------------------------------------- talents
-- The talent's own name over its rank and every rank's description: the
-- game's own tooltip for a talent heads it with "Passive".
local function Tooltip(owner, n)
    local text, lock = Describe(n), Lock(n.node)
    local plan = planning and not n.readonly and n.planned
    ns.Tip(owner, ns.window.Outside, { title = n.talent.name, color = GOLD,
        { "body", format(Tr["Rank %d/%d"], n.node.ranksPurchased, n.node.maxRanks)
            .. (plan and format(Tr["  ·  Planned %d/%d"], n.planned, n.node.maxRanks) or ""), ns.colors.dim },
        text ~= "" and { "body", text } or false,
        plan and n.refusal and { "warn", n.refusal } or not plan and not n.readonly and lock and { "warn", lock }
            or false })
end

local function Click(p, b, button)
    if ns.Linking(button) then
        ns.LinkInChat(ns.SpellLink(Entry(p.config or Config(), b.node).spell))
        return
    end
    -- someone else's talents (p.readonly): a click only chooses, to read it
    if p.readonly then
        p.chosen = b.node.ID
        p.Refresh()
        return
    end
    p.chosen = b.node.ID
    local back = button == "RightButton"
    local done
    if planning then
        if back then done = Remove(b.node.ID) else done = Add(b.node.ID) end
    elseif Editable() then
        if back then
            done = C_Traits.RefundRank(Config(), b.node.ID)
        else
            done = C_Traits.PurchaseRank(Config(), b.node.ID)
        end
    end
    if done then
        Sound(back and "refund" or "spend")
        if not back then p.Flash(b) end
    end
    p.Refresh()
end

local function Node(p, i)
    local b = CreateFrame("Button", nil, p.body)
    b:SetSize(ICON, ICON)
    b:SetFrameLevel(p.body:GetFrameLevel() + 2)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- planned and not learned: a gold ring round the edge, the next the brightest
    b.halo = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.halo:SetPoint("TOPLEFT", -5, 5)
    b.halo:SetPoint("BOTTOMRIGHT", 5, -5)
    b.halo:Hide()
    -- can take a point: a soft green glow, pulsing (Pulse); maxed: gold, still
    -- (over the plan's ring, which would hide its brightest part; additive,
    -- so the ring still shows through it)
    b.aura = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.aura:SetTexture(GLOW)
    b.aura:SetBlendMode("ADD")
    b.aura:SetSize(ICON * AURA, ICON * AURA)
    b.aura:SetPoint("CENTER")
    b.aura:Hide()
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetPoint("TOPLEFT", -2, 2)
    b.edge:SetPoint("BOTTOMRIGHT", 2, -2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- maxed: a sheen across the icon, a bright line inside its edge
    b.sheen = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.sheen:SetTexture(SHEEN)
    b.sheen:SetBlendMode("ADD")
    b.sheen:SetAllPoints()
    b.sheen:SetVertexColor(1, 0.95, 0.8, 0.4)
    b.sheen:Hide()
    b.inner = {}
    for k, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = b:CreateTexture(nil, "ARTWORK", nil, 2)
        t:SetColorTexture(BRIGHT[1], BRIGHT[2], BRIGHT[3], 0.9)
        -- a pixel in from the icon's edge, so a sliver of the icon parts it
        -- from the gold edge
        local dx, dy = side[1]:find("LEFT") and 1 or -1, side[1]:find("TOP") and -1 or 1
        local ex, ey = side[2]:find("LEFT") and 1 or -1, side[2]:find("TOP") and -1 or 1
        t:SetPoint(side[1], dx, dy)
        t:SetPoint(side[2], ex, ey)
        if k <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        t:Hide()
        b.inner[k] = t
    end
    b.well = b:CreateTexture(nil, "OVERLAY")
    b.well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.9)
    b.rank = ns.Text(b, 11)
    b.rank:SetPoint("BOTTOMRIGHT", 3, -3)
    b.well:SetPoint("TOPLEFT", b.rank, -2, 1)
    b.well:SetPoint("BOTTOMRIGHT", b.rank, 2, -1)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.15)
    b.readonly = p.readonly
    b:SetScript("OnClick", function(self, button) Click(p, self, button) end)
    b:SetScript("OnEnter", function(self) Tooltip(self, self) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.nodes[i] = b
    return b
end

local function Edge(p, i)
    -- lit: a soft gold halo under it
    local halo = p.body:CreateLine(nil, "BACKGROUND", nil, -1)
    halo:SetThickness(HALO)
    halo:SetTexture(BEAM)
    halo:SetBlendMode("ADD")
    p.halos[i] = halo
    local l = p.body:CreateLine(nil, "BACKGROUND")
    l:SetThickness(2)
    p.edges[i] = l
    return l
end

-- A tree's talents where the tree puts them, under the points' row. One
-- scale for the three, the largest filling the page, so a tier stands at
-- one height on every tab; each tree centred across the page, from its top.
-- A tree is every talent in its group, wherever the group stands among the
-- talent's groups.
-- plan: the plan walked (planning or not), its model and its next talent
local function Draw(p, config, group, groups, plan)
    local span = { x = 0, y = 0 }
    local box, list = {}, {}
    for _, id in ipairs(C_Traits.GetTreeNodes(Tree(config)) or {}) do
        local node = C_Traits.GetNodeInfo(config, id)
        if node and node.isVisible then
            for _, g in ipairs(groups) do
                if InGroup(node, g.groupID) then
                    local b = box[g.groupID] or { x0 = math.huge, x1 = -math.huge, y0 = math.huge, y1 = -math.huge }
                    b.x0, b.x1 = math.min(b.x0, node.posX), math.max(b.x1, node.posX)
                    b.y0, b.y1 = math.min(b.y0, node.posY), math.max(b.y1, node.posY)
                    box[g.groupID] = b
                    span.x, span.y = math.max(span.x, b.x1 - b.x0), math.max(span.y, b.y1 - b.y0)
                end
            end
            if InGroup(node, group.groupID) then table.insert(list, node) end
        end
    end
    local width = W.width - 2 * MARGIN - ICON
    local head = p.over or HEAD
    local height = (p.body:GetHeight() or 0) - head - 2 * MARGIN - ICON
    local scale = math.min(span.x > 0 and width / span.x or 1, span.y > 0 and height / span.y or 1)
    local own = box[group.groupID] or { x0 = 0, x1 = 0, y0 = 0 }
    local x0, y0 = own.x0, own.y0
    local left = MARGIN + ICON / 2 + (width - (own.x1 - own.x0) * scale) / 2
    local at, byID = {}, {}
    local editable = not p.readonly and Editable()
    -- the plan's mode is the player's talents' only
    local drawing = planning and not p.readonly
    for i, node in ipairs(list) do
        local b = p.nodes[i] or Node(p, i)
        b.node, b.talent = node, Entry(config, node)
        byID[node.ID] = b
        b:ClearAllPoints()
        b:SetPoint("CENTER", p.body, "TOPLEFT", left + (node.posX - x0) * scale,
            -(head + MARGIN + ICON / 2 + (node.posY - y0) * scale))
        b.icon:SetTexture(b.talent.icon)
        b.planned = plan.counts[node.ID] or 0
        b.refusal = not p.readonly and Why(plan.model, plan, node.ID) or nil
        -- planning: the ranks planned, and whether one more can be;
        -- otherwise the ranks learned, and whether one more can be staged
        local ranks = drawing and b.planned or node.ranksPurchased
        local maxed = ranks >= node.maxRanks
        local open
        if drawing then
            open = ranks > 0 or not b.refusal
        else
            open = maxed or ranks > 0 or (node.isAvailable and node.meetsEdgeRequirements)
        end
        b.icon:SetDesaturated(not open)
        b.icon:SetAlpha(open and 1 or 0.5)
        local can = drawing and not b.refusal or not drawing and open and editable and node.canPurchaseRank
        local edge = maxed and GOLD or can and LIT or GOLD_D
        b.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
        b.rank:SetText(ranks .. "/" .. node.maxRanks)
        local text = maxed and GOLD or ranks > 0 and LIT or ns.colors.dim
        b.rank:SetTextColor(text[1], text[2], text[3])
        local ahead = not drawing and b.planned > node.ranksPurchased
        b.halo:SetShown(ahead)
        b.halo:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], node.ID == plan.next and 0.9 or 0.35)
        -- the glow: green and pulsing while it can take a point, gold and
        -- still when maxed; the maxed shine
        -- the aura: pulsing while points are allocated and not applied
        -- (the draft's, in the mode), still once learned (planned); blue
        -- when the points fill it, else green
        local staged
        if drawing then
            staged = sim.draft and sim.draft.id == node.ID
        else
            local active = node.activeRank
            if type(active) == "number" then staged = node.ranksPurchased > active
            else staged = node.canRefundRank and true or false end
        end
        b.pulse = staged and true or false
        b.glow = maxed and BLUE or LIT
        -- (in the mode, only the draft's: the plan's other talents keep
        -- their gold edges, unlit)
        b.aura:SetShown((drawing and b.pulse or not drawing and ranks > 0) or (b.flashUntil or 0) > 0)
        b.aura:SetVertexColor(b.glow[1], b.glow[2], b.glow[3], b.pulse and PULSE[1] or STILL)
        b.sheen:SetShown(maxed)
        for _, t in ipairs(b.inner) do t:SetShown(maxed) end
        b.learned = node.ranksPurchased
        b:Show()
        at[i] = b
    end
    for i = #list + 1, #p.nodes do p.nodes[i]:Hide(); p.nodes[i].node = nil; p.nodes[i].pulse = false end
    -- the lines, from each talent to the ones it opens
    local e = 0
    for _, b in ipairs(at) do
        for _, out in ipairs(b.node.visibleEdges or {}) do
            local to = byID[out.targetNode]
            if to then
                e = e + 1
                local l = p.edges[e] or Edge(p, e)
                l:SetStartPoint("CENTER", b)
                l:SetEndPoint("CENTER", to)
                local active = out.isActive
                if drawing then active = b.planned >= b.node.maxRanks end
                local c = active and GOLD or GOLD_D
                l:SetColorTexture(c[1], c[2], c[3], active and 1 or 0.6)
                l:Show()
                local halo = p.halos[e]
                halo:SetStartPoint("CENTER", b)
                halo:SetEndPoint("CENTER", to)
                halo:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], HALO_ALPHA)
                halo:SetShown(active and true or false)
            end
        end
    end
    for i = e + 1, #p.edges do p.edges[i]:Hide(); p.halos[i]:Hide() end
    return byID
end

-- ------------------------------------------------------------- the foot
-- the margin: which talents are in view (marked), which in use (gold),
-- Plans marked while the plan's list shows, Activate while another's are
-- in view (off in combat)
local function Band(p)
    local active, groupsLearned = Active(), GetNumSpecGroups and GetNumSpecGroups() or 1
    for i in ipairs(p.specs) do
        p.margin:Set(i, { selected = i == Viewed(), enabled = i <= groupsLearned,
            color = i == active and GOLD or ns.colors.dim })
    end
    p.margin:Set("activate", { shown = Viewed() ~= active, enabled = not InCombatLockdown() })
    p.margin:Set("plans", { selected = p.list and true or false })
end

local Controls                          -- the console's controls laid out (with the console, below)
local function Refresh(p)
    local config = Config()
    local groups = Groups()
    local group = groups[p.tree]
    if not (config and group) then return end
    local m = Model(config)
    local plan = Walk(m, planning and Drawn() or Plan())
    local place, nextID, nextRank = Next(m, plan.kept)
    plan.model, plan.next = m, nextID
    local d = planning and sim.draft
    local byID = Draw(p, config, group, groups, plan)
    -- the foot: the talent chosen, and under it, in the plan's mode, a
    -- hint (why the talent last clicked was refused, else what the
    -- Checkpoint keeps, else what a click does); otherwise the plan's next
    -- step and where the chosen talent stands in the plan
    local chosen = p.chosen and byID[p.chosen]
    if planning then
        local why = chosen and chosen.refusal
        if chosen then
            local node, t = chosen.node, chosen.talent
            p.details:Set({ title = t.name, sub = format(Tr["Planned %d/%d"], plan.counts[node.ID] or 0, node.maxRanks)
                .. (why and ("  ·  " .. why) or ""), text = Describe(chosen) })
        else
            p.details.nothing:SetText(Tr["Choose a talent to read it."])
            p.details:Set(nil)
        end
        p.planLine:SetText(why and format("%s: %s", chosen.talent.name, why)
            or d and format(Tr["Checkpoint keeps %s %d/%d as a step of the plan."],
                Entry(config, m[d.id].node).name, plan.counts[d.id], m[d.id].node.maxRanks)
            or Tr["Click a talent to add a point to the plan; right-click takes its last off."])
    else
        local nextOne = nextID and m[nextID]
        local line = nextOne and format(Tr["Next in your plan: %s %d/%d, at level %d."],
                Entry(config, nextOne.node).name, nextRank, nextOne.node.maxRanks, place + 9)
            or #Plan() == 0 and Tr["No talent plan: make one under Plans."]
            or Tr["Your plan is complete."]
        if chosen then
            local node, t = chosen.node, chosen.talent
            local why = Lock(node)
            p.details:Set({ title = t.name, sub = format(Tr["Rank %d/%d"], node.ranksPurchased, node.maxRanks)
                .. (why and ("  ·  " .. why) or ""), text = Describe(chosen) })
            local planned = plan.counts[node.ID] or 0
            if planned > 0 then
                line = format(Tr["%s   ·   %s: planned %d/%d"], line, t.name, planned, node.maxRanks)
            end
        else
            p.details.nothing:SetText(Tr["Choose a talent to read it."])
            p.details:Set(nil)
        end
        p.planLine:SetText(line)
    end
    -- the console: the points left to spend (or planned), the tree's, and
    -- the status (the tabs' tips say each tree's)
    local spent = Spent(config, groups)
    local staged = not planning and C_Traits.ConfigHasStagedChanges(config) and true or false
    local c = p.console
    c.title:SetText(group.displayName)
    local function State(head, line, lit)
        c.state:SetText(head)
        c.status:SetText(line)
        local color = lit and GOLD or ns.colors.dim
        c.state:SetTextColor(color[1], color[2], color[3])
    end
    if planning then
        c.number:SetText(#plan.kept)
        c.caption:SetText(format(Tr["planned\nof %d"], Cap()))
        c.line:SetText(format(Tr["%d planned in this tree"], plan.spent[group.groupID] or 0))
        State(sim.name or Tr["New plan"], sim.note
            or d and format(Tr["Draft: %s +%d"], Entry(config, m[d.id].node).name, d.n)
            or sim.saved and Tr["Saved"] or Tr["Not saved"], true)
    else
        local left = Left(config)
        c.number:SetText(left)
        c.caption:SetText(ns.Plural(left, Tr["|4point:points;\nleft"]))
        c.line:SetText(format(Tr["%d |4point:points; in this tree"], spent[group.groupID] or 0))
        local nextOne = nextID and m[nextID]
        if staged then
            State(Tr["Points chosen"], Tr["Apply to learn them"], true)
        elseif nextOne then
            State(Tr["Next in plan"], format("%s %d/%d", Entry(config, nextOne.node).name, nextRank,
                nextOne.node.maxRanks))
        elseif #Plan() == 0 then
            State(Tr["No plan"], Tr["Make one under Plans"])
        else
            State(Tr["Plan complete"], "")
        end
    end
    if not planning then p.name:Hide() end
    c.state:SetShown(not p.name:IsShown())
    p.ground.Plan(planning)
    Controls(p, staged, not planning and nextID ~= nil and Editable() and Left(config) > 0, d and true or false,
        planning and #sim.steps > 0 and not d)
    Band(p)
end

-- the window's buttons, soft: the surface under them shows through
local function Button(parent, width, click, tip)
    return ns.window.Button(parent, width, click, tip, nil, true)
end

local SPECS = { Tr["Primary"], Tr["Secondary"] }
-- each, as a sentence names it: "View your primary talents."
local SPEC_WORD = { Tr["primary"], Tr["secondary"] }
local plansPage, back                   -- the plans' page, and the tree it was opened from

-- back to the tree the plans were opened from, or the first
local function Back()
    local to = back and back.available and back
    for _, page in ipairs(W.pages) do
        if not to and page.available and not page.tabless then to = page end
    end
    if to then W.Select(to) end
end

-- The margin, edge to edge: the specialisations, then the plans and
-- Activate past a divider, joined (ns.window.Segments)
local function Margin(p, band)
    local items = {}
    for i, name in ipairs(SPECS) do
        table.insert(items, { key = i, label = name, group = "specs", click = function()
            if i > (GetNumSpecGroups and GetNumSpecGroups() or 1) then return end
            if i ~= Viewed() then End() end
            view = i
            p.chosen = nil
            W.Refresh()
        end, tip = function()
            if i > (GetNumSpecGroups and GetNumSpecGroups() or 1) then
                return format(Tr["Learn a second specialization to use %s talents."], SPEC_WORD[i])
            end
            return format(Tr["View your %s talents."],
                SPEC_WORD[i]) .. (i == Active() and " " .. Tr["They are in use."] or "")
        end })
    end
    -- the plans kept, and back from them to the tree they were opened over
    table.insert(items, { key = "plans", label = Tr["Plans"], group = "plans", click = function()
        if W.Current() == plansPage then Back() else
            back = W.Current()
            W.Select(plansPage)
        end
    end, tip = function()
        return W.Current() == plansPage and Tr["Back to the trees."]
            or Tr["The plans kept, and the order the active one learns in."]
    end })
    table.insert(items, { key = "activate", label = Tr["Activate"], group = "plans", click = function()
        if InCombatLockdown() or Viewed() == Active() then return end
        C_SpecializationInfo.SetActiveSpecGroup(Viewed())
    end, tip = function()
        return InCombatLockdown() and Tr["Not in combat."] or format(Tr["Use your %s talents."], SPEC_WORD[Viewed()])
    end })
    local row = ns.window.Segments(band, { height = band:GetHeight(), items = items })
    row:SetPoint("TOPLEFT")
    row:SetPoint("TOPRIGHT")
    p.margin = row
    p.specs = { row.byKey[1], row.byKey[2] }
    p.plans, p.activate = row.byKey.plans, row.byKey.activate
end

-- the points' row over the tree: [Reset]  points available  [Apply]
-- The console: a plate the window's width (flush with its border, as
-- ns.window.Strip), its top meeting the tabs', gold-edged, a shine along
-- its top; three readouts across, parted by hairlines, the outer two the
-- wider (a tree's name is long: "Elemental Combat"); with controls, a row
-- under them past a gold rule (c.row, the page fills it).
--   c.title, c.line (the first); c.number, c.caption (the second);
--   c.state, c.status (the third); c.row
local FILL = { 0.133, 0.118, 0.086 }
local OFF = { 0.35, 0.33, 0.27 }        -- a control that cannot be used: its word
local function Console(body, controls, slot)
    local c = CreateFrame("Frame", nil, slot or body)
    if slot then
        -- (2026-11-19, /workspace/meld-sheet.png) in the panel the shell
        -- joins under the head: its box the shell's
        c:SetAllPoints(slot)
    else
        local out = ns.window.pad - 1
        c:SetPoint("TOPLEFT", -out, LIFT)
        c:SetPoint("TOPRIGHT", out, LIFT)
        c:SetHeight(controls and CONSOLE or READOUTS)
        local edge = c:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        local fill = c:CreateTexture(nil, "BACKGROUND", nil, 1)
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(FILL[1], FILL[2], FILL[3], 1)
        local shine = c:CreateTexture(nil, "BACKGROUND", nil, 2)
        shine:SetPoint("TOPLEFT", 2, -3)
        shine:SetPoint("TOPRIGHT", -2, -3)
        shine:SetHeight(1)
        shine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.15)
    end
    -- the readouts: three cells across the top, hairlines between
    local cells = {}
    for i = 1, 3 do
        local f = CreateFrame("Frame", nil, c)
        f:SetHeight(READOUTS)
        cells[i] = f
    end
    c.cells = cells
    local SHARE = { 0.37, 0.26, 0.37 }
    function c.Layout()
        local w, x = c:GetWidth() or 0, 0
        for i, f in ipairs(cells) do
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", c, "TOPLEFT", x, 0)
            f:SetWidth(w * SHARE[i])
            x = x + w * SHARE[i]
        end
    end
    c:SetScript("OnSizeChanged", c.Layout)
    c.Layout()
    -- the parting between the readouts: joined, solid gold top to bottom
    -- (the controls' rule under them); alone, a hairline fading at its ends
    c.splits = {}
    for i = 1, 2 do
        local rule
        if slot then
            rule = c:CreateTexture(nil, "BORDER")
            rule:SetWidth(1)
            rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            rule:SetPoint("TOP", cells[i], "TOPRIGHT", 0, 0)
            rule:SetPoint("BOTTOM", cells[i], "BOTTOMRIGHT", 0, 0)
        else
            rule = ns.window.Hair(c, true)
            rule:SetPoint("TOP", cells[i], "TOPRIGHT", 0, -14)
            rule:SetPoint("BOTTOM", cells[i], "BOTTOMRIGHT", 0, 14)
        end
        c.splits[i] = rule
    end
    local function Pair(cell, size, color)
        -- the head over the middle, its line under, a gap between
        local a, b = ns.Text(cell, size), ns.Text(cell, 12)
        a:SetPoint("BOTTOMLEFT", cell, "LEFT", 12, 3)
        a:SetPoint("BOTTOMRIGHT", cell, "RIGHT", -12, 3)
        b:SetPoint("TOPLEFT", cell, "LEFT", 12, -6)
        b:SetPoint("TOPRIGHT", cell, "RIGHT", -12, -6)
        for _, fs in ipairs({ a, b }) do
            fs:SetJustifyH("CENTER")
            fs:SetWordWrap(false)
        end
        a:SetTextColor(color[1], color[2], color[3])
        b:SetTextColor(unpack(ns.colors.dim))
        return a, b
    end
    c.title, c.line = Pair(cells[1], 17, GOLD)
    c.state, c.status = Pair(cells[3], 15, GOLD)
    -- the points: the number large, its word in two lines beside it
    c.number = ns.Text(cells[2], 34)
    c.number:SetPoint("RIGHT", cells[2], "CENTER", 2, 0)
    c.number:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.caption = ns.Text(cells[2], 12)
    c.caption:SetPoint("LEFT", cells[2], "CENTER", 12, 0)
    c.caption:SetJustifyH("LEFT")
    c.caption:SetTextColor(unpack(ns.colors.dim))
    if controls then
        c.row = CreateFrame("Frame", nil, c)
        c.row:SetPoint("BOTTOMLEFT", 0, 0)
        c.row:SetPoint("BOTTOMRIGHT", 0, 0)
        c.row:SetHeight(CONTROLS + 1)
    end
    return c
end
W.Console = Console

-- The tree's ground: a cloudy wash in the colour of the tree's role,
-- faint, its edges shaded darker; under the lines and talents.
--   local g = Ground(body); g.Set(class, tree)   (class: the class's file token)
-- The game tells a tree's name, icon and place, not its role; a class's
-- trees always come in the same order, so the role is by class and place
-- (any language). Feral is a druid's damage or tank tree as they choose:
-- taken as damage. A class not here: the trees by place, damage, tank, healer.
local ROLE_COLOR = { damage = { 0.78, 0.35, 0.24 }, tank = { 0.27, 0.43, 0.78 }, healer = { 0.27, 0.67, 0.35 } }
local ROLES = {
    WARRIOR = { "damage", "damage", "tank" },
    PALADIN = { "healer", "tank", "damage" },
    HUNTER = { "damage", "damage", "damage" },
    ROGUE = { "damage", "damage", "damage" },
    PRIEST = { "healer", "healer", "damage" },
    DEATHKNIGHT = { "tank", "damage", "damage" },
    SHAMAN = { "damage", "damage", "healer" },
    MAGE = { "damage", "damage", "damage" },
    WARLOCK = { "damage", "damage", "damage" },
    DRUID = { "damage", "damage", "healer" },
}
local BY_PLACE = { "damage", "tank", "healer" }
local function Role(class, tree)
    local roles = ROLES[class or ""]
    return roles and roles[tree] or BY_PLACE[tree] or "damage"
end
W.Role = Role
local CLOUDS, SHADE = 0.16, 0.6         -- the wash's strength; the edges' shade
local DRAFT, CELL = { 0.43, 0.63, 0.94, 0.22 }, ICON     -- the plan's grid: its colour, a cell's size
local GRID_CELLS = 4                    -- the grid texture's cells (its major line every fourth)
local function Ground(body)
    local g = {}
    g.clouds = body:CreateTexture(nil, "BACKGROUND", nil, -8)
    g.clouds:SetAllPoints()
    g.clouds:SetTexture(ns.media .. "talents\\clouds")
    -- the plan's mode: a drafting grid, tiled from the top left so a cell
    -- is an icon wide
    g.grid = body:CreateTexture(nil, "BACKGROUND", nil, -8)
    g.grid:SetAllPoints()
    g.grid:SetTexture(ns.media .. "talents\\grid", "REPEAT", "REPEAT")
    g.grid:SetVertexColor(DRAFT[1], DRAFT[2], DRAFT[3], DRAFT[4])
    g.grid:Hide()
    local function Tile()
        local tile = CELL * GRID_CELLS
        g.grid:SetTexCoord(0, (body:GetWidth() or 0) / tile, 0, (body:GetHeight() or 0) / tile)
    end
    body:HookScript("OnSizeChanged", Tile)
    Tile()
    function g.Plan(on)
        g.clouds:SetShown(not on)
        g.grid:SetShown(on and true or false)
    end
    g.shade = body:CreateTexture(nil, "BACKGROUND", nil, -7)
    g.shade:SetAllPoints()
    g.shade:SetTexture(ns.media .. "talents\\vignette")
    g.shade:SetVertexColor(1, 1, 1, SHADE)
    function g.Set(class, tree)
        local c = ROLE_COLOR[Role(class, tree)]
        g.clouds:SetVertexColor(c[1], c[2], c[3], CLOUDS)
    end
    return g
end
W.Ground = Ground

-- a control on or off: off, its word dim and its click refused
local function Can(b, on)
    b.on = on and true or false
    b:SetEnabled(b.on)
    local color = b.on and (b.bright or GOLD) or OFF
    b.label:SetTextColor(color[1], color[2], color[3])
    if b.lit then b.well:SetColorTexture(unpack(b.on and b.lit or b.dark)) end
end

local function Points(p, body)
    local c = Console(body, true, p.panel)
    p.console = c
    local row = c.row
    p.reset = Button(row, 64, function()
        C_Traits.RollbackConfig(Config())
        W.Refresh()
    end, function() return Tr["Forget the talents chosen."] end)
    p.reset.label:SetText(Tr["Reset"])
    p.follow = Button(row, 64, function()
        Follow()
        W.Refresh()
    end, function() return Tr["Choose the plan's next talents, as many as your points; Apply learns them."] end)
    p.follow.label:SetText(Tr["Follow"])
    p.apply = Button(row, 64, function()
        if not Editable() then return end
        if C_ClassTalents.CommitConfig() then
            committing = true
            Sound("apply")
        end
    end, function() return InCombatLockdown() and Tr["Not in combat."] or Tr["Learn the talents chosen."] end)
    p.apply.label:SetText(Tr["Apply"])
    -- the plan's mode's own: out of it (Create Plan and Edit, on the plans'
    -- page, bring it; the plan drawn is forgotten unless saved), the draft
    -- kept as a step, the plan kept under a name
    p.exit = Button(row, 64, function()
        End()
        p.chosen = nil
        W.Refresh()
    end, function()
        return sim.saved and Tr["Back to learning talents."]
            or Tr["Back to learning talents; the plan is lost unless saved."]
    end)
    p.exit.label:SetText(Tr["Exit plan"])
    p.checkpoint = Button(row, 64, function()
        Checkpoint()
        W.Refresh()
    end, function() return Tr["Keep the points added as one step of the plan."] end)
    p.checkpoint.label:SetText(Tr["Checkpoint"])
    p.save = Button(row, 64, function()
        if sim.draft then return end
        p.name:SetText(sim.name or format(Tr["Plan %d"], #Book().list + 1))
        p.name:Show()
        c.state:Hide()
        p.name:SetFocus()
        p.name:HighlightText()
    end, function()
        local d = sim.draft
        return d and format(Tr["Checkpoint %s first."], Entry(Config(), Model(Config())[d.id].node).name)
            or Tr["Name the plan and keep it; a plan of that name is replaced."]
    end)
    p.save.label:SetText(Tr["Save plan"])
    -- Apply and Save the bright ones while they can be used: their wells
    -- gold-brown, their words light
    for _, b in ipairs({ p.apply, p.save }) do
        b.lit = { 0.36, 0.28, 0.12, 1 }
        b.dark = { ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.85 }
        b.bright = { 1, 0.925, 0.667 }
    end
    -- Save plan asks for the name in a box over the plan's name, in the
    -- console: Enter keeps it, Escape (or leaving the box) does not
    p.name = CreateFrame("EditBox", nil, c.cells[3])
    p.name:SetAutoFocus(false)
    p.name:SetFont(ns.font, 14, "")
    p.name:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    p.name:SetTextInsets(8, 8, 0, 0)
    p.name:SetMaxLetters(32)
    p.name:SetHeight(24)
    p.name:SetPoint("BOTTOMLEFT", c.cells[3], "LEFT", 16, 0)
    p.name:SetPoint("BOTTOMRIGHT", c.cells[3], "RIGHT", -16, 0)
    local well = p.name:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local inside = p.name:CreateTexture(nil, "BACKGROUND", nil, 1)
    inside:SetPoint("TOPLEFT", 1, -1)
    inside:SetPoint("BOTTOMRIGHT", -1, 1)
    inside:SetColorTexture(0.047, 0.043, 0.035, 1)
    p.name:Hide()
    p.name:SetScript("OnEnterPressed", function(self)
        local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
        self:ClearFocus()
        if name ~= "" and planning and not sim.draft then Save(name) end
        W.Refresh()
    end)
    p.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.name:SetScript("OnEditFocusLost", function(self)
        self:Hide()
        c.state:Show()
    end)
    -- joined: each a third, neighbours sharing their edge; the mode's
    -- three or the others (Controls)
    local function Lay()
        local w = (row:GetWidth() or 0) / 3
        for _, list in ipairs({ { p.reset, p.follow, p.apply }, { p.exit, p.checkpoint, p.save } }) do
            for i, b in ipairs(list) do
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", row, "TOPLEFT", math.floor((i - 1) * w) - (i > 1 and 1 or 0), 0)
                b:SetSize(math.floor(w) + (i > 1 and 1 or 0), CONTROLS + 1)
            end
        end
    end
    row:SetScript("OnSizeChanged", Lay)
    Lay()
end

-- the console's controls: out of the plan's mode, Reset and Apply while
-- points are chosen (Apply while they can be learned), Follow while the
-- plan has a next; in it, Exit plan, Checkpoint while there is a draft,
-- Save plan while there is something to save and no draft
function Controls(p, staged, follow, draft, savable)
    for _, b in ipairs({ p.reset, p.follow, p.apply }) do b:SetShown(not planning) end
    for _, b in ipairs({ p.exit, p.checkpoint, p.save }) do b:SetShown(planning and true or false) end
    if planning then
        Can(p.exit, true)
        Can(p.checkpoint, draft)
        Can(p.save, savable)
    else
        Can(p.reset, staged)
        Can(p.follow, follow)
        Can(p.apply, staged and Editable())
    end
end

-- a foot's hint, under its row of buttons: two lines, wrapping
local function Hint(foot)
    local hint = ns.Text(foot, 12)
    hint:SetPoint("TOPLEFT", 8, -(6 + STRIP + 6))
    hint:SetPoint("TOPRIGHT", -8, -(6 + STRIP + 6))
    hint:SetJustifyH("CENTER")
    hint:SetWordWrap(true)
    hint:SetTextColor(unpack(ns.colors.dim))
    return hint
end

-- the foot: in the plan's mode, where the plan is worked ([Exit plan]
-- [Checkpoint] [Save plan] and the name asked for, a hint under them);
-- otherwise the chosen talent's details
local function Foot(p, foot)
    -- the talent chosen: its rank (planned, in the plan's mode) and what
    -- each gives
    p.details = ns.character.Details(foot, nil, Tr["Choose a talent to read it."], 4)
    -- and under it, always, on a row of its own under a fading rule: the
    -- plan's next step (and the chosen talent's place in the plan), or in
    -- the plan's mode the hint
    p.planLine = ns.Text(foot, 12)
    p.planLine:SetPoint("BOTTOMLEFT", 8, 2)
    p.planLine:SetPoint("BOTTOMRIGHT", -8, 2)
    p.planLine:SetJustifyH("CENTER")
    p.planLine:SetWordWrap(false)
    p.planLine:SetTextColor(unpack(ns.colors.dim))
    p.planHair = ns.window.Hair(foot)
    p.planHair:SetPoint("BOTTOMLEFT", 40, 2 + 15 + 6)
    p.planHair:SetPoint("BOTTOMRIGHT", -40, 2 + 15 + 6)
    p.footHeight = p.details.height + PLAN_ROW
end

-- The glows: a staged talent's alpha swinging round PULSE's, a flash
-- (FLASH seconds) fading from FLASH_ALPHA down to where it rests (its pulse,
-- its still aura, or nothing)
local function Pulse(p)
    local now = GetTime()
    local swing = PULSE[1] + PULSE[2] * math.sin(now * 2 * math.pi / PULSE[3])
    for _, b in ipairs(p.nodes) do
        if b.node and b.glow then
            local c = b.glow
            local rest = b.pulse and swing or b.aura:IsShown() and STILL or 0
            local left = (b.flashUntil or 0) - now
            if left > 0 then
                b.aura:SetVertexColor(c[1], c[2], c[3], rest + (FLASH_ALPHA - rest) * (left / FLASH))
            elseif b.flashUntil then
                b.flashUntil = nil
                p.Refresh()
            elseif b.pulse then
                b.aura:SetVertexColor(c[1], c[2], c[3], swing)
            end
        end
    end
end

-- ------------------------------------------------------------------ pages
for i = 1, TREES do
    local p = { key = "tree" .. i, tree = i, order = i, label = "", frame = "TalentsFrame" }
    p.nodes, p.edges, p.halos = {}, {}, {}
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    -- the console joined under the head (the shell's panel); the tree from
    -- just under it
    p.under, p.over = CONSOLE, 8
    p.events = { "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    function p.Available()
        local g = C_Traits and C_SpecializationInfo and Groups()[i]
        if not g then return false end
        p.label, p.icon = g.displayName, g.icon
        local spent = Spent(Config(), Groups())[g.groupID] or 0
        p.tip = format(Tr["%s: %d |4point:points;"], g.displayName, spent)
        return true
    end
    function p.Build(body, foot, band)
        -- the tree's ground, in its colour
        p.ground = Ground(body)
        p.ground.Set(select(2, UnitClass("player")), i)
        Points(p, body)
        Foot(p, foot)
        Margin(p, band)
        -- the glows' pulse and the flashes, while the tree is in sight
        body:HookScript("OnUpdate", function() Pulse(p) end)
    end
    function p.Refresh() Refresh(p) end
    -- a point spent: its glow flashes bright, and fades back
    function p.Flash(b)
        b.flashUntil = GetTime() + FLASH
        b.aura:Show()
    end
    -- Apply's talents learned: the game's complete sound, each talent
    -- that rose flashing (its learned ranks against the last drawn)
    function p.OnEvent(event)
        if event ~= "TRAIT_CONFIG_UPDATED" or not committing then return end
        committing = nil
        Sound("complete")
        local config = Config()
        for _, b in ipairs(p.nodes) do
            if b.node and b:IsShown() then
                local now = config and C_Traits.GetNodeInfo(config, b.node.ID)
                if now and now.ranksPurchased > (b.learned or 0) then p.Flash(b) end
            end
        end
    end
    W.Page(p)
end

-- ------------------------------------------------------------ the plans
-- The plans kept, each under a head of its own: a fold chevron, its name,
-- its points, and Use when it is not the active one (Active when it is).
-- A click on the head folds its checkpoints away or back (kept with the
-- plan). Under it, its checkpoints: the levels each comes at, the talent
-- and the rank it reaches, its tree; learned ones ticked and dim, the
-- active plan's next marked. A checkpoint is a run of one talent in it.
local LINE, GUTTER, HEADER, GAP, LABELS = 24, 10, 28, 6, 20

-- a plan's card: the parchment behind its head, labels and rows, as a
-- group's on the character window's lists (ns.character.Card), under them
local CARD_FOOT = 6
local function Card(p, i)
    local f = CreateFrame("Frame", nil, p.list.child)
    f:SetFrameLevel(p.list.child:GetFrameLevel())
    f.card = ns.character.Card(f)
    p.cards[i] = f
    return f
end

-- a plan's head: an engraved plate, as the character window's lists' headings
-- (ns.character.Plate), its name the title
local function Head(p, i)
    local h = CreateFrame("Button", nil, p.list.child)
    h:SetHeight(HEADER)
    h.name = ns.Text(h, 14)
    h.name:SetJustifyH("LEFT")
    h.name:SetWordWrap(false)
    h.plate = ns.character.Plate(h, h.name)
    h.fold = h.plate.fold
    h.use = Button(h, 48, function(self)
        Book().active = self:GetParent().plan
        W.Refresh()
    end, function() return Tr["Make this the active plan: the trees glow for it, and Follow takes its talents."] end)
    h.use.label:SetText(Tr["Use"])
    h.use:SetHeight(HEADER - 8)
    h.use:SetPoint("RIGHT", -4, 0)
    h.count = ns.Text(h, 11)
    h.count:SetTextColor(unpack(ns.colors.dim))
    local glow = h:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.05)
    h:SetScript("OnClick", function(self)
        local kept = Book().list[self.plan]
        if kept then kept.collapsed = not kept.collapsed or nil end
        W.Refresh()
    end)
    p.heads[i] = h
    return h
end

-- the checkpoints' table: its columns, from the right (the spec's icon,
-- the progress, the goal), the levels and the talent from the left
local SPEC, PROGRESS, GOAL, LVLS = 18, 58, 50, 44
local function Columns(f)
    f.at = ns.Text(f, 12)
    f.at:SetPoint("LEFT", 0, 0)
    f.at:SetWidth(LVLS)
    f.at:SetJustifyH("RIGHT")
    f.progress = ns.Text(f, 12)
    f.progress:SetPoint("RIGHT", -(4 + SPEC + 6), 0)
    f.progress:SetWidth(PROGRESS)
    f.progress:SetJustifyH("CENTER")
    f.goal = ns.Text(f, 12)
    f.goal:SetPoint("RIGHT", f.progress, "LEFT", 0, 0)
    f.goal:SetWidth(GOAL)
    f.goal:SetJustifyH("CENTER")
    f.name = ns.Text(f, 12)
    f.name:SetPoint("RIGHT", f.goal, "LEFT", -6, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
end

-- the table's head, under a plan's: what each column is
local function Labels(p, i)
    local f = CreateFrame("Frame", nil, p.list.child)
    f:SetHeight(LABELS)
    Columns(f)
    f.name:SetPoint("LEFT", LVLS + 8, 0)
    f.at:SetText(Tr["Lvls"])
    f.name:SetText(Tr["Talent"])
    f.goal:SetText(Tr["Goal"])
    f.progress:SetText(Tr["Progress"])
    f.spec = ns.Text(f, 11)
    f.spec:SetPoint("RIGHT", -2, 0)
    f.spec:SetText(Tr["Spec"])
    for _, t in ipairs({ f.at, f.name, f.goal, f.progress, f.spec }) do
        t:SetFont(ns.font, 11, "")
        t:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
    end
    p.labels[i] = f
    return f
end

local function Row(p, i)
    local r = CreateFrame("Button", nil, p.list.child)
    r:SetHeight(LINE)
    -- the next checkpoint's band, a gold hairline along each edge; under
    -- it, every other row's stripe and the thread to the plan's head
    r.mark = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.mark:SetAllPoints()
    r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    r.markEdges = {}
    for k, point in ipairs({ "TOP", "BOTTOM" }) do
        local t = r:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetHeight(1)
        t:SetPoint(point .. "LEFT", r.mark, point .. "LEFT")
        t:SetPoint(point .. "RIGHT", r.mark, point .. "RIGHT")
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.4)
        r.markEdges[k] = t
    end
    r.thread = ns.character.Thread(r)
    Columns(r)
    r.at:SetTextColor(unpack(ns.colors.dim))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(LINE - 4, LINE - 4)
    r.icon:SetPoint("LEFT", LVLS + 8, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.tick = r:CreateTexture(nil, "ARTWORK")
    r.tick:SetSize(14, 14)
    r.tick:SetPoint("CENTER", r.progress, "CENTER", 0, 0)
    r.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    r.spec = r:CreateTexture(nil, "ARTWORK")
    r.spec:SetSize(SPEC, SPEC)
    r.spec:SetPoint("RIGHT", -4, 0)
    r.spec:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    -- a checkpoint opens its talent's tree, the talent chosen
    r:SetScript("OnClick", function(self)
        for _, page in ipairs(W.pages) do
            local g = page.tree and Groups()[page.tree]
            if g and g.groupID == self.group and page.available then
                page.chosen = self.id
                W.Select(page)
                return
            end
        end
    end)
    r:SetScript("OnEnter", function(self) if self.talent then Tooltip(self, self) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = r
    return r
end

-- the walk's checkpoints: each run of one talent, its first and last
-- places and the rank it reaches
local function Checkpoints(kept)
    local out, counts = {}, {}
    for k, id in ipairs(kept) do
        counts[id] = (counts[id] or 0) + 1
        local last = out[#out]
        if last and last.id == id then
            last.to, last.rank = k, counts[id]
        else
            table.insert(out, { id = id, from = k, to = k, rank = counts[id] })
        end
    end
    return out
end

local function RefreshPlans(p)
    local config = Config()
    if not config then return end
    local m = Model(config)
    local b = Book()
    local icons = {}
    for _, g in ipairs(Groups()) do icons[g.groupID] = g.icon end
    local width = W.width - GUTTER
    local nh, nr, nl, y = 0, 0, 0, 0
    local summary
    for k, kept in ipairs(b.list) do
        local active = k == b.active
        local walk = Walk(m, kept.steps)
        local place = active and Next(m, walk.kept)
        local steps = Checkpoints(walk.kept)
        nh = nh + 1
        local h = p.heads[nh] or Head(p, nh)
        local card = p.cards[nh] or Card(p, nh)
        local top = y
        h.plan = k
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetWidth(width)
        h:Show()
        y = y + HEADER
        h.plate:Set({ x = 8, folded = kept.collapsed, bright = active })
        h.name:SetPoint("RIGHT", h.count, "LEFT", -8, 0)
        h.name:SetText(kept.name)
        local c = active and GOLD or ns.colors.text
        h.name:SetTextColor(c[1], c[2], c[3])
        h.use:SetShown(not active)
        h.count:ClearAllPoints()
        if active then h.count:SetPoint("RIGHT", -10, 0) else h.count:SetPoint("RIGHT", h.use, "LEFT", -8, 0) end
        h.count:SetText((active and Tr["Active"] .. "  ·  " or "") .. format(Tr["%d |4point:points;"], #walk.kept))
        if not kept.collapsed then
            nl = nl + 1
            local l = p.labels[nl] or Labels(p, nl)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", 0, -y)
            l:SetWidth(width)
            l:Show()
            y = y + LABELS
        end
        local learned = 0
        for n, step in ipairs(steps) do
            local t = m[step.id]
            local done = t.node.ranksPurchased >= step.rank
            if done then learned = learned + 1 end
            if not kept.collapsed then
                nr = nr + 1
                local r = p.rows[nr] or Row(p, nr)
                local ahead = place and place >= step.from and place <= step.to
                r.id, r.group, r.node, r.talent = step.id, t.group, t.node, Entry(config, t.node)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetWidth(width)
                r:Show()
                y = y + LINE
                r.at:SetText(step.from == step.to and tostring(step.from + 9)
                    or format("%d–%d", step.from + 9, step.to + 9))
                r.icon:SetTexture(r.talent.icon)
                r.icon:SetDesaturated(done)
                r.name:SetText(r.talent.name)
                local rc = ahead and GOLD or ns.colors.text
                r.name:SetTextColor(rc[1], rc[2], rc[3])
                -- the goal, the rank the checkpoint reaches; the progress,
                -- the ranks learned toward it, a tick once they are all
                r.goal:SetText(format("%d/%d", step.rank, t.node.maxRanks))
                r.progress:SetText(format("%d/%d", t.node.ranksPurchased, step.rank))
                r.progress:SetShown(not done)
                r.tick:SetShown(done)
                r.spec:SetTexture(icons[t.group])
                r:SetAlpha(done and 0.45 or 1)
                r.mark:SetShown(ahead and true or false)
                for _, e in ipairs(r.markEdges) do e:SetShown(ahead and true or false) end
                r.thread:Set(3, n % 2 == 1, n == #steps)
            end
        end
        -- the card from the head down, a foot under an open plan's rows
        if not kept.collapsed then y = y + CARD_FOOT end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 0, -top)
        card:SetSize(width, y - top)
        card:Show()
        card.card:Set({ top = top, h = y - top, first = true, last = true })
        y = y + GAP
        if active then
            summary = { steps = #steps, place = place }
        end
    end
    for k = nh + 1, #p.heads do p.heads[k]:Hide() end
    for k = nh + 1, #p.cards do p.cards[k]:Hide() end
    for k = nr + 1, #p.rows do p.rows[k]:Hide() end
    for k = nl + 1, #p.labels do p.labels[k]:Hide() end
    p.list.child:SetSize(width, math.max(1, y))
    p.list.To(p.list.target)
    p.edit:SetShown(summary and true or false)
    p.remove:SetShown(summary and true or false)
    p.hint:SetText(p.notice or #b.list == 0
        and Tr["No plan yet: Create Plan, click talents, Checkpoint each, then Save plan."]
        or not summary and Tr["Press Use on a plan to make it the active one."]
        or summary.place and format(Tr["Next: level %d. Click a checkpoint to open its talent."], summary.place + 9)
        or summary.steps > 0 and Tr["Every talent in the plan is learned."]
        or Tr["The plan is empty."])
    Band(p)
end

-- the plans' page: no tab, Plans in the margin opens it. Over its list the
-- active plan's count; in its foot, as under a tree, Edit and Remove and a
-- hint
do
    local p = { key = "plans", tabless = true, order = TREES + 1, label = Tr["Plans"], frame = "TalentsFrame" }
    p.rows, p.heads, p.labels, p.cards = {}, {}, {}, {}
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    p.events = { "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE",
        "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
    function p.Available() return C_Traits and C_SpecializationInfo and Groups()[1] ~= nil end
    function p.Build(body, foot, band)
        local top = CreateFrame("Frame", nil, foot)
        top:SetPoint("TOPLEFT", 0, -6)
        top:SetPoint("TOPRIGHT", 0, -6)
        top:SetHeight(STRIP)
        -- Create Plan draws one from nothing, in the plan's mode over a tree
        p.create = Button(top, 92, function()
            p.notice = nil
            Begin()
            Back()
        end, function() return Tr["Draw a plan from nothing: the order to learn talents in."] end)
        p.create.label:SetText(Tr["Create Plan"])
        p.create:SetHeight(STRIP - 2)
        p.create:SetPoint("LEFT", 4, 0)
        -- Edit draws the active plan again, in the plan's mode over a tree
        p.edit = Button(top, 52, function()
            local chosen = Chosen()
            if not chosen then return end
            p.notice = nil
            Begin(chosen.steps, chosen.name)
            Back()
        end, function()
            return Tr["Draw the active plan again, from its last checkpoint; Save plan keeps the changes."]
        end)
        p.edit.label:SetText(Tr["Edit"])
        p.edit:SetHeight(STRIP - 2)
        p.edit:SetPoint("LEFT", p.create, "RIGHT", 4, 0)
        -- Remove asks twice: the first press arms it, leaving disarms it
        p.remove = Button(top, 92, function(self)
            if not self.armed then
                self.armed = true
                self.label:SetText(Tr["Press again"])
                return
            end
            local b = Book()
            if b.active then table.remove(b.list, b.active) end
            b.active = nil
            self.armed = nil
            self.label:SetText(Tr["Remove"])
            W.Refresh()
        end, function() return Tr["Remove the active plan."] end)
        p.remove.label:SetText(Tr["Remove"])
        p.remove:SetHeight(STRIP - 2)
        p.remove:SetPoint("LEFT", p.edit, "RIGHT", 4, 0)
        p.remove:HookScript("OnLeave", function(self)
            self.armed = nil
            self.label:SetText(Tr["Remove"])
        end)
        -- Import: a Wowhead build pasted into a box over the hint, opened in
        -- the plan's mode to look over and save; why not, in the hint
        p.import = Button(top, 64, function()
            p.notice = nil
            p.paste:SetText("")
            p.paste:Show()
            p.hint:Hide()
            p.paste:SetFocus()
        end, function()
            return Tr["Paste a Wowhead talent calculator link or its WHML: the build opens as a plan to look over "
                .. "and save."]
        end)
        p.import.label:SetText(Tr["Import"])
        p.import:SetHeight(STRIP - 2)
        p.import:SetPoint("RIGHT", -4, 0)
        p.paste = CreateFrame("EditBox", nil, foot)
        p.paste:SetAutoFocus(false)
        p.paste:SetFont(ns.font, 12, "")
        p.paste:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
        p.paste:SetTextInsets(8, 8, 0, 0)
        p.paste:SetMaxLetters(600)
        p.paste:SetHeight(24)
        p.paste:SetPoint("TOPLEFT", 8, -(6 + STRIP + 6))
        p.paste:SetPoint("TOPRIGHT", -8, -(6 + STRIP + 6))
        local well = p.paste:CreateTexture(nil, "BACKGROUND")
        well:SetAllPoints()
        well:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local inside = p.paste:CreateTexture(nil, "BACKGROUND", nil, 1)
        inside:SetPoint("TOPLEFT", 1, -1)
        inside:SetPoint("BOTTOMRIGHT", -1, 1)
        inside:SetColorTexture(0.047, 0.043, 0.035, 1)
        p.paste:Hide()
        p.paste:SetScript("OnEnterPressed", function(self)
            local text = self:GetText()
            self:ClearFocus()
            local build = ns.WowheadBuild(text)
            local steps, left
            if build then
                steps, left = Imported(build)
            else
                left = Tr["No Wowhead talent build in that: paste the calculator's link, or its WHML."]
            end
            if not steps then
                p.notice = left
                W.Refresh()
                return
            end
            Begin(steps, nil, left > 0 and ns.Plural(left,
                format(Tr["Left out by the rules: %d |4point:points;."], left)) or nil, true)
            Back()
        end)
        p.paste:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        p.paste:SetScript("OnEditFocusLost", function(self)
            self:Hide()
            p.hint:Show()
        end)
        local area = CreateFrame("Frame", nil, body)
        area:SetPoint("TOPLEFT", 0, -4)
        area:SetPoint("BOTTOMRIGHT")
        p.list = ns.window.Scroller(area, GUTTER)
        area:EnableMouseWheel(true)
        area:SetScript("OnMouseWheel", function(_, delta) p.list.To(p.list.target - delta * LINE * 3) end)
        p.hint = Hint(foot)
        -- as tall as a tree's foot, so the list keeps its place between them
        p.footHeight = FOOT
        for _, page in ipairs(W.pages) do
            if page.tree and page.footHeight then p.footHeight = page.footHeight end
        end
        Margin(p, band)
    end
    function p.Refresh() RefreshPlans(p) end
    W.Page(p)
    plansPage = p
end

-- the drawing, for another's talents (inspect/talents.lua): read only, no
-- plan; Draw(p, config, group, groups) with p.readonly, p.body, p.nodes,
-- p.edges, and the room over the tree (head) the points' row's
W.Tree, W.Groups, W.Spent, W.Lock, W.Describe, W.Entry = Tree, Groups, Spent, Lock, Describe, Entry
W.head = HEAD
W.readouts = READOUTS
-- another's talents (inspect/talents.lua): read only, so no talent can
-- take a point and none pulses; the maxed ones shine, the lit lines glow
function W.Draw(p, config, group, groups)
    p.halos = p.halos or {}
    return Draw(p, config, group, groups, { counts = {}, kept = {}, spent = {}, model = {} })
end

function W.Refresh()
    local p = W.Current()
    if p and W.window:IsShown() then p.Refresh() end
end

local function Start()
    -- Forever's micro menu has a talents button of its own; retail's has
    -- one player-spells button for its combined frame
    if not ns.db.talents or not SpellbookMicroButton or not C_Traits or not C_SpecializationInfo
        or not C_SpecializationInfo.GetCombatConfigIDForSpecGroup then return end
    W.Build()
    -- the window closed: a plan drawn and not saved is lost
    W.window:HookScript("OnHide", End)
    for _, p in ipairs(W.pages) do
        if p.available then W.Select(p); break end
    end
    -- the trees' names and points come with the config; a switch of talents
    -- views the ones now in use
    for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do
        ns.On(e, function() W.Retab() end)
    end
    ns.On("ACTIVE_TALENT_GROUP_CHANGED", function()
        view = nil
        W.Retab()
    end)
    ns.PlayerSpellsTab("ClassTalents", W)
end

ns.On("PLAYER_LOGIN", Start)
