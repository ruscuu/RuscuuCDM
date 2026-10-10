-- Ruscuu Cooldown Manager Forever: núcleo (datos guardados, eventos y comandos)
local addonName, ns = ...
local L = ns.L

ns.COLORS = {
    bg = { 0.07, 0.03, 0.12, 0.85 },   -- morado muy oscuro del fondo del logo (para la interfaz del addon)
}

-- Valores por defecto de cada perfil de estilo
ns.PROFILE_DEFAULTS = {
    enabled = { essential = true, utility = true, buffIcons = true, buffBars = true },
    borderSize = 1,
    iconZoom = 0.08,
    fontSize = 14,
    font = "Fonts\\FRIZQT__.TTF",
    borderColor = { 0.61, 0.30, 1.00, 1 }, -- morado neón (ojos y corona del logo)
    barColor = { 0.55, 0.25, 0.95, 1 },
    bgColor = { 0.07, 0.03, 0.12, 0.85 },
    showNumbers = true,       -- números de cuenta atrás en el Cooldown Manager
    actionBarNumbers = true,  -- números de cuenta atrás en las barras de acción
    styleActionBarNumbers = true,
    actionBarFontSize = 16,
    numberColor = { 0.95, 0.91, 0.84, 1 }, -- blanco crema del texto "RUSCUU" del logo
}

-- Rangos válidos (los usan las opciones y la importación)
ns.LIMITS = {
    borderSize = { 0, 4 },
    iconZoom = { 0, 0.15 },
    fontSize = { 8, 24 },
    actionBarFontSize = { 8, 30 },
}

local GLOBAL_DEFAULTS = {
    autoEnableCDM = true,  -- activar el Cooldown Manager de Blizzard al entrar
    cdmWarned = false,     -- ya se avisó de que no se pudo activar automáticamente
    minimap = { hide = false, angle = 225 },
    profiles = {},
    chars = {},
}

-- Rellena los valores que falten sin pisar los que el jugador ya cambió
function ns.ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ns.ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.CopyTable(src)
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = type(v) == "table" and ns.CopyTable(v) or v
    end
    return copy
end

function ns.Print(msg)
    print("|cff9b4dffRuscuu CDM|r: " .. msg)
end

-- Opción nativa de WoW que dibuja los segundos restantes en los botones de acción
function ns.ApplyActionBarNumbers()
    SetCVar("countdownForCooldowns", ns.db.actionBarNumbers and "1" or "0")
end

-- Ajuste del juego que enciende el Cooldown Manager (Opciones > Opciones avanzadas)
local CDM_CVAR = "cooldownViewerEnabled"

-- Solo lo enciende; si el jugador desactiva la opción, el addon deja de tocarlo
function ns.EnableCooldownManager()
    if not ns.global.autoEnableCDM then return end
    local value = C_CVar.GetCVar(CDM_CVAR)
    if value == nil then
        -- Esta versión del juego no tiene ese ajuste: se avisa una sola vez
        if not ns.global.cdmWarned then
            ns.global.cdmWarned = true
            ns.Print(L["Could not enable the Cooldown Manager automatically: enable it in Options > Advanced Options."])
        end
    elseif value ~= "1" then
        C_CVar.SetCVar(CDM_CVAR, "1")
        ns.Print(L["Blizzard's Cooldown Manager has been enabled."])
    end
end

function ns.DebugCooldownManager()
    ns.Print(L["Cooldown Manager setting (%s): %s"]:format(CDM_CVAR, tostring(C_CVar.GetCVar(CDM_CVAR))))
end

-- Las versiones 0.1.x guardaban el estilo directamente en RuscuuCDMDB: se mueve al perfil Default
local function Migrate(db)
    if db.profiles then return end
    local old = {}
    for k in pairs(ns.PROFILE_DEFAULTS) do
        old[k] = db[k]
        db[k] = nil
    end
    db.profiles = { Default = old }
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            RuscuuCDMDB = RuscuuCDMDB or {}
            Migrate(RuscuuCDMDB)
            ns.ApplyDefaults(RuscuuCDMDB, GLOBAL_DEFAULTS)
            ns.global = RuscuuCDMDB
            ns.UseProfile("Default") -- provisional hasta conocer la especialización
            ns.CreateMinimapButton()
            ns.RegisterOptions()
        elseif arg1 == "Blizzard_CooldownViewer" and ns.db then
            ns.HookViewers()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Primero los enganches, para que un fallo al cargar el perfil no los deje sin hacer
        ns.EnableCooldownManager()
        ns.HookActionBars()
        ns.HookViewers()
        ns.SetProfile(ns.ProfileForSpec(GetSpecialization()))
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        ns.SelectProfileForSpec()
        C_Timer.After(1, ns.SkinAll)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Al cambiar de zona Blizzard rehace los iconos
        C_Timer.After(1, ns.SkinAll)
    end
end)

SLASH_RUSCUUCDM1 = "/ruscuu"
SLASH_RUSCUUCDM2 = "/rcdm"
SlashCmdList.RUSCUUCDM = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        RuscuuCDMDB = nil
        ReloadUI()
    elseif msg == "skin" then
        ns.SkinAll()
        ns.Print(L["Style reapplied."])
    elseif msg == "debug" then
        ns.Debug()
        ns.DebugActionBars()
        ns.DebugCooldownManager()
        ns.Print(L["Active profile: %s"]:format(ns.activeProfile))
    elseif msg == "minimap" then
        ns.SetMinimapShown(ns.global.minimap.hide)
        ns.Print(ns.global.minimap.hide and L["Minimap button hidden."] or L["Minimap button shown."])
    else
        ns.OpenOptions()
    end
end
