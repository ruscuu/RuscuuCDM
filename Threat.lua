-- Ruscuu Cooldown Manager Forever: medidor de amenaza encima de las placas de nombre de los enemigos.
-- Sobre cada placa de un enemigo con el que estás en combate: una barra fina que se llena con tu amenaza (el 100%
-- es cuando le quitarías el objetivo a quien lo tiene), su porcentaje, o ambos. El color cambia según el peligro:
-- poca amenaza, a punto de quitársela al tanque, lo tienes pero por poco, y te está atacando a ti (colores a
-- elegir). Si el juego oculta los datos (valores secretos), se dibuja igual con lo que el juego deja pasar, y el
-- color queda en el elegido para ese caso. Tamaño, posición y texto se configuran en su página de opciones.
local _, ns = ...
local L = ns.L

local UPDATE_INTERVAL = 0.2
local STATUS_KEYS = { [0] = "threatColorLow", [1] = "threatColorHigh", [2] = "threatColorInsecure",
    [3] = "threatColorTanking" }
local PREVIEW_STATUS, PREVIEW_PERCENT = 1, 85

local meters = {}  -- unidad de la placa -> medidor
local spare = {}   -- medidores sin usar, para no crear uno nuevo por cada placa
local previewUntil = 0

local function Plain(value)
    return not ns.IsSecret(value)
end

local function NewMeter()
    local meter = table.remove(spare)
    if meter then return meter end
    meter = CreateFrame("Frame", nil, UIParent)
    meter.bar = CreateFrame("StatusBar", nil, meter)
    meter.bar:SetAllPoints()
    meter.bar:SetMinMaxValues(0, 100)
    meter.bar.bg = meter.bar:CreateTexture(nil, "BACKGROUND")
    meter.bar.bg:SetAllPoints()
    meter.text = meter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    return meter
end

-- Tamaño, textura, fuente y lugar del texto según las opciones
local function StyleMeter(meter)
    local db = ns.db
    local show = db.threatShow
    meter:SetSize(db.threatWidth, db.threatHeight)
    meter.bar:SetStatusBarTexture(ns.ResolveBarTexture(db.barTexture) or ns.WHITE)
    local bg = db.threatBgColor
    meter.bar.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    meter.bar:SetShown(show ~= "percent")
    local tc = db.threatTextColor
    ns.SetFontSafe(meter.text, db.font, db.threatFontSize, "OUTLINE")
    meter.text:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    meter.text:ClearAllPoints()
    local pos = show == "percent" and "center" or db.threatTextPosition
    if pos == "left" then
        meter.text:SetPoint("RIGHT", meter, "LEFT", -3, 0)
    elseif pos == "center" then
        meter.text:SetPoint("CENTER", meter, "CENTER", 0, 0)
    else
        meter.text:SetPoint("LEFT", meter, "RIGHT", 3, 0)
    end
    meter.text:SetShown(show ~= "bar")
end

local function ReleaseMeter(unit)
    local meter = meters[unit]
    if not meter then return end
    meter:Hide()
    meter:ClearAllPoints()
    meter:SetParent(UIParent)
    meters[unit] = nil
    spare[#spare + 1] = meter
end

-- Amenaza del jugador sobre la unidad: nil si no está en su lista de amenaza
local function Threat(unit)
    if GetTime() < previewUntil then return PREVIEW_STATUS, PREVIEW_PERCENT end
    if not UnitDetailedThreatSituation then return end
    local ok, _, status, scaledPercent = pcall(UnitDetailedThreatSituation, "player", unit)
    if not ok then return end
    if Plain(status) and status == nil then return end
    return status, scaledPercent
end

local function UpdateMeter(unit)
    local meter = meters[unit]
    if not meter then return end
    local db = ns.db
    local status, percent = Threat(unit)
    if not ns.IsSecret(status) and status == nil then
        meter:Hide()
        return
    end
    local color = db[Plain(status) and STATUS_KEYS[status] or "threatColorSecret"] or db.threatColorSecret
    meter.bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
    if db.threatTextUseColor then meter.text:SetTextColor(color[1], color[2], color[3], 1) end
    -- Las barras y los textos aceptan los valores secretos tal cual: el addon nunca los lee
    local hasPercent = ns.IsSecret(percent) or percent ~= nil
    if not (hasPercent and pcall(meter.bar.SetValue, meter.bar, percent)) then meter.bar:SetValue(0) end
    if not (hasPercent and pcall(meter.text.SetFormattedText, meter.text, "%d%%", percent)) then
        meter.text:SetText("")
    end
    meter:Show()
end

local function CanAttack(unit)
    local ok, attack = pcall(UnitCanAttack, "player", unit)
    return ok and Plain(attack) and attack == true
end

local function AddPlate(unit)
    ReleaseMeter(unit)
    if not (ns.db and ns.db.threatBar) or not CanAttack(unit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return end
    local anchor = plate.UnitFrame or plate
    local meter = NewMeter()
    meter:SetParent(plate)
    meter:SetFrameLevel((anchor:GetFrameLevel() or 0) + 5)
    StyleMeter(meter)
    -- Encima del nombre, si la placa lo tiene; si no, encima de la placa. Desplazado lo que diga el jugador.
    local name = anchor.name or anchor.Name
    meter:SetPoint("BOTTOM", name or anchor, "TOP", ns.db.threatX, ns.db.threatY)
    meters[unit] = meter
    UpdateMeter(unit)
end

local function VisiblePlates()
    local units = {}
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return units end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and Plain(unit) then units[#units + 1] = unit end
    end
    return units
end

function ns.RefreshThreat()
    for unit in pairs(meters) do ReleaseMeter(unit) end
    if not (ns.db and ns.db.threatBar) then return end
    for _, unit in ipairs(VisiblePlates()) do AddPlate(unit) end
end

-- Vista previa: los enemigos con placa visible muestran un medidor de ejemplo durante unos segundos
function ns.PreviewThreat(seconds)
    if not ns.db.threatBar then
        ns.Print(L["Turn on the threat meter first."], true)
        return
    end
    previewUntil = GetTime() + (seconds or 10)
    ns.RefreshThreat()
    if next(meters) == nil then ns.Print(L["No enemy nameplates in sight: target an enemy or a training dummy."], true) end
end

-- Para las pruebas y /rcm debug
function ns.GetThreatMeter(unit) return meters[unit] end
function ns.CountThreatMeters()
    local n = 0
    for _ in pairs(meters) do n = n + 1 end
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
        ReleaseMeter(unit)
    elseif unit and meters[unit] then
        UpdateMeter(unit)
    else
        for u in pairs(meters) do UpdateMeter(u) end
    end
end)

-- La amenaza cambia con cada golpe: se revisa varias veces por segundo mientras haya medidores
local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < UPDATE_INTERVAL then return end
    since = 0
    for unit in pairs(meters) do pcall(UpdateMeter, unit) end
end)
