-- Ruscuu Cooldown Manager Forever: panel de opciones (Esc > Opciones > AddOns > Ruscuu CDM).
-- Cada página tiene desplazamiento, ayuda al pasar el ratón y su botón de "Valores por defecto".
local _, ns = ...
local L = ns.L

local WHITE = ns.WHITE
local PURPLE = ns.COLORS.purple
local LOGO_SMALL = "Interface\\AddOns\\RuscuuCDM\\Media\\icon"

-- Cada control registra cómo releer su valor, para refrescarlo al cambiar de perfil
local refreshers = {}

function ns.RefreshOptions()
    for _, refresh in ipairs(refreshers) do refresh() end
end

local function OnRefresh(fn)
    refreshers[#refreshers + 1] = fn
end

-- Aplica el estilo tras cambiar una opción
local function ApplyStyle()
    ns.UpdateExpire()
    ns.SkinAll()
    ns.StyleActionBars()
end

-- Un error al aplicar no debe romper el control que lo llamó (por ejemplo, el selector de color de Blizzard
-- no se cierra si su función falla): se avisa en el chat y el panel sigue funcionando
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.ReportError(err) end
end

local function Apply()
    SafeCall(ApplyStyle)
end

local function PlayClick(on)
    if SOUNDKIT then
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

local function AddTooltip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------------------
-- Formatos de los valores de los deslizadores
------------------------------------------------------------------------

local function FormatPercent(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
local function FormatPixels(v) return ("%d px"):format(v) end
local function FormatNumber(v) return ("%d"):format(v) end
local function FormatSeconds(v) return ("%.1f s"):format(v) end
local function FormatWholePercent(v) return ("%d%%"):format(v) end
local function FormatPerSecond(v) return L["%.1f per second"]:format(v) end
local function FormatOrBlizzard(v)
    if v == 0 then return L["Blizzard"] end
    return ("%d"):format(v)
end

-- Al escribir un valor se usan las unidades que se ven: 8% de recorte se guarda como 0.08
local DISPLAY_SCALE = { [FormatPercent] = 100 }

------------------------------------------------------------------------
-- Listas de opciones de los desplegables
------------------------------------------------------------------------

local function KeybindAnchorOptions()
    return {
        { value = "TOPLEFT", text = L["Top left"] },
        { value = "TOPRIGHT", text = L["Top right"] },
        { value = "BOTTOMLEFT", text = L["Bottom left"] },
        { value = "BOTTOMRIGHT", text = L["Bottom right"] },
    }
end

local function OutlineOptions()
    local list = {}
    for _, o in ipairs(ns.OUTLINES) do list[#list + 1] = { value = o.key, text = L[o.nameKey] } end
    return list
end

local function TriStateOptions()
    return {
        { value = "blizzard", text = L["Blizzard default"] },
        { value = "show", text = L["Show"] },
        { value = "hide", text = L["Hide"] },
    }
end

local function PulseOptions()
    return {
        { value = "none", text = L["No blinking"] },
        { value = "pulse", text = L["Smooth pulse"] },
        { value = "flash", text = L["Flash"] },
    }
end

local function FontOptions()
    local list = {}
    for _, f in ipairs(ns.GetFontList()) do list[#list + 1] = { value = f.path, text = f.name } end
    return list
end

local function BarTextureOptions()
    local list = {}
    for _, t in ipairs(ns.GetBarTextureList()) do list[#list + 1] = { value = t.key, text = t.name } end
    return list
end

local function ProfileOptions()
    local list = {}
    for _, name in ipairs(ns.GetProfileNames()) do list[#list + 1] = { value = name, text = name } end
    return list
end

------------------------------------------------------------------------
-- Maquetación: columnas, secciones y controles con el estilo Ruscuu
------------------------------------------------------------------------

local Layout = {}
Layout.__index = Layout

local function NewLayout(content, width)
    local self = setmetatable({}, Layout)
    self.content, self.width, self.y = content, width, -6
    self.colWidth = math.floor((width - 48) / 2)
    self.col2 = 16 + self.colWidth + 16
    return self
end

function Layout:X(col)
    return (col == 2) and self.col2 or 16
end

function Layout:Next(height)
    self.y = self.y - height
end

function Layout:Section(text)
    self:Next(10)
    local fs = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, self.y)
    fs:SetText(text)
    local line = self.content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.45)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 16, self.y - 22)
    line:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -16, self.y - 22)
    self:Next(32)
end

-- Texto explicativo; devuelve el texto y la altura que ocupa
function Layout:Note(text, col, width)
    local fs = self.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", self:X(col), self.y)
    fs:SetWidth(width or (col and self.colWidth or (self.width - 32)))
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.78, 0.78, 0.78)
    fs:SetText(text)
    return fs, math.ceil(fs:GetStringHeight()) + 8
end

function Layout:Check(col, label, get, set, tip)
    local cb = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", self:X(col) - 4, self.y + 3)
    local textWidth = self.colWidth - 30
    cb.Text:SetFontObject("GameFontHighlight")
    cb.Text:SetText(label)
    cb.Text:SetWidth(textWidth)
    cb.Text:SetJustifyH("LEFT")
    cb.Text:SetWordWrap(false)
    cb:SetHitRectInsets(0, -textWidth, 0, 0)
    cb:SetScript("OnClick", function(button)
        local on = button:GetChecked() and true or false
        PlayClick(on)
        set(on)
    end)
    local function refresh() cb:SetChecked(get() and true or false) end
    refresh()
    OnRefresh(refresh)
    AddTooltip(cb, label, tip)
    return cb
end

-- Casilla de una opción del perfil
function Layout:DBCheck(col, label, key, tip, onChange)
    return self:Check(col, label,
        function() return ns.db[key] end,
        function(on)
            ns.db[key] = on
            SafeCall(onChange or ApplyStyle)
        end, tip)
end

-- Deslizador propio con el estilo Ruscuu (no depende de plantillas que cambian entre versiones)
function Layout:Slider(col, label, key, step, display, onChange, tip)
    local x, y = self:X(col), self.y
    local title = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)
    local limits = ns.LIMITS[key]
    local scale = DISPLAY_SCALE[display] or 1
    local s = CreateFrame("Slider", nil, self.content, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(self.colWidth - 92, 12)
    s:SetPoint("TOPLEFT", x, y - 22)
    s:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    s:SetBackdropColor(unpack(ns.COLORS.bg))
    s:SetBackdropBorderColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.6)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 18)
    thumb:SetVertexColor(PURPLE[1], PURPLE[2], PURPLE[3])
    s:SetMinMaxValues(limits[1], limits[2])
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouse(true)

    -- Cuadro con el valor: se puede escribir el número exacto (Intro) o ajustarlo con la rueda del ratón
    local box = CreateFrame("EditBox", nil, self.content, "BackdropTemplate")
    box:SetSize(80, 20)
    box:SetPoint("LEFT", s, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetJustifyH("CENTER")
    box:SetTextInsets(3, 3, 0, 0)
    box:SetMaxLetters(12)
    box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.35)
    box:EnableMouseWheel(true)
    local function boxBorder(alpha) box:SetBackdropBorderColor(PURPLE[1], PURPLE[2], PURPLE[3], alpha) end
    boxBorder(0.25)

    local function round(v)
        v = math.max(limits[1], math.min(limits[2], v))
        return tonumber(("%.3f"):format(math.floor(v / step + 0.5) * step))
    end
    local function showValue()
        if box:HasFocus() then
            box:SetText(("%g"):format(tonumber(("%.3f"):format(ns.db[key] * scale))))
        else
            box:SetText(display(ns.db[key]))
        end
    end
    -- Cambia el valor como si se hubiera movido el deslizador (guarda y aplica el estilo)
    local function setValue(v)
        v = round(v)
        if v ~= ns.db[key] then s:SetValue(v) end
        showValue()
    end

    local refreshing = false
    local function refresh()
        refreshing = true
        s:SetValue(ns.db[key])
        showValue()
        refreshing = false
    end
    s:SetScript("OnValueChanged", function(_, v)
        if refreshing then return end
        ns.db[key] = round(v)
        showValue()
        SafeCall(onChange or ApplyStyle)
    end)

    box:SetScript("OnEditFocusGained", function()
        boxBorder(0.9)
        showValue()
        box:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function()
        boxBorder(0.25)
        box:HighlightText(0, 0)
        showValue()
    end)
    box:SetScript("OnEnterPressed", function()
        -- Acepta coma o punto decimal y unidades escritas ("8%", "3,5 s")
        local n = tonumber((box:GetText():gsub(",", ".")):match("%-?%d*%.?%d+"))
        if n then setValue(n / scale) end
        box:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
    box:SetScript("OnHide", function() box:ClearFocus() end)
    box:SetScript("OnMouseWheel", function(_, delta) setValue(ns.db[key] + delta * step) end)
    box:HookScript("OnEnter", function() if not box:HasFocus() then boxBorder(0.6) end end)
    box:HookScript("OnLeave", function() if not box:HasFocus() then boxBorder(0.25) end end)

    refresh()
    OnRefresh(refresh)
    AddTooltip(s, label, tip)
    AddTooltip(box, label, L["Type a value and press Enter, or use the mouse wheel over it."])
    return s
end

-- Muestra de color con transparencia
function Layout:Color(col, label, key, onChange, tip)
    local b = CreateFrame("Button", nil, self.content, "BackdropTemplate")
    b:SetSize(22, 22)
    b:SetPoint("TOPLEFT", self:X(col), self.y)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.15, 0.15, 0.15, 1)
    b:SetBackdropBorderColor(1, 1, 1, 0.8)
    local fill = b:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    local text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", b, "RIGHT", 8, 0)
    text:SetText(label)

    local function refresh()
        local c = ns.db[key]
        fill:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    local function apply(r, g, bl, a)
        local c = ns.db[key]
        c[1], c[2], c[3], c[4] = r, g, bl, a
        refresh()
        SafeCall(onChange or ApplyStyle)
    end
    b:SetScript("OnClick", function()
        local c = ns.db[key]
        local previous = c[4] or 1
        local info = {
            r = c[1], g = c[2], b = c[3],
            opacity = previous,
            hasOpacity = true,
        }
        info.swatchFunc = function()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or previous
            apply(r, g, bl, a)
        end
        info.opacityFunc = info.swatchFunc
        info.cancelFunc = function(prev)
            apply(prev.r, prev.g, prev.b, prev.a or prev.opacity or previous)
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    refresh()
    OnRefresh(refresh)
    AddTooltip(b, label, tip)
    return b
end

-- Desplegable con las opciones que devuelve getOptions() ({ value, text })
function Layout:Dropdown(col, label, getOptions, getSelected, onSelect, tip)
    local x, y = self:X(col), self.y
    local title = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)
    local dd = CreateFrame("DropdownButton", nil, self.content, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", x, y - 18)
    dd:SetWidth(self.colWidth - 20)
    dd:SetupMenu(function(_, root)
        for _, option in ipairs(getOptions()) do
            root:CreateRadio(option.text,
                function() return getSelected() == option.value end,
                function() onSelect(option.value) end)
        end
    end)
    OnRefresh(function() dd:GenerateMenu() end)
    AddTooltip(dd, label, tip)
    return dd
end

function Layout:DBChoice(col, label, key, getOptions, tip, onChange)
    return self:Dropdown(col, label, getOptions,
        function() return ns.db[key] end,
        function(value)
            ns.db[key] = value
            SafeCall(onChange or ApplyStyle)
        end, tip)
end

function Layout:Button(col, text, width, onClick, tip, xOffset)
    local b = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    b:SetSize(width or 200, 24)
    b:SetPoint("TOPLEFT", self:X(col) + (xOffset or 0), self.y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    AddTooltip(b, text, tip)
    return b
end

-- Vista previa en vivo de los ajustes del perfil activo
function Layout:Preview()
    local preview = ns.CreatePreview(self.content)
    preview:SetPoint("TOPLEFT", 16, self.y - 4)
    self:Next(92)
    return preview
end

------------------------------------------------------------------------
-- Páginas
------------------------------------------------------------------------

local function BuildHeader(panel)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO_SMALL)
    logo:SetSize(44, 44)
    logo:SetPoint("TOPLEFT", 12, -10)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -2)
    title:SetText("|cff9b4dffRuscuu|r  " .. L[panel.titleKey])

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.78, 0.78, 0.78)
    desc:SetText(L[panel.descKey])

    local chip = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    chip:SetPoint("TOPRIGHT", -16, -12)
    OnRefresh(function() chip:SetText(L["Profile: %s"]:format("|cff9b4dff" .. ns.activeProfile .. "|r")) end)

    -- Botones a la derecha: Valores por defecto (si la página tiene) y Recargar IU (en todas)
    local rightEdge = -16
    if panel.resetKeys then
        local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        reset:SetSize(150, 22)
        reset:SetPoint("TOPRIGHT", rightEdge, -30)
        reset:SetText(L["Defaults"])
        reset:SetScript("OnClick", function()
            ns.ShowPopup("RUSCUUCDM_RESET_KEYS", L[panel.titleKey], nil, panel.resetKeys)
        end)
        AddTooltip(reset, L["Defaults"], L["Restores the default values of this page in the active profile."])
        rightEdge = rightEdge - 150 - 6
    end
    local reload = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reload:SetSize(120, 22)
    reload:SetPoint("TOPRIGHT", rightEdge, -30)
    reload:SetText(L["Reload UI"])
    reload:SetScript("OnClick", function() ReloadUI() end)
    AddTooltip(reload, L["Reload UI"],
        L["Reloads the game interface, like /reload. Most changes apply instantly; the language needs a reload."])
    desc:SetPoint("RIGHT", panel, "RIGHT", rightEdge - 120 - 8, 0)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.6)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 12, -62)
    line:SetPoint("TOPRIGHT", -12, -62)
end

local function BuildScroll(panel)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, panel, "ScrollFrameTemplate")
    if not ok or not scroll then
        scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    end
    scroll:SetPoint("TOPLEFT", 0, -66)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local width = math.max(560, math.floor((panel:GetWidth() or 640) - 30))
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 100)
    scroll:SetScrollChild(content)
    return content, width
end

-- Las páginas se construyen la primera vez que se abren (el panel ya tiene su tamaño definitivo)
local function CreatePage(titleKey, descKey, resetKeys, build)
    local panel = CreateFrame("Frame")
    -- Oculto desde el principio: si no, el primer Show() de la ventana de opciones no dispara OnShow
    -- (el marco ya estaba visible) y la página sale en blanco hasta salir y volver a entrar
    panel:Hide()
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end
    panel.titleKey, panel.descKey, panel.resetKeys = titleKey, descKey, resetKeys
    panel:SetScript("OnShow", function(self)
        if not self.built then
            self.built = true
            BuildHeader(self)
            local content, width = BuildScroll(self)
            local ui = NewLayout(content, width)
            self.content, self.ui = content, ui
            -- Si algo falla al construir la página se avisa en ella en vez de dejarla en blanco
            local ok, err = pcall(build, ui, self)
            if not ok then
                local _, h = ui:Note("|cffff5555" .. L["This page could not be shown because of an error. Please report it:"]
                    .. "|r\n" .. tostring(err))
                ui:Next(h)
                geterrorhandler()(err)
            end
            content:SetHeight(-ui.y + 24)
        end
        ns.RefreshOptions()
        if self.onShow then self.onShow() end
    end)
    return panel
end

------------------------------------------------------------------------
-- Página General
------------------------------------------------------------------------

local function BuildGeneral(ui)
    ui:Section(L["Blizzard's Cooldown Manager"])
    local _, h = ui:Note(L["Choose which cooldowns appear, and in which bar, from Blizzard's own panel: drag a spell to \"Not Displayed\" to hide it. Your choice is saved for each specialization."])
    ui:Next(h)
    ui:Button(1, L["Choose visible cooldowns"], 260, function() ns.OpenCooldownSettings() end,
        L["Opens Blizzard's Advanced Cooldown Settings. Also: /rcm cooldowns, or Shift + click on the minimap button."])
    ui:Next(34)
    ui:Check(1, L["Enable the Cooldown Manager on install"],
        function() return ns.global.autoEnableCDM end,
        function(on)
            ns.global.autoEnableCDM = on
            if on then ns.EnableCooldownManager(true) end
        end,
        L["Turns on Blizzard's Cooldown Manager the first time the addon loads. If you turn it off later in Blizzard's options, the addon respects your choice."])
    ui:Next(30)

    ui:Section(L["Status"])
    local status = ui:Note("", nil)
    status:SetFontObject("GameFontHighlight")
    OnRefresh(function()
        local s = ns.GetStatus()
        local good, bad = "|cff4dff88", "|cffff5555"
        local function line(ok, text) return (ok and good or bad) .. text .. "|r" end
        status:SetText(table.concat({
            line(s.cdmOn, L["Cooldown Manager enabled: %s"]:format(s.cdmOn and L["yes"] or L["no"])),
            line(s.viewersFound == s.viewersTotal, L["Viewers found: %d/%d"]:format(s.viewersFound, s.viewersTotal)),
            line(s.actionCooldowns > 0, L["Action bar cooldowns hooked: %d"]:format(s.actionCooldowns)),
            line(s.curveAPI, L["Golden border: curve API %s, buttons %d, cooldowns read %d"]:format(
                s.curveAPI and L["yes"] or L["no"], s.expireTracked, s.expireReads)),
            line(s.auraAPI, L["Buffs about to end: aura API %s"]:format(s.auraAPI and L["yes"] or L["no"])),
            "|cffffffff" .. L["Active profile: %s"]:format(ns.activeProfile) .. "|r",
        }, "\n"))
    end)
    ui:Next(100)

    ui:Section(L["Addon"])
    ui:Check(1, L["Show minimap button"],
        function() return not ns.global.minimap.hide end,
        function(on) ns.SetMinimapShown(on) end)
    ui:Check(2, L["Lock minimap button"],
        function() return ns.global.minimap.lock end,
        function(on) ns.SetMinimapLocked(on) end,
        L["Prevents moving the minimap button by dragging it."])
    ui:Next(30)
    ui:Check(1, L["Chat messages"],
        function() return ns.global.chatMessages end,
        function(on) ns.global.chatMessages = on end,
        L["Informative messages such as profile switches or applied themes. Warnings are always shown."])
    ui:Next(32)
    ui:Dropdown(1, L["Language"],
        function()
            local list = { { value = "auto", text = L["Automatic (game language)"] } }
            for _, lang in ipairs(ns.LANGUAGES) do list[#list + 1] = { value = lang.code, text = lang.name } end
            return list
        end,
        function() return ns.global.language end,
        function(value)
            ns.global.language = value
            ns.Print(L["The language will change when you reload the interface."], true)
        end,
        L["The addon follows the game language by default. Changing it requires reloading the interface."])
    ui:Next(56)

    ui:Section(L["Commands"])
    local _, hc = ui:Note(table.concat({
        "/rcm  — " .. L["open options"],
        "/rcm cooldowns  — " .. L["choose which cooldowns are shown"],
        "/rcm test  — " .. L["preview the golden border for 5 seconds"],
        "/rcm skin  — " .. L["reapply the style"],
        "/rcm minimap  — " .. L["show or hide the minimap button"],
        "/rcm debug  — " .. L["diagnostic information"],
        "/rcm reset  — " .. L["reset all settings"],
    }, "\n"))
    ui:Next(hc + 4)
    ui:Button(1, L["Reset everything"], 200, function() ns.ShowPopup("RUSCUUCDM_RESET_ALL") end,
        L["Deletes all profiles and settings of the addon and reloads the interface."])
    ui:Next(30)
end

------------------------------------------------------------------------
-- Página Cooldown Manager
------------------------------------------------------------------------

local function BuildCooldownManager(ui)
    ui:Preview()

    ui:Section(L["Apply style to"])
    for i, entry in ipairs(ns.VIEWERS) do
        local col = (i % 2 == 1) and 1 or 2
        ui:Check(col, L[entry.labelKey],
            function() return ns.db.enabled[entry.key] end,
            function(on)
                ns.db.enabled[entry.key] = on
                Apply()
            end,
            L["When unchecked, this viewer goes back to Blizzard's look immediately."])
        if col == 2 then ui:Next(30) end
    end

    ui:Section(L["Active cooldowns"])
    local _, h = ui:Note(L["Hides the cooldowns that are ready and shows the ones on cooldown, essential and utility together, in one line centered where the essential cooldowns are."])
    ui:Next(h)
    ui:DBCheck(1, L["Only active cooldowns"], "activeOnly",
        L["The global cooldown doesn't count. While Edit Mode or Blizzard's cooldown settings are open, everything is shown as usual."])
    ui:DBCheck(2, L["Flash when ready"], "activeFlash",
        L["When a cooldown ends, its icon stays one second with a flash before hiding."])
    ui:Next(32)

    ui:Section(L["Icons"])
    ui:DBCheck(1, L["Square icons"], "squareIcons",
        L["Removes Blizzard's round mask and frame so icons are square."])
    ui:DBCheck(2, L["Class color border"], "borderClassColor",
        L["Uses your class color for the borders instead of the chosen color."])
    ui:Next(32)
    ui:Slider(1, L["Icon crop"], "iconZoom", 0.01, FormatPercent, nil,
        L["Trims the edges of the icon artwork. 0% shows the full icon."])
    ui:Slider(2, L["Border size"], "borderSize", 1, FormatPixels, nil,
        L["Thickness of the border around icons and bars. 0 hides it."])
    ui:Next(48)
    ui:Color(1, L["Border color"], "borderColor")
    ui:Next(32)

    ui:Section(L["Cooldown swipe"])
    ui:DBCheck(1, L["Show swipe"], "showSwipe",
        L["The shadow that sweeps over the icon while the cooldown runs."])
    ui:Color(2, L["Swipe color"], "swipeColor")
    ui:Next(32)
    ui:DBChoice(1, L["Swipe edge"], "cooldownEdge", TriStateOptions,
        L["The bright line at the edge of the swipe."])
    ui:DBChoice(2, L["Finish flash"], "cooldownBling", TriStateOptions,
        L["The flash Blizzard plays when a cooldown finishes."])
    ui:Next(56)

    ui:Section(L["Buff bars"])
    ui:DBChoice(1, L["Bar texture"], "barTexture", BarTextureOptions)
    ui:Next(56)
    ui:Color(1, L["Bar color"], "barColor")
    ui:Color(2, L["Bar background"], "bgColor")
    ui:Next(32)
    ui:DBCheck(1, L["Class color bars"], "barClassColor",
        L["Uses your class color for the buff bars instead of the chosen bar color."])
    ui:Next(32)
end

------------------------------------------------------------------------
-- Página Textos y números
------------------------------------------------------------------------

local function BuildTexts(ui)
    ui:Preview()

    ui:Section(L["Font"])
    ui:DBChoice(1, L["Typeface"], "font", FontOptions,
        L["Used by every text the addon styles. Fonts from SharedMedia appear here too."])
    ui:Next(56)

    ui:Section(L["Cooldown Manager countdown"])
    ui:DBCheck(1, L["Show countdown numbers"], "showNumbers")
    ui:Color(2, L["Number color"], "numberColor")
    ui:Next(32)
    ui:Slider(1, L["Number size"], "fontSize", 1, FormatNumber)
    ui:DBChoice(2, L["Outline"], "numberOutline", OutlineOptions)
    ui:Next(56)

    ui:Section(L["Charges and stacks"])
    ui:Slider(1, L["Size"], "countSize", 1, FormatOrBlizzard, nil, L["0 keeps Blizzard's size."])
    ui:DBChoice(2, L["Outline"], "countOutline", OutlineOptions,
        L["Also used by the name and duration of the buff bars."])
    ui:Next(56)
    ui:DBCheck(1, L["Custom color"], "countUseColor")
    ui:Color(2, L["Charges color"], "countColor")
    ui:Next(32)

    ui:Section(L["Keybinds"])
    ui:DBCheck(1, L["Show keybinds"], "showKeybinds",
        L["Shows on each Cooldown Manager icon the key that casts it, taken from your action bars."])
    ui:Color(2, L["Keybind color"], "keybindColor")
    ui:Next(32)
    ui:Slider(1, L["Keybind size"], "keybindSize", 1, FormatNumber)
    ui:DBChoice(2, L["Outline"], "keybindOutline", OutlineOptions)
    ui:Next(56)
    ui:DBChoice(1, L["Position"], "keybindAnchor", KeybindAnchorOptions)
    ui:Next(56)

    ui:Section(L["Buff bar texts"])
    ui:Slider(1, L["Name and duration size"], "barTextSize", 1, FormatOrBlizzard, nil, L["0 keeps Blizzard's size."])
    ui:Next(48)
end

------------------------------------------------------------------------
-- Página Barras de acción
------------------------------------------------------------------------

local function BuildActionBars(ui)
    ui:Section(L["Cooldown numbers on action buttons"])
    ui:Dropdown(1, L["Blizzard's countdown numbers"],
        function()
            return {
                { value = "on", text = L["Always show"] },
                { value = "off", text = L["Never show"] },
                { value = "blizzard", text = L["Leave the game setting"] },
            }
        end,
        function() return ns.global.actionBarNumbersMode end,
        function(value)
            ns.global.actionBarNumbersMode = value
            ns.ApplyActionBarNumbersMode()
        end,
        L["Controls the game's own \"Show numbers for cooldowns\" setting (shared by all profiles)."])
    ui:Next(56)
    ui:DBCheck(1, L["Ruscuu style for the numbers"], "styleActionBarNumbers",
        L["When unchecked, Blizzard's font returns immediately."])
    ui:Color(2, L["Number color"], "actionBarNumberColor")
    ui:Next(32)
    ui:Slider(1, L["Number size"], "actionBarFontSize", 1, FormatNumber)
    ui:DBChoice(2, L["Outline"], "actionBarNumberOutline", OutlineOptions)
    ui:Next(56)

    ui:Section(L["Bars included"])
    local _, h = ui:Note(L["The number style and the golden border are applied only to the checked bars."])
    ui:Next(h)
    for i, bar in ipairs(ns.ACTION_BARS) do
        local col = (i % 2 == 1) and 1 or 2
        ui:Check(col, L[bar.nameKey],
            function() return ns.db.bars[bar.key] end,
            function(on)
                ns.db.bars[bar.key] = on
                Apply()
            end, bar.tipKey and L[bar.tipKey])
        if col == 2 then ui:Next(28) end
    end
    if #ns.ACTION_BARS % 2 == 1 then ui:Next(28) end
end

------------------------------------------------------------------------
-- Página Borde dorado
------------------------------------------------------------------------

local function BuildGoldenBorder(ui)
    ui:Preview()
    ui:Button(1, L["Test for 5 seconds"], 200, function() ns.TestExpire(5) end,
        L["Shows the golden border on every button for 5 seconds so you can see how it looks."])
    local _, h = ui:Note(L["The game decides when the border appears: the addon never reads the remaining time, so it follows Forever's rules."], 2)
    ui:Next(math.max(30, h))

    ui:Section(L["General"])
    ui:DBCheck(1, L["Golden border when a cooldown is ending"], "expireGlow")
    ui:Color(2, L["Ending border color"], "expireColor")
    ui:Next(30)
    ui:DBCheck(1, L["On Cooldown Manager icons"], "expireOnCDM")
    ui:DBCheck(2, L["On action buttons"], "expireOnActionBars")
    ui:Next(32)
    ui:Slider(1, L["Last seconds"], "expireSeconds", 0.5, FormatSeconds, nil,
        L["The border appears when this many seconds (or fewer) remain."])
    ui:Slider(2, L["Thickness"], "expireThickness", 1, FormatPixels)
    ui:Next(48)

    ui:Section(L["Glow"])
    ui:DBCheck(1, L["Soft glow around the button"], "expireGlowShow")
    ui:Next(30)
    ui:Slider(1, L["Glow size"], "expireGlowSize", 5, FormatWholePercent, nil,
        L["100% is the size of Blizzard's own button glow."])
    ui:Next(48)

    ui:Section(L["Blinking"])
    ui:DBChoice(1, L["Blink style"], "expirePulse", PulseOptions)
    ui:Next(56)
    ui:Slider(1, L["Speed"], "expirePulseSpeed", 0.1, FormatPerSecond)
    ui:Slider(2, L["Minimum opacity"], "expirePulseMin", 0.05, FormatPercent,
        nil, L["How much the border fades between blinks."])
    ui:Next(48)

    ui:Section(L["Buffs about to end"])
    ui:DBCheck(1, L["Border when a buff is about to end"], "buffEndGlow",
        L["On the Cooldown Manager's buff icons and bars, so you know when to refresh them. Uses the thickness, glow and blinking above."])
    ui:Color(2, L["Buff border color"], "buffEndColor")
    ui:Next(32)
    ui:Slider(1, L["Last seconds of the buff"], "buffEndSeconds", 0.5, FormatSeconds, nil,
        L["The border appears when this many seconds (or fewer) of the buff remain."])
    ui:Next(48)
end

------------------------------------------------------------------------
-- Página Borde dorado: hechizos
------------------------------------------------------------------------

local function BuildSpells(ui, panel)
    local _, h = ui:Note(L["Uncheck the spells that should never get the golden border. The list shows the spells on your action bars and in the Cooldown Manager; the choice is saved in the active profile."])
    ui:Next(h)
    local listTop
    local rows = {}

    local function Rebuild()
        local spells, seen = {}, {}
        local function add(list)
            for _, sp in ipairs(list) do
                if not seen[sp.spellID] then
                    seen[sp.spellID] = true
                    spells[#spells + 1] = sp
                end
            end
        end
        add(ns.GetActionBarSpells())
        add(ns.GetViewerSpells())
        -- Hechizos excluidos que ya no están en las barras: se muestran para poder volver a incluirlos
        for spellID, on in pairs(ns.db.expireExclude) do
            if on and not seen[spellID] then
                seen[spellID] = true
                spells[#spells + 1] = {
                    spellID = spellID,
                    name = C_Spell.GetSpellName(spellID) or ("#" .. spellID),
                    icon = C_Spell.GetSpellTexture(spellID),
                }
            end
        end
        table.sort(spells, function(a, b) return a.name < b.name end)

        for i, sp in ipairs(spells) do
            local row = rows[i]
            if not row then
                row = CreateFrame("CheckButton", nil, ui.content, "UICheckButtonTemplate")
                row:SetSize(24, 24)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT", row, "RIGHT", 2, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.Text:ClearAllPoints()
                row.Text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                row.Text:SetFontObject("GameFontHighlight")
                row.Text:SetWidth(ui.colWidth - 60)
                row.Text:SetJustifyH("LEFT")
                row.Text:SetWordWrap(false)
                row:SetHitRectInsets(0, -(ui.colWidth - 30), 0, 0)
                row:SetScript("OnClick", function(self)
                    local on = self:GetChecked() and true or false
                    PlayClick(on)
                    ns.db.expireExclude[self.spellID] = (not on) or nil
                end)
                rows[i] = row
            end
            local col = (i % 2 == 1) and 1 or 2
            local line = math.floor((i - 1) / 2)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", ui:X(col) - 4, listTop - line * 28)
            row.spellID = sp.spellID
            row.icon:SetTexture(sp.icon or 134400)
            row.Text:SetText(sp.name)
            row:SetChecked(not ns.db.expireExclude[sp.spellID])
            row:Show()
        end
        for i = #spells + 1, #rows do rows[i]:Hide() end
        local listHeight = math.ceil(#spells / 2) * 28
        panel.emptyNote:SetShown(#spells == 0)
        ui.content:SetHeight(-listTop + listHeight + 24)
    end

    ui:Button(1, L["Refresh list"], 160, Rebuild)
    ui:Button(1, L["Include all"], 160, function()
        wipe(ns.db.expireExclude)
        Rebuild()
    end, nil, 170)
    ui:Next(36)
    listTop = ui.y
    panel.emptyNote = ui:Note(L["No spells found. Put spells on your action bars or enable the Cooldown Manager, then press \"Refresh list\"."])
    panel.onShow = Rebuild
    OnRefresh(function() if panel:IsVisible() then Rebuild() end end)
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
    p:SetBackdropBorderColor(PURPLE[1], PURPLE[2], PURPLE[3])
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
        local ok, result = ns.ImportProfile(p.edit:GetText())
        if ok then
            ns.Print(L["Profile imported (%d settings)."]:format(result), true)
            p:Hide()
        else
            ns.Print(result, true)
        end
    end)
    p:Show()
    p.edit:SetFocus()
end

------------------------------------------------------------------------
-- Diálogos de perfiles
------------------------------------------------------------------------

local function PopupEditBox(dialog)
    return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end

local function PopupText(dialog)
    local box = PopupEditBox(dialog)
    return strtrim(box and box:GetText() or "")
end

local function EnterAccepts(editBox)
    local dialog = editBox:GetParent()
    local info = StaticPopupDialogs[dialog.which]
    if info and info.OnAccept then info.OnAccept(dialog, dialog.data) end
    dialog:Hide()
end

StaticPopupDialogs["RUSCUUCDM_NEW_PROFILE"] = {
    textKey = "New profile name:",
    text = "",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, copyFrom)
        local name = PopupText(self)
        if name ~= "" then ns.CreateProfile(name, copyFrom) end
    end,
    EditBoxOnEnterPressed = EnterAccepts,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RUSCUUCDM_RENAME_PROFILE"] = {
    textKey = "New name for profile \"%s\":",
    text = "",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, old)
        local name = PopupText(self)
        if name ~= "" then ns.RenameProfile(old, name) end
    end,
    EditBoxOnEnterPressed = EnterAccepts,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RUSCUUCDM_DELETE_PROFILE"] = {
    textKey = "Delete profile \"%s\"?",
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name) ns.DeleteProfile(name) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RUSCUUCDM_RESET_PROFILE"] = {
    textKey = "Reset profile \"%s\" to default values?",
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name) ns.ResetProfile(name) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RUSCUUCDM_RESET_KEYS"] = {
    textKey = "Restore the default values of \"%s\" in the active profile?",
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, keys) ns.ResetKeys(keys) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

------------------------------------------------------------------------
-- Página Perfiles y temas
------------------------------------------------------------------------

local function BuildProfiles(ui)
    ui:Section(L["Themes"])
    local _, h = ui:Note(L["Themes change the colors and borders of the active profile. The highlighted theme is the one you are using."])
    ui:Next(h)
    local themeButtons = {}
    for i, theme in ipairs(ns.THEMES) do
        local index = (i - 1) % 3
        local b = ui:Button(1, L[theme.nameKey], 180, function() ns.ApplyTheme(theme) end, nil, index * 190)
        themeButtons[theme] = b
        if index == 2 or i == #ns.THEMES then ui:Next(30) end
    end
    OnRefresh(function()
        local current = ns.CurrentTheme()
        for theme, b in pairs(themeButtons) do
            if theme == current then b:LockHighlight() else b:UnlockHighlight() end
        end
    end)

    ui:Section(L["Profiles"])
    ui:Dropdown(1, L["Active profile"], ProfileOptions,
        function() return ns.activeProfile end,
        function(name) ns.ChooseProfile(name) end,
        L["The profile you choose here is also assigned to your current specialization."])
    ui:Next(56)
    ui:Button(1, L["New"], 108, function() ns.ShowPopup("RUSCUUCDM_NEW_PROFILE") end)
    ui:Button(1, L["Duplicate"], 108, function()
        ns.ShowPopup("RUSCUUCDM_NEW_PROFILE", nil, nil, ns.activeProfile)
    end, L["Creates a new profile with a copy of the active one."], 114)
    ui:Button(1, L["Rename"], 108, function()
        ns.ShowPopup("RUSCUUCDM_RENAME_PROFILE", ns.activeProfile, nil, ns.activeProfile)
    end, nil, 228)
    ui:Button(1, L["Delete"], 108, function()
        ns.ShowPopup("RUSCUUCDM_DELETE_PROFILE", ns.activeProfile, nil, ns.activeProfile)
    end, nil, 342)
    ui:Button(1, L["Reset"], 108, function()
        ns.ShowPopup("RUSCUUCDM_RESET_PROFILE", ns.activeProfile, nil, ns.activeProfile)
    end, nil, 456)
    ui:Next(36)

    ui:Section(L["Profile per specialization"])
    local _, h2 = ui:Note(L["The profile changes automatically when you switch specialization."])
    ui:Next(h2)
    local specs = ns.GetNumSpecs()
    if specs == 0 then
        local _, h3 = ui:Note(L["This character has no specializations yet: the active profile is used."])
        ui:Next(h3)
    end
    for spec = 1, specs do
        local specName, icon = ns.GetSpecInfo(spec)
        local tex = ui.content:CreateTexture(nil, "ARTWORK")
        tex:SetSize(22, 22)
        tex:SetPoint("TOPLEFT", 16, ui.y - 18)
        tex:SetTexture(icon or 134400)
        local label = ui.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", tex, "RIGHT", 8, 0)
        label:SetText(specName)
        ui:Dropdown(2, "", ProfileOptions,
            function() return ns.ProfileForSpec(spec) end,
            function(name) ns.AssignSpecProfile(spec, name) end)
        ui:Next(46)
    end

    ui:Section(L["Import / Export"])
    local _, h4 = ui:Note(L["Share your style by copying the text, or paste one to import it into the active profile."])
    ui:Next(h4)
    ui:Button(1, L["Export"], 160, ShowExport)
    ui:Button(1, L["Import"], 160, ShowImport, nil, 170)
    ui:Next(32)
end

------------------------------------------------------------------------
-- Registro en el panel de opciones de Blizzard
------------------------------------------------------------------------

local SUBPAGES = {
    {
        key = "cdm", titleKey = "Cooldown Manager", descKey = "Icons, borders, swipe and buff bars.",
        build = BuildCooldownManager,
        resetKeys = { "enabled", "activeOnly", "activeFlash", "squareIcons", "iconZoom", "borderSize", "borderColor", "borderClassColor",
            "showSwipe", "swipeColor", "cooldownEdge", "cooldownBling", "barTexture", "barColor", "barClassColor", "bgColor" },
    },
    {
        key = "texts", titleKey = "Texts and numbers", descKey = "Font, countdown numbers, charges, keybinds and bar texts.",
        build = BuildTexts,
        resetKeys = { "font", "showNumbers", "fontSize", "numberOutline", "numberColor", "countSize",
            "countOutline", "countUseColor", "countColor", "showKeybinds", "keybindSize", "keybindOutline",
            "keybindColor", "keybindAnchor", "barTextSize" },
    },
    {
        key = "actionbars", titleKey = "Action bars", descKey = "Cooldown numbers on your action buttons.",
        build = BuildActionBars,
        resetKeys = { "styleActionBarNumbers", "actionBarFontSize", "actionBarNumberOutline",
            "actionBarNumberColor", "bars" },
    },
    {
        key = "golden", titleKey = "Golden border", descKey = "A pulsing border during the last seconds of a cooldown.",
        build = BuildGoldenBorder,
        resetKeys = { "expireGlow", "expireOnCDM", "expireOnActionBars", "expireSeconds", "expireColor",
            "expireThickness", "expireGlowShow", "expireGlowSize", "expirePulse", "expirePulseSpeed", "expirePulseMin",
            "buffEndGlow", "buffEndColor", "buffEndSeconds" },
    },
    {
        key = "spells", titleKey = "Golden border: spells", descKey = "Choose which spells get the golden border.",
        build = BuildSpells,
        resetKeys = { "expireExclude" },
    },
    {
        key = "profiles", titleKey = "Profiles & Themes", descKey = "Themes, profiles per specialization and import/export.",
        build = BuildProfiles,
    },
}

ns.subcategories = {}

function ns.RegisterOptions()
    local general = CreatePage("General", "Status, Blizzard's Cooldown Manager and addon settings.", nil, BuildGeneral)
    local category = Settings.RegisterCanvasLayoutCategory(general, "Ruscuu CDM")
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
    for _, def in ipairs(SUBPAGES) do
        local page = CreatePage(def.titleKey, def.descKey, def.resetKeys, def.build)
        ns.subcategories[def.key] = Settings.RegisterCanvasLayoutSubcategory(category, page, L[def.titleKey])
    end
end

function ns.OpenOptions(pageKey)
    local category = (pageKey and ns.subcategories[pageKey]) or ns.optionsCategory
    Settings.OpenToCategory(category:GetID())
end
