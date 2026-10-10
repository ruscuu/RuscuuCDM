-- Ruscuu Cooldown Manager Forever: panel de opciones (Esc > Opciones > AddOns > Ruscuu CDM)
local _, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local PURPLE = { 0.61, 0.30, 1.00 }

-- Cada control registra cómo releer su valor, para refrescarlo al cambiar de perfil
local refreshers = {}

function ns.RefreshOptions()
    for _, refresh in ipairs(refreshers) do refresh() end
end

local function NewPanel()
    local panel = CreateFrame("Frame")
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end
    return panel
end

local function Label(parent, text, template, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Note(parent, text, x, y)
    local fs = Label(parent, text, "GameFontHighlightSmall", x, y)
    fs:SetTextColor(0.7, 0.7, 0.7)
    return fs
end

local function Checkbox(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self) set(self:GetChecked()) end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get()) end
    return cb
end

local function Button(parent, text, x, y, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Slider propio con el estilo Ruscuu (no depende de plantillas que cambian entre versiones)
local function Slider(parent, label, x, y, key, step, fmt, onChange)
    Label(parent, label, "GameFontNormal", x, y)
    local limits = ns.LIMITS[key]
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(220, 12)
    s:SetPoint("TOPLEFT", x, y - 20)
    s:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    s:SetBackdropColor(unpack(ns.COLORS.bg))
    s:SetBackdropBorderColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.6)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 18)
    thumb:SetVertexColor(unpack(PURPLE))
    s:SetMinMaxValues(limits[1], limits[2])
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouse(true)

    local value = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    value:SetPoint("LEFT", s, "RIGHT", 10, 0)

    local refreshing = false
    local function refresh()
        refreshing = true
        s:SetValue(ns.db[key])
        value:SetText(fmt:format(ns.db[key]))
        refreshing = false
    end
    refresh()
    refreshers[#refreshers + 1] = refresh

    s:SetScript("OnValueChanged", function(_, v)
        if refreshing then return end
        v = math.floor(v / step + 0.5) * step
        ns.db[key] = v
        value:SetText(fmt:format(v))
        if onChange then onChange() else ns.SkinAll() end
    end)
end

local function ColorSwatch(parent, label, x, y, key)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(22, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropBorderColor(1, 1, 1, 0.8)
    local fill = b:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)

    local text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", b, "RIGHT", 8, 0)
    text:SetText(label)

    local function refresh()
        local c = ns.db[key]
        fill:SetColorTexture(c[1], c[2], c[3])
    end
    refresh()
    refreshers[#refreshers + 1] = refresh

    local function apply(r, g, bl)
        local c = ns.db[key]
        c[1], c[2], c[3] = r, g, bl
        refresh()
        ns.SkinAll()
        ns.StyleActionBars()
    end

    b:SetScript("OnClick", function()
        local c = ns.db[key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c[1], g = c[2], b = c[3],
            hasOpacity = false,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(prev) apply(prev.r, prev.g, prev.b) end,
        })
    end)
end

-- Desplegable con las opciones que devuelve getOptions() ({ text, value })
local function Dropdown(parent, x, y, width, getOptions, getSelected, onSelect)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", x, y)
    dd:SetWidth(width)
    dd:SetupMenu(function(_, root)
        for _, option in ipairs(getOptions()) do
            root:CreateRadio(option.text,
                function() return getSelected() == option.value end,
                function() onSelect(option.value) end)
        end
    end)
    refreshers[#refreshers + 1] = function() dd:GenerateMenu() end
    return dd
end

local function ProfileOptions()
    local options = {}
    for _, name in ipairs(ns.GetProfileNames()) do
        options[#options + 1] = { text = name, value = name }
    end
    return options
end

------------------------------------------------------------------------
-- Página principal
------------------------------------------------------------------------

local function BuildMain(panel)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\RuscuuCDM\\Media\\logo")
    logo:SetSize(128, 128)
    logo:SetPoint("TOPLEFT", 16, -16)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 16, -36)
    title:SetText("|cff9b4dffRuscuu|r Cooldown Manager Forever")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(true)
    sub:SetText(L["Style for Blizzard's Cooldown Manager."] .. "\n|cffaaaaaa" .. L["Commands"]
        .. ": /ruscuu  ·  /ruscuu debug  ·  /ruscuu minimap  ·  /ruscuu reset|r")

    local y = -164
    Label(panel, L["Apply style to"], "GameFontNormalLarge", 16, y)
    y = y - 24
    for _, entry in ipairs(ns.VIEWERS) do
        Checkbox(panel, entry.label, 16, y,
            function() return ns.db.enabled[entry.key] end,
            function(checked)
                ns.db.enabled[entry.key] = checked
                if checked then
                    ns.SkinAll()
                else
                    ns.Print(L["Type /reload to restore Blizzard's style on that viewer."])
                end
            end)
        y = y - 28
    end

    y = y - 12
    Slider(panel, L["Border size"], 16, y, "borderSize", 1, "%d px")
    Slider(panel, L["Icon crop"], 340, y, "iconZoom", 0.01, "%.2f")
    y = y - 56
    Slider(panel, L["Cooldown text size"], 16, y, "fontSize", 1, "%d")

    y = y - 60
    ColorSwatch(panel, L["Border color"], 16, y, "borderColor")
    ColorSwatch(panel, L["Bar color"], 340, y, "barColor")

    y = y - 40
    Checkbox(panel, L["Show minimap button"], 16, y,
        function() return not ns.global.minimap.hide end,
        function(checked) ns.SetMinimapShown(checked) end)

    y = y - 40
    Label(panel, L["Cooldown numbers"], "GameFontNormalLarge", 16, y)
    y = y - 24
    Checkbox(panel, L["Show numbers on the Cooldown Manager"], 16, y,
        function() return ns.db.showNumbers end,
        function(checked)
            ns.db.showNumbers = checked
            ns.SkinAll()
        end)
    ColorSwatch(panel, L["Number color"], 340, y, "numberColor")
    y = y - 28
    Checkbox(panel, L["Show numbers on action bars"], 16, y,
        function() return ns.db.actionBarNumbers end,
        function(checked)
            ns.db.actionBarNumbers = checked
            ns.ApplyActionBarNumbers()
        end)
    Slider(panel, L["Action bar number size"], 340, y - 8, "actionBarFontSize", 1, "%d", ns.StyleActionBars)
    y = y - 28
    Checkbox(panel, L["Ruscuu style for action bar numbers"], 16, y,
        function() return ns.db.styleActionBarNumbers end,
        function(checked)
            ns.db.styleActionBarNumbers = checked
            if checked then
                ns.StyleActionBars()
            else
                ns.Print(L["Type /reload to restore Blizzard's numbers."])
            end
        end)
end

------------------------------------------------------------------------
-- Ventana para copiar o pegar el texto de importación/exportación
------------------------------------------------------------------------

local textPopup

local function GetTextPopup()
    if textPopup then return textPopup end
    local p = CreateFrame("Frame", "RuscuuCDMTextPopup", UIParent, "BackdropTemplate")
    p:SetSize(480, 260)
    p:SetPoint("CENTER")
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
    p:SetBackdropColor(0.05, 0.02, 0.09, 0.97)
    p:SetBackdropBorderColor(unpack(PURPLE))
    p:EnableMouse(true)
    p:SetMovable(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    tinsert(UISpecialFrames, "RuscuuCDMTextPopup") -- Esc la cierra

    p.title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    p.title:SetPoint("TOPLEFT", 16, -14)
    p.hint = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    p.hint:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -56)
    scroll:SetPoint("BOTTOMRIGHT", -34, 48)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(420)
    edit:SetScript("OnEscapePressed", function() p:Hide() end)
    scroll:SetScrollChild(edit)
    p.edit = edit

    p.action = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.action:SetSize(120, 24)
    p.action:SetPoint("BOTTOMRIGHT", -16, 14)

    textPopup = p
    return p
end

local function ShowExport()
    local p = GetTextPopup()
    p.title:SetText(L["Export profile"] .. ": " .. ns.activeProfile)
    p.hint:SetText(L["Press Ctrl+C to copy."])
    p.edit:SetText(ns.ExportProfile())
    p.action:SetText(L["Close"])
    p.action:SetScript("OnClick", function() p:Hide() end)
    p:Show()
    p.edit:SetFocus()
    p.edit:HighlightText()
end

local function ShowImport()
    local p = GetTextPopup()
    p.title:SetText(L["Import profile"] .. ": " .. ns.activeProfile)
    p.hint:SetText(L["Paste the text with Ctrl+V and press Import."])
    p.edit:SetText("")
    p.action:SetText(L["Import"])
    p.action:SetScript("OnClick", function()
        local ok, err = ns.ImportProfile(p.edit:GetText())
        if ok then
            ns.Print(L["Profile imported."])
            p:Hide()
        else
            ns.Print(err)
        end
    end)
    p:Show()
    p.edit:SetFocus()
end

------------------------------------------------------------------------
-- Diálogos para crear, borrar y restablecer perfiles
------------------------------------------------------------------------

local function PopupEditBox(dialog)
    return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end

local function AcceptNewProfile(dialog, copyFrom)
    local name = strtrim(PopupEditBox(dialog):GetText() or "")
    if name ~= "" then ns.CreateProfile(name, copyFrom) end
end

StaticPopupDialogs["RUSCUUCDM_NEW_PROFILE"] = {
    text = L["New profile name:"],
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, copyFrom) AcceptNewProfile(self, copyFrom) end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        AcceptNewProfile(dialog, dialog.data)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RUSCUUCDM_DELETE_PROFILE"] = {
    text = L["Delete profile \"%s\"?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name) ns.DeleteProfile(name) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RUSCUUCDM_RESET_PROFILE"] = {
    text = L["Reset profile \"%s\" to default values?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function() ns.ResetProfile() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

------------------------------------------------------------------------
-- Página de perfiles y temas
------------------------------------------------------------------------

local function BuildProfiles(panel)
    Label(panel, "|cff9b4dffRuscuu|r " .. L["Profiles & Themes"], "GameFontNormalHuge", 16, -16)

    local y = -60
    Label(panel, L["Themes"], "GameFontNormalLarge", 16, y)
    Note(panel, L["Themes change the colors and borders of the active profile."], 16, y - 20)
    y = y - 42
    for i, theme in ipairs(ns.THEMES) do
        Button(panel, theme.name, 16 + (i - 1) * 150, y, 140, function() ns.ApplyTheme(theme) end)
    end

    y = y - 50
    Label(panel, L["Profiles"], "GameFontNormalLarge", 16, y)
    y = y - 28
    Label(panel, L["Active profile"], "GameFontHighlight", 16, y - 4)
    Dropdown(panel, 140, y, 200, ProfileOptions,
        function() return ns.activeProfile end,
        function(name) ns.ChooseProfile(name) end)
    y = y - 36
    Button(panel, L["New"], 16, y, 110, function() StaticPopup_Show("RUSCUUCDM_NEW_PROFILE") end)
    Button(panel, L["Copy"], 132, y, 110, function()
        StaticPopup_Show("RUSCUUCDM_NEW_PROFILE", nil, nil, ns.activeProfile)
    end)
    Button(panel, L["Delete"], 248, y, 110, function()
        StaticPopup_Show("RUSCUUCDM_DELETE_PROFILE", ns.activeProfile, nil, ns.activeProfile)
    end)
    Button(panel, L["Reset"], 364, y, 110, function()
        StaticPopup_Show("RUSCUUCDM_RESET_PROFILE", ns.activeProfile)
    end)

    y = y - 50
    Label(panel, L["Profile per specialization"], "GameFontNormalLarge", 16, y)
    Note(panel, L["The profile changes automatically when you switch specialization."], 16, y - 20)
    y = y - 48
    for spec = 1, GetNumSpecializations() do
        local _, specName, _, icon = GetSpecializationInfo(spec)
        local tex = panel:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(icon)
        tex:SetSize(22, 22)
        tex:SetPoint("TOPLEFT", 16, y)
        Label(panel, specName, "GameFontHighlight", 46, y - 4)
        Dropdown(panel, 200, y, 200, ProfileOptions,
            function() return ns.ProfileForSpec(spec) end,
            function(name) ns.AssignSpecProfile(spec, name) end)
        y = y - 32
    end

    y = y - 20
    Label(panel, L["Import / Export"], "GameFontNormalLarge", 16, y)
    Note(panel, L["Share your style by copying the text, or paste one to import it into the active profile."], 16, y - 20)
    y = y - 44
    Button(panel, L["Export"], 16, y, 140, ShowExport)
    Button(panel, L["Import"], 166, y, 140, ShowImport)
end

------------------------------------------------------------------------
-- Registro en el panel de opciones de Blizzard
------------------------------------------------------------------------

function ns.RegisterOptions()
    local main = NewPanel()
    BuildMain(main)
    main:SetScript("OnShow", function() ns.RefreshOptions() end)
    local category = Settings.RegisterCanvasLayoutCategory(main, "Ruscuu CDM")
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category

    -- La lista de especializaciones solo está disponible tras entrar al juego: se construye al abrirla
    local profiles = NewPanel()
    profiles:SetScript("OnShow", function(self)
        if not self.built then
            self.built = true
            BuildProfiles(self)
        end
        ns.RefreshOptions()
    end)
    Settings.RegisterCanvasLayoutSubcategory(category, profiles, L["Profiles & Themes"])
end

function ns.OpenOptions()
    Settings.OpenToCategory(ns.optionsCategory:GetID())
end
