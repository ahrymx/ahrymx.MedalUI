-- The chat's log: a box of its own (the window shell, detached only:
-- chatLogPlace), opened by the Log button in the chat's drawer
-- (strips/chat.lua), with a chat window's history as plain text: a tab
-- for each chat window across its top. Its text can be selected by
-- dragging across it, and copied with Ctrl+C: the game lets text be
-- selected only in an edit box, so the log is one, that a key cannot
-- change.
--
--   [ log ]                                                     [x]
--   ---------------------------------------------------------------
--   [General][Trade][Whispers]
--   | the window's lines, oldest first, scrolled to the newest
--   ---------------------------------------------------------------
--   General · 214 lines                     drag to select, Ctrl+C
--
-- The lines are kept here, as each window's AddMessage passes them (the
-- one wrap on Blizzard's chat, strips/chat.lua): reading them back out of
-- the chat frame would be calling Blizzard's code. So the log holds what
-- came since the UI loaded, the last MAX of each window, and what was
-- saved from the last session. A line the game keeps secret is kept as a
-- note that it was there. Links, icons and colours are taken out, so a
-- copy is plain text.
--
-- While the text is selected (the box has focus), new lines wait: setting
-- the text would drop the selection. The band says how many are waiting;
-- they come in when the box is left (a click outside, or Escape).
--
-- The saved history (Chat > History, chatHistory lines, per character):
-- the last lines of each chat window, as shown, links and all, kept in
-- MedalUICharDB at logout and put back in their windows at the next
-- login, dimmed, under a divider; the log takes them too. Not the combat
-- log, nor the voice transcript, nor a line the game keeps secret. A
-- player's link loses its line ID (it names the sender of a line of this
-- session), and a Battle.net name its session's ID (as its plain text).
local _, ns = ...
local Tr = ns.L

local GOLD = ns.gold.light
local DIM = { 0.70, 0.66, 0.55 }
local MAX = 1000                        -- lines kept for each window, at least
local GUTTER, STEP = 10, 14 * 3         -- the scroll bar's room, a wheel's step (three lines)
local INSET = 2                         -- the text's room inside the box
local SECRET = Tr["(a line the game keeps hidden)"]
local FADED = 0.6                       -- a saved line's colour, put back
local DIVIDER = Tr["\226\128\148 last session, saved %s \226\128\148"]
local DIVIDER_COLOR = { 0.66, 0.58, 0.37 }

local logs = {}                         -- a chat frame -> its lines, oldest first
local raw = {}                          -- a chat frame -> its lines as shown, for the history: { text, r, g, b }
ns.chatLog = { logs = logs, raw = raw }

-- the lines of each window the history keeps (0: none)
local function Keep()
    local n = ns.db and ns.db.chatHistory
    return type(n) == "number" and n > 0 and math.floor(n) or 0
end
local function Most() return math.max(MAX, Keep()) end

-- The combat log and the voice transcript are no chat to keep or read.
local function Skipped(f)
    return f == ChatFrame2 or (IsVoiceTranscription and IsVoiceTranscription(f)) and true or false
end
ns.chatLog.Skipped = Skipped

-- A message as plain text: a link's shown text, no icons, no colours.
local function Plain(text)
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|K.-|k", "(Battle.net)")
    text = text:gsub("|cn[^:]*:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (text:gsub("|n", " "))
end

-- A line as it can be shown in another session: a player's link without
-- its line ID, a Battle.net name as plain text (its IDs are this session's).
local function Lasting(text)
    text = text:gsub("|Hplayer:([^:|]*):%d+", "|Hplayer:%1:0")
    text = text:gsub("|HBNplayer:.-|h(.-)|h", "%1")
    return (text:gsub("|K.-|k", "(Battle.net)"))
end
ns.chatLog.Lasting = Lasting

local W, page, box, measure, scroller, name, note, marked
local shown, frame = "", nil            -- the text set, and whose it is
local picked                            -- the window a tab chose (else the chat's own)
local waiting = 0                       -- lines come while the text is selected
local dirty = false
local stick = true                      -- the list kept at its newest line

-- The chat windows the log has a tab for, in the chat's order: the docked
-- ones, and any other shown.
local function Windows()
    local list, names = {}, CHAT_FRAMES
    if not names then
        names = {}
        for i = 1, NUM_CHAT_WINDOWS or 10 do names[i] = "ChatFrame" .. i end
    end
    for _, n in ipairs(names) do
        local f = _G[n]
        if f and not Skipped(f) and (f == ChatFrame1 or f.isDocked or f:IsShown()) then table.insert(list, f) end
    end
    return list
end

-- a window's name, as its tab says
local function Label(f)
    local title = f and _G[f:GetName() .. "Tab"]
    local label = title and title.GetText and title:GetText()
    if (not label or label == "") and title and title.Text then label = title.Text:GetText() end
    if not label or ns.IsSecret(label) or label == "" then label = f and f.name or Tr["Chat"] end
    return label
end

-- The chat window the log is of: the one its tab chose, else the one
-- chosen in the chat (its tab).
local function Source()
    if picked then return picked end
    local f = SELECTED_CHAT_FRAME or ChatFrame1
    return f and logs[f] and not Skipped(f) and f or ChatFrame1
end

local function Band()
    if not name then return end
    local f = frame
    local n = f and logs[f] and #logs[f] or 0
    name:SetText(Label(f) .. " · " .. ns.Plural(n, format(Tr["%d |4line:lines;"], n)))
    if waiting > 0 then
        note:SetText(ns.Plural(waiting, format(Tr["%d new |4line:lines;: click outside to see"], waiting)))
        note:SetTextColor(unpack(GOLD))
    else
        note:SetText(Tr["Drag to select, Ctrl+C to copy"])
        note:SetTextColor(unpack(DIM))
    end
end

-- the shown window's tab marked: the head's tabs again when it changes
local function Mark()
    if not W or marked == frame then return end
    marked = frame
    W.Retab()
end

local Fill
-- The log's head: a tab for each window (the shell draws them in the
-- page's tab's place), the shown one marked.
local function Heads()
    local items, found = {}, false
    for _, f in ipairs(Windows()) do
        if f == picked then found = true end
        table.insert(items, { label = Label(f), selected = f == frame,
            tip = function() return format(Tr["Show %s's lines."], Label(f)) end,
            click = function()
                picked = f
                Fill()
            end })
    end
    if picked and not found then picked = nil end
    return items
end

-- A tab for each window, again: one added, closed, docked or renamed.
local function Retab()
    if not W then return end
    marked = frame
    W.Retab()
end
ns.chatLog.Retab = Retab

-- The list as wide as the window's inside (the box hangs across it), as
-- tall as its text, measured, and at the newest line, or kept where it was
-- when the reader had scrolled up. Both sizes are set, never waited for: a
-- box with no width, or one hung by its top edge alone (no height), is not
-- drawn, and so never grows to its text (the first two builds did each).
-- The width is the window's own, which the shell sets: the scroll frame's,
-- read as it opens, can be 0.
local function Fit()
    local child = scroller.child
    local width = math.max(1, W.window:GetWidth() - 2 * ns.window.pad - GUTTER)
    measure:SetWidth(math.max(1, width - 2 * INSET))
    measure:SetText(shown)
    local tall = shown ~= "" and measure:GetStringHeight() + 2 * INSET or 0
    local height = math.max(scroller.scroll:GetHeight() or 0, tall, 1)
    child:SetSize(width, height)
    box:SetHeight(height)
    if stick then
        scroller.To(scroller.scroll:GetVerticalScrollRange() or 0, true)
    else
        scroller.To(scroller.target, true)
    end
end

-- The text from the log; not while it is selected.
function Fill()
    if not box then return end
    if box:HasFocus() then
        Band()
        return
    end
    local range = scroller.scroll:GetVerticalScrollRange() or 0
    stick = frame ~= Source() or scroller.target >= range - 2
    frame = Source()
    local lines = logs[frame] or {}
    shown = table.concat(lines, "\n")
    box:SetText(shown)
    waiting = 0
    Fit()
    Band()
    Mark()
end

-- a list kept to its last n, dropped a batch at a time, not a line at a time
local function Trim(lines, n)
    if #lines <= n + n / 4 then return end
    local cut, all = #lines - n, #lines
    for i = 1, n do lines[i] = lines[i + cut] end
    for i = all, n + 1, -1 do lines[i] = nil end
end

-- a line into the log's text
local function Log(f, text)
    local lines = logs[f]
    if not lines then
        lines = {}
        logs[f] = lines
    end
    table.insert(lines, text)
    Trim(lines, Most())
    if W and W.window and W.window:IsShown() and f == frame then
        if box:HasFocus() then waiting = waiting + 1 end
        dirty = true
    end
end

-- a line for the saved history, as shown, with its colour
local function Number(v)
    if type(v) == "number" and not ns.IsSecret(v) then return v end
end
local function Hold(f, text, r, g, b)
    local keep = Keep()
    if keep == 0 or Skipped(f) then return end
    local lines = raw[f]
    if not lines then
        lines = {}
        raw[f] = lines
    end
    table.insert(lines, { text, Number(r), Number(g), Number(b) })
    Trim(lines, keep)
end

-- each window's AddMessage, as shown (strips/chat.lua): its text and colour
function ns.chatLog.Add(f, text, r, g, b)
    if ns.IsSecret(text) then
        Log(f, SECRET)
        return
    elseif type(text) ~= "string" then
        return
    end
    Log(f, Plain(text))
    Hold(f, text, r, g, b)
end

-- ----------------------------------------------------------- history
-- the name the window has now (the game's own word for it, else its tab's)
local function WindowName(n, f)
    if GetChatWindowInfo then
        local ok, title = pcall(GetChatWindowInfo, n)
        if ok and type(title) == "string" and not ns.IsSecret(title) and title ~= "" then return title end
    end
    return Label(f)
end

-- Last session's lines back in their windows, dimmed, under a divider,
-- through each window's own AddMessage (before the wrap: not tagged again);
-- the log takes them too, and the next save keeps them. A window renamed
-- since is someone else's lines: left out. Once, after the chat's wrap is
-- on (strips/chat.lua's Build); again only when asked (the harness).
local restored = false
function ns.chatLog.Restore(again)
    if restored and not again then return end
    restored = true
    local saved = MedalUICharDB and MedalUICharDB.chatHistory
    if type(saved) ~= "table" or type(saved.windows) ~= "table" or Keep() == 0 then return end
    local when = type(saved.saved) == "number" and date("%d %b %H:%M", saved.saved) or "?"
    for n, w in pairs(saved.windows) do
        local f = type(n) == "number" and _G["ChatFrame" .. n]
        local lines = type(w) == "table" and w.lines
        if f and type(lines) == "table" and #lines > 0 and not Skipped(f)
            and (not w.name or w.name == WindowName(n, f)) then
            local add = f.medaluiAddMessage or f.AddMessage
            local divider = format(DIVIDER, when)
            add(f, divider, unpack(DIVIDER_COLOR))
            Log(f, divider)
            for i = math.max(1, #lines - Keep() + 1), #lines do
                local l = lines[i]
                if type(l) == "table" and type(l[1]) == "string" then
                    local r, g, b = l[2] or 1, l[3] or 1, l[4] or 1
                    add(f, l[1], r * FADED, g * FADED, b * FADED)
                    Log(f, Plain(l[1]))
                    Hold(f, l[1], l[2], l[3], l[4])
                end
            end
        end
    end
end

-- This session's lines (and the last's, put back) for the next: the last
-- chatHistory of each window. Only while the chat's own (the wrap sees the
-- lines): with the chat box off, what was saved stays as it was.
local function Save()
    if not W then return end
    MedalUICharDB = MedalUICharDB or {}
    local keep = Keep()
    if keep == 0 then
        MedalUICharDB.chatHistory = nil
        return
    end
    local windows = {}
    for f, list in pairs(raw) do
        local n = tonumber((f:GetName() or ""):match("^ChatFrame(%d+)$"))
        if n and #list > 0 and not Skipped(f) then
            local lines = {}
            for i = math.max(1, #list - keep + 1), #list do
                local l = list[i]
                lines[#lines + 1] = { Lasting(l[1]), l[2], l[3], l[4] }
            end
            windows[n] = { name = WindowName(n, f), lines = lines }
        end
    end
    MedalUICharDB.chatHistory = { saved = time and time(), windows = windows }
end
ns.chatLog.Save = Save
ns.On("PLAYER_LOGOUT", Save)

-- Chat > History's button: nothing saved, and nothing of this session kept
-- for the next.
function ns.chatLog.Clear()
    if MedalUICharDB then MedalUICharDB.chatHistory = nil end
    wipe(raw)
end

-- ----------------------------------------------------------- the window
local function Build(body, _, band)
    scroller = ns.window.Scroller(body, GUTTER)
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function(_, delta) scroller.To(scroller.target - delta * STEP) end)
    box = CreateFrame("EditBox", "MedalUIChatLogText", scroller.child)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetFontObject(ChatFontNormal)
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(INSET, INSET, INSET, INSET)
    box:SetPoint("TOPLEFT")
    box:SetPoint("TOPRIGHT")
    -- the text's height, from a hidden string of the same font and width
    measure = scroller.child:CreateFontString(nil, "ARTWORK")
    measure:SetFontObject(ChatFontNormal)
    measure:SetJustifyH("LEFT")
    measure:SetWordWrap(true)
    measure:SetNonSpaceWrap(true)
    measure:Hide()
    box:SetScript("OnEscapePressed", box.ClearFocus)
    -- read only: whatever a key changes is put back
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(shown) end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if waiting > 0 then Fill() end
    end)
    -- the list follows the cursor, so a drag past an edge goes on scrolling
    box:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local view = scroller.scroll:GetHeight() or 0
        local top, bottom = -y, -y + h
        if top < scroller.target then
            scroller.To(top, true)
        elseif bottom > scroller.target + view then
            scroller.To(bottom - view, true)
        end
    end)
    ns.chatLog.box = box

    name = ns.Text(band, 12)
    name:SetPoint("LEFT", 2, 0)
    name:SetTextColor(unpack(GOLD))
    note = ns.Text(band, 11)
    note:SetPoint("RIGHT", -18, 0)          -- clear of the size grip
end

local function Start()
    W = ns.Window{
        name = "MedalUIChatLog", named = Tr["Chat Log"], side = -1, place = "chatLogPlace", detachedOnly = true,
        closeTip = Tr["Close the log."],
        Close = function() W.SetShown(false) end,
        Lifted = function() return {} end,
    }
    page = { key = "log", label = Tr["Chat log"], glyph = "log", order = 1, flex = true, bandUsed = true,
        height = 80,
        tip = Tr["A chat window's lines, a tab for each: drag to select, Ctrl+C to copy."],
        Available = function() return true end,
        headTabs = Heads,
        Build = Build,
        Refresh = function() Fill() end,
        Fit = function()
            if box then Fit() end
        end,
        -- opened at the newest line of the chat's chosen window
        Shown = function()
            frame, picked = nil, nil
            Retab()
            Fill()
        end }
    W.Page(page)
    ns.chatLog.window = W.Build()
    ns.chatLog.W = W
    -- new lines, drawn at the next frame; the chosen window, followed
    W.window:HookScript("OnUpdate", function()
        if dirty or frame ~= Source() then
            dirty = false
            Fill()
        end
    end)
    -- the tabs follow the chat's windows: opened, closed, docked, renamed
    local function Again()
        if W.window:IsShown() then Retab() end
    end
    for _, event in ipairs({ "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS" }) do ns.On(event, Again) end
    for _, fn in ipairs({ "FCF_DockFrame", "FCF_UnDockFrame", "FCF_Close", "FCF_SetWindowName" }) do
        if _G[fn] then hooksecurefunc(fn, Again) end
    end
end

-- with the chat: the box is built at login, shown by the drawer's button
ns.On("PLAYER_LOGIN", function()
    if ns.db.chat then Start() end
end)

-- The drawer's button (strips/chat.lua) opens and closes it; the window is
-- no secure frame, so in combat too.
function ns.ChatLogShown() return W ~= nil and W.window:IsShown() end

function ns.ToggleChatLog()
    if not W then return end
    if not W.Current() then W.Select(page) end
    W.SetShown(not W.window:IsShown())
end
