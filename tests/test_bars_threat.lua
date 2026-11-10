-- Medidor de amenaza: los errores de los eventos se informan una sola vez (sin inundar el chat), los avisos de
-- otras unidades no rehacen todos los medidores, y la revisión periódica se para si no hay medidores
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()

local threatCalls = 0
local threat = {}
UnitDetailedThreatSituation = function(_, unit)
    threatCalls = threatCalls + 1
    local t = threat[unit]
    if not t then return nil end
    return t[1] == 3, t[1], t[2], t[2], 0
end
UnitCanAttack = function() return true end
local plates = {}
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function() local l = {}; for _, pl in pairs(plates) do l[#l + 1] = pl end; return l end,
}
local function plate(unit)
    local pl = M.CreateFrame("Frame", nil, UIParent)
    pl.namePlateUnitToken = unit
    pl.UnitFrame = M.CreateFrame("Frame", nil, pl)
    plates[unit] = pl
end

local reported = {}
geterrorhandler = function() return function(err) reported[#reported + 1] = tostring(err) end end
print = function() end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Threat.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)

-- El marco de eventos del medidor (el que tiene OnUpdate)
local events
for _, f in ipairs(M.frames) do
    if f._events and f._events.UNIT_THREAT_LIST_UPDATE and f._scripts and f._scripts.OnUpdate then events = f end
end
assert(events, "marco de eventos")
assert(not events:IsShown(), "sin medidores no corre la revisión periódica")

plate("nameplate1"); plate("nameplate2")
threat.nameplate1, threat.nameplate2 = { 1, 50 }, { 1, 60 }
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(ns.CountThreatMeters() == 2 and events:IsShown(), "con medidores se revisa")

-- Avisos de otras unidades (objetivo, jefe, grupo): no rehacen todos los medidores
threatCalls = 0
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
assert(threatCalls == 0, "avisos de otras unidades sin trabajo: " .. threatCalls)
-- Los de la placa solo rehacen su medidor; los tuyos y al entrar en combate, todos
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(threatCalls == 1, "solo la placa avisada")
threatCalls = 0
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
assert(threatCalls == 2, "tu situación rehace todos")
threatCalls = 0
M.FireEvent("PLAYER_REGEN_DISABLED")
assert(threatCalls == 2, "al entrar en combate se rehacen todos")

-- Un error en el camino de los eventos no sale como error de Lua en cada aviso: se informa una sola vez
ns.db.threatColorHigh = nil -- el color del nivel 1 falta: pintar da error
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
M.Tick(0.3)
M.Tick(0.3)
assert(#reported == 1, "el error se informa una vez: " .. #reported)
ns.db.threatColorHigh = { 1, 0.6, 0, 1 }

-- Datos secretos, sin curva de color: ¿te está atacando? (secreto) se pasa a la función de color
local SECRET = { __secret = true }
threat.nameplate1 = nil
UnitDetailedThreatSituation = function() return SECRET, SECRET, SECRET, SECRET, 0 end
CreateColor = function(r, g, b, a) return { GetRGBA = function() return r, g, b, a end } end
local fromBool = 0
C_CurveUtil = { EvaluateColorFromBoolean = function(_, yes) fromBool = fromBool + 1; return yes end }
ns.RefreshThreat()
assert(fromBool > 0 and ns.GetThreatColorInfo().source == "tanking", "color por verdadero/falso sin mirarlo")
assert(#reported == 1, "sin errores nuevos con datos secretos")

-- Al quitar las placas se para la revisión periódica
M.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
M.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate2")
assert(ns.CountThreatMeters() == 0 and not events:IsShown(), "sin medidores se para")

io.write("medidor de amenaza (eventos): OK\n")
