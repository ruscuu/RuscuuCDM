-- Página "Cooldowns activos": lista de hechizos (Cooldown Manager, libro con menús desplegables y mascota,
-- añadidos a mano), buscador, añadir por número o nombre, y que la barra use lo elegido.
-- También: los cooldowns de la mascota se piden por su hueco en el libro de la mascota.
package.path = "tests/?.lua;" .. package.path
local M, ns, pages = require("addon_env")("esES")
M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("PLAYER_ENTERING_WORLD")
for _ = 1, 3 do M.RunTimers() end

-- Libro de hechizos simulado: una línea de la clase con un hechizo, un pasivo y un menú desplegable,
-- una línea de otra especialización (no debe salir) y una mascota con un hechizo
Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 },
    SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 } }
local playerBook = {
    { itemType = 1, actionID = 200, spellID = 200, name = "Golpe", iconID = 1, isPassive = false, isOffSpec = false },
    { itemType = 1, actionID = 210, spellID = 210, name = "Golpe", iconID = 1, isPassive = false, isOffSpec = false },
    { itemType = 1, actionID = 201, spellID = 201, name = "Pasivo", iconID = 1, isPassive = true, isOffSpec = false },
    { itemType = 4, actionID = 7, name = "Portales", iconID = 1, isPassive = false, isOffSpec = false },
    { itemType = 1, actionID = 202, spellID = 202, name = "De otra especialización", iconID = 1, isPassive = false, isOffSpec = false },
}
local petBook = { { itemType = 3, actionID = 9, spellID = 400, name = "Zarpazo", iconID = 1, isPassive = false, isOffSpec = false } }
local petCooldown = { isActive = false, isOnGCD = false }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(line)
        if line == 1 then return { name = "Clase", itemIndexOffset = 0, numSpellBookItems = 4, shouldHide = false, isGuild = false } end
        return { name = "Otra", itemIndexOffset = 4, numSpellBookItems = 1, shouldHide = false, isGuild = false, offSpecID = 5 }
    end,
    GetSpellBookItemInfo = function(slot, bank)
        if bank == 1 then return petBook[slot] end
        return playerBook[slot]
    end,
    HasPetSpells = function() return #petBook, "PET" end,
    GetSpellBookItemCooldown = function(slot, bank)
        assert(slot == 1 and bank == 1, "el cooldown de la mascota se pide por su hueco")
        return petCooldown
    end,
    GetSpellBookItemCharges = function() return nil end,
    GetSpellBookItemCooldownDuration = function(slot, bank, ignoreGCD)
        assert(slot == 1 and bank == 1 and ignoreGCD == true, "duración de la mascota por su hueco, sin el GCD")
        return { pet = true }
    end,
}
GetFlyoutInfo = function(id) if id == 7 then return "Portales", "", 2, true end end
GetFlyoutSlotInfo = function(_, i)
    if i == 1 then return 300, 300, true, "Portal: Ventormenta" end
    return 301, 301, false, "Portal sin aprender"
end
local known = { [100] = true, [200] = true, [210] = true, [300] = true, [642] = true }
C_Spell.GetSpellName = function(id) if known[id] or id == 400 then return "S" .. id end end
C_Spell.GetSpellInfo = function(name) if name == "Escudo divino" then return { spellID = 642 } end end
local onCooldown = {}
C_Spell.GetSpellCooldown = function(id) if known[id] then return { isActive = onCooldown[id] == true, isOnGCD = false } end end

-- Lista del libro: sin pasivos ni otras especializaciones, con los del menú desplegable aprendidos y la mascota
local list = {}
for _, sp in ipairs(ns.GetSpellbookSpells()) do list[#list + 1] = sp.spellID end
-- Los rangos de un hechizo (Golpe 200 y 210) salen una sola vez, con el rango más alto
assert(table.concat(list, ",") == "210,300,400", "hechizos del libro: " .. table.concat(list, ","))

-- Abrir la página
local page
for _, p in ipairs(pages) do
    if p.titleKey == "Active cooldowns" then page = p end
end
assert(page, "hay una página de cooldowns activos")
page._width = 640
page:Show(); page:Fire("OnShow")
assert(page.built and page.content, "la página se construye")

local function rows()
    local found = {}
    for _, f in ipairs(M.frames) do
        if f._parent == page.content and f._type == "CheckButton" and f.spellID and f:IsShown() then
            found[f.spellID] = f
        end
    end
    return found
end
local function headers()
    local found = {}
    for _, r in ipairs(page.content._regions or {}) do
        if r._type == "FontString" and r:IsShown() and type(r._text) == "string" and r._text:match("%(%d+%)$") then
            found[#found + 1] = r._text
        end
    end
    return table.concat(found, " | ")
end

local r = rows()
assert(r[100] and r[210] and r[300] and r[400] and not r[201] and not r[202] and not r[301], "filas de la lista")
assert(r[100]:GetChecked() and not r[210]:GetChecked(), "los del Cooldown Manager vienen marcados, los demás no")
assert(headers():find("Cooldown Manager %(1%)") and headers():find("Libro de hechizos %(3%)"),
    "secciones de la lista: " .. headers())

-- Un rango bajo elegido antes (200) marca el hechizo; al desmarcarlo se quitan todos sus rangos
ns.db.activeAdd[200] = true
page:Hide(); page:Show(); page:Fire("OnShow")
r = rows()
assert(r[210] and not r[200] and r[210]:GetChecked(), "un rango elegido marca el hechizo")
r[210]:SetChecked(false); r[210]:Fire("OnClick")
assert(not ns.db.activeAdd[200] and not ns.db.activeAdd[210] and not r[210]:GetChecked(), "se quitan todos los rangos")
-- Marcar uno del libro y quitar uno del Cooldown Manager
r[210]:SetChecked(true); r[210]:Fire("OnClick")
r[100]:SetChecked(false); r[100]:Fire("OnClick")
assert(ns.db.activeAdd[210] and ns.db.activeRemove[100], "se guarda lo elegido")
assert(r[210]:GetChecked() and not r[100]:GetChecked(), "las casillas siguen lo elegido")

-- Buscador
local search, add, itemBox
for _, f in ipairs(M.frames) do
    if f._type == "EditBox" and f._parent == page.content then
        if f._scripts.OnTextChanged then
            search = f
        elseif f._scripts.OnEnterPressed and not f.plus then -- los de los deslizadores tienen botones - y +
            if add then itemBox = f else add = f end
        end
    end
end
assert(search and add and itemBox, "cuadros de buscar, añadir hechizo y añadir objeto")
search:SetText("portal"); search:Fire("OnTextChanged", true)
r = rows()
assert(r[300] and not r[210] and not r[100], "el buscador filtra por nombre")
search:SetText(""); search:Fire("OnTextChanged", true)
assert(rows()[210], "sin texto se ve todo")

-- Añadir por nombre o por número un hechizo que no está en el libro
local realPrint = print
local printed = {}
print = function(msg) printed[#printed + 1] = msg end
add:SetText("Escudo divino"); add:Fire("OnEnterPressed")
assert(ns.db.activeAdd[642] and add:GetText() == "", "añadido por nombre")
assert(rows()[642] and headers():find("Añadidos a mano %(1%)"), "sale en su sección: " .. headers())
add:SetText("99999"); add:Fire("OnEnterPressed")
print = realPrint
assert(not ns.db.activeAdd[99999] and printed[#printed]:find("99999"), "un hechizo que no existe no se añade")

-- Añadir un objeto por número o nombre: sale en su sección y se puede quitar
C_Item = {
    GetItemInfoInstant = function(x) if x == 5512 or x == "Piedra de salud" then return 5512 end end,
    GetItemNameByID = function(id) if id == 5512 then return "Piedra de salud" end end,
    GetItemIconByID = function() return 3000 end,
    GetItemCount = function() return 3 end,
}
print = function(msg) printed[#printed + 1] = msg end
itemBox:SetText("Piedra de salud"); itemBox:Fire("OnEnterPressed")
assert(ns.db.activeItems[5512] and itemBox:GetText() == "", "objeto añadido por nombre")
itemBox:SetText("123"); itemBox:Fire("OnEnterPressed")
print = realPrint
assert(not ns.db.activeItems[123] and printed[#printed]:find("123"), "un objeto que no existe no se añade")
assert(headers():find("Objetos %(1%)") and rows()[5512], "sale en la sección Objetos: " .. headers())
rows()[5512]:SetChecked(false); rows()[5512]:Fire("OnClick")
assert(not ns.db.activeItems[5512], "desmarcarlo lo quita")
ns.db.activeItems[5512] = true

-- La barra usa lo elegido: el de la mascota, por su hueco
ns.SetActiveSpellChosen(400, true)
ns.db.activeOnly = true
ns.RefreshActiveBar()
petCooldown.isActive = true
M.FireEvent("SPELL_UPDATE_COOLDOWN")
M.Tick(0.2)
local pet = ns.GetActiveIcon("spell400")
assert(pet and pet:IsShown() and pet.cd._cooldown.duration.pet, "el cooldown de la mascota se ve en la barra")
assert(not ns.GetActiveIcon("spell100"), "el quitado no tiene icono")

-- Da igual el rango: elegido Golpe (rango más alto, 210), sale en cooldown al lanzar el rango 1 (200)
onCooldown[200] = true
M.FireEvent("SPELL_UPDATE_COOLDOWN")
M.Tick(0.2)
local golpe = ns.GetActiveIcon("spell210")
assert(golpe and golpe:IsShown(), "el icono sale con cualquier rango en cooldown")
onCooldown[200] = nil
M.FireEvent("SPELL_UPDATE_COOLDOWN")
M.Tick(1.5)
assert(not golpe:IsShown(), "y se va cuando termina")

-- Página de orden y sonido: subir, bajar y sonido por hechizo
local orderPage
for _, p in ipairs(pages) do
    if p.titleKey == "Active cooldowns: order and sound" then orderPage = p end
end
assert(orderPage, "hay una página de orden y sonido")
orderPage._width = 640
orderPage:Show(); orderPage:Fire("OnShow")
local function orderRows()
    local found = {}
    for _, f in ipairs(M.frames) do
        if f._parent == orderPage.content and f.key and f:IsShown() then found[#found + 1] = f end
    end
    table.sort(found, function(a, b) return select(3, a:GetPoint(1)) > select(3, b:GetPoint(1)) end)
    return found
end
local function keys()
    local found = {}
    for _, row in ipairs(orderRows()) do found[#found + 1] = row.key end
    return table.concat(found, " ")
end
assert(keys() == "spell210 spell400 spell642 item5512", "orden inicial: " .. keys())
orderRows()[4].up:Fire("OnClick")
assert(keys() == "spell210 spell400 item5512 spell642", "subir: " .. keys())
orderRows()[1].down:Fire("OnClick")
assert(keys() == "spell400 spell210 item5512 spell642", "bajar: " .. keys())
assert(ns.db.activeOrder[1] == "spell400", "el orden se guarda en el perfil")
ns.RefreshActiveBar()
assert(ns.CountActiveEntries() == 4, "la barra tiene los cuatro")
local r1 = orderRows()[1]
r1.sound:SetChecked(true); r1.sound:Fire("OnClick")
assert(ns.db.activeSound.spell400, "sonido marcado")
-- Exportar e importar conserva el orden, el sonido y los objetos
local text = ns.ExportProfile()
ns.db.activeOrder, ns.db.activeSound, ns.db.activeItems = {}, {}, {}
assert(ns.ImportProfile(text), "importa")
assert(ns.db.activeOrder[1] == "spell400" and ns.db.activeOrder[3] == "item5512" and ns.db.activeSound.spell400
    and ns.db.activeItems[5512], "importar recupera orden, sonido y objetos")

-- Valores por defecto de la página: vuelve todo como al principio
ns.ResetKeys(page.resetKeys)
assert(next(ns.db.activeAdd) == nil and next(ns.db.activeRemove) == nil and not ns.db.activeOnly, "valores por defecto")
print("página de cooldowns activos: OK")
