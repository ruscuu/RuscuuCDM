-- Ruscuu Cooldown Manager Forever: aplica el estilo a los visores del Cooldown Manager.
-- Solo cambia la apariencia (texturas, bordes, fuentes); nunca lee datos de combate,
-- así que respeta las restricciones de addons de Forever/Midnight.
local _, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"

ns.VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer", label = L["Essential cooldowns"] },
    { key = "utility",   frame = "UtilityCooldownViewer",   label = L["Utility cooldowns"] },
    { key = "buffIcons", frame = "BuffIconCooldownViewer",  label = L["Buffs (icons)"] },
    { key = "buffBars",  frame = "BuffBarCooldownViewer",   label = L["Buffs (bars)"] },
}

-- Decoraciones propias por item, en una tabla aparte para no escribir campos en frames de Blizzard
local decor = setmetatable({}, { __mode = "k" })
local hooked = {}

-- En los iconos el campo Icon es una textura; en las barras es un frame que contiene la textura
local function IconTexture(item)
    local icon = item.Icon
    if not icon or not icon.IsObjectType then return end
    if icon:IsObjectType("Texture") then return icon end
    local inner = icon.Icon
    if inner and inner.IsObjectType and inner:IsObjectType("Texture") then return inner end
end

-- Quita la máscara redondeada de Blizzard para que el icono quede cuadrado
local function StripMasks(tex)
    if not tex.GetNumMaskTextures then return end
    for i = tex:GetNumMaskTextures(), 1, -1 do
        tex:RemoveMaskTexture(tex:GetMaskTexture(i))
    end
end

local function CreateBorder(parent, anchor)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetFrameLevel(parent:GetFrameLevel() + 2)
    border.anchor = anchor
    return border
end

local function StyleBorder(border, db)
    local s = db.borderSize
    if s <= 0 then
        border:Hide()
        return
    end
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", border.anchor, "TOPLEFT", -s, s)
    border:SetPoint("BOTTOMRIGHT", border.anchor, "BOTTOMRIGHT", s, -s)
    border:SetBackdrop({ edgeFile = WHITE, edgeSize = s })
    border:SetBackdropBorderColor(unpack(db.borderColor))
    border:Show()
end

-- Cambia la tipografía de los textos de un frame manteniendo su tamaño
local function StyleFonts(frame, db)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local _, size = region:GetFont()
            region:SetFont(db.font, size or db.fontSize, "OUTLINE")
        end
    end
end

local function SkinBar(item, db, d)
    local bar = item.Bar
    if not bar or not bar.SetStatusBarTexture then return end
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(unpack(db.barColor))
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if not d.barBg then
        d.barBg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.barBg:SetAllPoints(bar)
        d.barBorder = CreateBorder(bar, bar)
    end
    d.barBg:SetColorTexture(unpack(db.bgColor))
    StyleBorder(d.barBorder, db)
    StyleFonts(bar, db)
end

local function SkinItem(item, db)
    local d = decor[item]
    if not d then
        d = {}
        decor[item] = d
    end

    local tex = IconTexture(item)
    if tex then
        if not d.masksRemoved then
            StripMasks(tex)
            d.masksRemoved = true
        end
        local z = db.iconZoom
        tex:SetTexCoord(z, 1 - z, z, 1 - z)
        if not d.border then d.border = CreateBorder(item, tex) end
        StyleBorder(d.border, db)
    end

    local cd = item.Cooldown
    if cd then
        if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.75) end
        -- El juego calcula y dibuja los números; el addon solo decide si se muestran
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not db.showNumbers) end
        ns.HookExpire(item, cd, d)
        for _, region in ipairs({ cd:GetRegions() }) do
            if region:IsObjectType("FontString") then
                region:SetFont(db.font, db.fontSize, "OUTLINE")
                region:SetTextColor(unpack(db.numberColor))
            end
        end
    end

    StyleFonts(item, db)
    for _, child in ipairs({ item:GetChildren() }) do
        if child ~= cd and child ~= d.border and child ~= item.Bar then
            StyleFonts(child, db)
        end
    end

    SkinBar(item, db, d)
end

------------------------------------------------------------------------
-- Borde dorado cuando al cooldown le quedan pocos segundos.
-- El addon no puede leer el tiempo restante (es un valor secreto en combate): le pasa al juego
-- una curva de color y es el juego quien decide el color según el tiempo que queda.
------------------------------------------------------------------------

local expireCurve
local expireActive = {}   -- item -> DurationObject del cooldown en curso
local expireBroken = false
local capturedDurations = 0

function ns.RebuildExpireCurve()
    expireCurve = nil
    if expireBroken or not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
    local db = ns.db
    local r, g, b = db.expireColor[1], db.expireColor[2], db.expireColor[3]
    local s = db.expireSeconds
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        c:AddPoint(0, CreateColor(r, g, b, 1))
        c:AddPoint(s, CreateColor(r, g, b, 1))
        c:AddPoint(s + 0.05, CreateColor(r, g, b, 0))
        c:AddPoint(86400, CreateColor(r, g, b, 0))
        return c
    end)
    if ok then expireCurve = curve end
end

local function ExpireBorder(item, d, tex)
    if not d.expire then
        local f = CreateFrame("Frame", nil, item)
        f.edges = {}
        for i = 1, 4 do
            f.edges[i] = f:CreateTexture(nil, "OVERLAY")
            f.edges[i]:SetTexture(WHITE)
        end
        d.expire = f
    end
    local f = d.expire
    local s = math.max(ns.db.borderSize, 1) + 1 -- algo más grueso que el borde normal
    f:SetFrameLevel(item:GetFrameLevel() + 3)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", tex, "TOPLEFT", -s, s)
    f:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", s, -s)
    local top, bottom, left, right = unpack(f.edges)
    for _, edge in ipairs(f.edges) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(s)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(s)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(s)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(s)
    return f
end

local function StopExpire(item)
    expireActive[item] = nil
    local d = decor[item]
    if d and d.expire then d.expire:Hide() end
end

local function StartExpire(item, duration)
    local db = ns.db
    if expireBroken or not expireCurve or not duration or not db or not db.expireGlow then return end
    local d, tex = decor[item], IconTexture(item)
    if not d or not tex then return end
    local f = ExpireBorder(item, d, tex)
    for _, edge in ipairs(f.edges) do edge:SetVertexColor(0, 0, 0, 0) end
    f:Show()
    expireActive[item] = duration
    capturedDurations = capturedDurations + 1
end

-- Si la API no se comporta como esperamos, se desactiva la función en vez de llenar el chat de errores
local function BreakExpire()
    expireBroken = true
    for item in pairs(expireActive) do StopExpire(item) end
    ns.Print(L["The golden border is not available in this game version."])
end

local function UpdateExpireBorder(f, duration)
    local color = duration:EvaluateRemainingDuration(expireCurve)
    local r, g, b, a = color:GetRGBA()
    for _, edge in ipairs(f.edges) do edge:SetVertexColor(r, g, b, a) end
end

local expireDriver = CreateFrame("Frame")
local sinceUpdate = 0
expireDriver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < 0.05 or not expireCurve then return end
    sinceUpdate = 0
    for item, duration in pairs(expireActive) do
        local f = decor[item] and decor[item].expire
        if f and not pcall(UpdateExpireBorder, f, duration) then
            BreakExpire()
            return
        end
    end
end)

-- Captura el DurationObject con el que Blizzard arranca el cooldown de cada icono
local function HookExpire(item, cd, d)
    if d.expireHooked then return end
    d.expireHooked = true
    if type(cd.SetCooldownFromDurationObject) == "function" then
        hooksecurefunc(cd, "SetCooldownFromDurationObject", function(_, duration) StartExpire(item, duration) end)
    end
    -- Algunos cooldowns llegan como inicio + duración: se convierten en DurationObject si el juego lo permite
    if type(cd.SetCooldown) == "function" and C_DurationUtil and C_DurationUtil.CreateDuration then
        hooksecurefunc(cd, "SetCooldown", function(_, start, length)
            local ok, duration = pcall(function()
                local dur = C_DurationUtil.CreateDuration()
                dur:SetTimeFromStart(start, length)
                return dur
            end)
            if ok then StartExpire(item, duration) end
        end)
    end
    if type(cd.Clear) == "function" then
        hooksecurefunc(cd, "Clear", function() StopExpire(item) end)
    end
    cd:HookScript("OnCooldownDone", function() StopExpire(item) end)
    cd:HookScript("OnHide", function() StopExpire(item) end)
end
ns.HookExpire = HookExpire -- SkinItem está definido antes en el archivo

-- Se llama al cambiar las opciones del borde dorado
function ns.UpdateExpire()
    ns.RebuildExpireCurve()
    if not ns.db.expireGlow then
        for item in pairs(expireActive) do StopExpire(item) end
    end
end

function ns.DebugExpire()
    local api = (C_CurveUtil and C_CurveUtil.CreateColorCurve) and L["yes"] or L["no"]
    ns.Print(L["Golden border: curve API %s, cooldowns captured %d"]:format(api, capturedDurations)
        .. (expireBroken and " |cffff5555(" .. L["disabled"] .. ")|r" or ""))
end

local function ItemFrames(viewer)
    local items = {}
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.Cooldown or child.Bar or child.Icon then
            items[#items + 1] = child
        end
    end
    return items
end

function ns.SkinViewer(entry)
    local db = ns.db
    if not db or not db.enabled[entry.key] then return end
    local viewer = _G[entry.frame]
    if not viewer then return end
    for _, item in ipairs(ItemFrames(viewer)) do
        SkinItem(item, db)
    end
end

function ns.SkinAll()
    for _, entry in ipairs(ns.VIEWERS) do
        ns.SkinViewer(entry)
    end
end

-- Se engancha a los métodos con los que Blizzard recoloca los iconos, para reaplicar el estilo
function ns.HookViewers()
    for _, entry in ipairs(ns.VIEWERS) do
        local viewer = _G[entry.frame]
        if viewer and not hooked[viewer] then
            hooked[viewer] = true
            local function refresh() ns.SkinViewer(entry) end
            for _, method in ipairs({ "RefreshLayout", "Layout" }) do
                if type(viewer[method]) == "function" then
                    hooksecurefunc(viewer, method, refresh)
                end
            end
            viewer:HookScript("OnShow", refresh)
            refresh()
        end
    end
end

-- /ruscuu debug: muestra qué visores encuentra el addon, útil para probar en Forever
function ns.Debug()
    for _, entry in ipairs(ns.VIEWERS) do
        local viewer = _G[entry.frame]
        if viewer then
            ns.Print(L["%s: found, %d icons, hooked=%s"]:format(
                entry.frame, #ItemFrames(viewer), tostring(hooked[viewer] == true)))
        else
            ns.Print(entry.frame .. ": |cffff5555" .. L["does not exist"] .. "|r")
        end
    end
end
