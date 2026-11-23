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
local Tr = ns.L

ns.OPTION_SHEETS = {
    { "general", Tr["General"] },
    { "position", Tr["Position"] },
    { "look", Tr["Look"] },
    { "elements", Tr["Elements"] },
    { "visibility", Tr["Visibility"] },
    { "auras", Tr["Auras"] },
    { "behaviour", Tr["Behaviour"] },
    { "immersion", Tr["Immersion Mode"] },
    { "advanced", Tr["Advanced"] },
}

local RELOAD = Tr[" Takes effect after a reload."]

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
    return Button(label or Tr["Edit the frames"], function()
        ns.OpenEditor(type(id) == "function" and id() or id)
    end, Tr["The unit-frame editor: move, size, show or hide each piece of these frames, and choose what their "
        .. "texts say. Also /mdlui edit."])
end

-- A font for reading (ns.Fonts()): its choices asked as the list opens,
-- since other addons register theirs after us; each drawn in itself. A
-- shared font chosen whose addon is gone stays listed, saying so (the text
-- is MedalUI's own meanwhile).
local function FontChoice(key, label, tip)
    local spec = { kind = "choice", key = key, label = label, tip = tip }
    function spec.list()
        local out, chosen, there = {}, ns.db and ns.db[key], false
        for _, f in ipairs(ns.Fonts()) do
            table.insert(out, { f[1], f[2], nil, f[3] })
            there = there or f[1] == chosen
        end
        local name = not there and type(chosen) == "string" and chosen:match("^lsm:(.+)$")
        if name then table.insert(out, { chosen, format(Tr["%s (not loaded)"], name), nil, ns.font }) end
        return out
    end
    spec.choices = spec.list()
    return spec
end
local function Points(key, label, tip)
    return { kind = "slider", key = key, label = label, min = 9, max = 20, step = 1, tip = tip,
        text = function(v) return string.format(Tr["%d pt"], v) end }
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
            if v < 0.025 then return Tr["At once"] end
            return string.format("%.2fs", v)
        end }
end

-- The lower row's choices: the swing timer only where the client has one
-- (bars/lowrow.lua)
local function LowRows()
    local out = {
        { "resource", Tr["Class resource"], Tr["Combo points, holy power, chi, soul shards, arcane charges, essence or "
            .. "runes; vigor while skyriding. Empty for a class without one."] },
    }
    if ns.SwingTimerAvailable and ns.SwingTimerAvailable() then
        table.insert(out, { "swing", Tr["Swing timer"], Tr["Fills until your next main-hand swing or ranged shot, the "
            .. "seconds left at its right."] })
    end
    table.insert(out, { "mana", Tr["Mana"], Tr["Your mana, the amount at its right. Empty for a class without mana."] })
    return out
end

-- A module's medallion (media/strips) and its line on Modules, by path; an
-- addon's page has a card without a switch.
local MODULES = {
    ["console/bar"] = { "skills", "MedalUI's bar on top of the console, holding action bar 1." },
    ["console/overhead"] = { "view-full",
        Tr["Boss, pet, focus and target frames, and bars, at the top of the screen."] },
    chat = { "chat", Tr["Blizzard's chat in a box over the micro menu."] },
    side = { "side-meter", Tr["Zone, auras, meter and loot tabs on the right strip."] },
    ["side/zone"] = { "side-zone", Tr["The minimap beside this zone's quests, in the side panel."] },
    ["side/auras"] = { "side-auras", Tr["Your buffs and debuffs, with the time each has left."] },
    ["side/meter"] = { "side-rate", Tr["Damage, healing and more for each member, from the game's meter."] },
    ["side/loot"] = { "side-loot", Tr["What your group looted, boss by boss, with who won each roll."] },
    quests = { "quests", Tr["Your tracked quests on the left of the screen, by zone."] },
    tray = { "misc", Tr["A rail on the left edge: a tab to open and close each window there."] },
    bags = { "view-bags", Tr["One window for every bag, sorted and searchable."] },
    bank = { "currency", Tr["The bank in a window of its own, with the bags' views and search."] },
    character = { "character", Tr["Gear, stats, reputation and currency."] },
    inspect = { "character", Tr["A player's gear, item level, talents and guild, beside your own."] },
    spellbook = { "spellbook", Tr["Spells in role cards, macros and the trainer."] },
    talents = { "talents", Tr["A tab for each tree, with Apply and your plans, or Wowhead's."] },
    professions = { "profession", Tr["An overview, and a tab for each profession that crafts."] },
    questlog = { "questlog", Tr["Every quest in your log, by zone, on the right strip."] },
    lfg = { "lfg", Tr["The group finder and Who."] },
    cdm = { "side-timeless", Tr["The game's Cooldown Manager, its spells as medallions."] },
    cc = { "mouse", Tr["The game's Click Casting, each binding with its keycaps."] },
    npc = { "social", Tr["Gossip, quests, vendors, trainers, flights and mail."] },
    tooltips = { "help", Tr["Tooltips reskinned, with a live sample of each kind."], addon = true },
    radial = { "radial", Tr["Hold a key, sweep, release: radial menus of spells, items and markers."], addon = true },
}
-- (translated: a translation of an intro begins with them as translated)
local FOREVER = Tr["Forever only."]
local SCOPES = { Tr["Shared by every profile."], Tr["Kept per profile."] }

-- A page's or tab's extras for the window: Forever only, and the scope its
-- intro opened with (said once, in its header), off the intro; its
-- medallion and line.
local function Dress(content, path)
    local intro = content.intro
    if intro then
        if intro:sub(1, #FOREVER + 1) == FOREVER .. " " then
            content.forever = true
            intro = intro:sub(#FOREVER + 2)
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
            if g.forever then tip = tip and (FOREVER .. " " .. tip) or FOREVER end
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
-- (the setup wizard, options/setup.lua, says the same of the two)
function ns.PartyLayoutText(id)
    return {
        { "console", Tr["Console"], id == "reticule"
            and (Tr["A row of four frames under the Reticule, each member's pet hanging under its frame. While you "
                .. "are in a group the minimap stays in the top right corner and the centre grid stays out."])
            or Tr["The medallion's party wings, each member's pet hanging under its frame."] },
        { "widget", Tr["Widget"],
            Tr["A box of party frames, under a Party tab, that you can drag anywhere: hold the tab "
            .. "to move it. In a raid it gives way to the raid frames."] },
    }
end
local function PartyLayout(id)
    return Choice("partyLayout", Tr["Party layout"], ns.PartyLayoutText(id), Tr["Where the party frames sit."])
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
local function Visibility(many)
    local V = ns.VISIBILITY
    return {
        { V.ALWAYS, Tr["Always"] },
        { V.COMBAT, Tr["In combat"],
            many and Tr["Faded out of combat; they come back while you drag a spell onto them. "
            .. "Faded to 0%, no clicks or tooltips; keys still press."]
            or Tr["Faded out of combat; it comes back while you drag a spell onto it. "
            .. "Faded to 0%, no clicks or tooltips; keys still press."] },
        { V.MOUSEOVER, Tr["On mouseover"],
            many and Tr["Faded until the pointer is over them, or a spell is being dragged."]
            or Tr["Faded until the pointer is over it, or a spell is being dragged."] },
        { V.COMBAT_OR_MOUSEOVER, Tr["In combat or on mouseover"] },
    }
end

-- A text size, as a scale of what the button draws on its own; first, a
-- choice before them (Hidden).
local function TextSizes(first)
    local sizes = {
        { 0.8, Tr["Small"] },
        { 1, Tr["Normal"], Tr["As the button draws it."] },
        { 1.25, Tr["Large"] },
        { 1.5, Tr["Larger"] },
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
    return Check("simCdm", Tr["Simulate cooldowns"],
        Tr["Show every viewer's icons and bars as these options draw them, without a fight: your own spells or "
        .. "a random full set, cooling down, with charges and stacks, buffs coming and going. A small "
        .. "panel on the right sets what they show."])
end
local function CdmVisibility(K)
    local V = ns.VISIBILITY
    return On("visibility", Group(Tr["Visibility"],
        Choice(K("Vis"), Tr["Visibility"], {
            { V.ALWAYS, Tr["Always"] },
            { V.COMBAT, Tr["In combat"], Tr["Faded out of combat. Faded to 0%, no tooltips."] },
            { V.MOUSEOVER, Tr["On mouseover"], Tr["Faded until the pointer is over it."] },
            { V.COMBAT_OR_MOUSEOVER, Tr["In combat or on mouseover"] },
        }, Tr["Faded, it is only see-through: it still tracks everything (on In combat at 0%, without "
            .. "its tooltips). Whole while the Cooldown Manager or "
            .. "Edit Mode is open. Edit Mode's own Visibility (Cooldown Settings) still hides it outright. "
            .. "Shared > Immersion Mode's Minimal OoC Mode, while on, takes over from it."]),
        Opacity(K("Faded"), Tr["Faded opacity"], Tr["How see-through it is when faded: 0% is gone."]),
        Seconds(K("FadeTime"), Tr["Fade time"], Tr["How long a fade in or out takes."])))
end
-- its place: movers.lua's sliders, on Position after its layout
local function CdmPlace(groups, letter)
    for _, g in ipairs(ns.ConsolePlaceGroups(Group, { { "cdm" .. letter, Tr["Place"] } })) do
        g.tip = Tr["Drag it in Edit Mode, where it wears a blue mover, or set it here."]
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
    local px = function(n) return string.format(Tr["%d px"], n) end
    local function Positions(below)
        local out = {
            { "bottomright", Tr["Bottom right"] }, { "topright", Tr["Top right"] }, { "bottomleft", Tr["Bottom left"] },
            { "topleft", Tr["Top left"] }, { "center", Tr["Centre"] },
        }
        if below then table.insert(out, { "below", Tr["Below"], Tr["Under the icon, outside it."] }) end
        return out
    end
    -- its look: on the page's Layout and Icons groups, and on its mover's
    -- popup in Edit Mode (movers.lua, ns.CdmLookSpecs), the same specs
    local look = {
        Choice(K("Layout"), Tr["Layout"], {
            { "bar", Tr["Bar"], Tr["Rows of icons, across or down."] },
            { "arch", Tr["Arch"], Tr["One arc of icons, standing upright."] },
        }, Tr["How its icons stand."]),
        When("Layout", "bar", Choice(K("Orient"), Tr["Bar runs"], {
            { "across", Tr["Across"], Tr["Left to right; another row above."] },
            { "down", Tr["Down"], Tr["Top to bottom; another column to the right."] },
        }, Tr["A bar's direction."])),
        When("Layout", "bar", Slider(K("PerRow"), Tr["Icons per row"], 0, 20, 1,
            Tr["A row this long, then another. All in one row at 0."],
            function(n) return n == 0 and Tr["One row"] or tostring(n) end)),
        When("Layout", "arch", Slider(K("Span"), Tr["Arch span"], 60, 240, 5,
            Tr["How far round the arc reaches, end to end: wider is flatter for the same icons."],
            function(n) return string.format("%d°", n) end)),
        When("Layout", "arch", Choice(K("Opens"), Tr["Arch bends"], {
            { "up", Tr["Up"], Tr["Its middle highest, its ends lower: an arch."] },
            { "down", Tr["Down"], Tr["Its middle lowest, its ends higher: a bowl."] },
        }, Tr["Which way the arc curves."])),
        Choice(K("Shape"), Tr["Shape"], {
            { "round", Tr["Round medallion"], Tr["Round, in a gold rim, its sweep round."] },
            { "rounded", Tr["Rounded square"], Tr["A square with soft corners, in a gold rim."] },
            { "square", Tr["Square"], Tr["Square, in a gold rim."] },
            { "bare", Tr["Bare"], Tr["The icon alone, square, no rim."] },
        }, Tr["Each icon's shape; its sweep and out-of-range tint follow it."]),
        Slider(K("Size"), Tr["Size"], 16, 80, 1, Tr["Each icon's width."], px),
        Slider(K("Spacing"), Tr["Spacing"], 0, 30, 1, Tr["Between icons, and between rows."], px),
    }
    cdmLook[letter] = look
    local groups = {
        On("position", Group(Tr["Layout"],
            look[1], look[2], look[3], look[4], look[5],
            Choice(K("Order"), Tr["Fill order"], {
                { "middle", Tr["Middle out"], Tr["The first in the middle, then right of it, then left, outward."] },
                { "start", Tr["From the start"], Tr["The first at the left, or the top."] },
                { "finish", Tr["From the end"], Tr["The first at the right, or the bottom."] },
            }, Tr["The order is the Cooldown Manager's own, as you drag spells in it (/cdm): this is where its first "
                .. "stands."]),
            Check(K("Gaps"), Tr["Close gaps"],
                Tr["An icon that is hidden (a buff not up) leaves no hole: the others close ranks as it comes and "
                    .. "goes, "
                .. "in combat too. Off, each keeps its place."]))),
        On("look", Group(Tr["Icons"],
            look[6], look[7], look[8])),
        On("elements", Group(Tr["Text"],
            Choice(K("CdSize"), Tr["Cooldown number size"], TextSizes({ 0, Tr["Hidden"],
                Tr["The sweep alone says how long."] }),
                Tr["The time left on a cooling-down icon."]),
            Choice(K("CdPos"), Tr["Cooldown number at"], {
                { "center", Tr["Centre"] }, { "top", Tr["Top"] }, { "bottom", Tr["Bottom"] },
            }, Tr["Where the time left stands on the icon."]),
            Choice(K("CountSize"), Tr["Charges and stacks size"], TextSizes({ 0, Tr["Hidden"],
                Tr["No count on the icon."] }),
                Tr["A spell's charges, a buff's stacks."]),
            Choice(K("CountPos"), Tr["Charges and stacks at"], Positions(true), Tr["Where the count stands."]))),
        On("elements", Group(Tr["Cooldowns"],
            Check(K("Swipe"), Tr["Sweep"], Tr["The dark sweep that winds round a cooling-down icon."]),
            Check(K("Desat"), Tr["Grey while cooling down"],
                Tr["The game greys an icon while its spell cools down. Off, it keeps its colour."]),
            Check(K("Range"), Tr["Out-of-range tint"],
                Tr["A red tint over a spell whose target is out of its range."]),
            Check(K("Tips"), Tr["Tooltips"], Tr["The spell's tooltip with the pointer over its icon."]))),
        CdmVisibility(K),
    }
    CdmPlace(groups, letter)
    return {
        id = id, name = name, intro = Tr["Kept per profile."], aside = CdmSimulate(),
        enabled = function() return ns.db.cdmWindow and ns.db.cdmDisplay and true or false end,
        groups = groups,
    }
end

-- The tracked bars' tab: a bar each, so options of their own (settings.lua's
-- CDM_BAR_FIELDS, keyed cdmT<field>). Its look is on its mover's popup too.
local function BarsTab(v)
    local letter, id, name = v[1], v[2], v[3]
    local function K(field) return "cdm" .. letter .. field end
    local px = function(n) return string.format(Tr["%d px"], n) end
    local look = {
        Choice(K("Grow"), Tr["Grows"], {
            { "up", Tr["Up"], Tr["The first bar at the bottom, the next above it."] },
            { "down", Tr["Down"], Tr["The first bar at the top, the next below it."] },
        }, Tr["Which way the column runs from its first bar, which stays where it is."]),
        Slider(K("Width"), Tr["Width"], 80, 400, 5, Tr["Each bar's width, its icon included."], px),
        Slider(K("Size"), Tr["Height"], 12, 48, 1, Tr["Each bar's height; its icon is as tall."], px),
        Slider(K("Spacing"), Tr["Spacing"], 0, 20, 1, Tr["Between bars."], px),
        Choice(K("Icon"), Tr["Icon"], {
            { "left", Tr["On the left"] },
            { "right", Tr["On the right"] },
            { "none", Tr["None"], Tr["The bar alone, its full width."] },
        }, Tr["The spell's icon at one end of its bar."]),
        Choice(K("Shape"), Tr["Icon shape"], {
            { "round", Tr["Round medallion"], Tr["Round, in a gold rim."] },
            { "rounded", Tr["Rounded square"], Tr["A square with soft corners, in a gold rim."] },
            { "square", Tr["Square"], Tr["Square, in a gold rim."] },
            { "bare", Tr["Bare"], Tr["The icon alone, square, no rim."] },
        }, Tr["The icon's shape."]),
    }
    cdmLook[letter] = look
    local groups = {
        On("look", Group(Tr["Bars"],
            look[1], look[2], look[3], look[4],
            Check(K("Gaps"), Tr["Close gaps"],
                Tr["A bar whose buff is not up leaves no hole: the others close ranks as it comes and goes, in combat "
                .. "too. Off, each keeps its place."]))),
        On("look", Group(Tr["Icon"], look[5], look[6])),
        On("elements", Group(Tr["Text"],
            Choice(K("NameSize"), Tr["Name size"], TextSizes({ 0, Tr["Hidden"],
                Tr["The bar without its spell's name."] }),
                Tr["The spell's name, on its bar."]),
            Choice(K("TimeSize"), Tr["Time left size"], TextSizes({ 0, Tr["Hidden"],
                Tr["The bar alone says how long."] }),
                Tr["The time left, at the bar's end."]),
            Choice(K("CountSize"), Tr["Stacks size"], TextSizes({ 0, Tr["Hidden"], Tr["No count on the icon."] }),
                Tr["A buff's stacks, on its icon."]),
            Check(K("Tips"), Tr["Tooltips"], Tr["The spell's tooltip with the pointer over its bar."]))),
        CdmVisibility(K),
    }
    CdmPlace(groups, letter)
    return {
        id = id, name = name, intro = Tr["Kept per profile."], aside = CdmSimulate(),
        enabled = function() return ns.db.cdmWindow and ns.db.cdmDisplay and true or false end,
        groups = groups,
    }
end

-- How far a group's frames reach before they fade: who, the group's.
local RANGE_WORDS = {
    group = { Tr["Never fade group frames based on distance."],
        Tr["Fade group frames when members move beyond the chosen distance."] },
    party = { Tr["Never fade party frames based on distance."],
        Tr["Fade party frames when members move beyond the chosen distance."] },
    raid = { Tr["Never fade raid frames based on distance."],
        Tr["Fade raid frames when members move beyond the chosen distance."] },
    ["battleground team"] = { Tr["Never fade battleground team frames based on distance."],
        Tr["Fade battleground team frames when members move beyond the chosen distance."] },
}
local function Range(key, who)
    return Choice(key, Tr["Fade out of range"], {
        { 40, Tr["40 yards"], Tr["Standard spell and healing range."] },
        { 30, Tr["30 yards"], Tr["Mid-range distance."] },
        { 20, Tr["20 yards"], Tr["Short distance."] },
        { 10, Tr["10 yards"], Tr["Melee and interaction distance."] },
        { 0, Tr["Disabled"], RANGE_WORDS[who][1] },
    }, RANGE_WORDS[who][2])
end
-- a debuff's type (console/auras.lua's DISPEL_TYPES) as the options name it
local DISPEL_NAMES = { Magic = Tr["Magic"], Curse = Tr["Curse"], Poison = Tr["Poison"], Disease = Tr["Disease"],
    Bleed = Tr["Bleed"] }
local function Glow(key)
    return Check(key, Tr["Dispel glow on frame borders"],
        Tr["Glow the frame's border in the debuff's color (purple for Curse, green for Poison, etc.) when an ally has "
        .. "a debuff you can dispel. Which types, and their colours: Unit Frames > General > Highlights."])
end
local function Threat(key)
    return Check(key, Tr["Aggro glow on frame borders"],
        Tr["Glow the frame's border while that unit has aggro: something is attacking it. A dispel glow comes first. "
        .. "Its colour: Unit Frames > General > Highlights."])
end
-- The Highlights group (Unit Frames > General; "Glows" until 2026-11-21): the types the player
-- dispels, each one's on and colour, and the aggro glow's colour.
local function Glows()
    local items = {
        { kind = "note", text = function()
            local types, spells = ns.PlayerDispels()
            if not types[1] then return Tr["You dispel nothing: none of your spells removes a debuff."] end
            local names = {}
            for k, t in ipairs(types) do names[k] = DISPEL_NAMES[t] or t end
            return format(Tr["You dispel %s  (%s)."], table.concat(names, ", "), table.concat(spells, ", "))
        end },
        Choice("dispelStyle", Tr["Show a dispel as"], {
            { "glow", Tr["Border glow"], Tr["The frame's border glows in the debuff's colour."] },
            { "health", Tr["Health colour"], Tr["The health bar takes the debuff's colour instead of a glow."] },
        }, Tr["How a frame shows a debuff you can dispel: a glow round its border, or its health bar in the "
            .. "debuff's colour."]),
    }
    for _, t in ipairs(ns.DISPEL_TYPES) do
        local name = DISPEL_NAMES[t] or t
        local check = Check("dispel" .. t, name, format(Tr["Glow for a %s debuff. A type none of your spells "
            .. "dispels never glows."], name))
        check.can = function()
            for _, have in ipairs((ns.PlayerDispels())) do if have == t then return true end end
            return false
        end
        check.beside = Color("dispelColor" .. t, format(Tr["%s colour"], name),
            format(Tr["The glow's colour for a %s debuff."], name))
        check.beside.can = check.can
        table.insert(items, check)
    end
    table.insert(items, Color("threatColor", Tr["Aggro colour"], Tr["The aggro glow's colour."]))
    table.insert(items, Button(Tr["Reset colours"], function()
        for _, t in ipairs(ns.DISPEL_TYPES) do ns.SetOption("dispelColor" .. t, ns.OptionBase("dispelColor" .. t)) end
        ns.SetOption("threatColor", ns.OptionBase("threatColor"))
    end, Tr["Every glow's colour back to its first."]))
    return Group(Tr["Highlights"], unpack(items))
end
local CC_TIPS = {
    the = Tr["Display a large icon in the middle of the frame with a radial timer sweep when the unit is "
        .. "affected by CC."],
    ["a member's"] = Tr["Display a large icon in the middle of a member's frame with a radial timer sweep when the "
        .. "unit is affected by CC."],
    ["an enemy's"] = Tr["Display a large icon in the middle of an enemy's frame with a radial timer sweep when the "
        .. "unit is affected by CC."],
}
local function CC(key, whose)
    return Check(key, Tr["Crowd control center icon"], CC_TIPS[whose])
end
local function BossDebuffs(key)
    return Check(key, Tr["Boss debuffs"],
        Tr["Show a critical boss debuff in the middle of the frame, where crowd control would be; crowd control "
        .. "comes first."])
end
local function Pets(key)
    return Check(key, Tr["Show party pets"],
        Tr["Show pet unit frames directly below party members who have active pets."])
end
local function Buffs(key)
    return Check(key, Tr["Buffs"],
        Tr["Show a compact row of buffs on the outer corner of the health bar: your own (buffs and HoTs), or every "
        .. "one with From in the editor."])
end
-- where: in the bottom right corner (else the inner corner)
local function Debuffs(key, where)
    return Check(key, Tr["Debuffs"],
        where and Tr["Show a compact row of debuffs in the health bar's bottom right corner: every one, or only "
            .. "yours with From in the editor."]
        or Tr["Show a compact row of debuffs on the inner corner of the health bar: every one, or only yours with "
            .. "From in the editor."])
end
-- The corner minimap's place and size, and its grip's showing.
local function MinimapCorner()
    local groups = Placed("minimap", Tr["In the corner"])
    table.insert(groups[1].items, Check("minimapMoverHover", Tr["Movers only on mouseover"],
        Tr["Hide the corner minimap's tab, the grip with the area's name that moves it, until the pointer is over "
        .. "the minimap."]))
    return groups
end
local MOVER_TIPS = {
    Party = Tr["Hide the Party widget's tab, the grip that moves it, until the pointer is over the widget."],
    Raid = Tr["Hide the Raid widget's tab, the grip that moves it, until the pointer is over the widget."],
    Boss = Tr["Hide the Boss widget's tab, the grip that moves it, until the pointer is over the widget."],
    Arena = Tr["Hide the Arena widget's tab, the grip that moves it, until the pointer is over the widget."],
}
local function Movers(key, what)
    return Check(key, Tr["Movers only on mouseover"],
        MOVER_TIPS[what])
end
local function Mine(key, who)
    return Check(key, Tr["Debuffs"],
        who == "a boss" and Tr["Up to three of your own debuffs on a boss, small icons in the health bar's top right "
            .. "corner. From in the editor shows every one instead."]
        or Tr["Up to three of your own debuffs on an enemy, small icons in the health bar's top right corner. "
            .. "From in the editor shows every one instead."])
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

local AURA_COLS = { { label = Tr["All"] }, { label = Tr["Console"] }, { label = Tr["Widget"] }, { label = Tr["Raid"] },
    { label = Tr["BG"] }, { label = Tr["Overhead"] }, { label = Tr["Boss"] }, { label = Tr["Arena"] } }
-- a row per piece: the shared key, then each frame set's (false: it has none)
local AURA_ROWS = {
    { label = Tr["Dispel glow"], tip = Tr["The frame's border in the debuff's colour while an ally has one you can "
        .. "dispel."], keys = { "sharedGlow", "auraGlow", "partyWidgetGlow", "raidGlow", "bgGlow", false, false,
        false } },
    { label = Tr["Aggro glow"], tip = Tr["The frame's border while that unit has aggro."],
        keys = { "sharedThreat", "auraThreat", "partyWidgetThreat", "raidThreat", "bgThreat", false, false, false } },
    { label = Tr["Crowd control"], tip = Tr["A large icon in the middle of the frame while the unit is crowd "
        .. "controlled."], keys = { "sharedCC", "auraCC", "partyWidgetCC", "raidCC", "bgCC", false, false,
        "arenaCC" } },
    { label = Tr["Buffs"], tip = Tr["A row of buffs on the frame."],
        keys = { "sharedBuffs", "auraBuffs", "partyWidgetBuffs", false, false, false, false, false } },
    { label = Tr["Debuffs"], tip = Tr["A row of debuffs on the frame."],
        keys = { "sharedDebuffs", "auraDebuffs", "partyWidgetDebuffs", "raidDebuffs", "bgDebuffs", "bossMine",
            "bossWidgetMine", "arenaMine" } },
    { label = Tr["Boss debuffs"], tip = Tr["A critical boss debuff in the middle of the frame."],
        keys = { "sharedBoss", "auraBoss", "partyWidgetBoss", "raidBoss", false, false, false, false } },
}

-- Minimal OoC Mode for the whole Cooldown Manager (cooldowns/display.lua):
-- its switch heading its choices, as the console's
local function CdmMinimal()
    return Tip(Tr["Out of combat, every Cooldown Manager viewer fades away: cooldowns, buffs and bars. Kept per "
            .. "profile."],
        Switched(Check("cdmMinimal", Tr["Minimal OoC Mode"],
                Tr["Out of combat, fade every Cooldown Manager viewer away. Combat always brings them back. While "
                .. "it is on, it takes over from each viewer's own Visibility (Cooldowns); each keeps its fade "
                .. "time."]), Tr["Cooldown Manager: Minimal OoC Mode"],
            Opacity("cdmMinimalAlpha", Tr["Opacity out of combat"],
                Tr["How much of the viewers shows out of combat. 0%: gone, and without tooltips unless mouseover "
                .. "brings them back."]),
            { kind = "check", key = "cdmMinimalTarget", label = Tr["Back with a target"],
                tip = Tr["Whole again while you have a target."] },
            { kind = "check", key = "cdmMinimalHurt", label = Tr["Back when health is not full"],
                tip = Tr["Whole again while your health is below its most."] },
            { kind = "check", key = "cdmMinimalGroup", label = Tr["Back in a group"],
                tip = Tr["Whole again while you are in a party or a raid."] },
            { kind = "check", key = "cdmMinimalMouse", label = Tr["Back on mouseover"],
                tip = Tr["Whole again while the pointer is over a viewer."] }))
end

-- the party and raid boxes' Minimal OoC Mode (widgets/box.lua)
local function GroupMinimal()
    return Tip(Tr["Out of combat, the party and raid boxes fade away. Kept per profile."],
        Switched(Check("groupMinimal", Tr["Minimal OoC Mode"],
                Tr["Out of combat, fade the Party widget and the Raid widget (a battleground's too) away. Combat "
                .. "always brings them back. The console's party frames follow the console instead."]),
            Tr["Group frames: Minimal OoC Mode"],
            Opacity("groupMinimalAlpha", Tr["Opacity out of combat"],
                Tr["How much of the boxes shows out of combat. 0%: gone, and out of the pointer's way unless "
                .. "mouseover brings them back."]),
            { kind = "check", key = "groupMinimalHurt", label = Tr["Back when someone is hurt"],
                tip = Tr["Whole again while anyone in your group, you too, is below full health. The dead and "
                .. "offline don't count."] },
            { kind = "check", key = "groupMinimalMouse", label = Tr["Back on mouseover"],
                tip = Tr["Whole again while the pointer is over a box or its tab."] }))
end

local SHARED_NOTE = Tr["A frame's own choice, on its page, wins over a shared one there, and is marked Own."]

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
    local grid = Group(Tr["On the frames"], { kind = "grid", label = Tr["Auras"], cols = AURA_COLS, rows = AURA_ROWS })
    grid.wide = true
    grid.tip = Tr["All sets every frame that has not chosen its own; a gold corner marks one that has."]
    -- Tools: Overview > General's sections, the same ones
    local tools = {
        Mirror(Tr["Preview"], { "simParty", "simCdm" }),
        Group(Tr["Editor"], Editor(nil, Tr["Edit unit frames"])),
        Group(Tr["Key bindings"], Button(Tr["Bind keys"], function()
            if ns.CloseOptions then ns.CloseOptions() end
            ns.KeybindMode(true)
        end, Tr["Closes this window. Point at an action button and press a key to bind it; Esc over a button "
            .. "removes its keys. Also /mdlui kb."])),
        Mirror(Tr["Game menu"], { "gameMenu" }),
    }
    return {
        id = "shared", name = Tr["Shared"],
        tabs = {
            {
                id = "visibility", name = Tr["Visibility & fading"], intro = SHARED_NOTE,
                -- Immersion Mode: each profile's switch and its main choices;
                -- Advanced: every option, those the same ones (a key is one
                -- setting wherever it is shown)
                groups = Concat({
                    On("immersion", ns.consoleBuilt == "reticule"
                        and Mirror(Tr["Console: Minimal OoC Mode"], { "consoleMinimal", "consoleMinimalUnits",
                            "consoleMinimalRest", "consoleMinimalRegen", "consoleMinimalTarget", "consoleMinimalHurt",
                            "consoleMinimalGroup", "consoleMinimalMouse" },
                            Tr["Out of combat, the console fades away but for your player and target frames."])
                        or Tip(Tr["The Reticule's: choose it on Profiles to use it."],
                            Group(Tr["Console: Minimal OoC Mode"]))),
                    On("immersion", Mirror(Tr["Chat & side panel"], { "chatImmersion", "chatBareCombat",
                        "sideImmersion", "sideFadedAlpha", "sideShowCombat", "sideShowTarget", "sideShowMouse" },
                        Tr["The chat bare when idle, its box back on use; the side panel's background faded when "
                            .. "idle."])),
                    On("immersion", GroupMinimal()),
                    On("immersion", CdmMinimal()),
                }, AllOn("advanced", {
                    Group(Tr["Every frame"],
                        Check("moverHover", Tr["Movers only on mouseover"],
                            Tr["Hide each box's tab, the grip that moves it, and the corner minimap's, until the "
                            .. "pointer is over it."]),
                        Range("rangeFade", "group")),
                    Mirror(Tr["Console"], { "consoleFade", "consoleFadedAlpha", "consoleShowCombat",
                        "consoleShowTarget", "consoleShowHurt", "consoleShowGroup", "consoleShowMouse",
                        "consoleAlpha", "consoleFadeIn", "consoleFadeOut", "consoleMinimal", "consoleMinimalUnits",
                        "consoleMinimalRest", "consoleMinimalRegen", "consoleMinimalTarget", "consoleMinimalHurt",
                        "consoleMinimalGroup", "consoleMinimalMouse" }),
                    Mirror(Tr["Overhead"], { "overheadAlpha", "overheadFadeIn", "overheadFadeOut", "overheadRowVis",
                        "overheadRowFaded", "overheadRowFadeTime" }),
                    Mirror(Tr["Action bars"], { "visibility", "extraVisibility" }),
                    CdmMinimal(),
                    GroupMinimal(),
                    Mirror(Tr["Quest tracker, full view"], { "questsFullMouseover", "questsFullCombat" }),
                    Mirror(Tr["Quest tracker, minimal view"], { "questsMinimalMouseover", "questsMinimalCombat" }),
                    Mirror(Tr["Edge Draw"], { "trayDelay" }),
                    Mirror(Tr["Chat"], { "chatImmersion", "chatBareCombat", "chatBareDelay", "chatBands" }),
                    Mirror(Tr["Side panel"], { "sideImmersion", "sideFadedAlpha", "sideShowCombat", "sideShowTarget",
                        "sideShowHurt", "sideShowGroup", "sideShowMouse", "sideFadeIn", "sideFadeOut" }),
                })),
            },
            {
                id = "auras", name = Tr["Auras"], intro = SHARED_NOTE,
                groups = { grid, Glows(), Mirror(Tr["Blizzard's auras"], { "blizzardAuras" }) },
            },
            {
                id = "look", name = Tr["Colours & look"], intro = Tr["Each part's own, gathered here."],
                groups = {
                    Mirror(Tr["Unit frames"], { "deadColor" }),
                    Mirror(Tr["Action bars"], { "artColor", "hotkeySize", "cooldownTextSize" }),
                    Mirror(Tr["Quest tracker"], { "questsTitleFont", "questsTitleSize", "questsObjectiveFont",
                        "questsObjectiveSize" }),
                },
            },
            {
                id = "tools", name = Tr["Tools"], intro = Tr["Also on Overview > General."],
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
        content.also = format(Tr["Also on Shared > %s."], table.concat(names, ", "))
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
        local items = {
            Needs("actionBar", Choice(pb.key, Tr["Pages"], ns.PagingChoices(pb),
                Tr["Which action page the bar shows. A page is 12 slots: page n holds slots (n-1)x12+1 to nx12."])),
        }
        -- the grid's Forms, stealth, flying, a switch per condition, while it is picked
        if pb.grid then
            for _, p in ipairs(ns.GRID_PARTS or {}) do
                local check = Check(p.key, format(Tr["%s  \194\183  page %d"], p.name, p.page), p.note
                    .. " " .. Tr["Off: the grid stays on page 7 there."])
                check.line = p.note
                check.can = function() return ns.db[pb.key] == "default" end
                check.hide = true
                table.insert(items, Needs("actionBar", check))
            end
        end
        table.insert(items, Needs("actionBar", Button(Tr["Edit conditional"], function() ns.EditPaging(pb) end,
            Tr["A macro conditional naming the page, e.g. [mod:shift] 2; [stealth] 7; 1. \"possess\" is the "
            .. "bar the game puts up for a vehicle, an override or a possessed unit. Saving it picks Custom."])))
        table.insert(paging, {
            title = pb.label,
            tip = pb.grid and Tr["The Reticule's 2x5 grid in the centre bay."]
                or pb.base and format(Tr["Shown with Rows at %s or more."], pb.name:match("%d"))
                or Tr["Action bar 1, in the bar's frame."],
            items = items,
        })
    end

    local list = {
        {
            id = "modules", name = Tr["Modules"], modules = true,
            intro = Tr["Turn MedalUI's parts on or off. Some take effect after a reload; the footer says when."],
            groups = {},
        },
        {
            id = "general", name = Tr["General"], intro = Tr["Shared by every profile."],
            groups = {
                Group(Tr["Preview"],
                    Check("simParty", Tr["Simulate party frames"],
                        Tr["Show the console's party frame layer and simulated party members to preview "
                        .. "party frames while solo. The group boxes show too. A small panel on the left sets "
                        .. "what they show, a tab each for the party, the raid, the enemies and the "
                        .. "overhead frames: members and their health, deaths, range, pets, auras, "
                        .. "ready and role checks."]),
                    Check("simCdm", Tr["Simulate cooldowns"],
                        Tr["Show each Cooldown Manager viewer's icons as its options (Cooldowns) draw them, "
                        .. "without a fight: your own spells or a random full set, cooling down, with charges "
                        .. "and stacks, buffs coming and going. A small panel on the right sets what they show."]),
                    Check("simRolls", Tr["Simulate rolls"], Tr["Drop simulated items to roll on: the Roll window "
                        .. "pops up as for a real roll, its choices work, and a simulated group rolls too. A small "
                        .. "panel on the right sets what drops. Nothing is sent to the game."])),
                Group(Tr["Editor"],
                    Editor(nil, Tr["Edit unit frames"])),
                Group(Tr["Key bindings"],
                    Button(Tr["Bind keys"], function()
                        if ns.CloseOptions then ns.CloseOptions() end
                        ns.KeybindMode(true)
                    end, Tr["Closes this window. Point at an action button and press a key to bind it; Esc "
                        .. "over a button removes its keys. Also /mdlui kb. The action bars' keys are kept "
                        .. "per profile."])),
                Group(Tr["Game menu"],
                    Choice("gameMenu", Tr["Game menu"], {
                        { "docked", Tr["Docked"], Tr["A panel down the left edge: who you are at its top, the game's "
                            .. "buttons in sections under it, Log Out and Exit Game, and Return to Game at its "
                                .. "foot."] },
                        -- the medallion menu, being built: off till it is done
                        { "medallion", "(WIP)", Tr["The medallion menu, a ring around your character: still "
                            .. "being built, so it cannot be chosen yet."], wip = true },
                        { "game", Tr["The game's"], Tr["The game's own menu, as it stands."] },
                    }, Tr["How the menu Escape opens looks. Its buttons stay the game's own."], true)),
                -- (Latin clients only: Cyrillic has Forum alone, Korean and
                -- Chinese the game's own)
                ns.faceChoosable and Group(Tr["Font"],
                    Choice("medaluiFace", Tr["MedalUI's font"], {
                        { "marcellus", "Marcellus SC", Tr["Carved capitals throughout, the small letters as "
                            .. "smaller capitals."], ns.FACES.marcellus },
                        { "forum", "Forum", Tr["Carved capitals with lower-case letters: easier to read at "
                            .. "length."], ns.FACES.forum },
                    }, Tr["The face of every text MedalUI draws: windows, frames, bars and the quest "
                        .. "tracker, and the Tooltips and Radial menu companions where they use MedalUI's. "
                        .. "A text given a font of its own keeps it."], true)) or nil,
            },
        },
        {
            id = "console", name = Tr["Console"],
            tabs = {
                {
                    id = "general", name = Tr["General"],
                    intro = Tr["Each profile keeps its Console, console party, skills and keys."],
                    more = Tr["That is everything under Console but the Overhead, the console's party under Unit "
                        .. "Frames, its skills on the bars and their keys. The overhead, the widgets, Chat, Side "
                        .. "panel and Bags are shared. What the frames show is under Unit Frames."],
                    groups = Concat(AllOn("general", {
                        Group(Tr["Profile"],
                            Choice("consoleProfile", Tr["Console profile"], ns.PROFILE_NAMES,
                                Tr["The console the pages under Console start from. Switching brings back the options, "
                                .. "skills and keys you chose on that profile. The skills go back on the bars by "
                                .. "the cursor, the game's only way to place one: you hear each picked up and "
                                .. "put down, and their icons flash on the cursor. Then it asks to reload the "
                                .. "interface, which builds the console (switched in combat, once combat ends)."]),
                            Button(Tr["Reset profile"], function() StaticPopup_Show("MEDALUI_RESET_PROFILE") end,
                                Tr["This profile's options under Console but the Overhead, and its console party under "
                                .. "Unit Frames, back to its own. The overhead, the widgets, Chat, Side panel and Bags "
                                .. "are left as they are."]),
                            Button(Tr["Run setup again"], function()
                                if ns.CloseOptions then ns.CloseOptions() end
                                if ns.OpenSetup then ns.OpenSetup() end
                            end, Tr["Closes this window and opens the setup a new character starts with: the console, "
                                .. "Immersion Mode and where the party frames sit. Also /mdlui setup."])),
                        Group(Tr["Cast bars"],
                            Check("xpCast", Tr["Player casts on the experience bar"],
                                Tr["The experience bar under your portrait becomes your cast bar while you cast, and "
                                .. "goes back to experience when you stop."]),
                            Check("repCast", Tr["Target casts on the reputation bar"],
                                Tr["The reputation bar under your target becomes its cast bar while it casts, and goes "
                                .. "back to reputation when it stops or you change target."])),
                    }), AllOn("position", Placed("console", Tr["Position"],
                        Tr["Or open Edit Mode: drag a console anywhere, and click it for its scale. Without Edit "
                        .. "Mode, /mdlui move. The corner strips keep their own size and place."])),
                    AllOn("visibility", Concat({
                        Tip(Tr["A faded console still works: its keys press, and its buttons click unless it is "
                            .. "faded to "
                            .. "0% with On mouseover unticked. Binding keys, "
                            .. "a spell on the pointer, your casts, Edit Mode and Simulate party frames bring it "
                                .. "back."],
                        Switched(Check("consoleFade", Tr["Fade when idle"],
                                    Tr["Fade the console while none of what is ticked here is so."]), Tr["Visibility"],
                                Opacity("consoleFadedAlpha", Tr["Faded opacity"],
                                    Tr["How much of it shows while it is faded."], "consoleFade"),
                                { kind = "check", key = "consoleShowCombat", label = Tr["In combat"],
                                    tip = Tr["While you are in combat."], needs = "consoleFade" },
                                { kind = "check", key = "consoleShowTarget", label = Tr["With a target"],
                                    tip = Tr["While you have a target."], needs = "consoleFade" },
                                { kind = "check", key = "consoleShowHurt", label = Tr["Health not full"],
                                    tip = Tr["While your health is below its most."], needs = "consoleFade" },
                                { kind = "check", key = "consoleShowGroup", label = Tr["In a group"],
                                    tip = Tr["While you are in a party or a raid."], needs = "consoleFade" },
                                { kind = "check", key = "consoleShowMouse", label = Tr["On mouseover"],
                                    tip = Tr["While the pointer is over the console, its bars or its party. "
                                        .. "Unticked, at 0% it takes no clicks or tooltips."],
                                    needs = "consoleFade" })),
                    }, ForConsole("reticule", Tip(Tr["Out of combat, the console fades away but for your player "
                            .. "and target frames. While it is on, it takes over from Fade when idle. The corner "
                            .. "strips and the corner minimap keep their own."],
                        Switched(Check("consoleMinimal", Tr["Minimal OoC Mode"],
                                Tr["Out of combat, fade the console away but for your player and target frames. "
                                .. "Combat always brings it back."]), Tr["Minimal OoC Mode"],
                            Opacity("consoleMinimalUnits", Tr["Player and target opacity"],
                                Tr["How much of your player and target frames shows out of combat."]),
                            Opacity("consoleMinimalRest", Tr["Everything else"],
                                Tr["How much of the rest of the console, its bars and its party row shows out of "
                                .. "combat. The overhead keeps its own."]),
                            Opacity("consoleMinimalRegen", Tr["While regenerating"],
                                Tr["While your health, mana, energy or focus refills out of combat, the faded console "
                                .. "and your player and target frames show at least this much, hurt included. "
                                .. "0%: as faded. Combat and what brings it back below still make it whole, "
                                .. "but for health not full."]),
                            { kind = "check", key = "consoleMinimalTarget", label = Tr["Back with a target"],
                                tip = Tr["Whole again while you have a target."] },
                            { kind = "check", key = "consoleMinimalHurt", label = Tr["Back when health is not full"],
                                tip = Tr["Whole again while your health is below its most, unless While "
                                .. "regenerating is above 0%: then at that."] },
                            { kind = "check", key = "consoleMinimalGroup", label = Tr["Back in a group"],
                                tip = Tr["Whole again while you are in a party or a raid."] },
                            { kind = "check", key = "consoleMinimalMouse", label = Tr["Back on mouseover"],
                                tip = Tr["Whole again while the pointer is over the console, its bars or its party. "
                                    .. "Unticked, what is at 0% takes no clicks or tooltips."] }))),
                    { Group(Tr["Opacity"],
                        Opacity("consoleAlpha", Tr["Opacity"], Tr["How much of the console shows while it is not "
                            .. "faded. The corner strips and the corner minimap keep their own."]),
                        Seconds("consoleFadeIn", Tr["Fade in"], Tr["How long it takes to come back."]),
                        Seconds("consoleFadeOut", Tr["Fade out"], Tr["How long it takes to fade."])) }))),
                },
                {
                    -- where the console's parts sit: the console's own card,
                    -- then what both have
                    id = "layout", name = Tr["Layout"], intro = Tr["Kept per profile. Where the console's parts sit."],
                    groups = Concat(
                        ForConsole("reticule", Group(Tr["Party frames"], PartyLayout("reticule"))),
                        ForConsole("arena", Group(Tr["Party frames"], PartyLayout("arena"))),
                        { Group(Tr["Boss frames (shared by every profile)"],
                            Choice("bossFrames", Tr["Boss frames"], {
                                { "overhead", Tr["Overhead"], Tr["On the overhead's top tier, dividing into 1, 2 or 3 "
                                    .. "columns."] },
                                { "vertical", Tr["Vertical"],
                                    Tr["A column under a Boss tab that you can drag anywhere: "
                                    .. "hold the tab to move it."] },
                                { "both", Tr["Both"], Tr["On the overhead and in the column."] },
                            }, Tr["Where the encounter's boss frames show. Raid and arena frames are boxes too: hold a "
                                .. "box's tab to move it. Simulate party frames shows them all."])) }),
                },
                {
                    id = "bar", name = Tr["Action Bars"], intro = Tr["Kept per profile."],
                    master = Check("actionBar", Tr["Action bar"],
                        Tr["MedalUI's bar on top of the console, holding action bar 1. Untick it to keep Blizzard's "
                        .. "bars or use another action-bar addon."], true),
                    groups = {
                        On("look", Group(Tr["Bar"],
                            Choice("rows", Tr["Rows"], {
                                { 1, Tr["1 row"], Tr["Action bar 1."] },
                                { 2, Tr["2 rows"], Tr["Action bar 2 stacked above action bar 1."] },
                                { 3, Tr["3 rows"], Tr["Action bars 2 and 3 stacked above action bar 1."] },
                            }, Tr["Stack Blizzard's bottom bars (action bars 2 and 3) above MedalUI's bar frame "
                                .. "instead of leaving them where Edit Mode puts them."], true),
                            Color("artColor", Tr["Art colour"],
                                Tr["Tints the bar's stone frame. White leaves it as drawn."]),
                            Check("bareIcons", Tr["Bare icons"],
                                Tr["Square icons with a thin black edge, the cooldown time on the icon and range as a "
                                .. "red tint, instead of Blizzard's button art."], true),
                            Check("hideEmpty", Tr["Hide empty buttons"],
                                Tr["Hides empty buttons and their keybind text on extra bars (action bars 2 and "
                                    .. "3)."]))),
                        On("elements", Group(Tr["Long Resource Bar"],
                            Choice("barLowRow", Tr["Shows"], LowRows(),
                                Tr["What the row under the buttons shows. Your cast bar covers it while you cast."]))),
                        On("elements", Group(Tr["Text"],
                            Choice("hotkeySize", Tr["Keybind text size"], TextSizes({ 0, Tr["Hidden"],
                                Tr["No keybind text."] }),
                                Tr["The key bound to each button, at its top right."]))),
                        On("elements", Group(Tr["Cooldowns"],
                            Choice("cooldownText", Tr["Cooldown numbers"], {
                                { "auto", Tr["Default"], Tr["Bare icons show them; Blizzard's art follows the game's "
                                    .. "Show cooldown numbers option (Options > Action Bars)."] },
                                { "show", Tr["Always"], Tr["On every button, bare icons or Blizzard's art."] },
                                { "hide", Tr["Never"], Tr["The sweep alone says how long is left."] },
                            }, Tr["The time left, on the icon. The global cooldown never shows one on bare icons."]),
                            Choice("cooldownTextSize", Tr["Cooldown number size"], TextSizes(),
                                Tr["The time left on a cooling-down button."]),
                            Check("cooldownSwipe", Tr["Sweep"],
                                Tr["The dark sweep that winds round a cooling-down icon."]),
                            Check("cooldownEdge", Tr["Sweep edge"],
                                Tr["A bright line along the sweep's leading edge."]),
                            Check("cooldownBling", Tr["Flash when ready"],
                                Tr["The flash a button gives as its cooldown ends."]))),
                        On("visibility", Group(Tr["Fading"],
                            Choice("visibility", Tr["Bar 1 visibility"], Visibility(false),
                                Tr["A faded bar still works: its buttons and key bindings stay live."]),
                            Choice("extraVisibility", Tr["Extra bar(s) visibility"], Visibility(true),
                                Tr["Manages the visibility of action bars 2 and 3. Faded bars still work: their "
                                    .. "buttons "
                                .. "and key bindings stay live."]))),
                        On("elements", Group(Tr["Minimap buttons"],
                            Choice("drawer", Tr["Drawer opens"], {
                                { ns.DRAWER.LEFT, Tr["Open left"], Tr["One row, out to the left of the bar."] },
                                { ns.DRAWER.UP, Tr["Open up"], Tr["One column, up from the bar's left end."] },
                            }, Tr["The addons' minimap buttons gather in a drawer behind the box on the bar's left "
                                .. "end. This is the way it opens."]))),
                    },
                },
                {
                    -- under Action Bars in the sidebar; greyed while the bar is off
                    id = "paging", name = Tr["Paging"], under = "bar",
                    scope = Tr["Kept per profile & class"],
                    intro = Tr["Every character of a class shares it, separately for each profile."],
                    groups = paging,
                },
                {
                    id = "overhead", name = Tr["Overhead"], intro = Tr["Shared by every profile."],
                    master = Check("overhead", Tr["Overhead console"],
                        Tr["Top-of-screen cascading trapezoid structure for boss frames, pet, focus, target of target, "
                        .. "and action bars."], true),
                    groups = Concat(AllOn("elements", {
                        Group(Tr["Frames"],
                            Check("topPet", Tr["Player pet frame"], Tr["Player pet unit frame on the middle tier."]),
                            Check("topFocus", Tr["Focus frame"], Tr["Focus target unit frame on the middle tier."]),
                            Check("topToT", Tr["Target of target frame"],
                                Tr["Target's target unit frame on the middle tier."])),
                        Group(Tr["Detached"],
                            Check("detachPet", Tr["Pet frame"],
                                Tr["Off the overhead, on its own, with the pet bar docked under it. Alt+drag a frame "
                                .. "off the overhead to detach it there, and back onto it to put it back."]),
                            Check("detachFocus", Tr["Focus frame"],
                                Tr["Off the overhead, on its own. Alt+drag it off the overhead, or back onto it."]),
                            Check("detachToT", Tr["Target of target frame"],
                                Tr["Off the overhead, on its own. Alt+drag it off the overhead, or back onto it."])),
                        Group(Tr["Bars"],
                            Check("topPetBar", Tr["Pet action bar"],
                                Tr["Pet command and ability buttons on the bottom tier."],
                                true),
                            Check("topStances", Tr["Stance bar"],
                                Tr["Shapeshift forms, stealth, stances, and auras on the bottom tier."], true),
                            Check("topTotems", Tr["Totem bar"],
                                Tr["A shaman's totems on the bottom tier: each element's totem, and its choices "
                                .. "opening below it."], true),
                            Choice("overheadFlyoutTips", Tr["Totem choices' tooltips"], {
                                { "right", Tr["Right"], Tr["Beside the totem hovered, on its right."] },
                                { "left", Tr["Left"], Tr["Beside the totem hovered, on its left."] },
                            }, Tr["Where a tooltip stands for the totems opening below the bar. The rest of the "
                                .. "overhead's stand under it, which would cover them."])),
                    }), AllOn("position", Placed("overhead", Tr["Position"])), AllOn("visibility", {
                        Group(Tr["Opacity"],
                            Opacity("overheadAlpha", Tr["Opacity"], Tr["How much of the overhead shows. It shows "
                                .. "whenever it holds a frame or a bar."]),
                            Seconds("overheadFadeIn", Tr["Fade in"], Tr["How long it takes to appear."]),
                            Seconds("overheadFadeOut", Tr["Fade out"],
                                Tr["How long it takes to go once it is empty."])),
                        Group(Tr["Action-bar row"],
                            Choice("overheadRowVis", Tr["Visibility"], Visibility(false),
                                Tr["The stance, pet and totem bars and the tier they sit on. Faded, its keys still "
                                .. "press and its icons still click, unless In combat fades it to 0%. Whole while a "
                                .. "totem's choices are open."]),
                            Opacity("overheadRowFaded", Tr["Faded opacity"], Tr["How see-through it is when faded: 0% "
                                .. "is gone."]),
                            Seconds("overheadRowFadeTime", Tr["Fade time"], Tr["How long a fade in or out takes."])),
                    })),
                },
                {
                    id = "minimap", name = Tr["Minimap"],
                    intro = Tr["Kept per profile. The Reticule's minimap: in the console's bay, or the corner."],
                    more = Tr["It is in the screen's corner while the 2x5 grid takes the bay. Arena's stays "
                        .. "in its ring: of this page, only Area name is for it too."],
                    enabled = function() return ns.MinimapMoves and ns.MinimapMoves() end,
                    groups = Concat(AllOn("behaviour", {
                        Group(Tr["Switching"],
                            { kind = "key", label = Tr["Minimap key"], command = "MEDALUI_MINIMAP",
                                tip = Tr["Puts the minimap back where the game loads it (When the game loads), "
                                    .. "or, when it is there, in its other place, and keeps it there. Also under "
                                    .. "Options > Keybindings > AddOns."] },
                            Choice("minimapStart", Tr["When the game loads"], {
                                { "auto", Tr["As it moves"], Tr["Where Moving by itself puts it."] },
                                { "console", Tr["In the console"] },
                                { "corner", Tr["In the corner"] },
                            }, Tr["Where the minimap is after a login or a reload. It stays there until a ticked "
                                .. "trigger below starts or ends, or the minimap key is pressed. On "
                                .. "Arena the minimap stays in its ring."])),
                        Tip(Tr["A party row under the console always takes the corner: it needs the bay's foot."],
                        Switched(Check("minimapAuto", Tr["Move automatically"],
                                    Tr["Into the corner on what is ticked here, and back into the console after."]),
                                Tr["Moving by itself"],
                                { kind = "check", key = "minimapAutoCombat", label = Tr["In combat"],
                                    tip = Tr["While you are in combat."], needs = "minimapAuto" },
                                { kind = "check", key = "minimapAutoTarget", label = Tr["With a target"],
                                    tip = Tr["While you have a target."], needs = "minimapAuto" },
                                { kind = "check", key = "minimapAutoSkyriding", label = Tr["While skyriding"],
                                    tip = Tr["While you skyride: the grid shows the skyriding skills."],
                                    needs = "minimapAuto" })),
                    }), AllOn("position", MinimapCorner()), AllOn("visibility", {
                        Group(Tr["Area name"],
                            { kind = "slider", key = "minimapAreaTime", label = Tr["Shown for"], min = 0, max = 10,
                                step = 0.5, always = true,
                                tip = Tr["The area's name shows at the top of the minimap while the pointer is over "
                                    .. "it. After this long it fades out; Always keeps it until the pointer leaves. "
                                    .. "In the corner the name is on the minimap's grip instead."],
                                text = function(v)
                                    if v < 0.25 then return Tr["Always"] end
                                    return string.format("%gs", v)
                                end }),
                    })),
                },
            },
        },
        {
            id = "cooldowns", name = Tr["Cooldowns"],
            tabs = { CooldownTab(ns.CDM_VIEWERS[1]), CooldownTab(ns.CDM_VIEWERS[2]), CooldownTab(ns.CDM_VIEWERS[3]),
                BarsTab(ns.CDM_BARS) },
        },
        {
            id = "units", name = Tr["Unit Frames"],
            tabs = {
                {
                    id = "general", name = Tr["General"],
                    intro = Tr["Shared by every profile."],
                    groups = {
                        Group(Tr["Editor"], Editor(nil, Tr["Edit unit frames"])),
                        Group(Tr["Dead and offline"],
                            Color("deadColor", Tr["Dead frame colour"],
                                Tr["A dead or offline friend's frame: the player's, the party's (console or widget) "
                                .. "and the raid's. It shows the status icon, time or disconnection, and their "
                                    .. "name."])),
                        Glows(),
                        Group(Tr["Blizzard's auras (shared by every profile)"],
                            Check("blizzardAuras", Tr["Blizzard's buff and debuff rows"],
                                Tr["Show Blizzard's own rows of buffs and debuffs at the top right of the screen. Off, "
                                .. "MedalUI's auras stand in for them: the column over the portrait and the side "
                                .. "panel's Auras tab."])),
                    },
                },
                {
                    -- a set of options for each party: the console's, or the
                    -- widget's; Editing (beside the tabs) picks which, and
                    -- opens on the one Party layout shows
                    id = "party", name = Tr["Party"],
                    intro = Tr["Editing, at the tabs' right, picks the console's party frames or the widget's."],
                    more = Tr["Party layout (Console > Layout) picks which of the two show. The console's are kept "
                        .. "per profile, and are on the player and target frames too; the widget's are shared by "
                        .. "every profile."],
                    variants = { { "console", Tr["Console"] }, { "widget", Tr["Widget"] } },
                    variantKey = "partyLayout",
                    sheetNames = { position = Tr["Position & look"] },
                    groups = {
                        On("position", Group(Tr["Editor"], Editor(nil, Tr["Edit unit frames"]))),
                        On("position", Variant("widget", Tr["Shared"], Group(Tr["The widget"],
                            Movers("partyWidgetMoverHover", "Party")))),
                        On("visibility", Variant("console", Tr["Per profile"], Group(Tr["Range"],
                            Range("partyRange", "party")))),
                        On("visibility", Variant("widget", Tr["Shared"], Group(Tr["Range"],
                            Range("partyWidgetRange", "party")))),
                        On("visibility", Variant("widget", Tr["Per profile"], GroupMinimal())),
                        On("elements", Variant("console", Tr["Per profile"], Group(Tr["Frames"], Pets("partyPets")))),
                        On("elements", Variant("widget", Tr["Shared"], Group(Tr["Frames"],
                            Check("partyWidgetPlayer", Tr["Include yourself"],
                                Tr["Show your own unit frame as the first row of the Party widget."])))),
                        On("auras", Variant("console", Tr["Per profile"], Group(Tr["Glows and icons"],
                            Glow("auraGlow"), Threat("auraThreat"), CC("auraCC", "the")))),
                        On("auras", Variant("console", Tr["Per profile"], Group(Tr["Aura rows"],
                            Buffs("auraBuffs"), Debuffs("auraDebuffs"), BossDebuffs("auraBoss")))),
                        On("auras", Variant("widget", Tr["Shared"], Group(Tr["Glows and icons"],
                            Glow("partyWidgetGlow"), Threat("partyWidgetThreat"), CC("partyWidgetCC", "the")))),
                        On("auras", Variant("widget", Tr["Shared"], Group(Tr["Aura rows"],
                            Buffs("partyWidgetBuffs"), Debuffs("partyWidgetDebuffs"),
                            BossDebuffs("partyWidgetBoss")))),
                    },
                },
                {
                    id = "raid", name = Tr["Raid"],
                    intro = Tr["Shared by every profile. The Raid widget, out of battlegrounds; in one, the "
                        .. "Battleground tab's options take over."],
                    groups = {
                        Group(Tr["Raid"], Range("raidRange", "raid"), Movers("raidMoverHover", "Raid")),
                        GroupMinimal(),
                        Group(Tr["Auras"], Glow("raidGlow"), Threat("raidThreat"), CC("raidCC", "a member's"),
                            BossDebuffs("raidBoss"),
                            Debuffs("raidDebuffs", true)),
                        Group(Tr["Editor"], Editor("raid")),
                    },
                },
                {
                    id = "battleground", name = Tr["Battleground"],
                    intro = Tr["Shared by every profile. The Raid widget while you are in a battleground."],
                    groups = {
                        Group(Tr["Battleground"], Range("bgRange", "battleground team"),
                            Movers("bgMoverHover", "Raid")),
                        Group(Tr["Auras"], Glow("bgGlow"), Threat("bgThreat"), CC("bgCC", "a member's"),
                            Debuffs("bgDebuffs", true)),
                        Group(Tr["Editor"], Editor("raid", Tr["Edit the raid frames"])),
                    },
                },
                {
                    id = "boss", name = Tr["Boss"],
                    intro = Tr["Shared by every profile. Where the boss frames show is Console > Layout > Boss "
                        .. "frames."],
                    groups = {
                        Group(Tr["Overhead"], Mine("bossMine", "a boss")),
                        Group(Tr["Widget"], Mine("bossWidgetMine", "a boss"),
                            Movers("bossMoverHover", "Boss")),
                        Group(Tr["Editor"], Editor("boss", Tr["Edit the Boss widget"])),
                    },
                },
                {
                    id = "arena", name = Tr["Arena"],
                    intro = Tr["Shared by every profile. The Arena widget's enemy frames."],
                    groups = {
                        Group(Tr["Arena"], Movers("arenaMoverHover", "Arena")),
                        Group(Tr["Auras"], CC("arenaCC", "an enemy's"), Mine("arenaMine", "an enemy")),
                        Group(Tr["Editor"], Editor("arena")),
                    },
                },
            },
        },
        {
            id = "chat", name = Tr["Chat"], intro = Tr["Shared by every profile."],
            master = Check("chat", Tr["Chat box"],
                Tr["Blizzard's chat in a box on top of the micro menu, with the chat buttons beside its tabs, "
                .. "the timeless buffs and the edit box under it, and the quest tracker's full view above it. "
                .. "Untick it to keep the chat where Edit Mode puts it, or to use a chat addon."], true),
            groups = {
                Group(Tr["Names"],
                    Check("chatClassColors", Tr["Class colours"],
                        Tr["A speaker's name in their class's colour, whatever the game's own chat settings say."]),
                    Check("chatLevels", Tr["Levels"],
                        Tr["A speaker's level before their name, \"[60:Name]\", when it is known: from the game for "
                        .. "the line, else from your group, target, nameplates, guild, friends or a /who. It is "
                        .. "coloured by how it compares with yours, grey to red."])),
                Group(Tr["History"],
                    Choice("chatHistory", Tr["Lines kept"], {
                        { 0, Tr["Off"], Tr["Every session starts with empty chat windows."] },
                        { 100, "100", Tr["The last 100 lines of each window."] },
                        { 250, "250", Tr["The last 250 lines of each window."] },
                        { 500, "500", Tr["The last 500 lines of each window."] },
                        { 1000, "1000", Tr["The last 1000 lines of each window."] },
                    }, Tr["How many of each chat window's lines come back at your next login, dimmed under a "
                        .. "divider, and in the chat log. Kept for each character; not the combat log."]),
                    Button(Tr["Clear saved history"], function() if ns.chatLog then ns.chatLog.Clear() end end,
                        Tr["Forget the saved lines, and this session's so far: the next login starts empty."])),
                Switched(Check("chatImmersion", Tr["Bare when idle"],
                        Tr["Left alone, the chat drops its box, tabs and buttons, each message on a faint band of "
                        .. "its own over the world. The box comes back while you type, point at it or scroll up."]),
                    Tr["Immersion"],
                    Check("chatBareCombat", Tr["Box in combat"], Tr["Keep the whole box while you are in combat."]),
                    { kind = "slider", key = "chatBareDelay", label = Tr["Bare again after"],
                        min = 0, max = 10, step = 0.5, tip = Tr["How long the box stays once you are done with it."],
                        text = function(v) return v < 0.25 and Tr["At once"] or string.format("%.1fs", v) end },
                    Opacity("chatBands", Tr["Band opacity"], Tr["How dark the band behind each message is."])),
            },
        },
        {
            id = "side", name = Tr["Side panel"], intro = Tr["Shared by every profile."],
            -- the panel itself, then a card for each of its tabs; those grey
            -- while the panel is off, through their switches
            master = Check("side", Tr["Side panel"],
                Tr["The chat panel's mirror on the right strip, over the stats, with a Zone tab, an Auras "
                .. "tab, a Meter tab and a Loot tab. Untick it to keep the right corner clear, or to use "
                .. "a meter addon."], true),
            groups = {
                Part("side/zone", Tr["Zone tab"], false,
                    Needs("side", Check("sideZone", Tr["Zone tab"],
                        Tr["The minimap, moved into the panel while the tab is up, and the quests of the zone you "
                        .. "are in beside it. Its place on the console stands empty meanwhile."])),
                    {
                        Group(Tr["Quests"],
                            Choice("zoneSort", Tr["Sort"], {
                                { "log", Tr["Quest log"], Tr["As your quest log orders them."] },
                                { "distance", Tr["Distance"], Tr["The nearest quests first, by the game's objective "
                                    .. "markers on the map."] },
                                { "guide", Tr["Guide"], Tr["What to do next for experience: quests to take near you, "
                                    .. "then quick work, hand-ins and wide work, nearest first. Needs QuestieDB."] },
                            }, Tr["How the zone's quests are ordered; the waypoint's quest stays first. The tab's "
                                .. "own button changes it too."]),
                            Check("zoneGuideWaypoint", Tr["Guide sets the waypoint"],
                                Tr["While the Guide is shown, the waypoint follows the head of its list: a quest "
                                .. "to take points at its giver. A waypoint you set yourself is left alone until "
                                .. "you clear it."]),
                            Check("zoneGuidePicks", Tr["Guide lists quests to take"],
                                Tr["The Guide lists quests to take near you, not only your log's. The tab's "
                                .. "controls switch it too."]),
                            Check("zoneCoords", Tr["Coordinates"],
                                Tr["Where you stand, after the subzone over the list. The tab's controls switch "
                                .. "it too."]),
                            Slider("zoneFontSize", Tr["Text size"], 9, 14, 1,
                                Tr["The list's text, in points; its rows follow. The tab's controls step it too."])),
                    }),
                Part("side/auras", Tr["Auras tab"], false,
                    Needs("side", Check("sideAuras", Tr["Auras tab"],
                        Tr["Your buffs and debuffs, each with the time it has left, the longest first."])),
                    {
                        Group(Tr["Lists"],
                            Check("aurasTimeless", Tr["Auras that never run out"],
                                Tr["List forms, aspects, mounts and the like too, at the top. They are over the "
                                    .. "portrait "
                                .. "already. The infinity button switches this too."])),
                    }),
                Part("side/meter", Tr["Meter tab"], false,
                    Needs("side", Check("sideMeter", Tr["Meter tab"],
                        Tr["Damage, healing and more for each member of your group, from the game's own combat "
                            .. "meter."])),
                    {
                        Group(Tr["Lists"],
                            Choice("meterColumns", Tr["Meter lists"], {
                                { 1, Tr["One"], Tr["One list across the panel."] },
                                { 2, Tr["Two"], Tr["Two lists side by side, each showing its own thing: damage and "
                                    .. "healing, say."] },
                            }, Tr["The column button with the bars on it switches this too."]),
                            Choice("meterLeft", Tr["First list shows"], metrics,
                                Tr["Clicking a list's heading steps through these too; a right click steps back."]),
                            Choice("meterRight", Tr["Second list shows"], metrics,
                                Tr["Shown when the meter has two lists."]),
                            Choice("meterSession", Tr["Fight"], {
                                { M.CURRENT, Tr["Current"], Tr["The fight you are in, or the last one."] },
                                { M.OVERALL, Tr["Overall"], Tr["Every fight since the meter was last reset."] },
                            }, Tr["The clock button switches this too."]),
                            Check("meterRate", Tr["Per second"],
                                Tr["Damage and healing as amounts per second instead of totals. The /s button switches "
                                .. "this too."])),
                    }),
                Part("side/loot", Tr["Loot tab"], false,
                    Needs("side", Check("sideLoot", Tr["Loot tab"],
                        Tr["What your group looted, boss by boss, with who won each roll. Not the chat's loot lines: "
                        .. "the chat keeps those."])),
                    {
                        Group(Tr["Lists"],
                            Choice("lootWho", Tr["Whose loot"], {
                                { ns.LOOT_WHO.GROUP, Tr["The group's"],
                                    Tr["Everything the group looted, yours included."] },
                                { ns.LOOT_WHO.MINE, Tr["Mine"], Tr["Only what you looted or won."] },
                            }, Tr["The funnel button switches this too."]),
                            Choice("lootQuality", Tr["Least quality"], qualities,
                                Tr["Items below this quality are left out. The diamond button steps through these "
                                    .. "too."]),
                            Check("lootMoney", Tr["Money and currencies"],
                                Tr["Your share of looted money on each heading, and the currencies you loot as "
                                    .. "lines."])),
                        Group(Tr["Rolls"],
                            Check("rollFrame", Tr["Roll window"],
                                Tr["A small window of MedalUI's own pops up for each item to roll on: the item, "
                                    .. "its level against what you wear, need, greed or pass, and under it everyone's "
                                    .. "choice and roll on it. The die button shows and hides it. Untick it to keep "
                                    .. "the game's roll frames."]),
                            { kind = "slider", key = "rollsScale", label = Tr["Window scale"], min = 0.6, max = 1.6,
                                step = 0.05, tip = Tr["The Roll window's size, all of it."],
                                text = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end },
                            Choice("rollsTextSize", Tr["Text size"], {
                                { 1, Tr["Small"] }, { 1.15, Tr["Normal"] }, { 1.3, Tr["Large"] },
                                { 1.45, Tr["Larger"] } }, Tr["The Roll window's text, its box kept as it is."]),
                            Check("simRolls", Tr["Simulate rolls"], Tr["Drop simulated items to roll on: the Roll "
                                .. "window pops up as for a real roll, its choices work, and a simulated group rolls "
                                .. "too. A small panel on the right sets what drops. Nothing is sent to the game."])),
                    }),
                Switched(Check("sideImmersion", Tr["Faded when idle"],
                        Tr["Left alone, the panel's background fades to its faded opacity, whole again on what "
                            .. "is ticked here. Its text, buttons and tabs stay as they are."]),
                    Tr["Immersion"],
                    Opacity("sideFadedAlpha", Tr["Faded opacity"],
                        Tr["How much of the panel's background shows while it is faded."]),
                    Check("sideShowCombat", Tr["In combat"], Tr["Whole while you are in combat."]),
                    Check("sideShowTarget", Tr["With a target"], Tr["Whole while you have a target."]),
                    Check("sideShowHurt", Tr["Health not full"], Tr["Whole while your health is below its most."]),
                    Check("sideShowGroup", Tr["In a group"], Tr["Whole while you are in a party or a raid."]),
                    Check("sideShowMouse", Tr["On mouseover"], Tr["Whole while the pointer is over the panel."]),
                    Seconds("sideFadeIn", Tr["Fade in"], Tr["How long it takes to come back."]),
                    Seconds("sideFadeOut", Tr["Fade out"], Tr["How long it takes to fade."])),
            },
        },
        {
            id = "windows", name = Tr["Windows"],
            intro = Tr["Shared by every profile. Blizzard's windows, reskinned."],
            groups = {
                Part("bags", Tr["Bags"], false,
                    Check("bags", Tr["Bags window"],
                        Tr["Your backpack, bags and reagent bag in one window, with a search, the game's sort and the "
                        .. "items in groups if you like. Untick it to keep the game's bags, or to use a bag "
                        .. "addon."], true),
                    {
                        Group(Tr["Window"],
                            Choice("bagsView", Tr["Show"], {
                                { "bags", Tr["Bags"], Tr["Each bag on rows of its own, under its name."] },
                                { "grid", Tr["Grid"],
                                    Tr["Every slot, bag by bag, the reagent bag on rows of its own."] },
                                { "groups", Tr["Groups"], Tr["The items in groups: new, equipment, consumables, quest "
                                    .. "items, trade goods, other and junk, with one slot for the free ones."] },
                            }, Tr["The window's Bags, Grid and Groups buttons switch this too. Kept across reloads."]),
                            Check("bagsItemLevel", Tr["Item levels"],
                                Tr["The item level in the corner of each weapon and piece of armour, in its quality's "
                                .. "colour."])),
                    }),
                Part("bank", Tr["Bank"], true,
                    Check("bank", Tr["Bank window"],
                        Tr["The bank in a window of MedalUI's own, standing on the chat panel or, detached, wherever "
                        .. "you drag it: the same views and search as the bags window, the game's sort, and the bank's "
                        .. "bag slots and their purchase below. Untick it to keep the game's bank."], true),
                    {
                        Group(Tr["Window"],
                            Choice("bankView", Tr["Show"], {
                                { "bags", Tr["Bags"], Tr["Each bank bag on rows of its own, under its name."] },
                                { "grid", Tr["Grid"], Tr["Every slot, bag by bag."] },
                                { "groups", Tr["Groups"], Tr["The items in groups: new, equipment, consumables, quest "
                                    .. "items, trade goods, other and junk, with one slot for the free ones."] },
                            }, Tr["The window's Bags, Grid and Groups buttons switch this too. Kept across reloads."])),
                    }),
                Part("character", Tr["Character"], false,
                    Check("character", Tr["Character window"],
                        Tr["Your character, reputations and currencies (and on Forever your skills, PvP rank and "
                        .. "statistics) in one window standing on the chat panel, with the gear down both sides of "
                        .. "your model and the stats under it. Untick it to keep the game's window."], true),
                    nil),
                Part("inspect", Tr["Inspect"], false,
                    Check("inspect", Tr["Inspect window"],
                        Tr["The player you inspect in one window standing on the side panel, opposite your own "
                        .. "character window: their gear down both sides of their model, and under it their item "
                        .. "level, talents, PvP rank, guild and realm. Untick it to keep the game's window."], true),
                    nil),
                Part("spellbook", Tr["Spellbook"], true,
                    Check("spellbook", Tr["Spellbook window"],
                        Tr["Your spells in one list, a section for General and each specialisation (and your "
                            .. "pet's), its "
                        .. "ranks folded under each spell, in one window standing on the side panel. Cast and drag "
                        .. "them out of combat; in combat it reads. Untick it to keep the game's spellbook."], true),
                    {
                        Group(Tr["Spells"],
                            Check("spellbookMissing", Tr["Mark spells not on a bar"],
                                Tr["A red edge on a spell that is on none of your action bars, nor in a macro on "
                                    .. "one. Its "
                                .. "tooltip says so, or names the lower rank that is."]),
                            Choice("spellbookUpRank", Tr["Top rank"], {
                                { "all", Tr["Every spell"], Tr["Every spell on your bars rises to its highest rank."] },
                                { "marked", Tr["Only those marked"],
                                    Tr["Only the spells you mark: Shift+Right-click one in "
                                    .. "the spellbook."] },
                                { "none", Tr["None"], Tr["Your bars keep the ranks you put on them."] },
                            }, Tr["As you learn a rank, a lower rank of it on your action bars is swapped for it, out "
                                .. "of combat. Also the spellbook's Top rank button."]),
                            Check("spellbookClickCast", Tr["Mark click-cast bindings"],
                                Tr["A spell bound in Click Casting (/cc) wears a small mouse on its icon, and its "
                                    .. "click "
                                .. "follows its rank (Racial · Shift+Middle). While Click Casting is open, the spells "
                                .. "it can bind glow, the rest grey out, and a click binds a spell instead of casting "
                                .. "it."])),
                    }),
                Part("talents", Tr["Talents"], true,
                    Check("talents", Tr["Talents window"],
                        Tr["Your talents, a tab for each tree, in one window standing on the side panel. Spend points, "
                        .. "then Apply; switch between your Primary and Secondary talents in its margin. Plans, there, "
                        .. "draws and keeps the orders to learn them in, or brings one from Wowhead's talent "
                        .. "calculator. In combat it reads. Untick it to keep the game's talents."], true),
                    nil),
                Part("professions", Tr["Professions"], true,
                    Check("professions", Tr["Professions window"],
                        Tr["Your professions in one window standing on the side panel: an overview, and a tab for each "
                        .. "profession that crafts, with its recipes and Create. Crafting and the overview's spells "
                        .. "work out of combat. Untick it to keep the game's professions."], true),
                    {
                        Group(Tr["Overview"],
                            Choice("professionsArt", Tr["Overview art"], {
                                { "engraved", Tr["Engraved"], Tr["Gold etching on dark: calm behind the words."] },
                                { "painted", Tr["Painted"], Tr["Full colour, with painted light and haze."] },
                                { "poster", Tr["Poster"], Tr["A few flat tones for each scene, crisp."] },
                            }, Tr["The pictures behind the Overview's primary professions and its night sky."])),
                    }),
                Part("questlog", Tr["Quest log"], false,
                    Check("questLog", Tr["Quest log"],
                        Tr["Every quest in your log in a window on the right strip, as the spellbook's: by zone, each "
                        .. "with its level, experience, coin and whether it gives an item; a zone's eye tracks or "
                        .. "stops tracking all its quests, Drop abandons the quests you tick, and a quest opens its "
                        .. "own page. It opens on the quest log key and the Quests button, and the map no longer shows "
                        .. "the game's quest log. Untick it to keep the game's."], true),
                    nil),
                Part("lfg", Tr["Group finder"], false,
                    Check("lfgWindow", Tr["Looking for group and Who"],
                        Tr["The groups listed, your own listing and Who in one box standing on the chat box, where the "
                        .. "quest tracker stands (it steps aside while the box is open): Browse shows each group's "
                        .. "activity, leader, note, the roles it needs, its size and age, and a click opens its "
                        .. "members with Whisper and Ask to join; List me lists you as the roles you pick, for the "
                        .. "activities you tick, with a note; Who asks who is online, with your zone, your level and "
                        .. "your guild a click away. It opens on the game's LFG button and key, and on the Friends "
                        .. "window's Who tab. Forever's group finder only: on retail the game's stays, and the box has "
                        .. "Who alone. Untick it to keep the game's."], true),
                    nil),
                Part("cdm", Tr["Cooldown Manager"], false,
                    Check("cdmWindow", Tr["Cooldown Manager window"],
                        Tr["The game's Cooldown Manager (/cdm, Edit Mode's Cooldown Settings) in MedalUI's dress, "
                        .. "standing on the chat box where the LFG window stands: its tabs across the top, its spells "
                        .. "as round medallions. Everything in it is still the game's own: dragging spells between "
                        .. "Essential, Utility and Not displayed, their order, the alerts on a right-click, the "
                        .. "layouts per spec, import and export. It and the LFG window close each other. Untick it to "
                        .. "keep the game's look."],
                        true),
                    {
                        Group(Tr["Display"], Check("cdmDisplay", Tr["Cooldowns in MedalUI's dress"],
                            Tr["The game's cooldown and buff icons and its tracked bars in MedalUI's dress, each "
                            .. "viewer placed, laid out and shaped on its own: Essential, Utility, Tracked buffs and "
                            .. "Tracked bars, under Cooldowns. Edit Mode moving them is undone out of combat; their "
                            .. "movers move them. Untick it for the game's own in their Edit Mode places."],
                            true)),
                    }),
                Part("cc", Tr["Click Casting"], false,
                    Check("ccWindow", Tr["Click Casting window"],
                        Tr["The game's Click Casting (/cc) in MedalUI's dress, standing on the chat box where "
                            .. "the LFG "
                        .. "window stands, the spellbook open beside it: each binding a round icon with its click as "
                        .. "keycaps under its name. Everything in it is still the game's own: binding a spell or a "
                        .. "macro, mouseover cast and its key, reset and save. It, the Cooldown Manager and the LFG "
                        .. "window close each other. Untick it to keep the game's look."], true),
                    nil),
                Part("npc", Tr["Gossip and vendors"], false,
                    Needs("chat", Check("npcWindows", Tr["Gossip, quest, vendor, trainer, flight and mailbox windows"],
                        Tr["What an NPC says, its quest pages, its wares and what it teaches in one box standing "
                            .. "on the "
                        .. "chat box, where the quest tracker stands (it steps aside while the box is open). A "
                        .. "vendor's tabs show its wares and what you sold it, with buttons to repair and to sell your "
                        .. "grey items; a trainer's tabs show what you can learn now, what you cannot yet, or what you "
                        .. "know; the flight map stands there bare, with the places you can fly to under it (Forever's "
                        .. "map: retail's other one stays the game's); the mailbox's tabs show your letters, with Open "
                        .. "all, and a letter to send, the names you write to offered as you type. Needs the chat box. "
                        .. "Untick it to keep the game's windows, or to use an addon for them."], true)),
                    {
                        Group(Tr["Keys"], Check("npcSpace", Tr["Spacebar accepts quests"],
                            Tr["Space presses a quest's Accept, Continue or Complete Quest while its page is open, "
                            .. "instead of jumping. A gossip window's choices are numbered either way: the keys 1 to "
                            .. "0, - and = pick them, and the action bar buttons on those keys wait until it "
                                .. "closes."])),
                        Group(Tr["Quests"], Check("npcQuestItems", Tr["Open quest items"],
                            Tr["When you get an item that begins a quest, the box opens on it: Read the quest (or "
                                .. "Space, "
                            .. "with the Spacebar option) shows the quest, Later puts it away. Items you carry already "
                            .. "when you log in do not ask."])),
                    }),
            },
        },
        {
            id = "quests", name = Tr["Quests"], intro = Tr["Shared by every profile."],
            master = Check("quests", Tr["Quest tracker"],
                Tr["Your tracked quests on the left of the screen: by zone, each zone folding, with a button for a "
                .. "quest's item. Reads Questie's tracked quests when Questie is loaded; "
                .. "Questie's own tracker is left to Questie's options."], true),
            groups = {
                On("behaviour", Group(Tr["Tracker"],
                    Choice("questsView", Tr["View"], {
                        { "full", Tr["Full"], Tr["The character window's place, on the strip up to the screen's top, "
                            .. "fading to a tenth at the right, over the chat."] },
                        { "minimal", Tr["Minimal"], Tr["A box of its own: drag its heading, size it by its corner, "
                            .. "Ctrl-wheel over its heading to scale it."] },
                    }, Tr["How the tracker stands. Its own button changes it too."]),
                    Choice("questsSort", Tr["Sort"], {
                        { "level", Tr["Level"], Tr["The lowest quests first, and the zones by their lowest quest."] },
                        { "zone", Tr["Zone"], Tr["The zone you are in first, then the rest by name."] },
                        { "distance", Tr["Distance"], Tr["The nearest quests first, by the game's objective markers "
                            .. "on the map; the zones by their nearest quest."] },
                    }, Tr["How the quests are ordered. The tracker's own button changes it too."]),
                    Button(Tr["Reset the minimal view"], function() ns.SetOption("questsPlace", false) end,
                        Tr["The minimal view back to the top left, at its first size and scale."]))),
                On("look", Group(Tr["Text"],
                    Choice("questsTree", Tr["Objectives"], {
                        { false, Tr["Bullets"],
                            Tr["Each objective under its quest, bulleted, in the quest log's order."] },
                        { true, Tr["Tree"], Tr["On the branches of a tree, the finished ones risen to the top and "
                            .. "dimmed, what is left at the foot."] },
                    }, Tr["How a quest's objectives are drawn under it."]),
                    FontChoice("questsTitleFont", Tr["Title font"], Tr["The quests' titles. Fonts other addons share "
                        .. "(LibSharedMedia) are listed too."]),
                    Points("questsTitleSize", Tr["Title size"], Tr["The quests' titles, and their marks with them."]),
                    FontChoice("questsObjectiveFont", Tr["Objective font"], Tr["The objectives under each quest."]),
                    Points("questsObjectiveSize", Tr["Objective size"], Tr["The objectives under each quest. Every row "
                        .. "is as tall as the larger of the two sizes needs."]))),
                On("visibility", Group(Tr["Full view"], Check("questsFullMouseover", Tr["Only on mouseover"],
                        Tr["Hidden until the pointer is over the tracker's column."]),
                    Check("questsFullCombat", Tr["Hidden in combat"],
                        Tr["Gone in combat, items too, and clicks go through to what is behind it."]))),
                On("visibility", Group(Tr["Minimal view"], Check("questsMinimalMouseover", Tr["Only on mouseover"],
                        Tr["Hidden until the pointer is over the box."]),
                    Check("questsMinimalCombat", Tr["Hidden in combat"],
                        Tr["Gone in combat, items too, and clicks go through to what is behind it."]))),
                -- (not the tracker's: live while it is off; last, as it is
                -- left out where the game has no such marker)
                ns.waypoint.Navigation() and On("behaviour", Group(Tr["Navigation"],
                    (function()
                        local c = Check("questsNavigation", Tr["Marker in the world"],
                            Tr["The game's own marker at your tracked quest's objective, or your waypoint: a "
                            .. "diamond in the world with its distance. MedalUI turns it on at each login; "
                            .. "switched off here, it is turned off once."])
                        c.always = true
                        return c
                    end)())) or nil,
            },
        },
        {
            id = "tray", name = Tr["Edge Draw"], intro = Tr["Shared by every profile."],
            master = Check("tray", Tr["Edge Draw"],
                Tr["Touch the screen's left edge with the pointer, near its middle: a rail of tabs slides out, a "
                .. "tab for each window on the left. A click opens the window, or closes it when it is open (its "
                .. "tab lit gold). The rail goes a moment after the pointer leaves it; not while the game menu is "
                .. "open."], true),
            groups = {
                Group(Tr["Appearing"],
                    Seconds("trayDelay", Tr["Time to appear"],
                        Tr["How long the pointer rests at the edge before the rail comes out: a pass along the edge "
                        .. "on the way somewhere else does not bring it."])),
                Group(Tr["Tabs"],
                    Check("trayCharacter", Tr["Character"], Tr["The character window."]),
                    Check("trayQuests", Tr["Quest tracker"],
                        Tr["Hides or shows the quest tracker, until its tab shows it again; the chat box comes "
                        .. "down to the chat while it is hidden."]),
                    Check("trayLFG", Tr["Group finder"], Tr["The LFG / Who window, while its option is on."]),
                    Check("trayChatLog", Tr["Chat log"], Tr["The chat's log, while the chat panel is on."]),
                    Check("trayCdm", Tr["Cooldown Manager"],
                        Tr["The game's Cooldown Manager, where the client has one."]),
                    Check("trayCc", Tr["Click Casting"], Tr["The game's Click Casting, where the client has it."])),
            },
        },
        {
            id = "tooltips", name = Tr["Tooltips (ext)"],
            intro = Tr["Provided by the optional mdlui_Tooltips companion addon."],
            more = Tr["Enable mdlui_Tooltips in your AddOns list to reskin tooltips and open its window."],
            enabled = function() return SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS ~= nil end,
            groups = {
                Group("mdlui_Tooltips",
                    Button(Tr["Open mdlui_Tooltips"], function()
                        if SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_TOOLTIPS("")
                        end
                    end,
                        Tr["Closes this window and opens the mdlui_Tooltips window: each kind of tooltip's look, "
                            .. "with a "
                        .. "live sample (/mdltip)."]),
                    Button(Tr["Tooltip options"], function()
                        if SlashCmdList and SlashCmdList.MDLUI_TOOLTIPS then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_TOOLTIPS("options")
                        end
                    end, Tr["Closes this window and opens the mdlui_Tooltips window on its Options page "
                        .. "(/mdltip options)."])),
            },
        },
        {
            id = "radial", name = Tr["Radial menu (ext)"],
            intro = Tr["Provided by the optional mdlui_RadialMenu companion addon."],
            more = Tr["Enable mdlui_RadialMenu in your AddOns list to build radial menus: hold a key, sweep the mouse "
                .. "towards a button and let go."],
            enabled = function() return SlashCmdList and SlashCmdList.MDLUI_RADIAL ~= nil end,
            groups = {
                Group("mdlui_RadialMenu",
                    Button(Tr["Open radial editor"], function()
                        if SlashCmdList and SlashCmdList.MDLUI_RADIAL then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_RADIAL("")
                        end
                    end, Tr["Closes this window and opens mdlui_RadialMenu's editor: its radials, their buttons "
                        .. "and keys (/mdlradial)."]),
                    Button(Tr["Radial options"], function()
                        if SlashCmdList and SlashCmdList.MDLUI_RADIAL then
                            if ns.CloseOptions then ns.CloseOptions() end
                            SlashCmdList.MDLUI_RADIAL("options")
                        end
                    end, Tr["Closes this window and opens the editor's Options tab: how a radial opens, its size, "
                        .. "names and fonts (/mdlradial options)."])),
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
        { name = Tr["Overview"], glyph = "menu", items = { "modules", "general" } },
        { name = Tr["Shared"], glyph = "channels", scope = Tr["Every part's, in one place"],
            items = { "shared/visibility", "shared/auras", "shared/look", "shared/tools" } },
        { name = Tr["Console"], glyph = "skills", scope = Tr["Kept per profile"],
            items = { "console/general", "console/layout", "console/bar", "console/paging", "console/minimap" } },
        -- shared by every profile, unlike the console (2026-11-15): its own
        -- heading, its one page opened by it (window.lua's Single)
        { name = Tr["Overhead"], glyph = "chevron-up", scope = Tr["Shared by every profile"],
            items = { "console/overhead" } },
        { name = Tr["Cooldowns"], glyph = "side-timeless", scope = Tr["Kept per profile"],
            items = { "cooldowns/essential", "cooldowns/utility", "cooldowns/buffs", "cooldowns/bars" } },
        { name = Tr["Unit frames"], glyph = "character",
            items = { "units/general", "units/party", "units/raid", "units/battleground", "units/boss",
                "units/arena" } },
        { name = Tr["Interface"], glyph = "view-full", scope = Tr["Shared by every profile"],
            items = { "chat", "side", "quests", "tray", "windows" } },
        { name = Tr["Extensions"], glyph = "misc", note = Tr["Companion addons"], items = { "tooltips", "radial" } },
    }
end
