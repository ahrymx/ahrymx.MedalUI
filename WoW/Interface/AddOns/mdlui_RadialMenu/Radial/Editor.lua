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
    end
    return false
end

AddCategory("radials", L["Radials"], function()
    local out = {}
    for _, id in ipairs(RM():GetRadialsByName()) do
        if not ContainsRadial(id, editingID) then out[#out + 1] = { kind = "subradial", radial = id } end
    end
    return out
end, L["Creates sub-radials. Use the mouse wheel while hovering it in the radial menu to flip through its buttons."], L["No other radials yet: make one and it can open from here."])

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

local function Changed()
    dirty = true
    RM():RadialChanged(editingID)
end

local function InsertEntry(entry, atIndex)
    local radial = CurrentRadial()
    if not (radial and entry) then return end
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
    local radial = CurrentRadial()
    if not radial then return end
    to = math.max(1, math.min(#radial.buttons, to))
    if from == to then return end
    table.insert(radial.buttons, to, table.remove(radial.buttons, from))
    selectedButton = to
    Changed()
    Refresh()
end

local function RemoveButton(index)
    local radial = CurrentRadial()
    if not (radial and radial.buttons[index]) then return end
    table.remove(radial.buttons, index)
    if selectedButton and selectedButton > #radial.buttons then selectedButton = #radial.buttons end
    Changed()
    Refresh()
end

-- nothing is on the game cursor during an internal drag, so OnReceiveDrag never fires. On the canvas
-- (UI/Canvas.lua): dropped on a slot, a button takes its place and a Catalog entry goes in there; on
-- the empty slot, at the end. A button dropped off the canvas comes off the radial.
local function FinishDrag()
    local payload = dragging
    StopDrag()
    if not (payload and editor) then return end

    local target, empty = editor.canvas:SlotUnderMouse()
    local overCanvas = target ~= nil or editor.stage:IsMouseOver()
    local radial = CurrentRadial()
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
-- mdlui_RadialMenu's own, in the Unit Frame Editor's layout (FlareUI's builders are gone): UI/Window.lua
-- makes the window and hands its parts here. The list box: the radials, grouped, and what opens on
-- this character at its foot. The canvas (UI/Canvas.lua): the chosen radial's wheel, a slot per
-- button. The body: the radial's name and Delete over its tabs, Radial (who gets it, its key, Macro,
-- Copy, Rename), Slot (the chosen button) and Catalog (what to put on it); Look is the window's.
--------------------------------------------------
local Panel = ns.SettingsPanel
local UI = ns.ui
local RADIAL_ROW_H = 22
local LIST_ROWS = 16             -- the radials list, above "On this character"
local OVERVIEW_Y = 368           -- that one's hairline, from the list box's top
local GRID_ROW_H = 30            -- the Catalog's rows (three columns)
local GRID_RIM = 24              -- a Catalog entry's round icon
local SLOT_RIM = 42              -- the chosen button's icon on the Slot tab
local ROW_GAP = 30               -- a row (24) and the space under it

-- what kind of button a slot holds, on the Slot tab
local KINDS = {
    spell = L["Spell"], item = L["Item"], mount = L["Mount"], macro = L["Macro"], emote = L["Emote"],
    targetmarker = L["Target marker"], worldmarker = L["World marker"], subradial = L["Radial"],
    micromenu = L["Panel"], partycast = L["Party spell"], questitems = L["Quest Items"],
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
    if id == editingID then return end
    editingID, selectedButton = id, nil
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

-- the radials in the list box, grouped (a group's head folds it, its radials sit in under it), the
-- ones not on this character under a caption; "On this character" at the box's foot
local function BuildList(host, box)
    local list = CreateList(box, 156, 1, LIST_ROWS, RADIAL_ROW_H,
        function(cell)
            Panel.Rounded(cell.Highlight, UI.selected[1], UI.selected[2], UI.selected[3], 1)
            cell.Icon:SetSize(14, 14)
            Panel.Heading(cell.Text, 13, UI.text)
            cell.Key = Panel.Plain(cell, 10, UI.faint)
            cell.Key:SetPoint("RIGHT", -12, 0)
            cell.Key:SetJustifyH("RIGHT")
            cell.Mark = Panel.Fill(cell, "ARTWORK", UI.gold)
            cell.Mark:SetSize(4, 4)
            cell.Mark:SetPoint("RIGHT", -5, 0)
            cell.Head = Panel.Plain(cell, 9, UI.goldDark)
            cell.Head:SetPoint("BOTTOMLEFT", 6, 3)
            cell.Fold = Panel.Plain(cell, 11, UI.gold)
            cell.Fold:SetPoint("BOTTOMRIGHT", -12, 1)
            -- left: a radial to edit, a group folds or opens; right: the group menus
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:SetScript("OnClick", function(self, mouseButton)
                local item = self.item
                if not item then return end
                if item.group then
                    if mouseButton == "RightButton" then GroupMenu(self, item.group) return end
                    ns.ButtonSound()
                    RM():SetGroupOpen(item.group, not RM():IsGroupOpen(item.group))
                    Refresh()
                elseif item.id then
                    if mouseButton == "RightButton" then RadialRowMenu(self, item.id) return end
                    ns.ButtonSound()
                    SelectRadial(item.id)
                end
            end)
            cell:SetScript("OnEnter", function(self)
                if self.item and self.item.group then
                    ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                    local group = RM():GetGroup(self.item.group)
                    GameTooltip:AddLine(group and group.name or "", 1, 1, 1)
                    GameTooltip:AddLine(L["Click to open or close. Right-click to rename or ungroup. Drag to move."], 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                    return
                end
                local id = self.item and self.item.id
                local data = id and RM():GetRadial(id)
                if not data then return end
                ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(data.name, 1, 1, 1)
                GameTooltip:AddLine(ScopeText(data.scope, data))
                if not RM():IsRadialAvailable(id) then GameTooltip:AddLine(L["Not available on this character."], 0.6, 0.6, 0.6) end
                local winner = self.item.beatenBy and RM():GetRadial(self.item.beatenBy)
                if winner then GameTooltip:AddLine(L["%s opens %s on this character."]:format(KeyText(self.item.key), winner.name), 1, 0.6, 0) end
                GameTooltip:AddLine(L["Right-click for its group. Drag to move it."], 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            -- drag a radial over another to put it there; a name follows the cursor
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", function(self)
                local item = self.item
                if not (item and (item.id or item.group)) then return end
                GameTooltip:Hide()
                RadialDrag.Start(item.id or ("group:" .. item.group))
            end)
            cell:SetScript("OnDragStop", function() RadialDrag.Stop(host.radialList) end)
        end,
        function(cell, item)
            cell.Head:Hide()
            cell.Fold:Hide()
            cell.Mark:Hide()
            cell.Highlight:Hide()
            -- a caption: the radials not on this character
            if item.header then
                cell.Icon:Hide()
                cell.Text:Hide()
                cell.Key:Hide()
                cell.Head:SetText(item.header:upper())
                cell.Head:SetTextColor(UI.faint[1], UI.faint[2], UI.faint[3])
                cell.Head:Show()
                cell:EnableMouse(false)
                return
            end
            cell:EnableMouse(true)
            -- a group: its name (and, folded, its count) in capitals, - / + at the right
            if item.group then
                local group = RM():GetGroup(item.group)
                cell.Icon:Hide()
                cell.Text:Hide()
                cell.Key:Hide()
                local name = group and group.name or ""
                cell.Head:SetText((item.open and name or (name .. " (" .. item.count .. ")")):upper())
                cell.Head:SetTextColor(UI.goldDark[1], UI.goldDark[2], UI.goldDark[3])
                cell.Head:Show()
                cell.Fold:SetText(item.open and "-" or "+")
                cell.Fold:Show()
                return
            end
            -- a radial: who gets it (a narrowed one's icon), its name, its key; the chosen one lit
            local data = RM():GetRadial(item.id)
            local chosen = item.id == editingID
            local left = item.indent and 14 or 8
            cell.Icon:ClearAllPoints()
            cell.Icon:SetPoint("LEFT", left, 0)
            local icon = ApplyScopeIcon(cell.Icon, data.scope)
            cell.Icon:SetShown(icon)
            cell.Icon:SetDesaturated(not item.available)
            cell.Icon:SetAlpha(item.available and 1 or 0.5)
            cell.Text:ClearAllPoints()
            if icon then cell.Text:SetPoint("LEFT", cell.Icon, "RIGHT", 4, 0) else cell.Text:SetPoint("LEFT", left, 0) end
            cell.Text:SetPoint("RIGHT", cell.Key, "LEFT", -4, 0)
            cell.Text:SetText(data.name)
            local c = chosen and UI.goldBright or (item.available and UI.text or UI.faint)
            cell.Text:SetTextColor(c[1], c[2], c[3])
            cell.Text:Show()
            local k = item.beaten and UI.clash or (chosen and UI.gold or UI.faint)
            cell.Key:SetText(item.key and KeyText(item.key) or "")
            cell.Key:SetTextColor(k[1], k[2], k[3])
            cell.Key:Show()
            cell.Highlight:SetShown(chosen)
            cell.Mark:SetShown(chosen)
        end)
    list:SetPoint("TOPLEFT", 4, -4)
    host.radialList = list

    local line = Panel.Fill(box, "ARTWORK", UI.line)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, -OVERVIEW_Y)
    line:SetPoint("TOPRIGHT", -8, -OVERVIEW_Y)
    local title = Panel.Caption(box, ns.Settings:Text("rm.overview", "label"))
    title:SetPoint("TOPLEFT", 10, -OVERVIEW_Y - 10)
    host.overviewTitle = title
    local overview = Panel.Plain(box, 11)
    overview:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    overview:SetWidth(140)
    overview:SetJustifyV("TOP")
    overview:SetSpacing(3)
    overview:SetMaxLines(6)
    host.overview = overview
    local hover = CreateFrame("Frame", nil, box)
    hover:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, 0)
    hover:SetPoint("BOTTOMRIGHT", -8, 4)
    hover:EnableMouse(true)
    Hover(hover, "rm.overview")
end

-- the body's head (the radial's name, Delete) and its Radial tab
local function BuildRadialTab(host, win)
    local S = ns.Settings
    local body = win.body
    host.nameText = Panel.Serif(body, 16, UI.goldBright)
    host.nameText:SetPoint("TOPLEFT", 0, -2)
    host.nameText:SetWidth(180)
    host.nameText:SetJustifyH("LEFT")
    host.nameText:SetWordWrap(false)
    host.deleteButton = Panel.UButton(body, L["Delete..."], 80, 22)
    host.deleteButton:SetPoint("TOPRIGHT", 0, 0)
    host.deleteButton:SetScript("OnClick", function()
        ns.ButtonSound()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        ns.ShowDialog("MDLUI_RADIAL_DELETE", radial.name or "", { id = editingID })
    end)

    local page = win.pages.radial
    local content = CreateFrame("Frame", nil, page)
    content:SetAllPoints()
    host.radialContent = content
    host.radialEmpty = Panel.Plain(page, 11, UI.dim)
    host.radialEmpty:SetPoint("TOPLEFT", 0, -2)
    host.radialEmpty:SetWidth(270)
    host.radialEmpty:SetText(L["No radials yet. Create one with + New radial."])

    -- who gets it
    local row = Panel.Row(content, 0, S:Text("rm.scope", "label"))
    Hover(row, "rm.scope")
    host.scopeLabel = row.label
    local scope = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    scope:SetWidth(150)
    scope:SetPoint("RIGHT", 0, 0)
    scope:SetupMenu(function(_, root)
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
    Hover(scope, "rm.scope")
    host.scopeDrop = scope

    -- its key
    row = Panel.Row(content, ROW_GAP, S:Text("rm.key", "label"))
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
    host.keyButton:SetSize(150, 22)
    host.keyButton:SetPoint("RIGHT", 0, 0)
    Hover(host.keyButton, "rm.key")

    -- this character's own key
    row = Panel.Row(content, 2 * ROW_GAP, S:Text("rm.ownKey", "label"))
    Hover(row, "rm.ownKey")
    host.ownKey = Panel.Switch(row, function(self)
        if editingID then RM():SetOwnKey(editingID, self:GetChecked() and true or false) end
        Changed()
        Refresh()
    end)
    host.ownKey:SetPoint("RIGHT", -2, 0)
    Hover(host.ownKey, "rm.ownKey")

    local line = Panel.Fill(content, "ARTWORK", UI.line)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -(3 * ROW_GAP + 4))
    line:SetPoint("TOPRIGHT", 0, -(3 * ROW_GAP + 4))

    -- a macro that opens it (made on the spot and put on the cursor), a copy, a new name
    local y = 3 * ROW_GAP + 16
    host.macroButton = Panel.UButton(content, L["Macro"], 86, 24)
    host.macroButton:SetPoint("TOPLEFT", 0, -y)
    host.macroButton:SetScript("OnClick", function()
        ns.ButtonSound()
        CreateRadialMacro()
    end)
    Hover(host.macroButton, "rm.macroCreate")
    host.copyButton = Panel.UButton(content, L["Copy"], 86, 24)
    host.copyButton:SetPoint("TOPLEFT", 92, -y)
    host.copyButton:SetScript("OnClick", function()
        ns.ButtonSound()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        editingID, selectedButton = RM():CopyRadial(editingID, L["%s (copy)"]:format(radial.name)), nil
        Changed()
        Refresh()
    end)
    Hover(host.copyButton, "rm.copy")
    host.renameButton = Panel.UButton(content, L["Rename..."], 86, 24)
    host.renameButton:SetPoint("TOPLEFT", 184, -y)
    host.renameButton:SetScript("OnClick", function()
        ns.ButtonSound()
        ShowNamePopup(true)
    end)
end

-- the chosen button, on the Slot tab: its icon, name and kind, its place, a spell's rank, Remove
local function BuildSlotTab(host, win)
    local page = win.pages.slot
    local slot = CreateFrame("Frame", nil, page)
    slot:SetAllPoints()
    host.slot = slot
    host.slotEmpty = Panel.Plain(page, 11, UI.dim)
    host.slotEmpty:SetPoint("TOPLEFT", 0, -2)
    host.slotEmpty:SetWidth(270)

    local icon = CreateFrame("Frame", nil, slot)
    icon:SetSize(SLOT_RIM, SLOT_RIM)
    icon:SetPoint("TOPLEFT", 0, -2)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetPoint("CENTER")
    MakeRound(icon, SLOT_RIM)
    host.slotIcon = icon
    host.slotName = Panel.Serif(slot, 14, UI.text)
    host.slotName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -5)
    host.slotName:SetWidth(270 - SLOT_RIM - 10)
    host.slotName:SetJustifyH("LEFT")
    host.slotName:SetWordWrap(false)
    host.slotKind = Panel.Plain(slot, 11, UI.dim)
    host.slotKind:SetPoint("TOPLEFT", host.slotName, "BOTTOMLEFT", 0, -5)
    host.slotKind:SetWidth(270 - SLOT_RIM - 10)
    host.slotKind:SetWordWrap(false)

    -- its place on the wheel, a step either way
    local top = 56
    local row = Panel.Row(slot, top, L["Place"])
    Tip(row, L["Place"], L["Where the button sits on the wheel: 1 at the top, then clockwise. You can drag it on the wheel too."])
    local place = Panel.Stepper(row, 48, "<", ">")
    place:SetPoint("RIGHT", 0, 0)
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
    row = Panel.Row(slot, top + ROW_GAP, L["Rank"])
    Tip(row, L["Rank"], L["Best known: casts the best rank you know, and follows new ones as you learn them. This rank: stays on the rank it has (one put on below your best is kept there)."])
    host.rankSeg = Panel.Segment(row, { L["Best known"], L["This rank"] }, function(i)
        local radial = CurrentRadial()
        local entry = radial and selectedButton and radial.buttons[selectedButton]
        if not entry then return end
        entry.pinned = (i == 2) or nil
        Changed()
        Refresh()
    end)
    host.rankSeg:SetPoint("RIGHT", 0, 0)
    host.rankRow = row

    local line = Panel.Fill(slot, "ARTWORK", UI.line)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -(top + 2 * ROW_GAP + 4))
    line:SetPoint("TOPRIGHT", 0, -(top + 2 * ROW_GAP + 4))
    host.removeButton = Panel.UButton(slot, L["Remove"], 110, 22)
    host.removeButton:SetPoint("TOPRIGHT", 0, -(top + 2 * ROW_GAP + 14))
    host.removeButton:SetScript("OnClick", function()
        ns.ButtonSound()
        if selectedButton then RemoveButton(selectedButton) end
    end)
    Tip(host.removeButton, L["Remove"], L["Takes the button off this radial. Undo changes brings it back."])
end

-- the Catalog tab: its categories as links (the open one lit, slashes between them on a line), then
-- a three-column grid; how to add, and the search, at the foot
local function BuildCatalogTab(host, win)
    local page = win.pages.catalog
    local width, pageH = 270, win.PAGE_H or 422
    local LINK_H, SLASH_W = 18, 14
    local links, x, y = {}, 0, 0
    for i, c in ipairs(CATEGORIES) do
        local link = CreateFrame("Button", nil, page)
        local fs = link:CreateFontString(nil, "OVERLAY")
        Panel.Heading(fs, 12, UI.dim)
        fs:SetPoint("LEFT", 0, 0)
        link:SetFontString(fs)
        link.label = fs
        link:SetText(c.label)
        local w = math.ceil(fs:GetStringWidth() or 0) + 2
        link:SetSize(w, LINK_H)
        link.key = c.key
        link:SetScript("OnClick", function()
            ns.ButtonSound()
            activeCategory = c.key
            host.search:SetText("")
            RefreshBrowse()
        end)
        link:SetScript("OnEnter", function(self)
            if self.key ~= activeCategory then self.label:SetTextColor(UI.text[1], UI.text[2], UI.text[3]) end
        end)
        link:SetScript("OnLeave", function() host.PaintCategories() end)
        -- the next line when it would run past the tab; else a slash before it
        if x > 0 and x + SLASH_W + w > width then
            x, y = 0, y + LINK_H
        elseif x > 0 then
            local slash = Panel.Serif(page, 12, UI.goldDark)
            slash:SetText("/")
            slash:SetPoint("CENTER", page, "TOPLEFT", x + SLASH_W / 2, -y - LINK_H / 2)
            x = x + SLASH_W
        end
        link:SetPoint("TOPLEFT", x, -y)
        x = x + w
        links[i] = link
    end
    host.categoryLinks = links
    host.PaintCategories = function()
        for _, link in ipairs(links) do
            local c = link.key == activeCategory and UI.goldBright or UI.dim
            link.label:SetTextColor(c[1], c[2], c[3])
        end
    end

    local gridTop = y + LINK_H + 8
    local rows = math.max(4, math.floor((pageH - gridTop - 56) / GRID_ROW_H))
    local browseList = CreateList(page, width, 3, rows, GRID_ROW_H,
        function(cell)
            MakeRound(cell, GRID_RIM)
            cell.Icon:ClearAllPoints()
            cell.Icon:SetPoint("CENTER", cell, "LEFT", 2 + GRID_RIM / 2, 0)
            cell.Text:SetPoint("LEFT", cell, "LEFT", 2 + GRID_RIM + 5, 0)
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
                local radial = CurrentRadial()
                local after = radial and selectedButton and selectedButton <= #radial.buttons and selectedButton + 1 or nil
                InsertEntry(self.item, after)
            end)
        end,
        function(cell, entry)
            local name, icon = EntryDisplay(entry)
            ApplyIcon(cell, icon)
            cell.Text:SetText(name)
        end)
    browseList:SetPoint("TOPLEFT", 0, -gridTop)
    host.browseList = browseList

    local hint = Panel.Plain(page, 11, UI.faint)
    hint:SetPoint("BOTTOMLEFT", 0, 30)
    hint:SetWidth(width)
    hint:SetText(L["Click adds after the chosen slot, or drag onto the wheel."])
    local search = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
    search:SetSize(width - 6, 22)
    search:SetPoint("BOTTOMLEFT", 6, 2)
    search:HookScript("OnTextChanged", function() if editor and editor:IsShown() then RefreshBrowse() end end)
    host.search = search
end

-- the canvas: the chosen radial's wheel, its slots chosen, moved, filled and emptied there
local function BuildCanvas(host, win)
    host.stage = win.stage
    host.canvas = ns.RadialCanvas.Create(win.stage, {
        choose = function(i)
            -- something on the game cursor goes in at this slot
            local entry = EntryFromCursor()
            if entry then InsertEntry(entry, i) return end
            ns.ButtonSound()
            selectedButton = i
            win.ShowTab("slot")
            Refresh()
        end,
        remove = function(i) RemoveButton(i) end,
        drop = function(i)
            local entry = EntryFromCursor()
            if entry then
                InsertEntry(entry, i)
            elseif not i then
                -- the empty slot, clicked: the Catalog, to fill it from
                ns.ButtonSound()
                win.ShowTab("catalog")
            end
        end,
        startDrag = function(i)
            local radial = CurrentRadial()
            local entry = radial and radial.buttons[i]
            if entry then StartDrag({ from = i, entry = entry }) end
        end,
        finishDrag = FinishDrag,
        enter = function(hit)
            if hit.ghost then
                ns.OwnGameTooltip(hit, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["Empty slot"], 1, 1, 1)
                GameTooltip:AddLine(L["Drop something here, or click to open the Catalog."], nil, nil, nil, true)
                GameTooltip:Show()
                return
            end
            local radial = CurrentRadial()
            local entry = radial and radial.buttons[hit.index]
            if entry then EntryTooltip(hit, entry, L["Click to choose it. Drag it onto another slot to move it; right-click removes."]) end
        end,
    })
end

-- the footer's buttons the editor answers: + New radial, Undo changes
local function BuildFooter(host, win)
    host.newButton = win.newButton
    host.newButton:SetScript("OnClick", function()
        ns.ButtonSound()
        ShowNamePopup(false)
    end)
    Hover(host.newButton, "rm.new")
    host.undoButton = win.undoButton
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
    BuildList(win, win.list)
    BuildRadialTab(win, win)
    BuildSlotTab(win, win)
    BuildCatalogTab(win, win)
    BuildCanvas(win, win)
    BuildFooter(win, win)
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
-- the Catalog alone (categories, their note and the filtered grid)
function RefreshBrowse()
    activeCategory = activeCategory or CATEGORIES[1].key
    local category
    for _, c in ipairs(CATEGORIES) do
        if c.key == activeCategory then category = c end
    end
    editor.PaintCategories()
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
    -- an empty grid says why: nothing found by the search, or nothing in this category yet
    local list = editor.browseList
    if not list.emptyText then
        list.emptyText = Panel.Plain(list, 11, UI.faint)
        list.emptyText:SetPoint("TOPLEFT", 8, -14)
        list.emptyText:SetPoint("TOPRIGHT", -8, -14)
        list.emptyText:SetJustifyH("CENTER")
    end
    -- (a category without its own message: a plain one)
    local why = #entries == 0 and (filter ~= "" and L["Nothing matches your search."] or (category and category.empty) or L["Nothing here yet."]) or nil
    list.emptyText:SetText(why or "")
    list.emptyText:SetShown(why ~= nil)
end

-- the radials list: the ones this character gets in list order, then the others under a caption;
-- and what opens on this character
local function RefreshRadialColumn(perRadial)
    local rm = RM()
    local here, other = {}, {}
    -- groups: a row before their first radial here, then their radials unless folded; the radials
    -- not on this character stay ungrouped under the caption
    local counts, placed = {}, {}
    for _, id in ipairs(rm:GetRadialOrder()) do
        local data = rm:GetRadial(id)
        if data and data.group and rm:IsRadialAvailable(id) then counts[data.group] = (counts[data.group] or 0) + 1 end
    end
    for _, id in ipairs(rm:GetRadialOrder()) do
        local data = rm:GetRadial(id)
        if data then
            local available = rm:IsRadialAvailable(id)
            local key = available and rm:GetRadialKey(id) or rm:GetSharedKey(id)
            local beatenBy = perRadial[id] and perRadial[id].beatenBy
            local item = { id = id, available = available, key = key, beaten = beatenBy ~= nil, beatenBy = beatenBy }
            local gid = available and data.group and rm:GetGroup(data.group) and data.group
            if gid then
                local open = rm:IsGroupOpen(gid)
                if not placed[gid] then
                    placed[gid] = true
                    here[#here + 1] = { group = gid, count = counts[gid] or 0, open = open }
                end
                if open then item.indent = true; here[#here + 1] = item end
            elseif available then
                here[#here + 1] = item
            else
                other[#other + 1] = item
            end
        end
    end
    if #other > 0 then
        here[#here + 1] = { header = L["Not on This Character"] }
        for _, item in ipairs(other) do here[#here + 1] = item end
    end
    editor.radialList:SetData(here)

    -- what opens on this character: working keys in list order, then clashes
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

-- the Slot tab: the chosen button, or what to do for one
local function RefreshSlot(radial)
    local entry = radial and selectedButton and radial.buttons[selectedButton]
    editor.slot:SetShown(entry ~= nil)
    editor.slotEmpty:SetShown(entry == nil)
    editor.slotEmpty:SetText(radial and L["Choose a slot on the wheel."] or L["No radials yet. Create one with + New radial."])
    if not entry then return end
    local n = #radial.buttons
    local name, icon = EntryDisplay(entry)
    ApplyIcon(editor.slotIcon, icon)
    editor.slotName:SetText(name)
    -- a spell's rank, when it has ranks ("Rank 3")
    local rank = entry.kind == "spell" and entry.id and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(entry.id)
    rank = type(rank) == "string" and rank:find("%d") and rank or nil
    editor.slotKind:SetText((KINDS[entry.kind] or tostring(entry.kind)) .. (rank and (DOT .. rank) or "")
        .. DOT .. L["slot %d of %d"]:format(selectedButton, n))
    editor.slotPlace.value:SetText(L["%d of %d"]:format(selectedButton, n))
    editor.slotPlace.minus:SetEnabled(selectedButton > 1)
    editor.slotPlace.plus:SetEnabled(selectedButton < n)
    editor.rankRow:SetShown(rank ~= nil)
    editor.rankSeg:SetValue(entry.pinned and 2 or 1)
end

-- the canvas: the chosen radial's wheel, whose it is and its key over it
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
    local key = RM():GetRadialKey(editingID)
    local show = editor.show or {}
    editor.canvas:Draw({
        entries = entries,
        chosen = selectedButton,
        scope = radial.name .. DOT .. ScopeText(radial.scope, radial) .. DOT
            .. ((key and key ~= "") and ("|cffc4a557" .. KeyText(key) .. "|r") or L["no key"]),
        count = L["%d of %d buttons"]:format(#radial.buttons, RM().MAX_BUTTONS),
        hint = #radial.buttons == 0 and L["Drag something from the Catalog onto the wheel, or click it."]
            or L["Click a slot to choose it. Drag it onto another to move it; right-click removes."],
        names = show.names, numbers = show.numbers, empty = show.empty,
    })
end

function Refresh()
    if not (editor and editor:IsShown()) then return end
    local rm = RM()
    local radial = CurrentRadial()
    if radial and selectedButton and selectedButton > #radial.buttons then selectedButton = nil end
    local _, perRadial = rm:ResolveKeys()

    RefreshRadialColumn(perRadial)

    local has = radial ~= nil
    editor.nameText:SetShown(has)
    editor.deleteButton:SetShown(has)
    editor.radialContent:SetShown(has)
    editor.radialEmpty:SetShown(not has)
    if has then
        editor.nameText:SetText(radial.name)
        editor.scopeDrop:SetDefaultText(ScopeText(radial.scope, radial))
        editor.scopeDrop:GenerateMenu()
        editor.ownKey:SetOn(rm:HasOwnKey(editingID))
        if not editor.keyButton.waiting then editor.keyButton:ShowKey(rm:GetRadialKey(editingID) or "") end
    end
    RefreshSlot(radial)
    RefreshCanvas(radial)
    editor.undoButton:SetEnabled(dirty == true)

    RefreshBrowse()
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
}
