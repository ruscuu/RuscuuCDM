-- En combate el juego puede devolver el tamaño de los iconos del Cooldown Manager como valor secreto:
-- el borde dorado no debe operar con él (antes daba "attempt to perform numeric conversion on a secret number value")
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
M.InstallCurves()
local SECRET = { __secret = true }

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.RebuildExpireCurve()

local function expected(size)
    return math.floor(size * 0.36 * ns.db.expireGlowSize / 100 + 0.5)
end

-- Desplazamiento con el que se colocó el resplandor (el 5.º elemento del marco interior del borde)
local function glowOffset(owner)
    local _, inner = M.ExpireBorderFrame(owner)
    return inner._regions[5]._glowOffset
end

local function newIcon(w, h)
    local item = M.CreateFrame("Frame")
    local tex = item:CreateTexture()
    tex._width, tex._height = w, h
    return item, tex
end

local function track(item, tex)
    ns.TrackExpire(item, tex, function() end)
    local _, inner = M.ExpireBorderFrame(item)
    local glow = inner._regions[5]
    if not glow._wrapped then
        glow._wrapped = true
        glow.SetPoint = function(self, point, _, _, x) if point == "BOTTOMRIGHT" then self._glowOffset = x end end
        ns.TrackExpire(item, tex, function() end)
    end
end

-- Fuera de combate se lee el tamaño y se usa el lado corto
local item, tex = newIcon(40, 50)
track(item, tex)
assert(glowOffset(item) == expected(40), "fuera de combate se usa el lado corto del icono")

-- En combate el tamaño es secreto: no hay error y se mantiene el último tamaño conocido
tex._width, tex._height = SECRET, SECRET
local ok, err = pcall(track, item, tex)
assert(ok, "un tamaño secreto no debe dar error: " .. tostring(err))
assert(glowOffset(item) == expected(40), "con tamaño secreto se reutiliza el último tamaño conocido")

-- Solo un lado secreto: se usa el otro
tex._width, tex._height = SECRET, 30
track(item, tex)
assert(glowOffset(item) == expected(30), "con un solo lado secreto se usa el otro")

-- Un icono que nunca tuvo tamaño legible usa el de un botón normal (36)
local item2, tex2 = newIcon(SECRET, SECRET)
ok, err = pcall(track, item2, tex2)
assert(ok, "un icono nuevo con tamaño secreto no debe dar error: " .. tostring(err))
assert(glowOffset(item2) == expected(36), "sin tamaño conocido se usa 36")

print("tamaño secreto de los iconos: OK")
