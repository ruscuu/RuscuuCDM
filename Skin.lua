-- Ruscuu Cooldown Manager Forever: aplica el estilo a los visores del Cooldown Manager.
-- Solo cambia la apariencia (texturas, bordes, fuentes); nunca lee datos de combate,
-- así que respeta las restricciones de addons de Forever/Midnight.
local _, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"

ns.VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer", label = L["Essential cooldowns"], cooldowns = true },
    { key = "utility",   frame = "UtilityCooldownViewer",   label = L["Utility cooldowns"], cooldowns = true },
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
-- El addon no puede leer el tiempo restante (es un valor secreto en combate): pide al juego el
-- DurationObject del cooldown y una curva de color decide el color; el addon nunca ve el tiempo.
------------------------------------------------------------------------

local expireCurve
local gcdCurve            -- 0 si el cooldown dura 1,6 s o menos (cooldown global), 1 si dura más
local gcdGateWorks = true -- se desactiva si el juego no acepta ese valor en SetAlpha
local expireTracked = {}  -- frame -> { tex, getDuration, border }
local expireBroken = false
local durationsFound = 0
local lastAlpha, lastGate  -- últimos valores devueltos por el juego (para /ruscuu debug)

-- Transparente con 0 s (habilidad lista), del color elegido hasta N s, transparente a partir de ahí
function ns.RebuildExpireCurve()
    expireCurve = nil
    if expireBroken or not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
    local db = ns.db
    local r, g, b = db.expireColor[1], db.expireColor[2], db.expireColor[3]
    local s = db.expireSeconds
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        c:AddPoint(0, CreateColor(r, g, b, 0))
        c:AddPoint(0.05, CreateColor(r, g, b, 1))
        c:AddPoint(s, CreateColor(r, g, b, 1))
        c:AddPoint(s + 0.05, CreateColor(r, g, b, 0))
        c:AddPoint(86400, CreateColor(r, g, b, 0))
        return c
    end)
    if ok then expireCurve = curve end

    -- Por si el juego no admite ignorar el cooldown global: los cooldowns cortos no muestran el borde
    gcdCurve = nil
    if C_CurveUtil.CreateCurve then
        local gateOk, gate = pcall(function()
            local c = C_CurveUtil.CreateCurve()
            c:AddPoint(0, 0)
            c:AddPoint(1.6, 0)
            c:AddPoint(1.65, 1)
            c:AddPoint(86400, 1)
            return c
        end)
        if gateOk then gcdCurve = gate end
    end
end

local function LayoutExpireBorder(entry, owner)
    if not entry.border then
        -- Marco exterior: su transparencia filtra el cooldown global (curva gcdCurve)
        local f = CreateFrame("Frame", nil, owner)
        -- Marco interior: lleva el borde, el resplandor y la animación de parpadeo
        local inner = CreateFrame("Frame", nil, f)
        inner:SetAllPoints(f)
        inner.edges = {}
        for i = 1, 4 do
            inner.edges[i] = inner:CreateTexture(nil, "OVERLAY", nil, 7)
            inner.edges[i]:SetTexture(WHITE)
            inner.edges[i]:SetVertexColor(0, 0, 0, 0)
        end
        -- Resplandor suave alrededor del botón (el mismo brillo que usa Blizzard, teñido con el color elegido)
        inner.glow = inner:CreateTexture(nil, "OVERLAY", nil, 6)
        inner.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        inner.glow:SetBlendMode("ADD")
        inner.glow:SetVertexColor(0, 0, 0, 0)
        -- Pulso suave: anima la transparencia; la curva sigue decidiendo si el borde se ve
        inner.blink = inner:CreateAnimationGroup()
        inner.blink:SetLooping("BOUNCE")
        local fade = inner.blink:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.25)
        fade:SetDuration(0.45)
        fade:SetSmoothing("IN_OUT")
        f.inner = inner
        f:Hide()
        entry.border = f
    end
    local f = entry.border
    local inner = f.inner
    local s = math.max(ns.db.borderSize, 1) + 2 -- bastante más grueso que el borde normal para que se vea bien
    local size = entry.tex:GetWidth()
    if not size or size <= 0 then size = 36 end
    -- El resplandor sobresale poco para no invadir los botones de al lado
    local glow = math.floor(size * 0.18 + 0.5)
    inner.glow:ClearAllPoints()
    inner.glow:SetPoint("TOPLEFT", entry.tex, "TOPLEFT", -glow, glow)
    inner.glow:SetPoint("BOTTOMRIGHT", entry.tex, "BOTTOMRIGHT", glow, -glow)
    f:SetFrameLevel(owner:GetFrameLevel() + 5)
    inner:SetFrameLevel(f:GetFrameLevel())
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", entry.tex, "TOPLEFT", -s, s)
    f:SetPoint("BOTTOMRIGHT", entry.tex, "BOTTOMRIGHT", s, -s)
    local top, bottom, left, right = unpack(inner.edges)
    for _, edge in ipairs(inner.edges) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(s)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(s)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(s)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(s)
end

-- Registra un frame (icono del Cooldown Manager o botón de acción) para el borde dorado.
-- getDuration devuelve el DurationObject de su cooldown, o nil si no tiene.
function ns.TrackExpire(owner, tex, getDuration)
    local entry = expireTracked[owner] or {}
    expireTracked[owner] = entry
    entry.tex, entry.getDuration = tex, getDuration
    LayoutExpireBorder(entry, owner)
end

local function HideAllExpire()
    for _, entry in pairs(expireTracked) do entry.border:Hide() end
end

-- Si la API no se comporta como esperamos, se desactiva la función en vez de llenar el chat de errores
local function BreakExpire()
    expireBroken = true
    expireCurve = nil
    HideAllExpire()
    ns.Print(L["The golden border is not available in this game version."])
end

local function UpdateExpireEntry(entry)
    local duration = entry.getDuration()
    if not duration then
        entry.border:Hide()
        return
    end
    durationsFound = durationsFound + 1
    local color = duration:EvaluateRemainingDuration(expireCurve)
    local r, g, b, a = color:GetRGBA()
    lastAlpha = a
    local f, inner = entry.border, entry.border.inner
    for _, edge in ipairs(inner.edges) do edge:SetVertexColor(r, g, b, a) end
    inner.glow:SetVertexColor(r, g, b, a)

    -- Cooldowns de 1,6 s o menos (cooldown global) no muestran el borde; el juego decide sin revelar la duración
    if ns.global.gcdFilter and gcdCurve and gcdGateWorks and duration.EvaluateTotalDuration then
        if not pcall(function()
            lastGate = duration:EvaluateTotalDuration(gcdCurve)
            f:SetAlpha(lastGate)
        end) then
            gcdGateWorks = false
            f:SetAlpha(1)
        end
    else
        f:SetAlpha(1)
    end

    f:Show()
    if ns.db.expireBlink then
        if not inner.blink:IsPlaying() then inner.blink:Play() end
    elseif inner.blink:IsPlaying() then
        inner.blink:Stop()
        inner:SetAlpha(1)
    end
end

local expireDriver = CreateFrame("Frame")
local sinceUpdate = 0
expireDriver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < 0.1 then return end
    sinceUpdate = 0
    if not expireCurve or not ns.db or not ns.db.expireGlow then return end
    for owner, entry in pairs(expireTracked) do
        if owner:IsVisible() then
            if not pcall(UpdateExpireEntry, entry) then
                BreakExpire()
                return
            end
        else
            entry.border:Hide()
        end
    end
end)

-- Cooldown de un icono del Cooldown Manager (ignorando el cooldown global)
local function ViewerItemDuration(item)
    local spellID = item.GetSpellID and item:GetSpellID()
    if not spellID then return end
    return C_Spell.GetSpellCooldownDuration(spellID, true)
end

-- Se llama al cambiar las opciones del borde dorado
function ns.UpdateExpire()
    ns.RebuildExpireCurve()
    if not ns.db.expireGlow then HideAllExpire() end
    for owner, entry in pairs(expireTracked) do LayoutExpireBorder(entry, owner) end
end

-- Muestra un valor del juego, o "secreto" si el juego no deja leerlo
local function Describe(value)
    if value == nil then return "-" end
    if issecretvalue and issecretvalue(value) then return L["secret"] end
    return tostring(value)
end

function ns.ToggleGcdFilter()
    ns.global.gcdFilter = not ns.global.gcdFilter
    ns.Print(ns.global.gcdFilter and L["GCD filter on."] or L["GCD filter off."])
end

function ns.DebugExpire()
    local count = 0
    for _ in pairs(expireTracked) do count = count + 1 end
    local api = (C_CurveUtil and C_CurveUtil.CreateColorCurve) and L["yes"] or L["no"]
    ns.Print(L["Golden border: curve API %s, buttons %d, cooldowns read %d"]:format(api, count, durationsFound)
        .. ", GCD " .. ((ns.global.gcdFilter and gcdCurve and gcdGateWorks) and L["yes"] or L["no"])
        .. " (alpha " .. Describe(lastAlpha) .. ", gcd " .. Describe(lastGate) .. ")"
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
        local tex = IconTexture(item)
        if entry.cooldowns and tex then
            ns.TrackExpire(item, tex, function() return ViewerItemDuration(item) end)
        end
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
