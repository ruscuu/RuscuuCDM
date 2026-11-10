-- Ruscuu Cooldown Manager Forever: control de los iconos de efectos (beneficios y perjuicios) que dibuja el juego.
-- El juego pone iconos de efectos en varios sitios: encima de las placas de nombre de los enemigos (lo que tú les
-- aplicas), junto al marco del objetivo y del foco, y arriba a la derecha (lo que te aplican a ti, como una
-- maldición). Aquí se puede ocultar cada grupo, cambiar su tamaño y, en las placas, moverlos. Además se puede
-- ocultar cualquier otro marco de la interfaz por su nombre (el que da /fstack).
--
-- Nunca se leen los efectos (en combate el juego los oculta): solo se cambia la opacidad, la escala y el lugar de
-- los marcos de Blizzard, cosas que se pueden hacer también en combate. Todo lo que se cambia se guarda antes y se
-- devuelve tal cual al volver a los valores por defecto, sin recargar.
local _, ns = ...

local MAX_AURA_BUTTONS = 40
-- Partes del contenedor de efectos de las placas en las versiones nuevas del juego (si no, se usa el contenedor)
-- LossOfControlFrame: el icono de aturdimiento, polimorfia... junto a la barra de vida
local PLATE_LISTS = { "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame", "LossOfControlFrame" }
-- Blizzard le pone su propia escala en cada actualización (RefreshLossOfControl): solo se oculta y se mueve
local PLATE_NO_SCALE = { LossOfControlFrame = true }
-- Funciones de Blizzard que vuelven a colocar los efectos de una placa: después de ellas se aplica lo elegido
local PLATE_HOOKS = { "UpdateAnchor", "UpdateBuffs", "Layout", "RefreshList", "RefreshAuras" }
local UNIT_FRAMES = { target = "TargetFrame", focus = "FocusFrame" }

local function Plain(value)
    return not ns.IsSecret(value)
end

------------------------------------------------------------------------
-- Cambios guardados para poder devolverlos
------------------------------------------------------------------------

local saved = setmetatable({}, { __mode = "k" })  -- marco -> { alpha, mouse, scale, base, setX, setY }

local function State(frame)
    local s = saved[frame]
    if not s then
        s = {}
        saved[frame] = s
    end
    return s
end

-- Visible o invisible (opacidad 0 y sin ayuda al pasar el ratón); se puede en combate
local function SetVisible(frame, visible, mouse)
    local s = saved[frame]
    if visible then
        if s and s.alpha ~= nil then
            pcall(frame.SetAlpha, frame, s.alpha)
            s.alpha = nil
            if s.mouse ~= nil then pcall(frame.EnableMouse, frame, s.mouse) end
            s.mouse = nil
        end
        return
    end
    s = State(frame)
    if s.alpha == nil then
        local ok, alpha = pcall(frame.GetAlpha, frame)
        s.alpha = (ok and Plain(alpha) and alpha and alpha > 0) and alpha or 1
    end
    -- Aparte de la opacidad: otra opción pudo ocultarlo antes sin quitarle el ratón
    if mouse and s.mouse == nil and frame.IsMouseEnabled and not (frame.IsProtected and frame:IsProtected()) then
        local okMouse, enabled = pcall(frame.IsMouseEnabled, frame)
        if okMouse and Plain(enabled) then
            s.mouse = enabled and true or false
            pcall(frame.EnableMouse, frame, false)
        end
    end
    pcall(frame.SetAlpha, frame, 0)
end

-- Escala relativa a la de Blizzard (1 = sin cambios)
local function SetRelativeScale(frame, scale)
    local s = saved[frame]
    if scale == 1 then
        if s and s.scale then
            pcall(frame.SetScale, frame, s.scale)
            s.scale = nil
        end
        return
    end
    s = State(frame)
    if not s.scale then
        local ok, current = pcall(frame.GetScale, frame)
        s.scale = (ok and Plain(current) and current and current > 0) and current or 1
    end
    pcall(frame.SetScale, frame, s.scale * scale)
end

-- Todos los anclajes del marco: { {punto, relativo, puntoRel, x, y}, ... }, o nil si alguno es secreto
local function ReadPoints(frame)
    local okN, n = pcall(frame.GetNumPoints, frame)
    if not okN or not Plain(n) or type(n) ~= "number" or n < 1 then return end
    local points = {}
    for i = 1, n do
        local ok, point, rel, relPoint, x, y = pcall(frame.GetPoint, frame, i)
        -- Primero si es secreto: ni siquiera "not point" se puede hacer con un valor secreto
        if not ok or not (Plain(point) and Plain(rel) and Plain(relPoint) and Plain(x) and Plain(y)) or not point then
            return
        end
        points[i] = { point, rel, relPoint, x or 0, y or 0 }
    end
    return points
end

local function FindPoint(points, name)
    for _, p in ipairs(points or {}) do
        if p[1] == name then return p end
    end
end

local function SamePoint(a, b)
    return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] and a[5] == b[5]
end

-- Desplazamiento desde el lugar donde Blizzard lo puso. Se mueven todos los anclajes: con dos (la lista de
-- perjuicios va a la IZQUIERDA y ABAJO), mover solo uno la estira en vez de moverla. Si Blizzard vuelve a
-- colocar alguno, ese es su nuevo origen; los demás conservan el suyo.
local function SetOffset(frame, dx, dy)
    local s = saved[frame]
    if dx == 0 and dy == 0 and not (s and s.base) then return end
    local current = ReadPoints(frame)
    if not current then return end
    s = State(frame)
    local base = {}
    for i, c in ipairs(current) do
        local old = FindPoint(s.base, c[1])
        base[i] = (old and SamePoint(c, FindPoint(s.applied, c[1]))) and old or c
    end
    local target, changed = {}, false
    for i, b in ipairs(base) do
        target[i] = { b[1], b[2], b[3], b[4] + dx, b[5] + dy }
        if not SamePoint(target[i], current[i]) then changed = true end
    end
    if changed then
        pcall(frame.ClearAllPoints, frame)
        for _, t in ipairs(target) do pcall(frame.SetPoint, frame, t[1], t[2], t[3], t[4], t[5]) end
    end
    if dx == 0 and dy == 0 then
        s.base, s.applied = nil, nil
    else
        s.base, s.applied = base, target
    end
end

------------------------------------------------------------------------
-- Placas de nombre: lo que tú aplicas a los enemigos
------------------------------------------------------------------------

local plateHooked = setmetatable({}, { __mode = "k" })
local plateNoScale = setmetatable({}, { __mode = "k" })
local platesFound = 0  -- para /rcm debug: placas en las que se encontraron los efectos

-- Marcos de efectos de una placa: las listas de las versiones nuevas o el contenedor de siempre
local function PlateAuraFrames(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return {} end
    local container = uf.AurasFrame or uf.BuffFrame or uf.aurasFrame
    if not container then return {} end
    local lists = {}
    for _, key in ipairs(PLATE_LISTS) do
        if type(container[key]) == "table" then
            lists[#lists + 1] = container[key]
            if PLATE_NO_SCALE[key] then plateNoScale[container[key]] = true end
        end
    end
    if #lists == 0 then lists[1] = container end
    return lists
end

local function StylePlateFrame(frame)
    local db = ns.db
    if not db then return end
    -- Con todo por defecto y nada que devolver no hay trabajo (se llama muchas veces por segundo en combate)
    local s = saved[frame]
    if db.aurasPlateShow and db.aurasPlateScale == 1 and db.aurasPlateX == 0 and db.aurasPlateY == 0
        and not (s and (s.alpha ~= nil or s.scale or s.base)) then
        return
    end
    SetVisible(frame, db.aurasPlateShow)
    if not plateNoScale[frame] then SetRelativeScale(frame, db.aurasPlateScale) end
    SetOffset(frame, db.aurasPlateX, db.aurasPlateY)
end

local function HookPlateFrame(frame)
    if plateHooked[frame] then return end
    plateHooked[frame] = true
    for _, method in ipairs(PLATE_HOOKS) do
        if type(frame[method]) == "function" then
            hooksecurefunc(frame, method, function(self) pcall(StylePlateFrame, self) end)
        end
    end
end

-- El icono de pérdida de control no tiene Layout propio: Blizzard lo recoloca desde la placa
-- (UpdateAnchors) y desde su contenedor (RefreshLossOfControl), así que se vuelve a aplicar después
local function HookLossOfControl(plate)
    local uf = plate and plate.UnitFrame
    local container = uf and (uf.AurasFrame or uf.BuffFrame or uf.aurasFrame)
    local loc = container and container.LossOfControlFrame
    if type(loc) ~= "table" then return end
    local function restyle() pcall(StylePlateFrame, loc) end
    if type(uf.UpdateAnchors) == "function" then hooksecurefunc(uf, "UpdateAnchors", restyle) end
    if type(container.RefreshLossOfControl) == "function" then
        hooksecurefunc(container, "RefreshLossOfControl", restyle)
    end
end

-- Placas cuyo icono de pérdida de control ya está enganchado (una sola vez por placa)
local locHooked = setmetatable({}, { __mode = "k" })

local function StylePlate(plate)
    local frames = PlateAuraFrames(plate)
    for _, frame in ipairs(frames) do
        HookPlateFrame(frame)
        StylePlateFrame(frame)
    end
    local uf = plate and plate.UnitFrame
    if uf and not locHooked[uf] then
        locHooked[uf] = true
        HookLossOfControl(plate)
    end
    return #frames > 0
end

local function StylePlateUnit(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then StylePlate(plate) end
end

local function StyleAllPlates()
    platesFound = 0
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok then return end
    for _, plate in ipairs(plates or {}) do
        local okPlate, found = pcall(StylePlate, plate)
        if okPlate and found then platesFound = platesFound + 1 end
    end
end

------------------------------------------------------------------------
-- Marcos del objetivo y del foco
------------------------------------------------------------------------

-- Botones de efectos de un marco de unidad: (botón, esPerjuicio)
local function UnitAuraButtons(frame, name)
    local list = {}
    local pools = frame.auraPools
    if pools and type(pools.EnumerateActiveByTemplate) == "function" then
        for template, isDebuff in pairs({ TargetBuffFrameTemplate = false, TargetDebuffFrameTemplate = true }) do
            local ok, iter, state, start = pcall(pools.EnumerateActiveByTemplate, pools, template)
            if ok and iter then
                for button in iter, state, start do list[#list + 1] = { button, isDebuff } end
            end
        end
    end
    -- Marcos con nombre (estilo clásico): TargetFrameBuff1, TargetFrameDebuff1...
    if name then
        for i = 1, MAX_AURA_BUTTONS do
            local buff, debuff = _G[name .. "Buff" .. i], _G[name .. "Debuff" .. i]
            if buff then list[#list + 1] = { buff, false } end
            if debuff then list[#list + 1] = { debuff, true } end
            if not (buff or debuff) and i > 1 then break end
        end
    end
    return list
end

-- Versiones nuevas: los efectos van en un contenedor (GetAuraContainer) con sus botones en grupos privados.
-- No se pueden separar beneficios y perjuicios: se oculta el contenedor entero si ambos están desmarcados.
local function UnitAuraContainer(frame)
    if type(frame.GetAuraContainer) ~= "function" then return end
    local ok, container = pcall(frame.GetAuraContainer, frame)
    if ok and type(container) == "table" then return container end
end

local function StyleUnitFrame(unit)
    local db = ns.db
    local name = UNIT_FRAMES[unit]
    local frame = name and _G[name]
    if not (db and frame) then return 0 end
    local apply = unit == "target" or db.aurasFocus
    local container = UnitAuraContainer(frame)
    if container then
        -- Nunca se escriben campos en el marco de Blizzard (contaminaría ConfigureAuraContainer)
        SetVisible(container, not apply or db.aurasTargetBuffs or db.aurasTargetDebuffs, false)
        SetRelativeScale(container, apply and db.aurasTargetScale or 1)
        -- Para /rcm debug: 1 si el contenedor se deja tocar, 0 si está protegido
        return pcall(container.GetAlpha, container) and 1 or 0
    end
    local buttons = UnitAuraButtons(frame, name)
    for _, entry in ipairs(buttons) do
        local button, isDebuff = entry[1], entry[2]
        local show = not apply or (isDebuff and db.aurasTargetDebuffs) or (not isDebuff and db.aurasTargetBuffs)
        SetVisible(button, show, true)
        SetRelativeScale(button, apply and db.aurasTargetScale or 1)
    end
    return #buttons
end

local function StyleUnitFrames()
    StyleUnitFrame("target")
    StyleUnitFrame("focus")
end

local unitHooked = {}
local function HookUnitFrames()
    for unit, name in pairs(UNIT_FRAMES) do
        local frame = _G[name]
        if frame and not unitHooked[name] and type(frame.UpdateAuras) == "function" then
            unitHooked[name] = true
            hooksecurefunc(frame, "UpdateAuras", function() pcall(StyleUnitFrame, unit) end)
        end
    end
    if not unitHooked.classic and type(_G.TargetFrame_UpdateAuras) == "function" then
        unitHooked.classic = true
        hooksecurefunc("TargetFrame_UpdateAuras", function(frame)
            for unit, name in pairs(UNIT_FRAMES) do
                if frame == _G[name] then pcall(StyleUnitFrame, unit) end
            end
        end)
    end
end

------------------------------------------------------------------------
-- Lo que te aplican a ti (beneficios y perjuicios junto al minimapa)
------------------------------------------------------------------------

local function StylePlayerButton(buttonName, index)
    local db = ns.db
    local button = buttonName and _G[buttonName .. index]
    if not (db and button) then return end
    if buttonName == "DebuffButton" then
        SetVisible(button, db.aurasPlayerDebuffs, true)
    elseif buttonName == "BuffButton" then
        SetVisible(button, db.aurasPlayerBuffs, true)
    end
end

-- Marcos ocultos por su nombre (marco -> true): mandan sobre las demás opciones
local hiddenFrames = setmetatable({}, { __mode = "k" })

-- Botones de efectos de BuffFrame/DebuffFrame: con opacidad 0 siguen recibiendo el ratón, y un clic
-- derecho invisible quitaría un beneficio (CancelUnitBuff). Se les quita el ratón mientras están ocultos.
local function AuraChildren(frame)
    local list, seen = {}, {}
    local function Add(child)
        if type(child) == "table" and not seen[child] then
            seen[child] = true
            list[#list + 1] = child
        end
    end
    if type(frame.auraFrames) == "table" then
        for _, child in ipairs(frame.auraFrames) do Add(child) end
    end
    local container = frame.AuraContainer
    if type(container) == "table" and container.GetChildren then
        local ok, children = pcall(function() return { container:GetChildren() } end)
        if ok then
            for _, child in ipairs(children) do Add(child) end
        end
    end
    return list
end

local function SetAuraMouse(frame, enabled)
    for _, child in ipairs(AuraChildren(frame)) do
        local okP, protected = false, nil
        if child.IsProtected then okP, protected = pcall(child.IsProtected, child) end
        local isProtected = okP and (not Plain(protected) or protected)
        if not isProtected and child.EnableMouse then
            local s = saved[child]
            if enabled then
                if s and s.childMouse ~= nil then
                    pcall(child.EnableMouse, child, s.childMouse)
                    s.childMouse = nil
                end
            else
                s = State(child)
                if s.childMouse == nil and child.IsMouseEnabled then
                    local ok, on = pcall(child.IsMouseEnabled, child)
                    if ok and Plain(on) then s.childMouse = on and true or false end
                end
                if s.childMouse ~= nil then pcall(child.EnableMouse, child, false) end
            end
        end
    end
end

local function StylePlayer()
    local db = ns.db
    if not db then return end
    local buffs, debuffs = _G.BuffFrame, _G.DebuffFrame
    if debuffs then
        -- Versiones nuevas: un marco para cada cosa
        if buffs then
            local show = db.aurasPlayerBuffs and not hiddenFrames[buffs]
            SetVisible(buffs, show)
            SetAuraMouse(buffs, show)
        end
        local show = db.aurasPlayerDebuffs and not hiddenFrames[debuffs]
        SetVisible(debuffs, show)
        SetAuraMouse(debuffs, show)
    else
        -- Estilo clásico: los perjuicios van dentro del marco de beneficios, botón a botón
        for i = 1, MAX_AURA_BUTTONS do
            StylePlayerButton("BuffButton", i)
            StylePlayerButton("DebuffButton", i)
        end
    end
end

local playerHooked = false
local function HookPlayer()
    if playerHooked or _G.DebuffFrame or type(_G.AuraButton_Update) ~= "function" then return end
    playerHooked = true
    hooksecurefunc("AuraButton_Update", function(buttonName, index) pcall(StylePlayerButton, buttonName, index) end)
end

------------------------------------------------------------------------
-- Otros marcos, por su nombre
------------------------------------------------------------------------

local hiddenByName = {}   -- nombre -> marco que se ocultó
local shownHooked = setmetatable({}, { __mode = "k" })

-- Un nombre válido de un marco que existe ahora: devuelve el marco
function ns.FindFrameByName(name)
    if type(name) ~= "string" or not name:match("^[%a_][%w_]*$") then return nil end
    local frame = _G[name]
    if type(frame) ~= "table" or type(frame.SetAlpha) ~= "function" or frame == UIParent then return nil end
    return frame
end

local function StyleNamedFrames()
    local db = ns.db
    if not db then return end
    local list = db.aurasHideFrames or {}
    for name, frame in pairs(hiddenByName) do
        if not list[name] then
            SetVisible(frame, true)
            hiddenByName[name] = nil
            hiddenFrames[frame] = nil
        end
    end
    for name, on in pairs(list) do
        local frame = on and ns.FindFrameByName(name)
        if frame then
            hiddenByName[name] = frame
            hiddenFrames[frame] = true
            -- También sin ratón: invisible pero bloqueando clics y mostrando ayudas (los protegidos no se tocan)
            SetVisible(frame, false, true)
            if not shownHooked[frame] and frame.HookScript then
                shownHooked[frame] = true
                -- Algunos marcos vuelven a ponerse visibles al mostrarse: se ocultan otra vez
                pcall(frame.HookScript, frame, "OnShow", function(self)
                    if hiddenByName[name] == self then SetVisible(self, false, true) end
                end)
            end
        end
    end
    -- BuffFrame/DebuffFrame: al dejar de ocultarlos por su nombre vuelven a mandar sus opciones
    -- (y sus botones pierden o recuperan el ratón)
    pcall(StylePlayer)
end

-- Oculta o vuelve a mostrar un marco por su nombre; devuelve true si ahora está oculto, o nil si no existe
function ns.ToggleHiddenFrame(name)
    name = strtrim(name or "")
    local db = ns.db
    db.aurasHideFrames = db.aurasHideFrames or {}
    if db.aurasHideFrames[name] then
        db.aurasHideFrames[name] = nil
        StyleNamedFrames()
        return false
    end
    if not ns.FindFrameByName(name) then return nil end
    db.aurasHideFrames[name] = true
    StyleNamedFrames()
    return true
end

function ns.ShowAllHiddenFrames()
    ns.db.aurasHideFrames = {}
    StyleNamedFrames()
end

function ns.GetHiddenFrameNames()
    local names = {}
    for name, on in pairs(ns.db and ns.db.aurasHideFrames or {}) do
        if on then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

------------------------------------------------------------------------
-- Todo junto
------------------------------------------------------------------------

function ns.RefreshAuras()
    if not ns.db then return end
    HookUnitFrames()
    HookPlayer()
    pcall(StyleAllPlates)
    pcall(StyleUnitFrames)
    pcall(StylePlayer)
    pcall(StyleNamedFrames)
end

-- Contenedor nuevo: 1 si se deja tocar, 0 si no; si no, los botones encontrados
local function TargetAuraCount(frame)
    local container = UnitAuraContainer(frame)
    if container then return pcall(container.GetAlpha, container) and 1 or 0 end
    return #UnitAuraButtons(frame, "TargetFrame")
end

-- Para /rcm debug: qué se encontró de cada cosa
function ns.GetAuraStatus()
    return {
        plates = platesFound,
        target = _G.TargetFrame ~= nil,
        targetButtons = (_G.TargetFrame and TargetAuraCount(_G.TargetFrame)) or 0,
        playerBuffs = _G.BuffFrame ~= nil,
        playerDebuffs = _G.DebuffFrame ~= nil or playerHooked,
        hidden = #ns.GetHiddenFrameNames(),
    }
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
    pcall(events.RegisterEvent, events, event)
end
-- UNIT_AURA solo de las unidades que importan: las placas ya se rehacen con los enganches de Blizzard
-- (RefreshList, Layout) y en combate sus UNIT_AURA llegan cientos de veces por segundo.
-- Cada marco admite dos unidades: el jugador va en otro.
local playerEvents = CreateFrame("Frame")
local function RegisterUnitAura(frame, ...)
    if not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", ...)) then
        pcall(frame.RegisterEvent, frame, "UNIT_AURA")
    end
end
RegisterUnitAura(events, "target", "focus")
RegisterUnitAura(playerEvents, "player")
local function OnEvent(_, event, unit)
    if not ns.db then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        pcall(StylePlateUnit, unit)
    elseif event == "UNIT_AURA" then
        if type(unit) ~= "string" or not Plain(unit) then return end
        if UNIT_FRAMES[unit] then
            pcall(StyleUnitFrame, unit)
        elseif unit == "player" then
            pcall(StylePlayer)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        pcall(StyleUnitFrame, "target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        pcall(StyleUnitFrame, "focus")
    else
        -- Al entrar al mundo o al cargar otro addon pueden aparecer marcos nuevos
        ns.RefreshAuras()
    end
end
events:SetScript("OnEvent", OnEvent)
playerEvents:SetScript("OnEvent", OnEvent)
