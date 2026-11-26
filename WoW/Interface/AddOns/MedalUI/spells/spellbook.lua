-- The spellbook: MedalUI's own (the shell is window/shell.lua), standing
-- on the right strip over the side panel's place, its margin beside the
-- backpack's medallion. Forever only: retail's spellbook is one of its
-- player-spells frame's pages, and keeps Blizzard's.
--
--   (o) 1 of 2              Spellbook                          v | x
--   +---------------+---------------+---------------+-------------+
--   | <> General    | <> Elemental  |<> Enhancement | <> Restor.. |
--   |    9 spells   |   11 spells   |   13 spells   |   9 spells  |
--   +---------------+---------------+=====[held]====+-------------+
--   +- Not on your bars ------------------------------------- 2 -+  |
--   | [icon] Attack                                     Instant   |  | (its bar,
--   +-------------------------------------------------------------+  |  in the
--   +- On your bars ------------------------------------------ 6 -+     margin)
--   | [icon] Healing Wave v                               3 sec   |  |
--   |  [5]   Rank 5 · Shift+Middle                     200 Mana   |  |
--   |    |-- Rank 5                       3 sec        200 Mana   |  |
--   |    '-- Rank 1                     1.5 sec         25 Mana   |  |
--   |  Passive · 1 ----------------------------------------------- |
--   |  [icon] Reincarnation                                Passive |
--   +-------------------------------------------------------------+
--     (the floor bare under them)
--   [Trainer]                                            (backpack)
--
-- (2026-11-19, /workspace/spec-tabs-B.png) A panel under the head holds a
-- tab for each skill line the book shows (General, then each
-- specialisation) and Pet last while the pet has spells: its role's gem
-- (damage red, healer green, tank blue; General and the pet the theme's
-- brown), its name, its count; the open one held (MedalUICharDB.bookTab,
-- by name, each page its own). (2026-11-25, /workspace/spec-rows-B.png)
-- The specialisations share its top row; General and Pet a slim strip
-- under them, no more than three to a row. Under it that line's spells, as
-- glass cards, in two titled windows on the macros' floor (the page's) (2026-11-26, the
-- user's, mockup B of /workspace/booklist-windows-sheet.png): Not on your
-- bars and On your bars, each with its count and its own scroll, its bar
-- out in the window's margin by the rail (Scroller's outside); the
-- passives at the foot of On your bars under a heading (Grouped). Each
-- window fits its rows; when both cannot, Not on your bars is the longer
-- (Layout). A spell is a row the window's width, at
-- its highest rank learned, with its cast time over its cost at the right.
-- One with ranks has how many on a plate at its icon's foot and a chevron
-- after its name; a left click on it lists each rank under it
-- (MedalUICharDB.bookOpen, by name), highest first, on a tree from its
-- icon, a gold bar and a wash down the group, each a row that casts that
-- rank. The right button casts; the left only drags (and
-- shows ranks). Macros is the game's macro window in the book's look
-- (spells/macros.lua). The margin holds, once a class trainer has been visited (spells/trainers.lua),
-- Trainer: a page without a tab, in the same look, of what is still to
-- learn, now or at a later level, a tab for each skill line its spells
-- belong to (Other for the rest); Trainer again goes back.
--
-- A spell on no action bar, nor in a macro on one, wears a red edge
-- and stands under Not on your bars (spellbookMissing). Top rank, in the margin beside Trainer, keeps spells on
-- the bars at their highest rank (spellbookUpRank): every spell, only those
-- marked, or none. Shift+Right-click marks a spell or unmarks it (per
-- character, MedalUICharDB.upRank, by name), and a marked one wears a
-- Top rank chip on its second line, as a bound one wears its clicks'. A
-- lower rank on a bar is swapped for the highest as it is learned, or as
-- its spell is marked: out of combat, the cursor empty.
--
-- Casting is the client's: over each row wholly in view lies a secure
-- button (type2 spell, or flyout: the right button) in a layer parented to the strip, not the window, because a
-- frame that holds secure buttons cannot be shown or hidden in combat and
-- the window must open in combat. The layer follows the window out of
-- combat and a state driver hides it in combat: in combat the book reads,
-- scrolls and shows its tooltips, but casts and drags only out of it
-- (PickupSpellBookItem is protected in combat for an addon's code).
--
-- Blizzard's book is a tab of PlayerSpellsFrame, which the talents share:
-- this window shows while the frame is open on it (spells/frame.lua).
local _, ns = ...
local Tr = ns.L

local GOLD = ns.gold.light
local GOLD_D = ns.gold.dark
local MISSING = { 0.85, 0.3, 0.2 }      -- the edge of a spell on no bar
local BLUE = { 0.43, 0.63, 0.92 }       -- a cost
local SLOTS = 180                       -- the action slots looked through
local SPELL, RANK = 36, 24              -- a spell's row, a rank's
local SPECS_H = 44                      -- the tabs' panel, joined under the head: the specs' row
local STRIP_H = 26                      -- under it, General's and the pet's strip
local OFF = { 0.37, 0.345, 0.29 }       -- a tab's count, not held
local ICON, INDENT = 30, 8              -- a spell's icon, its left in its card
local HEADING = 28                      -- Passive's heading, at the foot of On your bars
local TITLE_H = 26                      -- a window's title band
local GAP = 6                           -- between the two windows
local LEAN = 0.6                        -- the share Not on your bars may take when both cannot fit
local SIDE, SPACE = 6, 4                -- a card in from the window's sides; the space over and under it
local GLASS = { fill = 0.45, sheen = 0.06, edge = 0.45, shine = 0.16 } -- a card: its tint, its light, its rims
local CHIP_H = 14                       -- a mark's chip on the second line
local FAINT = { 0.141, 0.122, 0.094 }   -- between a spell's ranks
local RIGHT = 80                        -- the cast time and cost's column
local EDGE = 10                         -- the cast time and cost, in from the card's edge
-- a section's colour, by its specialisation's role (General, the pet's
-- and the trainer's Other: the theme's brown)
local ROLE = { TANK = { 0.35, 0.55, 0.9 }, HEALER = { 0.35, 0.78, 0.45 }, DAMAGER = { 0.84, 0.35, 0.29 } }
local ROLE_WORD = { TANK = Tr["Tank"], HEALER = Tr["Healer"], DAMAGER = Tr["Damage"] }
local STEP = SPELL * 1.5                -- a turn of the wheel
local BANK = Enum and Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
local TYPE = Enum and Enum.SpellBookItemType or { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }

local W = ns.Window{
    name = "MedalUISpellbook", named = Tr["Spellbook"], side = 1,
    closeTip = Tr["Close the spellbook."],
    Close = function() HideUIPanel(PlayerSpellsFrame) end,
    Lifted = function() return { MainMenuBarBackpackButton } end,
}
ns.spellbook = W

local layer                             -- the secure buttons, on the strip
local open                              -- the window open on one of its pages
local SB = C_SpellBook

-- ------------------------------------------------------------- the items
-- The list, as entries to draw top to bottom: a heading for each section,
-- its spells (each at its highest rank learned), and under a spell
-- unfolded its ranks, highest first. The book's sections are its skill
-- lines (General, then each specialisation) and the pet's last; the
-- trainer's are the skill lines a spell's name is in, Other last.
local function Open(name)
    local t = MedalUICharDB and MedalUICharDB.bookOpen
    return type(t) == "table" and t[name] == true
end

local function Fold(name)
    MedalUICharDB = MedalUICharDB or {}
    MedalUICharDB.bookOpen = type(MedalUICharDB.bookOpen) == "table" and MedalUICharDB.bookOpen or {}
    MedalUICharDB.bookOpen[name] = not Open(name) or nil
end


-- A skill line's role: the game's, by its specialisation, where it has
-- one; else, on an English client, by the tree's name; else by the class
-- and the tree's place (the lines follow the talent trees' order, General
-- first); damage for the rest. General (the first line) has none.
local ROLE_BY_NAME = { Restoration = "HEALER", Holy = "HEALER", Discipline = "HEALER", Protection = "TANK",
    ["Feral Combat"] = "TANK" }
local ENGLISH = (GetLocale and GetLocale() or "enUS"):match("^en") ~= nil
local ROLE_BY_TAB = { DRUID = { [3] = "TANK", [4] = "HEALER" }, PALADIN = { [2] = "HEALER", [3] = "TANK" },
    PRIEST = { [2] = "HEALER", [3] = "HEALER" }, SHAMAN = { [4] = "HEALER" }, WARRIOR = { [4] = "TANK" } }
local function Role(line, l)
    if l == 1 or not line then return nil end
    if line.specID and GetSpecializationRoleByID then
        local ok, r = pcall(GetSpecializationRoleByID, line.specID)
        if ok and ROLE[r] then return r end
    end
    if ENGLISH then return ROLE_BY_NAME[line.name] or "DAMAGER" end
    local _, class = UnitClass("player")
    return ROLE_BY_TAB[class or ""] and ROLE_BY_TAB[class][l] or "DAMAGER"
end

-- a rank row: the rank's own slot (it casts that rank), under its spell
local function Rank(src, top)
    return { rank = true, of = top, slot = src.slot, bank = src.bank, info = src.info,
        key = "r" .. tostring(src.info.actionID) }
end

-- a section, for its tab: { name, list, count, now (the trainer's: to
-- learn now), role, icon, glyph (General's and the pet's: an icon for a
-- tab, on the left) }; none when it has nothing
local function Section(out, name, list, now, role, icon, glyph)
    if #list == 0 then return end
    table.insert(out, { name = name, list = list, count = #list, now = now, role = role, icon = icon,
        glyph = glyph })
end

-- a section's entries: each spell, and under one unfolded its ranks
local function Entries(section)
    local out = {}
    for _, item in ipairs(section and section.list or {}) do
        item.key = item.key or tostring(item.info.actionID)
        table.insert(out, item)
        if item.lower and #item.lower > 0 and Open(item.info.name) then
            table.insert(out, Rank(item, item))
            for i = #item.lower, 1, -1 do table.insert(out, Rank(item.lower[i], item)) end
        end
    end
    return out
end

-- the page's open tab (MedalUICharDB.bookTab[page], by the section's
-- name), or its first
local function Held(p)
    local t = MedalUICharDB and MedalUICharDB.bookTab
    local name = type(t) == "table" and t[p.key]
    for _, sec in ipairs(p.sections or {}) do
        if sec.name == name then return sec end
    end
    return p.sections and p.sections[1]
end

local function Hold(p, name)
    MedalUICharDB = MedalUICharDB or {}
    MedalUICharDB.bookTab = type(MedalUICharDB.bookTab) == "table" and MedalUICharDB.bookTab or {}
    MedalUICharDB.bookTab[p.key] = name
end

-- The trainer's services still to learn: no slot, nothing to cast.
local function Trained()
    local lines, of = {}, {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        if line and not line.shouldHide then
            lines[l] = { name = line.name, items = {}, role = Role(line, l), icon = line.iconID }
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = SB.GetSpellBookItemInfo(slot, BANK.Player)
                if info and not of[info.name] then of[info.name] = l end
            end
        end
    end
    local other = { name = Tr["Other"], items = {} }
    for _, t in ipairs(ns.trainers.Class()) do
        local e = t.entry
        local section = lines[of[e.name]] or other
        table.insert(section.items, { trainer = e, now = t.now, info = { name = e.name, subName = e.rank or "",
            iconID = e.icon, actionID = e.name .. "|" .. (e.rank or "") } })
    end
    local out = {}
    local order = {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        if lines[l] then table.insert(order, lines[l]) end
    end
    table.insert(order, other)
    for _, section in ipairs(order) do
        local now = 0
        for _, item in ipairs(section.items) do if item.now then now = now + 1 end end
        Section(out, section.name, section.items, now, section.role, section.icon)
    end
    return out
end

-- A skill line's spells: { slot, bank, info }, each at its highest rank
-- learned (highest; its lower ranks in lower). A rank not learned yet of a
-- spell you have is left out.
local function Line(line)
    local all, ranks, out = {}, {}, {}
    for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local info = SB.GetSpellBookItemInfo(slot, BANK.Player)
        if info then
            local item = { slot = slot, bank = BANK.Player, info = info }
            table.insert(all, item)
            if info.itemType == TYPE.Spell then
                ranks[info.name] = ranks[info.name] or {}
                table.insert(ranks[info.name], item)
            end
        end
    end
    -- the book lists a spell's ranks low to high: the last is the highest
    for _, list in pairs(ranks) do
        local top = list[#list]
        top.highest, top.lower = true, {}
        for i = 1, #list - 1 do table.insert(top.lower, list[i]) end
    end
    for _, item in ipairs(all) do
        local info = item.info
        local kept = info.itemType == TYPE.Spell and item.highest
            or info.itemType ~= TYPE.Spell and not (info.itemType == TYPE.FutureSpell and ranks[info.name])
        if kept then table.insert(out, item) end
    end
    return out
end

local function Sections(p)
    if p.trainer then return Trained() end
    local out = {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        if line and not line.shouldHide then
            Section(out, line.name, Line(line), nil, Role(line, l), line.iconID, l == 1)
        end
    end
    local pet = {}
    for slot = 1, SB.HasPetSpells and SB.HasPetSpells() or 0 do
        local info = SB.GetSpellBookItemInfo(slot, BANK.Pet)
        if info then table.insert(pet, { slot = slot, bank = BANK.Pet, info = info }) end
    end
    Section(out, Tr["Pet"], pet, nil, nil, GetPetIcon and GetPetIcon() or nil, true)
    return out
end

-- the page's sections (its tabs)
local function Items(p)
    p.sections = Sections(p)
    p.held = Held(p)
end

-- ------------------------------------------------------------ on the bars
-- The spells a macro on a bar casts, by ID.
local function Macros()
    local out = {}
    if not GetMacroSpell then return out end
    for slot = 1, SLOTS do
        local kind, id = GetActionInfo(slot)
        if kind == "macro" and id then
            local spell = GetMacroSpell(id)
            if spell then out[spell] = true end
        end
    end
    return out
end

local function OnBar(id, macros)
    if not id then return false end
    if macros[id] then return true end
    local slots = C_ActionBar and C_ActionBar.FindSpellActionButtons and C_ActionBar.FindSpellActionButtons(id)
    return slots ~= nil and #slots > 0
end

-- on a bar by either of its IDs: the book's own, or the one it is known by
-- now (its replacement: Ghost Wolf's)
local function Placed(info, macros)
    return OnBar(info.actionID, macros) or info.spellID ~= info.actionID and OnBar(info.spellID, macros)
end

-- Whether an item is on no bar, and the lower rank that is if one is. Only
-- a highest rank asks, and only one cast: no passive, nothing of the pet's.
local function Missing(item, macros)
    local info = item.info
    if not (ns.db.spellbookMissing and item.highest and not info.isPassive and item.bank == BANK.Player) then
        return false
    end
    if Placed(info, macros) then return false end
    for _, low in ipairs(item.lower or {}) do
        if Placed(low.info, macros) then return true, low.info.subName end
    end
    return true
end

-- (2026-11-26, /workspace/booklist-windows-sheet.png) The open tab's
-- spells in two windows: Not on your bars (each spell Missing finds) and
-- On your bars (the rest), its passives last under a Passive heading; each
-- in the book's order. Both windows always show, an empty one saying so.
-- On the trainer's page and while Click Casting binds nothing is missing,
-- so all stands under On your bars.
local function Grouped(p, macros, binding)
    local list = p.held and p.held.list or {}
    local groups = { {}, {}, {} }
    for _, item in ipairs(list) do
        if binding or p.trainer then
            item.missing, item.lowerOn = false, nil
        else
            item.missing, item.lowerOn = Missing(item, macros)
        end
        local g = item.missing and 1 or item.info.isPassive and 3 or 2
        table.insert(groups[g], item)
    end
    local placed = Entries({ list = groups[2] })
    if #groups[3] > 0 then
        table.insert(placed, { heading = Tr["Passive"], count = #groups[3], key = "h3" })
        for _, e in ipairs(Entries({ list = groups[3] })) do table.insert(placed, e) end
    end
    return { items = Entries({ list = groups[1] }), count = #groups[1] },
        { items = placed, count = #groups[2] + #groups[3] }
end

-- ------------------------------------------------------------- up-ranking
-- A lower rank on a bar becomes the highest learned, for the spells asked:
-- out of combat (else at its end), and with the cursor empty, since the
-- swap goes through it (a busy cursor waits for the next change).
local pending
-- each mode as the Top rank button's tip names it, mid-sentence
local MODE_WORD = { all = Tr["every spell"], marked = Tr["only those marked"], none = Tr["none"] }
local function Mode()
    local m = ns.db.spellbookUpRank
    return (m == "all" or m == "none") and m or "marked"
end
local function Marked(name)
    local t = MedalUICharDB and MedalUICharDB.upRank
    return type(t) == "table" and t[name] == true
end
local function Wanted(name)
    local m = Mode()
    if m == "all" then return true end
    return m == "marked" and Marked(name)
end

-- What can be marked: a spell of the player's own, cast, that has ranks
-- (learned below it, or a "Rank 1" with more to come); its highest row
local function Markable(item)
    local info = item and item.info
    if not info or item.rank or item.trainer or info.isPassive or item.bank ~= BANK.Player
        or info.itemType ~= TYPE.Spell then
        return false
    end
    return (item.lower and #item.lower > 0) or tostring(info.subName or ""):find("%d") ~= nil
end

local function UpRank()
    if not SB then return end
    if InCombatLockdown() then pending = true return end
    pending = nil
    if GetCursorInfo() then return end
    -- each lower rank's ID, to its spell's highest and its name
    local to = {}
    for l = 1, SB.GetNumSpellBookSkillLines() do
        local line = SB.GetSpellBookSkillLineInfo(l)
        local ids = {}
        for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
            local info = SB.GetSpellBookItemInfo(slot, BANK.Player)
            if info and info.itemType == TYPE.Spell and not info.isPassive and info.spellID then
                ids[info.name] = ids[info.name] or {}
                table.insert(ids[info.name], info.spellID)
            end
        end
        for name, list in pairs(ids) do
            for i = 1, #list - 1 do to[list[i]] = { top = list[#list], name = name } end
        end
    end
    for slot = 1, SLOTS do
        local kind, id = GetActionInfo(slot)
        local up = kind == "spell" and id and to[id]
        if up and Wanted(up.name) then
            C_Spell.PickupSpell(up.top)
            PlaceAction(slot)
            ClearCursor()
        end
    end
end
ns.spellbook.UpRank = UpRank

-- a spell marked, or unmarked: the bars follow at once
local function Mark(name)
    if type(MedalUICharDB) ~= "table" then return end
    local t = type(MedalUICharDB.upRank) == "table" and MedalUICharDB.upRank or {}
    MedalUICharDB.upRank = t
    t[name] = not t[name] or nil
    if Wanted(name) then UpRank() end
end
ns.spellbook.Mark = Mark

local Money = function(c) return ns.npc and ns.npc.Money(c) or tostring(c) end

local function Sub(item)
    local info = item.info
    if item.trainer then
        local e = item.trainer
        return (e.rank and e.rank .. " · " or "") .. (item.now and Tr["Now"] or format(Tr["Level %d"], e.level))
            .. ((e.cost or 0) > 0 and " · " .. Money(e.cost) or "")
    end
    if info.itemType == TYPE.FutureSpell then
        local level = SB.GetSpellBookItemLevelLearned and SB.GetSpellBookItemLevelLearned(item.slot, item.bank)
        return level and level > 0 and format(Tr["Level %d"], level) or Tr["Not learned yet"]
    end
    if info.isPassive then return Tr["Passive"] end
    return info.subName ~= "" and info.subName or nil
end

-- ---------------------------------------------------------- click casting
-- Its bindings (spells/clickcast.lua): a bound spell's click after its rank
-- and a mouse on its icon's corner. A binding set on a lower rank marks the
-- rank shown; a pet's, only the pet's spells.

local function Clicks(item, bound)
    local info = item.info
    if not bound or item.trainer or not info then return nil end
    local ids, names = bound[1], bound[2]
    local pet = item.bank == BANK.Pet
    local out, seen = {}, {}
    local function Take(list)
        for _, b in ipairs(list or {}) do
            if b.pet == pet and not seen[b.text] then
                seen[b.text] = true
                table.insert(out, b.text)
            end
        end
    end
    Take(ids[info.actionID])
    if info.spellID then Take(ids[info.spellID]) end
    for _, low in ipairs(item.lower or {}) do Take(ids[low.info.spellID or low.info.actionID]) end
    if info.itemType == TYPE.Spell or info.itemType == TYPE.PetAction then Take(names[info.name]) end
    return #out > 0 and table.concat(out, ", ") or nil
end

-- The game's bind mode (Click Casting open): a click on a spell it can bind
-- fills its waiting slot, as the game's own book does, and casts nothing.
local function Binding()
    return ns.db.spellbookClickCast and ns.clickcast ~= nil and ns.clickcast.Binding()
end

local function Bindable(item)
    local info = item and item.info
    if not info or item.trainer or info.itemType == TYPE.FutureSpell or info.isPassive or not info.actionID then
        return false
    end
    local can = C_ClickBindings and C_ClickBindings.CanSpellBeClickBound
    if not can then return false end
    local ok, yes = pcall(can, info.actionID)
    return ok and yes and true or false
end

-- A spell bound already (any of its ranks): into the binder to change its
-- click. Else a new binding: the game's slot added if there is none (its own
-- Add binding), then filled, which loads it into the binder.
local function Bind(item)
    local f = _G.ClickBindingFrame
    local cc = ns.clickcast
    if not (f and f.AddNewAction and Bindable(item)) then return end
    local info = item.info
    local ids = { [info.actionID] = true }
    if info.spellID then ids[info.spellID] = true end
    for _, low in ipairs(item.lower or {}) do ids[low.info.spellID or low.info.actionID or 0] = true end
    local had = cc and cc.Find and cc.Find(ids, info.name)
    if had then
        cc.Load(had)
        return
    end
    if f.HasNewSlot and not f:HasNewSlot() then
        local add = f.AddBindingButton
        local click = type(add) == "table" and add.GetScript and add:GetScript("OnClick")
        if click then click(add, "LeftButton") end
        if not f:HasNewSlot() then return end
    end
    local T = Enum and Enum.ClickBindingType or { Spell = 1, PetAction = 4 }
    f:AddNewAction(item.bank == BANK.Pet and T.PetAction or T.Spell, info.actionID)
end

local Refresh, Tabs                     -- below: a page drawn again; its tabs

-- ------------------------------------------------------------------ rows
-- What a row's right side says: a spell's cast time over its cost, or the
-- trainer's level over its price. Nothing for a passive, a flyout, or one
-- not learned yet; a field the game will not tell is left blank.
local function Word(s) return (tostring(s or ""):lower():gsub("^%l", string.upper)) end

local function Costs(item)
    if item.trainer then
        local e = item.trainer
        return item.now and Tr["Now"] or format(Tr["Level %d"], e.level or 0),
            (e.cost or 0) > 0 and Money(e.cost) or nil
    end
    local info = item.info
    if info.isPassive or (info.itemType ~= TYPE.Spell and info.itemType ~= TYPE.PetAction) then return nil, nil end
    local id = info.spellID or info.actionID
    if type(id) ~= "number" or not C_Spell then return nil, nil end
    local cast, cost
    if C_Spell.GetSpellInfo then
        local ok, s = pcall(C_Spell.GetSpellInfo, id)
        local ms = ok and type(s) == "table" and s.castTime
        if type(ms) == "number" then cast = ms <= 0 and Tr["Instant"] or format(Tr["%g sec"], ms / 1000) end
    end
    if C_Spell.GetSpellPowerCost then
        local ok, list = pcall(C_Spell.GetSpellPowerCost, id)
        for _, c in ipairs(ok and type(list) == "table" and list or {}) do
            local word = Word(c.name and (_G[c.name] or c.name) or "")
            if (c.cost or 0) > 0 then
                cost = format("%d %s", c.cost, word)
                break
            elseif (c.costPercent or 0) > 0 then
                cost = format(Tr["%d%% of base %s"], c.costPercent, word:lower())
                break
            end
        end
    end
    return cast, cost
end

local function Tooltip(owner, item)
    if item.trainer then
        local e = item.trainer
        ns.Tip(owner, ns.window.Outside, { title = e.name, color = GOLD,
            e.rank and { "body", e.rank, ns.colors.dim } or false,
            { "body", item.now and Tr["You can train it now."] or format(Tr["Train it at level %d."], e.level) },
            (e.cost or 0) > 0 and { "body", format(Tr["Costs %s"], Money(e.cost)) } or false })
        return
    end
    ns.window.Outside(owner)
    GameTooltip:SetSpellBookItem(item.slot, item.bank)
    if Binding() and not Bindable(item) then
        GameTooltip:AddLine(_G.CLICK_BINDING_NOT_AVAILABLE or Tr["Click casting cannot bind this."],
            MISSING[1], MISSING[2], MISSING[3])
    elseif Binding() then
        GameTooltip:AddLine(item.clicks and format(Tr["Bound to %s: click to change it."], item.clicks)
            or Tr["Click to bind it."], GOLD[1], GOLD[2], GOLD[3])
    elseif item.clicks then
        GameTooltip:AddLine(format(Tr["Click casting: %s"], item.clicks), GOLD[1], GOLD[2], GOLD[3])
    end
    if not Binding() and not item.rank and item.lower and #item.lower > 0 then
        local dim = ns.colors.dim
        GameTooltip:AddLine(Open(item.info.name) and Tr["Left-click to hide its ranks."]
            or Tr["Left-click to show its ranks."],
            dim[1], dim[2], dim[3])
    end
    if not Binding() and Markable(item) then
        local dim, m = ns.colors.dim, Mode()
        if m == "all" then
            GameTooltip:AddLine(Tr["Kept on its top rank, as every spell is."], GOLD[1], GOLD[2], GOLD[3])
        elseif Marked(item.info.name) then
            GameTooltip:AddLine(m == "none" and Tr["Marked for top rank, but Top rank is off."]
                or Tr["Kept on its top rank on your bars."], GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(Tr["Shift+Right-click to unmark it."], dim[1], dim[2], dim[3])
        else
            GameTooltip:AddLine(Tr["Shift+Right-click to keep it on its top rank."], dim[1], dim[2], dim[3])
        end
    end
    if item.missing then
        GameTooltip:AddLine(item.lowerOn and format(Tr["%s is on your bars."], item.lowerOn)
            or Tr["Not on your action bars."],
            MISSING[1], MISSING[2], MISSING[3])
    end
    GameTooltip:Show()
end

-- A spell with ranks to show (a rank's own row has none)
local function Ranked(item)
    return item and not item.rank and not item.trainer and item.lower ~= nil and #item.lower > 0
end

-- A click on a spell or a rank: Click Casting open, either button binds
-- it; else the left shows or hides a spell's ranks (and does nothing on
-- the rest). The right casts: the secure button's, the client's.
local function Press(p, item, button, down)
    if Binding() then
        Bind(item)
    elseif button == "RightButton" and IsShiftKeyDown() and Markable(item) then
        -- marked on the release (the secure button sees the press too)
        if not down then
            Mark(item.info.name)
            Refresh(p)
        end
    elseif ns.Linking(button) and item.info and (item.info.spellID or item.info.actionID) then
        ns.LinkInChat(ns.SpellLink(item.info.spellID or item.info.actionID))
    elseif button == "LeftButton" and Ranked(item) then
        Fold(item.info.name)
        Refresh(p)
    end
end

-- (2026-11-26, the user's, /workspace/booklist-plates-sheet.png) A spell
-- is a card: glass over the page's floor (a dark tint the hatch shows
-- through, a light falling from its top, faint gold rims, a bright line
-- under its top), SIDE in from the window's sides with SPACE over and
-- under. An unfolded spell and its ranks are one card: the spell's row has
-- its top, the last rank its foot. The card is c.hit, so the secure
-- button covers the card and nothing round it.
--
-- Its marks are chips on the second line after the rank: top rank (a
-- double chevron and "Top rank"; blue while Top rank keeps the marked) and the
-- click-cast binding (a mouse and its clicks).
--
--   spell   +--------------------------------------------------------+
--           | [icon] Lightning Bolt >                      2.5 sec |
--           |  [4]   Rank 4 [^ Top rank] [mouse Alt+Left]  100 Mana |
--   rank    |    |-- Rank 3                3 sec         155 Mana  |
--           |    '-- Rank 1              1.5 sec          25 Mana  |
--           +--------------------------------------------------------+

-- a chip: a small well with a gold rim, its glyph, its words
local function Chip(c, glyph)
    local h = CreateFrame("Frame", nil, c)
    h:SetHeight(CHIP_H)
    h:SetFrameLevel(c:GetFrameLevel() + 2)
    local rim = h:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    local well = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.9)
    h.glyph = h:CreateTexture(nil, "ARTWORK")
    h.glyph:SetPoint("LEFT", 4, 0)
    h.glyph:SetTexture(ns.media .. "strips\\" .. glyph)
    h.text = ns.Text(h, 9)
    h.text:SetPoint("LEFT", h.glyph, "RIGHT", 3, 0)
    h.text:SetJustifyH("LEFT")
    h.text:SetWordWrap(false)
    h:Hide()
    -- its words, a colour, and the most it may take: its width to fit
    function h.Say(words, col, most)
        h.text:SetText(words)
        h.text:SetTextColor(col[1], col[2], col[3])
        h.glyph:SetVertexColor(col[1], col[2], col[3])
        local fixed = 4 + (h.glyph:GetWidth() or 0) + 3 + 5
        local tw = math.ceil(h.text:GetStringWidth() or 0)
        if most then tw = math.max(0, math.min(tw, most - fixed)) end
        h.text:SetWidth(tw)
        h:SetWidth(fixed + tw)
        return fixed + tw
    end
    return h
end

-- A row, pooled: one frame for each kind, its parts shown for the kind.
local function Row(p, win, i)
    local c = CreateFrame("Button", nil, win.scroller.child)
    c:SetFrameLevel(win.scroller.child:GetFrameLevel() + 3)
    -- the card (what the secure button covers); Place sets its insets
    c.hit = CreateFrame("Frame", nil, c)
    c.hit:SetPoint("TOPLEFT", SIDE, -SPACE)
    c.hit:SetPoint("BOTTOMRIGHT", -SIDE, SPACE)
    local hit = c.hit
    local ink = ns.colors.ink
    c.fill = c:CreateTexture(nil, "BACKGROUND", nil, -5)
    c.fill:SetAllPoints(hit)
    c.fill:SetColorTexture(ink[1], ink[2], ink[3], GLASS.fill)
    -- the light, from the card's top down over its spell's row
    c.sheen = c:CreateTexture(nil, "BACKGROUND", nil, -4)
    c.sheen:SetPoint("TOPLEFT", hit)
    c.sheen:SetPoint("TOPRIGHT", hit)
    c.sheen:SetHeight(SPELL / 2)
    if c.sheen.SetGradient and CreateColor then
        c.sheen:SetColorTexture(1, 1, 1, 1)
        c.sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, GLASS.sheen))
    else
        c.sheen:SetColorTexture(1, 1, 1, GLASS.sheen / 2)
    end
    local function Rim(a1, a2, across)
        local t = c:CreateTexture(nil, "BORDER")
        t:SetPoint(a1, hit)
        t:SetPoint(a2, hit)
        if across then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], GLASS.edge)
        return t
    end
    c.rimL = Rim("TOPLEFT", "BOTTOMLEFT")
    c.rimR = Rim("TOPRIGHT", "BOTTOMRIGHT")
    c.rimT = Rim("TOPLEFT", "TOPRIGHT", true)
    c.rimB = Rim("BOTTOMLEFT", "BOTTOMRIGHT", true)
    c.shine = c:CreateTexture(nil, "BORDER", nil, 1)
    c.shine:SetPoint("TOPLEFT", hit, 1, -1)
    c.shine:SetPoint("TOPRIGHT", hit, -1, -1)
    c.shine:SetHeight(1)
    c.shine:SetColorTexture(1, 1, 1, GLASS.shine)
    -- a spell: its icon (stacked when it has ranks to show), its words
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.edge = c:CreateTexture(nil, "BACKGROUND", nil, 5)
    c.edge:SetPoint("TOPLEFT", c.icon, -1, 1)
    c.edge:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
    -- a spell with ranks: how many on a plate at the icon's foot (the
    -- gear slots' item level's look), a chevron after its name
    c.plate = CreateFrame("Frame", nil, c)
    c.plate:SetSize(14, 12)
    c.plate:SetPoint("CENTER", c.icon, "BOTTOM", 0, 0)
    c.plate:SetFrameLevel(c:GetFrameLevel() + 2)
    local pe = c.plate:CreateTexture(nil, "BACKGROUND")
    pe:SetAllPoints()
    pe:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local pw = c.plate:CreateTexture(nil, "BACKGROUND", nil, 1)
    pw:SetPoint("TOPLEFT", 1, -1)
    pw:SetPoint("BOTTOMRIGHT", -1, 1)
    pw:SetColorTexture(0.055, 0.05, 0.04, 0.95)
    c.plate.text = ns.Text(c.plate, 9)
    c.plate.text:SetPoint("CENTER", 0, 0)
    c.plate.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.chev = c:CreateTexture(nil, "ARTWORK")
    c.chev:SetSize(9, 9)
    c.chev:SetTexture(ns.media .. "strips\\chevron-down")
    c.chev:SetTexCoord(6 / 32, 26 / 32, 6 / 32, 26 / 32)
    -- an open spell and its ranks: a gold bar down the card's inner edge, a
    -- soft wash brightening outwards
    c.bar = c:CreateTexture(nil, "BORDER", nil, 2)
    c.bar:SetWidth(2)
    c.bar:SetPoint("TOPLEFT", hit)
    c.bar:SetPoint("BOTTOMLEFT", hit)
    c.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    c.gwash = c:CreateTexture(nil, "BACKGROUND", nil, -3)
    c.gwash:SetAllPoints(hit)
    if c.gwash.SetGradient and CreateColor then
        c.gwash:SetColorTexture(1, 1, 1, 1)
        c.gwash:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0),
            CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.14))
    else
        c.gwash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.07)
    end
    -- its marks, as chips (the chevrons point down: turned up; each glyph
    -- cut to its drawing)
    c.topChip = Chip(c, "chevron-double")
    c.topChip.glyph:SetTexCoord(7 / 32, 25 / 32, 27 / 32, 6 / 32)
    c.topChip.glyph:SetSize(8, 9)
    c.clickChip = Chip(c, "mouse")
    c.clickChip.glyph:SetTexCoord(8 / 32, 24 / 32, 5 / 32, 27 / 32)
    c.clickChip.glyph:SetSize(7, 10)
    -- while Click Casting is open, round a spell it can bind: a gold halo
    c.halo = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.halo:SetPoint("TOPLEFT", c.icon, -4, 4)
    c.halo:SetPoint("BOTTOMRIGHT", c.icon, 4, -4)
    c.halo:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    c.halo:Hide()
    c.name = ns.Text(c, 12)
    c.name:SetPoint("TOPLEFT", hit, "TOPLEFT", INDENT + ICON + 8, -5)
    c.name:SetPoint("RIGHT", hit, "RIGHT", -RIGHT, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    -- the second line: its words as wide as they are, the chips after
    c.sub = ns.Text(c, 10)
    c.sub:SetPoint("BOTTOMLEFT", hit, "TOPLEFT", INDENT + ICON + 8, -(SPELL - 5))
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(false)
    c.sub:SetTextColor(unpack(ns.colors.dim))
    c.cast = ns.Text(c, 11)
    c.cast:SetPoint("TOPRIGHT", hit, "TOPRIGHT", -EDGE, -5)
    c.cast:SetJustifyH("RIGHT")
    c.cost = ns.Text(c, 10)
    c.cost:SetPoint("BOTTOMRIGHT", hit, "TOPRIGHT", -EDGE, -(SPELL - 5))
    c.cost:SetJustifyH("RIGHT")
    c.cost:SetTextColor(unpack(BLUE))
    -- a rank: on a tree from under its spell's icon (a stem down, a
    -- branch to its name; the last's stem stops at its branch), its
    -- numbers on one line, a faint line between the ranks
    c.stem = c:CreateTexture(nil, "ARTWORK")
    c.stem:SetWidth(1)
    c.stem:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.branch = c:CreateTexture(nil, "ARTWORK")
    c.branch:SetHeight(1)
    c.branch:SetPoint("LEFT", hit, "LEFT", INDENT + ICON / 2, 0)
    c.branch:SetWidth(14)
    c.branch:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.rhair = c:CreateTexture(nil, "BACKGROUND", nil, -2)
    c.rhair:SetHeight(1)
    c.rhair:SetPoint("BOTTOMLEFT", hit, "BOTTOMLEFT", INDENT + ICON + 8, 0)
    c.rhair:SetPoint("BOTTOMRIGHT", hit, "BOTTOMRIGHT", -4, 0)
    c.rhair:SetColorTexture(FAINT[1], FAINT[2], FAINT[3], 1)
    -- a group's heading, as a book's: its name underlined in its ink, its
    -- count after, and under both a rule on to the edge
    c.hname = ns.Text(c, 13)
    c.hname:SetPoint("BOTTOMLEFT", 6, 9)
    c.hcount = ns.Text(c, 10)
    c.hcount:SetPoint("BOTTOMLEFT", c.hname, "BOTTOMRIGHT", 8, 0)
    c.hcount:SetTextColor(unpack(ns.colors.dim))
    c.hunder = c:CreateTexture(nil, "BORDER")
    c.hunder:SetHeight(1)
    c.hunder:SetPoint("TOPLEFT", c.hname, "BOTTOMLEFT", 0, -2)
    c.hunder:SetPoint("TOPRIGHT", c.hname, "BOTTOMRIGHT", 0, -2)
    c.hline = c:CreateTexture(nil, "BACKGROUND")
    c.hline:SetHeight(1)
    c.hline:SetPoint("BOTTOMLEFT", 6, 4)
    c.hline:SetPoint("BOTTOMRIGHT", 0, 4)
    c.hline:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    c.rank = ns.Text(c, 11)
    c.rank:SetPoint("LEFT", hit, "LEFT", INDENT + ICON + 8, 0)
    c.rcast = ns.Text(c, 10)
    c.rcast:SetPoint("RIGHT", hit, "RIGHT", -(EDGE + 96), 0)
    c.rcast:SetJustifyH("RIGHT")
    c.rcast:SetTextColor(unpack(ns.colors.dim))
    c.rcost = ns.Text(c, 10)
    c.rcost:SetPoint("RIGHT", hit, "RIGHT", -EDGE, 0)
    c.rcost:SetJustifyH("RIGHT")
    c.rcost:SetTextColor(unpack(BLUE))
    c.glow = c:CreateTexture(nil, "HIGHLIGHT")
    c.glow:SetAllPoints(hit)
    c.glow:SetColorTexture(1, 1, 1, 0.08)
    -- A spell, in combat (the secure layer away) or cut by the scroll's
    -- edge: the left button shows or hides its ranks, the right casts
    -- nothing; Click Casting open, either binds
    c:SetScript("OnClick", function(self, button)
        if self.item then Press(p, self.item, button) end
    end)
    c:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- an empty window's one line
    c.empty = ns.Text(c, 11)
    c.empty:SetPoint("LEFT", INDENT + ICON + 8 + SIDE, 0)
    c.empty:SetTextColor(unpack(ns.colors.dim))
    c.empty:SetText(Tr["None"])
    win.rows[i] = c
    return c
end

local PARTS = {
    spell = { "icon", "edge", "name", "sub", "cast", "cost" },
    rank = { "stem", "branch", "rank", "rcast", "rcost" },
    heading = { "hname", "hcount", "hunder", "hline" },
    none = { "empty" },
}
-- a card's parts: the spell's and the rank's rows
local CARD = { "fill", "rimL", "rimR" }
local function Kind(c, kind)
    for k, list in pairs(PARTS) do
        for _, part in ipairs(list) do c[part]:SetShown(k == kind) end
    end
    for _, part in ipairs({ "topChip", "clickChip", "halo", "plate", "chev", "bar", "gwash", "rhair",
        "sheen", "shine", "rimT", "rimB" }) do
        c[part]:Hide()
    end
    local card = kind == "spell" or kind == "rank"
    for _, part in ipairs(CARD) do c[part]:SetShown(card) end
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- a heading (or an empty window's line) is no button: no highlight
    -- under the pointer, no click
    local still = kind == "heading" or kind == "none"
    c:EnableMouse(not still)
    c.glow:SetShown(not still)
    c.kind = kind
end

-- A window's entries laid out top to bottom in its scroll's child, the
-- list's width (an empty window: its one None line); the rows left over
-- hidden. Its content's height kept for the windows' split (Layout). A
-- card's row has SPACE over it where the card begins (a spell) and under
-- it where it ends (a spell with no ranks open, a group's last rank): the
-- card itself is always SPELL or RANK tall.
local function Place(p, win, items)
    local width = W.width
    local y = 0
    if #items == 0 then items = { { none = true } } end
    for i, item in ipairs(items) do
        local c = win.rows[i] or Row(p, win, i)
        local nxt = items[i + 1]
        local card = not (item.heading or item.none)
        local over = card and not item.rank and SPACE or 0
        local under = card and not (nxt and nxt.rank) and SPACE or 0
        local h = item.heading and HEADING or item.rank and RANK or SPELL
        c.hit:ClearAllPoints()
        if card then
            c.hit:SetPoint("TOPLEFT", SIDE, -over)
            c.hit:SetPoint("BOTTOMRIGHT", -SIDE, under)
            h = h + over + under
        else
            c.hit:SetPoint("TOPLEFT", 0, 0)
            c.hit:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        c.over, c.under = over, under
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetSize(width, h)
        c.y, c.h = y, h
        c:Show()
        y = y + h
    end
    for i = #items + 1, #win.rows do
        win.rows[i].item = nil
        win.rows[i]:Hide()
    end
    win.scroller.child:SetSize(width, math.max(1, y))
    win.content = y
    return items
end

-- -------------------------------------------------------- the secure layer
-- One secure button per row in view, over it: the cast is the client's.
local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    -- the right button casts; the left shows a spell's ranks, and drags
    -- (Follow: in bind mode either binds)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown")
    -- cast on the release, whatever ActionButtonUseKeyDown says: a press
    -- held to drag the spell to a bar casts nothing
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.item and not InCombatLockdown() then
            SB.PickupSpellBookItem(self.item.slot, self.item.bank)
        end
    end)
    b:SetScript("PostClick", function(self, button, down)
        -- binding: once a click, on its release (the press comes here too)
        if down and Binding() then return end
        if self.item then Press(self.page, self.item, button, down) end
    end)
    b:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.08)
    layer.buttons[i] = b
    return b
end

-- What a row's button casts on the right button: a spell or a flyout, or
-- nothing (a passive, one not learned yet). type2, not type: the left
-- button (type1, else type) finds nothing, and casts nothing. A spell by
-- the book's own ID (actionID), the one learned: its spellID can be a
-- replacement the client will not cast from a button (Ghost Wolf's,
-- 1238640 for 2645). A pet's by its spell's.
local function Arm(b, item)
    local info = item and item.info
    local kind, what
    if info and not info.isPassive then
        if info.itemType == TYPE.Spell then
            kind, what = "spell", info.actionID or info.spellID
        elseif info.itemType == TYPE.PetAction then
            kind, what = "spell", info.spellID or info.actionID
        elseif info.itemType == TYPE.Flyout then
            kind, what = "flyout", info.actionID
        end
    end
    b:SetAttribute("type", nil)
    b:SetAttribute("type2", kind)
    b:SetAttribute("spell", what)
    -- Shift+Right on a spell that can be marked casts nothing: a type no
    -- handler has, so only PostClick (Press) answers it
    b:SetAttribute("shift-type2", Markable(item) and "medaluiTopRank" or nil)
end

-- Out of combat only: a button over each spell or rank row wholly in view,
-- armed; the rest away. A row the scroll's edge cuts has none (it casts
-- nothing) until it scrolls into view. The layer is shown while
-- the window is open (a driver hides it in combat), and hidden when it
-- closes.
local function Follow()
    if not layer or InCombatLockdown() then return end
    local p = W.Current()
    local wins = open and p and p.casts and p.wins or {}
    local n = 0
    for _, win in ipairs(wins) do
        local s = win.scroller
        local top = s.offset or 0
        local bottom = top + (s.scroll:GetHeight() or 0)
        for _, c in ipairs(win.rows) do
            local item = c:IsShown() and c.item
            if item and c.y >= top - 0.5 and c.y + c.h <= bottom + 0.5 then
                n = n + 1
                local b = Secure(n)
                b.item, b.page = item, p
                -- Click Casting open: nothing cast, the click binds (Press)
                Arm(b, not Binding() and item or nil)
                if Binding() then
                    b:RegisterForClicks("AnyUp", "AnyDown")
                else
                    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown")
                end
                b:SetShown(W.Over(b, c.hit))
            end
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.item = nil
        Arm(b, nil)
        b:Hide()
    end
    if open then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ------------------------------------------------------------------- tabs
-- The panel under the head (2026-11-19, /workspace/spec-tabs-B.png): a
-- tab for each section, joined across, the console's box round them; in
-- each its role's gem, its name and its count under, the open one held
-- (a gold wash, a gold line under its words).
local function Gem(parent)
    local g = {}
    g.rim = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    g.rim:SetSize(9, 9)
    g.rim:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    g.stone = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    g.stone:SetSize(7, 7)
    g.stone:SetPoint("CENTER", g.rim)
    if g.rim.SetRotation then
        g.rim:SetRotation(math.pi / 4)
        g.stone:SetRotation(math.pi / 4)
    end
    return g
end

local function Cell(p, i)
    local t = CreateFrame("Button", nil, p.specs)
    t.wash = t:CreateTexture(nil, "BACKGROUND", nil, 3)
    t.wash:SetPoint("TOPLEFT", 0, 0)
    t.wash:SetPoint("BOTTOMRIGHT", 0, 0)
    t.wash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.3)
    t.line = t:CreateTexture(nil, "ARTWORK")
    t.line:SetHeight(2)
    t.line:SetPoint("BOTTOMLEFT", 10, 1)
    t.line:SetPoint("BOTTOMRIGHT", -10, 1)
    t.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    t.split = t:CreateTexture(nil, "BORDER")
    t.split:SetWidth(1)
    t.split:SetPoint("TOPLEFT", -1, 0)
    t.split:SetPoint("BOTTOMLEFT", -1, 0)
    t.split:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    t.name = ns.Text(t, 12)
    t.name:SetPoint("CENTER", 0, 7)
    t.name:SetWordWrap(false)
    -- the gem beside the count, so a long name has the whole width
    t.count = ns.Text(t, 9)
    t.count:SetPoint("CENTER", 6, -9)
    t.gem = Gem(t)
    t.gem.rim:SetPoint("RIGHT", t.count, "LEFT", -6, 0)
    -- a glyph's tab: its section's icon over its count, for its name
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(20, 20)
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local glow = t:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.06)
    t:SetScript("OnClick", function(self)
        if not self.section then return end
        Hold(p, self.section.name)
        for _, win in ipairs(p.wins or {}) do win.scroller.To(0, true) end
        Refresh(p)
    end)
    t:SetScript("OnEnter", function(self)
        local sec = self.section
        if not sec then return end
        ns.Tip(self, ns.window.OutsideTop, { title = sec.name, color = GOLD,
            sec.glyph and { "body", p.trainer and format("%d/%d", sec.now or 0, sec.count)
                or ns.Plural(sec.count, format(Tr["%d |4spell:spells;"], sec.count)) } or nil,
            sec.role and { "body", ROLE_WORD[sec.role] } or nil })
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.specs.cells[i] = t
    return t
end

-- the tabs as the sections now are, each a share of the panel's width;
-- a name too wide drops a size or three (the gem is on the count's line).
-- (2026-11-25, /workspace/spec-rows-B.png, the user's: no more than three
-- to a row) the specs share the top row; General's and the pet's (the
-- glyphs) a slim strip under them, each half of it (or all), its icon,
-- its name and its count on one line. None: the specs the panel's height.
local function Strip(panel)
    if panel.strip then return panel.strip end
    local s = {}
    local ink = ns.colors.ink
    s.fill = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    s.fill:SetPoint("BOTTOMLEFT", 1, 1)
    s.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    s.fill:SetHeight(STRIP_H - 1)
    s.fill:SetColorTexture(ink[1], ink[2], ink[3], 0.35)
    s.rule = panel:CreateTexture(nil, "BORDER")
    s.rule:SetHeight(1)
    s.rule:SetPoint("BOTTOMLEFT", 0, STRIP_H)
    s.rule:SetPoint("BOTTOMRIGHT", 0, STRIP_H)
    s.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    panel.strip = s
    return s
end

function Tabs(p)
    local panel = p.specs
    if not panel then return end
    local list = {}
    for _, sec in ipairs(p.sections or {}) do if sec.glyph then table.insert(list, sec) end end
    local glyphs = #list
    for _, sec in ipairs(p.sections or {}) do if not sec.glyph then table.insert(list, sec) end end
    local width = (panel:GetWidth() or 0) > 0 and panel:GetWidth() or (W.width + 2 * ns.window.pad)
    -- the medallion and its step stand over the inner end (the left: the
    -- book is on the right): that cell's words centred in what they leave
    local clear = (W.step or 40) + 6    -- the step under the head, from the inner edge
    local strip = Strip(panel)
    strip.fill:SetShown(glyphs > 0)
    strip.rule:SetShown(glyphs > 0)
    local specs = #list - glyphs
    local tall = glyphs > 0 and SPECS_H or SPECS_H + STRIP_H
    for i, sec in ipairs(list) do
        local t = panel.cells[i] or Cell(p, i)
        -- k of n in its row; the row's first is under the medallion's step
        local k, n, y, h
        if sec.glyph then
            k, n, y, h = i, glyphs, -SPECS_H, STRIP_H
        else
            k, n, y, h = i - glyphs, specs, 0, tall
        end
        local x0 = math.floor((k - 1) * width / n)
        local x1 = math.floor(k * width / n)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, y)
        t:SetSize(x1 - x0, h)
        t.section = sec
        local held = sec == p.held
        t.wash:SetShown(held)
        t.line:SetShown(held)
        t.split:SetShown(k > 1)
        local first = k == 1
        local shift = first and clear / 2 or 0
        t.icon:SetShown(sec.glyph and true or false)
        t.count:SetShown(not sec.glyph)
        t.gem.rim:SetShown(not sec.glyph)
        t.gem.stone:SetShown(not sec.glyph)
        t.name:ClearAllPoints()
        if sec.glyph then
            -- its icon, then "General  ·  10", centred in its share
            t.icon:SetSize(16, 16)
            t.icon:SetTexture(sec.icon or 134400)
            t.icon:SetDesaturated(not held)
            t.icon:SetAlpha(held and 1 or 0.7)
            t.name:SetPoint("CENTER", shift + 11, 0)
            t.icon:ClearAllPoints()
            t.icon:SetPoint("RIGHT", t.name, "LEFT", -6, 0)
        else
            t.name:SetPoint("CENTER", shift, 7)
            t.count:ClearAllPoints()
            t.count:SetPoint("CENTER", shift + 6, -9)
        end
        local room = (x1 - x0) - 10 - (first and clear or 0) - (sec.glyph and 22 or 0)
        local size = 12
        -- (a trainer's tab: what can be learned now of all still to learn,
        -- as "2/7"; 2026-11-22, the words were cramped)
        local words = p.trainer and format("%d/%d", sec.now or 0, sec.count)
            or sec.glyph and tostring(sec.count)
            or ns.Plural(sec.count, format(Tr["%d |4spell:spells;"], sec.count))
        t.name:SetFont(ns.font, size, "")
        t.name:SetText(sec.glyph and (sec.name .. "  \194\183  " .. words) or sec.name)
        while size > 9 and (t.name:GetStringWidth() or 0) > room do
            size = size - 1
            t.name:SetFont(ns.font, size, "")
        end
        t.name:SetWidth(math.min(room, math.ceil(t.name:GetStringWidth() or 0) + 1))
        local col = ROLE[sec.role] or GOLD_D
        t.gem.stone:SetColorTexture(col[1], col[2], col[3], 1)
        local c = held and GOLD or ns.colors.dim
        t.name:SetTextColor(c[1], c[2], c[3])
        t.count:SetText(words)
        local cc = held and ns.colors.dim or OFF
        t.count:SetTextColor(cc[1], cc[2], cc[3])
        t:Show()
    end
    for i = #list + 1, #panel.cells do
        panel.cells[i].section = nil
        panel.cells[i]:Hide()
    end
    panel:SetShown(#list > 0)
end

-- the tabs in the panel the shell joins under the head (p.panel, spec
-- under: its box the shell's)
local function Panel(p)
    local panel = p.panel
    panel.cells = {}
    panel:HookScript("OnSizeChanged", function() if p.sections then Tabs(p) end end)
    p.specs = panel
    return panel
end

-- (2026-11-26, /workspace/booklist-windows-sheet.png) A window of the
-- list, on the page's floor: a faint gold edge, a dark title band with its
-- name (red: Not on your bars) and its count at the right over a gold
-- rule, and under it its own scroll, its bar out by the rail beside it.
local function Win(p, body, key, title, red)
    local win = { key = key, title = title, rows = {}, content = 0 }
    local f = CreateFrame("Frame", nil, body)
    f:SetPoint("LEFT")
    f:SetPoint("RIGHT")
    -- (2026-11-26, the user's) no floor of its own: the page's shows
    -- through it and its cards; a faint gold edge round it
    ns.window.Edge(f)
    local ink = ns.colors.ink
    f.band = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    f.band:SetPoint("TOPLEFT", 1, -1)
    f.band:SetPoint("TOPRIGHT", -1, -1)
    f.band:SetHeight(TITLE_H - 1)
    f.band:SetColorTexture(ink[1], ink[2], ink[3], 0.6)
    f.rule = f:CreateTexture(nil, "BORDER")
    f.rule:SetHeight(1)
    f.rule:SetPoint("TOPLEFT", 0, -TITLE_H)
    f.rule:SetPoint("TOPRIGHT", 0, -TITLE_H)
    f.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    f.title = ns.Text(f, 13)
    f.title:SetPoint("LEFT", f, "TOPLEFT", 10, -TITLE_H / 2)
    f.title:SetText(title)
    local col = red and MISSING or GOLD
    f.title:SetTextColor(col[1], col[2], col[3])
    f.count = ns.Text(f, 11)
    f.count:SetPoint("RIGHT", f, "TOPRIGHT", -EDGE, -TITLE_H / 2)
    f.count:SetJustifyH("RIGHT")
    f.count:SetTextColor(unpack(ns.colors.dim))
    local inner = CreateFrame("Frame", nil, f)
    inner:SetPoint("TOPLEFT", 0, -(TITLE_H + 1))
    inner:SetPoint("BOTTOMRIGHT", 0, 1)
    win.frame, win.inner = f, inner
    win.scroller = ns.window.Scroller(inner, 0, true)
    -- the buttons over the rows follow them as they scroll
    if p.casts then win.scroller.Moved = function() Follow() end end
    inner:EnableMouseWheel(true)
    inner:SetScript("OnMouseWheel", function(_, delta) win.scroller.To(win.scroller.target - delta * STEP) end)
    return win
end

-- The windows' heights: each fits its rows while both do, the floor bare
-- under them. When they cannot (2026-11-26, the user's: Not on your bars
-- the longer when it has a lot), Not on your bars has what it needs up to
-- LEAN of the room (all it needs when On your bars is short), On your bars
-- the rest; neither less than its title and two spells while the room
-- holds both so, else split at LEAN.
local function Layout(p)
    local wins = p.wins
    if not wins then return end
    local room = math.max(0, (p.listBody:GetHeight() or 0) - GAP)
    local miss, placed = wins[1], wins[2]
    local a, b = TITLE_H + 1 + miss.content + 1, TITLE_H + 1 + placed.content + 1
    local least = TITLE_H + 2 + 2 * SPELL
    -- (no "do both fit" test before it: when they do, room - b >= a and
    -- this gives each its own; a sweep measured the test and the formula alone
    -- as one)
    local ha = math.min(a, math.max(math.floor(room * LEAN), room - b))
    local fa, fb = math.min(a, least), math.min(b, least)
    if fa + fb <= room then
        -- (Not on your bars is never under fa here: LEAN of a room holding
        -- both floors is over it, and room - b is when On your bars is
        -- short; a sweep measured a math.max(fa, ...) as changing nothing)
        ha = math.min(ha, room - fb)
    else
        ha = math.min(a, math.floor(room * LEAN))
    end
    local hb = math.max(0, math.min(b, room - ha))
    miss.frame:ClearAllPoints()
    miss.frame:SetPoint("TOPLEFT", p.listBody, "TOPLEFT", 0, 0)
    miss.frame:SetPoint("TOPRIGHT", p.listBody, "TOPRIGHT", 0, 0)
    miss.frame:SetHeight(math.max(1, ha))
    placed.frame:ClearAllPoints()
    placed.frame:SetPoint("TOPLEFT", miss.frame, "BOTTOMLEFT", 0, -GAP)
    placed.frame:SetPoint("TOPRIGHT", miss.frame, "BOTTOMRIGHT", 0, -GAP)
    placed.frame:SetHeight(math.max(1, hb))
    for _, win in ipairs(wins) do win.scroller.To(win.scroller.target) end
end

-- ------------------------------------------------------------------ pages
local Band
-- A spell's second line: its words as wide as they are, then its chips,
-- Top (in its colour) and the clicks; all left of the cost's column. Short
-- of room the clicks' words shorten, and past that their chip goes, then
-- Top's. Nothing on it: the name stands at the card's middle.
local function Second(c, sub, topColor, clicks)
    local room = (W.width or 300) - 2 * SIDE - (INDENT + ICON + 8) - RIGHT
    c.sub:SetText(sub or "")
    local x = 0
    if sub then
        x = math.min(math.ceil(c.sub:GetStringWidth() or 0), room)
        c.sub:SetWidth(x)
        x = x + 6
    end
    local function Put(chip, words, col)
        chip:Hide()
        if not words or room - x < 2 * CHIP_H then return end
        local w = chip.Say(words, col, room - x)
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", c.hit, "TOPLEFT", INDENT + ICON + 8 + x, -(SPELL - 11))
        chip:Show()
        x = x + w + 4
    end
    Put(c.topChip, topColor and Tr["Top rank"], topColor)
    Put(c.clickChip, clicks, GOLD)
    c.name:ClearAllPoints()
    if sub or topColor or clicks then
        c.name:SetPoint("TOPLEFT", c.hit, "TOPLEFT", INDENT + ICON + 8, -5)
    else
        c.name:SetPoint("LEFT", c.hit, "LEFT", INDENT + ICON + 8, 0)
    end
    c.name:SetPoint("RIGHT", c.hit, "RIGHT", -RIGHT, 0)
end

-- a window's rows drawn: its entries, as Place laid them out
local function Draw(p, win, items, binding, bound, ready)
    for i, item in ipairs(items) do
        local c = win.rows[i]
        local nxt = items[i + 1]
        if item.none then
            Kind(c, "none")
            c.item = nil
        elseif item.heading then
            Kind(c, "heading")
            c.item = nil
            c.hname:SetText(item.heading)
            local hc = GOLD
            c.hname:SetTextColor(hc[1], hc[2], hc[3])
            c.hunder:SetColorTexture(hc[1], hc[2], hc[3], 0.9)
            c.hcount:SetText("· " .. tostring(item.count))
        else
            Kind(c, item.rank and "rank" or "spell")
            c.item = item
            local info = item.info
            local cast, cost = Costs(item)
            -- its card: the top (its rim, the light, the bright line) on a
            -- spell's row, the foot where Place left space under it
            c.sheen:SetShown(not item.rank)
            c.shine:SetShown(not item.rank)
            c.rimT:SetShown(not item.rank)
            c.rimB:SetShown(c.under > 0)
            -- an open spell and its ranks: the bar and the wash
            local group = item.rank or Ranked(item) and Open(info.name)
            c.bar:SetShown(group and true or false)
            c.gwash:SetShown(group and true or false)
            if item.rank then
                c.rank:SetText(info.subName ~= "" and info.subName or info.name)
                c.rcast:SetText(cast or "")
                c.rcost:SetText(cost or "")
                -- the tree: the last rank's stem stops at its branch
                local last = not (nxt and nxt.rank)
                c.stem:ClearAllPoints()
                c.stem:SetPoint("TOPLEFT", c.hit, "TOPLEFT", INDENT + ICON / 2, 0)
                if last then
                    c.stem:SetPoint("BOTTOMLEFT", c.hit, "LEFT", INDENT + ICON / 2, 0)
                else
                    c.stem:SetPoint("BOTTOMLEFT", c.hit, "BOTTOMLEFT", INDENT + ICON / 2, 0)
                end
                c.rhair:SetShown(not last)
                -- in bind mode, a rank it cannot bind greyed; the highest gold
                local grey = binding and not Bindable(item)
                local top = item.of and item.info == item.of.info
                c.rank:SetTextColor(unpack(grey and ns.colors.dim or top and GOLD or ns.colors.text or { 1, 1, 1 }))
            else
                local ranks = Ranked(item) and #item.lower + 1 or 0
                local unfolded = ranks > 1 and Open(info.name)
                -- with ranks: how many on the plate, the chevron after the
                -- name (down and gold while they show)
                c.icon:ClearAllPoints()
                c.icon:SetSize(ICON, ICON)
                c.icon:SetPoint("LEFT", c.hit, "LEFT", INDENT, 0)
                c.plate:SetShown(ranks > 1)
                c.chev:SetShown(ranks > 1)
                if ranks > 1 then
                    c.plate.text:SetText(tostring(ranks))
                    c.plate:SetWidth(math.max(14, math.floor((c.plate.text:GetStringWidth() or 0) + 8)))
                    local ch = unfolded and GOLD or GOLD_D
                    c.chev:SetVertexColor(ch[1], ch[2], ch[3])
                    if c.chev.SetRotation then c.chev:SetRotation(unfolded and 0 or math.pi / 2) end
                end
                c.icon:SetTexture(info.iconID)
                local learned = info.itemType ~= TYPE.FutureSpell
                if item.trainer then learned = item.now end
                c.icon:SetDesaturated(not learned)
                c.icon:SetAlpha((learned and not info.isPassive) and 1 or 0.6)
                c.name:SetText(info.name)
                if ranks > 1 then
                    local room = (W.width or 300) - 2 * SIDE - (INDENT + ICON + 8) - RIGHT - 14
                    local tw = math.min(c.name:GetStringWidth() or 0, room)
                    c.chev:ClearAllPoints()
                    c.chev:SetPoint("CENTER", c.name, "LEFT", tw + 9, 0)
                end
                c.name:SetTextColor(unpack(learned and (info.isPassive and ns.colors.dim or GOLD) or ns.colors.dim))
                -- its rank (the trainer's), how many it has folded away, its click
                local sub
                if item.trainer then
                    sub = item.trainer.rank ~= "" and item.trainer.rank or nil
                else
                    sub = Sub(item)
                end
                item.clicks = Clicks(item, bound)
                -- marked for top rank: blue while Top rank is on its marks,
                -- dim while it is on every spell or none
                local top = not binding and Markable(item) and Marked(info.name)
                Second(c, sub, top and (Mode() == "marked" and BLUE or ns.colors.dim), item.clicks)
                c.cast:SetText(cast or "")
                c.cast:SetTextColor(unpack(item.trainer and not item.now and ns.colors.dim
                    or ns.colors.text or { 1, 1, 1 }))
                c.cost:SetText(cost or "")
                -- on no bar (Grouped asked; in bind mode none): a red ring
                local edge = item.missing and MISSING or GOLD_D
                c.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
                c.edge:ClearAllPoints()
                c.edge:SetPoint("TOPLEFT", c.icon, -1, 1)
                c.edge:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
                -- Click Casting open: what it can bind lit (a halo while a
                -- slot waits), the rest grey
                local can = binding and Bindable(item)
                c.halo:SetShown(can and ready or false)
                if binding then
                    if can then
                        c.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
                    else
                        c.icon:SetDesaturated(true)
                        c.icon:SetAlpha(0.5)
                        c.name:SetTextColor(unpack(ns.colors.dim))
                    end
                end
            end
        end
    end
end

function Refresh(p)
    if not p.wins then return end
    Items(p)
    local macros = Macros()
    local binding = Binding()
    local lists = { Grouped(p, macros, binding) }
    local bound = ns.db.spellbookClickCast and ns.clickcast and { ns.clickcast.Bound() }
    local cbf = _G.ClickBindingFrame
    -- the halo while nothing is in the binder: pick one
    local ready = binding and cbf and ns.clickcast.Step and ns.clickcast.Step() == 1
    p.rows = {}
    for k, win in ipairs(p.wins) do
        local list = lists[k]
        win.frame.count:SetText(tostring(list.count))
        Draw(p, win, Place(p, win, list.items), binding, bound, ready)
        -- every row of both, in order (the windows' pools: the hidden too)
        for _, c in ipairs(win.rows) do table.insert(p.rows, c) end
    end
    Layout(p)
    Tabs(p)
    Band(p)
    Follow()
end

-- The margin, edge to edge (ns.window.Segments): Trainer, once a class
-- trainer has been read, which opens its page and, from it, goes back.
local trainerPage, back

-- Top rank's dialog over its button (ns.window.Choices, the quest log's
-- Sort's look): every spell, only those marked, none
local CHOICES = {
    { "all", Tr["Every spell"], Tr["Every spell on your bars rises to its highest rank as you learn it."] },
    { "marked", Tr["Marked"], Tr["Only the spells you mark: Shift+Right-click one in the book. A blue chevron on "
        .. "its icon shows it."] },
    { "none", Tr["None"], Tr["Your bars keep the ranks you put on them."] },
}
local topRank
function W.topRank() return topRank end

local function Controls(p, band)
    local row = ns.window.Segments(band, { height = band:GetHeight(), engraved = true, items = {
        { key = "trainer", label = Tr["Trainer"], click = function()
            if W.Current() == trainerPage then
                -- the page it came from, or the first with a tab
                local to = back and back.available and back
                for _, page in ipairs(W.pages) do
                    if not to and page.available and not page.tabless then to = page end
                end
                if to then W.Select(to) end
            else
                back = W.Current()
                W.Select(trainerPage)
            end
        end, tip = function()
            return W.Current() == trainerPage and Tr["Back to your spells."]
                or Tr["What your class trainer has still to teach you."]
        end },
        { key = "toprank", label = Tr["Top rank"], click = function(button)
            if button == "LeftButton" then topRank.Toggle() end
        end, tip = function()
            return format(Tr["Keeps spells on your action bars at their highest rank as you learn it: %s. Click "
                .. "to choose. Shift+Right-click a spell to mark it."], MODE_WORD[Mode()] or "")
        end },
    } })
    row:SetPoint("TOPLEFT")
    row:SetPoint("TOPRIGHT")
    p.margin = row
    topRank = topRank or ns.window.Choices({
        name = "MedalUISpellbookTopRank", title = Tr["Keep on top rank"], width = 240, choices = CHOICES,
        Get = Mode,
        Set = function(v) ns.SetOption("spellbookUpRank", v) end,
        -- over the page's own button: the page open now
        Anchor = function()
            local cur = W.Current()
            return cur and cur.margin and cur.margin.byKey.toprank
        end,
        Opened = function() local cur = W.Current() if cur then Band(cur) end end,
    })
    p.trainerButton = row.byKey.trainer
end

-- the margin's state: Trainer once read, marked while its page shows
function Band(p)
    if not p.margin then return end
    p.margin:Set("trainer", { selected = p.trainer, shown = ns.trainers.Visited() })
    p.margin:Set("toprank", { selected = topRank ~= nil and topRank.IsOpen() })
    if topRank then topRank.Mark() end
end

local function Page(spec)
    local p = spec
    p.rows = {}
    p.under = p.macros and SPECS_H or SPECS_H + STRIP_H   -- the tabs' panel (the macros' sets one row)
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    p.events = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_ICON", "PLAYER_LEVEL_UP",
        "UNIT_PET", "PET_BAR_UPDATE", "ACTIONBAR_SLOT_CHANGED", "PLAYER_MONEY" }
    function p.Build(body, foot, band)
        Controls(p, band)
        if p.macros then
            ns.macros.Build(p, body)
            return
        end
        -- the tabs' panel (joined under the head); the list in its two
        -- windows, each its bar out by the rail
        Panel(p)
        p.listBody = body
        -- (2026-11-26, the user's) the macros' floor under the whole page:
        -- the windows and their glass cards over it
        p.surface = CreateFrame("Frame", nil, body)
        p.surface:SetAllPoints()
        p.surface:SetFrameLevel(body:GetFrameLevel())
        ns.window.Floor(p.surface)
        p.wins = { Win(p, body, "missing", Tr["Not on your bars"], true), Win(p, body, "placed", Tr["On your bars"]) }
        body:HookScript("OnSizeChanged", function() Layout(p) Follow() end)
    end
    function p.Refresh()
        if p.macros then
            Band(p)
            ns.macros.Refresh()
            return
        end
        Refresh(p)
    end
    function p.Showing(on)
        if on then open = true elseif W.Current() == p then open = false end
        Follow()
        if p.macros then ns.macros.Showing(on) end
    end
    W.Page(p)
end

-- the book: every skill line, then the pet's
do
    local p = { key = "book", casts = true, order = 1, label = Tr["Spellbook"], glyph = "spellbook",
        frame = "SpellBookFrame" }
    function p.Available() return SB ~= nil end
    Page(p)
end
-- macros: the game's macro window (spells/macros.lua)
do
    local p = { key = "macros", macros = true, order = 2, label = Tr["Macros"], glyph = "log",
        frame = "SpellBookFrame" }
    function p.Available() return SB ~= nil end
    Page(p)
end
-- what the class trainers have still to teach, once one has been visited
do
    local p = { key = "trainer", trainer = true, tabless = true, order = 3, label = Tr["Trainer"],
        frame = "SpellBookFrame", icon = 136243 }
    function p.Available() return ns.trainers.Visited() end
    Page(p)
    trainerPage = p
end

function W.Refresh()
    local p = W.Current()
    if p and W.window:IsShown() then p.Refresh() end
end

local function Start()
    -- Forever's micro menu has a spellbook button of its own; retail's has
    -- one player-spells button for its combined frame
    if not ns.db.spellbook or not SpellbookMicroButton or not SB or not SB.GetSpellBookSkillLineInfo then return end
    W.Build()
    layer = W.Layer("MedalUISpellbookCasts")
    W.layer = layer
    -- Top rank's dialog shuts with the book
    W.window:HookScript("OnHide", function() if topRank then topRank.Close() end end)
    for _, p in ipairs(W.pages) do
        if p.available then W.Select(p); break end
    end
    -- the skill lines and the pet come and go
    for _, e in ipairs({ "SPELLS_CHANGED", "UNIT_PET", "PET_BAR_UPDATE" }) do
        ns.On(e, function() W.Retab() end)
    end
    ns.On("PLAYER_REGEN_ENABLED", function()
        Follow()
        if pending then UpRank() end
    end)
    -- a rank learned rises on the bars; a trainer read brings its button
    for _, e in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED" }) do ns.On(e, UpRank) end
    ns.OnSetting("spellbookUpRank", function(m) if m ~= "none" then UpRank() end end)
    for _, key in ipairs({ "spellbookMissing", "spellbookUpRank", "spellbookClickCast" }) do
        ns.OnSetting(key, function() W.Refresh() end)
    end
    for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do
        ns.On(e, function()
            W.Retab()
            W.Refresh()
        end)
    end
    -- click casting: its bindings saved or reset, its window open or shut,
    -- a slot waiting or filled
    local function Again() W.Refresh() end
    if C_ClickBindings then
        for _, fn in ipairs({ "SetProfileByInfo", "ResetCurrentProfile" }) do
            if C_ClickBindings[fn] then hooksecurefunc(C_ClickBindings, fn, Again) end
        end
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ClickBindingFrame.UpdateFrames", Again, W)
    end
    if ns.clickcast then ns.clickcast.Stepped = Again end
    local watched
    local function Watch()
        local f = _G.ClickBindingFrame
        if watched or not f then return end
        watched = true
        f:HookScript("OnShow", Again)
        f:HookScript("OnHide", Again)
    end
    Watch()
    ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_ClickBindingUI" then Watch() end end)
    ns.PlayerSpellsTab("SpellBook", W)
end

ns.On("PLAYER_LOGIN", Start)
