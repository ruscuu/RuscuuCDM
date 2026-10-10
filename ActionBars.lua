-- Ruscuu Cooldown Manager Forever: estilo para los números de cooldown de las barras de acción.
-- Solo cambia fuente, tamaño y color del texto que dibuja el juego; nunca lee el tiempo restante.
local _, ns = ...

local BUTTON_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton",
}

local cooldowns = {}

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
    local fs = CountdownText(cd)
    if not fs then return end
    fs:SetFont(db.font, db.actionBarFontSize, "OUTLINE")
    fs:SetTextColor(unpack(db.numberColor))
end

function ns.StyleActionBars()
    for cd in pairs(cooldowns) do
        StyleCooldown(cd)
    end
end

function ns.HookActionBars()
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            local cd = button and (button.cooldown or button.Cooldown)
            if cd and not cooldowns[cd] then
                cooldowns[cd] = true
                -- El texto de la cuenta atrás puede crearse al empezar el primer cooldown
                cd:HookScript("OnShow", StyleCooldown)
            end
        end
    end
    ns.StyleActionBars()
end
