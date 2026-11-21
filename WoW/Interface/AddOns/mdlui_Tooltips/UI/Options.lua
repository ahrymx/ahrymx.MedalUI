-- The game's AddOns list entry: a line and a button opening the mdlui_Tooltips window (UI/Editor.lua),
-- which holds every setting, and the minimap button's switch (UI/MinimapButton.lua; off at first).
-- The shared API lives in Core/Settings.lua.
local _, ns = ...
local L = ns.L

local page, category
ns.Options = {}

-- Called by the entry file after saved settings arrive.
function ns.Options.register()
    if page then return end
    page = CreateFrame("Frame")
    page.name = "mdlui_Tooltips"
    -- Created hidden, or the settings window never fires OnShow on first open.
    page:Hide()
    local pageTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 16, -16)
    pageTitle:SetText("mdlui_Tooltips")
    local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
    subtitle:SetText(L["A full reskin of tooltips. Changes apply the next time a tooltip opens."])

    local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    editorButton:SetSize(200, 24)
    editorButton:SetPoint("TOPLEFT", 16, -64)
    editorButton:SetText(L["Open mdlui_Tooltips"])
    local line = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    line:SetPoint("TOPLEFT", editorButton, "BOTTOMLEFT", 0, -12)
    line:SetWidth(520)
    line:SetJustifyH("LEFT")
    line:SetText(L["Every setting is in the mdlui_Tooltips window: the look of each kind of tooltip, with a live "
        .. "sample, and the options. Also /mdltip, and /mdltip options."])
    -- Opens over the settings window, which is left as it is: closing it from
    -- here would run its code under the addon's taint.
    editorButton:SetScript("OnClick", function()
        if ns.openEditor then ns.openEditor() end
    end)

    -- the minimap button: a click opens the window (the right button, on its Options), a drag moves it
    local minimap = ns.MinimapButton{
        name = "mdlui_TooltipsMinimapButton", icon = "Interface\\AddOns\\mdlui_Tooltips\\art\\logo",
        title = "mdlui_Tooltips",
        tip = { L["Click: the mdlui_Tooltips window."], L["Right-click: its options."],
            L["Drag: move round the minimap."] },
        Click = function(mouse)
            local window = _G.mdlui_TooltipsEditor
            if mouse ~= "RightButton" and window and window:IsShown() then
                window:Hide()
            elseif ns.openEditor then
                ns.openEditor(mouse == "RightButton" and "options" or nil)
            end
        end,
        Shown = function() return ns.option("minimapButton") and true or false end,
        Angle = function() return tonumber(ns.option("minimapAngle")) or 200 end,
        SetAngle = function(angle) ns.setOption("minimapAngle", angle) end,
    }
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", line, "BOTTOMLEFT", -4, -16)
    local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    label:SetText(L["Minimap button"])
    local note = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    note:SetWidth(480)
    note:SetJustifyH("LEFT")
    note:SetText(L["A button on the minimap's edge: a click opens the mdlui_Tooltips window. Drag it to move it. "
        .. "With MedalUI, it is in the action bar's minimap drawer instead."])
    check:SetScript("OnShow", function(self) self:SetChecked(ns.option("minimapButton") and true or false) end)
    check:SetScript("OnClick", function(self)
        -- off is the default, kept as nothing saved
        ns.setOption("minimapButton", self:GetChecked() and true or nil)
        minimap.Update()
    end)
    ns.Options.check, ns.minimapButton = check, minimap

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(page, page.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
end

-- The window's Options page; the game's AddOns page when the window is missing (a client
-- without the editor's pieces). True when something opened.
function ns.openSettings()
    if ns.openEditor then
        ns.openEditor("options")
        return true
    end
    if InCombatLockdown() then
        print(L["mdlui_Tooltips: the options cannot open during combat. Try again once it ends."])
        return false
    end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
    return true
end
