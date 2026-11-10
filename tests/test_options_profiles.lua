-- Perfiles e importación: borrar el perfil de la clase no lo vuelve a crear, un texto cortado no se acepta,
-- la importación se puede deshacer, no trae hechizos de otra clase ni oculta marcos imprescindibles.
-- También: el ajuste de números del juego vuelve a su valor original y el selector de color no aplica dos veces.
package.path = "tests/?.lua;" .. package.path
local M, ns, pages = require("addon_env")("esES")
local picker = M.InstallColorPicker()
local chat = {}
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end

-- Los desplegables guardan su menú para poder elegir una opción desde la prueba
local realCreateFrame = CreateFrame
CreateFrame = function(kind, ...)
    local f = realCreateFrame(kind, ...)
    if kind == "DropdownButton" then f.SetupMenu = function(self, gen) self._gen = gen end end
    return f
end

-- El jugador tenía los números del juego desactivados antes de instalar el addon
C_CVar.SetCVar("countdownForCooldowns", "0")
local knownSpells = { [100] = true }
IsPlayerSpell = function(id) return knownSpells[id] == true end

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end
for _, page in ipairs(pages) do page._width = 640; page:Show(); page:Fire("OnShow") end

------------------------------------------------------------------------
-- Números de Blizzard: "Dejar el ajuste del juego" devuelve el valor que tenía
------------------------------------------------------------------------
assert(C_CVar.GetCVar("countdownForCooldowns") == "1", "el modo por defecto los activa")
assert(ns.global.countdownCVarOriginal == "0", "se guarda el valor original")
local numbersMenu
for _, f in ipairs(M.frames) do
    if f._type == "DropdownButton" and f._gen then
        local radios = {}
        f._gen(f, { CreateRadio = function(_, text, _, select) radios[text] = select end })
        if radios[ns.L["Leave the game setting"]] then numbersMenu = radios end
    end
end
assert(numbersMenu, "desplegable de los números de Blizzard")
numbersMenu[ns.L["Leave the game setting"]]()
assert(C_CVar.GetCVar("countdownForCooldowns") == "0", "vuelve el valor del jugador")
assert(ns.global.countdownCVarOriginal == nil, "ya no hay nada que devolver")
numbersMenu[ns.L["Always show"]]()
assert(C_CVar.GetCVar("countdownForCooldowns") == "1" and ns.global.countdownCVarOriginal == "0", "otra vez activado")
-- "Borrar todo" también lo devuelve
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end
local savedDB = RuscuuCDMDB
StaticPopupDialogs["RUSCUUCDM_RESET_ALL"].OnAccept()
assert(reloads == 1 and C_CVar.GetCVar("countdownForCooldowns") == "0", "borrar todo devuelve el ajuste")
RuscuuCDMDB = savedDB

------------------------------------------------------------------------
-- Selector de color: swatchFunc y opacityFunc en el mismo movimiento aplican el estilo una sola vez
------------------------------------------------------------------------
local skins = 0
local realSkinAll = ns.SkinAll
ns.SkinAll = function(...) skins = skins + 1; return realSkinAll(...) end
local swatch
for _, f in ipairs(M.frames) do
    if f._type == "Button" and not f._name and f._scripts and f._scripts.OnClick and f._regions and #f._regions >= 2
        and f:GetText() == nil and not swatch then
        f:Fire("OnClick")
        if picker:IsShown() then swatch = f end
        picker:Hide()
    end
end
assert(swatch, "muestra de color")
swatch:Fire("OnClick")
skins = 0
picker.rgb = { 0.123, 0.456, 0.789 }
picker.swatchFunc(); picker.opacityFunc()
assert(skins == 1, "un movimiento del selector aplica una vez: " .. skins)
picker:ClickCancel()
ns.SkinAll = realSkinAll

------------------------------------------------------------------------
-- Borrar el perfil de la clase: se vuelve a Default y el perfil borrado no reaparece
------------------------------------------------------------------------
ns.SelectProfileForSpec()
assert(ns.activeProfile == "Druida", "perfil de la clase: " .. ns.activeProfile)
ns.DeleteProfile("Druida")
assert(ns.activeProfile == "Default", "borrado: vuelve a Default")
assert(ns.ProfileForSpec(2) == "Default", "la especialización sigue en Default")
ns.SelectProfileForSpec()
M.FireEvent("PLAYER_LOGIN")
assert(ns.activeProfile == "Default", "tras volver a entrar sigue en Default: " .. ns.activeProfile)
assert(ns.global.profiles.Druida == nil, "el perfil borrado no se vuelve a crear")

------------------------------------------------------------------------
-- Importar: texto cortado, deshacer, hechizos de otra clase y marcos ocultos
------------------------------------------------------------------------
ns.CreateProfile("Mio")
assert(ns.activeProfile == "Mio", "perfil propio")
ns.db.iconZoom = 0.2
ns.db.activeAdd = { [100] = true }
ns.db.aurasHideFrames = { MiMarco = true }
local mine = ns.ExportProfile()

-- El texto de otro jugador: otra clase, otros hechizos y marcos que no se deben ocultar
ns.db.iconZoom = 0.05
ns.db.activeAdd = { [100] = true, [999] = true }
ns.db.activeOrder = { "spell999", "spell100" }
ns.db.aurasHideFrames = { WorldFrame = true, SettingsPanel = true, GameMenuFrame = true, ChatFrame1 = true,
    StaticPopup1 = true, OtroMarco = true }
local foreign = ns.ExportProfile()
ns.ImportProfile(mine)
assert(ns.db.iconZoom == 0.2, "vuelve lo propio")

-- Un texto cortado (por el chat o al copiar) no se importa y no cambia nada
local ok, err = ns.ImportProfile(foreign:sub(1, 300))
assert(not ok and err == ns.L["The text is incomplete: copy it again."], "texto cortado: " .. tostring(err))
assert(ns.db.iconZoom == 0.2, "nada cambia con un texto cortado")
assert(ns.ImportProfileAs("Cortado", foreign:sub(1, 300)) == nil and not ns.global.profiles.Cortado,
    "tampoco se guarda como perfil nuevo")
-- Un texto de una versión anterior (sin la cuenta) se sigue aceptando
local plain = ns.Base64Decode(foreign:sub(#"!RUSCUU:1!" + 1)):gsub("^n=%d+;", "")
assert(not plain:find("^n=") and not plain:find(";n="), "sin la cuenta")
assert(ns.ImportProfileAs("Antiguo", "!RUSCUU:1!" .. ns.Base64Encode(plain)) == "Antiguo", "texto antiguo")

chat = {}
assert(ns.ImportProfile(foreign), "importa")
assert(ns.db.iconZoom == 0.05, "se aplica el aspecto")
assert(ns.db.activeAdd[100] and not ns.db.activeAdd[999], "sin hechizos que el personaje no conoce")
assert(table.concat(ns.db.activeOrder, " ") == "spell100", "orden sin hechizos ajenos")
local hide = ns.db.aurasHideFrames
assert(hide.OtroMarco and not hide.WorldFrame and not hide.SettingsPanel and not hide.GameMenuFrame
    and not hide.ChatFrame1 and not hide.StaticPopup1, "no se ocultan marcos imprescindibles")
local warned = false
for _, line in ipairs(chat) do if line:find("OtroMarco") then warned = true end end
assert(warned, "se avisa de los marcos que oculta la importación")

-- Deshacer devuelve el perfil como estaba, en la misma tabla
local db = ns.db
assert(ns.UndoImport() == "Mio", "deshacer")
assert(ns.db == db and ns.db.iconZoom == 0.2 and ns.db.aurasHideFrames.MiMarco and not ns.db.aurasHideFrames.OtroMarco,
    "vuelve lo anterior")
assert(ns.UndoImport() == nil, "solo se deshace una vez")
io.write("perfiles e importación: OK\n")
