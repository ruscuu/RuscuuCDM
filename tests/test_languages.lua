-- Idiomas: se elige el del juego o el de las opciones, y los textos con formato funcionan en todos
local ns, client = {}, "enUS"
GetLocale = function() return client end
for _, path in ipairs({ "Locales.lua", "Locales/esES.lua", "Locales/deDE.lua", "Locales/frFR.lua", "Locales/ptBR.lua", "Locales/ruRU.lua" }) do
    assert(loadfile(path))("RuscuuCDM", ns)
end
local L = ns.L

-- Antes de elegir idioma, y con frases o idiomas desconocidos, se usa el inglés
assert(L["Square icons"] == "Square icons", "antes de SetLanguage")
assert(L["clave inexistente"] == "clave inexistente", "frase sin traducción")
ns.SetLanguage("xx"); assert(L["Square icons"] == "Square icons", "idioma desconocido")

-- Cada idioma de la lista de opciones
local expected = {
    en = "Square icons", es = "Iconos cuadrados", de = "Quadratische Symbole",
    fr = "Icônes carrées", pt = "Ícones quadrados", ru = "Квадратные значки",
}
for _, lang in ipairs(ns.LANGUAGES) do
    ns.SetLanguage(lang.code)
    assert(L["Square icons"] == expected[lang.code], lang.code .. ": " .. L["Square icons"])
    assert(L["Active profile: %s"]:format("X"):find("X"), lang.code .. ": formato %s")
    assert(L["Viewers found: %d/%d"]:format(3, 4):find("3/4"), lang.code .. ": formato %d/%d")
end

-- "Automático" sigue el idioma del cliente
local byClient = {
    deDE = "Quadratische Symbole", frFR = "Icônes carrées", ptBR = "Ícones quadrados", ptPT = "Ícones quadrados",
    ruRU = "Квадратные значки", esES = "Iconos cuadrados", esMX = "Iconos cuadrados", koKR = "Square icons",
}
for clientLocale, text in pairs(byClient) do
    client = clientLocale
    ns.SetLanguage("auto")
    assert(L["Square icons"] == text, clientLocale)
end
print("idiomas: OK")
