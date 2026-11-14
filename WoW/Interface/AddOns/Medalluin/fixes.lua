-- Known issues: damage an older Medalluin left behind that an update alone
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

local issues = {}
function ns.KnownIssue(issue) table.insert(issues, issue) end

local function Say(text) print("|cffe0b84aMedalluin|r: " .. text) end
local COMMAND = "/mui fix-issues"

-- ------------------------------------------------- the console in Edit Mode
-- Before 0.41.0 the Cooldown Manager's viewers were anchored to the console
-- (MedalluinConsole). Saving an Edit Mode layout then wrote that anchor into
-- the layout by name, and the game kept it. Every time the layout is
-- applied, Edit Mode looks the name up, reads a global Medalluin made, and
-- the Cooldown Manager runs tainted for the rest of the session ("attempted
-- to index a table that cannot be accessed while tainted", CooldownViewer.lua,
-- on every tracked buff). The fix puts each such system back in its default
-- place in the saved layouts; Medalluin moves the viewers onto its own
-- holders anyway. Done on a fresh copy from C_EditMode, never on Edit Mode's
-- own tables, and applied by the reload: touching Edit Mode's live frames
-- from here would taint them the same way.
local function Named(anchor)
    return type(anchor) == "table" and type(anchor.relativeTo) == "string"
        and anchor.relativeTo:match("^Medalluin") ~= nil
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
    chat = "your saved Edit Mode layout still pins game frames (the Cooldown Manager) to Medalluin's frames, "
        .. "left by an older version. It makes the game's cooldown bars report errors \"tainted by Medalluin\".",
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
    MedalluinDB.issuesOffered = MedalluinDB.issuesOffered or {}
    return MedalluinDB.issuesOffered
end

-- Only a key is added: assigning StaticPopupDialogs itself would taint it.
-- The fixes and the reload run from the Fix button's own click: ReloadUI
-- from anything else is blocked (see settings.lua's profile reload).
StaticPopupDialogs.MEDALLUIN_FIX_ISSUES = {
    text = "Medalluin found %s left by an older version that updating does not undo:\n\n%s\n\n"
        .. "Fix now? The interface reloads to finish. You can do it later with " .. COMMAND .. ".",
    button1 = "Fix and reload",
    button2 = "Later",
    OnAccept = function()
        local failed = false
        for _, issue in ipairs(Found()) do
            local ok, err = pcall(issue.Fix)
            if not ok then
                failed = true
                Say("could not fix it (" .. tostring(err) .. "). Try again with " .. COMMAND .. ".")
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
    StaticPopup_Show("MEDALLUIN_FIX_ISSUES", #found == 1 and "a problem" or (#found .. " problems"),
        table.concat(lines, "\n"))
end

-- /mui fix-issues: the dialog again, or word that nothing is wrong.
function ns.FixIssues()
    local found = Found()
    if #found == 0 then
        Say("no known issues found.")
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
        Say(issue.chat .. " Type " .. COMMAND .. " to fix it.")
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
    else
        ns.CheckIssues()
    end
end)
