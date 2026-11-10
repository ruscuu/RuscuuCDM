-- Instantáneas: nombres largos en otros alfabetos, textos cortados, icono de las macros con "?",
-- barras de clase al restaurar en otra clase y teclas puestas directamente a botones de addons.
package.path = "tests/?.lua;" .. package.path
local M, ns = require("addon_env")("esES")

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end

------------------------------------------------------------------------
-- Juego simulado (mínimo)
------------------------------------------------------------------------

local slots = {}
local cursor
HasAction = function(slot) if slot > 180 then error("hueco no válido") end return slots[slot] ~= nil end
GetActionInfo = function(slot)
    local a = slots[slot]
    if a then return a.kind, a.id, "spell" end
end
GetActionText = function() return nil end
GetCursorInfo = function() return cursor and cursor.kind end
ClearCursor = function() cursor = nil end
PickupAction = function(slot) cursor, slots[slot] = slots[slot], cursor end
PlaceAction = function(slot) cursor, slots[slot] = slots[slot], cursor end
C_Spell.PickupSpell = function(id) cursor = { kind = "spell", id = id } end

-- Una macro con el icono "?": GetMacroInfo da el icono del hechizo que muestra, C_Macro el guardado
local QUESTION = 134400
local macros = { { name = "Bloque", icon = QUESTION, shown = 555, body = "/cast [mod:shift] Bloque; Nova" } }
GetMacroIndexByName = function(name)
    for i, m in ipairs(macros) do if m.name == name then return i end end
    return 0
end
GetNumMacros = function() return #macros, 0 end
GetMacroInfo = function(nameOrIndex)
    local m = macros[type(nameOrIndex) == "number" and nameOrIndex or GetMacroIndexByName(nameOrIndex)]
    if m then return m.name, m.shown or m.icon, m.body end
end
C_Macro = { GetSelectedMacroIcon = function(index) return macros[index] and macros[index].icon end }
local edits = 0
EditMacro = function(index, name, icon, body)
    edits = edits + 1
    macros[index] = { name = name, icon = icon, body = body, shown = icon == QUESTION and 555 or nil }
    return index
end
CreateMacro = function(name, icon, body)
    macros[#macros + 1] = { name = name, icon = icon, body = body, shown = icon == QUESTION and 555 or nil }
    return #macros
end

-- Teclas: una del juego (lista de GetBinding) y otra puesta a un botón de Bartender (solo GetBindingAction)
local keys = { W = "MOVEFORWARD", ["SHIFT-5"] = "CLICK BT4Button25:Keybind", ["ALT-F1"] = "SPELL Nova" }
GetNumBindings = function() return 1 end
GetBinding = function()
    local list = {}
    for key, command in pairs(keys) do if command == "MOVEFORWARD" then list[#list + 1] = key end end
    return "MOVEFORWARD", "Movimiento", unpack(list)
end
GetBindingAction = function(key) return keys[key] or "" end
SetBinding = function(key, command) keys[key] = command; return true end
SaveBindings = function() end

-- strlenutf8 del juego: cuenta letras, no bytes
strlenutf8 = function(text)
    local _, n = text:gsub("[^\128-\191]", "")
    return n
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

------------------------------------------------------------------------
-- Nombres largos en ruso: se conservan al exportar e importar todo
------------------------------------------------------------------------

slots[1] = { kind = "spell", id = 100 }
local longA = ("Ж"):rep(35) .. " A"     -- 37 letras, 72 bytes
local longB = ("Ж"):rep(35) .. " B"
assert(ns.SaveSnapshot(longA) and ns.SaveSnapshot(longB), "se guardan")
ns.global.snapshots[ns.L["Imported"]] = { actions = { { t = "spell", id = 1 } }, macros = {}, bindings = {} }
local everything = ns.ExportAll()
ns.global.snapshots = {}
local okAll, nSnap = ns.ImportAll(everything)
assert(okAll and nSnap == 3, "importar todo")
assert(ns.GetSnapshot(longA) and ns.GetSnapshot(longB), "los nombres largos en ruso se conservan")
assert(count(ns.global.snapshots) == 3, "no se pierde ninguna: " .. count(ns.global.snapshots))

-- Un texto sin nombre no sustituye a otra instantánea, ni siquiera al importar todo
local function encode(lines) return "!RUSCUUUI:1!" .. ns.Base64Encode(table.concat(lines, "\n")) end
local nameless = encode({ "A\t1\tspell\t100\t" })
local all = "!RUSCUUALL:1!" .. ns.Base64Encode("S\t" .. nameless .. "\nS\t" .. nameless)
assert(ns.ImportAll(all), "importa los textos sin nombre")
assert(count(ns.global.snapshots) == 5, "cada texto sin nombre es una instantánea nueva: " .. count(ns.global.snapshots))

------------------------------------------------------------------------
-- Textos cortados: se rechazan
------------------------------------------------------------------------

local text = ns.ExportSnapshot(longA)
assert(ns.ParseSnapshot(text), "el texto completo se lee")
for cut = #text - 1, 13, -1 do
    assert(not ns.ParseSnapshot(text:sub(1, cut)), "texto cortado en " .. cut .. " aceptado")
end
-- Un texto cortado del formato 1 (sin la línea final) con un número de caracteres que no es múltiplo de 4
local old = encode({ "N\tViejo", "A\t1\tspell\t12345\t" })
assert(ns.ParseSnapshot(old), "el formato 1 completo se sigue leyendo")
assert(not ns.ParseSnapshot(old:sub(1, #old - 1)), "formato 1 cortado")
-- La línea del diseño tiene que poder leerla el Modo Edición
C_EditMode = { ConvertStringToLayoutInfo = function() return nil end }
local _, withBadLayout = ns.ParseSnapshot(encode({ "N\tX", "E\tAAAA", "A\t1\tspell\t1\t" }))
assert(withBadLayout.layout == nil, "un diseño que el juego no entiende se descarta")
C_EditMode = nil

------------------------------------------------------------------------
-- Macros con "?": se guarda el icono "?" y no el del hechizo
------------------------------------------------------------------------

ns.SaveSnapshot("Macros")
assert(ns.GetSnapshot("Macros").macros.Bloque.icon == QUESTION, "icono guardado: " .. tostring(ns.GetSnapshot("Macros").macros.Bloque.icon))
edits = 0
ns.RestoreSnapshot("Macros", { macros = true })
assert(edits == 0, "una macro sin cambios no se edita (antes se comparaba el icono mostrado)")
macros = {}
ns.RestoreSnapshot("Macros", { macros = true })
assert(macros[1].icon == QUESTION, "la macro se crea con el icono ?, no con el del hechizo")
-- Instantánea antigua (guardaba el icono mostrado): no deja fija la macro con el icono del hechizo
ns.GetSnapshot("Macros").macros.Bloque.icon = 555
edits = 0
ns.RestoreSnapshot("Macros", { macros = true })
assert(edits == 0 and macros[1].icon == QUESTION, "instantánea antigua: la macro con ? no se toca")
ns.GetSnapshot("Macros").macros.Bloque.body = "/cast Nova"
ns.RestoreSnapshot("Macros", { macros = true })
assert(macros[1].body == "/cast Nova" and macros[1].icon == QUESTION, "al cambiar el texto se conserva el ?")

------------------------------------------------------------------------
-- Teclas puestas a botones de addons, hechizos y macros
------------------------------------------------------------------------

ns.SaveSnapshot("Teclas")
local saved = {}
for _, pair in ipairs(ns.GetSnapshot("Teclas").bindings) do saved[pair[2]] = pair[1] end
assert(saved["SHIFT-5"] == "CLICK BT4Button25:Keybind" and saved["ALT-F1"] == "SPELL Nova", "se guardan")
assert(saved.W == "MOVEFORWARD" and count(saved) == 3, "sin repetir las del juego")
keys = { W = "MOVEFORWARD", ["CTRL-Q"] = "CLICK Otro:LeftButton" }
ns.RestoreSnapshot("Teclas", { bindings = true })
assert(keys["SHIFT-5"] == "CLICK BT4Button25:Keybind" and keys["ALT-F1"] == "SPELL Nova", "se restauran")
assert(keys["CTRL-Q"] == nil, "y las que no estaban se quitan")

------------------------------------------------------------------------
-- Restaurar en otra clase: las barras de clase (huecos 73 a 120) no se tocan
------------------------------------------------------------------------

slots = { [1] = { kind = "spell", id = 100 } }
ns.SaveSnapshot("Guerrero")
ns.GetSnapshot("Guerrero").class = "WARRIOR"
slots = { [1] = { kind = "spell", id = 7 }, [80] = { kind = "spell", id = 300 }, [130] = { kind = "spell", id = 9 } }
local printed = {}
local realPrint = print
print = function(msg) printed[#printed + 1] = msg end
local report = ns.RestoreSnapshot("Guerrero", { actions = true })
print = realPrint
assert(slots[1].id == 100 and slots[130] == nil, "el resto de huecos se restaura")
assert(slots[80] and slots[80].id == 300, "la barra de forma felina del druida no se vacía")
assert(report.classBarsSkipped and #printed == 1, "se avisa una vez")
-- Misma clase: se restauran también
ns.GetSnapshot("Guerrero").class = "DRUID"
report = ns.RestoreSnapshot("Guerrero", { actions = true })
assert(slots[80] == nil and not report.classBarsSkipped, "con la misma clase se restauran todas")

-- La clase viaja en el texto exportado
local _, copy = ns.ParseSnapshot(ns.ExportSnapshot("Guerrero"))
assert(copy.class == "DRUID", "clase exportada")
print("instantáneas, importar y restaurar: OK")
