local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CANVAS
-- The Wheel card's well (UI/Window.lua, Radial/Editor.lua): the chosen radial's wheel drawn large by
-- the radial's own layout code (RM.DrawEditorWheel), one slot per button, the chosen slot lit as the
-- wheel lights the one you point at in play (its rim, its slice, the pointer, its name in gold). A
-- line under it says what the pointer does. The editor (Radial/Editor.lua) is told what happens to a
-- slot:
--   cb.choose(i)        a left click         cb.remove(i)       a right click
--   cb.drop(i)          the game cursor let go on it (i nil: the empty slot)
--   cb.startDrag(i)     cb.finishDrag()      a drag from a slot, and its end anywhere
--   cb.enter(hit)       the pointer on a slot (hit.index, hit.ghost)
-- canvas:Draw(st) draws it again; canvas:SlotUnderMouse() answers the slot under the pointer.
--------------------------------------------------
local Panel = ns.SettingsPanel
local C = ns.ui

local Canvas = {}
ns.RadialCanvas = Canvas

local FIT = 340          -- the wheel's diameter (buttons included) at most, so the names fit round it
local TOP_LINE, FOOT_LINE = 8, 24

local function RM() return ns.RadialMenu end

-- The names round the editor's wheel: every slot named at once (the radial names only the one aimed
-- at), so smaller, without the editor's rank ("Searing Totem (Rank 4)": the chosen slot's card says
-- it), each in a box of its own on the button's outer side, wrapping to two lines. Only a slot
-- near straight up or down names itself above or below it; the rest at its side, so two lower
-- slots don't share the space under the wheel.
local LABEL_SIZE, LABEL_W, LABEL_W_WIDE, LABEL_GAP = 13, 92, 130, 5
local UPRIGHT = math.pi / 12        -- within this of straight up or down: above or below (less than
                                    -- half the gap between twelve slots, so two never share it)
local function CanvasLabel(b, text)
    local label = b.Label
    local face, _, flags = label:GetFont()
    if face then label:SetFont(face, LABEL_SIZE, flags or "") end
    text = (text or ""):gsub(" %([^()]*%d[^()]*%)$", "")
    label:SetText(text)
    label:SetWordWrap(true)
    if label.SetMaxLines then label:SetMaxLines(2) end
    local a = math.atan2(b.baseY or 0, b.baseX or 0)
    label:ClearAllPoints()
    if math.abs(a - math.pi / 2) <= UPRIGHT then
        label:SetWidth(LABEL_W_WIDE)
        label:SetPoint("BOTTOM", b, "TOP", 0, LABEL_GAP)
        label:SetJustifyH("CENTER")
    elseif math.abs(a + math.pi / 2) <= UPRIGHT then
        label:SetWidth(LABEL_W_WIDE)
        label:SetPoint("TOP", b, "BOTTOM", 0, -LABEL_GAP)
        label:SetJustifyH("CENTER")
    elseif math.abs(a) > math.pi / 2 then
        label:SetWidth(LABEL_W)
        label:SetPoint("RIGHT", b, "LEFT", -LABEL_GAP, 0)
        label:SetJustifyH("RIGHT")
    else
        label:SetWidth(LABEL_W)
        label:SetPoint("LEFT", b, "RIGHT", LABEL_GAP, 0)
        label:SetJustifyH("LEFT")
    end
end

function Canvas.Create(stage, cb)
    local canvas = { stage = stage, hits = {} }
    local fill = Panel.Fill(stage, "BACKGROUND", C.well, 1)
    fill:SetAllPoints()
    Panel.Outline(stage, "BORDER", C.line, 0)
    stage:SetClipsChildren(true)

    canvas.hint = Panel.Plain(stage, 11, C.faint)
    canvas.hint:SetPoint("BOTTOMLEFT", 10, 9)
    canvas.hint:SetPoint("BOTTOMRIGHT", -10, 9)
    canvas.hint:SetJustifyH("CENTER")

    -- no radial at all
    canvas.emptyTitle = Panel.Plain(stage, 12, C.dim)
    canvas.emptyTitle:SetPoint("CENTER", 0, 10)
    canvas.emptyTitle:SetJustifyH("CENTER")
    canvas.emptyTitle:SetText(L["No radials yet."])
    canvas.emptyText = Panel.Plain(stage, 11, C.faint)
    canvas.emptyText:SetPoint("TOP", canvas.emptyTitle, "BOTTOM", 0, -6)
    canvas.emptyText:SetJustifyH("CENTER")
    canvas.emptyText:SetText(L["Create one with + New radial, below."])
    canvas.emptyText:SetTextColor(C.faint[1], C.faint[2], C.faint[3])

    -- the wheel: a sample's (the radial's art, its backdrop left out), over the hint
    local holder = RM().CreateSample(stage)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", 0, -TOP_LINE)
    holder:SetPoint("BOTTOMRIGHT", 0, FOOT_LINE)
    canvas.holder, canvas.wheel = holder, holder.wheel

    canvas.cb = cb
    return setmetatable(canvas, { __index = Canvas })
end

-- a slot's hit area: a button over the radial's own (which takes no mouse), with its number
function Canvas:Hit(i)
    local hit = self.hits[i]
    if hit then return hit end
    local cb, wheel = self.cb, self.wheel
    local size = RM().ROUND_SIZE
    hit = CreateFrame("Button", nil, wheel)
    hit:SetSize(size, size)
    hit:SetFrameLevel(wheel:GetFrameLevel() + 20)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnClick", function(h, mouse)
        if h.ghost then
            cb.drop(nil)
        elseif mouse == "RightButton" then
            cb.remove(h.index)
        else
            cb.choose(h.index)
        end
    end)
    hit:SetScript("OnReceiveDrag", function(h) cb.drop(not h.ghost and h.index or nil) end)
    hit:SetScript("OnDragStart", function(h)
        if h.ghost then return end
        GameTooltip:Hide()
        cb.startDrag(h.index)
    end)
    hit:SetScript("OnDragStop", function() cb.finishDrag() end)
    hit:SetScript("OnEnter", function(h) cb.enter(h) end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- the empty slot: a faint rim and a plus
    local style = RM().RoundStyle and RM().RoundStyle()
    hit.ghostRim = hit:CreateTexture(nil, "ARTWORK")
    hit.ghostRim:SetAllPoints()
    if style then hit.ghostRim:SetTexture(style.idle) end
    hit.ghostRim:SetAlpha(0.45)
    hit.plus = Panel.Serif(hit, 22, C.goldDark)
    hit.plus:SetPoint("CENTER", 0, 1)
    hit.plus:SetText("+")
    -- Numbers: the slot's place, at its top right
    hit.badge = CreateFrame("Frame", nil, hit)
    hit.badge:SetSize(15, 15)
    hit.badge:SetPoint("CENTER", hit, "TOPRIGHT", -6, -6)
    local disc = Panel.Fill(hit.badge, "BACKGROUND", C.ink, 1)
    disc:SetAllPoints()
    Panel.Outline(hit.badge, "BORDER", C.goldDark, 0)
    hit.badge.text = Panel.Plain(hit.badge, 9, C.goldBright)
    hit.badge.text:SetPoint("CENTER", 0, 0)
    hit.badge.text:SetJustifyH("CENTER")
    self.hits[i] = hit
    return hit
end

-- st: entries ({ name, icon } per button; nil: no radial), chosen, hint, and the
-- footer's chips: names (every slot's name, not only the chosen one's), numbers, empty (the next
-- free slot, a drop target; always while the radial has no buttons)
function Canvas:Draw(st)
    local none = st.entries == nil
    self.emptyTitle:SetShown(none)
    self.emptyText:SetShown(none)
    self.holder:SetShown(not none)
    self.hint:SetShown(not none)
    if none then
        for _, hit in ipairs(self.hits) do hit:Hide() end
        self.drawn = 0
        return
    end
    local rm = RM()
    local entries = {}
    for i, e in ipairs(st.entries) do entries[i] = e end
    local n = #entries
    local ghost = n < rm.MAX_BUTTONS and (st.empty or n == 0)
    if ghost then entries[n + 1] = { name = "", icon = nil } end
    local chosen = st.chosen and st.chosen <= n and st.chosen or nil
    local wheel = self.wheel
    local count, radius = rm.DrawEditorWheel(wheel, entries, chosen)
    wheel:SetScale(math.min(1, FIT / ((radius + rm.ICON_SIZE) * 2)))

    for i = 1, count do
        local b = wheel.buttons[i]
        local isGhost = ghost and i == count
        -- the empty slot draws no button of the radial's: its hit area draws it
        b.Icon:SetShown(not isGhost)
        b.RimArt:SetShown(not isGhost)
        b.Rim:SetShown(not isGhost)
        if isGhost then b.RimGlow:Hide() end
        if not isGhost then CanvasLabel(b, st.entries[i] and st.entries[i].name) end
        local named = (b.Label:GetText() or "") ~= ""
        b.Label:SetShown(not isGhost and named and (st.names or i == chosen))
        local c = i == chosen and C.goldBright or C.text
        b.Label:SetTextColor(c[1], c[2], c[3])

        local hit = self:Hit(i)
        hit.index, hit.ghost = i, isGhost or nil
        hit.entry = not isGhost and st.entries[i] or nil
        hit:ClearAllPoints()
        hit:SetPoint("CENTER", wheel, "CENTER", b.baseX, b.baseY)
        hit.ghostRim:SetShown(isGhost)
        hit.plus:SetShown(isGhost)
        hit.badge:SetShown(st.numbers and not isGhost and true or false)
        hit.badge.text:SetText(tostring(i))
        hit:Show()
    end
    for i = count + 1, #self.hits do self.hits[i]:Hide() end
    self.drawn = count
    self.hint:SetText(st.hint or "")
end

-- the slot under the pointer: its index (the empty slot's is one past the last button) and whether
-- it is the empty slot
function Canvas:SlotUnderMouse()
    for i = 1, self.drawn or 0 do
        local hit = self.hits[i]
        if hit and hit:IsShown() and hit:IsMouseOver() then return hit.index, hit.ghost end
    end
end
