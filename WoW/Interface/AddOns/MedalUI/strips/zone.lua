-- The side panel's Zone tab: the minimap on the left, and the quests of the
-- zone you are in on the right.
--
-- The minimap is the game's own, moved, not a copy: its pings, zoom and pins
-- come along. While the tab is up it lives in a well here (lent by
-- console/minimap.lua's ns.LendMinimap), and its place on the console, or
-- in the corner, stands empty (black) meanwhile. It goes back when another
-- tab is picked or the panel hides.
--
-- Over the list, the zone's name, and the subzone with where in it you
-- stand. Then a row a quest: those the log files under this zone, and on
-- retail those the game marks on this map too; the waypoint's quest heads
-- the list always, from whatever zone. The rest in the log's order, or by
-- the tab's sort button nearest first (zoneSort, quests/source.lua's
-- Q.ByDistance: the game's objective markers on the map). A row is the quest's title,
-- its progress over all its objectives ("13/30", the counts read from
-- them) and a tick once it is complete; one not tracked is striped, as the
-- quest log stripes it (quests/log.lua), and a gold hairline above each
-- quest but the first parts it from the objectives over it. An objective's line is shortened to fit: a kill's "slain"
-- becomes a sword before it, and a name too long gives its first word as
-- an initial ("D. Reclaimer"). A quest clicks as in the quest log and the
-- tracker (Q.Click, quests/source.lua; its tooltip's key lines say how):
-- its page, Shift a link, Ctrl the waypoint (its lines washed blue, its
-- distance after its title), Alt Questie's focus, right click tracked or
-- not, middle click the map; an objective's row the same, but Shift puts
-- its line in the chat box. Its + or - on the left, a button of its own,
-- opens its objectives under it or closes them. The waypoint's quest has
-- them open without a click (2026-11-23): closed by hand, they stay closed
-- while it is the waypoint's.
--
-- A quest with a usable item (quests/source.lua's q.item, as the tracker's)
-- ends its open objectives with it: its icon, its name and how many you
-- carry. A click uses it: a secure button over the line, on a layer of its
-- own on the strip, placed by numbers out of combat (ns.window.Over) and
-- hidden in combat by the game's driver, as the rows may move meanwhile.
--
-- (2026-11-23) The sort button's third choice, Guide (quests/guide.lua):
-- the list becomes what to do next for experience, the log's quests from
-- anywhere and quests to take near you ("!" before them, their experience
-- on the right), in the Guide's order, looked at again every RESORT
-- seconds out of combat. A quest to take clicks to the waypoint at its
-- giver. With zoneGuideWaypoint the waypoint follows the list's head (or
-- the row the controls stepped it to), unless you set one yourself (until
-- you clear it). The waypoint's row is not lifted to the top here.
--
-- The column: the tab's controls (strips/zonecontrols.lua: a drawer over
-- the panel with the list's quest items, the list's text size, where you
-- stand shown or not, and the Guide's quests to take and steps), the
-- minimap's tracking, the world map, the sort; at the foot, every quest
-- here tracked (or, while they all are, none). (2026-11-23: the controls
-- took zoom in and zoom out's place: the mouse wheel on the map zooms.)
--
-- The list's text is zoneFontSize points, its rows as tall as that needs;
-- the coordinates after the subzone go with zoneCoords.
local _, ns = ...
local Tr = ns.L

local PARTS = ns.media .. "strips\\"
local ROW, LINE, HEAD, GAP = 18, 13, 22, 1    -- a quest's row and an objective's line: at 11 points (Sized)
local SIZE, SIZE_MIN, SIZE_MAX = 11, 9, 14   -- the list's text, in points (zoneFontSize)
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local SWORD = "Interface\\CURSOR\\Attack"    -- the game's attack cursor
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }
local STRIPES, RULE = 0.3, 0.6      -- an untracked quest's stripes (the quest log's); the hairline's alpha

local body, well, hold, list, title, place, empty
local rows, quests, lines = {}, {}, {}
local open = {}                 -- quest ids whose objectives are shown
local first, shown = 0, 0
local layer                     -- the items' secure buttons (layer.buttons), over their lines

-- ------------------------------------------------------------- the zone
local function ZoneName()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

local function MapID()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

-- The subzone, and where in the zone's map you stand (none in an instance).
local function Place()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local map, at = MapID(), ""
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if pos then
        local x, y = pos:GetXY()
        if x and y and (x > 0 or y > 0) and ns.db.zoneCoords ~= false then
            at = string.format("%.0f, %.0f", x * 100, y * 100)
        end
    end
    if sub ~= "" and at ~= "" then return sub .. "  " .. at end
    return sub ~= "" and sub or at
end

-- The log's quests here: its heading is this zone (or the map's name for
-- it), or the game marks it on this map.
local rank = {}                 -- the distance sort's last order
local RESORT = 2                -- seconds between looks at the distances (sorted by them)
local function Distance() return ns.db.zoneSort == "distance" end
local function Guide() return ns.db.zoneSort == "guide" and ns.questGuide ~= nil end
local fresh                     -- the Guide's plan, looked at by Moved and not drawn yet

-- The Guide's list: its plan as it is, the waypoint's row where it falls
-- (2026-11-23, the user's: a step moves the waypoint, never the rows); and
-- the entry the waypoint is to follow (the one stepped to, or the head)
local function Guided()
    local plan = fresh or ns.questGuide.Plan(InCombatLockdown())
    fresh = nil
    return plan, ns.questGuide.Head(plan)
end

-- the row the waypoint is at: a quest to take by its giver's place
local function OnWay(q)
    local W = ns.waypoint
    if q.pick then
        local p = q.guide.where
        return p ~= nil and W.IsPoint(p.map, p.x, p.y)
    end
    return W.Is(q.id)
end

-- (2026-11-23, the user's) The waypoint's quest shows its objectives
-- without a click; its - closes them while it stays the waypoint's (shut),
-- and a quest opened by hand stays open as before.
local shut                      -- the waypoint's quest, closed by hand
local function Shown(q)
    if open[q.id] then return true end
    return not q.pick and shut ~= q.id and OnWay(q)
end

local function Here()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return {} end
    if Guide() then return Guided() end
    local names, marked = { [ZoneName()] = true }, {}
    local map = MapID()
    local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    -- (2026-11-22) in an instance with no map of its own (Forever's own
    -- dungeons), the best map is the zone outside: its name and its marked
    -- quests are not this place's, so only the log's heading counts. An
    -- instance's own dungeon map (mapType 4) still does.
    local inside = IsInInstance and IsInInstance()
    if inside and not (info and info.mapType == 4) then map, info = nil, nil end
    if info and info.name then names[info.name] = true end
    if map and C_QuestLog.GetQuestsOnMap then
        for _, e in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
            if e.questID then marked[e.questID] = true end
        end
    end
    -- the waypoint's quest first, always, wherever it is; the rest in the
    -- log's order, or nearest first (zoneSort; in combat the last order)
    local way = ns.waypoint and ns.waypoint.Quest()
    local out, lead = {}, nil
    for _, q in ipairs(ns.questSource.Log()) do
        if q.id == way then
            lead = q
        elseif names[q.zone] or marked[q.id] then
            table.insert(out, q)
        end
    end
    if Distance() then out, rank = ns.questSource.ByDistance(out, rank, InCombatLockdown()) end
    if lead then table.insert(out, 1, lead) end
    return out
end

-- ------------------------------------------------------------- progress
-- (an objective's count and words: quests/source.lua's Q.Count, Q.Words)
local function Count(o) return ns.questSource.Count(o) end
local function Words(o) return ns.questSource.Words(o) end

-- An objective's words, shortened for its line: "... slain" (or killed)
-- loses the word for a sword before the line; and when it is still too long
-- for room, a name of two words or more gives its first as an initial
-- ("Dragonmaw Reclaimer" -> "D. Reclaimer"). The words, and whether a sword
-- (in another language, the words kept: a monster's objective has its sword).
local ENGLISH = (GetLocale and GetLocale() or "enUS"):match("^en") ~= nil
local function Short(text, room, fs, kind)
    local killed = text:match("^(.-)%s+[Ss]lain$") or text:match("^(.-)%s+[Kk]illed$")
    if killed then text = killed end
    local sword = killed ~= nil or kind == "monster" and not ENGLISH
    fs:SetText(text)
    if room > 0 and (fs:GetStringWidth() or 0) > room then
        local initial, rest = text:match("^(%a)[%a'%-]*%s+(.+)$")
        if initial then text = initial .. ". " .. rest end
    end
    return text, sword
end

local function Progress(q)
    local have, need = 0, 0
    for _, o in ipairs(q.objectives) do
        local a, b = Count(o)
        have, need = have + math.min(a, b), need + b
    end
    return have, need
end

-- ---------------------------------------------------------------- items
local function ItemName(id)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and GetItemInfo then name = GetItemInfo(id) end
    return name or Tr["Quest item"]
end

local function ItemIcon(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    if not icon and GetItemIcon then icon = GetItemIcon(id) end
    return icon
end

local function ItemCount(id)
    return C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
end

local function ItemTip(owner, id, hint)
    ns.side.Beside(owner)
    GameTooltip:SetItemByID(id)
    if hint then GameTooltip:AddLine(hint, unpack(GOLD_D)) end
    GameTooltip:Show()
end

local function Secure(i)
    local b = layer.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "MedalUIZoneItem" .. i, layer, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.12)
    b:SetScript("OnEnter", function(self)
        if self.item then ItemTip(self, self.item, Tr["Click: use it."]) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    layer.buttons[i] = b
    return b
end

-- Out of combat only: a button over each item line shown, the rest away;
-- the layer hidden in combat while any is out.
local function PlaceItems()
    if InCombatLockdown() then return end
    if not layer then
        layer = CreateFrame("Frame", "MedalUIZoneItems", ns.strips[1])
        layer:SetFrameStrata("LOW")
        layer:SetAllPoints(ns.strips[1])
        layer.buttons = {}
    end
    local n = 0
    if body and body:IsVisible() then
        for _, r in ipairs(rows) do
            if r:IsShown() and r.line and r.line.item then
                local b = Secure(n + 1)
                if ns.window.Over(b, r) then
                    n = n + 1
                    b.item = r.line.item
                    b:SetAttribute("item", "item:" .. b.item)
                    b:Show()
                end
            end
        end
    end
    for i = n + 1, #layer.buttons do
        local b = layer.buttons[i]
        b.item = nil
        b:SetAttribute("item", nil)
        b:Hide()
    end
    if n > 0 then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(layer, "visibility")
        layer:Hide()
    end
end

-- ----------------------------------------------------------------- rows
-- experience as the quest tooltips' chip: 850, 2.4k, 12k
local function XPText(xp)
    if xp < 1000 then return tostring(xp) end
    if xp < 10000 then return (string.format("%.1fk", xp / 1000):gsub("%.0k$", "k")) end
    return string.format("%dk", math.floor(xp / 1000))
end

local function LevelColor(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    return c and { c.r, c.g, c.b } or ns.colors.text
end

-- A quest to take: who gives it, its experience, its chain, how far
local function PickTip(r, q)
    local g = q.guide
    local spec = { title = q.title, color = LevelColor(q.level),
        { "body", format(Tr["Level %d"], q.level) .. (g.xp > 0 and ("  \194\183  " .. format(Tr["%s experience"],
            XPText(g.xp))) or "") } }
    if g.npc then table.insert(spec, { "body", format(Tr["Given by %s."], g.npc) }) end
    if g.steps > 0 then
        table.insert(spec, { "body", g.chainXP > 0 and format(Tr["A chain: %d more after it, %s experience."],
            g.steps, XPText(g.chainXP)) or format(Tr["A chain: %d more after it."], g.steps) })
    end
    if g.yards then table.insert(spec, { "body", format(Tr["%d yd away."], g.yards) }) end
    if ns.questGuide.Ignored(q) then
        table.insert(spec, { "body", Tr["Ignored: the Guide's waypoint passes it by."] })
    end
    table.insert(spec, { "key", "left", nil, Tr["Waypoint"] })
    table.insert(spec, { "key", "right", "Ctrl", ns.questGuide.Ignored(q) and Tr["Unignore"] or Tr["Ignore"] })
    ns.Tip(r, ns.side.Beside, spec)
end

local function Tip(r)
    local q = r.line and r.line.quest
    if not q then return end
    if q.pick then PickTip(r, q) return end
    if r.line.item then
        -- (in combat: the secure button is away, the line under it shows)
        ItemTip(r, r.line.item, Tr["Usable here after combat."])
        return
    end
    -- (2026-11-21) the quest's own tooltip, as the tracker's (quests/tracker.lua):
    -- the game's link, which the tooltips companion draws as the quest's
    -- full panel, an item objective's drops, and the clicks under it
    local link = GetQuestLink and GetQuestLink(q.id)
    if link then
        ns.side.Beside(r)
        GameTooltip:SetHyperlink(link)
        if r.line.objective and ns.questDrops then ns.questDrops.AddTooltip(GameTooltip, q.id, r.line.objective) end
        ns.TipKeys(ns.questSource.Keys(q, r.line.objective))
        GameTooltip:Show()
        return
    end
    -- no link (a client without them): what the row knows
    local state = q.state == 1 and Tr["Complete."] or q.state == -1 and Tr["Failed."] or nil
    local spec = { title = q.title,
        { "body", format(Tr["Level %d"], q.level) .. (state and ("  \194\183  " .. state) or "") },
        { "body", q.tracked and Tr["Tracked."] or Tr["Not tracked."] } }
    for _, k in ipairs(ns.questSource.Keys(q, r.line.objective)) do table.insert(spec, k) end
    ns.Tip(r, ns.side.Beside, spec)
end

local Refresh, Moved, SORT

-- Under the pointer, a quest's rows all lit together (its title, its
-- objectives, its item), and the row itself glowing over that, as the
-- quest tracker's (character/list.lua); nil: none lit
local litQuest
local function Light(id)
    litQuest = id
    for _, r in ipairs(rows) do
        r.lit:SetShown(id ~= nil and r.line ~= nil and r.line.quest ~= nil and r.line.quest.id == id)
    end
end

local function Row()
    local r = CreateFrame("Button", nil, list)
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r.lit = r:CreateTexture(nil, "BACKGROUND", nil, 4)
    r.lit:SetAllPoints()
    r.lit:SetColorTexture(1, 1, 1, 0.06)
    r.lit:Hide()
    r.glow = r:CreateTexture(nil, "HIGHLIGHT")
    r.glow:SetAllPoints()
    r.glow:SetColorTexture(1, 1, 1, 0.06)
    r.fold = ns.Text(r, 11)
    r.fold:SetPoint("LEFT", 3, 0)
    r.fold:SetTextColor(unpack(GOLD_D))
    -- the + or -: its own button, opening the quest's objectives or closing them
    r.folder = CreateFrame("Button", nil, r)
    r.folder:SetPoint("TOPLEFT")
    r.folder:SetPoint("BOTTOMLEFT")
    r.folder:SetWidth(13)
    r.folder:SetScript("OnClick", function()
        local q = r.line and r.line.quest
        if not q then return end
        if Shown(q) then
            open[q.id] = nil
            if Shown(q) then shut = q.id end
        else
            open[q.id], shut = true, nil
        end
        Refresh()
        if GameTooltip:GetOwner() == r.folder then r.folder:GetScript("OnEnter")(r.folder) end
    end)
    r.folder:SetScript("OnEnter", function(self)
        local q = r.line and r.line.quest
        if not q then return end
        Light(q.id)
        r.fold:SetTextColor(unpack(GOLD))
        ns.Tip(self, ns.side.Beside, { title = Shown(q) and Tr["Hide its objectives."] or Tr["Show its objectives."],
            color = ns.colors.white, wrap = true })
    end)
    r.folder:SetScript("OnLeave", function()
        Light(nil)
        r.fold:SetTextColor(unpack(GOLD_D))
        GameTooltip:Hide()
    end)
    ns.side.PassWheel(r.folder)
    r.count = ns.Text(r, 11)
    r.count:SetPoint("RIGHT", -3, 0)
    r.tick = r:CreateTexture(nil, "ARTWORK")
    r.tick:SetSize(12, 12)
    r.tick:SetPoint("RIGHT", -3, 0)
    r.tick:SetTexture(TICK)
    -- an untracked quest: striped, as the quest log stripes it
    r.stripes = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    r.stripes:SetAllPoints()
    r.stripes:SetTexture(PARTS .. "stripes", "REPEAT", "REPEAT")
    r.stripes:SetHorizTile(true)
    r.stripes:SetVertTile(true)
    r.stripes:SetVertexColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    r.stripes:SetAlpha(STRIPES)
    -- above a quest but the first: a hairline, in the gap over it
    r.rule = r:CreateTexture(nil, "BORDER")
    r.rule:SetPoint("BOTTOMLEFT", r, "TOPLEFT", 0, 0)
    r.rule:SetPoint("BOTTOMRIGHT", r, "TOPRIGHT", 0, 0)
    r.rule:SetHeight(1)
    r.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], RULE)
    -- a kill objective's sword, before the line's indent
    r.sword = r:CreateTexture(nil, "ARTWORK")
    r.sword:SetSize(12, 12)
    r.sword:SetPoint("LEFT", 5, 0)
    r.sword:SetTexture(SWORD)
    r.sword:SetDesaturated(true)
    r.sword:SetVertexColor(unpack(GOLD_D))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 20, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.text = ns.Text(r, 11)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    r:SetScript("OnClick", function(self, mouse)
        local q = self.line and self.line.quest
        if not q or self.line.item then return end
        -- a quest to take: the waypoint at its giver, or away
        if q.pick then
            -- Ctrl+right-click: ignored, or not (stays put; the Guide's
            -- waypoint passes it by)
            if mouse == "RightButton" and IsControlKeyDown() then
                ns.questGuide.Ignore(q)
                Refresh()
                if GameTooltip:IsOwned(self) then Tip(self) end
                return
            end
            local p = q.guide.where
            if mouse ~= "LeftButton" or not p then return end
            if ns.waypoint.IsPoint(p.map, p.x, p.y) then
                ns.waypoint.ClearPoint()
            else
                ns.waypoint.Point(p.map, p.x, p.y)
            end
            return
        end
        -- (a waypoint is drawn again by its change); an objective's
        -- Shift-click puts its line in the chat box
        if ns.questSource.ClickObjective(q, self.line.objective, mouse) ~= "track" then return end
        Refresh()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    r:SetScript("OnEnter", function(self)
        Light(self.line and self.line.quest and self.line.quest.id)
        Tip(self)
    end)
    r:SetScript("OnLeave", function()
        Light(nil)
        GameTooltip:Hide()
    end)
    ns.side.PassWheel(r)
    return r
end

-- The waypoint's quest: all its lines in its wash.
local function Wash(r, q)
    local p = q.pick and q.guide.where
    if q.pick and not (p and ns.waypoint.IsPoint(p.map, p.x, p.y)) or not q.pick and not ns.waypoint.Is(q.id) then
        return false
    end
    r.stripe:SetColorTexture(unpack(ns.waypoint.WASH))
    r.stripe:Show()
    return true
end

-- A quest's row, or one of its objectives under it.
-- the list's text size: the rows' heights follow it, its rows' fonts too
local function Size()
    local n = tonumber(ns.db.zoneFontSize) or SIZE
    return math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(n)))
end
local function Sized(r)
    local n = Size()
    if r.size == n then return end
    r.size = n
    for _, fs in ipairs({ r.text, r.count, r.fold }) do fs:SetFont(ns.font, n, "") end
end

local function Fill(r, line, odd, top)
    r.line = line
    Sized(r)
    r.stripes:Hide()
    r.rule:Hide()
    r.folder:Hide()
    local q, o, item = line.quest, line.objective, line.item
    r.lit:SetShown(litQuest ~= nil and q ~= nil and q.id == litQuest)
    r.text:ClearAllPoints()
    r.far = nil
    r.icon:SetShown(item and true or false)
    r.sword:Hide()
    if item then
        local n = ItemCount(item)
        r:SetHeight(ROW)
        r.stripe:Hide()
        r.fold:SetText("")
        r.tick:Hide()
        r.icon:SetTexture(ItemIcon(item))
        r.icon:SetDesaturated(n == 0)
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
        r.text:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r.text:SetText(ItemName(item))
        r.text:SetTextColor(unpack(n > 0 and GOLD or DIM))
        r.count:SetText(n > 1 and n or "")
        r.count:SetTextColor(unpack(DIM))
        r:EnableMouse(true)
        Wash(r, q)
    elseif q.pick then
        -- a quest to take: "!", its title in its level's colour, its experience
        r:SetHeight(ROW)
        r.stripe:SetColorTexture(odd and 0 or 0.102, odd and 0 or 0.078, odd and 0 or 0.039, 0.45)
        r.stripe:Show()
        r.fold:SetText("!")
        r.tick:Hide()
        r.count:SetText(q.guide.xp > 0 and XPText(q.guide.xp) or "")
        r.count:SetTextColor(unpack(GOLD))
        r.rule:SetShown(not top)
        r.text:SetPoint("LEFT", 14, 0)
        r.text:SetPoint("RIGHT", r.count, "LEFT", -4, 0)
        r.text:SetText(q.title)
        r.text:SetTextColor(unpack(LevelColor(q.level)))
        -- ignored: striped, as a quest not tracked
        r.stripes:SetShown(ns.questGuide.Ignored(q))
        r:EnableMouse(true)
        if Wash(r, q) then
            r.far = q.title
            r.text:SetText(q.title .. ns.waypoint.PointTag())
        end
    elseif o then
        local a, b = Count(o)
        r:SetHeight(LINE)
        r.stripe:Hide()
        r.fold:SetText("")
        r.tick:Hide()
        r.text:SetPoint("LEFT", 20, 0)
        r.text:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r.count:SetText(o.text:match("%d+%s*/%s*%d+") and (a .. "/" .. b) or "")
        r.count:SetTextColor(unpack(DIM))
        local room = (list:GetWidth() or 0) - 20 - 6 - 3 - (r.count:GetStringWidth() or 0)
        local words, kill = Short(Words(o), room, r.text, o.kind)
        r.text:SetText(words)
        r.text:SetTextColor(unpack(DIM))
        r.sword:SetShown(kill)
        -- its own clicks (Shift: its line in the chat box) and its quest's tooltip
        r:EnableMouse(true)
        Wash(r, q)
    else
        local have, need = Progress(q)
        local done = q.state == 1
        r:SetHeight(ROW)
        r.stripe:SetColorTexture(odd and 0 or 0.102, odd and 0 or 0.078, odd and 0 or 0.039, 0.45)
        r.stripe:Show()
        local folds = (#q.objectives > 0 or q.item) and true or false
        r.fold:SetText(folds and (Shown(q) and "-" or "+") or "")
        r.folder:SetShown(folds)
        r.tick:SetShown(done)
        r.count:SetText(done and "" or need > 0 and (have .. "/" .. need) or "")
        r.count:SetTextColor(unpack(q.state == -1 and { 0.8, 0.3, 0.25 } or GOLD))
        r.stripes:SetShown(not q.tracked)
        r.rule:SetShown(not top)
        r.text:SetPoint("LEFT", 14, 0)
        r.text:SetPoint("RIGHT", done and r.tick or r.count, "LEFT", -4, 0)
        r.text:SetText(q.title)
        r.text:SetTextColor(unpack(done and DIM or ns.colors.text))
        r:EnableMouse(true)
        if Wash(r, q) then
            r.far = q.title
            r.text:SetText(q.title .. ns.waypoint.Tag(q.id))
        end
    end
    r:Show()
end

local function Lines()
    local out = {}
    -- closed by hand while the waypoint's: forgotten once it is not
    if shut then
        local still = false
        for _, q in ipairs(quests) do
            if q.id == shut and OnWay(q) then still = true end
        end
        if not still then shut = nil end
    end
    for _, q in ipairs(quests) do
        table.insert(out, { quest = q })
        if Shown(q) then
            for _, o in ipairs(q.objectives) do table.insert(out, { quest = q, objective = o }) end
            if q.item then table.insert(out, { quest = q, item = q.item }) end
        end
    end
    return out
end

local function Header()
    title:SetText(ZoneName())
    place:SetText(Place())
end

function Refresh()
    if not body then return end
    Header()
    local head
    ROW, LINE = Size() + 7, Size() + 2
    quests, head = Here()
    lines = Lines()
    if first > 0 and first >= #lines then first = math.max(0, #lines - 1) end
    local y, n, odd = HEAD, 0, false
    local height = list:GetHeight()
    shown = 0
    for i = first + 1, #lines do
        local l = lines[i]
        local h = l.objective and LINE or ROW + GAP
        if y + h - GAP > height then break end
        n = n + 1
        local r = rows[n] or Row()
        rows[n] = r
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        if not (l.objective or l.item) then odd = not odd end
        Fill(r, l, odd, n == 1)
        y = y + h
        shown = shown + 1
    end
    for i = n + 1, #rows do
        rows[i]:Hide()
        rows[i].line = nil
    end
    empty:SetShown(#lines == 0)
    if #lines == 0 then
        local G = Guide() and ns.questGuide
        local try = G and G.Ready() and G.Suggest()
        empty:SetText(not G and Tr["No quests in this zone."] or not G.Ready() and Tr["The Guide needs QuestieDB."]
            or try and format(Tr["Nothing here at your level: try %s."], try) or Tr["Nothing here at your level."])
    end
    PlaceItems()
    if ns.zoneControls then ns.zoneControls.Refresh() end
    ns.side.Changed()
    -- the waypoint after the plan's head (a change draws this again: the
    -- second finds it there already)
    if head then ns.questGuide.Steer(head) end
end

-- ---------------------------------------------------------- the minimap
-- Lent while the body is on the screen, given back when it is not: the tab
-- picked or another one, the panel shown or hidden.
local function Lend()
    if ns.LendMinimap then ns.LendMinimap(body:IsVisible() and hold or nil) end
end

-- The game's tracking types, as a menu of ticks just outside the panel,
-- level with the button: retail's menus, or the older clients' own
-- tracking drop-down.
local function TrackingInfo(i)
    local a, _, c = C_Minimap.GetTrackingInfo(i)
    if type(a) == "table" then return a.name, a.active end
    return a, c
end

local function Tracking(owner)
    if MenuUtil and MenuUtil.CreateContextMenu and C_Minimap and C_Minimap.GetNumTrackingTypes then
        local menu = MenuUtil.CreateContextMenu(ns.side.panel, function(_, root)
            root:CreateTitle(Tr["Tracking"])
            for i = 1, C_Minimap.GetNumTrackingTypes() do
                local name = TrackingInfo(i)
                if name then
                    root:CreateCheckbox(name, function() return select(2, TrackingInfo(i)) and true or false end,
                        function() C_Minimap.SetTracking(i, not select(2, TrackingInfo(i))) end)
                end
            end
        end)
        -- just outside the panel, level with the button, as its tooltips
        if menu and owner then ns.window.PlaceOutside(menu, owner, true) end
        return true
    end
    if ToggleDropDownMenu and MiniMapTrackingDropDown then
        ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor", 0, 0)
        if owner and DropDownList1 and DropDownList1:IsShown() then
            ns.window.PlaceOutside(DropDownList1, owner, true)
        end
        return true
    end
    return false
end

-- Every quest here tracked
local function AllTracked()
    if #quests == 0 then return false end
    for _, q in ipairs(quests) do
        if not q.pick and not q.tracked then return false end
    end
    return true
end

-- ------------------------------------------------------------- the view
local view = {
    key = "zone", label = Tr["Zone"], option = "sideZone",
    Available = function() return Minimap ~= nil and ns.questSource ~= nil end,
}
ns.side.zone = view

function view.Build(f)
    body = f
    local side = f:GetHeight()
    -- the map's well, as tall as the body, in the windows' gold edge; the
    -- map goes in the frame inside it, which clips its pins
    well = CreateFrame("Frame", nil, f)
    well:SetPoint("TOPLEFT")
    well:SetSize(side, side)
    ns.window.Face(well)
    hold = CreateFrame("Frame", "MedalUIZoneMap", well)
    hold:SetPoint("TOPLEFT", 1, -1)
    hold:SetPoint("BOTTOMRIGHT", -1, 1)
    hold:SetSize(side - 2, side - 2)
    hold:SetClipsChildren(true)
    -- the list, beside it
    list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", well, "TOPRIGHT", 8, 0)
    list:SetPoint("BOTTOMRIGHT")
    list:SetSize(f:GetWidth() - side - 8, side)
    title = ns.Text(list, 13)
    title:SetPoint("TOPLEFT", 2, -3)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(unpack(GOLD))
    place = ns.Text(list, 10)
    place:SetPoint("TOPRIGHT", -2, -5)
    place:SetJustifyH("RIGHT")
    place:SetWordWrap(false)
    place:SetTextColor(unpack(DIM))
    title:SetPoint("RIGHT", place, "LEFT", -6, 0)
    empty = ns.Text(list, 10)
    empty:SetPoint("TOPLEFT", 4, -HEAD - 4)
    empty:SetTextColor(unpack(DIM))
    empty:SetText(Tr["No quests in this zone."])
    f:HookScript("OnShow", Lend)
    f:HookScript("OnHide", function()
        Lend()
        PlaceItems()                -- the items' buttons away (in combat: hidden already)
    end)
    -- where you stand, twice a second while the tab is up
    -- and, sorted by distance, a look every RESORT seconds out of combat,
    -- drawn again only when the order moved
    local wait, resortIn = 0, RESORT
    f:HookScript("OnUpdate", function(_, elapsed)
        resortIn = resortIn - elapsed
        if resortIn <= 0 then
            resortIn = RESORT
            if (Distance() or Guide()) and not InCombatLockdown() and Moved() then Refresh() end
        end
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.5
        place:SetText(Place())
    end)
    local function Update()
        if ns.side.IsCurrent(view) then Refresh() end
    end
    ns.questSource.Listen(Update)
    for _, key in ipairs({ "zoneSort", "zoneGuidePicks", "zoneFontSize" }) do ns.OnSetting(key, Update) end
    ns.OnSetting("zoneCoords", function() place:SetText(Place()) end)
    -- the waypoint: its wash moves; its distance, in place
    ns.waypoint.OnChange(Update)
    ns.waypoint.OnTick(function()
        if not body:IsVisible() then return end
        for _, r in ipairs(rows) do
            if r:IsShown() and r.far then
                local q = r.line.quest
                r.text:SetText(r.far .. (q.pick and ns.waypoint.PointTag() or ns.waypoint.Tag(q.id)))
            end
        end
    end)
    -- the items' counts and names; their buttons placed again after a fight
    ns.On("PLAYER_REGEN_ENABLED", function() if ns.side.IsCurrent(view) then Refresh() else PlaceItems() end end)
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
        "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do
        ns.On(e, Update)
    end
end

view.Refresh = function() Refresh() end
-- (the tab's controls: strips/zonecontrols.lua)
view.Quests = function() return quests end
view.Guide = function() return Guide() end
view.Focused = function()
    for _, q in ipairs(quests) do if OnWay(q) then return q end end
end
view.Size, view.SIZE_MIN, view.SIZE_MAX = Size, SIZE_MIN, SIZE_MAX

function view.Shown()
    Lend()
end

function view.Scroll(by)
    first = math.max(0, math.min(first + by, #lines - shown))
    Refresh()
end

function view.Thumb()
    return first, shown, #lines
end

-- whether the distance order moved since the list was drawn (the waypoint's
-- quest aside: it heads the list whatever)
-- The sort button, its dialog at its left (ns.window.Choices, the quest
-- log's look): lit while open, or sorted by distance
local ORDERS = {
    { "log", Tr["Quest log"], Tr["As your quest log orders them."] },
    { "distance", Tr["Distance"], Tr["The nearest quests first, by the game's objective markers on the map."] },
    { "guide", Tr["Guide"], Tr["What to do next for experience: quests to take near you, then quick work, hand-ins "
        .. "and wide work, nearest first. Needs QuestieDB."] },
}
local function Order()
    for _, o in ipairs(ORDERS) do
        if o[1] == ns.db.zoneSort then return o end
    end
    return ORDERS[1]
end
local orders                    -- built at its first use: the window kit loads after this file
local function Orders()
    orders = orders or ns.window.Choices({
        name = "MedalUIZoneOrders", title = Tr["Show the quests"], width = 220, choices = ORDERS, side = "left",
        Get = function() return Order()[1] end,
        Set = function(v) ns.SetOption("zoneSort", v) end,
        Anchor = function()
            for _, b in ipairs(view.paint or {}) do
                if b.spec == SORT then return b end
            end
        end,
        Opened = function() ns.side.Changed() end,
    })
    return orders
end
view.Orders = Orders
SORT = {
    glyph = function() return "side-sort" end,
    lit = function() return Order() ~= ORDERS[1] or (orders ~= nil and orders.IsOpen()) end,
    click = function() Orders().Toggle() end,
    tip = function()
        local o = Order()
        return format(Tr["Sorted: %s."], o[2]), o[3] .. " " .. Tr["Click: choose another."]
    end,
}

function Moved()
    if Guide() then
        local plan, moved = ns.questGuide.Plan(false)
        fresh = moved and plan or nil
        return moved
    end
    local rest = {}
    for _, q in ipairs(quests) do
        if not (ns.waypoint and ns.waypoint.Is(q.id)) then table.insert(rest, q) end
    end
    return select(3, ns.questSource.ByDistance(rest, rank))
end

view.buttons = {
    {
        glyph = function() return "side-controls" end,
        lit = function() return ns.zoneControls ~= nil and ns.zoneControls.IsOpen() end,
        click = function() if ns.zoneControls then ns.zoneControls.Toggle() end end,
        tip = function()
            return Tr["Controls"], ns.zoneControls and ns.zoneControls.IsOpen() and Tr["Hide the tab's controls."]
                or Tr["Show the tab's controls over the panel: the quest items, the text size, where you stand "
                .. "and the Guide's."]
        end,
    },
    {
        glyph = function() return "side-tracking" end,
        lit = function() return false end,
        click = function(_, owner)
            if not Tracking(owner) and UIErrorsFrame then
                UIErrorsFrame:AddMessage("MedalUI: " .. Tr["this client has no tracking menu."], 1, 0.82, 0)
            end
        end,
        tip = function() return "Tracking", Tr["What the minimap shows: herbs, ores, vendors and the like."] end,
    },
    {
        glyph = function() return "side-worldmap" end,
        lit = function() return false end,
        click = function() if ToggleWorldMap then ToggleWorldMap() end end,
        tip = function() return Tr["World map"], Tr["Open or close the world map."] end,
    },
    SORT,
}
view.foot = {
    glyph = function() return "side-trackall" end,
    lit = AllTracked,
    click = function()
        if AllTracked() then
            for _, q in ipairs(quests) do if not q.pick then ns.questSource.Untrack(q) end end
        else
            for _, q in ipairs(quests) do
                if not q.pick and not q.tracked and not ns.questSource.Track(q) then break end
            end
        end
        Refresh()
    end,
    tip = function()
        if AllTracked() then return Tr["Untrack this zone"], Tr["Stop tracking every quest in this zone."] end
        return Tr["Track this zone"], Tr["Track every quest in this zone, as many as the game allows."]
    end,
}

ns.SideView(view)
