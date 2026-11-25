-- The chat box, on the left strip: Blizzard's own chat, in a box standing
-- on the micro menu, from the screen's edge as wide as the character
-- window. The box wears the windows' trim over an ink that fades to the
-- right (ns.window.Dress); from its foot up:
--
--   (medallion)  [buff][buff]          <- the margin: the timeless buffs,
--   ---------------------------------     and the edit box over them
--   the messages (the panel)
--   [General][Trade]           |(*)[o P <]  <- the tabs, the cog and its
--                                               drawer, open
--
-- The quest tracker's full view stands over the box, up to the screen's
-- top, in a box of its own on it (Reach): its foot is the chat box's top
-- edge, so the two read as one, and it fades with the tracker, and goes
-- when the tracker goes minimal. A gossip, quest or vendor window takes
-- its place while it is open (npc/window.lua, Hold).
--
-- Nothing of the chat is replaced. The docked chat frames (they all follow
-- ChatFrame1) are anchored into the panel and their backgrounds and borders
-- taken away; the tabs wear the windows' box tabs (ns.window.Face); the
-- edit box lies over the margin, on an ink backing while it is typed in.
-- Blizzard's own buttons (the chat menu, the friends toast, channels,
-- voice) leave their column at the messages' left for a drawer behind a
-- cog at the tab row's right end, which opens to the right, as the minimap
-- button drawer does (bars/drawer.lua); they wear gold glyphs instead of
-- their own art.
--
-- The chat is in UIParent's scale, the panel in the console's, so the
-- room left for Blizzard's own pieces (the tab row, the scroll bar) is
-- measured in the chat's units and converted.
--
-- A window torn out of the dock gets its background back and floats as
-- Blizzard's; only its tab keeps the box tab. Edit Mode's chat frame
-- position no longer applies: the panel puts it back.
--
-- The box is under everything: BACKGROUND strata, so the strip and its
-- medallion, the chat (MEDIUM), the friends toast and the dock (LOW) all
-- draw over it.
--
-- Built at login, and only when the Chat box option is on (settings.lua).
local _, ns = ...
local Tr = ns.L

local L = ns.stripLayout
local PARTS = ns.media .. "strips\\"
-- tooltips just outside the chat, towards the screen's middle (the strip
-- is marked, below); over their owner before the chat is built
local function Outside(owner) ns.window.Outside(owner, "ANCHOR_TOP") end
local PAD, RULE, TABS = 8, 6, 28    -- the box's edge, the gap over the margin's rule, the tabs' height
local BOX = TABS                    -- the head's height: the tabs, the cog and its drawer, flush to the box's top
local GAP = 4                       -- either side of the divider between the tabs and the cog
local GLYPH = 28                    -- a glyph in a box (its art is 20 of the 32)
local TAB_PAD, TAB_MIN = 16, 36     -- a tab's width: its text plus padding
local GOLD = { 0.941, 0.831, 0.533 }
local GOLD_D = { 0.541, 0.439, 0.204 }
local COMBAT_WELL = { 0.141, 0.063, 0.055, 1 }
local COMBAT_MARK = { 0.361, 0.133, 0.102, 0.65 }
local COMBAT_TEXT = { 1.00, 0.67, 0.55 }
local DIM = ns.colors.dim

-- A Blizzard region taken out of sight, and kept out: Blizzard's code shows
-- them again (a chat frame's fade-in, a tab's selection, the edit box's
-- focus). Let go when the window leaves the dock: shown again, or only left
-- for Blizzard to show (the edit box's focus art).
local gone, hooked = {}, {}
local function Gone(region)
    if not region then return end
    gone[region] = true
    region:Hide()
    if hooked[region] then return end
    hooked[region] = true
    hooksecurefunc(region, "Show", function(self)
        if gone[self] then self:Hide() end
    end)
    hooksecurefunc(region, "SetShown", function(self, shown)
        if shown and gone[self] then self:Hide() end
    end)
end
local function Back(region, shown)
    if region and gone[region] then
        gone[region] = nil
        if shown then region:Show() end
    end
end

local chatBox, panel, area, edit, head
local cog, tray, open = nil, nil, false
local lift = 0                      -- the dock raised by, measured
local hang = 0                      -- the alert frame's drop from the friends slot, measured

-- A chat unit in the panel's (the chat is in UIParent's scale)
local function Ratio() return ChatFrame1:GetEffectiveScale() / panel:GetEffectiveScale() end

-- A point set only when it is not already so: Blizzard answers some moves
-- (the alert frame's) by moving something else, which would come back here
local function Put(f, point, to, relative, x, y)
    if f:GetNumPoints() == 1 then
        local p, t, r, px, py = f:GetPoint(1)
        if p == point and t == to and r == relative and px == x and py == y then return end
    end
    f:ClearAllPoints()
    f:SetPoint(point, to, relative, x, y)
end
local placing = false

-- The drawer's buttons, from the left: the chat menu, the friends toast,
-- channels, the log (MedalUI's own: strips/chatlog.lua), and the two
-- voice toggles while voice is on. The voice toggles keep their own art: it
-- is their state.
local HEAD = {
    { name = "ChatFrameMenuButton", glyph = "chat" },
    { name = "QuickJoinToastButton", glyph = "character", alert = true },
    { name = "ChatFrameChannelButton", glyph = "channels" },
    { name = "MedalUIChatLogButton", glyph = "log" },
    { name = "ChatFrameToggleVoiceDeafenButton" },
    { name = "ChatFrameToggleVoiceMuteButton" },
}

-- The dock (Blizzard's tab row) along the head's foot, from the box's left
-- edge to short of the divider before the cog. It is raised, or lowered,
-- until its tabs' boxes fill the head from the hairline to the box's top:
-- the first tab's middle is measured from the chat's top (the hairline:
-- both in the chat's own units, so no scale is mixed in) and the dock
-- moved by what is missing.
local function Dock(width)
    local dock = GENERAL_CHAT_DOCK
    if not dock then return end
    local function Set()
        dock:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, lift)
        dock:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", L.chatRight - width, lift)
    end
    Set()
    if FCFDock_UpdateTabs then FCFDock_UpdateTabs(dock, true) end
    local tab = _G.ChatFrame1Tab
    local top, bottom, chat = tab:GetTop(), tab:GetBottom(), ChatFrame1:GetTop()
    if top and bottom and chat then
        local miss = (BOX / 2) / Ratio() - ((top + bottom) / 2 - chat)
        if math.abs(miss) > 0.5 then
            lift = lift + miss
            Set()
        end
    end
end

-- The cog lit while its drawer is open, and the drawer's shown buttons
-- left to right in it, a box high, each anchored to the drawer itself;
-- but the friends toast. Blizzard stacks the toast on the alert frame its
-- toasts come from (its BOTTOMLEFT on the frame's TOPLEFT) and puts it back
-- there whenever it likes, so the toast keeps that anchor and the alert
-- frame is moved instead: while the drawer is open, it hangs from the
-- friends slot's foot (by `hang`, measured), so the toast stacked on it
-- fills the slot; while it
-- is shut, it sits on the cog, so the toasts still come from the head.
-- Anchoring the alert frame to the toast would close a loop.
local function Row()
    local r = Ratio()
    placing = true
    Dock((BOX - PAD + GAP + 1 + GAP) / r)
    if cog then
        if open then cog:LockHighlight() else cog:UnlockHighlight() end
        local shown, friends = {}, nil
        for _, spec in ipairs(HEAD) do
            local b = _G[spec.name]
            if b and b:IsShown() then
                if spec.alert then friends = 1 + #shown * BOX end
                table.insert(shown, b)
            end
        end
        local toast = _G.QuickJoinToastButton
        local function Hang()
            Put(ChatAlertFrame, "TOPLEFT", tray, "BOTTOMLEFT", friends / r, hang)
        end
        if ChatAlertFrame then
            ChatAlertFrame:SetSize(BOX / r, BOX / r)
            if open and friends then
                Hang()
            else
                Put(ChatAlertFrame, "CENTER", cog, "CENTER", 0, 0)
            end
        end
        for i, b in ipairs(shown) do
            b:SetSize(BOX, BOX)
            if b.medaluiGlyph then b.medaluiGlyph:SetSize(GLYPH, GLYPH) end
            if b == toast and ChatAlertFrame then
                -- Blizzard's own stack, at whatever offset it chose: only
                -- put back on the alert frame if it is somewhere else
                if select(2, b:GetPoint(1)) ~= ChatAlertFrame then
                    Put(b, "BOTTOMLEFT", ChatAlertFrame, "TOPLEFT", 0, 0)
                end
                -- and its glyph held in the slot itself, in line with the
                -- others, wherever the stack leaves the button (it sat a
                -- pixel or two low in game, 2026-11-11)
                local g = b.medaluiGlyph
                if g then
                    g:ClearAllPoints()
                    g:SetPoint("CENTER", tray, "LEFT", 1 + (i - 1) * BOX + BOX / 2, 0)
                end
            else
                Put(b, "LEFT", tray, "LEFT", 1 + (i - 1) * BOX, 0)
            end
        end
        -- Blizzard's stack is not quite flush: the toast's middle measured
        -- against the drawer's (both in the drawer's units), and the alert
        -- frame moved by what is missing
        if open and friends and ChatAlertFrame and toast and toast:GetParent() == tray then
            local top, bottom, high, low = toast:GetTop(), toast:GetBottom(), tray:GetTop(), tray:GetBottom()
            if top and bottom and high and low then
                local miss = ((high + low) - (top + bottom)) / 2
                if math.abs(miss) > 0.25 then
                    hang = hang + miss / r
                    Hang()
                end
            end
        end
        tray:SetWidth(#shown * BOX + 2)
        tray:SetShown(open and #shown > 0)
    end
    placing = false
end

-- Where the messages go, in the panel, from the scale of the chat to the
-- panel's; and the dock's room for the cog, in the chat's.
local function Measure()
    local r = ChatFrame1:GetEffectiveScale() / panel:GetEffectiveScale()
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", panel, "TOPLEFT", L.chatPad, -L.chatTop * r)
    area:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -L.chatRight * r, L.chatPad)
    Row()
end

-- ChatFrame1 into the panel; the docked windows are anchored to it.
local function Place()
    placing = true
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("TOPLEFT", area, "TOPLEFT")
    ChatFrame1:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
    placing = false
end

-- ------------------------------------------------------------------ tabs
local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }

-- The selected tab marked and its name in gold (or ember for the combat
-- log), the others dim; after Blizzard's colours (FCFTab_UpdateColors).
local function Selected(tab, selected)
    if not tab.medalui then return end
    tab.mark:SetShown(selected and true or false)
    local text = tab.Text or _G[tab:GetName() .. "Text"]
    local c = selected and (tab.medaluiCombat and COMBAT_TEXT or GOLD) or DIM
    if text then text:SetTextColor(c[1], c[2], c[3]) end
end

-- The windows' box tab (ns.window.Face) instead of Blizzard's pill, filling
-- the head from the hairline to the box's top edge, as wide as its text.
local function Slot(tab)
    tab.medaluiSlot:SetHeight(BOX / Ratio())
end

local function FitTab(tab)
    if not tab or not tab.medalui then return end
    local text = tab.Text or _G[tab:GetName() .. "Text"]
    if not text then return end
    if text.SetWidth then text:SetWidth(0) end
    local w = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()
        or text.GetStringWidth and text:GetStringWidth() or 0
    if not ns.IsSecret(w) and w > 0 then
        tab:SetWidth(math.max(TAB_MIN, math.ceil(w) + TAB_PAD))
    end
end

local function SkinTab(tab)
    if not tab or tab.medalui then return end
    for _, key in ipairs(TAB_ART) do Gone(tab[key]) end
    local slot = CreateFrame("Frame", nil, tab)
    slot:SetPoint("LEFT")
    slot:SetPoint("RIGHT")
    tab.medaluiSlot = slot
    Slot(tab)
    local well = ns.window.Face(tab, slot)
    local frame = _G[tab:GetName():gsub("Tab$", "")]
    if frame == _G.ChatFrame2 then
        well:SetColorTexture(unpack(COMBAT_WELL))
        tab.mark:SetColorTexture(unpack(COMBAT_MARK))
        tab.medaluiCombat = true
    end
    tab.medaluiWell = well
    local text = tab.Text or _G[tab:GetName() .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", slot, "CENTER")
    end
    tab.medalui = true
    FitTab(tab)
    Selected(tab, frame and FCFDock_GetSelectedWindow
        and frame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK))
end

-- ------------------------------------------------------------- windows
-- A docked window loses its own background, border, size grip and edit box
-- art; its edit box moves over the messages' foot, on an ink backing.
local function Textures(frame)
    local name, list = frame:GetName(), {}
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local t = _G[name .. suffix]
        if t then table.insert(list, t) end
    end
    return list
end

-- The edit box's own art, and its focus art, which Blizzard shows itself.
local function BoxArt(box)
    local name = box:GetName()
    return { _G[name .. "Left"], _G[name .. "Mid"], _G[name .. "Right"] },
        { box.focusLeft, box.focusMid, box.focusRight }
end

-- The backing shows only while the box is typed in or holds text: at rest
-- and empty (the Classic chat style keeps the box) it was an empty bar over
-- the messages' foot. Empty, it takes the pointer only right of the
-- timeless buffs, which share the margin (strips/buffs.lua): the box is over
-- the strips, so it took their tooltips and right clicks. Typed in, or left
-- with text by a click elsewhere, it covers them (its text lay over the
-- buffs); left with text, its border dims till a click or Enter takes it up.
local BORDER, BORDER_IDLE = 0.9, 0.35
local function Lit(box)
    local typing = box:HasFocus() and true or false
    local text = box:GetText()
    local on = box.medaluiDressed and (typing or (text ~= nil and text ~= "")) and true or false
    for _, t in ipairs(box.medalui or {}) do t:SetShown(on) end
    if box.medalui and box.medalui[1] then box.medalui[1]:SetAlpha(typing and BORDER or BORDER_IDLE) end
    local inset = 0
    local w = box.medaluiDressed and not on and ns.BuffRowWidth and ns.BuffRowWidth() or 0
    if w > 0 and edit then inset = w * edit:GetEffectiveScale() / box:GetEffectiveScale() end
    box:SetHitRectInsets(inset, 0, 0, 0)
end

local function EditBox(frame)
    local box = frame.editBox
    if not box then return end
    local own, focus = BoxArt(box)
    for _, t in ipairs(own) do Gone(t) end
    for _, t in ipairs(focus) do Gone(t) end
    if not box.medalui then
        box.medalui = {}
        local ink = ns.colors.ink
        for i, colour in ipairs({ { 0.54, 0.44, 0.20, 0.9 }, { ink[1], ink[2], ink[3], 0.9 } }) do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, i)
            t:SetPoint("TOPLEFT", i - 1, 1 - i)
            t:SetPoint("BOTTOMRIGHT", 1 - i, i - 1)
            t:SetColorTexture(unpack(colour))
            box.medalui[i] = t
        end
        box:HookScript("OnEditFocusGained", Lit)
        box:HookScript("OnEditFocusLost", Lit)
        box:HookScript("OnTextChanged", Lit)
    end
    box.medaluiDressed = true
    Lit(box)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", edit, "TOPLEFT")
    box:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT")
end

-- Blizzard clamps a chat window to the screen with room at its left for
-- the button column (FCF_UpdateButtonSide); in the panel, at the screen's
-- edge, that pushed the messages and the tabs right, out of the box. A
-- docked window keeps no such room; it gets Blizzard's back when it leaves.
local dressed, clamping = {}, false
local function Unclamp(frame)
    if clamping or not dressed[frame] then return end
    clamping = true
    frame:SetClampRectInsets(0, 0, 0, 0)
    clamping = false
end

local function Dress(frame)
    if not frame or dressed[frame] then return end
    dressed[frame] = true
    -- its links' tooltips stand outside the box, as a docked window's do
    ns.window.Mark(frame, -1, chatBox)
    for _, t in ipairs(Textures(frame)) do Gone(t) end
    Gone(frame.ResizeButton)            -- the panel is a fixed size
    EditBox(frame)
    if frame.SetClampRectInsets then
        if not frame.medaluiClamp then
            frame.medaluiClamp = { frame:GetClampRectInsets() }
            hooksecurefunc(frame, "SetClampRectInsets", Unclamp)
        end
        Unclamp(frame)
    end
end

-- Back to Blizzard's look, its size grip (on an unlocked window) and its
-- edit box anchors (FloatingChatFrame.xml).
local function Undress(frame)
    if not frame or not dressed[frame] or frame == ChatFrame1 then return end
    dressed[frame] = nil
    ns.window.Unmark(frame)
    if frame.medaluiClamp then frame:SetClampRectInsets(unpack(frame.medaluiClamp)) end
    for _, t in ipairs(Textures(frame)) do Back(t, true) end
    Back(frame.ResizeButton, not frame.isLocked)
    local box = frame.editBox
    if box then
        local own, focus = BoxArt(box)
        for _, t in ipairs(own) do Back(t, true) end
        for _, t in ipairs(focus) do Back(t) end
        box.medaluiDressed = nil
        Lit(box)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -5, -2)
        if frame.ScrollBar then box:SetPoint("RIGHT", frame.ScrollBar, "RIGHT", 8, 0) end
    end
end

local function Frames()
    local list = {}
    if CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do table.insert(list, _G[name]) end
    else
        for i = 1, NUM_CHAT_WINDOWS or 10 do table.insert(list, _G["ChatFrame" .. i]) end
    end
    return list
end

-- The arrow keys move the cursor in the edit box, as in any text field, to
-- go back and fix a typo; Up and Down step through what was said before.
-- Blizzard's template ignores them unless Alt is held (ignoreArrows), so
-- they turned the character instead. Every window's box, docked or not.
local function Arrows(frame)
    local box = frame.editBox
    if box and box.SetAltArrowKeyMode then box:SetAltArrowKeyMode(false) end
end

-- A channel's tag is its number alone: "[1] [Name]: hi", not "[1. General -
-- Elwynn Forest] [Name]: hi". Blizzard builds the tag inside its own handler,
-- and its filters cannot make it shorter than "[1. ]", so each window's
-- AddMessage is wrapped, as Prat and ElvUI do: the one write to Blizzard's
-- chat, chosen by the user over the filter's "[1. ]". Only a message's tag
-- (channel:channel:N); a join or leave notice (channel:CHANNEL:N) keeps its
-- name, and a secret line passes untouched.
local TAG = "|Hchannel:channel:(%d+)|h%[%d+%.[^%]]*%]|h"

-- A speaker's name in their class's colour, after their level: "[60:Name]"
-- (Chat > Names), the level coloured by how it compares with yours. The
-- class, and a level, come from the line's sender (the link's line ID
-- gives its GUID); else the level is what this session saw
-- of them by name: the group, the target, the mouseover, nameplates, the
-- guild, friends and /who. Unknown, a name keeps the game's colour and has
-- no level. Anything secret is left as it came.
local levels = {}          -- by "Name" on this realm, "Name-Realm" off it
ns.chatLevels = levels
local function Key(name, server)
    if not name or ns.IsSecret(name) or ns.IsSecret(server) or name == "" then return end
    if server and server ~= "" and server ~= GetNormalizedRealmName() then return name .. "-" .. server end
    return name
end
local function KeyOf(full)
    if not full or ns.IsSecret(full) then return end
    local name, server = full:match("^([^%-]+)%-(.+)$")
    return Key(name or full, server)
end
local function Saw(key, level)
    if key and level and not ns.IsSecret(level) and level > 0 then levels[key] = level end
end
local function SawUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    Saw(Key(UnitFullName(unit)), UnitLevel(unit))
end

local PLAYER = "(|Hplayer:([^|]*)|h)%[(.-)%](|h)"
local function Speaker(link, data, shown, close)
    local full, line = data:match("^([^:]*):?(%d*)")
    local guid = line ~= "" and C_ChatInfo.GetChatLineSenderGUID(tonumber(line))
    local class, level
    if guid then                            -- a secret GUID is allowed: its answers are secret
        local _, c, _, _, _, _, _, l = GetPlayerInfoByGUID(guid)
        if not ns.IsSecret(c) then class = c end
        if not ns.IsSecret(l) and l and l > 0 then level = l end
    end
    level = level or levels[KeyOf(full) or ""]
    if ns.db.chatClassColors then
        local color = class and RAID_CLASS_COLORS[class]
        if color then
            shown = format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255,
                (shown:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
        end
    end
    if ns.db.chatLevels and level then
        -- the level in the colour of its difficulty against yours (grey, green, yellow, orange, red)
        local Difficulty = GetCreatureDifficultyColor or GetQuestDifficultyColor
        local c = Difficulty and Difficulty(level)
        local tag = c and c.r and format("|cff%02x%02x%02x%d|r", c.r * 255, c.g * 255, c.b * 255, level) or level
        shown = tag .. ":" .. shown
    end
    return link .. "[" .. shown .. "]" .. close
end

local function Short(text)
    if ns.IsSecret(text) or type(text) ~= "string" then return text end
    text = text:gsub(TAG, "|Hchannel:channel:%1|h[%1]|h")
    return (text:gsub(PLAYER, Speaker))
end
local function Tags(frame)
    local add = frame.AddMessage
    if not add or frame.medaluiAddMessage then return end
    frame.medaluiAddMessage = add
    -- what is shown is kept for the log too (strips/chatlog.lua)
    frame.AddMessage = function(self, text, ...)
        text = Short(text)
        if ns.chatLog then ns.chatLog.Add(self, text, ...) end
        return add(self, text, ...)
    end
end

local function Sweep()
    for _, frame in ipairs(Frames()) do
        Arrows(frame)
        Tags(frame)
        SkinTab(_G[frame:GetName() .. "Tab"])
        if frame == ChatFrame1 or frame.isDocked then Dress(frame) end
    end
end

-- ------------------------------------------------------------------ head
-- A head button's own art, out of sight: its states' textures, and the
-- icons Blizzard draws on it (the friends toast's two, and its count of
-- friends online: nobody reads it). Again whenever Blizzard sets a state's
-- art.
local STATES = { "Normal", "Pushed", "Disabled", "Highlight" }
local function Bare(b)
    for _, state in ipairs(STATES) do
        local get = b["Get" .. state .. "Texture"]
        local t = get and get(b)
        if t then t:SetAlpha(0) end
    end
    for _, key in ipairs({ "Icon", "FriendsButton", "QueueButton", "FriendCount" }) do
        if b[key] and b[key].SetAlpha then b[key]:SetAlpha(0) end
    end
end

-- A gold glyph instead, lit under the mouse, as the quest tracker's footer
local function Flat(b, glyph)
    Bare(b)
    for _, state in ipairs(STATES) do
        for _, kind in ipairs({ "Texture", "Atlas" }) do
            if b["Set" .. state .. kind] then hooksecurefunc(b, "Set" .. state .. kind, Bare) end
        end
    end
    local g = b:CreateTexture(nil, "OVERLAY")
    g:SetTexture(PARTS .. glyph)
    g:SetPoint("CENTER")
    local lit = b:CreateTexture(nil, "HIGHLIGHT")
    lit:SetTexture(PARTS .. glyph)
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.35)
    lit:SetAllPoints(g)
    b.medaluiGlyph = g
end

-- The cog at the tab row's right end, in a box as the tabs are but up to
-- the row's top, and its drawer: another box (ns.window.Face), out to the
-- right over the world, sharing the cog's edge. Both in MEDIUM strata,
-- over the chat frames and the dock (BACKGROUND, under them, took the
-- cog's clicks). A gold divider stands before the cog, where the tabs end.
local function Cog()
    cog = CreateFrame("Button", "MedalUIChatCog", head)
    cog:SetFrameStrata("MEDIUM")
    cog:SetFrameLevel(ChatFrame1:GetFrameLevel() + 5)
    cog:SetSize(BOX, BOX)
    cog:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)
    ns.window.Face(cog)
    local g = cog:CreateTexture(nil, "ARTWORK")
    g:SetTexture(PARTS .. "chat-tools")
    g:SetSize(GLYPH, GLYPH)
    g:SetPoint("CENTER")
    local lit = cog:CreateTexture(nil, "HIGHLIGHT")
    lit:SetTexture(PARTS .. "chat-tools")
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.35)
    lit:SetAllPoints(g)
    cog.glyph = g
    cog:SetScript("OnClick", function()
        open = not open
        Row()
    end)
    cog:SetScript("OnEnter", function(self)
        ns.Tip(self, Outside, { title = Tr["Chat buttons"],
            { "body", Tr["The chat menu, friends, channels and the log."] } })
    end)
    cog:SetScript("OnLeave", GameTooltip_Hide)
    tray = CreateFrame("Frame", "MedalUIChatDrawer", head)
    tray:SetFrameStrata("MEDIUM")
    tray:SetFrameLevel(cog:GetFrameLevel())
    tray:SetHeight(BOX)
    tray:SetPoint("LEFT", cog, "RIGHT", -1, 0)
    ns.window.Face(tray)
    -- the divider between the tabs and the cog, as tall as the cog
    local divider = head:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    divider:SetSize(1, BOX)
    divider:SetPoint("BOTTOMRIGHT", cog, "BOTTOMLEFT", -GAP, 0)
    -- the log's button, among Blizzard's (Head lays it out with them)
    local log = CreateFrame("Button", "MedalUIChatLogButton", tray)
    log:SetScript("OnClick", function() ns.ToggleChatLog() end)
    log:SetScript("OnEnter", function(self)
        ns.Tip(self, Outside, { title = Tr["Log"],
            { "body", Tr["The chat's history in a box of its own, to scroll and to copy from."] } })
    end)
    log:SetScript("OnLeave", GameTooltip_Hide)
    ns.chat.cog, ns.chat.drawer, ns.chat.divider, ns.chat.log = cog, tray, divider, log
end

-- The column's buttons come to the drawer (its art went with the window's,
-- in CHAT_FRAME_TEXTURES), and back to their place there when Blizzard
-- moves one or shows or hides one.
local function Head()
    local function Again()
        if not placing then Row() end
    end
    Cog()
    for _, spec in ipairs(HEAD) do
        local b = _G[spec.name]
        if b then
            if spec.glyph then Flat(b, spec.glyph) end
            b:SetParent(tray)
            b:SetFrameLevel(tray:GetFrameLevel() + 2)
            hooksecurefunc(b, "SetPoint", Again)
            if spec.alert and ChatAlertFrame then hooksecurefunc(ChatAlertFrame, "SetPoint", Again) end
            b:HookScript("OnShow", Again)
            b:HookScript("OnHide", Again)
        end
    end
    if GENERAL_CHAT_DOCK then hooksecurefunc(GENERAL_CHAT_DOCK, "SetPoint", Again) end
    Row()
end

-- ----------------------------------------------------------------- build
local function Build()
    local strip = ns.strips[-1]
    local margin = ns.window.band       -- the windows' margin (the edit box's and buffs' height)
    local foot = margin + RULE                  -- the panel's foot, over the margin's rule
    local top = foot + L.chatHeight + TABS      -- the tabs' top
    chatBox = CreateFrame("Frame", "MedalUIChat", strip)
    chatBox:SetFrameStrata("BACKGROUND")
    chatBox:SetWidth(L.chatLeft + L.chatWidth)
    -- the left strip's: its tooltips and menus just outside the chat, towards
    -- the screen's middle, as the side panel's (strips/side.lua)
    ns.window.Mark(strip, -1, chatBox, true)
    local dress = ns.window.Dress(chatBox, margin)
    dress.rule:SetPoint("BOTTOMLEFT", 0, margin)
    dress.rule:SetPoint("BOTTOMRIGHT", 0, margin)
    panel = CreateFrame("Frame", nil, chatBox)
    panel:SetPoint("BOTTOMLEFT", PAD, foot)
    panel:SetPoint("BOTTOMRIGHT", -PAD, foot)
    panel:SetHeight(L.chatHeight)
    area = CreateFrame("Frame", nil, panel)
    -- the edit box over the margin, beside the medallion, flush with the
    -- margin's row as the character window's shortcuts are
    -- (character/paperdoll.lua): from the strip's cells' start to the box's
    -- right edge, the margin's full height, its top edge on the rule
    edit = CreateFrame("Frame", nil, chatBox)
    edit:SetPoint("BOTTOMLEFT", ns.stripCells.from, 0)
    edit:SetPoint("TOPRIGHT", chatBox, "BOTTOMRIGHT", 0, margin + 1)
    -- the tab row, over the panel up to the box's top edge, edge to edge:
    -- the cog at its right end
    head = CreateFrame("Frame", nil, chatBox)
    head:SetPoint("BOTTOMLEFT", chatBox, "BOTTOMLEFT", 0, foot + L.chatHeight)
    head:SetPoint("BOTTOMRIGHT", chatBox, "BOTTOMRIGHT", 0, foot + L.chatHeight)
    head:SetHeight(BOX)
    -- the hairline between the tabs and the messages
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    -- the margin's start, over the character's medallion, stays whole while
    -- the box fades when idle (Immersion Mode), as the side panel's corner
    -- over the backpack's (strips/side.lua): its own ink (the dress's, its
    -- gradient carried on), trim and rule. The whole box fades, so it stands
    -- beside it on the strip, shown with it, one level up.
    local breakAt = ns.stripCells.from
    local width = L.chatLeft + L.chatWidth
    local well = CreateFrame("Frame", nil, strip)
    well:SetFrameStrata("BACKGROUND")
    well:SetFrameLevel(chatBox:GetFrameLevel() + 1)
    well:SetPoint("BOTTOMLEFT", chatBox, "BOTTOMLEFT")
    well:SetSize(breakAt, margin + 1)
    local tint = ns.colors.ink
    local wellInk = well:CreateTexture(nil, "BACKGROUND", nil, 1)
    wellInk:SetPoint("TOPLEFT", 1, 0)
    wellInk:SetPoint("BOTTOMRIGHT", 0, 1)
    if wellInk.SetGradient and CreateColor then
        local to = 1 - 0.90 * (breakAt - 1) / (width - 2)
        wellInk:SetColorTexture(1, 1, 1, 1)
        wellInk:SetGradient("HORIZONTAL", CreateColor(tint[1], tint[2], tint[3], 1),
            CreateColor(tint[1], tint[2], tint[3], to))
    else
        wellInk:SetColorTexture(tint[1], tint[2], tint[3], 0.55)
    end
    for _, edge in ipairs({ { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" } }) do
        local t = well:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        t[edge[3]](t, 1)
    end
    -- from the edge, closing the corner on the trim: the dress's starts in
    local wellRule = well:CreateTexture(nil, "ARTWORK")
    wellRule:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    wellRule:SetHeight(1)
    wellRule:SetPoint("TOPLEFT")
    wellRule:SetPoint("TOPRIGHT")
    well.rule = wellRule
    -- its right side, closed while it stands alone: as the box fades out
    -- (the margin's row beside it goes) and no timeless buff stands there
    -- (the first one's rim closes it); with the box whole it would split
    -- the margin's row
    local wellEdge = well:CreateTexture(nil, "BACKGROUND", nil, 2)
    wellEdge:SetColorTexture(GOLD_D[1], GOLD_D[2], GOLD_D[3], 1)
    wellEdge:SetPoint("TOPRIGHT")
    wellEdge:SetPoint("BOTTOMRIGHT")
    wellEdge:SetWidth(1)
    wellEdge:SetAlpha(0)
    well.edge = wellEdge
    well:SetShown(chatBox:IsShown())
    chatBox:HookScript("OnShow", function() well:Show() end)
    chatBox:HookScript("OnHide", function() well:Hide() end)
    ns.chat = { box = chatBox, dress = dress, panel = panel, area = area, edit = edit, head = head, top = top,
        well = well }

    chatBox:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, L.stripHeight)
    chatBox:SetHeight(top)
    -- The box's reach up to the screen's top, the quest tracker's full view
    -- in it: a box of its own on the chat's, its foot the chat box's top
    -- edge, so the two read as one; and the tracker fading fades it alone.
    local reach = CreateFrame("Frame", nil, strip)
    reach:SetFrameStrata("BACKGROUND")
    reach:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    reach:SetPoint("BOTTOMRIGHT", chatBox, "TOPRIGHT", 0, -1)
    local reachDress = ns.window.Dress(reach, 0)
    reachDress.rule:Hide()
    -- up: the reach shown, as much of it as alpha (the tracker's fade)
    local function Draw(up, alpha)
        alpha = up and (alpha or 1) or 0
        reach:SetShown(up and true or false)
        reach:SetAlpha(alpha)
    end
    -- An NPC window (npc/window.lua) stands on the box in the reach's
    -- place, a box of its own as tall as it needs: held, the reach is gone,
    -- the tracker's asks kept for after. The LFG window (social/lfg.lua)
    -- holds it too: each holder by name, held while any is.
    local wanted, held, holders = { false }, false, {}
    function ns.chat.Reach(up, alpha)
        wanted = { up, alpha }
        if not held then Draw(up, alpha) end
    end
    function ns.chat.Hold(on, who)
        holders[who or "npc"] = on and true or nil
        held = next(holders) ~= nil
        if held then
            reach:Hide()
        else
            Draw(wanted[1], wanted[2])
        end
    end
    -- something standing on the chat box: a window held there (an NPC's,
    -- the flight map, the LFG window, one of the reskinned ones), or the
    -- quest tracker's full view in the reach, while it shows at all
    function ns.chat.Stood()
        return held or (wanted[1] and (wanted[2] or 1) > 0) and true or false
    end
    ns.chat.reach = reach
    ns.chat.Reach(false)
    -- the timeless buffs along the margin, beside the medallion; the edit
    -- boxes clear of them as they come and go
    function ns.chat.WellEdge()
        local box = ns.chatChrome and ns.chatChrome.alpha or 1
        local buffs = ns.BuffRowWidth and ns.BuffRowWidth() or 0
        well.edge:SetAlpha(buffs > 0 and 0 or 1 - box)
    end
    function ns.chat.BuffsChanged()
        for frame in pairs(dressed) do
            if frame.editBox then Lit(frame.editBox) end
        end
        ns.chat.WellEdge()
    end
    ns.BuffRow({ x = ns.stripCells.from, y = ns.stripArt.height - L.stripHeight - (margin + 1) / 2 })

    -- The docked tabs in one row, each after the last. Blizzard keeps a
    -- window the player made (Guild, Instance: not static-docked) in the
    -- dock's scroll frame, which scrolls by its own fixed tab widths and
    -- clips the pointer to itself, while this row lays them out by their
    -- words; their tooltips flashed (the user's, 2026-11-25). So every
    -- docked tab stands on the dock itself, as General's does, over the
    -- scroll frame, and is only moved when it is somewhere else.
    local function FitTabs()
        local prev
        local dock = GENERAL_CHAT_DOCK
        for _, frame in ipairs(Frames()) do
            local tab = _G[frame:GetName() .. "Tab"]
            if tab and tab.medalui then
                FitTab(tab)
                if frame == ChatFrame1 or frame.isDocked then
                    if dock and tab:GetParent() ~= dock then tab:SetParent(dock) end
                    local scroll = dock and dock.scrollFrame
                    if scroll and tab:GetFrameLevel() <= scroll:GetFrameLevel() then
                        tab:SetFrameLevel(scroll:GetFrameLevel() + 1)
                    end
                    if prev and tab:GetNumPoints() > 0 then
                        local point, to, rel, x, y = tab:GetPoint(1)
                        if tab:GetNumPoints() ~= 1 or point ~= "LEFT" or to ~= prev or rel ~= "RIGHT"
                            or x ~= -1 or y ~= 0 then
                            tab:ClearAllPoints()
                            tab:SetPoint("LEFT", prev, "RIGHT", -1, 0)
                        end
                    end
                    prev = tab
                end
            end
        end
    end
    if FCFDock_UpdateTabs then hooksecurefunc("FCFDock_UpdateTabs", FitTabs) end
    if _G.PanelTemplates_TabResize then hooksecurefunc("PanelTemplates_TabResize", FitTab) end

    Measure()
    Place()
    Sweep()
    -- last session's lines, back in their windows (strips/chatlog.lua)
    if ns.chatLog and ns.chatLog.Restore then ns.chatLog.Restore() end
    -- A link clicked in a docked window opens Blizzard's ItemRefTooltip at
    -- the screen's foot (ANCHOR_PRESERVE: where it last was); it stands
    -- beside the box instead, as a hovered one does. Dragged, it stays
    -- where it is put until the next click. A modified click puts the link
    -- in the edit box and shows nothing.
    if SetItemRef then
        hooksecurefunc("SetItemRef", function(_, _, _, frame)
            if not frame or ns.IsSecret(frame) or IsModifiedClick() then return end
            if ItemRefTooltip and ItemRefTooltip:IsShown() then ns.window.PlaceOutside(ItemRefTooltip, frame) end
        end)
    end
    -- Blizzard re-places the chat frame from its saved layout and Edit Mode
    hooksecurefunc(ChatFrame1, "SetPoint", function()
        if not placing then Place() end
    end)
    -- the tabs never fade: their box and colour already say which one is
    -- chosen. FCFTab_UpdateAlpha reads these, for each docked tab, every
    -- time the dock's tabs are fitted (Dock, from Head's first Row on).
    for _, key in ipairs({ "SELECTED", "ALERTING", "NORMAL" }) do
        _G["CHAT_FRAME_TAB_" .. key .. "_MOUSEOVER_ALPHA"] = 1
        _G["CHAT_FRAME_TAB_" .. key .. "_NOMOUSE_ALPHA"] = 1
    end
    if ChatFrame1.buttonFrame then Head() end
    -- a scale change moves the room the chat's own pieces need
    local function Rescaled()
        for _, frame in ipairs(Frames()) do
            local tab = _G[frame:GetName() .. "Tab"]
            if tab and tab.medaluiSlot then Slot(tab) end
        end
        Measure()
        Place()
        ns.chat.BuffsChanged()
    end
    hooksecurefunc(ns.console, "SetScale", Rescaled)
    hooksecurefunc(UIParent, "SetScale", Rescaled)

    if FCFTab_UpdateColors then hooksecurefunc("FCFTab_UpdateColors", Selected) end
    -- a whisper window is new, and docked here too (FCF_OpenTemporaryWindow)
    if FCF_DockFrame then
        hooksecurefunc("FCF_DockFrame", function(frame)
            Arrows(frame)
            Tags(frame)
            SkinTab(_G[frame:GetName() .. "Tab"])
            Dress(frame)
        end)
    end
    if FCF_UnDockFrame then hooksecurefunc("FCF_UnDockFrame", Undress) end
end

-- --------------------------------------------------------------- immersion
-- Bare when idle (Shared > Visibility & fading, Immersion Mode): left
-- alone, the chat's chrome (the box, its tabs, the cog, the scroll bar)
-- fades out and each message stands on a pill of its own over the world
-- (2026-11-25: rounded, hugging its words, its width measured but never
-- tested when secret);
-- the chrome comes back while it is typed in, pointed at, scrolled up, its
-- drawer open, something stands on it (a window docked above it, the quest
-- tracker's full view), or (ticked) in combat, and goes again chatBareDelay seconds
-- after. A band's height is its line's points; its width is measured, but
-- a secret line's (its text may be secret) is the window's, untested. It
-- follows its line's alpha, so Blizzard's own chat fade takes the band
-- with the line. A line Blizzard lays out again
-- drops out of visibleLines (fewer lines: a shorter window, a bigger font)
-- and its band goes with it. Blizzard lays out lines enough for one-line
-- messages, so wrapped ones push the top lines past the window's top,
-- where its FontStringContainer clips them: the bands are clipped there
-- too, in a frame of their own (wider at the sides, for their margin).
-- Docked windows only: one torn out is Blizzard's.
local inCombat, idle = false, 0
local chrome                -- the chrome's fader; its alpha is the box's
local bands = {}            -- a line's band, by the line (a FontString)
ns.chatBands = bands

local function Num(key, lo, hi)
    local v = tonumber(ns.db[key])
    if v == nil then v = tonumber(ns.OptionBase(key)) or lo end
    return math.max(lo, math.min(hi, v))
end

-- dressed is docked: a window torn out is undressed (FCF_UnDockFrame)
local function Docked()
    local out = {}
    for _, frame in ipairs(Frames()) do
        if frame and dressed[frame] then table.insert(out, frame) end
    end
    return out
end

local function Immersed() return ns.db.chatImmersion and chatBox ~= nil end

-- (2026-11-25, /workspace/chat-A.png, the user's pick: modern) each line's
-- band a pill: rounded, hugging its words, a hair apart from the next.
-- Its pieces: four corners cut from the round art, the edges between them,
-- the middle; all ink at the bands' strength (chatBands)
local PILL = { r = 6, x = 9, top = 1, foot = 2 }    -- its corners; out past the words; in at the top, the foot
local ROUND = ns.media .. "strips\\round"
local function Tint(band)
    local ink, a = ns.colors.ink, Num("chatBands", 0, 1)
    for _, t in ipairs(band.parts) do t:SetVertexColor(ink[1], ink[2], ink[3], a) end
end

local function Pill(parent)
    local band = CreateFrame("Frame", nil, parent)
    band:SetFrameLevel(parent:GetFrameLevel())      -- (the clip's: under the lines' container)
    band.parts = {}
    local r = PILL.r
    local function Part(round)
        local t = band:CreateTexture(nil, "BACKGROUND")
        if round then t:SetTexture(ROUND) else t:SetTexture("Interface\\Buttons\\WHITE8X8") end
        table.insert(band.parts, t)
        return t
    end
    for _, c in ipairs({ { "TOPLEFT", 0, 0.5, 0, 0.5 }, { "TOPRIGHT", 0.5, 1, 0, 0.5 },
        { "BOTTOMLEFT", 0, 0.5, 0.5, 1 }, { "BOTTOMRIGHT", 0.5, 1, 0.5, 1 } }) do
        local t = Part(true)
        t:SetSize(r, r)
        t:SetPoint(c[1])
        t:SetTexCoord(c[2], c[3], c[4], c[5])
    end
    local top = Part()
    top:SetPoint("TOPLEFT", r, 0)
    top:SetPoint("TOPRIGHT", -r, 0)
    top:SetHeight(r)
    local foot = Part()
    foot:SetPoint("BOTTOMLEFT", r, 0)
    foot:SetPoint("BOTTOMRIGHT", -r, 0)
    foot:SetHeight(r)
    local mid = Part()
    mid:SetPoint("TOPLEFT", 0, -r)
    mid:SetPoint("BOTTOMRIGHT", 0, r)
    Tint(band)
    return band
end

-- a pill's width: its words' and its padding; a line wrapped, its window's.
-- A secret line's measure is secret too, never tested: the window's
local function Hug(band, line)
    local full = line:GetWidth() or 0
    local w = full
    local sw = line:GetStringWidth()
    local n = line.GetNumLines and line:GetNumLines()
    if not ns.IsSecret(sw) and not ns.IsSecret(n) and type(sw) == "number" then
        local lines = type(n) == "number" and n or 1
        w = (sw > full or lines > 1) and full or sw
    end
    band:SetWidth(math.max(2 * PILL.r, w + 2 * PILL.x))
end

-- each visible line's band, shown with it, as much of it as its line is
-- and as the chrome is not
local clips = {}            -- a window's bands' clip, by the window
local function Clip(frame)
    local clip = clips[frame]
    if not clip then
        clip = CreateFrame("Frame", nil, frame)
        clip:SetPoint("TOPLEFT", frame, "TOPLEFT", -PILL.x - 1, 0)
        -- (out at the right too: a wrapped line's pill runs the window's
        -- width and its padding, its corners round, 2026-11-25)
        clip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", PILL.x + 1, -2)
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(frame:GetFrameLevel())   -- under the lines' container
        clips[frame] = clip
    end
    return clip
end

local function Bands(frame)
    -- the chrome is whole while the mode is off, so no band shows then
    local away = 1 - (chrome and chrome.alpha or 1)
    local current = {}
    for _, line in ipairs(frame.visibleLines or {}) do current[line] = true end
    -- a line laid out away (released to the pool) never comes round again
    for line, band in pairs(bands) do
        if band.frame == frame and not current[line] then band:Hide() end
    end
    for _, line in ipairs(frame.visibleLines or {}) do
        local band = bands[line]
        if not band and away > 0 then
            band = Pill(Clip(frame))
            band:SetPoint("TOPLEFT", line, "TOPLEFT", -PILL.x, PILL.top)
            band:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", -PILL.x, PILL.foot)
            band.frame = frame
            bands[line] = band
        end
        if band then
            local on = away > 0 and frame:IsShown() and line:IsShown()
            band:SetShown(on and true or false)
            if on then
                Hug(band, line)
                band:SetAlpha(away * (line:GetAlpha() or 1))
            end
        end
    end
end

local function AllBands()
    for _, frame in ipairs(Docked()) do Bands(frame) end
end

-- Blizzard's own chat fade (UIFrameFade, each frame) writes a scroll bar's
-- alpha between our looks, so the bar flickered under the pointer
-- (2026-11-20): while bare, each such write is put back to the chrome's
-- at once
local held, holding = {}, false
local function Hold(part)
    if held[part] or not part.SetAlpha then return end
    held[part] = true
    hooksecurefunc(part, "SetAlpha", function(self, a)
        if holding or not (Immersed() and chrome) or a == chrome.alpha then return end
        holding = true
        self:SetAlpha(chrome.alpha)
        holding = false
    end)
end

-- the chrome at an alpha: the box and all on it, the docked windows' scroll
-- bars and tabs; the bands the other way
local function Chrome(a)
    if chatBox then chatBox:SetAlpha(a) end
    if ns.chat and ns.chat.WellEdge then ns.chat.WellEdge() end
    for _, frame in ipairs(Docked()) do
        -- (each by name: a client without one, the rest still)
        for _, key in ipairs({ "ScrollBar", "ScrollToBottomButton", "buttonFrame" }) do
            local part = frame[key]
            if part and part.SetAlpha then
                Hold(part)
                holding = true
                part:SetAlpha(a)
                holding = false
            end
        end
        local tab = _G[frame:GetName() .. "Tab"]
        if tab then tab:SetAlpha(a) end
    end
    AllBands()
end

-- the chrome wanted now: off, or the chat in use
function ns.ChatWanted()
    if not Immersed() then return true end
    if open or (ns.db.chatBareCombat and inCombat) then return true end
    -- a window docked on it, or the tracker over it: the box under them
    if ns.chat.Stood() then return true end
    if chatBox:IsMouseOver() then return true end
    for _, frame in ipairs(Docked()) do
        local box = frame.editBox
        if box and box:HasFocus() then return true end
        if frame:IsShown() then
            if frame:IsMouseOver() then return true end
            if frame.AtBottom and not frame:AtBottom() then return true end
        end
    end
    return false
end

-- now: a setting changed, so go there at once rather than fade
local function Immerse(now, dt)
    if not chrome then return end
    local want = ns.ChatWanted()
    idle = want and 0 or idle + (dt or 0)
    local goal = (want or idle < Num("chatBareDelay", 0, 10)) and 1 or 0
    if now then
        chrome:Go(goal, 0)
    elseif goal ~= chrome.goal then
        chrome:Go(goal, goal == 1 and 0.2 or 0.6)
    end
end
ns.UpdateChatBare = Immerse

local function Immersion()
    chrome = ns.Fader({
        GetAlpha = function() return 1 end,
        SetAlpha = function(_, a) Chrome(a) end,
    })
    ns.chatChrome = chrome
    for _, frame in ipairs(Frames()) do
        if frame and frame.RefreshDisplay then hooksecurefunc(frame, "RefreshDisplay", Bands) end
    end
    -- Blizzard's own fade of a tab, while bare, kept to the chrome's
    if FCFTab_UpdateAlpha then
        hooksecurefunc("FCFTab_UpdateAlpha", function(frame)
            local tab = frame and frame.GetName and _G[frame:GetName() .. "Tab"]
            if tab and Immersed() and dressed[frame] then tab:SetAlpha(chrome.alpha) end
        end)
    end
    -- the pointer, the scroll and the lines' own fade have no event: the
    -- chat looks ten times a second
    local watch = CreateFrame("Frame", nil, UIParent)
    local since = 0
    watch:SetScript("OnUpdate", function(_, dt)
        since = since + dt
        if since < 0.1 then return end
        Immerse(false, since)
        since = 0
        -- Blizzard's own chat fade (UIFrameFade on the tabs and buttons)
        -- writes past the hook: held to the chrome's while bare
        if Immersed() then Chrome(chrome.alpha) end
    end)
    ns.chatBareWatch = watch
    inCombat = UnitAffectingCombat("player") and true or false
    Immerse(true)
end

ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; Immerse() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; Immerse() end)
ns.OnSetting("chatImmersion", function()
    idle = 0
    Immerse(true)
    AllBands()
end)
ns.OnSetting("chatBareCombat", function() Immerse() end)
ns.OnSetting("chatBands", function()
    for _, band in pairs(bands) do Tint(band) end
    AllBands()
end)

ns.On("PLAYER_LOGIN", function()
    if ns.db.chat and ChatFrame1 then
        Build()
        Immersion()
    end
end)

-- ------------------------------------------------------------ the levels seen
ns.On("PLAYER_LOGIN", function() SawUnit("player") end)
ns.On("PLAYER_LEVEL_UP", function(_, level) Saw(Key(UnitFullName("player")), level) end)
ns.On("PLAYER_TARGET_CHANGED", function() SawUnit("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() SawUnit("mouseover") end)
ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) SawUnit(unit) end)
ns.On("UNIT_LEVEL", function(_, unit) SawUnit(unit) end)
ns.On("GROUP_ROSTER_UPDATE", function()
    local raid = IsInRaid()
    for i = 1, raid and 40 or 4 do SawUnit((raid and "raid" or "party") .. i) end
end)
ns.On("GUILD_ROSTER_UPDATE", function()
    if not GetGuildRosterInfo then return end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level = GetGuildRosterInfo(i)
        Saw(KeyOf(name), level)
    end
end)
ns.On("FRIENDLIST_UPDATE", function()
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info then Saw(KeyOf(info.name), info.level) end
    end
end)
ns.On("WHO_LIST_UPDATE", function()
    for i = 1, C_FriendList.GetNumWhoResults() do
        local info = C_FriendList.GetWhoInfo(i)
        if info then Saw(KeyOf(info.fullName), info.level) end
    end
end)
