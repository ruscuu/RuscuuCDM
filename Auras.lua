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
local PLATE_LISTS = { "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame" }
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
        if mouse and frame.IsMouseEnabled and not (frame.IsProtected and frame:IsProtected()) then
            local okMouse, enabled = pcall(frame.IsMouseEnabled, frame)
            if okMouse and Plain(enabled) then
                s.mouse = enabled and true or false
                pcall(frame.EnableMouse, frame, false)
            end
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

-- Desplazamiento desde el lugar donde Blizzard lo puso. Si Blizzard lo vuelve a colocar, ese es el nuevo origen.
local function SetOffset(frame, dx, dy)
    local s = saved[frame]
    local ok, point, rel, relPoint, x, y = pcall(frame.GetPoint, frame, 1)
    if not ok or not point or not (Plain(x) and Plain(y)) then return end
    x, y = x or 0, y or 0
    if dx == 0 and dy == 0 and not (s and s.base) then return end
    s = State(frame)
    local b = s.base
    if not b or x ~= s.setX or y ~= s.setY or rel ~= b[2] or point ~= b[1] then
        b = { point, rel, relPoint, x, y }
        s.base = b
    end
    local nx, ny = b[4] + dx, b[5] + dy
    if nx ~= x or ny ~= y then pcall(frame.SetPoint, frame, b[1], b[2], b[3], nx, ny) end
    s.setX, s.setY = nx, ny
    if dx == 0 and dy == 0 then s.base = nil end
end

------------------------------------------------------------------------
-- Placas de nombre: lo que tú aplicas a los enemigos
------------------------------------------------------------------------

local plateHooked = setmetatable({}, { __mode = "k" })
local platesFound = 0  -- para /rcm debug: placas en las que se encontraron los efectos

-- Marcos de efectos de una placa: las listas de las versiones nuevas o el contenedor de siempre
local function PlateAuraFrames(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return {} end
    local container = uf.AurasFrame or uf.BuffFrame or uf.aurasFrame
    if not container then return {} end
    local lists = {}
    for _, key in ipairs(PLATE_LISTS) do
        if type(container[key]) == "table" then lists[#lists + 1] = container[key] end
    end
    if #lists == 0 then lists[1] = container end
    return lists
end

local function StylePlateFrame(frame)
    local db = ns.db
    if not db then return end
    SetVisible(frame, db.aurasPlateShow)
    SetRelativeScale(frame, db.aurasPlateScale)
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

local function StylePlate(plate)
    local frames = PlateAuraFrames(plate)
    for _, frame in ipairs(frames) do
        HookPlateFrame(frame)
        StylePlateFrame(frame)
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

local function StyleUnitFrame(unit)
    local db = ns.db
    local name = UNIT_FRAMES[unit]
    local frame = name and _G[name]
    if not (db and frame) then return 0 end
    local apply = unit == "target" or db.aurasFocus
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

local function StylePlayer()
    local db = ns.db
    if not db then return end
    local buffs, debuffs = _G.BuffFrame, _G.DebuffFrame
    if debuffs then
        -- Versiones nuevas: un marco para cada cosa
        if buffs then SetVisible(buffs, db.aurasPlayerBuffs) end
        SetVisible(debuffs, db.aurasPlayerDebuffs)
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
        end
    end
    for name, on in pairs(list) do
        local frame = on and ns.FindFrameByName(name)
        if frame then
            hiddenByName[name] = frame
            SetVisible(frame, false)
            if not shownHooked[frame] and frame.HookScript then
                shownHooked[frame] = true
                -- Algunos marcos vuelven a ponerse visibles al mostrarse: se ocultan otra vez
                pcall(frame.HookScript, frame, "OnShow", function(self)
                    if hiddenByName[name] == self then SetVisible(self, false) end
                end)
            end
        end
    end
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

-- Para /rcm debug: qué se encontró de cada cosa
function ns.GetAuraStatus()
    return {
        plates = platesFound,
        target = _G.TargetFrame ~= nil,
        targetButtons = (_G.TargetFrame and #UnitAuraButtons(_G.TargetFrame, "TargetFrame")) or 0,
        playerBuffs = _G.BuffFrame ~= nil,
        playerDebuffs = _G.DebuffFrame ~= nil or playerHooked,
        hidden = #ns.GetHiddenFrameNames(),
    }
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if not ns.db then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        pcall(StylePlateUnit, unit)
    elseif event == "UNIT_AURA" then
        if type(unit) ~= "string" or not Plain(unit) then return end
        if unit:match("^nameplate") then
            pcall(StylePlateUnit, unit)
        elseif UNIT_FRAMES[unit] then
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
end)
