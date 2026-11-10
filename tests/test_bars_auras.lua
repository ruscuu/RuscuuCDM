-- Efectos del juego en la versión Forever: contenedor de efectos del objetivo, botones de tus efectos sin ratón
-- al ocultarlos, marcos ocultos por nombre que no vuelven solos, listas de las placas con dos anclajes, icono de
-- pérdida de control y UNIT_AURA de las placas sin trabajo de más.
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()

-- RegisterUnitEvent como en el juego: solo llega el evento de esas unidades
local Object = getmetatable(M.CreateFrame("Frame"))
function Object:RegisterUnitEvent(event, ...)
    self._events = self._events or {}
    self._events[event] = true
    self._unitFilter = self._unitFilter or {}
    self._unitFilter[event] = { ... }
end
local function FireUnitEvent(event, unit)
    for _, f in ipairs(M.frames) do
        if f._events and f._events[event] and f._scripts and f._scripts.OnEvent then
            local filter = f._unitFilter and f._unitFilter[event]
            local ok = not filter
            for _, u in ipairs(filter or {}) do if u == unit then ok = true end end
            if ok then f._scripts.OnEvent(f, event, unit) end
        end
    end
end

local plates, plateLookups = {}, 0
C_NamePlate = {
    GetNamePlateForUnit = function(unit) plateLookups = plateLookups + 1; return plates[unit] end,
    GetNamePlates = function()
        local list = {}
        for _, p in pairs(plates) do list[#list + 1] = p end
        return list
    end,
}

-- Placa como la de Forever: la lista de perjuicios con dos anclajes (IZQUIERDA y ABAJO), y el icono de
-- pérdida de control al que Blizzard pone su propia escala
local p = M.CreateFrame("Frame", nil, UIParent)
p.UnitFrame = M.CreateFrame("Frame", nil, p)
local uf = p.UnitFrame
uf.healthBar = M.CreateFrame("Frame", nil, uf)
uf.AurasFrame = M.CreateFrame("Frame", nil, uf)
local debuffList = M.CreateFrame("Frame", nil, uf.AurasFrame)
uf.AurasFrame.DebuffListFrame = debuffList
debuffList:SetPoint("LEFT", uf.healthBar, "LEFT", 0, 0)
debuffList:SetPoint("BOTTOM", uf.healthBar, "TOP", 0, 4)
local layouts = 0
function debuffList:Layout() layouts = layouts + 1; self:SetPoint("BOTTOM", uf.healthBar, "TOP", 0, 4) end
local loc = M.CreateFrame("Frame", nil, uf.AurasFrame)
uf.AurasFrame.LossOfControlFrame = loc
loc:SetPoint("RIGHT", uf.healthBar, "LEFT", -2, 0)
loc:SetScale(0.8)
plates.nameplate1 = p

-- Marco del objetivo de Forever: los botones van en un contenedor con grupos privados
local container = M.CreateFrame("Frame", nil, UIParent)
TargetFrame = M.CreateFrame("Frame", "TargetFrame")
function TargetFrame:GetAuraContainer() return container end
function TargetFrame:UpdateAuras() end

-- Tus efectos: botones creados una vez dentro de AuraContainer, con ratón (clic derecho = quitar)
local function auraFrame(name)
    local f = M.CreateFrame("Frame", name, UIParent)
    f.AuraContainer = M.CreateFrame("Frame", nil, f)
    f.auraFrames = {}
    for i = 1, 3 do
        local b = M.CreateFrame("Button", nil, f.AuraContainer)
        b:EnableMouse(true)
        f.auraFrames[i] = b
    end
    return f
end
BuffFrame = auraFrame("BuffFrame")
DebuffFrame = auraFrame("DebuffFrame")

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Auras.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.RefreshAuras()

local function point(frame, name)
    for i = 1, frame:GetNumPoints() do
        local pt, rel, rp, x, y = frame:GetPoint(i)
        if pt == name then return x, y, rel, rp end
    end
end

-- UNIT_AURA de las placas: Blizzard ya llama a Layout y el enganche basta; el evento no busca la placa
plateLookups = 0
FireUnitEvent("UNIT_AURA", "nameplate1")
assert(plateLookups == 0, "UNIT_AURA de una placa no hace trabajo de más: " .. plateLookups)

-- Por defecto, Layout no toca nada (ni siquiera lee los anclajes)
local reads = 0
local realGetNumPoints = debuffList.GetNumPoints
debuffList.GetNumPoints = function(self) reads = reads + 1; return realGetNumPoints(self) end
debuffList:Layout()
assert(reads == 0, "por defecto no se leen los anclajes")
debuffList.GetNumPoints = nil

-- Mover los efectos de la placa: se mueven los dos anclajes (si no, la lista se estira en vez de moverse)
ns.db.aurasPlateX, ns.db.aurasPlateY = 10, 20
ns.RefreshAuras()
local lx, ly = point(debuffList, "LEFT")
local bx, by = point(debuffList, "BOTTOM")
assert(lx == 10 and ly == 20, "IZQUIERDA desplazada: " .. tostring(lx) .. "," .. tostring(ly))
assert(bx == 10 and by == 24, "ABAJO desplazada: " .. tostring(bx) .. "," .. tostring(by))
-- Blizzard vuelve a poner solo ABAJO: no se acumula en ninguno
debuffList:Layout()
debuffList:Layout()
lx, ly = point(debuffList, "LEFT")
bx, by = point(debuffList, "BOTTOM")
assert(lx == 10 and ly == 20 and bx == 10 and by == 24,
    "sin acumular tras Layout: " .. lx .. "," .. ly .. " / " .. bx .. "," .. by)

-- Icono de pérdida de control: se oculta y se mueve, pero su escala es la de Blizzard
ns.db.aurasPlateShow, ns.db.aurasPlateScale = false, 1.5
ns.RefreshAuras()
assert(loc:GetAlpha() == 0, "pérdida de control oculta")
assert(loc:GetScale() == 0.8, "pérdida de control conserva la escala de Blizzard")
assert(debuffList:GetScale() == 1.5, "las listas sí se escalan")
local cx, cy = point(loc, "RIGHT")
assert(cx == 8 and cy == 20, "pérdida de control desplazada: " .. cx .. "," .. cy)

-- Volver a los valores por defecto lo devuelve todo
ns.db.aurasPlateShow, ns.db.aurasPlateScale, ns.db.aurasPlateX, ns.db.aurasPlateY = true, 1, 0, 0
ns.RefreshAuras()
lx, ly = point(debuffList, "LEFT")
bx, by = point(debuffList, "BOTTOM")
assert(lx == 0 and ly == 0 and bx == 0 and by == 4, "anclajes devueltos")
assert(loc:GetAlpha() == 1 and point(loc, "RIGHT") == -2, "pérdida de control devuelta")

-- Contenedor de efectos del objetivo: se oculta si se desmarcan los dos, y se escala
assert(ns.GetAuraStatus().targetButtons == 1, "/rcm debug encuentra el contenedor")
ns.db.aurasTargetBuffs = false
ns.RefreshAuras()
assert(container:GetAlpha() == 1, "con los perjuicios marcados el contenedor sigue visible")
ns.db.aurasTargetDebuffs = false
ns.db.aurasTargetScale = 1.25
ns.RefreshAuras()
assert(container:GetAlpha() == 0 and container:GetScale() == 1.25, "contenedor del objetivo oculto y escalado")
container:SetScale(1) -- Blizzard lo reconfigura
TargetFrame:UpdateAuras()
assert(container:GetScale() == 1.25, "tras actualizar Blizzard se aplica otra vez")
ns.db.aurasTargetBuffs, ns.db.aurasTargetDebuffs, ns.db.aurasTargetScale = true, true, 1
ns.RefreshAuras()
assert(container:GetAlpha() == 1 and container:GetScale() == 1, "contenedor devuelto")

-- Tus beneficios ocultos: sus botones no reciben el ratón (un clic derecho invisible los quitaría)
ns.db.aurasPlayerBuffs = false
ns.RefreshAuras()
assert(BuffFrame:GetAlpha() == 0, "tus beneficios ocultos")
for _, b in ipairs(BuffFrame.auraFrames) do assert(not b:IsMouseEnabled(), "botón oculto sin ratón") end
assert(DebuffFrame.auraFrames[1]:IsMouseEnabled(), "los perjuicios visibles conservan el ratón")
ns.db.aurasPlayerBuffs = true
ns.RefreshAuras()
for _, b in ipairs(BuffFrame.auraFrames) do assert(b:IsMouseEnabled(), "ratón devuelto") end

-- Ocultar BuffFrame por su nombre: no vuelve a aparecer al cambiar tus efectos
assert(ns.ToggleHiddenFrame("BuffFrame") == true and BuffFrame:GetAlpha() == 0, "BuffFrame oculto por nombre")
FireUnitEvent("UNIT_AURA", "player")
assert(BuffFrame:GetAlpha() == 0, "sigue oculto tras UNIT_AURA del jugador")
assert(not BuffFrame.auraFrames[1]:IsMouseEnabled(), "sus botones sin ratón")
assert(ns.ToggleHiddenFrame("BuffFrame") == false and BuffFrame:GetAlpha() == 1, "se muestra otra vez")
assert(BuffFrame.auraFrames[1]:IsMouseEnabled(), "botones con ratón otra vez")

-- Un marco cualquiera oculto por nombre deja de bloquear el ratón, y lo recupera al mostrarse
local mystery = M.CreateFrame("Frame", "Some_ClickBlocker", UIParent)
mystery:EnableMouse(true)
ns.ToggleHiddenFrame("Some_ClickBlocker")
assert(mystery:GetAlpha() == 0 and not mystery:IsMouseEnabled(), "oculto por nombre y sin ratón")
ns.ToggleHiddenFrame("Some_ClickBlocker")
assert(mystery:GetAlpha() == 1 and mystery:IsMouseEnabled(), "devuelto con ratón")

print("efectos del juego (Forever): OK")
