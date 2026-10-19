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
    local tanking = t[3]
    if tanking == nil then tanking = t[1] == 3 end
    return tanking, t[1], t[2], t[2], 0
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

local function sameColor(got, want)
    return got and got[1] == want[1] and got[2] == want[2] and got[3] == want[3]
end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Threat.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)

-- Enemigo fuera de combate: no hay barra; al entrar en su lista de amenaza aparece
local p1 = plate("nameplate1")
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
local bar = ns.GetThreatMeter("nameplate1")
assert(bar and not bar:IsShown(), "sin amenaza no se ve")
assert(bar:GetParent() == p1, "va en la placa del enemigo")
assert(select(2, bar:GetPoint(1)) == p1.UnitFrame.name, "encima del nombre")
threat.nameplate1 = { 1, 85 }
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(bar:IsShown() and bar.bar:GetValue() == 85, "se llena con la amenaza")
threat.nameplate1 = { 3, 100 }
M.Tick(0.3)
assert(bar.bar:GetValue() == 100, "se actualiza sola mientras dura el combate")

-- Datos ocultos por el juego: la barra recibe el valor tal cual, sin que el addon lo lea
threat.nameplate1 = { SECRET, SECRET, SECRET }
M.Tick(0.3)
assert(bar:IsShown() and bar.bar:GetValue() == SECRET, "con valores secretos se sigue viendo")
assert(sameColor(bar.bar._color, ns.db.threatColorSecret), "sin curva de color: el color de dato oculto")

-- Con la curva de color del juego, el nivel secreto da su color sin que el addon lo lea:
-- te está atacando (nivel 3) -> rojo, aunque el dato esté oculto
local Hidden = function(v) return { __secret = true, value = v } end
CreateColor = function(r, g, b, a) return { GetRGBA = function() return r, g, b, a end } end
C_CurveUtil = { CreateColorCurve = function()
    local curve = { points = {} }
    function curve:AddPoint(x, color) self.points[#self.points + 1] = { x = x, c = color } end
    function curve:Evaluate(x)
        x = type(x) == "table" and x.value or x
        local best
        for _, p in ipairs(self.points) do
            if not best or math.abs(p.x - x) < math.abs(best.x - x) then best = p end
        end
        return best.c
    end
    return curve
end }
ns.RefreshThreat()
bar = ns.GetThreatMeter("nameplate1")
threat.nameplate1 = { Hidden(3), SECRET }
M.Tick(0.3)
assert(sameColor(bar.bar._color, ns.db.threatColorTanking), "oculto pero te ataca: rojo")
threat.nameplate1 = { Hidden(0), SECRET }
M.Tick(0.3)
assert(sameColor(bar.bar._color, ns.db.threatColorLow), "oculto y con poca amenaza: verde")
threat.nameplate1 = { 1, 85 }
M.Tick(0.3)
assert(sameColor(bar.bar._color, ns.db.threatColorHigh), "dato visible: amarillo")

-- Si la curva no acepta el nivel oculto: se usa "te ataca a ti" (también oculto) con la función de color por
-- verdadero/falso del juego, sin mirarlo
local evaluate = C_CurveUtil.CreateColorCurve
C_CurveUtil.CreateColorCurve = function()
    local curve = evaluate()
    curve.Evaluate = function() error("valor secreto no permitido") end
    return curve
end
C_CurveUtil.EvaluateColorFromBoolean = function(b, yes, no) return b.value and yes or no end
ns.RefreshThreat()
threat.nameplate1 = { Hidden(3), SECRET, Hidden(true) }
M.Tick(0.3)
assert(sameColor(bar.bar._color, ns.db.threatColorTanking), "sin curva, pero te ataca: rojo")
assert(ns.GetThreatColorInfo().source == "tanking", "color sacado de si te ataca")
threat.nameplate1 = { Hidden(0), SECRET, Hidden(false) }
M.Tick(0.3)
assert(sameColor(bar.bar._color, ns.db.threatColorLow), "sin curva y no te ataca: poca amenaza")

-- Sin nada de eso: si el enemigo te tiene de objetivo, te está atacando
C_CurveUtil.EvaluateColorFromBoolean = nil
UnitIsUnit = function(a, b) return a == "nameplate1target" and b == "player" end
threat.nameplate1 = { Hidden(3), SECRET, Hidden(true) }
M.Tick(0.3)
assert(sameColor(bar.bar._color, ns.db.threatColorTanking), "por su objetivo: rojo")
assert(ns.GetThreatColorInfo().source == "target", "color sacado del objetivo del enemigo")
UnitIsUnit = nil
C_CurveUtil.CreateColorCurve = evaluate
ns.RefreshThreat()

-- Una placa amiga no lleva barra
plate("nameplate3")
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(not ns.GetThreatMeter("nameplate3"), "sin barra en los amigos")

-- Al desaparecer la placa, la barra se quita (y se reutiliza en la siguiente)
plates.nameplate1 = nil
M.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not ns.GetThreatMeter("nameplate1") and not bar:IsShown(), "se quita con la placa")
plate("nameplate2")
threat.nameplate2 = { 0, 20 }
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(ns.GetThreatMeter("nameplate2") == bar and bar:IsShown(), "se reutiliza la barra")

-- Desactivado en las opciones: no queda ninguna
ns.db.threatBar = false
ns.RefreshThreat()
assert(ns.CountThreatMeters() == 0 and not bar:IsShown(), "desactivado: sin barras")
ns.db.threatBar = true
ns.RefreshThreat()
assert(ns.CountThreatMeters() == 1, "al activarlo vuelven las de las placas visibles")
-- Configurable: solo el porcentaje, tamaño y posición elegidos
ns.db.threatShow, ns.db.threatWidth, ns.db.threatX, ns.db.threatY = "percent", 150, 10, 20
ns.RefreshThreat()
local m = ns.GetThreatMeter("nameplate2")
assert(not m.bar:IsShown() and m.text:IsShown(), "solo el porcentaje")
assert(m:GetWidth() == 150, "con el ancho elegido")
local _, _, _, ox, oy = m:GetPoint(1)
assert(ox == 10 and oy == 20, "en la posición elegida")
-- El medidor que ya está en la placa cambia de tamaño al momento, aunque el juego no liste las placas visibles
local getPlates = C_NamePlate.GetNamePlates
C_NamePlate.GetNamePlates = function() return {} end
ns.db.threatWidth, ns.db.threatHeight = 80, 12
ns.RefreshThreat()
assert(ns.GetThreatMeter("nameplate2") == m and m:GetWidth() == 80 and m:GetHeight() == 12,
    "el ancho y el alto cambian en el medidor que ya se ve")
C_NamePlate.GetNamePlates = getPlates
ns.db.threatShow = "bar"
ns.RefreshThreat()
m = ns.GetThreatMeter("nameplate2")
assert(m.bar:IsShown() and not m.text:IsShown(), "solo la barra")

-- Vista previa fuera de combate: un medidor de ejemplo en las placas visibles
threat.nameplate2 = nil
ns.RefreshThreat()
assert(not ns.GetThreatMeter("nameplate2"):IsShown(), "fuera de combate no se ve")
ns.PreviewThreat(10)
assert(ns.GetThreatMeter("nameplate2"):IsShown(), "la vista previa lo muestra")
M.Tick(11)
assert(not ns.GetThreatMeter("nameplate2"):IsShown(), "al terminar la vista previa se oculta")
print("medidor de amenaza: OK")
