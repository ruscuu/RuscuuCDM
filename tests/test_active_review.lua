-- Barra de cooldowns activos: correcciones de la revisión (cerrojo del cooldown real con GCD encadenados,
-- GET_ITEM_INFO_RECEIVED de objetos ajenos, borde del barrido en objetos, iconos de reserva de los buffs,
-- avisos de cooldown en ráfaga y una sola lectura del libro de hechizos por repaso)
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local Duration = M.InstallCurves()

local SECRET = { __secret = true }

local spells = {}
for _, id in ipairs({ 1, 2, 3, 60, 61, 62, 63, 70 }) do spells[id] = { active = false, gcd = false } end
local chargeCalls = 0
C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetOverrideSpell = function(id) return id end,
    GetSpellName = function(id) if spells[id] then return "Hechizo " .. id end end,
    GetSpellTexture = function(id) return 1000 + id end,
    GetSpellCooldown = function(id)
        local s = spells[id]
        if not s then return nil end
        return { isActive = s.active, isOnGCD = s.gcd, isEnabled = true, startTime = SECRET, duration = SECRET }
    end,
    GetSpellCooldownDuration = function(id)
        if spells[id] and spells[id].active then
            local d = Duration(10)
            d.spell = id
            return d
        end
    end,
    GetSpellCharges = function() chargeCalls = chargeCalls + 1 end,
    GetSpellChargeDuration = function() return {} end,
    GetSpellDisplayCount = function() return SECRET end,
}
-- El abalorio 13 en cooldown (no es secreto)
GetInventoryItemCooldown = function(_, slot)
    if slot == 13 then return GetTime() - 1, 30, 1 end
    return 0, 0, 1
end
GetInventoryItemTexture = function(_, slot) return 2000 + slot end
GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip")
C_Container = { GetItemCooldown = function() return 0, 0, 1 end }
-- Objetos: el 5 está en la caché; el 6 no carga nunca (número erróneo)
local loadRequests = 0
C_Item = {
    GetItemNameByID = function(id) if id == 5 then return "Objeto 5" end end,
    GetItemIconByID = function(id) return 4000 + id end,
    GetItemCount = function() return 1 end,
    RequestLoadItemDataByID = function() loadRequests = loadRequests + 1 end,
}
-- Hechizos que el personaje conoce según el juego (los rangos bajos no salen aquí)
IsPlayerSpell = function(id) return id == 1 or id == 2 or id == 3 or id == 70 end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua", "ActiveCooldowns.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.RebuildExpireCurve()

-- Libro: el 70 tiene un rango bajo, el 63. Se cuentan las lecturas completas.
local bookReads = 0
ns.GetSpellbookSpells = function()
    bookReads = bookReads + 1
    return { { spellID = 70, name = "Hechizo 70", ranks = { 63, 70 } } }
end

local essential = M.CreateFrame("Frame", "EssentialCooldownViewer")
local function item(v, index, spellID)
    local it = M.CreateFrame("Frame", nil, v)
    it.layoutIndex = index
    it._width, it._height = 40, 40
    it.Icon = it:CreateTexture()
    it.Cooldown = M.CreateFrame("Cooldown", nil, it)
    it.GetBaseSpellID = function() return spellID end
    return it
end
item(essential, 1, 1); item(essential, 2, 2); item(essential, 3, 3)
local buffs = M.CreateFrame("Frame", "BuffIconCooldownViewer")
local b1 = item(buffs, 1, 900)
b1.isActive = false
ns.HookViewers()

local function icon(key) return ns.GetActiveIcon(key) end
local function update()
    M.FireEvent("SPELL_UPDATE_COOLDOWN")
    M.Tick(0.2)
end

ns.db.activeOnly = true
ns.RefreshActiveBar()
M.Tick(0.2)

-- ACTIVE-BAR-1: el cooldown real termina en mitad de un GCD y le sigue otro GCD (cola de hechizos).
-- El juego sigue dando isActive (por el GCD), pero el barrido propio (sin GCD) acaba: el icono se va.
ns.db.activeFlash = false
spells[1] = { active = true, gcd = false }
update()
assert(icon("spell1"):IsShown(), "cooldown real: se ve")
spells[1] = { active = true, gcd = true }
update()
assert(icon("spell1"):IsShown(), "le queda menos que el GCD: sigue visible")
icon("spell1").cd:Fire("OnCooldownDone")
for _ = 1, 5 do update() end -- GCD encadenados: nunca se ve un momento sin cooldown
assert(not icon("spell1"):IsShown(), "terminado el barrido del cooldown real, el icono se oculta entre GCD")
-- Un barrido que no era de cooldown real (solo GCD) no quita el cerrojo de otro cooldown real
spells[1] = { active = false, gcd = false }
update()
spells[2] = { active = true, gcd = false }
update()
spells[2].gcd = true
update()
icon("spell1").cd:Fire("OnCooldownDone") -- otro icono: no toca al hechizo 2
M.Tick(0.2)
assert(icon("spell2"):IsShown(), "el cooldown real del 2 sigue anotado")
spells[2] = { active = false, gcd = false }
update()
ns.db.activeFlash = true

-- ACTIVE-BAR-8: varios hechizos añadidos que el juego da por desconocidos: el libro se lee una sola vez
ns.db.activeAdd = { [60] = true, [61] = true, [62] = true, [63] = true }
bookReads = 0
ns.RefreshActiveBar()
assert(bookReads == 1, "una sola lectura del libro por repaso: " .. bookReads)
local keys = {}
for _, e in ipairs(ns.GetActiveEntryList()) do keys[e.key] = true end
assert(keys.spell63 and not keys.spell60 and not keys.spell61, "el rango del libro sale, los desconocidos no")
-- Sin las tablas del libro (página de opciones) se sigue pudiendo preguntar
assert(ns.PlayerKnowsSpell(63) == true and ns.PlayerKnowsSpell(60) == false, "consulta suelta")
ns.db.activeAdd = {}
ns.RefreshActiveBar()

-- ACTIVE-BAR-2: GET_ITEM_INFO_RECEIVED de un objeto que no está en la barra no rehace nada
ns.db.activeItems = { [5] = true, [6] = true }
ns.RefreshActiveBar()
M.Tick(0.2)
assert(loadRequests == 1, "el objeto que no carga se pide: " .. loadRequests)
bookReads = 0
for id = 100, 120 do M.FireEvent("GET_ITEM_INFO_RECEIVED", id, true) end
M.Tick(0.2)
assert(bookReads == 0, "objetos ajenos: sin repaso de la lista: " .. bookReads)
-- El que no carga avisa con success = false: no se rehace ni se vuelve a pedir
M.FireEvent("GET_ITEM_INFO_RECEIVED", 6, false)
M.Tick(0.2)
assert(bookReads == 0, "un objeto que no cargó no rehace la lista")
ns.RefreshActiveBar(); ns.RefreshActiveBar()
assert(loadRequests == 1, "un objeto que no carga se pide una sola vez: " .. loadRequests)
-- El de la barra que llega bien sí rehace la lista (su nombre ya está)
bookReads = 0
M.FireEvent("GET_ITEM_INFO_RECEIVED", 5, true)
M.Tick(0.2)
assert(bookReads == 1, "objeto de la barra: se rehace: " .. bookReads)
ns.db.activeItems = {}

-- ACTIVE-BAR-3: volver a "como Blizzard" quita el borde del barrido en los abalorios
ns.db.activeTrinket1 = true
ns.db.cooldownEdge = "show"
ns.RefreshActiveBar()
local trinket = icon("slot13")
assert(trinket and trinket:IsShown() and trinket.cd._edge == true, "abalorio con borde")
ns.db.cooldownEdge = "blizzard"
ns.RefreshActiveBar()
assert(trinket.cd._edge == false, "como Blizzard: el abalorio pierde el borde")
ns.db.activeTrinket1 = false
ns.RefreshActiveBar()

-- ACTIVE-BAR-4: un icono de buff devuelto a la lista de Blizzard (isActive = nil) no reutiliza su estado anterior
buffs.hideWhenInactive = false
b1.isActive = true
M.Tick(0.2)
assert(b1:GetAlpha() > 0, "buff activo en la línea")
b1.isActive = nil
M.Tick(0.2)
assert(b1:GetAlpha() == 0, "icono de reserva vacío: fuera de la línea")

-- ACTIVE-BAR-5: los avisos de cooldown en ráfaga se juntan en un solo repaso, en el siguiente fotograma
M.Tick(0.2)
chargeCalls = 0
for _ = 1, 4 do
    M.FireEvent("SPELL_UPDATE_CHARGES")
    M.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
end
assert(chargeCalls == 0, "sin repaso dentro de cada aviso: " .. chargeCalls)
M.Tick(0.01)
local once = chargeCalls
assert(once > 0, "el repaso llega en el siguiente fotograma")
M.Tick(0.01)
assert(chargeCalls == once, "uno solo para toda la ráfaga")

print("barra de cooldowns activos (revisión): OK")
