-- Cada clase tiene su propio perfil: los hechizos elegidos con un personaje no salen en los de otra clase.
-- Antes todos los personajes usaban Default y se mezclaban los iconos.
package.path = "tests/?.lua;" .. package.path
local M, ns = require("addon_env")("esES")

-- Datos de una versión anterior: el druida eligió hechizos en Default (100 es suyo, 555 de otra clase)
RuscuuCDMDB = {
    profiles = { Default = { activeAdd = { [100] = true, [555] = true }, activeOrder = { "spell555", "spell100", "item5" },
        activeSound = { spell555 = true, spell100 = true }, activeItems = { [5] = true }, iconZoom = 0.2 } },
    chars = { ["Alma-Reino"] = { specs = { [2] = "Default" } } },
}
local knownSpells = { [100] = true }
IsPlayerSpell = function(id) return knownSpells[id] == true end

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("PLAYER_ENTERING_WORLD")
for _ = 1, 3 do M.RunTimers() end

-- El druida pasa a su perfil de clase: conserva su aspecto y sus hechizos, sin los de otras clases
assert(ns.activeProfile == "Druida", "perfil de la clase: " .. ns.activeProfile)
assert(ns.global.classProfiles.DRUID == "Druida", "se recuerda el perfil de la clase")
assert(ns.db.iconZoom == 0.2, "se copia el aspecto de Default")
assert(ns.db.activeAdd[100] and not ns.db.activeAdd[555], "solo los hechizos que conoce")
assert(table.concat(ns.db.activeOrder, " ") == "spell100 item5", "orden: " .. table.concat(ns.db.activeOrder, " "))
assert(ns.db.activeSound.spell100 and not ns.db.activeSound.spell555, "sonidos solo de sus hechizos")
assert(ns.db.activeItems[5], "los objetos se conservan")
assert(ns.global.profiles.Default.activeAdd[555], "Default no se toca")

-- Aunque un perfil se comparta a propósito, un hechizo que el personaje no conoce no sale en la barra
ns.SetProfile("Default")
local keys = {}
for _, e in ipairs(ns.GetActiveEntryList()) do keys[#keys + 1] = e.key end
assert(table.concat(keys, " ") == "spell100 item5", "barra con Default: " .. table.concat(keys, " "))
-- Elegir Default a mano después de la migración se respeta
ns.ChooseProfile("Default")
assert(ns.ProfileForSpec(2) == "Default", "Default elegido a mano")
ns.ChooseProfile("Druida")

-- Otro personaje de otra clase en la misma cuenta: perfil propio, sin los hechizos del druida
UnitName = function() return "Beto" end
UnitClass = function() return "Sacerdote", "PRIEST", 5 end
knownSpells = { [555] = true }
ns.SelectProfileForSpec()
assert(ns.activeProfile == "Sacerdote", "perfil del sacerdote: " .. ns.activeProfile)
assert(ns.db.activeAdd[555] and not ns.db.activeAdd[100], "hechizos del sacerdote")
ns.db.activeAdd[777] = true
assert(not ns.global.profiles.Druida.activeAdd[777], "lo que elige el sacerdote no llega al druida")

-- Renombrar o borrar el perfil de la clase mantiene el registro al día
ns.RenameProfile("Sacerdote", "Mi sacerdote")
assert(ns.global.classProfiles.PRIEST == "Mi sacerdote", "renombrado")
assert(ns.ProfileForSpec(2) == "Mi sacerdote", "la especialización sigue en el perfil renombrado")
ns.DeleteProfile("Mi sacerdote")
assert(ns.global.classProfiles.PRIEST == nil and ns.activeProfile == "Default", "borrado")

-- Si el juego no deja saber qué hechizos conoce, no se quita nada
IsPlayerSpell = nil
assert(ns.PlayerKnowsSpell(555) == nil, "sin datos del juego")

print("perfiles por clase: OK")
