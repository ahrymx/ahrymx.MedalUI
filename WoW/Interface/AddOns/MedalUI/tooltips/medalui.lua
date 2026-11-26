-- MedalUI's own tooltips as panels: the XP bar, the status icons, the
-- minimap button and the rest. MedalUI fills the game's tooltip with lines
-- alone and hands over what they say as a spec (its core.lua, ns.Tip), read
-- through MedalUI_TooltipSpec; the lines themselves are never parsed.
local _, medal = ...
local ns = medal.tips
local ui, util = ns.ui, ns.util
if not (ui and ui.renderView) then
    return
end

local colors = ns.Palette.roles
local KIND = "mdlui"
local GOLD = medal.Themed({ .847, .722, .416 })   -- MedalUI's gold, its XP bar's
local WARN = { 1, .3, .25 }

local function readSpec(tooltip)
    local spec = util.call(_G.MedalUI_TooltipSpec, tooltip)
    if type(spec) == "table" then return spec end
end

-- Every part's fields, so a tooltip filled again with new numbers (the
-- clock, the minimap button's switch) is drawn again.
local function specKey(tooltip)
    local spec = readSpec(tooltip)
    if not spec then return end
    local parts = { tostring(spec.title) }
    for _, part in ipairs(spec) do
        if part then
            for index = 1, 5 do parts[#parts + 1] = type(part[index]) == "table" and "" or tostring(part[index]) end
        end
    end
    return table.concat(parts, "\031")
end

-- A bar across the panel, value/max of it filled, and its text under it.
local function barSection(part, style)
    local value, max, text, color = tonumber(part[2]) or 0, tonumber(part[3]) or 0, part[4], part[5] or GOLD
    local row = { left = text or "" }
    return { kind = "custom",
        measure = function(panel) return ui.rowWidth(panel, row, style) end,
        draw = function(panel, y)
            local height = ui.barHeight()
            local set = ui.drawTrack(panel, y, height)
            set(max > 0 and value / max or 0, color)
            return ui.drawRow(panel, row, y + height + 4, style, colors.detail, 0, 3)
        end }
end

-- a key part's cell: the modifier, the mouse with its button lit, what it
-- does; an empty slot of the grid (a key that does nothing here) blank
local function keyCell(part)
    if not part[2] then return "" end
    return (part[3] and (part[3] .. " + ") or "") .. "|TInterface\\AddOns\\MedalUI\\media\\strips\\mouse-"
        .. tostring(part[2]) .. ":16:16:0:0:32:32:5:27:5:27|t " .. tostring(part[4])
end

local function specView(spec)
    local detail = ui.styleOf("objectDetails")
    local header, sections, hints = {}, {}, {}
    -- A tip that is one sentence reads as prose, not as a title.
    if spec.title and spec.wrap then
        sections[1] = { kind = "prose", sentences = { spec.title }, style = detail, color = colors.detail, gap = 4 }
    elseif spec.title then
        header[1] = { text = spec.title, style = ui.styleOf("objectTitle"), color = spec.color or colors.title, gap = 4 }
    end
    -- Neighbouring rows share a section; anything else starts its own.
    local function rows(color)
        local last = sections[#sections]
        if not (last and last.kind == "rows" and last.color == color) then
            last = { kind = "rows", rows = {}, style = detail, color = color, gap = 3, wrap = true }
            sections[#sections + 1] = last
        end
        return last.rows
    end
    local lastRole
    for _, part in ipairs(spec) do
        -- a line with nothing to say (a tab's count it does not have) left out
        if part and (part[1] == "body" or part[1] == "hint" or part[1] == "warn")
            and (part[2] == nil or part[2] == "") then
            part = false
        end
        local role = part and part[1]
        if role == "body" then
            local list = rows(part[3] and colors.caption or colors.detail)
            list[#list + 1] = { left = part[2], right = "" }
        elseif role == "row" then
            local list = rows(colors.caption)
            list[#list + 1] = { left = part[2], right = part[3], rightColor = colors.detail }
        elseif role == "item" then
            local list = rows(colors.detail)
            local icon = part[2] and ("|T" .. part[2] .. ":20:20|t ") or ""
            list[#list + 1] = { left = icon .. part[3], right = part[4] or "", rightColor = colors.detail }
        elseif role == "warn" then
            local list = rows(WARN)
            list[#list + 1] = { left = part[2], right = "" }
        elseif role == "bar" then
            sections[#sections + 1] = barSection(part, detail)
        elseif role == "hint" then
            hints[#hints + 1] = { left = part[2], right = "" }
        elseif role == "key" then
            -- a shortcut, "Shift + (mouse) Link": neighbouring ones two to a row, a grid
            local last = hints[#hints]
            if last and last.keys == 1 and lastRole == "key" then
                last.right, last.keys = keyCell(part), 2
            else
                hints[#hints + 1] = { left = keyCell(part), right = "", keys = 1 }
            end
        end
        if part then lastRole = role end
    end
    -- a grid row whose two slots are both empty is left out
    for index = #hints, 1, -1 do
        local row = hints[index]
        if row.keys and row.left == "" and (row.right or "") == "" then table.remove(hints, index) end
    end
    -- Sections after the first stand a little apart.
    for index = 2, #sections do sections[index].separator = { space = 4 } end
    return { tooltipType = "object", color = GOLD, header = header, sections = sections,
        footer = #hints > 0 and { rows = hints, style = ui.styleOf("objectPrices"), color = colors.caption, gap = 3 }
            or nil,
        minWidth = 0, compact = true }
end

ui.defineTooltipType(KIND, { read = readSpec, key = specKey, option = "medaluiPanels", linesOnly = true,
    render = function(panel, tooltip, spec) ui.renderView(panel, tooltip, specView(spec)) end })

-- MedalUI writes its lines, then shows: draw the panel when a spec is live.
hooksecurefunc(GameTooltip, "Show", function(tooltip)
    if not ns.Hooks or not util.canModify(tooltip) or not tooltip:IsShown() then return end
    if not readSpec(tooltip) then return end
    ns.Hooks.renderLines(tooltip, KIND)
end)
