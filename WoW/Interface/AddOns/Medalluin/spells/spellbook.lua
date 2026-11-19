-- The spellbook: Medalluin's own (the shell is window/shell.lua), standing
-- on the right strip over the side panel's place, its margin beside the
-- backpack's medallion. Forever only: retail's spellbook is one of its
-- player-spells frame's pages, and keeps Blizzard's.
--
--   (o) 1 of 2              Spellbook                          v | x
--   +---------------+---------------+---------------+-------------+
--   | <> General    | <> Elemental  |<> Enhancement | <> Restor.. |
--   |    9 spells   |   11 spells   |   13 spells   |   9 spells  |
--   +---------------+---------------+=====[held]====+-------------+
--   Not on your bars 2 ---------------------------------------------
--     [icon] Attack                                     Instant   |
--     ------------------------------------------------------------ | (bar,
--   On your bars 6 ------------------------------------------------ |  in the
--   | [icon] Healing Wave v                               3 sec   |  margin)
--   |  [5]   Rank 5 · Shift+Middle                     200 Mana   |
--   |    |-- Rank 5                       3 sec        200 Mana
--   |    '-- Rank 1                     1.5 sec         25 Mana
--   ...
--   ---------------------------------------------------------------
--   [Trainer]                                            (backpack)
--
-- (2026-11-19, /workspace/spec-tabs-B.png) A panel under the head holds a
-- tab for each skill line the book shows (General, then each
-- specialisation) and Pet last while the pet has spells: its role's gem
-- (damage red, healer green, tank blue; General and the pet the theme's
-- brown), its name, its count; the open one held (MedalluinCharDB.bookTab,
-- by name, each page its own). Under it that line's spells, on hairlines,
-- scrolled, the bar out in the window's margin by the rail (Scroller's
-- outside), under headings (2026-11-19, mockup B of
-- /workspace/booklist-sheet.png): Not on your bars, On your bars, Passive,
-- each with its count (Grouped). A spell is a row the window's width, at
-- its highest rank learned, with its cast time over its cost at the right.
-- One with ranks has how many on a plate at its icon's foot and a chevron
-- after its name; a left click on it lists each rank under it
-- (MedalluinCharDB.bookOpen, by name), highest first, on a tree from its
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
-- character, MedalluinCharDB.upRank, by name), and a marked one wears a
-- blue double chevron on its icon's top right, as a bound one wears a mouse. A
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

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local MISSING = { 0.85, 0.3, 0.2 }      -- the edge of a spell on no bar
local BLUE = { 0.43, 0.63, 0.92 }       -- a cost
local SLOTS = 180                       -- the action slots looked through
local SPELL, RANK = 36, 24              -- a spell's row, a rank's
local SPECS_H = 44                      -- the tabs' panel, joined under the head
local OFF = { 0.37, 0.345, 0.29 }       -- a tab's count, not held
local ICON, INDENT = 30, 20             -- a spell's icon, its left
local HEADING = 28                      -- a group's heading
local PAGE = 256                        -- the parchment's tile (media/spellbook, art/spellbook)
local DOTS = 8                          -- the dotted rule's tile
local FAINT = { 0.141, 0.122, 0.094 }   -- between a spell's ranks
local RIGHT = 80                        -- the cast time and cost's column
local EDGE = 12                         -- the cast time and cost, in from the card's edge
-- a section's colour, by its specialisation's role (General, the pet's
-- and the trainer's Other: the theme's brown)
local ROLE = { TANK = { 0.35, 0.55, 0.9 }, HEALER = { 0.35, 0.78, 0.45 }, DAMAGER = { 0.84, 0.35, 0.29 } }
local ROLE_WORD = { TANK = Tr["Tank"], HEALER = Tr["Healer"], DAMAGER = Tr["Damage"] }
local STEP = SPELL * 1.5                -- a turn of the wheel
local BANK = Enum and Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
local TYPE = Enum and Enum.SpellBookItemType or { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }

local W = ns.Window{
    name = "MedalluinSpellbook", named = Tr["Spellbook"], side = 1,
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
    local t = MedalluinCharDB and MedalluinCharDB.bookOpen
    return type(t) == "table" and t[name] == true
end

local function Fold(name)
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.bookOpen = type(MedalluinCharDB.bookOpen) == "table" and MedalluinCharDB.bookOpen or {}
    MedalluinCharDB.bookOpen[name] = not Open(name) or nil
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
-- learn now), role, icon }; none when it has nothing
local function Section(out, name, list, now, role, icon)
    if #list == 0 then return end
    table.insert(out, { name = name, list = list, count = #list, now = now, role = role, icon = icon })
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

-- the page's open tab (MedalluinCharDB.bookTab[page], by the section's
-- name), or its first
local function Held(p)
    local t = MedalluinCharDB and MedalluinCharDB.bookTab
    local name = type(t) == "table" and t[p.key]
    for _, sec in ipairs(p.sections or {}) do
        if sec.name == name then return sec end
    end
    return p.sections and p.sections[1]
end

local function Hold(p, name)
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.bookTab = type(MedalluinCharDB.bookTab) == "table" and MedalluinCharDB.bookTab or {}
    MedalluinCharDB.bookTab[p.key] = name
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
            Section(out, line.name, Line(line), nil, Role(line, l), line.iconID)
        end
    end
    local pet = {}
    for slot = 1, SB.HasPetSpells and SB.HasPetSpells() or 0 do
        local info = SB.GetSpellBookItemInfo(slot, BANK.Pet)
        if info then table.insert(pet, { slot = slot, bank = BANK.Pet, info = info }) end
    end
    Section(out, Tr["Pet"], pet, nil, nil, GetPetIcon and GetPetIcon() or nil)
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

-- (2026-11-19, mockup B of /workspace/booklist-sheet.png) The open tab's
-- entries under headings: Not on your bars (each spell Missing finds), On
-- your bars, Passive; each with its count, in the book's order within.
-- Headed only when two have spells, and not on the trainer's page nor
-- while Click Casting binds (nothing is missing then): else one list.
local GROUPS = { { Tr["Not on your bars"], true }, { Tr["On your bars"] }, { Tr["Passive"] } }
local function Grouped(p, macros, binding)
    local list = p.held and p.held.list or {}
    local groups, filled = { {}, {}, {} }, 0
    for _, item in ipairs(list) do
        if binding or p.trainer then
            item.missing, item.lowerOn = false, nil
        else
            item.missing, item.lowerOn = Missing(item, macros)
        end
        local g = item.missing and 1 or item.info.isPassive and 3 or 2
        table.insert(groups[g], item)
    end
    for _, g in ipairs(groups) do if #g > 0 then filled = filled + 1 end end
    if filled < 2 or binding or p.trainer then return Entries(p.held) end
    local out = {}
    for k, g in ipairs(groups) do
        if #g > 0 then
            table.insert(out, { heading = GROUPS[k][1], count = #g, red = GROUPS[k][2], key = "h" .. k })
            for _, e in ipairs(Entries({ list = g })) do table.insert(out, e) end
        end
    end
    return out
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
    local t = MedalluinCharDB and MedalluinCharDB.upRank
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
    if type(MedalluinCharDB) ~= "table" then return end
    local t = type(MedalluinCharDB.upRank) == "table" and MedalluinCharDB.upRank or {}
    MedalluinCharDB.upRank = t
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
local GOLD_HEX = "|cfff0d488"

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

-- A section's card, pooled, under its rows: a dark box with a brown edge,
-- its specialisation's icon faint at its top right under the strip.

-- A row, pooled: one frame for each kind, its parts shown for the kind.
--   strip   Restoration                              Healer · 6 (+)
--   spell   [icon] Lightning Bolt                    2.5 sec
--                  Rank 4                            100 Mana
--   ranked  [ic]]] Healing Wave                      3 sec      (a stack)
--                  Rank 5 · 5 ranks                  200 Mana
--   rank       |   Rank 4                  3 sec     155 Mana
local function Row(p, i)
    local c = CreateFrame("Button", nil, p.scroller.child)
    c:SetFrameLevel(p.scroller.child:GetFrameLevel() + 3)
    -- the hairline at a row's foot, from the icon's left (Refresh hides
    -- it on a group's last, over a heading and between ranks)
    c.hair = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.hair:SetHeight(1)
    c.hair:SetPoint("BOTTOMLEFT", INDENT, 0)
    c.hair:SetPoint("BOTTOMRIGHT", 0, 0)
    -- (2026-11-19, mockup B of /workspace/bookpage-sheet.png) dotted, as
    -- a ledger's: its tile repeated along it (Place sets how many)
    c.hair:SetTexture(ns.media .. "spellbook\\dots", "REPEAT", "REPEAT")
    c.hair:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
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
    -- an open spell and its ranks: a gold bar down the inner edge, a soft
    -- wash brightening outwards
    c.bar = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.bar:SetWidth(2)
    c.bar:SetPoint("TOPLEFT")
    c.bar:SetPoint("BOTTOMLEFT")
    c.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    c.gwash = c:CreateTexture(nil, "BACKGROUND", nil, -3)
    c.gwash:SetAllPoints()
    if c.gwash.SetGradient and CreateColor then
        c.gwash:SetColorTexture(1, 1, 1, 1)
        c.gwash:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0),
            CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.14))
    else
        c.gwash:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.07)
    end
    -- a click-cast binding: a small mouse in a gold ring on the icon's
    -- bottom corner; kept on its top rank: a double chevron, up, on its top
    local function Badge(glyph, at, dy)
        local b = CreateFrame("Frame", nil, c)
        b:SetSize(15, 15)
        b:SetPoint("CENTER", c.icon, at, -2, dy)
        b.ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
        b.ring:SetAllPoints()
        b.ring:SetTexture(ns.media .. "strips\\round")
        b.ring:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        local disc = b:CreateTexture(nil, "ARTWORK", nil, 2)
        disc:SetPoint("TOPLEFT", 1, -1)
        disc:SetPoint("BOTTOMRIGHT", -1, 1)
        disc:SetTexture(ns.media .. "strips\\round")
        disc:SetVertexColor(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
        b.glyph = b:CreateTexture(nil, "ARTWORK", nil, 3)
        b.glyph:SetSize(11, 11)
        b.glyph:SetPoint("CENTER")
        b.glyph:SetTexture(ns.media .. "strips\\" .. glyph)
        b.glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
        b:Hide()
        return b
    end
    -- each glyph cut to its drawing (its file is mostly margin), so it
    -- fills the badge's disc
    c.badge = Badge("mouse", "BOTTOMRIGHT", 2)
    c.badge.glyph:SetTexCoord(8 / 32, 24 / 32, 5 / 32, 27 / 32)
    c.badge.glyph:SetSize(9, 12)
    c.top = Badge("chevron-double", "TOPRIGHT", -2)
    c.top.glyph:SetTexCoord(7 / 32, 25 / 32, 27 / 32, 6 / 32)   -- the chevrons point down: turned up
    c.top.glyph:SetSize(10, 12)
    -- while Click Casting is open, round a spell it can bind: a gold halo
    c.halo = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.halo:SetPoint("TOPLEFT", c.icon, -4, 4)
    c.halo:SetPoint("BOTTOMRIGHT", c.icon, 4, -4)
    c.halo:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    c.halo:Hide()
    c.name = ns.Text(c, 12)
    c.name:SetPoint("TOPLEFT", INDENT + ICON + 8, -5)
    c.name:SetPoint("RIGHT", -RIGHT, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.sub = ns.Text(c, 10)
    c.sub:SetPoint("BOTTOMLEFT", INDENT + ICON + 8, 5)
    c.sub:SetPoint("RIGHT", -RIGHT, 0)
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(false)
    c.sub:SetTextColor(unpack(ns.colors.dim))
    c.cast = ns.Text(c, 11)
    c.cast:SetPoint("TOPRIGHT", -EDGE, -5)
    c.cast:SetJustifyH("RIGHT")
    c.cost = ns.Text(c, 10)
    c.cost:SetPoint("BOTTOMRIGHT", -EDGE, 5)
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
    c.branch:SetPoint("LEFT", INDENT + ICON / 2, 0)
    c.branch:SetWidth(14)
    c.branch:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    c.rhair = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.rhair:SetHeight(1)
    c.rhair:SetPoint("BOTTOMLEFT", INDENT + ICON + 8, 0)
    c.rhair:SetPoint("BOTTOMRIGHT", -4, 0)
    c.rhair:SetColorTexture(FAINT[1], FAINT[2], FAINT[3], 1)
    -- a group's heading, as a book's: its name (red: not on your bars)
    -- underlined in its ink, its count after, and under both a rule on to
    -- the edge
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
    c.rank:SetPoint("LEFT", INDENT + ICON + 8, 0)
    c.rcast = ns.Text(c, 10)
    c.rcast:SetPoint("RIGHT", -(EDGE + 96), 0)
    c.rcast:SetJustifyH("RIGHT")
    c.rcast:SetTextColor(unpack(ns.colors.dim))
    c.rcost = ns.Text(c, 10)
    c.rcost:SetPoint("RIGHT", -EDGE, 0)
    c.rcost:SetJustifyH("RIGHT")
    c.rcost:SetTextColor(unpack(BLUE))
    -- what the secure button covers: the row within the card's edges
    c.hit = CreateFrame("Frame", nil, c)
    c.hit:SetPoint("TOPLEFT", 1, 0)
    c.hit:SetPoint("BOTTOMRIGHT", -1, 0)
    c.glow = c:CreateTexture(nil, "HIGHLIGHT")
    c.glow:SetAllPoints(c.hit)
    c.glow:SetColorTexture(1, 1, 1, 0.08)
    -- A spell, in combat (the secure layer away) or cut by the scroll's
    -- edge: the left button shows or hides its ranks, the right casts
    -- nothing; Click Casting open, either binds
    c:SetScript("OnClick", function(self, button)
        if self.item then Press(p, self.item, button) end
    end)
    c:SetScript("OnEnter", function(self) if self.item then Tooltip(self, self.item) end end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = c
    return c
end

local PARTS = {
    spell = { "icon", "edge", "name", "sub", "cast", "cost" },
    rank = { "stem", "branch", "rank", "rcast", "rcost" },
    heading = { "hname", "hcount", "hunder", "hline" },
}
local function Kind(c, kind)
    for k, list in pairs(PARTS) do
        for _, part in ipairs(list) do c[part]:SetShown(k == kind) end
    end
    for _, part in ipairs({ "badge", "top", "halo", "plate", "chev", "bar", "gwash", "hair", "rhair" }) do
        c[part]:Hide()
    end
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- a heading is no button: no highlight under the pointer, no click
    c:EnableMouse(kind ~= "heading")
    c.glow:SetShown(kind ~= "heading")
    c.kind = kind
end

-- The entries laid out top to bottom in the scroll's child, the list's
-- width; the rows left over hidden.
local function Place(p, items)
    local width = W.width
    local y = 0
    for i, item in ipairs(items) do
        local c = p.rows[i] or Row(p, i)
        local h = item.heading and HEADING or item.rank and RANK or SPELL
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetSize(width, h)
        c.hair:SetTexCoord(0, (width - INDENT) / DOTS, 0, 0.5)
        c.y, c.h = y, h
        c:Show()
        y = y + h
    end
    for i = #items + 1, #p.rows do
        p.rows[i].item = nil
        p.rows[i]:Hide()
    end
    p.scroller.child:SetSize(width, math.max(1, y))
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
    b:SetAttribute("shift-type2", Markable(item) and "medalluinTopRank" or nil)
end

-- Out of combat only: a button over each spell or rank row wholly in view,
-- armed; the rest away. A row the scroll's edge cuts has none (it casts
-- nothing) until it scrolls into view. The layer is shown while
-- the window is open (a driver hides it in combat), and hidden when it
-- closes.
local function Follow()
    if not layer or InCombatLockdown() then return end
    local p = W.Current()
    local rows = open and p and p.casts and p.rows or {}
    local s = p and p.scroller
    local top = s and s.offset or 0
    local bottom = top + (s and s.scroll:GetHeight() or 0)
    local n = 0
    for _, c in ipairs(rows) do
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
    local glow = t:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.06)
    t:SetScript("OnClick", function(self)
        if not self.section then return end
        Hold(p, self.section.name)
        p.scroller.To(0, true)
        Refresh(p)
    end)
    t:SetScript("OnEnter", function(self)
        local sec = self.section
        if not sec then return end
        ns.Tip(self, ns.window.OutsideTop, { title = sec.name, color = GOLD,
            sec.role and { "body", ROLE_WORD[sec.role] } or nil })
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.specs.cells[i] = t
    return t
end

-- the tabs as the sections now are, each a share of the panel's width;
-- a name too wide drops a size or three (the gem is on the count's line)
function Tabs(p)
    local panel = p.specs
    if not panel then return end
    local list = p.sections or {}
    local width = (panel:GetWidth() or 0) > 0 and panel:GetWidth() or (W.width + 2 * ns.window.pad)
    -- the medallion and its step stand over the inner end (the left: the
    -- book is on the right): that cell's words centred in what they leave
    local clear = (W.step or 40) + 6    -- the step under the head, from the inner edge
    for i, sec in ipairs(list) do
        local t = panel.cells[i] or Cell(p, i)
        local x0 = math.floor((i - 1) * width / #list)
        local x1 = math.floor(i * width / #list)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, 0)
        t:SetSize(x1 - x0, SPECS_H)
        t.section = sec
        local held = sec == p.held
        t.wash:SetShown(held)
        t.line:SetShown(held)
        t.split:SetShown(i > 1)
        local shift = i == 1 and clear / 2 or 0
        t.name:ClearAllPoints()
        t.name:SetPoint("CENTER", shift, 7)
        t.count:ClearAllPoints()
        t.count:SetPoint("CENTER", shift + 6, -9)
        local room = (x1 - x0) - 10 - (i == 1 and clear or 0)
        local size = 12
        t.name:SetFont(ns.font, size, "")
        t.name:SetText(sec.name)
        while size > 9 and (t.name:GetStringWidth() or 0) > room do
            size = size - 1
            t.name:SetFont(ns.font, size, "")
        end
        t.name:SetWidth(math.min(room, math.ceil(t.name:GetStringWidth() or 0) + 1))
        local col = ROLE[sec.role] or GOLD_D
        t.gem.stone:SetColorTexture(col[1], col[2], col[3], 1)
        local c = held and GOLD or ns.colors.dim
        t.name:SetTextColor(c[1], c[2], c[3])
        local words = p.trainer and format(Tr["%d to learn"], sec.count)
            or ns.Plural(sec.count, format(Tr["%d |4spell:spells;"], sec.count))
        if p.trainer and (sec.now or 0) > 0 then words = words .. "  \194\183  " .. format(Tr["%d now"], sec.now) end
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

-- The page under the list (2026-11-19, mockup B of
-- /workspace/bookpage-sheet.png): a dark aged parchment, tiled, from the
-- window's inner frame to the rail and up to the tabs' panel's foot; the
-- spine's shadow down its inner edge (the left: the book stands on the
-- right), and it darkens at its top, its foot and its outer edge.
local function Paper(body)
    local f = CreateFrame("Frame", nil, body)
    local pad = ns.window.pad
    f:SetPoint("TOPLEFT", -(pad - 1), 5)
    f:SetPoint("BOTTOMRIGHT", pad - 4, 0)
    f:SetFrameLevel(body:GetFrameLevel())
    f.page = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.page:SetAllPoints()
    f.page:SetTexture(ns.media .. "spellbook\\parchment", "REPEAT", "REPEAT")
    f:SetScript("OnSizeChanged", function(self, w, h)
        self.page:SetTexCoord(0, (w or 0) / PAGE, 0, (h or 0) / PAGE)
    end)
    f.shades = {}
    -- black fading inwards from an edge: its side, how far, how dark
    for _, e in ipairs({ { "LEFT", 16, 0.55 }, { "TOP", 14, 0.35 }, { "BOTTOM", 18, 0.4 }, { "RIGHT", 8, 0.3 } }) do
        local at, size, a = e[1], e[2], e[3]
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        local across = at == "LEFT" or at == "RIGHT"
        if across then
            t:SetPoint("TOP" .. at)
            t:SetPoint("BOTTOM" .. at)
            t:SetWidth(size)
        else
            t:SetPoint(at .. "LEFT")
            t:SetPoint(at .. "RIGHT")
            t:SetHeight(size)
        end
        if t.SetGradient and CreateColor then
            t:SetColorTexture(1, 1, 1, 1)
            local dark, clear = CreateColor(0, 0, 0, a), CreateColor(0, 0, 0, 0)
            -- (a gradient runs left to right, bottom to top)
            local first = (at == "LEFT" or at == "BOTTOM")
            t:SetGradient(across and "HORIZONTAL" or "VERTICAL", first and dark or clear, first and clear or dark)
        else
            t:SetColorTexture(0, 0, 0, a / 2)
        end
        f.shades[at] = t
    end
    return f
end

-- ------------------------------------------------------------------ pages
local Band
function Refresh(p)
    if not p.scroller then return end
    Items(p)
    local macros = Macros()
    local binding = Binding()
    local items = Grouped(p, macros, binding)
    Place(p, items)
    local bound = ns.db.spellbookClickCast and ns.clickcast and { ns.clickcast.Bound() }
    local cbf = _G.ClickBindingFrame
    -- the halo while nothing is in the binder: pick one
    local ready = binding and cbf and ns.clickcast.Step and ns.clickcast.Step() == 1
    for i, item in ipairs(items) do
        local c = p.rows[i]
        local nxt = items[i + 1]
        if item.heading then
            Kind(c, "heading")
            c.item = nil
            c.hname:SetText(item.heading)
            local hc = item.red and MISSING or GOLD
            c.hname:SetTextColor(hc[1], hc[2], hc[3])
            c.hunder:SetColorTexture(hc[1], hc[2], hc[3], 0.9)
            c.hcount:SetText("· " .. tostring(item.count))
        else
            Kind(c, item.rank and "rank" or "spell")
            c.item = item
            local info = item.info
            local cast, cost = Costs(item)
            -- a hairline under it, but a group's last, over a heading and
            -- over its ranks
            c.hair:SetShown(nxt ~= nil and not nxt.rank and not nxt.heading)
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
                c.stem:SetPoint("TOPLEFT", INDENT + ICON / 2, 0)
                if last then
                    c.stem:SetPoint("BOTTOMLEFT", c, "LEFT", INDENT + ICON / 2, 0)
                else
                    c.stem:SetPoint("BOTTOMLEFT", INDENT + ICON / 2, 0)
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
                c.icon:SetPoint("LEFT", INDENT, 0)
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
                    local room = (W.width or 300) - (INDENT + ICON + 8) - RIGHT - 14
                    local tw = math.min(c.name:GetStringWidth() or 0, room)
                    c.chev:ClearAllPoints()
                    c.chev:SetPoint("CENTER", c, "TOPLEFT", INDENT + ICON + 8 + tw + 9, -11)
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
                if item.clicks then sub = (sub and sub .. "  ·  " or "") .. GOLD_HEX .. item.clicks .. "|r" end
                c.sub:SetText(sub or "")
                c.cast:SetText(cast or "")
                c.cast:SetTextColor(unpack(item.trainer and not item.now and ns.colors.dim
                    or ns.colors.text or { 1, 1, 1 }))
                c.cost:SetText(cost or "")
                c.badge:SetShown(item.clicks ~= nil and not binding)
                -- marked for top rank: blue while Top rank is on its marks,
                -- dim while it is on every spell or none
                local top = not binding and Markable(item) and Marked(info.name)
                c.top:SetShown(top)
                if top then
                    local g = Mode() == "marked" and BLUE or ns.colors.dim
                    c.top.glyph:SetVertexColor(g[1], g[2], g[3])
                end
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
    p.scroller.To(p.scroller.target)
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
    local row = ns.window.Segments(band, { height = band:GetHeight(), items = {
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
        name = "MedalluinSpellbookTopRank", title = Tr["Keep on top rank"], width = 240, choices = CHOICES,
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
    if not p.macros then p.under = SPECS_H end
    p.flex, p.height, p.bandUsed, p.bandFlush = true, 0, true, true
    p.events = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_ICON", "PLAYER_LEVEL_UP",
        "UNIT_PET", "PET_BAR_UPDATE", "ACTIONBAR_SLOT_CHANGED", "PLAYER_MONEY" }
    function p.Build(body, foot, band)
        Controls(p, band)
        if p.macros then
            ns.macros.Build(p, body)
            return
        end
        -- the tabs' panel (joined under the head); the list on its page,
        -- its bar out by the rail
        Panel(p)
        p.paper = Paper(body)
        local holder = CreateFrame("Frame", nil, body)
        holder:SetPoint("TOPLEFT")
        holder:SetPoint("BOTTOMRIGHT")
        p.holder = holder
        p.scroller = ns.window.Scroller(holder, 0, true)
        -- the buttons over the rows follow them as they scroll
        if p.casts then p.scroller.Moved = function() Follow() end end
        holder:EnableMouseWheel(true)
        holder:SetScript("OnMouseWheel", function(_, delta) p.scroller.To(p.scroller.target - delta * STEP) end)
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
    layer = W.Layer("MedalluinSpellbookCasts")
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
