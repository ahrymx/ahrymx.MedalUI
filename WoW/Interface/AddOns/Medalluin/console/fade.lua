-- Fading the console and the overhead.
--
--   the console    Console > General > Visibility and Opacity: while it is
--                  idle (nothing ticked there is so) it fades to its faded
--                  opacity, and back to its opacity when something is
--   minimal        Console > General > Visibility, Minimal OoC Mode (the
--                  Reticule only): out of combat everything fades to its
--                  "everything else" opacity but the player and target
--                  frames, lifted out of the console's alpha to their own
--                  (20%); combat, and what is ticked there, bring it back.
--                  It takes over from fading when idle while it is on. The
--                  overhead is not the console's: it keeps its own opacity
--   the overhead   Console > Overhead > Opacity: it shows whenever it holds
--                  anything (console/overhead.lua), so it only fades in as it
--                  appears and out as it empties
--
-- Only the alpha changes, which is allowed in combat, so a faded console
-- keeps working: its buttons still click and its keys still press, as a faded
-- action bar's do (bars/bar.lua). Faded to nothing with the pointer not among
-- what wakes it, it takes no mouse instead (ns.Untouchable, core.lua). The corner strips and the corner minimap
-- are the console's children but not its body, so they keep their own alpha.
local _, ns = ...

local console, overhead = ns.console, ns.overhead

local function Num(key, lo, hi)
    local v = tonumber(ns.db[key])
    if v == nil then v = tonumber(ns.OptionBase(key)) or lo end
    return math.max(lo, math.min(hi, v))
end

-- A frame's alpha eased toward a goal: a fade takes `time` seconds however
-- far it goes, and `done` runs when it gets there. The driver is its own
-- frame, so it runs while the faded frame is hidden too.
function ns.Fader(frame)
    local o = { alpha = frame:GetAlpha() or 1 }
    local driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    local function Arrive()
        driver:Hide()
        local done = o.done
        o.done = nil
        if done then done() end
    end
    function o:Set(a)
        self.alpha = a
        frame:SetAlpha(a)
    end
    function o:Go(goal, time, done)
        self.goal, self.done = goal, done
        local dist = math.abs(goal - self.alpha)
        if not time or time <= 0 or dist == 0 then
            self:Set(goal)
            Arrive()
            return
        end
        self.rate = dist / time
        driver:Show()
    end
    function o:Moving() return driver:IsShown() end
    driver:SetScript("OnUpdate", function(_, dt)
        local a, g = o.alpha, o.goal
        local step = dt * o.rate
        a = g > a and math.min(g, a + step) or math.max(g, a - step)
        o:Set(a)
        if a == g then Arrive() end
    end)
    o.driver = driver
    return o
end

-- ------------------------------------------------------------ the console
local fader = ns.Fader(console)
ns.consoleFader = fader
local inCombat = false

-- Hurt: health below its most. Where health is secret (retail always,
-- Forever in combat) it cannot be compared, so it is guessed: health that
-- is not full keeps changing (regeneration, or the fight), and full health
-- goes quiet. So hurt while the player's health changed in the last
-- REGEN_QUIET seconds. Wrong while regeneration is stopped, and briefly
-- after a change at full (a max health buff). Never a secret alpha instead:
-- it would mark every frame under the console secret too (2026-11-15:
-- Bar 7, the bars and the console art all broke reading their own alpha).
local REGEN_QUIET = 3
local healthChanged = -math.huge
local healthWatch = CreateFrame("Frame")
healthWatch:RegisterUnitEvent("UNIT_HEALTH", "player")
healthWatch:SetScript("OnEvent", function(_, _, unit)
    if unit == "player" then healthChanged = GetTime() end
end)
local function Hurt()
    local h, most = UnitHealth("player"), UnitHealthMax("player")
    if ns.IsSecret(h) or ns.IsSecret(most) then return GetTime() - healthChanged < REGEN_QUIET end
    if not h or not most or most <= 0 then return false end
    return h < most
end
ns.PlayerHurt = Hurt

-- The pointer over the console or anything that hangs off it.
local function Over()
    for _, f in ipairs({ console, ns.actionBar, ns.extraBars, ns.partyRowBand }) do
        if f and f:IsVisible() and f:IsMouseOver() then return true end
    end
    return ns.drawer and ns.drawer:IsShown() and ns.drawer:IsMouseOver() or false
end

-- Minimal OoC Mode: on, and on the console it was made for
local function Minimal()
    return ns.db.consoleMinimal and ns.consoleBuilt == "reticule" and true or false
end
ns.ConsoleMinimal = Minimal

-- Whether the console shows at its full opacity now. Binding keys, a spell
-- or item on the cursor, Edit Mode's movers and the party preview always
-- want it whole: they are about what is on it.
function ns.ConsoleWanted()
    local db = ns.db
    local minimal = Minimal()
    if not (db.consoleFade or minimal) then return true end
    if ns.keybinding or (GetCursorInfo and GetCursorInfo()) or db.simParty
        or (ns.ConsoleMoversShown and ns.ConsoleMoversShown()) then
        return true
    end
    if minimal then
        return inCombat
            or (db.consoleMinimalTarget and UnitExists("target"))
            or (db.consoleMinimalHurt and Hurt())
            or (db.consoleMinimalGroup and IsInGroup())
            or (db.consoleMinimalMouse and Over())
            or false
    end
    return (db.consoleShowCombat and inCombat)
        or (db.consoleShowTarget and UnitExists("target"))
        or (db.consoleShowHurt and Hurt())
        or (db.consoleShowGroup and IsInGroup())
        or (db.consoleShowMouse and Over())
        or false
end

-- The player and target frames while minimal: out of the console's alpha
-- (set only out of combat: they are secure buttons), their own eased as
-- one by the units' fader. Lifted, they follow the console's goal when it
-- is whole, their own opacity when it is minimal.
local UNITS = { "player", "target" }
local lifted = false
local units = ns.Fader({
    GetAlpha = function() return 1 end,
    SetAlpha = function(_, a)
        for _, u in ipairs(UNITS) do
            local b = ns.units and ns.units[u]
            if b then b:SetAlpha(a) end
        end
    end,
})
ns.unitsFader = units

-- Out of the pointer's way at nothing (ns.Untouchable): the console when
-- the pointer is not among what wakes it and its faded opacity is 0; the
-- lifted player and target the same at their own 0. Combat, or what is
-- ticked that can come in a fight, may wake it.
local function NoMouse()
    local db = ns.db
    if Minimal() then return not db.consoleMinimalMouse end
    return db.consoleFade and not db.consoleShowMouse or false
end
local touch = ns.Untouchable(console, function()
    return NoMouse() and fader.goal == 0 and fader.alpha == 0
end, function()
    local db = ns.db
    return Minimal() or db.consoleShowCombat or db.consoleShowTarget or db.consoleShowHurt
        or db.consoleShowGroup or false
end)
ns.consoleTouch = touch
touch.name = "console"
local unitTouch = ns.Untouchable(function()
    local list = {}
    for _, u in ipairs(UNITS) do
        local b = ns.units and ns.units[u]
        if b then table.insert(list, b) end
    end
    return list
end, function()
    return lifted and Minimal() and not ns.db.consoleMinimalMouse and units.goal == 0 and units.alpha == 0
end)
ns.unitsTouch = unitTouch
unitTouch.name = "player and target"
local function Touched() touch:Update() end
local function UnitsTouched() unitTouch:Update() end

local wanted
-- now: a setting changed, so go there at once rather than fade
local function Update(now)
    local want, minimal = ns.ConsoleWanted(), Minimal()
    local goal = want and Num("consoleAlpha", 0, 1)
        or minimal and Num("consoleMinimalRest", 0, 1) or Num("consoleFadedAlpha", 0, 1)
    local unitGoal = lifted and (want and Num("consoleAlpha", 0, 1) or Num("consoleMinimalUnits", 0, 1)) or 1
    if not now and want == wanted and goal == fader.goal and unitGoal == units.goal then return end
    wanted = want
    local time = (not now) and Num(want and "consoleFadeIn" or "consoleFadeOut", 0, 10) or 0
    fader:Go(goal, time, Touched)
    units:Go(unitGoal, time, UnitsTouched)
    touch:Update()
    unitTouch:Update()
end
ns.UpdateConsoleFade = Update

-- the player and target lifted out of the console's alpha while minimal,
-- back in it after; a change in combat waits for it to end
local function Lift()
    ns.OutOfCombat(function()
        local on = Minimal()
        if on ~= lifted then
            for _, u in ipairs(UNITS) do
                local b = ns.units and ns.units[u]
                if b and b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(on) end
            end
            lifted = on
            -- the console may already be out of the pointer's way: the
            -- lifted are their own now, given back (or taken, dropped)
            touch:Refresh()
        end
        Update(true)
    end)
end

-- The pointer has no event, so the console looks ten times a second.
local watch = CreateFrame("Frame", nil, UIParent)
local since = 0
watch:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    Update()
    -- each look, so a part off and still holding frames gives them back
    touch:Update()
    unitTouch:Update()
end)
ns.consoleFadeWatch = watch

ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; Update() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; Update() end)
ns.On("PLAYER_TARGET_CHANGED", function() Update() end)
ns.On("GROUP_ROSTER_UPDATE", function() Update() end)
ns.On("PLAYER_ENTERING_WORLD", function()
    inCombat = UnitAffectingCombat("player") and true or false
    Update(true)
end)
for _, key in ipairs({ "consoleFade", "consoleShowCombat", "consoleShowTarget", "consoleShowHurt",
    "consoleShowGroup", "consoleShowMouse", "consoleAlpha", "consoleFadedAlpha", "simParty" }) do
    ns.OnSetting(key, function() Update(true) end)
end
for _, key in ipairs({ "consoleMinimalUnits", "consoleMinimalRest", "consoleMinimalTarget", "consoleMinimalHurt",
    "consoleMinimalGroup", "consoleMinimalMouse" }) do
    ns.OnSetting(key, function() Update(true) end)
end
ns.OnSetting("consoleMinimal", function()
    Update(true)
    Lift()
end)

-- The strips keep their own alpha (the minimap in the corner sets its own:
-- console/minimap.lua).
ns.On("PLAYER_LOGIN", function()
    for _, strip in pairs(ns.strips or {}) do
        if strip.SetIgnoreParentAlpha then strip:SetIgnoreParentAlpha(true) end
    end
    Update(true)
    Lift()
end)

-- ------------------------------------------------------------ the overhead
local top = ns.Fader(overhead)
ns.overheadFader = top

-- Its opacity, its own: the console's fading and Minimal OoC Mode leave it be
local function OverheadGoal()
    return Num("overheadAlpha", 0, 1)
end

-- As it appears: from nothing, or from wherever a fade out had got to.
function ns.OverheadFadeIn()
    local goal = OverheadGoal()
    if not top:Moving() and top.alpha == goal then return end
    top:Go(goal, Num("overheadFadeIn", 0, 10))
end
-- As it empties: what it showed stays while it fades, then done() clears it.
-- False when there is no fade to make, and the overhead should go at once.
function ns.OverheadFadeOut(done)
    local time = Num("overheadFadeOut", 0, 10)
    if time <= 0 then return false end
    top:Go(0, time, done)
    return true
end
-- Shown at once: before it ever appears, and when it is turned off
function ns.OverheadSettle(shown)
    top:Go(shown and OverheadGoal() or 0, 0)
end
-- its opacity changed: there at once, while it shows and is not on its way out
function ns.OverheadRegoal(time)
    if overhead:IsShown() and not (top:Moving() and top.goal == 0) then
        local goal = OverheadGoal()
        if goal ~= top.goal or top.alpha ~= goal then top:Go(goal, time) end
    end
end
ns.OnSetting("overheadAlpha", function() ns.OverheadRegoal(0) end)
