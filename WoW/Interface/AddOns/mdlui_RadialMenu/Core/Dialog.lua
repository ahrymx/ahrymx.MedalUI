local _, ns = ...

--------------------------------------------------
-- DIALOG
-- Forked from FlareUI's Dialog.lua (by Malkkav, MIT) without its reload and macro buttons.
-- Yes / no questions in place of StaticPopups, which hang the client in the Gamepad UI when shown
-- from addon code. Reads the pad itself: bottom face button yes, right face button no.
--------------------------------------------------
-- ns.Dialogs[key] fields:
--   text                  "%s" takes ns.ShowDialog's textArg
--   button1, button2      yes / no labels (button2 optional)
--   button3, OnAlt(data)  an optional third answer after the two (11-13)
--   OnAccept(data, text)  on yes; text is the edit box's
--   OnCancel(data)        on no, Escape or the right face button
--   hasEditBox, maxLetters, editText(data)
--   hideOnEscape          Escape and the right face button answer no
--   showAlert             exclamation mark beside the text
--   padInput              reads the controller outside the Gamepad UI too
ns.Dialogs = ns.Dialogs or {}

--------------------------------------------------
-- 1. ANSWERS
--------------------------------------------------
local WIDTH     = 360
local PADDING   = 18
local BUTTON_W  = 130
local BUTTON_H  = 24
local BUTTON_GAP = 12

local frame, current, currentData

-- a button as wide as its text needs, never narrower than minWidth
local function ButtonWidthForText(button, minWidth)
    local text = button:GetFontString()
    local width = text and text:GetUnboundedStringWidth() or 0
    return math.max(minWidth, math.ceil(width) + 24)
end

local function PadLabel(key, label, padInput)
    -- in the gamepad UI a pad button's binding text is its glyph
    if not (ns.IsGamepadUI() or padInput) then return label end
    local glyph = GetBindingText(key, 1)
    if not glyph or glyph == "" or glyph == key then return label end
    return glyph .. " " .. label
end

local function Close()
    if frame then frame:Hide() end
end

-- the third button: its own answer, no reload
local function AnswerAlt()
    local def, data = current, currentData
    current, currentData = nil, nil
    Close()
    ns.ButtonSound()
    if def and def.OnAlt then def.OnAlt(data) end
end

local function Answer(yes)
    local def, data = current, currentData
    if not def then return Close() end
    local text = def.hasEditBox and frame.EditBox:GetText() or nil
    current, currentData = nil, nil
    Close()
    ns.ButtonSound()
    if yes then
        if def.OnAccept then def.OnAccept(data, text) end
    elseif def.OnCancel then
        def.OnCancel(data)
    end
end

--------------------------------------------------
-- 3. KEYS AND CONTROLLER
--------------------------------------------------
-- Escape and Enter are taken, other keys propagate. Propagation can't change in combat, where only
-- the buttons work.
local function OnKeyDown(self, key)
    -- in a fight the keys also reach the game (propagation is locked on): only the buttons answer
    if InCombatLockdown() and self:GetPropagateKeyboardInput() then return end
    local handled = (key == "ESCAPE" and current and current.hideOnEscape) or key == "ENTER"
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
    if key == "ESCAPE" and handled then
        Answer(false)
    elseif key == "ENTER" and handled then
        Answer(true)
    end
end

local PAD_YES = GAMEPAD_FACE_BOTTOM or "PAD1"
local PAD_NO  = GAMEPAD_FACE_RIGHT or "PAD2"

local function OnGamePadButtonDown(self, button)
    local yes = button == PAD_YES
    local no = button == PAD_NO and current and (current.hideOnEscape or current.button2)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not (yes or no)) end
    if yes then
        Answer(true)
    elseif no then
        Answer(false)
    end
end

--------------------------------------------------
-- 4. THE WINDOW
--------------------------------------------------
local function CreateDialogButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_W, BUTTON_H)
    if ns.SkinButton then ns.SkinButton(button) end
    button:SetScript("OnClick", onClick)
    return button
end

local function Build()
    frame = CreateFrame("Frame", "mdluiRadialDialog", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
    frame:Hide()
    -- keep Blizzard's gamepad cursor out: a pad click would run addon code inside its navigation
    frame.smartNavigationIgnored = true

    frame.Alert = frame:CreateTexture(nil, "ARTWORK")
    frame.Alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    frame.Alert:SetSize(32, 32)
    frame.Alert:SetPoint("TOPLEFT", PADDING, -PADDING + 4)

    frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.Text:SetJustifyH("CENTER")
    frame.Text:SetSpacing(2)

    frame.EditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.EditBox:SetSize(WIDTH - 2 * PADDING - 10, 22)
    frame.EditBox:SetAutoFocus(false)
    frame.EditBox:SetScript("OnEnterPressed", function() Answer(true) end)
    frame.EditBox:SetScript("OnEscapePressed", function() Answer(false) end)

    frame.Button1 = CreateDialogButton(frame, function() Answer(true) end)
    frame.Button2 = CreateDialogButton(frame, function() Answer(false) end)
    frame.Button3 = CreateDialogButton(frame, AnswerAlt)

    frame:SetScript("OnKeyDown", OnKeyDown)
    frame:SetScript("OnGamePadButtonDown", OnGamePadButtonDown)
    frame:SetScript("OnShow", function() ns.WindowOpenSound() end)
    frame:SetScript("OnHide", function(self)
        self.EditBox:ClearFocus()
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        if current then
            -- hidden from outside: no answer, no callback
            current, currentData = nil, nil
        end
    end)
end

local function Layout(def, text)
    frame.Button1:SetText(PadLabel(PAD_YES, def.button1 or OKAY or "Okay", def.padInput))
    local yesWidth = ButtonWidthForText(frame.Button1, BUTTON_W)
    frame.Button1:SetWidth(yesWidth)
    local secondButtonSpace = 0
    if def.button2 then
        frame.Button2:SetText(PadLabel(PAD_NO, def.button2, def.padInput))
        local noWidth = ButtonWidthForText(frame.Button2, BUTTON_W)
        frame.Button2:SetWidth(noWidth)
        secondButtonSpace = BUTTON_GAP + noWidth
    end
    if def.button3 then
        frame.Button3:SetText(def.button3)
        local altWidth = ButtonWidthForText(frame.Button3, BUTTON_W)
        frame.Button3:SetWidth(altWidth)
        secondButtonSpace = secondButtonSpace + BUTTON_GAP + altWidth
    end

    local alertOffset = def.showAlert and 20 or 0
    local sideSpace = 2 * (PADDING + alertOffset)
    local width = math.max(WIDTH, sideSpace + yesWidth + secondButtonSpace)
    frame:SetWidth(width)
    frame.Alert:SetShown(def.showAlert and true or false)
    frame.Text:ClearAllPoints()
    frame.Text:SetPoint("TOP", frame, "TOP", alertOffset, -PADDING)
    frame.Text:SetWidth(width - sideSpace)
    frame.Text:SetText(text)

    local height = PADDING + frame.Text:GetStringHeight()
    if def.hasEditBox then
        frame.EditBox:ClearAllPoints()
        frame.EditBox:SetPoint("TOP", frame.Text, "BOTTOM", 0, -12)
        frame.EditBox:Show()
        height = height + 12 + frame.EditBox:GetHeight()
    else
        frame.EditBox:Hide()
    end

    frame.Button1:Show()
    frame.Button1:ClearAllPoints()
    frame.Button1:SetPoint("TOP", frame, "TOP", alertOffset - secondButtonSpace / 2, -height - 16)
    if def.button2 then
        frame.Button2:Show()
        frame.Button2:ClearAllPoints()
        frame.Button2:SetPoint("LEFT", frame.Button1, "RIGHT", BUTTON_GAP, 0)
    else
        frame.Button2:Hide()
    end
    if def.button3 then
        frame.Button3:Show()
        frame.Button3:ClearAllPoints()
        frame.Button3:SetPoint("LEFT", def.button2 and frame.Button2 or frame.Button1, "RIGHT", BUTTON_GAP, 0)
    else
        frame.Button3:Hide()
    end
    frame:SetHeight(height + 16 + BUTTON_H + PADDING)
end

--------------------------------------------------
-- 5. SHOWING
--------------------------------------------------
-- textArg fills "%s"; data is passed to OnAccept / OnCancel
function ns.ShowDialog(key, textArg, data)
    local def = ns.Dialogs[key]
    if not def then return end
    if not frame then Build() end
    current, currentData = def, data
    local text = def.text or ""
    if textArg ~= nil then text = text:format(textArg) end
    Layout(def, text)

    -- propagation is locked in combat: a dialog that would not pass keys on takes none (buttons still work)
    if InCombatLockdown() then
        frame:EnableKeyboard(frame:GetPropagateKeyboardInput())
    else
        frame:EnableKeyboard(true)
        frame:SetPropagateKeyboardInput(true)
    end
    frame:EnableGamePadButton(ns.IsGamepadUI() or def.padInput == true)

    if def.hasEditBox then
        frame.EditBox:SetMaxLetters(def.maxLetters or 0)
        frame.EditBox:SetText(def.editText and def.editText(data) or "")
    end
    frame:Show()
    frame:Raise()
    if def.hasEditBox then
        frame.EditBox:SetFocus()
        frame.EditBox:HighlightText()
    end
end

function ns.AnyDialogShown()
    return frame ~= nil and frame:IsShown()
end
