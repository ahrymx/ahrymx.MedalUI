-- The player's timeless buffs (a mount, a form, an aura: anything without
-- an expiry), in a column above the portrait's medallion. Buffs that run
-- out stay in Blizzard's buff frame until the user decides where they go.
--
-- The quest tracker's full view stands where the column would, with an
-- empty row beside the medallion: it asks for the buffs there instead, left
-- to right (ns.BuffRow{ x, y, bare }: the first icon's left edge from the
-- screen's, the row's middle from the strip art's top, and minimal mode's
-- tiles' middle), and ns.BuffRow()
-- gives the column back.
--
-- Which buffs are timeless can be secret in combat (Forever and retail:
-- DoesAuraHaveExpirationTime is restricted with the rest of the aura API),
-- so a buff is sorted when it arrives if the client allows, and otherwise
-- at the end of combat, when the whole list is read again. Each is kept by
-- its aura instance, which is never secret for the player's own auras.
--
-- While the chat is bare (minimal mode: the chat's box faded out when
-- idle) the row is soft tiles instead, the squares again as the box comes
-- back (2026-11-25, the user's pick C of /workspace/buffs-sheet.png): no
-- rim, each icon's corners rounded, a soft shadow under it and a faint
-- light edge round it, in the row's place.
--
-- The icons are plain buttons, not secure ones: a right click cancels the
-- buff out of combat, and does nothing in it. The chat's edit box shares
-- the row's margin, over the strips: it leaves the row the pointer
-- (strips/chat.lua, Lit).
local _, ns = ...

local Auras = C_UnitAuras
local L = ns.stripLayout
local ICON, GAP = 29, 4
local TILE, TILE_GAP = 24, 3     -- minimal mode's tiles, and the room between them
local ROUNDED = ns.media .. "strips\\rounded"

local known = {}        -- auraInstanceID -> { icon, count } if timeless, false if timed
local unsorted = false  -- a buff could not be sorted in combat: read them all after it
local buttons = {}
local row               -- the quest tracker's row, while it asks for one

-- true for a timeless buff, false for a timed one, nil if the client will not say
local function Timeless(aura)
    local timed
    if Auras.DoesAuraHaveExpirationTime and not ns.IsSecret(aura.auraInstanceID) then
        local ok, res = pcall(Auras.DoesAuraHaveExpirationTime, "player", aura.auraInstanceID)
        if ok then timed = res end
    else
        timed = aura.expirationTime
        if not ns.IsSecret(timed) then timed = timed ~= nil and timed > 0 end
    end
    if ns.IsSecret(timed) or timed == nil then return nil end
    return not timed
end

local function Count(aura)
    local n = aura.applications
    if ns.IsSecret(n) or not n or n < 2 then return "" end
    return n
end

-- before: what a full read knew already, so a buff it cannot sort now (in
-- combat) keeps what it was
local function Add(aura, before)
    local id = aura.auraInstanceID
    if ns.IsSecret(id) then
        unsorted = true
        return
    end
    local timeless = Timeless(aura)
    if timeless == nil then
        local was = before and before[id]
        if was ~= nil then
            known[id] = was
            if was then was.count = Count(aura) end
        else
            unsorted = true
        end
    elseif timeless then
        known[id] = { icon = aura.icon, count = Count(aura) }
    else
        known[id] = false
    end
end

local function Button(i)
    if buttons[i] then return buttons[i] end
    local btn = CreateFrame("Button", nil, ns.strips[-1])
    btn:SetFrameLevel(ns.levels.stripTop)
    btn:SetSize(ICON, ICON)
    local rim = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    rim:SetAllPoints()
    rim:SetColorTexture(0.54, 0.44, 0.20, 1)
    local ink = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(unpack(ns.colors.ink))
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.square = { rim, ink, btn.icon }
    -- the tile: a soft shadow (two of the rounded art, wider and fainter
    -- out), a faint light edge, the icon's corners rounded
    local function Rounded(sub, out, down, r, g, b, a)
        local t = btn:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetTexture(ROUNDED)
        t:SetPoint("TOPLEFT", -out, out - down)
        t:SetPoint("BOTTOMRIGHT", out, -out - down)
        t:SetVertexColor(r, g, b, a)
        return t
    end
    local tile = btn:CreateTexture(nil, "ARTWORK")
    tile:SetAllPoints()
    tile:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if btn.CreateMaskTexture and tile.AddMaskTexture then
        local mask = btn:CreateMaskTexture()
        mask:SetTexture(ROUNDED, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(tile)
        tile:AddMaskTexture(mask)
    end
    btn.tile = tile
    btn.soft = { Rounded(3, 2.5, 1.5, 0, 0, 0, 0.25), Rounded(4, 1, 1.5, 0, 0, 0, 0.45),
        Rounded(5, 1, 0, 1, 0.94, 0.78, 0.22), tile }
    btn.count = ns.Text(btn, 10)
    btn.count:SetPoint("BOTTOMRIGHT", -1, 2)
    btn:RegisterForClicks("RightButtonUp")
    btn:SetScript("OnClick", function(self)
        if InCombatLockdown() or not self.id then return end
        if Auras.CancelAuraByInstanceID then Auras.CancelAuraByInstanceID("player", self.id) end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetUnitAuraByAuraInstanceID then
            GameTooltip:SetUnitAuraByAuraInstanceID("player", self.id)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    buttons[i] = btn
    return btn
end

-- bare: the chat's box past half faded out (strips/chat.lua)
local function Bare()
    local chrome = ns.chatChrome
    return ns.db ~= nil and ns.db.chatImmersion and chrome ~= nil and chrome.alpha < 0.5 or false
end
local bare = false

-- the tiles' row's width, n of them
local function TilesWidth(n)
    return n * TILE + (n - 1) * TILE_GAP
end

-- Up from the medallion's ring, oldest at the bottom; or along the
-- tracker's row, oldest at the left; in minimal mode, as tiles there.
local function Layout()
    bare = Bare() and row ~= nil
    local ids = {}
    for id, buff in pairs(known) do
        if buff then table.insert(ids, id) end
    end
    table.sort(ids)
    local well = ns.stripWell
    local top = well.y - L.ringRadius - GAP
    for i, id in ipairs(ids) do
        local btn, buff = Button(i), known[id]
        btn.id = id
        btn.icon:SetTexture(buff.icon)
        btn.tile:SetTexture(buff.icon)
        btn.count:SetText(buff.count)
        for _, t in ipairs(btn.square) do t:SetShown(not bare) end
        for _, t in ipairs(btn.soft) do t:SetShown(bare) end
        btn:SetSize(bare and TILE or ICON, bare and TILE or ICON)
        if bare then
            ns.OnStrip(btn, -1, row.x + 1 + TILE / 2 + (i - 1) * (TILE + TILE_GAP), row.bare or row.y)
        elseif row then
            ns.OnStrip(btn, -1, row.x + ICON / 2 + (i - 1) * (ICON - 1), row.y)
        else
            ns.OnStrip(btn, -1, well.x, top - ICON / 2 - (i - 1) * (ICON + GAP))
        end
        btn:Show()
    end
    for i = #ids + 1, #buttons do
        buttons[i].id = nil
        buttons[i]:Hide()
    end
    ns.buffs = buttons
    if ns.chat and ns.chat.BuffsChanged then ns.chat.BuffsChanged() end
end

-- How far the row runs along the margin from its first icon's left edge
-- (the chat asks: it always has the row); in minimal mode, the tiles'.
function ns.BuffRowWidth()
    local n = 0
    for _, btn in ipairs(buttons) do
        if btn.id then n = n + 1 end
    end
    if n == 0 then return 0 end
    if bare then return 1 + TilesWidth(n) end
    return n * (ICON - 1) + 1
end

function ns.BuffRow(spec)
    row = spec
    Layout()
end

-- The whole list read again. In combat a buff already sorted keeps its
-- place (the game will not say again whether it runs out), and one gone is
-- gone; a read cut short (a secret buff, a refused call) cannot say what is
-- gone, so what it did not see stays too.
local function Scan()
    local before = known
    known = {}
    unsorted = false
    local whole = true
    local i = 1
    while true do
        local ok, aura = pcall(Auras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then
            if not ok then unsorted, whole = true, false end
            break
        end
        if ns.IsSecret(aura.auraInstanceID) then whole = false end
        Add(aura, before)
        i = i + 1
    end
    if not whole then
        for id, buff in pairs(before) do
            if known[id] == nil then known[id] = buff end
        end
    end
    Layout()
end

local function Changed(info)
    if not info or ns.IsSecret(info) or ns.IsSecret(info.isFullUpdate) or info.isFullUpdate then
        return Scan()
    end
    local added = not ns.IsSecret(info.addedAuras) and info.addedAuras
    for _, aura in ipairs(added or {}) do Add(aura) end
    local updated = not ns.IsSecret(info.updatedAuraInstanceIDs) and info.updatedAuraInstanceIDs
    for _, id in ipairs(updated or {}) do
        if known[id] then
            local ok, aura = pcall(Auras.GetAuraDataByAuraInstanceID, "player", id)
            if ok and aura then known[id].count = Count(aura) end
        end
    end
    local removed = not ns.IsSecret(info.removedAuraInstanceIDs) and info.removedAuraInstanceIDs
    for _, id in ipairs(removed or {}) do known[id] = nil end
    Layout()
end

ns.OnSetting("chatImmersion", function() Layout() end)
-- the chat's box fading (strips/chat.lua): tiles as it goes, squares as it comes
function ns.BuffsBare()
    if (Bare() and row ~= nil) ~= bare then Layout() end
end

if Auras and Auras.GetAuraDataByIndex then
    local events = CreateFrame("Frame")
    ns.RegisterUnitEvent(events, "UNIT_AURA", "player")
    events:SetScript("OnEvent", function(_, _, _, info) Changed(info) end)
    ns.On("PLAYER_ENTERING_WORLD", Scan)
    ns.On("PLAYER_REGEN_ENABLED", function()
        if unsorted then Scan() end
    end)
end
