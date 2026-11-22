-- MedalUI core: namespace, media, palette, events and the hidden parent.
local _, ns = ...

ns.media = "Interface\\AddOns\\MedalUI\\media\\"
-- The face, by the client's letters (2026-11-19, a player's issue: Marcellus
-- SC has no Cyrillic, so a Russian client drew squares): Forum, a serif
-- of the same carved capitals with Cyrillic, on ruRU; the game's own on
-- Korean and Chinese, which no bundled face covers; else Marcellus SC.
-- On Latin clients the player may choose Forum instead (General > Font,
-- after a reload). The companions follow (mdlui_Tooltips,
-- mdlui_RadialMenu), through MedalUIFontFace.
local FACES = {
    marcellus = ns.media .. "fonts\\MarcellusSC-Regular.ttf",
    forum = ns.media .. "fonts\\Forum-Regular.ttf",
}
ns.FACES = FACES
local FACE = { ruRU = "forum" }
local GAME_FACE = { koKR = true, zhCN = true, zhTW = true }
local locale = GetLocale and GetLocale() or "enUS"
-- whether the face is the player's to choose: Latin letters, which both have
ns.faceChoosable = not GAME_FACE[locale] and not FACE[locale]
if GAME_FACE[locale] then
    ns.font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
else
    ns.font = FACES[FACE[locale] or "marcellus"]
end
local FACE_NAMES = { [FACES.marcellus] = "Marcellus SC", [FACES.forum] = "Forum" }

-- The texts made before the settings load (the files' own, as they run):
-- the face is not known yet, so they take the default and are put right
-- once it is (ns.SettleFace, from settings.lua's ADDON_LOADED). Every text
-- made then comes through ns.Text.
local early = {}
function ns.SettleFace(key)
    local path = ns.faceChoosable and FACES[key]
    if path and path ~= ns.font then
        local old = ns.font
        ns.font = path
        for fs in pairs(early or {}) do
            local face, size, flags = fs:GetFont()
            if face == old then fs:SetFont(path, size, flags) end
        end
    end
    early = nil
    -- for the companions, which load after us: the bundled face, or nil
    -- for the game's
    MedalUIFontFace = FACE_NAMES[ns.font] and ns.font or nil
end
ns.bar = ns.media .. "bar"

-- Sampled from the H mockup so code-drawn fills sit in the art's palette.
ns.colors = {
    ink = { 0.071, 0.067, 0.063 },      -- #121110, an empty window
    text = { 0.949, 0.918, 0.824 },     -- #f2ead2
    dim = { 0.70, 0.66, 0.55 },
    xp = { 0.847, 0.722, 0.416 },       -- #d8b86a
    rested = { 0.541, 0.439, 0.204 },   -- #8a7034
    rep = { 0.643, 0.545, 0.310 },      -- #a48b4f
    dead = { 0.35, 0.35, 0.35 },
    white = { 1, 1, 1 },
    grey = { 0.7, 0.7, 0.7 },
}
-- Blizzard's class and reaction colours are brighter than the art; mute them.
ns.mute = 0.8

-- One event frame for the whole addon: ns.On("EVENT", fn).
local handlers, events = {}, CreateFrame("Frame")
ns.eventFrame = events                          -- told apart from the game's listeners (strips/rolls.lua)
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)
-- An event this client does not have (Forever lacks ROLE_POLL_UPDATE and
-- QUEUE_STATUS_UPDATE) is skipped: RegisterEvent raises, and the raise would
-- end the calling file's main chunk, losing everything after it.
function ns.On(event, fn)
    if not handlers[event] then
        if not pcall(events.RegisterEvent, events, event) then return end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
end

-- Work that touches protected frames waits for combat to end.
local queued = {}
function ns.OutOfCombat(fn)
    if InCombatLockdown() then
        table.insert(queued, fn)
    else
        fn()
    end
end
ns.On("PLAYER_REGEN_ENABLED", function()
    for i = 1, #queued do queued[i]() end
    wipe(queued)
end)

-- A part faded to nothing that the pointer cannot wake (no mouseover in its
-- visibility) is out of the pointer's way: no tooltips under it, no clicks
-- (2026-11-15). Its keys still press, as Bar 7's do.
--
-- ns.Untouchable(frames, Off, CanWake): frames, a frame or a function
-- returning a list of them, each walked with its descendants (a subtree
-- that keeps its own alpha skipped: it is judged on its own). Off(): whether
-- the part is off now. o:Update() asks Off() again; o:Refresh() walks again
-- (frames built since). Only a frame taking the mouse when taken is ours to
-- give back; one held by two parts comes back when both let it go. A
-- protected frame changes out of combat only: a change asked in combat
-- waits for it to end, the last ask deciding. At PLAYER_REGEN_DISABLED,
-- before the lockdown, each part decides once for the fight: off only if
-- nothing can wake it in combat (CanWake(); a part that shows in combat
-- leaves it out), so a part that may show in the fight is never seen
-- unclickable.
local holds = setmetatable({}, { __mode = "k" })   -- by frame: the parts holding it off
local touches = {}
local function Locked(f)
    return f.IsProtected and f:IsProtected() and InCombatLockdown()
end
local function OwnedBy(tip, f)
    local owner = tip and tip:IsShown() and tip:GetOwner()
    while owner do
        if owner == f then return true end
        owner = owner.GetParent and owner:GetParent()
    end
    return false
end
-- What a frame took, the clicks and the pointer each, to give back as it
-- was: a frame can take one without the other (Blizzard's aura buttons
-- take the pointer for their tooltips and let clicks through to the frame
-- under them; the live dispel glow lies over a whole unit frame), and
-- EnableMouse(true) would give it both (2026-11-15: the player and target
-- frames stopped taking right clicks once faded out and back).
-- Read as they come, never tested: Blizzard's aura buttons answer with
-- secrets (and testing one is an error), so a secret is kept as it is and
-- handed back to the game as it was.
local took = setmetatable({}, { __mode = "k" })
local function Takes(f)
    if f.IsMouseClickEnabled and f.IsMouseMotionEnabled then
        return f:IsMouseClickEnabled(), f:IsMouseMotionEnabled()
    end
    local on = f.IsMouseEnabled and f:IsMouseEnabled()
    return on, on
end
-- takes the mouse at all: a secret answer may, so it is taken too
local function Any(v) return ns.IsSecret(v) or (v and true or false) end
-- what the parts did last, for /mdlui mouse (diag.lua)
local trail = {}
ns.touchTrail = trail
local function Note(o, text)
    local t = GetTime and GetTime() or 0
    trail[#trail + 1] = string.format("%.1f %s%s: %s", t, o.name or "?",
        InCombatLockdown() and " [combat]" or "", text)
    if #trail > 30 then table.remove(trail, 1) end
end
local function Take(f, o)
    local h = holds[f]
    if h then
        if not h[o] then h[o] = true; o.held = o.held + 1 end
        return true
    end
    local click, motion = Takes(f)
    if not (Any(click) or Any(motion)) then return true end   -- never ours
    if Locked(f) then return false end
    if OwnedBy(GameTooltip, f) then GameTooltip:Hide() end
    f:EnableMouse(false)
    holds[f] = { [o] = true }
    took[f] = { click, motion }
    o.held = o.held + 1
    return true
end
local function Release(f, o)
    local h = holds[f]
    if not (h and h[o]) then return true end
    local others = false
    for k in pairs(h) do if k ~= o then others = true end end
    if others then h[o] = nil; o.held = o.held - 1; return true end
    if Locked(f) then return false end
    holds[f] = nil
    o.held = o.held - 1
    local was = took[f] or { true, true }
    took[f] = nil
    if f.SetMouseClickEnabled and f.SetMouseMotionEnabled then
        -- a secret handed back as it was; refused, the pointer comes back
        -- and the clicks do not, as an aura button has them (its tooltip,
        -- the clicks let through): never a button eating clicks it did not
        if not pcall(f.SetMouseClickEnabled, f, was[1]) then f:SetMouseClickEnabled(false) end
        if not pcall(f.SetMouseMotionEnabled, f, was[2]) then f:SetMouseMotionEnabled(true) end
    else
        f:EnableMouse(true)
    end
    return true
end
-- Not walked: a forbidden frame, and Blizzard's aura containers (the live
-- auras and dispel glow, console/auras.lua): the game's frames, refused to
-- an addon while auras are secret, their mouse the game's to set.
local function Kept(f)
    local ok, kept = pcall(function()
        if f.IsForbidden and f:IsForbidden() then return true end
        return f.GetObjectType and f:GetObjectType() == "AuraContainer" or false
    end)
    return not ok or kept
end
local function Walk(f, seen)
    if Kept(f) then return end
    seen[f] = true
    local ok, kids = pcall(function() return { f:GetChildren() } end)
    -- its answer tested inside the pcall: a frame with Blizzard's secret
    -- aspects (the live auras' container, console/auras.lua) answers with
    -- a secret, and testing one outside ended every walk with an error
    -- (2026-11-15: the player and target held for good). A secret counts
    -- as fading with its parent, as the container does: its auras are the
    -- player's, and skipping it left them under the pointer at nothing.
    for _, c in ipairs(ok and kids or {}) do
        local own, lifted = pcall(function()
            local v = c.IsIgnoringParentAlpha and c:IsIgnoringParentAlpha()
            if ns.IsSecret(v) then return false end
            return v and true or false
        end)
        if own and not lifted then Walk(c, seen) end
    end
end
-- One frame that refuses (an error) is left as it is, never the end of the
-- walk: frames after it would stay out of the pointer's way for good
-- (2026-11-15: the player frame's right click and auras' tooltips gone).
local function Safely(Do, f, o)
    local ok, done = pcall(Do, f, o)
    if ok then return done end
    Note(o, "a frame refused: " .. tostring(done))
    for k in pairs(holds[f] or {}) do k.held = k.held - 1 end
    holds[f], took[f] = nil, nil
    return true
end
function ns.Untouchable(frames, Off, CanWake)
    local o = { want = false, held = 0 }
    local function Roots()
        if type(frames) == "function" then return frames() or {} end
        return { frames }
    end
    local Apply
    local recheck
    local function ApplyNow()
        o.walked = GetTime and GetTime() or 0
        local seen, pending, before = {}, false, o.held
        for _, r in ipairs(Roots()) do Walk(r, seen) end
        for f in pairs(seen) do
            if not Safely(o.want and Take or Release, f, o) then pending = true end
        end
        -- held but no longer part of it: given back
        local gone = {}
        for f, h in pairs(holds) do
            if h[o] and not seen[f] then gone[#gone + 1] = f end
        end
        for _, f in ipairs(gone) do
            if not Safely(Release, f, o) then pending = true end
        end
        -- (a recheck that changed nothing is not noted: one a second)
        if not recheck or before ~= o.held or pending then
            Note(o, string.format("%s%s, held %d -> %d%s", recheck and "recheck: " or "", o.want and "take"
                or "give back", before, o.held, pending and ", the rest after combat" or ""))
        end
        if pending and not o.waiting then
            o.waiting = true
            ns.OutOfCombat(function() o.waiting = false; Apply() end)
        end
    end
    -- an error in the walk noted with where, never lost (/mdlui mouse)
    function Apply()
        local ok, err = xpcall(ApplyNow, function(e)
            local where = debugstack and debugstack(2, 2, 0) or ""
            return tostring(e) .. " " .. where:gsub("\n", " ")
        end)
        if not ok then Note(o, "error: " .. tostring(err)) end
    end
    -- Off and still holding frames (none should be): given back again, once
    -- nothing waits for combat to end (2026-11-15: the player frame kept
    -- without its clicks, the part off).
    -- Out of the pointer's way, looked over again once a second: a frame
    -- that left it since (it took its own alpha: the corner strips and
    -- minimap while the game menu put the interface away, the minimap to
    -- the corner) is given back, and one that came is taken. Walked only
    -- as it went out before, a frame held then stayed without its clicks
    -- until it showed again (2026-11-19).
    local RECHECK = 1
    function o:Set(off)
        off = off and true or false
        if off == self.want then
            if off then
                local now = GetTime and GetTime() or 0
                if not self.waiting and now - (self.walked or 0) >= RECHECK then
                    recheck = true
                    Apply()
                    recheck = false
                end
                return
            end
            if self.held <= 0 or self.waiting then return end
            if self.noted ~= self.held then Note(self, "off, yet holding " .. self.held) end
            self.noted = self.held
        end
        self.want = off
        Apply()
    end
    function o:Update() self:Set(Off()) end
    function o:Refresh() if self.want then Apply() end end
    o.CanWake = CanWake or function() return true end
    o.Off = Off
    table.insert(touches, o)
    return o
end
-- for /mdlui mouse (diag.lua): every part, and who holds a frame
ns.untouchables = touches
function ns.TouchHeld(f) return holds[f], took[f] end
ns.On("PLAYER_REGEN_DISABLED", function()
    for _, o in ipairs(touches) do o:Set(o.Off() and not o.CanWake()) end
end)
-- the fight over: each asks again (a part at rest has no change to ask on)
ns.On("PLAYER_REGEN_ENABLED", function()
    for _, o in ipairs(touches) do o:Update() end
end)

-- A state driver whose states reach the frame only from the game's secure
-- update, never from MedalUI's own code. RegisterStateDriver applies the
-- conditional's state at once, inside the caller, and an addon's execution
-- is tainted: a snippet run then, setting "actionpage" on Blizzard's action
-- buttons, runs their OnAttributeChanged tainted, and what that writes on
-- the button taints every click after it ("MedalUI has been blocked",
-- UseAction; BugSack, 2026-11-01). So the frame holds while the driver is
-- registered (its snippet sees ns.HOLD and returns), and its state is left
-- at "hold", which no conditional gives: SecureStateDriverManager's next
-- update (within 0.2 s) sets the real state, securely, and the snippet runs
-- then. No conditional is the state nil, set the same way.
ns.HOLD = "medalui-hold"
function ns.DriveState(frame, state, conditional)
    frame:SetAttribute(ns.HOLD, true)
    RegisterStateDriver(frame, state, conditional or "nil")
    frame:SetAttribute("state-" .. state, "hold")
    frame:SetAttribute(ns.HOLD, nil)
end

-- Blizzard frames are parented here and unregistered, never just hidden,
-- so their own code cannot show them again and taint stays contained.
ns.hidden = CreateFrame("Frame")
ns.hidden:Hide()
-- Some come back: retail-family clients reparent MainActionBar to UIParent
-- when a vehicle or pet battle lets go of it. Such a frame goes back to the
-- hidden parent as soon as combat allows.
local killed = {}
-- Park is Kill without the unregistering: the frame is out of sight, but its
-- own events still run. The stance and pet bars are parked, because their
-- events are what give the buttons the overhead adopts their icons.
-- Parked under the veil (under) instead, a frame stays visible to its own
-- code: Blizzard_TrainerUI shows its frame and closes the trainer at once
-- when it is not IsVisible, which a frame under the hidden parent never is.
-- The veil is shown but see-through, and shrunk to a speck, so nothing on
-- it draws or takes a click.
ns.veil = CreateFrame("Frame", nil, UIParent)
ns.veil:SetAlpha(0)
ns.veil:SetScale(0.01)
local parkedUnder = {}                  -- a parked frame's parent, while it is parked
function ns.Park(frame, under)
    if not frame then return end
    under = under or ns.hidden
    parkedUnder[frame] = under
    frame:SetParent(under)
    if killed[frame] then return end
    killed[frame] = true
    hooksecurefunc(frame, "SetParent", function(self, parent)
        if parent ~= parkedUnder[self] then
            -- (asked again when the move is made: given back meanwhile, left be)
            ns.OutOfCombat(function()
                local held = parkedUnder[self]
                if held then self:SetParent(held) end
            end)
        end
    end)
end
-- A parked frame given back to Blizzard (UIParent's, shown as it draws
-- it) until it is parked again: the pet trainer's, whose Train only
-- Blizzard's own button may press (npc/trainer.lua).
function ns.Unpark(frame)
    if not frame then return end
    parkedUnder[frame] = nil
    frame:SetParent(UIParent)
end
function ns.Kill(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    ns.Park(frame)
end

-- Register a unit event if this client knows it; Classic-era clients have
-- renamed several (UNIT_HEALTH_FREQUENT, for one) between builds.
function ns.RegisterUnitEvent(frame, event, unit)
    return pcall(frame.RegisterUnitEvent, frame, event, unit)
end

-- ---------------------------------------------------------------- clients
-- One addon for Forever (1.60, a Mainline-family client: Edit Mode bars,
-- MicroMenu, duration objects, secret values) and retail (12.x), with the
-- older Classic-era names kept as fallbacks. Code asks for an API or frame
-- by name and never branches on a version number.

-- Secret values (combat-restricted numbers) can be shown by status bars and
-- font strings, but any arithmetic or comparison on one raises an error.
-- The simulated frames' situation, set by the simulation panel (simulate.lua);
-- for this session only. A set's state or aura that is on shows on at least
-- one of its frames (ns.SimHas); the party's members are set one by one, on
-- their stubs (console/units.lua).
ns.sim = {
    party = { count = 4, auras = { glow = true, cc = true, buffs = true, boss = true, mine = true } },
    raid = { groups = 2, hurt = true, auras = { glow = true, cc = true, boss = true, mine = true } },
    enemies = { bosses = 2, arena = 3, hurt = true, auras = { cc = true, mine = true } },
    overhead = { pet = true, focus = true, targettarget = true, hurt = true },
}

-- Where in a set a state or aura first falls, so that two of them fall on
-- different frames while there are frames enough.
-- (CC and the boss debuff share the centre: they meet only in a set of one.)
local FIRST = { away = 2, dead = 3, offline = 4, glow = 1, cc = 2, buffs = 3, boss = 4, mine = 1 }

-- Whether frame i of the n a set shows has state (or aura) key: the first
-- it falls on, and every eighth after it in a big set.
function ns.SimHas(set, key, i, n)
    local s = ns.sim[set]
    local on = s[key]
    if on == nil and s.auras then on = s.auras[key] end
    if not on or n < 1 or i > n then return false end
    local function First(k) return (FIRST[k] - 1) % n + 1 end
    local first = First(key)
    -- the boss debuff steps past CC's frame, the centre they share
    if key == "boss" and n > 1 and first == First("cc") then first = first % n + 1 end
    return i == first or i > first and (i - first) % 8 == 0
end

-- A set's states on frame i of n's stub: its health (whole unless the set
-- is hurt), dead, offline, out of range.
function ns.SimApply(stub, set, i, n)
    stub.hurtHealth = stub.hurtHealth or stub.health
    stub.health = ns.sim[set].hurt and stub.hurtHealth or stub.maxHealth
    stub.dead = ns.SimHas(set, "dead", i, n) or nil
    stub.offline = ns.SimHas(set, "offline", i, n) or nil
    stub.inRange = not ns.SimHas(set, "away", i, n)
end

function ns.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- v, or fallback when v is nil. A secret is never nil, and is passed on
-- untested: "v or fallback" would test it.
function ns.Or(v, fallback)
    if ns.IsSecret(v) then return v end
    if v == nil then return fallback end
    return v
end

-- Whether v is there at all, without testing a secret.
function ns.Present(v)
    return ns.IsSecret(v) or v ~= nil
end

-- The action-bar API moved into C_ActionBar; the old globals only exist
-- while the client's deprecation fallbacks are switched on.
local AB = C_ActionBar or {}
ns.HasAction = AB.HasAction or HasAction
ns.IsUsableAction = AB.IsUsableAction or IsUsableAction
ns.IsActionInRange = AB.IsActionInRange or IsActionInRange
function ns.ActionCooldown(action)
    if AB.GetActionCooldown then
        local info = AB.GetActionCooldown(action)
        if info then return info.startTime, info.duration, info.isEnabled end
        return
    end
    return GetActionCooldown(action)
end

-- Hide a Blizzard texture for good. Blizzard sets alpha (SetAlpha) on its
-- button art as states change; it does not touch the vertex colour's
-- alpha, so that is what silences it.
function ns.Mute(region)
    if region and region.SetVertexColor then region:SetVertexColor(1, 1, 1, 0) end
end

-- The fonts a reader may choose for text they read at length (the quest
-- tracker's): MedalUI's own, the four every client ships, then those
-- other addons register with LibSharedMedia, asked each time (they load
-- after us). Each { key, name, path }; a key is kept in the settings.
local FONTS = {
    { "marcellus", "Marcellus SC", ns.font },       -- MedalUI's face, whichever it is (ns.Fonts)
    { "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "arialn", "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "skurri", "Skurri", "Fonts\\SKURRI.TTF" },
}
local function Shared()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function ns.Fonts()
    local out = {}
    for _, f in ipairs(FONTS) do table.insert(out, f) end
    out[1] = { "marcellus", FACE_NAMES[ns.font] or out[1][2], ns.font }
    local lsm = Shared()
    if lsm then
        local mine = {}
        for _, f in ipairs(FONTS) do mine[f[3]:lower()] = true end
        for _, name in ipairs(lsm:List("font") or {}) do
            local path = lsm:Fetch("font", name, true)
            if path and not mine[path:lower()] then
                mine[path:lower()] = true
                table.insert(out, { "lsm:" .. name, name, path })
            end
        end
    end
    return out
end

-- A font key's file: MedalUI's own for a key no longer there (a shared
-- font whose addon is gone).
function ns.FontPath(key)
    if key == "marcellus" then return ns.font end
    for _, f in ipairs(FONTS) do
        if f[1] == key then return f[3] end
    end
    local name, lsm = type(key) == "string" and key:match("^lsm:(.+)$"), Shared()
    return name and lsm and lsm:Fetch("font", name, true) or ns.font
end

-- A text's points as MedalUI's code gave them (fs.medaluiPoints:
-- { point, relativeTo, relativePoint, x, y } each). The game keeps a text's
-- points secret while its words are (a health value, in a group), so the
-- unit-frame editor's canvas reads them here (options/canvas.lua).
local function Remember(fs)
    hooksecurefunc(fs, "ClearAllPoints", function(self) self.medaluiPoints = nil end)
    hooksecurefunc(fs, "SetPoint", function(self, point, rel, relPoint, x, y)
        -- (the short forms: point, x, y; point, rel, x, y)
        if type(rel) ~= "table" then rel, relPoint, x, y = self:GetParent(), point, rel, relPoint end
        if type(relPoint) ~= "string" then relPoint, x, y = point, relPoint, x end
        local list = self.medaluiPoints or {}
        for i = #list, 1, -1 do if list[i][1] == point then table.remove(list, i) end end
        table.insert(list, { point, rel, relPoint, x or 0, y or 0 })
        self.medaluiPoints = list
    end)
    hooksecurefunc(fs, "SetAllPoints", function(self, rel)
        rel = rel or self:GetParent()
        self.medaluiPoints = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
    end)
end

-- A tick or a cross in a line of text, as tall as the text and tinted
-- (colour {r, g, b}, 0-1; white when nil): neither Marcellus nor the game's
-- fonts have ✔ or ✖, which drew as an empty box (2026-11-13).
local function Mark(name, color, size)
    local c = color or { 1, 1, 1 }
    return ("|T%s:%d:%d:0:0:32:32:0:32:0:32:%d:%d:%d|t"):format(ns.media .. "options\\" .. name, size or 0,
        size or 0, math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
function ns.Tick(color, size) return Mark("tick", color, size) end
function ns.Cross(color, size) return Mark("cross", color, size) end

function ns.Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.font, size, "")
    if early then early[fs] = true end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(unpack(ns.colors.text))
    Remember(fs)
    return fs
end

-- ---------------------------------------------------------- tooltips
-- MedalUI's own tooltips, the ones no game data is behind: one spec,
-- written into GameTooltip as plain lines, and handed to mdlui_Tooltips
-- (mdlui/MedalUI.lua), which draws it as a panel instead.
--   spec = { title, color = {r, g, b} (the title's), wrap (the title's),
--     { "body", text, color },          -- a line, wrapped; white unless coloured
--     { "row", label, value, inline },  -- two columns, or "label: value"
--     { "bar", value, max, text, color },  -- the text here; a bar in the panel
--     { "item", icon, text, right },    -- "text  right"; an icon row in the panel
--     { "hint", text },                 -- dim; the panel's footer
--     { "key", button, modifier, does }, -- a shortcut, "Shift + (mouse) Link":
--                                       -- the modifier (or nil), a mouse glyph
--                                       -- ("left", "right", "middle"), what it
--                                       -- does in a word; neighbouring ones two
--                                       -- to a line, a grid; the footer too
--     { "warn", text } }                -- red
-- A part may be false, for one left out.
local WHITE, HINT, WARN = ns.colors.white, ns.colors.dim, { 1, 0.3, 0.25 }
local live = {}

local function Line(text, c, wrap)
    c = c or WHITE
    GameTooltip:AddLine(text, c[1], c[2], c[3], wrap)
end

local fill = {
    body = function(p) Line(p[2], p[3], true) end,
    row = function(p)
        if p[4] then Line(p[2] .. ": " .. p[3]) else GameTooltip:AddDoubleLine(p[2], p[3], 1, 1, 1, 1, 1, 1) end
    end,
    bar = function(p) Line(p[4]) end,
    item = function(p) Line(p[4] and format("%s  %s", p[3], p[4]) or p[3]) end,
    hint = function(p) Line(p[2], HINT) end,
    -- (key parts are written by Keys, two to a line)
    warn = function(p) Line(p[2], WARN, true) end,
}

-- a mouse with its button lit (media/strips/mouse-<button>), as text: the
-- glyph's 20 px box of its 32
function ns.MouseGlyph(button, size)
    size = size or 16
    return ("|T%sstrips\\mouse-%s:%d:%d:0:0:32:32:5:27:5:27|t"):format(ns.media, button, size, size)
end
-- a key part as its cell: "Shift + (mouse) Link"
function ns.KeyCell(p)
    if not p[2] then return "" end      -- an empty slot of the grid
    return (p[3] and (p[3] .. " + ") or "") .. ns.MouseGlyph(p[2]) .. " " .. p[4]
end

-- the parts written in order, neighbouring keys two to a line
local function Write(parts)
    local held
    local function Flush()
        if held and ns.KeyCell(held) ~= "" then
            GameTooltip:AddDoubleLine(ns.KeyCell(held), "", HINT[1], HINT[2], HINT[3])
        end
        held = nil
    end
    for _, p in ipairs(parts) do
        if p and p[1] == "key" then
            if held then
                local a, b = ns.KeyCell(held), ns.KeyCell(p)
                -- two cells side by side (mdlui_Tooltips lines them up as a grid);
                -- a row of two empty slots left out
                if a ~= "" or b ~= "" then
                    GameTooltip:AddDoubleLine(a, b, HINT[1], HINT[2], HINT[3], HINT[1], HINT[2], HINT[3])
                end
                held = nil
            else
                held = p
            end
        elseif p then
            Flush()
            fill[p[1]](p)
        end
    end
    Flush()
end

-- a tooltip's key lines, for one written outside a spec (the tracker's)
function ns.TipKeys(keys) Write(keys) end

-- anchor: SetOwner's, or a function that owns and places it (w.Beside)
function ns.Tip(owner, anchor, spec)
    if type(anchor) == "function" then anchor(owner) else GameTooltip:SetOwner(owner, anchor) end
    local c = spec.color
    GameTooltip:SetText(spec.title, c and c[1], c and c[2], c and c[3], c and 1, spec.wrap)
    Write(spec)
    spec.owner = owner
    live[GameTooltip] = spec
    GameTooltip:Show()
end

-- a SetOwner or ClearLines from anyone else ends it
if GameTooltip then
    GameTooltip:HookScript("OnTooltipCleared", function(self) live[self] = nil end)
end

-- The spec GameTooltip shows, while its owner is still the one it was
-- written for: the companion's only way in.
function MedalUI_TooltipSpec(tooltip)
    local spec = live[tooltip]
    if spec and tooltip:GetOwner() == spec.owner then return spec end
end

-- ------------------------------------------------------------ links into chat
-- A shift-clicked link: into the chat box being typed in, else the chat
-- opened with it, no Enter first (as the game's quest log does). Only where
-- Shift means nothing else: the game's bags split a stack with it, and a
-- merchant's list buys one.
local function ActiveChat()
    local get = ChatEdit_GetActiveWindow or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow)
    return get and get() or nil
end
ns.ChatOpen = function() return ActiveChat() ~= nil end
function ns.LinkInChat(link)
    if type(link) ~= "string" or link == "" then return end
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if insert and insert(link) then return end
    if ActiveChat() then return end
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if open then open(link) end
end
-- whether a click is the one that links (Shift, as the player has set it)
function ns.Linking(button)
    if button and button ~= "LeftButton" then return false end
    if IsModifiedClick then return IsModifiedClick("CHATLINK") and true or false end
    return IsShiftKeyDown() and true or false
end
-- (2026-11-22) An item's modified clicks, as the game's own item buttons
-- answer them: Shift (CHATLINK) links it in chat, Ctrl (DRESSUP) tries it on
-- in the dressing room. True when the click was one of them (the caller's
-- own click is then left undone). A link, or an item id (its link once the
-- client knows it).
function ns.ItemLink(item)
    if type(item) == "number" then
        local get = C_Item and C_Item.GetItemInfo or GetItemInfo
        item = get and select(2, get(item))
    end
    if type(item) ~= "string" or item == "" or ns.IsSecret(item) then return nil end
    return item
end
function ns.ItemClick(item, button)
    if button and button ~= "LeftButton" and button ~= "LeftButtonUp" then return false end
    local link = ns.ItemLink(item)
    if not link then return false end
    if ns.Linking() then
        ns.LinkInChat(link)
        return true
    end
    local dress
    if IsModifiedClick then dress = IsModifiedClick("DRESSUP") else dress = IsControlKeyDown() end
    if dress then
        local try = DressUpLink or DressUpItemLink
        if try then try(link) end
        return true
    end
    return false
end
function ns.SpellLink(id)
    if not id then return end
    if C_Spell and C_Spell.GetSpellLink then return C_Spell.GetSpellLink(id) end
    return GetSpellLink and GetSpellLink(id)
end
