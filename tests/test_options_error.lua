-- Si algo falla al construir una página de opciones, la página muestra el error en vez de quedarse en blanco,
-- y el error llega al gestor de errores del juego
package.path = "tests/?.lua;" .. package.path
local M, ns, pages = require("addon_env")("esES")
local reported
geterrorhandler = function() return function(err) reported = err end end

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end

-- La vista previa falla (como pasó con un texto sin fuente) en la página Cooldown Manager
local realPreview = ns.CreatePreview
ns.CreatePreview = function() error("fallo de prueba") end
local page = pages[2]
page._width = 640
page:Show(); page:Fire("OnShow")

assert(reported and tostring(reported):find("fallo de prueba"), "el error se envía al gestor de errores")
local shown = false
for _, region in ipairs(page.content._regions or {}) do
    local text = region._text
    if type(text) == "string" and text:find("no se pudo mostrar") and text:find("fallo de prueba") then shown = true end
end
assert(shown, "la página muestra el aviso con el error")

-- Sin el fallo, las demás páginas se construyen enteras y sin errores
ns.CreatePreview = realPreview
reported = nil
for i, other in ipairs(pages) do
    if other ~= page then
        other._width = 640
        other:Show(); other:Fire("OnShow")
        assert(other.built and not reported, "la página " .. i .. " se construye sin errores")
    end
end
print("páginas con error: OK")
