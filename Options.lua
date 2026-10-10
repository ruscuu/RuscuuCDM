-- Ruscuu Cooldown Manager Forever: panel de opciones (Esc > Opciones > AddOns > Ruscuu CDM)
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local PURPLE = { 0.61, 0.30, 1.00 }

local panel = CreateFrame("Frame")
panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = function() end

local function Label(text, template, x, y)
    local fs = panel:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Checkbox(label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self) set(self:GetChecked()) end)
    return cb
end

-- Slider propio con el estilo Ruscuu (no depende de plantillas que cambian entre versiones)
local function Slider(label, x, y, minV, maxV, step, fmt, get, set)
    Label(label, "GameFontNormal", x, y)
    local s = CreateFrame("Slider", nil, panel, "BackdropTemplate")
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
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouse(true)

    local value = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    value:SetPoint("LEFT", s, "RIGHT", 10, 0)

    s:SetValue(get())
    value:SetText(fmt:format(get()))
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        set(v)
        value:SetText(fmt:format(v))
        ns.SkinAll()
    end)
end

local function ColorSwatch(label, x, y, color)
    local b = CreateFrame("Button", nil, panel, "BackdropTemplate")
    b:SetSize(22, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropBorderColor(1, 1, 1, 0.8)
    local fill = b:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(color[1], color[2], color[3])

    local text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", b, "RIGHT", 8, 0)
    text:SetText(label)

    local function apply(r, g, bl)
        color[1], color[2], color[3] = r, g, bl
        fill:SetColorTexture(r, g, bl)
        ns.SkinAll()
    end

    b:SetScript("OnClick", function()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color[1], g = color[2], b = color[3],
            hasOpacity = false,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(prev) apply(prev.r, prev.g, prev.b) end,
        })
    end)
end

local function Build()
    local db = ns.db

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\RuscuuCDM\\Media\\logo")
    logo:SetSize(128, 128)
    logo:SetPoint("TOPLEFT", 16, -16)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 16, -36)
    title:SetText("|cff9b4dffRuscuu|r Cooldown Manager Forever")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetText("Estilo para el Cooldown Manager de Blizzard. Comandos: /ruscuu, /ruscuu debug, /ruscuu reset")

    local y = -164
    Label("Aplicar estilo a", "GameFontNormalLarge", 16, y)
    y = y - 24
    for _, entry in ipairs(ns.VIEWERS) do
        Checkbox(entry.label, 16, y,
            function() return db.enabled[entry.key] end,
            function(checked)
                db.enabled[entry.key] = checked
                if checked then
                    ns.SkinAll()
                else
                    ns.Print("Escribe /reload para volver al estilo de Blizzard en ese visor.")
                end
            end)
        y = y - 28
    end

    y = y - 12
    Slider("Grosor del borde", 16, y, 0, 4, 1, "%d px",
        function() return db.borderSize end, function(v) db.borderSize = v end)
    Slider("Recorte del icono", 340, y, 0, 0.15, 0.01, "%.2f",
        function() return db.iconZoom end, function(v) db.iconZoom = v end)
    y = y - 56
    Slider("Tamaño del texto de cooldown", 16, y, 8, 24, 1, "%d",
        function() return db.fontSize end, function(v) db.fontSize = v end)

    y = y - 60
    ColorSwatch("Color del borde", 16, y, db.borderColor)
    ColorSwatch("Color de las barras", 340, y, db.barColor)
end

function ns.RegisterOptions()
    Build()
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Ruscuu CDM")
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
end

function ns.OpenOptions()
    Settings.OpenToCategory(ns.optionsCategory:GetID())
end
