-- The game's AddOns list entry: a line and a button opening the editor (UI/Window.lua), which
-- holds every radial and setting, and the minimap button's switch (UI/MinimapButton.lua; off at
-- first). Registered at login, once the saved settings are read (Core/DB.lua).
local _, ns = ...
local L = ns.L

local page, category
ns.Options = {}

local function DB() return ns.db and ns.db.profile.radialmenu or {} end

function ns.Options.register()
    if page then return end
    page = CreateFrame("Frame")
    page.name = "mdlui_RadialMenu"
    -- Created hidden, or the settings window never fires OnShow on first open.
    page:Hide()
    local pageTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 16, -16)
    pageTitle:SetText("mdlui_RadialMenu")
    local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
    subtitle:SetText(L["Hold a key, sweep the mouse towards a button and let go."])

    local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    editorButton:SetSize(200, 24)
    editorButton:SetPoint("TOPLEFT", 16, -64)
    editorButton:SetText(L["Open radial editor"])
    local line = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    line:SetPoint("TOPLEFT", editorButton, "BOTTOMLEFT", 0, -12)
    line:SetWidth(520)
    line:SetJustifyH("LEFT")
    line:SetText(L["Every radial and setting is in the editor: its radials, their buttons and keys, and how "
        .. "a radial opens and looks. Also /mdlradial, and /mdlradial options."])
    -- Opens over the settings window, which is left as it is: closing it from
    -- here would run its code under the addon's taint.
    editorButton:SetScript("OnClick", function() ns.OpenEditor() end)

    -- the minimap button: a click opens or closes the editor (the right button, on its Options),
    -- a drag moves it
    local minimap = ns.MinimapButton{
        name = "mdlui_RadialMenuMinimapButton", icon = "Interface\\AddOns\\mdlui_RadialMenu\\art\\logo",
        title = "mdlui_RadialMenu",
        tip = { L["Click: the radial editor."], L["Right-click: its options."],
            L["Drag: move round the minimap."] },
        Click = function(mouse)
            if mouse == "RightButton" then ns.OpenEditor("options") else ns.ToggleEditor() end
        end,
        Shown = function() return DB().minimapButton and true or false end,
        Angle = function() return tonumber(DB().minimapAngle) or 225 end,
        SetAngle = function(angle) DB().minimapAngle = angle end,
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
    note:SetText(L["A button on the minimap's edge: a click opens the radial editor. Drag it to move it. "
        .. "With MedalUI, it is in the action bar's minimap drawer instead."])
    check:SetScript("OnShow", function(self) self:SetChecked(DB().minimapButton and true or false) end)
    check:SetScript("OnClick", function(self)
        DB().minimapButton = self:GetChecked() and true or false
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
