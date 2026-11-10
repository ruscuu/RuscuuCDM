-- Revisión de la importación: un corte a mitad del último valor también se detecta, lo que el jugador ya
-- ocultaba él mismo no se quita al importar, y borrar el perfil olvida su "deshacer".
package.path = "tests/?.lua;" .. package.path
local M, ns = require("addon_env")("esES")
print = function() end
M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end

ns.CreateProfile("Prueba")
ns.db.iconZoom = 0.2
local text = ns.ExportProfile()
local plain = ns.Base64Decode(text:sub(#"!RUSCUU:1!" + 1))
assert(plain:sub(-1) == ";", "el texto termina en ;")
-- Se quita solo parte del último valor: la cuenta de pares sigue igual, pero falta el ";" final
local cut = plain:sub(1, -3)
local ok, err = ns.ImportProfile("!RUSCUU:1!" .. ns.Base64Encode(cut))
assert(not ok and err == ns.L["The text is incomplete: copy it again."], "corte en el último valor: " .. tostring(err))
assert(ns.ImportProfile(text), "el texto entero se importa")

-- El jugador ocultaba ChatFrame2 él mismo: importar un texto no se lo quita
ns.db.aurasHideFrames = { ChatFrame2 = true }
local own = ns.ExportProfile()
ns.db.aurasHideFrames = { ChatFrame2 = true }
assert(ns.ImportProfile(own), "importa")
assert(ns.db.aurasHideFrames.ChatFrame2, "se conserva lo que ya ocultaba el jugador")

-- Borrar el perfil olvida su deshacer
assert(ns.global.importUndo and ns.global.importUndo.profile == "Prueba")
ns.DeleteProfile("Prueba")
assert(ns.global.importUndo == nil, "deshacer olvidado")
ns.CreateProfile("Prueba")
assert(ns.UndoImport() == nil, "no rellena el perfil nuevo")
io.write("revisión de importación: OK\n")
