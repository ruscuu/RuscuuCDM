-- Ruscuu Cooldown Manager Forever: números de cooldown y borde dorado en las barras de acción.
-- Solo cambia fuente, tamaño y color del texto que dibuja el juego; nunca lee el tiempo restante.
-- Al desactivarlo se restaura la fuente original de Blizzard sin recargar.
local _, ns = ...
local L = ns.L

local FONT_NAME = "RuscuuCDMActionFont"
local actionFont = CreateFont(FONT_NAME)

-- Métodos con los que el juego arranca un cooldown; tras cada uno se reaplica la fuente
local START_METHODS = { "SetCooldown", "SetCooldownDuration", "SetCooldownFromDurationObject", "SetCooldownUNIX" }

local buttons = {}                                       -- cooldown -> { button, bar }
local hookedCount = 0
local original = setmetatable({}, { __mode = "k" })     -- cooldown -> fuente original de Blizzard
local styled = setmetatable({}, { __mode = "k" })       -- cooldown -> versión del estilo aplicada
local version = 0

local function BarEnabled(barKey)
    return ns.db.bars[barKey] ~= false
end

local function UpdateFont()
    local db = ns.db
    local flags = ns.OutlineFlags(db.actionBarNumberOutline)
    actionFont:SetFont(db.font, db.actionBarFontSize, flags)
    if not actionFont:GetFont() then actionFont:SetFont(ns.DEFAULT_FONT, db.actionBarFontSize, flags) end
    local c = db.actionBarNumberColor
    actionFont:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- Guarda la fuente de Blizzard antes de cambiarla por primera vez
local function SaveOriginal(cd)
    if original[cd] then return end
    local info = {}
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then
        local fontObject = fs:GetFontObject()
        info.fontName = fontObject and fontObject.GetName and fontObject:GetName()
        info.file, info.size, info.flags = fs:GetFont()
        info.color = { fs:GetTextColor() }
    end
    original[cd] = info
end

local function Restore(cd)
    local info = original[cd]
    styled[cd] = nil
    if not info then return end
    if info.fontName and info.fontName ~= FONT_NAME then cd:SetCountdownFont(info.fontName) end
    local fs = cd:GetCountdownFontString()
    if fs and info.file then fs:SetFont(info.file, info.size, info.flags) end
    if fs and info.color and info.color[1] then fs:SetTextColor(unpack(info.color)) end
end

local function Style(cd)
    local db = ns.db
    local info = buttons[cd]
    if not db or not info then return end
    if not db.styleActionBarNumbers or not BarEnabled(info.bar) then
        if styled[cd] then Restore(cd) end
        return
    end
    SaveOriginal(cd)
    cd:SetCountdownFont(FONT_NAME)
    -- El texto ya creado se ajusta una sola vez por cambio de opciones (no en cada cooldown)
    if styled[cd] ~= version then
        styled[cd] = version
        local fs = cd:GetCountdownFontString()
        if fs then
            ns.SetFontSafe(fs, db.font, db.actionBarFontSize, ns.OutlineFlags(db.actionBarNumberOutline))
            local c = db.actionBarNumberColor
            fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        end
    end
end

------------------------------------------------------------------------
-- Borde dorado en los botones de acción
------------------------------------------------------------------------

local function ActionSlot(button)
    local action = button.action
    if not action and button.CalculateAction then action = button:CalculateAction() end
    if type(action) ~= "number" or action <= 0 then return end
    return action
end

-- Hechizo que hay en un hueco de acción (también en macros y objetos con hechizo)
local function ActionSpellID(action)
    local kind, id, subType = GetActionInfo(action)
    if ns.IsSecret(kind) or ns.IsSecret(id) then return end
    if kind == "spell" then return id end
    if kind == "macro" and subType == "spell" then return id end
    if kind == "item" and C_ActionBar and C_ActionBar.GetSpell then
        local spellID = C_ActionBar.GetSpell(action)
        if spellID and not ns.IsSecret(spellID) and spellID > 0 then return spellID end
    end
end

-- Cooldown del hueco de acción del botón (ignorando el cooldown global)
local function ButtonDuration(button)
    local action = ActionSlot(button)
    if not action or not HasAction(action) then return end
    if not ns.ExpireAllowed(ActionSpellID(action)) then return end
    return C_ActionBar.GetActionCooldownDuration(action, true)
end

local function UpdateExpireTracking()
    local db = ns.db
    local canTrack = C_ActionBar and C_ActionBar.GetActionCooldownDuration
    for _, info in pairs(buttons) do
        local button = info.button
        local icon = button.icon or button.Icon
        if canTrack and icon and not info.noActionSlot and db.expireOnActionBars and BarEnabled(info.bar) then
            ns.TrackExpire(button, icon, function() return ButtonDuration(button) end)
        else
            ns.UntrackExpire(button)
        end
    end
end

------------------------------------------------------------------------
-- Enganches
------------------------------------------------------------------------

function ns.StyleActionBars()
    if not ns.db then return end
    version = version + 1
    UpdateFont()
    for cd in pairs(buttons) do Style(cd) end
    UpdateExpireTracking()
end

function ns.HookActionBars()
    for _, group in ipairs(ns.ACTION_BARS) do
        for i = 1, 12 do
            local button = _G[group.prefix .. i]
            local cd = button and (button.cooldown or button.Cooldown)
            if cd and not buttons[cd] then
                buttons[cd] = { button = button, bar = group.key, noActionSlot = group.noActionSlot }
                hookedCount = hookedCount + 1
                -- El texto de la cuenta atrás puede crearse al empezar el primer cooldown
                cd:HookScript("OnShow", Style)
                for _, method in ipairs(START_METHODS) do
                    if type(cd[method]) == "function" then
                        hooksecurefunc(cd, method, Style)
                    end
                end
            end
        end
    end
    ns.StyleActionBars()
end

function ns.CountActionCooldowns()
    return hookedCount
end

-- Hechizos de las barras de acción (para la lista de exclusión del borde dorado)
function ns.GetActionBarSpells()
    local list, seen = {}, {}
    for _, info in pairs(buttons) do
        local action = not info.noActionSlot and ActionSlot(info.button)
        local spellID = action and HasAction(action) and ActionSpellID(action)
        if spellID then
            local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID) or spellID
            if ns.IsSecret(base) then base = spellID end
            if not seen[base] then
                seen[base] = true
                list[#list + 1] = {
                    spellID = base,
                    name = C_Spell.GetSpellName(base) or ("#" .. base),
                    icon = C_Spell.GetSpellTexture(base),
                }
            end
        end
    end
    return list
end
