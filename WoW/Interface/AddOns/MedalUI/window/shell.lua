-- The shell of MedalUI's own full-height windows: the character window
-- on the left strip, the spellbook, talents and professions on the right.
-- In the console's ink and gold, standing on its strip over the side
-- panel's place, from the screen's edge to its top.
--
--   [  @  ][  @  ][  @  ][  @  ][  @  ][  @  ] [x]
--   ---------------------------------------------------------------
--   the page
--   ---------------------------------------------------------------
--   the page's details
--   ---------------------------------------------------------------
--   (medallion)  the page's band           <- the margin
--
-- (On the right the medallion is at the band's right end.) The strip's
-- medallion stands up out of the strip into the window's bottom margin: it
-- is drawn over the window while the window is open (its buttons lifted to
-- the window's strata, the medallion's art copied over them), and the
-- margin's rule runs above it, so it covers nothing. A page may put a row
-- of its own in the margin beside the medallion (the Character page's
-- shortcuts); the others have a divider there. A page with bandFlush has
-- its margin edge to edge, as the side panel's tabs: from the window's
-- outer border to 5 short of the medallion's ring, and from its foot up
-- over the margin's rule (a row of joined buttons, ns.window.Segments,
-- meets both lines).
--
-- The tabs are icons spread across the row, flush in the window's top
-- corner, with the page's name in a tooltip (tip, or the label): the glyph
-- art/strips draws for the page (named by its key, or glyph), or the game's
-- own icon (icon). The cross, a glyph of the same set, is flush in the top
-- right corner, a gap between it and the tabs (two edges, no line). A window whose pages come and
-- go (a pet's spells, a profession learned) asks for Retab, and the row is
-- shared out again. A page with row = 2 has its tab on a second row under
-- the first, shared out across the whole width; while there is one, the
-- rule and the page stand a row lower.
--
--   local w = ns.Window{ name, named (its name, translated), side (-1 left, 1 right),
--                        closeTip, Close(), Open(page) (ask Blizzard),
--                        Lifted() -> the medallion's buttons,
--                        place (a setting: the window detaches, below),
--                        detachedOnly (with a place: never docked, no view glyph),
--                        opaque (its ink solid, not the windows' 94%),
--                        exclusive (docked, it closes the other docked
--                        windows on its strip as it opens, and they close
--                        it as they open: Close() each) }
--   Its tooltips stand outside it (ns.window.Outside; w.Beside for an owner
--   not inside it).
--   w.Page{ key, label, tip, glyph, icon, frame (Blizzard's page), order, row,
--           tabless (no tab: the page's own controls Select it),
--           heading, headGlyph (the head's words and glyph while the page
--           is open, in place of its label and icon: pages that are one
--           window's views, as the talents' trees, say the window's name),
--           Available() (or Blizzard's frame exists), height, footHeight,
--           flex, bandUsed, bandFlush, events = { ... }, Build(body, foot, band),
--           Fit(height), Refresh(), OnEvent(event, ...), Shown(),
--           Showing(on), head }
--   head = { Text() -> text, colour; Badge() -> a badge (ns.character.Badge's)
--            or nil; Click(mouse); tip() }: the page's tab is a heading, not
--            a glyph: the badge, then the words in the colour, left to right
--            (the quest's page, its title); its click and tooltip are the
--            head's, and a drag on it moves the window. w.Head() writes it
--            again.
--   headTabs() -> { { label, tip() -> text, click(), selected }, ... }: in the
--            page's tab's place, a tab for each, in words (the chat log's
--            windows); the selected one marked while the page is shown, a
--            click its own. w.Retab() asks again.
--   w.Build(), w.Select(page), w.Open(page) (as its tab does), w.ByFrame(name), w.Retab(), w.SetShown(on),
--   w.Detached(), w.Head()
--
-- Floating (detached), a window wears a lighter chrome: one soft gold line
-- and a shadow round it, its head a quiet band with no box round the tabs
-- or the cross, the page's tab underlined, its margin's rule edge to edge.
-- Docked, the look above. ns.window.Strip(parent, height) is a row edge to
-- edge across a page's body (a floating page's toolbar: its search, its
-- sorts; the quest's facts), a well between two gold lines.
--
-- A window with a place has two views, as the quest tracker has, switched
-- by a glyph left of the cross: docked, on its strip as every window
-- stands; detached, a box of its own (the bank's), dragged by its ink,
-- sized by the grip in its corner, scaled with Ctrl and the wheel over it.
-- Detached it has no medallion, its band runs edge to edge, and it is as
-- tall as it was sized, not the screen. Its place is the setting:
-- { detached, point, relative, x, y, w, h, scale }. Not in combat. A window
-- that detaches has no secure layer (Layer stands where the docked window
-- does).
--
-- Build draws into body (the page), foot (its details) and, when the page
-- says bandUsed, the margin beside the medallion; Refresh redraws
-- both, at the next frame after the page shows or one of its events comes,
-- and only while the window is open. OnEvent (optional) hears the event
-- itself first, for what only one event changes; Shown (optional) is told
-- each time the page comes into sight: the window opening on it, or its
-- tab, and Showing (optional) each time the window opens or closes on it or
-- its tab is taken or left. height is the least a fixed page needs, and Fit (optional) is told
-- the height it has, which is the screen's; a page with flex is a list,
-- which takes the same (see Layout).
local _, ns = ...
local Tr = ns.L

local L, ART = ns.stripLayout, ns.stripArt
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local WIDTH = L.chatLeft + L.chatWidth          -- from the screen's edge to the chat panel's far edge
local PAD, TAB, RULE = 8, 28, 6                 -- the edge, the tab row, the gap round a rule
local GLYPH, CONTROL = 20, 16                   -- a tab's glyph, the cross's
local GAP = 4                                   -- between the tabs and the cross
local TOP = TAB + RULE / 2                      -- the page's top, under the tabs' row
local MEDALLION = L.chatLeft                    -- the medallion's width: the strip's art left of the chat
local OVER = ART.height - L.stripHeight         -- how far the medallion stands above the strip
local BAND = OVER - 5                           -- the margin, up to its rule: as the chat's and the side panel's
local BOTTOM = BAND + RULE                      -- the page's (or its details') foot
-- A docked window's margin (2026-11-19, mockup B of /workspace/margin-B.png;
-- at the top only since /workspace/meld-sheet.png): its head and pages
-- stand this far down from the screen's top; the window's gold frame only
-- on its inner side and foot, the screen being the frame on the others,
-- and flush against the screen's edge a gold rail (RAIL: its columns, outer
-- first, bevelled), top to foot, the head and cross reaching it. Floating,
-- none.
local MARGIN = 10
local RAIL = { { 0.27, 0.22, 0.11 }, { 0.80, 0.69, 0.41 }, { 0.98, 0.90, 0.67 }, { 0.37, 0.29, 0.14 } }
local LIFT = 20                                 -- the medallion's buttons' level over the window's
local HEIGHT, LEAST = 480, { WIDTH, 240 }        -- a detached window's first height, its least size
local SCALES = { 0.6, 1.4, 0.05 }               -- a detached window's scale: least, most, a step
local GRIP = 14
local BESIDE = 4                                -- a tooltip outside the window: its gap
local GAME_ICON = 0.08                          -- the game's icons' border, trimmed
local SHADOW, DROP = 12, 3                      -- a floating window's shadow: how far out, how far down
local UNDER = 44                                -- a floating window's tab's underline
local FLOAT = { edge = 0.7, rule = 0.55, close = 0.8, dim = 0.5, head = { 0.118, 0.102, 0.071, 0.8 } }

ns.window = { width = WIDTH - 2 * PAD, pad = PAD, band = BAND }

-- A secure button b set over region by numbers from its layer's (its
-- parent's) own corner and scale, never anchored to region (see w.Layer);
-- out of combat. False when the region is not laid out.
function ns.window.Over(b, region)
    local layer = b:GetParent()
    local x, y, lx, ly = region:GetLeft(), region:GetBottom(), layer:GetLeft(), layer:GetBottom()
    if not (x and y and lx and ly) then return false end
    local k = region:GetEffectiveScale() / layer:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", x * k - lx, y * k - ly)
    b:SetSize(region:GetWidth() * k, region:GetHeight() * k)
    return true
end

-- ------------------------------------------------------------ buttons
-- As the bags window's: a gold edge, an ink well, a white glow under the
-- mouse; one of a set marked when it is in use. Drawn on b, over b or over
-- another region to (a chat tab's slim box inside its taller frame). Soft:
-- the edge faint and the well thin, so the surface under it shows through
-- (the talents' controls, over the tree's ground).
local SOFT = { edge = 0.3, well = 0.35, mark = 0.3, glow = 0.07 }
local HARD = { edge = 1, well = 1, mark = 0.45, glow = 0.12 }
local function Face(b, to, soft)
    to = to or b
    local a = soft and SOFT or HARD
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints(to)
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a.edge)
    local well = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    well:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    well:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], a.well)
    b.mark = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.mark:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    b.mark:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    b.mark:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], a.mark)
    b.mark:Hide()
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", to, "TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, a.glow)
    return well, edge, glow
end
ns.window.Face = Face           -- the chat's tabs wear it too (strips/chat.lua)

-- A gold line that fades out at both ends: a parting that is not a box.
-- Anchor it as a frame; across, its height is 1, down, its width.
local function Hair(parent, down, alpha)
    local f = CreateFrame("Frame", nil, parent)
    if down then f:SetWidth(1) else f:SetHeight(1) end
    alpha = alpha or 1
    local lit, clear
    if CreateColor then
        lit = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], alpha)
        clear = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0)
    end
    f.halves = {}
    for i = 1, 2 do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetPoint(down and (i == 1 and "TOPLEFT" or "BOTTOMLEFT") or (i == 1 and "TOPLEFT" or "TOPRIGHT"))
        t:SetPoint(down and (i == 1 and "BOTTOMRIGHT" or "TOPRIGHT") or (i == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT"),
            f, down and "RIGHT" or "BOTTOM")
        if t.SetGradient and lit then
            t:SetColorTexture(1, 1, 1, 1)
            -- across: clear at the ends; down: VERTICAL runs bottom to top
            if down then
                t:SetGradient("VERTICAL", i == 1 and lit or clear, i == 1 and clear or lit)
            else
                t:SetGradient("HORIZONTAL", i == 1 and clear or lit, i == 1 and lit or clear)
            end
        else
            t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], alpha * 0.6)
        end
        f.halves[i] = t
    end
    return f
end
ns.window.Hair = Hair

-- A row across a page edge to edge, out over the body's inset to the
-- window's border: a well between two gold lines (a floating page's
-- toolbar). Anchor its top (y down from the body's); it is as wide as the
-- window, less its border; f.At(y) moves it.
local STRIP_IN = 1
function ns.window.Strip(parent, height, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    function f.At(to)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", -(PAD - STRIP_IN), -(to or 0))
        f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", PAD - STRIP_IN, -(to or 0))
    end
    f.At(y)
    local well = f:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(0.04, 0.035, 0.024, 0.8)
    for _, at in ipairs({ "TOP", "BOTTOM" }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.7)
        t:SetHeight(1)
        t:SetPoint(at .. "LEFT")
        t:SetPoint(at .. "RIGHT")
        f[at:lower()] = t
    end
    return f
end

-- A round icon in a gold rim: the icon (returned, to texture and place),
-- with a gold disc and an ink one under it, all three masked round (the
-- bags' round mask, strips/bags.lua). A mask texture, not SetMask: a
-- texture SetMask has rounded refuses tex coords, and the icon trims its
-- border with them.
-- glow: soft gold discs under the rim (a lit medallion); icon.glows, to
-- recolour.
local GLOWS = { { 10, 0.13 }, { 18, 0.08 }, { 28, 0.04 } }     -- each disc: how much wider, its alpha
local function Ring(parent, size, glow)
    local function Disc(sub, grow)
        local t = parent:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetSize(size + grow, size + grow)
        if parent.CreateMaskTexture then
            local mask = parent:CreateMaskTexture()
            mask:SetTexture(ns.media .. "strips\\round", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            t:AddMaskTexture(mask)
            t.round = mask
        end
        return t
    end
    local rim, well, icon = Disc(1, 4), Disc(2, 2), Disc(3, 0)
    rim:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    well:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], 1)
    rim:SetPoint("CENTER", icon)
    well:SetPoint("CENTER", icon)
    icon:SetTexCoord(GAME_ICON, 1 - GAME_ICON, GAME_ICON, 1 - GAME_ICON)
    icon.rim, icon.well = rim, well
    if glow then
        rim:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        icon.glows = {}
        for i, g in ipairs(GLOWS) do
            local t = Disc(1 - i, g[1])
            t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], g[2])
            t:SetPoint("CENTER", icon)
            t.alpha = g[2]
            icon.glows[i] = t
        end
    end
    return icon
end
ns.window.Ring = Ring

-- A tab with no box (Segments' soft = "open"): its mark a gold underline and a
-- glow rising from it, under the face (b.top), where the glyph is drawn.
local function Bare(b)
    b.mark = CreateFrame("Frame", nil, b)
    b.mark:SetAllPoints()
    b.mark:Hide()
    b.top = CreateFrame("Frame", nil, b)
    b.top:SetAllPoints()
    b.top:SetFrameLevel(b.mark:GetFrameLevel() + 1)
    local rise = b.mark:CreateTexture(nil, "BACKGROUND")
    rise:SetPoint("TOPLEFT", 10, -2)
    rise:SetPoint("BOTTOMRIGHT", -10, 0)
    if rise.SetGradient and CreateColor then
        rise:SetColorTexture(1, 1, 1, 1)
        rise:SetGradient("VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.2),
            CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
    else
        rise:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
    end
    local line = b.mark:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 10, 0)
    line:SetPoint("BOTTOMRIGHT", -10, 0)
    line:SetHeight(2)
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.mark.line = line
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetPoint("TOPLEFT", 4, -2)
    glow:SetPoint("BOTTOMRIGHT", -4, 0)
    glow:SetColorTexture(1, 1, 1, 0.06)
    return glow
end

-- soft: Face's soft look; "open": Bare's
-- a button's tooltip: beside the window it is in (ns.window.Outside), or
-- over it
function ns.window.OutsideTop(owner) ns.window.Outside(owner, "ANCHOR_TOP") end
local OutsideTop = function(owner) ns.window.OutsideTop(owner) end

local function Button(parent, width, click, tip, template, soft)
    local b = CreateFrame("Button", nil, parent, template)
    b:SetSize(width, TAB)
    if soft == "open" then Bare(b) else b.well, b.edge = Face(b, nil, soft) end
    b.label = ns.Text(b, 12)
    b.label:SetPoint("CENTER")
    if click then b:SetScript("OnClick", click) end
    b:SetScript("OnEnter", function(self)
        ns.Tip(self, self.tipAt or OutsideTop, { title = tip(), color = ns.colors.white, wrap = true })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
ns.window.Button = Button

-- ------------------------------------------------------------- segments
-- A row of joined buttons, as the chat's and the side panel's tabs: each
-- wears the box (Face), neighbours share their edge (a pixel's overlap),
-- and where the group changes the two edges stand a little apart: a
-- double line, as before the chat's tools. Stretched, the buttons share out the
-- row's width (an icon keeps its own, 2026-11-11); fit, each is as wide as its word and the row as wide as
-- they come to (anchor it by the end it grows from).
--
--   local row = ns.window.Segments(parent, { height, fit, size (the
--               words', 12), iconSize (24), tipAt, items, soft (true:
--               Face's soft look; "open": tabs with no box, Bare's),
--               tabs (2026-11-19, /workspace/sleek-character.png: Bare's,
--               the held one's underline as wide as its word over a gold
--               fade bright at its middle, the others' words dim, a
--               hairline under the row) })
--   row:Fill({ { key, label, icon, group, tip() -> text, click(button),
--                selected, enabled, shown, color } ... })   (again: the
--               buttons kept, their words and deeds changed)
--   row:Set(key, { selected, enabled, shown, color, lit })   one's state
--               (lit = { wash = { r, g, b, a }, color = { r, g, b } }: its
--               well washed, its icon in the colour: the waypoint's)
--   row:Layout()          shared out again (as its width changes)
--   row.byKey[key], row.buttons, row.gaps (where each gap starts)
--
-- Selected: the mark, its word gold. Off (enabled false): its word dim
-- and no glow, its tooltip still saying why; its click still goes to the
-- page, which asks the game itself (a state set a moment ago may already
-- be stale: a specialization just learned). color overrides the word's
-- colour (the talents' spec in use).
--
-- An icon (a glyph of media/strips, by name) stands in for the word: dim
-- (as the window's tabs) until selected, faint when off; the word heads
-- its tooltip, over the tip.
local SEG_PAD, SEG_MIN, BREAK = 20, 36, 4       -- a fit button's room past its word, its least; the gap between groups
local ICON_PAD = 12                              -- a fit button's room past its icon
local function Paint(b)
    b.mark:SetShown(b.selected and true or false)
    b.glow:SetShown(b.enabled)
    local c = not b.enabled and ns.colors.dim or b.color or b.selected and GOLD
        or b.tabs and ns.colors.dim or ns.colors.text
    b.label:SetTextColor(c[1], c[2], c[3])
    b.icon:SetAlpha(not b.enabled and 0.3 or (b.selected or b.lit) and 1 or 0.6)
    local lit = b.lit
    if lit and not b.wash then
        b.wash = b:CreateTexture(nil, "BACKGROUND", nil, 4)
        b.wash:SetAllPoints(b.mark)
    end
    if b.wash then
        b.wash:SetShown(lit and true or false)
        if lit then b.wash:SetColorTexture(unpack(lit.wash)) end
    end
    b.icon:SetDesaturated(lit and true or false)
    if lit then b.icon:SetVertexColor(unpack(lit.color)) else b.icon:SetVertexColor(1, 1, 1) end
end

local function Segments(parent, spec)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(spec.height)
    row.buttons, row.byKey, row.gaps = {}, {}, {}
    if spec.tabs then
        spec.soft = "open"
        row.hair = row:CreateTexture(nil, "BACKGROUND")
        row.hair:SetHeight(1)
        row.hair:SetPoint("BOTTOMLEFT")
        row.hair:SetPoint("BOTTOMRIGHT")
        row.hair:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.45)
    end
    local n = 0                         -- the buttons in use

    function row:Layout()
        local shown = {}
        for i = 1, n do
            local b = self.buttons[i]
            b:SetShown(b.shown)
            if b.shown then table.insert(shown, b) end
        end
        local breaks = 0
        for i = 2, #shown do
            if shown[i].data.group ~= shown[i - 1].data.group then breaks = breaks + 1 end
        end
        -- the width less the gaps, the shared edges given back; none yet
        -- (not placed): as wide as their words until it comes
        -- (OnSizeChanged lays them out again)
        local total = math.floor(self:GetWidth() or 0) - breaks * BREAK + (#shown - 1 - breaks)
        local fit = spec.fit or total < #shown * SEG_MIN
        local widths = {}
        -- stretched, an icon keeps its own width and the words share the rest
        local words, icons = 0, 0
        for _, b in ipairs(shown) do
            if b.data.icon then icons = icons + (spec.iconSize or 24) + ICON_PAD else words = words + 1 end
        end
        local share, k = total - icons, 0
        for i, b in ipairs(shown) do
            local inner = b.data.icon and (spec.iconSize or 24) + ICON_PAD or math.ceil(b.label:GetStringWidth()) + SEG_PAD
            if fit or b.data.icon then
                widths[i] = fit and math.max(SEG_MIN, inner) or inner
            else
                k = k + 1
                widths[i] = math.floor(k * share / words) - math.floor((k - 1) * share / words)
            end
        end
        local x = 0
        self.gaps = {}
        for i, b in ipairs(shown) do
            if i > 1 then
                if b.data.group ~= shown[i - 1].data.group then
                    table.insert(self.gaps, x)  -- where the gap starts
                    x = x + BREAK
                else
                    x = x - 1               -- the edge shared
                end
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, 0)
            b:SetWidth(widths[i])
            x = x + widths[i]
        end
        if spec.fit then self:SetWidth(math.max(1, x)) end
    end

    function row:Set(key, state)
        local b = self.byKey[key]
        if not b then return end
        local was = b.shown
        b.selected = state.selected and true or false
        b.enabled = state.enabled ~= false
        b.shown = state.shown ~= false
        b.color = state.color
        b.lit = state.lit
        Paint(b)
        if b.shown ~= was then self:Layout() end
    end

    function row:Fill(items)
        wipe(self.byKey)
        n = #items
        for i, d in ipairs(items) do
            local b = self.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, self)
                b:SetHeight(spec.height)
                local face = b
                if spec.soft == "open" then
                    b.glow = Bare(b)
                    face = b.top                -- over the mark's glow
                else
                    local _, _, glow = Face(b, nil, spec.soft)
                    b.glow = glow
                end
                b.label = ns.Text(face, spec.size or 12)
                b.label:SetPoint("CENTER")
                if spec.tabs then
                    -- the underline as wide as the word; the fade across,
                    -- bright at the middle, in place of Bare's rise
                    b.tabs = true
                    local line = b.mark.line
                    line:ClearAllPoints()
                    line:SetPoint("BOTTOMLEFT", b.label, "LEFT", -4, -(spec.height / 2))
                    line:SetPoint("BOTTOMRIGHT", b.label, "RIGHT", 4, -(spec.height / 2))
                    local regions = { b.mark:GetRegions() }
                    for _, t in ipairs(regions) do
                        if t ~= line then t:Hide() end
                    end
                    for k, at in ipairs({ "LEFT", "RIGHT" }) do
                        local half = b.mark:CreateTexture(nil, "BACKGROUND")
                        half:SetPoint("TOP" .. at, 0, 0)
                        half:SetPoint("BOTTOM", 0, 0)
                        half:SetPoint(at == "LEFT" and "BOTTOMRIGHT" or "BOTTOMLEFT", b, "BOTTOM", 0, 0)
                        if half.SetGradient and CreateColor then
                            half:SetColorTexture(1, 1, 1, 1)
                            local lo = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0)
                            local hi = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.35)
                            half:SetGradient("HORIZONTAL", k == 1 and lo or hi, k == 1 and hi or lo)
                        else
                            half:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.15)
                        end
                    end
                end
                b.icon = face:CreateTexture(nil, "ARTWORK")
                b.icon:SetSize(spec.iconSize or 24, spec.iconSize or 24)
                b.icon:SetPoint("CENTER")
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                b:SetScript("OnClick", function(self, button)
                    if self.data.click then self.data.click(button) end
                end)
                b:SetScript("OnEnter", function(self)
                    local d = self.data
                    local tip = d.tip and d.tip()
                    if d.icon and d.label then
                        ns.Tip(self, spec.tipAt or OutsideTop, { title = d.label, color = GOLD, wrap = true,
                            tip and { "body", tip } or nil })
                    elseif tip then
                        ns.Tip(self, spec.tipAt or OutsideTop, { title = tip, color = ns.colors.white, wrap = true })
                    end
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.buttons[i] = b
            end
            b.data = d
            b.label:SetText(not d.icon and d.label or "")
            b.icon:SetShown(d.icon and true or false)
            if d.icon then b.icon:SetTexture(ns.media .. "strips\\" .. d.icon) end
            b.selected, b.enabled, b.shown, b.color = d.selected and true or false, d.enabled ~= false,
                d.shown ~= false, d.color
            b.lit = d.lit
            Paint(b)
            if d.key ~= nil then self.byKey[d.key] = b end
        end
        for i = n + 1, #self.buttons do self.buttons[i]:Hide() end
        self:Layout()
    end

    row:SetScript("OnSizeChanged", function(self) if not spec.fit then self:Layout() end end)
    if spec.items then row:Fill(spec.items) end
    return row
end
ns.window.Segments = Segments

-- ------------------------------------------------------------- scrolling
-- A list that scrolls, in a scroll frame filling the body but for a gutter
-- at the left, where its bar stands: a track and a gold thumb, which a
-- press or a drag places. To(y) eases the list there (the wheel), or sends
-- it at once (now: the bar dragged). Lay the list out in s.child, and call
-- To(s.target) as it changes, to keep it in range. s.Moved, if set, is
-- called as the list moves.
--
-- outside (2026-11-19): the list fills the body and the bar stands out of
-- it, beside its outer edge (the screen's side), in the window's margin:
-- the shell places it (Edge, from Under) as the window docks or floats.
local scrollers = {}
local function Scroller(body, gutter, outside)
    local s = { target = 0, offset = 0, body = body, outside = outside }
    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", outside and 0 or gutter, 0)
    scroll:SetPoint("BOTTOMRIGHT")
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    local bar = CreateFrame("Frame", nil, body)
    if outside then
        bar:SetWidth(6)
        table.insert(scrollers, s)
    else
        bar:SetPoint("TOPLEFT")
        bar:SetPoint("BOTTOMLEFT")
        bar:SetWidth(gutter - 4)
    end
    -- beside the body's outer edge (side 1: its right), its middle offset out
    function s.Edge(side, offset)
        local at = side > 0 and "RIGHT" or "LEFT"
        local x = side > 0 and offset - 3 or -(offset + 3)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", body, "TOP" .. at, x, 0)
        bar:SetPoint("BOTTOMLEFT", body, "BOTTOM" .. at, x, 0)
    end
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetWidth(1)
    track:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
    bar.thumb = bar:CreateTexture(nil, "ARTWORK")
    bar.thumb:SetWidth(3)
    bar.thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    s.scroll, s.child, s.bar = scroll, child, bar

    -- the bar: shown while there is more than fits, its thumb as long as
    -- the share that shows, as far down as the list is
    function s.Thumb()
        local range = scroll:GetVerticalScrollRange() or 0
        bar:SetShown(range > 0)
        if range <= 0 then return end
        local h = scroll:GetHeight()
        local size = math.max(16, h * h / (h + range))
        bar.thumb:SetHeight(size)
        bar.thumb:ClearAllPoints()
        bar.thumb:SetPoint("TOP", bar, "TOP", 0, -(h - size) * s.offset / range)
        bar.size = size
    end

    local function Ease(_, elapsed)
        s.offset = s.offset + (s.target - s.offset) * math.min(1, elapsed * 12)
        if math.abs(s.target - s.offset) < 0.5 then
            s.offset = s.target
            scroll:SetScript("OnUpdate", nil)
        end
        scroll:SetVerticalScroll(s.offset)
        s.Thumb()
        if s.Moved then s.Moved() end
    end
    function s.To(to, now)
        local range = scroll:GetVerticalScrollRange() or 0
        s.target = math.max(0, math.min(range, to or 0))
        s.offset = math.max(0, math.min(range, s.offset))
        if now then s.offset = s.target end
        scroll:SetVerticalScroll(s.offset)
        s.Thumb()
        scroll:SetScript("OnUpdate", s.offset ~= s.target and Ease or nil)
        if s.Moved then s.Moved() end
    end

    -- pressed: the thumb's middle goes to the cursor, and follows it
    local function Drag()
        local range = scroll:GetVerticalScrollRange() or 0
        local h, size = scroll:GetHeight(), bar.size or 16
        if range <= 0 or h <= size then return end
        local _, y = GetCursorPosition()
        y = y / bar:GetEffectiveScale()
        s.To((bar:GetTop() - y - size / 2) / (h - size) * range, true)
    end
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function()
        Drag()
        bar:SetScript("OnUpdate", Drag)
    end)
    bar:SetScript("OnMouseUp", function() bar:SetScript("OnUpdate", nil) end)
    bar:SetScript("OnHide", function() bar:SetScript("OnUpdate", nil) end)
    bar:Hide()
    return s
end
ns.window.Scroller = Scroller
ns.window.scrollers = scrollers

-- GameTooltip for owner, outside frame: beside its inner edge (side 1, a
-- frame on the right strip: its left; -1: its right), its top level with
-- the owner's; the offset is in the tooltip's own scale. Done in place of
-- SetOwner, and an anchor ns.Tip takes. The windows' (w.Beside,
-- ns.window.Outside), the side panel's (ns.side.Beside).
local placing                                  -- PlaceTip's own SetPoint (the hook below)
local function PlaceTip(frame, owner, side, tip, rise)
    tip = tip or GameTooltip                   -- or another: the chat's clicked links (ItemRefTooltip)
    placing = true
    tip:ClearAllPoints()
    local k = frame:GetEffectiveScale() / tip:GetEffectiveScale()
    if side == "down" then
        -- under the frame, below the owner: its centre across, in the tooltip's scale
        local l, r, fl, fr = owner:GetLeft(), owner:GetRight(), frame:GetLeft(), frame:GetRight()
        local dx = l and r and fl and fr and ((l + r) - (fl + fr)) / 2 * k or 0
        tip:SetPoint("TOP", frame, "BOTTOM", dx, -BESIDE)
        placing = false
        return
    end
    -- rise (a corner strip's mark): an owner under the frame (the strip's
    -- row, its medallion, under the side panel it stands for) has the foot
    -- level with its own, rising from the row rather than off the screen
    local foot, base = owner:GetBottom(), frame:GetBottom()
    if rise and owner ~= frame and foot and base and foot < base then
        local dy = (foot - base) * k
        if side > 0 then
            tip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -BESIDE, dy)
        else
            tip:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", BESIDE, dy)
        end
        placing = false
        return
    end
    local top, edge = owner:GetTop(), frame:GetTop()
    local dy = top and edge and (top - edge) * k or 0
    if side > 0 then
        tip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -BESIDE, dy)
    else
        tip:SetPoint("TOPLEFT", frame, "TOPRIGHT", BESIDE, dy)
    end
    placing = false
end

-- A footer button's choices, in a dialog over it (the quest log's Sort,
-- the spellbook's Top rank): the game menu's options' look (window/gamemenu.lua,
-- its joined keys), a notch down to the button, a small heading, and a key
-- for each choice sharing the width. A pick sets it and the dialog stays, its
-- key held; a click anywhere else, the button again, Escape, or Close shuts it.
--
--   local pop = ns.window.Choices{ name (global, for Escape), title, width,
--                   choices = { { value, label, tip } }, Get(), Set(value),
--                   Anchor() -> the button, Opened(open) (the button marked),
--                   side = "left" (beside the button, at its left, the notch
--                   pointing right: the side panel's column, on the right
--                   strip; else over it) }
--   pop.Open(), pop.Close(), pop.Toggle(), pop.IsOpen(), pop.Mark() (after
--   a change elsewhere); pop.frame, pop.catcher, pop.keys (each .word, .held)
local POP_INK = { 0.078, 0.067, 0.047 }
local POP_DIM = { 0.55, 0.52, 0.45 }
local POP_SEG = 22
function ns.window.Choices(spec)
    local pop = {}
    local function Build()
        if pop.frame then return pop.frame end
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        catcher:SetScript("OnClick", function() pop.Close() end)
        catcher:Hide()
        local width = spec.width or 220
        local f = CreateFrame("Frame", spec.name, catcher)
        f:SetFrameLevel(catcher:GetFrameLevel() + 5)
        f:SetWidth(width)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        shadow:SetPoint("TOPLEFT", 4, -6)
        shadow:SetPoint("BOTTOMRIGHT", 4, -6)
        shadow:SetColorTexture(0, 0, 0, 0.55)
        local edge = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local ink = f:CreateTexture(nil, "BACKGROUND", nil, 3)
        ink:SetPoint("TOPLEFT", 1, -1)
        ink:SetPoint("BOTTOMRIGHT", -1, 1)
        ink:SetColorTexture(POP_INK[1], POP_INK[2], POP_INK[3], 1)
        -- the notch, down to the button's middle: a gold diamond, its upper
        -- half the dialog's ink
        local notch = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        notch:SetSize(9, 9)
        local left = spec.side == "left"
        notch:SetPoint("CENTER", f, left and "RIGHT" or "BOTTOM", 0, 0)
        notch:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local fill = f:CreateTexture(nil, "BACKGROUND", nil, 4)
        fill:SetSize(7, 7)
        fill:SetPoint("CENTER", f, left and "RIGHT" or "BOTTOM", left and -1 or 0, left and 0 or 1)
        fill:SetColorTexture(POP_INK[1], POP_INK[2], POP_INK[3], 1)
        if notch.SetRotation then
            notch:SetRotation(math.pi / 4)
            fill:SetRotation(math.pi / 4)
        end
        local label = ns.Text(f, 9)
        label:SetPoint("TOPLEFT", 12, -12)
        label:SetText(ns.Upper(spec.title))
        label:SetTextColor(unpack(POP_DIM))
        pop.keys = {}
        local w, n = width - 24, #spec.choices
        for i, o in ipairs(spec.choices) do
            local k = CreateFrame("Button", nil, f)
            local x0, x1 = math.floor((i - 1) * w / n), math.floor(i * w / n)
            k:SetPoint("TOPLEFT", 12 + x0, -28)
            k:SetSize(x1 - x0 + (i < n and 1 or 0), POP_SEG)
            k:RegisterForClicks("LeftButtonUp")
            ns.gameMenu.Keyed(k)
            k.word = ns.Text(k, 11)
            k.word:SetPoint("CENTER")
            k.word:SetText(o[2])
            k.value = o[1]
            k:SetScript("OnClick", function()
                spec.Set(o[1])
                pop.Mark()
            end)
            k:HookScript("OnEnter", function(self)
                ns.Tip(self, ns.window.Outside, { title = o[2], { "hint", o[3] } })
            end)
            k:HookScript("OnLeave", function() GameTooltip:Hide() end)
            pop.keys[i] = k
        end
        f:SetHeight(28 + POP_SEG + 12)
        pop.frame, pop.catcher = f, catcher
        if spec.name and UISpecialFrames then table.insert(UISpecialFrames, spec.name) end
        f:SetScript("OnHide", function() pop.Close() end)
        return f
    end

    -- its keys as the choice now is: the one in use held, its word lit
    function pop.Mark()
        if not pop.keys then return end
        local now = spec.Get()
        for _, k in ipairs(pop.keys) do
            k.held = k.value == now
            k.Lit(false)
            k.word:SetTextColor(unpack(k.held and ns.colors.text or POP_DIM))
        end
    end

    function pop.IsOpen() return pop.catcher ~= nil and pop.catcher:IsShown() end

    function pop.Open()
        local f = Build()
        pop.Mark()
        local b = spec.Anchor and spec.Anchor()
        f:ClearAllPoints()
        if b and spec.side == "left" then f:SetPoint("RIGHT", b, "LEFT", -8, 0)
        elseif b then f:SetPoint("BOTTOM", b, "TOP", 0, 8) else f:SetPoint("CENTER") end
        pop.catcher:Show()
        f:Show()
        if spec.Opened then spec.Opened(true) end
    end

    function pop.Close()
        if not pop.IsOpen() then return end
        pop.catcher:Hide()
        if spec.Opened then spec.Opened(false) end
    end

    function pop.Toggle()
        if pop.IsOpen() then pop.Close() else pop.Open() end
    end
    return pop
end

function ns.window.Beside(frame, owner, side, rise)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    PlaceTip(frame, owner, side, nil, rise)
end

-- A frame tooltips stand outside: side its default (1: it stands on the
-- right, -1: the left), taken from where it is when it can be (a window
-- dragged across); "down": under it always, below the owner (the
-- overhead); a function: asked each time for either, and kept to (an
-- option's: the overhead's flyouts); at: the frame they stand beside instead (a cast layer
-- marks its window); rise: an owner under the frame it stands beside has
-- the tooltip's foot level with its own (a corner strip, under its panel).
-- ns.window.Outside(owner, fallback) is GameTooltip for
-- an owner inside one, beside the nearest such frame up its parents, on the
-- side towards the screen's middle; outside any, SetOwner by fallback
-- ("ANCHOR_RIGHT" when not given). An anchor ns.Tip takes, as is.
-- The marks are kept here, not on the frame: Blizzard's may be marked too
-- (the Cooldown Manager's window), and nothing is written onto those.
local marks = setmetatable({}, { __mode = "k" })    -- frame: { side, at, rise }
function ns.window.Mark(frame, side, at, rise) marks[frame] = { side = side, at = at, rise = rise } end

local function Facing(frame, m)
    m = m or marks[frame]                       -- the mark of the frame it stands beside for (at)
    if m and type(m.side) == "function" then return m.side() end
    if m and m.side == "down" then return "down" end
    local l, r, w = frame:GetLeft(), frame:GetRight(), UIParent:GetWidth()
    if not (l and r and w and w > 0) then return m and m.side or 1 end
    return (l + r) / 2 * frame:GetEffectiveScale() > w * UIParent:GetEffectiveScale() / 2 and 1 or -1
end

-- the marked frame owner is inside (or the one it marks), and its mark; or nil
local function Marked(owner)
    local f = owner
    while f and not marks[f] do f = f.GetParent and f:GetParent() end
    if f then return marks[f].at or f, marks[f] end
end

-- tip (a tooltip of its own, not GameTooltip: ItemRefTooltip; or a menu)
-- beside the marked frame owner is inside, its top level with the frame's
-- (level: with owner's, as GameTooltip's); false when owner is in none
function ns.window.PlaceOutside(tip, owner, level)
    local f, m = Marked(owner)
    if not f then return false end
    PlaceTip(f, level and owner or f, Facing(f, m), tip, m.rise)
    return true
end
function ns.window.Unmark(frame) marks[frame] = nil end

function ns.window.Outside(owner, fallback)
    local f, m = Marked(owner)
    if f then return ns.window.Beside(f, owner, Facing(f, m), m.rise) end
    GameTooltip:SetOwner(owner, type(fallback) == "string" and fallback or "ANCHOR_RIGHT")
end

-- Blizzard's own buttons in a marked frame (the gear slots, the bags' items)
-- own the tooltip by their own Lua, on every refresh too: by an anchor the
-- game applies again as the text fills it (ANCHOR_RIGHT), or by points of
-- their own set after SetOwner (beside the bag item, the default place).
-- So: once owned, no anchor of the game's (SetAnchorType, which keeps the
-- text); and whenever it is placed by anyone else while its owner is under
-- the mouse, placed back beside the frame. The tooltip's C methods alone.
-- Not under the mouse: a tooltip fading out, or parked by mdlui_Tooltips.
local function Own(owner)
    local f, m = Marked(owner)
    if not f then return end
    if GameTooltip.SetAnchorType then GameTooltip:SetAnchorType("ANCHOR_NONE") end
    PlaceTip(f, owner, Facing(f, m), nil, m.rise)
end
hooksecurefunc(GameTooltip, "SetOwner", function(_, owner) Own(owner) end)
hooksecurefunc(GameTooltip, "SetPoint", function(self)
    if placing then return end
    local owner = self:GetOwner()
    if owner and owner.IsMouseOver and owner:IsMouseOver() then Own(owner) end
end)
-- for mdlui_Tooltips: true when the tooltip owner shows stands beside a
-- window of ours, placed here (its cursor-following leaves it alone)
function MedalUI_TooltipBeside(owner) return owner ~= nil and (Marked(owner)) ~= nil end

-- ---------------------------------------------------------- decoration
-- A divider: a gold rule each side of a diamond, or of a word.
local function Ornament(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(12)
    local mid
    if label then
        mid = ns.Text(f, 11)
        mid:SetText(label)
        mid:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        mid = f:CreateTexture(nil, "ARTWORK")
        mid:SetSize(6, 6)
        mid:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        mid:SetRotation(math.pi / 4)
    end
    mid:SetPoint("CENTER")
    for _, side in ipairs({ -1, 1 }) do
        local rule = f:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetHeight(1)
        rule:SetPoint(side < 0 and "LEFT" or "RIGHT")
        rule:SetPoint(side < 0 and "RIGHT" or "LEFT", mid, side < 0 and "LEFT" or "RIGHT", side * 8, 0)
    end
    f.mid = mid
    return f
end
ns.window.Ornament = Ornament

-- A section's heading: its word on a gilded plate, a gold point at each
-- end, and a rule from each point fading out to the page's edge.
local RIBBON = 22
local function Ribbon(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(RIBBON)
    f.label = ns.Text(f, 12)
    f.label:SetText(label)
    f.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    f.label:SetPoint("CENTER", 0, 0)
    local plate = CreateFrame("Frame", nil, f)
    plate:SetSize(math.floor((f.label:GetStringWidth() or 0) + 36), RIBBON - 2)
    plate:SetPoint("CENTER")
    plate:SetFrameLevel(f:GetFrameLevel())
    local edge = plate:CreateTexture(nil, "BORDER")
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    local fill = plate:CreateTexture(nil, "BORDER", nil, 1)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(0.2, 0.165, 0.1, 1)
    local shine = plate:CreateTexture(nil, "BORDER", nil, 2)
    shine:SetPoint("TOPLEFT", 2, -2)
    shine:SetPoint("TOPRIGHT", -2, -2)
    shine:SetHeight(1)
    shine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    f.plate, f.points = plate, {}
    for i, side in ipairs({ -1, 1 }) do
        local tip = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        tip:SetSize(11, 11)
        tip:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        tip:SetRotation(math.pi / 4)
        tip:SetPoint("CENTER", plate, side < 0 and "LEFT" or "RIGHT", 0, 0)
        f.points[i] = tip
        local rule = f:CreateTexture(nil, "BACKGROUND")
        rule:SetHeight(1)
        rule:SetPoint(side < 0 and "LEFT" or "RIGHT")
        rule:SetPoint(side < 0 and "RIGHT" or "LEFT", plate, side < 0 and "LEFT" or "RIGHT", side * 9, 0)
        if rule.SetGradient and CreateColor then
            local lit = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            local clear = CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0)
            rule:SetColorTexture(1, 1, 1, 1)
            rule:SetGradient("HORIZONTAL", side < 0 and clear or lit, side < 0 and lit or clear)
        else
            rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.6)
        end
        f[side < 0 and "left" or "right"] = rule
    end
    return f
end
ns.window.Ribbon = Ribbon
ns.window.RIBBON = RIBBON

-- The chat box's frame, and the quest tracker's when there is no chat box
-- (strips/chat.lua, quests/tracker.lua): the windows' gold trim, the
-- ink fading from solid at the left to a tenth at the right
-- so it can stand open over the world (the trim drawn as four lines, so
-- nothing shows through it), and the medallion's margin under its rule:
-- band high (the windows' own when not given). Mirrored (the side panel,
-- strips/side.lua), the ink is solid at the right instead.
local FADE = { 1, 0.10 }
local function Dress(parent, band, mirrored)
    local dress = CreateFrame("Frame", nil, parent)
    dress:SetAllPoints()
    dress:SetFrameLevel(parent:GetFrameLevel())
    local tint = ns.colors.ink
    local ink = dress:CreateTexture(nil, "BACKGROUND", nil, 1)
    ink:SetPoint("TOPLEFT", 1, -1)
    ink:SetPoint("BOTTOMRIGHT", -1, 1)
    if ink.SetGradient and CreateColor then
        ink:SetColorTexture(1, 1, 1, 1)
        local from, to = FADE[1], FADE[2]
        if mirrored then from, to = to, from end
        ink:SetGradient("HORIZONTAL", CreateColor(tint[1], tint[2], tint[3], from),
            CreateColor(tint[1], tint[2], tint[3], to))
    else
        ink:SetColorTexture(tint[1], tint[2], tint[3], (FADE[1] + FADE[2]) / 2)
    end
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" } }) do
        local t = dress:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        t[edge[3]](t, 1)
    end
    local bandRule = dress:CreateTexture(nil, "ARTWORK")
    bandRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    bandRule:SetHeight(1)
    bandRule:SetPoint("BOTTOMLEFT", PAD, band or BAND)
    bandRule:SetPoint("BOTTOMRIGHT", -PAD, band or BAND)
    dress.ink, dress.rule = ink, bandRule
    return dress
end
ns.window.Dress = Dress

-- a control's glyph, centred in its button
local function Glyph(b, name)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(CONTROL, CONTROL)
    b.icon:SetPoint("CENTER")
    if name then b.icon:SetTexture(ns.media .. "strips\\" .. name) end
end

-- the medallion's corner, the band's inner and outer ends: on the left the
-- medallion is at the window's left, on the right at its right
local function Outer(side, point) return side < 0 and point .. "LEFT" or point .. "RIGHT" end

-- the windows on each strip, for the exclusive ones (spec.exclusive)
local docked = { [-1] = {}, [1] = {} }

-- ---------------------------------------------------------------- a window
function ns.Window(spec)
    local side = spec.side
    local pages = {}
    local w = { pages = pages, width = WIDTH - 2 * PAD, side = side,
        band = { left = side < 0 and MEDALLION + PAD or PAD, right = side < 0 and PAD or MEDALLION + PAD,
            height = BAND } }
    local window, close, rule, footRule, medal, view, grip
    local chrome = {}                   -- the floating look's parts (Chrome)
    w.chrome = chrome                   -- (the harness reads them)
    local floating = false
    local pageTop = TOP                 -- the page's top: a row lower with a second row of tabs
    local current, dirty
    local tabs = {}
    local drop = {}             -- the pages' dropdown (Tabs): its head, its list beside the window
    local Corner                -- (Tabs) the cross's corner
    local Bars                  -- (Make) the pages' outside scroll bars placed
    local Joined                -- (Make) a page's panel joined under the head
    -- the margin docked (MARGIN, above): the top's; the sides' none (the
    -- left's, the right's kept for the callers); floating, none
    local function Inset()
        return floating and 0 or MARGIN, 0, 0
    end
    -- the chrome's (the head's, the cross's, a joined panel's) insets from
    -- the window's sides: docked, the outer side's to the rail
    local function Edges()
        local m = floating and 0 or #RAIL
        return side < 0 and m or 0, side > 0 and m or 0
    end
    -- a page's top: under its joined panel (under), or the window's
    local function TopOf(p)
        if p and p.under and p.panel then return Inset() + TAB + p.under + RULE end
        return pageTop
    end
    local listener = CreateFrame("Frame")
    w.listener = listener
    w.exclusive = spec.exclusive and true or false
    function w.Close() spec.Close() end
    table.insert(docked[side], w)

    function w.Page(page)
        table.insert(pages, page)
    end

    -- the detached view's place (none for a window that stays docked)
    local function At() return spec.place and type(ns.db[spec.place]) == "table" and ns.db[spec.place] or {} end
    function w.Detached() return (spec.detachedOnly or At().detached) and true or false end

    -- A page's margin: beside the medallion, inside the edge; flush, from
    -- the outer border to short of the medallion's ring (edge to edge
    -- detached), over the margin's rule.
    local function BandAt(p)
        local off = w.Detached()
        p.band:ClearAllPoints()
        if p.bandFlush then
            local medal = off and 0 or ns.stripWell.x + L.ringRadius + 5
            p.band:SetPoint("BOTTOMLEFT", side < 0 and medal or 0, 0)
            p.band:SetPoint("BOTTOMRIGHT", -(side < 0 and 0 or medal), 0)
            p.band:SetHeight(BAND + 1)
        else
            p.band:SetPoint("BOTTOMLEFT", off and PAD or w.band.left, 0)
            p.band:SetPoint("BOTTOMRIGHT", -(off and PAD or w.band.right), 0)
            p.band:SetHeight(BAND)
        end
    end

    -- -------------------------------------------------------- medallion
    -- The medallion's buttons lifted to the window's strata while the
    -- window is open, under a copy of the medallion's art; put back when
    -- it closes. The copy fades with the strip.
    local function Lift(on)
        local strip = ns.strips[side]
        if on and w.Detached() then on = false end
        for i, f in ipairs(spec.Lifted()) do
            if not (f:IsProtected() and InCombatLockdown()) then
                if on then
                    f:SetFrameStrata(window:GetFrameStrata())
                    f:SetFrameLevel(window:GetFrameLevel() + LIFT + i - 1)
                else
                    f:SetFrameStrata(strip:GetFrameStrata())
                    f:SetFrameLevel(ns.levels.stripWell + i - 1)
                end
            end
        end
    end

    -- Lowered under an open window that wants it up: another window on its
    -- side that lifts the same button (the backpack: the book's, the
    -- talents', the quest log's) closed, or opened detached, and put it back
    -- on the strip; or it was opened in combat, where a protected one stays.
    -- The open window lifts it again, out of combat.
    local function Sunk()
        if w.Detached() then return false end
        local level = window:GetFrameLevel() + LIFT
        for _, f in ipairs(spec.Lifted()) do
            if f:GetFrameStrata() ~= window:GetFrameStrata() or f:GetFrameLevel() < level then return true end
        end
        return false
    end

    local function Medal()
        medal = CreateFrame("Frame", nil, window)
        medal:SetFrameLevel(window:GetFrameLevel() + LIFT + 2)
        medal:SetIgnoreParentAlpha(true)
        medal:SetSize(MEDALLION, ART.height)
        medal:SetPoint(Outer(side, "BOTTOM"), window, Outer(side, "BOTTOM"), 0, -L.stripHeight)
        local art = medal:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints()
        art:SetTexture(ns.media .. "strip")
        -- the right strip's art is the left's, mirrored
        local u, v = MEDALLION / ART.texWidth, ART.height / ART.texHeight
        if side < 0 then art:SetTexCoord(0, u, 0, v) else art:SetTexCoord(u, 0, 0, v) end
        window.medal = medal
    end

    -- ----------------------------------------------------------- layout
    -- How tall the window is: the screen above the strip.
    local function Room()
        if w.Detached() then return At().h or HEIGHT end
        local strip = ns.strips[side]
        local scale = strip:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return UIParent:GetHeight() / scale - L.stripHeight
    end

    -- What a page's details take, rule and all.
    local function Foot(page)
        if not (page.footHeight and page.footHeight > 0) then return 0 end
        return page.footHeight + 2 * RULE + 1
    end

    -- The window runs to the screen's top, on every page, so it keeps its
    -- height from tab to tab; a fixed page spreads out over it (Fit), a list
    -- fills it. On a screen too short for the tallest fixed page, that page
    -- runs off the top, and a list gives up height to fit.
    local function Layout()
        if not current then return end
        local least = 0
        for _, p in ipairs(pages) do
            if p.available and not p.flex then least = math.max(least, TopOf(p) + p.height + Foot(p)) end
        end
        local foot = Foot(current)
        local room = Room()
        local at = TopOf(current)
        local total = math.max(least + BOTTOM, room)
        if current.flex then total = math.max(at + 80 + foot + BOTTOM, math.min(total, room)) end
        local height = total - at - foot - BOTTOM
        current.body:SetHeight(height)
        if current.Fit then current.Fit(height) end
        local shown = foot > 0
        current.foot:SetShown(shown)
        footRule:SetShown(shown)
        if shown then
            footRule:ClearAllPoints()
            local _, li, ri = Inset()
            footRule:SetPoint("TOPLEFT", PAD + li, -(at + height + RULE))
            footRule:SetPoint("TOPRIGHT", -(PAD + ri), -(at + height + RULE))
            current.foot:SetHeight(current.footHeight)
        end
        window:SetHeight(total)
        dirty = true            -- a list's rows follow its height
    end

    -- ------------------------------------------------------------ place
    local Tabs                  -- below: the tab row, shared out

    -- A tab as its page's heading (head), or back to its glyph.
    local function Head(b)
        local head = b.page.head
        b.icon:SetShown(not head and not b.item)
        if not head then
            if b.headText then
                b.headText:Hide()
                b.headBadge:Hide()
            end
            return
        end
        if not b.headText then
            b.headBadge = b:CreateTexture(nil, "ARTWORK")
            b.headText = ns.Text(b, 14)
            b.headText:SetJustifyH("LEFT")
            b.headText:SetWordWrap(false)
            -- a drag on it moves the window, as one on its ink does (the
            -- click a drag ends in is not the head's)
            b:RegisterForDrag("LeftButton")
            b:SetScript("OnMouseDown", function(self) self.dragged = nil end)
            b:SetScript("OnDragStart", function(self)
                self.dragged = true
                local start = window:GetScript("OnDragStart")
                if start then start(window) end
            end)
            b:SetScript("OnDragStop", function()
                local stop = window:GetScript("OnDragStop")
                if stop then stop(window) end
            end)
        end
        local text, c = head.Text()
        c = c or GOLD
        b.headText:SetText(text or "")
        b.headText:SetTextColor(c[1], c[2], c[3])
        b.headText:ClearAllPoints()
        b.headText:SetPoint("RIGHT", -8, 0)
        local badge = head.Badge and head.Badge()
        if badge and ns.character and ns.character.Badge then
            local size = badge.size or 16
            ns.character.Badge(b.headBadge, badge)
            b.headBadge:SetSize(size, size)
            b.headBadge:ClearAllPoints()
            b.headBadge:SetPoint("LEFT", 8, 0)
            b.headBadge:Show()
            b.headText:SetPoint("LEFT", b.headBadge, "RIGHT", 6, 0)
        else
            b.headBadge:Hide()
            b.headText:SetPoint("LEFT", 8, 0)
        end
        b.headText:Show()
    end
    -- A tab's box, there docked, gone floating; and its mark: the box's
    -- docked, the underline floating (none under a heading)
    local function Boxed(b, on)
        if b.edge then b.edge:SetShown(on) end
        if b.well then b.well:SetShown(on) end
    end
    local function Mark(b, on)
        if b.row then
            -- a row of the dropdown's list: held, its words gold
            b.mark:SetShown(on)
            local c = on and GOLD or POP_DIM
            b.label:SetTextColor(c[1], c[2], c[3])
            b.icon:SetAlpha(on and 1 or 0.6)
            return
        end
        if b.item then on = on and b.item.selected end
        b.mark:SetShown(on and not floating)
        if b.under then b.under:SetShown(on and floating and not b.page.head) end
        b.icon:SetAlpha(on and 1 or floating and FLOAT.dim or 0.6)
        b.label:SetAlpha(on and 1 or floating and FLOAT.dim or 0.6)
    end
    -- a page's tab, or its head's tabs (headTabs)
    local function Remark(p, on)
        for _, b in ipairs(p.tabs or {}) do Mark(b, on) end
    end

    -- the shadow round a floating window: four corners of one texture,
    -- flipped, and its inner edge stretched along the sides, a little down
    local function Shadow()
        local tex = ns.media .. "strips\\shadow"
        local parts = {}
        local function Part(l, r, t, b)
            local p = window:CreateTexture(nil, "BACKGROUND", nil, -8)
            p:SetTexture(tex)
            p:SetTexCoord(l, r, t, b)
            table.insert(parts, p)
            return p
        end
        local IN = 31 / 32
        for _, c in ipairs({ { "TOPLEFT", -1, 1, 0, 1, 0, 1 }, { "TOPRIGHT", 1, 1, 1, 0, 0, 1 },
            { "BOTTOMLEFT", -1, -1, 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, -1, 1, 0, 1, 0 } }) do
            local p = Part(c[4], c[5], c[6], c[7])
            p:SetSize(SHADOW, SHADOW)
            p:SetPoint(c[1], window, c[1], c[2] * SHADOW, c[3] * SHADOW - DROP)
        end
        local top = Part(IN, 1, 0, 1)
        top:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 0, -DROP)
        top:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", 0, -DROP)
        top:SetHeight(SHADOW)
        local bottom = Part(IN, 1, 1, 0)
        bottom:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 0, -DROP)
        bottom:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -DROP)
        bottom:SetHeight(SHADOW)
        local left = Part(0, 1, IN, 1)
        left:SetPoint("TOPRIGHT", window, "TOPLEFT", 0, -DROP)
        left:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 0, -DROP)
        left:SetWidth(SHADOW)
        local right = Part(1, 0, IN, 1)
        right:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -DROP)
        right:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", 0, -DROP)
        right:SetWidth(SHADOW)
        -- the drop's gap under the window, between its foot and the bottom
        -- strip: as black as the shadow's inner edge (2026-11-20: the ground
        -- showed through it)
        local gap = window:CreateTexture(nil, "BACKGROUND", nil, -8)
        gap:SetColorTexture(0, 0, 0, 1)
        gap:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 0, 0)
        gap:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, 0)
        gap:SetHeight(DROP)
        table.insert(parts, gap)
        return parts
    end

    -- The look, floating or docked (the tabs follow in Tabs)
    local function Chrome(off)
        floating = off
        -- docked, the ink over the frame at the top and the screen's edge
        local bg = chrome.bg
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", (off or side > 0) and 1 or 0, off and -1 or 0)
        bg:SetPoint("BOTTOMRIGHT", (off or side < 0) and -1 or 0, 1)
        chrome.edge:SetAlpha(off and FLOAT.edge or 1)
        chrome.lit:SetShown(off)
        chrome.head:SetShown(off)
        for _, p in ipairs(chrome.shadow) do p:SetShown(off) end
        rule:SetAlpha(off and FLOAT.rule or 1)
        local inset = off and 1 or PAD
        local el, er = Edges()                  -- (on the pages' grid)
        window.bandRule:ClearAllPoints()
        window.bandRule:SetPoint("BOTTOMLEFT", math.max(inset, el), BAND)
        window.bandRule:SetPoint("BOTTOMRIGHT", -math.max(inset, er), BAND)
        footRule:SetAlpha(off and FLOAT.rule or 1)
        for _, b in ipairs({ close, view }) do
            Boxed(b, not off)
            if b.icon then b.icon:SetAlpha(off and FLOAT.close or 1) end
        end
    end

    -- The view's place, scale and medallion, then the layout; out of combat.
    -- Escape closes a floating (detached) window, as it does Blizzard's
    -- panels: the game hides the frames named in UISpecialFrames, so a
    -- stand-in of the window's, shown while it floats open, goes on the
    -- list, and its hiding closes the window the window's own way (Close).
    -- Docked, the strip's windows close with Blizzard's frames, or stay.
    local escape
    local function Escape()
        if not window or not spec.name then return end
        if not escape then
            escape = CreateFrame("Frame", spec.name .. "Escape", UIParent)
            escape:Hide()
            escape:SetScript("OnHide", function()
                if window:IsShown() and w.Detached() then spec.Close() end
            end)
            if UISpecialFrames then table.insert(UISpecialFrames, escape:GetName()) end
            w.escape = escape
        end
        escape:SetShown(window:IsShown() and w.Detached())
    end

    local function Place()
        if not window then return end
        if InCombatLockdown() then
            ns.OutOfCombat(Place)
            return
        end
        local strip, at, off = ns.strips[side], At(), w.Detached()
        window:ClearAllPoints()
        if off then
            window:SetScale(at.scale or 1)
            window:SetWidth(math.max(LEAST[1], at.w or WIDTH))
            window:SetPoint(at.point or "TOPLEFT", UIParent, at.relative or "TOPLEFT", at.x or 40, at.y or -80)
        else
            window:SetScale(1)
            window:SetWidth(WIDTH)
            window:SetPoint(Outer(side, "BOTTOM"), strip, Outer(side, "BOTTOM"), 0, L.stripHeight)
        end
        medal:SetShown(not off)
        Chrome(off)
        if grip then grip:SetShown(off) end
        if view then view.icon:SetTexture(ns.media .. "strips\\" .. (off and "view-full" or "view-minimal")) end
        for _, p in ipairs(pages) do
            if p.band then BandAt(p) end
        end
        if window:IsShown() then Lift(not off) end
        Tabs()
        Layout()
        Escape()
        if spec.Placed then spec.Placed(off) end
    end
    w.Place = Place

    -- The detached place, kept: the anchor as the game left it after a drag
    -- or the grip, the size and the scale, with the changes asked.
    local function Keep(changes)
        local at = At()
        local keep = { detached = at.detached, point = at.point, relative = at.relative, x = at.x, y = at.y,
            w = at.w, h = at.h, scale = at.scale }
        -- docked, the window's anchor is the strip's: the saved place stands
        if w.Detached() then
            local point, _, relative, x, y = window:GetPoint()
            keep.point, keep.relative, keep.x, keep.y = point, relative, x, y
        end
        for k, v in pairs(changes or {}) do keep[k] = v end
        ns.SetOption(spec.place, keep)
    end

    -- Ctrl and the wheel: the scale, in steps, the anchor kept where it is on
    -- the screen (its offsets are in the window's own units)
    local function Rescale(delta)
        local at = At()
        local old = at.scale or 1
        local new = math.max(SCALES[1], math.min(SCALES[2], old + delta * SCALES[3]))
        new = math.floor(new / SCALES[3] + 0.5) * SCALES[3]
        if math.abs(new - old) < 0.001 then return end
        local point, _, relative, x, y = window:GetPoint()
        Keep({ point = point, relative = relative, x = (x or 0) * old / new, y = (y or 0) * old / new, scale = new })
    end

    -- ------------------------------------------------------------ pages
    local function Listen()
        listener:UnregisterAllEvents()
        if not (window:IsShown() and current) then return end
        for _, e in ipairs(current.events or {}) do
            if e:match("^UNIT_") then
                ns.RegisterUnitEvent(listener, e, "player")
            else
                pcall(listener.RegisterEvent, listener, e)
            end
        end
    end
    listener:SetScript("OnEvent", function(_, event, ...)
        if current.OnEvent then current.OnEvent(event, ...) end
        dirty = true
    end)

    -- tell each page whether the window is open on it
    local function Showing()
        for _, p in ipairs(pages) do
            if p.Showing then p.Showing(window:IsShown() and p == current) end
        end
    end

    local function Select(page)
        if not page.available then return end
        current = page
        for _, p in ipairs(pages) do
            if p.body then
                p.body:SetShown(p == page)
                p.band:SetShown(p == page)
                if p.panel then p.panel:SetShown(p == page) end
                if p ~= page then p.foot:Hide() end
            end
            Remark(p, p == page)
        end
        if drop.Paint then drop.Paint() end
        Layout()
        Listen()
        if window:IsShown() and page.Shown then page.Shown() end
        Showing()
        dirty = true
    end
    w.Select = Select

    function w.Current() return current end

    -- the tooltip outside this window (ns.window.Beside)
    function w.Beside(owner) ns.window.Beside(window, owner, side) end

    function w.ByFrame(name)
        for _, p in ipairs(pages) do
            if p.frame == name then return p end
        end
    end

    -- A tab asks Blizzard for its page (the hook on that page's Show selects
    -- ours); in combat it turns ours alone.
    local function Open(page)
        if not InCombatLockdown() and spec.Open then spec.Open(page) end
        if current ~= page then Select(page) end
    end
    w.Open = Open

    -- ------------------------------------------------------------ build
    local function Available(p)
        if p.Available then return p.Available() and true or false end
        return _G[p.frame] ~= nil
    end

    -- the outside scroll bars of this window's pages (Scroller's outside):
    -- between the rail and the pages docked, in the edge's pad floating
    function Bars()
        for _, sc in ipairs(ns.window.scrollers) do
            local f = sc.body
            while f and f ~= window do f = f:GetParent() end
            if f then sc.Edge(side, floating and PAD / 2 or (PAD - #RAIL) / 2) end
        end
    end

    -- A page's panel joined under the head (2026-11-19, /workspace/meld-sheet.png:
    -- spec.under, its height): the head's span, from its foot down, its
    -- top the head's foot line (no edge of its own there); ink with a
    -- faint gold rising from its foot, gold down its sides and along its
    -- foot; under the head's step and medallion. The page fills it.
    function Joined(p)
        local f = CreateFrame("Frame", nil, window)
        f:SetFrameLevel(window:GetFrameLevel() + 1)
        f:SetHeight(p.under)
        local ink = ns.colors.ink
        f.fill = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.fill:SetAllPoints()
        f.fill:SetColorTexture(ink[1], ink[2], ink[3], 1)
        -- the gold rising from its foot, gone by its top: there it is the
        -- head's step's ink, which runs over it unseen
        f.glow = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        f.glow:SetAllPoints()
        if f.glow.SetGradient and CreateColor then
            f.glow:SetColorTexture(1, 1, 1, 1)
            f.glow:SetGradient("VERTICAL", CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.22),
                CreateColor(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0))
        else
            f.glow:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.1)
        end
        f.edges = {}
        for _, e in ipairs({ { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true },
            { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
            local t = f:CreateTexture(nil, "BORDER")
            t:SetPoint(e[1])
            t:SetPoint(e[2])
            if e[3] then t:SetWidth(1) else t:SetHeight(1) end
            t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            table.insert(f.edges, t)
        end
        f:Hide()
        return f
    end

    -- a page's frames, built the first time it is there
    local function Make(p)
        p.body = CreateFrame("Frame", nil, window)
        p.body:SetPoint("TOPLEFT", PAD, -pageTop)
        p.body:SetPoint("TOPRIGHT", -PAD, -pageTop)
        p.foot = CreateFrame("Frame", nil, window)
        p.foot:SetPoint("BOTTOMLEFT", PAD, BOTTOM)
        p.foot:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
        p.band = CreateFrame("Frame", nil, window)
        BandAt(p)
        if p.under then p.panel = Joined(p) end
        p.body:Hide()
        p.foot:Hide()
        p.band:Hide()
        p.Build(p.body, p.foot, p.band)
        Bars()
        if not p.bandUsed then
            local o = Ornament(p.band)
            o:SetPoint("LEFT", 0, 0)
            o:SetPoint("RIGHT", 0, 0)
        end
    end

    -- The rule along the head's foot (rows of tabs high), the window's
    -- width, and the pages under it
    local function Under(rows, medallion)
        local top, li, ri = Inset()
        local el, er = Edges()
        pageTop = TOP + (rows - 1) * (TAB - 1) + top
        -- under the dropdown's medallion: below the step's foot, a rule's gap
        if medallion then pageTop = math.max(pageTop, top + medallion + RULE) end
        rule:ClearAllPoints()
        rule:SetPoint("TOPLEFT", el, -(rows * (TAB - 1) + top))
        rule:SetPoint("TOPRIGHT", -er, -(rows * (TAB - 1) + top))
        for _, p in ipairs(pages) do
            if p.panel then
                p.panel:ClearAllPoints()
                p.panel:SetPoint("TOPLEFT", el, -(top + TAB))
                p.panel:SetPoint("TOPRIGHT", -er, -(top + TAB))
            end
            if p.body then
                local at = TopOf(p)
                p.body:ClearAllPoints()
                p.body:SetPoint("TOPLEFT", PAD + li, -at)
                p.body:SetPoint("TOPRIGHT", -(PAD + ri), -at)
                p.foot:ClearAllPoints()
                p.foot:SetPoint("BOTTOMLEFT", PAD + li, BOTTOM)
                p.foot:SetPoint("BOTTOMRIGHT", -(PAD + ri), BOTTOM)
            end
        end
        if window.metal then window.metal.Set(not floating) end
        Bars()
    end

    -- ------------------------------------------------------ the dropdown
    -- The pages as one dropdown (2026-11-19, mockup A of /workspace/tabs-A.png,
    -- its list beside the window): the head, across the row up to the
    -- cross, the page's icon and name and a chevron; a click opens the list
    -- beside the window, on the side its tooltips stand, its top the
    -- window's: a row a page, the one open held, the second row's pages
    -- (the professions' secondaries) under a rule. A pick, a click
    -- elsewhere, the head again, Escape, the window closing shut it. A
    -- window whose pages have a head (words of their own: the quest page,
    -- the chat log) keeps its row of tabs.
    -- (2026-11-19, mockup A of /workspace/drop-style-A.png, "Gilded": the
    -- head a gold band fading right, lit along its top, the icon in a ring,
    -- "1 of 6", the chevron in a cell of its own; the list a notch to the
    -- head, a heading naming the window, ringed rows on hairlines, the open
    -- one in a gold fade marked open)
    local DROP_ROW, DROP_ICON, DROP_RULE, DROP_HEAD = 30, 18, 9, 30
    local MEDAL, STEP, SLANT = 40, 40, 6        -- the head's medallion, its step's length, the slant up
    local FAINT = { 0.37, 0.345, 0.29 }
    local HAIR = { 0.157, 0.137, 0.106 }
    local LIFT_ROW = { 0.141, 0.125, 0.098 }
    -- a fade of c, left to right (back: right to left)
    local function Fade(t, c, a, back)
        if t.SetGradient and CreateColor then
            local from, to = CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], 0)
            t:SetColorTexture(1, 1, 1, 1)
            if back then from, to = to, from end
            t:SetGradient("HORIZONTAL", from, to)
        else
            t:SetColorTexture(c[1], c[2], c[3], a * 0.5)
        end
    end
    local function GoldFade(t, a, back) Fade(t, GOLD_D, a, back) end
    -- A window on the left strip is mirrored (2026-11-19): its cross (and
    -- view glyph) and the head's chevron at the left, the name and its
    -- ringed icon at the right. Every fade runs from the screen's edge
    -- towards its middle: the head's from its outer end, a list row's
    -- from the side away from the window (PlaceList)
    local mirror = side < 0
    local inward = side > 0             -- a right-hand window's fades: bright at the right
    -- the window's name, for the list's heading: "Character window" (its
    -- spec's named, in the client's language, else from its frame's name)
    local function Title()
        if spec.title then return spec.title end
        local n = spec.named or tostring(spec.name or ""):gsub("^MedalUI", ""):gsub("(%l)(%u)", "%1 %2")
        return n ~= "" and format(Tr["%s window"], n) or Tr["Pages"]
    end
    local function Dropped()
        for _, p in ipairs(pages) do
            if p.available and not p.tabless and (p.head or p.headTabs) then return false end
        end
        return true
    end
    local function PageIcon(t, p, head)
        if head and p.headGlyph then
            t:SetTexture(ns.media .. "strips\\" .. p.headGlyph)
            t:SetTexCoord(0, 1, 0, 1)
        elseif p.icon then
            t:SetTexture(p.icon)
            t:SetTexCoord(GAME_ICON, 1 - GAME_ICON, GAME_ICON, 1 - GAME_ICON)
        else
            t:SetTexture(ns.media .. "strips\\" .. (p.glyph or p.key))
            t:SetTexCoord(0, 1, 0, 1)
        end
    end
    function drop.IsOpen() return drop.catcher ~= nil and drop.catcher:IsShown() end
    local Unarm                 -- below: the rows' secure casts put away
    function drop.Close()
        if not drop.IsOpen() then return end
        drop.catcher:Hide()
        Unarm()
        drop.Paint()
    end
    -- the head as the open page is
    function drop.Paint()
        local h = drop.head
        if not h then return end
        local p = current
        if p then PageIcon(h.icon, p, true) end
        h.medal:SetShown(p ~= nil)
        h.label:SetText(p and (p.heading or p.label) or "")
        local many = drop.count and drop.count > 1 or false
        local at = 0
        for i, q in ipairs(drop.order or {}) do if q == p then at = i end end
        h.count:SetText(many and at > 0 and format(Tr["%d of %d"], at, drop.count) or "")
        h.chevron:SetShown(many)
        h.split:SetShown(many)
        h.chevron:SetTexture(ns.media .. "strips\\" .. (drop.IsOpen() and "chevron-up" or "chevron-down"))
        h.mark:Hide()
        h.band:SetShown(not floating)
        h.lit:SetShown(not floating)
        if h.under then h.under:SetShown(floating) end
    end
    -- its list: on a catcher over the screen (a click on it shuts it)
    local function List()
        if drop.list then return drop.list end
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        catcher:SetScript("OnClick", function() drop.Close() end)
        catcher:Hide()
        local name = spec.name and spec.name .. "Pages"
        local f = CreateFrame("Frame", name, catcher)
        f:SetFrameLevel(catcher:GetFrameLevel() + 5)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        shadow:SetPoint("TOPLEFT", 4, -6)
        shadow:SetPoint("BOTTOMRIGHT", 4, -6)
        shadow:SetColorTexture(0, 0, 0, 0.55)
        local edge = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local ink = f:CreateTexture(nil, "BACKGROUND", nil, 3)
        ink:SetPoint("TOPLEFT", 1, -1)
        ink:SetPoint("BOTTOMRIGHT", -1, 1)
        ink:SetColorTexture(POP_INK[1], POP_INK[2], POP_INK[3], 1)
        f.rule = f:CreateTexture(nil, "ARTWORK")
        f.rule:SetHeight(1)
        f.rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        f.rule:Hide()
        -- its heading: the window's name, small, over a hairline
        f.title = ns.Text(f, 9)
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.title:SetTextColor(FAINT[1], FAINT[2], FAINT[3])
        f.title:SetText(ns.Upper(Title()))
        local under = f:CreateTexture(nil, "ARTWORK")
        under:SetHeight(1)
        under:SetPoint("TOPLEFT", 12, -(DROP_HEAD - 6))
        under:SetPoint("TOPRIGHT", -12, -(DROP_HEAD - 6))
        under:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.65)
        -- the notch on the side towards the window, level with the head: a
        -- gold diamond, its outer half under the box (PlaceList)
        f.notch = f:CreateTexture(nil, "BACKGROUND", nil, 0)
        f.notch:SetSize(9, 9)
        f.notch:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        if f.notch.SetRotation then f.notch:SetRotation(math.pi / 4) end
        f:SetScript("OnHide", function() drop.Close() end)
        if name and UISpecialFrames then table.insert(UISpecialFrames, name) end
        drop.catcher, drop.list, drop.rows = catcher, f, {}
        return f
    end
    local function Row(i)
        local f = List()
        local r = drop.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, f)
        r.row = true
        r:SetHeight(DROP_ROW)
        r:RegisterForClicks("LeftButtonUp")
        -- under the mouse: lifted, its words bright (Lift)
        r.lift = r:CreateTexture(nil, "BACKGROUND", nil, 0)
        r.lift:SetPoint("TOPLEFT", 0, -1)
        r.lift:SetPoint("BOTTOMRIGHT", 0, 1)
        r.lift:SetColorTexture(LIFT_ROW[1], LIFT_ROW[2], LIFT_ROW[3], 1)
        r.lift:Hide()
        -- held: a gold fade, a gold bar at its left, "open" at its right
        r.mark = CreateFrame("Frame", nil, r)
        r.mark:SetAllPoints()
        r.fill = r.mark:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.fill:SetPoint("TOPLEFT", 0, -1)
        r.fill:SetPoint("BOTTOMRIGHT", 0, 1)
        GoldFade(r.fill, 0.6)
        r.bar = r.mark:CreateTexture(nil, "BACKGROUND", nil, 2)
        r.bar:SetWidth(2)
        r.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        r.bar:SetPoint("TOPLEFT", 0, -1)
        r.bar:SetPoint("BOTTOMLEFT", 0, 1)
        r.open = ns.Text(r.mark, 9)
        r.open:SetPoint("RIGHT", -10, 0)
        r.open:SetText("OPEN")
        r.open:SetTextColor(GOLD_D[1], GOLD_D[2], GOLD_D[3])
        r.mark:Hide()
        -- the page's icon in a ring (a game icon fills it; a glyph sits in it)
        r.icon = Ring(r, DROP_ICON)
        r.icon:SetPoint("LEFT", 13, 0)
        r.label = ns.Text(r, 13)
        r.label:SetPoint("LEFT", r.icon, "RIGHT", 12, 0)
        r.label:SetJustifyH("LEFT")
        -- a hairline under it, from the words on (not under the last)
        r.hair = r:CreateTexture(nil, "ARTWORK")
        r.hair:SetHeight(1)
        r.hair:SetPoint("BOTTOMLEFT", 36, 0)
        r.hair:SetPoint("BOTTOMRIGHT", -8, 0)
        r.hair:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
        r:SetScript("OnClick", function(self)
            drop.Close()
            Open(self.page)
        end)
        -- a page whose tip says more than its name (PvP)
        r:SetScript("OnEnter", function(self)
            if not self.mark:IsShown() then
                self.lift:Show()
                local c = ns.colors.text
                self.label:SetTextColor(c[1], c[2], c[3])
                self.icon:SetAlpha(1)
            end
            local p = self.page
            if p and p.tip and p.tip ~= p.label then
                GameTooltip:SetOwner(self, Facing(window) == 1 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
                GameTooltip:SetText(p.tip, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function(self)
            self.lift:Hide()
            Mark(self, self.mark:IsShown())
            GameTooltip:Hide()
        end)
        drop.rows[i] = r
        return r
    end
    -- A page that opens by a spell (cast: a profession's, whose window the
    -- game opens only from a secure click, not from OpenTradeSkill in an
    -- addon's): over its row a secure button casts it, and the page turns
    -- as its window comes. Armed out of combat as the list opens, for the
    -- pages not open (the open one's cast would close it); their holder a
    -- driver hides in combat, where the rows only turn the page, as the
    -- tabs did.
    local holder
    local function Holder()
        if holder then return holder end
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetAllPoints(UIParent)
        holder:SetFrameStrata("FULLSCREEN_DIALOG")
        holder:SetFrameLevel(drop.list:GetFrameLevel() + 20)
        holder.buttons = {}
        drop.holder = holder            -- (the harness reads it)
        RegisterStateDriver(holder, "visibility", "[combat] hide; show")
        -- a list shut in combat leaves its buttons up: away at its end
        ns.On("PLAYER_REGEN_ENABLED", function() if not drop.IsOpen() then Unarm() end end)
        return holder
    end
    local function Cast(i)
        local h = Holder()
        local b = h.buttons[i]
        if b then return b end
        b = CreateFrame("Button", nil, h, "SecureActionButtonTemplate")
        b:RegisterForClicks("LeftButtonUp")
        b:SetAttribute("useOnKeyDown", false)
        b:SetAttribute("type", "spell")
        b:SetScript("PostClick", function(self)
            local page = self.page      -- (closing the list unarms it)
            drop.Close()
            if page and current ~= page then Select(page) end
        end)
        -- the row under it lifts, as under the mouse
        b:SetScript("OnEnter", function(self) if self.row then self.row:GetScript("OnEnter")(self.row) end end)
        b:SetScript("OnLeave", function(self)
            if self.row then self.row:GetScript("OnLeave")(self.row) else GameTooltip:Hide() end
        end)
        h.buttons[i] = b
        return b
    end
    function Unarm()
        if not holder or InCombatLockdown() then return end
        for _, b in ipairs(holder.buttons) do
            b.page, b.row = nil, nil
            b:SetAttribute("spell", nil)
            b:ClearAllPoints()
            b:Hide()
        end
    end
    local function Arm()
        if InCombatLockdown() then return end
        local n = 0
        for _, r in ipairs(drop.rows or {}) do
            local p = r:IsShown() and r.page
            if p and p.cast and p ~= current then
                n = n + 1
                local b = Cast(n)
                b.page, b.row = p, r
                b:SetAttribute("spell", p.cast)
                -- over the row by numbers, never anchored to it: a secure
                -- button's anchor would protect the row, the list and the
                -- catcher in combat (2026-11-20: Retab's ClearAllPoints and
                -- Escape's Hide of the list blocked)
                if ns.window.Over(b, r) then b:Show() else b:Hide() end
            end
        end
        if holder then
            for i = n + 1, #holder.buttons do holder.buttons[i]:Hide() end
        end
    end
    drop.Arm = Arm

    -- beside the window on its medallion's side, wherever the window
    -- stands (2026-11-20: floating, it went towards the screen's middle,
    -- away from the medallion), its top the window's; docked, that side is
    -- the screen's middle anyway
    local function PlaceList()
        local f = drop.list
        local s = mirror and -1 or 1
        f:ClearAllPoints()
        f.notch:ClearAllPoints()
        if s == 1 then
            f:SetPoint("TOPRIGHT", window, "TOPLEFT", -(MEDAL / 2 + 6), -(Inset()))
            f.notch:SetPoint("CENTER", f, "TOPRIGHT", 0, -TAB / 2)
        else
            f:SetPoint("TOPLEFT", window, "TOPRIGHT", MEDAL / 2 + 6, -(Inset()))
            f.notch:SetPoint("CENTER", f, "TOPLEFT", 0, -TAB / 2)
        end
        -- the held row's fade and bar from the side by the window
        local edge = s == 1 and "RIGHT" or "LEFT"
        f.edge = edge
        for _, r in ipairs(drop.rows) do
            GoldFade(r.fill, 0.6, s == 1)
            r.bar:ClearAllPoints()
            r.bar:SetPoint("TOP" .. edge, 0, -1)
            r.bar:SetPoint("BOTTOM" .. edge, 0, 1)
        end
    end
    function drop.Open()
        if not (drop.count and drop.count > 1) then return end
        List()
        PlaceList()
        drop.catcher:Show()
        drop.list:Show()
        Arm()
        drop.Paint()
    end
    function drop.Toggle() if drop.IsOpen() then drop.Close() else drop.Open() end end

    -- the cross in the window's top corner, the view glyph beside it: the
    -- right, or the left for a mirrored head
    Corner = function(left)
        local top = Inset()
        local el, er = Edges()
        close:ClearAllPoints()
        if left then close:SetPoint("TOPLEFT", el, -top) else close:SetPoint("TOPRIGHT", -er, -top) end
        if view then
            view:ClearAllPoints()
            if left then
                view:SetPoint("LEFT", close, "RIGHT", -1, 0)
            else
                view:SetPoint("RIGHT", close, "LEFT", 1, 0)
            end
        end
    end

    -- the head and the list's rows, as the pages there now are
    local function Drop(first, second)
        local h = drop.head
        if not h then
            h = Button(window, 100, function() drop.Toggle() end, function()
                local p = current
                local name = p and (p.heading or p.tip or p.label) or ""
                return drop.count and drop.count > 1 and format(Tr["%s. Click for the window's pages."], name) or name
            end)
            -- a gold band fading right, lit along its top
            h.band = h:CreateTexture(nil, "BACKGROUND", nil, 3)
            h.band:SetPoint("TOPLEFT", 1, -1)
            h.band:SetPoint("BOTTOMRIGHT", -1, 1)
            GoldFade(h.band, 0.55, inward)
            h.lit = h:CreateTexture(nil, "ARTWORK", nil, 1)
            h.lit:SetHeight(1)
            h.lit:SetPoint("TOPLEFT", 1, -1)
            h.lit:SetPoint("TOPRIGHT", -1, -1)
            Fade(h.lit, GOLD, 0.75, inward)
            -- (2026-11-19, mockup C3 of /workspace/medal-C3-text.png) the
            -- page's medallion on the window's inner edge (near: the end
            -- towards the screen's middle), half out of it, its top the
            -- window's; the head's foot steps down to its base by it. Beside
            -- it how far along it is; the name centred in what is left; the
            -- chevron in a cell of its own at the far end
            local near, far = mirror and "RIGHT" or "LEFT", mirror and "LEFT" or "RIGHT"
            local out = mirror and -1 or 1          -- inwards from the near end
            local m = CreateFrame("Button", nil, h)
            m:SetSize(MEDAL, MEDAL)
            m:SetFrameLevel(h:GetFrameLevel() + 12)
            m:RegisterForClicks("LeftButtonUp")
            m:SetScript("OnClick", function() drop.Toggle() end)
            m:SetScript("OnEnter", function() local f = h:GetScript("OnEnter") if f then f(h) end end)
            m:SetScript("OnLeave", function() GameTooltip:Hide() end)
            local function Disc(size, c, sub)
                local t = m:CreateTexture(nil, "BACKGROUND", nil, sub)
                t:SetSize(size, size)
                t:SetPoint("CENTER")
                t:SetTexture(ns.media .. "strips\\round")
                t:SetVertexColor(c[1], c[2], c[3], 1)
                return t
            end
            m.rim = Disc(MEDAL, GOLD, 1)                        -- the gold rim
            m.gap = Disc(MEDAL - 3, ns.colors.ink, 2)           -- a dark line inside it
            m.icon = Ring(m, MEDAL - 8)                         -- the icon in a thin dark-gold ring
            m.icon:SetPoint("CENTER")
            h.medal, h.icon = m, m.icon
            -- the step: the foot down to the medallion's base, a short
            -- slant back up to the head's (covering the rule there)
            local st = CreateFrame("Frame", nil, h)
            st:SetFrameLevel(h:GetFrameLevel() + 10)
            st:SetSize(STEP, MEDAL - TAB + 2)
            -- its ink the step's shape: square to the slant's foot, then a
            -- column a pixel wide each, cut at the slant (nothing beyond it)
            local rise, run = MEDAL - TAB, SLANT
            local ink = ns.colors.ink
            local fill = st:CreateTexture(nil, "BACKGROUND")
            fill:SetPoint("TOP" .. near)
            fill:SetPoint("BOTTOM" .. near)
            fill:SetColorTexture(ink[1], ink[2], ink[3], 1)
            st.wedge = {}
            for i = 1, run do
                local col = st:CreateTexture(nil, "BACKGROUND")
                col:SetWidth(1)
                col:SetHeight(math.max(1, (MEDAL - TAB + 2) - rise * (i - 0.5) / run))
                col:SetColorTexture(ink[1], ink[2], ink[3], 1)
                st.wedge[i] = col
            end
            -- its length: STEP, longer by the medallion's shift docked
            function st.Length(len)
                st:SetWidth(len)
                fill:SetWidth(len - run)
                for i, col in ipairs(st.wedge) do
                    col:ClearAllPoints()
                    col:SetPoint("TOP" .. near, (len - run + i - 1) * out, 0)
                end
            end
            st.Length(STEP)
            local foot = st:CreateTexture(nil, "ARTWORK")
            foot:SetHeight(1)
            foot:SetPoint("BOTTOM" .. near, 0, 0)
            foot:SetPoint("BOTTOM" .. far, -run * out, 0)
            foot:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            -- the slant: from the foot's end up to the head's foot, inside
            -- the step, which covers the head's foot as far as its top
            local slant = st:CreateTexture(nil, "ARTWORK")
            slant:SetSize(math.sqrt(rise * rise + run * run) + 1, 1)
            slant:SetPoint("CENTER", st, "BOTTOM" .. far, -run / 2 * out, rise / 2)
            slant:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
            if slant.SetRotation then slant:SetRotation(out * math.atan2(rise, run)) end
            st.fill = fill
            h.step = st
            h.label:Hide()
            h.count = ns.Text(h, 10)
            h.count:SetTextColor(unpack(ns.colors.dim))
            h.label = ns.Text(h, 14)
            h.label:SetPoint(near, (MEDAL / 2 + 60) * out, 0)
            h.label:SetPoint(far, -(TAB + 8) * out, 0)
            h.label:SetJustifyH("CENTER")
            h.label:SetWordWrap(false)
            h.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            h.split = h:CreateTexture(nil, "ARTWORK")
            h.split:SetSize(1, TAB - 10)
            h.split:SetPoint(far, -TAB * out, 0)
            h.split:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 0.8)
            h.chevron = h:CreateTexture(nil, "ARTWORK")
            h.chevron:SetSize(12, 12)
            h.chevron:SetPoint("CENTER", h, far, -TAB / 2 * out, 0)
            h.chevron:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            h.under = h:CreateTexture(nil, "ARTWORK")
            h.under:SetSize(UNDER, 2)
            h.under:SetPoint("BOTTOM", 0, 1)
            h.under:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            h.under:Hide()
            drop.head = h
            w.dropdown, window.dropdown = drop, drop      -- (the harness reads it)
        end
        local controls = 1 + (view and 1 or 0)
        local edge = controls * TAB - (controls - 1)
        local top = Inset()
        local el, er = Edges()
        -- joined to the cross: sharing its edge (a pixel's overlap)
        h:SetWidth((window:GetWidth() or WIDTH) - edge + 1 - el - er)
        h:SetHeight(TAB)
        h:ClearAllPoints()
        h:SetPoint(mirror and "TOPRIGHT" or "TOPLEFT", 0, -top)
        -- the medallion and the step by it, down by the margin too
        -- (2026-11-19) in from the edge by a quarter of it, the step and
        -- the count with it (floating too, 2026-11-20)
        local near = mirror and "RIGHT" or "LEFT"
        local out = mirror and -1 or 1
        local shift = MEDAL / 4
        h.medal:ClearAllPoints()
        h.medal:SetPoint("CENTER", window, "TOP" .. near, shift * out, -(top + MEDAL / 2))
        h.count:ClearAllPoints()
        h.count:SetPoint(near, (MEDAL / 2 + 12 + shift) * out, 0)
        h.step.Length(STEP + shift)
        w.step = STEP + shift
        h.step:ClearAllPoints()
        h.step:SetPoint("TOP" .. near, window, "TOP" .. near, mirror and -1 or 1, -(top + TAB - 2))
        Boxed(h, not floating)
        h:Show()
        close:SetHeight(TAB)
        if view then view:SetHeight(TAB) end
        Corner(mirror)
        -- the rows: the first row's pages, a rule, the second's
        local f = List()
        local n, y, widest = 0, DROP_HEAD, 0
        drop.order = {}
        f.rule:Hide()
        for r, list in ipairs({ first, second }) do
            if r == 2 and #list > 0 and #first > 0 then
                f.rule:ClearAllPoints()
                f.rule:SetPoint("TOPLEFT", 10, -(y + math.floor(DROP_RULE / 2)))
                f.rule:SetPoint("TOPRIGHT", -10, -(y + math.floor(DROP_RULE / 2)))
                f.rule:Show()
                y = y + DROP_RULE
            end
            for _, entry in ipairs(list) do
                local p = entry.page
                n = n + 1
                local row = Row(n)
                row.page = p
                PageIcon(row.icon, p)
                row.label:SetText(p.label or p.key)
                widest = math.max(widest, math.ceil(row.label:GetStringWidth() or 0))
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 4, -y)
                row:SetPoint("TOPRIGHT", -4, -y)
                row:Show()
                row.hair:Show()
                Mark(row, p == current)
                p.tab, p.tabs = row, { row }
                table.insert(drop.order, p)
                y = y + DROP_ROW
            end
        end
        for i = n + 1, #drop.rows do drop.rows[i]:Hide() end
        -- no hairline under a group's last (the rule stands there) nor the list's
        for i = 1, n do
            local r, nxt = drop.rows[i], drop.rows[i + 1]
            local last = i == n or (nxt and #first > 0 and i == #first)
            r.hair:SetShown(not last)
        end
        f:SetSize(math.max(196, widest + DROP_ICON + 96), y + 6)
        drop.count = n
        drop.Paint()
    end

    -- the row less the cross (and the view glyph) and the gap before
    -- them, shared out among the pages that are there, and the second row,
    -- if any, under it as wide, the cross as tall as both; flush in the
    -- window's corner, the tabs overlap a pixel, sharing their edges (the
    -- window's border too), row on row as well
    function Tabs()
        local first, second = {}, {}
        for _, p in ipairs(pages) do
            p.tab, p.tabs = nil, {}
            if p.available and not p.tabless then
                local row = p.row == 2 and second or first
                if p.headTabs then
                    for _, item in ipairs(p.headTabs() or {}) do table.insert(row, { page = p, item = item }) end
                else
                    table.insert(row, { page = p })
                end
            end
        end
        if Dropped() then
            for _, b in ipairs(tabs) do b:Hide() end
            Drop(first, second)
            Under(1, MEDAL)
            return
        end
        if drop.head then
            drop.Close()
            drop.head:Hide()
            drop.count = 0
        end
        Corner(false)
        local controls = 1 + (view and 1 or 0)
        local top = Inset()
        local li, ri = Edges()
        local full = (window:GetWidth() or WIDTH) - li - ri
        local edge = controls * TAB - (controls - 1)    -- the cross and the view glyph, joined
        local room = full - edge - GAP
        local tall = #second > 0 and 2 * TAB - 1 or TAB
        close:SetHeight(tall)
        if view then view:SetHeight(tall) end
        local n = 0
        for r, list in ipairs({ first, second }) do
            local span = room
            local width = #list > 0 and math.floor((span + #list - 1) / #list) or 0
            local prev
            for k, entry in ipairs(list) do
                local p, item = entry.page, entry.item
                n = n + 1
                local b = tabs[n]
                if not b then
                    local i = n
                    b = Button(window, width, function(self, mouse)
                        local head = self.page.head
                        if self.dragged then
                            self.dragged = nil
                        elseif self.item then
                            if current ~= self.page then Open(self.page) end
                            self.item.click()
                        elseif head and head.Click then
                            head.Click(mouse)
                        else
                            Open(self.page)
                        end
                    end, function()
                        local pg, it = tabs[i].page, tabs[i].item
                        if it then return it.tip and it.tip() or it.label end
                        return pg.head and pg.head.tip and pg.head.tip() or pg.tip or pg.label
                    end)
                    b.icon = b:CreateTexture(nil, "ARTWORK")
                    b.icon:SetSize(GLYPH, GLYPH)
                    b.icon:SetPoint("CENTER")
                    b.under = b:CreateTexture(nil, "ARTWORK")
                    b.under:SetSize(UNDER, 2)
                    b.under:SetPoint("BOTTOM", 0, 1)
                    b.under:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
                    b.under:Hide()
                    tabs[n] = b
                end
                b.page, b.item = p, item
                Head(b)
                -- a head's words, not a glyph
                b.label:SetText(item and item.label or "")
                if item then b.icon:Hide() end
                -- the last to the row's end, exactly
                b:SetWidth(k < #list and width or span - (#list - 1) * (width - 1))
                -- a head's words cut short in a narrow tab, not over its neighbours
                b.label:SetWordWrap(false)
                b.label:SetWidth(item and math.max(1, b:GetWidth() - 8) or 0)
                if item then
                    b.icon:SetTexture(nil)
                elseif p.icon then
                    b.icon:SetTexture(p.icon)
                    b.icon:SetTexCoord(GAME_ICON, 1 - GAME_ICON, GAME_ICON, 1 - GAME_ICON)
                else
                    b.icon:SetTexture(ns.media .. "strips\\" .. (p.glyph or p.key))
                    b.icon:SetTexCoord(0, 1, 0, 1)
                end
                b:ClearAllPoints()
                if prev then
                    b:SetPoint("LEFT", prev, "RIGHT", -1, 0)
                else
                    b:SetPoint("TOPLEFT", li, -((r - 1) * (TAB - 1) + top))
                end
                Boxed(b, not floating)
                Mark(b, p == current)
                b:Show()
                p.tab, prev = b, b
                table.insert(p.tabs, b)
            end
        end
        for i = n + 1, #tabs do tabs[i]:Hide() end
        Under(#second > 0 and 2 or 1)
    end

    -- Which pages are there now: a page that has come is built, one that
    -- has gone is left, for the first that is still there.
    w.tabs = tabs                       -- (the harness reads them)
    function w.Head()
        for _, b in ipairs(tabs) do
            if b:IsShown() and b.page then Head(b) end
        end
    end

    function w.Retab()
        if not window then return end
        drop.Close()
        for _, p in ipairs(pages) do
            p.available = Available(p)
            if p.available and not p.body then Make(p) end
        end
        Tabs()
        if current and not current.available then
            current = nil
            for _, p in ipairs(pages) do
                if p.body then p.body:Hide(); p.foot:Hide(); p.band:Hide() end
                if p.panel then p.panel:Hide() end
            end
            for _, p in ipairs(pages) do
                if p.available then Select(p); break end
            end
        elseif current then
            Layout()
        end
    end

    function w.Build()
        local strip = ns.strips[side]
        window = CreateFrame("Frame", spec.name, strip)
        w.window = window
        ns.window.Mark(window, side)
        -- the strip's scale, so it stands on the strip as the side panels
        -- do, but not the console's fading
        window:SetIgnoreParentAlpha(true)
        window:SetFrameStrata("MEDIUM")
        -- over the chat's cog and drawer, MEDIUM too (strips/chat.lua)
        local cog = ns.chat and ns.chat.cog
        if cog then window:SetFrameLevel(math.max(window:GetFrameLevel(), cog:GetFrameLevel() + 1)) end
        window:EnableMouse(true)
        window:SetWidth(WIDTH)
        window:SetPoint(Outer(side, "BOTTOM"), strip, Outer(side, "BOTTOM"), 0, L.stripHeight)
        window:Hide()
        local edge = window:CreateTexture(nil, "BACKGROUND", nil, 1)
        edge:SetAllPoints()
        edge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        chrome.edge = edge
        chrome.shadow = Shadow()
        -- docked first: the shadow is a floating window's (Chrome shows it),
        -- and a window with no place never reaches Chrome (2026-11-21: it lay
        -- black under every docked window, as if floating)
        for _, p in ipairs(chrome.shadow) do p:Hide() end
        local bg = window:CreateTexture(nil, "BACKGROUND", nil, 2)
        bg:SetPoint("TOPLEFT", side > 0 and 1 or 0, 0)          -- (docked first: Chrome)
        bg:SetPoint("BOTTOMRIGHT", side < 0 and -1 or 0, 1)
        bg:SetColorTexture(ns.colors.ink[1], ns.colors.ink[2], ns.colors.ink[3], spec.opaque and 1 or 0.94)
        chrome.bg, window.chrome = bg, chrome     -- (the harness reads them)
        -- floating: the head's quiet band, and a lit line along the top
        chrome.head = window:CreateTexture(nil, "BACKGROUND", nil, 3)
        chrome.head:SetPoint("TOPLEFT", 1, -1)
        chrome.head:SetPoint("TOPRIGHT", -1, -1)
        chrome.head:SetHeight(TAB - 2)
        chrome.head:SetColorTexture(unpack(FLOAT.head))
        chrome.head:Hide()
        chrome.lit = window:CreateTexture(nil, "BORDER")
        chrome.lit:SetPoint("TOPLEFT", 1, -1)
        chrome.lit:SetPoint("TOPRIGHT", -1, -1)
        chrome.lit:SetHeight(1)
        if chrome.lit.SetGradient and CreateColor then
            chrome.lit:SetColorTexture(1, 1, 1, 1)
            chrome.lit:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.12),
                CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.6))
        else
            chrome.lit:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
        end
        chrome.lit:Hide()
        rule = window:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        rule:SetPoint("TOPLEFT", 0, -(TAB - 1))
        rule:SetPoint("TOPRIGHT", 0, -(TAB - 1))
        rule:SetHeight(1)
        footRule = window:CreateTexture(nil, "ARTWORK")
        footRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        footRule:SetHeight(1)
        -- the margin's edge, over the medallion
        local bandRule = window:CreateTexture(nil, "ARTWORK")
        bandRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        bandRule:SetHeight(1)
        bandRule:SetPoint("BOTTOMLEFT", PAD, BAND)
        bandRule:SetPoint("BOTTOMRIGHT", -PAD, BAND)
        window.bandRule = bandRule
        -- the margin's rail (docked): flush against the screen's edge, the
        -- window's height; its columns (RAIL) outer first
        do
            local metal = CreateFrame("Frame", nil, window)
            metal:SetWidth(#RAIL)
            metal:SetFrameLevel(window:GetFrameLevel() + 2)
            local outer = side < 0 and "LEFT" or "RIGHT"
            metal:SetPoint("TOP" .. outer, 0, 0)
            metal:SetPoint("BOTTOM" .. outer, 0, 0)
            metal.columns = {}
            for k, c in ipairs(RAIL) do
                local t = metal:CreateTexture(nil, "ARTWORK")
                t:SetWidth(1)
                t:SetPoint("TOP" .. outer, (k - 1) * (side < 0 and 1 or -1), 0)
                t:SetPoint("BOTTOM" .. outer, (k - 1) * (side < 0 and 1 or -1), 0)
                t:SetColorTexture(c[1], c[2], c[3], 1)
                metal.columns[k] = t
            end
            metal.Set = function(on) metal:SetShown(on) end
            metal:Hide()
            window.metal = metal
        end
        Medal()

        -- the cross flush in the top right corner
        close = Button(window, TAB, function() spec.Close() end, function() return spec.closeTip end)
        Glyph(close, "close")
        close:SetPoint("TOPRIGHT", 0, 0)
        window.close = close
        if spec.place and not spec.detachedOnly then
            view = Button(window, TAB, function()
                if InCombatLockdown() then return end
                local at = At()
                if at.detached then
                    Keep({ detached = false })
                else
                    -- the first time detached: its top left where the docked
                    -- window's stood (the docked anchor is the strip's, not
                    -- the screen's); after that, where it was left
                    local left, top = window:GetLeft(), window:GetTop()
                    local first = not at.point and left and top
                        and { point = "TOPLEFT", relative = "BOTTOMLEFT", x = left, y = top } or {}
                    first.detached, first.w, first.h = true, at.w or WIDTH, at.h or HEIGHT
                    Keep(first)
                end
            end, function()
                return w.Detached() and Tr["Docked: on the strip, as tall as the screen."]
                    or Tr["Detached: a box of its own, to move and size."]
            end)
            Glyph(view)
            view:SetPoint("RIGHT", close, "LEFT", 1, 0)
            window.view = view
        end
        if spec.place then
            window:SetMovable(true)
            window:SetResizable(true)
            window:SetClampedToScreen(true)
            if window.SetResizeBounds then window:SetResizeBounds(LEAST[1], LEAST[2]) end
            window:RegisterForDrag("LeftButton")
            window:SetScript("OnDragStart", function()
                if w.Detached() and not InCombatLockdown() then window:StartMoving() end
            end)
            window:SetScript("OnDragStop", function()
                window:StopMovingOrSizing()
                if w.Detached() then Keep() end
            end)
            window:EnableMouseWheel(true)
            window:SetScript("OnMouseWheel", function(_, delta)
                if IsControlKeyDown() and w.Detached() and not InCombatLockdown() then Rescale(delta) end
            end)
            grip = CreateFrame("Button", nil, window)
            grip:SetSize(GRIP, GRIP)
            grip:SetPoint("BOTTOMRIGHT", -2, 2)
            grip:SetFrameLevel(window:GetFrameLevel() + LIFT + 4)
            for _, part in ipairs({ { 14, 2 }, { 2, 14 } }) do
                local t = grip:CreateTexture(nil, "ARTWORK")
                t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
                t:SetSize(part[1], part[2])
                t:SetPoint("BOTTOMRIGHT")
            end
            grip:SetScript("OnMouseDown", function()
                if w.Detached() and not InCombatLockdown() then window:StartSizing("BOTTOMRIGHT") end
            end)
            grip:SetScript("OnMouseUp", function()
                window:StopMovingOrSizing()
                if w.Detached() then Keep({ w = window:GetWidth(), h = window:GetHeight() }) end
            end)
            window.grip = grip
            ns.OnSetting(spec.place, Place)
        end

        table.sort(pages, function(a, b) return a.order < b.order end)
        for _, p in ipairs(pages) do
            p.available = Available(p)
            if p.available then Make(p) end
        end
        Tabs()

        window:SetScript("OnShow", function()
            -- docked beside an exclusive window (or as one): the other goes
            if not w.Detached() then
                for _, o in ipairs(docked[side]) do
                    if o ~= w and (w.exclusive or o.exclusive) and o.window and o.window:IsShown()
                        and not o.Detached() then
                        o.Close()
                    end
                end
            end
            Lift(true)
            Layout()
            Listen()
            Showing()
            if current and current.Shown then current.Shown() end
            dirty = true
            Escape()
        end)
        window:SetScript("OnHide", function()
            drop.Close()
            Lift(false)
            Listen()
            Showing()
            Escape()
        end)
        -- a change is drawn once, at the next frame, and only while it is open
        local check = 0
        window:SetScript("OnUpdate", function(_, elapsed)
            medal:SetAlpha(strip:GetEffectiveAlpha())
            check = check + (elapsed or 0)
            if check >= 0.25 then
                check = 0
                if Sunk() then Lift(true) end
            end
            if dirty and current then
                dirty = false
                current.Refresh()
            end
        end)
        if spec.place then Place() end
        -- the screen's height is the window's
        for _, e in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
            ns.On(e, function() if window:IsShown() then Layout() end end)
        end
        return window
    end

    function w.SetShown(open)
        if window and open ~= window:IsShown() then window:SetShown(open) end
    end

    -- Secure buttons over the window, on a layer of their own on the strip.
    -- Never anchored to the window or anything in it: a frame a protected
    -- frame is anchored to is protected too, and so is whatever that one is
    -- anchored to, up to the window, which then cannot open or close in
    -- combat. The layer stands where the docked window does, at its foot;
    -- Over(b, region) sets b over region by numbers from the layer's own
    -- corner and scale, so a detached, scaled window is met too; out of
    -- combat (false when the region is not laid out).
    function w.Layer(name)
        local strip = ns.strips[side]
        local layer = CreateFrame("Frame", name, strip)
        ns.window.Mark(layer, side, window)      -- its buttons' tooltips beside the window
        layer:SetFrameStrata("MEDIUM")
        layer:SetFrameLevel(window:GetFrameLevel() + 10)
        layer:SetIgnoreParentAlpha(true)
        layer:SetPoint(Outer(side, "BOTTOM"), strip, Outer(side, "BOTTOM"), 0, L.stripHeight)
        layer:SetSize(WIDTH, 1)
        layer:Hide()
        layer.buttons = {}
        return layer
    end
    w.Over = ns.window.Over

    return w
end
