-- A minimap button: the addon's mark (Medalluin's medal in the companion's
-- colour, art/companions/gen_logos.py), as Medalluin's own button wears its
-- gold one, on the minimap's edge (on a square map, its square edge: GetMinimapShape,
-- the convention LibDBIcon reads), dragged round it with the left button.
-- Off until its setting turns it on.
--
--   ns.MinimapButton{ name, icon, title, tip = { lines }, Click(mouse),
--                     Shown() -> on, Angle() -> degrees, SetAngle(degrees) }
--   returns the button; button.Update() shows or hides it and puts it
--   where its angle says.
--
-- It is a named Button on the minimap, as LibDBIcon's are, so a minimap
-- button collector takes it: Medalluin's drawer on the action bar
-- (Medalluin/bars/drawer.lua) reparents it into its line, and from then
-- on it is only shown or hidden here, never placed or dragged.
local _, ns = ...

local SIZE = 32
local SQUARE = { SQUARE = true, CORNER = true }

-- where the angle puts it, from the minimap's middle: on a round map, a
-- circle past its edge; on a square one, that circle pushed out to the
-- square's
local function Offset(angle)
    local a = math.rad(angle)
    local x, y = math.cos(a), math.sin(a)
    local half = (Minimap:GetWidth() or 140) / 2
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local r = half + 5
    if SQUARE[shape] then
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
    end
    return x * r, y * r
end

function ns.MinimapButton(spec)
    local b = CreateFrame("Button", spec.name, Minimap)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(spec.icon)
    icon:SetAllPoints()
    b.icon = icon
    -- the pointer over it: the medal lit, as Medalluin's is
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(spec.icon)
    glow:SetAllPoints()
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.35)
    b:Hide()

    local function Place(angle)
        local x, y = Offset(angle)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- on the minimap: at its angle; taken into a collector's drawer, only
    -- shown or hidden
    local function Ours() return b:GetParent() == Minimap end
    function b.Update()
        local on = spec.Shown() and true or false
        b:SetShown(on)
        if on and Ours() then Place(spec.Angle()) end
    end

    -- dragged round the map: the angle from its middle to the pointer
    local function Follow()
        local mx, my = Minimap:GetCenter()
        if not mx then return end                   -- the map not laid out yet
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
        spec.SetAngle(angle)
        Place(angle)
    end
    b:SetScript("OnDragStart", function(self)
        if not Ours() then return end
        self:LockHighlight()
        self:SetScript("OnUpdate", Follow)
        GameTooltip:Hide()
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)
    b:SetScript("OnClick", function(_, mouse) spec.Click(mouse) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, Ours() and "ANCHOR_LEFT" or "ANCHOR_TOP")
        GameTooltip:SetText(spec.title, 1, 0.82, 0)
        for i, line in ipairs(spec.tip or {}) do
            -- the last line is the drag's, which a drawer's button has not
            if Ours() or i < #spec.tip then GameTooltip:AddLine(line, 1, 1, 1, true) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- the map resized, or the world entered (where an addon may have
    -- moved or reshaped it): the button follows
    Minimap:HookScript("OnSizeChanged", b.Update)
    b:RegisterEvent("PLAYER_ENTERING_WORLD")
    b:SetScript("OnEvent", b.Update)
    b.Update()
    return b
end
