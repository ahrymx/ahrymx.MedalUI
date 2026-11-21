-- The Rolls window (2026-11-21; the card, the same day): the game's roll
-- frames and the log of the item rolled on, in one small box.
--
--   Supremus · 2 to roll                            x    <- the boss, what is left to roll
--   +----+ [Supremus Blade]                              <- the card: the roll owed now
--   |icon| 489 · One-Hand · One-Handed Swords · BoP
--   +----+ ^ +13 over Felsteel Edge                      <- against what you wear there
--   [Need] [Greed] [Mog] [Pass]                          <- unavailable ones greyed, in place
--   ==============---------------             0:24       <- red in the last LATE seconds
--   (chip)(chip)                                         <- every roll owed, when two or more
--   (icon) [Ashtongue Signet]  You chose Greed   0:18    <- a roll chosen, still running
--   v [Supremus Blade]        (d)1 (c)2 ...2 (x)1 0:12   <- the log: the tally of choices
--      Alfa        (dice) need        87  leads             (the winner once decided)
--      Ahrymx (you) ...                                  <- your row: a gold edge
--   ----------                                           <- the linger running out
--
-- It pops up as a roll starts (in place of the game's frames, unless the
-- Roll window option is off). The card holds the first roll owed, or the
-- chip clicked; a choice turns it into a stamp until the game ends the
-- roll. Once every roll is chosen and the item decided, a box that popped
-- up by itself closes after LINGER seconds. The Loot tab's die (loot.lua)
-- shows and hides it by hand; shown so, it stays. Dragged anywhere, its
-- place kept in rollsPlace. No secure frame: in combat too.
local _, ns = ...
local Tr = ns.L

local LH = C_LootHistory
-- The game's roll API, read through here so the simulation (rolls_sim.lua)
-- can stand in for it without touching a global: the item of a roll, its
-- link and time left (ms), a choice made, the history's bosses and drops.
local GAME = {
    history = LH and LH.GetSortedDropsForEncounter and LH.GetInfoForEncounter and true or false,
    Info = function(id) if GetLootRollItemInfo then return GetLootRollItemInfo(id) end end,
    Link = function(id) return GetLootRollItemLink and GetLootRollItemLink(id) end,
    Left = function(id) return GetLootRollTimeLeft and GetLootRollTimeLeft(id) or 0 end,
    Roll = function(id, kind) RollOnLoot(id, kind) end,
    Encounters = function() return LH and LH.GetAllEncounterInfos and LH.GetAllEncounterInfos() or {} end,
    Drops = function(encounter) return LH.GetSortedDropsForEncounter(encounter) end,
}
local api = GAME
local WIDTH, PAD = 270, 6
local TOP, ICON, BUTTON, BAR = 20, 40, 20, 4    -- the title band, the card's icon, a choice, the time bar
local TAB, XW, CHIP, STAMP = 20, 8, 22, 26                -- an item's tab (its icon), its cross; a chosen roll's stamp
local SHOWN, COLS = 6, 3                        -- bosses in the title row, as a grid: columns
local SRC_H = 16                                -- a boss's tab in the title row
local HEAD, ROW = 18, 15                        -- the log's head, a member's row
local INDENT, ROLL_W, HOW_W, MARK_W = 14, 26, 70, 40
local CARD = 6 + ICON + 6 + BUTTON + 16         -- the card: its item, its buttons, its time row
local CLOCK_W = 32                              -- the card's countdown, right of its bar
local MAX_ROWS = 10                             -- members listed while a card is up; the rest counted
local LATE = 10                                 -- seconds left when the time turns red
local LINGER = 8                                -- seconds the box stays once all is decided
local WAIT, PASS = 4, 5                         -- Enum.EncounterLootDropRollState: not chosen, passed
local ORDER = { [0] = 1, 2, 3, 4, 5, 6 }        -- need first, pass last
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local GOLD_B = { 0.878, 0.722, 0.290 }
local DIM = { 0.70, 0.66, 0.55 }
local OFF = { 0.42, 0.39, 0.33 }
local RED = { 0.784, 0.267, 0.227 }
local GREEN = { 0.420, 0.780, 0.361 }
local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local COIN = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
local MOG = "Interface\\Minimap\\Tracking\\Transmogrifier"
local NOPE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
-- RollOnLoot's types, in the order their buttons stand: GetLootRollItemInfo's
-- index of may-I (can) and of why-not (why); always: a button even when the
-- game refuses it, greyed (transmog and disenchant stand only when offered)
local CHOICES = {
    { type = 1, can = 6, why = 9, always = true, tex = DICE, word = "Need" },
    { type = 4, can = 13, atlas = "lootroll-toast-icon-transmog-up", tex = MOG, word = "Mog" },
    { type = 2, can = 7, why = 10, always = true, tex = COIN, word = "Greed" },
    { type = 3, can = 8, why = 11, tex = "Interface\\Buttons\\UI-GroupLoot-DE-Up", word = "Shard" },
    { type = 0, always = true, tex = NOPE, word = "Pass" },
}
-- the tally's order and glyphs, by roll state; WAIT has none (an ellipsis)
local TALLY = { { 0, DICE }, { 1, DICE }, { 2, MOG }, { 3, COIN }, { WAIT }, { PASS, NOPE } }
-- where an item goes: the inventory slots to compare with, the first worn
-- one; pair: the lower of the two, an empty one passed over (fill: an empty
-- one is an empty slot to fill)
local EQUIP = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_FINGER = { 11, 12, pair = true, fill = true }, INVTYPE_TRINKET = { 13, 14, pair = true, fill = true },
    INVTYPE_WEAPON = { 16, 17, pair = true }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18, 16 }, INVTYPE_RANGEDRIGHT = { 18, 16 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
}
local ARMOR, WEAPON = 4, 2                      -- item classes; armour subclasses 1-4: cloth to plate

local frame, top, card, logHead, empty, more, foot, linger
local tabs, stamps, rows, sources = {}, {}, {}, {}
local owed = {}                                 -- the rolls not yet chosen (Owe)
local chosen = {}                               -- the rolls chosen, still running: { roll, kind }
local pick                                      -- the roll id a tab brought to the card
local view                                      -- the item a tab brought to the log: { key } or { link }
local source                                    -- the boss a title tab brought up: its encounter id
local cleared = {}                              -- decided bosses cleared from the title, by encounter id
local icons = {}                                -- an item's icon by its link, kept from its roll
local latest                                    -- the drop last updated: encounter id, lootListKey
local byHand, decidedAt = false, nil

local function Secret(v) return ns.IsSecret(v) end

-- The window's texts at the Text size option's share of their own size
-- (each one's own kept as it was made), and the window at its Scale: its
-- 100% is BASE of the window as drawn (2026-11-21: 15% larger by default).
local BASE = 1.15
local texts = {}                -- font string -> its size at 100%
local function TextSize() return tonumber(ns.db.rollsTextSize) or 1.15 end
local function Sized(fs, size)
    texts[fs] = size
    local path, _, flags = fs:GetFont()
    fs:SetFont(path, size * TextSize(), flags or "")
    return fs
end
local function Text(parent, size) return Sized(ns.Text(parent, size), size) end
local function Plain(parent, size) return Sized(ns.PlainText(parent, size), size) end
local function Resize()
    for fs, size in pairs(texts) do Sized(fs, size) end
end
local function WindowScale() return (tonumber(ns.db.rollsScale) or 1) * BASE end
local function Loot() return ns.loot or {} end

-- a choice in words (loot.lua's HOW names them in English)
local function Word(state)
    if state == 0 then return Tr["need"] elseif state == 1 then return Tr["off-spec"]
    elseif state == 2 then return Tr["transmog"] end
    return Tr["greed"]
end

local function Button(word)
    if word == "Need" then return Tr["Need"] elseif word == "Greed" then return Tr["Greed"]
    elseif word == "Mog" then return Tr["Mog"] elseif word == "Shard" then return Tr["Shard"] end
    return Tr["Pass"]
end

local function KindWord(kind)
    for _, c in ipairs(CHOICES) do if c.type == kind then return Button(c.word) end end
    return ""
end

local function Glyph(tex, size) return string.format("|T%s:%d:%d|t", tex, size, size) end
local function Paint(t, c) t:SetTextColor(c[1], c[2], c[3]) end
local function Fill(t, c, a) t:SetColorTexture(c[1], c[2], c[3], a or 1) end

local function Clock(left)
    left = math.max(0, math.ceil(left))
    return string.format("%d:%02d", math.floor(left / 60), left % 60)
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

-- the members by choice; a secret choice is counted apart, as unknown
local function Counts(d)
    local n, unknown = {}, 0
    for _, r in ipairs(d.rollInfos or {}) do
        if Secret(r.state) then unknown = unknown + 1
        elseif r.state ~= nil then n[r.state] = (n[r.state] or 0) + 1 end
    end
    return n, unknown
end

local function Tally(d)
    local n, unknown = Counts(d)
    local out = {}
    for _, t in ipairs(TALLY) do
        if (n[t[1]] or 0) > 0 then table.insert(out, (t[2] and Glyph(t[2], 11) or "…") .. n[t[1]]) end
    end
    if unknown > 0 then table.insert(out, "?" .. unknown) end
    return table.concat(out, "  ")
end

-- The history's bosses, newest first: every one with a drop still rolling,
-- then decided ones not cleared, SHOWN in all. The second list marks the decided.
local function Encounters()
    local infos = {}
    for _, info in ipairs(api.Encounters() or {}) do
        table.insert(infos, info)
    end
    table.sort(infos, function(a, b) return (a.startTime or 0) > (b.startTime or 0) end)
    local list, decided, kept = {}, {}, {}
    for _, info in ipairs(infos) do
        local live = false
        for _, d in ipairs(api.Drops(info.encounterID) or {}) do
            if Rolling(d) then live = true; break end
        end
        if live then
            table.insert(list, info)
        elseif not cleared[tostring(info.encounterID)] then
            table.insert(kept, info)
        end
    end
    for _, info in ipairs(kept) do
        table.insert(list, info)
        decided[info] = true
    end
    while #list > SHOWN do table.remove(list) end
    return list, decided
end

-- the history's drop of an item, still rolling, and its boss
local function DropFor(link)
    if not api.history or not link or Secret(link) then return nil end
    for _, info in ipairs(Encounters()) do
        for _, d in ipairs(api.Drops(info.encounterID) or {}) do
            if d.itemHyperlink == link and Rolling(d) then return d, info end
        end
    end
end

-- a drop's own name: its boss and its place in the boss's loot
local function Key(info, d)
    local k = d.lootListKey
    if k == nil or Secret(k) then k = d.itemHyperlink end
    if k == nil or Secret(k) then return nil end
    return tostring(info.encounterID) .. ":" .. tostring(k)
end

-- The item tabs of one boss (src: its encounter id), in order: the rolls
-- owed (the card's choices), the rolls chosen and still running, then the
-- boss's other drops. A roll's own drop (by its link, while rolling) is its
-- tab, not another; a roll whose boss the history lacks shows under any.
local function Items(src)
    local list, mine = {}, {}
    local function Mine(r, chose)
        local _, inf = DropFor(r.link)
        if inf and inf.encounterID ~= src then return end
        table.insert(list, { roll = r, link = r.link, chosen = chose })
        if r.link and not Secret(r.link) then mine[r.link] = (mine[r.link] or 0) + 1 end
    end
    for _, r in ipairs(owed) do Mine(r) end
    for _, c in ipairs(chosen) do Mine(c.roll, true) end
    if not api.history or src == nil then return list end
    for _, info in ipairs(Encounters()) do
        if info.encounterID == src then
            for _, d in ipairs(api.Drops(info.encounterID) or {}) do
                local link, rolling = d.itemHyperlink, Rolling(d)
                if rolling and link and not Secret(link) and (mine[link] or 0) > 0 then
                    mine[link] = mine[link] - 1
                else
                    table.insert(list, { drop = d, info = info, key = Key(info, d), link = link,
                        done = not rolling })
                end
            end
        end
    end
    return list
end

-- the roll on the card: the one a chip brought forward, else the first owed
local function Current()
    if pick then
        for _, r in ipairs(owed) do if r.id == pick then return r end end
        pick = nil
    end
    return owed[1]
end

-- The item the log follows: the card's, as the history has it (else the
-- newest roll chosen); else a drop still rolling (the one last updated
-- first, then the newest boss's); else the drop last updated; else the
-- newest boss's last drop.
local function Logged()
    if not api.history then return nil end
    if view then
        if view.key then
            for _, info in ipairs(Encounters()) do
                for _, d in ipairs(api.Drops(info.encounterID) or {}) do
                    if Key(info, d) == view.key then return d, info end
                end
            end
        else
            local d, info = DropFor(view.link)
            if d then return d, info end
        end
        view = nil
    end
    local want = Current() or (chosen[#chosen] and chosen[#chosen].roll)
    want = want and want.link
    local list = Encounters()
    if source then
        local only
        for _, info in ipairs(list) do if info.encounterID == source then only = info end end
        if only then list = { only } end
    end
    local updated, live, last
    for n, info in ipairs(list) do
        for _, d in ipairs(api.Drops(info.encounterID) or {}) do
            local link, rolling = d.itemHyperlink, Rolling(d)
            if want and link == want and not Secret(link) and rolling then return d, info end
            local isLatest = latest and latest[1] == info.encounterID and latest[2] == d.lootListKey
            if isLatest then updated = { d, info } end
            if rolling and (isLatest or not live) then live = { d, info } end
            if n == 1 then last = { d, info } end
        end
    end
    local found = live or updated or last
    if found then return found[1], found[2] end
end

-- ------------------------------------------------------------ the item
local function Instant(link)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if f and link and not Secret(link) then return f(link) end
end

local function Level(link)
    local f = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    local lv = f and link and not Secret(link) and f(link)
    if lv and lv > 0 then return lv end
end

-- "489 · One-Hand · One-Handed Swords · BoP": its level, where it goes,
-- what it is (a weapon's kind, an armour's cloth to plate; for what is not
-- worn, its kind alone, no level) and its bind
local function Meta(r)
    local parts = {}
    local _, kind, sub, equip, _, class, subclass = Instant(r.link)
    local slot = equip and equip ~= "" and _G[equip]
    if slot == "" then slot = nil end
    local lv = slot and Level(r.link)
    if lv then table.insert(parts, tostring(lv)) end
    if slot then table.insert(parts, slot) end
    if slot and sub and sub ~= "" and sub ~= slot
        and (class == WEAPON or (class == ARMOR and subclass and subclass >= 1 and subclass <= 4)) then
        table.insert(parts, sub)
    elseif not slot and (sub or kind) then
        table.insert(parts, (sub and sub ~= "") and sub or kind)
    end
    if r.bop then table.insert(parts, Tr["BoP"]) end
    return table.concat(parts, " · "), lv, equip
end

local function WornName(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    return link and link:match("%[(.-)%]") or Tr["what you wear"]
end

-- against what you wear there: "up", "same" or "down", and its words;
-- nothing for what is not worn, or whose level is not known yet
local function Upgrade(lv, equip)
    local slots = equip and EQUIP[equip]
    if not slots or not lv or not ns.WornItemLevel then return nil end
    local worn, at
    for _, slot in ipairs(slots) do
        local w = ns.WornItemLevel(slot)
        if w == nil and slots.fill then return "up", Tr["Fills an empty slot"] end
        if w ~= nil and (worn == nil or w < worn) then worn, at = w, slot end
        if worn ~= nil and not slots.pair then break end
    end
    if worn == nil then return "up", Tr["Fills an empty slot"] end
    local diff = lv - worn
    if diff > 0 then return "up", string.format(Tr["+%d over %s"], diff, WornName(at))
    elseif diff < 0 then return "down", string.format(Tr["-%d under %s"], -diff, WornName(at)) end
    return "same", string.format(Tr["Same as %s"], WornName(at))
end

-- why the game refuses a choice: its own sentence, by the reason's number
local function Reason(r, c)
    local n = c.why and r.why[c.type]
    local text = n ~= nil and not Secret(n) and _G["LOOT_ROLL_INELIGIBLE_REASON" .. tostring(n)]
    return text or Tr["The game does not offer this choice on this item."]
end

-- ----------------------------------------------------------------- parts
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

-- an item's icon in its quality's edge
local function MakeIcon(parent, size)
    local edge = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    edge:SetSize(size, size)
    local icon = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetSize(size - 2, size - 2)
    icon:SetPoint("CENTER", edge)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return edge, icon
end

local function SetIcon(edge, icon, r)
    Edge(edge, r.link, r.quality)
    if r.icon then icon:SetTexture(r.icon) else icon:SetColorTexture(0.071, 0.067, 0.063, 1) end
end

-- a roll's seconds left, and its share of the whole
local function TimeLeft(r)
    local left = api.Left(r.id) or 0
    return left / 1000, r.total and r.total > 0 and math.max(0, math.min(1, left / r.total)) or 0
end

-- a time bar's fill and colour, red in the last LATE seconds; its clock
local function SetBar(bar, width, r, sec)
    local left, share = TimeLeft(r)
    bar:SetWidth(math.max(0.01, width * share))
    Fill(bar, left <= LATE and RED or GOLD, 0.9)
    if sec then
        sec:SetText(Clock(left))
        Paint(sec, left <= LATE and RED or GOLD)
    end
end

-- a choice: its glyph and word, its edge lit on hover; greyed and still
-- in place when the game refuses it, its tooltip saying why
local function Look(b, hot, down)
    local on = b:IsEnabled()
    Fill(b.edge, not on and { 0.15, 0.13, 0.11 } or hot and GOLD or { 0.227, 0.196, 0.149 })
    Fill(b.fill, not on and { 0.082, 0.075, 0.063 } or down and { 0.204, 0.165, 0.086 }
        or hot and { 0.271, 0.220, 0.114 } or { 0.114, 0.102, 0.082 })
    Paint(b.word, on and ns.colors.text or OFF)
    b.glyph:SetDesaturated(not on)
    b.glyph:SetAlpha(on and 1 or 0.45)
end

local function ChoiceButton(parent, c)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(BUTTON)
    b.choice = c
    b.edge = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.edge:SetAllPoints()
    b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.fill:SetPoint("TOPLEFT", 1, -1)
    b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.glyph:SetSize(13, 13)
    local atlas = c.atlas and b.glyph.SetAtlas and C_Texture and C_Texture.GetAtlasInfo
    if atlas and C_Texture.GetAtlasInfo(c.atlas) then b.glyph:SetAtlas(c.atlas) else b.glyph:SetTexture(c.tex) end
    b.word = Text(b, 10)
    b.word:SetText(Button(c.word))
    b.word:SetPoint("CENTER", 8, 0)
    b.glyph:SetPoint("RIGHT", b.word, "LEFT", -3, 0)
    b:SetScript("OnClick", function(self) ns.rolls.Choose(card.roll, self.choice.type) end)
    b:SetScript("OnEnter", function(self)
        Look(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Button(self.choice.word))
        if not self:IsEnabled() and card.roll then
            GameTooltip:AddLine(Reason(card.roll, self.choice), RED[1], RED[2], RED[3], true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) Look(self); GameTooltip:Hide() end)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then Look(self, true, true) end end)
    b:SetScript("OnMouseUp", function(self) Look(self, self:IsMouseOver()) end)
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    return b
end

-- the card: the roll owed now, its item at length, its choices, its time
local function MakeCard()
    local c = CreateFrame("Frame", nil, frame)
    c:SetSize(WIDTH - 2, CARD)
    c.edge, c.icon = MakeIcon(c, ICON)
    c.edge:SetPoint("TOPLEFT", PAD, -6)
    c.hit = CreateFrame("Frame", nil, c)
    c.hit:SetAllPoints(c.edge)
    c.hit:EnableMouse(true)
    c.hit:SetScript("OnEnter", function(self) Tip(self, c.roll and c.roll.link) end)
    c.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c.link = Plain(c, 12)
    c.link:SetPoint("TOPLEFT", c.edge, "TOPRIGHT", 7, -1)
    c.link:SetPoint("RIGHT", -PAD, 0)
    c.link:SetJustifyH("LEFT")
    c.link:SetWordWrap(false)
    c.meta = Text(c, 10)
    c.meta:SetPoint("TOPLEFT", c.link, "BOTTOMLEFT", 0, -3)
    c.meta:SetPoint("RIGHT", -PAD, 0)
    c.meta:SetJustifyH("LEFT")
    c.meta:SetWordWrap(false)
    Paint(c.meta, DIM)
    c.arrow = c:CreateTexture(nil, "ARTWORK")
    c.arrow:SetSize(9, 9)
    c.arrow:SetPoint("TOPLEFT", c.meta, "BOTTOMLEFT", 0, -3)
    c.up = Text(c, 10)
    c.up:SetJustifyH("LEFT")
    c.up:SetWordWrap(false)
    c.buttons = {}
    for n, choice in ipairs(CHOICES) do c.buttons[n] = ChoiceButton(c, choice) end
    c.track = c:CreateTexture(nil, "ARTWORK")
    c.track:SetPoint("BOTTOMLEFT", PAD, 6)
    c.track:SetPoint("BOTTOMRIGHT", -PAD - CLOCK_W, 6)
    c.track:SetHeight(BAR)
    c.track:SetColorTexture(0, 0, 0, 1)
    c.bar = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.bar:SetPoint("BOTTOMLEFT", c.track)
    c.bar:SetHeight(BAR)
    c.sec = Text(c, 10)
    c.sec:SetPoint("RIGHT", c, "BOTTOMRIGHT", -PAD, 8)
    c.sec:SetJustifyH("RIGHT")
    return c
end

local BAR_W = WIDTH - 2 - 2 * PAD - CLOCK_W

local function FillCard(r)
    card.roll = r
    SetIcon(card.edge, card.icon, r)
    card.link:SetText(r.link or r.name or "")
    local meta, lv, equip = Meta(r)
    card.meta:SetText(meta)
    local way, words = Upgrade(lv, equip)
    card.way = way
    card.up:SetText(words or "")
    card.arrow:SetShown(way == "up" or way == "down")
    local tint = way == "up" and GREEN or way == "down" and RED or DIM
    if way == "up" or way == "down" then
        card.arrow:SetTexture(ns.media .. "strips\\chevron-" .. way)
        card.arrow:SetVertexColor(tint[1], tint[2], tint[3])
    end
    Paint(card.up, tint)
    card.up:ClearAllPoints()
    if card.arrow:IsShown() then card.up:SetPoint("LEFT", card.arrow, "RIGHT", 2, 0)
    else card.up:SetPoint("LEFT", card.arrow, "LEFT", 0, 0) end
    card.up:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
    -- the choices standing share the row evenly
    local stand = {}
    for n, c in ipairs(CHOICES) do
        local can = c.can == nil or r.can[c.type]
        local b = card.buttons[n]
        b:SetShown((can or c.always) and true or false)
        if b:IsShown() then
            b:SetEnabled(can and true or false)
            Look(b)
            table.insert(stand, b)
        end
    end
    local w = (WIDTH - 2 - 2 * PAD - 3 * (#stand - 1)) / #stand
    for i, b in ipairs(stand) do
        b:ClearAllPoints()
        b:SetWidth(w)
        b:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 3), -(6 + ICON + 6))
    end
    SetBar(card.bar, BAR_W, r, card.sec)
end

-- A tab: an item, its icon in its quality's edge, lit while its rolls
-- are listed. A roll owed: a click puts it on the card (its rolls listed
-- with it), its time under it. Any other: a click lists its rolls; a
-- decided one has a cross beside it that clears it from the tabs.
local function Tab(i)
    if tabs[i] then return tabs[i] end
    local c = CreateFrame("Button", nil, frame)
    c:SetSize(TAB, TAB + 3)
    c:SetFrameLevel(logHead:GetFrameLevel() + 2)
    c.ring = c:CreateTexture(nil, "ARTWORK", nil, 0)
    c.edge, c.icon = MakeIcon(c, TAB)
    c.edge:SetPoint("TOPLEFT")
    c.ring:SetPoint("TOPLEFT", c.edge, -1, 1)
    c.ring:SetPoint("BOTTOMRIGHT", c.edge, 1, -1)
    Fill(c.ring, GOLD_B)
    c.track = c:CreateTexture(nil, "ARTWORK")
    c.track:SetPoint("BOTTOMLEFT")
    c.track:SetWidth(TAB)
    c.track:SetHeight(2)
    c.track:SetColorTexture(0, 0, 0, 1)
    c.bar = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.bar:SetPoint("BOTTOMLEFT")
    c.bar:SetHeight(2)
    c:SetScript("OnClick", function(self)
        local item = self.item
        if not item then return end
        if item.roll and not item.chosen then
            pick, view = item.roll.id, nil
        elseif item.roll then
            view = { link = item.link }
        else
            view = item.key and { key = item.key } or nil
        end
        ns.rolls.Draw()
    end)
    c:SetScript("OnEnter", function(self) Tip(self, self.item and self.item.link) end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tabs[i] = c
    return c
end

-- a tab's item drawn: its icon (a roll's own, else the item's), its time
local function FillTab(c, item)
    c.item = item
    if item.roll then
        SetIcon(c.edge, c.icon, item.roll)
    else
        local link = item.link
        local icon = link and not Secret(link) and icons[link]
        local id = not icon and link and not Secret(link) and tonumber(link:match("item:(%d+)"))
        if id and C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
        if not icon then icon = select(5, Instant(link)) end
        SetIcon(c.edge, c.icon, { link = link, icon = icon })
    end
    c.track:SetShown(item.roll ~= nil)
    c.bar:SetShown(item.roll ~= nil)
    if item.roll then SetBar(c.bar, TAB, item.roll) end
    c:SetAlpha(item.done and 0.75 or 1)
end

-- a stamp: a roll chosen, still running: what you chose, how many are
-- still choosing, its time
local function Stamp(i)
    if stamps[i] then return stamps[i] end
    local s = CreateFrame("Frame", nil, frame)
    s:SetSize(WIDTH - 2, STAMP)
    s.edge, s.icon = MakeIcon(s, CHIP)
    s.edge:SetPoint("LEFT", PAD, 0)
    s.sec = Text(s, 10)
    s.sec:SetPoint("RIGHT", -PAD, 0)
    s.link = Plain(s, 10)
    s.link:SetPoint("TOPLEFT", s.edge, "TOPRIGHT", 6, 0)
    s.link:SetPoint("RIGHT", s.sec, "LEFT", -6, 0)
    s.link:SetJustifyH("LEFT")
    s.link:SetWordWrap(false)
    s.line = Text(s, 10)
    s.line:SetPoint("BOTTOMLEFT", s.edge, "BOTTOMRIGHT", 6, 0)
    s.line:SetPoint("RIGHT", s.sec, "LEFT", -6, 0)
    s.line:SetJustifyH("LEFT")
    s.line:SetWordWrap(false)
    Paint(s.line, DIM)
    s:EnableMouse(true)
    s:SetScript("OnEnter", function(self) Tip(self, self.roll and self.roll.link) end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stamps[i] = s
    return s
end

local function FillStamp(s, c)
    s.roll = c.roll
    SetIcon(s.edge, s.icon, c.roll)
    s.link:SetText(c.roll.link or c.roll.name or "")
    local line = string.format(Tr["You chose %s"], "|cffe0b84a" .. KindWord(c.kind) .. "|r")
    local d = DropFor(c.roll.link)
    local waiting = d and (Counts(d)[WAIT] or 0) or 0
    if waiting > 0 then line = line .. " · " .. string.format(Tr["waiting on %d"], waiting) end
    s.line:SetText(line)
    local left = TimeLeft(c.roll)
    s.sec:SetText(Clock(left))
    Paint(s.sec, left <= LATE and RED or GOLD)
end

-- the box's title band: the boss, what is left to roll, the cross
local function MakeTop()
    local t = CreateFrame("Frame", nil, frame)
    t:SetSize(WIDTH - 2, TOP)
    local band = t:CreateTexture(nil, "BACKGROUND", nil, 2)
    band:SetAllPoints()
    band:SetColorTexture(0.110, 0.098, 0.075, 1)
    local rule = t:CreateTexture(nil, "BORDER")
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(1)
    rule:SetColorTexture(0.173, 0.153, 0.114, 1)
    t.close = CreateFrame("Button", nil, t)
    t.close:SetSize(12, 12)
    t.close:SetPoint("TOPRIGHT", -4, -4)
    t.close.icon = t.close:CreateTexture(nil, "ARTWORK")
    t.close.icon:SetAllPoints()
    t.close.icon:SetTexture(ns.media .. "strips\\close")
    t.close.icon:SetVertexColor(DIM[1], DIM[2], DIM[3])
    t.close:SetScript("OnEnter", function(self) self.icon:SetVertexColor(0.9, 0.3, 0.25) end)
    t.close:SetScript("OnLeave", function(self) self.icon:SetVertexColor(DIM[1], DIM[2], DIM[3]) end)
    t.close:SetScript("OnClick", function() ns.rolls.Close() end)
    t.title = Text(t, 11)
    t.title:SetPoint("TOPLEFT", PAD + 1, -4)
    t.title:SetPoint("RIGHT", t.close, "LEFT", -6, 0)
    t.title:SetJustifyH("LEFT")
    t.title:SetWordWrap(false)
    Paint(t.title, GOLD)
    t:EnableMouse(true)
    t:RegisterForDrag("LeftButton")
    t:SetScript("OnDragStart", function() frame:StartMoving() end)
    t:SetScript("OnDragStop", function() ns.rolls.Dropped() end)
    return t
end

-- A boss's tab in the title row: its name, how many of its rolls are
-- yours to make, and once all its rolls are decided a cross that clears it
local function SourceTab(i)
    if sources[i] then return sources[i] end
    local b = CreateFrame("Button", nil, top)
    b:SetHeight(SRC_H)
    b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.fill:SetAllPoints()
    b.fill:SetColorTexture(0.173, 0.153, 0.114, 1)
    b.line = b:CreateTexture(nil, "BORDER")
    b.line:SetPoint("BOTTOMLEFT")
    b.line:SetPoint("BOTTOMRIGHT")
    b.line:SetHeight(2)
    Fill(b.line, GOLD_B)
    b.text = Text(b, 10)
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.count = Text(b, 10)
    Paint(b.count, GOLD)
    b.close = CreateFrame("Button", nil, b)
    b.close:SetSize(XW + 4, XW + 4)
    b.close:SetPoint("RIGHT", -2, 0)
    b.close.icon = b.close:CreateTexture(nil, "ARTWORK")
    b.close.icon:SetSize(XW, XW)
    b.close.icon:SetPoint("CENTER")
    b.close.icon:SetTexture(ns.media .. "strips\\close")
    b.close.icon:SetVertexColor(DIM[1], DIM[2], DIM[3])
    b.close:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(0.9, 0.3, 0.25)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Tr["Clear this boss's rolls from the list."])
        GameTooltip:Show()
    end)
    b.close:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(DIM[1], DIM[2], DIM[3])
        GameTooltip:Hide()
    end)
    b.close:SetScript("OnClick", function(self)
        local id = self:GetParent().id
        if id == nil then return end
        cleared[tostring(id)] = true
        view = nil
        GameTooltip:Hide()
        ns.rolls.Draw()
    end)
    b:SetScript("OnClick", function(self)
        if self.id == nil then return end
        source, view = self.id, nil
        ns.rolls.Draw()
    end)
    -- the whole name, which the cell may cut
    b:SetScript("OnEnter", function(self)
        if not self.name then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.name)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() frame:StartMoving() end)
    b:SetScript("OnDragStop", function() ns.rolls.Dropped() end)
    sources[i] = b
    return b
end

-- a grid cell's tab: the name cut to what is left of the cell's width
-- after your rolls owed (right) and the cross
local function FillSource(b, info, n, decided, lit, w)
    b.id = info.encounterID
    local name = info.encounterName
    if name == nil or Secret(name) then name = Tr["Rolls"] end
    b.name = name
    b:SetWidth(w)
    b.close:SetShown(decided)
    local right = decided and (XW + 8) or 6
    b.count:SetText(n > 0 and tostring(n) or "")
    b.count:ClearAllPoints()
    b.count:SetPoint("RIGHT", -right, 0)
    local cw = n > 0 and (b.count:GetStringWidth() + 4) or 0
    b.text:SetText(name)
    b.text:SetWidth(math.max(1, w - 6 - right - cw))
    Paint(b.text, lit and GOLD or DIM)
    b.fill:SetShown(lit)
    b.line:SetShown(lit)
    b:SetAlpha((decided and not lit) and 0.75 or 1)
end

-- The title row: a tab per boss, a grid of COLS by two rows; with
-- no history, the title alone. Its height.
local function Sources(info)
    local list, decided = Encounters()
    if not api.history or #list == 0 then
        for _, b in ipairs(sources) do b:Hide(); b.id = nil end
        top.title:Show()
        top:SetHeight(TOP)
        return TOP
    end
    top.title:Hide()
    -- your rolls owed, by boss
    local owes = {}
    for _, r in ipairs(owed) do
        local _, inf = DropFor(r.link)
        if inf then owes[inf.encounterID] = (owes[inf.encounterID] or 0) + 1 end
    end
    -- a grid of COLS, beside the window's cross
    local shown = info and info.encounterID
    local x0, gap = PAD - 2, 3
    local w = math.floor((WIDTH - 2 - 22 - x0 - gap * (COLS - 1)) / COLS)
    local at = 2
    for i, inf in ipairs(list) do
        local b = SourceTab(i)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        FillSource(b, inf, owes[inf.encounterID] or 0, decided[inf] == true, inf.encounterID == shown, w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x0 + col * (w + gap), -(2 + row * (SRC_H + 2)))
        b:Show()
        at = 2 + row * (SRC_H + 2)
    end
    for i = #list + 1, #sources do sources[i]:Hide(); sources[i].id = nil end
    local h = at + SRC_H + 2
    top:SetHeight(h)
    return h
end

local function Title(d, info)
    local name = info and info.encounterName
    if name == nil or Secret(name) then name = Tr["Rolls"] end
    local tail
    if #owed > 0 then tail = string.format(Tr["%d to roll"], #owed)
    elseif d and not Rolling(d) and #chosen == 0 then tail = Tr["all decided"] end
    top.title:SetText(tail and (name .. "  |cffb3a88c· " .. tail .. "|r") or name)
end

-- the log's head: fold chevron, the item, its state
local function MakeHead()
    local h = CreateFrame("Button", nil, frame)
    h:SetSize(WIDTH - 2, HEAD)
    local band = h:CreateTexture(nil, "BACKGROUND", nil, 2)
    band:SetAllPoints()
    band:SetColorTexture(0.086, 0.078, 0.059, 1)
    local rule = h:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT")
    rule:SetPoint("TOPRIGHT")
    rule:SetHeight(1)
    rule:SetColorTexture(0.173, 0.153, 0.114, 1)
    h.chevron = h:CreateTexture(nil, "ARTWORK")
    h.chevron:SetSize(10, 10)
    h.chevron:SetTexture(ns.media .. "strips\\chevron-down")
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
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() frame:StartMoving() end)
    h:SetScript("OnDragStop", function() ns.rolls.Dropped() end)
    return h
end

-- the foot's right end: the clock while rolling (none while the card above
-- shows the same item's), then the winner and their roll, or passed
local function State(h, d, info)
    if Rolling(d) then
        local left = Left(d, info)
        h.state:SetText(h.same and "" or ("|cffc4a557" .. (left and Clock(left) or Tr["rolling"]) .. "|r"))
        Paint(h.state, DIM)
        return
    end
    local w = d.winner
    if w and not Secret(w) then
        local roll = w.roll
        if roll ~= nil and not Secret(roll) then roll = tostring(roll) elseif roll ~= nil then roll = "?" end
        local name = string.format(Tr["%s wins"], Short(w.playerName) or "?")
        h.state:SetText(roll and (name .. " · " .. roll) or name)
        Paint(h.state, GOLD_B)
        return
    end
    h.state:SetText(Tr["passed"])
    Paint(h.state, DIM)
end

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - 2, ROW)
    r.lit = r:CreateTexture(nil, "BACKGROUND", nil, 3)
    r.lit:SetAllPoints()
    if r.lit.SetGradient and CreateColor then
        r.lit:SetColorTexture(1, 1, 1, 1)
        r.lit:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.22),
            CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
    else
        Fill(r.lit, GOLD, 0.12)
    end
    r.me = r:CreateTexture(nil, "ARTWORK")
    r.me:SetPoint("TOPLEFT")
    r.me:SetPoint("BOTTOMLEFT")
    r.me:SetWidth(2)
    Fill(r.me, GOLD_D)
    -- the mark and the roll as wide as their words, each by its right edge:
    -- a fixed width let a wider text sit off the column (2026-11-21)
    r.mark = Text(r, 9)
    r.mark:SetPoint("RIGHT", -PAD, 0)
    r.mark:SetJustifyH("RIGHT")
    Paint(r.mark, GOLD)
    r.roll = Text(r, 10)
    r.roll:SetPoint("RIGHT", -PAD - MARK_W, 0)
    r.roll:SetJustifyH("RIGHT")
    local right = PAD + MARK_W + ROLL_W
    r.how = Text(r, 10)
    r.how:SetPoint("LEFT", r, "RIGHT", -right - HOW_W + 14, 0)
    r.die = r:CreateTexture(nil, "ARTWORK")
    r.die:SetSize(12, 12)
    r.die:SetPoint("LEFT", r, "RIGHT", -right - HOW_W, 0)
    r.who = Text(r, 10)
    r.who:SetPoint("LEFT", INDENT, 0)
    r.who:SetPoint("RIGHT", r, "RIGHT", -right - HOW_W - 4, 0)
    r.who:SetJustifyH("LEFT")
    r.who:SetWordWrap(false)
    rows[i] = r
    return r
end

local function FillRow(r, m)
    local info = m.info
    local name = Short(info.playerName)
    local me = not Secret(info.isSelf) and info.isSelf == true
    if me then name = (name or "") .. " " .. Tr["(you)"] end
    r.who:SetText(name or "?")
    r.me:SetShown(me)
    local c = ClassColor(info.playerClass)
    if c then r.who:SetTextColor(c.r, c.g, c.b) else r.who:SetTextColor(unpack(ns.colors.text)) end
    local state = info.state
    local secret = Secret(state)
    local how = not secret and Loot().HOW and Loot().HOW[state]
    if secret then
        r.how:SetText(Tr["hidden"])
        Paint(r.how, DIM)
        r.die:Hide()
    elseif how then
        r.how:SetText(Word(state))
        r.how:SetTextColor(unpack(how[2]))
        r.die:SetShown(how[3] ~= nil)
        if how[3] then r.die:SetTexture(how[3]) end
    elseif state == PASS then
        r.how:SetText(Tr["pass"])
        Paint(r.how, DIM)
        r.die:SetTexture(NOPE)
        r.die:Show()
    else
        r.how:SetText(Tr["choosing\226\128\166"])
        Paint(r.how, OFF)
        r.die:Hide()
    end
    local roll = info.roll
    if roll ~= nil and Secret(roll) then r.roll:SetText("?")
    else r.roll:SetText(roll and tostring(roll) or "") end
    local won = (not Secret(info.isWinner) and info.isWinner) or m.lead == 2
    r.lit:SetShown(won and true or false)
    if won or m.lead == 1 then Paint(r.roll, GOLD_B) else r.roll:SetTextColor(unpack(ns.colors.text)) end
    r.mark:SetText(won and Tr["wins"] or m.lead == 1 and Tr["leads"] or "")
    r:SetAlpha(not secret and state == PASS and 0.6 or 1)
end

-- ------------------------------------------------------------------ draw
local function Draw()
    if not frame then return end
    local y = 1
    local d, info = Logged()
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", 1, -y)
    Title(d, info)
    y = y + Sources(info)
    local r = Current()
    if r then
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 1, -y)
        FillCard(r)
        card:Show()
        y = y + CARD
    else
        card:Hide()
        card.roll = nil
    end
    for i, c in ipairs(chosen) do
        local s = Stamp(i)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", 1, -y)
        FillStamp(s, c)
        s:Show()
        y = y + STAMP
    end
    for i = #chosen + 1, #stamps do stamps[i]:Hide(); stamps[i].roll = nil end
    -- the head: the fold chevron, then a tab per item, wrapping to another
    -- row when full; lit: the item listed below
    local items = Items(info and info.encounterID)
    local open = not ns.db.rollsFolded
    logHead.drop, logHead.info = d, info
    logHead:ClearAllPoints()
    logHead:SetPoint("TOPLEFT", 1, -y)
    local x0 = INDENT + 4
    local x, at = x0, 4
    for i, item in ipairs(items) do
        local c = Tab(i)
        FillTab(c, item)
        local w = c:GetWidth()
        if x + w > WIDTH - PAD and x > x0 then x, at = x0, at + TAB + 7 end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", x, -y - at)
        local lit = (item.drop ~= nil and item.drop == d)
            or (item.roll ~= nil and d ~= nil and item.link ~= nil and item.link == d.itemHyperlink and Rolling(d))
            or (item.roll ~= nil and d == nil and item.roll == r)
        c.ring:SetShown(lit and true or false)
        c:Show()
        x = x + w + 5
    end
    for i = #items + 1, #tabs do tabs[i]:Hide(); tabs[i].item = nil end
    local headH = #items > 0 and (at + TAB + 3 + 4) or HEAD
    logHead:SetHeight(headH)
    logHead.chevron:ClearAllPoints()
    logHead.chevron:SetPoint("TOPLEFT", PAD - 1, #items > 0 and -(4 + (TAB - 10) / 2) or -(HEAD - 10) / 2)
    y = y + headH
    local n, hidden = 0, 0
    logHead.same = d ~= nil and r ~= nil and d.itemHyperlink ~= nil and not Secret(d.itemHyperlink)
        and d.itemHyperlink == r.link
    foot.same = logHead.same
    empty:SetShown(d == nil and #items == 0)
    if d then
        if logHead.chevron.SetRotation then logHead.chevron:SetRotation(open and 0 or math.pi / 2) end
        logHead.chevron:Show()
        if open then
            y = y + 2
            -- under a card a long list stops short, the rest counted
            local members = Members(d)
            local cap = (r and #members > MAX_ROWS) and MAX_ROWS - 1 or #members
            for k, m in ipairs(members) do
                if k > cap then
                    hidden = hidden + 1
                else
                    n = n + 1
                    local row = Row(n)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 1, -y)
                    FillRow(row, m)
                    row:Show()
                    y = y + ROW
                end
            end
        end
    else
        logHead.chevron:Hide()
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    more:SetShown(hidden > 0)
    if hidden > 0 then
        more:SetText(string.format(Tr["+ %d more"], hidden))
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", INDENT + 1, -y - 2)
        y = y + ROW
    end
    -- the foot: the tally of choices; the clock, or the winner
    foot:SetShown(d ~= nil)
    if d then
        foot.text:SetText(Tally(d))
        State(foot, d, info)
        foot:ClearAllPoints()
        foot:SetPoint("TOPLEFT", 1, -y - 2)
        y = y + 2 + HEAD
    end
    -- decided: nothing owed and the logged item settled
    if #owed == 0 and not (d and Rolling(d)) then
        decidedAt = decidedAt or GetTime()
    else
        decidedAt = nil
    end
    local lingering = decidedAt ~= nil and not byHand
    linger:SetShown(lingering)
    if lingering then
        linger:ClearAllPoints()
        linger:SetPoint("TOPLEFT", PAD, -y - 2)
        y = y + 3
    end
    frame:SetHeight(y + 3)
end

-- the time bars and clocks, the stamps of rolls run out, the linger
local function Tick()
    if card:IsShown() and card.roll then SetBar(card.bar, BAR_W, card.roll, card.sec) end
    for _, c in ipairs(tabs) do
        if c:IsShown() and c.item and c.item.roll then SetBar(c.bar, TAB, c.item.roll) end
    end
    local ran = false
    for i = #chosen, 1, -1 do
        if TimeLeft(chosen[i].roll) <= 0 then table.remove(chosen, i); ran = true end
    end
    if ran then Draw() end
    for i, s in ipairs(stamps) do if s:IsShown() and chosen[i] then FillStamp(s, chosen[i]) end end
    if logHead.drop and Rolling(logHead.drop) then State(foot, logHead.drop, logHead.info) end
    if decidedAt and not byHand then
        local share = 1 - (GetTime() - decidedAt) / LINGER
        linger:SetWidth(math.max(0.01, (WIDTH - 2 * PAD) * math.max(0, share)))
        if share <= 0 then frame:Hide() end
    end
end

-- ----------------------------------------------------------------- place
local function Place()
    -- its place is kept in the screen's units; the frame's own are its scale's
    local at, k = ns.db.rollsPlace, WindowScale()
    frame:SetScale(k)
    frame:ClearAllPoints()
    if type(at) == "table" then
        frame:SetPoint(at.point or "BOTTOM", UIParent, at.relative or "BOTTOM", (at.x or 0) / k, (at.y or 320) / k)
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 320 / k)
    end
end

local function Dropped()
    frame:StopMovingOrSizing()
    local point, _, relative, x, y = frame:GetPoint()
    local k = WindowScale()
    ns.SetOption("rollsPlace", { point = point, relative = relative, x = x * k, y = y * k })
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
-- The game's roll dialog, kept away while the option is on and given back
-- as it goes off. The roll events are taken from UIParent and from every
-- other frame of the game's that hears them (GetFramesRegisteredForEvent:
-- the client's own loot container, where it listens itself), each one's
-- taken events kept to give back. A dialog shown anyway (a frame that
-- registered after us, or heard the roll before we did) is hidden as it shows.
local ROLL_EVENTS = { "START_LOOT_ROLL", "CANCEL_LOOT_ROLL" }
local taken = {}                                -- frame -> { event = true }
local hiding, hooked = false, {}

local function GameFrames()
    local list = { GroupLootContainer }
    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do table.insert(list, _G["GroupLootFrame" .. i]) end
    return list
end

local function HideGame()
    for _, f in pairs(GameFrames()) do
        if not hooked[f] and f.HookScript then
            hooked[f] = true
            f:HookScript("OnShow", function(self) if hiding then self:Hide() end end)
        end
        if f:IsShown() then f:Hide() end
    end
end

local function Game(on)
    hiding = not on
    if not UIParent.RegisterEvent then return end
    for _, e in ipairs(ROLL_EVENTS) do
        if on then UIParent:RegisterEvent(e) else UIParent:UnregisterEvent(e) end
    end
    if on then
        for f, es in pairs(taken) do
            for e in pairs(es) do pcall(f.RegisterEvent, f, e) end
        end
        taken = {}
        return
    end
    if GetFramesRegisteredForEvent then
        for _, e in ipairs(ROLL_EVENTS) do
            for _, f in ipairs({ GetFramesRegisteredForEvent(e) }) do
                if f ~= UIParent and f ~= ns.eventFrame and f.UnregisterEvent then
                    f:UnregisterEvent(e)
                    taken[f] = taken[f] or {}
                    taken[f][e] = true
                end
            end
        end
    end
    HideGame()
end

local function Owe(id, total)
    for _, r in ipairs(owed) do if r.id == id then return end end
    local info = { api.Info(id) }
    local texture, name, quality = info[1], info[2], info[4]
    if not texture and not name then return end
    local can, why = {}, {}
    for _, c in ipairs(CHOICES) do
        if c.can then can[c.type] = info[c.can] and true or false end
        if c.why then why[c.type] = info[c.why] end
    end
    local link = api.Link(id)
    if link and texture and not Secret(link) and not Secret(texture) then icons[link] = texture end
    source = nil
    table.insert(owed, { id = id, total = total or api.Left(id) or 0,
        link = link, name = name, icon = texture, quality = quality,
        bop = info[5] and true or false, can = can, why = why })
end

local function Drop(id)
    for i = #owed, 1, -1 do
        if owed[i].id == id then table.remove(owed, i) end
    end
    for i = #chosen, 1, -1 do
        if chosen[i].roll.id == id then table.remove(chosen, i) end
    end
end

-- a choice: the roll leaves the card; a need or greed stays as a stamp
-- until the game ends the roll
local function Choose(r, kind)
    if not r then return end
    api.Roll(r.id, kind)
    Drop(r.id)
    if kind ~= 0 then table.insert(chosen, { roll = r, kind = kind }) end
    Draw()
end

local function Start()
    frame = CreateFrame("Frame", "MedalUIRolls", UIParent)
    frame:SetSize(WIDTH, TOP + HEAD + 4)
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
    ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.94)
    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    Fill(edge, GOLD_D)
    frame:Hide()
    top = MakeTop()
    card = MakeCard()
    card:Hide()
    logHead = MakeHead()
    -- the foot: a rule, the tally
    foot = CreateFrame("Frame", nil, frame)
    foot:SetSize(WIDTH - 2, HEAD)
    local footRule = foot:CreateTexture(nil, "BORDER")
    footRule:SetPoint("TOPLEFT", PAD, 0)
    footRule:SetPoint("TOPRIGHT", -PAD, 0)
    footRule:SetHeight(1)
    footRule:SetColorTexture(0.173, 0.153, 0.114, 1)
    foot.text = Text(foot, 10)
    foot.text:SetPoint("LEFT", INDENT + 4, -1)
    Paint(foot.text, DIM)
    foot.state = Text(foot, 10)
    foot.state:SetPoint("RIGHT", -PAD, -1)
    foot:Hide()
    empty = Text(logHead, 10)
    empty:SetPoint("LEFT", INDENT + 4, 0)
    Paint(empty, DIM)
    empty:SetText(Tr["No rolls yet."])
    more = Text(frame, 10)
    Paint(more, DIM)
    more:Hide()
    linger = frame:CreateTexture(nil, "ARTWORK")
    linger:SetHeight(2)
    linger:SetWidth(WIDTH - 2 * PAD)
    if linger.SetGradient and CreateColor then
        linger:SetColorTexture(1, 1, 1, 1)
        linger:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 1),
            CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.1))
    else
        Fill(linger, GOLD)
    end
    linger:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalUIRolls") end
    Place()
    frame:SetScript("OnShow", Lit)
    frame:SetScript("OnHide", function()
        byHand, decidedAt = false, nil
        Lit()
    end)
    local acc = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.1 then return end
        acc = 0
        Tick()
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
        owed, chosen, pick, view, source = {}, {}, nil, nil, nil
        if frame:IsShown() then Draw() end
    end)
    -- an item's level arrives late the first time it is seen
    ns.On("GET_ITEM_INFO_RECEIVED", function()
        if frame:IsShown() and card.roll then Draw() end
    end)
    for _, event in ipairs({ "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_UPDATE_DROP" }) do
        ns.On(event, function(_, encounter, key)
            if event == "LOOT_HISTORY_UPDATE_DROP" then latest = { encounter, key } end
            if frame:IsShown() then Draw() end
        end)
    end
    ns.OnSetting("rollsScale", Place)
    ns.OnSetting("rollsTextSize", function()
        Resize()
        if frame:IsShown() then Draw() end
    end)
    ns.OnSetting("rollFrame", function(on)
        Game(not on)
        if not on then
            owed, chosen, pick = {}, {}, nil
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

-- The simulation's door: Use(source) puts its API in the game's place (it
-- answers the game's rolls through to the game), nil gives the game's back;
-- either way the simulated rolls (ids below 0) are forgotten, the real ones
-- kept. Start and Cancel act out START_LOOT_ROLL and CANCEL_LOOT_ROLL;
-- Redraw after the history moved.
local function Use(feed)
    api = feed or GAME
    for i = #owed, 1, -1 do if owed[i].id < 0 then table.remove(owed, i) end end
    for i = #chosen, 1, -1 do if chosen[i].roll.id < 0 then table.remove(chosen, i) end end
    if pick and pick < 0 then pick = nil end
    if frame and frame:IsShown() then
        if #owed == 0 and #chosen == 0 and not feed then frame:Hide() else Draw() end
    end
end

local function SimStart(id, total)
    Owe(id, total)
    Show()
end

local function SimCancel(id)
    Drop(id)
    if frame and frame:IsShown() then Draw() end
end

local function Redraw()
    if frame and frame:IsShown() then Draw() end
end

ns.rolls = { tabs = tabs, stamps = stamps, rows = rows, owed = function() return owed end,
    chosen = function() return chosen end, Draw = Draw, Close = Close, Choose = Choose, Dropped = Dropped,
    GAME = GAME, Use = Use, Start = SimStart, Cancel = SimCancel, Redraw = Redraw }
ns.On("PLAYER_LOGIN", function()
    Start()
    ns.rolls.frame, ns.rolls.top, ns.rolls.card, ns.rolls.head = frame, top, card, logHead
    ns.rolls.empty, ns.rolls.more, ns.rolls.linger = empty, more, linger
    ns.rolls.foot, ns.rolls.cleared, ns.rolls.sources = foot, cleared, sources
end)

function ns.RollsShown() return frame ~= nil and frame:IsShown() end

function ns.ToggleRolls()
    if not frame then return end
    if frame:IsShown() then Close() else Show(true) end
end
