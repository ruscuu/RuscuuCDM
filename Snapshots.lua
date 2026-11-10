-- Ruscuu Cooldown Manager Forever: instantáneas de la interfaz.
-- Guarda y restaura cuatro cosas del juego: las posiciones de los marcos (diseño del Modo Edición),
-- las teclas asignadas, todas las macros y el contenido de las barras de acción.
-- Nada de esto lee datos de combate, y todo se hace fuera de combate: el juego bloquea esas funciones en combate.
-- Las instantáneas son de la cuenta, así que se pueden restaurar en cualquier personaje.
local _, ns = ...
local L = ns.L

local MAX_ACTION_SLOT = 180          -- huecos de acción del juego (barras 1 a 8, formas y barras de bonificación)
local MAX_ACCOUNT_MACROS = 120       -- las macros con un índice mayor son del personaje
local MAX_LAYOUTS = 5                -- diseños del Modo Edición por tipo (cuenta / personaje)
local LAYOUT_NAME_MAX = 32
local RANDOM_FAVORITE_MOUNT = 268435455
local CLASS_BAR_FIRST, CLASS_BAR_LAST = 73, 120   -- barras que cambia la clase (formas de druida, sigilo...)

-- Tipos de acción que se saben volver a colocar; el resto se guarda pero se informa como no restaurable
local ACTION_TYPES = {
    spell = "number", item = "number", flyout = "number", summonmount = "number",
    macro = "string", equipmentset = "string", summonpet = "string",
}

------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function NumPresetLayouts()
    local meta = Enum and Enum.EditModePresetLayoutsMeta
    return meta and meta.NumValues or 2
end

local function AccountLayoutType()
    local t = Enum and Enum.EditModeLayoutType
    return t and t.Account or 1
end

-- Recorta un texto UTF-8 sin cortar una letra por la mitad
local function TrimUTF8(text, maxBytes)
    if #text <= maxBytes then return text end
    text = text:sub(1, maxBytes)
    return (text:gsub("[\192-\255][\128-\191]*$", ""))
end

function ns.CanChangeInterface()
    return not InCombatLockdown()
end

------------------------------------------------------------------------
-- Modo Edición
------------------------------------------------------------------------

-- Diseño activo del Modo Edición: { layoutName, ... } o nil
local function ActiveLayoutInfo()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
    local layouts = Call(C_EditMode.GetLayouts)
    if type(layouts) ~= "table" or not layouts.activeLayout then return nil end
    local index, presets = layouts.activeLayout, NumPresetLayouts()
    if index > presets then return (layouts.layouts or {})[index - presets] end
    local manager = EditModePresetLayoutManager
    local copies = manager and Call(manager.GetCopyOfPresetLayouts, manager)
    return copies and copies[index]
end

local function CaptureLayout()
    local info = ActiveLayoutInfo()
    if not info or not C_EditMode.ConvertLayoutInfoToString then return nil end
    local text = Call(C_EditMode.ConvertLayoutInfoToString, info)
    if type(text) ~= "string" or text == "" then return nil end
    return text, info.layoutName
end

-- Guarda el diseño como un diseño de cuenta "Ruscuu <nombre>" y lo deja activo.
-- El juego lo aplica del todo al recargar la interfaz (así no se contamina el Modo Edición de Blizzard).
local function RestoreLayout(text, snapshotName)
    if not (C_EditMode and C_EditMode.ConvertStringToLayoutInfo and C_EditMode.SaveLayouts) then
        return false, L["This game version has no Edit Mode."]
    end
    local info = Call(C_EditMode.ConvertStringToLayoutInfo, text)
    local layouts = Call(C_EditMode.GetLayouts)
    if type(info) ~= "table" or type(layouts) ~= "table" then return false, L["The saved positions could not be read."] end
    layouts.layouts = layouts.layouts or {}

    local layoutType = AccountLayoutType()
    info.layoutName = TrimUTF8("Ruscuu " .. snapshotName, LAYOUT_NAME_MAX)
    info.layoutType = layoutType
    local index, sameType = nil, 0
    for i, layout in ipairs(layouts.layouts) do
        if layout.layoutType == layoutType then
            sameType = sameType + 1
            if layout.layoutName == info.layoutName then index = i end
        end
    end
    if not index then
        if sameType >= MAX_LAYOUTS then
            return false, L["Edit Mode already has %d account layouts: delete one and try again."]:format(MAX_LAYOUTS)
        end
        index = #layouts.layouts + 1
    end
    layouts.layouts[index] = info
    layouts.activeLayout = NumPresetLayouts() + index
    local ok, err = pcall(C_EditMode.SaveLayouts, layouts)
    if not ok then return false, tostring(err) end
    if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, layouts.activeLayout) end
    return true, info.layoutName
end

------------------------------------------------------------------------
-- Teclas
------------------------------------------------------------------------

-- Teclas que se revisan una a una: GetBinding solo lista los comandos de Bindings.xml, así que
-- las teclas puestas a botones de addons (CLICK), hechizos, macros u objetos no salen en esa lista
local SCAN_MODIFIERS = { "", "ALT-", "CTRL-", "SHIFT-", "ALT-CTRL-", "ALT-SHIFT-", "CTRL-SHIFT-", "ALT-CTRL-SHIFT-" }
local SCAN_KEYS = {
    "SPACE", "TAB", "ENTER", "BACKSPACE", "UP", "DOWN", "LEFT", "RIGHT", "HOME", "END", "PAGEUP", "PAGEDOWN",
    "INSERT", "DELETE", "MOUSEWHEELUP", "MOUSEWHEELDOWN", "`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/",
    "NUMPADDIVIDE", "NUMPADMULTIPLY", "NUMPADMINUS", "NUMPADPLUS", "NUMPADDECIMAL", "NUMPADENTER",
}
for c = ("A"):byte(), ("Z"):byte() do SCAN_KEYS[#SCAN_KEYS + 1] = string.char(c) end
for i = 0, 9 do
    SCAN_KEYS[#SCAN_KEYS + 1] = tostring(i)
    SCAN_KEYS[#SCAN_KEYS + 1] = "NUMPAD" .. i
end
for i = 1, 12 do SCAN_KEYS[#SCAN_KEYS + 1] = "F" .. i end
for i = 1, 31 do SCAN_KEYS[#SCAN_KEYS + 1] = "BUTTON" .. i end

local DIRECT_ACTIONS = { "^CLICK ", "^SPELL ", "^MACRO ", "^ITEM " }

-- Añade a la lista las teclas puestas directamente a botones, hechizos, macros u objetos
local function AddDirectBindings(list)
    local getAction = _G.GetBindingAction   -- por _G: no está en la lista de luacheck
    if type(getAction) ~= "function" then return end
    local listed = {}
    for _, pair in ipairs(list) do listed[pair[2]] = true end
    for _, modifier in ipairs(SCAN_MODIFIERS) do
        for _, base in ipairs(SCAN_KEYS) do
            local key = modifier .. base
            local action = not listed[key] and Call(getAction, key)
            if type(action) == "string" then
                for _, pattern in ipairs(DIRECT_ACTIONS) do
                    if action:match(pattern) then
                        list[#list + 1] = { action, key }
                        listed[key] = true
                        break
                    end
                end
            end
        end
    end
end

-- Lista de { comando, tecla } con todas las teclas asignadas a las acciones del juego y de los addons
local function CurrentBindings()
    local list = {}
    if not (GetNumBindings and GetBinding) then return list end
    for i = 1, GetNumBindings() do
        local binding = { pcall(GetBinding, i) }
        local command = binding[1] and binding[2]
        if type(command) == "string" and not command:match("^HEADER_") then
            for k = 4, #binding do
                if type(binding[k]) == "string" and binding[k] ~= "" then
                    list[#list + 1] = { command, binding[k] }
                end
            end
        end
    end
    AddDirectBindings(list)
    return list
end

local function RestoreBindings(saved)
    for _, pair in ipairs(CurrentBindings()) do SetBinding(pair[2]) end
    local count = 0
    for _, pair in ipairs(saved) do
        if SetBinding(pair[2], pair[1]) ~= false then count = count + 1 end
    end
    if SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
    return count
end

------------------------------------------------------------------------
-- Barras de acción
------------------------------------------------------------------------

-- Lo que hay en un hueco: { t = tipo, id = identificador, sub = subtipo } o nil si está vacío
local function ReadAction(slot)
    if not HasAction(slot) then return nil end
    local kind, id, sub = GetActionInfo(slot)
    if ns.IsSecret(kind) or ns.IsSecret(id) or type(kind) ~= "string" then return nil end
    if kind == "macro" then
        -- Las macros se guardan por nombre (el índice cambia al crear o borrar macros)
        id = GetActionText and GetActionText(slot)
        if type(id) ~= "string" or id == "" then return nil end
    end
    if id == nil then return nil end
    return { t = kind, id = id, sub = type(sub) == "string" and sub or nil }
end

local function SameAction(a, b)
    if a == nil or b == nil then return a == b end
    return a.t == b.t and a.id == b.id
end

-- Icono guardado en la macro: con el signo de interrogación GetMacroInfo da el del hechizo que muestra,
-- y si se guardara ese, la macro restaurada dejaría de cambiar de icono
local function StoredMacroIcon(index)
    local macroAPI = _G.C_Macro   -- por _G: no está en la lista de luacheck
    if macroAPI and macroAPI.GetSelectedMacroIcon then
        local icon = Call(macroAPI.GetSelectedMacroIcon, index)
        if icon then return icon end
    end
    local _, icon = GetMacroInfo(index)
    return icon
end

local function CaptureMacro(name, macros)
    if macros[name] or not GetMacroInfo then return end
    local _, icon, body = GetMacroInfo(name)
    if type(body) ~= "string" then return end
    local index = GetMacroIndexByName and GetMacroIndexByName(name) or 0
    if index > 0 then icon = StoredMacroIcon(index) end
    macros[name] = { icon = icon, body = body, perChar = index > MAX_ACCOUNT_MACROS }
end

-- Todas las macros de la cuenta y del personaje, estén o no en una barra
local function CaptureAllMacros(macros)
    if not (GetNumMacros and GetMacroInfo) then return end
    local numAccount, numChar = GetNumMacros()
    local function add(index, perChar)
        local name, _, body = GetMacroInfo(index)
        if type(name) == "string" and name ~= "" and type(body) == "string" and not macros[name] then
            macros[name] = { icon = StoredMacroIcon(index), body = body, perChar = perChar }
        end
    end
    for i = 1, numAccount or 0 do add(i, false) end
    for i = MAX_ACCOUNT_MACROS + 1, MAX_ACCOUNT_MACROS + (numChar or 0) do add(i, true) end
end

-- Crea las macros que falten y pone el texto guardado en las que ya existen con el mismo nombre
local function RestoreMacros(macros, report)
    local names = {}
    for name in pairs(macros) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local m = macros[name]
        local index = GetMacroIndexByName and GetMacroIndexByName(name) or 0
        if index > 0 then
            local icon = StoredMacroIcon(index)
            local _, shown, body = GetMacroInfo(index)
            -- Las instantáneas antiguas guardaban el icono mostrado: si coincide con él, se deja el guardado
            -- (si no, una macro con "?" se editaría y quedaría fija con el icono del hechizo)
            local wantIcon = m.icon
            if wantIcon == nil or wantIcon == shown then wantIcon = icon end
            if (body ~= m.body or icon ~= wantIcon) and EditMacro then
                if Call(EditMacro, index, name, wantIcon, m.body) then report.macrosUpdated = report.macrosUpdated + 1 end
            end
        elseif CreateMacro then
            if (Call(CreateMacro, name, m.icon or "INV_MISC_QUESTIONMARK", m.body, m.perChar) or 0) > 0 then
                report.macrosCreated = report.macrosCreated + 1
            else
                report.macrosFailed = report.macrosFailed + 1
            end
        end
    end
end

-- Botón de hechizo del libro (para los menús desplegables: portales, totems...)
local function FindFlyoutSlot(flyoutID)
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo) then return end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local flyoutType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = Call(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if lineInfo then
            for slot = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local info = Call(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                if info and info.actionID == flyoutID and (flyoutType == nil or info.itemType == flyoutType) then
                    return slot, bank
                end
            end
        end
    end
end

local function PickupMount(mountID)
    if not C_MountJournal then return end
    if mountID == RANDOM_FAVORITE_MOUNT then Call(C_MountJournal.Pickup, 0) return end
    if C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetDisplayedMountID then
        for i = 1, C_MountJournal.GetNumDisplayedMounts() do
            if C_MountJournal.GetDisplayedMountID(i) == mountID then Call(C_MountJournal.Pickup, i) return end
        end
    end
    local _, spellID = Call(C_MountJournal.GetMountInfoByID, mountID)
    if spellID and C_Spell and C_Spell.PickupSpell then Call(C_Spell.PickupSpell, spellID) end
end

-- Coge en el cursor lo que hay que poner en el hueco
local function PickupSaved(action, macros, report)
    local kind, id = action.t, action.id
    if kind == "spell" then
        Call(C_Spell and C_Spell.PickupSpell or PickupSpell, id)
    elseif kind == "item" then
        if C_ToyBox and PlayerHasToy and PlayerHasToy(id) then
            Call(C_ToyBox.PickupToyBoxItem, id)
        else
            Call(C_Item and C_Item.PickupItem or PickupItem, id)
        end
    elseif kind == "macro" then
        local index = GetMacroIndexByName and GetMacroIndexByName(id) or 0
        local saved = macros[id]
        if index == 0 and saved and CreateMacro then
            index = Call(CreateMacro, id, saved.icon or "INV_MISC_QUESTIONMARK", saved.body, saved.perChar) or 0
            if index > 0 then report.macrosCreated = report.macrosCreated + 1 end
        end
        if index > 0 then Call(PickupMacro, index) end
    elseif kind == "flyout" then
        local slot, bank = FindFlyoutSlot(id)
        if slot then Call(C_SpellBook.PickupSpellBookItem, slot, bank) end
    elseif kind == "summonmount" then
        PickupMount(id)
    elseif kind == "summonpet" then
        if C_PetJournal then Call(C_PetJournal.PickupPet, id) end
    elseif kind == "equipmentset" then
        if C_EquipmentSet then
            local setID = Call(C_EquipmentSet.GetEquipmentSetID, id)
            if setID then Call(C_EquipmentSet.PickupEquipmentSet, setID) end
        end
    end
    return GetCursorInfo() ~= nil
end

-- Nombre legible de una acción (para decir cuáles no se pudieron colocar)
function ns.DescribeAction(action)
    local kind, id = action.t, action.id
    local name
    if kind == "spell" then
        name = C_Spell and C_Spell.GetSpellName and Call(C_Spell.GetSpellName, id)
    elseif kind == "item" then
        name = C_Item and C_Item.GetItemNameByID and Call(C_Item.GetItemNameByID, id)
    elseif type(id) == "string" then
        name = id
    end
    return name or (kind .. " " .. tostring(id))
end

-- sameClass = false: la instantánea es de otra clase y sus barras de clase no se tocan
-- (si no, un guerrero dejaría vacías las barras de forma felina, de oso... de un druida)
local function RestoreActions(saved, macros, report, sameClass)
    ClearCursor()
    for slot = 1, MAX_ACTION_SLOT do
        local want = saved[slot]
        if not sameClass and slot >= CLASS_BAR_FIRST and slot <= CLASS_BAR_LAST then
            if not SameAction(ReadAction(slot), want) then report.classBarsSkipped = true end
        elseif not SameAction(ReadAction(slot), want) then
            if HasAction(slot) then
                PickupAction(slot)
                ClearCursor()
            end
            if want then
                if PickupSaved(want, macros, report) then
                    PlaceAction(slot)
                    ClearCursor()
                    report.actions = report.actions + 1
                else
                    ClearCursor()
                    report.failed[#report.failed + 1] = ns.DescribeAction(want)
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Instantáneas
------------------------------------------------------------------------

function ns.GetSnapshotNames()
    local names = {}
    for name in pairs(ns.global.snapshots) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function ns.GetSnapshot(name)
    return name and ns.global.snapshots[name]
end

-- Lee la interfaz actual: { layout, layoutName, bindings, actions, macros, ... }
function ns.CaptureInterface()
    local snap = { actions = {}, macros = {} }
    snap.layout, snap.layoutName = CaptureLayout()
    snap.bindings = CurrentBindings()
    for slot = 1, MAX_ACTION_SLOT do
        local action = ReadAction(slot)
        if action then
            snap.actions[slot] = action
            if action.t == "macro" then CaptureMacro(action.id, snap.macros) end
        end
    end
    CaptureAllMacros(snap.macros)
    local name, realm = UnitName("player"), GetRealmName()
    snap.character = name and (name .. "-" .. (realm or "")) or nil
    local _, class = UnitClass("player")
    snap.class = class
    local spec = ns.GetSpec()
    snap.spec = spec and ns.GetSpecInfo(spec) or nil
    snap.time = time and time() or nil
    return snap
end

-- Cuántas teclas, botones y macros tiene una instantánea
function ns.SnapshotCounts(snap)
    local actions, macros = 0, 0
    for _ in pairs(snap.actions or {}) do actions = actions + 1 end
    for _ in pairs(snap.macros or {}) do macros = macros + 1 end
    return #(snap.bindings or {}), actions, macros
end

function ns.SaveSnapshot(name)
    name = strtrim(name or "")
    if name == "" then return false, L["Write a name for the snapshot."] end
    ns.global.snapshots[name] = ns.CaptureInterface()
    return true, name
end

function ns.DeleteSnapshot(name)
    ns.global.snapshots[name] = nil
end

-- Restaura las partes elegidas ({ layout, bindings, macros, actions }); devuelve un informe o nil y el motivo
function ns.RestoreSnapshot(name, parts)
    local snap = ns.GetSnapshot(name)
    if not snap then return nil, L["That snapshot no longer exists."] end
    if not ns.CanChangeInterface() then return nil, L["Not available in combat."] end
    parts = parts or ns.global.snapshotRestore
    local report = { bindings = 0, actions = 0, macrosCreated = 0, macrosUpdated = 0, macrosFailed = 0, failed = {} }
    if parts.bindings and snap.bindings then
        report.bindings = RestoreBindings(snap.bindings)
        report.bindingsDone = true
    end
    if parts.macros and snap.macros then
        RestoreMacros(snap.macros, report)
        report.macrosDone = true
    end
    if parts.actions and snap.actions then
        local _, class = UnitClass("player")
        local sameClass = snap.class == nil or snap.class == class
        RestoreActions(snap.actions, snap.macros or {}, report, sameClass)
        report.actionsDone = true
        -- El informe lo escribe Options.lua; este aviso se da aquí para que salga siempre que pase
        if report.classBarsSkipped then
            ns.Print(L["This snapshot is from another class: its class bars (forms, stealth) were left untouched."], true)
        end
    end
    if parts.layout and snap.layout then
        local ok, result = RestoreLayout(snap.layout, name)
        if ok then report.layoutName = result else report.layoutError = result end
    end
    return report
end

------------------------------------------------------------------------
-- Exportar / importar: "!RUSCUUUI:1!" + base64 de líneas separadas por tabuladores.
-- La importación nunca ejecuta código: solo acepta líneas conocidas con valores del tipo esperado.
-- Formato 2: la primera línea es "V\t2" y la última "Z\t<número de líneas anteriores>", para rechazar
-- un texto cortado. El prefijo sigue siendo :1! porque las versiones anteriores ignoran esas líneas.
------------------------------------------------------------------------

local PREFIX = "!RUSCUUUI:1!"

local function Escape(text)
    return (tostring(text):gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\n", "\\n"):gsub("\r", ""))
end

local function Unescape(text)
    return (text:gsub("\\(.)", { ["\\"] = "\\", t = "\t", n = "\n" }))
end

function ns.ExportSnapshot(name)
    local snap = ns.GetSnapshot(name)
    if not snap then return nil end
    local lines = { "V\t2", "N\t" .. Escape(name) }
    if snap.class then lines[#lines + 1] = "C\t" .. Escape(snap.class) end
    if snap.layout then lines[#lines + 1] = "E\t" .. Escape(snap.layout) end
    for _, pair in ipairs(snap.bindings or {}) do
        lines[#lines + 1] = "B\t" .. Escape(pair[1]) .. "\t" .. Escape(pair[2])
    end
    for slot = 1, MAX_ACTION_SLOT do
        local a = snap.actions and snap.actions[slot]
        if a then lines[#lines + 1] = ("A\t%d\t%s\t%s\t%s"):format(slot, a.t, Escape(a.id), Escape(a.sub or "")) end
    end
    local macroNames = {}
    for macroName in pairs(snap.macros or {}) do macroNames[#macroNames + 1] = macroName end
    table.sort(macroNames)
    for _, macroName in ipairs(macroNames) do
        local m = snap.macros[macroName]
        lines[#lines + 1] = ("M\t%s\t%s\t%d\t%s"):format(Escape(macroName), Escape(m.icon or ""), m.perChar and 1 or 0, Escape(m.body))
    end
    lines[#lines + 1] = "Z\t" .. #lines
    return PREFIX .. ns.Base64Encode(table.concat(lines, "\n"))
end

local function ValidText(text, maxLength)
    return type(text) == "string" and text ~= "" and #text <= maxLength
end

-- Los nombres se miden en letras, como el cuadro donde se escriben (una letra rusa ocupa 2 bytes)
local function ValidName(text)
    local utf8Length = _G.strlenutf8   -- por _G: no está en la lista de luacheck
    return ValidText(text, 240) and (type(utf8Length) ~= "function" or utf8Length(text) <= 60)
end

-- Lee el texto exportado; devuelve el nombre propuesto y la instantánea, o nil y el motivo
function ns.ParseSnapshot(text)
    local payload = strtrim(text or ""):match("^" .. PREFIX:gsub("%p", "%%%0") .. "(.+)$")
    if not payload then return nil, L["Invalid import string."] end
    -- Un base64 completo tiene un múltiplo de 4 caracteres: si no, el texto se cortó
    local clean = payload:gsub("%s", "")
    if #clean % 4 ~= 0 then return nil, L["Invalid import string."] end
    local snap = { bindings = {}, actions = {}, macros = {} }
    local name, valid, version, complete, lineCount = nil, 0, 1, false, 0
    for line in ns.Base64Decode(payload):gmatch("[^\n]+") do
        local fields = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = Unescape(field) end
        local kind = fields[1]
        if kind == "V" and lineCount == 0 then
            version = tonumber(fields[2]) or version
        elseif kind == "Z" then
            complete = tonumber(fields[2]) == lineCount
        elseif kind == "N" and ValidName(fields[2]) then
            name = fields[2]
        elseif kind == "C" and ValidText(fields[2], 32) and fields[2]:match("^%u+$") then
            snap.class = fields[2]
        elseif kind == "E" and ValidText(fields[2], 50000) and fields[2]:match("^[%w%+/=]+$")
            and (not (C_EditMode and C_EditMode.ConvertStringToLayoutInfo)
                or type(Call(C_EditMode.ConvertStringToLayoutInfo, fields[2])) == "table") then
            snap.layout = fields[2]
            valid = valid + 1
        elseif kind == "B" and ValidText(fields[2], 200) and ValidText(fields[3], 64) then
            snap.bindings[#snap.bindings + 1] = { fields[2], fields[3] }
            valid = valid + 1
        elseif kind == "A" then
            local slot, actionType = tonumber(fields[2]), fields[3]
            local idType = ACTION_TYPES[actionType]
            local id = idType == "number" and tonumber(fields[4]) or fields[4]
            if slot and slot >= 1 and slot <= MAX_ACTION_SLOT and slot % 1 == 0 and idType
                and type(id) == idType and (idType == "number" or ValidText(id, 64)) then
                snap.actions[slot] = { t = actionType, id = id, sub = fields[5] ~= "" and fields[5] or nil }
                valid = valid + 1
            end
        elseif kind == "M" and ValidText(fields[2], 64) and type(fields[5]) == "string" and #fields[5] <= 1023 then
            local icon = tonumber(fields[3]) or (fields[3] ~= "" and fields[3]) or nil
            snap.macros[fields[2]] = { icon = icon, body = fields[5], perChar = fields[4] == "1" }
        end
        lineCount = lineCount + 1
    end
    -- Formato 2: si falta la última línea o no cuadra el número de líneas, el texto está cortado
    if version >= 2 and not complete then return nil, L["Invalid import string."] end
    if valid == 0 then return nil, L["Invalid import string."] end
    -- El tercer valor dice si el texto traía nombre (sin nombre nunca sustituye a otra instantánea)
    return name or L["Imported"], snap, name ~= nil
end

-- Importa como una instantánea nueva (si el nombre ya existe se le añade un número, salvo con replace)
function ns.ImportSnapshot(text, replace)
    local name, snap, named = ns.ParseSnapshot(text)
    if not name then return false, snap end
    local base, n = name, 2
    while ns.global.snapshots[name] and not (replace and named) do
        name = ("%s (%d)"):format(base, n)
        n = n + 1
    end
    ns.global.snapshots[name] = snap
    return true, name
end

------------------------------------------------------------------------
-- Exportar / importar todo: todas las instantáneas y todos los perfiles de estilo en un solo texto,
-- para llevarlos a otra cuenta o a otra versión del juego (por ejemplo, de la beta a la 1.0).
-- "!RUSCUUALL:1!" + base64 de líneas: "S\t<instantánea exportada>" y "P\t<nombre>\t<perfil exportado>".
------------------------------------------------------------------------

local ALL_PREFIX = "!RUSCUUALL:1!"

function ns.ExportAll()
    local lines = {}
    for _, name in ipairs(ns.GetSnapshotNames()) do
        lines[#lines + 1] = "S\t" .. ns.ExportSnapshot(name)
    end
    for _, name in ipairs(ns.GetProfileNames()) do
        lines[#lines + 1] = "P\t" .. Escape(name) .. "\t" .. ns.ExportProfile(name)
    end
    return ALL_PREFIX .. ns.Base64Encode(table.concat(lines, "\n"))
end

-- Importa todo lo válido; lo que tenga el mismo nombre se sustituye (así el perfil Default de una
-- instalación nueva recibe el estilo exportado). Devuelve cuántas instantáneas y perfiles se importaron.
function ns.ImportAll(text)
    local payload = strtrim(text or ""):match("^" .. ALL_PREFIX:gsub("%p", "%%%0") .. "(.+)$")
    if not payload then return false, L["Invalid import string."] end
    local snapshots, profiles = 0, 0
    for line in ns.Base64Decode(payload):gmatch("[^\n]+") do
        local kind, a, b = line:match("^(%u)\t([^\t]*)\t?([^\t]*)$")
        if kind == "S" and ns.ImportSnapshot(a, true) then
            snapshots = snapshots + 1
        elseif kind == "P" and ValidName(Unescape(a)) and ns.ImportProfileAs(Unescape(a), b) then
            profiles = profiles + 1
        end
    end
    if snapshots + profiles == 0 then return false, L["Invalid import string."] end
    if profiles > 0 then
        ns.UseProfile(ns.activeProfile)
        ns.RefreshAll()
    end
    return true, snapshots, profiles
end
