-- Buscador de la página "Cooldowns activos": no distingue mayúsculas ni acentos fuera del ASCII
-- (string.lower no cambia "Л" ni "É", así que en ruRU no se encontraba nada escribiendo en minúsculas)
package.path = "tests/?.lua;" .. package.path
local M, _, pages = require("addon_env")("ruRU")

-- Lo que hace el cliente: minúsculas y sin acentos, también en UTF-8
local FOLD = { ["Л"] = "л", ["Е"] = "е", ["É"] = "e", ["é"] = "e" }
CaseAccentInsensitiveParse = function(text)
    for from, to in pairs(FOLD) do text = text:gsub(from, to) end
    return text:lower()
end

Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 },
    SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 } }
local playerBook = {
    { itemType = 1, actionID = 200, spellID = 200, name = "Ледяная стрела", iconID = 1, isPassive = false, isOffSpec = false },
    { itemType = 1, actionID = 210, spellID = 210, name = "Éclair", iconID = 1, isPassive = false, isOffSpec = false },
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function()
        return { name = "Clase", itemIndexOffset = 0, numSpellBookItems = #playerBook, shouldHide = false, isGuild = false }
    end,
    GetSpellBookItemInfo = function(slot, bank) if bank ~= 1 then return playerBook[slot] end end,
    HasPetSpells = function() return 0 end,
}
local known = { [100] = true, [200] = true, [210] = true }
C_Spell.GetSpellName = function(id) if known[id] then return "S" .. id end end

M.FireEvent("ADDON_LOADED", "RuscuuCDM")
M.FireEvent("PLAYER_LOGIN")
for _ = 1, 3 do M.RunTimers() end

local page
for _, p in ipairs(pages) do if p.titleKey == "Active cooldowns" then page = p end end
page._width = 640
page:Show(); page:Fire("OnShow")

local function rows()
    local found = {}
    for _, f in ipairs(M.frames) do
        if f._parent == page.content and f._type == "CheckButton" and f.spellID and f:IsShown() then found[f.spellID] = f end
    end
    return found
end
local search
for _, f in ipairs(M.frames) do
    if f._type == "EditBox" and f._parent == page.content and f._scripts.OnTextChanged then search = f end
end
assert(search, "cuadro de buscar")
assert(rows()[200] and rows()[210], "se ven los dos hechizos")

local function find(text)
    search:SetText(text); search:Fire("OnTextChanged", true)
    return rows()
end
local r = find("ледяная")
assert(r[200] and not r[210], "en minúsculas encuentra el nombre en cirílico")
r = find("eclair")
assert(r[210] and not r[200], "sin acento encuentra el nombre acentuado")
r = find("210")
assert(r[210] and not r[200], "por número")

-- Sin la función del cliente se sigue buscando como antes
CaseAccentInsensitiveParse = nil
r = find("Ледяная")
assert(r[200], "sin la función del cliente")
io.write("buscador sin mayúsculas ni acentos: OK\n")
