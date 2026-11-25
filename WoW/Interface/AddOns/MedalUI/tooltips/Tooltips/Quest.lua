-- Quests as a panel.
local _, medal = ...
local ns = medal.tips
local ui = ns.ui
local QUEST = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Quest
if not (ui and QUEST and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim, readable = util.isSecret, util.safeText, util.trim, util.readable
local unformat, startsWith = util.unformat, util.startsWith
local L = ns.L
local LINE = Enum.TooltipDataLineType or {}
local pad = ui.pad
local ICON_SIZE = 38
local TINT_STRENGTH = .45
local CHECK_SIZE = 10
local OBJECTIVE_INDENT = CHECK_SIZE + 7
local QUEST_GOLD = colors.quest
local PARCHMENT = colors.flavor
local DONE_COLOR = colors.done
local FAILED_COLOR = { 1, .35, .30 }
local EXTRAS_RULE = { .50, .50, .54 }
local REPEAT_COLOR = { .45, .70, 1 }
local CHAIN_COLOR = { .62, .60, .56 }
local CHAIN_TAG = { .71, .61, .89 }        -- the chain's chip, in the Chain band's violet
-- (2026-11-22) each section's heading band in a colour of its own, so the
-- sections are told apart at a glance
local SECTION_HUES = {
    objectives = { .88, .71, .31 },
    where = { .44, .71, .81 },
    chain = { .71, .61, .89 },
    reputation = { .49, .77, .48 },
    party = { .42, .80, .74 },
}
local BAND_BEFORE = 8
local QUEST_ICON = "Interface\\Icons\\INV_Misc_Book_08"
local TAGS = ns.Locale.questTags
-- Questie writes the tag as a suffix on the level: "[27D] The Fury Runs Deep".
local SUFFIX_TAGS = {
    ["+"] = ELITE, ["++"] = L["Legendary"], D = LFG_TYPE_DUNGEON, R = RAID, H = L["Heroic"],
    G = L["Group"], S = L["Scenario"], W = L["World event"],
}
-- Questie's labeled rows, shown as label and value.
local LABELS = { "Started by", "Ended by", "Found in", "Completed on" }
local PARTS = { "questTitle", "questInfo", "questBadges", "questText", "questCaption", "questObjectives",
    "extras" }

local function questKey(_, data)
    return readable(data.id)
end

local fromQuestie, questieWords, partyOf
local function completeModel(model, questID, game)
    -- The quest log's tooltip names no level.
    if questID and not model.level then model.level = game.questLevel(questID) end
    if questID and not model.active then
        -- nil without a quest log to ask.
        local completed = game.questCompleted(questID)
        if completed ~= nil then
            model.completed = model.completed or completed
            model.active = model.active or game.onQuest(questID)
        end
    end
    -- A quest turned in has done all it asked, whatever its lines count.
    if model.completed then
        for _, objective in ipairs(model.objectives) do objective.completed = true end
    end
    -- Where the quest is (Questie's Started by, Ended by and Found in) has a
    -- group of its own, in that order; the other labeled rows stay extras.
    local words = questieWords(game)
    local order = {}
    for index = 1, 3 do
        order[words.labels[index]] = index
        order[L[LABELS[index]]] = order[L[LABELS[index]]] or index
    end
    local where, kept = model.where or {}, {}
    for _, row in ipairs(model.extras) do
        if order[row.left] then where[#where + 1] = row else kept[#kept + 1] = row end
    end
    model.where, model.extras = where, kept
    fromQuestie(model, questID, game, words)
    -- (2026-11-22) the party's progress on it, once the objectives are known
    if questID then model.party = partyOf(model, questID, game) or false end
    table.sort(model.where, function(a, b) return (order[a.left] or 4) < (order[b.left] or 4) end)
    -- (2026-11-22) the experience it gives, while it can still give it
    if questID and not model.completed and game.questXP then model.xp = game.questXP(questID) end
    model.color = game.difficultyColor(model.level) or QUEST_GOLD
    model.icon = model.icon or QUEST_ICON
    return model
end

local function objectiveDone(row)
    if row.completed ~= nil then return row.completed end
    local have, need = (row.right ~= "" and row.right or row.left):match("(%d+)%s*/%s*(%d+)%s*$")
    return have ~= nil and tonumber(have) >= tonumber(need)
end

-- An objective's line: its goal and its count, done or not.
local function objectiveOf(text, right, completed)
    local name = text:gsub("^%-%s*", "")
    local goal, progress = name:match("^(.-):%s*(%d+%s*/%s*%d+)$")
    -- The quest log puts the count first: "0/1 Head of Deepfury".
    if not goal then progress, goal = name:match("^(%d+%s*/%s*%d+)%s+(.+)$") end
    -- A quest not in the log names how many: "15 x Dark Iron Dwarf".
    if not goal then progress, goal = name:match("^(%d+) x (.+)$") end
    local objective = { left = goal or name, right = progress or right or "", completed = completed }
    objective.completed = objectiveDone(objective)
    return objective
end

local function isRed(color)
    return type(color) == "table" and color[1] > .9 and color[2] < .4 and color[3] < .4
end

-- Questie colors its lines with codes on white text.
local function codeColor(text)
    local r, g, b = text:match("^%s*|c%x%x(%x%x)(%x%x)(%x%x)")
    if r then return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } end
end

local function readTitle(model, text)
    local level, suffix, rest = text:match("^%[(%d+)([^%]]*)%]%s*(.+)$")
    if level then
        model.level = tonumber(level)
        if SUFFIX_TAGS[suffix] then model.tags[#model.tags + 1] = SUFFIX_TAGS[suffix] end
        text = rest
    end
    model.name = text:gsub("%s*%(%d+%)$", "")
end

-- Questie's words, in the language it is set to: its phrases, the separator
-- it puts after a label (" : " in French), and its labels.
function questieWords(game)
    local words = {}
    for _, phrase in ipairs({ "You are on this quest", "Complete", "Failed", "You have completed this quest",
        "This quest is repeatable", "You have not done this quest", "Your progress", "Objectives", "Instance",
        ": " }) do
        words[phrase] = game.questieText(phrase)
    end
    words.labels = {}
    for index, label in ipairs(LABELS) do words.labels[index] = game.questieText(label) end
    return words
end

-- Questie's database --------------------------------------------------------------

-- What its lines leave out (a quest link's tooltip has little), from Questie's
-- database when it is loaded: never over what the lines said.
local PLACE = "|cff9a9282"                  -- where an NPC stands, after their name
local REP_GAIN = { .91, .78, .31 }          -- the reputation a quest gives

-- The first ID in a list of Questie's (or the ID itself).
local function firstId(list)
    if type(list) == "number" then return list end
    if type(list) ~= "table" then return end
    for key, value in pairs(list) do
        if type(value) == "number" then return value end
        if type(key) == "number" and value == true then return key end
    end
end

local function named(game, kind, id)
    local name = id and game.questieField(kind, id, "name")
    if type(name) == "string" and name ~= "" then return name end
end

-- Who starts or ends it: the first NPC, with where they stand; else the
-- object, else the item.
local function giver(game, by)
    if type(by) ~= "table" then return end
    local npc = firstId(by.NPC)
    local name = named(game, "NPC", npc)
    if name then
        local area = game.areaName(game.questieField("NPC", npc, "zoneID"))
        return area and area ~= name and name .. "  " .. PLACE .. area .. "|r" or name
    end
    return named(game, "Object", firstId(by.GameObject)) or named(game, "Item", firstId(by.Item))
end

local function questName(game, id)
    local name = named(game, "Quest", id)
    if name then return name end
    local quest = game.questieQuest(id)
    return quest and type(quest.name) == "string" and quest.name or nil
end

-- An objective's words: its own text, else what it asks for, by name.
local OBJECTIVE_KINDS = { monster = "NPC", killcredit = "NPC", object = "Object", item = "Item" }
local function objectiveText(game, objective)
    if type(objective) ~= "table" then return end
    if type(objective.Text) == "string" and objective.Text ~= "" then return objective.Text end
    local kind = OBJECTIVE_KINDS[objective.Type]
    return kind and named(game, kind, objective.Id)
end

function fromQuestie(model, id, game, words)
    local quest = id and game.questieQuest(id)
    if not quest then return end
    if not model.level and type(quest.level) == "number" and quest.level > 0 then model.level = quest.level end
    if not model.zone and type(quest.zoneOrSort) == "number" then model.zone = game.areaName(quest.zoneOrSort) end
    if #model.description == 0 and type(quest.objectivesText) == "table" then
        for _, text in ipairs(quest.objectivesText) do
            if type(text) == "string" and trim(text) ~= "" then model.description[#model.description + 1] = trim(text) end
        end
    end
    -- not on the quest: what it asks, unticked (ticked once it is done)
    if #model.objectives == 0 and type(quest.ObjectiveData) == "table" then
        for _, objective in ipairs(quest.ObjectiveData) do
            local text = objectiveText(game, objective)
            if text then
                model.objectives[#model.objectives + 1] = { left = text, right = "",
                    completed = (model.completed or model.ready) and true or false }
            end
        end
    end
    local said = {}
    for _, row in ipairs(model.where) do said[row.left] = true end
    for index, by in ipairs({ quest.Starts, quest.Finisher }) do
        local label = words.labels[index]
        local who = not said[label] and giver(game, by)
        if who then model.where[#model.where + 1] = { left = label, right = who } end
    end
    -- the quest before it and the one after, by name
    local before = firstId(quest.preQuestSingle)
    local after = type(quest.nextQuestInChain) == "number" and quest.nextQuestInChain > 0 and quest.nextQuestInChain
    local chain = { before = before and questName(game, before), after = after and questName(game, after) }
    if chain.before or chain.after then
        -- (2026-11-22) how many quests follow this one: Questie's next in
        -- chain, each in turn (a loop, or a very long one, stops it)
        local left, seen, on = 0, { [id] = true }, after
        while on and not seen[on] and left < 50 do
            seen[on], left = true, left + 1
            local following = game.questieQuest(on)
            local step = following and following.nextQuestInChain
            on = type(step) == "number" and step > 0 and step or nil
        end
        chain.left = left
        model.chain = chain
    end
    if quest.IsRepeatable == true then model.repeatable = true end
    -- the reputation it gives, ahead of the other rows
    if type(quest.reputationReward) == "table" then
        local rows = {}
        for _, pair in ipairs(quest.reputationReward) do
            local faction, amount = type(pair) == "table" and pair[1], type(pair) == "table" and pair[2]
            local name = game.factionName(faction)
            if name then
                -- the faction, and what it gives: under the Reputation heading
                local gain = type(amount) == "number" and amount ~= 0 and string.format("%+d", amount) or ""
                rows[#rows + 1] = { left = name, right = gain, rep = true, rightColor = REP_GAIN }
            end
        end
        for index = #rows, 1, -1 do table.insert(model.extras, 1, rows[index]) end
    end
end

-- (2026-11-22) The party members on the quest and how far each has got:
-- the game's own account first (its synced party progress), then Questie's
-- party sharing, then only whether a member has the quest. Each member is
-- { name, classFile, objectives = { objective rows }, done, total, ready };
-- nil when no one in the party is on it.
function partyOf(model, id, game)
    local members = game.partyMembers()
    if #members == 0 then return end
    local byName = {}
    for _, member in ipairs(members) do
        byName[member.name] = member
        byName[member.short] = byName[member.short] or member
    end
    local found = {}
    -- the game's: a member's name, then that member's objectives
    local current
    for _, line in ipairs(game.questPartyLines(id) or {}) do
        if line.name then
            local name = trim(line.name)
            local member = byName[name] or byName[name:match("^[^%-]+") or name]
            -- (a name not in the party: its objectives go nowhere)
            current = { objectives = {} }
            if member then found[member] = current end
        elseif current then
            current.objectives[#current.objectives + 1] = objectiveOf(trim(line.text), "", line.completed)
        end
    end
    -- Questie's: counts by objective, named as the quest names them
    local log = game.questieRemoteLog(id)
    local quest = log and game.questieQuest(id)
    for _, member in ipairs(log and members or {}) do
        local shared = not found[member] and (log[member.name] or log[member.short])
        if type(shared) == "table" then
            local entry = { objectives = {} }
            for index, objective in ipairs(shared) do
                if type(objective) == "table" then
                    local have, need = tonumber(objective.fulfilled), tonumber(objective.required)
                    local mine = model.objectives[index]
                    local text = mine and mine.left
                        or quest and type(quest.ObjectiveData) == "table" and objectiveText(game, quest.ObjectiveData[index])
                        or "#" .. index
                    entry.objectives[#entry.objectives + 1] = { left = text, right = have and need and (have .. "/" .. need)
                        or "", completed = objective.finished == true or (have ~= nil and need ~= nil and have >= need) }
                end
            end
            found[member] = entry
        end
    end
    local list = {}
    for _, member in ipairs(members) do
        local entry = found[member]
        -- on the quest, and nothing more known
        if not entry and game.unitOnQuest(member.unit, id) then entry = { objectives = {} } end
        if entry then
            local done = 0
            for _, objective in ipairs(entry.objectives) do
                if objective.completed then done = done + 1 end
            end
            entry.name, entry.classFile = member.short, member.classFile
            entry.done, entry.total = done, #entry.objectives
            entry.ready = entry.total > 0 and done == entry.total
            list[#list + 1] = entry
        end
    end
    if #list > 0 then return list end
end

-- The text after a label, trimmed: "" for the label alone; nil without it.
local function afterLabel(text, label)
    if startsWith(text, label) then return trim(text:sub(#trim(label) + 1)) end
end

-- A row from the data or from a font string, read the same way.
local function readRow(model, row, state)
    local text = trim(util.uncolored(row.left))
    local right = trim(util.uncolored(row.right or ""))
    if text == "" and right == "" then return end
    if not model.name then return readTitle(model, text) end
    -- (2026-11-22) the quest log's party lines ("Party members on this
    -- quest:", each member's name and objectives): the Party section reads
    -- the party itself, so they are left out here; MedalUI's clicks after
    -- them still count
    if text == PARTY_QUEST_STATUS_ON or text == PARTY_QUEST_STATUS_NONE then state.party = true return end
    if state.party and not ui.isKeyRow(row) then return end
    if state.label then
        model.extras[#model.extras + 1] = { left = state.label, right = text }
        state.label = nil
        return
    end
    local words = state.words
    local colon = words[": "]
    local label, value
    for _, name in ipairs(words.labels) do
        value = afterLabel(text, name .. colon)
        if value then label = name break end
    end
    local onQuest = afterLabel(text, words["You are on this quest"]) or afterLabel(text, QUEST_TOOLTIP_ACTIVE)
    local level = unformat(text, UNIT_LEVEL_TEMPLATE) or unformat(text, ITEM_MIN_LEVEL)
    if tonumber(level) and not model.level then
        model.level = tonumber(level)
    elseif TAGS[text] then
        model.tags[#model.tags + 1] = text
    elseif onQuest then
        model.active = true
        model.ready = onQuest:find("(" .. words.Complete .. ")", 1, true) ~= nil
        model.failed = onQuest:find("(" .. words.Failed .. ")", 1, true) ~= nil
    elseif startsWith(text, words["You have completed this quest"]) then
        model.completed = true
    elseif startsWith(text, words["This quest is repeatable"]) then
        model.repeatable = true
    -- The headings over the objectives; the panel has its own caption.
    elseif startsWith(text, words["You have not done this quest"]) or text == words.Objectives
        or text == OBJECTIVES_LABEL or text == QUEST_TOOLTIP_REQUIREMENTS or startsWith(text, words["Your progress"]) then
        return
    elseif afterLabel(text, words.Instance .. colon) then
        model.zone = afterLabel(text, words.Instance .. colon)
    elseif row.objective or text:match("^%-") or text:match("%d+%s*/%s*%d+%s*$") then
        model.objectives[#model.objectives + 1] = objectiveOf(text, right, row.completed)
    elseif label then
        if value ~= "" then
            model.extras[#model.extras + 1] = { left = label, right = value }
        else
            -- "Completed on:" puts its date on the next line.
            state.label = label
        end
    elseif isRed(codeColor(row.left) or row.textColor) then
        model.extras[#model.extras + 1] = { left = text, right = right, color = FAILED_COLOR }
    -- The description comes before the objectives; long lines after them are
    -- other addons'.
    -- MedalUI's clicks ("Shift + (mouse) Link"), two to a line: the key band
    elseif ui.isKeyRow(row) then
        model.keys = model.keys or {}
        model.keys[#model.keys + 1] = { left = row.left or "", right = row.right or "" }
    elseif right == "" and util.width(text) >= 30 and #model.objectives == 0 and #model.extras == 0 then
        model.description[#model.description + 1] = text
    else
        -- A color code on the line outranks the font's color, dimmed as other addons' rows are.
        local code = codeColor(row.left)
        local color = code and { code[1] * .85, code[2] * .85, code[3] * .85 } or row.color
        model.extras[#model.extras + 1] = { left = text, right = right, color = color, rightColor = row.rightColor }
    end
end

-- A quest's marker on the world map (the game's quest pin): its quest.
local function mapPinQuest(owner)
    if not util.canModify(owner) or type(owner.GetQuestID) ~= "function" or type(owner.GetMap) ~= "function" then
        return
    end
    local map = util.call(owner.GetMap, owner)
    if map == nil or map ~= WorldMapFrame then return end
    local id = util.number((util.call(owner.GetQuestID, owner)))
    return id and id > 0 and id or nil
end

-- The marker's tooltip names only what is left to do (nothing, once the
-- quest is ready): every objective from the quest log, ticked as it stands.
local function fromLog(model, questID, game)
    local progress = game.questProgress(questID)
    if not progress then return end
    model.active, model.ready = true, progress.ready
    if #progress.objectives == 0 then return end
    model.objectives = {}
    for _, objective in ipairs(progress.objectives) do
        model.objectives[#model.objectives + 1] = objectiveOf(trim(util.uncolored(objective.text)), "",
            objective.finished)
    end
end

local function readQuest(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { description = {}, objectives = {}, tags = {}, extras = {} }
    local lineIndices, state = {}, { words = questieWords(game) }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            lineIndices[line.lineIndex] = true
            local color = tooltipData.colorOf(line.leftColor)
            local completed = line.completed
            if isSecret(completed) then completed = nil end
            readRow(model, {
                left = left,
                right = right,
                color = color,
                textColor = color,
                rightColor = tooltipData.colorOf(line.rightColor),
                objective = LINE.QuestObjective and line.type == LINE.QuestObjective,
                completed = completed,
            }, state)
        end
    end
    local appended = tooltipData.appendedRows(tooltip, lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do readRow(model, row, state) end
    if not model.name or model.name == "" then return end
    local id = readable(data.id)
    if id and mapPinQuest(util.call(tooltip.GetOwner, tooltip)) == id then fromLog(model, id, game) end
    return completeModel(model, id, game)
end

-- (2026-11-22) The chips under the name, as few words as can be: "LvL" and
-- the level (not the level it needs: Questie's figure, of no use on a quest
-- already taken), a glyph for where the quest
-- stands (with the objectives done while it is under way), a chain with the
-- quests still to come after it. Its tags keep their words.
-- (2026-11-22) The experience as few figures as can be: "850", "2.4k", "12k".
local function xpText(xp)
    if xp < 1000 then return tostring(xp) end
    local k = xp / 1000
    if k >= 10 then return string.format("%dk", math.floor(k + .5)) end
    return (string.format("%.1fk", k):gsub("%.0k$", "k"))
end

local function badges(model)
    local list = {}
    if model.level then list[#list + 1] = { "LvL " .. model.level, model.color, keepCase = true } end
    -- the reward's experience, after its level: "ExP 2.4k"
    if model.xp then list[#list + 1] = { "ExP " .. xpText(model.xp), PARCHMENT, keepCase = true } end
    for _, tag in ipairs(model.tags) do list[#list + 1] = { tag, PARCHMENT } end
    if model.completed then
        list[#list + 1] = { "", DONE_COLOR, "completed" }
    elseif model.failed then
        list[#list + 1] = { "", FAILED_COLOR, "failed" }
    elseif model.ready then
        list[#list + 1] = { "", DONE_COLOR, "ready" }
    elseif model.active then
        local done, total = 0, #model.objectives
        for _, objective in ipairs(model.objectives) do
            if objective.completed then done = done + 1 end
        end
        list[#list + 1] = { total > 0 and (done .. "/" .. total) or "", QUEST_GOLD, "progress" }
    end
    local chain = model.chain
    if chain then
        list[#list + 1] = { (chain.left or 0) > 0 and ("+" .. chain.left) or "", CHAIN_TAG, "chain" }
    end
    if model.repeatable then list[#list + 1] = { "", REPEAT_COLOR, "repeat" } end
    return list
end

-- The description reads as the quest giver's words.
local function quoted(model)
    local list = {}
    for index, text in ipairs(model.description) do
        if index == 1 then text = "\226\128\156" .. text end
        if index == #model.description then text = text .. "\226\128\157" end
        list[#list + 1] = text
    end
    return list
end

local function checkbox(panel, y, done, size)
    local top = y + math.max(0, math.floor((size - CHECK_SIZE) / 2)) + 1
    local px = ui.pixel(panel)
    local border = ui.acquireTexture(panel, nil, 0)
    border:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -ui.snap(panel, top))
    border:SetSize(CHECK_SIZE, CHECK_SIZE)
    local edge = done and DONE_COLOR or PARCHMENT
    if panel.parchment then edge = { .35, .21, .10 } end
    border:SetVertexColor(edge[1] * .7, edge[2] * .7, edge[3] * .7, .9)
    local fill = ui.acquireTexture(panel, nil, 1)
    fill:SetPoint("TOPLEFT", border, "TOPLEFT", px, -px)
    fill:SetSize(CHECK_SIZE - 2 * px, CHECK_SIZE - 2 * px)
    if done then
        fill:SetVertexColor(DONE_COLOR[1] * .45, DONE_COLOR[2] * .45, DONE_COLOR[3] * .45, 1)
        local mark = ui.acquireTexture(panel, "Interface\\Buttons\\UI-CheckBox-Check", 2)
        mark:SetPoint("CENTER", border, "CENTER", 1, 1)
        mark:SetSize(CHECK_SIZE + 6, CHECK_SIZE + 6)
        if panel.parchment then mark:SetVertexColor(.11, .085, .055, 1)
        else mark:SetVertexColor(1, 1, 1, 1) end
    else
        fill:SetVertexColor(.08, .07, .06, panel.parchment and 0 or 1)
    end
end

-- The objectives under their caption, each with a checkbox.
local function objectivesSection(model, styles, after)
    local style = styles.questObjectives
    return {
        kind = "custom",
        measure = function(panel)
            local need = 0
            for _, row in ipairs(model.objectives) do
                need = math.max(need, ui.rowWidth(panel, row, style) + OBJECTIVE_INDENT)
            end
            return need
        end,
        draw = function(panel, y)
            y = ui.band(panel, y, OBJECTIVES_LABEL, styles.questCaption, SECTION_HUES.objectives,
                after and BAND_BEFORE or 0)
            for _, row in ipairs(model.objectives) do
                checkbox(panel, y, row.completed, style.size)
                y = ui.drawRow(panel, row, y, style, row.completed and DONE_COLOR or colors.objective,
                    OBJECTIVE_INDENT, 5)
            end
            return y
        end,
    }
end

-- (2026-11-22) The party under its own band: each member in the class's
-- colour, with how far they have got on the right (Ready, the objectives
-- done of all, or only that they have it), and the objectives of one not
-- yet done under the name, each with its checkbox.
local function partyRows(model)
    local rows = {}
    for _, member in ipairs(model.party) do
        local right, rightColor
        if member.ready then
            right, rightColor = L["Ready"], DONE_COLOR
        elseif member.total > 0 then
            right, rightColor = member.done .. "/" .. member.total, QUEST_GOLD
        else
            right, rightColor = L["On the quest"], colors.detail
        end
        local game = ns.Game
        local color = game and (game.customClassColor(member.classFile) or game.classColor(member.classFile))
        rows[#rows + 1] = { row = { left = member.name, right = right, color = color or colors.title,
            rightColor = rightColor } }
        if not member.ready then
            for _, objective in ipairs(member.objectives) do rows[#rows + 1] = { row = objective, objective = true } end
        end
    end
    return rows
end

local function partySection(model, styles, after)
    local style = styles.questObjectives
    return {
        kind = "custom",
        measure = function(panel)
            local need = 0
            for _, entry in ipairs(partyRows(model)) do
                need = math.max(need, ui.rowWidth(panel, entry.row, style) + (entry.objective and OBJECTIVE_INDENT or 0))
            end
            return need
        end,
        draw = function(panel, y)
            y = ui.band(panel, y, PARTY or L["Party"], styles.questCaption, SECTION_HUES.party,
                after and BAND_BEFORE or 0)
            for _, entry in ipairs(partyRows(model)) do
                local row = entry.row
                if entry.objective then
                    checkbox(panel, y, row.completed, style.size)
                    y = ui.drawRow(panel, row, y, style, row.completed and DONE_COLOR or colors.objective,
                        OBJECTIVE_INDENT, 5)
                else
                    y = ui.drawRow(panel, row, y, style, colors.title, 0, 5)
                end
            end
            return y
        end,
    }
end

-- What the panel shows, for Panel/Render.lua to draw.
-- (2026-11-22) The hint to hold the details key for the rest of the quest
-- (where, chain, reputation), in Questie's own words when it is there, as its
-- tooltips say it. (Asked only when something is held back, so the key is
-- Shift: the options offer it or Always.)
local function holdHint()
    local word = ns.Game and ns.Game.questieText and ns.Game.questieText("Hold Shift")
    -- (questieText hands the phrase back without Questie: ours, translated)
    if type(word) == "string" and word ~= "" and word ~= "Hold Shift" then return word end
    return L["Hold Shift"]
end

-- (2026-11-22) MedalUI's right click on a quest's map marker (its page), as
-- its key glyphs say it, opposite the hint
local function pageKey()
    return "|TInterface\\AddOns\\MedalUI\\media\\strips\\mouse-right:16:16:0:0:32:32:5:27:5:27|t " .. L["Page"]
end

-- details: the rest of the quest shows (the key held, or always); without it,
-- the hint to hold the key in its place. page: a right click opens its page.
local function questView(model, details, page)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local header = { { text = model.name, style = styles.questTitle, color = colors.title, gap = 3 } }
    if model.zone then header[#header + 1] = { text = model.zone, style = styles.questInfo, color = colors.detail, gap = 3 } end
    header[#header + 1] = { badges = badges(model), style = styles.questBadges, before = 3, gap = 4 }

    local sections = {}
    local paragraphs = quoted(model)
    if #paragraphs > 0 then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "prose", sentences = paragraphs,
            style = styles.questText, color = ui.FLAVOR_GOLD, gap = 5 }
    end
    if #model.objectives > 0 then
        sections[#sections + 1] = objectivesSection(model, styles, #sections > 0)
    end
    -- the party's progress, always (not held back with the details)
    if model.party and #model.party > 0 then
        sections[#sections + 1] = partySection(model, styles, #sections > 0)
    end
    -- where it is, and the quests either side of it, each under its caption
    local function captioned(label, hue)
        return { band = label, style = styles.questCaption, color = hue, before = #sections > 0 and BAND_BEFORE or 0 }
    end
    -- where, the chain and the reputation only with the details key held
    local held = 0
    local function shown(count)
        if count == 0 then return false end
        if details then return true end
        held = held + 1
        return false
    end
    if model.where and shown(#model.where) then
        sections[#sections + 1] = { separator = captioned(L["Where"], SECTION_HUES.where), kind = "rows", rows = model.where,
            style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    local chain = model.chain
    if chain and shown((chain.before or chain.after) and 1 or 0) then
        local rows = {}
        if chain.before then rows[#rows + 1] = { left = "\194\171  " .. chain.before, color = CHAIN_COLOR } end
        rows[#rows + 1] = { left = "\226\128\162  " .. model.name, color = QUEST_GOLD }
        if chain.after then rows[#rows + 1] = { left = "\194\187  " .. chain.after, color = CHAIN_COLOR } end
        sections[#sections + 1] = { separator = captioned(L["Chain"], SECTION_HUES.chain), kind = "rows", rows = rows,
            style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    -- the reputation it gives under its own heading; the other rows after it
    local reputation, others = {}, {}
    for _, row in ipairs(model.extras) do
        if row.rep then reputation[#reputation + 1] = row else others[#others + 1] = row end
    end
    if shown(#reputation) then
        sections[#sections + 1] = { separator = captioned(REPUTATION or L["Reputation"], SECTION_HUES.reputation),
            kind = "rows", rows = reputation, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    if #others > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 4 },
            kind = "rows", rows = others, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    -- the hint to hold the key, then MedalUI's clicks
    local foot = {}
    local hint = held > 0 and holdHint()
    -- (loose: not in the clicks' grid below it, the key at the right edge)
    if hint or page then foot[1] = { left = hint or "", right = page and pageKey() or "", loose = true } end
    for _, row in ipairs(model.keys or {}) do foot[#foot + 1] = row end
    local footer = #foot > 0 and { rows = foot, style = ui.styleOf("objectPrices"), color = colors.caption,
        gap = 3 } or nil
    return {
        tooltipType = "quest",
        color = PARCHMENT,
        tint = PARCHMENT,
        strength = TINT_STRENGTH,
        icon = ns.option("iconQuests") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = header,
        sections = sections,
        footer = footer,
    }
end

local function renderQuest(panel, tooltip, model)
    local details = panel.isPreview or panel.allDetails or ns.detailsKeyDown()
    -- (on the world map's marker, when MedalUI opens the quest's page from it)
    local page = false
    if not panel.isPreview and ns.Game and ns.Game.mapPage then
        local id = mapPinQuest(util.call(tooltip.GetOwner, tooltip))
        page = id ~= nil and ns.Game.mapPage(id)
    end
    ui.renderView(panel, tooltip, questView(model, details and true or false, page))
end

ui.questModel = function(fields, questID)
    for _, list in ipairs({ "description", "objectives", "tags", "extras" }) do
        fields[list] = fields[list] or {}
    end
    return completeModel(fields, questID, ns.Game)
end
ns.QuestPin = { quest = mapPinQuest, read = function(tooltip, id)
    return readQuest(tooltip, { id = id, lines = {}, fromLines = true }, ns.Game)
end }
ui.defineTooltipType(QUEST, { read = readQuest, render = renderQuest, key = questKey, option = "questPanels" })

local function linkedQuest(link)
    if isSecret(link) or type(link) ~= "string" then return end
    local id = link:match("^questie:(%d+)") or link:match("^quest:(%d+)")
    return id and tonumber(id)
end

local function hasQuestData(tooltip)
    local data = util.call(tooltip.GetTooltipData, tooltip)
    return type(data) == "table" and not isSecret(data.type) and data.type == QUEST
end

-- Questie fills the tooltip with lines itself, for its own links and the game's.
local function drawQuestie(tooltip, id)
    if util.canModify(tooltip) and tooltip:IsShown() and tooltip:NumLines() > 0 and not hasQuestData(tooltip) then
        if ns.Hooks then ns.Hooks.renderLines(tooltip, QUEST, id) end
    end
end

hooksecurefunc("SetItemRef", function(link)
    local id = linkedQuest(link)
    if id then drawQuestie(ItemRefTooltip, id) end
end)

-- The world map's quest log fills the tooltip with lines too, from its title
-- buttons; their quest is the button's.
local function questLogButton(owner)
    local contents = QuestScrollFrame and QuestScrollFrame.Contents
    return contents and util.canModify(owner) and util.call(owner.GetParent, owner) == contents
end

-- Questie may hook the chat frames before or after this file, so its Show is
-- caught too. Other addons add their lines to the quest log's and show it again.
local hovered
local drawing = false
hooksecurefunc(GameTooltip, "Show", function(tooltip)
    if drawing or not util.canModify(tooltip) then return end
    local owner = util.call(tooltip.GetOwner, tooltip)
    local id
    if hovered and owner == hovered.frame then
        id = hovered.id
    elseif questLogButton(owner) then
        id = readable(owner.questID)
    elseif mapPinQuest(owner) then
        -- (2026-11-22) a quest's marker on the world map: the game's lines
        id = mapPinQuest(owner)
    else
        return
    end
    drawing = true
    pcall(drawQuestie, tooltip, id)
    drawing = false
end)
for index = 1, NUM_CHAT_WINDOWS or 10 do
    local frame = _G["ChatFrame" .. index]
    if util.canModify(frame) then
        frame:HookScript("OnHyperlinkEnter", function(self, link)
            local id = not isSecret(link) and type(link) == "string" and link:match("^questie:(%d+)")
            hovered = id and { frame = self, id = tonumber(id) } or nil
            if hovered and util.canModify(GameTooltip)
                and util.call(GameTooltip.GetOwner, GameTooltip) == self then drawQuestie(GameTooltip, hovered.id) end
        end)
        frame:HookScript("OnHyperlinkLeave", function() hovered = nil end)
    end
end
