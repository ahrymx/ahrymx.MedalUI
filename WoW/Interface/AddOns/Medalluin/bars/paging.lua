-- Paging: which action page each bar Medalluin draws shows, by a macro
-- conditional, as Bartender's bars do. One option per bar (the Paging page
-- under Console, per profile): a preset, or Custom with its own conditional.
--
--   bar 1         ActionButton1-12              Blizzard's own paging by default
--   row 2         MultiBarBottomLeftButton1-12  page 6 (action bar 2) by default
--   row 3         MultiBarBottomRightButton1-12 page 5 (action bar 3) by default
--   centre grid   MultiBar6Button1-10           the Reticule's forms, stealth, flying
--
-- A page is 12 slots: page n holds actions (n - 1) * 12 + 1 to n * 12. Pages
-- 7 to 10 are the ones the game swaps bar 1 to for stances, forms and stealth,
-- and 11 the one it flies on (skyriding).
--
-- Blizzard's buttons read their page from an "actionpage" attribute, their
-- own or else their parent's. Their bars kept it on the bar frame, which
-- the buttons left when Medalluin took them, so each button now carries its
-- own, set by a secure state header from the conditional, in combat too,
-- and never by Medalluin's own code, which would taint the buttons' clicks
-- (ns.DriveState, core.lua).
-- Bar 1 left on Blizzard's paging carries none, and the game's own rules
-- (page arrows, stances, vehicles, override and possess bars) decide;
-- except where there is a centre grid, which takes the skyriding page from
-- it: there bar 1 carries Blizzard's rules written out, less that one.
--
-- The word "possess" in a conditional stands for whatever bar the game
-- puts up instead of bar 1: a vehicle's, an override, a temporary
-- shapeshift or a possessed unit's.
local _, ns = ...
local Tr = ns.L

-- Bar 1, Blizzard's rules as far as conditionals can say them: what takes
-- over bar 1, skyriding, the page arrows, then the stance pages.
local MAIN = "[overridebar][vehicleui][possessbar][shapeshift] possess; [bonusbar:5] 11; "
    .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
    .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; 1"

-- Bar 1 where the centre grid flies instead (the Reticule): the same,
-- without skyriding, so bar 1 keeps its page and the skyriding page shows
-- on the grid alone (the user's call, 2026-11-01).
local GROUNDED = MAIN:gsub("%[bonusbar:5%] 11; ", "")

-- key: the option; name: the bar's own (its header's frame is named by
-- it), label: as the options show it; base: the page it shows by default (nil: Blizzard's
-- rules); default: the default's own conditional, where it has one.
ns.PAGING_BARS = {
    { key = "bar1Paging", name = "Bar 1", label = Tr["Bar 1"], base = nil,
      defaultLabel = Tr["Blizzard's"], defaultTip = Tr["The game's own paging: the page arrows, stances, forms and "
        .. "stealth, skyriding, vehicles and override bars. With the centre grid (the Reticule), "
        .. "skyriding pages the grid instead, and bar 1 keeps its page."] },
    { key = "row2Paging", name = "Row 2", label = Tr["Row 2"], base = 6,
      defaultLabel = Tr["Action bar 2 (page 6)"], defaultTip = Tr["What Blizzard's action bar 2 shows."] },
    { key = "row3Paging", name = "Row 3", label = Tr["Row 3"], base = 5,
      defaultLabel = Tr["Action bar 3 (page 5)"], defaultTip = Tr["What Blizzard's action bar 3 shows."] },
    { key = "gridPaging", name = "Centre grid", label = Tr["Centre grid"], base = 7, grid = true,
      defaultLabel = Tr["Forms, stealth, flying (7-11)"], defaultTip = Tr["The Reticule's: page 7, page 8 "
        .. "in the first form or stance, 9 in the second and third, 10 in stealth, and 11 on a skyriding "
        .. "mount, the page bar 1 flies on, so skyriding skills can go on the grid. Each one can be switched "
        .. "off below."] },
}
-- The grid's default, a condition at a time, each switched on or off by its
-- own option (the Paging page's switches): off, the grid stays on page 7
-- there. Skyriding first, as on bar 1 (MAIN): a druid flying in a form flies.
ns.GRID_PARTS = {
    { key = "gridPageFlying", name = Tr["Flying"], page = 11, part = "[bonusbar:5] 11",
      note = Tr["On a skyriding mount: the page bar 1 flies on."] },
    { key = "gridPageForm1", name = Tr["First form"], page = 8, part = "[bonusbar:1] 8; [form:1] 8",
      note = Tr["Cat form, ghost wolf, battle stance, a rogue's stealth: the first form or stance."] },
    { key = "gridPageForm2", name = Tr["Second form"], page = 9, part = "[form:2] 9",
      note = Tr["Bear form, defensive stance: the second form or stance."] },
    { key = "gridPageForm3", name = Tr["Third form"], page = 9, part = "[form:3] 9",
      note = Tr["Travel form, berserker stance: the third form or stance."] },
    { key = "gridPageStealth", name = Tr["Stealth"], page = 10, part = "[stealth] 10",
      note = Tr["Stealth outside a form, as shadowmeld. A rogue's stealth and a druid's prowl are their first form."] },
}
local function GridDefault()
    local parts = {}
    for _, p in ipairs(ns.GRID_PARTS) do
        if ns.db[p.key] ~= false then parts[#parts + 1] = p.part end
    end
    parts[#parts + 1] = "7"
    return table.concat(parts, "; ")
end

local function Stances(base)
    return "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; " .. base
end

-- The dropdown's choices for a bar: its default, stance paging (not the
-- grid's: its default is that), a fixed page, or Custom.
function ns.PagingChoices(bar)
    local list = { { "default", bar.defaultLabel, bar.defaultTip } }
    if not bar.grid then
        table.insert(list, { "stances", bar.base and Tr["Stances and stealth"] or Tr["Medalluin's (stances, vehicles)"],
            bar.base and format(Tr["Pages 7 to 10 for stances, forms and stealth, as bar 1's are; page %d otherwise."],
                bar.base) or Tr["Blizzard's rules written as a conditional, so a page can be added "
                .. "to it: start Custom from here."] })
    end
    for n = 1, 10 do table.insert(list, { "page" .. n, format(Tr["Always page %d"], n) }) end
    table.insert(list, { "custom", Tr["Custom"], Tr["Your own conditional: Edit conditional below."] })
    return list
end

local function Find(key)
    for _, bar in ipairs(ns.PAGING_BARS) do
        if bar.key == key then return bar end
    end
end

-- The conditional a bar's option asks for, or nil for Blizzard's rules.
function ns.PagingConditional(key, choice, custom)
    local bar = Find(key)
    choice = choice or ns.db[key]
    custom = custom or ns.db[key .. "Custom"]
    local page = tonumber(tostring(choice):match("^page(%d+)$"))
    if page then return tostring(page) end
    if choice == "custom" and custom and custom:match("%S") then return custom end
    if choice == "stances" then return bar.base and Stances(bar.base) or MAIN end
    if bar.grid then return GridDefault() end
    if not bar.base and ns.bar7 then return GROUNDED end
    return bar.base and tostring(bar.base) or nil
end

-- What Custom's editor starts from: the conditional in use (bar 1 on
-- Blizzard's rules starts from them, written out).
function ns.PagingStart(key)
    return ns.PagingConditional(key) or MAIN
end

-- Run in the secure environment on every change of state: "possess" made a
-- page as the game's own bar 1 would, and the page put on each button. Only
-- the game's secure update ever runs it to the end (ns.DriveState).
local SNIPPET = [=[
    if self:GetAttribute("medalluin-hold") then return end
    local page = newstate
    if page == "possess" then
        if HasVehicleActionBar() then page = GetVehicleBarIndex()
        elseif HasOverrideActionBar() then page = GetOverrideBarIndex()
        elseif HasTempShapeshiftActionBar() then page = GetTempShapeshiftBarIndex()
        elseif HasBonusActionBar() then page = GetBonusBarIndex()
        else page = 1 end
    end
    -- no state (no conditional): no page of its own, Blizzard's paging
    if newstate ~= nil then page = tonumber(page) or 1 end
    self:SetAttribute("page", page)
    for i = 1, 12 do
        local b = self:GetFrameRef("b" .. i)
        if b then b:SetAttribute("actionpage", page) end
    end
]=]
ns.PAGING_SNIPPET = SNIPPET

local headers = {}
ns.pagingHeaders = headers

local function Apply(bar)
    local header = headers[bar.key]
    if not header then return end
    local conditional = ns.PagingConditional(bar.key)
    header.conditional = conditional
    ns.DriveState(header, "page", conditional)
end

-- A header for one row of Blizzard's buttons, once they are on the bar.
local function Header(bar, prefix)
    local header = CreateFrame("Frame", "Medalluin" .. bar.name:gsub(" ", "") .. "Paging", UIParent,
        "SecureHandlerStateTemplate")
    header.buttons = {}
    for i = 1, 12 do
        local b = _G[prefix .. i]
        if b then
            header:SetFrameRef("b" .. i, b)
            table.insert(header.buttons, b)
        end
    end
    header:SetAttribute("_onstate-page", SNIPPET)
    headers[bar.key] = header
    Apply(bar)
end

local ROWS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton" }

-- After bars/buttons.lua has adopted the rows (both wait out combat, in
-- the order they were asked).
ns.On("PLAYER_LOGIN", function()
    if not ns.db.actionBar then return end
    local rows = math.max(1, math.min(#ROWS, tonumber(ns.db.rows) or 1))
    ns.OutOfCombat(function()
        for r = 1, rows do Header(ns.PAGING_BARS[r], ROWS[r]) end
    end)
end)

for _, bar in ipairs(ns.PAGING_BARS) do
    local function Changed()
        if bar.grid then
            if ns.ApplyGridPaging then ns.OutOfCombat(ns.ApplyGridPaging) end
        else
            ns.OutOfCombat(function() Apply(bar) end)
        end
    end
    ns.OnSetting(bar.key, function(v)
        Changed()
        -- picking Custom with no conditional yet opens the editor (settings.lua)
        if v == "custom" and not tostring(ns.db[bar.key .. "Custom"]):match("%S") and ns.EditPaging then
            ns.EditPaging(bar)
        end
    end)
    ns.OnSetting(bar.key .. "Custom", Changed)
    if bar.grid then
        for _, p in ipairs(ns.GRID_PARTS) do ns.OnSetting(p.key, Changed) end
    end
end
