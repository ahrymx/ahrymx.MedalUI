-- The game menu (Escape), in Medalluin's look: Blizzard's own buttons,
-- moved into a frame of ours and dressed, so every click stays the game's
-- (Log Out, Exit Game, Options run Blizzard's own code, untouched). Two
-- ways to stand (gameMenu):
--
--   docked (the default): a panel down the left edge, as the windows stand
--   (mockup E2, 2026-11-11; redrawn 2026-11-14: one cog, a card a row,
--   friends and the guild as tabs, the session under a clock; 2026-11-15:
--   the two tabs a strip in a window called Social)
--   +--------------------------------+
--   | (portrait)  Ahrymx         [*] |   who you are: name in class colour,
--   |             Level 24 Gnome Mage|   level, race, class; zone, guild;
--   |             Westfall · <Guild> |   the XP bar short of the last level;
--   | [=========-----   ]  62% to 25 |   the cog: the menu's own options
--   | +-* Game menu *----------- 6-+ |   a window each, always open: its word
--   | | [o| Options          new ] | |   in the top border, its note at the
--   | | [o| AddOns     42 loaded ] | |   border's end; the game's buttons a
--   | | [o| Edit Mode           ]  | |   card a row: glyph, words, a line
--   | +------------------------------+ |   under (none on a short panel), hint
--   | +-* Shortcuts *----------- 3-+ |
--   | | [o| Medalluin        /mui ] | |   ours apart, the same, their command
--   | +-* Social *------- Online-+ |   friends and the guild, one window:
--   | | Friends (3) | Guild (5)   | |   a tab each in a strip inside it, how
--   | | ==========                 | |   many it lists online in a ring, the
--   | | [message of the day]      :| |   lit one barred in gold; it takes the
--   | |  . Aldren 60 Officer      : | |   height left, its list scrolled by the
--   | +------------------------------+ |   wheel, a honeycomb behind it fading
--   | -------------------------------|   out down it (media/gamemenu-honeycomb)
--   | [ v  ] [ Return to Game ] [ x ]|   Log Out, Return (Esc), Exit Game
--   | [Log ] [      Esc       ] [Exit]
--   +--------------------------------+
--   On a short panel the cards go to a line each, then the guild's message
--   is left out, till the people have three rows.
--   A rail down its right edge, a chevron on it, folds it in at a click, as
--   does being left alone a while: it slides out to the left, the rail left
--   at the screen's edge (fading as the clock does), the camera turning
--   slowly around you till the mouse resting on the rail, or a click,
--   brings it back.
--
--   At the screen's top centre, the clock, and under it gold, the session
--   and latency; it fades a while after the menu opens, and the mouse over
--   it brings it back. The cog opens a window at the screen's centre, in the
--   game's Options' shape: its pages down the left (Sections, Friends,
--   Guild, Clock), their choices beside, each saved as it is made. Escape,
--   or a click outside it, closes it before the menu.
--
--   medallion: a ring of medallions around your character, at the screen's
--   centre: the menu's buttons an arch over it, two chains of dumbbells
--                 (o)====(o)
--          (o)====/          \====(o)          the arch: 160 to 20 degrees,
--       (o)/                        \(o)       a metal bar from each to the next
--                    (you)
--          (v)\                    /(x)        Log Out, Return to Game, Exit
--              \=====( ^ )=====/               Game: 225, 270, 315 degrees
--
--   The world is not dimmed but a little; no band, no title. "ribbon", its
--   old name, is read as it.
--
-- Shortcuts of ours join them, docked only: a slash command each
-- (Medalluin's options, the game's Cooldown Manager and Click Casting), a
-- section of their own; one nothing answers (the game's not loaded, a
-- client without it) is left out. The Medallion ring is for a controller,
-- and those windows want a mouse: it has none of them.
--
-- While it is open the rest of the interface is gone: UIParent's alpha is
-- nothing, and the frames that keep their own alpha (the strips, the minimap
-- in the corner, the tracker, the windows) follow it again until it closes.
-- Ours alone keeps its own; the world stays. A click outside it lands on it,
-- not on the buttons unseen under it.
--
-- Options and AddOns open beside it (docked), a dashboard's page: the menu
-- stays, its card lit, the game's window where the game puts it, lifted
-- over ours and drawn over the hidden interface with its tooltip, prompts
-- and dropdowns. Its close (Escape, its own) goes back to the menu as the
-- game's does; Return to Game, or another card, closes it first.
--
-- Blizzard's GameMenuFrame stays the panel the game shows and hides
-- (Escape, ShowUIPanel), made see-through and let click through; it builds
-- its buttons again each time it shows (InitButtons, from a pool), and each
-- time they are taken into ours, by what they say. Its sections (a button
-- with topPadding starts one) become ours. "game" leaves it as it is.
local _, ns = ...
local Tr = ns.L

local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local DIM = { 0.55, 0.52, 0.45 }
local RED = { 0.86, 0.27, 0.22 }
local BLUE = { 0.47, 0.75, 1 }
local DOCK_W, PAD = 360, 18
local MOTD_TOP = 20             -- the message under its heading
local WIN_TOP, WIN_PAD, WIN_GAP = 16, 12, 22   -- a window's body under its title, its sides; apart
local CARD_H = 64                              -- a card (the old look): its glyph over its words
local FOOT_H, SQUARE_W = 86, 76                -- the foot: Return to Game, Log Out and Exit either side
local ROW_H, ROW_LOW, ROW_GAP = 38, 26, 5   -- a card a row: its words and a line under; a line alone
local COG = 28                  -- the panel's cog, at its top right
local SETUP_W, SETUP_H, SETUP_NAV = 560, 400, 150   -- the cog's window; its pages' column
local FADE_AFTER, FADE_FOR, FADE_TO = 5, 1, 0.15    -- the clock: still, fading, faded
local RAIL_W = 24                           -- the rail on the panel's right edge, open or folded
local FOLD_IDLE, FOLD_FOR, DWELL = 8, 0.35, 0.25    -- folds after, slides for; the rail opens under the mouse after
local SPIN = 0.035                          -- the camera's turn while folded (MoveViewLeftStart)
-- the filter over the world behind the menu (2026-11-15): on or off, its
-- shape, its strength and its tint. A vignette (the default) leaves the
-- world's middle clear, darker out to the edges, its strength half again at
-- the corners; even, as before: docked, at the panel's edge fading out
-- across, medallion two fifths of it over the whole screen
local STRENGTHS = { 0.2, 0.35, 0.5, 0.65, 0.8 }
local TINTS = {
    { "black", Tr["Black"], { 0, 0, 0 } },
    { "night", Tr["Night"], { 0.04, 0.08, 0.20 } },
    { "dusk", Tr["Dusk"], { 0.12, 0.05, 0.18 } },
    { "ember", Tr["Ember"], { 0.22, 0.06, 0.03 } },
    { "moss", Tr["Moss"], { 0.04, 0.13, 0.06 } },
    { "gold", Tr["Gold"], { 0.24, 0.18, 0.06 } },
}
local MEDAL, BACK_MEDAL = 48, 58           -- a medallion's size; Return to Game's
local REACH = 0.30                          -- the ring's radius, of the screen's height
local ARCH_FROM, ARCH_TO = 160, 20          -- the arch's ends, in degrees, for six
local ARCH_GROW = 7                         -- each end's step out per medallion past six, to 180 and 0
local LEAVE_AT = { logout = 225, exit = 315 }
local BAR_W = 5                             -- a chain bar's thickness
local ROUND = ns.media .. "strips\\round"
local BAR = ns.media .. "gamemenu-bar"
local COMB, COMB_PX = ns.media .. "gamemenu-honeycomb", 512   -- behind the Social lists
local KEY_TOP, KEY_FOOT = { 0.341, 0.286, 0.165 }, { 0.141, 0.114, 0.055 }   -- a key's well, as the strips'
local PERSON = 26                           -- a friend's or a guild member's row
local STRIP_TOP, STRIP_H, STRIP_LOW, STRIP_GAP = 12, 28, 24, 8   -- Social's tabs, inside it under its word
local SEAM = { 0.231, 0.196, 0.125 }        -- the strip's rules, a dark gold

local menu = {}
ns.gameMenu = menu

-- Blizzard's buttons by their words: our key, the glyph (media/strips)
local function Kinds()
    return {
        { GAMEMENU_OPTIONS, "options", "menu" }, { BLIZZARD_STORE, "shop", "store" },
        { ADDONS, "addons", "misc" }, { HUD_EDIT_MODE_MENU, "edit", "view-grid" },
        { GAMEMENU_SUPPORT, "support", "help" }, { MACROS, "macros", "log" },
        { LOG_OUT, "logout", "chevron-down" }, { EXIT_GAME, "exit", "close" },
        { GAMEMENU_EXTERNALEVENT, "event", "achievement" }, { GAME_MENU_SHOW_REWARDS, "rewards", "store" },
        { GAMEMENU_NEW_BUTTON, "news", "journal" }, { RATINGS_MENU, "ratings", "statistics" },
    }
end

local function Kind(b, close)
    if b == close then return "return" end
    local text = b:GetText()
    for _, k in ipairs(Kinds()) do
        if k[1] and text == k[1] then return k[2], k[3] end
    end
    return "other", "misc"
end
menu.Kind = Kind

-- the shortcuts (docked): a slash command, its words, its glyph, and the
-- game's function opening it where no command answers
-- (and the few words on its key)
local SHORTCUTS = {
    { "/mui", "Medalluin", "achievement", nil, nil, "Medalluin", Tr["Settings for every part"] },
    { "/cdm", Tr["Cooldown Manager"], "legacy", nil, nil, Tr["Cooldowns"], Tr["The game's cooldown viewers"] },
    { "/cc", Tr["Click Casting"], "spellbook", nil, "ToggleClickBindingFrame", Tr["Click Cast"],
        Tr["Spells on a frame's click"] },
}

-- a card's line under its words (docked), by kind: what it opens
local LINES = {
    options = Tr["Graphics, sound and controls"], shop = Tr["The in-game store"], addons = Tr["Turn addons on or off"],
    edit = Tr["Move the game's frames"], support = Tr["Help and bug reports"], macros = Tr["Write and keep macros"],
    event = Tr["This season's event"], rewards = Tr["Rewards to claim"], news = Tr["What is new"],
    ratings = Tr["Rated play"],
}

local holder, docked, ring, shade
-- beside (docked): the game's window a card opens while the menu stays
local BESIDE = { options = "SettingsPanel", addons = "AddonList" }
local want                      -- the kind a click is opening beside, from its PreClick to its PostClick
local open, openKind            -- the window beside the menu, and its card's kind
local lifted                    -- that window's strata and level, to give back
local lent = {}                 -- frames given their own alpha while it is open
local clicks = {}               -- Blizzard's buttons whose clicks are hooked
local Post                      -- after a click: what stands beside the menu settled
local shortcuts = {}            -- our buttons for them, by command
local bars = {}                 -- the chains' bars, pooled
local deco = {}                 -- a button's dress, by button (no field of ours on Blizzard's)
local heads = {}                -- the docked panel's headings, pooled
local who = {}                  -- the docked panel's portrait and lines

local function FilterOn() return ns.db.gameMenuFilter ~= false end
local function Strength()
    local v = tonumber(ns.db.gameMenuFilterStrength) or 0.5
    return math.max(0, math.min(1, v))
end
local VIGNETTE = ns.media .. "gamemenu-vignette"
local function Tint()
    for _, t in ipairs(TINTS) do if t[1] == ns.db.gameMenuFilterTint then return t[3] end end
    return TINTS[1][3]
end

-- The medallion menu is being built (WIP: its choice off in Options), so a
-- profile that chose it, or the ribbon before it, is moved to the docked
-- one, and its options show that. menu.wipOpen (the harness's, testing
-- the ring as it stands) lets it through.
local WIP = { medallion = true, ribbon = true }
local function Style()
    local style = ns.db.gameMenu or "docked"
    if style == "ribbon" then style = "medallion" end
    if WIP[style] and not menu.wipOpen then
        style = "docked"
        ns.db.gameMenu = style
    end
    return style
end
menu.Style = Style

-- ------------------------------------------------------------- the dress
local function Fade(t, c, a)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], a * 0.1))
    else
        t:SetColorTexture(c[1], c[2], c[3], a * 0.55)
    end
end

-- the filter on the shade, over the world it covers (wide: docked, fading
-- out across). The vignette's strength is the shade's own alpha, times
-- the slide's (t.slide): the game left a vertex alpha unseen on it, the
-- vignette as strong at every strength
local function Paint(t, wide)
    t:SetShown(FilterOn())
    local c, a = Tint(), Strength()
    if ns.db.gameMenuFilterShape ~= "even" then
        t:SetTexture(VIGNETTE)
        if t.SetGradient and CreateColor then  -- the even shape's gradient gone
            t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 1), CreateColor(c[1], c[2], c[3], 1))
        end
        t:SetVertexColor(c[1], c[2], c[3], 1)
        t.level = math.min(1, a * 1.5)
        t:SetAlpha(t.level * (t.slide or 1))
        return
    end
    t:SetVertexColor(1, 1, 1, 1)
    t.level = 1
    t:SetAlpha(t.slide or 1)
    if wide then Fade(t, c, a) else t:SetColorTexture(c[1], c[2], c[3], a * 0.4) end
end

-- Blizzard's look put away (its slices, its words), ours drawn on the
-- button itself, so the game's highlight layer lights it under the mouse.
-- a rectangle's four sides, 1px, inset from its edge
local function Sides(r, inset, c, a)
    local top = r:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", -inset, -inset)
    top:SetHeight(1)
    local foot = r:CreateTexture(nil, "BORDER")
    foot:SetPoint("BOTTOMLEFT", inset, inset)
    foot:SetPoint("BOTTOMRIGHT", -inset, inset)
    foot:SetHeight(1)
    local left = r:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", inset, inset)
    left:SetWidth(1)
    local right = r:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", -inset, inset)
    right:SetWidth(1)
    local s = { top, foot, left, right }
    function s.Shown(on) for _, t in ipairs(s) do t:SetShown(on) end end
    for _, t in ipairs(s) do t:SetColorTexture(c[1], c[2], c[3], a) end
    return s
end

local function Dress(b)
    local d = deco[b]
    if d then return d end
    d = {}
    deco[b] = d
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    for _, r in ipairs({ b:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
    local words = b.GetFontString and b:GetFontString()
    if words then words:SetAlpha(0) end
    -- a button's box: a gold edge, an ink well, its fill when it leads
    d.edge = b:CreateTexture(nil, "BACKGROUND", nil, 4)
    d.edge:SetAllPoints()
    d.edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    d.well = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.well:SetPoint("TOPLEFT", 1, -1)
    d.well:SetPoint("BOTTOMRIGHT", -1, 1)
    d.well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    -- a key's well, lighter at its top, and the lit lip along it
    d.key = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.key:SetPoint("TOPLEFT", 1, -1)
    d.key:SetPoint("BOTTOMRIGHT", -1, 1)
    if d.key.SetGradient and CreateColor then
        d.key:SetColorTexture(1, 1, 1, 1)
        d.key:SetGradient("VERTICAL", CreateColor(KEY_FOOT[1], KEY_FOOT[2], KEY_FOOT[3], 1),
            CreateColor(KEY_TOP[1], KEY_TOP[2], KEY_TOP[3], 1))
    else
        d.key:SetColorTexture((KEY_TOP[1] + KEY_FOOT[1]) / 2, (KEY_TOP[2] + KEY_FOOT[2]) / 2,
            (KEY_TOP[3] + KEY_FOOT[3]) / 2, 1)
    end
    d.lip = b:CreateTexture(nil, "BACKGROUND", nil, 7)
    d.lip:SetPoint("TOPLEFT", 3, -2)
    d.lip:SetPoint("TOPRIGHT", -3, -2)
    d.lip:SetHeight(1)
    d.lip:SetColorTexture(1, 0.95, 0.78, 0.2)
    -- what is new, on a key: a blue dot at its top right
    d.dot = b:CreateTexture(nil, "OVERLAY")
    d.dot:SetTexture(ROUND)
    d.dot:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], 1)
    d.dot:SetSize(7, 7)
    d.dot:SetPoint("CENTER", b, "TOPRIGHT", -7, -7)
    d.fill = b:CreateTexture(nil, "BACKGROUND", nil, 6)
    d.fill:SetPoint("TOPLEFT", 1, -1)
    d.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    d.fill:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    d.glow = b:CreateTexture(nil, "HIGHLIGHT")
    d.glow:SetPoint("TOPLEFT", 1, -1)
    d.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    d.glow:SetColorTexture(1, 1, 1, 0.1)
    -- a row's glyph in its own well: the rule between it and the words, and
    -- the line under the words
    d.split = b:CreateTexture(nil, "ARTWORK")
    d.split:SetWidth(1)
    d.split:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    d.desc = ns.PlainText(b, 11)
    -- a card's and the foot's (E2): a gold wash under the mouse; a card's
    -- rule fading both ways under its glyph, its line under its words;
    -- Return to Game's inner rule
    d.gild = b:CreateTexture(nil, "HIGHLIGHT")
    d.gild:SetPoint("TOPLEFT", 1, -1)
    d.gild:SetPoint("BOTTOMRIGHT", -1, 1)
    d.gild:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.07)
    d.ruleL = b:CreateTexture(nil, "ARTWORK")
    d.ruleL:SetSize(30, 1)
    d.ruleL:SetPoint("RIGHT", b, "TOP", 0, -38)
    d.ruleR = b:CreateTexture(nil, "ARTWORK")
    d.ruleR:SetSize(30, 1)
    d.ruleR:SetPoint("LEFT", b, "TOP", 0, -38)
    Fade(d.ruleR, GOLD, 0.7)
    if d.ruleL.SetGradient and CreateColor then
        d.ruleL:SetColorTexture(1, 1, 1, 1)
        d.ruleL:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.07),
            CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.7))
    else
        d.ruleL:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.4)
    end
    d.sub = ns.Text(b, 10)
    d.inside = Sides(b, 3, GOLD, 0.3)
    -- a medallion: a gold rim, an ink well; under the mouse it lights itself
    -- (the rim bright, the well lifted), with nothing around it
    d.rim = b:CreateTexture(nil, "BACKGROUND", nil, 4)
    d.rim:SetSize(MEDAL, MEDAL)
    d.rim:SetTexture(ROUND)
    d.rim:SetVertexColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    d.inner = b:CreateTexture(nil, "BACKGROUND", nil, 5)
    d.inner:SetSize(MEDAL - 4, MEDAL - 4)
    d.inner:SetTexture(ROUND)
    d.inner:SetVertexColor(0.063, 0.059, 0.055, 1)
    d.core = b:CreateTexture(nil, "BACKGROUND", nil, 6)   -- the leading medallion's gold fill
    d.core:SetTexture(ROUND)
    d.core:SetVertexColor(0.306, 0.251, 0.125, 1)
    -- the glyph, the words, a hint at the end
    d.glyph = b:CreateTexture(nil, "ARTWORK")
    d.label = ns.Text(b, 14)
    d.hint = ns.Text(b, 11)
    local function Hot(hot)
        if d.look == "key" or d.look == "wide" then
            local c = hot and b:IsEnabled() and GOLD or GOLD_D
            d.edge:SetColorTexture(c[1], c[2], c[3], 1)
            return
        end
        if d.look == "card" or d.look == "square" or d.look == "row" then
            local c, a = d.edgeC, d.edgeA
            if hot and b:IsEnabled() then c, a = GOLD, 1 end
            d.edge:SetColorTexture(c[1], c[2], c[3], a)
            return
        end
        if d.look ~= "medal" then return end
        local lit = hot and b:IsEnabled()
        local rim = (lit or d.primary) and GOLD or GOLD_D
        d.rim:SetVertexColor(rim[1], rim[2], rim[3], 1)
        local lift = lit and 0.1 or 0
        d.inner:SetVertexColor(0.063 + lift, 0.059 + lift, 0.055 + lift * 0.6, 1)
        d.glyph:SetAlpha((lit or d.primary) and 1 or b:IsEnabled() and 0.9 or 0.35)
        d.label:SetAlpha(lit and 1 or 0.85)
    end
    d.hot = Hot
    -- a key's words are in its tooltip
    b:HookScript("OnEnter", function()
        Hot(true)
        if d.tip and (d.look == "key" or d.look == "wide") then ns.Tip(b, "ANCHOR_RIGHT", d.tip()) end
    end)
    b:HookScript("OnLeave", function()
        Hot(false)
        if d.tip and GameTooltip:IsOwned(b) then GameTooltip:Hide() end
    end)
    return d
end

-- the hint at a row's end: what is new, how many addons run
local function Hint(kind)
    local f = GameMenuFrame
    if kind == "options" and f.NewOptionsFrame and f.NewOptionsFrame:IsShown() then return "new", BLUE end
    if kind == "edit" and f.EditModeNotification and f.EditModeNotification:IsShown() then return "new", BLUE end
    if kind == "event" and f.NewExternalEventFrame and f.NewExternalEventFrame:IsShown() then return "new", BLUE end
    if kind == "addons" and C_AddOns and C_AddOns.GetNumAddOns then
        local n = 0
        for i = 1, C_AddOns.GetNumAddOns() do
            if C_AddOns.IsAddOnLoaded(i) then n = n + 1 end
        end
        return format(Tr["%d loaded"], n), DIM
    end
end

-- a card's line under its words: what is new or loaded (Hint), what it
-- opens, the macros held
-- One button drawn as a look: "row" (a card a row: its glyph in a well, its
-- words and the line under them, its hint at the end; the line left out
-- under ROW_H), "button", "primary", "key" (its glyph
-- alone, its words in its tooltip), "wide" (a key with its glyph and few
-- words), "card" (its glyph over a rule and its words; what it says more is in
-- its tooltip, 2026-11-11), "square"
-- (the foot's Log Out and Exit: the glyph over the words), "return" (the
-- foot's Return to Game, gold) or "medal" (size, and primary: the leading
-- one, gold)
local function Look(b, look, kind, glyph, size, primary)
    local d = Dress(b)
    size = size or MEDAL
    d.primary = look == "medal" and primary or false
    local on = b:IsEnabled()
    local keyed = look == "key" or look == "wide"
    local card, square, ret, row = look == "card", look == "square", look == "return", look == "row"
    local gilt = card or square or ret or row
    local boxed = look == "button" or look == "primary" or keyed or gilt
    d.edgeC, d.edgeA = GOLD_D, 1
    -- the card whose window stands beside the menu: lit, as Return to Game is
    d.held = (card or row) and openKind ~= nil and kind == openKind
    if d.held then d.edgeC = GOLD
    elseif card or row then d.edgeA = 0.7 elseif ret then d.edgeC = GOLD elseif square and kind == "exit" then
        d.edgeC = { 0.54, 0.2, 0.14 }
    end
    d.edge:SetShown(boxed)
    d.edge:SetColorTexture(d.edgeC[1], d.edgeC[2], d.edgeC[3], d.edgeA)
    d.well:SetShown(boxed and not keyed)
    if card or row then d.well:SetColorTexture(0.082, 0.071, 0.043, 1)
    else d.well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1) end
    d.key:SetShown(keyed)
    d.lip:SetShown(keyed)
    d.dot:Hide()
    d.fill:SetShown(look == "primary" or ret or d.held)
    d.glow:SetShown(boxed and not gilt)
    d.gild:SetShown(gilt)
    d.ruleL:SetShown(card)
    d.ruleR:SetShown(card)
    d.inside.Shown(ret)
    d.sub:Hide()
    d.sub:ClearAllPoints()
    d.label:SetFont(ns.font, ret and 17 or square and 12 or row and 13 or 14, "")
    d.split:SetShown(row)
    d.desc:Hide()
    d.desc:ClearAllPoints()
    local medal = look == "medal"
    d.rim:SetShown(medal)
    d.inner:SetShown(medal)
    d.core:SetShown(medal and d.primary)
    d.glyph:SetShown(glyph ~= nil)
    if glyph then d.glyph:SetTexture(ns.media .. "strips\\" .. glyph) end
    d.glyph:SetAlpha(on and 0.9 or 0.35)
    d.glyph:ClearAllPoints()
    d.label:ClearAllPoints()
    d.hint:ClearAllPoints()
    d.hint:Hide()
    d.label:SetText(look == "wide" and d.short or d.words or b:GetText() or "")
    d.label:SetShown(look ~= "key")
    local c = not on and DIM or (look == "primary" or ret or d.primary) and GOLD or kind == "exit" and RED
        or ns.colors.text
    d.label:SetTextColor(c[1], c[2], c[3])
    local gc = medal and kind == "exit" and RED or ns.colors.white
    d.glyph:SetVertexColor(gc[1], gc[2], gc[3])
    if look == "key" then
        d.glyph:SetSize(28, 28)
        d.glyph:SetPoint("CENTER")
        d.dot:SetShown(Hint(kind) == "new")
    elseif card and size < CARD_H then
        -- low: the glyph at the left, the words and their line beside it
        d.ruleL:Hide()
        d.ruleR:Hide()
        d.glyph:SetSize(22, 22)
        d.glyph:SetPoint("LEFT", 10, 0)
        d.label:SetPoint("LEFT", 40, 0)
        d.dot:SetShown(Hint(kind) == "new")
    elseif card then
        -- the glyph at the top, a rule, the words
        d.glyph:SetSize(26, 26)
        d.glyph:SetPoint("CENTER", b, "TOP", 0, -20)
        d.label:SetPoint("CENTER", b, "TOP", 0, -50)
        d.dot:SetShown(Hint(kind) == "new")
    elseif square then
        d.glyph:SetSize(24, 24)
        d.glyph:SetPoint("CENTER", b, "TOP", 0, -32)
        d.label:SetPoint("BOTTOM", 0, 14)
    elseif ret then
        -- up, the words, the key that does it too
        d.glyph:SetSize(22, 22)
        d.glyph:SetPoint("CENTER", b, "TOP", 0, -24)
        d.label:SetPoint("CENTER", 0, -6)
        d.sub:SetText("Esc")
        d.sub:SetTextColor(DIM[1], DIM[2], DIM[3])
        d.sub:SetPoint("BOTTOM", 0, 10)
        d.sub:Show()
    elseif look == "wide" then
        d.glyph:SetSize(20, 20)
        d.glyph:SetPoint("LEFT", 8, 0)
        d.label:SetPoint("LEFT", 32, 0)
        d.label:SetPoint("RIGHT", -4, 0)
        d.label:SetJustifyH("LEFT")
    elseif row then
        d.glyph:SetSize(18, 18)
        d.glyph:SetPoint("CENTER", b, "LEFT", 18, 0)
        d.split:ClearAllPoints()
        d.split:SetPoint("TOPLEFT", 35, -1)
        d.split:SetPoint("BOTTOMLEFT", 35, 1)
        local under = size >= ROW_H and d.line
        d.label:SetPoint("LEFT", 46, under and 7 or 0)
        if under then
            d.desc:SetText(under)
            d.desc:SetTextColor(DIM[1], DIM[2], DIM[3])
            d.desc:SetPoint("TOPLEFT", d.label, "BOTTOMLEFT", 0, -3)
            d.desc:Show()
        end
        local hint, hc = Hint(kind)
        if not hint and d.cmd then hint, hc = d.cmd, GOLD_D end
        if hint then
            d.hint:SetText(hint)
            d.hint:SetTextColor(hc[1], hc[2], hc[3])
            d.hint:SetPoint("RIGHT", -10, 0)
            d.hint:Show()
        end
    elseif medal then
        d.rim:ClearAllPoints()
        d.rim:SetSize(size, size)
        d.rim:SetPoint("CENTER", b, "TOP", 0, -size / 2)
        d.inner:ClearAllPoints()
        d.inner:SetSize(size - 4, size - 4)
        d.inner:SetPoint("CENTER", d.rim)
        d.core:ClearAllPoints()
        d.core:SetSize(size - 4, size - 4)
        d.core:SetPoint("CENTER", d.rim)
        d.glyph:SetSize(size / 2, size / 2)
        d.glyph:SetPoint("CENTER", d.rim)
        d.label:SetPoint("TOP", d.rim, "BOTTOM", 0, -5)
        local hint = Hint(kind)
        if hint == "new" then
            d.hint:SetText("new")
            d.hint:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
            d.hint:SetPoint("LEFT", d.rim, "TOPRIGHT", -4, -2)
            d.hint:Show()
        end
    else
        -- a box: the glyph and the words centred together
        d.label:SetPoint("CENTER", glyph and 11 or 0, 0)
        if glyph then
            d.glyph:SetSize(14, 14)
            d.glyph:SetPoint("RIGHT", d.label, "LEFT", -6, 0)
        end
    end
    d.look = look
    d.label:SetAlpha(1)
    if medal then d.hot(b.IsMouseOver and b:IsMouseOver() or false) end
end
menu.Look = Look

-- ------------------------------------------------------------ the frames
local function Hair(parent, alpha)
    return ns.window.Hair(parent, false, alpha)
end

local Relayout                  -- the docked panel laid out again, as last read

-- Hidden sections (docked), by key (2026-11-11, mockup D2): left out
-- whole, heading and all, until ticked again in the cog's Sections
local function Hidden(key)
    local h = ns.db.gameMenuHidden
    return type(h) == "table" and h[key] == true
end

local function SetHidden(key, hide)
    if type(ns.db.gameMenuHidden) ~= "table" then ns.db.gameMenuHidden = {} end
    ns.db.gameMenuHidden[key] = hide or nil
    if Relayout then Relayout() end
end
menu.Hidden, menu.SetHidden = Hidden, SetHidden

-- the sections' words, by key, in their order
local TITLES = { menu = Tr["Game menu"], shortcuts = Tr["Shortcuts"], friends = Tr["Friends"], guild = Tr["Guild"],
    clock = Tr["Clock & session"], sound = Tr["Sound"] }
local ORDER = { "menu", "shortcuts", "friends", "guild", "clock", "sound" }
menu.TITLES, menu.ORDER = TITLES, ORDER

-- A key's dress, as the strips' keys: its well lighter at the top, a dark
-- gold edge (gold under the mouse, or while held), a lip along its top.
local function Keyed(b)
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", -1, 1)
    if well.SetGradient and CreateColor then
        well:SetColorTexture(1, 1, 1, 1)
        well:SetGradient("VERTICAL", CreateColor(KEY_FOOT[1], KEY_FOOT[2], KEY_FOOT[3], 1),
            CreateColor(KEY_TOP[1], KEY_TOP[2], KEY_TOP[3], 1))
    else
        well:SetColorTexture((KEY_TOP[1] + KEY_FOOT[1]) / 2, (KEY_TOP[2] + KEY_FOOT[2]) / 2,
            (KEY_TOP[3] + KEY_FOOT[3]) / 2, 1)
    end
    local lip = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    lip:SetPoint("TOPLEFT", 3, -2)
    lip:SetPoint("TOPRIGHT", -3, -2)
    lip:SetHeight(1)
    lip:SetColorTexture(1, 0.95, 0.78, 0.22)
    b.edge, b.well = edge, well
    function b.Lit(on)
        local c = (on or b.held) and GOLD or GOLD_D
        edge:SetColorTexture(c[1], c[2], c[3], 1)
    end
    b.Lit(false)
    b:HookScript("OnEnter", function() b.Lit(true) end)
    b:HookScript("OnLeave", function() b.Lit(false) end)
end
menu.Keyed = Keyed

local Setup = {}                -- the cog's window, the menu's options (below)

-- A section's window (mockup E2, 2026-11-11; were D2's bands): ink in a
-- dark gold border, a fainter rule inside it; the section's word set in
-- the top border between two gold diamonds (or its tabs, the people's),
-- its note at the border's right end, each on a patch of the panel's ink.
-- Every section is open: nothing folds. The wheel over a window scrolls its people when they
-- overflow it.
local offset = {}               -- a window's people scrolled past, by key

-- a patch of the panel's ink, cutting the border where a word stands on it
local function Patch(h)
    local t = h:CreateTexture(nil, "BORDER", nil, 3)
    t:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    t:SetHeight(7)
    return t
end

local function Diamond(h)
    local t = h:CreateTexture(nil, "ARTWORK")
    t:SetSize(6, 6)
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    if t.SetRotation then t:SetRotation(math.pi / 4) end
    return t
end

-- a disc of the strips' round, tinted (a ring: a smaller one of ink in it)
local function Ring(l, size, c)
    local t = l:CreateTexture(nil, "ARTWORK")
    t:SetTexture(ROUND)
    t:SetSize(size, size)
    t:SetVertexColor(c[1], c[2], c[3])
    return t
end

-- the wheel over a window, or a row in it: its people a row on or back
local function Wheel(h, delta)
    if not (h and h.key and h.most and h.most > 0) then return end
    local at = math.max(0, math.min(h.most, (offset[h.key] or 0) - delta))
    if at == (offset[h.key] or 0) then return end
    offset[h.key] = at
    if Relayout then Relayout() end
end

local function Window(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, docked)
    h:SetFrameLevel(docked:GetFrameLevel() + 1)
    local ink = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetAllPoints()
    ink:SetColorTexture(0.051, 0.043, 0.027, 0.88)
    Sides(h, 0, GOLD_D, 1)
    Sides(h, 3, GOLD_D, 0.35)
    -- the honeycomb behind its people (the Social window's), fading down
    h.comb = h:CreateTexture(nil, "BACKGROUND", nil, 2)
    h.comb:SetTexture(COMB)
    h.comb:Hide()
    -- the word between its diamonds, on the top border
    h.patch = Patch(h)
    h.patch:SetPoint("LEFT", h, "TOPLEFT", 12, 0)
    h.left = Diamond(h)
    h.left:SetPoint("CENTER", h, "TOPLEFT", 20, 0)
    h.word = ns.Text(h, 14)
    h.word:SetPoint("LEFT", h, "TOPLEFT", 30, 0)
    h.word:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    h.right = Diamond(h)
    -- the tabs (the Social window's, 2026-11-15): a strip just inside it,
    -- under its word, a half each; a word and its count in a ring, the lit
    -- one gold over a wash, a gold bar under it; a click shows its list
    h.tabs = {}
    for t = 1, 2 do
        local b = CreateFrame("Button", nil, h)
        b:RegisterForClicks("LeftButtonUp")
        b.wash = b:CreateTexture(nil, "BACKGROUND")
        b.wash:SetAllPoints()
        if b.wash.SetGradient and CreateColor then
            b.wash:SetColorTexture(1, 1, 1, 1)
            b.wash:SetGradient("VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0),
                CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.10))
        else
            b.wash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.05)
        end
        b.bar = b:CreateTexture(nil, "ARTWORK", nil, 2)
        b.bar:SetHeight(2)
        b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        b.word = ns.Text(b, 14)
        b.ring = Ring(b, 18, SEAM)
        b.ring:SetPoint("LEFT", b.word, "RIGHT", 6, 0)
        b.well = Ring(b, 16, ns.colors.ink)
        b.well:SetDrawLayer("ARTWORK", 1)
        b.well:SetPoint("CENTER", b.ring)
        b.count = ns.PlainText(b, 10)
        b.count:SetDrawLayer("OVERLAY")
        b.count:SetPoint("CENTER", b.ring, "CENTER", 0, 0)
        function b.Lit(hot)
            local c = b.on and GOLD or hot and ns.colors.text or DIM
            b.word:SetTextColor(c[1], c[2], c[3])
            local cc = (b.on or hot) and ns.colors.text or DIM
            b.count:SetTextColor(cc[1], cc[2], cc[3])
            local rc = b.on and GOLD_D or SEAM
            b.ring:SetVertexColor(rc[1], rc[2], rc[3])
            b.wash:SetShown(b.on == true)
            b.bar:SetShown(b.on == true)
        end
        b:SetScript("OnEnter", function(self) self.Lit(true) end)
        b:SetScript("OnLeave", function(self) self.Lit(false) end)
        b:SetScript("OnClick", function(self)
            if self.on then return end
            ns.db.gameMenuTab = self.key
            if Relayout then Relayout() end
        end)
        h.tabs[t] = b
    end
    -- the rule between the tabs, and the one under the strip
    h.sep = h:CreateTexture(nil, "ARTWORK")
    h.sep:SetWidth(1)
    h.sep:SetColorTexture(SEAM[1], SEAM[2], SEAM[3], 1)
    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetHeight(1)
    h.rule:SetColorTexture(SEAM[1], SEAM[2], SEAM[3], 1)
    h.note = ns.Text(h, 11)
    h.note:SetPoint("RIGHT", h, "TOPRIGHT", -14, 0)
    h.note:SetTextColor(DIM[1], DIM[2], DIM[3])
    h.note.patch = Patch(h)
    h.note.patch:SetPoint("RIGHT", h.note, "RIGHT", 4, 0)
    -- its people's scroll: a dark track down its right, a gold thumb
    h.track = h:CreateTexture(nil, "ARTWORK")
    h.track:SetWidth(3)
    h.track:SetColorTexture(0, 0, 0, 0.6)
    h.thumb = h:CreateTexture(nil, "ARTWORK", nil, 1)
    h.thumb:SetWidth(3)
    h.thumb:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    -- its people from first + 1, fit of total shown in a body body tall
    -- from top (the window's own y): the bar when they overflow
    function h.Scroll(first, fit, total, top, body)
        local on = total > fit
        h.track:SetShown(on)
        h.thumb:SetShown(on)
        if not on then return end
        h.track:ClearAllPoints()
        h.track:SetPoint("TOPRIGHT", h, "TOPRIGHT", -6, -top)
        h.track:SetHeight(body)
        local tall = math.max(12, math.floor(body * fit / total))
        h.thumb:ClearAllPoints()
        h.thumb:SetPoint("TOPRIGHT", h, "TOPRIGHT", -6, -top - math.floor((body - tall) * first / (total - fit)))
        h.thumb:SetHeight(tall)
    end
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", Wheel)
    heads[i] = h
    return h
end

-- a window set: where it stands (y from the panel's top) and how tall, its
-- word, note and key (its scroll); and tabs ({ key, word, count, on }
-- each), a strip strip tall under the word (the Social window)
local function Win(n, y, tall, word, note, key, tabs, strip)
    local h = Window(n)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", docked, "TOPLEFT", PAD, y)
    h:SetPoint("TOPRIGHT", docked, "TOPRIGHT", -PAD, y)
    h:SetHeight(tall)
    h.key, h.most = key, 0
    h.word:SetText(word or "")
    h.word:Show()
    local ww = math.ceil(h.word:GetStringWidth() or 0)
    h.sep:Hide()
    h.rule:SetShown(tabs ~= nil)
    local across = DOCK_W - 2 * PAD - 8
    local each = tabs and math.floor(across / #tabs) or 0
    strip = strip or STRIP_H
    for t, b in ipairs(h.tabs) do
        local tab = tabs and tabs[t]
        b:SetShown(tab ~= nil)
        if tab then
            b.key, b.on = tab[1], tab[4]
            b.word:SetText(tab[2])
            b.count:SetText(tostring(tab[3]))
            local cw = math.ceil(b.count:GetStringWidth() or 0)
            b.ring:SetWidth(math.max(18, cw + 8))
            b.well:SetWidth(math.max(16, cw + 6))
            local bw = math.ceil((b.word:GetStringWidth() or 0) + 6 + math.max(18, cw + 8))
            local x = 4 + (t - 1) * each
            local w = t == #tabs and across - (t - 1) * each or each
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", h, "TOPLEFT", x, -STRIP_TOP)
            b:SetSize(w, strip)
            b.word:ClearAllPoints()
            b.word:SetPoint("LEFT", b, "LEFT", math.floor((w - bw) / 2), 0)
            b.bar:ClearAllPoints()
            b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", math.floor(w * 0.18), 0)
            b.bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -math.floor(w * 0.18), 0)
            b.Lit(false)
            if t > 1 then
                h.sep:ClearAllPoints()
                h.sep:SetPoint("TOPLEFT", h, "TOPLEFT", x, -STRIP_TOP - 4)
                h.sep:SetHeight(strip - 8)
                h.sep:Show()
            end
        end
    end
    if tabs then
        h.rule:ClearAllPoints()
        h.rule:SetPoint("TOPLEFT", h, "TOPLEFT", 4, -STRIP_TOP - strip)
        h.rule:SetPoint("TOPRIGHT", h, "TOPRIGHT", -4, -STRIP_TOP - strip)
    end
    h.patch:SetWidth(ww + 34)
    h.right:ClearAllPoints()
    h.right:SetPoint("CENTER", h, "TOPLEFT", 40 + ww, 0)
    h.note:SetText(note or "")
    h.note:SetShown(note ~= nil)
    h.note.patch:SetShown(note ~= nil)
    h.note.patch:SetWidth(math.ceil(h.note:GetStringWidth() or 0) + 8)
    h.Scroll(0, 0, 0)
    h.comb:Hide()
    h:Show()
    return h
end

local function Build()
    holder = CreateFrame("Frame", "MedalluinGameMenu", UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetFrameLevel(20)
    holder:SetAllPoints(UIParent)
    holder:Hide()
    if holder.SetIgnoreParentAlpha then holder:SetIgnoreParentAlpha(true) end
    holder:EnableMouse(true)
    -- the world dimmed behind it
    shade = holder:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    -- docked: down the whole left edge, ink, a gold edge on its right
    docked = CreateFrame("Frame", nil, holder)
    docked:SetWidth(DOCK_W)
    docked:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    docked:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    docked:EnableMouse(true)
    local well = docked:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetAllPoints()
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.97)
    local edge = docked:CreateTexture(nil, "BACKGROUND", nil, 2)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    who.ring = ns.window.Ring(docked, 56)
    who.ring:SetPoint("TOPLEFT", PAD + 4, -PAD - 4)
    who.name = ns.PlainText(docked, 20)
    who.name:SetPoint("TOPLEFT", PAD + 74, -PAD - 6)
    who.what = ns.PlainText(docked, 12)
    who.what:SetPoint("TOPLEFT", who.name, "BOTTOMLEFT", 0, -6)
    who.what:SetTextColor(DIM[1], DIM[2], DIM[3])
    who.where = ns.PlainText(docked, 12)
    who.where:SetPoint("TOPLEFT", who.what, "BOTTOMLEFT", 0, -4)
    who.where:SetTextColor(DIM[1], DIM[2], DIM[3])
    -- the XP bar under who you are: ink in a gold edge, the XP purple, the
    -- rested past it blue; its words under it
    local xp = CreateFrame("Frame", nil, docked)
    xp:SetPoint("TOPLEFT", PAD, -(PAD + 76))
    xp:SetPoint("TOPRIGHT", -PAD, -(PAD + 76))
    xp:SetHeight(8)
    local e = xp:CreateTexture(nil, "BACKGROUND", nil, 1)
    e:SetAllPoints()
    e:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local ink = xp:CreateTexture(nil, "BACKGROUND", nil, 2)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(0.043, 0.035, 0.024, 1)
    xp.fill = xp:CreateTexture(nil, "ARTWORK", nil, 2)
    xp.fill:SetPoint("TOPLEFT", 1, -1)
    xp.fill:SetPoint("BOTTOMLEFT", 1, 1)
    xp.fill:SetColorTexture(0.55, 0.30, 0.82, 1)
    xp.rest = xp:CreateTexture(nil, "ARTWORK", nil, 1)
    xp.rest:SetPoint("TOPLEFT", xp.fill, "TOPRIGHT")
    xp.rest:SetPoint("BOTTOMLEFT", xp.fill, "BOTTOMRIGHT")
    xp.rest:SetColorTexture(0.23, 0.37, 0.69, 0.55)
    xp.left = ns.PlainText(xp, 11)
    xp.left:SetPoint("TOPLEFT", xp, "BOTTOMLEFT", 0, -4)
    xp.left:SetTextColor(DIM[1], DIM[2], DIM[3])
    xp.right = ns.PlainText(xp, 11)
    xp.right:SetPoint("TOPRIGHT", xp, "BOTTOMRIGHT", 0, -4)
    xp.right:SetTextColor(0.48, 0.61, 0.88)
    who.xp = xp
    -- the cog, at the panel's top right: the menu's options, centred
    local cog = CreateFrame("Button", nil, docked)
    cog:SetSize(COG, COG)
    cog:SetPoint("TOPRIGHT", -PAD, -PAD - 4)
    cog:SetFrameLevel(docked:GetFrameLevel() + 4)
    cog:RegisterForClicks("LeftButtonUp")
    Keyed(cog)
    cog.glyph = cog:CreateTexture(nil, "ARTWORK")
    cog.glyph:SetSize(16, 16)
    cog.glyph:SetPoint("CENTER")
    cog.glyph:SetTexture(ns.media .. "strips\\menu")
    local lit = cog.Lit
    function cog.Lit(on)
        lit(on)
        local c = (on or cog.held) and GOLD or { 1, 1, 1 }
        cog.glyph:SetVertexColor(c[1], c[2], c[3], (on or cog.held) and 1 or 0.65)
    end
    cog.Lit(false)
    cog:SetScript("OnClick", function() Setup.Toggle() end)
    cog:SetScript("OnEnter", function(self)
        self.Lit(true)
        ns.Tip(self, "ANCHOR_RIGHT", { title = Tr["Game menu options"],
            { "hint", Tr["Sections, friends, guild, clock."] } })
    end)
    cog:SetScript("OnLeave", function(self)
        self.Lit(false)
        GameTooltip_Hide()
    end)
    who.cog = cog
    local foot = Hair(docked)
    foot:SetPoint("BOTTOMLEFT", PAD, PAD + FOOT_H + 12)
    foot:SetPoint("BOTTOMRIGHT", -PAD, PAD + FOOT_H + 12)
    -- medallion: a point at the screen's centre the ring stands around; the
    -- chains' bars are its, the medallions over them
    ring = CreateFrame("Frame", nil, holder)
    ring:SetSize(1, 1)
    ring:SetPoint("CENTER", UIParent, "CENTER")
    menu.holder, menu.docked, menu.ring, menu.bars, menu.cog = holder, docked, ring, bars, cog
    menu.shade = shade
end

-- who you are, at the docked panel's top
local function Who()
    if SetPortraitTexture then
        SetPortraitTexture(who.ring, "player")
        who.ring:SetTexCoord(0, 1, 0, 1)
    end
    local name = UnitName("player") or ""
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    who.name:SetText(name)
    if c then who.name:SetTextColor(c.r, c.g, c.b) else who.name:SetTextColor(unpack(ns.colors.text)) end
    local race = UnitRace and UnitRace("player") or ""
    local className = UnitClass("player") or ""
    who.what:SetText(format(Tr["Level %d  %s  %s"], UnitLevel("player") or 0, race, className))
    local guild = GetGuildInfo and GetGuildInfo("player")
    local zone = GetZoneText and GetZoneText() or ""
    who.where:SetText(zone .. (guild and ("  \194\183  <" .. guild .. ">") or ""))
    -- the XP bar, short of the last level
    local xp, level = who.xp, UnitLevel("player") or 0
    local top = GetMaxPlayerLevel and GetMaxPlayerLevel() or 0
    local cur, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
    local on = level < top and max > 0
    xp:SetShown(on)
    if on then
        local w = math.max(1, (xp:GetWidth() or (DOCK_W - 2 * PAD)) - 2)
        local rest = math.min(GetXPExhaustion and GetXPExhaustion() or 0, max - cur)
        xp.fill:SetWidth(math.max(0.01, w * cur / max))
        xp.rest:SetWidth(math.max(0.01, w * rest / max))
        xp.rest:SetShown(rest > 0)
        xp.left:SetText(format(Tr["%d%% to %d"], math.floor(cur / max * 100), level + 1))
        xp.right:SetText(rest > 0 and format(Tr["rested %d%%"], math.floor(rest / max * 100)) or "")
    end
    return on
end

-- Blizzard's buttons, read as it lays them: sections (topPadding starts
-- one), and each button's kind
local function Read()
    local f = GameMenuFrame
    local close = f.closeButton
    local sections, leave, back = {}, {}, nil
    local cur
    for _, b in ipairs(f.buttons or {}) do
        local kind, glyph = Kind(b, close)
        if kind == "return" then
            back = b
        elseif kind == "logout" or kind == "exit" then
            table.insert(leave, { b = b, kind = kind, glyph = glyph })
        else
            if not cur or b.topPadding then
                cur = {}
                table.insert(sections, cur)
            end
            table.insert(cur, { b = b, kind = kind, glyph = glyph })
        end
    end
    return sections, leave, back
end
menu.Read = Read

-- What a slash command runs: the chat box's own table of them first (the
-- game's commands it has met), then the handler whose SLASH_ names it; nil
-- when nothing answers it
local function Handler(cmd)
    local hash = _G.hash_SlashCmdList
    if type(hash) == "table" and type(hash[cmd:upper()]) == "function" then return hash[cmd:upper()] end
    if type(SlashCmdList) ~= "table" then return nil end
    cmd = cmd:lower()
    for key, fn in pairs(SlashCmdList) do
        local i = 1
        while true do
            local name = _G["SLASH_" .. key .. i]
            if type(name) ~= "string" then break end
            if name:lower() == cmd then return fn end
            i = i + 1
        end
    end
end
menu.Handler = Handler

-- What a shortcut runs: its command's handler, else the game's function
local function Runs(sc)
    local fn = Handler(sc[1])
    if fn then return function() fn("") end end
    local game = sc[5] and _G[sc[5]]
    if type(game) == "function" then return game end
end

-- Our shortcut buttons (docked), those something answers: the menu closes, then the
-- command runs as if typed. They hold no words of their own (a button's
-- own would show in the game's yellow under the mouse): ours, in the dress.
local function Shortcuts(wanted)
    local out = {}
    for _, sc in ipairs(SHORTCUTS) do
        local cmd = sc[1]
        local b = shortcuts[cmd]
        if wanted and Runs(sc) then
            if not b then
                b = CreateFrame("Button", nil, holder)
                b:RegisterForClicks("LeftButtonUp")
                b:SetScript("OnClick", function()
                    local run = Runs(sc)
                    Post()      -- a window beside the menu goes with it
                    HideUIPanel(GameMenuFrame)
                    if run then run() end
                end)
                shortcuts[cmd] = b
            end
            local d = Dress(b)
            d.words, d.short, d.cmd = sc[2], sc[6], cmd
            d.tip = function() return { title = sc[2], { "hint", cmd } } end
            b:Show()
            table.insert(out, { b = b, kind = "shortcut", glyph = sc[3], hint = cmd, line = sc[7] })
        elseif b then
            b:Hide()
        end
    end
    return out
end
menu.Shortcuts = Shortcuts
function menu.Words(b) return deco[b] and (deco[b].words or deco[b].label:GetText()) end
function menu.Deco(b) return deco[b] end
function menu.Command(b) return deco[b] and deco[b].cmd end

local function Take(b, parent)
    b:SetParent(parent)
    b:ClearAllPoints()
end

-- ------------------------------------------------------------ the people
-- Friends and the guild (docked, mockup C2c): a row each, a status dot,
-- the name in its class's colour, the level (and rank), where they are;
-- under the mouse, Whisper and Invite in where's place. A click whispers.
local rows = {}                 -- pooled people rows
local social = {}               -- the guild's name and its message box
local STATUS = { online = { 0.25, 0.75, 0.31 }, afk = { 0.88, 0.69, 0.19 }, dnd = { 0.82, 0.25, 0.19 },
    offline = { 0.45, 0.43, 0.40 } }
local started = GetTime and GetTime() or 0

-- a class's token from its name in the game's words (friends give the words)
local function ClassFile(name)
    if not name then return nil end
    for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for file, words in pairs(list) do
            if words == name then return file end
        end
    end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[name] and name or nil
end

local function Whisper(p)
    HideUIPanel(GameMenuFrame)
    if p.bnet and ChatFrame_SendBNetTell then ChatFrame_SendBNetTell(p.bnet)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(p.name) end
end

local function Invite(p)
    if not p.invite then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(p.invite)
    elseif InviteUnit then InviteUnit(p.invite) end
end

-- a small key on a row: its glyph, a tooltip, the click
local function SmallKey(row, glyph, words, run)
    local k = CreateFrame("Button", nil, row)
    k:SetSize(26, 20)
    k:RegisterForClicks("LeftButtonUp")
    local d = Dress(k)
    Look(k, "key", "other", glyph)
    d.glyph:SetSize(18, 18)
    d.tip = function() return { title = words } end
    k:SetScript("OnClick", function() if row.person then run(row.person) end end)
    k:HookScript("OnLeave", function() if not row:IsMouseOver() then row.Lit(false) end end)
    return k
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, docked)
    r:SetHeight(PERSON)
    r:SetFrameLevel(docked:GetFrameLevel() + 3)
    r:RegisterForClicks("LeftButtonUp")
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) Wheel(r.win, delta) end)
    r.wash = r:CreateTexture(nil, "BACKGROUND")
    r.wash:SetAllPoints()
    Fade(r.wash, GOLD_D, 0.3)
    r.wash:Hide()
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetTexture(ROUND)
    r.dot:SetSize(8, 8)
    r.dot:SetPoint("LEFT", 8, 0)
    r.nick = ns.PlainText(r, 13)
    r.nick:SetPoint("LEFT", 22, 0)
    r.lvl = ns.PlainText(r, 11)
    r.lvl:SetPoint("LEFT", r.nick, "RIGHT", 6, 0)
    r.lvl:SetTextColor(DIM[1], DIM[2], DIM[3])
    r.where = ns.PlainText(r, 11)
    r.where:SetPoint("RIGHT", -8, 0)
    r.where:SetPoint("LEFT", r.lvl, "RIGHT", 8, 0)
    r.where:SetJustifyH("RIGHT")
    r.where:SetTextColor(DIM[1], DIM[2], DIM[3])
    r.where:SetWordWrap(false)
    r.invite = SmallKey(r, "character", Tr["Invite"], Invite)
    r.invite:SetPoint("RIGHT", -4, 0)
    r.whisper = SmallKey(r, "chat", Tr["Whisper"], Whisper)
    r.whisper:SetPoint("RIGHT", r.invite, "LEFT", -3, 0)
    function r.Lit(on)
        r.wash:SetShown(on)
        r.where:SetShown(not on)
        r.whisper:SetShown(on)
        r.invite:SetShown(on and r.person and r.person.invite ~= nil)
    end
    r:SetScript("OnEnter", function() r.Lit(true) end)
    r:SetScript("OnLeave", function()
        if not (r.whisper:IsMouseOver() or r.invite:IsMouseOver()) then r.Lit(false) end
    end)
    r:SetScript("OnClick", function() if r.person and not r.person.more then Whisper(r.person) end end)
    r.Lit(false)
    rows[i] = r
    return r
end

-- a row set to a person, or to a word (none to show), in its window
local function Person(i, y, p, win)
    local r = Row(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", PAD + 4, y)
    r:SetPoint("TOPRIGHT", -PAD - 10, y)
    r.person, r.win = p, win
    r.Lit(false)
    if p.more then
        r.dot:Hide()
        r.nick:SetText(p.more)
        r.nick:SetTextColor(DIM[1], DIM[2], DIM[3])
        r.lvl:SetText("")
        r.where:SetText("")
        r:EnableMouse(false)
    else
        local c = STATUS[p.status] or STATUS.online
        r.dot:SetVertexColor(c[1], c[2], c[3], 1)
        r.dot:Show()
        r.nick:SetText(p.name)
        local cc = p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
        if p.status == "offline" then r.nick:SetTextColor(DIM[1], DIM[2], DIM[3])
        elseif cc then r.nick:SetTextColor(cc.r, cc.g, cc.b)
        else r.nick:SetTextColor(unpack(ns.colors.text)) end
        r.lvl:SetText((p.level and p.level > 0 and p.level or "") .. (p.rank and ("  " .. p.rank) or ""))
        r.where:SetText(p.where or "")
        r:EnableMouse(true)
    end
    r:Show()
    return r
end

local function Clean(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

-- the friends, by the filter: "online" (in WoW, online), "all", or "bnet"
-- People in the order chosen (ns.db.gameMenuFriendsSort, gameMenuGuildSort):
-- "name", "level" (high first), "zone", or "rank" (the guild's, from its
-- top); the offline after the online always, ties by name
local function Ordered(list, by)
    local function key(p)
        if by == "level" then return -(tonumber(p.level) or 0) end
        if by == "zone" then return (p.where or ""):lower() end
        if by == "rank" then return p.rankIndex or 99 end
        return 0
    end
    table.sort(list, function(a, b)
        if (a.status == "offline") ~= (b.status == "offline") then return b.status == "offline" end
        local ka, kb = key(a), key(b)
        if ka ~= kb then return ka < kb end
        return a.name < b.name
    end)
    return list
end

local function Friends(filter)
    local out, online = {}, 0
    if filter == "bnet" then
        if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return out, 0 end
        for i = 1, BNGetNumFriends() or 0 do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            local g = a and a.gameAccountInfo
            if g and g.isOnline then
                online = online + 1
                local wow = g.clientProgram == (BNET_CLIENT_WOW or "WoW")
                table.insert(out, { name = Clean(wow and g.characterName) or Clean(a.accountName) or "?",
                    class = ClassFile(Clean(g.className)), level = Clean(g.characterLevel),
                    where = Clean(wow and g.areaName) or Clean(g.richPresence) or "",
                    status = a.isAFK and "afk" or a.isDND and "dnd" or "online",
                    bnet = Clean(a.accountName), invite = wow and Clean(g.characterName) or nil })
            end
        end
        return Ordered(out, ns.db.gameMenuFriendsSort), online
    end
    -- Online and All: the character friends, and the Battle.net friends
    -- playing WoW, a character each (most friends are Battle.net's; the
    -- list was empty without them, 2026-11-11)
    local seen = {}
    for i = 1, C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0 do
        local f = C_FriendList.GetFriendInfoByIndex(i)
        local name = f and Clean(f.name)
        if name then
            if f.connected then online = online + 1 end
            if f.connected or filter == "all" then
                table.insert(out, { name = name, class = ClassFile(Clean(f.className)), level = Clean(f.level),
                    where = f.connected and Clean(f.area) or "offline",
                    status = not f.connected and "offline" or f.afk and "afk" or f.dnd and "dnd" or "online",
                    invite = f.connected and name or nil })
                seen[name] = true
            end
        end
    end
    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        for i = 1, BNGetNumFriends() or 0 do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            local g = a and a.gameAccountInfo
            local name = g and g.isOnline and g.clientProgram == (BNET_CLIENT_WOW or "WoW") and Clean(g.characterName)
            if name and not seen[name] then
                seen[name] = true
                online = online + 1
                table.insert(out, { name = name, class = ClassFile(Clean(g.className)), level = Clean(g.characterLevel),
                    where = Clean(g.areaName) or "", status = a.isAFK and "afk" or a.isDND and "dnd" or "online",
                    bnet = Clean(a.accountName), invite = name })
            end
        end
    end
    return Ordered(out, ns.db.gameMenuFriendsSort), online
end
menu.Friends = Friends

-- the guild's online members, but you; and how many it has
-- Which of the guild are listed (2026-11-11), by ns.db.gameMenuGuild:
-- "officers", its top ranks (the leader, rank 0, the rank under it, and
-- any rank named an officer's); "all"; or "ranks", those picked by name in
-- ns.db.gameMenuGuildRanks (by name: a rank's index moves when ranks are
-- added), the top ranks until any is picked. The rest are counted, not
-- listed.
local function Top(rank, index)
    if type(index) == "number" and index <= 1 then return true end
    return type(rank) == "string" and rank:lower():find("officer", 1, true) ~= nil
end

local function Picked(rank, index)
    local picked = ns.db.gameMenuGuildRanks
    if type(picked) ~= "table" then return Top(rank, index) end
    return picked[rank] == true
end

local function Wanted(mode, rank, index)
    if mode == "all" then return true end
    if mode == "ranks" then return Picked(rank, index) end
    return Top(rank, index)
end

-- the members listed, the roster's size, how many are online, and the
-- guild's ranks ({ index, name }, in order) as the roster names them
local function Guild(mode)
    local out, total, on = {}, GetNumGuildMembers and GetNumGuildMembers() or 0, 0
    local me = UnitName("player")
    local seen, ranks = {}, {}
    for i = 1, total do
        local name, rank, index, level, _, zone, _, _, online, status, class = GetGuildRosterInfo(i)
        name, rank, index = Clean(name), Clean(rank), Clean(index)
        if type(rank) == "string" and not seen[rank] then
            seen[rank] = true
            table.insert(ranks, { index = type(index) == "number" and index or 99, name = rank })
        end
        local short = name and (Ambiguate and Ambiguate(name, "guild") or name:match("^[^-]+"))
        if online then on = on + 1 end
        if short and online and short ~= me and Wanted(mode, rank, index) then
            table.insert(out, { name = short, rank = rank, rankIndex = type(index) == "number" and index or 99,
                level = Clean(level), where = Clean(zone) or "", class = Clean(class),
                status = (status == 1 or status == "<AFK>") and "afk" or (status == 2 or status == "<DND>") and "dnd"
                    or "online", invite = name })
        end
    end
    Ordered(out, ns.db.gameMenuGuildSort)
    table.sort(ranks, function(a, b) return a.index < b.index end)
    return out, total, on, ranks
end
menu.Guild = Guild

-- A rank chip toggled: the picks begin from what was shown (the top ranks)
local function Pick(rank, ranks)
    local picked = ns.db.gameMenuGuildRanks
    if type(picked) ~= "table" then
        picked = {}
        for _, r in ipairs(ranks) do
            if Top(r.name, r.index) then picked[r.name] = true end
        end
        ns.db.gameMenuGuildRanks = picked
    end
    picked[rank.name] = not picked[rank.name] or nil
end

local function Money(m)
    local g, sv = math.floor(m / 10000), math.floor(m / 100) % 100
    local gs = BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)
    return format(Tr["%sg %ds"], gs, sv)
end

local function Since()
    local t = math.floor((GetTime and GetTime() or 0) - started)
    local h, m = math.floor(t / 3600), math.floor(t / 60) % 60
    return h > 0 and format(Tr["%dh %dm"], h, m) or format(Tr["%dm"], m)
end

local function Latency()
    if not GetNetStats then return "?" end
    local _, _, home = GetNetStats()
    return format(Tr["%d ms"], home or 0)
end

-- ------------------------------------------------------------- the clock
-- The time at the screen's top centre (docked), and under it the session's
-- numbers (gold, how long played, latency): full as the menu opens, faded
-- FADE_AFTER seconds on, back while the mouse is over it.
local clock

-- the time as the clock shows it: this computer's (date), or the realm's
local function Stamp()
    local h, m
    if ns.db.gameMenuClockRealm and GetGameTime then
        h, m = GetGameTime()
    else
        local hh, mm = tostring(date and date("%H:%M") or ""):match("(%d+):(%d+)")
        h, m = tonumber(hh) or 0, tonumber(mm) or 0
    end
    if ns.db.gameMenuClock24 ~= false then return format("%02d:%02d", h, m) end
    return format("%d:%02d %s", h % 12 == 0 and 12 or h % 12, m, h < 12 and "am" or "pm")
end
menu.Stamp = Stamp

local function SessionLine()
    local dot = "|cff8a7034  \194\183  |r"
    return "|cfff0d488" .. Money(GetMoney and GetMoney() or 0) .. "|r" .. dot .. format(Tr["Session %s"], Since())
        .. dot .. Latency()
end

local function ClockDraw()
    clock.time:SetText(Stamp())
    local on = ns.db.gameMenuSession ~= false
    clock.line:SetText(on and SessionLine() or "")
    clock.line:SetShown(on)
    clock.ruleL:SetShown(on)
    clock.ruleR:SetShown(on)
end

-- its alpha, by how long it has stood still with the mouse off it
local function ClockFade()
    local a = 1
    if ns.db.gameMenuClockFade ~= false and not clock.over then
        local past = clock.idle - FADE_AFTER
        if past > 0 then a = 1 - (1 - FADE_TO) * math.min(1, past / FADE_FOR) end
    end
    clock:SetAlpha(a)
end

local function Clock()
    if clock then return clock end
    clock = CreateFrame("Frame", nil, holder)
    clock:SetSize(320, 74)
    clock:SetPoint("TOP", UIParent, "TOP", 0, -24)
    clock:SetFrameLevel(docked:GetFrameLevel() + 2)
    clock:EnableMouse(true)
    clock.time = ns.Text(clock, 30)
    clock.time:SetPoint("TOP", 0, -4)
    clock.time:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    -- a short gold rule under the time, fading out both ways
    clock.ruleL = clock:CreateTexture(nil, "ARTWORK")
    clock.ruleL:SetSize(60, 1)
    clock.ruleL:SetPoint("TOPRIGHT", clock.time, "BOTTOM", 0, -8)
    clock.ruleR = clock:CreateTexture(nil, "ARTWORK")
    clock.ruleR:SetSize(60, 1)
    clock.ruleR:SetPoint("TOPLEFT", clock.time, "BOTTOM", 0, -8)
    Fade(clock.ruleR, GOLD_D, 1)
    if clock.ruleL.SetGradient and CreateColor then
        clock.ruleL:SetColorTexture(1, 1, 1, 1)
        clock.ruleL:SetGradient("HORIZONTAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.1),
            CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1))
    else
        clock.ruleL:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.55)
    end
    clock.line = ns.PlainText(clock, 12)
    clock.line:SetPoint("TOP", clock.time, "BOTTOM", 0, -16)
    clock.line:SetTextColor(DIM[1], DIM[2], DIM[3])
    clock.idle, clock.tick = 0, 0
    clock:SetScript("OnUpdate", function(self, elapsed)
        self.tick = self.tick + elapsed
        if self.tick >= 1 then
            self.tick = 0
            ClockDraw()
        end
        self.idle = self.idle + elapsed
        ClockFade()
    end)
    clock:SetScript("OnEnter", function(self)
        self.over = true
        ClockFade()
    end)
    clock:SetScript("OnLeave", function(self)
        self.over, self.idle = false, 0
        ClockFade()
    end)
    -- each time the menu opens: full again
    holder:HookScript("OnShow", function()
        clock.idle, clock.tick = 0, 0
        ClockFade()
    end)
    menu.clock = clock
    return clock
end

-- ------------------------------------------------------------ the fold
-- The docked panel folds in (2026-11-15): a rail down its right edge, a
-- chevron between two diamonds, slides with it. A click on it, or
-- FOLD_IDLE seconds with the mouse off it and the panel (nothing beside,
-- no options open), slides the panel out to the left, the world undimmed,
-- the rail left at the screen's edge, its chevron turned out. The rail
-- fades as the clock does, open or folded, but always: the clock's Fade
-- option is the clock's alone. Folded, the mouse resting on
-- it, or a click, slides the panel back. While folded the
-- camera turns slowly around you (gameMenuSpin), stopped as it opens or
-- the menu closes. Each opening of the menu starts it unfolded.
local fold = { p = 0, want = false, idle = 0, rest = 0, dwell = 0, spinning = false }
menu.fold = fold

local function Chevron(parent, size, turn)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(ns.media .. "strips\\chevron-up")
    if t.SetRotation then t:SetRotation(turn) end
    return t
end

local function Spin(on)
    on = on and ns.db.gameMenuSpin ~= false and MoveViewLeftStart ~= nil
    if on == fold.spinning then return end
    fold.spinning = on
    if on then MoveViewLeftStart(SPIN) elseif MoveViewLeftStop then MoveViewLeftStop() end
end

-- where the slide stands: the panel out by its part, the shade with it,
-- the rail coming in (and faded once it has rested)
local function FoldDraw()
    local t = fold.p
    local e = t * t * (3 - 2 * t)
    local x = -math.floor(DOCK_W * e + 0.5)
    docked:ClearAllPoints()
    docked:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
    docked:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
    shade.slide = 1 - e
    shade:SetAlpha(shade.slide * (shade.level or 1))
    local rail = fold.rail
    if not rail then return end
    local a = 1
    if not rail.over and (t <= 0 or t >= 1) then
        local past = fold.rest - FADE_AFTER
        if past > 0 then a = 1 - (1 - FADE_TO) * math.min(1, past / FADE_FOR) end
    end
    rail:SetAlpha(a)
    if rail.chevron.SetRotation then rail.chevron:SetRotation(fold.want and -math.pi / 2 or math.pi / 2) end
end

local function Fold(on)
    fold.want, fold.idle, fold.rest, fold.dwell = on, 0, 0, 0
    if on then
        Setup.Close()
        if GameTooltip_Hide then GameTooltip_Hide() end
    end
    Spin(on)
end
menu.Fold = Fold

-- the menu's first open: the rail and the clock of the slide
local function Folding()
    if fold.rail then return fold end
    local rail = CreateFrame("Button", nil, holder)
    rail:SetWidth(RAIL_W)
    rail:SetPoint("TOPLEFT", docked, "TOPRIGHT")
    rail:SetPoint("BOTTOMLEFT", docked, "BOTTOMRIGHT")
    rail:SetFrameLevel(docked:GetFrameLevel() + 5)
    rail:RegisterForClicks("LeftButtonUp")
    local ink = rail:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.9)
    local edge = rail:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    rail.chevron = Chevron(rail, 14, math.pi / 2)
    rail.chevron:SetPoint("CENTER")
    rail.chevron:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    local up, down = Diamond(rail), Diamond(rail)
    up:SetPoint("CENTER", 0, 22)
    down:SetPoint("CENTER", 0, -22)
    rail:SetScript("OnClick", function() Fold(not fold.want) end)
    rail:SetScript("OnEnter", function(self)
        self.over, fold.dwell = true, 0
        if not fold.want then
            ns.Tip(self, "ANCHOR_RIGHT", { title = Tr["Fold the menu"],
                { "hint", Tr["It folds by itself when left alone."] } })
        end
    end)
    rail:SetScript("OnLeave", function(self)
        self.over, fold.rest = false, 0
        if GameTooltip_Hide then GameTooltip_Hide() end
    end)
    fold.rail = rail
    -- the slide's clock, while the menu is open
    local drive = CreateFrame("Frame", nil, holder)
    drive:SetScript("OnUpdate", function(_, elapsed)
        if Style() ~= "docked" then return end
        if not fold.want then
            local busy = ns.db.gameMenuFoldIdle == false or Setup.shown or open ~= nil or want ~= nil
                or docked:IsMouseOver() or rail.over or rail:IsMouseOver()
            fold.idle = busy and 0 or fold.idle + elapsed
            if not rail.over then fold.rest = fold.rest + elapsed end
            if fold.idle >= FOLD_IDLE then Fold(true) end
        elseif fold.p >= 1 then
            if rail.over then
                fold.dwell = fold.dwell + elapsed
                if fold.dwell >= DWELL then Fold(false) end
            else
                fold.rest = fold.rest + elapsed
            end
        end
        local to = fold.want and 1 or 0
        if fold.p ~= to then
            local step = elapsed / FOLD_FOR
            fold.p = to > fold.p and math.min(1, fold.p + step) or math.max(0, fold.p - step)
        end
        FoldDraw()
    end)
    fold.drive = drive
    -- each opening: unfolded, still; each closing: the camera stopped
    holder:HookScript("OnShow", function()
        fold.p = 0
        Fold(false)
        FoldDraw()
    end)
    holder:HookScript("OnHide", function()
        Spin(false)
        fold.p, fold.want = 0, false
        FoldDraw()
    end)
    return fold
end

-- ------------------------------------------------------------- the sound
-- The game's volumes at the screen's bottom centre (docked, 2026-11-15),
-- the clock's counterpart: Master, and a chevron opening a tray above it
-- with Music, Effects, Ambience and Dialogue, and the game's Audio
-- settings (opened beside the menu, as the Options card opens). A row: its
-- speaker (a click turns the channel off or on), its word, its bar (a
-- click or a drag sets it, to a step of 0.05), its percent; the wheel over
-- it a step. It fades as the clock does, but always (the clock's Fade is
-- the clock's alone), and the tray shuts once it has faded. The volumes
-- are the game's CVars, read again whenever one changes (its Audio page
-- beside).
local sound, Sound, SoundFade
do
local SOUND_W, SOUND_ROW, SOUND_BAR, SOUND_STEP = 320, 26, 150, 0.05
local CHANNELS = {              -- key, word, volume, on or off
    { "master", Tr["Master"], "Sound_MasterVolume", "Sound_EnableAllSound" },
    { "music", Tr["Music"], "Sound_MusicVolume", "Sound_EnableMusic" },
    { "effects", Tr["Effects"], "Sound_SFXVolume", "Sound_EnableSFX" },
    { "ambience", Tr["Ambience"], "Sound_AmbienceVolume", "Sound_EnableAmbience" },
    { "dialogue", Tr["Dialogue"], "Sound_DialogVolume", "Sound_EnableDialog" },
}
local function GetVar(k)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    return get and get(k)
end
local function SetVar(k, v)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then set(k, v) end
end

local function Volume(ch) return math.max(0, math.min(1, tonumber(GetVar(ch[3])) or 0)) end
local function Muted(ch) return GetVar(ch[4]) == "0" end

-- a volume set: held to 0..1, to the nearest step
local function SetVolume(ch, v)
    v = math.max(0, math.min(1, v))
    v = math.floor(v / SOUND_STEP + 0.5) * SOUND_STEP
    SetVar(ch[3], format("%.2f", v))
    if sound then sound.Draw() end
end

-- where the cursor stands along a bar: its volume
local function PickVolume(bar)
    local left, w = bar:GetLeft(), bar:GetWidth()
    if not (left and w and w > 0) then return end
    local x = GetCursorPosition() / bar:GetEffectiveScale()
    SetVolume(bar.ch, (x - left) / w)
end

local function SoundRow(parent, ch)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(SOUND_W, SOUND_ROW)
    row:EnableMouseWheel(true)
    row.ch = ch
    local speaker = CreateFrame("Button", nil, row)
    speaker:SetSize(18, 18)
    speaker:SetPoint("LEFT", 8, 0)
    speaker:RegisterForClicks("LeftButtonUp")
    speaker.glyph = speaker:CreateTexture(nil, "ARTWORK")
    speaker.glyph:SetAllPoints()
    speaker:SetScript("OnClick", function()
        SetVar(ch[4], Muted(ch) and "1" or "0")
        sound.Draw()
    end)
    row.speaker = speaker
    row.word = ns.Text(row, 12)
    row.word:SetPoint("LEFT", 32, 0)
    row.word:SetText(ch[2])
    local bar = CreateFrame("Frame", nil, row)
    bar:SetSize(SOUND_BAR, 14)
    bar:SetPoint("LEFT", 104, 0)
    bar:EnableMouse(true)
    bar.ch = ch
    row.track = bar:CreateTexture(nil, "BACKGROUND")
    row.track:SetPoint("LEFT")
    row.track:SetPoint("RIGHT")
    row.track:SetHeight(4)
    row.track:SetColorTexture(SEAM[1], SEAM[2], SEAM[3], 1)
    row.fill = bar:CreateTexture(nil, "ARTWORK")
    row.fill:SetPoint("LEFT")
    row.fill:SetHeight(4)
    row.knob = Diamond(bar)
    row.knob:SetPoint("CENTER", row.fill, "RIGHT")
    bar:SetScript("OnMouseDown", function(self)
        self.held = true
        PickVolume(self)
    end)
    bar:SetScript("OnMouseUp", function(self)
        if self.held then PickVolume(self) end
        self.held = false
    end)
    bar:SetScript("OnUpdate", function(self) if self.held then PickVolume(self) end end)
    row.bar = bar
    row.value = ns.PlainText(row, 11)
    row.value:SetPoint("RIGHT", row, "LEFT", 296, 0)
    row:SetScript("OnMouseWheel", function(_, delta) SetVolume(ch, Volume(ch) + delta * SOUND_STEP) end)
    function row.Draw()
        local v, off = Volume(ch), Muted(ch)
        row.fill:SetWidth(math.max(1, math.floor(SOUND_BAR * v + 0.5)))
        row.fill:SetShown(v > 0)
        row.value:SetText(format("%d%%", math.floor(v * 100 + 0.5)))
        speaker.glyph:SetTexture(ns.media .. "strips\\" .. (off and "sound-off" or "sound"))
        local c = off and DIM or GOLD
        speaker.glyph:SetVertexColor(c[1], c[2], c[3])
        local f = off and GOLD_D or GOLD
        row.fill:SetColorTexture(f[1], f[2], f[3], 1)
        row.knob:SetVertexColor(f[1], f[2], f[3])
        if off then row.word:SetTextColor(DIM[1], DIM[2], DIM[3])
        else row.word:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3]) end
        row.value:SetTextColor(DIM[1], DIM[2], DIM[3])
    end
    return row
end

local function Tray(on)
    sound.tray:SetShown(on)
    if sound.chevron.SetRotation then sound.chevron:SetRotation(on and math.pi or 0) end
end

-- its alpha, by how long it has stood still with the mouse off it; faded,
-- the tray shut
SoundFade = function()
    local a = 1
    if not sound.over then
        local past = sound.idle - FADE_AFTER
        if past > 0 then a = 1 - (1 - FADE_TO) * math.min(1, past / FADE_FOR) end
        if past >= FADE_FOR and sound.tray:IsShown() then Tray(false) end
    end
    sound:SetAlpha(a)
end

-- the game's Audio settings beside the menu, as the Options card opens them
local function AudioSettings()
    local id = Settings and Settings.AUDIO_CATEGORY_ID
    if not (id and Settings.OpenToCategory) then
        local f = GameMenuFrame
        for _, b in ipairs(f and f.buttons or {}) do
            if Kind(b, f.closeButton) == "options" and b.Click then return b:Click() end
        end
        return
    end
    Setup.Close()
    want = "options"
    Settings.OpenToCategory(id)
    Post()
end

Sound = function()
    if sound then return sound end
    sound = CreateFrame("Frame", nil, holder)
    sound:SetSize(SOUND_W, SOUND_ROW)
    sound:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 24)
    sound:SetFrameLevel(docked:GetFrameLevel() + 2)
    sound:EnableMouse(true)
    sound.rows = { SoundRow(sound, CHANNELS[1]) }
    sound.rows[1]:SetPoint("BOTTOMLEFT")
    -- the chevron at Master's end: the tray open or shut
    local more = CreateFrame("Button", nil, sound)
    more:SetSize(18, 18)
    more:SetPoint("RIGHT", -4, 0)
    more:RegisterForClicks("LeftButtonUp")
    sound.chevron = Chevron(more, 14, 0)
    sound.chevron:SetPoint("CENTER")
    sound.chevron:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    more:SetScript("OnClick", function() Tray(not sound.tray:IsShown()) end)
    sound.more = more
    -- the tray: a window's card above it, its rows, the Audio settings key
    local tray = CreateFrame("Frame", nil, sound)
    tray:SetSize(SOUND_W, (#CHANNELS - 1) * SOUND_ROW + 52)
    tray:SetPoint("BOTTOM", sound, "TOP", 0, 6)
    tray:EnableMouse(true)
    local ink = tray:CreateTexture(nil, "BACKGROUND")
    ink:SetAllPoints()
    ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.92)
    Sides(tray, 0, GOLD_D, 1)
    local l, r = Diamond(tray), Diamond(tray)
    l:SetPoint("CENTER", tray, "TOPLEFT")
    r:SetPoint("CENTER", tray, "TOPRIGHT")
    for i = 2, #CHANNELS do
        local row = SoundRow(tray, CHANNELS[i])
        row:SetPoint("TOPLEFT", 0, -8 - (i - 2) * SOUND_ROW)
        sound.rows[i] = row
    end
    local key = CreateFrame("Button", nil, tray)
    key:SetSize(140, 22)
    key:SetPoint("BOTTOM", 0, 10)
    key:RegisterForClicks("LeftButtonUp")
    Keyed(key)
    key.word = ns.Text(key, 12)
    key.word:SetPoint("CENTER")
    key.word:SetText(Tr["Audio settings"])
    key:SetScript("OnClick", AudioSettings)
    sound.audio = key
    sound.tray = tray
    Tray(false)
    function sound.Draw()
        for _, row in ipairs(sound.rows) do row.Draw() end
    end
    sound.idle = 0
    sound:SetScript("OnUpdate", function(self, elapsed)
        self.over = self:IsMouseOver() or (self.tray:IsShown() and self.tray:IsMouseOver()) or false
        self.idle = self.over and 0 or self.idle + elapsed
        SoundFade()
    end)
    -- each time the menu opens: full again, the tray shut
    holder:HookScript("OnShow", function()
        sound.idle, sound.over = 0, false
        Tray(false)
        sound.Draw()
        SoundFade()
    end)
    menu.sound = sound
    return sound
end
-- the game's own changes (its Audio page, a key binding): drawn as they come
ns.On("CVAR_UPDATE", function() if sound and sound:IsVisible() then sound.Draw() end end)
end

local function Social()
    if social.motd then return social end
    -- over the guild's window
    local layer = CreateFrame("Frame", nil, docked)
    layer:SetAllPoints()
    layer:SetFrameLevel(docked:GetFrameLevel() + 3)
    -- the message of the day (2026-11-11): a part of the guild's window,
    -- not a box in it: its heading between two rules fading out from it,
    -- the message under it centred, a rule under that over the people
    local box = CreateFrame("Frame", nil, layer)
    box:SetHeight(36)
    box.label = ns.Text(box, 10)
    box.label:SetPoint("TOP", 0, -2)
    box.label:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
    box.label:SetText(Tr["Message of the day"])
    local left = box:CreateTexture(nil, "ARTWORK")
    left:SetHeight(1)
    left:SetPoint("LEFT", box, "TOPLEFT", 0, -8)
    left:SetPoint("RIGHT", box.label, "LEFT", -8, 0)
    if left.SetGradient and CreateColor then
        left:SetColorTexture(1, 1, 1, 1)
        left:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.05),
            CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.5))
    else
        left:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    end
    local right = box:CreateTexture(nil, "ARTWORK")
    right:SetHeight(1)
    right:SetPoint("LEFT", box.label, "RIGHT", 8, 0)
    right:SetPoint("RIGHT", box, "TOPRIGHT", 0, -8)
    Fade(right, GOLD, 0.5)
    -- the message wrapped, as many lines as it takes (a guild's message is
    -- at most 128 characters): its width set, so its height is known
    box.text = ns.PlainText(box, 13)
    box.text:SetPoint("TOP", 0, -MOTD_TOP)
    box.text:SetWidth(DOCK_W - 2 * PAD - 2 * WIN_PAD - 8)
    box.text:SetJustifyH("CENTER")
    box.text:SetJustifyV("TOP")
    box.text:SetWordWrap(true)
    box.text:SetTextColor(ns.colors.text[1], ns.colors.text[2], ns.colors.text[3])
    local under = box:CreateTexture(nil, "ARTWORK")
    under:SetHeight(1)
    under:SetPoint("BOTTOMLEFT")
    under:SetPoint("BOTTOMRIGHT")
    under:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    social.motd = box
    return social
end

-- The message of the day's box, fitted to it; its height.
local function Motd(motd)
    local box = Social().motd
    box.text:SetText(motd)
    -- a secret message is shown as it is, but cannot be measured: two lines
    local ok, high = pcall(function() return math.ceil(box.text:GetStringHeight()) end)
    if not ok or ns.IsSecret(high) then high = 34 end
    local tall = MOTD_TOP + high + 10
    box:SetHeight(tall)
    return tall
end

local last                      -- the docked panel's last reading: sections, leave, back
-- The guild's message of the day, as GUILD_MOTD last brought it (at login,
-- and when it changes), kept though it be a secret (shown, never tested);
-- else the guild's community's broadcast, read on the game's events.
-- GetGuildRosterMOTD from here is a blocked action in game
-- (ADDON_ACTION_BLOCKED, 2026-11-11)
local guildMotd, clubMotd
local lastRanks = {}            -- the guild's ranks, as the panel last read them (for its options)

-- ------------------------------------------------------------ the options
-- The menu's options (2026-11-14, were a popover under each window's
-- gear): a window at the screen's centre in the game's Options' shape, over
-- the world dimmed further. Its head (the title, a close), its pages down
-- the left, their choices to the right, a foot (Done). Each choice is saved
-- as it is clicked and the panel behind laid out again, the window left
-- open on its new marks. Escape, a click outside it, its close or Done, or
-- the menu closing shuts it.
local LINE, LABEL, RULE_H, SEG = 22, 18, 13, 24
local POP_INK = { 0.078, 0.067, 0.047 }
local PAGES = { { "sections", Tr["Sections"] }, { "friends", Tr["Friends"] }, { "guild", Tr["Guild"] },
    { "clock", Tr["Clock"] },
    { "filter", Tr["Filter"] } }
local PANE_W = SETUP_W - SETUP_NAV - 40


-- a line of the options, any kind: its parts all made, the kind's shown
local function PopLine(i)
    local l = Setup.lines[i]
    if l then return l end
    l = CreateFrame("Button", nil, Setup.pane)
    l:RegisterForClicks("LeftButtonUp")
    l:SetScript("OnClick", function(self)
        if self.run then self.run() end
    end)
    l.lit = l:CreateTexture(nil, "HIGHLIGHT")
    l.lit:SetAllPoints()
    l.lit:SetColorTexture(1, 1, 1, 0.05)
    l.ring = Ring(l, 12, GOLD_D)                -- a radio: a ring, its dot
    l.ring:SetPoint("LEFT", 2, 0)
    l.hole = Ring(l, 10, POP_INK)
    l.hole:SetPoint("CENTER", l.ring)
    l.dot = Ring(l, 6, GOLD)
    l.dot:SetPoint("CENTER", l.ring)
    l.box = l:CreateTexture(nil, "ARTWORK", nil, 1)    -- a check: a box, its tick
    l.box:SetSize(12, 12)
    l.box:SetPoint("LEFT", 2, 0)
    l.boxInk = l:CreateTexture(nil, "ARTWORK", nil, 2)
    l.boxInk:SetSize(10, 10)
    l.boxInk:SetPoint("CENTER", l.box)
    l.boxInk:SetColorTexture(POP_INK[1], POP_INK[2], POP_INK[3], 1)
    l.tick = ns.PlainText(l, 11)
    l.tick:SetPoint("CENTER", l.box, "CENTER", 1, 0)
    l.tick:SetText(ns.Tick(GOLD))
    l.tick:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    l.word = ns.Text(l, 12)
    l.word:SetPoint("LEFT", 20, 0)
    l.aside = ns.PlainText(l, 11)                   -- what it is, at the line's end
    l.aside:SetPoint("RIGHT", -4, 0)
    l.aside:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
    l.rule = l:CreateTexture(nil, "ARTWORK")
    l.rule:SetHeight(1)
    l.rule:SetPoint("LEFT")
    l.rule:SetPoint("RIGHT")
    l.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    Setup.lines[i] = l
    return l
end

-- a key of a joined row (the sorts, the clock's hours)
local function PopSeg(i)
    local k = Setup.segs[i]
    if k then return k end
    k = CreateFrame("Button", nil, Setup.pane)
    k:RegisterForClicks("LeftButtonUp")
    Keyed(k)
    k.word = ns.Text(k, 11)
    k.word:SetPoint("CENTER")
    -- a colour's bar along its foot (the filter's tints)
    k.swatch = k:CreateTexture(nil, "ARTWORK", nil, 2)
    k.swatch:SetPoint("BOTTOMLEFT", 6, 3)
    k.swatch:SetPoint("BOTTOMRIGHT", -6, 3)
    k.swatch:SetHeight(3)
    k.swatch:Hide()
    k:SetScript("OnClick", function(self) if self.run then self.run() end end)
    Setup.segs[i] = k
    return k
end

local function Flip(key) ns.db[key] = ns.db[key] == false end

-- What a page offers, laid out in the pane: a choice saved, the panel
-- (and the clock) laid out again.
local function Fill(page)
    local w = PANE_W
    local y, nl, nk = 0, 0, 0
    local function Again()
        if clock then ClockDraw(); ClockFade() end
        if Relayout then Relayout() end
        Setup.Refresh()
    end
    local function Line(kind, word, on, run, indent, aside)
        nl = nl + 1
        local l = PopLine(nl)
        indent = indent or 0
        local tall = kind == "label" and LABEL or kind == "rule" and RULE_H or LINE
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", indent, y)
        l:SetSize(w - indent, tall)
        l.kind, l.run, l.on = kind, run, on
        l:EnableMouse(run ~= nil)
        l.lit:SetShown(run ~= nil)
        for _, t in ipairs({ l.ring, l.hole }) do t:SetShown(kind == "radio") end
        l.dot:SetShown(kind == "radio" and on)
        for _, t in ipairs({ l.box, l.boxInk }) do t:SetShown(kind == "check") end
        local c = on and GOLD or GOLD_D
        l.box:SetColorTexture(c[1], c[2], c[3], 1)
        l.ring:SetVertexColor(c[1], c[2], c[3])
        l.tick:SetShown(kind == "check" and on)
        l.rule:SetShown(kind == "rule")
        l.word:SetShown(word ~= nil)
        l.word:ClearAllPoints()
        l.aside:SetText(aside or "")
        l.aside:SetShown(aside ~= nil)
        if kind == "label" then
            l.word:SetPoint("LEFT", 0, 0)
            l.word:SetFont(ns.font, 9, "")
            l.word:SetText((word or ""):upper())
            l.word:SetTextColor(DIM[1], DIM[2], DIM[3])
        else
            l.word:SetPoint("LEFT", 20, 0)
            l.word:SetFont(ns.font, 13, "")
            l.word:SetText(word or "")
            local t = on and ns.colors.text or DIM
            l.word:SetTextColor(t[1], t[2], t[3])
        end
        l:Show()
        y = y - tall
    end
    local function Seg(items, current, save)
        local n = #items
        for i, it in ipairs(items) do
            nk = nk + 1
            local k = PopSeg(nk)
            local x0, x1 = math.floor((i - 1) * w / n), math.floor(i * w / n)
            k:ClearAllPoints()
            k:SetPoint("TOPLEFT", x0, y - 2)
            k:SetSize(x1 - x0 + (i < n and 1 or 0), SEG)
            k.value = it[1]
            k.held = current == it[1]
            k.Lit(false)
            k.word:SetText(it[2])
            -- a tint is shown lit, its hue made out of its darkness (black a grey)
            local c = it[3]
            k.swatch:SetShown(c ~= nil)
            if c then
                local top = math.max(c[1], c[2], c[3])
                if top <= 0 then k.swatch:SetColorTexture(0.25, 0.25, 0.25, 1)
                else k.swatch:SetColorTexture(c[1] / top * 0.8, c[2] / top * 0.8, c[3] / top * 0.8, 1) end
            end
            local t = k.held and ns.colors.text or DIM
            k.word:SetTextColor(t[1], t[2], t[3])
            k.run = function() save(it[1]); Again() end
            k:Show()
        end
        y = y - SEG - 8
    end
    if page == "sections" then
        -- a tick each: unticked, the section is left out
        local counts = Setup.counts or {}
        local asides = { menu = format(Tr["%d cards"], counts.menu or 0),
            shortcuts = format(Tr["%d cards"], counts.shortcuts or 0), friends = Tr["a tab"], guild = Tr["a tab"],
            clock = Tr["top of the screen"], sound = Tr["bottom of the screen"] }
        Line("label", Tr["Shown in the menu"])
        for _, key in ipairs(ORDER) do
            Line("check", TITLES[key], not Hidden(key), function() SetHidden(key, not Hidden(key)); Again() end, 0,
                asides[key])
        end
        Line("rule")
        Line("label", Tr["When left alone"])
        Line("check", Tr["Fold the panel in"], ns.db.gameMenuFoldIdle ~= false,
            function() Flip("gameMenuFoldIdle"); Again() end, 0, format(Tr["after %d s"], FOLD_IDLE))
        Line("check", Tr["Turn the camera while folded"], ns.db.gameMenuSpin ~= false,
            function() Flip("gameMenuSpin"); Again() end)
    elseif page == "friends" then
        local filter = ns.db.gameMenuFriends or "online"
        Line("label", Tr["Show"])
        local kinds = { { "online", Tr["Online"] }, { "all", Tr["All"] } }
        if BNGetNumFriends then table.insert(kinds, { "bnet", "Battle.net" }) end
        for _, k in ipairs(kinds) do
            Line("radio", k[2], filter == k[1], function() ns.db.gameMenuFriends = k[1]; Again() end)
        end
        Line("rule")
        Line("label", Tr["Sort"])
        Seg({ { "name", Tr["Name"] }, { "level", Tr["Level"] }, { "zone", Tr["Zone"] } },
            ns.db.gameMenuFriendsSort or "name",
            function(v) ns.db.gameMenuFriendsSort = v end)
    elseif page == "guild" then
        local mode = ns.db.gameMenuGuild or "officers"
        Line("label", Tr["Show"])
        for _, k in ipairs({ { "officers", Tr["Officers"] }, { "all", Tr["All"] }, { "ranks", Tr["Ranks"] } }) do
            Line("radio", k[2], mode == k[1], function() ns.db.gameMenuGuild = k[1]; Again() end)
            -- picking ranks: a check each under it, ticked when listed
            if k[1] == "ranks" and mode == "ranks" then
                for _, r in ipairs(lastRanks) do
                    Line("check", r.name, Picked(r.name, r.index), function() Pick(r, lastRanks); Again() end, 22)
                end
            end
        end
        Line("rule")
        Line("label", Tr["Sort"])
        Seg({ { "name", Tr["Name"] }, { "level", Tr["Level"] }, { "rank", Tr["Rank"] }, { "zone", Tr["Zone"] } },
            ns.db.gameMenuGuildSort or "name", function(v) ns.db.gameMenuGuildSort = v end)
        Line("label", Tr["Show also"])
        Line("check", Tr["Name as title"], ns.db.gameMenuGuildName ~= false,
            function() Flip("gameMenuGuildName"); Again() end)
        Line("check", Tr["Message of the day"], ns.db.gameMenuMotd ~= false,
            function() Flip("gameMenuMotd"); Again() end)
    elseif page == "clock" then
        Line("label", Tr["Time"])
        Seg({ { true, Tr["24-hour"] }, { false, Tr["12-hour"] } }, ns.db.gameMenuClock24 ~= false,
            function(v) ns.db.gameMenuClock24 = v end)
        Line("radio", Tr["Local time"], not ns.db.gameMenuClockRealm,
            function() ns.db.gameMenuClockRealm = false; Again() end, 0, Tr["this computer's"])
        Line("radio", Tr["Realm time"], ns.db.gameMenuClockRealm == true,
            function() ns.db.gameMenuClockRealm = true; Again() end, 0, Tr["the server's"])
        Line("rule")
        Line("label", Tr["Under it"])
        Line("check", Tr["Gold, session and latency"], ns.db.gameMenuSession ~= false,
            function() Flip("gameMenuSession"); Again() end)
        Line("check", Tr["Fade after 5 seconds"], ns.db.gameMenuClockFade ~= false,
            function() Flip("gameMenuClockFade"); Again() end)
    elseif page == "filter" then
        Line("label", Tr["The world behind the menu"])
        Line("check", Tr["Dim and tint it"], FilterOn(), function() Flip("gameMenuFilter"); Again() end)
        Line("rule")
        Line("label", Tr["Shape"])
        Seg({ { "vignette", Tr["Vignette"] }, { "even", Tr["Even"] } }, ns.db.gameMenuFilterShape or "vignette",
            function(v) ns.db.gameMenuFilterShape = v end)
        Line("label", Tr["Strength"])
        local strengths = {}
        for _, v in ipairs(STRENGTHS) do table.insert(strengths, { v, format("%d%%", v * 100 + 0.5) }) end
        Seg(strengths, Strength(), function(v) ns.db.gameMenuFilterStrength = v end)
        Line("label", Tr["Tint"])
        Seg(TINTS, ns.db.gameMenuFilterTint or "black", function(v) ns.db.gameMenuFilterTint = v end)
    end
    for i = nl + 1, #Setup.lines do Setup.lines[i]:Hide() end
    for i = nk + 1, #Setup.segs do Setup.segs[i]:Hide() end
end

-- a page's key in the column down the left: gold, a bar at its side, when on
local function PageKey(i, page, words)
    local k = CreateFrame("Button", nil, Setup.frame)
    k:SetSize(SETUP_NAV, 28)
    k:SetPoint("TOPLEFT", 1, -41 - 10 - (i - 1) * 28)
    k:RegisterForClicks("LeftButtonUp")
    k.page = page
    k.wash = k:CreateTexture(nil, "BACKGROUND")
    k.wash:SetAllPoints()
    k.wash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.09)
    k.bar = k:CreateTexture(nil, "ARTWORK")
    k.bar:SetPoint("TOPLEFT", 0, -4)
    k.bar:SetPoint("BOTTOMLEFT", 0, 4)
    k.bar:SetWidth(2)
    k.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local glow = k:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.05)
    k.word = ns.Text(k, 13)
    k.word:SetPoint("LEFT", 16, 0)
    k.word:SetText(words)
    function k.Lit(on)
        k.on = on
        k.wash:SetShown(on)
        k.bar:SetShown(on)
        local c = on and GOLD or DIM
        k.word:SetTextColor(c[1], c[2], c[3])
    end
    k:SetScript("OnClick", function(self) Setup.Open(self.page) end)
    return k
end

local function Make()
    if Setup.frame then return end
    -- under it, over the panel and the world: a click there shuts it
    local catcher = CreateFrame("Button", nil, holder)
    catcher:SetAllPoints(holder)
    catcher:SetFrameLevel(docked:GetFrameLevel() + 30)
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    catcher:SetScript("OnClick", function() Setup.Close() end)
    local dim = catcher:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.45)
    catcher:Hide()
    local f = CreateFrame("Frame", nil, holder)
    f:SetSize(SETUP_W, SETUP_H)
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetFrameLevel(docked:GetFrameLevel() + 35)
    f:EnableMouse(true)
    -- Escape shuts it, not the menu; any other key goes on to the game
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        local esc = key == "ESCAPE"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not esc) end
        if esc then Setup.Close() end
    end)
    f:Hide()
    local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetPoint("TOPLEFT", 6, -10)
    shadow:SetPoint("BOTTOMRIGHT", 6, -10)
    shadow:SetColorTexture(0, 0, 0, 0.6)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local ink = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    ink:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 0.98)
    -- the head: the title between its diamonds, "options", the close
    local left = Diamond(f)
    left:SetPoint("CENTER", f, "TOPLEFT", 20, -20)
    local title = ns.Text(f, 16)
    title:SetPoint("LEFT", f, "TOPLEFT", 30, -20)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText(Tr["Game menu"])
    local right = Diamond(f)
    right:SetPoint("LEFT", title, "RIGHT", 7, 0)
    local sub = ns.PlainText(f, 12)
    sub:SetPoint("LEFT", right, "RIGHT", 10, 0)
    sub:SetTextColor(DIM[1], DIM[2], DIM[3])
    sub:SetText("options")
    local close = CreateFrame("Button", nil, f)
    close:SetSize(40, 39)
    close:SetPoint("TOPRIGHT", -1, -1)
    close:RegisterForClicks("LeftButtonUp")
    local red = close:CreateTexture(nil, "HIGHLIGHT")
    red:SetAllPoints()
    red:SetColorTexture(0.47, 0.09, 0.08, 1)
    local x = close:CreateTexture(nil, "ARTWORK")
    x:SetSize(14, 14)
    x:SetPoint("CENTER")
    x:SetTexture(ns.media .. "strips\\close")
    x:SetVertexColor(DIM[1], DIM[2], DIM[3])
    close:SetScript("OnClick", function() Setup.Close() end)
    local function Rule(r, a)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a or 0.45)
        r(t)
        return t
    end
    Rule(function(t) t:SetPoint("TOPLEFT", 1, -40); t:SetPoint("TOPRIGHT", -1, -40); t:SetHeight(1) end)
    Rule(function(t)
        t:SetPoint("TOPRIGHT", close, "TOPLEFT")
        t:SetPoint("BOTTOMRIGHT", close, "BOTTOMLEFT")
        t:SetWidth(1)
    end)
    Rule(function(t) t:SetPoint("BOTTOMLEFT", 1, 44); t:SetPoint("BOTTOMRIGHT", -1, 44); t:SetHeight(1) end)
    Rule(function(t)
        t:SetPoint("TOPLEFT", SETUP_NAV + 1, -41)
        t:SetPoint("BOTTOMLEFT", SETUP_NAV + 1, 45)
        t:SetWidth(1)
    end)
    -- the pages' column, a shade darker
    local nav = f:CreateTexture(nil, "BACKGROUND", nil, 4)
    nav:SetPoint("TOPLEFT", 1, -41)
    nav:SetPoint("BOTTOMLEFT", 1, 45)
    nav:SetWidth(SETUP_NAV)
    nav:SetColorTexture(0, 0, 0, 0.25)
    -- the foot: a word on saving, Done
    local saved = ns.PlainText(f, 12)
    saved:SetPoint("BOTTOMLEFT", 16, 16)
    saved:SetTextColor(DIM[1], DIM[2], DIM[3])
    saved:SetText(Tr["Each choice is saved as you make it."])
    local done = CreateFrame("Button", nil, f)
    done:SetSize(84, 26)
    done:SetPoint("BOTTOMRIGHT", -12, 9)
    done:RegisterForClicks("LeftButtonUp")
    Keyed(done)
    done.word = ns.Text(done, 12)
    done.word:SetPoint("CENTER")
    done.word:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    done.word:SetText(Tr["Done"])
    done:SetScript("OnClick", function() Setup.Close() end)
    local pane = CreateFrame("Frame", nil, f)
    pane:SetPoint("TOPLEFT", SETUP_NAV + 21, -41 - 14)
    pane:SetSize(PANE_W, SETUP_H - 41 - 45 - 28)
    Setup.frame, Setup.catcher, Setup.pane, Setup.close, Setup.done = f, catcher, pane, close, done
    Setup.lines, Setup.segs, Setup.keys = {}, {}, {}
    for i, p in ipairs(PAGES) do Setup.keys[i] = PageKey(i, p[1], p[2]) end
    holder:HookScript("OnHide", function() Setup.Close() end)
end

local function Cog(on)
    local cog = who.cog
    if not cog then return end
    cog.held = on
    cog.Lit(false)
end

function Setup.Close()
    Setup.shown = false
    if not Setup.frame then return end
    Setup.frame:Hide()
    Setup.catcher:Hide()
    Cog(false)
end

-- after a layout: its page's marks as they now are
function Setup.Refresh()
    if not (Setup.shown and Setup.frame) then return end
    for _, k in ipairs(Setup.keys) do k.Lit(k.page == Setup.page) end
    Fill(Setup.page)
end

function Setup.Open(page)
    Make()
    Setup.page = page or Setup.page or "sections"
    Setup.shown = true
    if not InCombatLockdown() then Setup.frame:SetPropagateKeyboardInput(true) end
    Setup.frame:Show()
    Setup.catcher:Show()
    Cog(true)
    Setup.Refresh()
end

function Setup.Toggle()
    if Setup.shown then Setup.Close() else Setup.Open() end
end
menu.Setup = Setup

local function Docked(sections, leave, back)
    last = { sections, leave, back }
    local hasXP = Who()
    local inner = DOCK_W - 2 * PAD - 2 * WIN_PAD           -- a window's body, across
    local y = -(PAD + (hasXP and 110 or 84)) - 10
    local n = 0
    local over = docked:GetFrameLevel() + 3                 -- what stands in a window
    -- Blizzard's buttons, and our shortcuts, apart
    local items, ours = {}, {}
    for _, section in ipairs(sections) do
        for _, it in ipairs(section) do table.insert(it.kind == "shortcut" and ours or items, it) end
    end
    Setup.counts = { menu = #items, shortcuts = #ours }
    local function Hide(list) for _, it in ipairs(list) do it.b:Hide() end end
    -- a card a row in a window's body, tall each
    local function Rows(list, top, tall)
        for i, it in ipairs(list) do
            Take(it.b, docked)
            it.b:SetPoint("TOPLEFT", PAD + WIN_PAD, top - (i - 1) * (tall + ROW_GAP))
            it.b:SetSize(inner, tall)
            it.b:SetFrameLevel(over)
            local d = Dress(it.b)
            d.line = it.line or LINES[it.kind]
            Look(it.b, "row", it.kind, it.glyph, tall)
            it.b:Show()
        end
    end
    local function Tall(count, rowH) return WIN_TOP + count * (rowH + ROW_GAP) - ROW_GAP + WIN_PAD end
    -- the foot's rule, from the bottom; the windows stop over it
    local rule = PAD + FOOT_H + 12
    local panel = docked:GetHeight() or 0
    if panel <= 0 then panel = UIParent:GetHeight() or 768 end
    local floor = -(panel - rule - 10)
    -- the people: a tab each for friends and the guild, the one shown listed
    local showF = not Hidden("friends")
    local filter = ns.db.gameMenuFriends or "online"
    if filter == "bnet" and not BNGetNumFriends then filter = "online" end
    local friends = {}
    if showF then friends = Friends(filter) end
    local inGuild = (not IsInGuild or IsInGuild()) and GetGuildInfo and GetGuildInfo("player")
    if Hidden("guild") then inGuild = nil end
    local guildMode = ns.db.gameMenuGuild or "officers"
    local members, total, guildOn, ranks = {}, 0, 0, {}
    if inGuild then members, total, guildOn, ranks = Guild(guildMode) end
    lastRanks = ranks
    -- a tab's count: the online among those it lists
    local function Online(list)
        local c = 0
        for _, p in ipairs(list) do if p.status ~= "offline" then c = c + 1 end end
        return c
    end
    local tabs = {}
    if showF then table.insert(tabs, { "friends", Tr["Friends"], Online(friends), false }) end
    -- the guild's name its tab's word (unless its option is off)
    local showName = ns.db.gameMenuGuildName ~= false and not ns.IsSecret(inGuild)
    if inGuild then table.insert(tabs, { "guild", showName and inGuild or Tr["Guild"], Online(members), false }) end
    local tab = tabs[1]
    for _, t in ipairs(tabs) do if t[1] == ns.db.gameMenuTab then tab = t end end
    if tab then tab[4] = true end
    local onGuild = tab ~= nil and tab[1] == "guild"
    local motd = onGuild and ns.db.gameMenuMotd ~= false and (guildMotd or clubMotd) or nil
    if motd ~= nil and not ns.IsSecret(motd) and motd == "" then motd = nil end
    local motdTall = motd and Motd(motd) or 0
    -- the people's body under the Social window's strip (and the message)
    local function Fix(strip, withMotd)
        return STRIP_TOP + strip + STRIP_GAP + WIN_PAD + (withMotd and motdTall + 8 or 0)
    end
    local strip = STRIP_H
    local fix = Fix(strip, motd ~= nil)
    -- a short panel: the cards a line each, then the guild's message left
    -- out, till the people have three rows
    local showMenu, showOurs = not Hidden("menu") and #items > 0, not Hidden("shortcuts") and #ours > 0
    local function Above(rowH)
        local t = 0
        if showMenu then t = t + Tall(#items, rowH) + WIN_GAP end
        if showOurs then t = t + Tall(#ours, rowH) + WIN_GAP end
        return t
    end
    local function Least(f) return tab and f + 3 * PERSON or 0 end
    local rowH = ROW_H
    if y - Above(rowH) - floor < Least(fix) then
        rowH, strip = ROW_LOW, STRIP_LOW
        fix = Fix(strip, motd ~= nil)
    end
    if y - Above(rowH) - floor < Least(fix) then
        motd = nil
        fix = Fix(strip, false)
    end
    -- the game's menu, a card a row
    if not showMenu then Hide(items) else
        local tall = Tall(#items, rowH)
        n = n + 1
        Win(n, y, tall, Tr["Game menu"], tostring(#items), "menu")
        Rows(items, y - WIN_TOP, rowH)
        y = y - tall - WIN_GAP
    end
    -- our shortcuts, the same
    if not showOurs then Hide(ours) else
        local tall = Tall(#ours, rowH)
        n = n + 1
        Win(n, y, tall, Tr["Shortcuts"], tostring(#ours), "shortcuts")
        Rows(ours, y - WIN_TOP, rowH)
        y = y - tall - WIN_GAP
    end

    -- the people's window: the height left; its list from its scroll on,
    -- the rows its body holds
    local used = 0
    local soc = Social()
    soc.motd:Hide()
    if tab then
        local tall = y - floor
        n = n + 1
        local note
        if onGuild then
            local word = ({ officers = Tr["Officers"], all = Tr["All"], ranks = Tr["Ranks"] })[guildMode]
                or Tr["Officers"]
            note = format("%s  \194\183  %d / %d", word, guildOn, total)
        else
            note = ({ online = Tr["Online"], all = Tr["All"], bnet = "Battle.net" })[filter]
        end
        local h = Win(n, y, tall, Tr["Social"], note, tab[1], tabs, strip)
        local top = y - STRIP_TOP - strip - STRIP_GAP
        if motd then
            soc.motd:ClearAllPoints()
            soc.motd:SetPoint("TOPLEFT", PAD + WIN_PAD, top)
            soc.motd:SetPoint("TOPRIGHT", -PAD - WIN_PAD, top)
            soc.motd:Show()
            top = top - motdTall - 8
        end
        local list = onGuild and members or friends
        local none = onGuild and Tr["No one to show"]
            or filter == "online" and Tr["No friends online"] or Tr["No friends"]
        local body = tall - fix
        local fit = math.max(1, math.floor(body / PERSON))
        h.most = math.max(0, #list - fit)
        local first = math.min(offset[h.key] or 0, h.most)
        offset[h.key] = first
        if #list == 0 then
            used = used + 1
            Person(used, top, { more = none }, h)
        end
        for i = first + 1, math.min(#list, first + fit) do
            used = used + 1
            Person(used, top - (i - first - 1) * PERSON, list[i], h)
        end
        h.Scroll(first, fit, #list, y - top, body)
        -- the honeycomb from the list's top to the window's foot, a texel
        -- a point (cells keep their shape), gold fading out downward
        local cw, ch = DOCK_W - 2 * PAD - 6, math.max(1, top - (y - tall) - 3)
        local k = math.max(1, cw / COMB_PX, ch / COMB_PX)
        h.comb:ClearAllPoints()
        h.comb:SetPoint("TOPLEFT", h, "TOPLEFT", 3, top - y)
        h.comb:SetSize(cw, ch)
        h.comb:SetTexCoord(0, cw / (COMB_PX * k), 0, ch / (COMB_PX * k))
        if h.comb.SetGradient and CreateColor then
            h.comb:SetVertexColor(1, 1, 1, 1)
            h.comb:SetGradient("VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0),
                CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.13))
        else
            h.comb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.06)
        end
        h.comb:Show()
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    for i = n + 1, #heads do heads[i]:Hide() end

    -- the fold: its rail, the panel where the slide has it
    Folding()
    fold.rail:Show()
    FoldDraw()

    -- the clock at the screen's top centre, the session under it
    local c = Clock()
    c:SetShown(not Hidden("clock"))
    ClockDraw()
    ClockFade()

    -- the volumes at its bottom centre
    local so = Sound()
    so:SetShown(not Hidden("sound"))
    so.Draw()
    SoundFade()

    -- the foot (E2): Log Out and Exit squared either side, Return to Game
    -- wide between; a third Leave (a client's own) takes the next side
    local sides = { {}, {} }
    for i, it in ipairs(leave) do table.insert(sides[(i - 1) % 2 + 1], it) end
    for s, list in ipairs(sides) do
        for i, it in ipairs(list) do
            Take(it.b, docked)
            local at = PAD + (i - 1) * (SQUARE_W + 8)
            if s == 1 then it.b:SetPoint("BOTTOMLEFT", at, PAD) else it.b:SetPoint("BOTTOMRIGHT", -at, PAD) end
            it.b:SetSize(SQUARE_W, FOOT_H)
            it.b:SetFrameLevel(over)
            Look(it.b, "square", it.kind, it.glyph)
        end
    end
    if back then
        Take(back, docked)
        back:SetPoint("BOTTOMLEFT", PAD + #sides[1] * (SQUARE_W + 8), PAD)
        back:SetPoint("BOTTOMRIGHT", -(PAD + #sides[2] * (SQUARE_W + 8)), PAD)
        back:SetHeight(FOOT_H)
        back:SetFrameLevel(over)
        Look(back, "return", "return", "chevron-up")
    end
    -- the world to its right, dimmed a little, fading
    shade:ClearAllPoints()
    shade:SetPoint("TOPLEFT", docked, "TOPRIGHT")
    shade:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    Paint(shade, true)
    Setup.Refresh()
end

Relayout = function()
    if last and holder and holder:IsShown() and Style() == "docked" then Docked(last[1], last[2], last[3]) end
end
menu.Relayout = Relayout

-- a chain's bar from one medallion's centre to the next's: stretched to the
-- distance, turned to the angle between them
local function Bar(n, x1, y1, x2, y2)
    local t = bars[n]
    if not t then
        t = ring:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(BAR)
        bars[n] = t
    end
    local dx, dy = x2 - x1, y2 - y1
    t:SetSize(math.sqrt(dx * dx + dy * dy), BAR_W * 2)      -- the art's bar is its middle half
    t:ClearAllPoints()
    t:SetPoint("CENTER", ring, "CENTER", (x1 + x2) / 2, (y1 + y2) / 2)
    if t.SetRotation then t:SetRotation(math.atan2(dy, dx)) end
    t:Show()
    return t
end

-- a medallion's centre on the ring, at a angle (degrees, counter-clockwise from the right)
local function At(r, deg)
    local a = math.rad(deg)
    return r * math.cos(a), r * math.sin(a)
end

local function Place(b, x, y, size)
    b:SetSize(math.max(size + 40, 96), size + 24)
    b:SetPoint("TOP", ring, "CENTER", x, y + size / 2)
end

local function Medallion(sections, leave, back)
    local r = REACH * (UIParent:GetHeight() or 768)
    local items = {}
    for _, section in ipairs(sections) do
        for _, it in ipairs(section) do table.insert(items, it) end
    end
    local n, used = #items, 0
    local grow = math.min(math.max(n - 6, 0) * ARCH_GROW, 180 - ARCH_FROM)
    local from, to = ARCH_FROM + grow, ARCH_TO - grow
    -- the arch, evenly from end to end; a chain bar from each to the next
    local px, py
    for i, it in ipairs(items) do
        local deg = n > 1 and from + (to - from) * (i - 1) / (n - 1) or 90
        local x, y = At(r, deg)
        Take(it.b, ring)
        Place(it.b, x, y, MEDAL)
        Look(it.b, "medal", it.kind, it.glyph)
        if px then
            used = used + 1
            Bar(used, px, py, x, y)
        end
        px, py = x, y
    end
    -- below: Log Out, Return to Game, Exit Game, chained the same
    local low = {}
    for _, it in ipairs(leave) do
        if it.kind == "logout" then table.insert(low, 1, it) end
    end
    if back then table.insert(low, { b = back, kind = "return", glyph = "chevron-up", primary = true }) end
    for _, it in ipairs(leave) do
        if it.kind ~= "logout" then table.insert(low, it) end
    end
    px, py = nil, nil
    for _, it in ipairs(low) do
        local deg = it.primary and 270 or LEAVE_AT[it.kind] or 270
        local x, y = At(r, deg)
        local size = it.primary and BACK_MEDAL or MEDAL
        Take(it.b, ring)
        Place(it.b, x, y, size)
        Look(it.b, "medal", it.kind, it.glyph, size, it.primary)
        if px then
            used = used + 1
            Bar(used, px, py, x, y)
        end
        px, py = x, y
    end
    for i = used + 1, #bars do bars[i]:Hide() end
    if clock then clock:Hide() end
    if sound then sound:Hide() end
    Setup.Close()
    if fold.rail then
        Spin(false)
        fold.p, fold.want = 0, false
        fold.rail:Hide()
    end
    shade.slide = 1
    shade:ClearAllPoints()
    shade:SetAllPoints(UIParent)
    Paint(shade, false)
end

-- Taken in: after each InitButtons (as it shows, as the store's state
-- changes), Blizzard's buttons are moved into ours and dressed.
local Pre
local function Arrange()
    if not holder then return end
    -- each of Blizzard's buttons, hooked once: the pool gives them out again
    -- with other words, so what a click opens is read as it is clicked
    for _, b in ipairs(GameMenuFrame.buttons or {}) do
        if not clicks[b] then
            clicks[b] = true
            b:HookScript("PreClick", Pre)
            b:HookScript("PostClick", function() Post() end)
        end
    end
    local sections, leave, back = Read()
    local style = Style()
    local extra = Shortcuts(style == "docked")
    if #extra > 0 then table.insert(sections, extra) end
    docked:SetShown(style == "docked")
    ring:SetShown(style == "medallion")
    if style == "medallion" then Medallion(sections, leave, back) else Docked(sections, leave, back) end
end
menu.Arrange = Arrange

-- The rest of the interface put away while the menu is open, and back after
local cleared
local function Clear()
    if cleared then return end
    cleared = { alpha = UIParent:GetAlpha(), loose = {} }
    -- a frame whose answers are secret (another addon's, a restricted one)
    -- is left as it is: a secret cannot be tested
    local function Loose(f)
        if f == holder or not f.IsIgnoringParentAlpha then return false end
        local forbidden = f.IsForbidden and f:IsForbidden()
        if ns.IsSecret(forbidden) or forbidden then return false end
        local ignores = f:IsIgnoringParentAlpha()
        return not ns.IsSecret(ignores) and ignores == true
    end
    if EnumerateFrames and holder.IsIgnoringParentAlpha then
        local f = EnumerateFrames()
        while f do
            local ok, loose = pcall(Loose, f)
            if ok and loose then
                f:SetIgnoreParentAlpha(false)
                table.insert(cleared.loose, f)
            end
            f = EnumerateFrames(f)
        end
    end
    UIParent:SetAlpha(0)
    -- the minimap draws its blips and pins (the quest marks, the arrow) past
    -- any alpha: it is hidden, and shown again after
    local mm = _G.Minimap
    if mm and mm:IsShown() and not (mm.IsProtected and mm:IsProtected() and InCombatLockdown()) then
        mm:Hide()
        cleared.minimap = mm
    end
end
local function Restore()
    if not cleared then return end
    for _, f in ipairs(cleared.loose) do f:SetIgnoreParentAlpha(true) end
    UIParent:SetAlpha(cleared.alpha or 1)
    if cleared.minimap then cleared.minimap:Show() end
    cleared = nil
end
menu.Clear, menu.Restore = Clear, Restore

-- Beside (docked): Options and AddOns open with the menu still there, as a
-- dashboard's page. Blizzard's click hides its menu before it opens the
-- window, so the PreClick says what is coming and the menu's OnHide keeps
-- ours; the PostClick finds the window open and holds it.
Pre = function(b)
    want = nil
    if Style() ~= "docked" then return end
    local kind = Kind(b, GameMenuFrame.closeButton)
    if BESIDE[kind] then want = kind end
end

-- a frame drawn over the interface put away: its own alpha, till it closes
local function Lend(f)
    if f and f.SetIgnoreParentAlpha and lent[f] == nil then
        lent[f] = true
        f:SetIgnoreParentAlpha(true)
    end
end
local function Unlend(f)
    if lent[f] then
        lent[f] = nil
        f:SetIgnoreParentAlpha(false)
    end
end

-- the window let go (it closed): its strata and level back, the lent frames
-- following UIParent again, the card unlit
local function Let()
    local w = open
    open, openKind = nil, nil
    if w and lifted then
        w:SetFrameStrata(lifted[1])
        w:SetFrameLevel(lifted[2])
    end
    lifted = nil
    for f in pairs(lent) do Unlend(f) end
    Relayout()
end

-- a frame later: closed with no way back to the menu (another's HideUIPanel,
-- Close(true)), the menu goes too; the game's own way back has shown it again
local function Settle()
    if open or not holder:IsShown() then return end
    if not GameMenuFrame:IsShown() then
        holder:Hide()
        Restore()
    end
end

-- The window held beside the menu: lifted over our holder (whose catch
-- keeps clicks off the bars unseen), drawn over a hidden UIParent with what
-- it raises (the tooltip, the game's prompts; its dropdowns as they open)
local hooked = {}
local function Hold(kind, w)
    open, openKind = w, kind
    if not hooked[w] then
        hooked[w] = true
        w:HookScript("OnHide", function(self)
            if open ~= self then return end
            Let()
            C_Timer.After(0, Settle)
        end)
    end
    lifted = { w:GetFrameStrata(), w:GetFrameLevel() }
    w:SetFrameStrata("DIALOG")
    w:SetFrameLevel(holder:GetFrameLevel() + 100)
    Lend(w)
    Lend(GameTooltip)
    for i = 1, 4 do Lend(_G["StaticPopup" .. i]) end
    Relayout()
end

-- the window closed without going back to the menu (Settings skips its
-- way back; the AddOns list's brings the menu again, put away after)
local function Shut(w, kind)
    if kind == "options" and w.Close then w:Close(true) else HideUIPanel(w) end
end

-- After a click on the menu (Blizzard's buttons, our shortcuts): the window
-- it opened beside it held, one beside it before closed; nothing beside it
-- now, and the menu goes as any click takes it
Post = function()
    local kind = want
    want = nil
    local old = open
    if not (kind or old) then return end
    local w = kind and _G[BESIDE[kind]]
    if old and old ~= w then Shut(old, openKind) end
    if w and w:IsShown() then
        if open ~= w then Hold(kind, w) end
        if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    elseif not (open and open:IsShown()) then
        if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame)
        else
            holder:Hide()
            Restore()
        end
    end
end

-- the game's dropdowns are made as they open, on UIParent: lent while a
-- window is beside the menu
if EventRegistry and EventRegistry.RegisterCallback then
    local owner = {}
    EventRegistry:RegisterCallback("MenuProxy.OnShow", function(_, m) if open then Lend(m) end end, owner)
    EventRegistry:RegisterCallback("MenuProxy.OnHide", function(_, m) Unlend(m) end, owner)
end
menu.Beside = function() return openKind, open end

local adopted = false
local function Adopt()
    local f = _G.GameMenuFrame
    if adopted or not f or not f.InitButtons then return end
    adopted = true
    Build()
    -- Blizzard's frame: still the panel the game shows and hides, but unseen
    -- and clicked through; its buttons stand in ours
    f:SetAlpha(0)
    f:EnableMouse(false)
    hooksecurefunc(f, "InitButtons", Arrange)
    f:HookScript("OnShow", function()
        Clear()
        holder:Show()
        -- the friends and the guild asked for again; their answers lay it out anew
        if Style() == "docked" then
            if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends() end
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
            elseif GuildRoster then GuildRoster() end
        end
    end)
    f:HookScript("OnHide", function()
        -- a card opening its window beside it, or one there still: ours stays
        if want or (open and open:IsShown()) then return end
        holder:Hide()
        Restore()
    end)
    if f:IsShown() then
        Arrange()
        Clear()
        holder:Show()
    end
end
menu.Adopt = Adopt

local function Start()
    local style = Style()
    if style ~= "docked" and style ~= "medallion" then return end
    Adopt()
    if not adopted then
        ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_GameMenu" then Adopt() end end)
    end
end

ns.On("PLAYER_LOGIN", Start)
-- while it is open: the people and the session as they change
for _, e in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "PLAYER_MONEY" }) do
    ns.On(e, function() Relayout() end)
end
-- the friends as the server has them, asked for once at login (as the
-- game's friends frame does), so the list is there before it is opened
ns.On("PLAYER_LOGIN", function()
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
end)
ns.On("GUILD_MOTD", function(_, message)
    guildMotd = message
    Relayout()
end)
-- the guild's community's broadcast: the same message, where the client
-- has communities
local function Club()
    if not (C_Club and C_Club.GetGuildClubId and C_Club.GetClubInfo) then return end
    local ok, id = pcall(C_Club.GetGuildClubId)
    local info = ok and id and C_Club.GetClubInfo(id)
    clubMotd = info and info.broadcast or nil
end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "CLUB_UPDATED" }) do
    ns.On(e, function() pcall(Club) end)
end
