-- The setup wizard: two questions a new character starts with, in one
-- small window in the settings window's look.
--
--   +--------------------------------------------------+
--   | MedalUI   Setup · 1 of 2                    [x] |
--   |--------------------------------------------------|
--   | Choose your console                              |
--   | what it is for                                   |
--   |  [ Reticule (default) ...                      ] |
--   |  [ Arena (WIP) ...                             ] |
--   |--------------------------------------------------|
--   | Skip                              [Back] [Next]  |
--   +--------------------------------------------------+
--
--   1  the console (Console > General's Profile; account-wide);
--   2  Immersion Mode: each part's switch, all ticked to start (the
--      console's only on the Reticule).
--
-- Its answers are its own until Finish, which writes them all
-- (ns.ApplySetup, settings.lua). Skip, the cross and Esc write nothing but
-- that this character has been through it (ns.SetupDone).
--
-- Shown by itself at the first login (or reload) of a character new to
-- MedalUI (ns.SetupOwed), out of combat and after the known-issues
-- dialog (fixes.lua); again by /mdlui setup or Console > General's Run
-- setup again.
local _, ns = ...
local Tr = ns.L

local UI = ns.OptionsUI
local C = UI.colors

local W, PAD, HEAD, FOOT = 520, 18, 40, 48
local INNER = W - 2 * PAD
local CARD_GAP = 8
local STEPS = 2

local frame, stepText, title, intro, body, back, nextButton
local step, answers, finished
local views = {}        -- per step: { frame, Refresh() }

-- The answers to start from: what is set now, every Immersion switch on.
local function Fresh()
    local a = { console = ns.db.consoleProfile, immersion = {} }
    for _, key in ipairs(ns.SETUP_IMMERSION) do a.immersion[key] = true end
    return a
end

-- ------------------------------------------------------------ a card
-- A choice as a card: its name and what it is; the chosen one lit, a gold
-- bar down its left (the settings window's card on); one that cannot be
-- chosen dimmed.
local function Card(parent, pick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(INNER)
    b.bg = UI.Fill(b, "BACKGROUND", C.raised, 1)
    b.bg:SetAllPoints()
    b.edge = UI.Outline(b, "BORDER", C.line, 0)
    b.bar = UI.Fill(b, "ARTWORK", C.gold)
    b.bar:SetPoint("TOPLEFT", 0, 0)
    b.bar:SetPoint("BOTTOMLEFT", 0, 0)
    b.bar:SetWidth(2)
    b.name = UI.Serif(b, 14, C.text)
    b.name:SetPoint("TOPLEFT", 14, -10)
    b.name:SetWidth(INNER - 28)
    b.name:SetJustifyH("LEFT")
    b.text = UI.Plain(b, 11, C.dim)
    b.text:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
    b.text:SetWidth(INNER - 28)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(true)
    b:SetScript("OnClick", function(self) if not self.wip then pick(self.id) end end)
    b:SetScript("OnEnter", function(self) if not self.wip and not self.on then UI.Paint(self.bg, C.hover) end end)
    b:SetScript("OnLeave", function(self) self:Show_(self.on) end)
    function b:Set(id, name, text, wip)
        self.id, self.wip = id, wip and true or nil
        self.name:SetText(name)
        self.text:SetText(text or "")
        self:SetHeight(10 + math.ceil(self.name:GetStringHeight() or 0) + 4
            + math.ceil(self.text:GetStringHeight() or 0) + 12)
        self:SetAlpha(self.wip and 0.45 or 1)
    end
    function b:Show_(on)
        self.on = on and true or nil
        UI.Paint(self.bg, on and C.selected or C.raised)
        UI.Paint(self.edge, on and C.goldDark or C.line)
        self.bar:SetShown(on and true or false)
        local c = on and C.goldBright or C.text
        self.name:SetTextColor(c[1], c[2], c[3])
    end
    return b
end

-- Cards stacked from the top of a step, as many as its choices.
local function Stack(view, list, chosen)
    view.cards = view.cards or {}
    local y = 0
    for i, choice in ipairs(list) do
        local card = view.cards[i] or Card(view.frame, view.pick)
        view.cards[i] = card
        card:Set(choice[1], choice[2], choice[3], choice.wip)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 0, -y)
        card:Show_(choice[1] == chosen)
        card:Show()
        y = y + card:GetHeight() + CARD_GAP
    end
    for i = #list + 1, #view.cards do view.cards[i]:Hide() end
    return y
end

-- ------------------------------------------------------------ the steps
local STEP = {
    {
        title = Tr["Choose your console"],
        intro = Tr["The console the pages under Console start from. Every character on this account shares it; "
            .. "you can switch later under Console > General."],
        Build = function(view)
            view.pick = function(id)
                answers.console = id
                view.Refresh()
            end
        end,
        Refresh = function(view) return Stack(view, ns.PROFILE_NAMES, answers.console) end,
    },
    {
        title = Tr["Immersion Mode"],
        intro = Tr["Parts that fade out of the way when you are not fighting or using them. Each can be shaped "
            .. "later under Shared > Visibility & fading."],
        Build = function(view)
            local rows = {
                consoleMinimal = { Tr["Console: Minimal OoC Mode"],
                    Tr["Out of combat, the console fades away but for your player and target frames."] },
                chatImmersion = { Tr["Chat: bare when idle"],
                    Tr["The chat's box hides while it is idle, its lines left on the screen; it comes back on use."] },
                sideImmersion = { Tr["Side panel: faded when idle"],
                    Tr["The side panel's background fades while it is idle; its text and buttons stay whole."] },
                groupMinimal = { Tr["Group frames: Minimal OoC Mode"],
                    Tr["Out of combat, the party and raid boxes fade away."] },
                cdmMinimal = { Tr["Cooldown Manager: Minimal OoC Mode"],
                    Tr["Out of combat, every Cooldown Manager viewer fades away: cooldowns, buffs and bars."] },
            }
            view.checks = {}
            for _, key in ipairs(ns.SETUP_IMMERSION) do
                local spec = {
                    kind = "check", key = key, label = rows[key][1], tip = rows[key][2],
                    get = function() return answers.immersion[key] end,
                    set = function(on)
                        answers.immersion[key] = on and true or false
                        view.Refresh()
                    end,
                }
                local check = UI.Check(view.frame, spec, INNER, true)
                check.key = key
                table.insert(view.checks, check)
            end
        end,
        Refresh = function(view)
            local y = 0
            for _, check in ipairs(view.checks) do
                -- the console's Minimal OoC Mode is the Reticule's
                local shown = check.key ~= "consoleMinimal" or answers.console == "reticule"
                check:SetShown(shown)
                if shown then
                    check:ClearAllPoints()
                    check:SetPoint("TOPLEFT", 0, -y)
                    check:Refresh(true)
                    y = y + check:GetHeight() + 4
                end
            end
            return y
        end,
    },
}

-- ------------------------------------------------------------ the window
local function Close()
    frame:Hide()
end

local function Show(n)
    step = n
    for i, view in ipairs(views) do view.frame:SetShown(i == n) end
    local s = STEP[n]
    stepText:SetText(format(Tr["Setup · %d of %d"], n, STEPS))
    title:SetText(s.title)
    intro:SetText(s.intro)
    local h = views[n].Refresh()
    views[n].frame:SetHeight(math.max(1, h))
    body:SetHeight(math.max(1, h))
    local introH = math.ceil(intro:GetStringHeight() or 0)
    frame:SetHeight(HEAD + 16 + 20 + 6 + introH + 14 + h + 8 + FOOT)
    back:Refresh(n > 1)
    nextButton.text:SetText(n == STEPS and Tr["Finish"] or Tr["Next"])
end

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "MedalUISetup", UIParent)
    -- hidden before its OnHide is set: that marks the character set up
    frame:Hide()
    frame:SetWidth(W)
    frame:SetPoint("CENTER", 0, 60)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    -- the settings window's: the page's tone, a hairline edge, a faint gold
    -- ring outside it
    UI.Fill(frame, "BACKGROUND", C.page, 1):SetAllPoints()
    UI.Outline(frame, "BORDER", C.lineStrong, 0)
    UI.Outline(frame, "BORDER", { C.gold[1], C.gold[2], C.gold[3], 0.35 }, -1)
    -- Esc closes it, as the game's own windows
    if UISpecialFrames then table.insert(UISpecialFrames, "MedalUISetup") end
    -- however it closes, this character has been through it
    frame:SetScript("OnHide", function()
        if not finished then ns.SetupDone() end
    end)

    -- the head, as the settings window's: its name, the step; a cross red
    -- under the pointer
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(HEAD)
    UI.Fill(head, "BACKGROUND", C.chrome, 1):SetAllPoints()
    local rule = UI.Fill(head, "BORDER", C.line)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    local name = UI.Serif(head, 15, C.goldBright)
    name:SetPoint("LEFT", 14, 0)
    name:SetText("MedalUI")
    stepText = UI.Plain(head, 11, C.faint)
    stepText:SetPoint("LEFT", name, "RIGHT", 10, -1)
    local x = CreateFrame("Button", nil, head)
    x:SetSize(HEAD, HEAD - 1)
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
    x:SetScript("OnClick", Close)
    x:SetScript("OnEnter", function(self)
        lit:Show()
        self.glyph:SetVertexColor(0.949, 0.847, 0.784, 1)
    end)
    x:SetScript("OnLeave", function(self)
        lit:Hide()
        self.glyph:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
    end)
    frame.closeX = x

    title = UI.Serif(frame, 18, C.text)
    title:SetPoint("TOPLEFT", PAD, -(HEAD + 16))
    intro = UI.Plain(frame, 12, C.dim)
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    intro:SetWidth(INNER)
    intro:SetJustifyH("LEFT")
    intro:SetWordWrap(true)
    body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
    body:SetWidth(INNER)

    -- the footer, as the settings window's
    local foot = UI.Fill(frame, "BACKGROUND", C.chrome, 2)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOT)
    local footRule = UI.Fill(frame, "BORDER", C.line)
    footRule:SetHeight(1)
    footRule:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 0)
    footRule:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 0)
    local skip = UI.Button(frame, Tr["Skip"], 70, 26, Close,
        Tr["Leave everything as it is. /mdlui setup brings this back."], "quiet")
    skip:SetPoint("BOTTOMLEFT", PAD - 6, 11)
    nextButton = UI.Button(frame, Tr["Next"], 90, 26, function()
        if step < STEPS then
            Show(step + 1)
            return
        end
        finished = true
        frame:Hide()
        ns.ApplySetup(answers)
    end, nil, "primary")
    nextButton:SetPoint("BOTTOMRIGHT", -PAD, 11)
    back = UI.Button(frame, Tr["Back"], 80, 26, function()
        if step > 1 then Show(step - 1) end
    end)
    back:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
    frame.skip, frame.back, frame.next = skip, back, nextButton

    for i, s in ipairs(STEP) do
        local view = { frame = CreateFrame("Frame", nil, body) }
        view.frame:SetPoint("TOPLEFT", 0, 0)
        view.frame:SetWidth(INNER)
        view.Refresh = function()
            local h = s.Refresh(view)
            if step == i then
                view.frame:SetHeight(math.max(1, h))
            end
            return h
        end
        s.Build(view)
        views[i] = view
    end
end

-- ns.OpenSetup(): the wizard on its first step, its answers what is set now.
function ns.OpenSetup()
    if InCombatLockdown() then
        ns.OutOfCombat(ns.OpenSetup)
        return
    end
    Build()
    answers, finished = Fresh(), nil
    Show(1)
    frame:Show()
    frame:Raise()
end

-- The window and the step shown, while it is (the harness's way in).
function ns.SetupShown()
    return frame and frame:IsShown() and step or nil
end
function ns.SetupFrame() return frame, views end

-- At a new character's first login, once the game has settled and after the
-- known-issues dialog, which reloads when it fixes.
local function Offer()
    if not ns.SetupOwed() then return end
    if StaticPopup_Visible and StaticPopup_Visible("MEDALUI_FIX_ISSUES") then
        C_Timer.After(2, Offer)
        return
    end
    ns.OpenSetup()
end
ns.On("PLAYER_ENTERING_WORLD", function(_, initial, reloading)
    if not (initial or reloading) or not ns.SetupOwed() then return end
    if C_Timer and C_Timer.After then C_Timer.After(2, Offer) else Offer() end
end)
