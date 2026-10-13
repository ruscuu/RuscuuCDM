-- Borde dorado de cooldowns y aviso de buffs a punto de terminar (curvas de color simuladas)
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local Duration = M.InstallCurves()
local auras = {}       -- auraInstanceID -> segundos restantes
C_UnitAuras = { GetAuraDuration = function(_, id)
    if auras[id] == nil then error("aura no válida") end
    return Duration(auras[id])
end }
C_Spell = { GetSpellCooldownDuration = function() return Duration(2) end, GetBaseSpell = function(id) return id end }
local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.GetSpellHotkey = function() end

local function viewer(name) return M.CreateFrame("Frame", name) end
local ess, icons, bars = viewer("EssentialCooldownViewer"), viewer("BuffIconCooldownViewer"), viewer("BuffBarCooldownViewer")
local function cdItem(spellID)
    local it = M.CreateFrame("Frame", nil, ess)
    it.Icon = it:CreateTexture(); it.Cooldown = M.CreateFrame("Cooldown", nil, it)
    it.GetBaseSpellID = function() return spellID end
    return it
end
local function buffIcon(auraID)
    local it = M.CreateFrame("Frame", nil, icons)
    it.Icon = it:CreateTexture(); it.Cooldown = M.CreateFrame("Cooldown", nil, it)
    it.GetAuraSpellInstanceID = function() return auraID end
    it.GetAuraDataUnit = function() return "player" end
    return it
end
local function buffBar(auraID, iconShown)
    local it = M.CreateFrame("Frame", nil, bars)
    it.Icon = M.CreateFrame("Frame", nil, it); it.Icon.Icon = it.Icon:CreateTexture(); it.Icon._shown = iconShown
    it.Bar = M.CreateFrame("StatusBar", nil, it)
    it.GetAuraSpellInstanceID = function() return auraID end
    return it
end
local cd = cdItem(10)
local b1, b2, b3, bSecret, bGone = buffIcon(1), buffIcon(2), buffIcon(3), buffIcon({ __secret = true }), buffIcon(99)
local bar = buffBar(4, false)
auras[1], auras[2], auras[3], auras[4] = 3, 20, 0, 2   -- 3 s, 20 s, sin duración, 2 s

local tick = M.Tick
local borderOf = M.ExpireBorderFrame
local shownWithAlpha = M.ExpireBorder

-- Desactivado por defecto: los buffs no llevan borde
ns.RebuildExpireCurve(); ns.SkinAll(); tick()
assert(not borderOf(b1), "sin la opción no se crea el borde")
-- Activado: 3 s (dentro de 5 s) -> naranja; 20 s -> transparente; sin duración -> transparente
ns.db.buffEndGlow = true; ns.UpdateExpire(); ns.SkinAll(); tick()
local on, color = shownWithAlpha(b1)
assert(on and color[1] == 1 and math.abs(color[2] - 0.4) < 0.01, "buff a 3 s con borde naranja")
assert(not shownWithAlpha(b2), "buff a 20 s sin borde")
assert(not shownWithAlpha(b3), "buff sin duración sin borde")
assert(not shownWithAlpha(bSecret), "aura secreta: sin borde y sin error")
assert(not shownWithAlpha(bGone), "aura que ya no existe: sin borde")
-- La barra con el icono oculto: el borde rodea la barra
local on2 = shownWithAlpha(bar); assert(on2, "barra de buff a 2 s")
local border = borderOf(bar); assert(border._points[1][2] == bar.Bar, "borde anclado a la barra")
-- El cooldown sigue con su color dorado
local onCd, cdColor = shownWithAlpha(cd); assert(onCd and cdColor[2] > 0.8, "cooldown dorado")
-- Un aura que falla muchas veces no desactiva el aviso (no cuenta como error)
for _ = 1, 10 do tick() end
auras[99] = 1; tick(); assert(shownWithAlpha(bGone), "el aura vuelve a funcionar")
-- Desactivar solo el borde dorado deja el de buffs
ns.db.expireGlow = false; ns.UpdateExpire(); tick()
assert(not shownWithAlpha(cd) and shownWithAlpha(b1), "cada aviso por separado")
-- Prueba de 5 s: los buffs se ven con su color
ns.db.expireGlow = true; ns.UpdateExpire(); ns.SkinAll()
ns.Print = function() end
ns.TestExpire(5); tick()
local _, testColor = shownWithAlpha(b2); assert(testColor and math.abs(testColor[2] - 0.4) < 0.01, "vista previa en naranja")
print("bordes y buffs: OK")
