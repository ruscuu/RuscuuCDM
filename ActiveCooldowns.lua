-- Ruscuu Cooldown Manager Forever: modo "solo cooldowns activos".
-- Oculta los iconos de cooldowns que están listos y coloca los que están en cooldown, de esenciales y de
-- utilidad, en una sola línea centrada donde está la barra de esenciales. Al terminar un cooldown, el icono se
-- queda un momento con un destello. Saber si un hechizo está en cooldown (isActive) o solo en el tiempo de
-- reutilización global (isOnGCD) está permitido incluso en combate: el juego nunca oculta esos dos datos.
-- Los iconos se ocultan con transparencia (Blizzard no recoloca la barra) y todo vuelve a su sitio al
-- desactivar la opción o mientras están abiertos el modo de edición o los ajustes de cooldowns de Blizzard.
local _, ns = ...

local LINGER = 1             -- segundos que se ve un icono con destello tras terminar su cooldown
local EVAL_INTERVAL = 0.1    -- cada cuánto se revisa qué cooldowns están activos
local VIEWER_NAMES = { "EssentialCooldownViewer", "UtilityCooldownViewer" }

-- Estado propio por icono, en tablas aparte para no escribir campos en frames de Blizzard
local state = setmetatable({}, { __mode = "k" })  -- icono -> { points, moved, hidden, mouse, wasActive, lingerUntil, flash }
local onGCD = setmetatable({}, { __mode = "k" })  -- icono -> su cooldown es solo el GCD (se anota al cambiar los cooldowns)
local applied = false        -- hay iconos movidos u ocultos que habrá que devolver
local apiState               -- el juego da isActive: true / false, o nil si aún no se ha consultado
local lastLine               -- iconos de la última línea colocada, para no recolocar si no cambia

local function State(item)
    local s = state[item]
    if not s then
        s = {}
        state[item] = s
    end
    return s
end

-- Iconos de las dos barras en el orden de Blizzard: primero esenciales, después utilidad
local function OrderedItems()
    local items = {}
    for _, name in ipairs(VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then
            local list = {}
            for _, item in ipairs(ns.GetViewerItems(viewer)) do
                local shown = item:IsShown()
                if item.layoutIndex and (shown == true or ns.IsSecret(shown)) then list[#list + 1] = item end
            end
            table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
            for _, item in ipairs(list) do items[#items + 1] = item end
        end
    end
    return items
end

-- ¿Está en cooldown? true / false, o nil si no se puede saber (entonces se muestra)
local function IsActive(item)
    local spellID = ns.ViewerItemSpell(item)
    if spellID then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if not ok or type(info) ~= "table" or ns.IsSecret(info.isActive) or type(info.isActive) ~= "boolean" then
            apiState = false
            return nil
        end
        apiState = true
        return info.isActive and not onGCD[item]
    end
    -- Objetos equipados (abalorios): su propio cooldown, si el juego deja leerlo
    local slot = item.GetEquipSlot and item:GetEquipSlot()
    if slot and GetInventoryItemCooldown then
        local start, duration, enable = GetInventoryItemCooldown("player", slot)
        if ns.IsSecret(start) or ns.IsSecret(duration) or ns.IsSecret(enable) or not start or not duration then
            return nil
        end
        return (enable == 1 or enable == true) and duration > 1.5 and start + duration > GetTime()
    end
    return nil
end

-- Mientras se configuran las barras se ve todo como lo deja Blizzard
local function Editing()
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
        return true
    end
    return CooldownViewerSettings ~= nil and CooldownViewerSettings:IsShown() == true
end

local function SavePoints(item)
    local s = State(item)
    s.points = {}
    for i = 1, item:GetNumPoints() do s.points[i] = { item:GetPoint(i) } end
    s.moved = false
end

local function RestorePoints(item)
    local s = state[item]
    if not (s and s.moved and s.points) then return end
    item:ClearAllPoints()
    for _, point in ipairs(s.points) do item:SetPoint(unpack(point)) end
    s.moved = false
end

local function SetHidden(item, hidden)
    local s = State(item)
    if hidden == (s.hidden == true) then return end
    s.hidden = hidden
    if hidden then
        -- Invisible y sin ayuda al pasar el ratón (podría quedar debajo de un icono visible)
        s.mouse = item:IsMouseMotionEnabled()
        item:SetAlpha(0)
        item:SetMouseMotionEnabled(false)
    else
        item:SetAlpha(1)
        if s.mouse ~= nil then item:SetMouseMotionEnabled(s.mouse) end
    end
end

local function Flash(item)
    local s = State(item)
    if not s.flash then
        local f = CreateFrame("Frame", nil, item)
        f:SetAllPoints(item.Icon or item)
        f:SetFrameLevel(item:GetFrameLevel() + 6)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture(ns.WHITE)
        tex:SetBlendMode("ADD")
        f:Hide()
        s.flash = f
    end
    return s.flash
end

-- Para /rcm debug: si el juego da el dato isActive (nil si todavía no se ha usado el modo)
function ns.ActiveCooldownAPI()
    return apiState
end

-- Para las pruebas y el diagnóstico: el destello de un icono (o nil)
function ns.GetActiveFlash(item)
    return state[item] and state[item].flash
end

local function RestoreAll()
    for item, s in pairs(state) do
        SetHidden(item, false)
        RestorePoints(item)
        s.lingerUntil = nil
        if s.flash then s.flash:Hide() end
    end
    applied, lastLine = false, nil
end

-- Una línea centrada en la barra de esenciales, con la separación elegida en el modo de edición.
-- Las cuentas se hacen en unidades de pantalla porque cada barra puede tener otro tamaño de icono.
local function Arrange(line)
    local anchor = _G.EssentialCooldownViewer or _G.UtilityCooldownViewer
    if not anchor then return end
    local gap = (anchor.childXPadding or 0) * anchor:GetEffectiveScale()
    local total = 0
    for i, item in ipairs(line) do
        total = total + item:GetWidth() * item:GetEffectiveScale() + (i > 1 and gap or 0)
    end
    local x = -total / 2
    for _, item in ipairs(line) do
        local s = State(item)
        if not s.moved then SavePoints(item) end
        local scale = item:GetEffectiveScale()
        local width = item:GetWidth() * scale
        item:ClearAllPoints()
        item:SetPoint("CENTER", anchor, "CENTER", (x + width / 2) / scale, 0)
        s.moved = true
        x = x + width + gap
    end
end

local function SameLine(a, b)
    if not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function Update()
    local db = ns.db
    if not db or not db.activeOnly or Editing() then
        if applied then RestoreAll() end
        return
    end
    local now = GetTime()
    local line = {}
    for _, item in ipairs(OrderedItems()) do
        local s = State(item)
        local active = IsActive(item)
        if active == nil then active = true end
        if s.wasActive and not active and db.activeFlash then
            s.lingerUntil = now + LINGER -- acaba de terminar: un momento visible con destello
            Flash(item)
        end
        s.wasActive = active
        if s.lingerUntil and now >= s.lingerUntil then s.lingerUntil = nil end
        local show = active or s.lingerUntil ~= nil
        SetHidden(item, not show)
        if show then line[#line + 1] = item end
    end
    applied = true
    if not SameLine(line, lastLine) then
        lastLine = line
        Arrange(line)
    end
end

-- Un error no debe repetirse en cada revisión: se avisa una vez en el chat y se sigue
local function SafeUpdate()
    local ok, err = pcall(Update)
    if not ok then ns.ReportError(err) end
end

local function UpdateFlashes(now)
    for _, s in pairs(state) do
        local f = s.flash
        if f then
            if s.lingerUntil and now < s.lingerUntil then
                f:SetAlpha(0.8 * (s.lingerUntil - now) / LINGER)
                f:Show()
            elseif f:IsShown() then
                f:Hide()
            end
        end
    end
end

local driver = CreateFrame("Frame")
local sinceUpdate = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate >= EVAL_INTERVAL then
        sinceUpdate = 0
        SafeUpdate()
    end
    UpdateFlashes(GetTime())
end)

-- isOnGCD solo es fiable al recibir el aviso de cambio de cooldowns: se anota en ese momento
local events = CreateFrame("Frame")
for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "ACTIONBAR_UPDATE_COOLDOWN" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function()
    if not (ns.db and ns.db.activeOnly) then return end
    for _, item in ipairs(OrderedItems()) do
        local ok, gcd = pcall(ns.SpellOnGCD, ns.ViewerItemSpell(item))
        onGCD[item] = ok and gcd == true
    end
    SafeUpdate()
end)

-- Cuando Blizzard vuelve a colocar los iconos se guardan sus posiciones y se rehace la línea al momento
function ns.HookActiveViewer(viewer)
    if type(viewer.Layout) ~= "function" then return end
    local known = false
    for _, name in ipairs(VIEWER_NAMES) do
        if _G[name] == viewer then known = true end
    end
    if not known then return end
    hooksecurefunc(viewer, "Layout", function()
        for _, item in ipairs(ns.GetViewerItems(viewer)) do
            SavePoints(item)
            -- Blizzard reutiliza los iconos: uno puede mostrar ahora otro hechizo, sin heredar su estado
            State(item).wasActive = nil
        end
        lastLine = nil
        SafeUpdate()
    end)
end
