-- The addon's settings: saved per account in MedalluinDB, shown in
-- Medalluin's own window (options/), opened by /medalluin; the game's
-- Options > AddOns > Medalluin is a page about it with a way in. Every option starts from
-- the chosen console profile, and only the player's own choices are saved,
-- on top of it: the console's per profile, the rest shared (see PROFILES below).
--
-- Two kinds of option. The Action bar and Rows options move Blizzard's
-- secure buttons, which cannot be handed back mid-session, so they are read
-- once at login and a change waits for a reload, as do Bare icons and the
-- Chat and Side panels. The rest are drawing only (art colour, visibility, drawer,
-- the beam's cast bars) and apply at once: modules hear about a change through ns.OnSetting.
local addonName, ns = ...
local Tr = ns.L

local DEFAULTS = {
    actionBar = true,       -- the bar on the console, holding action bar 1
    rows = 1,               -- 2 and 3 stack action bars 2 and 3 above it
    bareIcons = false,      -- WeakAuras-style icons instead of Blizzard's button art
    artColor = "ffffffff",  -- AARRGGBB, as the colour swatch stores it; white leaves the art as drawn
    hideEmpty = true,       -- hide empty buttons on extra bars (action bars 2 and 3)
    -- the bar's lower row, under the cast bar (bars/lowrow.lua): "resource"
    -- (the class's), "swing" (the swing timer, Forever only) or "mana"
    barLowRow = "resource",
    -- the bar's buttons' text and cooldowns (bars/buttons.lua); a size is a
    -- scale of what the button draws on its own, so 1 leaves it as it was
    hotkeySize = 1,         -- keybind text; 0 hides it
    -- cooldown numbers: "auto" (bare icons show them, Blizzard's art asks the game), "show", "hide"
    cooldownText = "auto",
    cooldownTextSize = 1,   -- cooldown numbers
    cooldownSwipe = true,   -- the dark sweep over a cooling-down icon
    cooldownEdge = false,   -- the bright line on the sweep's edge
    cooldownBling = true,   -- the flash when a cooldown ends
    -- where each console sits and how big (movers.lua): a scale of the size it
    -- is drawn at, and an offset from where it is drawn, in the console's own
    -- units (a 1080-high screen), so a place survives a resolution change
    consoleScale = 1, consoleX = 0, consoleY = 0,
    overheadScale = 1, overheadX = 0, overheadY = 0,
    -- the Reticule's minimap (console/minimap.lua): whether it moves to
    -- the screen's corner by itself, and on what; and the corner's size and
    -- place, as the consoles' are (movers.lua)
    minimapAuto = true,
    minimapAutoCombat = true, minimapAutoTarget = true, minimapAutoSkyriding = true,
    minimapScale = 1, minimapX = 0, minimapY = 0,
    -- where it is when the game loads: "auto" (rule 3 decides), "console" or
    -- "corner", held until rule 3's answer changes or the key is pressed
    minimapStart = "auto",
    -- seconds the area shows over the hovered minimap before it fades; 0
    -- keeps it until the pointer leaves (console/minimap.lua)
    minimapAreaTime = 3,
    -- the corner minimap's grip only while the pointer is over it, as the
    -- widgets' movers (widgets/box.lua)
    minimapMoverHover = false,
    -- fading (console/fade.lua): the console fades while idle, which is what
    -- is ticked here not being so; its opacity shown and faded, and how long a
    -- fade takes each way, in seconds. The overhead shows whenever it holds
    -- anything, so it has only an opacity and its fade times.
    consoleFade = false,
    consoleShowCombat = true, consoleShowTarget = true, consoleShowHurt = true,
    consoleShowGroup = false, consoleShowMouse = true,
    consoleAlpha = 1, consoleFadedAlpha = 0, consoleFadeIn = 0.2, consoleFadeOut = 0.6,
    overheadAlpha = 1, overheadFadeIn = 0.2, overheadFadeOut = 0.2,
    -- the overhead's bottom row (stances, pet bar, totems) and its deck: as an
    -- action bar's visibility (ns.VISIBILITY), its faded opacity, its fade's length
    overheadRowVis = 1, overheadRowFaded = 0, overheadRowFadeTime = 0.25,
    -- Minimal OoC Mode (the Reticule): out of combat the console at Rest, the
    -- player and target at Units; combat, and what is ticked, bring it back
    consoleMinimal = false, consoleMinimalUnits = 0.2, consoleMinimalRest = 0, consoleMinimalRegen = 0,
    consoleMinimalTarget = false, consoleMinimalHurt = false, consoleMinimalGroup = false, consoleMinimalMouse = true,
    deadColor = "ff40424a", -- a dead friend's frame (dead.lua), every frame and profile
    visibility = 1,         -- Bar 1 visibility: see VISIBILITY
    extraVisibility = 1,    -- Extra bar(s) visibility (action bars 2 and 3): see VISIBILITY
    drawer = 1,             -- which way the minimap button drawer opens: see DRAWER
    chat = true,            -- the chat in a box on the left strip, the quest tracker over it
    chatClassColors = true, -- a speaker's name in the chat in their class's colour (strips/chat.lua)
    chatLevels = true,      -- and their level before it, "[60:Name]", when it is known
    chatHistory = 500,      -- the lines of each chat window kept for the next session, per character (0: none)
    side = true,            -- the chat panel's mirror on the right strip: the meter, the loot, the auras
    sideAuras = true,       -- its Auras tab
    sideMeter = true,       -- its Meter tab
    sideLoot = true,        -- its Loot tab
    sideZone = true,        -- its Zone tab: the minimap and this zone's quests
    sideTab = "meter",      -- the tab last shown (not on the page: the tabs set it)
    sideClosed = false,     -- closed to its tab row (not on the page: a click on the lit tab)
    -- Immersion (Shared > Visibility & fading): the chat bare when idle, its
    -- box back on use (strips/chat.lua); the side panel faded when idle,
    -- whole again on what is ticked (strips/side.lua)
    chatImmersion = false, chatBareCombat = false, chatBareDelay = 4, chatBands = 0.45,
    sideImmersion = false, sideFadedAlpha = 0.5, sideShowCombat = true, sideShowTarget = true,
    sideShowHurt = false, sideShowGroup = false, sideShowMouse = true, sideFadeIn = 0.2, sideFadeOut = 0.6,
    meterColumns = 1,       -- 2 shows a second list beside the first
    meterLeft = "damage",   -- what the first list shows: see METER_METRICS
    meterRight = "healing", -- what the second list shows
    meterSession = 1,       -- see METER_SESSION
    meterRate = true,       -- damage and healing per second instead of totals
    lootWho = 1,            -- see LOOT_WHO
    lootQuality = 2,        -- the least item quality shown (2 = uncommon)
    lootMoney = true,       -- money and currencies in the loot log
    aurasTimeless = false,  -- list the auras that never run out too (they are over the portrait already)
    bags = true,            -- Medalluin's bags window instead of Blizzard's bags
    bagsView = "grid",      -- "bags": each bag under its name; "grid": every slot, bag by bag; "groups": fixed groups
    bagsColumns = 10,       -- slots across the window (not on the page: the window's corner sets it, 8 to 24)
    bagsItemLevel = true,   -- item levels on weapons and armour
    bagsPoint = false,      -- where the window was dragged to: { point, relativePoint, x, y } (not on the page)
    bank = true,            -- Medalluin's bank window instead of Blizzard's (Forever)
    bankView = "grid",      -- as bagsView, for the bank
    bankPlace = false,      -- detached: { detached, point, relative, x, y, w, h, scale } (not on the page)
    altPlace = false,       -- an alt's window (professions/alts.lua): { point, relative, x, y, w, h, scale }
    altItemsView = "list",  -- an alt's Items page: "list" or "grid"
    altItemsFilter = "all", -- and its filter: "all", "equipment", "consumable", "trade", "quest", "other", "junk"
    altRecipesSort = "name", -- its Professions page's recipes: "name", "quality" or "newest"
    altRecipesFolded = false, -- and the professions folded there: { [profession] = true } (not on the page)
    chatLogPlace = false,   -- the chat log's box: { point, relative, x, y, w, h, scale } (not on the page)
    rollFrame = true,       -- the Rolls window (strips/rolls.lua) instead of the game's roll frames
    rollsPlace = false,     -- its place: { point, relative, x, y } (not on the page)
    rollsFolded = false,    -- its log folded (not on the page)
    character = true,       -- Medalluin's character window instead of Blizzard's
    inspect = true,         -- Medalluin's inspect window instead of Blizzard's
    spellbook = true,       -- Medalluin's spellbook instead of Blizzard's (Forever)
    spellbookMissing = true, -- a red edge on a spell on no action bar (nor in a macro on one)
    spellbookUpRank = "marked", -- spells kept on their highest rank on the bars: "all", "marked" (Shift+Right-click
                                -- in the book, MedalluinCharDB.upRank) or "none"
    spellbookClickCast = true, -- click-cast bindings marked on their spells, and the book binding while /cc is open
    talents = true,         -- Medalluin's talents instead of Blizzard's (Forever)
    professions = true,     -- Medalluin's professions instead of Blizzard's (Forever)
    quests = true,          -- Medalluin's quest tracker on the left; its full view stands in the chat box
    questsSort = "level",   -- "level" or "zone" (the tracker's button sets it too)
    questsFolded = false,   -- the zone headings folded: { [zone] = true } (not on the page)
    questsMinimised = false, -- the tracker folded to its heading (not on the page: a click on its heading)
    questsView = "full",    -- "full": the screen's height at its left; "minimal": a box to move and size
    questsPlace = false,    -- the minimal view's place, size and scale: { point, relative, x, y, w, h, scale }
    questsFullMouseover = false, questsFullCombat = false,       -- each view hidden until the pointer is
    questsMinimalMouseover = false, questsMinimalCombat = false, -- over it, and in combat
    questsTree = false,     -- objectives on a tree's branches, the finished risen to the top; bulleted otherwise
    questsHidden = false,   -- hidden by the tray's tab (strips/tray.lua), until shown again (not on the page)
    questLog = true,        -- Medalluin's quest log, a window on the right strip, instead of Blizzard's
    questLogFolded = false, -- its zones folded: { [zone] = true } (not on the page)
    questLogSort = false,   -- its sort, by a heading: { key = "lvl"/"title"/"xp"/"item"/"coin", dir = "up"/"down" }
    questLogOrder = false,  -- its zones' order (its sort button): false (the log's), "level", "zone" (not on the page)
    questDropPlace = false, -- the Drop window's place, size and scale (quests/drop.lua)
    questPagePlace = false, -- a quest's page's, the same (quests/page.lua)
    lfgWindow = true,       -- the LFG / Who window on the chat box, instead of the game's (social/lfg.lua)
    tray = true,            -- the left-edge tray: a rail of tabs for the left windows (strips/tray.lua)
    trayCharacter = true, trayQuests = true,    -- its tabs: the character window, the quest tracker,
    trayLFG = false, trayChatLog = false,       -- the group finder, the chat's log,
    trayCdm = false, trayCc = false,            -- the Cooldown Manager, Click Casting
    trayDelay = 0.15,       -- how long the pointer rests at the edge before the rail comes (0: at once)
    lfgPage = "browse",     -- its page: browse, list or who (not on the page)
    lfgCategory = false,    -- Browse's category, the game's id (not on the page)
    lfgListed = false,      -- List me's picks: { [activity id] = true } (not on the page)
    lfgListCategory = false, -- List me's category, the game's id (not on the page)
    lfgPlaystyle = false,   -- List me's playstyle (the game's Enum.LFGEntryGeneralPlaystyle; not on the page)
    lfgVoice = false,       -- List me's voice chat (Enum.LFGEntryVoiceMode; not on the page)
    lfgNewPlayers = false,  -- List me: new players welcome (not on the page)
    lfgWhoSort = false,     -- Who's order: name, level or class (not on the page)
    lfgRoles = false,       -- the roles you list as, where the game keeps none: { tank, healer, dps }
    cdmWindow = true,       -- the game's Cooldown Manager dressed, on the chat box (cooldowns/window.lua)
    cdmDisplay = true,      -- its cooldown and buff icons as medallions over the console (cooldowns/display.lua)
    ccWindow = true,        -- the game's Click Casting window dressed, on the chat box (spells/clickcast.lua)
    professionsArt = "engraved", -- the professions Overview's art: "engraved", "painted" or "poster"
    medalluinFace = "marcellus", -- Medalluin's font on Latin clients: "marcellus" or "forum" (core.lua)
    gameMenu = "docked",    -- the game menu (Escape): "docked", "medallion" or the game's, "game" (window/gamemenu.lua)
    gameMenuFriends = "online", -- its friends shown: "online", "all" or "bnet"
    gameMenuGuild = "officers", -- its guild shown: "officers" (the top ranks), "all", or "ranks" (those picked)
    gameMenuGuildRanks = false, -- the ranks picked, by name (a table once one is); the top ranks until then
    gameMenuFriendsSort = "name", -- the friends' order: name, level or zone (offline last)
    gameMenuGuildSort = "name", -- the guild's order: name, level, rank or zone (offline last)
    gameMenuGuildName = true, -- the guild's name as its window's title (else "Guild")
    gameMenuMotd = true, -- the guild's message of the day over its list
    gameMenuHidden = false, -- the docked game menu's hidden sections, by key (a table once one is)
    gameMenuTab = "friends", -- the people window's tab shown: "friends" or "guild"
    gameMenuClock24 = true, -- the menu's clock in 24 hours (else 12, with am and pm)
    gameMenuClockRealm = false, -- the clock on the realm's time (else this computer's)
    gameMenuSession = true, -- gold, the session and latency under the clock
    gameMenuClockFade = true, -- the clock fades a while after the menu opens
    gameMenuFoldIdle = true, -- the docked panel folds to a rail when left alone
    gameMenuSpin = true, -- the camera turns around you while it is folded
    gameMenuFilter = true, -- the world behind the menu dimmed and tinted
    gameMenuFilterStrength = 0.5, -- how strongly (0.2 to 0.8)
    gameMenuFilterTint = "black", -- its tint (window/gamemenu.lua TINTS)
    gameMenuFilterShape = "vignette", -- a vignette, or "even" (the old flat shade)
    npcWindows = true,      -- gossip, the quest pages and the vendor in a box on the chat box (npc/window.lua)
    merchantAutoRepair = false, -- a repair vendor opened repairs everything (Alt-click its Repair, npc/merchant.lua)
    npcSpace = true,        -- Space presses a quest page's Accept, Continue or Complete Quest
    npcQuestItems = true,   -- an item that begins a quest, got, opens the box on it (npc/questitem.lua)
    trainerFilter = false,  -- the trainer's type shown: "available", "unavailable" or "used"; Available if unset
    questsTitleFont = "marcellus", questsTitleSize = 12,         -- ns.Fonts()'s keys, and points
    questsObjectiveFont = "marcellus", questsObjectiveSize = 12,
    optionsPoint = false,   -- where the settings window was dragged to, the same way (options/window.lua)
    editorPoint = false,    -- and the unit-frame editor's (options/editor.lua)
    xpCast = false,         -- the player's casts over the experience bar
    repCast = false,        -- the target's casts over the reputation bar
    simParty = false,       -- simulate party frames and show the group art layer
    simCdm = false,         -- simulate the Cooldown Manager's viewers in their options (cooldowns/simulate.lua)
    partyPets = true,       -- show pet frames directly below party members with pets
    partyLayout = "console", -- "console": on the console, Arena's medallion wings or the Reticule's row
                             -- under it (console/party_row.lua); "widget": a box dragged anywhere
                             -- (widgets/party.lua)
    partyRange = 40,        -- distance in yards to fade out-of-range party frames (0 = off)
    overhead = true,        -- top-of-screen cascading trapezoid structure
    bossFrames = "overhead", -- boss frames on the overhead's top tier, in the "vertical" Boss widget, or "both"
    -- where each group widget was dragged to: { point, relativePoint, x, y } (widgets/; not on the
    -- page), shared by every profile
    partyWidgetPoint = false, raidWidgetPoint = false, bossWidgetPoint = false, arenaWidgetPoint = false,
    topPet = true,          -- player pet unit frame on the middle tier
    topFocus = true,        -- focus unit frame on the middle tier
    topToT = true,          -- target of target frame on the middle tier
    topPetBar = true,       -- pet action bar on the bottom tier
    -- an overhead unit frame alt+dragged off it, where it was left: its
    -- holder's top-left from the screen's bottom-left, in the holder's units
    -- (console/overhead.lua; false: not placed yet)
    detachPet = false, detachFocus = false, detachToT = false,
    detachPetX = false, detachPetY = false, detachFocusX = false, detachFocusY = false,
    detachToTX = false, detachToTY = false,
    topStances = true,      -- stance bar on the bottom tier
    topTotems = true,       -- totem bar on the bottom tier (Forever's)
    overheadFlyoutTips = "right",   -- a totem flyout's tooltips: beside it, "right" or "left"
    auraGlow = true,        -- border glow for dispellable debuffs
    auraThreat = true,      -- border glow while the unit has aggro
    auraCC = true,          -- large center icon for crowd control
    auraBuffs = true,       -- row of buffs on outer health corner (yours; the editor's From)
    auraDebuffs = true,     -- row of debuffs on inner health corner (all; the editor's From)
    auraBoss = true,        -- boss debuffs on inner health corner
    bossMine = true,        -- your debuffs on the overhead's bosses
    -- The widgets' (Unit Frames' Widget groups and the Raid, Battleground and
    -- Arena tabs; console/auras.lua), shared by every profile: the Party
    -- widget's own range and auras (ns.PartyOption; it has no pets), the raid's out of
    -- battlegrounds and in one, the Boss widget's and the arena's
    partyWidgetPlayer = true, partyWidgetRange = 40, partyWidgetGlow = true, partyWidgetCC = true,
    partyWidgetBuffs = true, partyWidgetBoss = true, partyWidgetThreat = true, partyWidgetDebuffs = true,
    raidRange = 40, raidGlow = true, raidCC = true, raidBoss = true, raidThreat = true, raidDebuffs = true,
    bgRange = 40, bgGlow = true, bgCC = true, bgThreat = true, bgDebuffs = true,
    -- the dispel glow, type by type (console/auras.lua): on, and its colour;
    -- the aggro glow's colour. Shared by every profile.
    dispelMagic = true, dispelCurse = true, dispelPoison = true, dispelDisease = true, dispelBleed = true,
    dispelColorMagic = "ff3399ff", dispelColorCurse = "ffb200ff", dispelColorPoison = "ff00d11f",
    dispelColorDisease = "ffd16100", dispelColorBleed = "ffcc0f0f",
    dispelStyle = "glow",   -- a dispel shown as the border's glow, or "health": the health bar in its colour
    threatColor = "ffe63c28",
    bossWidgetMine = true,
    arenaCC = true, arenaMine = true,
    -- each box's movers (its tabs) only on mouseover (widgets/box.lua)
    partyWidgetMoverHover = false, raidMoverHover = false, bgMoverHover = false, bossMoverHover = false,
    arenaMoverHover = false,
    -- what the unit-frame editor (editor.lua) changed on each frame, piece
    -- by piece: false until something is; the console's per profile, the
    -- widgets' shared
    editUnit = false, editParty = false,
    editPartyWidget = false, editRaid = false, editBoss = false, editArena = false,
    blizzardAuras = false,  -- Blizzard's own buff and debuff rows, top right (blizzard.lua)
    consoleProfile = "reticule", -- "reticule": the slim console, square minimap & bar 7; "arena": the medallion
    -- which page each bar shows (bars/paging.lua): "default", "stances", "page1".."page10" or
    -- "custom", with the custom conditional beside it
    bar1Paging = "default", bar1PagingCustom = "",
    row2Paging = "default", row2PagingCustom = "",
    row3Paging = "default", row3PagingCustom = "",
    gridPaging = "default", gridPagingCustom = "",
    -- the grid's Forms, stealth, flying, condition by condition (bars/paging.lua's GRID_PARTS)
    gridPageFlying = true, gridPageForm1 = true, gridPageForm2 = true, gridPageForm3 = true, gridPageStealth = true,
    -- Settings > Shared: one value for an option many frames have, which
    -- each frame's own choice overrides (SHARED below)
    moverHover = false, rangeFade = 40,
    sharedGlow = true, sharedThreat = true, sharedCC = true, sharedBuffs = true, sharedDebuffs = true,
    sharedBoss = true,
}
ns.VISIBILITY = { ALWAYS = 1, COMBAT = 2, MOUSEOVER = 3, COMBAT_OR_MOUSEOVER = 4 }
-- The Cooldown Manager's three icon viewers over the screen (cooldowns/display.lua):
-- each one's letter in its options' keys (cdmE..., cdmU..., cdmB...), its
-- display's key, and the size its icons are drawn at.
ns.CDM_VIEWERS = {
    { "E", "essential", Tr["Essential cooldowns"], 44 },
    { "U", "utility", Tr["Utility cooldowns"], 32 },
    { "B", "buffs", Tr["Tracked buffs"], 30 },
}
-- each one's options, the same set: their names after cdm<letter>, and what
-- they are untouched
local CDM_FIELDS = {
    Layout = "bar",         -- "bar" or "arch" (cooldowns/layout.lua)
    Orient = "across",      -- a bar's rows: "across" or "down"
    PerRow = 0,             -- a bar's icons a row; 0, one row
    Span = 120,             -- an arch's sweep, in degrees
    Opens = "up",           -- an arch: "up" (its ends low) or "down"
    Order = "middle",       -- where its first spell stands: "middle", "start" or "finish"
    Gaps = false,           -- close ranks over a hidden icon (true for the buffs)
    Shape = "round",        -- "round", "rounded", "square" or "bare"
    Spacing = 4,            -- between icons
    CdSize = 1, CdPos = "center",               -- the cooldown's number: a scale (0, hidden), and where
    CountSize = 1, CountPos = "bottomright",    -- charges and stacks: the same
    Swipe = true, Desat = true, Range = true, Tips = true,
    Vis = 1, Faded = 0, FadeTime = 0.25,        -- ns.VISIBILITY; the faded opacity and the fade's length
    X = 0, Y = 0,           -- moved from where it is drawn (movers.lua)
}
ns.CDM_FIELDS = CDM_FIELDS
for _, v in ipairs(ns.CDM_VIEWERS) do
    for field, value in pairs(CDM_FIELDS) do DEFAULTS["cdm" .. v[1] .. field] = value end
    DEFAULTS["cdm" .. v[1] .. "Size"] = v[4]
end
DEFAULTS.cdmBGaps = true
-- Minimal OoC Mode for the whole Cooldown Manager (Shared > Immersion Mode):
-- out of combat every viewer at cdmMinimalAlpha, back for what is ticked;
-- while on, it takes over from each viewer's Visibility (cooldowns/display.lua)
DEFAULTS.cdmMinimal, DEFAULTS.cdmMinimalAlpha = false, 0
DEFAULTS.cdmMinimalTarget, DEFAULTS.cdmMinimalHurt = false, false
DEFAULTS.cdmMinimalGroup, DEFAULTS.cdmMinimalMouse = false, true
-- Minimal OoC Mode for the party and raid boxes (Shared > Immersion Mode,
-- widgets/box.lua): out of combat at groupMinimalAlpha, back for what is ticked
DEFAULTS.groupMinimal, DEFAULTS.groupMinimalAlpha = false, 0
DEFAULTS.groupMinimalHurt, DEFAULTS.groupMinimalMouse = true, true
-- The fourth viewer, the tracked bars (BuffBarCooldownViewer): a bar each,
-- so options of their own, keyed cdmT<field>. Size is a bar's height.
ns.CDM_BARS = { "T", "bars", Tr["Tracked bars"], 24 }
local CDM_BAR_FIELDS = {
    Grow = "up",            -- the next bar above the first ("up") or below ("down")
    Gaps = true,            -- close ranks over a bar not up
    Width = 220,            -- a bar's width, its icon in it
    Spacing = 4,            -- between bars
    Icon = "left",          -- the spell's icon: "left", "right" or "none"
    Shape = "round",        -- the icon's, as the other viewers': "round", "rounded", "square", "bare"
    NameSize = 1, TimeSize = 1, CountSize = 1,  -- the texts: a scale (0, hidden)
    Tips = true,
    Vis = 1, Faded = 0, FadeTime = 0.25,
    X = 0, Y = 0,
}
ns.CDM_BAR_FIELDS = CDM_BAR_FIELDS
for field, value in pairs(CDM_BAR_FIELDS) do DEFAULTS["cdmT" .. field] = value end
DEFAULTS.cdmTSize = ns.CDM_BARS[4]
-- Utility at Essential's right: its default place, so Across reads from the
-- screen's middle for all three, as the mover shows it
DEFAULTS.cdmUX = 280
ns.DRAWER = { LEFT = 1, UP = 2 }
ns.METER_SESSION = { OVERALL = 0, CURRENT = 1 }     -- Enum.DamageMeterSessionType's values
ns.LOOT_WHO = { GROUP = 1, MINE = 2 }
-- What a meter list can show: the key saved, the name on the page. The
-- client's types for each are in meter.lua.
ns.METER_METRICS = {
    { "damage", Tr["Damage"] },
    { "healing", Tr["Healing"] },
    { "absorbs", Tr["Absorbs"] },
    { "interrupts", Tr["Interrupts"] },
    { "dispels", Tr["Dispels"] },
    { "taken", Tr["Damage taken"] },
    { "avoidable", Tr["Avoidable damage taken"] },
}
-- Item qualities, as the loot log's least-quality option offers them.
ns.LOOT_QUALITIES = { { 0, Tr["Poor"] }, { 1, Tr["Common"] }, { 2, Tr["Uncommon"] }, { 3, Tr["Rare"] }, { 4,
    Tr["Epic"] } }

-- The built-in profiles. Each is a look the console starts from: what it
-- changes from DEFAULTS. The art the Reticule draws is
-- console/light_profile.lua; this is only what it means for the options.
-- Reticule is the default; Arena is the round medallion console. Their ids
-- were "light" and "default" until 0.44 (Migrate renames them).
local PROFILES = {
    arena = {},
    reticule = { rows = 3 },
}
-- Arena is set aside (2026-11-17): not chosen, and an install on it moved to
-- the Reticule once (Migrate), each character's bars with it at its next
-- login (bars/skills.lua). Medalluin_ArenaOpen (the harness's, testing the
-- console as it stands) lets it through.
local WIP = { arena = true }
local function Open(profile) return not WIP[profile] or Medalluin_ArenaOpen == true end
ns.ProfileOpen = Open
ns.PROFILE_NAMES = {
    { "reticule", Tr["Reticule (default)"], Tr["Flush-top player/target wings, dynamic square minimap / 2x5 Bar 7 bay, "
        .. "split Action Bars 2 & 3, and party frames in a row under the console."] },
    -- set aside till its redesign after 1.0: shown, dimmed, not chosen (WIP)
    { "arena", Tr["Arena (WIP)"], Tr["The classic round medallion console with integrated party wings, and a large "
        .. "player and target. Out of date, and to be redesigned after 1.0, so it cannot be chosen."],
        wip = not Open("arena") or nil },
}
-- the ids the profiles had, and what they are now
local OLD_IDS = { default = "arena", light = "reticule" }

-- The options are layered: DEFAULTS, then the chosen profile, then the
-- player's own choices on top. Only a choice that differs from the profile
-- is saved.
--
-- What shapes the console (every page under Console but the Overhead; under
-- Unit Frames the console's party; the editor's player, target and console
-- party) is remembered per profile, in MedalluinDB.profiles[name]:
-- each profile keeps its own choices, so a switch brings back the ones made
-- on the profile switched to. Everything else (the overhead and its bosses,
-- the group widgets, the chat, the side panel, the bags, where windows were
-- left, the party preview) has nothing to do with the console and is one
-- set, MedalluinDB.global.
-- Reset profile clears the current profile's choices and nothing else.
local PER_PROFILE = {}
-- the overhead's: shared by every profile since 2026-11-15 (Migrate moves
-- what a profile held)
local OVERHEAD_KEYS = {
    "overhead", "overheadScale", "overheadX", "overheadY", "overheadAlpha", "overheadFadeIn", "overheadFadeOut",
    "topPet", "topFocus", "topToT", "topPetBar", "topStances", "topTotems", "overheadFlyoutTips",
    "detachPet", "detachFocus", "detachToT", "detachPetX", "detachPetY", "detachFocusX", "detachFocusY",
    "detachToTX", "detachToTY", "bossFrames", "bossMine",
}
ns.OVERHEAD_KEYS = OVERHEAD_KEYS
for _, key in ipairs({
    "actionBar", "rows", "bareIcons", "artColor", "hideEmpty", "barLowRow", "visibility", "extraVisibility", "drawer",
    "hotkeySize", "cooldownText", "cooldownTextSize", "cooldownSwipe", "cooldownEdge", "cooldownBling",
    "consoleScale", "consoleX", "consoleY",
    "minimapAuto", "minimapAutoCombat", "minimapAutoTarget", "minimapAutoSkyriding",
    "minimapScale", "minimapX", "minimapY", "minimapAreaTime", "minimapStart", "minimapMoverHover",
    "consoleFade", "consoleShowCombat", "consoleShowTarget", "consoleShowHurt", "consoleShowGroup",
    "consoleShowMouse", "consoleAlpha", "consoleFadedAlpha", "consoleFadeIn", "consoleFadeOut",
    "consoleMinimal", "consoleMinimalUnits", "consoleMinimalRest", "consoleMinimalRegen", "consoleMinimalTarget",
    "consoleMinimalHurt", "consoleMinimalGroup", "consoleMinimalMouse",
    "partyPets", "partyLayout", "partyRange", "auraGlow", "auraThreat", "auraCC", "auraBuffs", "auraBoss",
    "auraDebuffs",
    "editUnit", "editParty",
    "xpCast", "repCast",
    "cdmMinimal", "cdmMinimalAlpha", "cdmMinimalTarget", "cdmMinimalHurt", "cdmMinimalGroup", "cdmMinimalMouse",
    "groupMinimal", "groupMinimalAlpha", "groupMinimalHurt", "groupMinimalMouse",
}) do PER_PROFILE[key] = true end
-- the Cooldown Manager's viewers: placed and dressed per profile, as the console is
for key in pairs(DEFAULTS) do
    if key:match("^cdm[EUBT]%u") then PER_PROFILE[key] = true end
end
ns.PER_PROFILE = PER_PROFILE

-- Paging (bars/paging.lua) is the class's: its forms, stances and stealth
-- are, so every character of a class shares it, still per profile, in
-- MedalluinDB.classes[class][profile]. A class's first look at a profile
-- starts from what the profile held, where paging was kept until 2026-11-19.
local PER_CLASS = {}
for _, key in ipairs({ "bar1Paging", "bar1PagingCustom", "row2Paging", "row2PagingCustom", "row3Paging",
    "row3PagingCustom", "gridPaging", "gridPagingCustom", "gridPageFlying", "gridPageForm1", "gridPageForm2",
    "gridPageForm3", "gridPageStealth" }) do PER_CLASS[key] = true end
ns.PER_CLASS = PER_CLASS

-- The party's options: the console's (per profile, shaped and placed by
-- it), or, while the Party layout is the widget, the widget's own (shared).
-- The player's and target's frames keep the console's.
local PARTY_WIDGET = {
    partyRange = "partyWidgetRange", auraGlow = "partyWidgetGlow", auraThreat = "partyWidgetThreat",
    auraCC = "partyWidgetCC", auraBuffs = "partyWidgetBuffs", auraBoss = "partyWidgetBoss",
    auraDebuffs = "partyWidgetDebuffs",
}
function ns.PartyKey(key)
    return ns.db.partyLayout == "widget" and PARTY_WIDGET[key] or key
end
function ns.PartyOption(key) return ns.db[ns.PartyKey(key)] end
-- The party's pets: the console's option; the widget shows none (it is for
-- competitive play, where they are not wanted).
function ns.PartyPets() return ns.db.partyLayout ~= "widget" and ns.db.partyPets ~= false end

-- Options many frames have, one value for them all (Settings > Shared):
-- a frame's option the player has not set is the shared one; one set is
-- the frame's own, and wins. Set back to the shared value, it follows it
-- again (a choice equal to its base is not saved). Each family's defaults
-- are the same, so the shared value changes nothing until it is changed.
local SHARED = {
    moverHover = { "minimapMoverHover", "partyWidgetMoverHover", "raidMoverHover", "bgMoverHover",
        "bossMoverHover", "arenaMoverHover" },
    rangeFade = { "partyRange", "partyWidgetRange", "raidRange", "bgRange" },
    sharedGlow = { "auraGlow", "partyWidgetGlow", "raidGlow", "bgGlow" },
    sharedThreat = { "auraThreat", "partyWidgetThreat", "raidThreat", "bgThreat" },
    sharedCC = { "auraCC", "partyWidgetCC", "raidCC", "bgCC", "arenaCC" },
    sharedBuffs = { "auraBuffs", "partyWidgetBuffs" },
    sharedDebuffs = { "auraDebuffs", "partyWidgetDebuffs", "raidDebuffs", "bgDebuffs", "bossMine", "bossWidgetMine",
        "arenaMine" },
    sharedBoss = { "auraBoss", "partyWidgetBoss", "raidBoss" },
}
local SHARED_OF = {}
for shared, keys in pairs(SHARED) do
    for _, key in ipairs(keys) do SHARED_OF[key] = shared end
end
ns.SHARED = SHARED
-- The shared option a frame's option follows, or nil.
function ns.SharedOf(key) return SHARED_OF[key] end

local function Profile()
    local p = MedalluinDB and MedalluinDB.consoleProfile
    return PROFILES[p] and Open(p) and p or "reticule"
end

-- The class's own options for the profile in use (PER_CLASS), made from
-- the profile's the first time.
local function ClassStore(profile)
    local class = UnitClass and select(2, UnitClass("player"))
    if not class then return nil end
    MedalluinDB.classes = MedalluinDB.classes or {}
    local byClass = MedalluinDB.classes[class] or {}
    MedalluinDB.classes[class] = byClass
    profile = profile or Profile()
    local t = byClass[profile]
    if not t then
        t = {}
        local old = MedalluinDB.profiles[profile] or {}
        for key in pairs(PER_CLASS) do t[key] = old[key] end
        byClass[profile] = t
    end
    return t
end

-- Where the player's choice for an option is kept.
local function Store(key)
    if PER_CLASS[key] then
        local t = ClassStore()
        if t then return t end
    end
    if PER_PROFILE[key] or PER_CLASS[key] then return MedalluinDB.profiles[Profile()] end
    return MedalluinDB.global
end

-- What an option is when the player has not chosen: the profile's, else
-- the shared option's it follows (as chosen), else DEFAULTS.
local function Base(key)
    local v = PROFILES[Profile()][key]
    local shared = v == nil and SHARED_OF[key]
    if shared then
        v = MedalluinDB and MedalluinDB.global and MedalluinDB.global[shared]
        if v == nil then v = Base(shared) end
    end
    if v == nil then v = DEFAULTS[key] end
    return v
end

-- Whether the player chose this option (a frame's own, over a shared one).
function ns.OptionOwn(key)
    return MedalluinDB ~= nil and MedalluinDB.global ~= nil and Store(key)[key] ~= nil
end

-- ns.db reads through the layers and writes the player's choices; it holds
-- nothing itself. Defaults only until ADDON_LOADED, before the saved table.
ns.db = {}
for k, v in pairs(DEFAULTS) do ns.db[k] = v end
local layered = setmetatable({}, {
    __index = function(_, key)
        if key == "consoleProfile" then return Profile() end
        local v = Store(key)[key]
        if v == nil then v = Base(key) end
        return v
    end,
    __newindex = function(_, key, value)
        if key == "consoleProfile" then
            MedalluinDB.consoleProfile = value
        elseif value == Base(key) then
            Store(key)[key] = nil
        else
            Store(key)[key] = value
        end
    end,
})

-- ns.OnSetting(key, fn): fn(value) whenever the player changes that option.
-- ns.OnAnySetting(fn): fn(key, value) after any option changes (the
-- settings window, to show it).
local watchers, anyWatchers = {}, {}
function ns.OnSetting(key, fn)
    watchers[key] = watchers[key] or {}
    table.insert(watchers[key], fn)
end
function ns.OnAnySetting(fn)
    table.insert(anyWatchers, fn)
end
local function Changed(key, value)
    ns.db[key] = value
    for _, fn in ipairs(watchers[key] or {}) do fn(value) end
    for _, fn in ipairs(anyWatchers) do fn(key, value) end
end

-- What an option is when the player has not chosen one (the window's tips).
ns.OptionBase = Base
-- What an option is before any profile or choice (the harness's check that
-- a shared option starts where its frames' did).
function ns.OptionDefault(key) return DEFAULTS[key] end

local SwitchProfile
local reloadAsked               -- a switch in combat: its reload asked for when combat ends

-- ns.SetOption(key, value): an option changed, by the settings window or by
-- Medalluin's own controls (the side panel's column buttons). Choosing the
-- profile switches to it.
function ns.SetOption(key, value)
    if key == "consoleProfile" then
        if not Open(value) then return end      -- set aside: not chosen, nothing told
        SwitchProfile(value)
    end
    -- a shared option: the frames that follow it hear their change too
    local followers, before = SHARED[key], {}
    for _, k in ipairs(followers or {}) do before[k] = ns.db[k] end
    Changed(key, value)
    for _, k in ipairs(followers or {}) do
        local now = ns.db[k]
        if now ~= before[k] then Changed(k, now) end
    end
end

-- Run change(), which moves layers under the options, then tell the modules
-- (and the window) about every option whose value it moved.
local function Relayer(change)
    local before = {}
    for key in pairs(DEFAULTS) do before[key] = ns.db[key] end
    change()
    for key in pairs(DEFAULTS) do
        local now = ns.db[key]
        -- the profile's own setting reports itself, as any setting does
        if now ~= before[key] and key ~= "consoleProfile" then Changed(key, now) end
    end
end

-- Switching profile brings back that profile's own choices; the global
-- options stay as they are.
function SwitchProfile(profile)
    if not PROFILES[profile] or not Open(profile) or profile == Profile() then return end
    -- and its own skills on the bars (bars/skills.lua), and keys on them
    -- (keybind.lua)
    if ns.SwitchSkills then ns.SwitchSkills(Profile(), profile) end
    if ns.SwitchKeys then ns.SwitchKeys(Profile(), profile) end
    Relayer(function() MedalluinDB.consoleProfile = profile end)
    -- a console is built at load (ns.ApplyLightProfile): the switch ends by
    -- asking for a reload, once its skills and keys are on the bars. It asks,
    -- never reloads: ReloadUI from the option's own click is blocked as a
    -- protected call (ADDON_ACTION_BLOCKED, seen in game), while the dialog's
    -- Reload button is a click of its own. In combat the skills and keys
    -- wait for it to end, and the asking waits with them.
    if not InCombatLockdown() then
        StaticPopup_Show("MEDALLUIN_PROFILE_RELOAD")
        return
    end
    if reloadAsked then return end      -- asked once, after the last of them
    reloadAsked = true
    ns.OutOfCombat(function()
        reloadAsked = nil
        StaticPopup_Show("MEDALLUIN_PROFILE_RELOAD")
    end)
end

-- Reset profile: the current profile's options back to its own.
function ns.ResetProfile()
    Relayer(function()
        wipe(MedalluinDB.profiles[Profile()])
        -- this class's paging on it too
        local t = ClassStore()
        if t then wipe(t) end
    end)
end

-- The setup wizard's answers (options/setup.lua), written in one go: the
-- console first, so what is kept per profile lands in the profile chosen
-- (Store reads the one saved, and a switch saves it at once, then asks for
-- the reload); then each other answer through SetOption, so the parts hear
-- it. A console that cannot be chosen is refused as on Profiles, and the
-- console's Minimal OoC Mode is the Reticule's only.
--   answers = { console = id, immersion = { [key] = on }, partyLayout = "console" | "widget" }
ns.SETUP_IMMERSION = { "consoleMinimal", "chatImmersion", "sideImmersion", "groupMinimal", "cdmMinimal" }
function ns.ApplySetup(answers)
    if answers.console and answers.console ~= Profile() then ns.SetOption("consoleProfile", answers.console) end
    for _, key in ipairs(ns.SETUP_IMMERSION) do
        local on = answers.immersion and answers.immersion[key]
        if on ~= nil and (key ~= "consoleMinimal" or Profile() == "reticule") then ns.SetOption(key, on) end
    end
    if answers.partyLayout then ns.SetOption("partyLayout", answers.partyLayout) end
    ns.SetupDone()
end
-- This character has been through setup (finished, skipped or closed): it
-- is not offered again at login; /mui setup still opens it.
function ns.SetupDone()
    MedalluinCharDB = MedalluinCharDB or {}
    MedalluinCharDB.setup = "done"
end
-- Whether the wizard is owed at this login: a character new to Medalluin
-- (no saved table of its own when the addon loaded), not yet through it.
-- One that existed before the wizard counts as set up.
function ns.SetupOwed()
    return ns.setupFresh == true and not (MedalluinCharDB and MedalluinCharDB.setup)
end

-- A saved table from before profiles is flat, every option at the top with
-- the defaults filled in. Its console options become the choices of the
-- profile it was on (the other profile starts as it is drawn), the rest the
-- global ones; only what differs from the profile is kept, and anything
-- unknown is left where it is.
-- A table keyed by profile id, its old ids renamed: an entry already under
-- the new id wins; the old one goes either way.
local function RenameIds(t)
    if type(t) ~= "table" then return end
    for old, new in pairs(OLD_IDS) do
        if t[old] ~= nil then
            if t[new] == nil then t[new] = t[old] end
            t[old] = nil
        end
    end
end

local function Migrate(fresh)
    local db = MedalluinDB
    db.global = db.global or {}
    db.profiles = db.profiles or {}
    -- the profiles' ids, renamed wherever they key something: the options
    -- per profile, the keys (the account's binding set here, a character's
    -- in MedalluinCharDB, with the character's skills on the bars, migrated
    -- as each character logs in), and the profile chosen
    RenameIds(db.profiles)
    RenameIds(db.keys)
    if type(MedalluinCharDB) == "table" then
        RenameIds(MedalluinCharDB.layouts)
        RenameIds(MedalluinCharDB.keys)
    end
    db.consoleProfile = OLD_IDS[db.consoleProfile] or db.consoleProfile
    -- an install that never chose was on the medallion, the default until
    -- 0.44: it stays there; a new one starts on the Reticule
    if not fresh and db.consoleProfile == nil then db.consoleProfile = "arena" end
    -- one set aside: the Reticule (its options, skills and keys, as a switch
    -- brings them); each character's bars follow at its login (arenaLeft)
    if db.consoleProfile and not Open(db.consoleProfile) then
        db.consoleProfile = "reticule"
        db.arenaLeft = true
    end
    for name in pairs(PROFILES) do db.profiles[name] = db.profiles[name] or {} end
    -- the overhead's Boss frames checkbox became Boss frames: Overhead,
    -- Vertical or Both; turned off, the bosses were not on the overhead
    local stores = { db }
    for name in pairs(PROFILES) do table.insert(stores, db.profiles[name]) end
    -- the party layout was Vertical (the medallion's wings, the light
    -- profile's stack on the left), Horizontal (the Reticule's row) or
    -- Widget; the stack is gone, and both others are now the console's own
    for _, store in ipairs(stores) do
        if store.partyLayout == "vertical" or store.partyLayout == "horizontal" then store.partyLayout = nil end
    end
    for _, store in ipairs(stores) do
        if store.topBoss == false and store.bossFrames == nil then store.bossFrames = "vertical" end
        store.topBoss = nil
    end
    -- the windows' details are always open now: their folds forgotten; and
    -- the spellbook lists a spell's ranks under it, folded, not all at once
    local gone = { "bankDetails", "characterDetails", "spellbookDetails", "spellbookAllRanks" }
    for _, store in ipairs(stores) do
        for _, key in ipairs(gone) do store[key] = nil end
    end
    if db.global then
        for _, key in ipairs(gone) do db.global[key] = nil end
    end
    -- Keep every spell on its highest rank (a checkbox) became Top rank:
    -- Every spell, Only those marked or None
    for _, store in ipairs({ db, db.global }) do
        if store.spellbookUpRankAll == true and store.spellbookUpRank == nil then store.spellbookUpRank = "all" end
        store.spellbookUpRankAll = nil
    end
    for name in pairs(PROFILES) do db.profiles[name].spellbookUpRankAll = nil end
    for key in pairs(DEFAULTS) do
        local v = db[key]
        if key ~= "consoleProfile" and v ~= nil then
            if v ~= Base(key) then Store(key)[key] = v end
            db[key] = nil
        end
    end
    -- the docked game menu's This session became the clock's line: hidden,
    -- the clock is
    local hid = db.global.gameMenuHidden
    if type(hid) == "table" and hid.session ~= nil then
        if hid.clock == nil then hid.clock = hid.session end
        hid.session = nil
    end
    -- The widgets became shared by every profile, the console's party staying
    -- per profile. A widget's place, kept per profile until then, comes from
    -- the profile in use; the widgets' own options start from what the party
    -- (and Your debuffs, the boss's) had there, which was theirs until then.
    -- Once: an option set back to its default is not saved, and must not be
    -- copied again.
    if not db.widgetsShared then
        local here = db.profiles[Profile()]
        for _, key in ipairs({ "partyWidgetPoint", "raidWidgetPoint", "bossWidgetPoint", "arenaWidgetPoint" }) do
            if db.global[key] == nil then db.global[key] = here[key] end
            for name in pairs(PROFILES) do db.profiles[name][key] = nil end
        end
        local from = {
            partyWidgetRange = "partyRange", partyWidgetGlow = "auraGlow",
            partyWidgetCC = "auraCC", partyWidgetBuffs = "auraBuffs", partyWidgetBoss = "auraBoss",
            raidRange = "partyRange", bgRange = "partyRange", bossWidgetMine = "bossMine",
        }
        for key, src in pairs(from) do
            if db.global[key] == nil then db.global[key] = here[src] end
        end
        db.widgetsShared = true
    end
    -- The overhead became shared by every profile (2026-11-15): its options,
    -- its frames' places and its bosses', kept per profile until then, come
    -- from the profile in use. Once, as the widgets' move was.
    if not db.overheadShared then
        local here = db.profiles[Profile()]
        for _, key in ipairs(OVERHEAD_KEYS) do
            if db.global[key] == nil then db.global[key] = here[key] end
            for name in pairs(PROFILES) do db.profiles[name][key] = nil end
        end
        db.overheadShared = true
    end
end

-- "ffRRGGBB" -> r, g, b in 0..1, white for anything unreadable.
function ns.HexColor(hex)
    local r, g, b = tostring(hex):match("^%x%x(%x%x)(%x%x)(%x%x)$")
    if not r then return 1, 1, 1 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- Only a key is added: assigning StaticPopupDialogs itself would taint it.
StaticPopupDialogs.MEDALLUIN_PROFILE_RELOAD = {
    text = Tr["Reload to finish switching console profile?\n\n"
        .. "Its skills and keys are on the bars; its console is built as the interface loads."],
    button1 = Tr["Reload"],
    button2 = Tr["Later"],
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs.MEDALLUIN_RESET_PROFILE = {
    text = Tr["Put this console profile's options back to its own?\n\n"
        .. "Options that take effect after a reload need one."],
    button1 = OKAY or Tr["Okay"],
    button2 = CANCEL or Tr["Cancel"],
    OnAccept = function() ns.ResetProfile() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- The conditional editor: the bar's conditional in use, in a text box.
-- Saving one picks Custom; saving it empty, or cancelling a Custom that has
-- none, goes back to the bar's default.
local function PagingBox(dialog)
    return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end
local function SavePaging(dialog, bar)
    local text = (PagingBox(dialog):GetText() or ""):match("^%s*(.-)%s*$")
    ns.SetOption(bar.key .. "Custom", text)
    ns.SetOption(bar.key, text ~= "" and "custom" or "default")
end
StaticPopupDialogs.MEDALLUIN_PAGING = {
    text = Tr["%s: the page, by macro conditional"],
    button1 = SAVE or Tr["Save"],
    button2 = CANCEL or Tr["Cancel"],
    hasEditBox = true,
    editBoxWidth = 420,
    OnShow = function(self, bar)
        local box = PagingBox(self)
        box:SetText(ns.PagingStart(bar.key))
        box:HighlightText()
    end,
    OnAccept = function(self, bar) SavePaging(self, bar) end,
    OnCancel = function(_, bar)
        if ns.db[bar.key] == "custom" and not tostring(ns.db[bar.key .. "Custom"]):match("%S") then
            ns.SetOption(bar.key, "default")
        end
    end,
    EditBoxOnEnterPressed = function(self, bar)
        local dialog = self:GetParent()
        SavePaging(dialog, bar)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
function ns.EditPaging(bar)
    StaticPopup_Show("MEDALLUIN_PAGING", bar.name, nil, bar)
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    local fresh = MedalluinDB == nil
    -- a character with nothing saved yet: new, so the setup wizard is owed
    ns.setupFresh = MedalluinCharDB == nil
    MedalluinDB = MedalluinDB or {}
    Migrate(fresh)
    ns.db = layered
    ns.SettleFace(ns.db.medalluinFace)
    -- the console built, until the next reload: a switch asks for one, and
    -- the settings window describes this one until it is
    ns.consoleBuilt = ns.db.consoleProfile
    if ns.consoleBuilt == "reticule" and ns.ApplyLightProfile then
        ns.ApplyLightProfile()
    end
end)

SLASH_MEDALLUIN1 = "/medalluin"
SLASH_MEDALLUIN2 = "/mui"
SLASH_MDLUI1 = "/mdlui"

local KEYBIND = { kb = true, keybind = true, keybinds = true, bind = true, binds = true }
local EDITOR = { edit = true, editor = true, frames = true }
local MOVE = { move = true, movers = true, unlock = true }
-- fixes.lua: the known-issues dialog again
local FIX = { ["fix-issues"] = true, ["fix-issue"] = true, fix = true, fixes = true, issues = true }
local SETUP = { setup = true, wizard = true }

-- /mdlui <word>: the window on that page.
local PAGES = {
    [""] = "modules", modules = "modules", module = "modules", mods = "modules",
    console = "console/general", profile = "console/general", profiles = "console/general",
    position = "console/general", scale = "console/general", place = "console/general",
    layout = "console/general", unitlayout = "console/general",
    cast = "console/general", castbars = "console/general", casting = "console/general",
    minimap = "console/minimap", map = "console/minimap",
    paging = "console/paging", page = "console/paging", pages = "console/paging",
    bar = "console/bar", actionbar = "console/bar", bars = "console/bar",
    unit = "units/general", units = "units/general", unitframe = "units/general", unitframes = "units/general",
    uf = "units/general", party = "units/party", raid = "units/raid", bg = "units/battleground",
    battleground = "units/battleground", pvp = "units/battleground", boss = "units/boss", bosses = "units/boss",
    arena = "units/arena",
    overhead = "console/overhead", top = "console/overhead",
    chat = "chat",
    side = "side", meter = "side#side/meter", loot = "side#side/loot", auras = "side#side/auras",
    windows = "windows", window = "windows",
    bags = "windows#bags", bag = "windows#bags", inventory = "windows#bags", bank = "windows#bank",
    character = "windows#character", char = "windows#character",
    inspect = "windows#inspect",
    spellbook = "windows#spellbook", spells = "windows#spellbook", book = "windows#spellbook",
    talents = "windows#talents", talent = "windows#talents",
    professions = "windows#professions", profession = "windows#professions", prof = "windows#professions",
    craft = "windows#professions",
    quests = "quests", quest = "quests", tracker = "quests",
    tray = "tray", edge = "tray",
    questlog = "windows#questlog", log = "windows#questlog",
    lfg = "windows#lfg", who = "windows#lfg", group = "windows#lfg", finder = "windows#lfg",
    npc = "windows#npc", gossip = "windows#npc", vendor = "windows#npc", merchant = "windows#npc",
    tooltip = "tooltips", tooltips = "tooltips",
}

local function OpenSettings(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%S*)")
    if (arg == "taint" or arg == "debug") and ns.TaintReport then
        ns.TaintReport()
        return
    end
    -- /mdlui mouse: what holds a frame's clicks (diag.lua)
    if arg == "mouse" and ns.TouchReport then
        ns.TouchReport()
        return
    end
    -- /mdlui probe: what the client hands this addon of the auras
    if arg == "probe" and ns.AuraProbe then
        ns.AuraProbe()
        return
    end
    if arg == "lfgdump" and ns.lfgData then
        ns.lfgData.Dump()
        return
    end
    if FIX[arg] then
        if ns.FixIssues then ns.FixIssues() end
        return
    end
    -- options/setup.lua: the setup wizard again
    if SETUP[arg] then
        if ns.OpenSetup then ns.OpenSetup() end
        return
    end
    if KEYBIND[arg] then
        if ns.KeybindMode then ns.KeybindMode() end
        return
    end
    if EDITOR[arg] then
        if ns.OpenEditor then ns.OpenEditor() end
        return
    end
    -- the consoles' movers, as Edit Mode shows them (movers.lua); again hides them
    if MOVE[arg] then
        if ns.ShowConsoleMovers then ns.ShowConsoleMovers(not ns.ConsoleMoversShown()) end
        return
    end
    if ns.OpenOptions then ns.OpenOptions(PAGES[arg]) end
end

SlashCmdList.MEDALLUIN = OpenSettings
SlashCmdList.MDLUI = OpenSettings
