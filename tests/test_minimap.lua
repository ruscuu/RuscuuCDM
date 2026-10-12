-- Botón del minimapa: posición en minimapas redondos, cuadrados y con esquinas
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
assert(loadfile("Minimap.lua"))("RuscuuCDM", ns)

local function near(a, b) return math.abs(a - b) < 0.01 end
local function check(angle, shape, ex, ey)
    local x, y = ns.MinimapButtonOffset(angle, shape, 140, 140)
    assert(near(x, ex) and near(y, ey), ("%s %d°: %.2f,%.2f (esperado %.2f,%.2f)"):format(shape, angle, x, y, ex, ey))
end
local function onCircle(angle, r) return r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle)) end
local r = 80 -- 140 / 2 + 10 px de separación

-- Redondo: un círculo, como antes de admitir otras formas
check(0, "ROUND", r, 0)
check(90, "ROUND", 0, r)
check(45, "ROUND", onCircle(45, r))
check(225, "ROUND", onCircle(225, r))
-- Cuadrado: el botón sigue el borde recto
check(45, "SQUARE", r, r)
check(0, "SQUARE", r, 0)
check(225, "SQUARE", -r, -r)
check(30, "SQUARE", r, r * math.tan(math.rad(30)))
-- Formas mixtas (las que declara GetMinimapShape)
check(45, "CORNER-TOPRIGHT", onCircle(45, r))
check(135, "CORNER-TOPRIGHT", -r, r)
check(135, "SIDE-LEFT", onCircle(135, r))
check(315, "SIDE-LEFT", r, -r)
check(315, "TRICORNER-BOTTOMLEFT", onCircle(315, r))
check(45, "TRICORNER-BOTTOMLEFT", r, r)
-- Una forma desconocida se trata como redonda
check(45, "algo-raro", onCircle(45, r))
print("minimapa: OK")
