-- Questie's map and minimap icons as a panel, the quest restyle's: the quests
-- (or the givers) an icon stands for, each with its lines under it, and
-- Questie's "(Hold Shift)" as the panel's foot. Questie fills the game's
-- tooltip with lines alone and marks it (ShownAsMapIcon), redrawing it with
-- Shift; the lines are read as Questie lays them out, its indents (blank
-- textures of a width) the depth of each.
local _, ns = ...
local ui = ns.ui
if not (ui and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local trim = util.trim
local KIND = "questieMap"
local INDENT_STEP = 10          -- px a level of Questie's indents is drawn in
local QUEST_GOLD = colors.quest

-- Questie's indent: a blank texture this many pixels wide.
local INDENT = "^|T[^|]-bonusobjectiveblob%-inside[^|]-:1:([%d%.]+)|t"

-- A line's depth (its indents' width) and its text without them, nor a
-- leading "- " (an older Questie's bullet).
local function depthOf(text)
    local width = 0
    while true do
        local w = text:match(INDENT)
        if not w then break end
        width = width + (tonumber(w) or 0)
        text = text:gsub(INDENT, "", 1)
    end
    local spaces = text:match("^( +)")
    if spaces then
        width, text = width + #spaces * 3, text:sub(#spaces + 1)
    end
    local code, rest = text:match("^(|c%x%x%x%x%x%x%x%x)%- (.*)$")
    if code then text = code .. rest elseif text:sub(1, 2) == "- " then text = text:sub(3) end
    return width, text
end

-- Questie's own word for its hint, in the words its tooltips print.
local function holdShift()
    local game = ns.Game
    local word = game and game.questieText and game.questieText("Hold Shift")
    return type(word) == "string" and word ~= "" and word or "Hold Shift"
end

-- Questie's "(…)" round a note, as a panel's badge or foot without them.
local function unwrapped(text)
    local plain = trim(util.plainText(text))
    return plain:match("^%((.*)%)$") or plain
end

local function isQuestieMap(tooltip)
    if rawget(tooltip, "ShownAsMapIcon") ~= true or type(rawget(tooltip, "_Rebuild")) ~= "function" then
        return false
    end
    local owner = rawget(tooltip, "_showOwner") or rawget(tooltip, "_owner")
    local ok, current = pcall(tooltip.GetOwner, tooltip)
    return ok and owner ~= nil and current == owner
end

local function readMap(tooltip)
    if not isQuestieMap(tooltip) then return end
    local rows = tooltipData.appendedRows(tooltip, {})
    if not rows or #rows == 0 then return end
    local hint = holdShift()
    local model = { groups = {} }
    local group
    local depths = {}
    for _, row in ipairs(rows) do
        -- (Questie's spacer, before a heading: the heading starts its group)
        if not tooltipData.isBlank(row) then
            local depth, left = depthOf(row.left)
            local right = row.right or ""
            if util.plainText(right):find(hint, 1, true) then
                model.hint, right = unwrapped(right), ""
            end
            local line = { left = left, right = right, color = row.textColor, rightColor = row.rightColor,
                depth = depth }
            if depth == 0 or not group then
                group = { head = line, lines = {} }
                model.groups[#model.groups + 1] = group
            else
                group.lines[#group.lines + 1] = line
                depths[depth] = true
            end
        end
    end
    if #model.groups == 0 then return end
    -- the depths in use, smallest first: each one a step in
    local order = {}
    for depth in pairs(depths) do order[#order + 1] = depth end
    table.sort(order)
    model.steps = {}
    for index, depth in ipairs(order) do model.steps[depth] = index - 1 end
    return model
end

local function mapKey(tooltip)
    local parts = {}
    for index = 1, tooltip:NumLines() do
        local font = tooltip:GetLeftLine(index)
        local text = font and util.safeText(font:GetText())
        if not text then return end
        parts[#parts + 1] = text
    end
    return table.concat(parts, "\n")
end

local function colorOf(color, fallback)
    if type(color) == "table" and type(color[1]) == "number" then return { color[1], color[2], color[3] } end
    return fallback
end

local function mapView(model)
    local titleStyle, rowStyle = ui.styleOf("questTitle"), ui.styleOf("questObjectives")
    local header, sections = {}, {}
    for index, group in ipairs(model.groups) do
        local head = group.head
        local rows = {}
        if index == 1 then
            header[1] = { text = head.left, style = titleStyle, color = colorOf(head.color, QUEST_GOLD), gap = 4 }
            if head.right ~= "" then
                header[2] = { badges = { { unwrapped(head.right), colorOf(head.rightColor, colors.caption) } },
                    style = ui.styleOf("objectKind"), before = 1, gap = 4 }
            end
        else
            rows[1] = { left = head.left, right = head.right ~= "" and unwrapped(head.right) or "", color = colorOf(head.color, QUEST_GOLD),
                rightColor = colorOf(head.rightColor, colors.caption) }
        end
        for _, line in ipairs(group.lines) do
            rows[#rows + 1] = { left = line.left, right = line.right, color = colorOf(line.color, colors.detail),
                rightColor = colorOf(line.rightColor, colors.caption),
                indent = (model.steps[line.depth] or 0) * INDENT_STEP }
        end
        if #rows > 0 then
            sections[#sections + 1] = { kind = "rows", rows = rows, style = rowStyle, color = colors.detail, gap = 3,
                wrap = true, separator = #sections > 0 and { space = 6 } or nil }
        end
    end
    local footer = model.hint and { rows = { { left = model.hint, right = "" } }, style = ui.styleOf("objectPrices"),
        color = colors.caption, gap = 3 }
    return { tooltipType = "quest", color = QUEST_GOLD, header = header, sections = sections, footer = footer,
        minWidth = 0 }
end

ns.QuestieMap = { read = readMap, view = mapView, depthOf = depthOf }

-- Restyled with the quests (no setting of its own).
ui.defineTooltipType(KIND, { read = readMap, key = mapKey, option = "questPanels", linesOnly = true,
    render = function(panel, tooltip, model) ui.renderView(panel, tooltip, mapView(model)) end })

-- Questie writes its lines, marks the tooltip, then shows it (again with
-- Shift): drawn when it is one of Questie's icons'.
hooksecurefunc(GameTooltip, "Show", function(tooltip)
    if not ns.Hooks or not util.canModify(tooltip) or not tooltip:IsShown() then return end
    if not isQuestieMap(tooltip) then return end
    ns.Hooks.renderLines(tooltip, KIND)
end)
