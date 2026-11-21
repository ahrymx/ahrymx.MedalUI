-- The Rolls window (2026-11-21): the game's roll frames, minimal, and the
-- log of the item rolled on, in one small box.
--
--   (icon) [Item]                  (need)(greed)(pass)   <- a roll you owe: one line each,
--   ==============-------------                              its time left under it
--   v [Item]                                0:12  x      <- the log: the current item (or the
--      Alfa         (dice) need               87            latest), folded by its head
--      Bravo        (coin) greed              40         <- its members: the leader, then by
--      Charlie             ...                              choice, then by roll
--
-- It pops up as a roll starts (in place of the game's frames, unless the
-- Roll window option is off), a roll line going as you choose; once every
-- roll is chosen and the item decided, a box that popped up by itself
-- closes after LINGER seconds. The Loot tab's die (loot.lua) shows and
-- hides it by hand; shown so, it stays. Dragged anywhere, its place kept
-- in rollsPlace. No secure frame: in combat too.
local _, ns = ...
local Tr = ns.L

local LH = C_LootHistory
local HISTORY = LH and LH.GetSortedDropsForEncounter and LH.GetInfoForEncounter
local WIDTH, PAD = 250, 4
local LINE, BUTTON, BAR = 20, 18, 2             -- a roll line, its choice buttons, its time bar
local HEAD, ROW = 16, 14                        -- the log's head, a member's row
local INDENT, ROLL_W, HOW_W = 16, 26, 70
local LINGER = 8                                -- seconds the box stays once all is decided
local PASS = 5                                  -- Enum.EncounterLootDropRollState: passed (4: not chosen yet)
local ORDER = { [0] = 1, 2, 3, 4, 5, 6 }        -- need first, pass last
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.70, 0.66, 0.55 }
-- RollOnLoot's types, in the order their buttons stand; the transmog's art
-- is an atlas where the client has it
local CHOICES = {
    { type = 1, can = 6, tex = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", word = "need" },
    { type = 4, can = 13, atlas = "lootroll-toast-icon-transmog-up",
      tex = "Interface\\Minimap\\Tracking\\Transmogrifier", word = "transmog" },
    { type = 2, can = 7, tex = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", word = "greed" },
    { type = 3, can = 8, tex = "Interface\\Buttons\\UI-GroupLoot-DE-Up", word = "disenchant" },
    { type = 0, tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", word = "pass" },
}

local frame, logHead, empty
local lines, rows = {}, {}
local owed = {}                                 -- the rolls not yet chosen: { id, total, link, icon, quality, can }
local latest                                    -- the drop last updated: encounter id, lootListKey
local byHand, decidedAt = false, nil

local function Secret(v) return ns.IsSecret(v) end
local function Loot() return ns.loot or {} end

-- a choice in words (loot.lua's HOW names them in English)
local function Word(state)
    if state == 0 then return Tr["need"] elseif state == 1 then return Tr["off-spec"]
    elseif state == 2 then return Tr["transmog"] end
    return Tr["greed"]
end

local function ChoiceWord(word)
    if word == "need" then return Tr["need"] elseif word == "greed" then return Tr["greed"]
    elseif word == "transmog" then return Tr["transmog"] elseif word == "disenchant" then return Tr["disenchant"] end
    return Tr["pass"]
end

-- ------------------------------------------------------------- the log
-- The roll timer: the drop's, else its boss's. Its unit is not documented:
-- a value over 600 is milliseconds (no roll lasts ten minutes).
local function Left(d, info)
    local start, length = d.startTime, d.duration
    if start == nil or length == nil then start, length = info and info.startTime, info and info.duration end
    if start == nil or length == nil or Secret(start) or Secret(length) then return nil end
    local now = GetTime()
    if length > 600 then now = now * 1000 end
    local left = start + length - now
    if length > 600 then left = left / 1000 end
    if left < 0 then return nil end
    return left
end

local function Rolling(d)
    if Secret(d.winner) or Secret(d.allPassed) then return false end
    return d.winner == nil and not d.allPassed
end

-- the leader (or winner) first, then by choice (a need beats any greed,
-- whatever the numbers), then the highest roll; nothing secret is
-- compared: a secret roll ranks as no roll, a secret choice after every
-- choice, a secret name or win as not the leader
local function Rank(r, d)
    local lead = 0
    if not Secret(r.isWinner) and r.isWinner then lead = 2 end
    local w = d.winner
    if w == nil then w = d.currentLeader end
    if lead == 0 and w ~= nil and not Secret(w) and not Secret(r.playerName) and not Secret(w.playerName)
        and w.playerName ~= nil and w.playerName == r.playerName then
        lead = 1
    end
    local roll = r.roll
    if roll == nil or Secret(roll) then roll = -1 end
    local order = 9
    if not Secret(r.state) then order = ORDER[r.state] or 7 end
    return lead, roll, order
end

local function Members(d)
    local list = {}
    for i, r in ipairs(d.rollInfos or {}) do
        local lead, roll, order = Rank(r, d)
        table.insert(list, { info = r, lead = lead, roll = roll, order = order, i = i })
    end
    table.sort(list, function(a, b)
        if a.lead ~= b.lead then return a.lead > b.lead end
        if a.order ~= b.order then return a.order < b.order end
        if a.roll ~= b.roll then return a.roll > b.roll end
        return a.i < b.i
    end)
    return list
end

-- The item the log follows: the roll owed last, as the history has it;
-- else a drop still rolling (the one last updated first, then the newest
-- boss's); else the drop last updated; else the newest boss's last drop.
local function Logged()
    if not HISTORY then return nil end
    local infos = {}
    for _, info in ipairs(LH.GetAllEncounterInfos and LH.GetAllEncounterInfos() or {}) do
        table.insert(infos, info)
    end
    table.sort(infos, function(a, b) return (a.startTime or 0) > (b.startTime or 0) end)
    local want = owed[#owed] and owed[#owed].link
    local updated, live, last
    for n, info in ipairs(infos) do
        for _, d in ipairs(LH.GetSortedDropsForEncounter(info.encounterID) or {}) do
            local link, rolling = d.itemHyperlink, Rolling(d)
            if want and link == want and not Secret(link) and rolling then return d, info end
            local isLatest = latest and latest[1] == info.encounterID and latest[2] == d.lootListKey
            if isLatest then updated = { d, info } end
            if rolling and (isLatest or not live) then live = { d, info } end
            if n == 1 then last = { d, info } end
        end
    end
    local pick = live or updated or last
    if pick then return pick[1], pick[2] end
end

-- ----------------------------------------------------------------- parts
local function Clock(left)
    left = math.ceil(left)
    return string.format("%d:%02d", math.floor(left / 60), left % 60)
end

local function ClassColor(class)
    if class == nil or Secret(class) then return nil end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

local function Short(name)
    if name ~= nil and not Secret(name) and Loot().Short then return Loot().Short(name) end
    return name
end

local function Edge(t, link, quality)
    local L = Loot()
    local q = quality or (link and not Secret(link) and L.Quality and L.Quality(link)) or 1
    if L.QualityColor then t:SetColorTexture(L.QualityColor(q)) end
end

local function Tip(owner, link)
    if not link or Secret(link) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

-- a roll owed: its icon, its link, a button for each choice the game
-- allows, its time left as a bar under it
local function Line(i)
    if lines[i] then return lines[i] end
    local l = CreateFrame("Frame", nil, frame)
    l:SetSize(WIDTH - 2 * PAD, LINE + BAR + 1)
    l.edge = l:CreateTexture(nil, "ARTWORK", nil, 1)
    l.edge:SetSize(LINE, LINE)
    l.edge:SetPoint("TOPLEFT")
    l.icon = l:CreateTexture(nil, "ARTWORK", nil, 2)
    l.icon:SetSize(LINE - 2, LINE - 2)
    l.icon:SetPoint("CENTER", l.edge)
    l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    l.buttons = {}
    for n, c in ipairs(CHOICES) do
        local b = CreateFrame("Button", nil, l)
        b:SetSize(BUTTON, BUTTON)
        b.choice = c
        b.glyph = b:CreateTexture(nil, "ARTWORK")
        b.glyph:SetAllPoints()
        local atlas = c.atlas and b.glyph.SetAtlas and C_Texture and C_Texture.GetAtlasInfo
        if atlas and C_Texture.GetAtlasInfo(c.atlas) then
            b.glyph:SetAtlas(c.atlas)
        else
            b.glyph:SetTexture(c.tex)
        end
        local glow = b:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.15)
        b:SetScript("OnClick", function(self) ns.rolls.Choose(self:GetParent().roll, self.choice.type) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ChoiceWord(self.choice.word))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        l.buttons[n] = b
    end
    l.link = ns.PlainText(l, 11)
    l.link:SetPoint("LEFT", l.edge, "RIGHT", 5, 0)
    l.link:SetJustifyH("LEFT")
    l.link:SetWordWrap(false)
    l.track = l:CreateTexture(nil, "ARTWORK")
    l.track:SetPoint("BOTTOMLEFT")
    l.track:SetPoint("BOTTOMRIGHT")
    l.track:SetHeight(BAR)
    l.track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
    l.bar = l:CreateTexture(nil, "ARTWORK", nil, 1)
    l.bar:SetPoint("BOTTOMLEFT")
    l.bar:SetHeight(BAR)
    l.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self) Tip(self, self.roll and self.roll.link) end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lines[i] = l
    return l
end

local function TimeBar(l)
    local r = l.roll
    local left = GetLootRollTimeLeft and GetLootRollTimeLeft(r.id) or 0
    local share = r.total and r.total > 0 and math.max(0, math.min(1, left / r.total)) or 0
    l.bar:SetWidth(math.max(0.01, (WIDTH - 2 * PAD) * share))
end

local function FillLine(l, r)
    l.roll = r
    Edge(l.edge, r.link, r.quality)
    if r.icon then l.icon:SetTexture(r.icon) else l.icon:SetColorTexture(0.071, 0.067, 0.063, 1) end
    l.link:SetText(r.link or r.name or "")
    local right
    for n = #CHOICES, 1, -1 do
        local b, c = l.buttons[n], CHOICES[n]
        local can = c.can == nil or r.can[c.type]
        b:SetShown(can and true or false)
        if can then
            b:ClearAllPoints()
            if right then b:SetPoint("RIGHT", right, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", 0, -1) end
            right = b
        end
    end
    l.link:SetPoint("RIGHT", right, "LEFT", -4, 0)
    TimeBar(l)
end

-- the log's head: fold chevron, the item, its state, the box's cross
local function MakeHead()
    local h = CreateFrame("Button", nil, frame)
    h:SetSize(WIDTH - 2 * PAD, HEAD)
    h.chevron = h:CreateTexture(nil, "ARTWORK")
    h.chevron:SetSize(10, 10)
    h.chevron:SetPoint("LEFT", 1, 0)
    h.chevron:SetTexture(ns.media .. "strips\\chevron-down")
    h.close = CreateFrame("Button", nil, h)
    h.close:SetSize(12, 12)
    h.close:SetPoint("RIGHT", 0, 0)
    h.close.icon = h.close:CreateTexture(nil, "ARTWORK")
    h.close.icon:SetAllPoints()
    h.close.icon:SetTexture(ns.media .. "strips\\close")
    h.close.icon:SetVertexColor(DIM[1], DIM[2], DIM[3])
    h.close:SetScript("OnEnter", function(self) self.icon:SetVertexColor(0.9, 0.3, 0.25) end)
    h.close:SetScript("OnLeave", function(self) self.icon:SetVertexColor(DIM[1], DIM[2], DIM[3]) end)
    h.close:SetScript("OnClick", function() ns.rolls.Close() end)
    h.state = ns.Text(h, 10)
    h.state:SetPoint("RIGHT", h.close, "LEFT", -4, 0)
    h.link = ns.PlainText(h, 10)
    h.link:SetPoint("LEFT", INDENT, 0)
    h.link:SetPoint("RIGHT", h.state, "LEFT", -6, 0)
    h.link:SetJustifyH("LEFT")
    h.link:SetWordWrap(false)
    h:RegisterForClicks("LeftButtonUp")
    h:SetScript("OnClick", function(self)
        local link = self.drop and self.drop.itemHyperlink
        if link and not Secret(link) and ns.Linking() then
            ns.LinkInChat(link)
            return
        end
        ns.SetOption("rollsFolded", not ns.db.rollsFolded)
        ns.rolls.Draw()
    end)
    h:SetScript("OnEnter", function(self) Tip(self, self.drop and self.drop.itemHyperlink) end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() frame:StartMoving() end)
    h:SetScript("OnDragStop", function() ns.rolls.Dropped() end)
    return h
end

-- the head's right end: the clock while rolling, then the winner and their
-- roll, or passed
local function State(h, d, info)
    if Rolling(d) then
        local left = Left(d, info)
        h.state:SetText(left and Clock(left) or Tr["rolling"])
        h.state:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        return
    end
    local w = d.winner
    if w and not Secret(w) then
        local roll = w.roll
        if roll ~= nil and not Secret(roll) then roll = tostring(roll) elseif roll ~= nil then roll = "?" end
        local name = Short(w.playerName)
        h.state:SetText(roll and string.format("%s  %s", name or "", roll) or (name or ""))
        local c = ClassColor(w.playerClass)
        if c then h.state:SetTextColor(c.r, c.g, c.b) else h.state:SetTextColor(unpack(ns.colors.text)) end
        return
    end
    h.state:SetText(Tr["passed"])
    h.state:SetTextColor(DIM[1], DIM[2], DIM[3])
end

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - 2 * PAD, ROW)
    r.roll = ns.Text(r, 10)
    r.roll:SetPoint("RIGHT", -2, 0)
    r.roll:SetWidth(ROLL_W)
    r.roll:SetJustifyH("RIGHT")
    r.how = ns.Text(r, 10)
    r.how:SetPoint("LEFT", r, "RIGHT", -ROLL_W - HOW_W + 14, 0)
    r.die = r:CreateTexture(nil, "ARTWORK")
    r.die:SetSize(12, 12)
    r.die:SetPoint("LEFT", r, "RIGHT", -ROLL_W - HOW_W, 0)
    r.who = ns.Text(r, 10)
    r.who:SetPoint("LEFT", INDENT, 0)
    r.who:SetPoint("RIGHT", r, "RIGHT", -ROLL_W - HOW_W - 4, 0)
    r.who:SetJustifyH("LEFT")
    r.who:SetWordWrap(false)
    rows[i] = r
    return r
end

local function FillRow(r, m)
    local info = m.info
    local name = Short(info.playerName)
    if info.isSelf == true then name = (name or "") .. " " .. Tr["(you)"] end
    r.who:SetText(name or "?")
    local c = ClassColor(info.playerClass)
    if c then r.who:SetTextColor(c.r, c.g, c.b) else r.who:SetTextColor(unpack(ns.colors.text)) end
    local state = info.state
    local how = not Secret(state) and Loot().HOW and Loot().HOW[state]
    if Secret(state) then
        r.how:SetText("?")
        r.how:SetTextColor(DIM[1], DIM[2], DIM[3])
        r.die:Hide()
    elseif how then
        r.how:SetText(Word(state))
        r.how:SetTextColor(unpack(how[2]))
        r.die:SetShown(how[3] ~= nil)
        if how[3] then r.die:SetTexture(how[3]) end
    else
        r.how:SetText(state == PASS and Tr["pass"] or "…")
        r.how:SetTextColor(DIM[1], DIM[2], DIM[3])
        r.die:Hide()
    end
    local roll = info.roll
    if roll ~= nil and Secret(roll) then r.roll:SetText("?")
    else r.roll:SetText(roll and tostring(roll) or "") end
    local won = (not Secret(info.isWinner) and info.isWinner) or m.lead == 2
    if won then r.roll:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else r.roll:SetTextColor(unpack(ns.colors.text)) end
end

-- ------------------------------------------------------------------ draw
local function Draw()
    if not frame then return end
    local y = PAD
    for i, r in ipairs(owed) do
        local l = Line(i)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", PAD, -y)
        FillLine(l, r)
        l:Show()
        y = y + LINE + BAR + 3
    end
    for i = #owed + 1, #lines do lines[i]:Hide(); lines[i].roll = nil end
    local d, info = Logged()
    logHead.drop, logHead.info = d, info
    logHead:ClearAllPoints()
    logHead:SetPoint("TOPLEFT", PAD, -y)
    local open = not ns.db.rollsFolded
    local n = 0
    if d then
        logHead.link:SetText(d.itemHyperlink or "")
        State(logHead, d, info)
        if logHead.chevron.SetRotation then logHead.chevron:SetRotation(open and 0 or math.pi / 2) end
        logHead.chevron:Show()
        empty:Hide()
        y = y + HEAD
        if open then
            for _, m in ipairs(Members(d)) do
                n = n + 1
                local r = Row(n)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", PAD, -y)
                FillRow(r, m)
                r:Show()
                y = y + ROW
            end
        end
    else
        logHead.link:SetText("")
        logHead.state:SetText("")
        logHead.chevron:Hide()
        empty:Show()
        y = y + HEAD
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    frame:SetHeight(y + PAD)
    -- decided: nothing owed and the logged item settled
    if #owed == 0 and not (d and Rolling(d)) then
        decidedAt = decidedAt or GetTime()
    else
        decidedAt = nil
    end
end

-- ----------------------------------------------------------------- place
local function Place()
    local at = ns.db.rollsPlace
    frame:ClearAllPoints()
    if type(at) == "table" then
        frame:SetPoint(at.point or "BOTTOM", UIParent, at.relative or "BOTTOM", at.x or 0, at.y or 320)
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 320)
    end
end

local function Dropped()
    frame:StopMovingOrSizing()
    local point, _, relative, x, y = frame:GetPoint()
    ns.SetOption("rollsPlace", { point = point, relative = relative, x = x, y = y })
    Place()
end

local function Lit()
    if ns.side and ns.side.Changed then ns.side.Changed() end
end

local function Show(hand)
    if hand then byHand = true end
    Draw()
    frame:Show()
end

local function Close()
    frame:Hide()
end

-- ----------------------------------------------------------------- rolls
-- the game's roll frames: kept away while the option is on, given back as
-- it goes off
local function Game(on)
    if not UIParent.RegisterEvent then return end
    for _, e in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL" }) do
        if on then UIParent:RegisterEvent(e) else UIParent:UnregisterEvent(e) end
    end
end

local function Owe(id, total)
    for _, r in ipairs(owed) do if r.id == id then return end end
    if not GetLootRollItemInfo then return end
    local info = { GetLootRollItemInfo(id) }
    local texture, name, quality = info[1], info[2], info[4]
    if not texture and not name then return end
    local can = {}
    for _, c in ipairs(CHOICES) do
        if c.can then can[c.type] = info[c.can] and true or false end
    end
    table.insert(owed, { id = id, total = total or (GetLootRollTimeLeft and GetLootRollTimeLeft(id)) or 0,
        link = GetLootRollItemLink and GetLootRollItemLink(id), name = name, icon = texture, quality = quality,
        can = can })
end

local function Drop(id)
    for i = #owed, 1, -1 do
        if owed[i].id == id then table.remove(owed, i) end
    end
end

local function Choose(r, kind)
    if not r then return end
    RollOnLoot(r.id, kind)
    Drop(r.id)
    Draw()
end

local function Start()
    frame = CreateFrame("Frame", "MedalluinRolls", UIParent)
    frame:SetSize(WIDTH, 2 * PAD + HEAD)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", Dropped)
    local ink = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.92)
    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    frame:Hide()
    logHead = MakeHead()
    empty = ns.Text(logHead, 10)
    empty:SetPoint("LEFT", INDENT, 0)
    empty:SetTextColor(DIM[1], DIM[2], DIM[3])
    empty:SetText(Tr["No rolls yet."])
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalluinRolls") end
    Place()
    frame:SetScript("OnShow", Lit)
    frame:SetScript("OnHide", function()
        byHand, decidedAt = false, nil
        Lit()
    end)
    -- the time bars and the clock; the box gone once all is decided, if it
    -- popped up by itself
    local acc = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.1 then return end
        acc = 0
        for _, l in ipairs(lines) do if l:IsShown() and l.roll then TimeBar(l) end end
        if logHead.drop and Rolling(logHead.drop) then State(logHead, logHead.drop, logHead.info) end
        if decidedAt and not byHand and GetTime() - decidedAt >= LINGER then frame:Hide() end
    end)

    ns.On("START_LOOT_ROLL", function(_, id, total)
        if not ns.db.rollFrame then return end
        Owe(id, total)
        Show()
    end)
    ns.On("CANCEL_LOOT_ROLL", function(_, id)
        Drop(id)
        if frame:IsShown() then Draw() end
    end)
    ns.On("CANCEL_ALL_LOOT_ROLLS", function()
        owed = {}
        if frame:IsShown() then Draw() end
    end)
    for _, event in ipairs({ "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_UPDATE_DROP" }) do
        ns.On(event, function(_, encounter, key)
            if event == "LOOT_HISTORY_UPDATE_DROP" then latest = { encounter, key } end
            if frame:IsShown() then Draw() end
        end)
    end
    ns.OnSetting("rollFrame", function(on)
        Game(not on)
        if not on then
            owed = {}
            frame:Hide()
        end
    end)
    if ns.db.rollFrame then
        Game(false)
        -- rolls already open before a reload
        if GetActiveLootRollIDs then
            for _, id in ipairs(GetActiveLootRollIDs() or {}) do Owe(id) end
            if #owed > 0 then Show() end
        end
    end
end

ns.rolls = { lines = lines, rows = rows, owed = function() return owed end, Draw = Draw, Close = Close,
    Choose = Choose, Dropped = Dropped }
ns.On("PLAYER_LOGIN", function()
    Start()
    ns.rolls.frame, ns.rolls.head, ns.rolls.empty = frame, logHead, empty
end)

function ns.RollsShown() return frame ~= nil and frame:IsShown() end

function ns.ToggleRolls()
    if not frame then return end
    if frame:IsShown() then Close() else Show(true) end
end
