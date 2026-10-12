-- Ruscuu Cooldown Manager Forever: núcleo (datos guardados, valores por defecto, eventos y comandos)
local addonName, ns = ...
local L = ns.L

ns.COLORS = {
    bg = { 0.07, 0.03, 0.12, 0.85 },   -- morado muy oscuro del fondo del logo (interfaz del addon)
    purple = { 0.61, 0.30, 1.00 },     -- morado neón de los ojos y la corona del logo
}

ns.WHITE = "Interface\\Buttons\\WHITE8X8"
ns.DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

------------------------------------------------------------------------
-- Catálogos (fuentes, texturas de barra, contornos)
------------------------------------------------------------------------

-- Fuentes que trae el juego; si hay LibSharedMedia se añaden también las suyas
ns.FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

-- Texturas para las barras de buffs: "blizzard" deja la de Blizzard sin tocar
ns.BAR_TEXTURES = {
    { key = "flat", nameKey = "Flat", path = ns.WHITE },
    { key = "classic", nameKey = "Classic", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "raid", nameKey = "Smooth", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "blizzard", nameKey = "Blizzard (no change)" },
}

-- Contornos de texto: clave guardada -> marcas de SetFont
ns.OUTLINES = {
    { key = "NONE", nameKey = "None", flags = "" },
    { key = "OUTLINE", nameKey = "Outline", flags = "OUTLINE" },
    { key = "THICKOUTLINE", nameKey = "Thick outline", flags = "THICKOUTLINE" },
    { key = "MONOCHROME", nameKey = "Pixel (monochrome)", flags = "MONOCHROME,OUTLINE" },
}

function ns.OutlineFlags(key)
    for _, o in ipairs(ns.OUTLINES) do
        if o.key == key then return o.flags end
    end
    return "OUTLINE"
end

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Lista de fuentes disponibles: { name, path }
function ns.GetFontList()
    local list, seen = {}, {}
    for _, f in ipairs(ns.FONTS) do
        list[#list + 1] = f
        seen[f.path:lower()] = true
    end
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("font")) do
            local path = lsm:Fetch("font", name)
            if type(path) == "string" and not seen[path:lower()] then
                list[#list + 1] = { name = name, path = path }
                seen[path:lower()] = true
            end
        end
    end
    return list
end

function ns.IsKnownFont(path)
    if type(path) ~= "string" then return false end
    if path == ns.DEFAULT_FONT then return true end
    for _, f in ipairs(ns.GetFontList()) do
        if f.path:lower() == path:lower() then return true end
    end
    return false
end

-- Lista de texturas de barra: { key, name, path }
function ns.GetBarTextureList()
    local list = {}
    for _, t in ipairs(ns.BAR_TEXTURES) do
        list[#list + 1] = { key = t.key, name = L[t.nameKey], path = t.path }
    end
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List("statusbar")) do
            list[#list + 1] = { key = "lsm:" .. name, name = name, path = lsm:Fetch("statusbar", name) }
        end
    end
    return list
end

-- Devuelve la ruta de la textura elegida, o nil para dejar la de Blizzard
function ns.ResolveBarTexture(key)
    for _, t in ipairs(ns.GetBarTextureList()) do
        if t.key == key then return t.path end
    end
    return ns.WHITE
end

function ns.IsKnownBarTexture(key)
    for _, t in ipairs(ns.GetBarTextureList()) do
        if t.key == key then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Valores por defecto
------------------------------------------------------------------------

-- Grupos de barras de acción (se usan para elegir a cuáles se aplica el estilo)
ns.ACTION_BARS = {
    { key = "main", prefix = "ActionButton", nameKey = "Main action bar" },
    { key = "bottomLeft", prefix = "MultiBarBottomLeftButton", nameKey = "Action bar 2" },
    { key = "bottomRight", prefix = "MultiBarBottomRightButton", nameKey = "Action bar 3" },
    { key = "right", prefix = "MultiBarRightButton", nameKey = "Action bar 4" },
    { key = "left", prefix = "MultiBarLeftButton", nameKey = "Action bar 5" },
    { key = "bar5", prefix = "MultiBar5Button", nameKey = "Action bar 6" },
    { key = "bar6", prefix = "MultiBar6Button", nameKey = "Action bar 7" },
    { key = "bar7", prefix = "MultiBar7Button", nameKey = "Action bar 8" },
    { key = "pet", prefix = "PetActionButton", nameKey = "Pet bar", noActionSlot = true },
    { key = "stance", prefix = "StanceButton", nameKey = "Stance bar", noActionSlot = true },
    -- Botones de Bartender4, Dominos, ElvUI y otros addons de barras (se buscan aparte, sin prefijo fijo)
    { key = "addons", nameKey = "Bars from other addons", tipKey = "Bartender4, Dominos, ElvUI and other action bar addons." },
}

-- Valores por defecto de cada perfil de estilo (cada clave es una opción del panel)
ns.PROFILE_DEFAULTS = {
    -- Visores del Cooldown Manager a los que se aplica el estilo
    enabled = { essential = true, utility = true, buffIcons = true, buffBars = true },

    -- Iconos del Cooldown Manager
    squareIcons = true,                       -- quitar la máscara y el marco redondo de Blizzard
    iconZoom = 0.08,                          -- recorte de los bordes del dibujo del icono
    borderSize = 1,
    borderColor = { 0.61, 0.30, 1.00, 1 },    -- morado neón (ojos y corona del logo)
    borderClassColor = false,                 -- usar el color de la clase en vez del borde elegido

    -- Barrido del cooldown (la sombra que recorre el icono)
    showSwipe = true,
    swipeColor = { 0, 0, 0, 0.75 },
    cooldownEdge = "blizzard",                -- línea brillante del barrido: blizzard | show | hide
    cooldownBling = "blizzard",               -- destello al terminar: blizzard | show | hide

    -- Barras de buffs
    barTexture = "flat",
    barColor = { 0.55, 0.25, 0.95, 1 },
    barClassColor = false,                    -- usar el color de la clase en vez del color de barra elegido
    bgColor = { 0.07, 0.03, 0.12, 0.85 },

    -- Textos
    font = ns.DEFAULT_FONT,
    showNumbers = true,                       -- números de cuenta atrás en el Cooldown Manager
    fontSize = 14,
    numberOutline = "OUTLINE",
    numberColor = { 0.95, 0.91, 0.84, 1 },    -- blanco crema del texto "RUSCUU" del logo
    countSize = 0,                            -- cargas y acumulaciones; 0 = tamaño de Blizzard
    countOutline = "OUTLINE",
    countUseColor = false,
    countColor = { 1, 1, 1, 1 },
    barTextSize = 0,                          -- nombre y duración de las barras; 0 = tamaño de Blizzard

    -- Atajos de teclado sobre los iconos de cooldowns
    showKeybinds = true,
    keybindSize = 12,
    keybindOutline = "OUTLINE",
    keybindColor = { 0.95, 0.91, 0.84, 1 },
    keybindAnchor = "TOPRIGHT",               -- esquina del icono: TOPLEFT | TOPRIGHT | BOTTOMLEFT | BOTTOMRIGHT

    -- Números de las barras de acción
    styleActionBarNumbers = true,
    actionBarFontSize = 16,
    actionBarNumberOutline = "OUTLINE",
    actionBarNumberColor = { 0.95, 0.91, 0.84, 1 },
    bars = {
        main = true, bottomLeft = true, bottomRight = true, right = true, left = true,
        bar5 = true, bar6 = true, bar7 = true, pet = true, stance = true, addons = true,
    },

    -- Borde dorado cuando un cooldown está terminando
    expireGlow = true,
    expireOnCDM = true,
    expireOnActionBars = true,
    expireSeconds = 3,
    expireColor = { 1, 0.82, 0, 1 },
    expireThickness = 3,
    expireGlowShow = true,                    -- resplandor suave alrededor del botón
    expireGlowSize = 100,                     -- % del tamaño natural del resplandor
    expirePulse = "pulse",                    -- none | pulse | flash
    expirePulseSpeed = 1.2,                   -- parpadeos por segundo
    expirePulseMin = 0.25,                    -- transparencia mínima del parpadeo
    expireExclude = {},                       -- [spellID] = true: hechizos sin borde dorado

    -- Borde en los buffs del Cooldown Manager cuando están a punto de terminar
    -- (usa el grosor, el resplandor y el parpadeo del borde dorado)
    buffEndGlow = false,
    buffEndSeconds = 5,
    buffEndColor = { 1, 0.40, 0.10, 1 },
}

-- Rangos válidos (los usan las opciones y la importación)
ns.LIMITS = {
    iconZoom = { 0, 0.25 },
    borderSize = { 0, 8 },
    fontSize = { 6, 40 },
    countSize = { 0, 32 },
    barTextSize = { 0, 24 },
    keybindSize = { 6, 24 },
    actionBarFontSize = { 6, 40 },
    expireSeconds = { 0.5, 30 },
    expireThickness = { 1, 8 },
    expireGlowSize = { 0, 200 },
    expirePulseSpeed = { 0.2, 5 },
    expirePulseMin = { 0, 0.9 },
    buffEndSeconds = { 1, 60 },
}

-- Valores permitidos para las opciones de lista (los usa la importación)
ns.CHOICES = {
    cooldownEdge = { blizzard = true, show = true, hide = true },
    cooldownBling = { blizzard = true, show = true, hide = true },
    numberOutline = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true },
    countOutline = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true },
    actionBarNumberOutline = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true },
    keybindOutline = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true },
    keybindAnchor = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
    expirePulse = { none = true, pulse = true, flash = true },
}

-- Ajustes de la cuenta (no dependen del perfil)
local GLOBAL_DEFAULTS = {
    language = "auto",               -- auto | en | es
    chatMessages = true,             -- mensajes informativos en el chat
    autoEnableCDM = true,            -- activar el Cooldown Manager de Blizzard la primera vez
    cdmAutoDone = false,             -- ya se activó: a partir de ahí se respeta lo que elija el jugador
    cdmWarned = false,               -- ya se avisó de que no se pudo activar automáticamente
    actionBarNumbersMode = "on",     -- números de Blizzard en las barras: on | off | blizzard (no tocar)
    minimap = { hide = false, angle = 225, lock = false },
    profiles = {},
    chars = {},
}

------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------

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

-- important = true para avisos que se muestran aunque el jugador haya silenciado los mensajes
function ns.Print(msg, important)
    if not important and ns.global and ns.global.chatMessages == false then return end
    print("|cff9b4dffRuscuu CDM|r: " .. msg)
end

function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Color de la clase del personaje
function ns.ClassColor()
    local _, class = UnitClass("player")
    local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if c then return c.r, c.g, c.b end
    c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

------------------------------------------------------------------------
-- Especializaciones. En la API moderna (Forever) las funciones están en C_SpecializationInfo y las
-- globales antiguas pueden no existir. No se redefine ninguna función global de Blizzard: eso
-- "contaminaría" (taint) la interfaz del juego y provocaría errores de acción bloqueada.
------------------------------------------------------------------------

local SpecAPI = C_SpecializationInfo or {}

-- Especialización activa (1, 2, 3...) o nil si el personaje todavía no ha elegido ninguna
function ns.GetSpec()
    local getter = SpecAPI.GetSpecialization or GetSpecialization or GetPrimaryTalentTree
    if not getter then return 1 end
    local ok, spec = pcall(getter)
    if ok and type(spec) == "number" and spec > 0 then return spec end
    return nil
end

function ns.GetNumSpecs()
    if GetNumSpecializations then
        local ok, count = pcall(GetNumSpecializations)
        if ok and type(count) == "number" then return count end
    end
    local _, _, classID = UnitClass("player")
    if classID and SpecAPI.GetNumSpecializationsForClassID then
        local ok, count = pcall(SpecAPI.GetNumSpecializationsForClassID, classID)
        if ok and type(count) == "number" then return count end
    end
    return 0
end

-- Nombre e icono de una especialización del personaje
function ns.GetSpecInfo(index)
    local getter = SpecAPI.GetSpecializationInfo or GetSpecializationInfo
    if getter then
        local ok, _, name, _, icon = pcall(getter, index)
        if ok and name then return name, icon end
    end
    local _, _, classID = UnitClass("player")
    if classID and GetSpecializationInfoForClassID then
        local ok, _, name, _, icon = pcall(GetSpecializationInfoForClassID, classID, index)
        if ok and name then return name, icon end
    end
    return L["Specialization %d"]:format(index), nil
end

------------------------------------------------------------------------
-- Ajustes del juego (CVars)
------------------------------------------------------------------------

-- Números de Blizzard en los botones de acción: solo se toca si el jugador eligió on/off
function ns.ApplyActionBarNumbersMode()
    local mode = ns.global.actionBarNumbersMode
    if mode == "on" then
        SetCVar("countdownForCooldowns", "1")
    elseif mode == "off" then
        SetCVar("countdownForCooldowns", "0")
    end
end

local CDM_CVAR = "cooldownViewerEnabled"

function ns.IsCooldownManagerOn()
    return C_CVar.GetCVar(CDM_CVAR) == "1"
end

-- Lo enciende solo una vez (al instalar o al marcar la opción con force); si el jugador lo apaga
-- después en las opciones de Blizzard, el addon no lo vuelve a encender
function ns.EnableCooldownManager(force)
    if not ns.global.autoEnableCDM then return end
    if ns.global.cdmAutoDone and not force then return end
    local value = C_CVar.GetCVar(CDM_CVAR)
    if value == nil then
        -- Esta versión del juego no tiene ese ajuste: se avisa una sola vez
        if not ns.global.cdmWarned then
            ns.global.cdmWarned = true
            ns.Print(L["Could not enable the Cooldown Manager automatically: enable it in Options > Advanced Options."], true)
        end
        return
    end
    if value ~= "1" then C_CVar.SetCVar(CDM_CVAR, "1") end
    -- Solo se da por hecho si el juego aceptó el cambio (en combate puede rechazarlo)
    if C_CVar.GetCVar(CDM_CVAR) == "1" then
        ns.global.cdmAutoDone = true
        if value ~= "1" then ns.Print(L["Blizzard's Cooldown Manager has been enabled."]) end
    end
end

-- Abre el panel de Blizzard donde se eligen los cooldowns que se muestran
function ns.OpenCooldownSettings()
    if InCombatLockdown() then
        ns.Print(L["Not available in combat."], true)
        return
    end
    if not CooldownViewerSettings then
        ns.Print(L["Blizzard's Cooldown Manager is not loaded."], true)
        return
    end
    if C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable then
        local ok, reason = C_CooldownViewer.IsCooldownViewerAvailable()
        if not ok then
            ns.Print(reason or L["Blizzard's Cooldown Manager is not available."], true)
            return
        end
    end
    if SettingsPanel and SettingsPanel:IsShown() then SettingsPanel:Close(true) end
    ShowUIPanel(CooldownViewerSettings)
end

------------------------------------------------------------------------
-- Migración de datos de versiones anteriores
------------------------------------------------------------------------

-- Las versiones 0.1.x guardaban el estilo directamente en RuscuuCDMDB: se mueve al perfil Default
local function MigrateFlat(db)
    if db.profiles then return end
    local old = {}
    for k in pairs(ns.PROFILE_DEFAULTS) do
        old[k] = db[k]
        db[k] = nil
    end
    old.actionBarNumbers, db.actionBarNumbers = db.actionBarNumbers, nil
    old.expireBlink, db.expireBlink = db.expireBlink, nil
    db.profiles = { Default = old }
end

-- Ajusta un perfil guardado por una versión anterior antes de rellenar los valores que falten
function ns.MigrateProfile(p)
    if p.expireBlink ~= nil then
        if p.expireBlink == false and p.expirePulse == nil then p.expirePulse = "none" end
        p.expireBlink = nil
    end
    -- Antes los números de las barras de acción compartían el color del Cooldown Manager
    if p.actionBarNumberColor == nil and type(p.numberColor) == "table" then
        p.actionBarNumberColor = ns.CopyTable(p.numberColor)
    end
    -- Antes era una opción del perfil; ahora es de la cuenta porque cambia un ajuste del juego
    if p.actionBarNumbers ~= nil then
        if ns.global and ns.global.actionBarNumbersMode == nil then
            ns.global.actionBarNumbersMode = p.actionBarNumbers and "on" or "off"
        end
        p.actionBarNumbers = nil
    end
end

-- Aplica una fuente a un texto; si el juego no la acepta (archivo que ya no existe) usa la del juego
function ns.SetFontSafe(fs, path, size, flags)
    fs:SetFont(path or ns.DEFAULT_FONT, size, flags)
    if not fs:GetFont() then fs:SetFont(ns.DEFAULT_FONT, size, flags) end
end

local function MigrateGlobal(db)
    db.gcdFilter = nil -- el filtro del GCD ya no hace falta: el juego ignora el GCD de forma nativa
    if db.actionBarNumbersMode == nil and db.profiles and db.profiles.Default
        and db.profiles.Default.actionBarNumbers == false then
        db.actionBarNumbersMode = "off"
    end
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
-- El nombre del evento de cambio de especialización varía entre versiones: se registran ambos sin fallar
pcall(events.RegisterEvent, events, "PLAYER_SPECIALIZATION_CHANGED")
pcall(events.RegisterEvent, events, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            RuscuuCDMDB = RuscuuCDMDB or {}
            MigrateFlat(RuscuuCDMDB)
            MigrateGlobal(RuscuuCDMDB)
            ns.ApplyDefaults(RuscuuCDMDB, GLOBAL_DEFAULTS)
            ns.global = RuscuuCDMDB
            ns.SetLanguage(ns.global.language)
            ns.UseProfile("Default") -- provisional hasta conocer la especialización
            ns.CreateMinimapButton()
            ns.RegisterOptions()
        elseif arg1 == "Blizzard_CooldownViewer" and ns.db and IsLoggedIn() then
            ns.HookViewers()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Primero el perfil de la especialización, para no aplicar nunca el de Default por error
        local ok, name = pcall(ns.ProfileForSpec, ns.GetSpec())
        ns.UseProfile(ok and name or "Default")
        ns.EnableCooldownManager()
        ns.ApplyActionBarNumbersMode()
        ns.HookActionBars()
        ns.HookViewers()
        ns.RefreshAll()
        -- Para entonces los addons de minimapa ya decidieron su forma (cuadrada, redonda...)
        ns.UpdateMinimapPosition()
    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
        or (event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player") then
        ns.SelectProfileForSpec()
        C_Timer.After(1, ns.SkinAll)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Al cambiar de zona Blizzard rehace los iconos; los addons de barras pueden crear botones tarde
        C_Timer.After(1, function()
            ns.SkinAll()
            ns.HookActionBars()
        end)
    end
end)

------------------------------------------------------------------------
-- Comandos
------------------------------------------------------------------------

function ns.PrintHelp()
    ns.Print(L["Commands"] .. ":", true)
    print("  /rcm  — " .. L["open options"])
    print("  /rcm cooldowns  — " .. L["choose which cooldowns are shown"])
    print("  /rcm test  — " .. L["preview the golden border for 5 seconds"])
    print("  /rcm skin  — " .. L["reapply the style"])
    print("  /rcm minimap  — " .. L["show or hide the minimap button"])
    print("  /rcm debug  — " .. L["diagnostic information"])
    print("  /rcm reset  — " .. L["reset all settings"])
end

SLASH_RUSCUUCDM1 = "/rcm"
SLASH_RUSCUUCDM2 = "/rcmf"
SlashCmdList.RUSCUUCDM = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        ns.ShowPopup("RUSCUUCDM_RESET_ALL")
    elseif msg == "skin" then
        ns.RefreshAll()
        ns.Print(L["Style reapplied."], true)
    elseif msg == "debug" then
        ns.Debug()
    elseif msg == "test" then
        ns.TestExpire(5)
    elseif msg == "cooldowns" or msg == "cdm" or msg == "spells" then
        ns.OpenCooldownSettings()
    elseif msg == "minimap" then
        ns.SetMinimapShown(ns.global.minimap.hide)
        ns.Print(ns.global.minimap.hide and L["Minimap button hidden."] or L["Minimap button shown."], true)
    elseif msg == "help" or msg == "?" then
        ns.PrintHelp()
    else
        ns.OpenOptions()
    end
end

-- Muestra un diálogo con el texto en el idioma elegido en ese momento (textKey se traduce al abrirlo)
function ns.ShowPopup(which, textArg1, textArg2, data)
    local dialog = StaticPopupDialogs[which]
    if dialog and dialog.textKey then dialog.text = L[dialog.textKey] end
    return StaticPopup_Show(which, textArg1, textArg2, data)
end

-- Borrar toda la configuración pide confirmación; se conserva que el Cooldown Manager ya se activó
StaticPopupDialogs["RUSCUUCDM_RESET_ALL"] = {
    textKey = "Reset ALL Ruscuu CDM settings and profiles? The interface will reload.",
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local keep = RuscuuCDMDB and RuscuuCDMDB.cdmAutoDone
        RuscuuCDMDB = { cdmAutoDone = keep }
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Diagnóstico completo (/rcm debug); los datos también se muestran en la página General
function ns.GetStatus()
    local viewersFound = 0
    for _, entry in ipairs(ns.VIEWERS) do
        if _G[entry.frame] then viewersFound = viewersFound + 1 end
    end
    return {
        viewersFound = viewersFound,
        viewersTotal = #ns.VIEWERS,
        actionCooldowns = ns.CountActionCooldowns(),
        cdmOn = ns.IsCooldownManagerOn(),
        curveAPI = (C_CurveUtil and C_CurveUtil.CreateColorCurve) ~= nil,
        expireTracked = ns.CountExpireTracked(),
        expireReads = ns.CountExpireReads(),
        expireBroken = ns.IsExpireBroken(),
        auraAPI = ns.HasAuraDurationAPI(),
    }
end

function ns.Debug()
    local s = ns.GetStatus()
    local yes, no = L["yes"], L["no"]
    ns.Print(L["Viewers found: %d/%d"]:format(s.viewersFound, s.viewersTotal), true)
    for _, entry in ipairs(ns.VIEWERS) do
        local viewer = _G[entry.frame]
        print(("  %s: %s"):format(entry.frame, viewer and (L["%d icons"]):format(ns.CountViewerItems(viewer)) or L["does not exist"]))
    end
    ns.Print(L["Action bar cooldowns hooked: %d"]:format(s.actionCooldowns), true)
    ns.Print(L["Cooldown Manager enabled: %s"]:format(s.cdmOn and yes or no), true)
    ns.Print(L["Golden border: curve API %s, buttons %d, cooldowns read %d"]:format(
        s.curveAPI and yes or no, s.expireTracked, s.expireReads)
        .. (s.expireBroken and " |cffff5555(" .. L["disabled"] .. ")|r" or ""), true)
    ns.Print(L["Buffs about to end: aura API %s"]:format(s.auraAPI and yes or no), true)
    ns.Print(L["Active profile: %s"]:format(ns.activeProfile), true)
end
