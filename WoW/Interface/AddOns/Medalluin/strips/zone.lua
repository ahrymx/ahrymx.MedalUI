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
-- retail those the game marks on this map too. A row is the quest's title,
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
-- opens its objectives under it or closes them.
--
-- A quest with a usable item (quests/source.lua's q.item, as the tracker's)
-- ends its open objectives with it: its icon, its name and how many you
-- carry. A click uses it: a secure button over the line, on a layer of its
-- own on the strip, placed by numbers out of combat (ns.window.Over) and
-- hidden in combat by the game's driver, as the rows may move meanwhile.
--
-- The column: zoom in, zoom out, the minimap's tracking, the world map; at
-- the foot, every quest here tracked (or, while they all are, none).
local _, ns = ...

local PARTS = ns.media .. "strips\\"
local ROW, LINE, HEAD, GAP = 18, 13, 22, 1
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
        if x and y and (x > 0 or y > 0) then at = string.format("%.0f, %.0f", x * 100, y * 100) end
    end
    if sub ~= "" and at ~= "" then return sub .. "  " .. at end
    return sub ~= "" and sub or at
end

-- The log's quests here: its heading is this zone (or the map's name for
-- it), or the game marks it on this map.
local function Here()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return {} end
    local names, marked = { [ZoneName()] = true }, {}
    local map = MapID()
    local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    if info and info.name then names[info.name] = true end
    if map and C_QuestLog.GetQuestsOnMap then
        for _, e in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
            if e.questID then marked[e.questID] = true end
        end
    end
    local out = {}
    for _, q in ipairs(ns.questSource.Log()) do
        if names[q.zone] or marked[q.id] then table.insert(out, q) end
    end
    return out
end

-- ------------------------------------------------------------- progress
-- (an objective's count and words: quests/source.lua's Q.Count, Q.Words)
local function Count(o) return ns.questSource.Count(o) end
local function Words(o) return ns.questSource.Words(o) end

-- An objective's words, shortened for its line: "... slain" (or killed)
-- loses the word for a sword before the line; and when it is still too long
-- for room, a name of two words or more gives its first as an initial
-- ("Dragonmaw Reclaimer" -> "D. Reclaimer"). The words, and whether a sword.
local function Short(text, room, fs)
    local killed = text:match("^(.-)%s+[Ss]lain$") or text:match("^(.-)%s+[Kk]illed$")
    if killed then text = killed end
    fs:SetText(text)
    if room > 0 and (fs:GetStringWidth() or 0) > room then
        local initial, rest = text:match("^(%a)[%a'%-]*%s+(.+)$")
        if initial then text = initial .. ". " .. rest end
    end
    return text, killed ~= nil
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
    return name or "Quest item"
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
    b = CreateFrame("Button", "MedalluinZoneItem" .. i, layer, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.12)
    b:SetScript("OnEnter", function(self)
        if self.item then ItemTip(self, self.item, "Click: use it.") end
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
        layer = CreateFrame("Frame", "MedalluinZoneItems", ns.strips[1])
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
local function Tip(r)
    local q = r.line and r.line.quest
    if not q then return end
    if r.line.item then
        -- (in combat: the secure button is away, the line under it shows)
        ItemTip(r, r.line.item, "Usable here after combat.")
        return
    end
    local state = q.state == 1 and "Complete." or q.state == -1 and "Failed." or nil
    local spec = { title = q.title,
        { "body", "Level " .. q.level .. (state and ("  \194\183  " .. state) or "") },
        { "body", q.tracked and "Tracked." or "Not tracked." } }
    for _, k in ipairs(ns.questSource.Keys(q, r.line.objective)) do table.insert(spec, k) end
    ns.Tip(r, ns.side.Beside, spec)
end

local Refresh

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
        open[q.id] = not open[q.id] or nil
        Refresh()
        if GameTooltip:GetOwner() == r.folder then r.folder:GetScript("OnEnter")(r.folder) end
    end)
    r.folder:SetScript("OnEnter", function(self)
        local q = r.line and r.line.quest
        if not q then return end
        Light(q.id)
        r.fold:SetTextColor(unpack(GOLD))
        ns.Tip(self, ns.side.Beside, { title = open[q.id] and "Hide its objectives." or "Show its objectives.",
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
    if not ns.waypoint.Is(q.id) then return false end
    r.stripe:SetColorTexture(unpack(ns.waypoint.WASH))
    r.stripe:Show()
    return true
end

-- A quest's row, or one of its objectives under it.
local function Fill(r, line, odd, top)
    r.line = line
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
        local words, kill = Short(Words(o), room, r.text)
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
        r.fold:SetText(folds and (open[q.id] and "-" or "+") or "")
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
    for _, q in ipairs(quests) do
        table.insert(out, { quest = q })
        if open[q.id] then
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
    quests = Here()
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
    PlaceItems()
    ns.side.Changed()
end

-- ---------------------------------------------------------- the minimap
-- Lent while the body is on the screen, given back when it is not: the tab
-- picked or another one, the panel shown or hidden.
local function Lend()
    if ns.LendMinimap then ns.LendMinimap(body:IsVisible() and hold or nil) end
end

local function Zoom(by)
    local z = Minimap:GetZoom() + by
    Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, z)))
end

-- The game's tracking types, as a menu of ticks at the pointer: retail's
-- menus, or the older clients' own tracking drop-down.
local function TrackingInfo(i)
    local a, _, c = C_Minimap.GetTrackingInfo(i)
    if type(a) == "table" then return a.name, a.active end
    return a, c
end

local function Tracking()
    if MenuUtil and MenuUtil.CreateContextMenu and C_Minimap and C_Minimap.GetNumTrackingTypes then
        MenuUtil.CreateContextMenu(ns.side.panel, function(_, root)
            root:CreateTitle("Tracking")
            for i = 1, C_Minimap.GetNumTrackingTypes() do
                local name = TrackingInfo(i)
                if name then
                    root:CreateCheckbox(name, function() return select(2, TrackingInfo(i)) and true or false end,
                        function() C_Minimap.SetTracking(i, not select(2, TrackingInfo(i))) end)
                end
            end
        end)
        return true
    end
    if ToggleDropDownMenu and MiniMapTrackingDropDown then
        ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor", 0, 0)
        return true
    end
    return false
end

-- Every quest here tracked
local function AllTracked()
    if #quests == 0 then return false end
    for _, q in ipairs(quests) do
        if not q.tracked then return false end
    end
    return true
end

-- ------------------------------------------------------------- the view
local view = {
    key = "zone", label = "Zone", option = "sideZone",
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
    hold = CreateFrame("Frame", "MedalluinZoneMap", well)
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
    empty:SetText("No quests in this zone.")
    f:HookScript("OnShow", Lend)
    f:HookScript("OnHide", function()
        Lend()
        PlaceItems()                -- the items' buttons away (in combat: hidden already)
    end)
    -- where you stand, twice a second while the tab is up
    local wait = 0
    f:HookScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.5
        place:SetText(Place())
    end)
    local function Update()
        if ns.side.IsCurrent(view) then Refresh() end
    end
    ns.questSource.Listen(Update)
    -- the waypoint: its wash moves; its distance, in place
    ns.waypoint.OnChange(Update)
    ns.waypoint.OnTick(function()
        if not body:IsVisible() then return end
        for _, r in ipairs(rows) do
            if r:IsShown() and r.far then r.text:SetText(r.far .. ns.waypoint.Tag(r.line.quest.id)) end
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

view.buttons = {
    {
        glyph = function() return "side-zoom-in" end,
        lit = function() return false end,
        click = function() Zoom(1) end,
        tip = function() return "Zoom in", "The mouse wheel on the map zooms too." end,
    },
    {
        glyph = function() return "side-zoom-out" end,
        lit = function() return false end,
        click = function() Zoom(-1) end,
        tip = function() return "Zoom out", "The mouse wheel on the map zooms too." end,
    },
    {
        glyph = function() return "side-tracking" end,
        lit = function() return false end,
        click = function()
            if not Tracking() and UIErrorsFrame then
                UIErrorsFrame:AddMessage("Medalluin: this client has no tracking menu.", 1, 0.82, 0)
            end
        end,
        tip = function() return "Tracking", "What the minimap shows: herbs, ores, vendors and the like." end,
    },
    {
        glyph = function() return "side-worldmap" end,
        lit = function() return false end,
        click = function() if ToggleWorldMap then ToggleWorldMap() end end,
        tip = function() return "World map", "Open or close the world map." end,
    },
}
view.foot = {
    glyph = function() return "side-trackall" end,
    lit = AllTracked,
    click = function()
        if AllTracked() then
            for _, q in ipairs(quests) do ns.questSource.Untrack(q) end
        else
            for _, q in ipairs(quests) do
                if not q.tracked and not ns.questSource.Track(q) then break end
            end
        end
        Refresh()
    end,
    tip = function()
        if AllTracked() then return "Untrack this zone", "Stop tracking every quest in this zone." end
        return "Track this zone", "Track every quest in this zone, as many as the game allows."
    end,
}

ns.SideView(view)
