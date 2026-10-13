-- Selector de color y botón de recargar: el selector siempre se cierra con Aceptar o Cancelar, aunque falle
-- algo al aplicar el estilo (el error sale en el chat), y cada página tiene un botón para recargar la interfaz
package.path = "tests/?.lua;" .. package.path
local M, ns, pages = require("addon_env")("esES")
local picker = M.InstallColorPicker()
local chat = {}
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end
geterrorhandler = function() return function() end end

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end
for _, page in ipairs(pages) do page._width = 640; page:Show(); page:Fire("OnShow") end

-- Muestras de color de las opciones: botones sin nombre con OnClick y la textura de relleno
local swatches = {}
for _, f in ipairs(M.frames) do
    if f._type == "Button" and not f._name and f._scripts and f._scripts.OnClick and f._regions and #f._regions >= 2
        and f:GetText() == nil then
        swatches[#swatches + 1] = f
    end
end
assert(#swatches == 10, "muestras de color: " .. #swatches)

-- Normal: Aceptar guarda el color, Cancelar lo devuelve, y el selector se cierra
local numberSwatch
for _, sw in ipairs(swatches) do
    sw:Fire("OnClick")
    if picker.previousValues.r == ns.db.numberColor[1] then numberSwatch = numberSwatch or sw end
    picker:ClickCancel()
end
local before = ns.CopyTable(ns.db.numberColor)
numberSwatch:Fire("OnClick")
assert(picker:IsShown(), "el selector se abre")
picker.rgb = { 1, 0, 0 }
picker:ClickOkay()
assert(not picker:IsShown(), "Aceptar cierra el selector")
assert(ns.db.numberColor[1] == 1 and ns.db.numberColor[2] == 0, "Aceptar guarda el color")
numberSwatch:Fire("OnClick")
picker.rgb = { 0, 1, 0 }
picker.swatchFunc() -- al mover el color se aplica al momento
picker:ClickCancel()
assert(not picker:IsShown(), "Cancelar cierra el selector")
assert(ns.db.numberColor[1] == 1 and ns.db.numberColor[2] == 0, "Cancelar devuelve el color anterior")
assert(#chat == 0, "sin errores no se escribe nada en el chat: " .. tostring(chat[1]))

-- Si aplicar el estilo falla, el selector se cierra igual y el error sale una vez en el chat
local realSkinAll = ns.SkinAll
ns.SkinAll = function() error("fallo de prueba") end
numberSwatch:Fire("OnClick")
picker.rgb = { 0, 0, 1 }
picker.swatchFunc(); picker.swatchFunc()
picker:ClickOkay()
assert(not picker:IsShown(), "con un error, Aceptar también cierra el selector")
numberSwatch:Fire("OnClick")
picker:ClickCancel()
assert(not picker:IsShown(), "con un error, Cancelar también cierra el selector")
local errors = 0
for _, line in ipairs(chat) do if line:find("fallo de prueba") then errors = errors + 1 end end
assert(errors == 1, "el error sale una sola vez en el chat (" .. errors .. ")")
ns.SkinAll = realSkinAll
ns.db.numberColor = before

-- Botón de recargar la interfaz en la cabecera de cada página
for i, page in ipairs(pages) do
    local found
    for _, child in ipairs(page._children or {}) do
        if child._type == "Button" and child:GetText() == ns.L["Reload UI"] then found = child end
    end
    assert(found, "la página " .. i .. " tiene el botón de recargar")
    found:Fire("OnClick")
end
assert(reloads == #pages, "cada botón recarga la interfaz")
io.write("selector de color y recargar: OK\n")
