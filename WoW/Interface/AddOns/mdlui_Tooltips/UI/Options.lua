-- The game's AddOns list entry: a line and a button opening the mdlui_Tooltips window (UI/Editor.lua),
-- which holds every setting. The shared API lives in Core/Settings.lua.
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
