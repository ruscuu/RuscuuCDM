-- Ruscuu Cooldown Manager Forever: números de cooldown y borde dorado en las barras de acción.
-- Solo cambia fuente, tamaño y color del texto que dibuja el juego; nunca lee el tiempo restante.
-- Al desactivarlo se restaura la fuente original de Blizzard sin recargar.
local _, ns = ...

local FONT_NAME = "RuscuuCDMActionFont"
local actionFont = CreateFont(FONT_NAME)

-- Métodos con los que el juego arranca un cooldown; tras cada uno se reaplica la fuente
local START_METHODS = { "SetCooldown", "SetCooldownDuration", "SetCooldownFromDurationObject", "SetCooldownUNIX" }

local buttons = {}                                       -- cooldown -> { button, bar, noActionSlot }
local buttonList = {}                                    -- los mismos datos en orden (barras de Blizzard primero)
local hookedCount = 0
local original = setmetatable({}, { __mode = "k" })     -- cooldown -> fuente original de Blizzard
local styled = setmetatable({}, { __mode = "k" })       -- cooldown -> versión del estilo aplicada
local version = 0

local function BarEnabled(barKey)
    return ns.db.bars[barKey] ~= false
end

local function UpdateFont()
    local db = ns.db
    local flags = ns.OutlineFlags(db.actionBarNumberOutline)
    actionFont:SetFont(db.font, db.actionBarFontSize, flags)
    if not actionFont:GetFont() then actionFont:SetFont(ns.DEFAULT_FONT, db.actionBarFontSize, flags) end
    local c = db.actionBarNumberColor
    actionFont:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- Guarda la fuente de Blizzard antes de cambiarla por primera vez
local function SaveOriginal(cd)
    if original[cd] then return end
    local info = {}
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then
        local fontObject = fs:GetFontObject()
        info.fontName = fontObject and fontObject.GetName and fontObject:GetName()
        info.file, info.size, info.flags = fs:GetFont()
        info.color = { fs:GetTextColor() }
    end
    original[cd] = info
end

local function Restore(cd)
    local info = original[cd]
    styled[cd] = nil
    if not info then return end
    if info.fontName and info.fontName ~= FONT_NAME then cd:SetCountdownFont(info.fontName) end
    local fs = cd:GetCountdownFontString()
    if fs and info.file then fs:SetFont(info.file, info.size, info.flags) end
    if fs and info.color and info.color[1] then fs:SetTextColor(unpack(info.color)) end
end

local function Style(cd)
    local db = ns.db
    local info = buttons[cd]
    if not db or not info then return end
    if not db.styleActionBarNumbers or not BarEnabled(info.bar) then
        if styled[cd] then Restore(cd) end
        return
    end
    SaveOriginal(cd)
    cd:SetCountdownFont(FONT_NAME)
    -- El texto ya creado se ajusta una sola vez por cambio de opciones (no en cada cooldown)
    if styled[cd] ~= version then
        styled[cd] = version
        local fs = cd:GetCountdownFontString()
        if fs then
            ns.SetFontSafe(fs, db.font, db.actionBarFontSize, ns.OutlineFlags(db.actionBarNumberOutline))
            local c = db.actionBarNumberColor
            fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        end
    end
end

------------------------------------------------------------------------
-- Borde dorado en los botones de acción
------------------------------------------------------------------------

local function ActionSlot(button)
    -- Botones de LibActionButton (Bartender4, ElvUI): la acción está en _state_action
    if button._state_type ~= nil then
        local action = button._state_type == "action" and tonumber(button._state_action)
        if action and action > 0 then return action end
        return
    end
    local action = button.action
    if not action and button.CalculateAction then action = button:CalculateAction() end
    if type(action) ~= "number" or action <= 0 then return end
    return action
end

-- Hechizo que hay en un hueco de acción (también en macros y objetos con hechizo)
local function ActionSpellID(action)
    local kind, id, subType = GetActionInfo(action)
    if ns.IsSecret(kind) or ns.IsSecret(id) then return end
    if kind == "spell" then return id end
    if kind == "macro" and subType == "spell" then return id end
    if kind == "item" and C_ActionBar and C_ActionBar.GetSpell then
        local spellID = C_ActionBar.GetSpell(action)
        if spellID and not ns.IsSecret(spellID) and spellID > 0 then return spellID end
    end
end

-- Cooldown del hueco de acción del botón (ignorando el cooldown global)
local function ButtonDuration(button)
    local action = ActionSlot(button)
    if not action or not HasAction(action) then return end
    if not ns.ExpireAllowed(ActionSpellID(action)) then return end
    return C_ActionBar.GetActionCooldownDuration(action, true)
end

-- ¿El cooldown del botón es solo el tiempo de reutilización global? (dato que el juego nunca oculta)
local function ActionOnGCD(button)
    local action = ActionSlot(button)
    if not action then return false end
    if C_ActionBar and C_ActionBar.GetActionCooldown then
        local info = C_ActionBar.GetActionCooldown(action)
        return info ~= nil and info.isOnGCD == true
    end
    return ns.SpellOnGCD(ActionSpellID(action))
end

local function UpdateExpireTracking()
    local db = ns.db
    local canTrack = C_ActionBar and C_ActionBar.GetActionCooldownDuration
    for _, info in pairs(buttons) do
        local button = info.button
        local icon = button.icon or button.Icon
        if canTrack and icon and not info.noActionSlot and db.expireOnActionBars and BarEnabled(info.bar) then
            ns.TrackExpire(button, icon, function() return ButtonDuration(button) end, nil,
                function() return ActionOnGCD(button) end)
        else
            ns.UntrackExpire(button)
        end
    end
end

------------------------------------------------------------------------
-- Enganches
------------------------------------------------------------------------

function ns.StyleActionBars()
    if not ns.db then return end
    version = version + 1
    UpdateFont()
    for cd in pairs(buttons) do Style(cd) end
    UpdateExpireTracking()
end

local function HookButton(button, barKey, noActionSlot)
    local cd = button and (button.cooldown or button.Cooldown)
    if not cd or buttons[cd] or not cd.HookScript then return end
    local info = { button = button, bar = barKey, noActionSlot = noActionSlot }
    buttons[cd] = info
    buttonList[#buttonList + 1] = info
    hookedCount = hookedCount + 1
    -- El texto de la cuenta atrás puede crearse al empezar el primer cooldown
    cd:HookScript("OnShow", Style)
    for _, method in ipairs(START_METHODS) do
        if type(cd[method]) == "function" then
            hooksecurefunc(cd, method, Style)
        end
    end
end

-- Botones de Blizzard que no son de las barras normales (no se tocan aunque usen la misma plantilla)
local SKIPPED_BUTTONS = { "^ExtraActionButton", "^OverrideActionBarButton" }
-- LibActionButton: la usan Bartender4 y otros; ElvUI lleva su propia copia
local LAB_NAMES = { "LibActionButton-1.0", "LibActionButton-1.0-ElvUI" }
local watchedLibraries = {}
local rescanQueued = false

local function QueueRescan()
    if rescanQueued then return end
    rescanQueued = true
    C_Timer.After(0.2, function()
        rescanQueued = false
        ns.HookActionBars()
    end)
end

local function HookAddonButtons()
    for _, libName in ipairs(LAB_NAMES) do
        local lab = LibStub and LibStub(libName, true)
        if lab and lab.GetAllButtons then
            for button in pairs(lab:GetAllButtons()) do HookButton(button, "addons") end
            -- Botones creados más tarde (al añadir barras)
            if not watchedLibraries[lab] and lab.RegisterCallback then
                watchedLibraries[lab] = true
                lab.RegisterCallback("RuscuuCDM", "OnButtonCreated", QueueRescan)
            end
        end
    end
    -- Dominos y otros addons que usan la plantilla de botón de acción de Blizzard
    local frames = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    if type(frames) == "table" then
        for _, button in pairs(frames) do
            local name = button.GetName and button:GetName()
            local skipped = not name
            for _, pattern in ipairs(SKIPPED_BUTTONS) do
                if name and name:find(pattern) then skipped = true end
            end
            if not skipped then HookButton(button, "addons") end
        end
    end
end

-- Se puede llamar varias veces: solo engancha los botones nuevos
function ns.HookActionBars()
    for _, group in ipairs(ns.ACTION_BARS) do
        if group.prefix then
            for i = 1, 12 do
                HookButton(_G[group.prefix .. i], group.key, group.noActionSlot)
            end
        end
    end
    HookAddonButtons()
    ns.StyleActionBars()
end

function ns.CountActionCooldowns()
    return hookedCount
end

-- Hechizos de las barras de acción (para la lista de exclusión del borde dorado)
function ns.GetActionBarSpells()
    local list, seen = {}, {}
    for _, info in pairs(buttons) do
        local action = not info.noActionSlot and ActionSlot(info.button)
        local spellID = action and HasAction(action) and ActionSpellID(action)
        if spellID then
            local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID) or spellID
            if ns.IsSecret(base) then base = spellID end
            if not seen[base] then
                seen[base] = true
                list[#list + 1] = {
                    spellID = base,
                    name = C_Spell.GetSpellName(base) or ("#" .. base),
                    icon = C_Spell.GetSpellTexture(base),
                }
            end
        end
    end
    return list
end

------------------------------------------------------------------------
-- Atajos de teclado: qué tecla lanza cada hechizo, para mostrarla en el Cooldown Manager.
-- Solo se lee la configuración de teclas y de barras (nunca datos de combate), y fuera de combate.
------------------------------------------------------------------------

-- Huecos de las barras de Blizzard -> comando de tecla. Sirve también para barras que no están a la
-- vista: las habilidades de forma de gato o de sigilo van en la barra principal solo en esa forma
local SLOT_COMMANDS = {
    { first = 1, last = 12, command = "ACTIONBUTTON" },
    { first = 25, last = 36, command = "MULTIACTIONBAR3BUTTON" },
    { first = 37, last = 48, command = "MULTIACTIONBAR4BUTTON" },
    { first = 49, last = 60, command = "MULTIACTIONBAR2BUTTON" },
    { first = 61, last = 72, command = "MULTIACTIONBAR1BUTTON" },
    { first = 73, last = 120, command = "ACTIONBUTTON" }, -- barras de forma, postura y sigilo
    { first = 145, last = 156, command = "MULTIACTIONBAR5BUTTON" },
    { first = 157, last = 168, command = "MULTIACTIONBAR6BUTTON" },
    { first = 169, last = 180, command = "MULTIACTIONBAR7BUTTON" },
}

local hotkeyBySpell = {}
local hotkeysDirty = true
local rebuildQueued = false

-- Texto corto de la tecla asignada a un comando ("1", "s-Q", "M4"...), como en los botones de Blizzard
local function CommandHotkey(command)
    local key = GetBindingKey(command)
    if not key then return end
    local text = GetBindingText(key, 1)
    if not text or text == "" then text = key end
    return text
end

-- Comandos con los que se puede pulsar un botón: el de Blizzard, el de Dominos, el de LibActionButton
-- o un clic directo
local function ButtonHotkey(button)
    local commands = {}
    if type(button.bindingAction) == "string" then commands[#commands + 1] = button.bindingAction end
    local attribute = button.GetAttribute and button:GetAttribute("commandName")
    if type(attribute) == "string" then commands[#commands + 1] = attribute end
    if type(button.GetBindingAction) == "function" then
        local ok, command = pcall(button.GetBindingAction, button)
        if ok and type(command) == "string" then commands[#commands + 1] = command end
    end
    local name = button:GetName()
    if name then
        commands[#commands + 1] = "CLICK " .. name .. ":LeftButton"
        commands[#commands + 1] = "CLICK " .. name .. ":Keybind"
        commands[#commands + 1] = "CLICK " .. name .. ":HOTKEY"
    end
    for _, command in ipairs(commands) do
        local text = CommandHotkey(command)
        if text then return text end
    end
    -- Último recurso: el texto que el propio botón ya muestra
    local text = button.HotKey and button.HotKey:GetText()
    if type(text) == "string" and not ns.IsSecret(text) and text ~= "" and text ~= RANGE_INDICATOR then
        return text
    end
end

-- Un hueco que no existe en esta versión del juego da error: se trata como vacío
local function SlotHasAction(action)
    local ok, has = pcall(HasAction, action)
    return ok and has == true
end

local function AddSpellHotkey(spellID, text)
    if not spellID or ns.IsSecret(spellID) then return end
    if not hotkeyBySpell[spellID] then hotkeyBySpell[spellID] = text end
    local base = C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)
    if base and not ns.IsSecret(base) and not hotkeyBySpell[base] then hotkeyBySpell[base] = text end
end

local function RebuildHotkeys()
    wipe(hotkeyBySpell)
    -- 1) Botones a la vista, de cualquier addon (lo que el jugador ve en pantalla manda)
    for _, info in ipairs(buttonList) do
        local button = info.button
        local visible = button:IsVisible()
        if not info.noActionSlot and visible == true then
            local action = ActionSlot(button)
            if action and SlotHasAction(action) then
                local spellID = ActionSpellID(action)
                local text = spellID and ButtonHotkey(button)
                if text then AddSpellHotkey(spellID, text) end
            end
        end
    end
    -- 2) Huecos de las barras de Blizzard aunque no se vean (formas, sigilo, barras ocultas)
    for _, range in ipairs(SLOT_COMMANDS) do
        for action = range.first, range.last do
            if SlotHasAction(action) then
                local spellID = ActionSpellID(action)
                local text = spellID and CommandHotkey(range.command .. ((action - range.first) % 12 + 1))
                if text then AddSpellHotkey(spellID, text) end
            end
        end
    end
    hotkeysDirty = false
    if ns.RefreshKeybinds then ns.RefreshKeybinds() end
end

-- Tecla del hechizo (o de su versión base), o nil si no está en ninguna barra con tecla asignada
function ns.GetSpellHotkey(spellID)
    if not spellID or ns.IsSecret(spellID) then return end
    return hotkeyBySpell[spellID]
end

-- Las teclas y las barras no se pueden cambiar en combate: se recalcula al salir
function ns.QueueHotkeyRebuild()
    hotkeysDirty = true
    if rebuildQueued or InCombatLockdown() then return end
    rebuildQueued = true
    C_Timer.After(0.2, function()
        rebuildQueued = false
        if InCombatLockdown() then return end
        RebuildHotkeys()
    end)
end

local hotkeyEvents = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" }) do
    pcall(hotkeyEvents.RegisterEvent, hotkeyEvents, event)
end
hotkeyEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not hotkeysDirty then return end
    ns.QueueHotkeyRebuild()
end)
