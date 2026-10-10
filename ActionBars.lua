-- Ruscuu Cooldown Manager Forever: estilo para los números de cooldown de las barras de acción.
-- Solo cambia fuente, tamaño y color del texto que dibuja el juego; nunca lee el tiempo restante.
local _, ns = ...
local L = ns.L

local BUTTON_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton",
}

-- Métodos con los que el juego arranca un cooldown; tras cada uno se reaplica el estilo
local START_METHODS = { "SetCooldown", "SetCooldownDuration", "SetCooldownFromDurationObject", "SetCooldownUNIX" }

local cooldowns = {}
local hookedCount = 0

-- Fuente propia: al cambiarla se actualizan a la vez todos los contadores que la usan
local countdownFont = CreateFont("RuscuuCDMCountdownFont")

local function UpdateFont()
    local db = ns.db
    countdownFont:SetFont(db.font, db.actionBarFontSize, "OUTLINE")
    countdownFont:SetTextColor(unpack(db.numberColor))
end

local function CountdownText(cd)
    if cd.GetCountdownFontString then
        local fs = cd:GetCountdownFontString()
        if fs then return fs end
    end
    for _, region in ipairs({ cd:GetRegions() }) do
        if region:IsObjectType("FontString") then return region end
    end
end

local function StyleCooldown(cd)
    local db = ns.db
    if not db or not db.styleActionBarNumbers then return end
    if cd.SetCountdownFont then
        cd:SetCountdownFont("RuscuuCDMCountdownFont")
    end
    -- Además se aplica directamente al texto por si esta versión del juego no usa la fuente del contador
    local fs = CountdownText(cd)
    if fs then
        fs:SetFont(db.font, db.actionBarFontSize, "OUTLINE")
        fs:SetTextColor(unpack(db.numberColor))
    end
end

-- Cooldown del hueco de acción del botón (ignorando el cooldown global)
local function ButtonDuration(button)
    local action = button.action
    if not action and button.CalculateAction then action = button:CalculateAction() end
    if not action or not HasAction(action) then return end
    return C_ActionBar.GetActionCooldownDuration(action, true)
end

function ns.HookActionBars()
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            local icon = button and (button.icon or button.Icon)
            -- Mascota y posturas no usan huecos de acción normales: no llevan borde dorado
            if icon and prefix ~= "PetActionButton" and prefix ~= "StanceButton"
                and C_ActionBar and C_ActionBar.GetActionCooldownDuration then
                ns.TrackExpire(button, icon, function() return ButtonDuration(button) end)
            end
            local cd = button and (button.cooldown or button.Cooldown)
            if cd and not cooldowns[cd] then
                cooldowns[cd] = true
                hookedCount = hookedCount + 1
                cd:HookScript("OnShow", StyleCooldown)
                for _, method in ipairs(START_METHODS) do
                    if type(cd[method]) == "function" then
                        hooksecurefunc(cd, method, StyleCooldown)
                    end
                end
            end
        end
    end
    ns.StyleActionBars()
end

function ns.StyleActionBars()
    if not ns.db then return end
    UpdateFont()
    for cd in pairs(cooldowns) do
        StyleCooldown(cd)
    end
end

function ns.DebugActionBars()
    ns.Print(L["Action bar cooldowns hooked: %d"]:format(hookedCount))
end
