-- Borde dorado de cooldowns y aviso de buffs a punto de terminar (curvas de color simuladas)
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
-- Curvas de color y duraciones simuladas: la curva se evalúa por tramos lineales
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGBA = function(c) return c.r, c.g, c.b, c.a end } end
C_CurveUtil = { CreateColorCurve = function()
    local cv = { points = {} }
    function cv:AddPoint(x, c) table.insert(self.points, { x = x, c = c }) end
    function cv:Evaluate(x)
        local p = self.points
        for i = 1, #p - 1 do
            if x >= p[i].x and x <= p[i + 1].x then
                local t = (x - p[i].x) / (p[i + 1].x - p[i].x)
                local a, b = p[i].c, p[i + 1].c
                return CreateColor(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
            end
        end
        return p[#p].c
    end
    return cv
end }
local function Duration(remaining)
    return { EvaluateRemainingDuration = function(_, curve) return curve:Evaluate(remaining) end }
end
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

local driver
for _, f in ipairs(M.frames) do if f._scripts and f._scripts.OnUpdate and not f._parent then driver = f end end
local function tick() M.now = (M.now or 100) + 0.2; driver._scripts.OnUpdate(driver, 0.2) end
local function borderOf(item)
    for _, child in ipairs(item._children or {}) do
        if child._children and child._children[1] and child._children[1]._regions and #child._children[1]._regions == 5 then
            return child, child._children[1]._regions[1]
        end
    end
end
local function shownWithAlpha(item)
    local border, edge = borderOf(item)
    if not border or not border._shown then return false end
    return edge._vertex[4] > 0.5, edge._vertex
end

-- Desactivado por defecto: los buffs no llevan borde
ns.RebuildExpireCurve(); ns.SkinAll(); tick()
assert(borderOf(b1) == nil, "sin la opción no se crea el borde")
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
