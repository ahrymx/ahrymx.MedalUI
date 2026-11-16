-- The "radial" pass: mdlui_RadialMenu, loaded after Medalluin (tools/harness.lua
-- hands over what it keeps local). Its secure snippets run here in an emulated
-- restricted environment: one shared table of globals per header (ACTIVE,
-- MODE, CHILD ...), frame refs, header bindings, and the wraps' pre and post
-- bodies around a click, so the slot maths, the hold, click mode, the wheel
-- and the controller can be played through without the game.
local H = ...
local events, setCombat = H.events, H.setCombat
local ADDON = "WoW/Interface/AddOns/mdlui_RadialMenu/"

-- ------------------------------------------------------------ stubs
-- override bindings, by owner: key -> "frame:button"
local owned = {}
function SetOverrideBindingClick(owner, prio, key, name, button)
    if InCombatLockdown() then error("SetOverrideBindingClick in combat") end
    owned[owner] = owned[owner] or {}
    owned[owner][key] = name .. ":" .. tostring(button) .. (prio and "!" or "")
end
function ClearOverrideBindings(owner) owned[owner] = nil end
local function overrideList()
    local out = {}
    for _, keys in pairs(owned) do
        for key, target in pairs(keys) do out[#out + 1] = key .. "=" .. target end
    end
    table.sort(out)
    return table.concat(out, " ")
end

local cvars = { GamePadStickAxisButtons = "0" }
C_CVar = { GetCVar = function(k) return cvars[k] end, SetCVar = function(k, v) cvars[k] = tostring(v) return true end }
local padState = { sticks = { { x = 0, y = 0, len = 0 }, { x = 0, y = 0, len = 0 } }, buttons = {} }
function GetGamePadState() return padState end
C_GamePad = {
    GetDeviceMappedState = function() return padState end,
    ButtonBindingToIndex = function(key) return ({ PADLTRIGGER = 6, PADRTRIGGER = 7 })[key] end,
    StickIndexToConfigName = function(i) return ({ [0] = "Left", [1] = "Right" })[i] end,
    GetConfig = function() return nil end, SetConfig = function() end, ApplyConfigs = function() end,
}
local gamepadUI = false
Enum = Enum or {}
Enum.InputDeviceInterfaceType = { KeyboardAndMouse = 0, Gamepad = 1 }
C_InputInterfaceStyle = { GetCurrentStyle = function() return gamepadUI and 1 or 0 end }
C_Texture = C_Texture or {}
local atlases = {}   -- none of the client's atlases unless a test adds them
C_Texture.GetAtlasInfo = function(name) return atlases[name] and {} or nil end
C_Texture.GetAtlasExists = nil
SOUNDKIT = SOUNDKIT or {}
PlaySound = PlaySound or function() end
strtrim = strtrim or function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
GetRealmName = GetRealmName or function() return "Doomhowl" end
C_Timer = C_Timer or {}
local timers = {}
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
C_Timer.NewTicker = function() return { Cancel = function() end } end
local function runTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end
C_AddOns.IsAddOnLoaded = function(name) return name == "Medalluin" end
GetNumMacros = GetNumMacros or function() return 0, 0 end
UIParent.GetCenter = function() return 960, 540 end
UnitGUID = UnitGUID or function(u) return u == "player" and "Player-1-00000001" or nil end

-- ------------------------------------------------------------ the restricted environment
local headerEnv, refs, wraps = {}, {}, {}
local secureBinds = {}            -- header -> key -> "frame:button"
local lib = {
    math = { atan2 = math.atan2, floor = math.floor, pi = math.pi, sqrt = math.sqrt, abs = math.abs },
    gmatch = string.gmatch, strlower = string.lower, format = string.format, tostring = tostring,
    tonumber = tonumber, type = type, next = next, select = select, print = print,
    newtable = function(...) return { ... } end,
    PlayerInCombat = function() return InCombatLockdown() end,
    GetGamePadState = function() return padState end,
}
local function envOf(header)
    headerEnv[header] = headerEnv[header] or setmetatable({}, { __index = lib })
    return headerEnv[header]
end
radialCursor = { 0.5, 0.5 }        -- the mouse over the screen, 0..1
local Handle
local function compile(header, args, body)
    local maker = assert(loadstring("return function(" .. args .. ")\n" .. body .. "\nend"))
    setfenv(maker, envOf(header))
    return maker()
end
local function runAttribute(header, name, ...)
    local body = header:GetAttribute(name)
    if not body then error("no attribute " .. name) end
    return compile(header, "self, ...", body)(Handle(header, header), ...)
end
function Handle(f, header)
    if f == nil then return nil end
    local h = { frame = f }
    function h:GetAttribute(k) return f:GetAttribute(k) end
    function h:SetAttribute(k, v) f:SetAttribute(k, v) end
    function h:Show() f:Show() end
    function h:Hide() f:Hide() end
    function h:IsShown() return f:IsShown() end
    function h:GetWidth() return 1000 end
    function h:GetHeight() return 800 end
    function h:GetMousePosition() return radialCursor[1], radialCursor[2] end
    function h:GetFrameRef(k) return Handle(refs[f] and refs[f][k], header) end
    function h:RunAttribute(name, ...) return runAttribute(f, name, ...) end
    function h:CallMethod(name, ...) return f[name](f, ...) end
    function h:EnableGamePadStick(on) f.padStick = on end
    function h:SetBindingClick(_, key, name, button)
        secureBinds[f] = secureBinds[f] or {}
        secureBinds[f][key] = name .. ":" .. tostring(button)
    end
    function h:ClearBindings() secureBinds[f] = nil end
    return h
end
function SecureHandlerSetFrameRef(header, name, frame)
    refs[header] = refs[header] or {}
    refs[header][name] = frame
end
function SecureHandlerExecute(header, body)
    return compile(header, "self", body)(Handle(header, header))
end
local snippets = {}   -- every body compiled once, for the syntax line
function SecureHandlerWrapScript(f, script, header, pre, post)
    wraps[f] = wraps[f] or {}
    wraps[f][script] = { header = header, pre = pre, post = post }
    snippets[#snippets + 1] = pre
    if post then snippets[#snippets + 1] = post end
end
local function secureKeys()
    local out = {}
    for _, keys in pairs(secureBinds) do
        for key, target in pairs(keys) do out[#out + 1] = key .. "=" .. target end
    end
    table.sort(out)
    return table.concat(out, " ")
end

-- A click through the wrap, as the game runs it: the pre body (false cancels),
-- then the button's action from its attributes, then the post body.
local ACTION_KEYS = { "type", "spell", "item", "macro", "macrotext", "unit", "marker", "action" }
local function click(f, button, down)
    local w = wraps[f] and wraps[f].OnClick
    if f.scripts.PreClick then f.scripts.PreClick(f, button, down) end
    local result, message
    if w then
        result, message = compile(w.header, "self, button, down, control", w.pre)(
            Handle(f, w.header), button, down, Handle(w.header, w.header))
        if result == false then
            if f.scripts.PostClick then f.scripts.PostClick(f, button, down) end
            return "cancelled"
        end
    end
    local parts = {}
    for _, key in ipairs(ACTION_KEYS) do
        local v = f:GetAttribute(key)
        if v ~= nil then parts[#parts + 1] = key .. "=" .. tostring(v) end
    end
    local did = #parts > 0 and table.concat(parts, " ") or "nothing"
    if w and w.post and message ~= nil then
        compile(w.header, "self, message, button, down, control", w.post)(
            Handle(f, w.header), message, button, down, Handle(w.header, w.header))
    end
    if f.scripts.PostClick then f.scripts.PostClick(f, button, down) end
    return did
end
local function wheelTurn(f, delta)
    local w = wraps[f] and wraps[f].OnMouseWheel
    compile(w.header, "self, offset, control", w.pre)(Handle(f, w.header), delta, Handle(w.header, w.header))
end

-- ------------------------------------------------------------ load + login
local ns = {}
for line in io.lines(ADDON .. "mdlui_RadialMenu.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(ADDON .. line:gsub("\\", "/")))
        chunk("mdlui_RadialMenu", ns)
    end
end
local function fire(e, ...)
    for _, f in ipairs(events[e] or {}) do
        if f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end
    end
end
fire("ADDON_LOADED", "mdlui_RadialMenu")
fire("PLAYER_LOGIN")
local RM = ns.RadialMenu
-- /mdlradial, its chat lines marked as the pass's
local function slash(message)
    local realPrint = print
    print = function(...) realPrint("radial /mdlradial " .. message, ...) end
    SlashCmdList.MDLUI_RADIAL(message)
    print = realPrint
end

-- every secure body compiles
local bad = 0
for _, body in ipairs(snippets) do
    if not loadstring("return function(self, button, down, control)\n" .. body .. "\nend") then bad = bad + 1 end
end
print("radial snippets", #snippets, "compile errors=" .. bad)
print("radial saved", "options=" .. tostring(type(mdlui_RadialMenuDB.options)),
    "activation=" .. tostring(mdlui_RadialMenuDB.options.activation),
    "autoRanks=" .. tostring(mdlui_RadialMenuDB.options.autoRanks),
    "labelFont=" .. tostring(mdlui_RadialMenuDB.options.labelFont.face))

-- ------------------------------------------------------------ first run
local order = RM:GetRadialOrder()
local first = order[1]
local data = RM:GetRadial(first)
local kinds = {}
for _, b in ipairs(data.buttons) do kinds[#kinds + 1] = b.kind .. ":" .. tostring(b.marker or b.id or b.which or "") end
print("radial first run", "radials=" .. #order, "name=" .. tostring(data.name), "buttons=" .. #data.buttons)
print("radial first run buttons", table.concat(kinds, " "))
print("radial macro", RM:GetMacroText(first))

local header = refs and (function()
    for h in pairs(refs) do return h end
end)()
print("radial header", header ~= nil, "count=" .. tostring(header and header:GetAttribute(first .. "-count")))

-- ------------------------------------------------------------ the secure copy
local function slotAttrs(id, slot, child)
    local prefix = id .. "-s" .. slot .. "-" .. (child or 1) .. "-"
    local parts = {}
    for _, key in ipairs(ACTION_KEYS) do
        local v = header:GetAttribute(prefix .. key)
        if v ~= nil then parts[#parts + 1] = key .. "=" .. tostring(v) end
    end
    return table.concat(parts, " ")
end
print("radial synced slot 1", slotAttrs(first, 1))
print("radial synced slot 9", slotAttrs(first, 9))
print("radial synced tag", "tag-markers=" .. tostring(header:GetAttribute("tag-markers")),
    "assigned=" .. tostring(header:GetAttribute("flare-assigned")))

-- ------------------------------------------------------------ a key, held
local caster, catcher = _G.mdluiRadialCaster, _G.mdluiRadialCatcher
local wheel, macro = _G.mdluiRadialWheel, _G.MdlRadial
local function state(label)
    local env = headerEnv[header]
    print("radial " .. label, "mode=" .. tostring(env.MODE), "active=" .. tostring(env.ACTIVE),
        "wheel=" .. tostring(wheel:IsShown()), "catcher=" .. tostring(catcher:IsShown()),
        "secure keys=" .. secureKeys())
end
print("radial keys before", "overrides=" .. overrideList())
slash("key markers shift-q")
print("radial keys", "overrides=" .. overrideList(), "holdkeys=" .. tostring(header:GetAttribute(first .. "-holdkeys")))

-- the cursor at the screen's middle: slot one is straight up, then clockwise
radialCursor = { 0.5, 0.5 }
print("radial hold press", click(caster, first, true))
state("held")
radialCursor = { 0.5, 0.7 }      -- up
print("radial hold release up", click(caster, first, false))
state("released")
local aims = { { "up", 0.5, 0.7 }, { "right", 0.7, 0.5 }, { "down", 0.5, 0.3 }, { "left", 0.3, 0.5 },
               { "dead zone", 0.51, 0.51 } }
for _, aim in ipairs(aims) do
    radialCursor = { 0.5, 0.5 }
    click(caster, first, true)
    radialCursor = { aim[2], aim[3] }
    local slot = headerEnv[header].ACTIVE and runAttribute(header, "flare-select")
    print("radial aim " .. aim[1], "slot=" .. tostring(slot), click(caster, first, false))
end
-- right-click while held cancels; the key's release then does nothing
radialCursor = { 0.5, 0.5 }
click(caster, first, true)
radialCursor = { 0.5, 0.7 }
print("radial hold right-click", click(catcher, "RightButton", false))
print("radial hold release after cancel", click(caster, first, false))
state("cancelled")

-- ------------------------------------------------------------ click mode, by macro
radialCursor = { 0.5, 0.5 }
print("radial macro open", click(macro, "markers", false))
state("macro opened")
radialCursor = { 0.7, 0.5 }
print("radial macro left-click right", click(catcher, "LeftButton", false))
state("macro used")
click(macro, "MARKERS", false)
print("radial macro again closes", click(macro, "markers", false))
state("macro closed")
print("radial macro unknown", click(macro, "nosuch", false))
click(macro, "markers", false)
print("radial macro escape", click(catcher, "Escape", false))
state("escaped")

-- ------------------------------------------------------------ a sub-radial on the wheel
local emotes = RM:CreateRadial("Emotes")
RM:GetRadial(emotes).buttons = { { kind = "emote", emote = "WAVE" }, { kind = "emote", emote = "CHEER" },
    { kind = "emote", emote = "BOW" } }
table.insert(RM:GetRadial(first).buttons, 1, { kind = "subradial", radial = emotes })
RM:RadialChanged(first)
runTimers()
print("radial sub synced", "count=" .. tostring(header:GetAttribute(first .. "-count")),
    "n=" .. tostring(header:GetAttribute(first .. "-s1-n")), "sub=" .. tostring(header:GetAttribute(first .. "-s1-sub")),
    "child 2: " .. slotAttrs(first, 1, 2))
radialCursor = { 0.5, 0.5 }
click(caster, first, true)
radialCursor = { 0.5, 0.7 }
wheelTurn(wheel, -1)
wheelTurn(wheel, -1)
print("radial wheel twice down, release", click(caster, first, false))
radialCursor = { 0.5, 0.5 }
click(caster, first, true)
radialCursor = { 0.5, 0.7 }
print("radial wheel reset on open, release", click(caster, first, false))
-- click mode: middle-click opens the sub-radial in place, right-click goes back
radialCursor = { 0.5, 0.5 }
click(macro, "markers", false)
radialCursor = { 0.5, 0.7 }
click(catcher, "MiddleButton", false)
state("nested")
click(catcher, "RightButton", false)
state("back")
click(catcher, "RightButton", false)
state("right-click closes")

-- ------------------------------------------------------------ combat
setCombat(true)
slash("key 1 F")
RM:SetRadialKey(emotes, "G")
print("radial key in combat", "overrides=" .. overrideList(), "pending=" .. tostring(RM.bindingPending))
setCombat(false)
fire("PLAYER_REGEN_ENABLED")
print("radial key after combat", "overrides=" .. overrideList(), "pending=" .. tostring(RM.bindingPending))
-- two radials on one key: the first in the list wins it
RM:SetRadialKey(emotes, "SHIFT-Q")
print("radial shared key", "overrides=" .. overrideList())
RM:SetRadialKey(emotes, nil)
slash("list")
print("radial hold variants", RM.HoldVariants("SHIFT-Q", {}), "|", RM.HoldVariants("Q", { ["SHIFT-Q"] = true }))

-- ------------------------------------------------------------ the controller
gamepadUI = true
RM:SetPadKey(first, "PADCOMBO-L3")
print("radial pad bound", "overrides=" .. overrideList(),
    "L3=" .. tostring(header:GetAttribute("flare-pad-L3-TOP")), "release=" .. tostring(header:GetAttribute("flare-padrelease")))
local pad, aim = _G.mdluiRadialPad, _G.mdluiRadialAim
print("radial pad open", click(pad, "PadL3", false), "stick keys=" .. cvars.GamePadStickAxisButtons)
state("pad opened")
padState.sticks[2] = { x = 1, y = 0, len = 1 }       -- right
click(aim, "AimRight", true)
print("radial pad sticky", tostring(headerEnv[header].STICKY))
padState.sticks[2] = { x = 0, y = 0, len = 0 }       -- let go
print("radial pad release", click(aim, "AimRight", false), "stick keys=" .. cvars.GamePadStickAxisButtons)
state("pad closed")
click(pad, "PadL3", false)
print("radial pad B", click(pad, "RightButton", false))
state("pad B")
-- LT held with L3: a radial on that combo instead
RM:SetPadKey(emotes, "PADCOMBO-LT-L3")
padState.buttons = { [7] = true }
print("radial pad LT+L3", click(pad, "PadL3", false), "active=" .. tostring(headerEnv[header].ACTIVE == emotes))
click(pad, "RightButton", false)
padState.buttons = {}
-- another controller addon: no controller key is bound
C_AddOns.IsAddOnLoaded = function(name) return name == "ConsolePort" end
RM:ApplyBindings()
print("radial pad with ConsolePort", "overrides=" .. overrideList())
C_AddOns.IsAddOnLoaded = function(name) return name == "Medalluin" end
gamepadUI = false
RM:ApplyBindings()
print("radial pad off", "overrides=" .. overrideList())

-- ------------------------------------------------------------ fonts, and FlareUI beside it
local button = RM.fontButtons and next(RM.fontButtons)
local font = button and button.Label and button.Label.font
print("radial label font", font and table.concat({ tostring(font[1]), tostring(font[2]), tostring(font[3]) }, " ") or "-")
print("radial FlareUI radial on", tostring(ns.FlareRadialOn()))
C_AddOns.IsAddOnLoaded = function(name) return name == "FlareUI" end
FlareUI2_DB = { profileKeys = { ["Ahrymx - Doomhowl"] = "Main" }, profiles = { Main = { radialmenu = { enabled = true } } } }
print("radial FlareUI radial on, FlareUI loaded", tostring(ns.FlareRadialOn()))
FlareUI2_DB.profiles.Main.radialmenu.enabled = false
print("radial FlareUI radial off", tostring(ns.FlareRadialOn()))
FlareUI2_DB = nil
C_AddOns.IsAddOnLoaded = function(name) return name == "Medalluin" end

-- ------------------------------------------------------------ a character's own key
RM:SetOwnKey(first, true)
RM:SetRadialKey(first, "Z")
local mine = mdlui_RadialMenuDB.global.characters and mdlui_RadialMenuDB.global.characters["Player-1-00000001"]
print("radial own key", "key=" .. tostring((RM:GetRadialKey(first))), "shared=" .. tostring(RM:GetSharedKey(first)),
    "saved=" .. tostring(mine and mine.radialKeyOverride and mine.radialKeyOverride[first]),
    "overrides=" .. overrideList())
slash("list")
RM:SetOwnKey(first, false)
slash("key emotes none")
slash("key 7 X")
slash("key")
RM:SetRadialKey(emotes, "V")
slash("key Emotes none")
print("radial own key off", "key=" .. tostring((RM:GetRadialKey(first))), "overrides=" .. overrideList())

-- ------------------------------------------------------------ a spell: its rank and its cooldown
-- Lightning Bolt, ranks 1 to 3 in the book; rank 3 on cooldown
local book = { { 403, "Rank 1" }, { 529, "Rank 2" }, { 548, "Rank 3" } }
C_SpellBook = C_SpellBook or {}
C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #book } end
C_SpellBook.GetSpellBookItemInfo = function(i) return book[i] and { spellID = book[i][1] } end
C_SpellBook.IsSpellKnown = function(id) for _, b in ipairs(book) do if b[1] == id then return true end end return false end
C_SpellBook.IsSpellKnownOrInSpellBook = nil
Enum.SpellBookSpellBank = Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
local function inBook(id) for _, b in ipairs(book) do if b[1] == id then return b end end end
C_Spell.GetSpellInfo = function(id) return inBook(id) and { name = "Lightning Bolt", iconID = 136048 } end
C_Spell.GetSpellName = function(id) return inBook(id) and "Lightning Bolt" end
C_Spell.GetSpellSubtext = function(id) return inBook(id) and inBook(id)[2] end
C_Spell.GetSpellCooldown = function(id)
    if id == 548 then return { startTime = 100, duration = 8, isEnabled = true } end
    return { startTime = 0, duration = 0, isEnabled = true }
end
C_Spell.GetSpellCooldownDuration = nil
C_Spell.IsSpellUsable = function() return true, false end
C_Spell.IsSpellInRange = function() return nil end
C_Spell.GetSpellCharges = nil
local cooldowns = {}
getmetatable(UIParent).SetCooldown = function(self, start, duration)
    self.start, self.duration = start, duration
    cooldowns[#cooldowns + 1] = start .. "+" .. duration
end
RM.ForgetRanks()
local buttons = RM:GetRadial(first).buttons
buttons[2] = { kind = "spell", id = 403, rankChecked = true }   -- saved before ranks were followed
RM:RadialChanged(first)
runTimers()
print("radial spell follows rank", slotAttrs(first, 2), "cooldowns=" .. table.concat(cooldowns, ","))
mdlui_RadialMenuDB.options.autoRanks = false
RM:RadialChanged(first)
print("radial spell rank kept, autoRanks off", slotAttrs(first, 2))
mdlui_RadialMenuDB.options.autoRanks = true
buttons[2] = { kind = "spell", id = 403 }                       -- put on at rank 1 now: pinned
RM:RadialChanged(first)
print("radial spell put on at rank 1", slotAttrs(first, 2), "pinned=" .. tostring(buttons[2].pinned))

-- ------------------------------------------------------------ the dialog: a Custom Emote asks for its command
local dialog = function() return _G.mdluiRadialDialog end
local emoteButtons = RM:GetRadial(emotes).buttons
emoteButtons[#emoteButtons + 1] = { kind = "emote", emote = "CUSTOM" }
RM:RadialChanged(emotes)
runTimers()
local d = dialog()
print("radial dialog asks", d and tostring(d:IsShown()), d and d.Text.text, d and d.EditBox.text,
    d and d.Button1.text, d and d.Button2.text)
d.EditBox.text = "/oom"
d.Button1.scripts.OnClick(d.Button1)
click(macro, "emotes", false)       -- the next open writes the secure copy
print("radial dialog yes", "shown=" .. tostring(d:IsShown()), "command=" .. tostring(emoteButtons[#emoteButtons].command),
    "slot 4: " .. slotAttrs(emotes, 4))
click(catcher, "RightButton", false)
emoteButtons[#emoteButtons + 1] = { kind = "emote", emote = "CUSTOM" }
RM:RadialChanged(emotes)
runTimers()
d.EditBox.text = "oom"
d.Button1.scripts.OnClick(d.Button1)
print("radial dialog no slash", "buttons=" .. #emoteButtons)
emoteButtons[#emoteButtons + 1] = { kind = "emote", emote = "CUSTOM" }
RM:RadialChanged(emotes)
runTimers()
d.scripts.OnKeyDown(d, "ESCAPE")
print("radial dialog escape", "shown=" .. tostring(d:IsShown()), "buttons=" .. #emoteButtons)

-- ------------------------------------------------------------ the editor window (UI/Window.lua)
-- What the window's controls read of the client, stubbed only from here on, so the lines above
-- stay as they were: a button's font string, a dropdown's menu, the globals the editor uses.
local Region = getmetatable(CreateFrame("Frame"))
tinsert = tinsert or table.insert
local setText = Region.SetText
function Region:SetText(t)
    setText(self, t)
    if rawget(self, "fs_") then self.fs_.text = t end
end
function Region:GetFontString()
    if self.kind ~= "Button" and self.kind ~= "CheckButton" then return nil end
    if not rawget(self, "fs_") then
        self.fs_ = self:CreateFontString()
        self.fs_.text = self.text
    end
    return self.fs_
end
function Region:SetupMenu(fn) self.menuFn = fn end
function Region:GenerateMenu() end
function Region:SetDefaultText(t) self.defaultText = t end
function Region:SetChecked(on) self.checked = on and true or false end
function Region:GetChecked() return self.checked end
-- a menu's entries as text: "(x) " marks the chosen radio
local function menuOf(drop)
    local out = {}
    local root = {}
    function root:CreateRadio(text, isSelected, pick)
        out[#out + 1] = { text = text, on = isSelected(), pick = pick }
    end
    function root:CreateButton(text, pick) out[#out + 1] = { text = text, pick = pick } end
    function root:CreateTitle() end
    function root:CreateDivider() end
    drop.menuFn(drop, root)
    return out
end
local function menuText(entries)
    local parts = {}
    for _, e in ipairs(entries) do parts[#parts + 1] = (e.on and "(x) " or "") .. tostring(e.text) end
    return table.concat(parts, " | ")
end
CopyTable = CopyTable or function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and CopyTable(v) or v end
    return out
end
local getText = Region.GetText
function Region:GetText()
    local text = getText(self)
    if text == nil and self.kind == "EditBox" then return "" end
    return text
end
function Region:HookScript(k, fn)
    local old = self.scripts[k]
    self.scripts[k] = old and function(...) old(...) fn(...) end or fn
end
function Region:SetEnabled(on) self.enabled = on and true or false end
function Region:IsEnabled() return self.enabled ~= false end
C_Item.GetItemCount = C_Item.GetItemCount or function() return 0 end
UnitFactionGroup = UnitFactionGroup or function() return "Alliance", "Alliance" end
-- ---- the window opens on a radial's Wheel sheet, laid out as Medalluin's Settings window
setCombat(false)
slash("")
local win = _G.mdluiRadialEditor
local host = win
local function plain(t) return ((t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- the page shown, and on a radial's page its sheet ("radial/wheel", "options")
local function shownTabs()
    local on = {}
    for k, b in pairs(win.tabs) do if b:IsShown() and b.foot:IsShown() then on[#on + 1] = k end end
    table.sort(on)
    return win.page .. (#on > 0 and ("/" .. table.concat(on, ",")) or "")
end
local function isIn(list, name) for _, v in ipairs(list) do if v == name then return true end end return false end
print("radial editor opens", "shown=" .. tostring(win:IsShown()), "strata=" .. tostring(win.strata or win:GetFrameStrata()),
    "escape=" .. tostring(isIn(UISpecialFrames, "mdluiRadialEditor")), "tab=" .. shownTabs(),
    "wheel=" .. tostring(win.sheets.wheel:IsShown()), "options=" .. tostring(win.options:IsShown()))
local function texts(list, field)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = tostring(field and r[field] or r.text) end
    return table.concat(out, ",")
end
print("radial editor window", "size=" .. win.w .. "x" .. win.h, "title=" .. tostring(win.title.text),
    "subtitle=" .. tostring(win.subtitle.text), "tabs=" .. tostring(win.tabs.wheel.text) .. "," .. tostring(win.tabs.radial.text),
    "search=" .. tostring(win.sideSearch.hint.text), "rows=" .. #host.radialList.cells,
    "cards=" .. tostring(host.wheelCard.title.text) .. "," .. tostring(host.slotCard.title.text) .. "," .. tostring(host.catalogCard.title.text),
    "show=" .. texts(win.chips, "key"))
print("radial editor footer", "new=" .. tostring(win.newButton.text) .. ":" .. win.newButton.style,
    "import=" .. tostring(win.importButton:IsShown()), "undo=" .. tostring(win.undoButton.text),
    "close=" .. tostring(win.closeButton.text) .. ":" .. win.closeButton.style, "changed=" .. tostring(win.changed:IsShown()))
-- the sidebar: [a heading], <a group>, -a radial in a group, a radial=its key, *Every radial
local function listNames()
    local out = {}
    for _, item in ipairs(host.radialList.data) do
        local data = item.id and RM:GetRadial(item.id)
        out[#out + 1] = item.head and ("[" .. item.head .. (item.count and not item.open and (" " .. item.count) or "") .. "]")
            or item.group and ("<" .. item.group .. ">") or item.options and "*Every radial"
            or ((item.member and "-" or "") .. (data and data.name or "?") .. (item.key and ("=" .. item.key) or ""))
    end
    return table.concat(out, ", ")
end
local function lit()
    for _, c in ipairs(host.radialList.cells) do
        if c.item and c.Bar:IsShown() then return tostring(c.Text.text) end
    end
    return "none"
end
local function buttonsOf(id)
    local out = {}
    for _, b in ipairs(RM:GetRadial(id).buttons) do out[#out + 1] = b.kind .. ":" .. tostring(b.marker or b.id or b.emote or b.radial or b.panel or "") end
    return table.concat(out, " ")
end
-- the canvas's slots: how many it drew, "+" for the empty one; the chosen one, lit as in play
local function slotsOf()
    local c = host.canvas
    local n, empty = 0, false
    for i = 1, c.drawn or 0 do
        if c.hits[i].ghost then empty = true else n = n + 1 end
    end
    local _, chosen = ns.RadialEditorEmbed.Chosen()
    return n .. (empty and "+" or "") .. " chosen=" .. tostring(chosen)
        .. " lit=" .. tostring(chosen and c.wheel.buttons[chosen].lit or false)
end
print("radial editor list", listNames(), "lit=" .. lit())
print("radial editor selected", "name=" .. tostring(host.nameText.text), "key=" .. tostring(host.keyButton.text),
    "slots=" .. slotsOf(), "undo=" .. tostring(host.undoButton.enabled))
print("radial editor overview", plain(host.overview.text))
print("radial editor canvas", "crumb=" .. plain(win.crumb.text), "chip=" .. tostring(host.keyChip.text.text),
    "count=" .. tostring(host.countText.text), "hint=" .. tostring(host.canvas.hint.text))
print("radial editor slot card", "empty=" .. tostring(host.slotEmpty:IsShown()) .. ":" .. tostring(host.slotEmpty.text),
    "slot=" .. tostring(host.slot:IsShown()), "remove=" .. tostring(host.removeButton:IsShown()))

-- ---- the Catalog: its categories (a menu), the markers' grid, a click puts one on the radial
print("radial editor catalog", "categories=" .. menuText(menuOf(host.catDrop)), "grid=" .. #host.browseList.data,
    "count=" .. tostring(host.catCount.text))
local function category(label)
    for _, e in ipairs(menuOf(host.catDrop)) do if e.text == label then e.pick() end end
end
category("Markers")
print("radial editor markers", "shown=" .. tostring(host.catDrop.value.text), "grid=" .. #host.browseList.data,
    "count=" .. tostring(host.catCount.text),
    "first=" .. host.browseList.data[1].kind .. ":" .. host.browseList.data[1].marker,
    "last=" .. host.browseList.data[#host.browseList.data].kind .. ":" .. host.browseList.data[#host.browseList.data].marker)
local editing = RM:GetRadialOrder()[1]
local before = #RM:GetRadial(editing).buttons
local cell = host.browseList.cells[10]   -- clear (marker 0)
cell.scripts.OnClick(cell, "LeftButton")
print("radial editor add", "buttons " .. before .. "->" .. #RM:GetRadial(editing).buttons,
    "last=" .. RM:GetRadial(editing).buttons[#RM:GetRadial(editing).buttons].kind .. ":" .. RM:GetRadial(editing).buttons[#RM:GetRadial(editing).buttons].marker,
    "undo=" .. tostring(host.undoButton.enabled), "changed=" .. tostring(win.changed:IsShown()), "slots=" .. slotsOf(),
    "count=" .. tostring(host.countText.text))
local hits = host.canvas.hits
hits[1].scripts.OnClick(hits[1], "RightButton")
print("radial editor remove", "buttons=" .. #RM:GetRadial(editing).buttons, "first=" .. buttonsOf(editing):match("^%S+"))
host.undoButton.scripts.OnClick(host.undoButton)
print("radial editor undo", "buttons=" .. #RM:GetRadial(editing).buttons, "first=" .. buttonsOf(editing):match("^%S+"),
    "undo=" .. tostring(host.undoButton.enabled), "changed=" .. tostring(win.changed:IsShown()))
host.search.text = "marker 8"   -- (the harness's marker names)
host.search.scripts.OnTextChanged(host.search)
print("radial editor search", "grid=" .. #host.browseList.data, "count=" .. tostring(host.catCount.text),
    "hint=" .. tostring(host.search.hint:IsShown()))
host.search.text = ""
host.search.scripts.OnTextChanged(host.search)

-- ---- the canvas: a slot chosen (its card), moved a step, dragged onto another; a Catalog entry
-- dropped on a slot; a slot dragged off; Show
hits[2].scripts.OnClick(hits[2], "LeftButton")
local cw = host.canvas.wheel
print("radial editor slot", "tab=" .. tostring(shownTabs()), "slots=" .. slotsOf(), "name=" .. tostring(host.slotName.text),
    "kind=" .. tostring(host.slotKind.text), "chip=" .. tostring(host.slotChip.text.text), "place=" .. tostring(host.slotPlace.value.text),
    "rank=" .. tostring(host.rankRow:GetAlpha()) .. ":" .. tostring(host.rankRow.line.text),
    "rims=" .. tostring(cw.buttons[2].RimArt.texture):match("([^\\]+)$")
    .. "," .. tostring(cw.buttons[1].RimArt.texture):match("([^\\]+)$"), "pointer=" .. tostring(cw.Pointer:IsShown()),
    "label=" .. table.concat(cw.buttons[2].Label.textColor, ","))
hits[1].scripts.OnClick(hits[1], "LeftButton")
print("radial editor slot unranked", "kind=" .. tostring(host.slotKind.text), "rank=" .. tostring(host.rankRow:GetAlpha())
    .. ":" .. tostring(host.rankRow.line.text), "seg=" .. tostring(host.rankSeg.buttons[1].enabled))
hits[2].scripts.OnClick(hits[2], "LeftButton")
local order0 = buttonsOf(editing)
host.slotPlace.plus.scripts.OnClick(host.slotPlace.plus)
print("radial editor slot move", "slots=" .. slotsOf(), "place=" .. tostring(host.slotPlace.value.text),
    "moved=" .. tostring(buttonsOf(editing) ~= order0), "second=" .. (select(2, buttonsOf(editing):match("^(%S+) (%S+)"))))
host.slotPlace.minus.scripts.OnClick(host.slotPlace.minus)
hits[1].scripts.OnClick(hits[1], "LeftButton")
print("radial editor slot back", "same=" .. tostring(buttonsOf(editing) == order0), "first minus=" .. tostring(host.slotPlace.minus.enabled),
    "plus=" .. tostring(host.slotPlace.plus.enabled))
local function first(n)
    local out, i = {}, 0
    for word in buttonsOf(editing):gmatch("%S+") do
        i = i + 1
        if i > n then break end
        out[i] = word
    end
    return table.concat(out, " ")
end
local was = first(3)
hits[3].scripts.OnDragStart(hits[3])
H.pointAt(hits[1])
hits[3].scripts.OnDragStop(hits[3])
H.pointAt(nil)
print("radial editor drag", "before=" .. was, "after=" .. first(3), "slots=" .. slotsOf())
host.undoButton.scripts.OnClick(host.undoButton)
category("Emotes")
local emoteCell = host.browseList.cells[1]
local count0 = #RM:GetRadial(editing).buttons
emoteCell.scripts.OnDragStart(emoteCell)
H.pointAt(hits[2])
emoteCell.scripts.OnDragStop(emoteCell)
H.pointAt(nil)
print("radial editor catalog drop", "buttons " .. count0 .. "->" .. #RM:GetRadial(editing).buttons,
    "second=" .. (select(2, buttonsOf(editing):match("^(%S+) (%S+)"))), "slots=" .. slotsOf())
local count1 = #RM:GetRadial(editing).buttons
hits[2].scripts.OnDragStart(hits[2])
hits[2].scripts.OnDragStop(hits[2])   -- (the pointer over nothing: off the canvas)
print("radial editor drag off", "buttons " .. count1 .. "->" .. #RM:GetRadial(editing).buttons)
host.undoButton.scripts.OnClick(host.undoButton)
category("Markers")
-- the empty slot: clicked, the Catalog's search takes the keyboard
local ghostHit
for i = 1, host.canvas.drawn do if hits[i].ghost then ghostHit = hits[i] end end
local focused = false
host.search.SetFocus = function() focused = true end
ghostHit.scripts.OnClick(ghostHit, "LeftButton")
print("radial editor empty slot", "focus=" .. tostring(focused), "index=" .. tostring(ghostHit.index))
local function chip(key)
    for _, c in ipairs(win.chips) do if c.key == key then c.scripts.OnClick(c) end end
end
local function labelsShown()
    local n = 0
    for i = 1, host.canvas.drawn do if host.canvas.wheel.buttons[i].Label:IsShown() then n = n + 1 end end
    return n
end
local function badgesShown()
    local n = 0
    for i = 1, host.canvas.drawn do if hits[i].badge:IsShown() then n = n + 1 end end
    return n
end
local namesOn = labelsShown()
chip("names")
local namesOff = labelsShown()
chip("names")
chip("numbers")
local badges = badgesShown()
chip("numbers")
chip("empty")
local noGhost = slotsOf()
chip("empty")
print("radial editor chips", "names " .. namesOn .. "->" .. namesOff, "numbers=" .. badges .. "/" .. badgesShown(),
    "empty off=" .. noGhost, "on=" .. slotsOf())
-- a Catalog click goes in after the chosen slot
hits[2].scripts.OnClick(hits[2], "LeftButton")
local count2 = #RM:GetRadial(editing).buttons
host.browseList.cells[3].scripts.OnClick(host.browseList.cells[3], "LeftButton")
print("radial editor catalog after", "buttons " .. count2 .. "->" .. #RM:GetRadial(editing).buttons,
    "third=" .. (select(3, buttonsOf(editing):match("^(%S+) (%S+) (%S+)"))), "slots=" .. slotsOf())
host.undoButton.scripts.OnClick(host.undoButton)

-- ---- the Radial sheet: who gets it, its key, Macro / Copy / Rename / Delete, the keys here
win.tabs.radial.scripts.OnClick(win.tabs.radial)
print("radial editor radial sheet", "tab=" .. shownTabs(), "wheel=" .. tostring(win.sheets.wheel:IsShown()),
    "radial=" .. tostring(win.sheets.radial:IsShown()), "show=" .. tostring(win.showSeg:IsShown()),
    "scope=" .. tostring(host.scopeDrop.value.text), "own=" .. tostring(host.ownKey.checked),
    "name=" .. tostring(host.nameLine.text), "delete=" .. host.deleteButton.style)
win.tabs.wheel.scripts.OnClick(win.tabs.wheel)

-- ---- a new radial, named in the popup; renamed; copied; deleted
host.newButton.scripts.OnClick(host.newButton)
local popup = _G.mdluiRadialNewRadial
print("radial editor new popup", "shown=" .. tostring(popup:IsShown()), "text=" .. tostring(popup.box.text),
    "scope=" .. menuText(menuOf(popup.scopeDrop)))
popup.box.text = "Heals"
popup.accept.scripts.OnClick(popup.accept)
local count = #RM:GetRadialOrder()
local heals = RM:GetRadialOrder()[count]
print("radial editor new", "popup=" .. tostring(popup:IsShown()), "radials=" .. count, "name=" .. tostring(host.nameText.text),
    "selected=" .. tostring(heals), "slots=" .. slotsOf(), "hint=" .. tostring(host.canvas.hint.text))
chip("empty")
print("radial editor new, empty slot off", "slots=" .. slotsOf())
chip("empty")
host.renameButton.scripts.OnClick(host.renameButton)
print("radial editor rename popup", "text=" .. tostring(popup.box.text), "accept=" .. tostring(popup.accept.text),
    "scope shown=" .. tostring(popup.scopeDrop:IsShown()))
popup.box.text = "Healing"
popup.box.scripts.OnEnterPressed(popup.box)
print("radial editor rename", "name=" .. tostring(RM:GetRadial(heals).name), "list=" .. listNames())
host.copyButton.scripts.OnClick(host.copyButton)
print("radial editor copy", "radials=" .. #RM:GetRadialOrder(), "name=" .. tostring(host.nameText.text))
host.deleteButton.scripts.OnClick(host.deleteButton)
local d2 = _G.mdluiRadialDialog
print("radial editor delete asks", "shown=" .. tostring(d2:IsShown()), d2.Text.text)
d2.Button1.scripts.OnClick(d2.Button1)
print("radial editor delete", "radials=" .. #RM:GetRadialOrder(), "list=" .. listNames(), "name=" .. tostring(host.nameText.text))
for _, c in ipairs(host.radialList.cells) do
    if c.item and c.item.id == heals then c.scripts.OnClick(c, "LeftButton") end
end
print("radial editor select", "name=" .. tostring(host.nameText.text), "key=" .. tostring(host.keyButton.text))

-- ---- who gets it: the menu, a pick
local scopes = menuOf(host.scopeDrop)
print("radial editor scope menu", menuText(scopes))
scopes[#scopes].pick()
print("radial editor scope", "scope=" .. tostring(RM:GetRadial(heals) and RM:GetRadial(heals).scope))

-- ---- its key: click, press; a game key asks first; right-click clears; this character's own
local kb = host.keyButton
kb.scripts.OnClick(kb, "LeftButton")
print("radial editor key listens", "text=" .. tostring(kb.text), "waiting=" .. tostring(kb.waiting))
kb.scripts.OnKeyDown(kb, "LSHIFT")
kb.scripts.OnKeyDown(kb, "T")
print("radial editor key", "key=" .. tostring(RM:GetRadialKey(heals)), "button=" .. tostring(kb.text), "overrides=" .. overrideList())
kb.scripts.OnClick(kb, "LeftButton")
kb.scripts.OnKeyDown(kb, "1")
print("radial editor key taken asks", "shown=" .. tostring(d2:IsShown()), d2.Text.text, "key=" .. tostring(RM:GetRadialKey(heals)))
d2.Button2.scripts.OnClick(d2.Button2)
print("radial editor key taken no", "key=" .. tostring(RM:GetRadialKey(heals)))
kb.scripts.OnClick(kb, "LeftButton")
kb.scripts.OnKeyDown(kb, "ESCAPE")
print("radial editor key escape", "waiting=" .. tostring(kb.waiting), "key=" .. tostring(RM:GetRadialKey(heals)))
host.ownKey.checked = true
host.ownKey.scripts.OnClick(host.ownKey)
local _, own = RM:GetRadialKey(heals)
print("radial editor own key", "key=" .. tostring(RM:GetRadialKey(heals)), "own=" .. tostring(own),
    "shared=" .. tostring(RM:GetRadial(heals).key), "checked=" .. tostring(host.ownKey.checked))
host.ownKey.checked = false
host.ownKey.scripts.OnClick(host.ownKey)
kb.scripts.OnClick(kb, "RightButton")
print("radial editor key cleared", "key=" .. tostring(RM:GetRadialKey(heals)), "overrides=" .. overrideList())

-- ---- the window moved: where it was left is kept for the next session
harnessDropAt = { "TOPLEFT", "TOPLEFT", 120.4, -80.6 }
win.scripts.OnDragStart(win)
win.scripts.OnDragStop(win)
harnessDropAt = nil
local at = ns.db.global.editorPoint
print("radial editor moved", "saved=" .. (at and table.concat({ tostring(at[1]), tostring(at[2]), tostring(at[3]), tostring(at[4]) }, ",") or "nil"),
    "moving=" .. tostring(win.isMoving))

-- ---- a hovered control explains itself
local tipLines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(_, text) tipLines[#tipLines + 1] = text end
host.newButton.scripts.OnEnter(host.newButton)
GameTooltip.AddLine = addLine
print("radial editor hover", "owner=" .. tostring(GameTooltip.owner == host.newButton), table.concat(tipLines, " / "))

-- ---- a group in the sidebar: its heading, its radials on an elbow under it; folded, its count
local emotes = RM:GetRadialOrder()[2]
local social = RM:CreateGroupWith(emotes, "Social")
local function cellOf(test)
    for _, c in ipairs(host.radialList.cells) do if c.item and test(c.item) then return c end end
end
local emoteCell = cellOf(function(item) return item.id == emotes end)
emoteCell.scripts.OnClick(emoteCell, "LeftButton")
local head = cellOf(function(item) return item.group == social end)
emoteCell = cellOf(function(item) return item.id == emotes end)
print("radial editor group", listNames(), "head=" .. tostring(head.Head.text), "elbow=" .. tostring(emoteCell.Elbow[1]:IsShown()),
    "crumb=" .. plain(win.crumb.text))
head.scripts.OnClick(head, "LeftButton")
head = cellOf(function(item) return item.group == social end)
print("radial editor group folded", listNames(), "pill=" .. tostring(head.Pill:IsShown()) .. ":" .. tostring(head.Pill.text.text))
head.scripts.OnClick(head, "LeftButton")
RM:Ungroup(social)
local markersCell = cellOf(function(item) return item.id == RM:GetRadialOrder()[1] end)
markersCell.scripts.OnClick(markersCell, "LeftButton")

-- ---- Every radial (the sidebar's Options): its cards, its rows (each one's text in its tooltip)
host.sideSearch.text = "emo"
host.sideSearch.scripts.OnTextChanged(host.sideSearch)
print("radial editor sidebar search", listNames())
host.sideSearch.text = ""
host.sideSearch.scripts.OnTextChanged(host.sideSearch)
for _, c in ipairs(host.radialList.cells) do
    if c.item and c.item.options then c.scripts.OnClick(c, "LeftButton") end
end
local opt = win.look
local function rowOf(key) return win.lookRows[key] end
print("radial options tab", "tab=" .. shownTabs(), "look=" .. tostring(opt:IsShown()), "wheel=" .. tostring(win.sheets.wheel:IsShown()),
    "title=" .. tostring(win.pageTitle.text), "crumb=" .. tostring(win.crumb.text), "lit=" .. lit())
local pos = rowOf("rm.position")
local function picked(r)
    local out = {}
    for i, b in ipairs(r.buttons) do if b.mark.shown then out[#out + 1] = i .. ":" .. tostring(b.text) end end
    return table.concat(out, ",")
end
print("radial options choices", "position=" .. picked(pos), "activation=" .. picked(rowOf("rm.activation")),
    "subRadials=" .. picked(rowOf("rm.subRadials")))
pos.buttons[2].scripts.OnClick(pos.buttons[2])
print("radial options position", "saved=" .. tostring(mdlui_RadialMenuDB.options.position), "picked=" .. picked(pos),
    "center=" .. tostring(header:GetAttribute("flare-center")))
pos.buttons[1].scripts.OnClick(pos.buttons[1])
local sub = rowOf("rm.subRadials")
sub.buttons[2].scripts.OnClick(sub.buttons[2])
print("radial options sub-radials", "saved=" .. tostring(mdlui_RadialMenuDB.options.subRadials),
    "reset=" .. tostring(header:GetAttribute("flare-subreset")))
local scale = rowOf("rm.scale")
print("radial options scale", "text=" .. tostring(scale.value.text), "minus=" .. tostring(scale.minus.enabled))
scale.plus.scripts.OnClick(scale.plus)
scale.plus.scripts.OnClick(scale.plus)
print("radial options scale up", "saved=" .. tostring(mdlui_RadialMenuDB.options.scale), "text=" .. tostring(scale.value.text))
for _ = 1, 12 do scale.minus.scripts.OnClick(scale.minus) end
print("radial options scale floor", "saved=" .. tostring(mdlui_RadialMenuDB.options.scale), "text=" .. tostring(scale.value.text),
    "minus=" .. tostring(scale.minus.enabled))
mdlui_RadialMenuDB.options.scale = 1
local names = rowOf("rm.names")
print("radial options names", "checked=" .. tostring(names.check.checked))
names.check.checked = false
names.check.scripts.OnClick(names.check)
print("radial options names off", "saved=" .. tostring(mdlui_RadialMenuDB.options.showNames))
names.check.checked = true
names.check.scripts.OnClick(names.check)
local ranks = rowOf("rm.autoRanks")
ranks.check.checked = false
ranks.check.scripts.OnClick(ranks.check)
print("radial options ranks off", "saved=" .. tostring(mdlui_RadialMenuDB.options.autoRanks))
ranks.check.checked = true
ranks.check.scripts.OnClick(ranks.check)
local labels, labelSize = rowOf("rm.font.labels"), rowOf("rm.font.labels.size")
print("radial options font", "face=" .. tostring(labels.drop.value.text), "size=" .. tostring(labelSize.value.text),
    "label=" .. tostring(labelSize.label.text), "menu=" .. menuText(menuOf(labels.drop)))
local faces = menuOf(labels.drop)
faces[2].pick()
labelSize.plus.scripts.OnClick(labelSize.plus)
print("radial options font set", "face=" .. tostring(mdlui_RadialMenuDB.options.labelFont.face),
    "size=" .. tostring(mdlui_RadialMenuDB.options.labelFont.size), "shown=" .. tostring(labels.drop.value.text))
mdlui_RadialMenuDB.options.labelFont.face, mdlui_RadialMenuDB.options.labelFont.size = "__global", 16
local tipped = {}
GameTooltip.AddLine = function(_, text) tipped[#tipped + 1] = text end
pos.scripts.OnEnter(pos)
GameTooltip.AddLine = addLine
print("radial options hover", "title=" .. tostring(tipped[1]), "tip=" .. tostring(tipped[3] ~= nil))
print("radial options import", "shown=" .. tostring(win.importButton:IsShown()))
print("radial options copy", "missing=" .. tostring(ns.Settings:Text("rm.nosuch", "label")),
    "optional=" .. tostring(ns.Settings:Text("rm.nosuch", "tip", true)), "format=" .. ns.Settings:Format("a `b` c"))

-- ---- the FlareUI import: two radials (one opens the other), a group, a character's own key
FlareUI2_DB = { global = {
    radialmenu = {
        radials = {
            r1 = { name = "Flare Mounts", key = "V", group = "g7", buttons = { { kind = "subradial", radial = "r2" } } },
            r2 = { name = "Flare Food", buttons = { { kind = "item", id = 4599 } }, group = "g7" },
        },
        radialOrder = { "r2", "r1" }, nextRadialID = 3,
        groups = { g7 = { name = "Travel" } }, nextGroupID = 8,
    },
    characters = { ["Player-1-00000001"] = { radialKeyOverride = { r1 = "B" }, radialGroupsClosed = { g7 = true } } },
} }
local function dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. dump(v[k] ~= nil and v[k] or v[tonumber(k)]) end
    return "{" .. table.concat(out, ",") .. "}"
end
local flareBefore = dump(FlareUI2_DB)
win.tabs.wheel.scripts.OnClick(win.tabs.wheel)
print("radial import shown", "shown=" .. tostring(win.importButton:IsShown()))
win.importButton.scripts.OnClick(win.importButton)
print("radial import asks", "shown=" .. tostring(d2:IsShown()), d2.Text.text)
local radialsBefore = #RM:GetRadialOrder()
d2.Button1.scripts.OnClick(d2.Button1)
local order2 = RM:GetRadialOrder()
local food, mounts = order2[#order2 - 1], order2[#order2]
local store2 = RM.GetStore()
print("radial import", "radials " .. radialsBefore .. "->" .. #order2, "names=" .. RM:GetRadial(food).name .. "," .. RM:GetRadial(mounts).name,
    "ids=" .. food .. "," .. mounts, "sub=" .. buttonsOf(mounts), "group=" .. tostring(RM:GetRadial(food).group) .. ":"
    .. tostring(store2.groups[RM:GetRadial(food).group] and store2.groups[RM:GetRadial(food).group].name))
local _, ownMounts = RM:GetRadialKey(mounts)
print("radial import keys", "mounts=" .. tostring(RM:GetRadialKey(mounts)), "own=" .. tostring(ownMounts),
    "shared=" .. tostring(RM:GetRadial(mounts).key), "closed=" .. tostring(ns.CharDB().radialGroupsClosed
    and ns.CharDB().radialGroupsClosed[RM:GetRadial(food).group]), "overrides=" .. overrideList())
print("radial import leaves FlareUI", "same=" .. tostring(dump(FlareUI2_DB) == flareBefore))
setCombat(true)
print("radial import in combat", tostring(select(2, ns.ImportFromFlare())))
setCombat(false)
FlareUI2_DB = nil

-- ---- /mdlradial options, the binding, Escape's way out
win.tabs.wheel.scripts.OnClick(win.tabs.wheel)
win:Hide()
slash("options")
print("radial editor options word", "shown=" .. tostring(win:IsShown()), "tab=" .. shownTabs())
mdluiRadialToggleEditor()
print("radial editor binding", "shown=" .. tostring(win:IsShown()), "header=" .. tostring(BINDING_HEADER_MDLUI_RADIAL))
mdluiRadialToggleEditor()
print("radial editor binding again", "shown=" .. tostring(win:IsShown()), "tab=" .. shownTabs())

-- ---- round 3: the wheel's own art (art/radial/gen_radial.py), in FlareUI's layout
local function artName(path) return path and (tostring(path):match("([^\\]+)$")) or tostring(path) end
local wheelArt = _G.mdluiRadial
print("radial art wheel", "pointer=" .. artName(wheelArt.Pointer.texture), "atlas=" .. tostring(wheelArt.Pointer.atlas),
    "size=" .. tostring(wheelArt.Pointer.w), "cancel=" .. artName(wheelArt.CancelIcon.texture)
    .. "/" .. tostring(wheelArt.CancelIcon.atlas),
    "cancel lit=" .. artName(wheelArt.CancelSelect.texture), "hub=" .. artName(wheelArt.Ping.Ring.texture),
    "backdrop=" .. artName(wheelArt.Ping.Background.texture), "outer=" .. artName(wheelArt.Ping.Outer.texture))
local sample = RM.CreateSample(UIParent)
RM.DrawSample(sample)
local sw = sample.wheel
local b1, b2 = sw.buttons[1], sw.buttons[2]
local function rimOf(b)
    return artName(b.RimArt.texture) .. " glow=" .. tostring(b.RimGlow:IsShown()) .. " scale=" .. tostring(b.scale)
end
local count = #sw.buttons
local radius = 90 + math.max(0, count - 4) * 7.5
print("radial art buttons", "count=" .. count, "aimed=" .. rimOf(b1), "idle=" .. rimOf(b2),
    "well=" .. tostring(b1.Rim:IsShown()) .. ":" .. table.concat(b1.Rim.vertex, ","),
    "mask=" .. artName(b1.Mask.texture), "icon=" .. tostring(b1.Icon.w))
print("radial art outer ring", "size=" .. string.format("%.1f", sw.Ping.Outer.w),
    "ring radius=" .. string.format("%.1f", sw.Ping.Outer.w * 179 / 360), "want=" .. string.format("%.1f", radius + 46 * 0.9))
print("radial art colours", "slice=" .. table.concat(sw.Ping.Glow.vertex, ","),
    "label=" .. table.concat(b1.Label.textColor, ","),
    "lit edge=" .. table.concat(sw.Ping.Dividers[1].vertex, ","), "edge=" .. table.concat(sw.Ping.Dividers[3].vertex, ","))
-- the editor's round icons (the Catalog's): the same rim and mask over an ink well
local rowCell = host.browseList.cells[1]
local arts, wells = {}, 0
for _, r in ipairs(rowCell.all_ or {}) do
    if r.texture and tostring(r.texture):find("mdlui_RadialMenu") then arts[#arts + 1] = r.kind .. ":" .. artName(r.texture) end
    if r.kind == "Texture" and r.color and r.vertex and r.vertex[1] == 0.071 then wells = wells + 1 end
end
table.sort(arts)
print("radial art editor icon", "art=" .. table.concat(arts, ","), "wells=" .. wells)

-- ---- round 4: Medalluin's Options > Extensions > Radial menu (ext), lit by /mdlradial's being there
local mns = H.medalluin
local extPage
for _, page in ipairs(mns.OptionPages()) do if page.id == "radial" then extPage = page end end
local extButtons = {}
for _, g in ipairs(extPage.groups) do
    for _, item in ipairs(g.items) do if item.kind == "button" then extButtons[#extButtons + 1] = item end end
end
local extCategory
for _, c in ipairs(mns.OptionCategories()) do
    for _, item in ipairs(c.items) do if item == "radial" then extCategory = c.name end end
end
print("radial ext page", "name=" .. extPage.name, "enabled=" .. tostring(extPage.enabled()), "category=" .. tostring(extCategory),
    "buttons=" .. #extButtons .. ":" .. (extButtons[1] and extButtons[1].label or "") .. "," .. (extButtons[2] and extButtons[2].label or ""))
local closed = 0
local realClose = mns.CloseOptions
mns.CloseOptions = function() closed = closed + 1 end
win:Hide()
extButtons[1].click()
print("radial ext editor", "closed=" .. closed, "shown=" .. tostring(win:IsShown()), "tab=" .. shownTabs())
win:Hide()
extButtons[2].click()
print("radial ext options", "closed=" .. closed, "shown=" .. tostring(win:IsShown()), "tab=" .. shownTabs())
win:Hide()
local slashFn = SlashCmdList.MDLUI_RADIAL
SlashCmdList.MDLUI_RADIAL = nil
extButtons[1].click()
print("radial ext without the addon", "enabled=" .. tostring(extPage.enabled()), "closed=" .. closed, "shown=" .. tostring(win:IsShown()))
SlashCmdList.MDLUI_RADIAL = slashFn
mns.CloseOptions = realClose

-- A game panel's button: the micro button /clicked. The backpack opens
-- nothing when clicked with a modifier held (a radial on Shift-E fires with
-- Shift down), so Bags clicks it with none, and opens the bags itself with one.
for _, panel in ipairs({ "bags", "character" }) do
    local info = RM:ResolveEntry({ kind = "micromenu", panel = panel })
    local attrs = info and info.attributes
    print("radial panel " .. panel, "label=" .. tostring(info and info.name), "type=" .. tostring(attrs and attrs.type),
        "macrotext=" .. tostring(attrs and attrs.macrotext):gsub("\n", " / "))
end
