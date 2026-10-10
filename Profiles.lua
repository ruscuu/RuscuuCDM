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
    chars[key] = chars[key] or { specs = {} }
    return chars[key]
end

-- Cambia el perfil activo sin reaplicar el estilo (se usa al cargar)
function ns.UseProfile(name)
    local profiles = ns.global.profiles
    if not profiles[name] then name = "Default" end
    profiles[name] = profiles[name] or {}
    ns.ApplyDefaults(profiles[name], ns.PROFILE_DEFAULTS)
    ns.db = profiles[name]
    ns.activeProfile = name
end

-- Reaplica todo lo visual tras cambiar de perfil o de valores
function ns.RefreshAll()
    ns.SkinAll()
    ns.StyleActionBars()
    ns.ApplyActionBarNumbers()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SetProfile(name)
    ns.UseProfile(name)
    ns.RefreshAll()
end

function ns.ProfileForSpec(specIndex)
    local name = specIndex and CharData().specs[specIndex]
    if name and ns.global.profiles[name] then return name end
    return "Default"
end

function ns.SelectProfileForSpec()
    local name = ns.ProfileForSpec(GetSpecialization())
    if name ~= ns.activeProfile then
        ns.SetProfile(name)
        ns.Print(L["Active profile: %s"]:format(name))
    end
end

function ns.AssignSpecProfile(specIndex, name)
    CharData().specs[specIndex] = name
    if specIndex == GetSpecialization() then
        ns.SetProfile(name)
    elseif ns.RefreshOptions then
        ns.RefreshOptions()
    end
end

-- Elegir un perfil desde las opciones lo asigna también a la especialización actual
function ns.ChooseProfile(name)
    local spec = GetSpecialization()
    if spec then
        ns.AssignSpecProfile(spec, name)
    else
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
        ns.Print(L["A profile with that name already exists."])
        return
    end
    profiles[name] = copyFrom and profiles[copyFrom] and ns.CopyTable(profiles[copyFrom]) or {}
    ns.ChooseProfile(name)
end

function ns.DeleteProfile(name)
    if name == "Default" then
        ns.Print(L["The Default profile cannot be deleted."])
        return
    end
    ns.global.profiles[name] = nil
    -- Las especializaciones que usaban ese perfil vuelven a Default
    for _, char in pairs(ns.global.chars) do
        for spec, profile in pairs(char.specs) do
            if profile == name then char.specs[spec] = nil end
        end
    end
    if ns.activeProfile == name then
        ns.SetProfile("Default")
    elseif ns.RefreshOptions then
        ns.RefreshOptions()
    end
end

function ns.ResetProfile()
    wipe(ns.db)
    ns.SetProfile(ns.activeProfile)
end

------------------------------------------------------------------------
-- Temas: cambian colores y bordes del perfil activo
------------------------------------------------------------------------

ns.THEMES = {
    {
        name = L["Ruscuu Neon"],
        values = {
            borderSize = 2, iconZoom = 0.08,
            borderColor = { 0.61, 0.30, 1.00, 1 }, barColor = { 0.55, 0.25, 0.95, 1 },
            bgColor = { 0.07, 0.03, 0.12, 0.85 }, numberColor = { 0.95, 0.91, 0.84, 1 },
        },
    },
    {
        name = L["Minimal"],
        values = {
            borderSize = 1, iconZoom = 0.10,
            borderColor = { 0, 0, 0, 1 }, barColor = { 0.80, 0.80, 0.80, 1 },
            bgColor = { 0, 0, 0, 0.60 }, numberColor = { 1, 1, 1, 1 },
        },
    },
    {
        name = L["Dark"],
        values = {
            borderSize = 1, iconZoom = 0.08,
            borderColor = { 0.25, 0.22, 0.30, 1 }, barColor = { 0.35, 0.30, 0.45, 1 },
            bgColor = { 0.05, 0.05, 0.07, 0.90 }, numberColor = { 0.85, 0.85, 0.85, 1 },
        },
    },
    {
        name = L["Classic"],
        values = {
            borderSize = 1, iconZoom = 0.06,
            borderColor = { 0.85, 0.70, 0.30, 1 }, barColor = { 1, 0.70, 0, 1 },
            bgColor = { 0, 0, 0, 0.50 }, numberColor = { 1, 0.82, 0, 1 },
        },
    },
}

function ns.ApplyTheme(theme)
    for k, v in pairs(theme.values) do
        ns.db[k] = type(v) == "table" and ns.CopyTable(v) or v
    end
    ns.RefreshAll()
    ns.Print(L["Theme applied: %s"]:format(theme.name))
end

------------------------------------------------------------------------
-- Importar / exportar: "!RUSCUU:1!" + base64 de "clave=valor;clave=valor"
-- La importación nunca ejecuta código: solo acepta claves conocidas con el tipo esperado.
------------------------------------------------------------------------

local PREFIX = "!RUSCUU:1!"
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

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
        if IsColor(def) then
            out[#out + 1] = ("%s=%.3f,%.3f,%.3f,%.3f"):format(key, v[1], v[2], v[3], v[4] or 1)
        elseif type(def) == "table" then
            Flatten(def, v, key .. ".", out)
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

-- Escribe un valor importado si la clave existe en los valores por defecto y el tipo coincide
local function ImportValue(target, key, raw)
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
        -- Solo rutas de archivo sencillas (fuentes del juego o de otros addons)
        if not raw:match("^[%w_%.%-\\/]+$") then return false end
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
    return true
end
