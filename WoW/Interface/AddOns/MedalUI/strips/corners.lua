-- The medallions' corners in minimal mode (2026-11-25, the user's pick 1+2
-- of the "Minimal Mode Corners" mockups): the boxes round the controls by
-- the two medallions go with the chrome, the controls staying where they
-- are as bare glyphs; idle on, the glyphs go too, and the pointer near
-- the corner brings them back. Only alpha: every control still clicks.
--
--   the character's (-1)  the chat's well over the portrait (strips/chat.lua)
--                         and the drawer's chevron (strips/drawer.lua)
--   the backpack's (1)    the side panel's tabs and its well (strips/side.lua)
--                         and the drawer's chevron
--
-- Per corner:
--   box     the boxes' alpha: the chat's bare chrome (minimal mode); on the
--           backpack's while the side panel is open, its box's own fade
--           instead, so the tabs go as the panel over them does
--   show    the glyphs': 1 while the pointer is near the corner (or its
--           drawer open, or the box whole), and chatBareDelay seconds after;
--           then it fades out
--   a glyph shows max(box, show) of its own strength
local _, ns = ...

local IN, OUT = 0.2, 0.6        -- the glyphs' fade in and out, seconds
local NEAR = 12                 -- the pointer's slack round the corner's frames

local function Num(key, lo, hi)
    local v = tonumber(ns.db[key])
    if v == nil then v = tonumber(ns.OptionBase(key)) or lo end
    return math.max(lo, math.min(hi, v))
end

local corners = {}
ns.corners = corners

local function Box(side)
    local chat = ns.chatChrome and ns.chatChrome.alpha or 1
    if side < 0 then return chat end
    local s = ns.side
    if s and s.panel and ns.sideFader and not s.Closed() then return ns.sideFader.alpha end
    return chat
end

-- the frames the pointer finds the corner by
local function Frames(side)
    local list = {}
    local function add(f) if f and f:IsVisible() then table.insert(list, f) end end
    if side < 0 then
        add(ns.chat and ns.chat.well)
    elseif ns.side then
        add(ns.side.row)
        add(ns.side.well)
    end
    local D = ns.stripDrawers[side]
    add(D and D.key)
    return list
end

local function Near(side)
    for _, f in ipairs(Frames(side)) do
        if f:IsMouseOver(NEAR, -NEAR, -NEAR, NEAR) then return true end
    end
    local D = ns.stripDrawers[side]
    return D ~= nil and D.open and true or false
end

-- the corner's alphas, now: called as the box fades (each frame) and as
-- the glyphs do
local function Paint(side)
    local c = corners[side]
    if not c then return end
    local box = Box(side)
    local strength = math.max(box, c.show)
    c.box, c.strength = box, strength
    if side > 0 and ns.side and ns.side.Corner then ns.side.Corner(box, strength) end
    local D = ns.stripDrawers[side]
    if D and D.Corner then D.Corner(box, strength) end
end
ns.CornerPaint = Paint

local function Tick(dt)
    if not corners[-1] then return end
    for _, side in ipairs({ -1, 1 }) do
        local c = corners[side]
        local box = Box(side)
        if box >= 1 or Near(side) then c.idle = 0 else c.idle = c.idle + dt end
        local goal = c.idle < Num("chatBareDelay", 0, 10) and 1 or 0
        if goal ~= c.fader.goal then c.fader:Go(goal, goal == 1 and IN or OUT) end
        Paint(side)
    end
end
corners.Tick = Tick

ns.On("PLAYER_LOGIN", function()
    for _, side in ipairs({ -1, 1 }) do
        local c = { side = side, idle = 0, show = 1 }
        c.fader = ns.Fader({
            GetAlpha = function() return 1 end,
            SetAlpha = function(_, a) c.show = a; Paint(side) end,
        })
        c.fader.goal = 1
        corners[side] = c
    end
    -- the pointer has no event: the corners look ten times a second
    local watch = CreateFrame("Frame", nil, UIParent)
    local since = 0
    watch:SetScript("OnUpdate", function(_, dt)
        since = since + dt
        if since < 0.1 then return end
        Tick(since)
        since = 0
    end)
    corners.watch = watch
    Paint(-1)
    Paint(1)
end)
