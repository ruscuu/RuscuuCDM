-- Ruscuu Cooldown Manager Forever: idiomas.
-- Las claves están en inglés (idioma por defecto) y cada archivo de Locales/ añade un idioma;
-- si falta una traducción se muestra la clave en inglés.
-- El idioma se decide en cada consulta, así se puede elegir en las opciones sin tocar el resto del código.
local _, ns = ...

local tables = {}   -- código del addon ("es", "de"...) -> traducciones
local current       -- traducciones del idioma activo; nil = inglés

-- Idioma del cliente del juego -> código del addon
local CLIENT_LANGUAGE = {
    esES = "es", esMX = "es",
    deDE = "de",
    frFR = "fr",
    ptBR = "pt", ptPT = "pt",
    ruRU = "ru",
}

-- Idiomas que se pueden elegir en las opciones (además de "Automático"), en el orden del desplegable
ns.LANGUAGES = {
    { code = "en", name = "English" },
    { code = "es", name = "Español" },
    { code = "de", name = "Deutsch" },
    { code = "fr", name = "Français" },
    { code = "pt", name = "Português" },
    { code = "ru", name = "Русский" },
}

-- Lo usa cada archivo de Locales/ para registrar sus traducciones
function ns.NewLocale(code)
    tables[code] = tables[code] or {}
    return tables[code]
end

-- lang: "auto" (idioma del juego) o uno de los códigos de ns.LANGUAGES
function ns.SetLanguage(lang)
    if lang == nil or lang == "auto" then lang = CLIENT_LANGUAGE[GetLocale()] end
    current = lang and tables[lang] or nil
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        return current and current[key] or key
    end,
})
