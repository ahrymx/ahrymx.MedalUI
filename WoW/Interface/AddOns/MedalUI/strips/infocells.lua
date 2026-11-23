-- The drawers' information cells (2026-11-23, the user's; mockup A of the
-- "MedalUI strip drawers" canvas): what each strip's row shows while its
-- menu keys are rolled away (strips/drawer.lua), from the medallion
-- inward. The cells share the whole row; each is an icon with its number
-- beside it (a profession's "/max" after, dimmed, where it fits).
--
--   left    ammo (a hunter's, where there is ammo), else the lowest
--           durability; then the class's reagents, each with the spell that
--           spends it: a click casts that spell, where there is one.
--   right   the secondary professions, then the primaries; a click opens
--           a crafting one.
--
-- A reagent shows while a spell that spends it is known, or some is
-- carried. One at none is greyed, not hidden, so the gap shows. Ammo and
-- reagents are only where the character has an ammo slot (Forever, not
-- retail, where these reagents are gone).
--
-- The cells are secure buttons. In combat only their numbers change; a
-- cell come or gone waits for the fight's end.
local _, ns = ...
local Tr = ns.L

local ICON = 16
local PAD, SPACE = 3, 2                 -- a cell's edge to its contents; icon to number
local SUB_ALPHA = 0.55
local SIZE = 10
local WHITE = { 1, 1, 1 }
local GREEN = { 0.65, 0.85, 0.56 }      -- a profession at its rank's cap
local AMBER = { 0.94, 0.64, 0.23 }
local RED = { 1, 0.35, 0.29 }
local AMMO_LOW = 200
local DURABILITY_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local AMMO_ICON = "Interface\\Icons\\INV_Ammo_Arrow_02"

-- Each class's reagents, by cell: the items (the best rank's first; the
-- cell shows the first one carried), the spells spending them, and
-- whether a click casts the first (the rest are its other ranks, or other
-- spells one click could not choose between).
local REAGENTS = {
    MAGE = {
        -- Arcane Powder: Arcane Brilliance
        { items = { 17020 }, spells = { 23028 }, cast = true },
        -- Rune of Teleportation: the teleports
        { items = { 17031 }, spells = { 3561, 3562, 3563, 3565, 3566, 3567, 32271, 32272, 33690, 35715,
            49358, 49359 } },
        -- Rune of Portals: the portals
        { items = { 17032 }, spells = { 10059, 11416, 11417, 11418, 11419, 11420, 32266, 32267, 33691, 35717,
            49360, 49361 } },
        -- Light Feather: Slow Fall
        { items = { 17056 }, spells = { 130 }, cast = true },
    },
    PRIEST = {
        -- Sacred and Holy Candles: Prayer of Fortitude (and of Spirit, of Shadow Protection)
        { items = { 17029, 17028 }, spells = { 21562, 21564, 27681, 27683 }, cast = true },
        -- Light Feather: Levitate
        { items = { 17056 }, spells = { 1706 }, cast = true },
    },
    DRUID = {
        -- Wild Thornroot, Wild Berries: Gift of the Wild
        { items = { 17026, 17021 }, spells = { 21849, 21850 }, cast = true },
        -- the seeds, Flintweed to Maple: Rebirth
        { items = { 22147, 17038, 17037, 17036, 17035, 17034 },
            spells = { 20484, 20739, 20742, 20747, 20748, 26994 }, cast = true },
    },
    PALADIN = {
        -- Symbol of Kings: the greater blessings
        { items = { 21177 }, spells = { 25898, 25782, 25894, 25895, 25890, 25899 } },
        -- Symbol of Divinity: Divine Intervention
        { items = { 17033 }, spells = { 19752 }, cast = true },
    },
    SHAMAN = {
        -- Ankh: Reincarnation
        { items = { 17030 }, spells = { 20608 } },
    },
    WARLOCK = {
        -- Soul Shard: always
        { items = { 6265 } },
        -- Infernal Stone: Inferno
        { items = { 5565 }, spells = { 1122 }, cast = true },
        -- Demonic Figurine: Ritual of Doom
        { items = { 16583 }, spells = { 18540 }, cast = true },
    },
    ROGUE = {
        -- Flash Powder: Vanish
        { items = { 5140 }, spells = { 1856, 1857, 26889 }, cast = true },
        -- Blinding Powder: Blind
        { items = { 5530 }, spells = { 2094 }, cast = true },
    },
}
ns.stripReagents = REAGENTS

-- ------------------------------------------------------------- the game
local function Count(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    local old = _G.GetItemCount
    return old and old(id) or 0
end
local function ItemIcon(id)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
    return GetItemIcon and GetItemIcon(id)
end
local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
    return GetItemInfo and (GetItemInfo(id))
end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    local old = _G.GetSpellTexture
    return old and old(id)
end
local function Known(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

-- ammo and these reagents: a client with an ammo slot
local function OldWorld() return _G.CharacterAmmoSlot ~= nil end

-- tooltips beside the side panel, as the strips' others (strips/status.lua)
local function Outside(owner) ns.window.Outside(owner, "ANCHOR_TOP") end

-- ------------------------------------------------------------ the cells
-- A cell's spec: id (what it is, and what its click does: a cell whose id
-- changes is laid out again), icon, text, sub (dimmed after it), color,
-- grey, share (of the row, as ns.StripCells), cast (a spell name), Tip(owner).

local function Ammo()
    local count = _G.GetInventoryItemCount
    local n = count and count("player", 0) or 0
    local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", 0)
    return { id = "ammo", icon = icon or AMMO_ICON, text = BreakUpLargeNumbers and BreakUpLargeNumbers(n)
        or tostring(n), color = n < AMMO_LOW and RED or WHITE, share = 1.4,
        Tip = function(owner)
            if icon then
                Outside(owner)
                GameTooltip:SetInventoryItem("player", 0)
                GameTooltip:Show()
            else
                ns.Tip(owner, Outside, { title = Tr["Ammo"], { "body", Tr["None equipped."] } })
            end
        end }
end

local function Durability()
    local low, slot = ns.stripDurability()
    local pct = math.floor(low * 100)
    local icon = slot and GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
    return { id = "durability", icon = icon or DURABILITY_ICON, text = pct .. "%", share = 1.2,
        color = low < 0.2 and RED or low < 0.5 and AMBER or WHITE,
        Tip = function(owner)
            ns.Tip(owner, Outside, { title = DURABILITY or "Durability",
                { "row", Tr["Lowest"], format("%d%%", pct) },
                slot and { "item", icon, GetInventoryItemLink("player", slot) or "", format("%d%%", pct) } or false })
        end }
end

local function Reagent(r)
    local item, n = r.items[1], 0
    for _, id in ipairs(r.items) do
        local c = Count(id)
        if c > 0 then item, n = id, c break end
    end
    local known
    for _, s in ipairs(r.spells or {}) do
        if Known(s) then known = s break end
    end
    if r.spells and not known and n == 0 then return nil end
    local spell = r.cast and known and SpellName(known) or nil
    local icon = r.cast and known and SpellIcon(known) or ItemIcon(item)
    return { id = "item:" .. table.concat(r.items, ",") .. ":" .. tostring(spell), icon = icon,
        text = tostring(n), color = WHITE, grey = n == 0, cast = spell,
        Tip = function(owner)
            ns.Tip(owner, Outside, { title = ItemName(item) or "",
                { "row", Tr["Carried"], tostring(n) },
                known and { "row", Tr["For"], SpellName(known) or "" } or false,
                spell and { "hint", format(Tr["Click: cast %s."], spell) } or false })
        end }
end

local function Left()
    local out = {}
    local _, class = UnitClass("player")
    local old = OldWorld()
    table.insert(out, (old and class == "HUNTER") and Ammo() or Durability())
    if old then
        for _, r in ipairs(REAGENTS[class] or {}) do
            local s = Reagent(r)
            if s then table.insert(out, s) end
        end
    end
    return out
end

local function Profession(index, primary)
    local name, icon, rank, max, _, offset = GetProfessionInfo(index)
    if not name then return nil end
    -- its crafting spell, which opens its window (professions/window.lua's W.Learned)
    local spell
    local book = C_SpellBook and C_SpellBook.GetSpellBookItemInfo
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local item = book and bank and offset and book(offset + 1, bank)
    if item and item.spellID and C_TradeSkillUI and C_TradeSkillUI.CanTradeSkillShowCraftingUI
        and C_TradeSkillUI.CanTradeSkillShowCraftingUI(item.spellID) then
        spell = SpellName(item.spellID) or item.name
    end
    rank, max = rank or 0, max or 0
    return { id = "profession:" .. name .. ":" .. tostring(spell), icon = icon, text = tostring(rank),
        sub = max > 0 and "/" .. max or nil, share = primary and 1.3 or 1,
        color = max > 0 and rank >= max and GREEN or WHITE, cast = spell,
        Tip = function(owner)
            ns.Tip(owner, Outside, { title = name,
                { "bar", rank, max, format("%d / %d", rank, max) },
                spell and { "hint", Tr["Click: open it."] } or false })
        end }
end

local function Right()
    local out = {}
    if not (GetProfessions and GetProfessionInfo) then return out end
    -- prof1, prof2, archaeology, fishing, cooking, first aid (the last on Forever's)
    local p1, p2, arch, fish, cook, aid = GetProfessions()
    for i, index in ipairs({ cook or false, aid or false, fish or false, arch or false, p1 or false, p2 or false }) do
        local s = index and Profession(index, i > 4)
        if s then table.insert(out, s) end
    end
    return out
end

-- ----------------------------------------------------------- the buttons
local Fit
local pool = { [-1] = {}, [1] = {} }
local laid = { [-1] = {}, [1] = {} }    -- the specs laid out, in order

local function Cell(side, i)
    local b = pool[side][i]
    if b then return b end
    b = CreateFrame("Button", "MedalUIStripCell" .. (side < 0 and "L" or "R") .. i, ns.stripDrawers[side].info,
        "SecureActionButtonTemplate")
    b:SetFrameLevel(ns.levels.stripTop)
    b:RegisterForClicks("AnyUp", "AnyDown")
    ns.StripCell(b)
    b.icon = b:CreateTexture(nil, "OVERLAY", nil, 5)
    b.icon:SetSize(ICON, ICON)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = ns.Text(b, SIZE)
    b.count:SetPoint("LEFT", b.icon, "RIGHT", SPACE, 0)
    b.sub = ns.Text(b, SIZE - 1)
    b.sub:SetPoint("LEFT", b.count, "RIGHT", 0, 0)
    b.Fitted = function(self, w)
        self.fit = w
        Fit(self)
    end
    b:SetScript("OnEnter", function(self) if self.spec then self.spec.Tip(self) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pool[side][i] = b
    return b
end

-- the icon, number and "/max" centred in the cell; the "/max" only where
-- all of it fits
function Fit(b)
    local w = b.fit or 0
    local inner = ICON + SPACE + b.count:GetStringWidth()
    local sub = b.spec and b.spec.sub and inner + b.sub:GetStringWidth() <= w - 2 * PAD
    b.sub:SetShown(sub and true or false)
    if sub then inner = inner + b.sub:GetStringWidth() end
    b.icon:ClearAllPoints()
    b.icon:SetPoint("LEFT", b, "LEFT", math.max(PAD, math.floor((w - inner) / 2)), 0)
end

-- a cell's face: what may change in combat
local function Face(b, s)
    b.spec = s
    b.icon:SetTexture(s.icon)
    b.icon:SetDesaturated(s.grey or false)
    b.icon:SetAlpha(s.grey and 0.45 or 1)
    b.count:SetText(s.text)
    b.sub:SetText(s.sub or "")
    local c = s.color or WHITE
    b.count:SetTextColor(c[1], c[2], c[3], s.grey and 0.6 or 1)
    b.sub:SetTextColor(c[1], c[2], c[3], SUB_ALPHA)
    Fit(b)
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i].id ~= b[i].id then return false end
    end
    return true
end

local Refresh
local waiting = { [-1] = false, [1] = false }

function Refresh(side)
    local specs = side < 0 and Left() or Right()
    local was = laid[side]
    if Same(specs, was) or InCombatLockdown() then
        -- the faces of the cells still standing; the rest after the fight
        for i, b in ipairs(pool[side]) do
            local s = was[i]
            if s and b:IsShown() then
                for _, now in ipairs(specs) do
                    if now.id == s.id then Face(b, now) end
                end
            end
        end
        if not Same(specs, was) and not waiting[side] then
            waiting[side] = true
            ns.OutOfCombat(function()
                waiting[side] = false
                Refresh(side)
            end)
        end
        return
    end
    local list = {}
    for i, s in ipairs(specs) do
        local b = Cell(side, i)
        Face(b, s)
        b.share = s.share
        b:SetAttribute("type", s.cast and "spell" or nil)
        b:SetAttribute("spell", s.cast)
        b:Show()
        list[i] = b
    end
    for i = #specs + 1, #pool[side] do
        local b = pool[side][i]
        b.spec = nil
        b:SetAttribute("type", nil)
        b:SetAttribute("spell", nil)
        b:Hide()
    end
    laid[side] = specs
    ns.stripDrawers[side].Info(list)
end

local function Both()
    Refresh(-1)
    Refresh(1)
end
local function LeftOnly() Refresh(-1) end
local function RightOnly() Refresh(1) end

ns.stripInfo = { Refresh = Refresh, pool = pool }

ns.On("PLAYER_LOGIN", Both)
ns.On("PLAYER_ENTERING_WORLD", Both)
ns.On("SPELLS_CHANGED", Both)
for _, e in ipairs({ "BAG_UPDATE", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" }) do
    ns.On(e, LeftOnly)
end
local events = CreateFrame("Frame")
ns.RegisterUnitEvent(events, "UNIT_INVENTORY_CHANGED", "player")
events:SetScript("OnEvent", LeftOnly)
ns.On("SKILL_LINES_CHANGED", RightOnly)
ns.On("TRADE_SKILL_LIST_UPDATE", RightOnly)
