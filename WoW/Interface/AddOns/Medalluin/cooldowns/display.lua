-- The Cooldown Manager's display: the game's own viewers (Blizzard_CooldownViewer),
-- their spells drawn in Medalluin's dress, each viewer where the player puts it.
--
--                 (b) (b) (b)                  BuffIconCooldownViewer: the tracked buffs
--          (E)  (E)  (E)  (E)   (u) (u) (u)    Essential, the biggest; Utility at its right
--        +-----------------------------+
--        |         the console         |      (where they stand untouched; each moves on its own)
--
-- The viewers still track everything themselves (cooldowns, charges, auras,
-- totems, alerts, their secret values in combat): only their look and their
-- place are ours. Each viewer has its own options (Cooldowns, per profile):
--
--   place    a holder of ours on the screen (movers.lua: dragged in Edit
--            Mode, or its sliders); the viewer stands on it
--   layout   its icons as a bar or an arch (cooldowns/layout.lua), in the
--            Cooldown Manager's own order, its first where Fill order says;
--            with Close gaps an icon that is hidden (a buff not up) leaves
--            no hole, the others closing ranks as it comes and goes
--   look     the shape (a round medallion, a rounded or plain square, or
--            bare), the size and spacing, the texts' sizes and places, the
--            sweep, the grey while cooling down, the out-of-range tint, and
--            the tooltips
--   fade     its alpha by its Visibility: always, in combat, on mouseover
--
-- The viewers are placed and scaled out of combat only; Edit Mode moving one
-- is undone once combat allows. The icons are the game's plain frames (no
-- secure template), so they are laid out in combat too, as a buff comes and
-- goes. Our parts sit in a side table (deco), never as fields on theirs.
local _, ns = ...

local L = ns.cdmLayout
local GOLD_D = { 0.541, 0.439, 0.204 }
local ROUND = ns.media .. "strips\\round"
local ROUNDED = ns.media .. "strips\\rounded"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GAP = 14                  -- between the console and the rows, and between rows, untouched

-- each shape: its mask, how far in from the icon's edge it is cut, its rim
-- under the icon (none: bare), and its sweep's edge
local SHAPES = {
    round = { tex = ROUND, inset = 2, rim = ROUND, circular = true },
    rounded = { tex = ROUNDED, inset = 2, rim = ROUNDED },
    square = { tex = WHITE, inset = 2, rim = WHITE },
    bare = { tex = WHITE, inset = 0 },
}
-- where a text stands on its icon: its point, the icon's, and the offset
local POINTS = {
    center = { "CENTER", "CENTER", 0, 0 },
    top = { "TOP", "TOP", 0, -2 },
    bottom = { "BOTTOM", "BOTTOM", 0, 2 },
    bottomright = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2 },
    topright = { "TOPRIGHT", "TOPRIGHT", -2, -2 },
    bottomleft = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 2 },
    topleft = { "TOPLEFT", "TOPLEFT", 2, -2 },
    below = { "TOP", "BOTTOM", 0, -1 },
}
local CD_FONT, COUNT_FONT = 14, 13  -- the texts' sizes at Normal, in the icon's own units

local display = {}
ns.cooldownDisplay = display

local deco = {}                 -- our dress, by the game's frame
local viewers = {}              -- ours, by key: the game's viewer frames
local holders = {}              -- ours, by key: where each stands
local sims = {}                 -- ours, by key: the simulation's icons and their frame (cooldowns/simulate.lua)
local LETTER, DEFAULT_SIZE = {}, {}
local placing, started = false, false
display.viewers, display.holders, display.sims = viewers, holders, sims

for _, v in ipairs(ns.CDM_VIEWERS) do
    LETTER[v[2]], DEFAULT_SIZE[v[2]] = v[1], v[4]
    local h = CreateFrame("Frame", "MedalluinCooldowns_" .. v[2], UIParent)
    h:SetSize(v[4], v[4])
    holders[v[2]] = h
end

-- A viewer's option, by its field (settings.lua's CDM_FIELDS)
local function Opt(key, field) return ns.db["cdm" .. LETTER[key] .. field] end
local function Num(key, field) return tonumber(Opt(key, field)) or 0 end

local function Viewer(key)
    return key == "essential" and _G.EssentialCooldownViewer or key == "utility" and _G.UtilityCooldownViewer
        or key == "buffs" and _G.BuffIconCooldownViewer or nil
end

local function Items(v)
    if v.GetItemFrames then
        local ok, frames = pcall(v.GetItemFrames, v)
        if ok and type(frames) == "table" then return frames end
    end
    local out = {}
    if v.itemFramePool and v.itemFramePool.EnumerateActive then
        for item in v.itemFramePool:EnumerateActive() do table.insert(out, item) end
    end
    return out
end

-- A viewer's icons as they are laid out: the simulation's while it runs
local function List(key)
    local sim = sims[key]
    if sim then return sim.items end
    return viewers[key] and Items(viewers[key]) or nil
end

function display.On() return started end

-- ---------------------------------------------------------------- the dress
local function Font(fs, size)
    if not fs or not fs.SetFont then return end
    fs:SetFont(ns.font, size, "OUTLINE")
end

local Arrange

-- The cooldown's numbers: its own FontStrings, and the countdown's where
-- the client makes it apart
local function CooldownTexts(cd)
    local out = {}
    for _, r in ipairs({ cd:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then table.insert(out, r) end
    end
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then
        local there = false
        for _, r in ipairs(out) do there = there or r == fs end
        if not there then table.insert(out, fs) end
    end
    return out
end

-- A text: its size as a scale of Normal (0: hidden), and its place on the icon
local function Text(fs, base, scale, pos, icon)
    if not fs then return end
    if scale <= 0 then
        fs:SetAlpha(0)
        return
    end
    fs:SetAlpha(1)
    Font(fs, base * scale)
    local p = POINTS[pos] or POINTS.center
    fs:ClearAllPoints()
    fs:SetPoint(p[1], icon, p[2], p[3], p[4])
end

-- The viewer's options on one of its icons: its shape, its texts, its
-- cooldown's look. Again on each option changed.
local function Restyle(item)
    local d = deco[item]
    if not d then return end
    local key, icon = d.key, item.Icon
    local shape = SHAPES[Opt(key, "Shape")] or SHAPES.round
    local i = shape.inset
    local function Inset(r)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", icon, "TOPLEFT", i, -i)
        r:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -i, i)
    end
    if d.mask then
        d.mask:SetTexture(shape.tex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        Inset(d.mask)
    end
    if shape.rim then
        d.rim:SetTexture(shape.rim)
        d.rim:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        d.rim:Show()
    else
        d.rim:Hide()
    end
    -- out of range: a red tint in the icon's shape, not the square shadow
    local oor = item.OutOfRange
    if oor then
        oor:SetTexture(shape.tex)
        Inset(oor)
        oor:SetVertexColor(0.8, 0.1, 0.08, 0.45)
        oor:SetAlpha(Opt(key, "Range") and 1 or 0)
    end
    local cd = item.Cooldown
    if cd then
        if cd.SetSwipeTexture then cd:SetSwipeTexture(shape.tex) end
        if cd.SetUseCircularEdge then cd:SetUseCircularEdge(shape.circular and true or false) end
        Inset(cd)
        if not Opt(key, "Swipe") and cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
        for _, fs in ipairs(CooldownTexts(cd)) do
            Text(fs, CD_FONT, Num(key, "CdSize"), Opt(key, "CdPos"), icon)
        end
    end
    if not Opt(key, "Desat") and icon.SetDesaturated then icon:SetDesaturated(false) end
    local scale, pos = Num(key, "CountSize"), Opt(key, "CountPos")
    if item.ChargeCount then Text(item.ChargeCount.Current, COUNT_FONT, scale, pos, icon) end
    if item.Applications then Text(item.Applications.Applications, COUNT_FONT, scale, pos, icon) end
end
display.Restyle = Restyle

-- A spell's frame in our dress: its masks swapped for ours, its overlay
-- hidden, a rim under it; and the hooks that keep the viewer's options
-- over the game's own refreshes. Once a frame; the shape is Restyle's.
local function Dress(item, key)
    local icon = item and item.Icon
    if not icon or deco[item] then return end
    local d = { key = key }
    deco[item] = d
    if icon.GetNumMaskTextures and icon.RemoveMaskTexture then
        for i = (icon:GetNumMaskTextures() or 0), 1, -1 do
            local m = icon:GetMaskTexture(i)
            if m then icon:RemoveMaskTexture(m) end
        end
    end
    -- the icon's own square border cut off, so the mask shows its face
    -- (with the game's masks off: tex coords are refused on a masked texture)
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if item.CreateMaskTexture and icon.AddMaskTexture then
        d.mask = item:CreateMaskTexture()
        icon:AddMaskTexture(d.mask)
    end
    -- the square overlay (its frame art): put away; the icon and the shadow kept
    for _, r in ipairs({ item:GetRegions() }) do
        if r ~= icon and r ~= item.OutOfRange and r.GetObjectType and r:GetObjectType() == "Texture" then
            r:SetAlpha(0)
        end
    end
    d.rim = item:CreateTexture(nil, "BACKGROUND", nil, -6)
    d.rim:SetAllPoints(icon)
    local cd = item.Cooldown
    if cd then
        if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.7) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        -- the game sets its sweep on each refresh: put ours back after
        if cd.SetDrawSwipe then
            hooksecurefunc(cd, "SetDrawSwipe", function(self, on)
                if on and not d.swiping and not Opt(key, "Swipe") then
                    d.swiping = true
                    self:SetDrawSwipe(false)
                    d.swiping = nil
                end
            end)
        end
    end
    -- the game greys a cooling-down icon: put back, if this viewer says not to
    if icon.SetDesaturated then
        hooksecurefunc(icon, "SetDesaturated", function(self, on)
            if on and not d.greying and not Opt(key, "Desat") then
                d.greying = true
                self:SetDesaturated(false)
                d.greying = nil
            end
        end)
    end
    -- the GCD's square flash: put away
    if item.CooldownFlash then item.CooldownFlash:SetAlpha(0) end
    if item.HookScript then
        -- its tooltip, gone again if this viewer has none
        item:HookScript("OnEnter", function(self)
            if not Opt(key, "Tips") and GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end)
        -- a buff coming or going: the others close ranks
        local function Moved() if Opt(key, "Gaps") then Arrange(key) end end
        item:HookScript("OnShow", Moved)
        item:HookScript("OnHide", Moved)
    end
    Restyle(item)
end
display.Dress = Dress

local function DressAll(v, key)
    for _, item in ipairs(Items(v)) do Dress(item, key) end
end

-- --------------------------------------------------------------- the layout
local function Spec(key)
    return {
        layout = Opt(key, "Layout"), orient = Opt(key, "Orient"), perRow = Num(key, "PerRow"),
        span = Num(key, "Span"), opens = Opt(key, "Opens"), order = Opt(key, "Order"),
        size = Num(key, "Size"), spacing = Num(key, "Spacing"),
    }
end

-- Its icons on the holder, in the Cooldown Manager's order (layoutIndex):
-- each where the layout puts its rank, the holder sized to them all
local arranging = {}
function Arrange(key)
    local h, items = holders[key], List(key)
    if not items or arranging[key] then return end
    arranging[key] = true
    local gaps, list = Opt(key, "Gaps"), {}
    for i, item in ipairs(items) do
        if not gaps or item:IsShown() then table.insert(list, { item, tonumber(item.layoutIndex) or i, i }) end
    end
    table.sort(list, function(a, b)
        if a[2] ~= b[2] then return a[2] < b[2] end
        return a[3] < b[3]
    end)
    local s = Spec(key)
    local at, w, ht = L.Place(#list, s)
    pcall(function()
        for rank, e in ipairs(list) do
            local item = e[1]
            local k = h:GetEffectiveScale() / item:GetEffectiveScale()
            item:ClearAllPoints()
            item:SetPoint("CENTER", h, "CENTER", at[rank][1] * k, at[rank][2] * k)
        end
    end)
    h:SetSize(math.max(w, s.size), math.max(ht, s.size))
    arranging[key] = nil
end
display.Arrange = Arrange

-- ---------------------------------------------------------------- the place
-- A viewer's scale, for its spells to stand at its Size (Edit Mode's own
-- icon size inside it kept as the base)
local function Fit(v, key)
    local item = Items(v)[1]
    if not item then return end
    local w = (item:GetWidth() or 0) * (item:GetScale() or 1)
    if w > 0 then v:SetScale(Num(key, "Size") / w) end
end

-- Where each stands at Across and Up 0, its bottom from the screen's: over
-- the console as the profile draws it, in the screen's middle, the buffs
-- over Essential (Utility's place at its right is its default Across,
-- settings.lua). The console moving does not take them along.
-- In design units; k turns the screen's into them (Essential's row is drawn
-- in the screen's).
local function Base(key, k)
    local art = ns.art or {}
    local top = (art.bottomGap or 0) + (art.height or 0) + GAP
    if key == "buffs" then return 0, top + (DEFAULT_SIZE.essential + GAP) / k end
    return 0, top
end

-- The holders on the screen, and the viewers on them. A place is in design
-- units (a 1080-high screen, as the consoles' are, so a mover's drag
-- follows the pointer); an icon's Size is in the screen's own, as the
-- game's icons are.
local function Place()
    if placing then return end
    if InCombatLockdown and InCombatLockdown() then
        ns.OutOfCombat(Place)
        return
    end
    placing = true
    local design = ns.layout and ns.layout.designHeight or 1080
    pcall(function()
        for key, h in pairs(holders) do
            local k = UIParent:GetHeight() / design
            local bx, by = Base(key, k)
            h:ClearAllPoints()
            h:SetPoint("BOTTOM", UIParent, "BOTTOM", (bx + Num(key, "X")) * k, (by + Num(key, "Y")) * k)
            local v = viewers[key]
            if v then
                Fit(v, key)
                v:ClearAllPoints()
                v:SetPoint("CENTER", h, "CENTER", 0, 0)
            end
        end
    end)
    placing = false
    for key in pairs(holders) do Arrange(key) end
end
display.Place = Place

-- ---------------------------------------------------------------- the fade
-- Each viewer's alpha by its Visibility (ns.VISIBILITY): whole while the
-- Cooldown Manager or Edit Mode is open, so it can be seen to be set. The
-- alpha alone, so it is allowed in combat.
local faders, goals = {}, {}   -- by the frame faded: a viewer, or the simulation's
local inCombat = false
display.simCombat = false       -- the simulation playing a fight, for Visibility

local function Wanted(key)
    local V, vis = ns.VISIBILITY, Num(key, "Vis")
    if vis == V.ALWAYS or vis == 0 then return true end
    local s = _G.CooldownViewerSettings
    local e = _G.EditModeManagerFrame
    if (s and s:IsShown()) or (e and e:IsShown()) then return true end
    local over = holders[key]:IsMouseOver()
    local fighting = inCombat or (sims[key] ~= nil and display.simCombat)
    if vis == V.COMBAT then return fighting end
    if vis == V.MOUSEOVER then return over end
    return fighting or over
end

-- The viewer's alpha, or, while the simulation runs, the simulation's (the
-- viewer then out of sight)
local function Fader(f)
    faders[f] = faders[f] or ns.Fader(f)
    return faders[f]
end
local function Fade(key, now)
    local v, sim = viewers[key], sims[key]
    local f = sim and sim.root or v
    if not f then return end
    if sim and v and now then
        Fader(v):Go(0, 0)
        goals[v] = 0
    end
    local goal = Wanted(key) and 1 or math.max(0, math.min(1, Num(key, "Faded")))
    if goals[f] == goal and not now then return end
    goals[f] = goal
    Fader(f):Go(goal, not now and Num(key, "FadeTime") or 0)
end
display.Fade = Fade

local function FadeAll(now)
    for key in pairs(holders) do Fade(key, now) end
end

-- the pointer over a viewer whose Visibility asks for it: a look each tenth
local watch = CreateFrame("Frame")
watch:Hide()
local since = 0
watch:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    FadeAll()
end)
local function Watch()
    local V, any = ns.VISIBILITY, false
    for key in pairs(holders) do
        local vis = Num(key, "Vis")
        any = any or ((viewers[key] or sims[key]) and (vis == V.MOUSEOVER or vis == V.COMBAT_OR_MOUSEOVER))
    end
    watch:SetShown(any)
end

ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; FadeAll() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; FadeAll() end)

-- ------------------------------------------------------------- the options
-- A viewer's option changed: its icons dressed again and laid out again;
-- its size placed (out of combat); its fade. Its place is movers.lua's.
local BY_LETTER = {}
for _, v in ipairs(ns.CDM_VIEWERS) do BY_LETTER[v[1]] = v[2] end
ns.OnAnySetting(function(setting)
    local letter, field = tostring(setting):match("^cdm([EUB])(%u%a*)$")
    local key = letter and BY_LETTER[letter]
    if not key or not List(key) or field == "X" or field == "Y" then return end
    if field == "Vis" or field == "Faded" or field == "FadeTime" then
        Watch()
        Fade(key, true)
        return
    end
    for _, item in ipairs(List(key)) do Restyle(item) end
    if field == "Size" then
        if sims[key] then sims[key].Resize() end
        ns.OutOfCombat(Place)
    end
    Arrange(key)
end)

-- ------------------------------------------------------------- the takeover
local function Adopt(key)
    local v = Viewer(key)
    if not v or viewers[key] then return end
    viewers[key] = v
    -- Edit Mode's own box for the viewer (its Selection) is sized to the
    -- game's grid, which no longer holds the icons: it drew inside our mover,
    -- which covers them where they are. Out of sight and let through to the
    -- mover; Edit Mode never sets either itself. Widget state only, no field
    -- written on the game's frames, so nothing is tainted.
    local box = v.Selection
    if box and box.SetAlpha then
        box:SetAlpha(0)
        if box.EnableMouse then box:EnableMouse(false) end
    end
    DressAll(v, key)
    if v.OnAcquireItemFrame then
        hooksecurefunc(v, "OnAcquireItemFrame", function(_, item) Dress(item, key) end)
    end
    if v.RefreshLayout then
        hooksecurefunc(v, "RefreshLayout", function()
            DressAll(v, key)
            ns.OutOfCombat(Place)
        end)
    end
    -- the game's grid laying the icons out: ours over it, after
    local ok, c = pcall(function() return v.GetItemContainerFrame and v:GetItemContainerFrame() end)
    c = ok and c or v
    if c and c.Layout then
        hooksecurefunc(c, "Layout", function() Arrange(key) end)
    end
    -- Edit Mode (or the game) moving it: back on its holder once combat allows
    hooksecurefunc(v, "SetPoint", function()
        if not placing then ns.OutOfCombat(Place) end
    end)
    Fade(key, true)
end

local function AdoptAll()
    for _, key in ipairs({ "essential", "utility", "buffs" }) do Adopt(key) end
    if next(viewers) then
        started = true
        ns.OutOfCombat(Place)
        Watch()
        -- the Cooldown Manager's window showing each viewer whole while open
        local s = _G.CooldownViewerSettings
        if s and s.HookScript and not deco[s] then
            deco[s] = true
            s:HookScript("OnShow", function() FadeAll(true) end)
            s:HookScript("OnHide", function() FadeAll(true) end)
        end
    end
end
display.Adopt = AdoptAll

local function Start()
    if not (ns.db.cdmWindow and ns.db.cdmDisplay) then return end
    inCombat = InCombatLockdown and InCombatLockdown() or false
    AdoptAll()
    ns.On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_CooldownViewer" then AdoptAll() end
    end)
    local e = _G.EditModeManagerFrame
    if e and e.HookScript then
        e:HookScript("OnShow", function() FadeAll(true) end)
        e:HookScript("OnHide", function() FadeAll(true) end)
    end
end

-- The simulation's icons (cooldowns/simulate.lua) standing in for a
-- viewer's: { root, items, Resize }, or nil to give the viewer back. The
-- holders are placed for it even with no viewer.
function display.Simulate(key, sim)
    sims[key] = sim
    if sim then
        for _, item in ipairs(sim.items) do Dress(item, key) end
    end
    ns.OutOfCombat(Place)
    Arrange(key)
    Watch()
    Fade(key, true)
end

ns.On("PLAYER_LOGIN", Start)
