-- Medidor de amenaza encima de las placas de nombre: solo en enemigos con los que estás en combate, se llena con
-- tu amenaza, sigue funcionando si el juego oculta los datos, y se quita al desaparecer la placa o al apagarlo
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local SECRET = { __secret = true }

-- Amenaza del jugador sobre cada unidad: { estado, porcentaje } o nil si no está en su lista
local threat = {}
UnitDetailedThreatSituation = function(_, unit)
    local t = threat[unit]
    if not t then return nil end
    return t[1] == 3, t[1], t[2], t[2], 0
end
local hostile = { nameplate1 = true, nameplate2 = true, nameplate3 = false }
UnitCanAttack = function(_, unit) return hostile[unit] end
local plates = {}
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function()
        local list = {}
        for _, p in pairs(plates) do list[#list + 1] = p end
        return list
    end,
}
local function plate(unit)
    local p = M.CreateFrame("Frame", nil, UIParent)
    p.namePlateUnitToken = unit
    p.UnitFrame = M.CreateFrame("Frame", nil, p)
    p.UnitFrame.name = p.UnitFrame:CreateFontString()
    plates[unit] = p
    return p
end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Threat.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)

-- Enemigo fuera de combate: no hay barra; al entrar en su lista de amenaza aparece
local p1 = plate("nameplate1")
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
local bar = ns.GetThreatBar("nameplate1")
assert(bar and not bar:IsShown(), "sin amenaza no se ve")
assert(bar:GetParent() == p1, "va en la placa del enemigo")
assert(select(2, bar:GetPoint(1)) == p1.UnitFrame.name, "encima del nombre")
threat.nameplate1 = { 1, 85 }
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(bar:IsShown() and bar:GetValue() == 85, "se llena con la amenaza")
threat.nameplate1 = { 3, 100 }
M.Tick(0.3)
assert(bar:GetValue() == 100, "se actualiza sola mientras dura el combate")

-- Datos ocultos por el juego: la barra recibe el valor tal cual, sin que el addon lo lea
threat.nameplate1 = { SECRET, SECRET }
M.Tick(0.3)
assert(bar:IsShown() and bar:GetValue() == SECRET, "con valores secretos se sigue viendo")

-- Una placa amiga no lleva barra
plate("nameplate3")
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(not ns.GetThreatBar("nameplate3"), "sin barra en los amigos")

-- Al desaparecer la placa, la barra se quita (y se reutiliza en la siguiente)
plates.nameplate1 = nil
M.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not ns.GetThreatBar("nameplate1") and not bar:IsShown(), "se quita con la placa")
plate("nameplate2")
threat.nameplate2 = { 0, 20 }
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(ns.GetThreatBar("nameplate2") == bar and bar:IsShown(), "se reutiliza la barra")

-- Desactivado en las opciones: no queda ninguna
ns.db.threatBar = false
ns.RefreshThreat()
assert(ns.CountThreatBars() == 0 and not bar:IsShown(), "desactivado: sin barras")
ns.db.threatBar = true
ns.RefreshThreat()
assert(ns.CountThreatBars() == 1, "al activarlo vuelven las de las placas visibles")
print("medidor de amenaza: OK")
