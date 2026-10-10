-- Ruscuu Cooldown Manager Forever: aplica el estilo a los visores del Cooldown Manager.
-- Solo cambia la apariencia (texturas, bordes, fuentes); nunca lee datos de combate,
-- así que respeta las restricciones de addons de Forever/Midnight.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"

ns.VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer", label = "Cooldowns esenciales" },
    { key = "utility",   frame = "UtilityCooldownViewer",   label = "Cooldowns de utilidad" },
    { key = "buffIcons", frame = "BuffIconCooldownViewer",  label = "Buffs (iconos)" },
    { key = "buffBars",  frame = "BuffBarCooldownViewer",   label = "Buffs (barras)" },
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
    d.barBg:SetColorTexture(unpack(ns.COLORS.bg))
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
            ns.Print(("%s: encontrado, %d iconos, enganchado=%s"):format(
                entry.frame, #ItemFrames(viewer), tostring(hooked[viewer] == true)))
        else
            ns.Print(entry.frame .. ": |cffff5555no existe|r")
        end
    end
end
