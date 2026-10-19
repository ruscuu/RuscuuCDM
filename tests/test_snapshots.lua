-- Instantáneas de la interfaz: guardar y restaurar posiciones (Modo Edición), teclas y barras de acción,
-- exportarlas como texto y rechazar textos manipulados.
package.path = "tests/?.lua;" .. package.path
local M, ns = require("addon_env")("esES")

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end

------------------------------------------------------------------------
-- Juego simulado: barras de acción, cursor, macros, teclas y Modo Edición
------------------------------------------------------------------------

local slots = {}          -- [hueco] = { kind, id }
local cursor
local known = { [100] = true, [200] = true }
local macros = { { name = "Curar", icon = 1, body = "/cast S100" }, { name = "Suelta", icon = 2, body = "/dance" } }

HasAction = function(slot) if slot > 180 then error("hueco no válido") end return slots[slot] ~= nil end
GetActionInfo = function(slot)
    local a = slots[slot]
    if not a then return nil end
    if a.kind == "macro" then return "macro", a.index, "" end
    return a.kind, a.id, a.kind == "spell" and "spell" or nil
end
GetActionText = function(slot) local a = slots[slot]; return a and a.kind == "macro" and macros[a.index].name or nil end
GetCursorInfo = function() return cursor and cursor.kind end
ClearCursor = function() cursor = nil end
PickupAction = function(slot) cursor, slots[slot] = slots[slot], cursor end
PlaceAction = function(slot) cursor, slots[slot] = slots[slot], cursor end
C_Spell.PickupSpell = function(id) if known[id] then cursor = { kind = "spell", id = id } end end
C_Item = { PickupItem = function(id) cursor = { kind = "item", id = id } end, GetItemNameByID = function(id) return "Objeto" .. id end }
GetMacroIndexByName = function(name)
    for i, m in ipairs(macros) do if m.name == name then return i end end
    return 0
end
GetNumMacros = function() return #macros, 0 end
GetMacroInfo = function(nameOrIndex)
    local m = macros[type(nameOrIndex) == "number" and nameOrIndex or GetMacroIndexByName(nameOrIndex)]
    if m then return m.name, m.icon, m.body end
end
CreateMacro = function(name, icon, body)
    macros[#macros + 1] = { name = name, icon = icon, body = body }
    return #macros
end
EditMacro = function(index, name, icon, body)
    macros[index] = { name = name, icon = icon, body = body }
    return index
end
PickupMacro = function(index) cursor = { kind = "macro", index = index } end

local bindings = { { "MOVEFORWARD", "W" }, { "ACTIONBUTTON1", "1", "SHIFT-1" }, { "ACTIONBUTTON2" } }
local saveCalls = 0
GetNumBindings = function() return #bindings + 1 end
GetBinding = function(i)
    if i == 1 then return "HEADER_MOVEMENT", "Movimiento" end
    local b = bindings[i - 1]
    return b[1], "Categoría", unpack(b, 2)
end
SetBinding = function(key, command)
    for _, b in ipairs(bindings) do
        for k = #b, 2, -1 do if b[k] == key then table.remove(b, k) end end
    end
    if command then
        for _, b in ipairs(bindings) do if b[1] == command then b[#b + 1] = key; return true end end
        bindings[#bindings + 1] = { command, key }
    end
    return true
end
GetCurrentBindingSet = function() return 2 end
SaveBindings = function(set) assert(set == 2, "se guarda en el juego de teclas en uso"); saveCalls = saveCalls + 1 end

Enum = { EditModePresetLayoutsMeta = { NumValues = 2 }, EditModeLayoutType = { Account = 1, Character = 2 } }
local editLayouts = { activeLayout = 3, layouts = { { layoutName = "Mío", layoutType = 1, data = "A" } } }
local savedLayouts
local function deepCopy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and deepCopy(v) or v end
    return c
end
C_EditMode = {
    GetLayouts = function() return deepCopy(editLayouts) end,
    ConvertLayoutInfoToString = function(info) return "LAYOUT" .. info.data end,
    ConvertStringToLayoutInfo = function(text) return { data = text:match("^LAYOUT(.*)$") } end,
    SaveLayouts = function(layouts) savedLayouts = layouts end,
}

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

------------------------------------------------------------------------
-- Guardar
------------------------------------------------------------------------

slots[1] = { kind = "spell", id = 100 }
slots[2] = { kind = "item", id = 5 }
slots[3] = { kind = "macro", index = 1 }
slots[150] = { kind = "spell", id = 200 }

local ok, name = ns.SaveSnapshot("  Raid  ")
assert(ok and name == "Raid", "se guarda con el nombre sin espacios")
local snap = ns.GetSnapshot("Raid")
assert(snap.layout == "LAYOUTA" and snap.layoutName == "Mío", "diseño del Modo Edición activo")
assert(#snap.bindings == 3, "teclas guardadas: " .. #snap.bindings)
assert(count(snap.actions) == 4, "botones guardados")
assert(snap.actions[3].t == "macro" and snap.actions[3].id == "Curar", "las macros se guardan por nombre")
assert(snap.macros.Curar.body == "/cast S100", "y con su texto")
assert(snap.macros.Suelta.body == "/dance", "también las macros que no están en ninguna barra")
assert(snap.character == "Alma-Reino" and snap.class == "DRUID", "quién la guardó")
assert(not ns.SaveSnapshot("   "), "hace falta un nombre")

------------------------------------------------------------------------
-- Restaurar
------------------------------------------------------------------------

-- Cambia todo: otra tecla, botones movidos, una macro borrada y un hechizo que ya no conoce
SetBinding("1"); SetBinding("2", "ACTIONBUTTON2")
slots = { [1] = { kind = "item", id = 9 }, [7] = { kind = "spell", id = 100 } }
macros = {}
known[200] = nil

local report = ns.RestoreSnapshot("Raid", { layout = true, bindings = true, macros = true, actions = true })
assert(report.bindings == 3 and saveCalls == 1, "teclas restauradas y guardadas")
local keys = {}
for _, b in ipairs(bindings) do for k = 2, #b do keys[b[k]] = b[1] end end
assert(keys["1"] == "ACTIONBUTTON1" and keys["SHIFT-1"] == "ACTIONBUTTON1" and keys.W == "MOVEFORWARD", "mismas teclas")
assert(keys["2"] == nil, "las teclas que no estaban se quitan")

assert(slots[1].kind == "spell" and slots[1].id == 100, "hueco 1")
assert(slots[2].kind == "item" and slots[2].id == 5, "hueco 2")
assert(slots[3].kind == "macro" and macros[slots[3].index].body == "/cast S100", "la macro se vuelve a crear")
assert(report.macrosCreated == 2 and macros[GetMacroIndexByName("Suelta")].body == "/dance", "macros creadas: " .. report.macrosCreated)

assert(slots[7] == nil, "los huecos vacíos en la instantánea se vacían")
assert(slots[150] == nil and #report.failed == 1 and report.failed[1] == "S200", "lo que no conoce se informa")
assert(report.actions == 3, "botones colocados: " .. report.actions)
assert(cursor == nil, "el cursor queda vacío")


assert(report.layoutName == "Ruscuu Raid", "diseño nuevo de cuenta")
assert(#savedLayouts.layouts == 2 and savedLayouts.layouts[2].layoutName == "Ruscuu Raid", "se añade a los diseños")
assert(savedLayouts.layouts[2].data == "A" and savedLayouts.layouts[2].layoutType == 1, "con las posiciones guardadas")
assert(savedLayouts.activeLayout == 4, "y queda activo (después de los 2 de Blizzard)")

-- Macros: la que cambió recupera su texto y la creada después se conserva
macros[GetMacroIndexByName("Suelta")].body = "/sit"
macros[#macros + 1] = { name = "Nueva", icon = 3, body = "/wave" }
report = ns.RestoreSnapshot("Raid", { macros = true })
assert(report.macrosUpdated == 1 and macros[GetMacroIndexByName("Suelta")].body == "/dance", "macro actualizada")
assert(GetMacroIndexByName("Nueva") > 0, "las macros nuevas no se borran")

-- Restaurar otra vez: no se duplica el diseño, se sustituye
editLayouts = savedLayouts
ns.RestoreSnapshot("Raid", { layout = true })
assert(#savedLayouts.layouts == 2, "el diseño con el mismo nombre se sustituye")

-- Sin hueco para más diseños de cuenta
editLayouts = { activeLayout = 3, layouts = {} }
for i = 1, 5 do editLayouts.layouts[i] = { layoutName = "D" .. i, layoutType = 1 } end
savedLayouts = nil
report = ns.RestoreSnapshot("Raid", { layout = true })
assert(report.layoutError and savedLayouts == nil, "con 5 diseños de cuenta no se guarda y se avisa")

-- Solo las partes elegidas
local before = slots[1]
slots[1] = nil
report = ns.RestoreSnapshot("Raid", { bindings = true })
assert(slots[1] == nil and not report.actionsDone, "si no se marcan las barras no se tocan")
slots[1] = before

-- En combate no se toca nada
M.inCombat = true
local fail, why = ns.RestoreSnapshot("Raid")
assert(fail == nil and why == "No disponible en combate.", "en combate: " .. tostring(why))
M.inCombat = false

------------------------------------------------------------------------
-- Exportar e importar
------------------------------------------------------------------------

local text = ns.ExportSnapshot("Raid")
assert(text:sub(1, 12) == "!RUSCUUUI:1!", "prefijo")
local ok2, imported = ns.ImportSnapshot(text)
assert(ok2 and imported == "Raid (2)", "no pisa una instantánea con el mismo nombre: " .. tostring(imported))
local copy = ns.GetSnapshot("Raid (2)")
assert(copy.layout == snap.layout and #copy.bindings == #snap.bindings, "mismas posiciones y teclas")
assert(count(copy.actions) == count(snap.actions) and copy.actions[3].id == "Curar" and copy.actions[150].id == 200, "mismos botones")
assert(copy.macros.Curar.body == "/cast S100" and copy.macros.Suelta.body == "/dance", "mismas macros")

-- Textos con tabuladores y saltos de línea en una macro sobreviven al viaje
snap.macros.Curar.body = "/cast S100\n/say a\tb \\n"
copy = select(2, ns.ParseSnapshot(ns.ExportSnapshot("Raid")))
assert(copy.macros.Curar.body == snap.macros.Curar.body, "escapes: " .. copy.macros.Curar.body)

-- Textos manipulados: tipos desconocidos, huecos fuera de rango y nada válido
local function encode(lines) return "!RUSCUUUI:1!" .. ns.Base64Encode(table.concat(lines, "\n")) end
copy = select(2, ns.ParseSnapshot(encode({ "N\tX", "A\t1\tspell\t100\t", "A\t999\tspell\t1\t", "A\t2\tscript\tx\t",
    "A\t3\tspell\tabc\t", "E\tno es base64!", "B\tJUMP\tSPACE" })))
assert(count(copy.actions) == 1 and copy.actions[1].id == 100, "solo acciones válidas")
assert(copy.layout == nil and #copy.bindings == 1, "diseño no válido descartado")
assert(not ns.ImportSnapshot(encode({ "N\tX", "Z\tnada" })), "sin datos válidos no se importa")
assert(not ns.ImportSnapshot("hola"), "texto sin prefijo")

ns.DeleteSnapshot("Raid (2)")
assert(ns.GetSnapshot("Raid (2)") == nil and #ns.GetSnapshotNames() == 1, "borrar")

------------------------------------------------------------------------
-- Exportar todo e importarlo en una instalación nueva (por ejemplo, de la beta a la 1.0)
------------------------------------------------------------------------

local active = ns.activeProfile
ns.db.iconZoom = 0.2
ns.global.profiles.Otro = { iconZoom = 0.1 }   -- perfil sin usar: todavía sin valores por defecto
local everything = ns.ExportAll()
assert(everything:sub(1, 13) == "!RUSCUUALL:1!", "prefijo de exportar todo")

-- Instalación nueva: sin instantáneas, el perfil activo con los valores por defecto y sin el perfil Otro
ns.global.snapshots = {}
wipe(ns.db); ns.ApplyDefaults(ns.db, ns.PROFILE_DEFAULTS)
ns.global.profiles.Otro = nil
local okAll, nSnap, nProf = ns.ImportAll(everything)
assert(okAll and nSnap == 1 and nProf == #ns.GetProfileNames(), "importar todo: " .. tostring(nSnap) .. " " .. tostring(nProf))
assert(ns.GetSnapshot("Raid") and ns.GetSnapshot("Raid").macros.Suelta.body == "/dance", "la instantánea vuelve con el mismo nombre")
assert(ns.activeProfile == active and ns.db.iconZoom == 0.2, "el perfil con el mismo nombre recibe el estilo exportado")
assert(ns.global.profiles.Otro.iconZoom == 0.1 and ns.global.profiles.Otro.squareIcons == true, "perfil sin usar, con sus valores completos")
okAll = ns.ImportAll(everything)
assert(okAll and #ns.GetSnapshotNames() == 1, "importar dos veces no duplica")
assert(not ns.ImportAll("!RUSCUUALL:1!" .. ns.Base64Encode("X\tnada")), "sin datos válidos no se importa")
print("instantáneas de la interfaz: OK")
