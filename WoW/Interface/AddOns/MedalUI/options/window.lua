-- MedalUI's settings window: a sidebar down the left lists the pages
-- under their categories (pages.lua's), each heading with its glyph, with a
-- search over every option above them; the page shown has a header (its
-- title, where it sits, its master's switch) over its options, each group a
-- card of rows under a title band, each row its label, a line saying what
-- it does, and its control at the right. A page whose groups are on two
-- sheets or more has a tab for each under its header, its cards one column
-- across the page; another has its cards in two columns. Modules, the page
-- it opens on, has a card for each part with a master, a tab for each
-- category with one. The head across its top, or the window itself, drags
-- it; where it is left is kept. The
-- footer names the profile being edited and, once an option that waits for
-- one has changed, asks for a reload.
--
-- Built the first time it opens (/mdlui, the minimap button, the button on
-- Options > AddOns > MedalUI); pages.lua says what is on it.
local _, ns = ...
local Tr = ns.L

local UI = ns.OptionsUI
local C = UI.colors

local W, H = 900, 600
local SIDE_W, BAR_H, FOOT, EDGE = 200, 34, 40, 1 -- the sidebar; the window's head and footer; its edge
local HEAD_TOP, RIGHT = EDGE + BAR_H, 16         -- a page's header: its top, and its right margin
local SEC_GAP, CARD_PAD, BAND_H = 8, 12, 28
local ROW_GAP = 4                       -- between a card's rows
-- (2026-11-26, the user's pick "Ledger") a page's header: two rails across
-- the page, flush under the window's head: the tabs' (the chrome's ink),
-- then the index's (raised), when the page has one
local TAB_H, INDEX_H = 32, 26
local HEAD_H = TAB_H
local ITEM_H, CAT_H, SEARCH_H, LINK_H = 28, 42, 26, 20
local CARD_H, CARD_GAP = 44, 8
local X = EDGE + SIDE_W + 18            -- the body's left
local HEAD_X = EDGE + SIDE_W            -- the header's rails' left, against the sidebar
local PAD = X - HEAD_X                  -- the rails' words in line with the body
local ROUND = ns.media .. "strips\\round"
local GREEN = { 0.42, 0.78, 0.36 }

local pages        -- pages.lua's, built at login
local categories
local window, side, nav, navChild, search, body, scroll, thumb, flash
local finds        -- a search's page: the sections it matched, lent by their own
local footProfile, footReload, footDot, footChip, footButton
local built = {}   -- page frames by path ("general", "console/unit")
ns.optionPages = built
local current      -- the path shown
local lastTab = {} -- each tabbed page's tab, by page id
local lastIn = {}  -- each category's item last shown, by name
local reloadAt     -- what the reload options were at login
local controls = {}
ns.optionControls = controls
local place = {}   -- each path's category and sidebar item
local index = {}   -- what search looks through
local query        -- what it is looking for, while it shows what it found
local results = {}

-- ------------------------------------------------------------ pages
local function Find(path)
    local id, tab = tostring(path):match("^([^/]+)/?(.*)$")
    for _, page in ipairs(pages) do
        if page.id == id then
            if not page.tabs then return page, nil end
            tab = tab ~= "" and tab or lastTab[id] or page.tabs[1].id
            for _, t in ipairs(page.tabs) do
                if t.id == tab then return page, t end
            end
            return page, page.tabs[1]
        end
    end
end

local function Each(fn)
    for _, page in ipairs(pages) do
        if page.tabs then
            for _, tab in ipairs(page.tabs) do fn(tab, page.id .. "/" .. tab.id, page, tab) end
        else
            fn(page, page.id, page, nil)
        end
    end
end

-- A sidebar item's name.
local function ItemName(item)
    local page, tab = Find(item)
    if not page then return item end
    return tab and tab.name or page.name
end

-- A category of one page named as it is (the Overhead): its heading opens
-- the page, no row under it, and the crumb says the name once.
local function Single(cat)
    return #cat.items == 1 and ItemName(cat.items[1]) == cat.name
end

-- A tab's parent (a tab `under` another, as Paging under Action Bars): its
-- name, for the crumb, or nil.
local function Parent(item)
    local page, tab = Find(item)
    if not (tab and tab.under) then return nil end
    for _, t in ipairs(page.tabs) do
        if t.id == tab.under then return t.name end
    end
end

-- A sheet's name: its page's own (Party's "Position & look"), or the
-- vocabulary's (pages.lua's OPTION_SHEETS).
local function SheetName(content, id)
    if content.sheetNames and content.sheetNames[id] then return content.sheetNames[id] end
    for _, sh in ipairs(ns.OPTION_SHEETS) do
        if sh[1] == id then return sh[2] end
    end
    return id
end

-- Where an option is, for search: "Console > Action Bars > Elements > Text".
local function Where(path, title, sheet)
    local at = place[path]
    local up = at and Parent(at.item)
    local w = at and (at.cat.name .. " > " .. (up and (up .. " > ") or "") .. ItemName(at.item)) or path
    if at and Single(at.cat) then w = at.cat.name end
    if sheet then w = w .. " > " .. sheet end
    return title and (w .. " > " .. title) or w
end

-- Every path's category and item.
local function Places()
    for _, cat in ipairs(categories) do
        for _, item in ipairs(cat.items) do
            local page, tab = Find(item)
            if page then
                place[tab and (page.id .. "/" .. tab.id) or page.id] = { cat = cat, item = item }
            end
        end
    end
end

-- The options that take effect after a reload, and the profile: what they
-- were at login.
local function ReloadKeys(fn)
    fn("consoleProfile")
    Each(function(content)
        if content.master and content.master.reload then fn(content.master.key) end
        for _, group in ipairs(content.groups) do
            if group.switch and group.switch.reload then fn(group.switch.key) end
            for _, item in ipairs(group.items) do
                if item.reload then fn(item.key) end
            end
        end
    end)
end
local function NeedsReload()
    local needs = false
    ReloadKeys(function(key)
        if ns.db[key] ~= reloadAt[key] then needs = true end
    end)
    return needs
end

-- ------------------------------------------------------------ a page
-- An option's control: in a section's row (row true), or a header's switch
-- (row "switch", label by it).
local function Control(parent, spec, width, row, label)
    local c
    if row == "switch" then
        c = UI.Switch(parent, spec, label)
    elseif spec.kind == "check" then
        c = UI.Check(parent, spec, width, row)
    elseif spec.kind == "choice" then
        -- two or three short answers, side by side, in a row with room
        if row == true and UI.Segmentable(spec, width) then
            c = UI.Segment(parent, spec, width)
        else
            c = UI.Choice(parent, spec, width, row)
        end
    elseif spec.kind == "color" then
        c = UI.Color(parent, spec, width, row)
    elseif spec.kind == "slider" then
        c = UI.Slider(parent, spec, width, row)
    elseif spec.kind == "key" then
        c = UI.Key(parent, spec, width)
    elseif spec.kind == "note" then
        c = UI.Note(parent, spec, width)
    elseif spec.kind == "grid" then
        c = UI.Grid(parent, spec, width)
    else
        c = UI.Button(parent, spec.label, math.min(width, 200), 24, spec.click, spec.tip)
    end
    -- a control drawn greyed while another option is off, or while its
    -- page's own test says no (spec.needs; content.enabled) unless it is
    -- for every profile there (spec.always)
    c.needs, c.always, c.can = spec.needs, spec.always, spec.can
    -- a key control is found by its binding's name
    if spec.key or spec.command then controls[spec.key or spec.command] = c end
    return c
end

local ShowSheet, SetVariant
local Layout, Found, Thumb, Choose   -- (folding, the chips: defined further down)

-- (2026-11-26, the user's pick "Ledger") the index: its own rail under the
-- tabs', each section shown by name (its title up to a ":") between small
-- gold diamonds, when there are three or more; a click opens its section
-- there and scrolls to it. The section at the scroll's top is lit,
-- underlined in gold. Names past the rail's right go in a "+N" word's list.
local function Chips(f)
    local head = f.head
    f.chips = f.chips or {}
    local shown = {}
    for _, sec in ipairs(f.sections) do
        if sec.chipName and (not f.sheet or sec.sheet == f.sheet) and (not sec.variant or sec.variant == f.variant) then
            table.insert(shown, sec)
        end
    end
    local on = #shown >= 3
    local y = -(TAB_H + INDEX_H / 2)
    head.index:SetShown(on)
    head.indexRule:SetShown(on)
    head:SetHeight(TAB_H + (on and INDEX_H or 0))
    local x = PAD
    local room = head:GetWidth()
    if not room or room <= 0 then room = W - HEAD_X - EDGE end
    room = room - (RIGHT - EDGE)
    -- how many fit: all, or as many as leave room for the "+N"
    head.measure = head.measure or UI.Plain(head, 12)
    head.measure:Hide()
    local function Width(name)
        head.measure:SetText(name)
        return math.ceil(head.measure:GetStringWidth() or 0) + 4
    end
    local fit, used = 0, x
    for i, sec in ipairs(on and shown or {}) do
        local nw = Width(sec.chipName)
        if used + nw > room then break end
        fit, used = i, used + nw + 18
    end
    if on and fit < #shown then
        fit, used = 0, x
        for _, sec in ipairs(shown) do
            local nw = Width(sec.chipName)
            if used + nw + 18 + Width("+" .. #shown) > room then break end
            fit, used = fit + 1, used + nw + 18
        end
    end
    for i, sec in ipairs(on and shown or {}) do
        local b = f.chips[i]
        if not b then
            b = CreateFrame("Button", nil, head)
            b:SetHeight(INDEX_H - 4)
            b.text = UI.Plain(b, 12, C.dim)
            b.text:SetPoint("CENTER", 0, 0)
            b.under = UI.Fill(b, "ARTWORK", C.gold)
            b.under:SetHeight(2)
            b.under:SetPoint("BOTTOMLEFT", 0, 0)
            b.under:SetPoint("BOTTOMRIGHT", 0, 0)
            -- the diamond after it: a small square, turned
            b.dot = UI.Fill(head, "ARTWORK", C.goldDark)
            b.dot:SetSize(4, 4)
            b.dot:SetRotation(math.pi / 4)
            b:SetScript("OnClick", function(self)
                Choose({ path = f.path, section = self.section, control = self.section })
            end)
            b:SetScript("OnEnter", function(self)
                self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
            end)
            b:SetScript("OnLeave", function() ns.LightChips() end)
            f.chips[i] = b
        end
        b.section = sec
        b.text:SetText(sec.chipName)
        local bw = math.ceil(b.text:GetStringWidth() or 0) + 4
        b:SetWidth(bw)
        b:ClearAllPoints()
        b:SetPoint("LEFT", head, "TOPLEFT", x, y)
        local fits = i <= fit
        b:SetShown(fits)
        b.dot:ClearAllPoints()
        b.dot:SetPoint("CENTER", head, "TOPLEFT", x + bw + 9, y)
        b.dot:SetShown(fits and i < #shown)
        if fits then x = x + bw + 18 end
    end
    -- the rest, in a list under a "+N"
    local rest = on and #shown - fit or 0
    if rest > 0 and not head.rest then
        local r = CreateFrame("Button", nil, head)
        r:SetHeight(INDEX_H - 4)
        r.text = UI.Plain(r, 12, C.gold)
        r.text:SetPoint("CENTER", 0, 0)
        r:SetScript("OnClick", function(self)
            local choices = {}
            for i = self.fit + 1, #self.secs do choices[#choices + 1] = { i, self.secs[i].chipName } end
            UI.OpenMenu(self, { choices = choices, get = function() return nil end, set = function(i)
                local sec = self.secs[i]
                Choose({ path = f.path, section = sec, control = sec })
            end })
        end)
        r:SetScript("OnEnter", function(self)
            self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3])
        end)
        r:SetScript("OnLeave", function(self) self.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
        head.rest = r
    end
    if head.rest then
        head.rest.secs, head.rest.fit = shown, fit
        head.rest:SetShown(rest > 0)
        if rest > 0 then
            head.rest.text:SetText("+" .. rest)
            head.rest:SetWidth(math.ceil(head.rest.text:GetStringWidth() or 0) + 4)
            head.rest:ClearAllPoints()
            head.rest:SetPoint("LEFT", head, "TOPLEFT", x, y)
        end
    end
    for i = (on and #shown or 0) + 1, #f.chips do
        f.chips[i]:Hide()
        f.chips[i].dot:Hide()
    end
end

-- the name of the section at the scroll's top lit, the rest dim
function ns.LightChips()
    local f = current and built[current]
    if not (f and f.chips and scroll) then return end
    local at = scroll:GetVerticalScroll() or 0
    local lit
    for _, b in ipairs(f.chips) do
        if b:IsShown() and b.section and b.section.top then
            if not lit or b.section.top <= at + 4 then lit = b end
        end
    end
    for _, b in ipairs(f.chips) do
        local on = b == lit
        local t = on and C.goldBright or C.dim
        b.text:SetTextColor(t[1], t[2], t[3])
        b.under:SetShown(on)
    end
end

-- The tabs shown: each sheet with a section of the variant shown, left to
-- right; the one shown cut into the page under it, gilded along its top.
local function Strip(f)
    local x = PAD - 6
    for _, b in ipairs(f.tabs or { f.head.only }) do
        local any = b == f.head.only
        for _, sec in ipairs(f.sections) do
            if sec.sheet == b.sheet and (not sec.variant or sec.variant == f.variant) then any = true end
        end
        b.any = any
        b:SetShown(any)
        if any then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f.head, "TOPLEFT", x, -4)
            x = x + b:GetWidth() + 2
        end
        local on = b.sheet == f.sheet
        b.foot:SetShown(on)
        b.cut:SetShown(on)
        for _, e in ipairs(b.sides) do e:SetShown(on) end
        local c = on and C.goldBright or C.dim
        b.text:SetTextColor(c[1], c[2], c[3])
    end
    Chips(f)
end

-- A page's header, over its body (2026-11-26: no title and no crumb, the
-- sidebar says where it is; the user's pick "Ledger"): the tabs' rail, in
-- the chrome's ink flush under the window's head, its sheets' tabs at the
-- left (a page of no sheets: one tab, its name); at its right its master's
-- switch, the variant's switch or an aside (Simulate), and a (?) holding the
-- rest of its intro, its own scope and where else its options are. Under
-- it, the index's rail (Chips). Shown with its page.
local function Header(f, content, path, page, tab)
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT", window, "TOPLEFT", HEAD_X, -HEAD_TOP)
    head:SetPoint("TOPRIGHT", window, "TOPRIGHT", -EDGE, -HEAD_TOP)
    head:SetHeight(HEAD_H)
    local rail = UI.Fill(head, "BACKGROUND", C.chrome, 1)
    rail:SetPoint("TOPLEFT", 0, 0)
    rail:SetPoint("TOPRIGHT", 0, 0)
    rail:SetHeight(TAB_H)
    head.index = UI.Fill(head, "BACKGROUND", C.raised, 1)
    head.index:SetPoint("TOPLEFT", 0, -TAB_H)
    head.index:SetPoint("TOPRIGHT", 0, -TAB_H)
    head.index:SetHeight(INDEX_H)
    head.index:Hide()
    head.indexRule = UI.Fill(head, "BORDER", C.line)
    head.indexRule:SetHeight(1)
    head.indexRule:SetPoint("TOPLEFT", 0, -(TAB_H + INDEX_H - 1))
    head.indexRule:SetPoint("TOPRIGHT", 0, -(TAB_H + INDEX_H - 1))
    head.indexRule:Hide()
    local at = place[path]
    head.name = at and ItemName(at.item) or (tab and tab.name or page.name)
    -- the page's own scope, where it is not its category's (under its name in the sidebar)
    local scope = content.scope ~= (at and at.cat.scope) and content.scope or nil
    local more = content.more and content.also and (content.more .. "\n\n" .. content.also)
        or content.more or content.also
    if scope then more = more and (scope .. ".\n\n" .. more) or (scope .. ".") end
    local right = {}   -- the strip's right, from the edge in
    if content.master then
        local m = Control(head, content.master, nil, "switch", Tr["Enabled"])
        f.master = m
        table.insert(f.controls, m)
        table.insert(right, m)
    end
    local function Tab(id, name)
        local b = CreateFrame("Button", nil, head)
        b.sheet, b.name = id, name
        -- down to the rail's foot, over its hairline: the shown one opens into the page
        b:SetHeight(TAB_H - 4)
        b.lift = UI.Fill(b, "BACKGROUND", C.lift, 2)
        b.lift:SetAllPoints()
        b.lift:Hide()
        b.cut = UI.Fill(b, "BACKGROUND", C.page, 1)
        b.cut:SetAllPoints()
        b.sides = {}
        for i, edge in ipairs({ "LEFT", "RIGHT" }) do
            local e = UI.Fill(b, "BORDER", C.lineStrong)
            e:SetWidth(1)
            e:SetPoint("TOP" .. edge, 0, 0)
            e:SetPoint("BOTTOM" .. edge, 0, 0)
            b.sides[i] = e
        end
        b.text = UI.Serif(b, 12.5, C.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetText(name)
        b:SetWidth(math.ceil(b.text:GetStringWidth()) + 28)
        -- the shown tab's gilt edge, along its top
        b.foot = UI.Fill(b, "OVERLAY", C.gold)
        b.foot:SetHeight(2)
        b.foot:SetPoint("TOPLEFT", 0, 0)
        b.foot:SetPoint("TOPRIGHT", 0, 0)
        return b
    end
    if not f.sheets then
        -- the page's one tab, its name: lit, nothing to switch to
        head.only = Tab(nil, head.name)
    end
    if f.sheets then
        f.tabs = {}
        for _, id in ipairs(f.sheets) do
            local b = Tab(id, SheetName(content, id))
            b:SetScript("OnClick", function(self) ShowSheet(f, self.sheet) end)
            b:SetScript("OnEnter", function(self)
                if f.sheet ~= self.sheet then
                    self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
                    self.lift:Show()
                end
            end)
            b:SetScript("OnLeave", function(self)
                self.lift:Hide()
                Strip(f)
            end)
            table.insert(f.tabs, b)
        end
        -- at the tabs' right: which variant the rows edit (Party: the
        -- console's or the group frame's), or the page's aside (Simulate)
        local aside
        if content.variants then
            local spec = { kind = "choice", label = Tr["Editing"], choices = content.variants, line = false,
                tip = Tr["Which party frames the options below set."],
                get = function() return f.variant end,
                set = function(v) SetVariant(f, v) end }
            aside = UI.Segment(head, spec, UI.TextWidth(spec.label) + 12 + UI.SegmentTotal(spec))
            aside.always = true
            f.variantSeg = aside
            table.insert(f.controls, aside)
        elseif content.aside then
            aside = Control(head, content.aside, nil, "switch", Tr["Simulate"])
            table.insert(f.controls, aside)
            table.insert(index, { label = content.aside.label, path = path, control = aside, where = Where(path) })
        end
        if aside then table.insert(right, aside) end
        f.aside = aside
    end
    if more then
        local q = CreateFrame("Button", nil, head)
        q:SetSize(22, 16)
        q.text = UI.Plain(q, 12, C.gold)
        q.text:SetPoint("CENTER", 0, 0)
        q.text:SetText("(?)")
        q.tip = more
        q:SetScript("OnEnter", function(self)
            self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3])
            UI.Tip(self, head.name, self.tip)
        end)
        q:SetScript("OnLeave", function(self)
            self.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
            if GameTooltip then GameTooltip:Hide() end
        end)
        head.more = q
        table.insert(right, q)
    end
    -- the rail's right: each left of the one before, in line with the tabs
    local last
    for _, c in ipairs(right) do
        c:ClearAllPoints()
        if last then
            c:SetPoint("RIGHT", last, "LEFT", -10, 0)
        else
            c:SetPoint("RIGHT", head, "TOPRIGHT", -(RIGHT - EDGE), -(TAB_H / 2 + 2))
        end
        last = c
    end
    -- the rail's foot, which the shown tab stands over
    local rule = UI.Fill(head, "BORDER", C.lineStrong)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -(TAB_H - 1))
    rule:SetPoint("TOPRIGHT", 0, -(TAB_H - 1))
    head.rule = rule
    head:Hide()
    f.head = head
end

-- A frame's own choice over a shared option (settings.lua's SHARED): a
-- small "Own" left of its control, while it has one; a click puts it back
-- on the shared value, which it then follows.
local function Own(row, spec)
    local shared = ns.SharedOf(spec.key)
    local b = UI.Button(row, Tr["Own"], 38, 16, function()
        ns.SetOption(spec.key, ns.db[shared])
    end, Tr["This one's own choice, over Shared's. Click to follow Shared again."])
    b.text:SetFont(b.text:GetFont(), 10)
    -- left of the control: a dropdown's box, a segment's answers, a pill
    local box = not row.stacked and (row.button or row.box or row.track)
    local room = box and box:GetWidth() or spec.kind == "choice" and UI.CHOICE_W or 16
    b:SetPoint("RIGHT", row, "RIGHT", -(room + 8), 0)
    local refresh = b.Refresh
    function b:Refresh(enabled)
        refresh(self, enabled)
        self:SetShown(ns.OptionOwn(spec.key))
    end
    b.always = true
    return b
end

-- ------------------------------------------------------------ folding
-- (2026-11-25, the user's pick C of the "Settings" mockups) a section
-- folds to its heading: a click on the heading (its caret at the left)
-- folds or opens it, and the window keeps which are folded
-- (optionsFolded, by page and title). A link, a chip or a search opens
-- one for that look only (peek), never saving it.
local function Shut(s) return s.folded and not s.peek end

local function Refold(s)
    local f = s:GetParent()
    if f == finds then
        Found()
    else
        Layout(s.home or f)
    end
    Thumb()
end

local function FoldSection(s, on)
    s.folded, s.peek = on and true or false, nil
    local saved = type(ns.db.optionsFolded) == "table" and ns.db.optionsFolded or {}
    saved[s.foldKey] = on and true or nil
    ns.db.optionsFolded = next(saved) and saved or false
    Refold(s)
end
ns.OptionsFold = FoldSection

-- the heading's fold: its caret, and a button across it (short of
-- whatever sits at its right, room wide)
local function Folds(s, key, room)
    s.foldKey = key
    local saved = ns.db.optionsFolded
    s.folded = type(saved) == "table" and saved[key] and true or false
    s.caret = s:CreateTexture(nil, "OVERLAY")
    s.caret:SetTexture(ns.media .. "strips\\chevron-down")
    s.caret:SetSize(12, 12)
    s.caret:SetPoint("CENTER", s, "TOPLEFT", CARD_PAD + 4, -BAND_H / 2)
    s.caret:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    local b = CreateFrame("Button", nil, s)
    b:SetPoint("TOPLEFT", 0, 0)
    b:SetPoint("TOPRIGHT", -(room or 0), 0)
    b:SetHeight(BAND_H)
    b.lift = UI.Fill(b, "BACKGROUND", C.lift, 3)
    b.lift:SetAllPoints()
    b.lift:Hide()
    b:SetScript("OnClick", function() FoldSection(s, not Shut(s)) end)
    b:SetScript("OnEnter", function(self) self.lift:Show() end)
    b:SetScript("OnLeave", function(self) self.lift:Hide() end)
    s.foldButton = b
end

-- the caret's turn: down while open, right while folded
local function Caret(s)
    if not s.caret then return end
    local shut = Shut(s)
    s.caret:SetRotation(shut and math.pi / 2 or 0)
    local c = shut and C.dim or C.gold
    s.caret:SetVertexColor(c[1], c[2], c[3], 1)
end

-- a choice's answer as the list shows it
local function Answer(spec)
    local v = UI.Get(spec)
    for _, ch in ipairs(spec.list and spec.list() or spec.choices or {}) do
        if ch[1] == v then return ch[2] end
    end
end

-- A group as a card, a step lighter than the page: its heading holding
-- its caret, its title, its chip (where a variant's options are kept)
-- and, on the right, what is in it (folded: its first choice's answer and
-- how many options) and the switch its rows need; open, a hairline under
-- it, its tip, then an option a row, a hairline between them. A gold bar
-- runs down its left while its switch is on; a row lifts under the
-- pointer. A group of one choice or button and nothing else is one line,
-- its control in its heading, with nothing to fold. sheet: its sheet's
-- name, for search's crumb.
local function Section(f, group, width, path, sheet)
    local s = CreateFrame("Frame", nil, f)
    s:SetWidth(width)
    s.group = group
    s.path = path
    s.chipName = tostring(group.title or ""):match("^(.-):") or group.title
    local inset = CARD_PAD
    width = width - 2 * inset
    UI.Fill(s, "BACKGROUND", C.raised, 1):SetAllPoints()
    local band = UI.Fill(s, "BACKGROUND", C.raised, 2)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(BAND_H - 1)
    s.band = band
    s.edge = UI.Outline(s, "BORDER", C.line, 0)
    s.accent = UI.Fill(s, "OVERLAY", C.goldBright)
    s.accent:SetWidth(2)
    s.accent:SetPoint("TOPLEFT", 1, -1)
    s.accent:SetPoint("BOTTOMLEFT", 1, 1)
    s.accent:Hide()
    -- one line: a single choice (that fits beside its title) or button
    local only = #group.items == 1 and group.items[1]
    local inline = only and not group.switch and not group.tip and not only.beside and not only.hide
        and (only.kind == "button" or only.kind == "choice" and not (only.key and ns.SharedOf(only.key)))
    s.title = UI.Serif(s, 13, C.text)
    s.title:SetWordWrap(false)
    s.title:SetJustifyH("LEFT")
    s.title:SetPoint("LEFT", s, "TOPLEFT", inline and inset or inset + 14, -BAND_H / 2)
    s.title:SetText(group.title)
    s.titleW = math.ceil(s.title:GetStringWidth() or 0)
    if group.chip then
        local shared = group.chip == Tr["Shared"]
        local chip = CreateFrame("Frame", nil, s)
        chip:SetHeight(14)
        chip:SetPoint("LEFT", s.title, "RIGHT", 8, 0)
        UI.Outline(chip, "BORDER", shared and C.lineStrong or { C.gold[1], C.gold[2], C.gold[3], 0.45 }, 0)
        chip.text = UI.Plain(chip, 10, shared and C.dim or C.gold)
        chip.text:SetPoint("CENTER", 0, 0)
        chip.text:SetText(group.chip)
        chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + 10)
        s.chip = chip
    end
    local rule = UI.Fill(s, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 1, -BAND_H)
    rule:SetPoint("TOPRIGHT", -1, -BAND_H)
    s.rule = rule
    local where = Where(path, group.title, sheet)
    local right = inset     -- the heading's room taken at the right
    if group.switch then
        -- a part's title names it; another's switch says what it is
        local w = Control(s, group.switch, nil, "switch", not group.id and group.switch.label or nil)
        w:SetPoint("TOPRIGHT", -inset, -(BAND_H - w:GetHeight()) / 2)
        table.insert(f.controls, w)
        s.switch = w
        right = right + w:GetWidth() + 10
        local refresh = w.Refresh
        function w:Refresh(enabled)
            refresh(self, enabled)
            s.accent:SetShown(UI.Get(group.switch) and true or false)
        end
        table.insert(index, { label = group.switch.label, path = path, section = s, control = w, where = where })
    end
    s.right = right
    s.sum = UI.Plain(s, 11, C.faint)
    s.sum:SetWordWrap(false)
    s.sum:SetPoint("RIGHT", s, "TOPRIGHT", -right, -BAND_H / 2)
    table.insert(index, { label = group.title, path = path, section = s, where = Where(path, nil, sheet) })
    s.rows = {}
    if inline then
        -- the control in the heading, at its right; its label is the title
        -- (a choice as its list, never side by side answers: one line)
        local c
        if only.kind == "choice" then
            c = UI.Choice(s, only, width, true)
            c.needs, c.always, c.can = only.needs, only.always, only.can
            if only.key then controls[only.key] = c end
        else
            c = Control(s, only, width, true)
        end
        if c.stacked then
            inline = false
            c:Hide()
            c:SetParent(nil)
        else
            table.insert(f.controls, c)
            if c.label and only.kind == "choice" then c.label:Hide() end
            if c.line then c.line:Hide() end
            c:ClearAllPoints()
            if only.kind == "choice" then
                c:SetHeight(BAND_H)
                c:SetPoint("TOPLEFT", inset, 0)
            else
                c:SetPoint("RIGHT", s, "TOPRIGHT", -inset, -BAND_H / 2)
            end
            s.inline = c
            if only.label then
                table.insert(index, { label = only.label, path = path, section = s, control = c, where = where })
            end
        end
    end
    s.isInline = inline and true or false
    if not inline then Folds(s, path .. "|" .. tostring(group.title), right) end
    local y = -BAND_H - 10
    if group.tip and not inline then
        local tip = UI.Plain(s, 11, C.dim)
        tip:SetPoint("TOPLEFT", inset, y)
        tip:SetWidth(width)
        tip:SetJustifyH("LEFT")
        tip:SetText(group.tip)
        s.tip = tip
        y = y - math.ceil(tip:GetStringHeight()) - 8
    end
    local top = y
    for i, spec in ipairs(inline and {} or group.items) do
        local c = Control(s, spec, width, true)
        table.insert(f.controls, c)
        local r = { control = c }
        -- a swatch on the same row, left of the box (a dispel type's colour)
        if spec.beside then
            local w = Control(s, spec.beside, 40, true)
            -- the row's label says what it is: the swatch's own is its tip
            w.label:SetText("")
            w:SetHeight(UI.CHECK_H)
            w:SetPoint("RIGHT", c, "RIGHT", -(UI.SWITCH_W + 14), 0)
            table.insert(f.controls, w)
            r.beside = w
        end
        if spec.key and ns.SharedOf(spec.key) then
            c.own = Own(c, spec)
            table.insert(f.controls, c.own)
        end
        -- its lift under the pointer, across the card (Hover)
        c.lift = c:CreateTexture(nil, "BACKGROUND")
        UI.Paint(c.lift, C.lift)
        c.lift:SetPoint("TOPLEFT", c, "TOPLEFT", -(inset - 1), ROW_GAP / 2)
        c.lift:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", inset - 1, -ROW_GAP / 2)
        c.lift:Hide()
        if i > 1 then
            local hair = c:CreateTexture(nil, "BACKGROUND")
            UI.Paint(hair, C.line)
            hair:SetHeight(1)
            hair:SetPoint("BOTTOMLEFT", c, "TOPLEFT", -(inset - 1), ROW_GAP / 2)
            hair:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", inset - 1, ROW_GAP / 2)
        end
        table.insert(s.rows, r)
        -- a grid's rows are found by their names
        for _, gr in ipairs(spec.kind == "grid" and spec.rows or {}) do
            table.insert(index, { label = gr.label, path = path, section = s, control = c, where = where })
        end
        if spec.label then
            table.insert(index, { label = spec.label, path = path, section = s, control = c, where = where })
        end
    end
    -- what the heading says at its right: folded, the first choice's answer
    -- and how many options; open, how many (none beside a switch). The
    -- title gives way to it, ending in "...".
    function s:Summary()
        local room = s:GetWidth() - (self.isInline and inset or inset + 14) - self.right - 8
        local text = ""
        if self.isInline then
            local c = self.inline
            room = room - (c.button and c.button:GetWidth() or c:GetWidth()) - 8
        else
            local n, first = 0, nil
            for _, r in ipairs(self.rows) do
                local c = r.control
                if not (c.spec.hide and c.can and not c.can()) then
                    n = n + 1
                    if not first and c.spec.kind == "choice" then first = c.spec end
                end
            end
            local count = ns.Plural(n, format(Tr["%d |4option:options;"], n))
            if Shut(self) then
                local answer = first and Answer(first)
                text = answer and (answer .. "   \194\183   " .. count) or count
                self.sum:SetText(text)
                if answer and self.titleW + math.ceil(self.sum:GetStringWidth() or 0) + 12 > room then
                    text = count
                end
            elseif not self.switch and n > 0 then
                text = tostring(n)
            end
        end
        self.sum:SetText(text)
        local used = text ~= "" and math.ceil(self.sum:GetStringWidth() or 0) + 12 or 0
        self.title:SetWidth(math.max(20, math.min(self.titleW, room - used)))
    end
    -- its rows, one under another; a row its page's layout does not use
    -- (spec.hide, while its test says no) off, and the card as tall as the
    -- rest; folded, its heading alone
    function s:Rows()
        local shut = Shut(self)
        local ry = top
        for _, r in ipairs(self.rows) do
            local c = r.control
            local on = not (c.spec.hide and c.can and not c.can())
            c:SetShown(on and not shut)
            if r.beside then r.beside:SetShown(on and not shut) end
            if on and not shut then
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", inset, ry)
                ry = ry - c:GetHeight() - ROW_GAP
            end
        end
        if self.tip then self.tip:SetShown(not shut) end
        self.rule:SetShown(not shut and not self.isInline)
        Caret(self)
        if shut or self.isInline then
            self:SetHeight(BAND_H)
        else
            self:SetHeight(-ry + 4)
        end
        self:Summary()
    end
    s:Rows()
    s.sheetName = sheet
    return s
end

-- The page's sections, one under another across the page: on a page with
-- sheets, those on the sheet shown (and of the variant shown). Each's rows
-- as they stand. A section a search has lent is left where it is.
function Layout(f)
    local top = f.y0
    for _, sec in ipairs(f.sections) do
        if sec:GetParent() == f then
            local on = (not f.sheet or sec.sheet == f.sheet) and (not sec.variant or sec.variant == f.variant)
            sec:SetShown(on)
            if on then
                sec:Rows()
                sec:ClearAllPoints()
                sec.x, sec.top, sec.col = 0, -top, 1
                sec:SetPoint("TOPLEFT", 0, top)
                top = top - sec:GetHeight() - SEC_GAP
            end
        end
    end
    f:SetHeight(-top + 4)
end

-- The page: its header (with its sheets' tabs, when its groups are on two
-- or more), its intro, its cards (Layout).
local function Build(content, path, page, tab, width)
    local f = CreateFrame("Frame", nil, scroll)
    f:SetWidth(width)
    f.path = path
    f.controls = {}
    f.sections = {}
    f.enabled = content.enabled
    -- its sheets, in the vocabulary's order; a group with none on the first
    local has = {}
    for _, g in ipairs(content.groups) do
        if g.sheet then has[g.sheet] = true end
    end
    local sheets = {}
    for _, sh in ipairs(ns.OPTION_SHEETS) do
        if has[sh[1]] then table.insert(sheets, sh[1]) end
    end
    if #sheets >= 2 then f.sheets, f.sheet = sheets, sheets[1] end
    -- its variants: first the one its key shows
    if content.variants then
        f.variant = content.variants[1][1]
        local now = content.variantKey and ns.db[content.variantKey]
        for _, v in ipairs(content.variants) do
            if v[1] == now then f.variant = now end
        end
    end
    Header(f, content, path, page, tab)
    local y = -4
    if content.intro then
        local intro = UI.Plain(f, 12, C.dim)
        intro:SetPoint("TOPLEFT", 0, y)
        intro:SetWidth(width)
        intro:SetJustifyH("LEFT")
        intro:SetText(content.intro)
        f.intro = intro
        y = y - math.ceil(intro:GetStringHeight()) - 16
    end
    f.y0 = y
    local names = {}
    for _, v in ipairs(content.variants or {}) do names[v[1]] = v[2] end
    for i, group in ipairs(content.groups) do
        local sheet = f.sheets and (group.sheet or f.sheets[1]) or nil
        -- search's crumb: the sheet, and the variant ("Auras (Widget)")
        local crumb = sheet and SheetName(content, sheet)
        if crumb and group.variant then crumb = crumb .. " (" .. names[group.variant] .. ")" end
        local s = Section(f, group, width, path, crumb)
        s.home, s.sheet, s.variant, s.wide = f, sheet, group.variant, true
        f.sections[i] = s
    end
    Strip(f)
    Layout(f)
    f:Hide()
    return f
end

-- ------------------------------------------------------------ modules
local Select, Reveal

-- A part's card on Modules: its medallion, name, tag and line, its master's
-- switch (not the header's: the header's is the option's control); a click
-- off the switch opens its page. An addon's card has no switch, only
-- whether the addon is loaded.
local function CardName(content)
    local name = (content.master.label:gsub(" window$", ""))
    return #name > 22 and content.name or name
end

local function Card(parent, content, path, width, names)
    local m = content.master
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, CARD_H)
    b.path, b.needs, b.content = path, m and m.needs, content
    UI.Fill(b, "BACKGROUND", C.raised, 1):SetAllPoints()
    b.lift = UI.Fill(b, "BACKGROUND", C.lift, 2)
    b.lift:SetAllPoints()
    b.lift:Hide()
    b.edge = UI.Outline(b, "BORDER", C.line, 0)
    -- a gold bar down its left while it is on
    b.bar = UI.Fill(b, "ARTWORK", C.goldBright, 4)
    b.bar:SetWidth(2)
    b.bar:SetPoint("TOPLEFT", 1, -1)
    b.bar:SetPoint("BOTTOMLEFT", 1, 1)
    local ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture(ROUND)
    ring:SetSize(32, 32)
    ring:SetPoint("LEFT", 8, 0)
    ring:SetVertexColor(C.goldDark[1], C.goldDark[2], C.goldDark[3], 1)
    b.ring = ring
    local well = b:CreateTexture(nil, "ARTWORK", nil, 2)
    well:SetTexture(ROUND)
    well:SetSize(28, 28)
    well:SetPoint("CENTER", ring, "CENTER", 0, 0)
    well:SetVertexColor(C.well[1], C.well[2], C.well[3], 1)
    b.glyph = b:CreateTexture(nil, "ARTWORK", nil, 3)
    b.glyph:SetTexture(ns.media .. "strips\\" .. (content.glyph or "help"))
    b.glyph:SetSize(18, 18)
    b.glyph:SetPoint("CENTER", ring, "CENTER", 0, 0)
    b.name = UI.Serif(b, 13, C.gold)
    b.name:SetPoint("TOPLEFT", 50, -7)
    b.name:SetText(m and CardName(content) or content.name)
    -- the tag: Forever, what it needs, or the addon's state
    local tag = CreateFrame("Frame", nil, b)
    tag:SetHeight(14)
    tag:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
    UI.Outline(tag, "BORDER", C.lineStrong, 0)
    tag.text = UI.Plain(tag, 10, C.gold)
    tag.text:SetPoint("CENTER", 0, 0)
    b.tag = tag
    local function Tag(text)
        tag.text:SetText(text or "")
        tag:SetWidth(math.ceil(tag.text:GetStringWidth()) + 10)
        tag:SetShown(text ~= nil)
    end
    Tag(content.forever and Tr["Forever"] or b.needs and format(Tr["Needs %s"], names[b.needs] or b.needs) or nil)
    b.blurb = UI.Plain(b, 11, C.dim)
    b.blurb:SetPoint("BOTTOMLEFT", 50, 7)
    b.blurb:SetPoint("RIGHT", b, "RIGHT", -(UI.SWITCH_W + 18), 0)
    b.blurb:SetJustifyH("LEFT")
    b.blurb:SetWordWrap(false)
    b.blurb:SetText(content.blurb or "")
    if m then
        b.switch = UI.Switch(b, m)
        b.switch:SetPoint("RIGHT", -10, 0)
    end
    b:SetScript("OnClick", function(self)
        if content.group then Reveal(self.path, content.group) else Select(self.path) end
    end)
    b:SetScript("OnEnter", function(self)
        self.lift:Show()
        local why = self.off and format(Tr["Turn on %s first."], names[self.needs] or self.needs)
        UI.Tip(self, self.name:GetText(), why or (m and m.tip) or content.intro)
    end)
    b:SetScript("OnLeave", function(self)
        self.lift:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
    function b:Refresh(enabled)
        local on
        if m then
            self.switch:Refresh(enabled)
            on = enabled and UI.Get(m) and true or false
        else
            on = content.enabled and content.enabled() and true or false
            Tag(on and Tr["Loaded"] or Tr["Addon off"])
        end
        self.off = m and not enabled
        local n = enabled and (on and C.text or C.dim) or C.faint
        self.name:SetTextColor(n[1], n[2], n[3])
        local g = on and C.goldBright or C.dim
        self.glyph:SetVertexColor(g[1], g[2], g[3], 1)
        local r = on and C.gold or C.goldDark
        self.ring:SetVertexColor(r[1], r[2], r[3], 1)
        self.ring:SetAlpha(on and 1 or 0.6)
        self.bar:SetShown(on)
    end
    return b
end

-- Every part with a master, a card each under the sidebar's categories.
local function Modules(content, path, page, width)
    local f = CreateFrame("Frame", nil, scroll)
    f:SetWidth(width)
    f.path = path
    f.controls = {}
    f.sections = {}
    f.cards = {}
    -- the parts, and the names of those another needs
    local names = {}
    local function Parts(cat)
        local out = {}
        local function Add(c, p)
            if c.master and c.master.kind == "check" then
                table.insert(out, { c, p })
                names[c.master.key] = CardName(c)
            elseif c.addon then
                table.insert(out, { c, p })
            end
        end
        for _, item in ipairs(cat.items) do
            local pg, tab = Find(item)
            if pg then
                local c = tab or pg
                Add(c, item)
                -- a part on that page (a window, a side panel tab): a card
                -- of its own, opening the page at it
                for _, g in ipairs(c.groups or {}) do
                    if g.id and g.switch then
                        Add({ master = g.switch, name = g.title, forever = g.forever, glyph = g.glyph,
                            blurb = g.blurb, group = g }, item)
                    end
                end
            end
        end
        return out
    end
    -- (2026-11-25, the user's pick C) every category with a part, one under
    -- another, each folding to its heading: its scope or note at the right
    local lists = {}
    for i, cat in ipairs(categories) do lists[i] = Parts(cat) end
    Header(f, content, path, page, nil)
    local intro = UI.Plain(f, 12, C.dim)
    intro:SetPoint("TOPLEFT", 0, -4)
    intro:SetWidth(width)
    intro:SetJustifyH("LEFT")
    intro:SetText(content.intro)
    f.intro = intro
    f.y0 = -4 - math.ceil(intro:GetStringHeight()) - 16
    local cardW = math.floor((width - CARD_GAP) / 2)
    for i, cat in ipairs(categories) do
        local list = lists[i]
        if #list > 0 then
            local s = CreateFrame("Frame", nil, f)
            s:SetWidth(width)
            s.home, s.path, s.chipName, s.cat = f, path, cat.name, cat.name
            s.band = UI.Fill(s, "BACKGROUND", C.raised, 1)
            s.band:SetPoint("TOPLEFT", 0, 0)
            s.band:SetPoint("TOPRIGHT", 0, 0)
            s.band:SetHeight(BAND_H)
            UI.Outline(s, "BORDER", C.line, 0)
            s.title = UI.Serif(s, 13, C.text)
            s.title:SetPoint("LEFT", s, "TOPLEFT", CARD_PAD + 14, -BAND_H / 2)
            s.title:SetText(cat.name)
            s.note = UI.Plain(s, 11, C.faint)
            s.note:SetPoint("RIGHT", s, "TOPRIGHT", -CARD_PAD, -BAND_H / 2)
            s.note:SetText(cat.note or cat.scope or "")
            Folds(s, path .. "|" .. cat.name, 0)
            s.cards = {}
            local sy = -BAND_H - CARD_GAP
            for n, part in ipairs(list) do
                local card = Card(s, part[1], part[2], cardW - CARD_GAP, names)
                local col = (n - 1) % 2
                card:SetPoint("TOPLEFT", CARD_GAP + col * cardW, sy)
                if col == 1 or n == #list then sy = sy - CARD_H - CARD_GAP end
                table.insert(f.controls, card)
                table.insert(f.cards, card)
                table.insert(s.cards, card)
            end
            s.open = -sy
            function s:Rows()
                local shut = Shut(self)
                for _, card in ipairs(self.cards) do card:SetShown(not shut) end
                Caret(self)
                self:SetHeight(shut and BAND_H or self.open)
            end
            table.insert(f.sections, s)
        end
    end
    Strip(f)
    Layout(f)
    f:Hide()
    return f
end

-- ------------------------------------------------------------ scrolling
function Thumb()
    ns.LightChips()
    local range = scroll:GetVerticalScrollRange() or 0
    if range <= 0 then
        thumb:Hide()
        return
    end
    local view = scroll:GetHeight()
    local size = math.max(24, view * view / (view + range))
    thumb:SetHeight(size)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(view - size) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

-- The body under the shown page's header, as tall as the header is.
local function PlaceBody(f)
    local top = HEAD_TOP + f.head:GetHeight() + 10
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", window, "TOPLEFT", X, -top)
    body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -RIGHT, EDGE + FOOT + 6)
end

-- A sheet shown: its tab lit, its cards laid out, at their top.
function ShowSheet(f, sheet)
    f.sheet = sheet
    Strip(f)
    PlaceBody(f)
    Layout(f)
    scroll:SetVerticalScroll(0)
    flash:Hide()
    UI.CloseMenu()
    Thumb()
end

-- A variant shown (Party's console or group frame): its cards, on the sheet
-- shown, or the first that has some.
function SetVariant(f, v)
    f.variant = v
    if f.variantSeg then f.variantSeg:Refresh(true) end
    Strip(f)
    if f.path == current then PlaceBody(f) end
    local here
    for _, b in ipairs(f.tabs or {}) do
        if b.sheet == f.sheet then here = b.any end
    end
    if f.tabs and not here then
        for _, b in ipairs(f.tabs) do
            if b.any then
                f.sheet = b.sheet
                break
            end
        end
        Strip(f)
        if f.path == current then PlaceBody(f) end
    end
    Layout(f)
    Thumb()
end

local function Scroll(delta)
    local range = scroll:GetVerticalScrollRange() or 0
    local to = math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * 40))
    scroll:SetVerticalScroll(to)
    Thumb()
end

-- ------------------------------------------------------------ the sidebar
-- The rows down the sidebar: a heading for each category, a row for each
-- item; only the shown page's category open, the others folded to their
-- heading and how many items they hold. While a search shows what it
-- found, no item is lit (the last page's category stays open).
local function Nav()
    local y = -2
    for _, h in ipairs(side.heads) do h:Hide() end
    for _, r in ipairs(side.rows) do r:Hide() end
    local shown = current and place[current] and place[current].item
    local item = not query and shown
    -- the open category's pages run down a gold rail under its glyph
    side.rail = side.rail or UI.Fill(navChild, "ARTWORK", C.gold, 3)
    side.rail:SetWidth(2)
    local railed = false
    for _, h in ipairs(side.heads) do
        local here = false
        for _, r in ipairs(h.rows) do here = here or r.path == shown end
        h.open = here
        h.sign:SetText(h.open and "" or (#h.rows .. "  \226\128\186"))
        h.pill:SetWidth(math.max(18, math.ceil(h.sign:GetStringWidth()) + 2))
        h.pill:SetShown(not h.open and not h.single)
        h.rule:SetShown(h ~= side.heads[1])
        h:Paint(false)
        h:SetPoint("TOPLEFT", 0, y)
        h:SetPoint("TOPRIGHT", 0, y)
        h:Show()
        y = y - CAT_H
        local first, last
        for _, r in ipairs(h.rows) do
            if h.open and not h.single then
                r:SetPoint("TOPLEFT", 0, y)
                r:SetPoint("TOPRIGHT", 0, y)
                r:Show()
                y = y - ITEM_H
                first, last = first or r, r
            end
            local on = r.path == item
            r.lit:SetShown(on)
            r.lift:Hide()
            local c = on and C.goldBright or C.dim
            r.text:SetTextColor(c[1], c[2], c[3])
        end
        if first then
            side.rail:ClearAllPoints()
            side.rail:SetPoint("TOPLEFT", first, "TOPLEFT", 14, 0)
            side.rail:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", 14, 0)
            railed = true
            y = y - 6
        end
        y = y - 2
    end
    side.rail:SetShown(railed)
    navChild:SetHeight(-y + 4)
    local range = math.max(0, navChild:GetHeight() - nav:GetHeight())
    if nav:GetVerticalScroll() > range then nav:SetVerticalScroll(range) end
end

-- A category's heading, a ledger line: its glyph in gold, its name in the
-- serif with what it keeps under it ("Kept per profile"), a fading gold
-- hair above it parting it from the one before; folded, its pages' count
-- and an arrow at the right. Under the pointer, it brightens.
local HOVER = { 1, 0.97, 0.88 }
local function Head(cat)
    local h = CreateFrame("Button", nil, navChild)
    h:SetHeight(CAT_H)
    h.cat = cat
    h.rule = ns.window.Hair(h, false, 0.5)
    h.rule:SetPoint("TOPLEFT", 8, 0)
    h.rule:SetPoint("TOPRIGHT", -8, 0)
    -- under the pointer, the line lifts (a folded one; the open one is lit)
    h.lift = UI.Fill(h, "BACKGROUND", C.lift2, 1)
    h.lift:SetPoint("TOPLEFT", 0, -1)
    h.lift:SetPoint("BOTTOMRIGHT", 0, 0)
    h.lift:Hide()
    h.glyph = h:CreateTexture(nil, "ARTWORK")
    h.glyph:SetTexture(ns.media .. "strips\\" .. (cat.glyph or "help"))
    h.glyph:SetSize(18, 18)
    h.glyph:SetPoint("LEFT", 6, 0)
    h.text = UI.Serif(h, 15, C.text)
    h.text:SetText(cat.name)
    local scope = cat.scope or cat.note
    if scope then
        h.text:SetPoint("BOTTOMLEFT", h, "LEFT", 34, -1)
        h.sub = UI.Plain(h, 9, C.faint)
        h.sub:SetPoint("TOPLEFT", h, "LEFT", 34, -3)
        h.sub:SetText(scope)
    else
        h.text:SetPoint("LEFT", 34, 0)
    end
    h.pill = CreateFrame("Frame", nil, h)
    h.pill:SetHeight(15)
    h.pill:SetPoint("RIGHT", -12, 0)
    h.sign = UI.Plain(h.pill, 11, C.faint)
    h.sign:SetPoint("RIGHT", 0, 0)
    -- open, bright gold; under the pointer, lighter; else the text's colour
    function h:Paint(over)
        self.over = over
        local t = self.open and C.goldBright or over and HOVER or C.text
        self.text:SetTextColor(t[1], t[2], t[3])
        local g = (self.open or over) and C.goldBright or C.gold
        self.glyph:SetVertexColor(g[1], g[2], g[3], 1)
        self.lift:SetShown(over and not self.open or false)
        if self.sign then
            local s = over and C.dim or C.faint
            self.sign:SetTextColor(s[1], s[2], s[3])
        end
    end
    h:SetScript("OnEnter", function(self) self:Paint(true) end)
    h:SetScript("OnLeave", function(self) self:Paint(false) end)
    -- a folded category opens on the item last shown in it, or its first
    h:SetScript("OnClick", function(self)
        local to = lastIn[self.cat.name] or (self.rows[1] and self.rows[1].path)
        if to and not self.open then Select(to) end
    end)
    h.rows = {}
    return h
end

-- A page's row: its name under its category's; the page shown lit (a
-- faint gold fill from the category's rail, gold text); another lifts
-- under the pointer. A page under another (Paging) hangs off it on an elbow.
local function Item(path)
    local r = CreateFrame("Button", nil, navChild)
    r:SetHeight(ITEM_H)
    r.path = path
    r.lift = UI.Fill(r, "BACKGROUND", C.lift2, 1)
    r.lift:SetPoint("TOPLEFT", 16, 0)
    r.lift:SetPoint("BOTTOMRIGHT", 0, 0)
    r.lift:Hide()
    r.lit = UI.Fill(r, "BACKGROUND", C.lit, 2)
    r.lit:SetPoint("TOPLEFT", 16, 0)
    r.lit:SetPoint("BOTTOMRIGHT", 0, 0)
    r.lit:Hide()
    r.text = UI.Serif(r, 13, C.dim)
    -- a tab under another, indented below it
    r.sub = Parent(path) and true or nil
    r.text:SetPoint("LEFT", r.sub and 56 or 34, 0)
    r.text:SetText(ItemName(path))
    if r.sub then
        local down = UI.Fill(r, "ARTWORK", C.lineStrong)
        down:SetWidth(1)
        down:SetPoint("TOPLEFT", 42, 0)
        down:SetPoint("BOTTOMLEFT", r, "LEFT", 42, 0)
        local across = UI.Fill(r, "ARTWORK", C.lineStrong)
        across:SetSize(8, 1)
        across:SetPoint("LEFT", 42, 0)
        r.elbow = { down, across }
    end
    local content = select(2, Find(path)) or Find(path)
    r.master = content.master and content.master.kind == "check" and content.master or nil
    r.addon = content.addon and content or nil
    if r.master or r.addon then
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetTexture(ROUND)
        r.dot:SetSize(7, 7)
        r.dot:SetPoint("RIGHT", -8, 0)
    end
    r:SetScript("OnEnter", function(self)
        if self.lit:IsShown() then return end
        self.lift:Show()
        self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    end)
    r:SetScript("OnLeave", function(self)
        self.lift:Hide()
        if not self.lit:IsShown() then self.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end
    end)
    r:SetScript("OnClick", function(self) Select(self.path) end)
    return r
end

-- ------------------------------------------------------------ search
local function Flash(c)
    flash:ClearAllPoints()
    flash:SetPoint("TOPLEFT", c, "TOPLEFT", -4, 3)
    flash:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 4, -3)
    flash.left = 1.2
    flash.control = c
    flash:SetAlpha(1)
    flash:Show()
end

-- The sections a search lent its page, back on their own pages, each laid
-- out again.
local function Home()
    local homes = {}
    for _, s in ipairs(finds.lent) do
        s:SetParent(s.home)
        s:ClearAllPoints()
        s.peek = nil
        homes[s.home] = true
    end
    finds.lent = {}
    for f in pairs(homes) do Layout(f) end
end

-- The search over: its page gone, the sections home; the box emptied too
-- when something else ends it (a page chosen).
local function EndSearch(clear)
    if not finds.on then return end
    query, results = nil, {}
    finds.on = false
    Home()
    finds:Hide()
    finds.head:Hide()
    if clear and search:GetText() ~= "" then search:SetText("") end
end

-- A match chosen: its page, on its sheet and variant, scrolled to its
-- section, the match outlined.
function Choose(e)
    local s = e.section
    Select(e.path, s and s.sheet)
    local f = built[current]
    if s and f then
        if s.variant and f.variant ~= s.variant then SetVariant(f, s.variant) end
        if s.folded and not s.peek then
            s.peek = true
            Layout(f)
        end
        local range = math.max(0, f:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.min(range, s.top or 0))
        Thumb()
    end
    if e.control then Flash(e.control) end
end

-- A part's card on Modules: its page, scrolled to its section, outlined.
function Reveal(path, group)
    Select(path)
    local f = built[current]
    for _, s in ipairs(f and f.sections or {}) do
        if s.group == group then return Choose({ path = current, section = s, control = s }) end
    end
end

-- A line over a match: where it is, a click opening it there.
local function Link(n)
    local b = finds.links[n]
    if b then return b end
    b = CreateFrame("Button", nil, finds)
    b:SetHeight(LINK_H)
    b.text = UI.Plain(b, 11, C.dim)
    b.text:SetPoint("LEFT", 0, 0)
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(C.goldBright[1], C.goldBright[2], C.goldBright[3]) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)
    b:SetScript("OnClick", function(self) Choose(self.entry) end)
    finds.links[n] = b
    return b
end

-- What a search found, on the right: the pages whose names match, then each
-- section with a match (its own, lent: its options work there) under a
-- line saying where it is, in two columns.
function Found()
    Home()
    local seen, sections, named = {}, {}, {}
    for _, e in ipairs(results) do
        if not e.section then
            table.insert(named, e)
        elseif not seen[e.section] then
            seen[e.section] = true
            table.insert(sections, e)
        end
    end
    for _, b in ipairs(finds.links) do b:Hide() end
    local n = 0
    local function Line(e, text, x, y, w)
        n = n + 1
        local b = Link(n)
        b.entry = e
        b.text:SetText(text)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, y)
        b:SetWidth(w)
        b:Show()
    end
    local width = finds:GetWidth()
    local y = -4
    for _, e in ipairs(named) do
        Line(e, format(Tr["Open %s   (%s)"], e.label, e.where), 0, y, width)
        y = y - LINK_H
    end
    if #named > 0 then y = y - 10 end
    for _, e in ipairs(sections) do
        local s = e.section
        Line(e, Where(e.path, nil, s.sheetName) .. "  >", 0, y, width)
        -- one off its page's sheet, or a row its layout leaves off, as it
        -- is; a folded one open while it is lent
        s.peek = true
        s:Show()
        s:Rows()
        s:SetParent(finds)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", finds, "TOPLEFT", 0, y - LINK_H - 2)
        table.insert(finds.lent, s)
        y = y - LINK_H - 2 - s:GetHeight() - SEC_GAP
    end
    finds.none:SetShown(#results == 0)
    finds.head.crumb:SetText(#results == 0 and format(Tr["Nothing matches \"%s\"."], query)
        or format(Tr["%s and %s match \"%s\""], ns.Plural(#sections, format(Tr["%d |4section:sections;"], #sections)),
            ns.Plural(#named, format(Tr["%d |4page:pages;"], #named)), query))
    finds:SetHeight(-y + 4)
end

-- lower case for matching: string.lower is ASCII only, so Cyrillic capitals
-- (U+0410-042F, and U+0401) are folded by their UTF-8 bytes
local function Fold(s)
    s = s:lower():gsub("\208([\144-\175])", function(c)
        local b = c:byte() + 32
        return b < 192 and ("\208" .. string.char(b)) or ("\209" .. string.char(b - 64))
    end)
    return (s:gsub("\208\129", "\209\145"))
end

local function Search(text)
    text = Fold(tostring(text or "")):match("^%s*(.-)%s*$")
    -- letters, not bytes: a Cyrillic letter is two
    if select(2, text:gsub("[^\128-\191]", "")) < 2 then
        -- back to the page it was on
        if finds.on then
            EndSearch()
            Select(current)
        end
        return
    end
    query = text
    results = {}
    for _, e in ipairs(index) do
        if Fold(e.label):find(query, 1, true) then table.insert(results, e) end
    end
    if not finds.on then
        finds.on = true
        for _, f in pairs(built) do
            f:Hide()
            f.head:Hide()
        end
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", window, "TOPLEFT", X, -(HEAD_TOP + HEAD_H + 12))
        body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -RIGHT, EDGE + FOOT + 6)
        finds:Show()
        finds.head:Show()
        scroll:SetScrollChild(finds)
        flash:Hide()
        UI.CloseMenu()
    end
    Found()
    scroll:SetVerticalScroll(0)
    Thumb()
    Nav()
end

local function SearchBox()
    local box = CreateFrame("EditBox", nil, side)
    box:SetHeight(SEARCH_H)
    box:SetPoint("TOPLEFT", 10, -10)
    box:SetPoint("TOPRIGHT", -10, -10)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    box:SetTextInsets(8, 8, 0, 0)
    box:SetMaxLetters(40)
    UI.Fill(box, "BACKGROUND", C.well, 1):SetAllPoints()
    box.edge = UI.Outline(box, "BORDER", C.lineStrong, 0)
    box.hint = UI.Plain(box, 12, C.faint)
    box.hint:SetPoint("LEFT", 8, 0)
    box.hint:SetText(Tr["Search options"])
    box:SetScript("OnTextChanged", function(self)
        self.hint:SetShown((self:GetText() or "") == "")
        Search(self:GetText())
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        Search("")
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local first = finds.links[1]
        if first and first:IsShown() then Choose(first.entry) end
    end)
    box:SetScript("OnEditFocusGained", function(self)
        UI.Paint(self.edge, C.gold)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        UI.Paint(self.edge, C.lineStrong)
    end)
    return box
end

-- ------------------------------------------------------------ redraw
local function Refresh()
    if not window then return end
    -- a master greys only with what it needs; all else with it too
    -- (and with its own test: c.can, a dispel type the player has not)
    -- what it needs, and what that needs in turn (a gossip card's rows
    -- need its switch, which needs the chat box)
    local function Has(c)
        local key, n = c.needs, 0
        while key and n < 8 do
            if not ns.db[key] then return false end
            local by = controls[key]
            key, n = by and by.needs, n + 1
        end
        return not c.can or c.can() and true or false
    end
    for _, f in pairs(built) do
        local on = (not f.master or ns.db[f.master.spec.key] and Has(f.master))
            and (not f.enabled or f.enabled()) and true or false
        for _, c in ipairs(f.controls) do
            c:Refresh((c == f.master or c.always or on) and Has(c))
        end
    end
    -- the sidebar's dots: a part on, or off
    for _, r in ipairs(side.rows) do
        if r.dot then
            local on
            if r.master then
                on = ns.db[r.master.key] and Has(r.master)
            else
                on = r.addon.enabled and r.addon.enabled()
            end
            local c = on and GREEN or C.dim
            r.dot:SetVertexColor(c[1], c[2], c[3], 1)
            r.dot.on = on and true or false
        end
    end
    local name = ns.db.consoleProfile
    for _, p in ipairs(ns.PROFILE_NAMES) do
        if p[1] == name then name = p[2] end
    end
    footProfile:SetText("Profile \194\183 " .. ns.GoldHex(ns.gold.mid) .. name .. "|r")
    footChip:SetWidth(9 + 12 + 6 + math.ceil(footProfile:GetStringWidth()) + 10)
    local reload = NeedsReload()
    footReload:SetShown(reload)
    footReload.pill:SetShown(reload)
    footDot:SetShown(reload)
    footButton:SetStyle(reload and "primary" or "secondary")
    -- a row its layout no longer uses goes, one it does comes back
    if finds and finds.on then
        Found()
    elseif current and built[current] then
        Layout(built[current])
        Thumb()
    end
end
ns.RefreshOptions = Refresh

-- A page shown: on sheet (one of its sheets' ids), or the one it was
-- last on, or its first.
function Select(path, sheet)
    local page, tab = Find(path)
    if not page then return end
    EndSearch(true)
    if tab then lastTab[page.id] = tab.id end
    current = tab and (page.id .. "/" .. tab.id) or page.id
    local at = place[current]
    if at then lastIn[at.cat.name] = at.item end
    local f = built[current]
    if f.sheets then
        local ok = false
        for _, id in ipairs(f.sheets) do ok = ok or id == sheet end
        if ok then f.sheet = sheet end
    end
    -- a section a link or chip opened for a look is folded again
    for _, s in ipairs(f.sections) do s.peek = nil end
    Strip(f)
    Layout(f)
    PlaceBody(f)
    for p, pf in pairs(built) do
        pf:SetShown(p == current)
        pf.head:SetShown(p == current)
    end
    scroll:SetScrollChild(f)
    scroll:SetVerticalScroll(0)
    flash:Hide()
    UI.CloseMenu()
    Nav()
    Refresh()
    Thumb()
end

-- ------------------------------------------------------------ the window
local function Remember()
    local point, _, relative, x, y = window:GetPoint()
    ns.db.optionsPoint = { point, relative, math.floor(x + 0.5), math.floor(y + 0.5) }
end

local function Grip(frame)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() window:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        if window.SetUserPlaced then window:SetUserPlaced(false) end
        Remember()
    end)
end

local function Sidebar()
    side = CreateFrame("Frame", nil, window)
    -- docked: flush to the window's left edge, between its head and footer
    side:SetPoint("TOPLEFT", EDGE, -(EDGE + BAR_H))
    side:SetPoint("BOTTOMLEFT", EDGE, EDGE + FOOT)
    side:SetWidth(SIDE_W)
    UI.Fill(side, "BACKGROUND", C.chrome, 1):SetAllPoints()
    local rule = UI.Fill(side, "BORDER", C.line)
    rule:SetWidth(1)
    rule:SetPoint("TOPRIGHT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    search = SearchBox()
    nav = CreateFrame("ScrollFrame", nil, side)
    nav:SetPoint("TOPLEFT", 0, -(10 + SEARCH_H + 4))
    nav:SetPoint("BOTTOMRIGHT", -1, 4)
    navChild = CreateFrame("Frame", nil, nav)
    navChild:SetWidth(SIDE_W - 1)
    navChild:SetHeight(1)
    nav:SetScrollChild(navChild)
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, navChild:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    side.heads, side.rows = {}, {}
    for _, cat in ipairs(categories) do
        local h = Head(cat)
        for _, item in ipairs(cat.items) do
            if Find(item) then
                local r = Item(item)
                table.insert(h.rows, r)
                table.insert(side.rows, r)
            end
        end
        -- one page of its own name: the heading is its row, lit (gold) while
        -- it shows, its dot beside the name where the count would be
        h.single = Single(cat)
        if h.single and h.rows[1].dot then
            local dot = h.rows[1].dot
            dot:SetParent(h)
            dot:ClearAllPoints()
            dot:SetPoint("RIGHT", -14, 0)
        end
        table.insert(side.heads, h)
    end
    -- the pages' names are found too
    for _, cat in ipairs(categories) do
        for _, item in ipairs(cat.items) do
            if Find(item) then table.insert(index, { label = ItemName(item), path = item, where = cat.name }) end
        end
    end
end

-- The window's footer, the head's match: the profile being edited in a
-- chip; while a reload waits, a pill saying so; Reload UI (gold, the main
-- action, while one waits) and Close.
local function Footer()
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    bar:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    bar:SetHeight(FOOT)
    UI.Fill(bar, "BACKGROUND", C.chrome, 1):SetAllPoints()
    local rule = UI.Fill(bar, "BORDER", C.line)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", 0, 0)
    footChip = CreateFrame("Frame", nil, bar)
    footChip:SetHeight(24)
    footChip:SetPoint("LEFT", 12, 0)
    UI.Outline(footChip, "BORDER", C.line, 0)
    local who = footChip:CreateTexture(nil, "ARTWORK")
    who:SetTexture(ns.media .. "strips\\character")
    who:SetSize(12, 12)
    who:SetPoint("LEFT", 9, 0)
    who:SetVertexColor(C.faint[1], C.faint[2], C.faint[3], 1)
    footProfile = UI.Plain(footChip, 11, C.dim)
    footProfile:SetPoint("LEFT", who, "RIGHT", 6, 0)
    local close = UI.Button(bar, Tr["Close"], 64, 26, function() window:Hide() end, nil, "quiet")
    close:SetPoint("RIGHT", -8, 0)
    footButton = UI.Button(bar, Tr["Reload UI"], 96, 26, ReloadUI,
        Tr["Reload the interface so a changed option takes effect."])
    footButton:SetPoint("RIGHT", close, "LEFT", -6, 0)
    -- the pill: "Reload to apply", a dot before it, until the reload
    local pill = CreateFrame("Frame", nil, bar)
    pill:SetHeight(24)
    pill:SetPoint("RIGHT", footButton, "LEFT", -10, 0)
    UI.Fill(pill, "BACKGROUND", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.10 }, 1):SetAllPoints()
    UI.Outline(pill, "BORDER", { C.goldBright[1], C.goldBright[2], C.goldBright[3], 0.35 }, 0)
    footDot = pill:CreateTexture(nil, "ARTWORK")
    footDot:SetTexture(ROUND)
    footDot:SetSize(7, 7)
    footDot:SetPoint("LEFT", 10, 0)
    footDot:SetVertexColor(C.goldBright[1], C.goldBright[2], C.goldBright[3], 1)
    footReload = UI.Plain(pill, 11, C.goldBright)
    footReload:SetPoint("LEFT", footDot, "RIGHT", 7, 0)
    footReload:SetText(Tr["Reload to apply"])
    pill:SetWidth(10 + 7 + 7 + math.ceil(footReload:GetStringWidth()) + 10)
    footReload.pill = pill
    pill:Hide()
    footReload:Hide()
    footDot:Hide()
    window.foot, window.footChip, window.footButton = bar, footChip, footButton
end

-- A card's row under the pointer lifts: the rows aren't the mouse's (their
-- controls are), so the body asks each frame which shown row the pointer
-- is over, on the page shown or the sections a search lent.
local hovered
local function Hover(c)
    if hovered == c then return end
    if hovered then hovered.lift:Hide() end
    hovered = c
    if c then c.lift:Show() end
end
local function UnderPointer()
    local sections = finds and finds.on and finds.lent or (built[current] or {}).sections or {}
    for _, s in ipairs(sections) do
        if s.rows and s:IsVisible() and s:IsMouseOver() then
            for _, r in ipairs(s.rows) do
                local c = r.control
                if c.lift and c:IsVisible() and c:IsMouseOver() then return c end
            end
        end
    end
end

-- The window's head, across its top: its name, the version;
-- a close button at the right, red under the pointer. All of it drags
-- the window.
local function WindowHead()
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint("TOPLEFT", EDGE, -EDGE)
    bar:SetPoint("TOPRIGHT", -EDGE, -EDGE)
    bar:SetHeight(BAR_H)
    bar:SetFrameLevel(window:GetFrameLevel() + 5)
    UI.Fill(bar, "BACKGROUND", C.chrome, 1):SetAllPoints()
    local rule = UI.Fill(bar, "BORDER", C.line)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    local text = UI.Serif(bar, 15, C.goldBright)
    text:SetPoint("LEFT", 14, 0)
    text:SetText("MedalUI")
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = get and get("MedalUI", "Version")
    local sub = UI.Plain(bar, 11, C.faint)
    sub:SetPoint("LEFT", text, "RIGHT", 10, -1)
    sub:SetText(Tr["Settings"] .. (version and ("  \194\183  " .. version) or ""))
    Grip(bar)
    window.title, window.titleBox, window.version = text, bar, sub

    local x = CreateFrame("Button", nil, bar)
    x:SetSize(BAR_H, BAR_H - 1)
    x:SetPoint("TOPRIGHT", 0, 0)
    local lit = UI.Fill(x, "BACKGROUND", C.red, 1)
    lit:SetAllPoints()
    lit:Hide()
    local seam = UI.Fill(x, "BORDER", C.line)
    seam:SetWidth(1)
    seam:SetPoint("TOPLEFT", 0, 0)
    seam:SetPoint("BOTTOMLEFT", 0, 0)
    x.glyph = x:CreateTexture(nil, "ARTWORK")
    x.glyph:SetTexture(ns.media .. "strips\\close")
    x.glyph:SetSize(14, 14)
    x.glyph:SetPoint("CENTER", 0, 0)
    x.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    x.lit = lit
    x:SetScript("OnClick", function() window:Hide() end)
    x:SetScript("OnEnter", function(self)
        self.lit:Show()
        self.glyph:SetVertexColor(0.949, 0.847, 0.784, 1)
    end)
    x:SetScript("OnLeave", function(self)
        self.lit:Hide()
        self.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    end)
    window.closeX = x
end

local function Window()
    if window then return end
    window = CreateFrame("Frame", "MedalUIOptions", UIParent)
    window:SetSize(W, H)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    Grip(window)
    local at = ns.db.optionsPoint
    if at then
        window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    -- the page's tone; a hairline edge, a faint gold ring outside it
    UI.Fill(window, "BACKGROUND", C.page, 1):SetAllPoints()
    UI.Outline(window, "BORDER", C.lineStrong, 0)
    UI.Outline(window, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.35 }, -1)
    window:Hide()
    -- Esc closes it, as it closes the game's own windows
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalUIOptions") end
    -- a row's lift follows the pointer only while the window is open
    local function Track() Hover(UnderPointer()) end
    window:SetScript("OnHide", function()
        UI.CloseMenu()
        if body then body:SetScript("OnUpdate", nil) end
        Hover(nil)
    end)
    window:SetScript("OnShow", function()
        if body then body:SetScript("OnUpdate", Track) end
        Refresh()
    end)

    WindowHead()

    Places()
    Sidebar()

    body = CreateFrame("Frame", nil, window)
    window.Hover = function() Hover(UnderPointer()) return hovered end
    scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -12, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    thumb = UI.Fill(body, "ARTWORK", C.lineStrong)
    thumb:SetWidth(4)
    thumb:Hide()
    -- a search's match, outlined a moment
    flash = CreateFrame("Frame", nil, body)
    flash:SetFrameLevel(body:GetFrameLevel() + 20)
    UI.Outline(flash, "OVERLAY", C.goldBright, 0)
    flash:Hide()
    flash:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        if self.left <= 0 then self:Hide() else self:SetAlpha(self.left / 1.2) end
    end)
    Footer()
    -- its parts, by name (the harness reads them)
    window.tree, window.scroll, window.thumb = side, scroll, thumb
    window.search, window.nav, window.flash = search, nav, flash
    window.footProfile, window.footReload, window.footDot = footProfile, footReload, footDot

    local width = W - X - RIGHT - 12
    -- a search's page, its header saying what it found
    finds = CreateFrame("Frame", nil, scroll)
    finds:SetWidth(width)
    finds:SetHeight(1)
    finds.lent, finds.links = {}, {}
    finds.head = CreateFrame("Frame", nil, window)
    finds.head:SetPoint("TOPLEFT", window, "TOPLEFT", HEAD_X, -HEAD_TOP)
    finds.head:SetPoint("TOPRIGHT", window, "TOPRIGHT", -EDGE, -HEAD_TOP)
    finds.head:SetHeight(HEAD_H)
    UI.Fill(finds.head, "BACKGROUND", C.chrome, 1):SetAllPoints()
    -- what matched, on the rail (no title: the search box says it)
    finds.head.crumb = UI.Plain(finds.head, 13, C.dim)
    finds.head.crumb:SetPoint("LEFT", finds.head, "TOPLEFT", PAD, -TAB_H / 2)
    local rule = UI.Fill(finds.head, "ARTWORK", C.line)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    finds.none = UI.Plain(finds, 12, C.dim)
    finds.none:SetPoint("TOPLEFT", 0, -4)
    finds.none:SetText(Tr["No option, section or page has those letters in its name."])
    finds:Hide()
    finds.head:Hide()
    window.finds = finds
    Each(function(content, path, page, tab)
        built[path] = content.modules and Modules(content, path, page, width) or Build(content, path, page, tab, width)
    end)
    Select(current or "modules")
end

-- ------------------------------------------------------------ open
-- ns.OpenOptions(path): the window, on that page ("console/unit"), at a
-- part's card on it ("windows#bags"), on one of its sheets
-- ("console/bar#elements"), or on the page it was last on.
function ns.OpenOptions(path)
    if not pages then return end
    Window()
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
    local at, part = tostring(path or ""):match("^([^#]+)#(.+)$")
    if at then
        local page, tab = Find(at)
        local found = false
        for _, g in ipairs((tab or page) and (tab or page).groups or {}) do
            if g.id == part then
                Reveal(at, g)
                found = true
            end
        end
        if not found then Select(at, part) end
    elseif path then
        Select(path)
    end
    window:Show()
    window:Raise()
end

function ns.CloseOptions()
    if window then window:Hide() end
end

-- The page shown, while the window is.
function ns.OptionsShown()
    return window and window:IsShown() and current or nil
end

-- The window's frames, made without showing it (the harness's way in).
function ns.BuildOptions()
    Window()
end

-- What a search finds, and choosing its nth line on the right (the
-- harness's way in).
function ns.SearchOptions(text, choose)
    Window()
    search:SetText(text or "")
    Search(text)
    local found = results
    local link = choose and finds.links[choose]
    if link and link:IsShown() then Choose(link.entry) end
    return found
end

ns.OnAnySetting(function() Refresh() end)

ns.On("PLAYER_LOGIN", function()
    pages = ns.OptionPages()
    categories = ns.OptionCategories()
    reloadAt = {}
    ReloadKeys(function(key) reloadAt[key] = ns.db[key] end)
end)
