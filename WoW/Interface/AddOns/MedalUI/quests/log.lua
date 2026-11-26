-- The quest log: every quest in the log, MedalUI's own window (the shell
-- is window/shell.lua) on the right strip as the spellbook's, over the side
-- panel, its ink solid, its margin beside the backpack's medallion. It
-- stands instead of the game's log: the quest log key and the Quests button
-- open and close it, and the map no longer shows the game's. Exclusive: it
-- closes the spellbook, the talents or the professions as it opens, and
-- they close it.
--
--   [quests]                                                   [x]
--   -----------------------------------------------------------------
--   14 / 25             [search]                             [fold]
--   Lvl  Quest                               XP     Item     Coin
--   - Westfall (4)                                          [eye]
--   18   The Defias Brotherhood  (group)    1,450    v        45s
--   17 ///The Coastal Menace/////////////// 1,250 // v /////// 35s   (untracked)
--   + Duskwood (5)                                          [eye]
--   -----------------------------------------------------------------
--   [ Track all | Untrack all | sort ]  [ Drop... ]           (backpack)
--
-- A zone folds (remembered, questLogFolded); its eye tracks every quest in
-- it, or stops tracking them all when they all are: lit when all are
-- tracked, dim when some, struck when none. A quest's level and title are
-- in its difficulty's colour, its mark after it (ready, daily, a group's, a
-- dungeon's: the tracker's); an untracked one's row is striped and its
-- title a little darker.
-- Item: a tick when it gives an item (or a choice of them), a cross when
-- not. A quest's clicks are the tracker's and the Zone tab's (Q.Click,
-- quests/source.lua), its tooltip's key lines saying them: a click opens its
-- page, Shift links it, Ctrl sets the waypoint to it or clears it
-- (quests/waypoint.lua: its row washed blue, its distance after its title),
-- Alt focuses it with Questie's arrow, a right click tracks it or stops, a
-- middle click opens the world map at it. The search keeps the quests whose title has
-- the words, folded zones too. Track all stops at the game's limit.
-- Drop opens the window that abandons quests (quests/drop.lua).
-- The columns' headings sort (2026-11-11): a click sorts each zone's
-- quests by that column, a second reverses it, a third puts back the log's
-- order; the sorted heading in gold with a chevron (remembered,
-- questLogSort). The zones stay in the log's order, unless the sort
-- button by Track all orders them: a dialog over it, the game menu's
-- options' look, offers the tracker's sorts (questLogOrder, 2026-11-11), Level (each zone's quests
-- by level, the zones by their lowest) or Zone (the one you are in first,
-- then by name), or the log's own order. A heading's sort still orders
-- the quests inside each zone.
local _, ns = ...
local Tr = ns.L

local Q = ns.questSource
local WP = ns.waypoint
local GOLD = ns.gold.light
local GOLD_D = ns.gold.dark
local DIM = { 0.55, 0.52, 0.45 }
-- a zone's fold keeps the gold as drawn, whatever the theme (theme.lua)
local FOLD_L, FOLD_D = ns.goldKept.light, ns.goldKept.dark
local XP = { 0.63, 0.55, 0.9 }
local RED = { 0.86, 0.27, 0.22 }
local NONE = { 0.47, 0.24, 0.2 }
local HEAD = 26                         -- the search and the fold, over the columns
local COUNTS = 18                       -- the counts' line under the list, over the margin's buttons
local COLUMNS, ROW, FOLD = 18, 20, 26   -- the columns' heading, a quest's row, a zone's
local GUTTER = 10                       -- the scroll bar, left of the rows
local CONTROL = 18
local ZEBRA, RULE = 0.05, 0.6
local FILL = 0.45                       -- a fold's gold
local FAR = 44                          -- the waypoint's distance: its room after the title
local STRIPES, UNTRACKED = 0.3, 0.75    -- an untracked quest: its row's stripes, its title's colour
-- the columns, from the rows' right edge: XP's right, Item's centre, Coin's right
local AT_XP, AT_ITEM, AT_COIN = 118, 76, 6
local TITLE = 34                        -- the title's left, past the level

local frame, count, search, foldAll, columns, body, empty, foot, bar, thumb
local rows, lines = {}, {}
local first, shown = 0, 0
local dirty = true
local log = {}
ns.questLog = log

function log.On() return ns.db.questLog and true or false end

-- ------------------------------------------------------------------ data
local function Money(copper)
    if not copper or copper <= 0 then return nil end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then table.insert(out, g .. "g") end
    if s > 0 then table.insert(out, s .. "s") end
    if c > 0 and g == 0 then table.insert(out, c .. "c") end
    return table.concat(out, " ")
end
log.Money = Money

local function Number(n)
    local s = tostring(math.floor(n or 0))
    while true do
        local k
        s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if k == 0 then return s end
    end
end
log.Number = Number

-- The quests by zone, in the log's order: { name, quests, tracked (all,
-- some or none) }.
local function Zones(quests)
    local zones, by = {}, {}
    for _, q in ipairs(quests) do
        local z = by[q.zone]
        if not z then
            z = { name = q.zone, quests = {} }
            by[q.zone] = z
            table.insert(zones, z)
        end
        table.insert(z.quests, q)
    end
    for _, z in ipairs(zones) do
        local n = 0
        for _, q in ipairs(z.quests) do if q.tracked then n = n + 1 end end
        z.tracked = n == #z.quests and "all" or n > 0 and "some" or "none"
    end
    return zones
end
log.Zones = Zones

local function Matches(q, words)
    if not words then return true end
    local t = q.title:lower()
    for w in words:gmatch("%S+") do
        if not t:find(w, 1, true) then return false end
    end
    return true
end

-- The sorts: each column's value, and which way it runs first (the most
-- worth first; the level and title from the low end).
local SORTS = {
    lvl = { word = Tr["level"], first = "up", value = function(q) return q.level or 0 end },
    title = { word = Tr["title"], first = "up", value = function(q) return (q.title or ""):lower() end },
    xp = { word = Tr["XP"], first = "down", value = function(q) return (q.rewards or {}).xp or 0 end },
    item = { word = Tr["item"], first = "down", value = function(q) return (q.rewards or {}).items and 1 or 0 end },
    coin = { word = Tr["coin"], first = "down", value = function(q) return (q.rewards or {}).money or 0 end },
}

-- the sort in use: its key and "up" or "down"; nil, the log's order
local function Sorting()
    local s = ns.db.questLogSort
    if type(s) == "table" and SORTS[s.key] then return s.key, s.dir == "down" and "down" or "up" end
end

-- a heading clicked: its sort, reversed, then none
local function SortBy(key)
    local now, dir = Sorting()
    if now ~= key then
        ns.db.questLogSort = { key = key, dir = SORTS[key].first }
    elseif dir == SORTS[key].first then
        ns.db.questLogSort = { key = key, dir = dir == "up" and "down" or "up" }
    else
        ns.db.questLogSort = false
    end
    log.Refresh()
end
log.SortBy = SortBy

-- a zone's quests in the sort's order; ties, and no sort, in the log's
local function Sorted(list)
    local key, dir = Sorting()
    if not key then return list end
    local value, at = SORTS[key].value, {}
    for i, q in ipairs(list) do at[q] = i end
    table.sort(list, function(a, b)
        local va, vb = value(a), value(b)
        if va ~= vb then
            if dir == "down" then return va > vb end
            return va < vb
        end
        return at[a] < at[b]
    end)
    return list
end

-- The sort button's orders (the tracker's, quests/tracker.lua), or the
-- log's own (none).
local ORDERS = {
    { false, Tr["Log order"], Tr["The zones and their quests as the game lists them."] },
    { "level", Tr["Level"], Tr["The lowest quests first, and the zones by their lowest quest."] },
    { "zone", Tr["Zone"], Tr["The zone you are in first, then the rest by name."] },
}
local function Order()
    local o = ns.db.questLogOrder
    return (o == "level" or o == "zone") and o or false
end
-- the order in use: its word and what it does
local function OrderOf()
    for _, o in ipairs(ORDERS) do
        if o[1] == Order() then return o end
    end
end

-- the zones, and their quests, in the order chosen; ties in the log's
local function Ordered(zones)
    local order = Order()
    if not order then return zones end
    local at = {}
    for i, z in ipairs(zones) do
        at[z] = i
        for j, q in ipairs(z.quests) do at[q] = j end
        table.sort(z.quests, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
            return at[a] < at[b]
        end)
        z.low = z.quests[1] and z.quests[1].level or 0
    end
    local here = GetRealZoneText and GetRealZoneText()
    table.sort(zones, function(a, b)
        if order == "zone" then
            if (a.name == here) ~= (b.name == here) then return a.name == here end
            if a.name ~= b.name then return a.name < b.name end
        elseif a.low ~= b.low then
            return a.low < b.low
        end
        return at[a] < at[b]
    end)
    return zones
end

local quests = {}
local function Lines()
    quests = Q.All()
    local words = search and search:GetText() or ""
    words = words:match("%S") and words:lower() or nil
    local folded = ns.db.questLogFolded or {}
    local out = {}
    for _, z in ipairs(Ordered(Zones(quests))) do
        local list = {}
        for _, q in ipairs(z.quests) do
            if Matches(q, words) then table.insert(list, q) end
        end
        Sorted(list)
        if #list > 0 then
            table.insert(out, { zone = z })
            if words or not folded[z.name] then
                for _, q in ipairs(list) do table.insert(out, { quest = q }) end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------- actions
local function Each(list, fn)
    local stopped = false
    for _, q in ipairs(list) do
        if not fn(q) then stopped = true end
    end
    return not stopped
end

-- every quest in the list tracked, or none: false when the limit stopped it
local function TrackAll(list) return Each(list, function(q) return Q.Track(q) end) end
local function UntrackAll(list) return Each(list, function(q) Q.Untrack(q) return true end) end

local function Fold(zone)
    local f = ns.db.questLogFolded or {}
    f[zone] = not f[zone] or nil
    ns.db.questLogFolded = f
    log.Refresh()
end

local function LimitTip()
    local limit = Q.WatchLimit()
    return limit and format(Tr["The game tracks at most %d quests."], limit) or nil
end

-- ------------------------------------------------------------- the rows
-- c at alpha a at the right (the screen's edge: the log stands on the
-- right) fading to a tenth of it towards the middle
local function Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a * 0.1), CreateColor(c[1], c[2], c[3], a))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.55)
    end
end

local function Glyph(b, name, size)
    b.icon = b.icon or b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(size or 16, size or 16)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(ns.media .. "strips\\" .. name)
    b.glyph = name
end

local function Tip(owner, spec)
    ns.Tip(owner, ns.window.Outside, spec)
end

local function Wheel(delta) log.Scroll(-delta * 3) end

-- ------------------------------------------------------------ the orders
-- The sort button's dialog (ns.window.Choices): its keys are the orders; a
-- pick sorts and the dialog stays, its key lit. A click anywhere else, the
-- button again, Escape, or the log closing shuts it.
local orders = ns.window.Choices({
    name = "MedalUIQuestLogOrders", title = Tr["Sort the zones"], width = 220, choices = ORDERS,
    Get = Order,
    Set = function(v)
        ns.db.questLogOrder = v
        log.Refresh()
    end,
    Anchor = function() return foot and foot.byKey.sort end,
    Opened = function(open)
        if foot then foot:Set("sort", { selected = open, enabled = #quests > 0 }) end
    end,
})
log.orders = orders

-- A row, either kind: a zone's fold or a quest's line; each drawn as it is
-- filled.
local function Row()
    local r = CreateFrame("Button", nil, body)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0.06)
    -- the fold: a band of gold fading in from the right, lit along its top
    -- (in gold whatever the theme)
    r.fill = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.over = r:CreateTexture(nil, "BORDER")
    r.under = r:CreateTexture(nil, "BORDER")
    r.sign = ns.Text(r, 14)
    r.zone = ns.Text(r, 13)
    ns.KeepGold(r.fill, r.over, r.under, r.sign, r.zone)
    r.fill:SetPoint("TOPLEFT", 0, -2)
    r.fill:SetPoint("BOTTOMRIGHT", 0, 2)
    Fade(r.fill, FOLD_D, FILL)
    r.over:SetPoint("TOPLEFT", 0, -2)
    r.over:SetPoint("TOPRIGHT", 0, -2)
    r.over:SetHeight(1)
    Fade(r.over, FOLD_L, RULE)
    r.under:SetPoint("BOTTOMLEFT", 0, 2)
    r.under:SetPoint("BOTTOMRIGHT", 0, 2)
    r.under:SetHeight(1)
    Fade(r.under, FOLD_D, RULE)
    r.sign:SetPoint("LEFT", 6, 0)
    r.sign:SetTextColor(unpack(FOLD_L))
    r.zone:SetPoint("LEFT", 20, 0)
    r.zone:SetTextColor(unpack(FOLD_L))
    r.count = ns.Text(r, 11)
    r.count:SetPoint("LEFT", r.zone, "RIGHT", 6, 0)
    r.count:SetTextColor(unpack(DIM))
    r.eye = CreateFrame("Button", nil, r)
    r.eye:SetSize(CONTROL + 4, CONTROL)
    r.eye:SetPoint("RIGHT", -4, 0)
    r.eye.icon = r.eye:CreateTexture(nil, "ARTWORK")
    ns.KeepGold(r.eye.icon)
    Glyph(r.eye, "track", CONTROL + 2)
    r.eye:SetScript("OnClick", function(self)
        local z = self:GetParent().data.zone
        if z.tracked == "all" then UntrackAll(z.quests) else TrackAll(z.quests) end
        log.Refresh()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    r.eye:SetScript("OnEnter", function(self)
        local z = self:GetParent().data.zone
        local all = z.tracked == "all"
        Tip(self, { title = format(all and Tr["Stop tracking %s"] or Tr["Track %s"], z.name),
            { "body", all and Tr["Every quest in it is tracked."] or z.tracked == "some"
                and Tr["Some of its quests are tracked: click to track them all."]
                or Tr["None of its quests is tracked."] },
            not all and LimitTip() and { "hint", LimitTip() } or false })
    end)
    r.eye:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- the quest: shading, the open page's mark, level, title, mark, columns
    r.zebra = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.zebra:SetAllPoints()
    r.zebra:SetColorTexture(1, 1, 1, ZEBRA)
    r.mark = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.mark:SetAllPoints()
    r.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    r.edge = r:CreateTexture(nil, "BORDER")
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(2)
    r.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    r.lvl = ns.PlainText(r, 11)
    r.lvl:SetPoint("CENTER", r, "LEFT", 14, 0)
    -- an untracked quest: its row striped, faint
    r.stripes = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    r.stripes:SetAllPoints()
    r.stripes:SetTexture(ns.media .. "strips\\stripes", "REPEAT", "REPEAT")
    r.stripes:SetHorizTile(true)
    r.stripes:SetVertTile(true)
    r.stripes:SetVertexColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    r.stripes:SetAlpha(STRIPES)
    -- the waypoint's quest: washed, its distance after its title (and mark)
    r.wash = r:CreateTexture(nil, "BACKGROUND", nil, 4)
    r.wash:SetAllPoints()
    r.wash:SetColorTexture(unpack(WP.WASH))
    r.title = ns.PlainText(r, 11)
    r.title:SetPoint("LEFT", TITLE, 0)
    r.title:SetJustifyH("LEFT")
    r.title:SetWordWrap(false)
    r.badge = r:CreateTexture(nil, "ARTWORK")
    r.badge:SetSize(12, 12)
    r.badge:SetPoint("LEFT", r.title, "RIGHT", 4, 0)
    r.far = ns.PlainText(r, 10)
    r.far:SetTextColor(unpack(WP.COLOR))
    r.xp = ns.PlainText(r, 11)
    r.xp:SetPoint("RIGHT", -AT_XP, 0)
    r.xp:SetTextColor(unpack(XP))
    r.item = ns.PlainText(r, 11)
    r.item:SetPoint("CENTER", r, "RIGHT", -AT_ITEM, 0)
    r.coin = ns.PlainText(r, 11)
    r.coin:SetPoint("RIGHT", -AT_COIN, 0)
    r:SetScript("OnClick", function(self, mouse)
        local d = self.data
        if d.zone then
            Fold(d.zone.name)
        elseif Q.Click(d.quest, mouse) == "track" then
            log.Refresh()
        end
    end)
    r:SetScript("OnEnter", function(self)
        local q = self.data.quest
        if not q then return end
        local spec = { title = q.title, color = ns.QuestColour and ns.QuestColour(q) or nil, wrap = true }
        for _, o in ipairs(q.objectives) do
            table.insert(spec, { "body", (o.done and "|cff808080" or "") .. o.text .. (o.done and "|r" or "") })
        end
        for _, k in ipairs(Q.Keys(q)) do table.insert(spec, k) end
        Tip(self, spec)
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function FillZone(r, z)
    r:SetHeight(FOLD)
    for _, t in ipairs({ r.fill, r.over, r.under, r.sign, r.zone, r.count }) do t:Show() end
    r.eye:Show()
    for _, t in ipairs({ r.zebra, r.mark, r.edge, r.lvl, r.stripes, r.title, r.badge, r.xp, r.item, r.coin,
        r.wash, r.far }) do
        t:Hide()
    end
    -- a search opens every zone it finds quests in
    local folded = (ns.db.questLogFolded or {})[z.name] and not (search and search:GetText() or ""):match("%S")
    r.sign:SetText(folded and "+" or "-")
    r.zone:SetText(z.name)
    r.count:SetText("(" .. #z.quests .. ")")
    Glyph(r.eye, z.tracked == "none" and "track-off" or "track", CONTROL + 2)
    r.eye.icon:SetAlpha(z.tracked == "all" and 1 or 0.45)
end

local function FillQuest(r, q, n)
    r:SetHeight(ROW)
    for _, t in ipairs({ r.fill, r.over, r.under, r.sign, r.zone, r.count }) do t:Hide() end
    r.eye:Hide()
    for _, t in ipairs({ r.lvl, r.title, r.xp, r.item, r.coin }) do t:Show() end
    r.zebra:SetShown(n % 2 == 0)
    local open = ns.questPage and ns.questPage.Current() == q.id
    r.mark:SetShown(open)
    r.edge:SetShown(open)
    local c = ns.QuestColour and ns.QuestColour(q) or ns.colors.text
    r.lvl:SetText(q.level > 0 and q.level or "")
    r.lvl:SetTextColor(c[1], c[2], c[3])
    r.stripes:SetShown(not q.tracked)
    r.title:SetText(q.title .. (q.state == -1 and "  " .. Tr["(failed)"] or ""))
    local k = q.tracked and 1 or UNTRACKED
    r.title:SetTextColor(c[1] * k, c[2] * k, c[3] * k)
    -- the title, as wide as the room up to the XP's column
    -- (less the waypoint's distance after it)
    r.title:SetWidth(math.min(r.title:GetStringWidth() + 1, body:GetWidth() - GUTTER - TITLE - AT_XP - 60
        - (WP.Is(q.id) and FAR or 0)))
    local marked = q.state == 1 or q.daily or q.kind
    r.badge:SetShown(marked and ns.QuestMark and ns.character and ns.character.Badge and true or false)
    if r.badge:IsShown() then ns.character.Badge(r.badge, ns.QuestMark(q, 12)) end
    local way = WP.Is(q.id)
    r.wash:SetShown(way)
    r.far:SetShown(way)
    r.far:ClearAllPoints()
    r.far:SetPoint("LEFT", r.badge:IsShown() and r.badge or r.title, "RIGHT", 6, 0)
    r.far:SetText(way and WP.Distance(q.id) or "")
    local rw = q.rewards or {}
    r.xp:SetText((rw.xp or 0) > 0 and Number(rw.xp) or "\226\128\148")
    r.xp:SetTextColor(unpack((rw.xp or 0) > 0 and XP or DIM))
    r.item:SetText(rw.items and ns.Tick({ 0.43, 0.78, 0.35 }) or ns.Cross(NONE))
    r.item:SetTextColor(unpack(rw.items and { 0.43, 0.78, 0.35 } or NONE))
    local coin = Money(rw.money)
    r.coin:SetText(coin or "\226\128\148")
    r.coin:SetTextColor(unpack(coin and GOLD or DIM))
end

-- ------------------------------------------------------------- drawing
local function Thumb()
    local total = #lines
    if total <= shown or shown <= 0 then
        thumb:Hide()
        return
    end
    local h = bar:GetHeight()
    local th = math.max(14, h * shown / total)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -(h - th) * math.min(1, first / (total - shown)))
    thumb:Show()
end

function log.Refresh()
    if not body then return end
    dirty = false
    lines = Lines()
    -- (2026-11-24) the log's count and the tracked count
    count:SetText(Q.CountText(true, quests))
    count.hold:SetWidth(count:GetStringWidth())
    if first > 0 and first >= #lines then first = math.max(0, #lines - 1) end
    local height = body:GetHeight()
    local y, used, n = 0, 0, 0
    shown = 0
    for i = first + 1, #lines do
        local l = lines[i]
        local h = l.zone and FOLD or ROW
        if y + h > height then break end
        used = used + 1
        local r = rows[used] or Row()
        rows[used] = r
        r.data = l
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", GUTTER, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        if l.zone then
            n = 0
            FillZone(r, l.zone)
        else
            n = n + 1
            FillQuest(r, l.quest, n)
        end
        r:Show()
        y = y + h
        shown = shown + 1
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    local key, dir = Sorting()
    for _, h in ipairs(columns.heads) do
        local on = h.key == key
        h.text:SetTextColor(unpack(on and GOLD or DIM))
        h.chev:SetShown(on)
        if on then h.chev:SetTexture(ns.media .. "strips\\chevron-" .. dir) end
    end
    empty:SetShown(#lines == 0)
    empty:SetText((search and search:GetText() or ""):match("%S") and Tr["No quest has those words."]
        or Tr["Your quest log is empty."])
    Thumb()
    if foot then
        foot:Set("untrack", { enabled = #quests > 0 })
        foot:Set("track", { enabled = #quests > 0 })
        foot:Set("sort", { enabled = #quests > 0,
            selected = orders.IsOpen() })
        orders.Mark()
        foot:Set("drop", { enabled = #quests > 0, color = RED })
    end
    if ns.questDrop and ns.questDrop.Refresh then ns.questDrop.Refresh() end
    if ns.questPage and ns.questPage.Refresh then ns.questPage.Refresh() end
end

function log.Scroll(by)
    first = math.max(0, math.min(first + by, #lines - shown))
    log.Refresh()
end

function log.Thumb() return first, shown, #lines end

-- -------------------------------------------------------------- the window
local W, page

local function Control(parent, name, tip, click)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CONTROL + 6, CONTROL + 6)
    ns.window.Face(b)
    Glyph(b, name, CONTROL)
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", function(self) Tip(self, { title = tip() }) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- the page: the count, the search and the fold over the columns' heading
-- and the list; the margin's row edge to edge (bandFlush)
local function Build(pageBody, _, band)
    local head = CreateFrame("Frame", nil, pageBody)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD)
    -- (2026-11-24, the user's) the log's count and the tracked count: under
    -- the list, over the margin's buttons
    count = ns.Text(pageBody, 12)
    count:SetPoint("BOTTOMLEFT", GUTTER + 4, 3)
    count:SetTextColor(unpack(DIM))
    -- the counts' tip
    count.hold = CreateFrame("Frame", nil, pageBody)
    count.hold:SetPoint("LEFT", count)
    count.hold:SetHeight(COUNTS)
    count.hold:SetWidth(1)
    count.hold:EnableMouse(true)
    count.hold:SetScript("OnEnter", function(self)
        local spec = { title = Tr["Quests"], color = GOLD }
        for _, l in ipairs(Q.CountLines(quests)) do spec[#spec + 1] = l end
        ns.Tip(self, ns.window.Outside, spec)
    end)
    count.hold:SetScript("OnLeave", function() GameTooltip:Hide() end)
    foldAll = Control(head, "chevron-double", function()
        return log.AnyOpen() and Tr["Fold every zone."] or Tr["Open every zone."]
    end, function(self)
        local fold = log.AnyOpen()
        local f = {}
        if fold then
            for _, q in ipairs(quests) do f[q.zone] = true end
        end
        ns.db.questLogFolded = f
        log.Refresh()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    foldAll:SetPoint("RIGHT", 0, 0)
    search = CreateFrame("EditBox", "MedalUIQuestLogSearch", head, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("LEFT", 10, 0)
    search:SetPoint("RIGHT", foldAll, "LEFT", -10, 0)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function()
        first = 0
        log.Refresh()
    end)

    -- the columns' heading, as the trainer's
    columns = CreateFrame("Frame", nil, pageBody)
    columns:SetHeight(COLUMNS)
    columns:SetPoint("TOPLEFT", GUTTER, -(HEAD + 4))
    columns:SetPoint("TOPRIGHT", 0, -(HEAD + 4))
    -- each heading a button that sorts by its column; the chevron beside
    -- the sorted one's words, up or down
    local function Heading(key, text, point, x)
        local b = CreateFrame("Button", nil, columns)
        b:SetHeight(COLUMNS)
        local t = ns.Text(b, 11)
        t:SetTextColor(unpack(DIM))
        t:SetText(text)
        t:SetPoint("CENTER")
        b:SetWidth(t:GetStringWidth() + 6)
        b:SetPoint(point, columns, point == "CENTER" and "RIGHT" or point, x - (point == "RIGHT" and 0 or 3), 0)
        b.text, b.key = t, key
        b.chev = b:CreateTexture(nil, "ARTWORK")
        b.chev:SetSize(10, 10)
        b.chev:SetPoint(point == "RIGHT" and "RIGHT" or "LEFT", t, point == "RIGHT" and "LEFT" or "RIGHT",
            point == "RIGHT" and -2 or 2, 0)
        b.chev:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
        b.chev:Hide()
        local lit = b:CreateTexture(nil, "HIGHLIGHT")
        lit:SetAllPoints()
        lit:SetColorTexture(1, 1, 1, 0.06)
        b:SetScript("OnClick", function(self)
            SortBy(key)
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
        end)
        b:SetScript("OnEnter", function(self)
            local now, dir = Sorting()
            local word = SORTS[key].word
            local hint = now ~= key and format(Tr["Click: sort each zone's quests by %s."], word)
                or dir == SORTS[key].first and Tr["Click: the other way round."]
                or Tr["Click: back to the log's order."]
            Tip(self, { title = format(Tr["Sort by %s"], word), { "hint", hint } })
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    columns.lvl = Heading("lvl", Tr["Lvl"], "LEFT", 4)
    columns.quest = Heading("title", Tr["Quest"], "LEFT", TITLE)
    columns.xp = Heading("xp", Tr["XP"], "RIGHT", -AT_XP)
    columns.item = Heading("item", Tr["Item"], "CENTER", -AT_ITEM)
    columns.coin = Heading("coin", Tr["Coin"], "RIGHT", -AT_COIN)
    columns.heads = { columns.lvl, columns.quest, columns.xp, columns.item, columns.coin }
    local under = columns:CreateTexture(nil, "ARTWORK")
    under:SetHeight(1)
    under:SetPoint("BOTTOMLEFT")
    under:SetPoint("BOTTOMRIGHT")
    Fade(under, GOLD_D, 1)

    -- the list, and its scroll bar in the gutter
    body = CreateFrame("Frame", nil, pageBody)
    body:SetPoint("TOPLEFT", 0, -(HEAD + 4 + COLUMNS + 4))
    body:SetPoint("BOTTOMRIGHT", 0, COUNTS)
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    body:SetScript("OnSizeChanged", function() if log.IsShown() then log.Refresh() end end)
    bar = body:CreateTexture(nil, "BORDER")
    bar:SetColorTexture(0, 0, 0, 0.35)
    bar:SetWidth(4)
    bar:SetPoint("TOPLEFT", 1, 0)
    bar:SetPoint("BOTTOMLEFT", 1, 0)
    thumb = body:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
    thumb:SetWidth(4)
    empty = ns.Text(body, 11)
    empty:SetPoint("TOPLEFT", GUTTER + 4, -6)
    empty:SetTextColor(unpack(DIM))

    -- the margin: track every quest, or none; Drop
    foot = ns.window.Segments(band, { height = band:GetHeight(), engraved = true, items = {
        { key = "track", label = Tr["Track all"], group = "track", click = function()
            TrackAll(quests)
            log.Refresh()
        end, tip = function() return Tr["Track every quest."] .. (LimitTip() and (" " .. LimitTip()) or "") end },
        { key = "untrack", label = Tr["Untrack all"], group = "track", click = function()
            UntrackAll(quests)
            log.Refresh()
        end, tip = function() return Tr["Stop tracking every quest."] end },
        { key = "sort", label = Tr["Sort"], icon = "sort", group = "track", click = function() orders.Toggle() end,
            tip = function()
                local o = OrderOf()
                return format(Tr["Sorted: %s."], o[2]) .. " " .. o[3] .. " " .. Tr["Click: choose another."]
            end },
        { key = "drop", label = Tr["Drop\226\128\166"], group = "drop", color = RED, click = function()
            if ns.questDrop then ns.questDrop.Toggle() end
        end, tip = function() return Tr["Pick quests to abandon, and abandon them in one go."] end },
    } })
    foot:SetPoint("TOPLEFT")
    foot:SetPoint("TOPRIGHT")

    log.search, log.foot, log.body, log.rows, log.count, log.foldAll = search, foot, body, rows, count, foldAll
    log.columns = columns
end

local function Window()
    W = ns.Window{
        name = "MedalUIQuestLog", named = Tr["Quest Log"], side = 1, opaque = true, exclusive = true,
        closeTip = Tr["Close the quest log."],
        Close = function() log.Close() end,
        Lifted = function() return { MainMenuBarBackpackButton } end,
    }
    page = { key = "quests", label = Tr["Quests"], tip = Tr["Every quest in your log."], glyph = "quests", order = 1,
        flex = true, height = 120, bandUsed = true, bandFlush = true,
        Available = function() return true end,
        Build = Build,
        Refresh = function() log.Refresh() end,
    }
    W.Page(page)
    W.Build()
    frame = W.window
    frame:HookScript("OnHide", function()
        if search then search:ClearFocus() end
        if ns.questDrop then ns.questDrop.Close() end
        orders.Close()
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalUIQuestLog") end
    -- the log changed: drawn again at the next frame, while it is open
    Q.Listen(function() dirty = true end)
    WP.OnChange(function() dirty = true end)
    WP.OnTick(function()
        if not frame:IsShown() then return end
        for _, r in ipairs(rows) do
            local q = r:IsShown() and r.data and r.data.quest
            if q and r.far:IsShown() then r.far:SetText(WP.Distance(q.id)) end
        end
    end)
    frame:HookScript("OnUpdate", function() if dirty then log.Refresh() end end)
    log.frame, log.window = frame, W
end

function log.AnyOpen()
    local folded = ns.db.questLogFolded or {}
    for _, q in ipairs(quests) do
        if not folded[q.zone] then return true end
    end
    return false
end

function log.Open()
    if not W then return end
    if not W.Current() then W.Select(page) end
    W.SetShown(true)
end

function log.Close()
    if W then W.SetShown(false) end
end

function log.Toggle()
    if not frame then return end
    if frame:IsShown() then log.Close() else log.Open() end
end

function log.IsShown() return frame ~= nil and frame:IsShown() end

-- The key's own binding (Bindings.xml), under the header console/minimap.lua
-- names.
BINDING_NAME_MEDALUI_QUESTLOG = Tr["Quest log"]
function MedalUIToggleQuestLog()
    if log.On() and frame then
        log.Toggle()
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

-- ------------------------------------------------------- the game's log
-- The quest log key's keys are bound to ours (an override, so the game's
-- binding stays as it was set); again when the bindings change, if the
-- keys did (an override set says the bindings changed too). Not in combat:
-- the override waits for its end.
local keys = CreateFrame("Frame")
local bound = ""
local function Bind()
    local list = { GetBindingKey and GetBindingKey("TOGGLEQUESTLOG") }
    local now = table.concat(list, " ")
    if now == bound then return end
    if InCombatLockdown() then
        ns.OutOfCombat(Bind)
        return
    end
    bound = now
    ClearOverrideBindings(keys)
    for _, key in ipairs(list) do SetOverrideBinding(keys, false, key, "MEDALUI_QUESTLOG") end
end

-- Whatever opens the game's log opens ours: Classic's QuestLogFrame, shown,
-- is closed again and ours toggled; retail's log is the map's, so after
-- ToggleQuestLog the map it opened is closed again and ours toggled.
local function Take()
    if QuestLogFrame then
        QuestLogFrame:HookScript("OnShow", function(self)
            HideUIPanel(self)
            log.Toggle()
        end)
    elseif ToggleQuestLog then
        hooksecurefunc("ToggleQuestLog", function()
            if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
            log.Toggle()
        end)
    end
end

-- Retail's map: its quest panel folded away, and the button that opens it
-- gone; the map's own setting for it kept off.
local mapDone
local function Map()
    if mapDone or not (WorldMapFrame and QuestMapFrame) then return end
    mapDone = true
    if SetCVar then pcall(SetCVar, "questLogOpen", "0") end
    local function Panel()
        if not QuestMapFrame:IsShown() then return end
        if QuestMapFrame_Hide then QuestMapFrame_Hide() else QuestMapFrame:Hide() end
    end
    QuestMapFrame:HookScript("OnShow", Panel)
    if WorldMapFrame.SidePanelToggle then
        WorldMapFrame.SidePanelToggle:Hide()
        hooksecurefunc(WorldMapFrame.SidePanelToggle, "Show", function(self) self:Hide() end)
    end
    Panel()
end

ns.On("PLAYER_LOGIN", function()
    if not log.On() then return end
    Window()
    Bind()
    ns.On("UPDATE_BINDINGS", Bind)
    Take()
    Map()
    ns.On("ADDON_LOADED", Map)
end)
