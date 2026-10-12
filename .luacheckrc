-- Configuración de luacheck: detecta errores (variables mal escritas, globales inesperadas) sin abrir el juego.
-- Si el addon empieza a usar una función nueva de la API de WoW, añádela a read_globals.
std = "lua51"
max_line_length = false
self = false -- no avisar de "self" sin usar en métodos

-- Globales que el addon crea o modifica
globals = {
    "RuscuuCDMDB",
    "SLASH_RUSCUUCDM1",
    "SLASH_RUSCUUCDM2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "RuscuuCDM_OnAddonCompartmentClick",
    "RuscuuCDM_OnAddonCompartmentEnter",
    "RuscuuCDM_OnAddonCompartmentLeave",
}

-- API de World of Warcraft que el addon solo lee
read_globals = {
    -- Lua de WoW
    "strsplit", "strtrim", "wipe", "tinsert",

    -- Espacios de nombres C_*
    "C_ActionBar", "C_ClassColor", "C_CooldownViewer", "C_CurveUtil", "C_CVar", "C_DurationUtil",
    "C_SpecializationInfo", "C_Spell", "C_Timer", "C_UnitAuras",

    -- Funciones
    "CreateColor", "CreateFont", "CreateFrame", "GetActionInfo", "GetBindingKey", "GetBindingText",
    "GetCursorPosition", "GetInventoryItemCooldown", "GetLocale", "GetMinimapShape", "GetNumSpecializations", "GetPrimaryTalentTree",
    "GetRealmName", "geterrorhandler", "GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoForClassID",
    "GetTime", "HasAction", "hooksecurefunc", "InCombatLockdown", "IsLoggedIn", "IsShiftKeyDown",
    "issecretvalue", "LibStub", "PlaySound", "ReloadUI", "SetCVar", "ShowUIPanel", "StaticPopup_Show",
    "UnitClass", "UnitName",

    -- Frames, objetos y constantes de Blizzard
    "ActionBarButtonEventsFrame", "ChatFontNormal", "ColorPickerFrame", "CooldownViewerSettings",
    "EditModeManagerFrame", "EventRegistry", "GameTooltip", "Minimap", "SettingsPanel", "Settings", "UIParent", "UISpecialFrames",
    "ACCEPT", "CANCEL", "NO", "YES", "RAID_CLASS_COLORS", "RANGE_INDICATOR", "SOUNDKIT", "STANDARD_TEXT_FONT",
}

-- Pruebas: el simulador crea y sustituye globales del juego a propósito
files["tests"] = { ignore = { "1" } }
