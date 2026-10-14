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
    meter:SetWidth(db.threatWidth)
    meter:SetHeight(db.threatHeight)
    if meter.anchor then
        meter:ClearAllPoints()
        meter:SetPoint("BOTTOM", meter.anchor, "TOP", db.threatX, db.threatY)
    end
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
    meter.anchor = nil
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

-- En combate el juego oculta el nivel de amenaza (valor secreto): no se puede mirar, pero sí pasárselo a una
-- curva de color, que devuelve el color de ese nivel sin que el addon lo vea. Los niveles son 0, 1, 2 y 3: cada
-- uno tiene su color en un tramo plano de la curva.
local statusCurve
local function BuildStatusCurve()
    statusCurve = nil
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return end
    for level = 0, 3 do
        local c = ns.db[STATUS_KEYS[level]]
        local color = CreateColor(c[1], c[2], c[3], c[4] or 1)
        curve:AddPoint(math.max(0, level - 0.45), color)
        curve:AddPoint(level + 0.45, color)
    end
    statusCurve = curve
end

local function StatusColor(status)
    local db = ns.db
    if Plain(status) then
        local c = db[STATUS_KEYS[status] or "threatColorSecret"]
        return c[1], c[2], c[3], c[4] or 1
    end
    if not statusCurve then BuildStatusCurve() end
    if statusCurve then
        local ok, color = pcall(statusCurve.Evaluate, statusCurve, status)
        if ok and color then
            local okRGBA, r, g, b, a = pcall(color.GetRGBA, color)
            if okRGBA then return r, g, b, a end
        end
    end
    local c = db.threatColorSecret
    return c[1], c[2], c[3], c[4] or 1
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
    local r, g, b, a = StatusColor(status)
    if not pcall(meter.bar.SetStatusBarColor, meter.bar, r, g, b, a) then
        local c = db.threatColorSecret
        meter.bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    end
    if db.threatTextUseColor then pcall(meter.text.SetTextColor, meter.text, r, g, b, 1) end
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
    -- Encima del nombre, si la placa lo tiene; si no, encima de la placa
    meter.anchor = anchor.name or anchor.Name or anchor
    StyleMeter(meter)
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

-- Al cambiar una opción: los medidores que ya están en las placas se rehacen en el sitio (tamaño, posición,
-- colores) y se añaden los de las placas visibles que aún no tienen
function ns.RefreshThreat()
    statusCurve = nil -- los colores pueden haber cambiado
    if not (ns.db and ns.db.threatBar) then
        for unit in pairs(meters) do ReleaseMeter(unit) end
        return
    end
    for unit, meter in pairs(meters) do
        StyleMeter(meter)
        UpdateMeter(unit)
    end
    for _, unit in ipairs(VisiblePlates()) do
        if not meters[unit] then AddPlate(unit) end
    end
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
