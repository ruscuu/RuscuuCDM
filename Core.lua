-- Ruscuu Cooldown Manager Forever: núcleo (datos guardados, eventos y comandos)
local addonName, ns = ...

ns.COLORS = {
    bg = { 0.07, 0.03, 0.12, 0.85 },   -- morado muy oscuro del fondo del logo
}

local defaults = {
    enabled = { essential = true, utility = true, buffIcons = true, buffBars = true },
    borderSize = 1,
    iconZoom = 0.08,
    fontSize = 14,
    font = "Fonts\\FRIZQT__.TTF",
    borderColor = { 0.61, 0.30, 1.00, 1 }, -- morado neón (ojos y corona del logo)
    barColor = { 0.55, 0.25, 0.95, 1 },
}

-- Rellena los valores que falten sin pisar los que el jugador ya cambió
local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.Print(msg)
    print("|cff9b4dffRuscuu CDM|r: " .. msg)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            RuscuuCDMDB = RuscuuCDMDB or {}
            ApplyDefaults(RuscuuCDMDB, defaults)
            ns.db = RuscuuCDMDB
            ns.RegisterOptions()
        elseif arg1 == "Blizzard_CooldownViewer" and ns.db then
            ns.HookViewers()
        end
    elseif event == "PLAYER_LOGIN" then
        ns.HookViewers()
    else
        -- Al cambiar de zona o especialización Blizzard rehace los iconos
        C_Timer.After(1, ns.SkinAll)
    end
end)

SLASH_RUSCUUCDM1 = "/ruscuu"
SLASH_RUSCUUCDM2 = "/rcdm"
SlashCmdList.RUSCUUCDM = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        RuscuuCDMDB = nil
        ReloadUI()
    elseif msg == "skin" then
        ns.SkinAll()
        ns.Print("Estilo reaplicado.")
    elseif msg == "debug" then
        ns.Debug()
    else
        ns.OpenOptions()
    end
end
