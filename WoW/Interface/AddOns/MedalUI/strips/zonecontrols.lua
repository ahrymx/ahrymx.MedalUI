-- The Zone tab's controls (strips/zone.lua): a drawer over the side panel,
-- as the bags' drawer stands over the bags window (inventory/bags.lua),
-- opened and closed by the column's top button. It opens out of the
-- panel's top-right corner, over that button, and grows to the left:
--
--   [item][item][item] | [A][A] [x/y] | [!] [<][>]     <- over the panel
--   ------------------------------------------- [=]   <- the column's button
--
--   the quest items   the usable items of the quests the tab lists, in its
--                     order (the Guide's, when it is shown): a click uses
--                     one. Secure buttons on a layer of their own on the
--                     strip, placed over the slots out of combat, hidden in
--                     combat as the list's are (a slot still shows its
--                     count and cooldown then)
--   A A               the list's text a point smaller, a point larger
--                     (zoneFontSize)
--   x/y               where you stand after the subzone, or not (zoneCoords)
--   ! < >             with the Guide shown only (quests/guide.lua): quests to
--                     take in the list or not (zoneGuidePicks); the waypoint
--                     a row up the list, a row down (the rows stay put)
--
-- Left open, it is open again whenever the tab is up (zoneControls, not on
-- the options page); it goes with the tab, the panel closed or hidden.
local _, ns = ...
local Tr = ns.L

local SLOT, PAD, GAP = 26, 5, 2         -- an item's slot; the drawer's padding; between slots
local BUTTON = 24                       -- a control's width (as tall as a slot)
local SPLIT = 6                         -- room each side of a group's divider
local GROW = 0.15                       -- seconds to open
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }

local C = {}
ns.zoneControls = C

local drawer, layer
local slots, controls, splits = {}, {}, {}
local items = {}                        -- the items shown, in order

local function View() return ns.side and ns.side.zone end

function C.IsOpen() return ns.db.zoneControls and true or false end

-- ------------------------------------------------------------- the items
-- the list's quests' items, once each, in the list's order
local function Items()
    local v, out, seen = View(), {}, {}
    for _, q in ipairs(v and v.Quests() or {}) do
        if not q.pick and q.item and not seen[q.item] then
            seen[q.item] = true
            out[#out + 1] = q.item
        end
    end
    return out
end

local function Count(id) return C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0 end

local function Icon(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    if not icon and GetItemIcon then icon = GetItemIcon(id) end
    return icon
end

local function ItemTip(owner, id, hint)
    ns.side.Beside(owner)
    GameTooltip:SetItemByID(id)
    if hint then GameTooltip:AddLine(hint, unpack(GOLD_D)) end
    GameTooltip:Show()
end

-- its count and cooldown: not secure, so in combat too
local function Paint(slot)
    local id = slot.item
    if not id then return end
    local n = Count(id)
    slot.icon:SetTexture(Icon(id))
    slot.icon:SetDesaturated(n == 0)
    slot.count:SetText(n > 1 and n or "")
    local start, duration, enable = 0, 0, 0
    if C_Container and C_Container.GetItemCooldown then
        start, duration, enable = C_Container.GetItemCooldown(id)
    end
    if enable == 1 and duration and duration > 0 then
        slot.cooldown:SetCooldown(start, duration)
    else
        slot.cooldown:Clear()
    end
end

local function Slot(i)
    local s = slots[i]
    if s then return s end
    s = CreateFrame("Button", nil, drawer.inner)
    s:SetSize(SLOT, SLOT)
    local edge = s:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetPoint("TOPLEFT", 1, -1)
    s.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.cooldown = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    s.cooldown:SetAllPoints(s.icon)
    s.count = ns.Text(s, 10)
    s.count:SetPoint("BOTTOMRIGHT", -2, 2)
    s.count:SetTextColor(1, 1, 1)
    -- (in combat: the secure button is away, this shows)
    s:SetScript("OnEnter", function(self)
        if self.item then ItemTip(self, self.item, Tr["Usable here after combat."]) end
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slots[i] = s
    return s
end

local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "MedalUIZoneControlItem" .. i, layer, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnEnter", function(self)
        if self.item then ItemTip(self, self.item, Tr["Click: use it."]) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    layer.buttons[i] = b
    return b
end

-- Out of combat only: a secure button over each slot shown, once the
-- drawer is open all the way; the rest away
local function PlaceBar()
    if InCombatLockdown() then return end
    if not layer then
        layer = CreateFrame("Frame", "MedalUIZoneControlItems", ns.strips[1])
        layer:SetFrameStrata("LOW")
        layer:SetAllPoints(ns.strips[1])
        layer.buttons = {}
    end
    local n = 0
    if drawer and drawer:IsVisible() and not drawer.growing then
        for _, s in ipairs(slots) do
            if s:IsShown() and s.item then
                local b = Secure(n + 1)
                if ns.window.Over(b, s) then
                    n = n + 1
                    b.item = s.item
                    b:SetAttribute("item", "item:" .. s.item)
                    b:Show()
                end
            end
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.item = nil
        b:SetAttribute("item", nil)
        b:Hide()
    end
    if n > 0 then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end
C.PlaceBar = PlaceBar

-- ---------------------------------------------------------- the controls
local function Guide() local v = View() return v and v.Guide() end
local function G() return ns.questGuide end

local function Step(size)
    local v = View()
    local n = v.Size() + size
    if n < v.SIZE_MIN or n > v.SIZE_MAX then return end
    ns.SetOption("zoneFontSize", n)
end

local function Again()
    local v = View()
    if v then v.Refresh() end
end

-- { text, size, group, guide (shown with the Guide only), lit(), on() (may be
--   pressed: dimmed when not), click() (doing nothing when it may not be),
--   tip() -> title, line }
local SPECS = {
    { text = "A", size = 9, group = 1,
        on = function() return View().Size() > View().SIZE_MIN end,
        click = function() Step(-1) end,
        tip = function() return Tr["Smaller text"], format(Tr["The list's text: %d points."], View().Size()) end },
    { text = "A", size = 14, group = 1,
        on = function() return View().Size() < View().SIZE_MAX end,
        click = function() Step(1) end,
        tip = function() return Tr["Larger text"], format(Tr["The list's text: %d points."], View().Size()) end },
    { text = "x/y", size = 10, group = 1,
        lit = function() return ns.db.zoneCoords ~= false end,
        click = function() ns.SetOption("zoneCoords", ns.db.zoneCoords == false) end,
        tip = function()
            return Tr["Coordinates"], ns.db.zoneCoords ~= false and Tr["Shown after the subzone. Click: hide them."]
                or Tr["Hidden. Click: show where you stand after the subzone."]
        end },
    { text = "!", size = 14, group = 2, guide = true,
        lit = function() return ns.db.zoneGuidePicks ~= false end,
        click = function() ns.SetOption("zoneGuidePicks", ns.db.zoneGuidePicks == false) end,
        tip = function()
            return Tr["Quests to take"], ns.db.zoneGuidePicks ~= false
                and Tr["The Guide lists quests to take near you. Click: only your log's."]
                or Tr["The Guide lists your log's quests only. Click: quests to take near you too."]
        end },
    { text = "<", size = 13, group = 2, guide = true,
        on = function() return G() ~= nil and G().CanBack(View().Focused()) end,
        click = function() if G().Back(View().Focused()) then Again() end end,
        tip = function() return Tr["Step back"], Tr["The waypoint to the quest above in the list."] end },
    { text = ">", size = 13, group = 2, guide = true,
        on = function() return G() ~= nil and G().CanNext(View().Focused()) end,
        click = function() if G().Next(View().Focused()) then Again() end end,
        tip = function() return Tr["Step on"], Tr["The waypoint to the quest below in the list."] end },
}

local function Pressable(spec) return not spec.on or spec.on() end

local function Show(b)
    local spec = b.spec
    local on = Pressable(spec)
    b.mark:SetShown(spec.lit ~= nil and spec.lit() and true or false)
    b.label:SetTextColor(unpack(on and GOLD or DIM))
    b.label:SetAlpha(on and 1 or 0.4)
end

local function Tip(b)
    local title, line = b.spec.tip()
    ns.Tip(b, ns.side.Beside, { title = title, line and { "body", line } or false })
end

local function Control(spec)
    local b = CreateFrame("Button", nil, drawer.inner)
    b.spec = spec
    b:SetSize(BUTTON, SLOT)
    ns.window.Face(b)
    b.label = ns.Text(b, spec.size)
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(spec.text)
    b:SetScript("OnClick", function(self)
        self.spec.click()
        C.Refresh()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    controls[#controls + 1] = b
    return b
end

local function Split(i)
    local t = splits[i]
    if t then return t end
    t = drawer.inner:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    t:SetSize(1, SLOT - 6)
    splits[i] = t
    return t
end

-- --------------------------------------------------------------- the drawer
local function Build()
    local v = View()
    drawer = CreateFrame("Frame", "MedalUIZoneControls", v.body)
    drawer:SetPoint("BOTTOMRIGHT", ns.side.panel, "TOPRIGHT", 0, 2)
    drawer:SetHeight(SLOT + 2 * PAD)
    drawer:SetClipsChildren(true)
    drawer:EnableMouse(true)
    drawer.inner = CreateFrame("Frame", nil, drawer)
    drawer.inner:SetPoint("TOPRIGHT")
    local edge = drawer:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local bg = drawer:CreateTexture(nil, "BACKGROUND", nil, 2)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.94)
    drawer.none = ns.Text(drawer.inner, 10)
    drawer.none:SetTextColor(unpack(DIM))
    drawer.none:SetText(Tr["No quest items."])
    for _, spec in ipairs(SPECS) do Control(spec) end
    drawer.full = 1
    -- opening: out of the corner, to the left; the items' buttons once open
    drawer:SetScript("OnShow", function(self)
        self.t, self.growing = 0, true
        self:SetWidth(1)
    end)
    drawer:SetScript("OnUpdate", function(self, elapsed)
        if not self.growing then return end
        self.t = math.min(GROW, self.t + elapsed)
        self:SetWidth(math.max(1, self.full * self.t / GROW))
        if self.t >= GROW then
            self.growing = false
            PlaceBar()
        end
    end)
    -- gone with the tab, the panel closed or hidden: the items' buttons away
    -- (in combat: hidden already)
    drawer:SetScript("OnHide", function() PlaceBar() end)
    v.body:HookScript("OnHide", function() PlaceBar() end)
    drawer.growing = true
    drawer:Hide()
end

-- the drawer's row, right to left from its corner: the Guide's group (with
-- the Guide shown), the list's group, the items; as wide as that, up to the
-- panel's width (the items that do not fit left off)
local function Layout()
    local guide = Guide()
    local x = PAD                       -- from the right edge
    local group, nsplit = nil, 0
    for i = #controls, 1, -1 do
        local b = controls[i]
        local shown = not b.spec.guide or guide
        b:SetShown(shown and true or false)
        if shown then
            if group and b.spec.group ~= group then
                nsplit = nsplit + 1
                local t = Split(nsplit)
                t:ClearAllPoints()
                t:SetPoint("RIGHT", drawer.inner, "RIGHT", -(x + SPLIT - GAP), 0)
                t:Show()
                x = x + 2 * SPLIT + 1 - GAP
            end
            group = b.spec.group
            b:ClearAllPoints()
            b:SetPoint("RIGHT", drawer.inner, "RIGHT", -x, 0)
            Show(b)
            x = x + BUTTON + GAP
        end
    end
    -- the items, after a divider
    nsplit = nsplit + 1
    local t = Split(nsplit)
    t:ClearAllPoints()
    t:SetPoint("RIGHT", drawer.inner, "RIGHT", -(x + SPLIT - GAP), 0)
    t:Show()
    x = x + 2 * SPLIT + 1 - GAP
    for i = nsplit + 1, #splits do splits[i]:Hide() end
    local room = math.floor((ns.side.panel:GetWidth() - x - PAD + GAP) / (SLOT + GAP))
    items = Items()
    local n = math.max(0, math.min(#items, room))
    for i = 1, n do
        local s = Slot(i)
        s.item = items[i]
        s:ClearAllPoints()
        s:SetPoint("RIGHT", drawer.inner, "RIGHT", -(x + (n - i) * (SLOT + GAP)), 0)
        Paint(s)
        s:Show()
    end
    for i = n + 1, #slots do
        slots[i].item = nil
        slots[i]:Hide()
    end
    drawer.none:SetShown(n == 0)
    if n == 0 then
        drawer.none:ClearAllPoints()
        drawer.none:SetPoint("RIGHT", drawer.inner, "RIGHT", -x, 0)
        x = x + (drawer.none:GetStringWidth() or 0) + GAP
    else
        x = x + n * (SLOT + GAP)
    end
    drawer.full = x - GAP + PAD
    drawer.inner:SetSize(drawer.full, SLOT + 2 * PAD)
    if not drawer.growing then drawer:SetWidth(drawer.full) end
end

-- After the tab's list is drawn, or a setting changed: the drawer as it
-- now is, its buttons placed again
function C.Refresh()
    local v = View()
    if not (v and v.body) then return end
    if not drawer then
        if not C.IsOpen() then return end
        Build()
    end
    -- (only as it changes: shown again, it would open again from the corner)
    if drawer:IsShown() ~= C.IsOpen() then drawer:SetShown(C.IsOpen()) end
    if not drawer:IsShown() then return end
    Layout()
    PlaceBar()
end

function C.Toggle()
    ns.db.zoneControls = not C.IsOpen()
    C.Refresh()
end

-- (the harness's)
function C.Drawer() return drawer end
function C.Layer() return layer end

ns.On("BAG_UPDATE_COOLDOWN", function()
    if not (drawer and drawer:IsVisible()) then return end
    for _, s in ipairs(slots) do if s:IsShown() then Paint(s) end end
end)
-- the items' buttons placed again after a fight
ns.On("PLAYER_REGEN_ENABLED", function() if drawer then PlaceBar() end end)
