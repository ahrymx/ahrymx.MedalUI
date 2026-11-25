-- Known issues: damage an older MedalUI left behind that an update alone
-- does not undo (it lives in the game's own saved data, not ours). Each
-- issue can tell whether it is there and can put it right. At login, any
-- that are found are told in chat; the first time one is found a dialog
-- offers to fix it, and /mui fix-issues brings the dialog back.
--
-- A new issue is one more ns.KnownIssue{...}:
--   id     a stable key: the dialog is offered once per id
--   chat   what went wrong, a sentence for the chat line
--   Find() true while the issue is there
--   Fix()  puts it right; the dialog then reloads, so a fix only saves
local _, ns = ...
local Tr = ns.L

local issues = {}
function ns.KnownIssue(issue) table.insert(issues, issue) end

local function Say(text) print("|cffe0b84aMedalUI|r: " .. text) end
local COMMAND = "/mui fix-issues"

-- ------------------------------------------------- the console in Edit Mode
-- Before 0.41.0 the Cooldown Manager's viewers were anchored to the console
-- (MedalUIConsole). Saving an Edit Mode layout then wrote that anchor into
-- the layout by name, and the game kept it. Every time the layout is
-- applied, Edit Mode looks the name up, reads a global MedalUI made, and
-- the Cooldown Manager runs tainted for the rest of the session ("attempted
-- to index a table that cannot be accessed while tainted", CooldownViewer.lua,
-- on every tracked buff). The fix puts each such system back in its default
-- place in the saved layouts; MedalUI moves the viewers onto its own
-- holders anyway. Done on a fresh copy from C_EditMode, never on Edit Mode's
-- own tables, and applied by the reload: touching Edit Mode's live frames
-- from here would taint them the same way.
local function Named(anchor)
    return type(anchor) == "table" and type(anchor.relativeTo) == "string"
        and anchor.relativeTo:match("^MedalUI") ~= nil
end

local function Stuck(layouts)
    local found = {}
    for _, layout in ipairs(layouts and layouts.layouts or {}) do
        for _, system in ipairs(layout.systems or {}) do
            if Named(system.anchorInfo) or Named(system.anchorInfo2) then
                table.insert(found, system)
            end
        end
    end
    return found
end

local function Layouts()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
    local ok, layouts = pcall(C_EditMode.GetLayouts)
    return ok and layouts or nil
end

ns.KnownIssue({
    id = "editModeConsoleAnchor",
    chat = Tr["your saved Edit Mode layout still pins game frames (the Cooldown Manager) to MedalUI's frames, "
        .. "left by an older version. It makes the game's cooldown bars report errors \"tainted by MedalUI\"."],
    Find = function() return #Stuck(Layouts()) > 0 end,
    Fix = function()
        local layouts = Layouts()
        local preset = EditModePresetLayoutManager
        for _, system in ipairs(Stuck(layouts)) do
            local default = preset and preset.GetDefaultSystemAnchorInfo
                and preset:GetDefaultSystemAnchorInfo(system.system, system.systemIndex)
            system.anchorInfo = default or { point = "CENTER", relativeTo = "UIParent",
                relativePoint = "CENTER", offsetX = 0, offsetY = 0 }
            system.anchorInfo2 = nil
            system.isInDefaultPosition = default ~= nil
        end
        C_EditMode.SaveLayouts(layouts)
    end,
})

-- ------------------------------------------------------- Medalluin beside it
-- (2026-11-21) MedalUI was Medalluin until 0.63.1, a clean break: the old
-- folder is not replaced by the new one, and both load if both are there,
-- each drawing its own console over the other's. Found while Medalluin is
-- installed and on (or running); the fix turns it off, for every
-- character, and the reload leaves MedalUI alone. Deleting the folder, and
-- carrying the old settings over, are the player's (the README says how).
local OLD = "Medalluin"
local function Installed(name)
    if C_AddOns and C_AddOns.DoesAddOnExist then return C_AddOns.DoesAddOnExist(name) end
    local info = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if not info then return false end
    local found, _, _, _, reason = info(name)
    return found ~= nil and reason ~= "MISSING"
end
local function On(name)
    local me = UnitName("player")
    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        state = C_AddOns.GetAddOnEnableState(name, me)
    elseif GetAddOnEnableState then
        state = GetAddOnEnableState(me, name)    -- the older order: character first
    end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return (tonumber(state) or 0) > 0 or (loaded ~= nil and loaded(name) and true or false)
end

ns.KnownIssue({
    id = "medalluinBeside",
    chat = Tr["Medalluin, MedalUI's old name, is still installed and on: both run at once and draw over each "
        .. "other. Fixing turns Medalluin off; remove its folder from Interface/AddOns when the game is closed."],
    Find = function() return Installed(OLD) and On(OLD) end,
    Fix = function()
        local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
        disable(OLD)                            -- every character
        disable(OLD, UnitName("player"))        -- and this one, should the first be this one's only
    end,
})

-- --------------------------------------------------- Questie beside QuestieDB
-- (2026-11-25) Not an issue but advice: MedalUI's quest log, tracker, quest
-- pages, drop rates, the Zone tab's Guide and the tooltips' quests read
-- QuestieDB themselves, so Questie running as well only doubles them, and
-- its map pins hide the game's objective markers, which the waypoint to a
-- quest (the game's super-tracked one) needs. Once both are loaded, a
-- dialog offers to turn Questie off (QuestieDB stays on). "Keep Questie" is
-- final: it is not asked again. It waits for one of the two (Escape leaves
-- it); one closed by another dialog is asked again at the next login.
local function Loaded(name)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return loaded ~= nil and loaded(name) and true or false
end

function ns.QuestieAdvised()
    return Loaded("Questie") and Loaded("QuestieDB") and not (MedalUIDB and MedalUIDB.questieAdvised)
end

StaticPopupDialogs.MEDALUI_QUESTIE = {
    text = Tr["Questie is running beside QuestieDB. That is not recommended with MedalUI: it already has "
        .. "Questie's features, improved. Its quest log, tracker, quest pages with their whole chains, drop "
        .. "rates, the Zone tab's Guide and the quest tooltips read QuestieDB themselves, so Questie only "
        .. "doubles them, and its map pins hide the game's objective markers that waypoints to quests need."
        .. "\n\nTurn Questie off? The interface reloads; QuestieDB stays on."],
    button1 = Tr["Turn Questie off"],
    button2 = Tr["Keep Questie"],
    OnAccept = function()
        local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
        disable("Questie")                          -- every character
        disable("Questie", UnitName("player"))      -- and this one
        ReloadUI()
    end,
    OnCancel = function(_, _, reason)
        -- (closed by another dialog: asked again next login)
        if reason == "clicked" then MedalUIDB.questieAdvised = true end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
}

function ns.CheckQuestie()
    if not ns.QuestieAdvised() then return end
    if InCombatLockdown() then
        ns.OutOfCombat(ns.CheckQuestie)
        return
    end
    StaticPopup_Show("MEDALUI_QUESTIE")
end

-- -------------------------------------------------------------- the finding
local function Found()
    local found = {}
    for _, issue in ipairs(issues) do
        local ok, there = pcall(issue.Find)
        if ok and there then table.insert(found, issue) end
    end
    return found
end

local function Offered()
    MedalUIDB.issuesOffered = MedalUIDB.issuesOffered or {}
    return MedalUIDB.issuesOffered
end

-- Only a key is added: assigning StaticPopupDialogs itself would taint it.
-- The fixes and the reload run from the Fix button's own click: ReloadUI
-- from anything else is blocked (see settings.lua's profile reload).
StaticPopupDialogs.MEDALUI_FIX_ISSUES = {
    -- (the popup fills the two %s: what was found, and the list)
    text = Tr["MedalUI found %s left by an older version that updating does not undo:\n\n%s\n\n"
        .. "Fix now? The interface reloads to finish. You can do it later with /mui fix-issues."],
    button1 = Tr["Fix and reload"],
    button2 = Tr["Later"],
    OnAccept = function()
        local failed = false
        for _, issue in ipairs(Found()) do
            local ok, err = pcall(issue.Fix)
            if not ok then
                failed = true
                Say(format(Tr["could not fix it (%s). Try again with %s."], tostring(err), COMMAND))
            end
        end
        if not failed then ReloadUI() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function Offer(found)
    if InCombatLockdown() then
        ns.OutOfCombat(function() Offer(Found()) end)
        return
    end
    local lines = {}
    for _, issue in ipairs(found) do table.insert(lines, "- " .. issue.chat) end
    StaticPopup_Show("MEDALUI_FIX_ISSUES", #found == 1 and Tr["a problem"]
        or ns.Plural(#found, format(Tr["%d |4problem:problems;"], #found)),
        table.concat(lines, "\n"))
end

-- /mui fix-issues: the dialog again, or word that nothing is wrong.
function ns.FixIssues()
    local found = Found()
    if #found == 0 then
        Say(Tr["no known issues found."])
        return
    end
    Offer(found)
end

-- At login: every issue found is told in chat; one found for the first
-- time also gets the dialog. Once the game has finished loading (C_Timer),
-- so the chat line is not lost among the login's own.
function ns.CheckIssues()
    local found = Found()
    if #found == 0 then return end
    local offered, fresh = Offered(), false
    for _, issue in ipairs(found) do
        Say(format(Tr["%s Type %s to fix it."], issue.chat, COMMAND))
        if not offered[issue.id] then
            offered[issue.id] = true
            fresh = true
        end
    end
    if fresh then Offer(found) end
end

local checked = false
ns.On("PLAYER_ENTERING_WORLD", function()
    if checked then return end
    checked = true
    if C_Timer and C_Timer.After then
        C_Timer.After(3, ns.CheckIssues)
        C_Timer.After(4, ns.CheckQuestie)
    else
        ns.CheckIssues()
        ns.CheckQuestie()
    end
end)
