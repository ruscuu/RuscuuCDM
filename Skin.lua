-- Ruscuu Cooldown Manager Forever: estilo de los visores del Cooldown Manager y borde dorado.
-- Solo cambia la apariencia (texturas, bordes, fuentes) y deja que el juego decida todo lo que
-- depende del tiempo de combate (valores secretos): respeta las restricciones de Forever/Midnight.
-- Todo lo que se cambia se puede deshacer al momento, sin recargar la interfaz.
local _, ns = ...
local L = ns.L
local WHITE = ns.WHITE

-- Valores originales de Blizzard (Blizzard_CooldownViewer/CooldownViewer.xml en el cliente de Forever)
local BLIZZ_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local BLIZZ_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local BLIZZ_BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
local BLIZZ_BAR_COLOR = { 1, 0.5, 0.25 }
local BLIZZ_COUNTDOWN_FONT = "GameFontHighlightOutline"

ns.VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer", labelKey = "Essential cooldowns", cooldowns = true },
    { key = "utility", frame = "UtilityCooldownViewer", labelKey = "Utility cooldowns", cooldowns = true },
    { key = "buffIcons", frame = "BuffIconCooldownViewer", labelKey = "Buffs (icons)" },
    { key = "buffBars", frame = "BuffBarCooldownViewer", labelKey = "Buffs (bars)" },
}

-- Estado propio por item, en una tabla aparte para no escribir campos en frames de Blizzard
local decor = setmetatable({}, { __mode = "k" })
local hookedViewers = {}

------------------------------------------------------------------------
-- Textos: se guarda el estado original de cada texto para poder restaurarlo
------------------------------------------------------------------------

local savedText = setmetatable({}, { __mode = "k" })

local function SaveText(fs)
    if savedText[fs] then return savedText[fs] end
    local file, size, flags = fs:GetFont()
    local r, g, b, a = fs:GetTextColor()
    savedText[fs] = { object = fs:GetFontObject(), file = file, size = size, flags = flags, color = { r, g, b, a } }
    return savedText[fs]
end

-- size 0/nil = tamaño original; color nil = color original
function ns.StyleText(fs, size, outlineKey, color)
    if not fs or not fs.SetFont then return end
    local saved = SaveText(fs)
    local useSize = (size and size > 0) and size or saved.size or 12
    ns.SetFontSafe(fs, ns.db.font, useSize, ns.OutlineFlags(outlineKey))
    local c = color or saved.color
    if c and c[1] then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
end

function ns.RestoreText(fs)
    local saved = fs and savedText[fs]
    if not saved then return end
    if saved.object then fs:SetFontObject(saved.object) end
    if saved.file then fs:SetFont(saved.file, saved.size, saved.flags) end
    local c = saved.color
    if c and c[1] then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
end

-- Fuente propia para la cuenta atrás del Cooldown Manager (SetCountdownFont necesita un objeto Font)
ns.CDM_FONT_NAME = "RuscuuCDMCountdownFont"
local cdmFont = CreateFont(ns.CDM_FONT_NAME)

local function UpdateCDMFont()
    local db = ns.db
    cdmFont:SetFont(db.font, db.fontSize, ns.OutlineFlags(db.numberOutline))
    if not cdmFont:GetFont() then cdmFont:SetFont(ns.DEFAULT_FONT, db.fontSize, ns.OutlineFlags(db.numberOutline)) end
    local c = db.numberColor
    cdmFont:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

------------------------------------------------------------------------
-- Bordes
------------------------------------------------------------------------

function ns.BorderColor(db)
    if db.borderClassColor then
        local r, g, b = ns.ClassColor()
        return r, g, b, db.borderColor[4] or 1
    end
    local c = db.borderColor
    return c[1], c[2], c[3], c[4] or 1
end

function ns.BarColor(db)
    if db.barClassColor then
        local r, g, b = ns.ClassColor()
        return r, g, b, db.barColor[4] or 1
    end
    local c = db.barColor
    return c[1], c[2], c[3], c[4] or 1
end

function ns.MakeBorder(parent, anchor)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border.anchor = anchor
    return border
end

function ns.LayoutBorder(border, size, r, g, b, a)
    if not size or size <= 0 then
        border:Hide()
        return
    end
    border:SetFrameLevel(border:GetParent():GetFrameLevel() + 2)
    if border.size ~= size then
        border.size = size
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", border.anchor, "TOPLEFT", -size, size)
        border:SetPoint("BOTTOMRIGHT", border.anchor, "BOTTOMRIGHT", size, -size)
        border:SetBackdrop({ edgeFile = WHITE, edgeSize = size })
    end
    border:SetBackdropBorderColor(r, g, b, a)
    border:Show()
end

------------------------------------------------------------------------
-- Piezas de cada item del Cooldown Manager
------------------------------------------------------------------------

-- En los iconos el campo Icon es una textura; en las barras es un frame que contiene la textura
local function IconTexture(item)
    local icon = item.Icon
    if not icon or not icon.IsObjectType then return end
    if icon:IsObjectType("Texture") then return icon end
    local inner = icon.Icon
    if inner and inner.IsObjectType and inner:IsObjectType("Texture") then return inner end
end

-- Frame que contiene la textura del icono (el propio item, o el frame Icon de las barras)
local function IconHolder(item)
    local icon = item.Icon
    if icon and icon.IsObjectType and not icon:IsObjectType("Texture") then return icon end
    return item
end

-- Marco redondo que Blizzard dibuja encima del icono (textura sin nombre)
local function FindOverlay(holder)
    for _, region in ipairs({ holder:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == BLIZZ_OVERLAY_ATLAS then
            return region
        end
    end
end

-- Textos de cargas y acumulaciones
local function CountTexts(item)
    local list = {}
    if item.ChargeCount and item.ChargeCount.Current then list[#list + 1] = item.ChargeCount.Current end
    local apps = item.Applications
    if apps then
        if apps.Applications then
            list[#list + 1] = apps.Applications
        elseif apps.IsObjectType and apps:IsObjectType("FontString") then
            list[#list + 1] = apps
        end
    end
    if item.Icon and not (item.Icon.IsObjectType and item.Icon:IsObjectType("Texture")) and item.Icon.Applications then
        list[#list + 1] = item.Icon.Applications
    end
    return list
end

-- Lee un ajuste de Blizzard solo si no es secreto (para poder restaurarlo después)
local function SafeGet(obj, method)
    if type(obj[method]) ~= "function" then return nil end
    local ok, value = pcall(obj[method], obj)
    if ok and type(value) == "boolean" and not ns.IsSecret(value) then return value end
    return nil
end

local function RestoreMasks(d, tex)
    if d.masksRemoved and d.masks then
        for _, mask in ipairs(d.masks) do tex:AddMaskTexture(mask) end
    end
    d.masksRemoved = false
end

local function SkinIcon(item, d, db)
    local tex = IconTexture(item)
    if not tex then return end
    local holder = IconHolder(item)
    d.tex = tex

    if db.squareIcons then
        if not d.masks then
            d.masks = {}
            for i = 1, (tex:GetNumMaskTextures() or 0) do d.masks[i] = tex:GetMaskTexture(i) end
        end
        if not d.masksRemoved then
            for _, mask in ipairs(d.masks) do tex:RemoveMaskTexture(mask) end
            d.masksRemoved = true
        end
        d.overlay = d.overlay or FindOverlay(holder)
        if d.overlay then d.overlay:SetAlpha(0) end
    else
        RestoreMasks(d, tex)
        if d.overlay then d.overlay:SetAlpha(1) end
    end

    local z = db.iconZoom
    tex:SetTexCoord(z, 1 - z, z, 1 - z)

    d.border = d.border or ns.MakeBorder(holder, tex)
    ns.LayoutBorder(d.border, db.borderSize, ns.BorderColor(db))
end

local function UnskinIcon(item, d)
    local tex = d.tex or IconTexture(item)
    if not tex then return end
    RestoreMasks(d, tex)
    if d.overlay then d.overlay:SetAlpha(1) end
    tex:SetTexCoord(0, 1, 0, 1)
    if d.border then d.border:Hide() end
end

local function SkinCooldown(item, d, db)
    local cd = item.Cooldown
    if not cd then return end
    if d.origEdge == nil then d.origEdge = SafeGet(cd, "GetDrawEdge") end
    if d.origBling == nil then d.origBling = SafeGet(cd, "GetDrawBling") end

    local c = db.swipeColor
    cd:SetDrawSwipe(db.showSwipe)
    cd:SetSwipeTexture(db.squareIcons and WHITE or BLIZZ_SWIPE, c[1], c[2], c[3], c[4] or 1)
    cd:SetSwipeColor(c[1], c[2], c[3], c[4] or 1)

    if db.cooldownEdge == "show" then
        cd:SetDrawEdge(true)
    elseif db.cooldownEdge == "hide" then
        cd:SetDrawEdge(false)
    elseif d.origEdge ~= nil then
        cd:SetDrawEdge(d.origEdge)
    end
    if db.cooldownBling == "show" then
        cd:SetDrawBling(true)
    elseif db.cooldownBling == "hide" then
        cd:SetDrawBling(false)
    elseif d.origBling ~= nil then
        cd:SetDrawBling(d.origBling)
    end

    -- El juego calcula y dibuja los números; el addon solo decide si se muestran y con qué fuente
    cd:SetHideCountdownNumbers(not db.showNumbers)
    cd:SetCountdownFont(ns.CDM_FONT_NAME)
    ns.StyleText(cd:GetCountdownFontString(), db.fontSize, db.numberOutline, db.numberColor)
end

local function UnskinCooldown(item, d)
    local cd = item.Cooldown
    if not cd then return end
    cd:SetDrawSwipe(true)
    cd:SetSwipeTexture(BLIZZ_SWIPE, 0, 0, 0, 0.7)
    cd:SetSwipeColor(0, 0, 0, 0.7)
    if d.origEdge ~= nil then cd:SetDrawEdge(d.origEdge) end
    if d.origBling ~= nil then cd:SetDrawBling(d.origBling) end
    cd:SetHideCountdownNumbers(false)
    cd:SetCountdownFont(item.cooldownFont or BLIZZ_COUNTDOWN_FONT)
    ns.RestoreText(cd:GetCountdownFontString())
end

local function SkinBar(item, d, db)
    local bar = item.Bar
    if not bar or not bar.SetStatusBarTexture then return end
    local path = ns.ResolveBarTexture(db.barTexture)
    if path then
        bar:SetStatusBarTexture(path)
    else
        local t = bar:GetStatusBarTexture()
        if t then t:SetAtlas(BLIZZ_BAR_ATLAS) end
    end
    bar:SetStatusBarColor(ns.BarColor(db))
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if not d.barBg then
        d.barBg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.barBg:SetAllPoints(bar)
    end
    local bg = db.bgColor
    d.barBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    d.barBg:Show()
    d.barBorder = d.barBorder or ns.MakeBorder(bar, bar)
    ns.LayoutBorder(d.barBorder, db.borderSize, ns.BorderColor(db))
    ns.StyleText(bar.Name, db.barTextSize, db.countOutline, nil)
    ns.StyleText(bar.Duration, db.barTextSize, db.countOutline, nil)
end

local function UnskinBar(item, d)
    local bar = item.Bar
    if not bar or not bar.SetStatusBarTexture then return end
    local t = bar:GetStatusBarTexture()
    if t then t:SetAtlas(BLIZZ_BAR_ATLAS) end
    bar:SetStatusBarColor(BLIZZ_BAR_COLOR[1], BLIZZ_BAR_COLOR[2], BLIZZ_BAR_COLOR[3], 1)
    if bar.BarBG then bar.BarBG:SetAlpha(1) end
    if d.barBg then d.barBg:Hide() end
    if d.barBorder then d.barBorder:Hide() end
    ns.RestoreText(bar.Name)
    ns.RestoreText(bar.Duration)
end

local function SkinItem(item, db)
    local d = decor[item]
    if not d then
        d = {}
        decor[item] = d
    end
    d.skinned = true
    SkinIcon(item, d, db)
    SkinCooldown(item, d, db)
    for _, fs in ipairs(CountTexts(item)) do
        ns.StyleText(fs, db.countSize, db.countOutline, db.countUseColor and db.countColor or nil)
    end
    SkinBar(item, d, db)
end

local function UnskinItem(item)
    local d = decor[item]
    if not d or not d.skinned then return end
    d.skinned = false
    UnskinIcon(item, d)
    UnskinCooldown(item, d)
    for _, fs in ipairs(CountTexts(item)) do ns.RestoreText(fs) end
    UnskinBar(item, d)
end

------------------------------------------------------------------------
-- Borde dorado cuando al cooldown le quedan pocos segundos.
-- El addon no puede leer el tiempo restante (es un valor secreto en combate): pide al juego el
-- DurationObject del cooldown y una curva de color decide el color; el addon nunca ve el tiempo.
------------------------------------------------------------------------

local expireCurve
local tracked = {}        -- owner -> { tex, getDuration, border, inner, edges, glow, errors }
local trackedCount = 0
local reads = 0
local testUntil = 0
local testing = false

-- Transparente con 0 s (habilidad lista), del color elegido hasta N s, transparente a partir de ahí
function ns.RebuildExpireCurve()
    expireCurve = nil
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
    local c, s = ns.db.expireColor, ns.db.expireSeconds
    local a = c[4] or 1
    local ok, curve = pcall(function()
        local cv = C_CurveUtil.CreateColorCurve()
        cv:AddPoint(0, CreateColor(c[1], c[2], c[3], 0))
        cv:AddPoint(0.05, CreateColor(c[1], c[2], c[3], a))
        cv:AddPoint(s, CreateColor(c[1], c[2], c[3], a))
        cv:AddPoint(s + 0.05, CreateColor(c[1], c[2], c[3], 0))
        cv:AddPoint(86400, CreateColor(c[1], c[2], c[3], 0))
        return cv
    end)
    if ok then expireCurve = curve end
end

local function SetExpireColor(entry, r, g, b, a)
    for _, edge in ipairs(entry.edges) do edge:SetVertexColor(r, g, b, a) end
    entry.glow:SetVertexColor(r, g, b, a)
end

local function LayoutExpire(entry, owner)
    local db = ns.db
    if not entry.border then
        -- Marco exterior: se muestra u oculta. Marco interior: lleva el pulso (transparencia)
        local f = CreateFrame("Frame", nil, owner)
        local inner = CreateFrame("Frame", nil, f)
        inner:SetAllPoints(f)
        entry.edges = {}
        for i = 1, 4 do
            entry.edges[i] = inner:CreateTexture(nil, "OVERLAY", nil, 7)
            entry.edges[i]:SetTexture(WHITE)
        end
        -- Resplandor suave (el brillo de los botones de Blizzard teñido con el color elegido)
        entry.glow = inner:CreateTexture(nil, "OVERLAY", nil, 6)
        entry.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        entry.glow:SetBlendMode("ADD")
        SetExpireColor(entry, 0, 0, 0, 0)
        f:Hide()
        entry.border, entry.inner = f, inner
    end
    local f, inner = entry.border, entry.inner
    local s = db.expireThickness
    f:SetFrameLevel(owner:GetFrameLevel() + 5)
    inner:SetFrameLevel(f:GetFrameLevel())
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", entry.tex, "TOPLEFT", -s, s)
    f:SetPoint("BOTTOMRIGHT", entry.tex, "BOTTOMRIGHT", s, -s)
    local top, bottom, left, right = unpack(entry.edges)
    for _, edge in ipairs(entry.edges) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(s)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(s)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(s)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(s)

    -- El brillo de Blizzard mide 62 px para un botón de 36: sobresale un 36% del icono por lado
    local size = entry.tex:GetWidth()
    if not size or size <= 0 then size = 36 end
    local glow = math.floor(size * 0.36 * db.expireGlowSize / 100 + 0.5)
    entry.glow:ClearAllPoints()
    entry.glow:SetPoint("TOPLEFT", entry.tex, "TOPLEFT", -glow, glow)
    entry.glow:SetPoint("BOTTOMRIGHT", entry.tex, "BOTTOMRIGHT", glow, -glow)
    entry.glow:SetShown(db.expireGlowShow and glow > 0)
end

-- Registra un frame (icono del Cooldown Manager o botón de acción) para el borde dorado.
-- getDuration devuelve el DurationObject de su cooldown, o nil si no tiene o está excluido.
function ns.TrackExpire(owner, tex, getDuration)
    local entry = tracked[owner]
    if not entry then
        entry = { errors = 0 }
        tracked[owner] = entry
        trackedCount = trackedCount + 1
    end
    entry.tex, entry.getDuration = tex, getDuration
    LayoutExpire(entry, owner)
end

function ns.UntrackExpire(owner)
    local entry = tracked[owner]
    if not entry then return end
    if entry.border then entry.border:Hide() end
    tracked[owner] = nil
    trackedCount = trackedCount - 1
end

local function HideAllExpire()
    for _, entry in pairs(tracked) do entry.border:Hide() end
end

-- Hechizos que el jugador excluyó del borde dorado (se comprueba también por el hechizo base)
function ns.ExpireAllowed(spellID)
    if not spellID or ns.IsSecret(spellID) then return true end
    local exclude = ns.db.expireExclude
    if exclude[spellID] then return false end
    local base = C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)
    if base and not ns.IsSecret(base) and exclude[base] then return false end
    return true
end

local function UpdateEntry(entry)
    local duration = entry.getDuration()
    if not duration then
        entry.border:Hide()
        return
    end
    reads = reads + 1
    local color = duration:EvaluateRemainingDuration(expireCurve)
    SetExpireColor(entry, color:GetRGBA())
    entry.border:Show()
end

-- Un mismo pulso para todos los bordes: así parpadean sincronizados y de forma fluida
local function PulseAlpha(now, db)
    local mode, low = db.expirePulse, db.expirePulseMin
    if mode == "pulse" then
        return low + (1 - low) * (0.5 + 0.5 * math.cos(2 * math.pi * now * db.expirePulseSpeed))
    elseif mode == "flash" then
        return ((now * db.expirePulseSpeed) % 1 < 0.5) and 1 or low
    end
    return 1
end

local function OwnerVisible(owner)
    local visible = owner:IsVisible()
    if ns.IsSecret(visible) then return true end
    return visible
end

local driver = CreateFrame("Frame")
local sinceEval = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    local db = ns.db
    if not db then return end
    local now = GetTime()

    if now < testUntil then
        -- Vista previa: todos los bordes visibles con el color elegido
        testing = true
        local c = db.expireColor
        for owner, entry in pairs(tracked) do
            if OwnerVisible(owner) then
                SetExpireColor(entry, c[1], c[2], c[3], c[4] or 1)
                entry.border:Show()
            else
                entry.border:Hide()
            end
        end
    else
        if testing then
            testing = false
            HideAllExpire()
            sinceEval = 1
        end
        sinceEval = sinceEval + elapsed
        if sinceEval >= 0.1 then
            sinceEval = 0
            if db.expireGlow and expireCurve then
                for owner, entry in pairs(tracked) do
                    if not entry.disabled and OwnerVisible(owner) then
                        if not pcall(UpdateEntry, entry) then
                            -- Un fallo aislado no apaga la función; un frame que falla siempre se ignora
                            entry.errors = entry.errors + 1
                            entry.border:Hide()
                            if entry.errors >= 5 then entry.disabled = true end
                        end
                    else
                        entry.border:Hide()
                    end
                end
            end
        end
    end

    local pulse = PulseAlpha(now, db)
    for _, entry in pairs(tracked) do
        if entry.border:IsShown() then entry.inner:SetAlpha(pulse) end
    end
end)

-- Cooldown de un icono del Cooldown Manager (ignorando el cooldown global).
-- Se usa el hechizo base: el hechizo "actual" puede ser un aura secreta en combate.
local function ViewerItemDuration(item)
    local spellID = item.GetBaseSpellID and item:GetBaseSpellID()
    if not spellID and item.GetSpellID then spellID = item:GetSpellID() end
    if not spellID or ns.IsSecret(spellID) then return end
    if not ns.ExpireAllowed(spellID) then return end
    return C_Spell.GetSpellCooldownDuration(spellID, true)
end

-- Se llama al cambiar las opciones del borde dorado (y al cambiar de perfil)
function ns.UpdateExpire()
    ns.RebuildExpireCurve()
    for owner, entry in pairs(tracked) do
        entry.errors, entry.disabled = 0, nil -- cualquier cambio vuelve a intentarlo
        LayoutExpire(entry, owner)
    end
    if not ns.db.expireGlow then HideAllExpire() end
end

function ns.TestExpire(seconds)
    testUntil = GetTime() + (seconds or 5)
    ns.Print(L["Golden border preview for %d seconds."]:format(seconds or 5), true)
end

function ns.CountExpireTracked() return trackedCount end
function ns.CountExpireReads() return reads end
function ns.IsExpireBroken() return not (C_CurveUtil and C_CurveUtil.CreateColorCurve) end

------------------------------------------------------------------------
-- Visores
------------------------------------------------------------------------

local function ItemFrames(viewer)
    local items = {}
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.Cooldown or child.Bar or child.Icon then
            items[#items + 1] = child
        end
    end
    return items
end

function ns.CountViewerItems(viewer)
    return #ItemFrames(viewer)
end

-- Hechizos de los cooldowns visibles en el Cooldown Manager (para la lista del borde dorado)
function ns.GetViewerSpells()
    local list, seen = {}, {}
    for _, entry in ipairs(ns.VIEWERS) do
        local viewer = entry.cooldowns and _G[entry.frame]
        if viewer then
            for _, item in ipairs(ItemFrames(viewer)) do
                local spellID = item.GetBaseSpellID and item:GetBaseSpellID()
                if spellID and not ns.IsSecret(spellID) and not seen[spellID] then
                    seen[spellID] = true
                    list[#list + 1] = {
                        spellID = spellID,
                        name = C_Spell.GetSpellName(spellID) or ("#" .. spellID),
                        icon = C_Spell.GetSpellTexture(spellID),
                    }
                end
            end
        end
    end
    return list
end

function ns.SkinViewer(entry)
    local db = ns.db
    local viewer = _G[entry.frame]
    if not db or not viewer then return end
    local on = db.enabled[entry.key]
    for _, item in ipairs(ItemFrames(viewer)) do
        if on then SkinItem(item, db) else UnskinItem(item) end
        local tex = IconTexture(item)
        if entry.cooldowns and on and db.expireOnCDM and tex then
            ns.TrackExpire(item, tex, function() return ViewerItemDuration(item) end)
        else
            ns.UntrackExpire(item)
        end
    end
end

function ns.SkinAll()
    if not ns.db then return end
    UpdateCDMFont()
    for _, entry in ipairs(ns.VIEWERS) do
        ns.SkinViewer(entry)
    end
    if ns.RefreshPreviews then ns.RefreshPreviews() end
end

-- Varias llamadas de Blizzard en el mismo instante se agrupan en un solo repaso
local pending, scheduled = {}, false
local function FlushPending()
    scheduled = false
    if not ns.db then return end
    UpdateCDMFont()
    for entry in pairs(pending) do
        pending[entry] = nil
        ns.SkinViewer(entry)
    end
end

local function QueueSkin(entry)
    pending[entry] = true
    if not scheduled then
        scheduled = true
        C_Timer.After(0, FlushPending)
    end
end

-- Se engancha a los métodos con los que Blizzard recoloca o reasigna los iconos
local callbacksRegistered = false
function ns.HookViewers()
    for _, entry in ipairs(ns.VIEWERS) do
        local viewer = _G[entry.frame]
        if viewer and not hookedViewers[viewer] then
            hookedViewers[viewer] = true
            local function queue() QueueSkin(entry) end
            for _, method in ipairs({ "RefreshLayout", "Layout", "RefreshData" }) do
                if type(viewer[method]) == "function" then
                    hooksecurefunc(viewer, method, queue)
                end
            end
            viewer:HookScript("OnShow", queue)
            queue()
        end
    end
    -- Cuando el jugador cambia qué cooldowns se muestran en el panel de Blizzard
    if not callbacksRegistered and EventRegistry and EventRegistry.RegisterCallback then
        callbacksRegistered = true
        local function all()
            for _, entry in ipairs(ns.VIEWERS) do QueueSkin(entry) end
        end
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", all, ns)
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", all, ns)
        EventRegistry:RegisterCallback("EditMode.RefreshCooldownViewer", all, ns)
    end
end

------------------------------------------------------------------------
-- Vista previa para el panel de opciones (frames propios, no de Blizzard)
------------------------------------------------------------------------

local previews = {}
local PREVIEW_ICONS = {
    { icon = "Interface\\Icons\\Spell_Frost_FrostNova", duration = 12, count = "2" },
    { icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", duration = 30 },
    { icon = "Interface\\Icons\\Ability_Warrior_Charge" },
}

-- Muestra cómo quedan los iconos, la barra, los números y el borde dorado con los ajustes actuales
function ns.CreatePreview(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(400, 84)
    p.icons = {}

    -- Título para que quede claro que son elementos de ejemplo, no barras reales
    local caption = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    caption:SetPoint("TOPLEFT", 4, 0)
    caption:SetText(L["Preview (example, not your real bars)"])
    caption:SetTextColor(0.75, 0.75, 0.75)
    for i, info in ipairs(PREVIEW_ICONS) do
        local holder = CreateFrame("Frame", nil, p)
        holder:SetSize(40, 40)
        holder:SetPoint("TOPLEFT", (i - 1) * 52 + 4, -24)
        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(info.icon)
        holder.tex = tex
        holder.border = ns.MakeBorder(holder, tex)
        if info.duration then
            local cd = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
            cd:SetAllPoints(tex)
            holder.cd = cd
            local function restart()
                local start = GetTime()
                if not pcall(cd.SetCooldown, cd, start, info.duration) then cd:Hide() end
                if C_DurationUtil and C_DurationUtil.CreateDuration then
                    holder.durationObject = holder.durationObject or C_DurationUtil.CreateDuration()
                    pcall(holder.durationObject.SetTimeFromStart, holder.durationObject, start, info.duration)
                end
            end
            cd:SetScript("OnCooldownDone", restart)
            restart()
            -- El borde dorado de la vista previa usa el mismo sistema que los botones reales
            ns.TrackExpire(holder, tex, function() return holder.durationObject end)
        end
        if info.count then
            holder.count = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            holder.count:SetPoint("BOTTOMRIGHT", -2, 2)
            holder.count:SetText(info.count)
        end
        p.icons[i] = holder
    end

    local bar = CreateFrame("StatusBar", nil, p)
    bar:SetSize(170, 18)
    bar:SetPoint("TOPLEFT", #PREVIEW_ICONS * 52 + 12, -35)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.65)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.border = ns.MakeBorder(bar, bar)
    bar.name = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bar.name:SetPoint("LEFT", 5, 0)
    bar.name:SetText(L["Example"])
    bar.duration = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bar.duration:SetPoint("RIGHT", -6, 0)
    bar.duration:SetText("8")
    p.bar = bar

    -- La barra de ejemplo se va vaciando y cuenta hacia atrás, como una barra de buff real (12 s en bucle)
    local elapsedSinceUpdate = 0
    p:SetScript("OnUpdate", function(_, elapsed)
        elapsedSinceUpdate = elapsedSinceUpdate + elapsed
        if elapsedSinceUpdate < 0.05 then return end
        elapsedSinceUpdate = 0
        local left = 12 - (GetTime() % 12)
        bar:SetValue(left / 12)
        bar.duration:SetText(("%d"):format(math.ceil(left)))
    end)

    previews[#previews + 1] = p
    ns.RefreshPreview(p)
    return p
end

function ns.RefreshPreview(p)
    local db = ns.db
    if not db then return end
    UpdateCDMFont()
    local r, g, b, a = ns.BorderColor(db)
    for _, holder in ipairs(p.icons) do
        local z = db.iconZoom
        holder.tex:SetTexCoord(z, 1 - z, z, 1 - z)
        ns.LayoutBorder(holder.border, db.borderSize, r, g, b, a)
        if holder.cd then
            local c = db.swipeColor
            holder.cd:SetDrawSwipe(db.showSwipe)
            holder.cd:SetSwipeTexture(WHITE, c[1], c[2], c[3], c[4] or 1)
            holder.cd:SetSwipeColor(c[1], c[2], c[3], c[4] or 1)
            if db.cooldownEdge ~= "blizzard" then holder.cd:SetDrawEdge(db.cooldownEdge == "show") end
            holder.cd:SetHideCountdownNumbers(not db.showNumbers)
            holder.cd:SetCountdownFont(ns.CDM_FONT_NAME)
            ns.StyleText(holder.cd:GetCountdownFontString(), db.fontSize, db.numberOutline, db.numberColor)
        end
        if holder.count then
            ns.StyleText(holder.count, db.countSize, db.countOutline, db.countUseColor and db.countColor or nil)
        end
    end
    local bar = p.bar
    bar:SetStatusBarTexture(ns.ResolveBarTexture(db.barTexture) or WHITE)
    local bg = db.bgColor
    bar:SetStatusBarColor(ns.BarColor(db))
    bar.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    ns.LayoutBorder(bar.border, db.borderSize, r, g, b, a)
    ns.StyleText(bar.name, db.barTextSize, db.countOutline, nil)
    ns.StyleText(bar.duration, db.barTextSize, db.countOutline, nil)
end

function ns.RefreshPreviews()
    for _, p in ipairs(previews) do ns.RefreshPreview(p) end
end
