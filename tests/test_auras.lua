-- Iconos de efectos del juego: ocultar, escalar y mover los de las placas, los del marco del objetivo y del foco,
-- los tuyos, y cualquier marco por su nombre. Todo vuelve tal cual al dejar los valores por defecto.
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()

local plates = {}
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function()
        local list = {}
        for _, p in pairs(plates) do list[#list + 1] = p end
        return list
    end,
}

-- Placa de estilo nuevo (contenedor con listas) y de estilo antiguo (un solo contenedor)
local function plate(unit, newStyle)
    local p = M.CreateFrame("Frame", nil, UIParent)
    p.UnitFrame = M.CreateFrame("Frame", nil, p)
    local uf = p.UnitFrame
    if newStyle then
        uf.AurasFrame = M.CreateFrame("Frame", nil, uf)
        uf.AurasFrame.DebuffListFrame = M.CreateFrame("Frame", nil, uf.AurasFrame)
        uf.AurasFrame.DebuffListFrame:SetPoint("BOTTOM", uf, "TOP", 0, 5)
        uf.AurasFrame.BuffListFrame = M.CreateFrame("Frame", nil, uf.AurasFrame)
        uf.AurasFrame.BuffListFrame:SetPoint("LEFT", uf, "RIGHT", 2, 0)
    else
        uf.BuffFrame = M.CreateFrame("Frame", nil, uf)
        uf.BuffFrame:SetPoint("BOTTOM", uf, "TOP", 0, 5)
        -- Blizzard la vuelve a colocar en cada actualización
        function uf.BuffFrame:UpdateAnchor() self:SetPoint("BOTTOM", uf, "TOP", 0, 5) end
    end
    plates[unit] = p
    return p
end

-- Marco del objetivo con botones de efectos en grupos (versiones nuevas)
local function pooled(frame, buffs, debuffs)
    local active = { TargetBuffFrameTemplate = buffs, TargetDebuffFrameTemplate = debuffs }
    frame.auraPools = {
        EnumerateActiveByTemplate = function(_, template)
            local list, i = active[template] or {}, 0
            return function() i = i + 1; return list[i] end
        end,
    }
    function frame:UpdateAuras() end
end
local function button()
    local b = M.CreateFrame("Frame", nil, UIParent)
    b:EnableMouse(true)
    return b
end

TargetFrame = M.CreateFrame("Frame", "TargetFrame")
local tBuff, tDebuff = button(), button()
pooled(TargetFrame, { tBuff }, { tDebuff })
FocusFrame = M.CreateFrame("Frame", "FocusFrame")
local fDebuff = button()
pooled(FocusFrame, {}, { fDebuff })
BuffFrame = M.CreateFrame("Frame", "BuffFrame")
DebuffFrame = M.CreateFrame("Frame", "DebuffFrame")
UnitIsUnit = function(a, b) return a == b end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Auras.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)

local newPlate = plate("nameplate1", true)
local oldPlate = plate("nameplate2", false)
local debuffList = newPlate.UnitFrame.AurasFrame.DebuffListFrame
local buffList = newPlate.UnitFrame.AurasFrame.BuffListFrame
local container = oldPlate.UnitFrame.BuffFrame

-- Por defecto no se toca nada
ns.RefreshAuras()
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(debuffList:GetAlpha() == 1 and debuffList:GetScale() == 1, "por defecto, como lo deja Blizzard")
assert(select(5, debuffList:GetPoint(1)) == 5, "por defecto no se mueve")
assert(tBuff:GetAlpha() == 1 and BuffFrame:GetAlpha() == 1, "por defecto todo visible")

-- Placas: ocultar, tamaño y posición, en las listas nuevas y en el contenedor antiguo
ns.db.aurasPlateShow = false
ns.db.aurasPlateScale = 1.5
ns.db.aurasPlateX, ns.db.aurasPlateY = 10, 20
ns.RefreshAuras()
assert(debuffList:GetAlpha() == 0 and buffList:GetAlpha() == 0, "placas nuevas: efectos ocultos")
assert(newPlate.UnitFrame.AurasFrame:GetScale() == 1, "las listas se escalan, no el contenedor (no se duplica)")
assert(debuffList:GetScale() == 1.5, "placas nuevas: tamaño")
local _, _, _, x, y = debuffList:GetPoint(1)
assert(x == 10 and y == 25, "placas nuevas: desplazados desde donde estaban: " .. x .. "," .. y)
assert(container:GetAlpha() == 0 and container:GetScale() == 1.5, "placa antigua: oculta y escalada")
_, _, _, x, y = container:GetPoint(1)
assert(x == 10 and y == 25, "placa antigua: desplazada")

-- Blizzard vuelve a colocar los efectos: se aplica otra vez el desplazamiento, sin acumularse
container:UpdateAnchor()
_, _, _, x, y = container:GetPoint(1)
assert(x == 10 and y == 25, "tras recolocarlos Blizzard sigue el mismo desplazamiento: " .. x .. "," .. y)
M.FireEvent("UNIT_AURA", "nameplate2")
M.FireEvent("UNIT_AURA", "nameplate2")
_, _, _, x, y = container:GetPoint(1)
assert(x == 10 and y == 25, "las actualizaciones no lo acumulan")

-- Una placa nueva que aparece recibe lo elegido
local third = plate("nameplate3", false)
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(third.UnitFrame.BuffFrame:GetAlpha() == 0, "placa que aparece después")

-- Volver a los valores por defecto lo devuelve todo tal cual
ns.db.aurasPlateShow, ns.db.aurasPlateScale, ns.db.aurasPlateX, ns.db.aurasPlateY = true, 1, 0, 0
ns.RefreshAuras()
_, _, _, x, y = container:GetPoint(1)
assert(container:GetAlpha() == 1 and container:GetScale() == 1 and x == 0 and y == 5, "placa devuelta a Blizzard")
_, _, _, x, y = debuffList:GetPoint(1)
assert(debuffList:GetAlpha() == 1 and x == 0 and y == 5, "listas devueltas a Blizzard")

-- Marco del objetivo: beneficios y perjuicios por separado, sin ayuda al pasar el ratón por los ocultos
ns.db.aurasTargetBuffs = false
ns.db.aurasTargetScale = 1.25
ns.RefreshAuras()
assert(tBuff:GetAlpha() == 0 and not tBuff:IsMouseEnabled(), "beneficios del objetivo ocultos y sin ayuda")
assert(tDebuff:GetAlpha() == 1, "perjuicios del objetivo visibles")
assert(tBuff:GetScale() == 1.25 and tDebuff:GetScale() == 1.25, "tamaño de los efectos del objetivo")
assert(fDebuff:GetScale() == 1.25, "el foco igual")
-- Blizzard rehace los efectos (al cambiar de objetivo): se aplica de nuevo
local newBuff = button()
pooled(TargetFrame, { newBuff }, { tDebuff })
ns.RefreshAuras() -- engancha la nueva función de actualización (en el juego es siempre la misma)
TargetFrame:UpdateAuras()
assert(newBuff:GetAlpha() == 0, "efecto nuevo del objetivo oculto")
-- Sin "Igual en el foco", el foco vuelve a como estaba
ns.db.aurasFocus = false
ns.db.aurasTargetDebuffs = false
ns.RefreshAuras()
assert(fDebuff:GetAlpha() == 1 and fDebuff:GetScale() == 1, "foco sin cambios")
assert(tDebuff:GetAlpha() == 0, "perjuicios del objetivo ocultos")
ns.db.aurasTargetBuffs, ns.db.aurasTargetDebuffs, ns.db.aurasTargetScale = true, true, 1
ns.RefreshAuras()
assert(newBuff:GetAlpha() == 1 and newBuff:IsMouseEnabled() and tDebuff:GetScale() == 1, "objetivo devuelto")

-- Lo tuyo: beneficios y perjuicios (maldiciones...) por separado
ns.db.aurasPlayerDebuffs = false
ns.RefreshAuras()
assert(DebuffFrame:GetAlpha() == 0 and BuffFrame:GetAlpha() == 1, "tus perjuicios ocultos")
M.FireEvent("UNIT_AURA", "player")
assert(DebuffFrame:GetAlpha() == 0, "siguen ocultos al cambiar tus efectos")
ns.db.aurasPlayerDebuffs = true
ns.RefreshAuras()
assert(DebuffFrame:GetAlpha() == 1, "tus perjuicios visibles otra vez")

-- Cualquier marco por su nombre (el que da /fstack)
local mystery = M.CreateFrame("Frame", "Some_TopCenterFrame", UIParent)
assert(ns.ToggleHiddenFrame("NoExiste") == nil, "un marco que no existe no se guarda")
assert(ns.ToggleHiddenFrame("UIParent") == nil, "no se puede ocultar toda la interfaz")
assert(ns.ToggleHiddenFrame("bad name!") == nil, "nombre no válido")
assert(ns.ToggleHiddenFrame("Some_TopCenterFrame") == true and mystery:GetAlpha() == 0, "oculto por su nombre")
assert(ns.GetHiddenFrameNames()[1] == "Some_TopCenterFrame", "aparece en la lista")
mystery:SetAlpha(1); mystery:Fire("OnShow")
assert(mystery:GetAlpha() == 0, "al mostrarse se oculta otra vez")
assert(ns.ToggleHiddenFrame("Some_TopCenterFrame") == false and mystery:GetAlpha() == 1, "escribirlo otra vez lo muestra")
ns.ToggleHiddenFrame("Some_TopCenterFrame")
ns.ShowAllHiddenFrames()
assert(mystery:GetAlpha() == 1 and #ns.GetHiddenFrameNames() == 0, "mostrar todos otra vez")

-- Comando /rcm hide <nombre>, respetando mayúsculas
ns.global = { chatMessages = false }
local realPrint = print
print = function() end
SlashCmdList.RUSCUUCDM("hide Some_TopCenterFrame")
print = realPrint
assert(mystery:GetAlpha() == 0, "/rcm hide oculta el marco")

print("efectos del juego: OK")
