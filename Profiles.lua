-- Ruscuu Cooldown Manager Forever: perfiles por especialización, temas e importar/exportar
local _, ns = ...
local L = ns.L

ns.activeProfile = "Default"

------------------------------------------------------------------------
-- Perfiles
------------------------------------------------------------------------

local function CharData()
    local key = UnitName("player") .. "-" .. GetRealmName()
    local chars = ns.global.chars
    chars[key] = chars[key] or { specs = {}, classProfiles = true }
    local char = chars[key]
    char.specs = char.specs or {}
    -- Antes todos los personajes usaban Default y se mezclaban los hechizos de varias clases. Lo que apuntaba a
    -- Default pasa a usar el perfil de su clase (una sola vez: después Default se puede volver a elegir).
    if not char.classProfiles then
        for spec, profile in pairs(char.specs) do
            if profile == "Default" then char.specs[spec] = nil end
        end
        if char.noSpec == "Default" then char.noSpec = nil end
        char.classProfiles = true
    end
    return char
end

-- Lo que solo tiene sentido para una clase: hechizos elegidos, su orden, sus sonidos y sus excepciones
local SPELL_KEYS = { "activeAdd", "activeRemove", "expireExclude" }

-- Copia de un perfil para otra clase: el aspecto se conserva, los hechizos que la clase no conoce no
local function CopyForClass(source)
    local copy = ns.CopyTable(source)
    local knows = ns.PlayerKnowsSpell or function() return nil end
    for _, key in ipairs(SPELL_KEYS) do
        if type(copy[key]) == "table" then
            for id in pairs(copy[key]) do
                if type(id) ~= "number" or knows(id) == false then copy[key][id] = nil end
            end
        end
    end
    local function keepKey(key)
        local id = type(key) == "string" and tonumber(key:match("^spell(%d+)$"))
        return not id or knows(id) ~= false
    end
    if type(copy.activeSound) == "table" then
        for key in pairs(copy.activeSound) do
            if not keepKey(key) then copy.activeSound[key] = nil end
        end
    end
    if type(copy.activeOrder) == "table" then
        local order = {}
        for _, key in ipairs(copy.activeOrder) do
            if keepKey(key) then order[#order + 1] = key end
        end
        copy.activeOrder = order
    end
    return copy
end

-- Perfil propio de la clase del personaje (se crea la primera vez como copia de Default, sin hechizos ajenos).
-- Es el que usa cada especialización mientras el jugador no elija otro.
local function ClassProfile()
    local className, class = UnitClass("player")
    if type(class) ~= "string" then return "Default" end
    local profiles, map = ns.global.profiles, ns.global.classProfiles
    local name = map[class]
    if name and profiles[name] then return name end
    name = type(className) == "string" and className ~= "" and className or class
    if not profiles[name] then profiles[name] = CopyForClass(profiles.Default or {}) end
    map[class] = name
    return name
end

-- Cambia el perfil activo sin reaplicar el estilo (se usa al cargar)
function ns.UseProfile(name)
    local profiles = ns.global.profiles
    if not profiles[name] then name = "Default" end
    profiles[name] = profiles[name] or {}
    ns.MigrateProfile(profiles[name])
    ns.ApplyDefaults(profiles[name], ns.PROFILE_DEFAULTS)
    ns.db = profiles[name]
    ns.activeProfile = name
end

-- Reaplica todo lo visual tras cambiar de perfil o de valores
function ns.RefreshAll()
    ns.UpdateExpire()
    ns.SkinAll()
    ns.StyleActionBars()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SetProfile(name)
    ns.UseProfile(name)
    ns.RefreshAll()
end

-- Perfil de una especialización; sin especialización (personajes de nivel bajo) se usa noSpec
function ns.ProfileForSpec(specIndex)
    local char = CharData()
    local name
    if specIndex then name = char.specs[specIndex] else name = char.noSpec end
    if name and ns.global.profiles[name] then return name end
    return ClassProfile()
end

function ns.SelectProfileForSpec()
    local name = ns.ProfileForSpec(ns.GetSpec())
    if name ~= ns.activeProfile then
        ns.SetProfile(name)
        ns.Print(L["Active profile: %s"]:format(name))
    end
end

function ns.AssignSpecProfile(specIndex, name)
    CharData().specs[specIndex] = name
    if specIndex == ns.GetSpec() then
        ns.SetProfile(name)
    elseif ns.RefreshOptions then
        ns.RefreshOptions()
    end
end

-- Elegir un perfil desde las opciones lo asigna también a la especialización actual
function ns.ChooseProfile(name)
    local spec = ns.GetSpec()
    if spec then
        ns.AssignSpecProfile(spec, name)
    else
        CharData().noSpec = name
        ns.SetProfile(name)
    end
end

function ns.GetProfileNames()
    local names = {}
    for name in pairs(ns.global.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function ns.CreateProfile(name, copyFrom)
    local profiles = ns.global.profiles
    if profiles[name] then
        ns.Print(L["A profile with that name already exists."], true)
        return
    end
    profiles[name] = copyFrom and profiles[copyFrom] and ns.CopyTable(profiles[copyFrom]) or {}
    ns.ChooseProfile(name)
end

function ns.RenameProfile(old, new)
    local profiles = ns.global.profiles
    if old == "Default" then
        ns.Print(L["The Default profile cannot be renamed."], true)
        return
    end
    if not profiles[old] or new == "" or new == old then return end
    if profiles[new] then
        ns.Print(L["A profile with that name already exists."], true)
        return
    end
    profiles[new], profiles[old] = profiles[old], nil
    for class, profile in pairs(ns.global.classProfiles) do
        if profile == old then ns.global.classProfiles[class] = new end
    end
    for _, char in pairs(ns.global.chars) do
        for spec, profile in pairs(char.specs or {}) do
            if profile == old then char.specs[spec] = new end
        end
        if char.noSpec == old then char.noSpec = new end
    end
    if ns.activeProfile == old then ns.activeProfile = new end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.DeleteProfile(name)
    if name == "Default" then
        ns.Print(L["The Default profile cannot be deleted."], true)
        return
    end
    ns.global.profiles[name] = nil
    for class, profile in pairs(ns.global.classProfiles) do
        if profile == name then ns.global.classProfiles[class] = nil end
    end
    -- Las especializaciones que usaban ese perfil vuelven a Default
    for _, char in pairs(ns.global.chars) do
        for spec, profile in pairs(char.specs or {}) do
            if profile == name then char.specs[spec] = nil end
        end
        if char.noSpec == name then char.noSpec = nil end
    end
    if ns.activeProfile == name then
        ns.SetProfile("Default")
    elseif ns.RefreshOptions then
        ns.RefreshOptions()
    end
end

-- Restablece el perfil indicado (no "el que esté activo al pulsar Sí")
function ns.ResetProfile(name)
    name = name or ns.activeProfile
    local profile = ns.global.profiles[name]
    if not profile then return end
    wipe(profile)
    if name == ns.activeProfile then
        ns.SetProfile(name)
    else
        ns.ApplyDefaults(profile, ns.PROFILE_DEFAULTS)
    end
end

-- Restablece solo algunas opciones del perfil activo (botón "Valores por defecto" de cada página)
function ns.ResetKeys(keys)
    for _, key in ipairs(keys) do
        local def = ns.PROFILE_DEFAULTS[key]
        if type(def) == "table" then
            ns.db[key] = ns.CopyTable(def)
        else
            ns.db[key] = def
        end
    end
    ns.RefreshAll()
end

------------------------------------------------------------------------
-- Temas: cambian colores y bordes del perfil activo
------------------------------------------------------------------------

ns.THEMES = {
    {
        nameKey = "Ruscuu Neon",
        values = {
            squareIcons = true, borderSize = 2, iconZoom = 0.08, borderClassColor = false, barClassColor = false,
            borderColor = { 0.61, 0.30, 1.00, 1 }, barColor = { 0.55, 0.25, 0.95, 1 },
            bgColor = { 0.07, 0.03, 0.12, 0.85 }, swipeColor = { 0.08, 0, 0.15, 0.75 },
            numberColor = { 0.95, 0.91, 0.84, 1 }, actionBarNumberColor = { 0.95, 0.91, 0.84, 1 },
            expireColor = { 1, 0.82, 0, 1 },
        },
    },
    {
        nameKey = "Minimal",
        values = {
            squareIcons = true, borderSize = 1, iconZoom = 0.10, borderClassColor = false, barClassColor = false,
            borderColor = { 0, 0, 0, 1 }, barColor = { 0.80, 0.80, 0.80, 1 },
            bgColor = { 0, 0, 0, 0.60 }, swipeColor = { 0, 0, 0, 0.7 },
            numberColor = { 1, 1, 1, 1 }, actionBarNumberColor = { 1, 1, 1, 1 },
            expireColor = { 1, 1, 1, 1 },
        },
    },
    {
        nameKey = "Dark",
        values = {
            squareIcons = true, borderSize = 1, iconZoom = 0.08, borderClassColor = false, barClassColor = false,
            borderColor = { 0.25, 0.22, 0.30, 1 }, barColor = { 0.35, 0.30, 0.45, 1 },
            bgColor = { 0.05, 0.05, 0.07, 0.90 }, swipeColor = { 0, 0, 0, 0.85 },
            numberColor = { 0.85, 0.85, 0.85, 1 }, actionBarNumberColor = { 0.85, 0.85, 0.85, 1 },
            expireColor = { 1, 0.82, 0, 1 },
        },
    },
    {
        nameKey = "Class color",
        values = {
            squareIcons = true, borderSize = 2, iconZoom = 0.08, borderClassColor = true, barClassColor = true,
            barColor = { 0.55, 0.25, 0.95, 1 }, bgColor = { 0, 0, 0, 0.7 }, swipeColor = { 0, 0, 0, 0.75 },
            numberColor = { 1, 1, 1, 1 }, actionBarNumberColor = { 1, 1, 1, 1 },
            expireColor = { 1, 0.82, 0, 1 },
        },
    },
    {
        nameKey = "Blizzard style",
        values = {
            squareIcons = false, borderSize = 0, iconZoom = 0, borderClassColor = false, barClassColor = false,
            barColor = { 1, 0.5, 0.25, 1 }, bgColor = { 0, 0, 0, 0.5 }, swipeColor = { 0, 0, 0, 0.7 },
            numberColor = { 1, 1, 1, 1 }, actionBarNumberColor = { 1, 1, 1, 1 },
            expireColor = { 1, 0.82, 0, 1 },
        },
    },
}

-- Si los valores del perfil coinciden con un tema, devuelve ese tema (para marcarlo en las opciones)
function ns.CurrentTheme()
    for _, theme in ipairs(ns.THEMES) do
        local same = true
        for k, v in pairs(theme.values) do
            local cur = ns.db[k]
            if type(v) == "table" then
                if type(cur) ~= "table" then
                    same = false
                else
                    for i = 1, 4 do
                        if math.abs((cur[i] or 1) - (v[i] or 1)) > 0.01 then same = false end
                    end
                end
            elseif cur ~= v then
                same = false
            end
            if not same then break end
        end
        if same then return theme end
    end
end

function ns.ApplyTheme(theme)
    for k, v in pairs(theme.values) do
        ns.db[k] = type(v) == "table" and ns.CopyTable(v) or v
    end
    ns.RefreshAll()
    ns.Print(L["Theme applied: %s"]:format(L[theme.nameKey]))
end

------------------------------------------------------------------------
-- Importar / exportar: "!RUSCUU:1!" + base64 de "clave=valor;clave=valor"
-- La importación nunca ejecuta código: solo acepta claves conocidas con el tipo y rango esperados.
------------------------------------------------------------------------

local PREFIX = "!RUSCUU:1!"
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local SPELL_SET_KEYS = { expireExclude = true, activeAdd = true, activeRemove = true, activeItems = true }
-- Claves de texto: una lista con orden ("a,b,c") o un conjunto ([clave] = true)
local KEY_LISTS = { activeOrder = "list", activeSound = "set" } -- conjuntos de hechizos: se exportan como "123,456"

local function B64Char(n)
    return B64:sub(n + 1, n + 1)
end

local function Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = B64Char(math.floor(n / 262144) % 64)
            .. B64Char(math.floor(n / 4096) % 64)
            .. (b and B64Char(math.floor(n / 64) % 64) or "=")
            .. (c and B64Char(n % 64) or "=")
    end
    return table.concat(out)
end

local function Decode(text)
    text = text:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #text, 4 do
        local n, pad = 0, 0
        for j = i, i + 3 do
            local ch = text:sub(j, j)
            local value = 0
            if ch == "" or ch == "=" then
                pad = pad + 1
            else
                value = B64:find(ch, 1, true) - 1
            end
            n = n * 64 + value
        end
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if pad < 2 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if pad < 1 then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

local function IsColor(value)
    return type(value) == "table" and value[1] ~= nil
end

local function Flatten(defaults, values, prefix, out)
    for k, def in pairs(defaults) do
        local key, v = prefix .. k, values[k]
        if KEY_LISTS[key] then
            local words = {}
            if KEY_LISTS[key] == "list" then
                for _, w in ipairs(type(v) == "table" and v or {}) do
                    if type(w) == "string" and w:match("^%w+$") then words[#words + 1] = w end
                end
            else
                for w, on in pairs(type(v) == "table" and v or {}) do
                    if on and type(w) == "string" and w:match("^%w+$") then words[#words + 1] = w end
                end
                table.sort(words)
            end
            out[#out + 1] = key .. "=" .. table.concat(words, ",")
        elseif SPELL_SET_KEYS[key] then
            local ids = {}
            for id, on in pairs(v or {}) do
                if on and tonumber(id) then ids[#ids + 1] = tostring(id) end
            end
            table.sort(ids)
            out[#out + 1] = key .. "=" .. table.concat(ids, ",")
        elseif IsColor(def) then
            v = type(v) == "table" and v or def
            out[#out + 1] = ("%s=%.3f,%.3f,%.3f,%.3f"):format(key, v[1], v[2], v[3], v[4] or 1)
        elseif type(def) == "table" then
            Flatten(def, type(v) == "table" and v or {}, key .. ".", out)
        elseif type(def) == "boolean" then
            out[#out + 1] = key .. "=" .. (v and "1" or "0")
        else
            out[#out + 1] = key .. "=" .. tostring(v)
        end
    end
end

function ns.ExportProfile()
    local out = {}
    Flatten(ns.PROFILE_DEFAULTS, ns.db, "", out)
    table.sort(out)
    return PREFIX .. Encode(table.concat(out, ";"))
end

local function Clamp(n, low, high)
    return math.max(low, math.min(high, n))
end

-- Escribe un valor importado si la clave existe en los valores por defecto y el valor es válido
local function ImportValue(target, key, raw)
    if KEY_LISTS[key] then
        if not raw:match("^[%w,]*$") then return false end
        local value = {}
        for w in raw:gmatch("%w+") do
            if KEY_LISTS[key] == "list" then value[#value + 1] = w else value[w] = true end
        end
        target[key] = value
        return true
    end
    if SPELL_SET_KEYS[key] then
        if not raw:match("^[%d,]*$") then return false end
        local set = {}
        for id in raw:gmatch("%d+") do set[tonumber(id)] = true end
        target[key] = set
        return true
    end
    local defaults = ns.PROFILE_DEFAULTS
    local parts = { strsplit(".", key) }
    for i = 1, #parts - 1 do
        defaults, target = defaults[parts[i]], target[parts[i]]
        if type(defaults) ~= "table" or IsColor(defaults) or type(target) ~= "table" then return false end
    end
    local k = parts[#parts]
    local def = defaults[k]
    if IsColor(def) then
        local r, g, b, a = raw:match("^([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]+)$")
        r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
        if not (r and g and b and a) then return false end
        target[k] = { Clamp(r, 0, 1), Clamp(g, 0, 1), Clamp(b, 0, 1), Clamp(a, 0, 1) }
    elseif type(def) == "boolean" then
        if raw ~= "1" and raw ~= "0" then return false end
        target[k] = raw == "1"
    elseif type(def) == "number" then
        local n = tonumber(raw)
        if not n then return false end
        local limits = ns.LIMITS[k]
        target[k] = limits and Clamp(n, limits[1], limits[2]) or n
    elseif type(def) == "string" then
        if ns.CHOICES[k] then
            if not ns.CHOICES[k][raw] then return false end
        elseif k == "font" then
            if not ns.IsKnownFont(raw) then return false end
        elseif k == "barTexture" then
            if not ns.IsKnownBarTexture(raw) then return false end
        else
            return false
        end
        target[k] = raw
    else
        return false
    end
    return true
end

function ns.ImportProfile(text)
    local payload = strtrim(text or ""):match("^" .. PREFIX:gsub("%p", "%%%0") .. "(.+)$")
    if not payload then return false, L["Invalid import string."] end

    -- Se importa sobre una copia y solo se aplica si al menos un valor es válido
    local imported = ns.CopyTable(ns.db)
    local count = 0
    for pair in Decode(payload):gmatch("[^;]+") do
        local key, raw = pair:match("^([%w%.]+)=(.*)$")
        if key and ImportValue(imported, key, raw) then count = count + 1 end
    end
    if count == 0 then return false, L["Invalid import string."] end

    wipe(ns.db)
    for k, v in pairs(imported) do ns.db[k] = v end
    ns.RefreshAll()
    return true, count
end
