-- Entorno común de las pruebas que cargan el addon completo: juego simulado, un icono en el Cooldown Manager,
-- la barra principal con un hechizo en la tecla 1, y todos los archivos del .toc cargados en su orden.
-- Uso: local M, ns, pages = require("addon_env")("esES")
local M = require("wowmock")

return function(clientLocale)
    M.install()
    GetLocale = function() return clientLocale end

    -- Lo que el addon consulta del juego al cargar y al iniciar sesión
    local cvars = { cooldownViewerEnabled = "1" }
    C_CVar = { GetCVar = function(k) return cvars[k] end, SetCVar = function(k, v) cvars[k] = v end }
    SetCVar = C_CVar.SetCVar
    UnitClass = function() return "Druida", "DRUID", 11 end
    UnitName = function() return "Alma" end
    GetRealmName = function() return "Reino" end
    C_SpecializationInfo = {
        GetSpecialization = function() return 2 end,
        GetSpecializationInfo = function(i) return i, "Spec" .. i, "", 134400 end,
        GetNumSpecializationsForClassID = function() return 4 end,
    }
    GetNumSpecializations = function() return 4 end
    C_ClassColor = { GetClassColor = function() return { r = 1, g = 0.49, b = 0.04 } end }
    IsLoggedIn = function() return true end
    GetBindingKey = function(command) if command == "ACTIONBUTTON1" then return "1" end end
    GetBindingText = function(key) return key end
    HasAction = function(action) if action > 180 then error("hueco no válido") end return action == 1 end
    GetActionInfo = function(action) if action == 1 then return "spell", 100 end end
    C_Spell = {
        GetBaseSpell = function(id) return id end,
        GetSpellName = function(id) return "S" .. id end,
        GetSpellTexture = function() return 134400 end,
        GetSpellCooldownDuration = function() return nil end,
    }
    C_ActionBar = { GetActionCooldownDuration = function() return nil end }
    Minimap = M.CreateFrame("Frame", "Minimap"); Minimap._width, Minimap._height = 140, 140
    GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip")
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    SOUNDKIT = {}; PlaySound = function() end
    YES, NO, ACCEPT, CANCEL = "Yes", "No", "Accept", "Cancel"
    StaticPopup_Show = function() end
    local pages = {}
    Settings = {
        RegisterCanvasLayoutCategory = function(frame) pages[#pages + 1] = frame; return { GetID = function() return 1 end } end,
        RegisterAddOnCategory = function() end,
        RegisterCanvasLayoutSubcategory = function(_, frame) pages[#pages + 1] = frame; return { GetID = function() return #pages end } end,
        OpenToCategory = function() end,
    }

    -- Un icono en el Cooldown Manager y la barra principal con un hechizo en la tecla 1
    local essential = M.CreateFrame("Frame", "EssentialCooldownViewer")
    local item = M.CreateFrame("Frame", nil, essential)
    item.Icon = item:CreateTexture()
    item.Cooldown = M.CreateFrame("Cooldown", nil, item)
    item.GetBaseSpellID = function() return 100 end
    for i = 1, 12 do
        local button = M.NewActionButton("ActionButton" .. i, i)
        button.bindingAction = "ACTIONBUTTON" .. i
    end

    -- Todos los archivos del .toc, en su orden
    local ns = {}
    for line in io.lines("RuscuuCDM.toc") do
        if line:match("%.lua$") then M.Load(ns, (line:gsub("\\", "/"))) end
    end

    return M, ns, pages
end
