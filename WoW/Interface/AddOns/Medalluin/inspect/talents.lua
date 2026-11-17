-- The inspect window's Talents page (Forever): the inspected player's
-- trees, drawn as the talents window draws yours (spells/talents.lua,
-- ns.talents.Draw), read only. The game keeps an inspection's talents as a
-- config of their own (Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID),
-- known once the inspection has come back (C_Traits.HasValidInspectData).
--
--   Arms  ·  14 points                                   <- over the tree
--        [o]     [o]
--         |                     (the tree, its talents' ranks)
--        [o] 2/5 [o]
--   ---------------------------------------------------------------
--   the chosen talent's name, rank and what each rank gives
--   ---------------------------------------------------------------
--   [ Arms 14 ][ Fury 0 ][ Protection 0 ]   (backpack)   <- the margin
--
-- The margin switches the tree; each inspection opens on the tree with the
-- most points. A click on a talent reads it in the details; Shift-click
-- links it. Its tab is not there where the game has no such config
-- (retail keeps Blizzard's own route to them: the window stays as it is).
local _, ns = ...

local GOLD = { 0.941, 0.831, 0.533 }
local LINES = 4

local page = { key = "inspectTalents", label = "Talents", tip = "Their talents", glyph = "talents", order = 2,
    flex = true, height = 0, bandUsed = true, bandFlush = true, readonly = true }
page.nodes, page.edges = {}, {}
local tree                              -- the tree in view, by its place; nil: the fullest, chosen anew

local function T() return ns.talents end
local function Config()
    return Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
end
-- the inspection's talents, when they are known
local function Valid()
    return C_Traits and C_Traits.HasValidInspectData and C_Traits.HasValidInspectData() and T() ~= nil
end

local function Read()
    if not Valid() then return end
    local config = Config()
    local ok, groups = pcall(T().Groups, config)
    if not ok or not groups or #groups == 0 then return end
    return config, groups, T().Spent(config, groups)
end

-- "14/0/0", for the summary's ribbon (inspect/page.lua)
function ns.inspect.TalentSplit()
    local _, groups, spent = Read()
    if not groups then return end
    local list = {}
    for i, g in ipairs(groups) do list[i] = spent[g.groupID] or 0 end
    return table.concat(list, "/")
end

-- the tree in view: the one chosen, else the one with the most points
local function InView(groups, spent)
    if tree and groups[tree] then return tree end
    local best, most = 1, -1
    for i, g in ipairs(groups) do
        if (spent[g.groupID] or 0) > most then best, most = i, spent[g.groupID] or 0 end
    end
    return best
end

local function Margin(groups, spent, at)
    local items = {}
    for i, g in ipairs(groups) do
        items[i] = { key = i, label = format("%s %d", g.displayName or "?", spent[g.groupID] or 0), group = "trees",
            click = function()
                tree = i
                page.chosen = nil
                page.Refresh()
            end,
            tip = function() return format("%s: %d |4point:points;", g.displayName or "?", spent[g.groupID] or 0) end,
            selected = i == at }
    end
    page.margin:Fill(items)
end

local function Hide()
    for _, b in ipairs(page.nodes) do b:Hide() end
    for _, l in ipairs(page.edges) do l:Hide() end
end

function page.Refresh()
    local config, groups, spent = Read()
    page.waiting:SetShown(not config)
    if not config then
        Hide()
        page.points:SetText("")
        page.details:Set(nil)
        page.margin:Fill({})
        return
    end
    local at = InView(groups, spent)
    local group = groups[at]
    page.config = config
    local byID = T().Draw(page, config, group, groups)
    page.points:SetText(format("%s  ·  %d |4point:points;", group.displayName or "?", spent[group.groupID] or 0))
    local chosen = page.chosen and byID[page.chosen]
    if chosen then
        local node = chosen.node
        page.details:Set({ title = chosen.talent.name, sub = format("Rank %d/%d", node.ranksPurchased, node.maxRanks),
            text = T().Describe(chosen) })
    else
        page.details:Set(nil)
    end
    Margin(groups, spent, at)
end

-- Forever's trees only, as the talents window's (its micro menu's own
-- talents button, the spec groups' configs)
function page.Available()
    return C_Traits ~= nil and C_Traits.HasValidInspectData ~= nil and ns.talents ~= nil
        and SpellbookMicroButton ~= nil and C_SpecializationInfo ~= nil
        and C_SpecializationInfo.GetCombatConfigIDForSpecGroup ~= nil
end

function page.Build(body, foot, band)
    page.body = body
    local strip = CreateFrame("Frame", nil, body)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(T().head)
    page.points = ns.Text(strip, 12)
    page.points:SetPoint("CENTER")
    page.points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    page.waiting = ns.Text(body, 13)
    page.waiting:SetPoint("CENTER")
    page.waiting:SetTextColor(unpack(ns.colors.dim))
    page.waiting:SetText("Their talents have not come yet.")
    page.details = ns.character.Details(foot, nil, "Choose a talent to read it.", LINES)
    page.footHeight = page.details.height
    local row = ns.window.Segments(band, { height = band:GetHeight(), items = {} })
    row:SetPoint("TOPLEFT")
    row:SetPoint("TOPRIGHT")
    page.margin = row
end

page.events = { "INSPECT_READY", "TRAIT_CONFIG_UPDATED" }
-- a new inspection opens on its fullest tree
function page.OnEvent(event)
    if event == "INSPECT_READY" then tree, page.chosen = nil, nil end
end

ns.inspect.InspectPage(page)
ns.inspect.talents = page
