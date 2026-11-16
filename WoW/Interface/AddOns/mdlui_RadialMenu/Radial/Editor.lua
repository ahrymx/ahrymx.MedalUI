local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RADIAL EDITOR
-- mdlui_RadialMenu: forked from FlareUI's Settings/RadialEditor.lua (6.8.2) by Malkkav, MIT (see LICENSE).
-- Sections 1-10 are the fork's model, read across from FlareUI's file: the lists, the Catalog's
-- categories, drags, the edits (InsertEntry, MoveButton, RemoveButton), Undo, who gets a radial and its
-- key, the name popup, macros. Changes there: names and dialog keys renamed, the Gamepad UI's
-- controller row and bar slots left out (controller work waits for 2.0), drops on the canvas.
-- Sections 11-13 are this addon's own (2026-11-16): FlareUI's layout builders were replaced by the
-- Unit Frame Editor's layout (UI/Window.lua, UI/Canvas.lua), so the layout half no longer follows
-- FlareUI's and the scratchpad script that regenerated this file from FlareUI's no longer applies.
--
-- The editor window's radials: every radial with who gets it and its key, what opens on this
-- character, the chosen radial's wheel with its buttons as slots, and a Catalog to fill it from.
-- Edits are live; a snapshot taken on open backs "Undo changes". Drags from Blizzard's windows use the
-- game cursor (OnReceiveDrag); internal drags are resolved in FinishDrag.
--------------------------------------------------

local BRONZE       = { 0.769, 0.647, 0.341 }   -- Medalluin's gold
local BRONZE_MUTED = { 0.541, 0.439, 0.204 }   -- and its dark gold
local FALLBACK_ICON = 134400

local editor, editingID, selectedButton, dragging, activeCategory
-- openSlot: the category open on the wheel (its slot on the radial); viewPreset: the preset shown
-- (Core/Presets.lua), read-only, instead of a radial
local openSlot, viewPreset
local RadialDrag, RadialRowMenu, GroupMenu   -- the radials list's drag and its group menus (before BuildRadialColumn)
local browseCache = {}   -- category -> its entries, built once per opening
local snapshot, dirty

local function RM() return ns.RadialMenu end

--------------------------------------------------
-- 1. PIECES
--------------------------------------------------
-- sound replaces the Game Menu click; false leaves the sound to onClick
local function RedButton(parent, text, width, onClick, sound)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if ns.SkinButton then ns.SkinButton(b) end
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", function(...)
        if sound ~= false then ns.ButtonSound(sound) end
        onClick(...)
    end)
    return b
end

--------------------------------------------------
-- 2. SCROLLING LIST (1 or more columns, the settings panel's thin scroll line)
--------------------------------------------------
local function CreateList(parent, width, columns, rows, cellHeight, buildCell, fillCell)
    local list = CreateFrame("Frame", nil, parent)
    local cellWidth = (width - 12) / columns
    list.cells, list.data = {}, {}
    list:SetSize(width, rows * cellHeight)

    for i = 1, columns * rows do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local cell = CreateFrame("Button", nil, list)
        cell:SetSize(cellWidth, cellHeight)
        cell:SetPoint("TOPLEFT", col * cellWidth, -row * cellHeight)

        cell.Highlight = cell:CreateTexture(nil, "BACKGROUND")
        cell.Highlight:SetAllPoints()
        ns.SettingsPanel.Rounded(cell.Highlight, BRONZE[1], BRONZE[2], BRONZE[3], 0.25)
        cell.Highlight:Hide()

        cell.Icon = cell:CreateTexture(nil, "ARTWORK")
        cell.Icon:SetSize(cellHeight - 8, cellHeight - 8)
        cell.Icon:SetPoint("LEFT", 4, 0)
        cell.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        cell.Text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell.Text:SetPoint("LEFT", cell.Icon, "RIGHT", 6, 0)
        cell.Text:SetPoint("RIGHT", -6, 0)
        cell.Text:SetJustifyH("LEFT")
        cell.Text:SetWordWrap(false)

        -- a bronze wash instead of Blizzard's blue square
        cell:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        ns.SettingsPanel.Rounded(cell:GetHighlightTexture(), BRONZE[1], BRONZE[2], BRONZE[3], 0.18)

        if buildCell then buildCell(cell) end
        list.cells[i] = cell
    end

    list.offset, list.maxOffset = 0, 0

    function list:Update()
        local offset = self.offset * columns
        for i, cell in ipairs(self.cells) do
            local index = offset + i
            local item = self.data[index]
            cell.item, cell.dataIndex = item, item and index or nil
            if item then
                fillCell(cell, item, index)
                cell:Show()
            else
                cell:Hide()
            end
        end
    end

    -- list.offset is in rows
    local function SetOffset(offset)
        offset = math.max(0, math.min(list.maxOffset, math.floor(offset + 0.5)))
        if offset == list.offset then return false end
        list.offset = offset
        list:Update()
        if list.SyncBar then list.SyncBar() end
        return true
    end

    -- the controller (PadNav.lua): a row up or down, past the first or last visible cell
    function list:PadScroll(delta) return SetOffset(self.offset + delta) end
    -- the cell showing data index, scrolled into view
    function list:CellFor(index)
        local row = math.floor((index - 1) / columns)
        if row < self.offset then SetOffset(row) elseif row >= self.offset + rows then SetOffset(row - rows + 1) end
        for _, cell in ipairs(self.cells) do
            if cell.dataIndex == index then return cell end
        end
    end

    local bar = ns.SettingsPanel.ScrollLine(list)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar.onScroll = function(position)
        SetOffset(position * list.maxOffset)
        bar:SetValues(bar.visible, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
    end

    local function SyncBar()
        local total = math.max(rows, math.ceil(#list.data / columns))
        bar:SetValues(rows / total, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
    end
    list.SyncBar = SyncBar

    function list:SetData(data)
        self.data = data or {}
        self.maxOffset = math.max(0, math.ceil(#self.data / columns) - rows)
        if self.offset > self.maxOffset then self.offset = self.maxOffset end
        SyncBar()
        self:Update()
    end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        SetOffset(list.offset - delta)
        SyncBar()
    end)
    return list
end

--------------------------------------------------
-- 3. ENTRIES
--------------------------------------------------
-- a spell's ID is GetCursorInfo's fourth return (the first is a spellbook slot, never a spell)
local function EntryFromCursor()
    local cursorType, info1, _, info3 = GetCursorInfo()
    local entry
    if cursorType == "spell" then
        entry = info3 and { kind = "spell", id = info3 }
    elseif cursorType == "item" then
        entry = { kind = "item", id = info1 }
    elseif cursorType == "mount" then
        entry = { kind = "mount", id = info1 }
    elseif cursorType == "macro" then
        local name, icon, body = GetMacroInfo(info1)
        entry = { kind = "macro", name = name, icon = icon, text = body }
    end
    -- only what resolves reaches the radial
    if entry and RM():ResolveEntry(entry) then
        ClearCursor()
        return entry
    end
    return nil
end

-- the guillemet marking a sub-radial, as bytes so the file stays ASCII
local CHEVRON = "\194\187 "

local function EntryDisplay(entry)
    -- a party spell: the spell, then who it spreads over
    if entry and entry.kind == "partycast" then
        local info = RM():ResolveEntry(entry)
        local name = (info and info.name) or (entry.id and C_Spell.GetSpellName(entry.id))
        if name then
            return name .. " |cff9d8462" .. CHEVRON .. L["party"] .. "|r", { texture = C_Spell.GetSpellTexture(entry.id) or FALLBACK_ICON }
        end
    end
    -- Quest Items keeps its own name and mark, with how many items it holds now
    if entry and entry.kind == "questitems" then
        local info = RM():ResolveEntry(entry)
        local count = info and info.children and #info.children or 0
        return L["Quest Items"] .. " |cff9d8462(" .. count .. ")|r", { texture = RM().QUEST_ITEMS_ICON }
    end
    local info = entry and RM():ResolveEntry(entry)
    -- a sub-radial shows the radial's name, even when it resolves to nothing
    if entry and entry.kind == "subradial" then
        local data = RM():GetRadial(entry.radial)
        if data then
            return CHEVRON .. data.name, info and info.icon or { texture = FALLBACK_ICON }
        end
    end
    if info then
        -- the editor names a spell's rank ("Frostbolt (Rank 3)"), so the ranks tell apart and search
        -- finds them; the radial itself keeps the short name
        if entry.kind == "spell" and entry.id and info.name then
            -- the rank it casts for this character (its best, unless the button is pinned)
            local cast = info.attributes and tonumber(info.attributes.spell) or entry.id
            local subtext = C_Spell.GetSpellSubtext(cast)
            if type(subtext) == "string" and subtext:find("%d") then
                if entry.pinned then subtext = L["%s, kept"]:format(subtext) end
                return info.name .. " (" .. subtext .. ")", info.icon
            end
        end
        return info.name, info.icon
    end
    -- an item not in the bags or a mount not owned (left out of the radial): its name, greyed
    if entry and entry.kind == "item" and entry.id then
        local name = C_Item.GetItemNameByID(entry.id)
        if name then
            return "|cff808080" .. name .. " (" .. L["not in your bags"] .. ")|r",
                { texture = C_Item.GetItemIconByID(entry.id) or FALLBACK_ICON }
        end
    end
    if entry and entry.kind == "mount" and entry.id and C_MountJournal then
        local name, _, icon = C_MountJournal.GetMountInfoByID(entry.id)
        if name then return "|cff808080" .. name .. " (" .. L["unavailable"] .. ")|r", { texture = icon or FALLBACK_ICON } end
    end
    -- a spell this character doesn't know (a radial shared with others): its name, greyed
    if entry and entry.kind == "spell" and entry.id then
        local name = C_Spell.GetSpellName(entry.id)
        if name then
            return "|cff808080" .. name .. " (" .. L["unavailable"] .. ")|r",
                { texture = C_Spell.GetSpellTexture(entry.id) or FALLBACK_ICON }
        end
    end
    return "|cff808080" .. L["unavailable"] .. "|r", { texture = FALLBACK_ICON }
end

-- Spells and items get the game's own tooltip (it shows the rank), the rest their name; hint below.
-- A macro gets the tooltip of what it casts now, under its own name.
local function EntryTooltip(owner, entry, hint)
    ns.OwnGameTooltip(owner, "ANCHOR_RIGHT")
    local macroKind, macroID
    if entry.kind == "macro" and RM() and RM().MacroAction then macroKind, macroID = RM().MacroAction(entry) end
    if entry.kind == "spell" and entry.id then
        GameTooltip:SetSpellByID(entry.id)
    elseif entry.kind == "item" and entry.id then
        GameTooltip:SetItemByID(entry.id)
    elseif macroKind == "spell" or macroKind == "item" then
        if macroKind == "spell" then GameTooltip:SetSpellByID(macroID) else GameTooltip:SetItemByID(macroID) end
        GameTooltip:AddLine(L["Macro"] .. ": " .. tostring(entry.name), 1, 0.82, 0)
    else
        GameTooltip:AddLine((EntryDisplay(entry)), 1, 1, 1)
    end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

-- The radial's own round button on a list cell: the icon in a circle mask over an ink well, under the
-- rim art (Radial.lua RoundStyle; the drawn rim is FlareUI's fallback, unused here). size is the rim's.
local function MakeRound(cell, size)
    local rm = RM()
    local style = rm and rm.RoundStyle and rm.RoundStyle()
    local iconSize = style and size * style.iconFactor or size * (1 - 2 * (rm and rm.ROUND_BORDER_FRACTION or 0.06))
    cell.Icon:SetSize(iconSize, iconSize)
    local mask = cell:CreateMaskTexture()
    if style then
        mask:SetTexture(style.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    else
        mask:SetAtlas("CircleMaskScalable")
    end
    mask:SetAllPoints(cell.Icon)
    cell.Icon:AddMaskTexture(mask)
    local rim
    if style then
        local well = cell:CreateTexture(nil, "BACKGROUND", nil, 1)
        well:SetColorTexture(1, 1, 1)
        local c = rm.ROUND_BORDER_COLOR
        well:SetVertexColor(c[1], c[2], c[3])
        well:SetSize(size, size)
        well:SetPoint("CENTER", cell.Icon, "CENTER")
        local wellMask = cell:CreateMaskTexture()
        wellMask:SetTexture(style.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        wellMask:SetAllPoints(well)
        well:AddMaskTexture(wellMask)
        rim = cell:CreateTexture(nil, "OVERLAY", nil, 1)
        rim:SetTexture(style.idle)
    else
        rim = cell:CreateTexture(nil, "BORDER")
        rim:SetColorTexture(1, 1, 1)
        local c = rm and rm.ROUND_BORDER_COLOR or BRONZE_MUTED
        rim:SetVertexColor(c[1], c[2], c[3])
        local rimMask = cell:CreateMaskTexture()
        rimMask:SetAtlas("CircleMaskScalable")
        rimMask:SetAllPoints(rim)
        rim:AddMaskTexture(rimMask)
    end
    rim:SetSize(size, size)
    rim:SetPoint("CENTER", cell.Icon, "CENTER")
end

local function ApplyIcon(owner, icon)
    if icon and icon.atlas then
        owner.Icon:SetTexCoord(0, 1, 0, 1)
        owner.Icon:SetAtlas(icon.atlas)
    else
        owner.Icon:SetTexture((icon and icon.texture) or FALLBACK_ICON)
        owner.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

--------------------------------------------------
-- 4. CATEGORY BROWSERS (menu order = declaration order)
--------------------------------------------------
local CATEGORIES = {}

-- empty: what the grid says when the category has nothing for this character (11-12)
local function AddCategory(key, label, build, note, empty)
    CATEGORIES[#CATEGORIES + 1] = { key = key, label = label, build = build, note = note, empty = empty }
end

AddCategory("panels", L["Panels"], function()
    local panels, out = RM().MICRO_PANELS, {}
    for key in pairs(panels) do out[#out + 1] = { kind = "micromenu", panel = key } end
    table.sort(out, function(a, b) return panels[a.panel].order < panels[b.panel].order end)
    return out
end)

-- each castable spell in the player's book: the spell itself, not a temporary override showing in
-- its place right now (a flyout has no spellID and is skipped)
local function ForEachBookSpell(callback)
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        -- another specialization's line holds spells the character can't cast now
        if lineInfo and not lineInfo.shouldHide and not lineInfo.offSpecID then
            for offset = 1, lineInfo.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(lineInfo.itemIndexOffset + offset, bank)
                if info and info.spellID and not info.isPassive and info.itemType ~= Enum.SpellBookItemType.FutureSpell then
                    callback(info.actionID or info.spellID)
                end
            end
        end
    end
end

AddCategory("spells", L["Spells"], function()
    local out = {}
    ForEachBookSpell(function(spellID) out[#out + 1] = { kind = "spell", id = spellID } end)
    return out
end, nil, L["No spells in your spellbook yet."])

-- Party: your helpful spells, each spread over the group (a button per person, RadialMenu.lua
-- ACTIONS.partycast)
AddCategory("party", L["Party"], function()
    local out = {}
    ForEachBookSpell(function(spellID)
        if C_Spell.IsSpellHelpful(spellID) then out[#out + 1] = { kind = "partycast", id = spellID } end
    end)
    return out
end, L["A button for you and each party member: aim at a person to cast on them."], L["No helpful spells to cast on others yet."])

AddCategory("items", L["Items"], function()
    -- first: the button that fills itself with your quests' items
    local out, seen = { { kind = "questitems" } }, {}
    if not C_Container then return out end
    for bag = 0, 5 do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            if itemID and not seen[itemID] then
                seen[itemID] = true
                out[#out + 1] = { kind = "item", id = itemID }
            end
        end
    end
    return out
end)

-- Professions (11-12, Marcus): every profession you know, at its best rank (each opens its window),
-- then the profession spells around them: Smelting, Disenchant, the tracking, a campfire, Pick Lock.
-- Ranks highest first; a spell you don't know is left out.
local PROFESSION_SPELLS = {
    { 11611, 3464, 3101, 2259 },     -- Alchemy
    { 9785, 3538, 3100, 2018 },      -- Blacksmithing
    { 13920, 7413, 7412, 7411 },     -- Enchanting
    { 12656, 4038, 4037, 4036 },     -- Engineering
    { 10662, 3811, 3104, 2108 },     -- Leatherworking
    { 12180, 3910, 3909, 3908 },     -- Tailoring
    { 18260, 3413, 3102, 2550 },     -- Cooking
    { 10846, 7924, 3274, 3273 },     -- First Aid
    { 18248, 7732, 7731, 7620 },     -- Fishing
    { 2656 },                        -- Smelting (Mining)
    { 13262 },                       -- Disenchant
    { 2580 },                        -- Find Minerals
    { 2383 },                        -- Find Herbs
    { 818 },                         -- Basic Campfire
    { 1804 },                        -- Pick Lock
}
-- (11-12: the IDs alone found nothing on Forever, whose profession spells can carry other IDs: each one
-- is also looked up by its name in your spellbook, which answers with the rank you have)
local function KnownProfessionSpell(ranks)
    for _, id in ipairs(ranks) do
        if ns.IsPlayerSpell(id) then return id end
    end
    local name = C_Spell.GetSpellName(ranks[1])
    local info = name and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
    local id = info and info.spellID
    if id and C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.FindSpellBookSlotForSpell(id) then return id end
    if id and ns.IsPlayerSpell(id) then return id end
end
AddCategory("professions", L["Professions"], function()
    local out = {}
    -- by name too: every spell in your book whose name is one of these (any rank, any ID)
    local names, found = {}, {}
    for i, ranks in ipairs(PROFESSION_SPELLS) do
        local name = C_Spell.GetSpellName(ranks[1])
        if name then names[name] = i end
    end
    ForEachBookSpell(function(spellID)
        local i = names[C_Spell.GetSpellName(spellID) or ""]
        if i and not found[i] then found[i] = spellID end
    end)
    for i, ranks in ipairs(PROFESSION_SPELLS) do
        local id = found[i] or KnownProfessionSpell(ranks)
        if id then out[#out + 1] = { kind = "spell", id = id } end
    end
    return out
end, nil, L["Nothing here yet: learn a profession and its spells appear here."])

AddCategory("macros", L["Macros"], function()
    local out = {}
    local global, perChar = GetNumMacros()
    -- per-character macros are indexed after the account block
    local accountMax = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for i = 1, (global or 0) do
        local name, icon, body = GetMacroInfo(i)
        if name then out[#out + 1] = { kind = "macro", name = name, icon = icon, text = body } end
    end
    for i = 1, (perChar or 0) do
        local name, icon, body = GetMacroInfo(accountMax + i)
        if name then out[#out + 1] = { kind = "macro", name = name, icon = icon, text = body } end
    end
    return out
end, nil, L["No macros yet: make one with /macro and it appears here."])

AddCategory("markers", L["Markers"], function()
    local out = {}
    for i = 1, 8 do out[#out + 1] = { kind = "targetmarker", marker = i } end
    out[#out + 1] = { kind = "targetmarker", marker = -1 }
    out[#out + 1] = { kind = "targetmarker", marker = 0 }
    -- star to skull, like the target markers above (the stored number is the game's own)
    for icon = 1, 8 do
        local marker = ns.RadialMenu.WorldMarkerForIcon and ns.RadialMenu.WorldMarkerForIcon(icon) or icon
        out[#out + 1] = { kind = "worldmarker", marker = marker }
    end
    out[#out + 1] = { kind = "worldmarker", marker = 0 }
    return out
end)

AddCategory("emotes", L["Emotes"], function()
    local out = {}
    for _, e in ipairs(RM().EMOTES or {}) do out[#out + 1] = { kind = "emote", emote = e.token } end
    return out
end)

AddCategory("mounts", L["Mounts"], function()
    local out = {}
    if not C_MountJournal then return out end
    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if isCollected then out[#out + 1] = { kind = "mount", id = mountID } end
    end
    return out
end, nil, L["No mounts yet."])

-- a radial that contains the edited one, at any depth, is left out of the list
local function ContainsRadial(radialID, targetID, depth)
    depth = depth or 0
    if radialID == targetID then return true end
    if depth > 6 then return true end
    local data = RM():GetRadial(radialID)
    if not data then return false end
    for _, button in ipairs(data.buttons) do
        if button.kind == "subradial" and ContainsRadial(button.radial, targetID, depth + 1) then return true end
        for _, inner in ipairs(button.kind == "category" and button.buttons or {}) do
            if inner.kind == "subradial" and ContainsRadial(inner.radial, targetID, depth + 1) then return true end
        end
    end
    return false
end

AddCategory("radials", L["Radials"], function()
    local out = {}
    -- an empty category, to fill with buttons of its own (not inside a category)
    if not openSlot then out[1] = { kind = "category", name = L["Category"], glyph = "atease", buttons = {} } end
    for _, id in ipairs(RM():GetRadialsByName()) do
        if not ContainsRadial(id, editingID) then out[#out + 1] = { kind = "subradial", radial = id } end
    end
    return out
end, L["Creates sub-radials. Use the mouse wheel while hovering it in the radial menu to flip through its buttons. A category is a ring of its own buttons, kept in this radial: click it, or turn the wheel on it, to open it."], L["No other radials yet: make one and it can open from here."])

--------------------------------------------------
-- 5. DRAG
--------------------------------------------------
local ghost

local function StopDrag()
    dragging = nil
    if ghost then ghost:Hide() end
end

local function StartDrag(payload)
    dragging = payload
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetSize(32, 32)
        ghost:SetFrameStrata("TOOLTIP")
        ghost.Icon = ghost:CreateTexture(nil, "OVERLAY")
        ghost.Icon:SetAllPoints()
        ghost:SetScript("OnUpdate", function(self)
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end)
    end
    local _, icon = EntryDisplay(payload.entry)
    ApplyIcon(ghost, icon)
    ghost:Show()
end

--------------------------------------------------
-- 6. EDITING
--------------------------------------------------
local Refresh, RefreshBrowse   -- rebuild the whole tab, or the Catalog alone

local function CurrentRadial()
    local rm = RM()
    if not rm then return nil end
    local radial = editingID and rm:GetRadial(editingID)
    if radial then return radial end
    editingID = rm:GetDefaultRadialID() or rm:GetRadialOrder()[1]
    return editingID and rm:GetRadial(editingID) or nil
end

-- what the wheel shows and edits: the radial, or its category opened there (an entry that keeps its
-- own buttons); a preset, or its category, while one is viewed
local function CurrentList()
    local top
    if viewPreset then
        top = ns.PRESETS[viewPreset]
    else
        top = CurrentRadial()
    end
    local category = top and openSlot and top.buttons[openSlot]
    if category and category.kind == "category" then return category end
    openSlot = nil
    return top
end

local function Changed()
    dirty = true
    RM():RadialChanged(editingID)
end

local function InsertEntry(entry, atIndex)
    local radial = CurrentList()
    if not (radial and entry) or viewPreset then return end
    if entry.kind == "category" then
        if openSlot then
            ns.Print(L["a category can't go inside a category."])
            return
        end
        -- the Catalog's is a template: each gets buttons of its own
        entry = CopyTable(entry)
    end
    if #radial.buttons >= RM().MAX_BUTTONS then
        ns.Print(L["that radial is full (%d buttons)."]:format(RM().MAX_BUTTONS))
        return
    end
    atIndex = atIndex or (#radial.buttons + 1)
    -- a spell below the best rank known stays on that rank (pinned); otherwise it follows
    if RM().MarkRank then RM().MarkRank(entry) end
    table.insert(radial.buttons, atIndex, entry)
    selectedButton = atIndex
    Changed()
    Refresh()
end

local function MoveButton(from, to)
    local radial = CurrentList()
    if not radial or viewPreset then return end
    to = math.max(1, math.min(#radial.buttons, to))
    if from == to then return end
    table.insert(radial.buttons, to, table.remove(radial.buttons, from))
    selectedButton = to
    Changed()
    Refresh()
end

local function RemoveButton(index)
    local radial = CurrentList()
    if not (radial and radial.buttons[index]) or viewPreset then return end
    table.remove(radial.buttons, index)
    if selectedButton and selectedButton > #radial.buttons then selectedButton = #radial.buttons end
    Changed()
    Refresh()
end

-- a category's ring on the wheel, in place of the radial (its slot chosen again on the way back)
local function OpenCategory(slot)
    local list = CurrentList()
    local entry = not openSlot and list and slot and list.buttons[slot]
    if not (entry and entry.kind == "category") then return end
    openSlot, selectedButton = slot, nil
    Refresh()
end

local function CloseCategory()
    if not openSlot then return end
    selectedButton, openSlot = openSlot, nil
    Refresh()
end

-- nothing is on the game cursor during an internal drag, so OnReceiveDrag never fires. On the canvas
-- (UI/Canvas.lua): dropped on a slot, a button takes its place and a Catalog entry goes in there; on
-- the empty slot, at the end. A button dropped off the canvas comes off the radial.
local function FinishDrag()
    local payload = dragging
    StopDrag()
    if not (payload and editor) or viewPreset then return end

    local target, empty = editor.canvas:SlotUnderMouse()
    local overCanvas = target ~= nil or editor.stage:IsMouseOver()
    local radial = CurrentList()
    if not radial then return end

    if payload.from then
        if target and not empty then
            MoveButton(payload.from, target)
        elseif empty then
            MoveButton(payload.from, #radial.buttons)
        elseif not overCanvas then
            RemoveButton(payload.from)   -- dragged off the wheel entirely
        end
    elseif payload.entry then
        if target and not empty then
            InsertEntry(payload.entry, target)
        elseif overCanvas then
            InsertEntry(payload.entry)
        end
    end
end

--------------------------------------------------
-- 7. UNDOING CHANGES
-- The radials (buttons, names, who gets them, shared keys) and this character's own keys.
--------------------------------------------------
local function TakeSnapshot()
    local store = RM().GetStore()
    dirty = false
    if not store then snapshot = nil return end
    snapshot = {
        radials      = CopyTable(store.radials),
        radialOrder  = CopyTable(store.radialOrder),
        nextRadialID = store.nextRadialID,
        ownKeys      = CopyTable(ns.CharDB().radialKeyOverride or {}),
    }
end

local function RestoreSnapshot()
    local store = RM().GetStore()
    if not (store and snapshot and dirty) then return end
    -- the store table itself is kept: others hold a reference to it
    store.radials      = CopyTable(snapshot.radials)
    store.radialOrder  = CopyTable(snapshot.radialOrder)
    store.nextRadialID = snapshot.nextRadialID
    ns.CharDB().radialKeyOverride = CopyTable(snapshot.ownKeys)
    dirty = false
    RM():RadialChanged()
    RM():AvailabilityChanged()
end

-- acts on the radial the question named, even if the selection moved on
ns.Dialogs["MDLUI_RADIAL_DELETE"] = {
    text = L["Delete the radial |cffffff00%s|r?"],
    button1 = L["Delete"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if not (data and data.id and RM():GetRadial(data.id)) then return end
        RM():DeleteRadial(data.id)
        if editingID == data.id then editingID, selectedButton = nil, nil end
        Changed()
        Refresh()
    end,
    hideOnEscape = true,
    showAlert = true,
}

-- a preset's copy, back as the preset has it; its name, key and who gets it stay
ns.Dialogs["MDLUI_RADIAL_RESET"] = {
    text = L["Put |cffffff00%s|r back as it comes? Your changes to its buttons are lost; its name and key stay."],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if not (data and data.id and RM():ResetToPreset(data.id)) then return end
        if editingID == data.id then selectedButton, openSlot = nil, nil end
        dirty = true
        Refresh()
    end,
    hideOnEscape = true,
}

ns.Dialogs["MDLUI_RADIAL_CATEGORY_NAME"] = {
    text = "%s",
    button1 = L["Rename"],
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 40,
    editText = function(data) return data and data.name or "" end,
    OnAccept = function(data, text)
        text = text and strtrim(text) or ""
        if text == "" or not (data and data.entry) then return end
        data.entry.name = text
        Changed()
        Refresh()
    end,
    hideOnEscape = true,
}

--------------------------------------------------
-- 8. WHO GETS A RADIAL (scope words and icons)
--------------------------------------------------
local ICON_FACTION = { Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance", Horde = "Interface\\FriendsFrame\\PlusManz-Horde" }
local ICON_CHAR    = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon"
local ICON_CLASSES = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
local FACTION_COLOR = { Alliance = "ff4a9eff", Horde = "ffff4030" }

local function ClassName(token)
    if select(2, UnitClass("player")) == token then return (UnitClass("player")) end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end

local function ColorClass(token, text)
    local color = C_ClassColor and C_ClassColor.GetClassColor(token)
    return color and color:WrapTextInColorCode(text) or text
end

local function FactionName(token)
    local mine, myName = UnitFactionGroup("player")
    if mine == token and myName then return myName end
    return _G["FACTION_" .. token:upper()] or token
end

-- "Only Hedgey": the character's name was kept when the scope was set
local function ScopeOwner(scope, data)
    local _, guid = RM().SplitScope(scope)
    if guid == ns.PlayerGUID() then return (UnitName("player")) end
    return (data and data.scopeName) or "?"
end

-- the dropdown's words for a scope; data names the character of a "char:" scope made elsewhere
local function ScopeText(scope, data)
    local kind, value = RM().SplitScope(scope)
    if kind == "faction" then
        return L["All %s characters"]:format("|c" .. (FACTION_COLOR[value] or "ffffffff") .. FactionName(value) .. "|r")
    elseif kind == "class" then
        return L["All %s characters"]:format(ColorClass(value, ClassName(value)))
    elseif kind == "char" then
        return L["Only %s"]:format("|cffffd100" .. ScopeOwner(scope, data) .. "|r")
    end
    return L["All Characters"]
end

-- only a narrowed radial gets an icon (class, faction crest, a person); false for every character
local function ApplyScopeIcon(texture, scope)
    local kind, value = RM().SplitScope(scope)
    texture:SetDesaturated(false)
    if kind == "class" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[value] then
        texture:SetTexture(ICON_CLASSES)
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[value]))
        return true
    end
    texture:SetTexCoord(0, 1, 0, 1)
    if kind == "faction" and ICON_FACTION[value] then
        texture:SetTexture(ICON_FACTION[value])
        return true
    elseif kind == "char" then
        texture:SetTexture(ICON_CHAR)
        texture:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        return true
    end
    return false
end

local function KeyText(key)
    return ns.KeyText(key)
end

-- What the key does in the game's own key bindings (a radial key takes it over while this addon is on),
-- or nil
local function GameAction(key)
    if not key or key == "" or ns.ParsePadCombo(key) then return nil end
    local action = GetBindingAction(key)
    if not action or action == "" or action:find("^CLICK mdluiRadial") then return nil end
    local name = GetBindingName and GetBindingName(action)
    return (name and name ~= "") and name or action
end

-- asked before a radial key takes a game key; acts on the radial the question named
ns.Dialogs["MDLUI_RADIAL_KEY_TAKEN"] = {
    text = "%s",
    button1 = L["Use It"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if data and data.id and RM():GetRadial(data.id) then RM():SetRadialKey(data.id, data.key) end
        Changed()
        Refresh()
    end,
    OnCancel = function() Refresh() end,
    hideOnEscape = true,
}

--------------------------------------------------
-- 9. NAME POPUP (new radial with who gets it, or rename: popup.renaming)
--------------------------------------------------
local popup

local function ShowNamePopup(renaming)
    if not popup then
        popup = CreateFrame("Frame", "mdluiRadialNewRadial", UIParent, "BackdropTemplate")
        -- FULLSCREEN: over the settings window (DIALOG) and under Blizzard's menus (FULLSCREEN_DIALOG),
        -- so the Available To list opens over it (it opened under it, 11-12)
        popup:SetFrameStrata("FULLSCREEN")
        popup:SetToplevel(true)
        popup:EnableMouse(true)
        ns.SettingsPanel.Dress(popup)
        popup:Hide()
        tinsert(UISpecialFrames, "mdluiRadialNewRadial")
        popup:SetScript("OnShow", ns.WindowOpenSound)
        popup:SetScript("OnHide", ns.WindowCloseSound)

        local label = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", 0, -16)
        popup.label = label

        local box = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        box:SetSize(250, 20)
        box:SetPoint("TOP", label, "BOTTOM", 6, -12)
        box:SetAutoFocus(true)
        popup.box = box

        -- who gets the new radial
        local scopeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        scopeLabel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -14)
        scopeLabel:SetText(L["Available To"])
        popup.scopeLabel = scopeLabel
        local scopeDrop = CreateFrame("DropdownButton", nil, popup, "WowStyle1DropdownTemplate")
        scopeDrop:SetWidth(256)
        scopeDrop:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -4)
        scopeDrop:SetupMenu(function(_, root)
            for _, scope in ipairs(RM():GetScopeChoices()) do
                root:CreateRadio(ScopeText(scope), function() return popup.scope == scope end, function()
                    popup.scope = scope
                end)
            end
        end)
        popup.scopeDrop = scopeDrop
        -- the Gamepad UI: FlareUI's plain list in place of Blizzard's menu (PadNav.GuardDropdown)
        if ns.PadNav and ns.PadNav.GuardDropdown then
            ns.PadNav.GuardDropdown(scopeDrop, function()
                local entries = {}
                for _, s in ipairs(RM():GetScopeChoices()) do
                    entries[#entries + 1] = { text = ScopeText(s), checked = function() return popup.scope == s end,
                                              pick = function() popup.scope = s end }
                end
                return entries
            end)
        end

        local function Accept()
            local name = strtrim(box:GetText())
            if name == "" then return end
            if popup.renaming then
                RM():RenameRadial(editingID, name)
            else
                editingID, selectedButton = RM():CreateRadial(name, popup.scope), nil
            end
            ns.ButtonSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            popup:Hide()
            Changed()
            Refresh()
        end

        local accept = RedButton(popup, L["Create"], 90, Accept, false)
        accept:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -4, 14)
        popup.accept = accept
        local cancel = RedButton(popup, L["Cancel"], 90, function() popup:Hide() end)
        cancel:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 4, 14)

        box:SetScript("OnEnterPressed", Accept)
        box:SetScript("OnEscapePressed", function() popup:Hide() end)
    end

    local radial = renaming and editingID and RM():GetRadial(editingID)
    if renaming and not radial then return end
    popup.renaming = renaming and true or nil
    popup.label:SetText(renaming and L["Rename the radial"] or L["Name the new radial"])
    popup.accept:SetText(renaming and L["Rename"] or L["Create"])
    -- a new radial starts on every character (11-12, Marcus: All, not only this one)
    local choices = RM():GetScopeChoices()
    popup.scope = choices[1]
    popup.scopeLabel:SetShown(not renaming)
    popup.scopeDrop:SetShown(not renaming)
    popup.scopeDrop:GenerateMenu()
    popup:SetSize(320, renaming and 116 or 170)

    popup:ClearAllPoints()
    popup:SetPoint("CENTER", editor or UIParent, "CENTER", 0, 60)
    popup.box:SetText(renaming and radial.name or L["New Radial"])
    popup.box:HighlightText()
    popup:Show()
    popup.box:SetFocus()
end

--------------------------------------------------
-- 10. RADIAL MACROS
--------------------------------------------------
local function CreateRadialMacro()
    local data = editingID and RM():GetRadial(editingID)
    if not data then return end
    local S = ns.Settings
    if InCombatLockdown() then
        ns.Print((S:Text("rm.macroCreate", "errorInCombat", true) or L["You can't create macros in combat."]))
        return
    end
    local _, perCharacter = GetNumMacros()
    local maxPerCharacter = Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS or 30
    if perCharacter >= maxPerCharacter then
        ns.Print((S:Text("rm.macroCreate", "errorMacrosFull", true) or L["Your macro list is full. Delete one and try again."]))
        return
    end
    -- 16 bytes at most, without splitting a multi-byte letter
    local full, cut = "MDL " .. data.name, 16
    while cut < #full and full:byte(cut + 1) >= 128 and full:byte(cut + 1) < 192 do cut = cut - 1 end
    local name = full:sub(1, cut)
    local index = CreateMacro(name, "INV_MISC_QUESTIONMARK", RM():GetMacroText(editingID), true)
    if index then
        PickupMacro(index)
        local done = S:Text("rm.macroCreate", "done", true) or L["Macro \"{name}\" created and on your cursor. Drop it on a bar."]
        ns.Print(done:gsub("{name}", function() return name end))
    end
end

--------------------------------------------------
-- 11. BUILD
-- mdlui_RadialMenu's own, in the Settings window's layout (FlareUI's builders are gone): UI/Window.lua
-- makes the window and hands its parts here. The sidebar: the radials under their groups' headings,
-- the ones not on this character, Options > Every radial. A radial's page: its header, and two sheets:
--   Wheel    the wheel (UI/Canvas.lua: a slot per button), the chosen slot, the Catalog
--   Radial   who gets it, its key, Macro / Copy / Rename / Delete, the keys on this character
-- Every radial (the options) is the window's.
--------------------------------------------------
local Panel = ns.SettingsPanel
local UI = ns.ui
local NAV_ROW_H = 24             -- the sidebar's rows (a heading or a radial)
local GRID_ROW_H = 28            -- the Catalog's rows (two columns)
local GRID_RIM = 22              -- a Catalog entry's round icon
local SLOT_RIM = 40              -- the chosen slot's icon
local otherOpen = false          -- "Not on this character" unfolded (this session)

-- what kind of button a slot holds, on the chosen slot's card
local KINDS = {
    spell = L["Spell"], item = L["Item"], mount = L["Mount"], macro = L["Macro"], emote = L["Emote"],
    targetmarker = L["Target marker"], worldmarker = L["World marker"], subradial = L["Radial"],
    micromenu = L["Panel"], partycast = L["Party spell"], questitems = L["Quest Items"], category = L["Category"],
}

-- a tooltip from the copy document: label, description, tip
local function Hover(control, rowKey)
    local S = ns.Settings
    control:HookScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(S:Text(rowKey, "label"), 1, 1, 1)
        local desc, tip = S:Text(rowKey, "desc", true), S:Text(rowKey, "tip", true)
        if desc then GameTooltip:AddLine(S:Format(desc), nil, nil, nil, true) end
        if tip then GameTooltip:AddLine(L["Tip:"] .. " " .. S:Format(tip), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SelectRadial(id)
    if id == editingID and not viewPreset then return end
    editingID, selectedButton, openSlot, viewPreset = id, nil, nil, nil
    Refresh()
end

-- dragging in the radials list: a radial or a group ("group:gid"), its name under the cursor.
-- A radial dropped on a radial takes its place (and its group); on a group's row it joins the group.
-- A group dropped on a row moves there with its radials.
RadialDrag = {}
function RadialDrag.Start(payload)
    local gid = payload:match("^group:(.+)$")
    local data = gid and RM():GetGroup(gid) or (not gid and RM():GetRadial(payload))
    if not data then return end
    RadialDrag.payload = payload
    local g = RadialDrag.ghost
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetFrameStrata("TOOLTIP")
        g:SetSize(10, 16)
        g.text = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        g.text:SetPoint("LEFT")
        g:SetScript("OnUpdate", function(self)
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            self:ClearAllPoints()
            self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale)
        end)
        RadialDrag.ghost = g
    end
    g.text:SetText(data.name or "")
    g:Show()
end
function RadialDrag.Stop(list)
    local payload = RadialDrag.payload
    RadialDrag.payload = nil
    if RadialDrag.ghost then RadialDrag.ghost:Hide() end
    if not (payload and list) then return end
    local gid = payload:match("^group:(.+)$")
    for _, cell in ipairs(list.cells) do
        local item = cell:IsShown() and cell:IsMouseOver() and cell.item
        if item and (item.id or item.group) then
            local moved = false
            if gid then
                local target = item.id or ("group:" .. item.group)
                if target ~= payload then moved = RM():MoveGroup(gid, target) end
            elseif item.group then
                local data = RM():GetRadial(payload)
                if data and data.group ~= item.group then RM():SetRadialGroup(payload, item.group); moved = true end
            elseif item.id ~= payload then
                moved = RM():MoveRadial(payload, item.id)
            end
            if moved then ns.ButtonSound() Refresh() end
            return
        end
    end
end

-- GROUP MENUS (11-12): a radial's right-click puts it in a new group, another group, or out of its
-- own; a group's renames or ungroups it. Blizzard's menu, FlareUI's own list in the Gamepad UI.
local function ShowRowMenu(owner, title, entries)
    if ns.IsGamepadUI() and ns.PadNav and ns.PadNav.OpenList then
        local list = {}
        for _, e in ipairs(entries) do
            if not e.divider then list[#list + 1] = { text = e.text, pick = e.func } end
        end
        ns.PadNav.OpenList(owner, list)
        return
    end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        for _, e in ipairs(entries) do
            if e.divider then root:CreateDivider() else root:CreateButton(e.text, e.func) end
        end
    end)
end

ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["MDLUI_RADIAL_GROUP"] = {
    text = "%s",
    button1 = _G.ACCEPT or "Accept",
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 40,
    editText = function(data)
        local group = data and data.gid and RM():GetGroup(data.gid)
        return group and group.name or L["New Group"]
    end,
    OnAccept = function(data, text)
        text = text and strtrim(text) or ""
        if text == "" or not data then return end
        if data.gid then
            RM():RenameGroup(data.gid, text)
        elseif data.id then
            RM():CreateGroupWith(data.id, text)
        end
        Refresh()
    end,
    hideOnEscape = true,
}

function RadialRowMenu(owner, id)
    local rm = RM()
    local data = rm:GetRadial(id)
    if not data then return end
    local entries = {
        { text = L["Add to New Group..."], func = function()
            ns.ShowDialog("MDLUI_RADIAL_GROUP", L["Name the group"], { id = id })
        end },
    }
    -- the other groups, by name
    local others = {}
    for gid, group in pairs(rm:GetGroups()) do
        if gid ~= data.group then others[#others + 1] = { gid = gid, name = group.name or "" } end
    end
    table.sort(others, function(a, b) return a.name:lower() < b.name:lower() end)
    for _, o in ipairs(others) do
        entries[#entries + 1] = { text = L["Move to %s"]:format(o.name), func = function() rm:SetRadialGroup(id, o.gid) Refresh() end }
    end
    if data.group then
        entries[#entries + 1] = { text = L["Remove from Group"], func = function() rm:SetRadialGroup(id, nil) Refresh() end }
    end
    ShowRowMenu(owner, data.name, entries)
end

function GroupMenu(owner, gid)
    local group = RM():GetGroup(gid)
    if not group then return end
    ShowRowMenu(owner, group.name, {
        { text = L["Rename..."], func = function()
            ns.ShowDialog("MDLUI_RADIAL_GROUP", L["Name the group"], { gid = gid })
        end },
        { text = L["Ungroup"], func = function() RM():Ungroup(gid) Refresh() end },
    })
end

-- a tooltip of plain words: a title, then the text, wrapped
local function Tip(control, title, text)
    control:HookScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local DOT = " \194\183 "   -- a middle dot between facts, as bytes so the file stays ASCII

local function Paint(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

--------------------------------------------------
-- THE SIDEBAR
-- As the Settings window's: a heading per group (its glyph, its name in capitals; folded, its count in
-- a pill; a click folds or opens it, a right-click its menu), its radials hung off it on an elbow;
-- the radials in no group; "Not on this character", folded; Options > Every radial. The radial
-- shown is lit (a faint gold fill, a gold bar at the sidebar's edge, gold text); its key at the
-- right, orange where another radial wins it. A radial drags onto another, or onto a group.
--------------------------------------------------
local function BuildNav(win)
    local list = CreateList(win.nav, 194, 1, win.navRows, NAV_ROW_H,
        function(cell)
            Panel.Rounded(cell.Highlight, UI.goldBright[1], UI.goldBright[2], UI.goldBright[3], 0.11)
            Panel.Rounded(cell:GetHighlightTexture(), UI.lift[1], UI.lift[2], UI.lift[3], UI.lift[4])
            cell.Bar = Panel.Fill(cell, "ARTWORK", UI.goldBright)
            cell.Bar:SetWidth(3)
            cell.Bar:SetPoint("TOPLEFT", -6, 0)
            cell.Bar:SetPoint("BOTTOMLEFT", -6, 0)
            Panel.Heading(cell.Text, 12, UI.dim)
            cell.Key = Panel.Plain(cell, 10, UI.faint)
            cell.Key:SetPoint("RIGHT", -8, 0)
            cell.Key:SetJustifyH("RIGHT")
            -- a narrowed radial's scope (a class, a faction, a character), small, before its key
            cell.Icon:SetSize(12, 12)
            cell.Icon:ClearAllPoints()
            cell.Icon:SetPoint("RIGHT", cell.Key, "LEFT", -4, 0)
            cell.Glyph = Panel.Fill(cell, "ARTWORK", UI.faint)
            cell.Glyph:SetSize(6, 6)
            cell.Glyph:SetPoint("LEFT", 9, -4)
            cell.Glyph:SetRotation(math.pi / 4)
            cell.Head = Panel.Plain(cell, 10, UI.dim)
            cell.Head:SetPoint("LEFT", 25, -4)
            cell.Pill = CreateFrame("Frame", nil, cell)
            cell.Pill:SetHeight(15)
            cell.Pill:SetPoint("RIGHT", -6, -4)
            Panel.Fill(cell.Pill, "BACKGROUND", UI.lift2, 1):SetAllPoints()
            cell.Pill.text = Panel.Plain(cell.Pill, 10, UI.dim)
            cell.Pill.text:SetPoint("CENTER", 0, 0)
            local down = Panel.Fill(cell, "ARTWORK", UI.lineStrong)
            down:SetWidth(1)
            down:SetPoint("TOPLEFT", 22, 0)
            down:SetPoint("BOTTOMLEFT", cell, "LEFT", 22, 0)
            local across = Panel.Fill(cell, "ARTWORK", UI.lineStrong)
            across:SetSize(6, 1)
            across:SetPoint("LEFT", 22, 0)
            cell.Elbow = { down, across }
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:SetScript("OnClick", function(self, mouseButton)
                local item = self.item
                if not item then return end
                if item.group then
                    if mouseButton == "RightButton" then GroupMenu(self, item.group) return end
                    ns.ButtonSound()
                    RM():SetGroupOpen(item.group, not RM():IsGroupOpen(item.group))
                    Refresh()
                elseif item.fold then
                    ns.ButtonSound()
                    otherOpen = not otherOpen
                    Refresh()
                elseif item.options then
                    ns.ButtonSound()
                    win.ShowPage("options")
                elseif item.preset then
                    ns.ButtonSound()
                    if item.preset ~= viewPreset then viewPreset, selectedButton, openSlot = item.preset, nil, nil end
                    win.ShowPage("radial", "wheel")
                elseif item.id then
                    if mouseButton == "RightButton" then RadialRowMenu(self, item.id) return end
                    ns.ButtonSound()
                    if win.page == "radial" then
                        SelectRadial(item.id)
                    else
                        if item.id ~= editingID or viewPreset then
                            editingID, selectedButton, openSlot, viewPreset = item.id, nil, nil, nil
                        end
                        win.ShowPage("radial")
                    end
                end
            end)
            cell:SetScript("OnEnter", function(self)
                local item = self.item
                if not item then return end
                if item.group then
                    ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                    local group = RM():GetGroup(item.group)
                    GameTooltip:AddLine(group and group.name or "", 1, 1, 1)
                    GameTooltip:AddLine(L["Click to open or close. Right-click to rename or ungroup. Drag to move."], 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                    return
                end
                if item.preset then
                    ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(ns.PRESETS[item.preset].name, 1, 1, 1)
                    GameTooltip:AddLine(L["A ready-made radial. Add a copy of your own to change it; you can put the copy back as it comes at any time."], nil, nil, nil, true)
                    GameTooltip:Show()
                    return
                end
                if item.options then
                    ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(L["Every radial"], 1, 1, 1)
                    GameTooltip:AddLine(L["How every radial opens and looks, and its fonts."], nil, nil, nil, true)
                    GameTooltip:Show()
                    return
                end
                local data = item.id and RM():GetRadial(item.id)
                if not data then return end
                ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(data.name, 1, 1, 1)
                GameTooltip:AddLine(ScopeText(data.scope, data))
                if not RM():IsRadialAvailable(item.id) then GameTooltip:AddLine(L["Not available on this character."], 0.6, 0.6, 0.6) end
                local winner = item.beatenBy and RM():GetRadial(item.beatenBy)
                if winner then GameTooltip:AddLine(L["%s opens %s on this character."]:format(KeyText(item.key), winner.name), 1, 0.6, 0) end
                GameTooltip:AddLine(L["Right-click for its group. Drag to move it."], 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", function(self)
                local item = self.item
                if not (item and (item.id or item.group)) then return end
                GameTooltip:Hide()
                RadialDrag.Start(item.id or ("group:" .. item.group))
            end)
            cell:SetScript("OnDragStop", function() RadialDrag.Stop(win.radialList) end)
        end,
        function(cell, item)
            for _, r in ipairs({ cell.Head, cell.Pill, cell.Glyph, cell.Elbow[1], cell.Elbow[2], cell.Bar,
                cell.Highlight, cell.Icon, cell.Text, cell.Key }) do r:Hide() end
            -- a heading: a group's (it folds), "Not on this character" (it folds), Options
            if item.head or item.group then
                local name = item.head
                if item.group then
                    local group = RM():GetGroup(item.group)
                    name = group and group.name or ""
                end
                cell.Head:SetText(name:upper())
                Paint(cell.Head, item.open and UI.gold or (item.faint and UI.faint or UI.dim))
                cell.Head:Show()
                local g = item.open and UI.goldBright or UI.faint
                cell.Glyph:SetColorTexture(g[1], g[2], g[3], 1)
                cell.Glyph:Show()
                if not item.open and item.count then
                    cell.Pill.text:SetText(tostring(item.count))
                    cell.Pill:SetWidth(math.max(18, math.ceil(cell.Pill.text:GetStringWidth() or 0) + 10))
                    cell.Pill:Show()
                end
                cell:EnableMouse(item.group ~= nil or item.fold ~= nil)
                return
            end
            cell:EnableMouse(true)
            local lit, name, available
            available = true
            name = L["Every radial"]
            if item.preset then
                name = ns.PRESETS[item.preset].name
                lit = win.page == "radial" and item.preset == viewPreset
            elseif item.id then
                local data = RM():GetRadial(item.id)
                name, available = data.name, item.available
                lit = win.page == "radial" and item.id == editingID and not viewPreset
                local key = item.key and KeyText(item.key) or ""
                cell.Key:SetText(key)
                Paint(cell.Key, item.beaten and UI.clash or (lit and UI.gold or UI.faint))
                cell.Key:Show()
                local icon = ApplyScopeIcon(cell.Icon, data.scope)
                cell.Icon:SetShown(icon)
                cell.Icon:SetDesaturated(not available)
                cell.Icon:SetAlpha(available and 1 or 0.5)
            else
                lit = win.page == "options"
            end
            local left = item.member and 34 or 20
            cell.Elbow[1]:SetShown(item.member == true)
            cell.Elbow[2]:SetShown(item.member == true)
            cell.Text:ClearAllPoints()
            cell.Text:SetPoint("LEFT", left, 0)
            cell.Text:SetPoint("RIGHT", cell.Icon:IsShown() and cell.Icon or cell.Key, "LEFT", -4, 0)
            cell.Text:SetText(name)
            Paint(cell.Text, lit and UI.goldBright or (available and UI.dim or UI.faint))
            cell.Text:Show()
            cell.Highlight:SetShown(lit)
            cell.Bar:SetShown(lit)
        end)
    list:SetPoint("TOPLEFT", 6, 0)
    win.radialList = list
end

--------------------------------------------------
-- THE WHEEL SHEET
-- The wheel's card (its key in a chip, its count at the band's right, the canvas in a well); at the
-- right, the chosen slot's card over the Catalog's.
--------------------------------------------------
local WHEEL_W, SIDE_CARD_W, SLOT_H, GAP = 452, 341, 184, 12

local function BuildWheelCard(host, sheet)
    local card = Panel.Card(sheet, L["Wheel"], WHEEL_W, sheet:GetHeight())
    card:SetPoint("TOPLEFT", 0, 0)
    card:SetPoint("BOTTOMLEFT", 0, 0)
    host.wheelCard = card
    host.keyChip = Panel.Chip(card, "")
    Panel.InBand(card, host.keyChip, 8, true)
    -- a category open on the wheel: back to its radial
    host.backButton = Panel.UButton(card, L["< Back"], 64, 20, "quiet")
    Panel.InBand(card, host.backButton, 10, true)
    host.backButton:SetScript("OnClick", function()
        ns.ButtonSound()
        CloseCategory()
    end)
    Tip(host.backButton, L["Back"], L["Back to the radial this category is on."])
    host.countText = Panel.Plain(card, 11, UI.faint)
    host.countText:SetJustifyH("RIGHT")
    Panel.InBand(card, host.countText)
    local stage = CreateFrame("Frame", nil, card)
    stage:SetPoint("TOPLEFT", Panel.CARD_PAD, -(Panel.BAND_H + 10))
    stage:SetPoint("BOTTOMRIGHT", -Panel.CARD_PAD, Panel.CARD_PAD)
    host.stage = stage
end

local function BuildSlotCard(host, sheet)
    local card = Panel.Card(sheet, L["Chosen slot"], SIDE_CARD_W, SLOT_H)
    card:SetPoint("TOPRIGHT", 0, 0)
    host.slotCard = card
    host.slotChip = Panel.Chip(card, "")
    Panel.InBand(card, host.slotChip, 8, true)
    host.removeButton = Panel.UButton(card, L["Remove"], 70, 22, "quiet")
    Panel.InBand(card, host.removeButton, 8)
    host.removeButton:SetScript("OnClick", function()
        ns.ButtonSound()
        if selectedButton then RemoveButton(selectedButton) end
    end)
    Tip(host.removeButton, L["Remove"], L["Takes the button off this radial. Undo changes brings it back."])
    -- a category: open its ring on the wheel (a double-click opens it too), and rename it
    host.openButton = Panel.UButton(card, L["Open"], 56, 22, "secondary")
    host.openButton:SetPoint("RIGHT", host.removeButton, "LEFT", -6, 0)
    host.openButton:SetScript("OnClick", function()
        ns.ButtonSound()
        OpenCategory(selectedButton)
    end)
    Tip(host.openButton, L["Open"], L["Shows the category's own buttons on the wheel, to change them."])
    host.renameCatButton = Panel.UButton(card, L["Rename..."], 76, 22, "quiet")
    host.renameCatButton:SetPoint("RIGHT", host.openButton, "LEFT", -6, 0)
    host.renameCatButton:SetScript("OnClick", function()
        ns.ButtonSound()
        local list = CurrentList()
        local entry = list and selectedButton and list.buttons[selectedButton]
        if not (entry and entry.kind == "category") then return end
        ns.ShowDialog("MDLUI_RADIAL_CATEGORY_NAME", L["Name the category"], { entry = entry, name = entry.name })
    end)
    host.slotEmpty = Panel.Plain(card, 12, UI.dim)
    host.slotEmpty:SetPoint("TOP", 0, -(Panel.BAND_H + 64))
    host.slotEmpty:SetJustifyH("CENTER")

    local slot = CreateFrame("Frame", nil, card)
    slot:SetPoint("TOPLEFT", 0, 0)
    slot:SetSize(SIDE_CARD_W, SLOT_H)
    host.slot = slot
    local icon = CreateFrame("Frame", nil, slot)
    icon:SetSize(SLOT_RIM, SLOT_RIM)
    icon:SetPoint("TOPLEFT", Panel.CARD_PAD, -(Panel.BAND_H + 6))
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetPoint("CENTER")
    MakeRound(icon, SLOT_RIM)
    host.slotIcon = icon
    host.slotName = Panel.Serif(slot, 15, UI.text)
    host.slotName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
    host.slotName:SetWidth(SIDE_CARD_W - 2 * Panel.CARD_PAD - SLOT_RIM - 12)
    host.slotName:SetJustifyH("LEFT")
    host.slotName:SetWordWrap(false)
    host.slotKind = Panel.Plain(slot, 11, UI.dim)
    host.slotKind:SetPoint("TOPLEFT", host.slotName, "BOTTOMLEFT", 0, -4)
    host.slotKind:SetWidth(SIDE_CARD_W - 2 * Panel.CARD_PAD - SLOT_RIM - 12)
    host.slotKind:SetWordWrap(false)

    -- its place on the wheel, a step either way
    local row = Panel.CardRow(slot, 2, L["Place"], L["1 at the top, then clockwise"])
    Tip(row, L["Place"], L["Where the button sits on the wheel: 1 at the top, then clockwise. You can drag it on the wheel too."])
    local place = Panel.Stepper(row, 52, "<", ">")
    row:Hold(place)
    place.minus:SetScript("OnClick", function()
        ns.ButtonSound()
        if selectedButton then MoveButton(selectedButton, selectedButton - 1) end
    end)
    place.plus:SetScript("OnClick", function()
        ns.ButtonSound()
        if selectedButton then MoveButton(selectedButton, selectedButton + 1) end
    end)
    host.slotPlace = place

    -- a spell with ranks: its best known (following new ones), or kept on the one it has
    row = Panel.CardRow(slot, 3, L["Spell rank"], "")
    Tip(row, L["Spell rank"], L["Best known: casts the best rank you know, and follows new ones as you learn them. This rank: stays on the rank it has (one put on below your best is kept there)."])
    host.rankSeg = Panel.Segment(row, { L["Best known"], L["This rank"] }, function(i)
        local radial = CurrentList()
        local entry = radial and selectedButton and radial.buttons[selectedButton]
        if not entry then return end
        entry.pinned = (i == 2) or nil
        Changed()
        Refresh()
    end)
    row:Hold(host.rankSeg)
    host.rankRow = row

    -- a category: its glyph, in the rank's place
    row = Panel.CardRow(slot, 3, L["Glyph"], "")
    Tip(row, L["Glyph"], L["The picture the category shows on the radial."])
    local glyphs = CreateFrame("Frame", nil, row)
    local glyphNames = RM().CATEGORY_GLYPHS
    glyphs:SetSize(#glyphNames * 22 - 2, 20)
    host.glyphButtons = {}
    for i, glyph in ipairs(glyphNames) do
        local b = CreateFrame("Button", nil, glyphs)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", (i - 1) * 22, 0)
        b.Icon = b:CreateTexture(nil, "ARTWORK")
        b.Icon:SetAllPoints()
        b.Icon:SetTexture(RM().GlyphIcon(glyph).texture)
        b.glyph = glyph
        b:SetScript("OnClick", function()
            local list = CurrentList()
            local entry = list and selectedButton and list.buttons[selectedButton]
            if not (entry and entry.kind == "category") or viewPreset then return end
            ns.ButtonSound()
            entry.glyph = glyph
            Changed()
            Refresh()
        end)
        host.glyphButtons[i] = b
    end
    row:Hold(glyphs)
    host.glyphRow = row
end

local function BuildCatalogCard(host, sheet)
    local height = sheet:GetHeight() - SLOT_H - GAP
    local card = Panel.Card(sheet, L["Catalog"], SIDE_CARD_W, height)
    card:SetPoint("TOPRIGHT", 0, -(SLOT_H + GAP))
    card:SetPoint("BOTTOMRIGHT", 0, 0)
    host.catalogCard = card
    host.search = Panel.Search(card, 140, 22, L["Search"], function()
        if editor and editor:IsShown() then RefreshBrowse() end
    end)
    Panel.InBand(card, host.search, 8)

    -- the category: a menu of them, how many it holds at the right
    host.catDrop = Panel.Choice(card, 150, function(_, root)
        for _, c in ipairs(CATEGORIES) do
            root:CreateRadio(c.label, function() return c.key == activeCategory end, function()
                activeCategory = c.key
                host.search:SetText("")
                RefreshBrowse()
            end)
        end
    end)
    host.catDrop:SetPoint("TOPLEFT", Panel.CARD_PAD, -(Panel.BAND_H + 10))
    host.catCount = Panel.Plain(card, 11, UI.faint)
    host.catCount:SetJustifyH("RIGHT")
    host.catCount:SetPoint("RIGHT", card, "TOPRIGHT", -Panel.CARD_PAD, -(Panel.BAND_H + 21))

    local top = Panel.BAND_H + 40
    local rows = math.max(3, math.floor((height - top - 28) / GRID_ROW_H))
    local grid = CreateList(card, SIDE_CARD_W - 12, 2, rows, GRID_ROW_H,
        function(cell)
            cell.Highlight:Hide()
            Panel.Rounded(cell:GetHighlightTexture(), UI.lift[1], UI.lift[2], UI.lift[3], UI.lift[4])
            MakeRound(cell, GRID_RIM)
            cell.Icon:ClearAllPoints()
            cell.Icon:SetPoint("CENTER", cell, "LEFT", 4 + GRID_RIM / 2, 0)
            local face = cell.Text:GetFont()
            if face then cell.Text:SetFont(face, 12, "") end
            Paint(cell.Text, UI.text)
            cell.Text:ClearAllPoints()
            cell.Text:SetPoint("LEFT", cell, "LEFT", 4 + GRID_RIM + 8, 0)
            cell.Text:SetPoint("RIGHT", -2, 0)
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnEnter", function(self)
                if not self.item then return end
                -- a category's note (Radials explains sub-radials) comes with every entry's tooltip
                local note = host.categoryNote
                EntryTooltip(self, self.item, (note and (note .. "\n\n") or "") .. L["Click to add it after the chosen slot, or drag it onto the wheel."])
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cell:SetScript("OnDragStart", function(self)
                if self.item then StartDrag({ entry = self.item }) end
            end)
            cell:SetScript("OnDragStop", FinishDrag)
            cell:SetScript("OnClick", function(self)
                if not self.item then return end
                ns.ButtonSound()
                local radial = CurrentList()
                local after = radial and selectedButton and selectedButton <= #radial.buttons and selectedButton + 1 or nil
                InsertEntry(self.item, after)
            end)
        end,
        function(cell, entry)
            local name, icon = EntryDisplay(entry)
            ApplyIcon(cell, icon)
            cell.Text:SetText(name)
        end)
    grid:SetPoint("TOPLEFT", 8, -top)
    host.browseList = grid

    local hint = Panel.Plain(card, 11, UI.faint)
    hint:SetPoint("BOTTOMLEFT", Panel.CARD_PAD, 10)
    hint:SetPoint("BOTTOMRIGHT", -Panel.CARD_PAD, 10)
    hint:SetText(L["Click adds after the chosen slot, or drag onto the wheel."])
end

--------------------------------------------------
-- THE RADIAL SHEET
-- Who gets it, its key; Macro / Copy / Rename / Delete; the keys on this character.
--------------------------------------------------
-- a preset, viewed: what it is, and a copy of it for your radials (in the Catalog's place)
local function BuildPresetCard(host, sheet)
    local height = sheet:GetHeight() - SLOT_H - GAP
    local card = Panel.Card(sheet, L["Preset"], SIDE_CARD_W, height)
    card:SetPoint("TOPRIGHT", 0, -(SLOT_H + GAP))
    host.presetCard = card
    local text = Panel.Plain(card, 12, UI.dim)
    text:SetPoint("TOPLEFT", Panel.CARD_PAD, -(Panel.BAND_H + 12))
    text:SetWidth(SIDE_CARD_W - 2 * Panel.CARD_PAD)
    text:SetSpacing(3)
    text:SetText(L["A ready-made radial, read-only. Add a copy to your radials and change it however you like: its Radial sheet can put it back as it comes at any time."])
    local add = Panel.UButton(card, L["Add to my radials"], 150, 26, "primary")
    add:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    add:SetScript("OnClick", function()
        if not viewPreset then return end
        ns.ButtonSound()
        local id = RM():AddPreset(viewPreset)
        if not id then return end
        editingID, viewPreset, openSlot, selectedButton = id, nil, nil, nil
        Changed()
        Refresh()
    end)
    host.addPresetButton = add
    host.presetCopies = Panel.Plain(card, 11, UI.faint)
    host.presetCopies:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -10)
    host.presetCopies:SetWidth(SIDE_CARD_W - 2 * Panel.CARD_PAD)
end

local function BuildRadialSheet(host, sheet)
    local S = ns.Settings
    local colW = math.floor((sheet:GetWidth() - GAP) / 2)
    local function Height(n) return Panel.BAND_H + 4 + n * Panel.ROW_H + 8 end
    local content = CreateFrame("Frame", nil, sheet)
    content:SetAllPoints()
    host.radialContent = content
    host.radialEmpty = Panel.Plain(sheet, 12, UI.dim)
    host.radialEmpty:SetPoint("TOPLEFT", 0, -2)
    host.radialEmpty:SetText(L["No radials yet. Create one with + New radial."])

    local who = Panel.Card(content, L["Who gets it"], colW, Height(2))
    who:SetPoint("TOPLEFT", 0, 0)
    local row = Panel.CardRow(who, 1, S:Text("rm.scope", "label"), L["Every character, or a faction, a class or one"])
    Hover(row, "rm.scope")
    host.scopeLabel = row.label
    local scope = Panel.Choice(row, 150, function(_, root)
        local data = editingID and RM():GetRadial(editingID)
        if not data then return end
        local choices = RM():GetScopeChoices()
        -- a scope set on another character stays listed, so it shows as chosen
        local listed = false
        for _, s in ipairs(choices) do if s == (data.scope or "") then listed = true end end
        if not listed and data.scope then table.insert(choices, data.scope) end
        for _, s in ipairs(choices) do
            root:CreateRadio(ScopeText(s, data), function() return (data.scope or "") == s end, function()
                RM():SetRadialScope(editingID, s)
                Changed()
                Refresh()
            end)
        end
    end)
    row:Hold(scope)
    Hover(scope, "rm.scope")
    host.scopeDrop = scope

    row = Panel.CardRow(who, 2, S:Text("rm.ownKey", "label"), L["This character keeps a key of its own"])
    Hover(row, "rm.ownKey")
    host.ownKey = Panel.Switch(row, function(self)
        if editingID then RM():SetOwnKey(editingID, self:GetChecked() and true or false) end
        Changed()
        Refresh()
    end)
    row:Hold(host.ownKey)
    Hover(host.ownKey, "rm.ownKey")

    local keyCard = Panel.Card(content, S:Text("rm.key", "label"), colW, Height(1))
    keyCard:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -GAP)
    row = Panel.CardRow(keyCard, 1, L["Opens with"], L["On every character that gets it"])
    Hover(row, "rm.key")
    host.keyLabel = row.label
    host.keyButton = Panel.KeyButton(row, function(key)
        if not editingID then return end
        local taken = GameAction(key)
        if taken then
            ns.ShowDialog("MDLUI_RADIAL_KEY_TAKEN",
                L["%s is bound to %s. Use it for this radial anyway?"]:format(KeyText(key), taken),
                { id = editingID, key = key })
            return
        end
        RM():SetRadialKey(editingID, key)
        Changed()
        Refresh()
    end, function(button)
        -- a cancelled capture only puts the key back: a refresh would reset Undo
        button:ShowKey(editingID and RM():GetRadialKey(editingID) or "")
    end)
    row:Hold(host.keyButton)
    Hover(host.keyButton, "rm.key")

    -- a macro that opens it (made on the spot and put on the cursor), a copy, a new name, Delete
    local rightW = sheet:GetWidth() - colW - GAP
    local make = Panel.Card(content, L["Make"], rightW, Height(5))
    make:SetPoint("TOPRIGHT", 0, 0)
    local function Action(n, label, line, text, style, onClick)
        local r = Panel.CardRow(make, n, label, line)
        local b = Panel.UButton(r, text, 96, 24, style)
        r:Hold(b)
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            onClick()
        end)
        return b, r
    end
    host.macroButton = Action(1, L["Macro"], L["On your cursor: opens it from a bar"], L["Macro"], nil, CreateRadialMacro)
    Hover(host.macroButton, "rm.macroCreate")
    host.copyButton = Action(2, L["Copy"], L["A new radial with its buttons, no key"], L["Copy"], nil, function()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        editingID, selectedButton = RM():CopyRadial(editingID, L["%s (copy)"]:format(radial.name)), nil
        Changed()
        Refresh()
    end)
    Hover(host.copyButton, "rm.copy")
    local nameRow
    host.renameButton, nameRow = Action(3, L["Name"], "", L["Rename..."], nil, function() ShowNamePopup(true) end)
    host.nameLine = nameRow.line
    host.deleteButton = Action(4, L["Delete"], L["Undo changes brings it back"], L["Delete..."], "danger", function()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        ns.ShowDialog("MDLUI_RADIAL_DELETE", radial.name or "", { id = editingID })
    end)
    -- a preset's copy: its buttons back as the preset has them
    local presetRow
    host.resetButton, presetRow = Action(5, L["Preset"], "", L["Reset..."], nil, function()
        local radial = editingID and RM():GetRadial(editingID)
        local preset = radial and radial.preset and ns.PRESETS[radial.preset]
        if not preset then return end
        ns.ShowDialog("MDLUI_RADIAL_RESET", preset.name, { id = editingID })
    end)
    host.presetLine = presetRow.line

    -- what opens on this character
    local keys = Panel.Card(content, S:Text("rm.overview", "label"), rightW, 160)
    keys:SetPoint("TOPRIGHT", make, "BOTTOMRIGHT", 0, -GAP)
    keys:EnableMouse(true)
    Hover(keys, "rm.overview")
    local overview = Panel.Plain(keys, 12)
    overview:SetPoint("TOPLEFT", Panel.CARD_PAD, -(Panel.BAND_H + 10))
    overview:SetWidth(rightW - 2 * Panel.CARD_PAD)
    overview:SetJustifyV("TOP")
    overview:SetSpacing(4)
    overview:SetMaxLines(6)
    host.overview = overview
end

-- the canvas: the chosen radial's wheel, its slots chosen, moved, filled and emptied there
local function BuildCanvas(host)
    host.canvas = ns.RadialCanvas.Create(host.stage, {
        choose = function(i)
            -- something on the game cursor goes in at this slot
            local entry = EntryFromCursor()
            if entry then InsertEntry(entry, i) return end
            ns.ButtonSound()
            -- the same slot again, quickly: a category opens
            local now = GetTime()
            local again = i == selectedButton and host.lastChoose and now - host.lastChoose < 0.4
            host.lastChoose = now
            if again then
                local list = CurrentList()
                local chosen = list and list.buttons[i]
                if chosen and chosen.kind == "category" then
                    host.lastChoose = nil
                    OpenCategory(i)
                    return
                end
            end
            selectedButton = i
            Refresh()
        end,
        remove = function(i) RemoveButton(i) end,
        drop = function(i)
            local entry = EntryFromCursor()
            if entry then
                InsertEntry(entry, i)
            elseif not i then
                -- the empty slot, clicked: the Catalog's search, to find something for it
                host.search:SetFocus()
            end
        end,
        startDrag = function(i)
            if viewPreset then return end
            local radial = CurrentList()
            local entry = radial and radial.buttons[i]
            if entry then StartDrag({ from = i, entry = entry }) end
        end,
        finishDrag = FinishDrag,
        enter = function(hit)
            if hit.ghost then
                ns.OwnGameTooltip(hit, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["Empty slot"], 1, 1, 1)
                GameTooltip:AddLine(L["Drop something here from the Catalog, or click to search it."], nil, nil, nil, true)
                GameTooltip:Show()
                return
            end
            local radial = CurrentList()
            local entry = radial and radial.buttons[hit.index]
            if entry then EntryTooltip(hit, entry, L["Click to choose it. Drag it onto another slot to move it; right-click removes."]) end
        end,
    })
end

-- the footer's buttons the editor answers: + New radial, Undo changes
local function BuildFooter(host)
    host.newButton:SetScript("OnClick", function()
        ns.ButtonSound()
        ShowNamePopup(false)
    end)
    Hover(host.newButton, "rm.new")
    host.undoButton:SetScript("OnClick", function()
        ns.ButtonSound()
        RestoreSnapshot()
        TakeSnapshot()
        Refresh()
    end)
    Tip(host.undoButton, L["Undo changes"], L["Every change since the window opened, undone: buttons, names, who gets them, keys."])
end

local function Build(win)
    editor = win
    win.nameText = win.pageTitle
    BuildNav(win)
    local wheel = win.sheets.wheel
    BuildWheelCard(win, wheel)
    BuildSlotCard(win, wheel)
    BuildCatalogCard(win, wheel)
    BuildPresetCard(win, wheel)
    BuildRadialSheet(win, win.sheets.radial)
    BuildCanvas(win)
    BuildFooter(win)
    -- opening takes the Undo snapshot; closing keeps the edits
    win:HookScript("OnShow", function()
        browseCache = {}
        TakeSnapshot()
    end)
    win:HookScript("OnHide", function()
        dirty, snapshot = false, nil
        if popup then popup:Hide() end
        StopDrag()
    end)
    browseCache = {}
    TakeSnapshot()
end

--------------------------------------------------
-- 12. REFRESH
--------------------------------------------------
-- the Catalog alone (its category, that one's note and the filtered grid)
function RefreshBrowse()
    activeCategory = activeCategory or CATEGORIES[1].key
    local category
    for _, c in ipairs(CATEGORIES) do
        if c.key == activeCategory then category = c end
    end
    editor.catDrop:SetValueText(category and category.label or "")
    editor.catDrop:GenerateMenu()
    editor.categoryNote = category and category.note

    -- cached per opening; Radials depends on the edited radial and is rebuilt each time
    if activeCategory == "radials" then browseCache.radials = nil end
    local entries = browseCache[activeCategory]
    if not entries then
        entries = (category and category.build()) or {}
        browseCache[activeCategory] = entries
    end

    local filter = editor.search:GetText():lower()
    if filter ~= "" then
        local shown = {}
        for _, entry in ipairs(entries) do
            if EntryDisplay(entry):lower():find(filter, 1, true) then shown[#shown + 1] = entry end
        end
        entries = shown
    end
    editor.browseList:SetData(entries)
    editor.catCount:SetText(#entries == 1 and L["1 entry"] or L["%d entries"]:format(#entries))
    -- an empty grid says why: nothing found by the search, or nothing in this category yet
    local list = editor.browseList
    if not list.emptyText then
        list.emptyText = Panel.Plain(list, 11, UI.faint)
        list.emptyText:SetPoint("TOPLEFT", 8, -14)
        list.emptyText:SetPoint("TOPRIGHT", -8, -14)
        list.emptyText:SetJustifyH("CENTER")
    end
    local why = #entries == 0 and (filter ~= "" and L["Nothing matches your search."] or (category and category.empty) or L["Nothing here yet."]) or nil
    list.emptyText:SetText(why or "")
    list.emptyText:SetShown(why ~= nil)
end

-- the sidebar's rows: the radials this character gets in list order (groups' headings at their first
-- radial, their radials under them unless folded), the others under their own heading, then
-- Options. A search lists the radials whose names have its letters, and nothing else.
local function NavItems(perRadial)
    local rm = RM()
    local function Item(id, member)
        local available = rm:IsRadialAvailable(id)
        local beatenBy = perRadial[id] and perRadial[id].beatenBy
        return { id = id, available = available, member = member,
            key = available and rm:GetRadialKey(id) or rm:GetSharedKey(id),
            beaten = beatenBy ~= nil, beatenBy = beatenBy }
    end
    local out, other = {}, {}
    local filter = (editor.sideSearch:GetText() or ""):lower()
    if filter ~= "" then
        for _, id in ipairs(rm:GetRadialOrder()) do
            local data = rm:GetRadial(id)
            if data and (data.name or ""):lower():find(filter, 1, true) then out[#out + 1] = Item(id) end
        end
        for _, key in ipairs(ns.PRESET_ORDER) do
            if ns.PRESETS[key].name:lower():find(filter, 1, true) then out[#out + 1] = { preset = key } end
        end
        if L["Every radial"]:lower():find(filter, 1, true) then out[#out + 1] = { options = true } end
        if #out == 0 then out[1] = { head = L["Nothing matches"], faint = true } end
        return out
    end
    local counts, placed = {}, {}
    for _, id in ipairs(rm:GetRadialOrder()) do
        local data = rm:GetRadial(id)
        if data and data.group and rm:IsRadialAvailable(id) then counts[data.group] = (counts[data.group] or 0) + 1 end
    end
    for _, id in ipairs(rm:GetRadialOrder()) do
        local data = rm:GetRadial(id)
        if data then
            local available = rm:IsRadialAvailable(id)
            local gid = available and data.group and rm:GetGroup(data.group) and data.group
            if gid then
                local open = rm:IsGroupOpen(gid)
                if not placed[gid] then
                    placed[gid] = true
                    out[#out + 1] = { group = gid, count = counts[gid] or 0, open = open }
                end
                if open then out[#out + 1] = Item(id, true) end
            elseif available then
                out[#out + 1] = Item(id)
            else
                other[#other + 1] = Item(id)
            end
        end
    end
    if #other > 0 then
        out[#out + 1] = { head = L["Not on This Character"], fold = true, open = otherOpen, count = #other, faint = true }
        if otherOpen then for _, item in ipairs(other) do out[#out + 1] = item end end
    end
    out[#out + 1] = { head = L["Presets"], open = true }
    for _, key in ipairs(ns.PRESET_ORDER) do out[#out + 1] = { preset = key } end
    out[#out + 1] = { head = L["Options"], open = true }
    out[#out + 1] = { options = true }
    return out
end

-- what opens on this character: working keys in list order, then clashes
local function RefreshOverview(perRadial)
    local rm = RM()
    local lines, clashes = {}, {}
    for _, id in ipairs(rm:GetRadialOrder()) do
        local info = perRadial[id]
        if info then
            local name = rm:GetRadial(id).name
            if not info.beatenBy then
                local taken = GameAction(info.key)
                lines[#lines + 1] = "|cffc4a557" .. KeyText(info.key) .. "|r  " .. name
                    .. (taken and ("  |cffe8923a" .. L["also bound to %s"]:format(taken) .. "|r") or "")
            elseif info.tie then
                clashes[#clashes + 1] = "|cffe8923a" .. KeyText(info.key) .. "  " .. name .. " (" .. L["clash"] .. ")|r"
            end
        end
    end
    for _, line in ipairs(clashes) do lines[#lines + 1] = line end
    if #lines == 0 then lines[1] = "|cff7d7562" .. L["No keys yet."] .. "|r" end
    editor.overview:SetText(table.concat(lines, "\n"))
end

-- the page's header: the radial's name, where it sits (its group) and who gets it
local function RefreshHeader(radial)
    if editor.page ~= "radial" then return end
    editor.moreText = L["Click a slot on the wheel to choose it, drag it to move it, or fill the wheel from the Catalog. The Radial sheet holds who gets it and its key."]
    if not radial then
        editor.pageTitle:SetText(L["No radials yet"])
        editor.crumb:SetText(L["Create one with + New radial, below."])
        return
    end
    local list = CurrentList()
    local category = list ~= radial and list or nil
    if viewPreset then
        editor.moreText = L["A ready-made radial, to look at: click a category's slot twice, or choose it and Open, to see its buttons. Add to my radials makes a copy you can change."]
        local parts = { L["Presets"], radial.name }
        if category then parts[#parts + 1] = category.name end
        editor.pageTitle:SetText(radial.name)
        editor.crumb:SetText(table.concat(parts, "  >  ") .. "   " .. DOT .. "  " .. L["Read-only"])
        return
    end
    local parts = { L["Radials"] }
    local group = radial.group and RM():GetGroup(radial.group)
    if group then parts[#parts + 1] = group.name end
    parts[#parts + 1] = radial.name
    if category then parts[#parts + 1] = category.name end
    editor.pageTitle:SetText(radial.name)
    editor.crumb:SetText(table.concat(parts, "  >  ") .. "   " .. DOT .. "  " .. ScopeText(radial.scope, radial))
end

-- the chosen slot's card: the button, or what to do for one
local function RefreshSlot(radial)
    local entry = radial and selectedButton and radial.buttons[selectedButton]
    local category = entry and entry.kind == "category"
    editor.slot:SetShown(entry ~= nil)
    editor.slotChip:SetShown(entry ~= nil)
    editor.removeButton:SetShown(entry ~= nil and not viewPreset)
    editor.openButton:SetShown(category == true)
    editor.renameCatButton:SetShown(category == true and not viewPreset)
    editor.rankRow:SetShown(not category)
    editor.glyphRow:SetShown(category == true)
    editor.slotEmpty:SetShown(entry == nil)
    editor.slotEmpty:SetText(L["Choose a slot on the wheel."])
    if not entry then return end
    local n = #radial.buttons
    local name, icon = EntryDisplay(entry)
    ApplyIcon(editor.slotIcon, icon)
    editor.slotName:SetText(name)
    -- a spell's rank, when it has ranks ("Rank 3")
    local rank = entry.kind == "spell" and entry.id and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(entry.id)
    rank = type(rank) == "string" and rank:find("%d") and rank or nil
    local fact = rank
    if category then
        local count = #(entry.buttons or {})
        fact = count == 1 and L["1 button"] or L["%d buttons"]:format(count)
    end
    editor.slotKind:SetText((KINDS[entry.kind] or tostring(entry.kind)) .. (fact and (DOT .. fact) or ""))
    editor.slotChip:SetText(L["%d of %d"]:format(selectedButton, n))
    editor.slotPlace.value:SetText(L["%d of %d"]:format(selectedButton, n))
    editor.slotPlace.minus:SetEnabled(selectedButton > 1 and not viewPreset)
    editor.slotPlace.plus:SetEnabled(selectedButton < n and not viewPreset)
    for _, b in ipairs(editor.glyphButtons) do
        local on = category and b.glyph == (entry.glyph or "atease")
        b.Icon:SetAlpha(on and 1 or 0.4)
        b:SetEnabled(not viewPreset)
    end
    -- no rank: the row stays, greyed, saying when it applies
    local row = editor.rankRow
    row:SetAlpha(rank and 1 or 0.45)
    row.line:SetText(rank and L["Best known follows the ranks you learn"] or L["A spell with ranks only"])
    for _, b in ipairs(editor.rankSeg.buttons) do b:SetEnabled(rank ~= nil and not viewPreset) end
    editor.rankSeg:SetValue(rank and (entry.pinned and 2 or 1) or 0)
end

-- the canvas: the chosen radial's wheel
local function RefreshCanvas(radial)
    if not radial then
        editor.canvas:Draw({})
        return
    end
    local entries = {}
    for i, entry in ipairs(radial.buttons) do
        local name, icon = EntryDisplay(entry)
        entries[i] = { name = name, icon = icon }
    end
    local show = editor.show or {}
    editor.canvas:Draw({
        entries = entries,
        chosen = selectedButton,
        hint = (viewPreset and L["A preset: click a slot to see it  \194\183  click a category twice to open it"])
            or (#radial.buttons == 0 and L["Drag something from the Catalog onto the wheel, or click it."])
            or L["Click a slot to choose it  \194\183  drag it onto another to move it  \194\183  right-click removes"],
        -- a preset takes nothing: no empty slot to drop on
        names = show.names, numbers = show.numbers, empty = show.empty and not viewPreset,
    })
end

function Refresh()
    if not (editor and editor:IsShown()) then return end
    local rm = RM()
    local radial = CurrentRadial()
    local list = CurrentList()
    if list and selectedButton and selectedButton > #list.buttons then selectedButton = nil end
    -- a preset has no Radial sheet
    editor.tabs.radial:SetShown(editor.page == "radial" and not viewPreset)
    if viewPreset and editor.sheet == "radial" then editor.ShowPage("radial", "wheel") return end
    local _, perRadial = rm:ResolveKeys()

    editor.radialList:SetData(NavItems(perRadial))
    RefreshOverview(perRadial)
    RefreshHeader(viewPreset and ns.PRESETS[viewPreset] or radial)

    local has = radial ~= nil and not viewPreset
    editor.radialContent:SetShown(has)
    editor.radialEmpty:SetShown(radial == nil)
    editor.keyChip:SetShown(has and not openSlot)
    editor.backButton:SetShown(openSlot ~= nil)
    editor.wheelCard.title:SetText(openSlot and list.name or L["Wheel"])
    editor.countText:SetShown(list ~= nil)
    editor.slotCard:SetShown(list ~= nil)
    editor.catalogCard:SetShown(has)
    editor.presetCard:SetShown(viewPreset ~= nil)
    if viewPreset then
        editor.countText:SetText(L["%d of %d buttons"]:format(#list.buttons, rm.MAX_BUTTONS))
        local names = {}
        for _, id in ipairs(rm:PresetCopies(viewPreset)) do names[#names + 1] = rm:GetRadial(id).name end
        editor.presetCopies:SetText(#names > 0 and L["Your copies: %s"]:format(table.concat(names, ", "))
            or L["No copy yet."])
    end
    if has then
        local preset = radial.preset and ns.PRESETS[radial.preset]
        editor.resetButton:SetEnabled(preset ~= nil)
        editor.presetLine:SetText(preset and L["Copied from %s: put it back as it comes"]:format(preset.name)
            or L["Not made from a preset"])
        local key = rm:GetRadialKey(editingID)
        editor.keyChip:SetText((key and key ~= "") and KeyText(key) or L["no key"])
        editor.countText:SetText(L["%d of %d buttons"]:format(#list.buttons, rm.MAX_BUTTONS))
        editor.scopeDrop:SetValueText(ScopeText(radial.scope, radial))
        editor.scopeDrop:GenerateMenu()
        editor.ownKey:SetOn(rm:HasOwnKey(editingID))
        if not editor.keyButton.waiting then editor.keyButton:ShowKey(key or "") end
        editor.nameLine:SetText(radial.name)
    end
    RefreshSlot(list)
    RefreshCanvas(list)
    editor.undoButton:SetEnabled(dirty == true)
    editor.changed:SetShown(dirty == true)
    if has then RefreshBrowse() end
end

--------------------------------------------------
-- 13. PUBLIC
--------------------------------------------------
-- used by UI/Window.lua
ns.RadialEditorEmbed = {
    Build = Build,
    Refresh = function() if editor then Refresh() end end,
    -- the chosen slot (the harness's way to read it)
    Chosen = function() return editingID, selectedButton end,
    -- the category open on the wheel, and the preset viewed
    Open = function() return openSlot, viewPreset end,
}
