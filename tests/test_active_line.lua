-- Modo "solo cooldowns activos": se ven solo los hechizos en cooldown (no el GCD), los de esenciales y utilidad
-- juntos en una línea centrada en la barra de esenciales; al terminar, un segundo con destello
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
M.InstallCurves()

-- Cooldowns simulados: isActive e isOnGCD nunca son secretos en el juego
local spells = {}
for id = 1, 5 do spells[id] = { active = false, gcd = false } end
C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellCooldownDuration = function() return nil end,
    GetSpellCooldown = function(id)
        return { isActive = spells[id].active, isOnGCD = spells[id].gcd, startTime = { __secret = true } }
    end,
}

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua", "ActiveCooldowns.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.GetSpellHotkey = function() end

-- Dos barras de Blizzard: esenciales (tamaño normal) y utilidad (iconos al 75 %)
local function viewer(name, scale, padding)
    local v = M.CreateFrame("Frame", name)
    v.childXPadding = padding
    -- Como Blizzard: coloca los iconos en fila desde la izquierda
    function v:Layout()
        for _, item in ipairs(self._children) do
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", self, "TOPLEFT", (item.layoutIndex - 1) * 44, 0)
        end
    end
    v.itemScale = scale
    return v
end
local essential = viewer("EssentialCooldownViewer", 1, 4)
local utility = viewer("UtilityCooldownViewer", 0.75, 4)
local function item(v, index, spellID)
    local it = M.CreateFrame("Frame", nil, v)
    it.layoutIndex = index
    it._width, it._height = 40, 40
    it:SetScale(v.itemScale)
    it.Icon = it:CreateTexture()
    it.Cooldown = M.CreateFrame("Cooldown", nil, it)
    it.GetBaseSpellID = function() return spellID end
    return it
end
local e1, e2, e3 = item(essential, 1, 1), item(essential, 2, 2), item(essential, 3, 3)
local u1, u2 = item(utility, 1, 4), item(utility, 2, 5)
essential:Layout(); utility:Layout()
ns.HookViewers()

local function shown(it) return it:GetAlpha() > 0 end
local function offset(it)
    local point, rel, relPoint, x, y = it:GetPoint(1)
    assert(point == "CENTER" and rel == essential and relPoint == "CENTER" and y == 0,
        "anclado al centro de los esenciales: " .. tostring(point) .. " " .. tostring(relPoint))
    return x
end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function update()
    M.FireEvent("SPELL_UPDATE_COOLDOWN")
    M.Tick(0.2)
end

-- Desactivado (por defecto): no se toca nada
spells[2].active = true
update()
assert(shown(e1) and shown(e3) and shown(u2), "desactivado: todo visible")
assert(e2:GetPoint(1) == "TOPLEFT", "desactivado: posición de Blizzard")

-- Activado: e2 y u1 en cooldown real, e1 solo en el GCD
ns.db.activeOnly = true
spells[1] = { active = true, gcd = true }
spells[4].active = true
update()
assert(shown(e2) and shown(u1), "los cooldowns activos se ven")
assert(not shown(e1), "el GCD no cuenta como cooldown activo")
assert(not shown(e3) and not shown(u2), "los que están listos se ocultan")
assert(not e3:IsMouseMotionEnabled(), "un icono oculto no muestra su ayuda al pasar el ratón")
-- Línea centrada: e2 mide 40 en pantalla, u1 30 (40 al 75 %), separación 4 -> total 74
assert(near(offset(e2), -17), "e2 a la izquierda del centro: " .. offset(e2))
assert(near(offset(u1), 22 / 0.75), "u1 a la derecha, en sus propias unidades: " .. offset(u1))

-- Si Blizzard vuelve a colocar los iconos, la línea se rehace al momento
essential:Layout()
assert(near(offset(e2), -17), "tras el Layout de Blizzard sigue centrado")

-- Termina el cooldown de e2: un segundo visible con destello y después se va
spells[2].active = false
update()
assert(shown(e2), "al terminar se queda visible un momento")
local flash = ns.GetActiveFlash(e2)
assert(flash and flash:IsShown() and flash:GetAlpha() > 0, "con destello")
M.Tick(0.5); M.Tick(0.5); M.Tick(0.2)
assert(not shown(e2), "pasado el segundo se oculta")
assert(near(offset(u1), 0), "u1 solo queda en el centro: " .. offset(u1))

-- Sin destello: desaparece al momento
ns.db.activeFlash = false
spells[4].active = false
update()
assert(not shown(u1), "sin destello se oculta al momento")

-- Modo de edición abierto: todo visible y en su sitio de Blizzard
spells[3].active = true
EditModeManagerFrame = { IsEditModeActive = function() return true end }
update()
for _, it in ipairs({ e1, e2, e3, u1, u2 }) do
    assert(shown(it) and it:GetPoint(1) == "TOPLEFT", "modo de edición: todo como Blizzard")
    assert(it:IsMouseMotionEnabled(), "modo de edición: la ayuda vuelve")
end
EditModeManagerFrame = nil
update()
assert(shown(e3) and not shown(e2) and near(offset(e3), 0), "al salir del modo de edición vuelve la línea")

-- Desactivar la opción lo devuelve todo como estaba
ns.db.activeOnly = false
update()
for _, it in ipairs({ e1, e2, e3, u1, u2 }) do
    assert(shown(it) and it:GetPoint(1) == "TOPLEFT", "desactivado: todo como Blizzard")
end
print("solo cooldowns activos: OK")
