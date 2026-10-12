-- Carga el addon completo en el orden del .toc, simula el inicio de sesión y abre cada página de opciones.
-- Uso: luajit tests/load_addon.lua <idioma del cliente>   (por ejemplo esES; por defecto enUS)
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local clientLocale = arg[1] or "enUS"
GetLocale = function() return clientLocale end

-- Lo que el addon consulta del juego al cargar y al iniciar sesión
local cvars = { cooldownViewerEnabled = "1" }
C_CVar = { GetCVar = function(k) return cvars[k] end, SetCVar = function(k, v) cvars[k] = v end }
SetCVar = C_CVar.SetCVar
UnitClass = function() return "Druida", "DRUID", 11 end
UnitName = function() return "Alma" end
GetRealmName = function() return "Reino" end
C_SpecializationInfo = {
    GetSpecialization = function() return 2 end,
    GetSpecializationInfo = function(i) return i, "Spec" .. i, "", 134400 end,
    GetNumSpecializationsForClassID = function() return 4 end,
}
GetNumSpecializations = function() return 4 end
C_ClassColor = { GetClassColor = function() return { r = 1, g = 0.49, b = 0.04 } end }
IsLoggedIn = function() return true end
GetBindingKey = function(command) if command == "ACTIONBUTTON1" then return "1" end end
GetBindingText = function(key) return key end
HasAction = function(action) if action > 180 then error("hueco no válido") end return action == 1 end
GetActionInfo = function(action) if action == 1 then return "spell", 100 end end
C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellName = function(id) return "S" .. id end,
    GetSpellTexture = function() return 134400 end,
    GetSpellCooldownDuration = function() return nil end,
}
C_ActionBar = { GetActionCooldownDuration = function() return nil end }
Minimap = M.CreateFrame("Frame", "Minimap"); Minimap._width, Minimap._height = 140, 140
GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SOUNDKIT = {}; PlaySound = function() end
YES, NO, ACCEPT, CANCEL = "Yes", "No", "Accept", "Cancel"
StaticPopup_Show = function() end
local pages = {}
Settings = {
    RegisterCanvasLayoutCategory = function(frame) pages[#pages + 1] = frame; return { GetID = function() return 1 end } end,
    RegisterAddOnCategory = function() end,
    RegisterCanvasLayoutSubcategory = function(_, frame) pages[#pages + 1] = frame; return { GetID = function() return #pages end } end,
    OpenToCategory = function() end,
}

-- Un icono en el Cooldown Manager y la barra principal con un hechizo en la tecla 1
local essential = M.CreateFrame("Frame", "EssentialCooldownViewer")
local item = M.CreateFrame("Frame", nil, essential)
item.Icon = item:CreateTexture()
item.Cooldown = M.CreateFrame("Cooldown", nil, item)
item.GetBaseSpellID = function() return 100 end
for i = 1, 12 do
    local button = M.NewActionButton("ActionButton" .. i, i)
    button.bindingAction = "ACTIONBUTTON" .. i
end

-- Todos los archivos del .toc, en su orden
local ns = {}
for line in io.lines("RuscuuCDM.toc") do
    if line:match("%.lua$") then M.Load(ns, (line:gsub("\\", "/"))) end
end

-- Inicio de sesión
M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("PLAYER_ENTERING_WORLD")
for _ = 1, 3 do M.RunTimers() end
assert(ns.GetSpellHotkey(100) == "1", "tecla del hechizo tras iniciar sesión")

-- Páginas de opciones: empiezan ocultas y se construyen la primera vez que se muestran
-- (si empezaran visibles, la primera vez saldrían en blanco)
assert(#pages == 7, "páginas registradas: " .. #pages)
for i, page in ipairs(pages) do
    assert(not page:IsShown(), "la página " .. i .. " debe empezar oculta")
    page._width = 640
    page:Show(); page:Fire("OnShow")
    assert(page.built and page.content, "la página " .. i .. " se construye la primera vez")
end

-- Cuadros de valor de los deslizadores (se buscan por el valor que muestran)
local function findBox(text)
    for _, f in ipairs(M.frames) do
        if f._type == "EditBox" and f._scripts and f._scripts.OnEnterPressed and f:GetText() == text then return f end
    end
    error("no hay ningún cuadro que muestre " .. text)
end
local function typeInto(box, text)
    box:SetFocus(); box:SetText(text); box:Fire("OnEnterPressed")
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

local crop = findBox("8%")                      -- recorte del icono: se ve en %, se guarda de 0 a 0.25
typeInto(crop, "20%")
assert(near(ns.db.iconZoom, 0.20), "recorte escrito: " .. tostring(ns.db.iconZoom))
assert(crop:GetText() == "20%", "vuelve a mostrar el valor con su formato: " .. tostring(crop:GetText()))
crop:Fire("OnMouseWheel", 1)
assert(near(ns.db.iconZoom, 0.21), "rueda del ratón: " .. tostring(ns.db.iconZoom))
typeInto(crop, "90")
assert(near(ns.db.iconZoom, 0.25), "se limita al máximo: " .. tostring(ns.db.iconZoom))
typeInto(crop, "abc")
assert(near(ns.db.iconZoom, 0.25) and crop:GetText() == "25%", "un texto no válido no cambia nada")

local seconds = findBox("3.0 s")                -- últimos segundos del borde dorado (paso de 0,5)
typeInto(seconds, "3,7 s")
assert(near(ns.db.expireSeconds, 3.5), "coma decimal y ajuste al paso: " .. tostring(ns.db.expireSeconds))
seconds:SetFocus(); seconds:SetText("9"); seconds:Fire("OnEscapePressed")
assert(near(ns.db.expireSeconds, 3.5) and seconds:GetText() == "3.5 s", "Escape descarta lo escrito")

-- Exportar e importar conserva las opciones nuevas
local text = ns.ExportProfile()
ns.db.keybindAnchor = "BOTTOMLEFT"; ns.db.buffEndGlow = true; ns.db.bars.addons = false
local ok = ns.ImportProfile(text)
assert(ok and ns.db.keybindAnchor == "TOPRIGHT" and ns.db.buffEndGlow == false and ns.db.bars.addons == true,
    "importar recupera las opciones nuevas")

-- Diagnóstico (/rcm debug) sin errores en este idioma
local realPrint = print
print = function() end
ns.Debug()
print = realPrint
print("addon completo (" .. clientLocale .. "): OK")
