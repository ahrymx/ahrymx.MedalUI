-- What the settings window shows: its pages, some with tabs, each page's
-- options in groups, and the sidebar's categories they are listed under.
-- Data only; the window (window.lua) draws it and controls.lua makes the
-- controls.
--
-- A page's master, when it has one, is the switch in its header and its
-- card on Modules: while it is off, everything else on the page is drawn
-- but cannot be changed. A section's switch (Switched) does the same for
-- its rows; a part's (Part) has a card on Modules too. An intro is one
-- line; more of it (more) is the header's (?) tip. An option marked
-- reload takes effect after a reload; the window's footer says so once
-- one has changed.
--
-- A group sits on a sheet (On): a tab under its page's header, one of
-- OPTION_SHEETS, in their order. A page whose groups are on two sheets or
-- more shows the tabs, one column of cards each; others show every group,
-- in two columns. A page with variants (Party: the console's frames, or
-- the widget's) has a switch beside its tabs, each group of one variant
-- (Variant) shown only with it.
local _, ns = ...

ns.OPTION_SHEETS = {
    { "general", "General" },
    { "position", "Position" },
    { "look", "Look" },
    { "elements", "Elements" },
    { "visibility", "Visibility" },
    { "auras", "Auras" },
    { "behaviour", "Behaviour" },
    { "immersion", "Immersion Mode" },
    { "advanced", "Advanced" },
}

local RELOAD = " Takes effect after a reload."

local function Check(key, label, tip, reload)
    return { kind = "check", key = key, label = label, tip = reload and tip .. RELOAD or tip, reload = reload }
end
-- An option greyed while another is off: for a master, whose page has no
-- other way to say so.
local function Needs(key, spec)
    spec.needs = key
    return spec
end
local function Choice(key, label, choices, tip, reload)
    return { kind = "choice", key = key, label = label, choices = choices,
        tip = reload and tip .. RELOAD or tip, reload = reload }
end
local function Color(key, label, tip)
    return { kind = "color", key = key, label = label, tip = tip }
end
local function Button(label, click, tip)
    return { kind = "button", label = label, click = click, tip = tip }
end
-- The unit-frame editor on a frame (options/editor.lua).
local function Editor(id, label)
    return Button(label or "Edit the frames", function()
        ns.OpenEditor(type(id) == "function" and id() or id)
    end, "The unit-frame editor: move, size, show or hide each piece of these frames, and choose what their "
        .. "texts say. Also /mdlui edit.")
end

-- A font for reading (ns.Fonts()): its choices asked as the list opens,
-- since other addons register theirs after us; each drawn in itself. A
-- shared font chosen whose addon is gone stays listed, saying so (the text
-- is Medalluin's own meanwhile).
local function FontChoice(key, label, tip)
    local spec = { kind = "choice", key = key, label = label, tip = tip }
    function spec.list()
        local out, chosen, there = {}, ns.db and ns.db[key], false
        for _, f in ipairs(ns.Fonts()) do
            table.insert(out, { f[1], f[2], nil, f[3] })
            there = there or f[1] == chosen
        end
        local name = not there and type(chosen) == "string" and chosen:match("^lsm:(.+)$")
        if name then table.insert(out, { chosen, name .. " (not loaded)", nil, ns.font }) end
        return out
    end
    spec.choices = spec.list()
    return spec
end
local function Points(key, label, tip)
    return { kind = "slider", key = key, label = label, min = 9, max = 20, step = 1, tip = tip,
        text = function(v) return string.format("%d pt", v) end }
end

local function Group(title, ...)
    return { title = title, items = { ... } }
end
-- A group on a sheet; a list of groups, each on it.
local function On(sheet, g)
    g.sheet = sheet
    return g
end
local function AllOn(sheet, groups)
    for _, g in ipairs(groups) do g.sheet = sheet end
    return groups
end
-- A group of one variant of its page, and the chip on its band saying
-- where its options are kept.
local function Variant(variant, chip, g)
    g.variant, g.chip = variant, chip
    return g
end
-- A section headed by the switch its rows need: on its heading's line, the
-- rows greyed while it is off (unless they need something else).
local function Switched(switch, title, ...)
    local g = Group(title, ...)
    g.switch = switch
    for _, spec in ipairs(g.items) do
        if not spec.needs then spec.needs = switch.key end
    end
    return g
end
-- A group with a tip under its heading.
local function Tip(tip, g)
    g.tip = tip
    return g
end
-- A part (a window, a side panel tab) as a card on its page: its switch in
-- its head, its options under it, and a card of its own on Modules (by id,
-- MODULES' key). Its old page's groups, run together.
local function Part(id, title, forever, switch, groups)
    local items = {}
    for _, g in ipairs(groups or {}) do
        for _, spec in ipairs(g.items) do table.insert(items, spec) end
    end
    local g = Switched(switch, title, unpack(items))
    g.id, g.forever = id, forever or nil
    return g
end

-- An opacity, as a percentage; and a fade's length, in seconds.
local function Opacity(key, label, tip, needs)
    return { kind = "slider", key = key, label = label, min = 0, max = 1, step = 0.05, tip = tip, needs = needs,
        text = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end }
end
local function Seconds(key, label, tip)
    return { kind = "slider", key = key, label = label, min = 0, max = 2, step = 0.05, tip = tip,
        text = function(v)
            if v < 0.025 then return "At once" end
            return string.format("%.2fs", v)
        end }
end

-- The lower row's choices: the swing timer only where the client has one
-- (bars/lowrow.lua)
local function LowRows()
    local out = {
        { "resource", "Class resource", "Combo points, holy power, chi, soul shards, arcane charges, essence or "
            .. "runes; vigor while skyriding. Empty for a class without one." },
    }
    if ns.SwingTimerAvailable and ns.SwingTimerAvailable() then
        table.insert(out, { "swing", "Swing timer", "Fills until your next main-hand swing or ranged shot, the "
            .. "seconds left at its right." })
    end
    table.insert(out, { "mana", "Mana", "Your mana, the amount at its right. Empty for a class without mana." })
    return out
end

-- A module's medallion (media/strips) and its line on Modules, by path; an
-- addon's page has a card without a switch.
local MODULES = {
    ["console/bar"] = { "skills", "Medalluin's bar on top of the console, holding action bar 1." },
    ["console/overhead"] = { "view-full", "Boss, pet, focus and target frames, and bars, at the top of the screen." },
    chat = { "chat", "Blizzard's chat in a box over the micro menu." },
    side = { "side-meter", "Zone, auras, meter and loot tabs on the right strip." },
    ["side/zone"] = { "side-zone", "The minimap beside this zone's quests, in the side panel." },
    ["side/auras"] = { "side-auras", "Your buffs and debuffs, with the time each has left." },
    ["side/meter"] = { "side-rate", "Damage, healing and more for each member, from the game's meter." },
    ["side/loot"] = { "side-loot", "What your group looted, boss by boss, with who won each roll." },
    quests = { "quests", "Your tracked quests on the left of the screen, by zone." },
    tray = { "misc", "A rail on the left edge: a tab to open and close each window there." },
    bags = { "view-bags", "One window for every bag, sorted and searchable." },
    bank = { "currency", "The bank in a window of its own, with the bags' views and search." },
    character = { "character", "Gear, stats, reputation and currency." },
    spellbook = { "spellbook", "Spells in role cards, macros and the trainer." },
    talents = { "talents", "A tab for each tree, with Apply and your plans." },
    professions = { "profession", "An overview, and a tab for each profession that crafts." },
    questlog = { "questlog", "Every quest in your log, by zone, on the right strip." },
    lfg = { "lfg", "The group finder and Who." },
    cdm = { "side-timeless", "The game's Cooldown Manager, its spells as medallions." },
    cc = { "mouse", "The game's Click Casting, each binding with its keycaps." },
    npc = { "social", "Gossip, quests, vendors, trainers, flights and mail." },
    tooltips = { "help", "Tooltips reskinned, with a live sample of each kind.", addon = true },
    radial = { "radial", "Hold a key, sweep, release: radial menus of spells, items and markers.", addon = true },
}
local SCOPES = { "Shared by every profile.", "Kept per profile." }

-- A page's or tab's extras for the window: Forever only, and the scope its
-- intro opened with (said once, in its header), off the intro; its
-- medallion and line.
local function Dress(content, path)
    local intro = content.intro
    if intro then
        if intro:find("^Forever only%. ") then
            content.forever = true
            intro = intro:sub(#"Forever only. " + 1)
        end
        for _, scope in ipairs(SCOPES) do
            if intro:sub(1, #scope) == scope then
                content.scope = scope:sub(1, -2)
                intro = (intro:sub(#scope + 1):gsub("^ +", ""))
            end
        end
        content.intro = intro ~= "" and intro or nil
    end
    local m = MODULES[path]
    if m then content.glyph, content.blurb, content.addon = m[1], m[2], m.addon end
    -- a part's card: its line under its head when it has no options, and
    -- Forever only when it is
    for _, g in ipairs(content.groups or {}) do
        if g.id then
            local pm = MODULES[g.id]
            if pm then g.glyph, g.blurb = pm[1], pm[2] end
            local tip = #g.items == 0 and g.blurb or nil
            if g.forever then tip = tip and ("Forever only. " .. tip) or "Forever only." end
            g.tip = g.tip or tip
        end
    end
end

-- Lists of groups, one after another.
-- A group only on one console (a profile's id): built when that console is
-- the one built (ns.consoleBuilt), as a list for Concat; else none.
local function ForConsole(id, g)
    return ns.consoleBuilt == id and { g } or {}
end

-- Where the party sits: on the console (the Reticule's row, or the
-- Arena's wings), or the widget.
local function PartyLayout(id)
    return Choice("partyLayout", "Party layout", {
        { "console", "Console", id == "reticule"
            and ("A row of four frames under the Reticule, each member's pet hanging under its frame. While you "
                .. "are in a group the minimap stays in the top right corner and the centre grid stays out.")
            or "The medallion's party wings, each member's pet hanging under its frame." },
        { "widget", "Widget", "A box of party frames, under a Party tab, that you can drag anywhere: hold the tab "
            .. "to move it. In a raid it gives way to the raid frames." },
    }, "Where the party frames sit.")
end

local function Concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, g in ipairs(list) do table.insert(out, g) end
    end
    return out
end

-- A console's place and size (movers.lua), as one group; a tip under its title.
local function Placed(id, title, tip)
    local groups = ns.ConsolePlaceGroups(Group, { { id, title } })
    if groups[1] then groups[1].tip = tip end
    return groups
end

-- Bar 1's choices, and the extra bars'
local function Visibility(it, them)
    local V = ns.VISIBILITY
    return {
        { V.ALWAYS, "Always" },
        { V.COMBAT, "In combat", "Faded out of combat; " .. it .. " back while you drag a spell onto " .. them .. ". "
            .. "Faded to 0%, no clicks or tooltips; keys still press." },
        { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over " .. them .. ", or a spell is being dragged." },
        { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
    }
end

-- A text size, as a scale of what the button draws on its own; first, a
-- choice before them (Hidden).
local function TextSizes(first)
    local sizes = {
        { 0.8, "Small" },
        { 1, "Normal", "As the button draws it." },
        { 1.25, "Large" },
        { 1.5, "Larger" },
    }
    if first then table.insert(sizes, 1, first) end
    return sizes
end

-- A Cooldown Manager viewer's tab (cooldowns/display.lua): the same options
-- for each, keyed cdm<letter><field> (settings.lua's CDM_FIELDS), an
-- option greyed while its layout does not use it.
local function Slider(key, label, min, max, step, tip, text)
    return { kind = "slider", key = key, label = label, min = min, max = max, step = step, tip = tip, text = text }
end
local cdmLook = {}               -- by viewer letter: CooldownTab's look specs
function ns.CdmLookSpecs(letter) return cdmLook[letter] end
-- every viewer's tab: the simulation at its tabs' right, its fade on Visibility
local function CdmSimulate()
    return Check("simCdm", "Simulate cooldowns",
        "Show every viewer's icons and bars as these options draw them, without a fight: your own spells or "
        .. "a random full set, cooling down, with charges and stacks, buffs coming and going. A small "
        .. "panel on the right sets what they show.")
end
local function CdmVisibility(K)
    local V = ns.VISIBILITY
    return On("visibility", Group("Visibility",
        Choice(K("Vis"), "Visibility", {
            { V.ALWAYS, "Always" },
            { V.COMBAT, "In combat", "Faded out of combat. Faded to 0%, no tooltips." },
            { V.MOUSEOVER, "On mouseover", "Faded until the pointer is over it." },
            { V.COMBAT_OR_MOUSEOVER, "In combat or on mouseover" },
        }, "Faded, it is only see-through: it still tracks everything (on In combat at 0%, without "
            .. "its tooltips). Whole while the Cooldown Manager or "
            .. "Edit Mode is open. Edit Mode's own Visibility (Cooldown Settings) still hides it outright."),
        Opacity(K("Faded"), "Faded opacity", "How see-through it is when faded: 0% is gone."),
        Seconds(K("FadeTime"), "Fade time", "How long a fade in or out takes.")))
end
-- its place: movers.lua's sliders, on Position after its layout
local function CdmPlace(groups, letter)
    for _, g in ipairs(ns.ConsolePlaceGroups(Group, { { "cdm" .. letter, "Place" } })) do
        g.tip = "Drag it in Edit Mode, where it wears a blue mover, or set it here."
        g.sheet = "position"
        table.insert(groups, 2, g)
    end
end
local function CooldownTab(v)
    local letter, id, name = v[1], v[2], v[3]
    local function K(field) return "cdm" .. letter .. field end
    -- an option its layout does not use: off the page meanwhile (greyed on
    -- the mover's popup)
    local function When(field, value, spec)
        spec.can = function() return ns.db[K(field)] == value end
        spec.hide = true
        return spec
    end
    local px = function(n) return string.format("%d px", n) end
    local function Positions(below)
        local out = {
            { "bottomright", "Bottom right" }, { "topright", "Top right" }, { "bottomleft", "Bottom left" },
            { "topleft", "Top left" }, { "center", "Centre" },
        }
        if below then table.insert(out, { "below", "Below", "Under the icon, outside it." }) end
        return out
    end
    -- its look: on the page's Layout and Icons groups, and on its mover's
    -- popup in Edit Mode (movers.lua, ns.CdmLookSpecs), the same specs
    local look = {
        Choice(K("Layout"), "Layout", {
            { "bar", "Bar", "Rows of icons, across or down." },
            { "arch", "Arch", "One arc of icons, standing upright." },
        }, "How its icons stand."),
        When("Layout", "bar", Choice(K("Orient"), "Bar runs", {
            { "across", "Across", "Left to right; another row above." },
            { "down", "Down", "Top to bottom; another column to the right." },
        }, "A bar's direction.")),
        When("Layout", "bar", Slider(K("PerRow"), "Icons per row", 0, 20, 1,
            "A row this long, then another. All in one row at 0.",
            function(n) return n == 0 and "One row" or tostring(n) end)),
        When("Layout", "arch", Slider(K("Span"), "Arch span", 60, 240, 5,
            "How far round the arc reaches, end to end: wider is flatter for the same icons.",
            function(n) return string.format("%d°", n) end)),
        When("Layout", "arch", Choice(K("Opens"), "Arch bends", {
            { "up", "Up", "Its middle highest, its ends lower: an arch." },
            { "down", "Down", "Its middle lowest, its ends higher: a bowl." },
        }, "Which way the arc curves.")),
        Choice(K("Shape"), "Shape", {
            { "round", "Round medallion", "Round, in a gold rim, its sweep round." },
            { "rounded", "Rounded square", "A square with soft corners, in a gold rim." },
            { "square", "Square", "Square, in a gold rim." },
            { "bare", "Bare", "The icon alone, square, no rim." },
        }, "Each icon's shape; its sweep and out-of-range tint follow it."),
        Slider(K("Size"), "Size", 16, 80, 1, "Each icon's width.", px),
        Slider(K("Spacing"), "Spacing", 0, 30, 1, "Between icons, and between rows.", px),
    }
    cdmLook[letter] = look
    local groups = {
        On("position", Group("Layout",
            look[1], look[2], look[3], look[4], look[5],
            Choice(K("Order"), "Fill order", {
                { "middle", "Middle out", "The first in the middle, then right of it, then left, outward." },
                { "start", "From the start", "The first at the left, or the top." },
                { "finish", "From the end", "The first at the right, or the bottom." },
            }, "The order is the Cooldown Manager's own, as you drag spells in it (/cdm): this is where its first "
                .. "stands."),
            Check(K("Gaps"), "Close gaps",
                "An icon that is hidden (a buff not up) leaves no hole: the others close ranks as it comes and goes, "
                .. "in combat too. Off, each keeps its place."))),
        On("look", Group("Icons",
            look[6], look[7], look[8])),
        On("elements", Group("Text",
            Choice(K("CdSize"), "Cooldown number size", TextSizes({ 0, "Hidden", "The sweep alone says how long." }),
                "The time left on a cooling-down icon."),
            Choice(K("CdPos"), "Cooldown number at", {
                { "center", "Centre" }, { "top", "Top" }, { "bottom", "Bottom" },
            }, "Where the time left stands on the icon."),
            Choice(K("CountSize"), "Charges and stacks size", TextSizes({ 0, "Hidden", "No count on the icon." }),
                "A spell's charges, a buff's stacks."),
            Choice(K("CountPos"), "Charges and stacks at", Positions(true), "Where the count stands."))),
        On("elements", Group("Cooldowns",
            Check(K("Swipe"), "Sweep", "The dark sweep that winds round a cooling-down icon."),
            Check(K("Desat"), "Grey while cooling down",
                "The game greys an icon while its spell cools down. Off, it keeps its colour."),
            Check(K("Range"), "Out-of-range tint", "A red tint over a spell whose target is out of its range."),
            Check(K("Tips"), "Tooltips", "The spell's tooltip with the pointer over its icon."))),
        CdmVisibility(K),
    }
    CdmPlace(groups, letter)
    return {
        id = id, name = name, intro = "Kept per profile.", aside = CdmSimulate(),
        enabled = function() return ns.db.cdmWindow and ns.db.cdmDisplay and true or false end,
        groups = groups,
    }
end

-- The tracked bars' tab: a bar each, so options of their own (settings.lua's
-- CDM_BAR_FIELDS, keyed cdmT<field>). Its look is on its mover's popup too.
local function BarsTab(v)
    local letter, id, name = v[1], v[2], v[3]
    local function K(field) return "cdm" .. letter .. field end
    local px = function(n) return string.format("%d px", n) end
    local look = {
        Choice(K("Grow"), "Grows", {
            { "up", "Up", "The first bar at the bottom, the next above it." },
            { "down", "Down", "The first bar at the top, the next below it." },
        }, "Which way the column runs from its first bar, which stays where it is."),
        Slider(K("Width"), "Width", 80, 400, 5, "Each bar's width, its icon included.", px),
        Slider(K("Size"), "Height", 12, 48, 1, "Each bar's height; its icon is as tall.", px),
        Slider(K("Spacing"), "Spacing", 0, 20, 1, "Between bars.", px),
        Choice(K("Icon"), "Icon", {
            { "left", "On the left" },
            { "right", "On the right" },
            { "none", "None", "The bar alone, its full width." },
        }, "The spell's icon at one end of its bar."),
        Choice(K("Shape"), "Icon shape", {
            { "round", "Round medallion", "Round, in a gold rim." },
            { "rounded", "Rounded square", "A square with soft corners, in a gold rim." },
            { "square", "Square", "Square, in a gold rim." },
            { "bare", "Bare", "The icon alone, square, no rim." },
        }, "The icon's shape."),
    }
    cdmLook[letter] = look
    local groups = {
        On("look", Group("Bars",
            look[1], look[2], look[3], look[4],
            Check(K("Gaps"), "Close gaps",
                "A bar whose buff is not up leaves no hole: the others close ranks as it comes and goes, in combat "
                .. "too. Off, each keeps its place."))),
        On("look", Group("Icon", look[5], look[6])),
        On("elements", Group("Text",
            Choice(K("NameSize"), "Name size", TextSizes({ 0, "Hidden", "The bar without its spell's name." }),
                "The spell's name, on its bar."),
            Choice(K("TimeSize"), "Time left size", TextSizes({ 0, "Hidden", "The bar alone says how long." }),
                "The time left, at the bar's end."),
            Choice(K("CountSize"), "Stacks size", TextSizes({ 0, "Hidden", "No count on the icon." }),
                "A buff's stacks, on its icon."),
            Check(K("Tips"), "Tooltips", "The spell's tooltip with the pointer over its bar."))),
        CdmVisibility(K),
    }
    CdmPlace(groups, letter)
    return {
        id = id, name = name, intro = "Kept per profile.", aside = CdmSimulate(),
        enabled = function() return ns.db.cdmWindow and ns.db.cdmDisplay and true or false end,
        groups = groups,
    }
end

-- How far a group's frames reach before they fade.
local function Range(key, who)
    return Choice(key, "Fade out of range", {
        { 40, "40 yards", "Standard spell and healing range." },
        { 30, "30 yards", "Mid-range distance." },
        { 20, "20 yards", "Short distance." },
        { 10, "10 yards", "Melee and interaction distance." },
        { 0, "Disabled", "Never fade " .. who .. " frames based on distance." },
    }, "Fade " .. who .. " frames when members move beyond the chosen distance.")
end
local function Glow(key)
    return Check(key, "Dispel glow on frame borders",
        "Glow the frame's border in the debuff's color (purple for Curse, green for Poison, etc.) when an ally has "
        .. "a debuff you can dispel. Which types, and their colours: Unit Frames > General > Glows.")
end
local function Threat(key)
    return Check(key, "Aggro glow on frame borders",
        "Glow the frame's border while that unit has aggro: something is attacking it. A dispel glow comes first. "
        .. "Its colour: Unit Frames > General > Glows.")
end
-- The glows' own group (Unit Frames > General): the types the player
-- dispels, each one's on and colour, and the aggro glow's colour.
local function Glows()
    local items = {
        { kind = "note", text = function()
            local types, spells = ns.PlayerDispels()
            if not types[1] then return "You dispel nothing: none of your spells removes a debuff." end
            return "You dispel " .. table.concat(types, ", ") .. "  (" .. table.concat(spells, ", ") .. ")."
        end },
    }
    for _, t in ipairs(ns.DISPEL_TYPES) do
        local check = Check("dispel" .. t, t, "Glow for a " .. t .. " debuff. A type none of your spells "
            .. "dispels never glows.")
        check.can = function()
            for _, have in ipairs((ns.PlayerDispels())) do if have == t then return true end end
            return false
        end
        check.beside = Color("dispelColor" .. t, t .. " colour", "The glow's colour for a " .. t .. " debuff.")
        check.beside.can = check.can
        table.insert(items, check)
    end
    table.insert(items, Color("threatColor", "Aggro colour", "The aggro glow's colour."))
    table.insert(items, Button("Reset colours", function()
        for _, t in ipairs(ns.DISPEL_TYPES) do ns.SetOption("dispelColor" .. t, ns.OptionBase("dispelColor" .. t)) end
        ns.SetOption("threatColor", ns.OptionBase("threatColor"))
    end, "Every glow's colour back to its first."))
    return Group("Glows", unpack(items))
end
local function CC(key, whose)
    return Check(key, "Crowd control center icon",
        "Display a large icon in the middle of " .. whose .. " frame with a radial timer sweep when the unit is "
        .. "affected by CC.")
end
local function BossDebuffs(key)
    return Check(key, "Boss debuffs",
        "Show a critical boss debuff in the middle of the frame, where crowd control would be; crowd control "
        .. "comes first.")
end
local function Pets(key)
    return Check(key, "Show party pets", "Show pet unit frames directly below party members who have active pets.")
end
local function Buffs(key)
    return Check(key, "Buffs",
        "Show a compact row of buffs on the outer corner of the health bar: your own (buffs and HoTs), or every "
        .. "one with From in the editor.")
end
local function Debuffs(key, where)
    return Check(key, "Debuffs",
        "Show a compact row of debuffs " .. (where or "on the inner corner of the health bar") .. ": every one, "
        .. "or only yours with From in the editor.")
end
-- The corner minimap's place and size, and its grip's showing.
local function MinimapCorner()
    local groups = Placed("minimap", "In the corner")
    table.insert(groups[1].items, Check("minimapMoverHover", "Movers only on mouseover",
        "Hide the corner minimap's tab, the grip with the area's name that moves it, until the pointer is over "
        .. "the minimap."))
    return groups
end
local function Movers(key, what)
    return Check(key, "Movers only on mouseover",
        "Hide the " .. what .. " widget's tab, the grip that moves it, until the pointer is over the widget.")
end
local function Mine(key, who)
    return Check(key, "Debuffs",
        "Up to three of your own debuffs on " .. who .. ", small icons in the health bar's top right corner. "
        .. "From in the editor shows every one instead.")
end

-- ------------------------------------------------------------ Shared
-- Settings > Shared: what many parts have, in one place. Its own options
-- are the shared values (settings.lua's SHARED), which a frame's own choice
-- on its page overrides (marked Own there); the rest are the parts' own
-- options, the same ones, gathered by topic.

-- Every option on the pages by key, with the master that greys it there.
local function Specs(list)
    local specs = {}
    local function Walk(groups, master)
        for _, g in ipairs(groups or {}) do
            if g.switch and not specs[g.switch.key] then specs[g.switch.key] = { spec = g.switch, master = master } end
            for _, spec in ipairs(g.items) do
                if spec.key and not specs[spec.key] then specs[spec.key] = { spec = spec, master = master } end
            end
        end
    end
    for _, page in ipairs(list) do
        Walk(page.groups, page.master)
        for _, tab in ipairs(page.tabs or {}) do Walk(tab.groups, tab.master or page.master) end
    end
    return specs
end

local AURA_COLS = { { label = "All" }, { label = "Console" }, { label = "Widget" }, { label = "Raid" },
    { label = "BG" }, { label = "Overhead" }, { label = "Boss" }, { label = "Arena" } }
-- a row per piece: the shared key, then each frame set's (false: it has none)
local AURA_ROWS = {
    { label = "Dispel glow", tip = "The frame's border in the debuff's colour while an ally has one you can "
        .. "dispel.", keys = { "sharedGlow", "auraGlow", "partyWidgetGlow", "raidGlow", "bgGlow", false, false,
        false } },
    { label = "Aggro glow", tip = "The frame's border while that unit has aggro.",
        keys = { "sharedThreat", "auraThreat", "partyWidgetThreat", "raidThreat", "bgThreat", false, false, false } },
    { label = "Crowd control", tip = "A large icon in the middle of the frame while the unit is crowd "
        .. "controlled.", keys = { "sharedCC", "auraCC", "partyWidgetCC", "raidCC", "bgCC", false, false,
        "arenaCC" } },
    { label = "Buffs", tip = "A row of buffs on the frame.",
        keys = { "sharedBuffs", "auraBuffs", "partyWidgetBuffs", false, false, false, false, false } },
    { label = "Debuffs", tip = "A row of debuffs on the frame.",
        keys = { "sharedDebuffs", "auraDebuffs", "partyWidgetDebuffs", "raidDebuffs", "bgDebuffs", "bossMine",
            "bossWidgetMine", "arenaMine" } },
    { label = "Boss debuffs", tip = "A critical boss debuff in the middle of the frame.",
        keys = { "sharedBoss", "auraBoss", "partyWidgetBoss", "raidBoss", false, false, false, false } },
}

local SHARED_NOTE = "A frame's own choice, on its page, wins over a shared one there, and is marked Own."

local function Shared(list)
    local specs = Specs(list)
    -- a part's own options, by key, under a title (greyed with their
    -- page's master, as there)
    local function Mirror(title, keys, tip)
        local items = {}
        for _, key in ipairs(keys) do
            local e = specs[key]
            if e then
                if e.master and not e.spec.needs and e.spec ~= e.master then e.spec.needs = e.master.key end
                table.insert(items, e.spec)
            end
        end
        local g = Group(title, unpack(items))
        g.tip = tip
        return g
    end
    local grid = Group("On the frames", { kind = "grid", label = "Auras", cols = AURA_COLS, rows = AURA_ROWS })
    grid.wide = true
    grid.tip = "All sets every frame that has not chosen its own; a gold corner marks one that has."
    -- Tools: Overview > General's sections, the same ones
    local tools = {
        Mirror("Preview", { "simParty", "simCdm" }),
        Group("Editor", Editor(nil, "Edit unit frames")),
        Group("Key bindings", Button("Bind keys", function()
            if ns.CloseOptions then ns.CloseOptions() end
            ns.KeybindMode(true)
        end, "Closes this window. Point at an action button and press a key to bind it; Esc over a button "
            .. "removes its keys. Also /mdlui kb.")),
        Mirror("Game menu", { "gameMenu" }),
    }
    return {
        id = "shared", name = "Shared",
        tabs = {
            {
                id = "visibility", name = "Visibility & fading", intro = SHARED_NOTE,
                -- Immersion Mode: each profile's switch and its main choices;
                -- Advanced: every option, those the same ones (a key is one
                -- setting wherever it is shown)
                groups = Concat({
                    On("immersion", ns.consoleBuilt == "reticule"
                        and Mirror("Console: Minimal OoC Mode", { "consoleMinimal", "consoleMinimalUnits",
                            "consoleMinimalRest", "consoleMinimalRegen", "consoleMinimalTarget", "consoleMinimalHurt",
                            "consoleMinimalGroup", "consoleMinimalMouse" },
                            "Out of combat, the console fades away but for your player and target frames.")
                        or Tip("The Reticule's: choose it on Profiles to use it.",
                            Group("Console: Minimal OoC Mode"))),
                    On("immersion", Mirror("Chat & side panel", { "chatImmersion", "chatBareCombat",
                        "sideImmersion", "sideFadedAlpha", "sideShowCombat", "sideShowTarget", "sideShowMouse" },
                        "The chat bare when idle, its box back on use; the side panel's background faded when idle.")),
                }, AllOn("advanced", {
                    Group("Every frame",
                        Check("moverHover", "Movers only on mouseover",
                            "Hide each box's tab, the grip that moves it, and the corner minimap's, until the "
                            .. "pointer is over it."),
                        Range("rangeFade", "group")),
                    Mirror("Console", { "consoleFade", "consoleFadedAlpha", "consoleShowCombat",
                        "consoleShowTarget", "consoleShowHurt", "consoleShowGroup", "consoleShowMouse",
                        "consoleAlpha", "consoleFadeIn", "consoleFadeOut", "consoleMinimal", "consoleMinimalUnits",
                        "consoleMinimalRest", "consoleMinimalRegen", "consoleMinimalTarget", "consoleMinimalHurt",
                        "consoleMinimalGroup", "consoleMinimalMouse" }),
                    Mirror("Overhead", { "overheadAlpha", "overheadFadeIn", "overheadFadeOut", "overheadRowVis",
                        "overheadRowFaded", "overheadRowFadeTime" }),
                    Mirror("Action bars", { "visibility", "extraVisibility" }),
                    Mirror("Quest tracker, full view", { "questsFullMouseover", "questsFullCombat" }),
                    Mirror("Quest tracker, minimal view", { "questsMinimalMouseover", "questsMinimalCombat" }),
                    Mirror("Edge Draw", { "trayDelay" }),
                    Mirror("Chat", { "chatImmersion", "chatBareCombat", "chatBareDelay", "chatBands" }),
                    Mirror("Side panel", { "sideImmersion", "sideFadedAlpha", "sideShowCombat", "sideShowTarget",
                        "sideShowHurt", "sideShowGroup", "sideShowMouse", "sideFadeIn", "sideFadeOut" }),
                })),
            },
            {
                id = "auras", name = "Auras", intro = SHARED_NOTE,
                groups = { grid, Glows(), Mirror("Blizzard's auras", { "blizzardAuras" }) },
            },
            {
                id = "look", name = "Colours & look", intro = "Each part's own, gathered here.",
                groups = {
                    Mirror("Unit frames", { "deadColor" }),
                    Mirror("Action bars", { "artColor", "hotkeySize", "cooldownTextSize" }),
                    Mirror("Quest tracker", { "questsTitleFont", "questsTitleSize", "questsObjectiveFont",
                        "questsObjectiveSize" }),
                },
            },
            {
                id = "tools", name = "Tools", intro = "Also on Overview > General.",
                groups = tools,
            },
        },
    }
end

-- Each part's page whose options are also on a Shared tab says so, in its
-- header's (?) tip: "Also on Shared > Auras."
local function AlsoOnShared(list)
    local on = {}  -- key -> the Shared tabs' names it is on
    local shared
    for _, page in ipairs(list) do if page.id == "shared" then shared = page end end
    for _, tab in ipairs(shared.tabs) do
        local function Add(key)
            on[key] = on[key] or {}
            if on[key][#on[key]] ~= tab.name then table.insert(on[key], tab.name) end
        end
        for _, g in ipairs(tab.groups) do
            for _, spec in ipairs(g.items) do
                if spec.key then
                    Add(spec.key)
                    for _, k in ipairs(ns.SHARED[spec.key] or {}) do Add(k) end
                end
                for _, row in ipairs(spec.rows or {}) do
                    for _, k in ipairs(row.keys) do if k then Add(k) end end
                end
            end
        end
    end
    local function Note(content)
        local names, seen = {}, {}
        for _, g in ipairs(content.groups or {}) do
            for _, spec in ipairs(g.items) do
                for _, name in ipairs(spec.key and on[spec.key] or {}) do
                    if not seen[name] then
                        seen[name] = true
                        table.insert(names, name)
                    end
                end
            end
        end
        if #names == 0 then return end
        content.also = "Also on Shared > " .. table.concat(names, ", ") .. "."
    end
    for _, page in ipairs(list) do
        if page ~= shared then
            Note(page)
            for _, tab in ipairs(page.tabs or {}) do Note(tab) end
        end
    end
end

-- Built when the window first opens: the lists come from modules loaded
-- after settings.lua (paging, the meter, the loot log).
function ns.OptionPages()
    local metrics, qualities = {}, {}
    for _, m in ipairs(ns.METER_METRICS) do table.insert(metrics, { m[1], m[2] }) end
    for _, q in ipairs(ns.LOOT_QUALITIES) do table.insert(qualities, { q[1], q[2] }) end
    local M = ns.METER_SESSION

    local paging = {}
    for _, pb in ipairs(ns.PAGING_BARS or {}) do
        table.insert(paging, {
            title = pb.name,
            tip = pb.grid and "The Reticule's 2x5 grid in the centre bay."
                or pb.base and ("Shown with Rows at " .. pb.name:match("%d") .. " or more.")
                or "Action bar 1, in the bar's frame.",
            items = {
                Needs("actionBar", Choice(pb.key, "Pages", ns.PagingChoices(pb),
                    "Which action page the bar shows. A page is 12 slots: page n holds slots (n-1)x12+1 to nx12.")),
                Needs("actionBar", Button("Edit conditional", function() ns.EditPaging(pb) end,
                    "A macro conditional naming the page, e.g. [mod:shift] 2; [stealth] 7; 1. \"possess\" is the "
                    .. "bar the game puts up for a vehicle, an override or a possessed unit. Saving it picks Custom.")),
            },
        })
    end

    local list = {
        {
            id = "modules", name = "Modules", modules = true,
            intro = "Turn Medalluin's parts on or off. Some take effect after a reload; the footer says when.",
            groups = {},
        },
        {
            id = "general", name = "General", intro = "Shared by every profile.",
            groups = {
                Group("Preview",
                    Check("simParty", "Simulate party frames",
                        "Show the console's party frame layer and simulated party members to preview "
                        .. "party frames while solo. The group boxes show too. A small panel on the left sets "
                        .. "what they show, a tab each for the party, the raid, the enemies and the "
                        .. "overhead frames: members and their health, deaths, range, pets, auras, "
                        .. "ready and role checks."),
                    Check("simCdm", "Simulate cooldowns",
                        "Show each Cooldown Manager viewer's icons as its options (Cooldowns) draw them, "
                        .. "without a fight: your own spells or a random full set, cooling down, with charges "
                        .. "and stacks, buffs coming and going. A small panel on the right sets what they show.")),
                Group("Editor",
                    Editor(nil, "Edit unit frames")),
                Group("Key bindings",
                    Button("Bind keys", function()
                        if ns.CloseOptions then ns.CloseOptions() end
                        ns.KeybindMode(true)
                    end, "Closes this window. Point at an action button and press a key to bind it; Esc "
                        .. "over a button removes its keys. Also /mdlui kb. The action bars' keys are kept "
                        .. "per profile.")),
                Group("Game menu",
                    Choice("gameMenu", "Game menu", {
                        { "docked", "Docked", "A panel down the left edge: who you are at its top, the game's "
                            .. "buttons in sections under it, Log Out and Exit Game, and Return to Game at its foot." },
                        -- the medallion menu, being built: off till it is done
                        { "medallion", "(WIP)", "The medallion menu, a ring around your character: still "
                            .. "being built, so it cannot be chosen yet.", wip = true },
                        { "game", "The game's", "The game's own menu, as it stands." },
                    }, "How the menu Escape opens looks. Its buttons stay the game's own.", true)),
            },
        },
        {
            id = "console", name = "Console",
            tabs = {
                {
                    id = "general", name = "General",
                    intro = "Each profile keeps its Console, console party, skills and keys.",
                    more = "That is everything under Console but the Overhead, the console's party under Unit "
                        .. "Frames, its skills on the bars and their keys. The overhead, the widgets, Chat, Side "
                        .. "panel and Bags are shared. What the frames show is under Unit Frames.",
                    groups = Concat(AllOn("general", {
                        Group("Profile",
                            Choice("consoleProfile", "Console profile", ns.PROFILE_NAMES,
                                "The console the pages under Console start from. Switching brings back the options, "
                                .. "skills and keys you chose on that profile. The skills go back on the bars by "
                                .. "the cursor, the game's only way to place one: you hear each picked up and "
                                .. "put down, and their icons flash on the cursor. Then it asks to reload the "
                                .. "interface, which builds the console (switched in combat, once combat ends)."),
                            Button("Reset profile", function() StaticPopup_Show("MEDALLUIN_RESET_PROFILE") end,
                                "This profile's options under Console but the Overhead, and its console party under "
                                .. "Unit Frames, back to its own. The overhead, the widgets, Chat, Side panel and Bags "
                                .. "are left as they are.")),
                        Group("Cast bars",
                            Check("xpCast", "Player casts on the experience bar",
                                "The experience bar under your portrait becomes your cast bar while you cast, and "
                                .. "goes back to experience when you stop."),
                            Check("repCast", "Target casts on the reputation bar",
                                "The reputation bar under your target becomes its cast bar while it casts, and goes "
                                .. "back to reputation when it stops or you change target.")),
                    }), AllOn("position", Placed("console", "Position",
                        "Or open Edit Mode: drag a console anywhere, and click it for its scale. Without Edit "
                        .. "Mode, /mdlui move. The corner strips keep their own size and place.")),
                    AllOn("visibility", Concat({
                        Tip("A faded console still works: its keys press, and its buttons click unless it is faded to "
                            .. "0% with On mouseover unticked. Binding keys, "
                            .. "a spell on the pointer, your casts, Edit Mode and Simulate party frames bring it back.",
                        Switched(Check("consoleFade", "Fade when idle",
                                    "Fade the console while none of what is ticked here is so."), "Visibility",
                                Opacity("consoleFadedAlpha", "Faded opacity",
                                    "How much of it shows while it is faded.", "consoleFade"),
                                { kind = "check", key = "consoleShowCombat", label = "In combat",
                                    tip = "While you are in combat.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowTarget", label = "With a target",
                                    tip = "While you have a target.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowHurt", label = "Health not full",
                                    tip = "While your health is below its most.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowGroup", label = "In a group",
                                    tip = "While you are in a party or a raid.", needs = "consoleFade" },
                                { kind = "check", key = "consoleShowMouse", label = "On mouseover",
                                    tip = "While the pointer is over the console, its bars or its party. "
                                        .. "Unticked, at 0% it takes no clicks or tooltips.",
                                    needs = "consoleFade" })),
                    }, ForConsole("reticule", Tip("Out of combat, the console fades away but for your player "
                            .. "and target frames. While it is on, it takes over from Fade when idle. The corner "
                            .. "strips and the corner minimap keep their own.",
                        Switched(Check("consoleMinimal", "Minimal OoC Mode",
                                "Out of combat, fade the console away but for your player and target frames. "
                                .. "Combat always brings it back."), "Minimal OoC Mode",
                            Opacity("consoleMinimalUnits", "Player and target opacity",
                                "How much of your player and target frames shows out of combat."),
                            Opacity("consoleMinimalRest", "Everything else",
                                "How much of the rest of the console, its bars and its party row shows out of "
                                .. "combat. The overhead keeps its own."),
                            Opacity("consoleMinimalRegen", "While regenerating",
                                "While your health, mana, energy or focus refills out of combat, the faded console "
                                .. "and your player and target frames show at least this much. 0%: as faded. "
                                .. "Combat and what brings it back below still make it whole."),
                            { kind = "check", key = "consoleMinimalTarget", label = "Back with a target",
                                tip = "Whole again while you have a target." },
                            { kind = "check", key = "consoleMinimalHurt", label = "Back when health is not full",
                                tip = "Whole again while your health is below its most." },
                            { kind = "check", key = "consoleMinimalGroup", label = "Back in a group",
                                tip = "Whole again while you are in a party or a raid." },
                            { kind = "check", key = "consoleMinimalMouse", label = "Back on mouseover",
                                tip = "Whole again while the pointer is over the console, its bars or its party. "
                                    .. "Unticked, what is at 0% takes no clicks or tooltips." }))),
                    { Group("Opacity",
                        Opacity("consoleAlpha", "Opacity", "How much of the console shows while it is not "
                            .. "faded. The corner strips and the corner minimap keep their own."),
                        Seconds("consoleFadeIn", "Fade in", "How long it takes to come back."),
                        Seconds("consoleFadeOut", "Fade out", "How long it takes to fade.")) }))),
                },
                {
                    -- where the console's parts sit: the console's own card,
                    -- then what both have
                    id = "layout", name = "Layout", intro = "Kept per profile. Where the console's parts sit.",
                    groups = Concat(
                        ForConsole("reticule", Group("Party frames", PartyLayout("reticule"))),
                        ForConsole("arena", Group("Party frames", PartyLayout("arena"))),
                        { Group("Boss frames (shared by every profile)",
                            Choice("bossFrames", "Boss frames", {
                                { "overhead", "Overhead", "On the overhead's top tier, dividing into 1, 2 or 3 "
                                    .. "columns." },
                                { "vertical", "Vertical", "A column under a Boss tab that you can drag anywhere: "
                                    .. "hold the tab to move it." },
                                { "both", "Both", "On the overhead and in the column." },
                            }, "Where the encounter's boss frames show. Raid and arena frames are boxes too: hold a "
                                .. "box's tab to move it. Simulate party frames shows them all.")) }),
                },
                {
                    id = "bar", name = "Action Bars", intro = "Kept per profile.",
                    master = Check("actionBar", "Action bar",
                        "Medalluin's bar on top of the console, holding action bar 1. Untick it to keep Blizzard's "
                        .. "bars or use another action-bar addon.", true),
                    groups = {
                        On("look", Group("Bar",
                            Choice("rows", "Rows", {
                                { 1, "1 row", "Action bar 1." },
                                { 2, "2 rows", "Action bar 2 stacked above action bar 1." },
                                { 3, "3 rows", "Action bars 2 and 3 stacked above action bar 1." },
                            }, "Stack Blizzard's bottom bars (action bars 2 and 3) above Medalluin's bar frame "
                                .. "instead of leaving them where Edit Mode puts them.", true),
                            Color("artColor", "Art colour", "Tints the bar's stone frame. White leaves it as drawn."),
                            Check("bareIcons", "Bare icons",
                                "Square icons with a thin black edge, the cooldown time on the icon and range as a "
                                .. "red tint, instead of Blizzard's button art.", true),
                            Check("hideEmpty", "Hide empty buttons",
                                "Hides empty buttons and their keybind text on extra bars (action bars 2 and 3)."))),
                        On("elements", Group("Long Resource Bar",
                            Choice("barLowRow", "Shows", LowRows(),
                                "What the row under the buttons shows. Your cast bar covers it while you cast."))),
                        On("elements", Group("Text",
                            Choice("hotkeySize", "Keybind text size", TextSizes({ 0, "Hidden", "No keybind text." }),
                                "The key bound to each button, at its top right."))),
                        On("elements", Group("Cooldowns",
                            Choice("cooldownText", "Cooldown numbers", {
                                { "auto", "Default", "Bare icons show them; Blizzard's art follows the game's "
                                    .. "Show cooldown numbers option (Options > Action Bars)." },
                                { "show", "Always", "On every button, bare icons or Blizzard's art." },
                                { "hide", "Never", "The sweep alone says how long is left." },
                            }, "The time left, on the icon. The global cooldown never shows one on bare icons."),
                            Choice("cooldownTextSize", "Cooldown number size", TextSizes(),
                                "The time left on a cooling-down button."),
                            Check("cooldownSwipe", "Sweep",
                                "The dark sweep that winds round a cooling-down icon."),
                            Check("cooldownEdge", "Sweep edge",
                                "A bright line along the sweep's leading edge."),
                            Check("cooldownBling", "Flash when ready",
                                "The flash a button gives as its cooldown ends."))),
                        On("visibility", Group("Fading",
                            Choice("visibility", "Bar 1 visibility", Visibility("it comes", "it"),
                                "A faded bar still works: its buttons and key bindings stay live."),
                            Choice("extraVisibility", "Extra bar(s) visibility", Visibility("they come", "them"),
                                "Manages the visibility of action bars 2 and 3. Faded bars still work: their buttons "
                                .. "and key bindings stay live."))),
                        On("elements", Group("Minimap buttons",
                            Choice("drawer", "Drawer opens", {
                                { ns.DRAWER.LEFT, "Open left", "One row, out to the left of the bar." },
                                { ns.DRAWER.UP, "Open up", "One column, up from the bar's left end." },
                            }, "The addons' minimap buttons gather in a drawer behind the box on the bar's left "
                                .. "end. This is the way it opens."))),
                    },
                },
                {
                    -- under Action Bars in the sidebar; greyed while the bar is off
                    id = "paging", name = "Paging", under = "bar", intro = "Kept per profile.",
                    groups = paging,
                },
                {
                    id = "overhead", name = "Overhead", intro = "Shared by every profile.",
                    master = Check("overhead", "Overhead console",
                        "Top-of-screen cascading trapezoid structure for boss frames, pet, focus, target of target, "
                        .. "and action bars.", true),
                    groups = Concat(AllOn("elements", {
                        Group("Frames",
                            Check("topPet", "Player pet frame", "Player pet unit frame on the middle tier."),
                            Check("topFocus", "Focus frame", "Focus target unit frame on the middle tier."),
                            Check("topToT", "Target of target frame",
                                "Target's target unit frame on the middle tier.")),
                        Group("Detached",
                            Check("detachPet", "Pet frame",
                                "Off the overhead, on its own, with the pet bar docked under it. Alt+drag a frame "
                                .. "off the overhead to detach it there, and back onto it to put it back."),
                            Check("detachFocus", "Focus frame",
                                "Off the overhead, on its own. Alt+drag it off the overhead, or back onto it."),
                            Check("detachToT", "Target of target frame",
                                "Off the overhead, on its own. Alt+drag it off the overhead, or back onto it.")),
                        Group("Bars",
                            Check("topPetBar", "Pet action bar", "Pet command and ability buttons on the bottom tier.",
                                true),
                            Check("topStances", "Stance bar",
                                "Shapeshift forms, stealth, stances, and auras on the bottom tier.", true),
                            Check("topTotems", "Totem bar",
                                "A shaman's totems on the bottom tier: each element's totem, and its choices "
                                .. "opening below it.", true),
                            Choice("overheadFlyoutTips", "Totem choices' tooltips", {
                                { "right", "Right", "Beside the totem hovered, on its right." },
                                { "left", "Left", "Beside the totem hovered, on its left." },
                            }, "Where a tooltip stands for the totems opening below the bar. The rest of the "
                                .. "overhead's stand under it, which would cover them.")),
                    }), AllOn("position", Placed("overhead", "Position")), AllOn("visibility", {
                        Group("Opacity",
                            Opacity("overheadAlpha", "Opacity", "How much of the overhead shows. It shows "
                                .. "whenever it holds a frame or a bar."),
                            Seconds("overheadFadeIn", "Fade in", "How long it takes to appear."),
                            Seconds("overheadFadeOut", "Fade out", "How long it takes to go once it is empty.")),
                        Group("Action-bar row",
                            Choice("overheadRowVis", "Visibility", Visibility("it comes", "it"),
                                "The stance, pet and totem bars and the tier they sit on. Faded, its keys still "
                                .. "press and its icons still click, unless In combat fades it to 0%. Whole while a "
                                .. "totem's choices are open."),
                            Opacity("overheadRowFaded", "Faded opacity", "How see-through it is when faded: 0% "
                                .. "is gone."),
                            Seconds("overheadRowFadeTime", "Fade time", "How long a fade in or out takes.")),
                    })),
                },
                {
                    id = "minimap", name = "Minimap",
                    intro = "Kept per profile. The Reticule's minimap: in the console's bay, or the corner.",
                    more = "It is in the screen's corner while the 2x5 grid takes the bay. Arena's stays "
                        .. "in its ring: of this page, only Area name is for it too.",
                    enabled = function() return ns.MinimapMoves and ns.MinimapMoves() end,
                    groups = Concat(AllOn("behaviour", {
                        Group("Switching",
                            { kind = "key", label = "Minimap key", command = "MEDALLUIN_MINIMAP",
                                tip = "Puts the minimap back where the game loads it (When the game loads), "
                                    .. "or, when it is there, in its other place, and keeps it there. Also under "
                                    .. "Options > Keybindings > AddOns." },
                            Choice("minimapStart", "When the game loads", {
                                { "auto", "As it moves", "Where Moving by itself puts it." },
                                { "console", "In the console" },
                                { "corner", "In the corner" },
                            }, "Where the minimap is after a login or a reload. It stays there until a ticked "
                                .. "trigger below starts or ends, or the minimap key is pressed. On "
                                .. "Arena the minimap stays in its ring.")),
                        Tip("A party row under the console always takes the corner: it needs the bay's foot.",
                        Switched(Check("minimapAuto", "Move automatically",
                                    "Into the corner on what is ticked here, and back into the console after."),
                                "Moving by itself",
                                { kind = "check", key = "minimapAutoCombat", label = "In combat",
                                    tip = "While you are in combat.", needs = "minimapAuto" },
                                { kind = "check", key = "minimapAutoTarget", label = "With a target",
                                    tip = "While you have a target.", needs = "minimapAuto" },
                                { kind = "check", key = "minimapAutoSkyriding", label = "While skyriding",
                                    tip = "While you skyride: the grid shows the skyriding skills.",
                                    needs = "minimapAuto" })),
                    }), AllOn("position", MinimapCorner()), AllOn("visibility", {
                        Group("Area name",
                            { kind = "slider", key = "minimapAreaTime", label = "Shown for", min = 0, max = 10,
                                step = 0.5, always = true,
                                tip = "The area's name shows at the top of the minimap while the pointer is over "
                                    .. "it. After this long it fades out; Always keeps it until the pointer leaves. "
                                    .. "In the corner the name is on the minimap's grip instead.",
                                text = function(v)
                                    if v < 0.25 then return "Always" end
                                    return string.format("%gs", v)
                                end }),
                    })),
                },
            },
        },
        {
            id = "cooldowns", name = "Cooldowns",
            tabs = { CooldownTab(ns.CDM_VIEWERS[1]), CooldownTab(ns.CDM_VIEWERS[2]), CooldownTab(ns.CDM_VIEWERS[3]),
                BarsTab(ns.CDM_BARS) },
        },
        {
            id = "units", name = "Unit Frames",
            tabs = {
                {
                    id = "general", name = "General",
                    intro = "Shared by every profile.",
                    groups = {
                        Group("Editor", Editor(nil, "Edit unit frames")),
                        Group("Dead and offline",
                            Color("deadColor", "Dead frame colour",
                                "A dead or offline friend's frame: the player's, the party's (console or widget) "
                                .. "and the raid's. It shows the status icon, time or disconnection, and their name.")),
                        Glows(),
                        Group("Blizzard's auras (shared by every profile)",
                            Check("blizzardAuras", "Blizzard's buff and debuff rows",
                                "Show Blizzard's own rows of buffs and debuffs at the top right of the screen. Off, "
                                .. "Medalluin's auras stand in for them: the column over the portrait and the side "
                                .. "panel's Auras tab.")),
                    },
                },
                {
                    -- a set of options for each party: the console's, or the
                    -- widget's; Editing (beside the tabs) picks which, and
                    -- opens on the one Party layout shows
                    id = "party", name = "Party",
                    intro = "Editing, at the tabs' right, picks the console's party frames or the widget's.",
                    more = "Party layout (Console > Layout) picks which of the two show. The console's are kept "
                        .. "per profile, and are on the player and target frames too; the widget's are shared by "
                        .. "every profile.",
                    variants = { { "console", "Console" }, { "widget", "Widget" } },
                    variantKey = "partyLayout",
                    sheetNames = { position = "Position & look" },
                    groups = {
                        On("position", Group("Editor", Editor(nil, "Edit unit frames"))),
                        On("position", Variant("widget", "Shared", Group("The widget",
                            Movers("partyWidgetMoverHover", "Party")))),
                        On("visibility", Variant("console", "Per profile", Group("Range",
                            Range("partyRange", "party")))),
                        On("visibility", Variant("widget", "Shared", Group("Range",
                            Range("partyWidgetRange", "party")))),
                        On("elements", Variant("console", "Per profile", Group("Frames", Pets("partyPets")))),
                        On("elements", Variant("widget", "Shared", Group("Frames",
                            Check("partyWidgetPlayer", "Include yourself",
                                "Show your own unit frame as the first row of the Party widget.")))),
                        On("auras", Variant("console", "Per profile", Group("Glows and icons",
                            Glow("auraGlow"), Threat("auraThreat"), CC("auraCC", "the")))),
                        On("auras", Variant("console", "Per profile", Group("Aura rows",
                            Buffs("auraBuffs"), Debuffs("auraDebuffs"), BossDebuffs("auraBoss")))),
                        On("auras", Variant("widget", "Shared", Group("Glows and icons",
                            Glow("partyWidgetGlow"), Threat("partyWidgetThreat"), CC("partyWidgetCC", "the")))),
                        On("auras", Variant("widget", "Shared", Group("Aura rows",
                            Buffs("partyWidgetBuffs"), Debuffs("partyWidgetDebuffs"),
                            BossDebuffs("partyWidgetBoss")))),
                    },
                },
                {
                    id = "raid", name = "Raid",
                    intro = "Shared by every profile. The Raid widget, out of battlegrounds; in one, the "
                        .. "Battleground tab's options take over.",
                    groups = {
                        Group("Raid", Range("raidRange", "raid"), Movers("raidMoverHover", "Raid")),
                        Group("Auras", Glow("raidGlow"), Threat("raidThreat"), CC("raidCC", "a member's"),
                            BossDebuffs("raidBoss"),
                            Debuffs("raidDebuffs", "in the health bar's bottom right corner")),
                        Group("Editor", Editor("raid")),
                    },
                },
                {
                    id = "battleground", name = "Battleground",
                    intro = "Shared by every profile. The Raid widget while you are in a battleground.",
                    groups = {
                        Group("Battleground", Range("bgRange", "battleground team"),
                            Movers("bgMoverHover", "Raid")),
                        Group("Auras", Glow("bgGlow"), Threat("bgThreat"), CC("bgCC", "a member's"),
                            Debuffs("bgDebuffs", "in the health bar's bottom right corner")),
                        Group("Editor", Editor("raid", "Edit the raid frames")),
                    },
                },
                {
                    id = "boss", name = "Boss",
                    intro = "Shared by every profile. Where the boss frames show is Console > Layout > Boss frames.",
                    groups = {
                        Group("Overhead", Mine("bossMine", "a boss")),
                        Group("Widget", Mine("bossWidgetMine", "a boss"),
                            Movers("bossMoverHover", "Boss")),
                        Group("Editor", Editor("boss", "Edit the Boss widget")),
                    },
                },
                {
                    id = "arena", name = "Arena",
                    intro = "Shared by every profile. The Arena widget's enemy frames.",
                    groups = {
                        Group("Arena", Movers("arenaMoverHover", "Arena")),
                        Group("Auras", CC("arenaCC", "an enemy's"), Mine("arenaMine", "an enemy")),
                        Group("Editor", Editor("arena")),
                    },
                },
            },
        },
        {
            id = "chat", name = "Chat", intro = "Shared by every profile.",
            master = Check("chat", "Chat box",
                "Blizzard's chat in a box on top of the micro menu, with the chat buttons beside its tabs, "
                .. "the timeless buffs and the edit box under it, and the quest tracker's full view above it. "
                .. "Untick it to keep the chat where Edit Mode puts it, or to use a chat addon.", true),
            groups = {
                Group("Names",
                    Check("chatClassColors", "Class colours",
                        "A speaker's name in their class's colour, whatever the game's own chat settings say."),
                    Check("chatLevels", "Levels",
                        "A speaker's level before their name, \"[60:Name]\", when it is known: from the game for "
                        .. "the line, else from your group, target, nameplates, guild, friends or a /who. It is "
                        .. "coloured by how it compares with yours, grey to red.")),
                Group("History",
                    Choice("chatHistory", "Lines kept", {
                        { 0, "Off", "Every session starts with empty chat windows." },
                        { 100, "100", "The last 100 lines of each window." },
                        { 250, "250", "The last 250 lines of each window." },
                        { 500, "500", "The last 500 lines of each window." },
                        { 1000, "1000", "The last 1000 lines of each window." },
                    }, "How many of each chat window's lines come back at your next login, dimmed under a "
                        .. "divider, and in the chat log. Kept for each character; not the combat log."),
                    Button("Clear saved history", function() if ns.chatLog then ns.chatLog.Clear() end end,
                        "Forget the saved lines, and this session's so far: the next login starts empty.")),
                Switched(Check("chatImmersion", "Bare when idle",
                        "Left alone, the chat drops its box, tabs and buttons, each message on a faint band of "
                        .. "its own over the world. The box comes back while you type, point at it or scroll up."),
                    "Immersion",
                    Check("chatBareCombat", "Box in combat", "Keep the whole box while you are in combat."),
                    { kind = "slider", key = "chatBareDelay", label = "Bare again after",
                        min = 0, max = 10, step = 0.5, tip = "How long the box stays once you are done with it.",
                        text = function(v) return v < 0.25 and "At once" or string.format("%.1fs", v) end },
                    Opacity("chatBands", "Band opacity", "How dark the band behind each message is.")),
            },
        },
        {
            id = "side", name = "Side panel", intro = "Shared by every profile.",
            -- the panel itself, then a card for each of its tabs; those grey
            -- while the panel is off, through their switches
            master = Check("side", "Side panel",
                "The chat panel's mirror on the right strip, over the stats, with a Zone tab, an Auras "
                .. "tab, a Meter tab and a Loot tab. Untick it to keep the right corner clear, or to use "
                .. "a meter addon.", true),
            groups = {
                Part("side/zone", "Zone tab", false,
                    Needs("side", Check("sideZone", "Zone tab",
                        "The minimap, moved into the panel while the tab is up, and the quests of the zone you "
                        .. "are in beside it. Its place on the console stands empty meanwhile.")),
                    nil),
                Part("side/auras", "Auras tab", false,
                    Needs("side", Check("sideAuras", "Auras tab",
                        "Your buffs and debuffs, each with the time it has left, the longest first.")),
                    {
                        Group("Lists",
                            Check("aurasTimeless", "Auras that never run out",
                                "List forms, aspects, mounts and the like too, at the top. They are over the portrait "
                                .. "already. The infinity button switches this too.")),
                    }),
                Part("side/meter", "Meter tab", false,
                    Needs("side", Check("sideMeter", "Meter tab",
                        "Damage, healing and more for each member of your group, from the game's own combat meter.")),
                    {
                        Group("Lists",
                            Choice("meterColumns", "Meter lists", {
                                { 1, "One", "One list across the panel." },
                                { 2, "Two", "Two lists side by side, each showing its own thing: damage and "
                                    .. "healing, say." },
                            }, "The column button with the bars on it switches this too."),
                            Choice("meterLeft", "First list shows", metrics,
                                "Clicking a list's heading steps through these too; a right click steps back."),
                            Choice("meterRight", "Second list shows", metrics, "Shown when the meter has two lists."),
                            Choice("meterSession", "Fight", {
                                { M.CURRENT, "Current", "The fight you are in, or the last one." },
                                { M.OVERALL, "Overall", "Every fight since the meter was last reset." },
                            }, "The clock button switches this too."),
                            Check("meterRate", "Per second",
                                "Damage and healing as amounts per second instead of totals. The /s button switches "
                                .. "this too.")),
                    }),
                Part("side/loot", "Loot tab", false,
                    Needs("side", Check("sideLoot", "Loot tab",
                        "What your group looted, boss by boss, with who won each roll. Not the chat's loot lines: "
                        .. "the chat keeps those.")),
                    {
                        Group("Lists",
                            Choice("lootWho", "Whose loot", {
                                { ns.LOOT_WHO.GROUP, "The group's", "Everything the group looted, yours included." },
                                { ns.LOOT_WHO.MINE, "Mine", "Only what you looted or won." },
                            }, "The funnel button switches this too."),
                            Choice("lootQuality", "Least quality", qualities,
                                "Items below this quality are left out. The diamond button steps through these too."),
                            Check("lootMoney", "Money and currencies",
                                "Your share of looted money on each heading, and the currencies you loot as lines.")),
                    }),
                Switched(Check("sideImmersion", "Faded when idle",
                        "Left alone, the panel's background fades to its faded opacity, whole again on what "
                            .. "is ticked here. Its text, buttons and tabs stay as they are."),
                    "Immersion",
                    Opacity("sideFadedAlpha", "Faded opacity",
                        "How much of the panel's background shows while it is faded."),
                    Check("sideShowCombat", "In combat", "Whole while you are in combat."),
                    Check("sideShowTarget", "With a target", "Whole while you have a target."),
                    Check("sideShowHurt", "Health not full", "Whole while your health is below its most."),
                    Check("sideShowGroup", "In a group", "Whole while you are in a party or a raid."),
                    Check("sideShowMouse", "On mouseover", "Whole while the pointer is over the panel."),
                    Seconds("sideFadeIn", "Fade in", "How long it takes to come back."),
                    Seconds("sideFadeOut", "Fade out", "How long it takes to fade.")),
            },
        },
        {
            id = "windows", name = "Windows",
            intro = "Shared by every profile. Blizzard's windows, reskinned.",
            groups = {
                Part("bags", "Bags", false,
                    Check("bags", "Bags window",
                        "Your backpack, bags and reagent bag in one window, with a search, the game's sort and the "
                        .. "items in groups if you like. Untick it to keep the game's bags, or to use a bag "
                        .. "addon.", true),
                    {
                        Group("Window",
                            Choice("bagsView", "Show", {
                                { "bags", "Bags", "Each bag on rows of its own, under its name." },
                                { "grid", "Grid", "Every slot, bag by bag, the reagent bag on rows of its own." },
                                { "groups", "Groups", "The items in groups: new, equipment, consumables, quest "
                                    .. "items, trade goods, other and junk, with one slot for the free ones." },
                            }, "The window's Bags, Grid and Groups buttons switch this too. Kept across reloads."),
                            Check("bagsItemLevel", "Item levels",
                                "The item level in the corner of each weapon and piece of armour, in its quality's "
                                .. "colour.")),
                    }),
                Part("bank", "Bank", true,
                    Check("bank", "Bank window",
                        "The bank in a window of Medalluin's own, standing on the chat panel or, detached, wherever "
                        .. "you drag it: the same views and search as the bags window, the game's sort, and the bank's "
                        .. "bag slots and their purchase below. Untick it to keep the game's bank.", true),
                    {
                        Group("Window",
                            Choice("bankView", "Show", {
                                { "bags", "Bags", "Each bank bag on rows of its own, under its name." },
                                { "grid", "Grid", "Every slot, bag by bag." },
                                { "groups", "Groups", "The items in groups: new, equipment, consumables, quest "
                                    .. "items, trade goods, other and junk, with one slot for the free ones." },
                            }, "The window's Bags, Grid and Groups buttons switch this too. Kept across reloads.")),
                    }),
                Part("character", "Character", false,
                    Check("character", "Character window",
                        "Your character, reputations and currencies (and on Forever your skills, PvP rank and "
                        .. "statistics) in one window standing on the chat panel, with the gear down both sides of "
                        .. "your model and the stats under it. Untick it to keep the game's window.", true),
                    nil),
                Part("spellbook", "Spellbook", true,
                    Check("spellbook", "Spellbook window",
                        "Your spells in one list, a section for General and each specialisation (and your pet's), its "
                        .. "ranks folded under each spell, in one window standing on the side panel. Cast and drag "
                        .. "them out of combat; in combat it reads. Untick it to keep the game's spellbook.", true),
                    {
                        Group("Spells",
                            Check("spellbookMissing", "Mark spells not on a bar",
                                "A red edge on a spell that is on none of your action bars, nor in a macro on one. Its "
                                .. "tooltip says so, or names the lower rank that is."),
                            Check("spellbookUpRankAll", "Keep every spell on its highest rank",
                                "As you learn a rank, a lower rank of it on your action bars is swapped for it, out of "
                                .. "combat. Unticked, only the spells whose details have it ticked."),
                            Check("spellbookClickCast", "Mark click-cast bindings",
                                "A spell bound in Click Casting (/cc) wears a small mouse on its icon, and its click "
                                .. "follows its rank (Racial · Shift+Middle). While Click Casting is open, the spells "
                                .. "it can bind glow, the rest grey out, and a click binds a spell instead of casting "
                                .. "it.")),
                    }),
                Part("talents", "Talents", true,
                    Check("talents", "Talents window",
                        "Your talents, a tab for each tree, in one window standing on the side panel. Spend points, "
                        .. "then Apply; switch between your Primary and Secondary talents in its margin. Plans, there, "
                        .. "draws and keeps the orders to learn them in. In combat it reads. Untick it to keep the "
                        .. "game's talents.", true),
                    nil),
                Part("professions", "Professions", true,
                    Check("professions", "Professions window",
                        "Your professions in one window standing on the side panel: an overview, and a tab for each "
                        .. "profession that crafts, with its recipes and Create. Crafting and the overview's spells "
                        .. "work out of combat. Untick it to keep the game's professions.", true),
                    nil),
                Part("questlog", "Quest log", false,
                    Check("questLog", "Quest log",
                        "Every quest in your log in a window on the right strip, as the spellbook's: by zone, each "
                        .. "with its level, experience, coin and whether it gives an item; a zone's eye tracks or "
                        .. "stops tracking all its quests, Drop abandons the quests you tick, and a quest opens its "
                        .. "own page. It opens on the quest log key and the Quests button, and the map no longer shows "
                        .. "the game's quest log. Untick it to keep the game's.", true),
                    nil),
                Part("lfg", "Group finder", false,
                    Check("lfgWindow", "Looking for group and Who",
                        "The groups listed, your own listing and Who in one box standing on the chat box, where the "
                        .. "quest tracker stands (it steps aside while the box is open): Browse shows each group's "
                        .. "activity, leader, note, the roles it needs, its size and age, and a click opens its "
                        .. "members with Whisper and Ask to join; List me lists you as the roles you pick, for the "
                        .. "activities you tick, with a note; Who asks who is online, with your zone, your level and "
                        .. "your guild a click away. It opens on the game's LFG button and key, and on the Friends "
                        .. "window's Who tab. Forever's group finder only: on retail the game's stays, and the box has "
                        .. "Who alone. Untick it to keep the game's.", true),
                    nil),
                Part("cdm", "Cooldown Manager", false,
                    Check("cdmWindow", "Cooldown Manager window",
                        "The game's Cooldown Manager (/cdm, Edit Mode's Cooldown Settings) in Medalluin's dress, "
                        .. "standing on the chat box where the LFG window stands: its tabs across the top, its spells "
                        .. "as round medallions. Everything in it is still the game's own: dragging spells between "
                        .. "Essential, Utility and Not displayed, their order, the alerts on a right-click, the "
                        .. "layouts per spec, import and export. It and the LFG window close each other. Untick it to "
                        .. "keep the game's look.",
                        true),
                    {
                        Group("Display", Check("cdmDisplay", "Cooldowns in Medalluin's dress",
                            "The game's cooldown and buff icons and its tracked bars in Medalluin's dress, each "
                            .. "viewer placed, laid out and shaped on its own: Essential, Utility, Tracked buffs and "
                            .. "Tracked bars, under Cooldowns. Edit Mode moving them is undone out of combat; their "
                            .. "movers move them. Untick it for the game's own in their Edit Mode places.",
                            true)),
                    }),
                Part("cc", "Click Casting", false,
                    Check("ccWindow", "Click Casting window",
                        "The game's Click Casting (/cc) in Medalluin's dress, standing on the chat box where the LFG "
                        .. "window stands, the spellbook open beside it: each binding a round icon with its click as "
                        .. "keycaps under its name. Everything in it is still the game's own: binding a spell or a "
                        .. "macro, mouseover cast and its key, reset and save. It, the Cooldown Manager and the LFG "
                        .. "window close each other. Untick it to keep the game's look.", true),
                    nil),
                Part("npc", "Gossip and vendors", false,
                    Needs("chat", Check("npcWindows", "Gossip, quest, vendor, trainer, flight and mailbox windows",
                        "What an NPC says, its quest pages, its wares and what it teaches in one box standing on the "
                        .. "chat box, where the quest tracker stands (it steps aside while the box is open). A "
                        .. "vendor's tabs show its wares and what you sold it, with buttons to repair and to sell your "
                        .. "grey items; a trainer's tabs show what you can learn now, what you cannot yet, or what you "
                        .. "know; the flight map stands there bare, with the places you can fly to under it (Forever's "
                        .. "map: retail's other one stays the game's); the mailbox's tabs show your letters, with Open "
                        .. "all, and a letter to send, the names you write to offered as you type. Needs the chat box. "
                        .. "Untick it to keep the game's windows, or to use an addon for them.", true)),
                    {
                        Group("Keys", Check("npcSpace", "Spacebar accepts quests",
                            "Space presses a quest's Accept, Continue or Complete Quest while its page is open, "
                            .. "instead of jumping. A gossip window's choices are numbered either way: the keys 1 to "
                            .. "0, - and = pick them, and the action bar buttons on those keys wait until it closes.")),
                        Group("Quests", Check("npcQuestItems", "Open quest items",
                            "When you get an item that begins a quest, the box opens on it: Read the quest (or Space, "
                            .. "with the Spacebar option) shows the quest, Later puts it away. Items you carry already "
                            .. "when you log in do not ask.")),
                    }),
            },
        },
        {
            id = "quests", name = "Quests", intro = "Shared by every profile.",
            master = Check("quests", "Quest tracker",
                "Your tracked quests on the left of the screen: by zone, each zone folding, with a button for a "
                .. "quest's item. Reads Questie's tracked quests when Questie is loaded; "
                .. "Questie's own tracker is left to Questie's options.", true),
            groups = {
                On("behaviour", Group("Tracker",
                    Choice("questsView", "View", {
                        { "full", "Full", "The character window's place, on the strip up to the screen's top, "
                            .. "fading to a tenth at the right, over the chat." },
                        { "minimal", "Minimal", "A box of its own: drag its heading, size it by its corner, "
                            .. "Ctrl-wheel over its heading to scale it." },
                    }, "How the tracker stands. Its own button changes it too."),
                    Choice("questsSort", "Sort", {
                        { "level", "Level", "The lowest quests first, and the zones by their lowest quest." },
                        { "zone", "Zone", "The zone you are in first, then the rest by name." },
                    }, "How the quests are ordered. The tracker's own button changes it too."),
                    Button("Reset the minimal view", function() ns.SetOption("questsPlace", false) end,
                        "The minimal view back to the top left, at its first size and scale."))),
                On("look", Group("Text",
                    Choice("questsTree", "Objectives", {
                        { false, "Bullets", "Each objective under its quest, bulleted, in the quest log's order." },
                        { true, "Tree", "On the branches of a tree, the finished ones risen to the top and "
                            .. "dimmed, what is left at the foot." },
                    }, "How a quest's objectives are drawn under it."),
                    FontChoice("questsTitleFont", "Title font", "The quests' titles. Fonts other addons share "
                        .. "(LibSharedMedia) are listed too."),
                    Points("questsTitleSize", "Title size", "The quests' titles, and their marks with them."),
                    FontChoice("questsObjectiveFont", "Objective font", "The objectives under each quest."),
                    Points("questsObjectiveSize", "Objective size", "The objectives under each quest. Every row "
                        .. "is as tall as the larger of the two sizes needs."))),
                On("visibility", Group("Full view", Check("questsFullMouseover", "Only on mouseover",
                        "Hidden until the pointer is over the tracker's column."),
                    Check("questsFullCombat", "Hidden in combat",
                        "Gone in combat, items too, and clicks go through to what is behind it."))),
                On("visibility", Group("Minimal view", Check("questsMinimalMouseover", "Only on mouseover",
                        "Hidden until the pointer is over the box."),
                    Check("questsMinimalCombat", "Hidden in combat",
                        "Gone in combat, items too, and clicks go through to what is behind it."))),
            },
        },
        {
            id = "tray", name = "Edge Draw", intro = "Shared by every profile.",
            master = Check("tray", "Edge Draw",
                "Touch the screen's left edge with the pointer, near its middle: a rail of tabs slides out, a "
                .. "tab for each window on the left. A click opens the window, or closes it when it is open (its "
                .. "tab lit gold). The rail goes a moment after the pointer leaves it; not while the game menu is "
                .. "open.", true),
            groups = {
                Group("Appearing",
                    Seconds("trayDelay", "Time to appear",
                        "How long the pointer rests at the edge before the rail comes out: a pass along the edge "
                        .. "on the way somewhere else does not bring it.")),
                Group("Tabs",
                    Check("trayCharacter", "Character", "The character window."),
                    Check("trayQuests", "Quest tracker",
                        "Hides or shows the quest tracker, until its tab shows it again; the chat box comes "
                        .. "down to the chat while it is hidden."),
                    Check("trayLFG", "Group finder", "The LFG / Who window, while its option is on."),
                    Check("trayChatLog", "Chat log", "The chat's log, while the chat panel is on."),
                    Check("trayCdm", "Cooldown Manager", "The game's Cooldown Manager, where the client has one."),
                    Check("trayCc", "Click Casting", "The game's Click Casting, where the client has it.")),
            },
        },
        {
            id = "tooltips", name = "Tooltips (ext)",
            intro = "Provided by the optional mdlui_Tooltips companion addon.",
            more = "Enable mdlui_Tooltips in your AddOns list to reskin tooltips and open its window.",
            enabled = function() return SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS ~= nil end,
            groups = {
                Group("mdlui_Tooltips",
                    Button("Open mdlui_Tooltips", function()
                        if SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_TOOLTIPS("")
                        end
                    end, "Closes this window and opens the mdlui_Tooltips window: each kind of tooltip's look, with a "
                        .. "live sample (/mdltip)."),
                    Button("Tooltip options", function()
                        if SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_TOOLTIPS("options")
                        end
                    end, "Closes this window and opens the mdlui_Tooltips window on its Options page "
                        .. "(/mdltip options).")),
            },
        },
        {
            id = "radial", name = "Radial menu (ext)",
            intro = "Provided by the optional mdlui_RadialMenu companion addon.",
            more = "Enable mdlui_RadialMenu in your AddOns list to build radial menus: hold a key, sweep the mouse "
                .. "towards a button and let go.",
            enabled = function() return SlashCmdList and SlashCmdList.MDLUI_RADIAL ~= nil end,
            groups = {
                Group("mdlui_RadialMenu",
                    Button("Open radial editor", function()
                        if SlashCmdList and SlashCmdList.MDLUI_RADIAL then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_RADIAL("")
                        end
                    end, "Closes this window and opens mdlui_RadialMenu's editor: its radials, their buttons "
                        .. "and keys (/mdlradial)."),
                    Button("Radial options", function()
                        if SlashCmdList and SlashCmdList.MDLUI_RADIAL then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_RADIAL("options")
                        end
                    end, "Closes this window and opens the editor's Options tab: how a radial opens, its size, "
                        .. "names and fonts (/mdlradial options).")),
            },
        },
    }
    table.insert(list, 2, Shared(list))
    for _, page in ipairs(list) do
        if page.tabs then
            for _, tab in ipairs(page.tabs) do Dress(tab, page.id .. "/" .. tab.id) end
        else
            Dress(page, page.id)
        end
    end
    AlsoOnShared(list)
    return list
end

-- The sidebar: its categories in order, each a heading over its items (a
-- page, or one of a page's tabs; a tab `under` another is indented below it). Only the shown page's category is open.
-- A category's scope or note sits by its heading on Modules; its glyph
-- (media/strips) by its heading in the sidebar.
function ns.OptionCategories()
    return {
        { name = "Overview", glyph = "menu", items = { "modules", "general" } },
        { name = "Shared", glyph = "channels", scope = "Every part's, in one place",
            items = { "shared/visibility", "shared/auras", "shared/look", "shared/tools" } },
        { name = "Console", glyph = "skills", scope = "Kept per profile",
            items = { "console/general", "console/layout", "console/bar", "console/paging", "console/minimap" } },
        -- shared by every profile, unlike the console (2026-11-15): its own
        -- heading, its one page opened by it (window.lua's Single)
        { name = "Overhead", glyph = "chevron-up", scope = "Shared by every profile", items = { "console/overhead" } },
        { name = "Cooldowns", glyph = "side-timeless", scope = "Kept per profile",
            items = { "cooldowns/essential", "cooldowns/utility", "cooldowns/buffs", "cooldowns/bars" } },
        { name = "Unit frames", glyph = "character",
            items = { "units/general", "units/party", "units/raid", "units/battleground", "units/boss",
                "units/arena" } },
        { name = "Interface", glyph = "view-full", scope = "Shared by every profile",
            items = { "chat", "side", "quests", "tray", "windows" } },
        { name = "Extensions", glyph = "misc", note = "Companion addons", items = { "tooltips", "radial" } },
    }
end
