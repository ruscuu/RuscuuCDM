-- Beneficios y perjuicios elegidos en la barra de cooldowns activos: salen mientras están (en el personaje, o
-- los del personaje en su objetivo), con el tiempo restante y las acumulaciones que da el juego, destello y sonido
-- al aparecer, cualquier rango por su nombre, y en combate (datos secretos) se sigue el aura que ya se encontró.
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local Duration = M.InstallCurves()

local SECRET = { __secret = true }

C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetOverrideSpell = function(id) return id end,
    GetSpellName = function(id) return "Hechizo " .. id end,
    GetSpellTexture = function(id) return 1000 + id end,
    GetSpellCooldown = function() return nil end,
}
GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip")
local played = {}
SOUNDKIT = { READY_CHECK = 8960 }
PlaySound = function(kit) played[#played + 1] = kit end

-- Auras simuladas por unidad: { spellId, name, auraInstanceID, applications, remaining, count, filter }
local auras = { player = {}, target = {} }
local targetExists = true
UnitExists = function(unit) return unit == "player" or targetExists end
local function find(unit, id)
    for _, a in ipairs(auras[unit]) do
        if a.auraInstanceID == id then return a end
    end
end
local filters = {}
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index, filter)
        filters[unit] = filter
        return auras[unit][index]
    end,
    GetAuraDataByAuraInstanceID = function(unit, id) return find(unit, id) end,
    GetAuraDuration = function(unit, id)
        local a = find(unit, id)
        if a and a.remaining then
            local d = Duration(a.remaining)
            d.aura = id
            return d
        end
    end,
    GetAuraApplicationDisplayCount = function(unit, id)
        local a = find(unit, id)
        return a and a.count or ""
    end,
}

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua", "ActiveCooldowns.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.RebuildExpireCurve()
ns.db.activeOnly, ns.db.activeShow = true, "always"

local function update(event, unit)
    M.FireEvent(event or "UNIT_AURA", unit or "player")
    M.Tick(0.2)
end

-- Elegido un beneficio (700) que todavía no está: sin icono
ns.SetActiveAuraChosen("buff", 700, true)
ns.db.activeSound.buff700 = true
ns.RefreshActiveBar()
update()
local f = ns.GetActiveIcon("buff700")
assert(f and not f:IsShown(), "sin el beneficio no sale")
assert(filters.player == "HELPFUL", "los beneficios se buscan en el personaje")
assert(ns.CountActiveEntries() == 1, "una entrada en la barra")

-- Salta el proc: sale con su tiempo restante, sus acumulaciones, destello y sonido
auras.player[1] = { spellId = 700, name = "Hechizo 700", auraInstanceID = 11, applications = 2, remaining = 8, count = "2" }
update()
assert(f:IsShown(), "con el beneficio sale")
assert(f.cd._cooldown and f.cd._cooldown.duration.aura == 11, "el barrido usa la duración del aura que da el juego")
assert(f.count:IsShown() and f.count:GetText() == "2", "con sus acumulaciones")
assert(not f.icon:IsDesaturated(), "un beneficio no se ve en gris")
assert(f.icon._texture == 1700, "con el icono del hechizo")
assert(#played == 1, "suena al aparecer")
assert(ns.GetActiveFlash("buff700"):IsShown(), "destello al aparecer")
M.Tick(1.2)
assert(not ns.GetActiveFlash("buff700"):IsShown(), "el destello se apaga")
update()
assert(#played == 1, "no vuelve a sonar mientras sigue")

-- Cambian las acumulaciones (el juego avisa con UNIT_AURA): el texto se actualiza, aunque sea secreto
auras.player[1].count = SECRET
update()
assert(f.count:GetText() == SECRET, "el número de acumulaciones se pasa tal cual")

-- Borde de "buff a punto de terminar" (no el dorado de los cooldowns)
ns.db.buffEndGlow, ns.db.expireGlow = true, false
ns.UpdateExpire()
auras.player[1].remaining = 2
update()
M.Tick(0.2)
assert(M.ExpireBorder(f), "borde cuando el beneficio está terminando")
ns.db.buffEndGlow, ns.db.expireGlow = false, true
ns.UpdateExpire()
M.Tick(0.2)
assert(not M.ExpireBorder(f), "sin el aviso de buffs no hay borde")

-- En combate el juego oculta qué auras son: se sigue la que ya se encontró mientras exista
auras.player[1].spellId, auras.player[1].name = SECRET, SECRET
update()
assert(f:IsShown(), "en combate sigue mientras el aura exista")
assert(ns.ActiveAurasHidden() == true, "el diagnóstico sabe que el juego las oculta")
table.remove(auras.player, 1)
auras.player[1] = { spellId = SECRET, name = SECRET, auraInstanceID = 99 }
update()
assert(not f:IsShown(), "cuando el aura termina, se va (sin despedirse con destello)")
assert(not ns.GetActiveFlash("buff700"):IsShown(), "sin destello al terminar")
auras.player = {}
update()

-- Otro rango del mismo beneficio (mismo nombre, otro número) también cuenta
auras.player[1] = { spellId = 701, name = "Hechizo 700", auraInstanceID = 12, applications = 1, count = "" }
update()
assert(f:IsShown(), "cualquier rango por su nombre")
assert(not f.cd._cooldown, "un aura sin duración no tiene barrido")
assert(#played == 2, "vuelve a sonar al aparecer de nuevo")
auras.player = {}
update()
assert(not f:IsShown(), "y se va al terminar")

-- Perjuicio del personaje en su objetivo
ns.SetActiveAuraChosen("debuff", 800, true)
ns.RefreshActiveBar()
update("PLAYER_TARGET_CHANGED")
local d = ns.GetActiveIcon("debuff800")
assert(d and not d:IsShown(), "sin el perjuicio no sale")
auras.target[1] = { spellId = 800, name = "Hechizo 800", auraInstanceID = 21, applications = 3, remaining = 12, count = "3" }
update("UNIT_AURA", "target")
assert(d:IsShown() and d.count:GetText() == "3", "el perjuicio en el objetivo sale con sus acumulaciones")
assert(filters.target == "HARMFUL|PLAYER", "solo los perjuicios que pone el personaje")
targetExists = false
update("PLAYER_TARGET_CHANGED")
assert(not d:IsShown(), "sin objetivo no sale")
targetExists = true

-- Orden y nombres en la página de orden y sonido
local list = ns.GetActiveEntryList()
assert(#list == 2 and list[1].key == "buff700" and list[2].key == "debuff800", "beneficios y después perjuicios")
assert(list[1].name:find("Hechizo 700") and list[1].icon == 1700, "con su nombre y su icono")

-- Lista de opciones: los vistos en esta sesión (sin las auras largas) y los elegidos
auras.player = {
    { spellId = 900, name = "Proc", auraInstanceID = 31, duration = 10 },
    { spellId = 901, name = "Comida", auraInstanceID = 32, duration = 3600 },
}
update()
local seen = {}
for _, sp in ipairs(ns.GetActiveAuraList("buff")) do seen[sp.spellID] = sp.name end
assert(seen[900] == "Proc" and not seen[901] and seen[700], "vistos y elegidos, sin las auras largas")
auras.player = {}
update()
seen = {}
for _, sp in ipairs(ns.GetActiveAuraList("buff")) do seen[sp.spellID] = true end
assert(seen[900], "el proc sigue en la lista aunque haya terminado")

-- Quitarlo de la lista lo quita de la barra
ns.SetActiveAuraChosen("buff", 700, false)
ns.RefreshActiveBar()
assert(ns.CountActiveEntries() == 1, "quitado de la barra")
print("beneficios y perjuicios en la barra: OK")
