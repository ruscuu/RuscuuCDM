-- El tiempo de reutilización global (GCD) no enciende el borde dorado, ni en los iconos del Cooldown Manager
-- ni en los botones de acción; un cooldown real que termina sí
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local Duration = M.InstallCurves()
local SECRET = { __secret = true }

-- Cooldown de cada hechizo: segundos restantes y si es solo el GCD (isOnGCD nunca es secreto en el juego)
local spells = {
    [10] = { remaining = 1.5, gcd = true },   -- solo el GCD
    [20] = { remaining = 2, gcd = false },    -- cooldown real a punto de terminar
}
local function cooldownInfo(spellID)
    local s = spells[spellID]
    return { isOnGCD = s.gcd, isActive = true, isEnabled = true, startTime = SECRET, duration = SECRET }
end
C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellCooldownDuration = function(id) return Duration(spells[id].remaining) end,
    GetSpellCooldown = cooldownInfo,
}
local slots = { [1] = 10, [2] = 20 }
HasAction = function(action) return slots[action] ~= nil end
GetActionInfo = function(action) if slots[action] then return "spell", slots[action] end end
C_ActionBar = {
    GetActionCooldownDuration = function(action) return Duration(spells[slots[action]].remaining) end,
    GetActionCooldown = function(action) return cooldownInfo(slots[action]) end,
}
GetBindingKey = function() end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua", "ActionBars.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)

-- Dos iconos del Cooldown Manager y dos botones de acción con los mismos hechizos
local essential = M.CreateFrame("Frame", "EssentialCooldownViewer")
local function cdItem(spellID)
    local item = M.CreateFrame("Frame", nil, essential)
    item.Icon = item:CreateTexture()
    item.Cooldown = M.CreateFrame("Cooldown", nil, item)
    item.GetBaseSpellID = function() return spellID end
    return item
end
local gcdIcon, realIcon = cdItem(10), cdItem(20)
local gcdButton, realButton = M.NewActionButton("ActionButton1", 1), M.NewActionButton("ActionButton2", 2)

ns.RebuildExpireCurve()
ns.HookActionBars()
ns.SkinAll()
-- Al lanzar un hechizo el juego avisa de que cambiaron los cooldowns
M.FireEvent("SPELL_UPDATE_COOLDOWN")
M.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
M.Tick()

assert(not M.ExpireBorder(gcdIcon), "el GCD no enciende el borde en el Cooldown Manager")
assert(not M.ExpireBorder(gcdButton), "el GCD no enciende el borde en los botones de acción")
assert(M.ExpireBorder(realIcon), "un cooldown real que termina sí lleva borde (Cooldown Manager)")
assert(M.ExpireBorder(realButton), "un cooldown real que termina sí lleva borde (botón de acción)")

-- Más tarde ese hechizo entra en un cooldown real que está terminando: ahora sí lleva borde
spells[10] = { remaining = 2, gcd = false }
M.FireEvent("SPELL_UPDATE_COOLDOWN")
M.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
M.Tick()
assert(M.ExpireBorder(gcdIcon) and M.ExpireBorder(gcdButton), "cooldown real después del GCD")

-- Si el juego no puede consultar el cooldown, el borde sigue funcionando como antes
C_Spell.GetSpellCooldown = function() error("no disponible") end
C_ActionBar.GetActionCooldown = nil
M.FireEvent("SPELL_UPDATE_COOLDOWN")
M.Tick()
assert(M.ExpireBorder(realIcon) and M.ExpireBorder(realButton), "sin la consulta no se rompe nada")
print("tiempo global (GCD): OK")
