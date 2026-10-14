-- Ruscuu Cooldown Manager Forever: medidor de amenaza encima de las placas de nombre de los enemigos.
-- Una barra fina sobre cada placa de un enemigo con el que estás en combate: se llena con tu amenaza (el 100%
-- es cuando le quitarías el objetivo a quien lo tiene) y cambia de color según el peligro:
-- verde (poca), amarillo (más que el tanque, a punto de quitársela), naranja (lo tienes, pero por poco) y rojo
-- (te está atacando a ti). Si el juego oculta los datos (valores secretos), la barra se dibuja igual con lo que
-- el juego deja pasar, y el color queda en el morado de Ruscuu.
local _, ns = ...

local UPDATE_INTERVAL = 0.2
local BAR_WIDTH, BAR_HEIGHT, GAP = 110, 6, 2
local STATUS_COLORS = {
    [0] = { 0.3, 0.8, 0.3 },
    [1] = { 1, 0.85, 0.1 },
    [2] = { 1, 0.5, 0.1 },
    [3] = { 0.95, 0.15, 0.15 },
}
local SECRET_COLOR = { 0.61, 0.3, 1 }

local bars = {}   -- unidad de la placa -> barra
local spare = {}  -- barras sin usar, para no crear una nueva por cada placa

local function Plain(value)
    return not ns.IsSecret(value)
end

local function NewBar()
    local bar = table.remove(spare)
    if bar then return bar end
    bar = CreateFrame("StatusBar", nil, UIParent, "BackdropTemplate")
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar:SetMinMaxValues(0, 100)
    bar:SetStatusBarTexture(ns.WHITE)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.6)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("LEFT", bar, "RIGHT", 3, 0)
    return bar
end

local function ReleaseBar(unit)
    local bar = bars[unit]
    if not bar then return end
    bar:Hide()
    bar:ClearAllPoints()
    bar:SetParent(UIParent)
    bars[unit] = nil
    spare[#spare + 1] = bar
end

-- Amenaza del jugador sobre la unidad: nil si no está en su lista de amenaza
local function Threat(unit)
    if not UnitDetailedThreatSituation then return end
    local ok, _, status, scaledPercent = pcall(UnitDetailedThreatSituation, "player", unit)
    if not ok then return end
    if Plain(status) and status == nil then return end
    return status, scaledPercent
end

local function UpdateBar(unit)
    local bar = bars[unit]
    if not bar then return end
    local db = ns.db
    local status, percent = Threat(unit)
    if not ns.IsSecret(status) and status == nil then
        bar:Hide()
        return
    end
    local color = Plain(status) and STATUS_COLORS[status] or SECRET_COLOR
    bar:SetStatusBarColor(color[1], color[2], color[3], 1)
    -- Las barras y los textos aceptan los valores secretos tal cual: el addon nunca los lee
    local hasPercent = ns.IsSecret(percent) or percent ~= nil
    if not (hasPercent and pcall(bar.SetValue, bar, percent)) then bar:SetValue(0) end
    if db.threatPercent and hasPercent then
        if not pcall(bar.text.SetFormattedText, bar.text, "%d%%", percent) then bar.text:SetText("") end
        bar.text:Show()
    else
        bar.text:Hide()
    end
    bar:Show()
end

local function CanAttack(unit)
    local ok, attack = pcall(UnitCanAttack, "player", unit)
    return ok and Plain(attack) and attack == true
end

local function AddPlate(unit)
    ReleaseBar(unit)
    if not (ns.db and ns.db.threatBar) or not CanAttack(unit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return end
    local anchor = plate.UnitFrame or plate
    local bar = NewBar()
    bar:SetParent(plate)
    bar:SetFrameLevel((anchor:GetFrameLevel() or 0) + 5)
    -- Encima del nombre, si la placa lo tiene; si no, encima de la placa
    local name = anchor.name or anchor.Name
    bar:SetPoint("BOTTOM", name or anchor, "TOP", 0, GAP)
    bars[unit] = bar
    UpdateBar(unit)
end

function ns.RefreshThreat()
    for unit in pairs(bars) do ReleaseBar(unit) end
    if not (ns.db and ns.db.threatBar and C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and Plain(unit) then AddPlate(unit) end
    end
end

-- Para las pruebas y /rcm debug
function ns.GetThreatBar(unit) return bars[unit] end
function ns.CountThreatBars()
    local n = 0
    for _ in pairs(bars) do n = n + 1 end
    return n
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_THREAT_LIST_UPDATE",
    "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if not ns.db then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        AddPlate(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ReleaseBar(unit)
    elseif unit and bars[unit] then
        UpdateBar(unit)
    else
        for u in pairs(bars) do UpdateBar(u) end
    end
end)

-- La amenaza cambia con cada golpe: se revisa varias veces por segundo mientras haya barras
local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < UPDATE_INTERVAL then return end
    since = 0
    for unit in pairs(bars) do pcall(UpdateBar, unit) end
end)
