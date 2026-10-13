-- Ruscuu Cooldown Manager Forever: barra de "solo cooldowns activos".
-- Una barra propia del addon, centrada donde está la barra de esenciales, con un icono por cada hechizo
-- elegido que esté en cooldown. Por defecto salen los hechizos de esenciales y utilidad del Cooldown Manager,
-- y el jugador puede quitar cualquiera o añadir cualquier otro hechizo de su libro (o por su número), y sus
-- abalorios. Los buffs activos del Cooldown Manager se colocan en la misma línea. Al terminar un cooldown,
-- su icono se queda un momento con un destello.
--
-- Todo respeta los valores secretos de Forever: saber si un hechizo está en cooldown (isActive), si es solo el
-- tiempo de reutilización global (isOnGCD), si recarga cargas (isActive de las cargas) y cuántas cargas tiene
-- como máximo (maxCharges) está permitido incluso en combate. El tiempo restante nunca se lee: el juego lo
-- dibuja a partir de su DurationObject, y el número de cargas se pasa tal cual al texto.
-- Los iconos de esenciales y utilidad de Blizzard se ocultan con transparencia mientras la barra está activa,
-- y todo vuelve a su sitio al desactivarla o mientras están abiertos el modo de edición o los ajustes de
-- cooldowns de Blizzard.
local _, ns = ...
local L = ns.L

local LINGER = 1             -- segundos que se ve un icono con destello tras terminar su cooldown
local MIN_FLASH = 1.6        -- sin destello si el icono se vio menos que un tiempo de reutilización global
local EVAL_INTERVAL = 0.1    -- cada cuánto se revisa qué cooldowns están activos
local COOLDOWN_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
local BUFF_VIEWER = "BuffIconCooldownViewer"
local BUFF_BAR_VIEWER = "BuffBarCooldownViewer"
local PREVIEW_LENGTH = 10    -- segundos de la vista previa de la barra
ns.TRINKET_SLOTS = { 13, 14 }

-- Sonidos para avisar de que un cooldown está listo (kit de Blizzard, con su número por si falta el nombre)
ns.ACTIVE_SOUNDS = {
    { key = "ready", kit = "READY_CHECK", id = 8960, nameKey = "Ready check" },
    { key = "warning", kit = "RAID_WARNING", id = 8959, nameKey = "Raid warning" },
    { key = "alarm", kit = "ALARM_CLOCK_WARNING_3", id = 12889, nameKey = "Alarm clock" },
    { key = "ping", kit = "MAP_PING", id = 3175, nameKey = "Map ping" },
}

function ns.PlayActiveSound(key)
    for _, sound in ipairs(ns.ACTIVE_SOUNDS) do
        if sound.key == key then
            local kit = SOUNDKIT and SOUNDKIT[sound.kit] or sound.id
            pcall(PlaySound, kit, "Master")
            return
        end
    end
end

------------------------------------------------------------------------
-- Iconos de Blizzard: se ocultan (esenciales y utilidad) o se colocan en la línea (buffs)
------------------------------------------------------------------------

-- Estado propio por icono de Blizzard, en una tabla aparte para no escribir campos en sus frames
local blizz = setmetatable({}, { __mode = "k" })  -- icono -> { points, moved, hidden, mouse, scale, fitted }
local applied = false        -- hay iconos de Blizzard ocultos, movidos o escalados que habrá que devolver

local function State(item)
    local s = blizz[item]
    if not s then
        s = {}
        blizz[item] = s
    end
    return s
end

-- Lee un valor de Blizzard solo si no es secreto
local function Plain(value)
    if ns.IsSecret(value) then return nil end
    return value
end

local function Shown(frame)
    local shown = frame:IsShown()
    return ns.IsSecret(shown) or shown == true
end

-- Iconos de una barra de Blizzard en su orden (los que no tienen sitio en ella, sin layoutIndex, no cuentan)
local function ViewerItems(viewer)
    local list = {}
    if not viewer then return list end
    for _, item in ipairs(ns.GetViewerItems(viewer)) do
        if Plain(item.layoutIndex) then list[#list + 1] = item end
    end
    table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
    return list
end

local function SavePoints(item)
    local s = State(item)
    s.points = {}
    for i = 1, item:GetNumPoints() do s.points[i] = { item:GetPoint(i) } end
    s.moved = false
end

local function RestorePoints(item)
    local s = blizz[item]
    if not (s and s.moved and s.points) then return end
    item:ClearAllPoints()
    for _, point in ipairs(s.points) do item:SetPoint(unpack(point)) end
    s.moved = false
end

local function SetHidden(item, hidden)
    local s = State(item)
    if hidden == (s.hidden == true) then
        -- Blizzard vuelve a activar la ayuda al reutilizar un icono (SetTooltipsShown): se apaga otra vez
        if hidden and item:IsMouseMotionEnabled() == true then
            s.mouse = true
            item:SetMouseMotionEnabled(false)
        end
        return
    end
    s.hidden = hidden
    if hidden then
        -- Invisible y sin ayuda al pasar el ratón (podría quedar debajo de un icono visible)
        s.mouse = item:IsMouseMotionEnabled()
        item:SetAlpha(0)
        item:SetMouseMotionEnabled(false)
    else
        item:SetAlpha(1)
        if s.mouse ~= nil then item:SetMouseMotionEnabled(s.mouse) end
    end
end

-- Escala de Blizzard de un icono de buff, guardada antes de cambiarla para poder devolverla
local function SaveScale(item)
    local s = State(item)
    local scale = Plain(item:GetScale())
    if scale and scale ~= s.fitted then s.scale = scale end
end

local function RestoreScale(item)
    local s = blizz[item]
    if not (s and s.fitted) then return end
    if s.scale then item:SetScale(s.scale) end
    s.fitted = nil
end

------------------------------------------------------------------------
-- Hechizos de la barra
------------------------------------------------------------------------

local cdmSpells = {}         -- hechizos de esenciales y utilidad, en su orden (la última lista que se pudo leer)
local cdmSet = {}
local entriesDirty = true

-- Lee los hechizos del Cooldown Manager. Si el juego oculta alguno (en combate) se conserva la lista anterior.
local function ReadCDMSpells()
    local list, seen = {}, {}
    for _, name in ipairs(COOLDOWN_VIEWERS) do
        for _, item in ipairs(ViewerItems(_G[name])) do
            local id = item.GetBaseSpellID and item:GetBaseSpellID()
            if (not id or id == 0) and item.GetSpellID then id = item:GetSpellID() end
            if ns.IsSecret(id) then return false end
            if type(id) == "number" and id > 0 and not seen[id] then
                seen[id] = true
                list[#list + 1] = id
            end
        end
    end
    cdmSpells, cdmSet = list, seen
    return true
end

-- Hechizos del Cooldown Manager (para la lista de opciones)
function ns.GetCDMSpellIDs()
    ReadCDMSpells()
    return cdmSpells
end

-- ¿Sale este hechizo en la barra? Los del Cooldown Manager salen salvo que se quiten; los demás, si se añaden
function ns.IsActiveSpellChosen(spellID)
    local db = ns.db
    if db.activeAdd[spellID] then return true end
    return db.activeCDM and cdmSet[spellID] == true and not db.activeRemove[spellID]
end

function ns.SetActiveSpellChosen(spellID, on)
    local db = ns.db
    if on then
        db.activeRemove[spellID] = nil
        if not ns.IsActiveSpellChosen(spellID) then db.activeAdd[spellID] = true end
    else
        db.activeAdd[spellID] = nil
        if ns.IsActiveSpellChosen(spellID) then db.activeRemove[spellID] = true end
    end
    entriesDirty = true
end

local function SpellName(spellID)
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    return ok and type(name) == "string" and name or ("#" .. spellID)
end

-- Hechizos del libro del jugador (y de su mascota), sin pasivos ni los de otras especializaciones
function ns.GetSpellbookSpells()
    local list, seen = {}, {}
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank) then return list end
    local SPELL = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    local PET_ACTION = Enum.SpellBookItemType and Enum.SpellBookItemType.PetAction
    -- En Forever los hechizos tienen rangos: cada rango es otro hechizo con el mismo nombre. Se deja uno por
    -- nombre (el último del libro, que es el rango más alto) y se recuerdan todos sus rangos.
    local byName = {}
    local function add(info, spellID)
        if not info or info.isPassive or info.isOffSpec or type(spellID) ~= "number" or seen[spellID] then return end
        seen[spellID] = true
        local name = info.name or SpellName(spellID)
        local entry = byName[name]
        if entry then
            entry.spellID, entry.icon = spellID, info.iconID or entry.icon
            entry.ranks[#entry.ranks + 1] = spellID
            return
        end
        entry = { spellID = spellID, name = name, icon = info.iconID, ranks = { spellID } }
        byName[name] = entry
        list[#list + 1] = entry
    end
    local FLYOUT = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
    -- Hechizos de un menú desplegable del libro (portales, invocaciones...)
    local function addFlyout(flyoutID)
        if not (GetFlyoutInfo and GetFlyoutSlotInfo) then return end
        local ok, _, _, numSlots, known = pcall(GetFlyoutInfo, flyoutID)
        if not ok or not known or type(numSlots) ~= "number" then return end
        for i = 1, numSlots do
            local okSlot, spellID, _, slotKnown, slotName = pcall(GetFlyoutSlotInfo, flyoutID, i)
            if okSlot and slotKnown and type(spellID) == "number" then
                local okIcon, icon = pcall(C_Spell.GetSpellTexture, spellID)
                add({ name = slotName ~= "" and slotName or nil, iconID = okIcon and icon or nil }, spellID)
            end
        end
    end
    local player = Enum.SpellBookSpellBank.Player
    for line = 1, book.GetNumSpellBookSkillLines() or 0 do
        local lineInfo = book.GetSpellBookSkillLineInfo(line)
        if lineInfo and not lineInfo.shouldHide and not lineInfo.isGuild and not lineInfo.offSpecID then
            for slot = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local info = book.GetSpellBookItemInfo(slot, player)
                if info and info.itemType == SPELL then
                    add(info, info.actionID) -- el hechizo base: el que lo sustituye cambia con talentos y formas
                elseif info and info.itemType == FLYOUT then
                    addFlyout(info.actionID)
                end
            end
        end
    end
    local pets = book.HasPetSpells and book.HasPetSpells()
    local petBank = Enum.SpellBookSpellBank.Pet
    for slot = 1, (type(pets) == "number" and pets or 0) do
        local info = book.GetSpellBookItemInfo(slot, petBank)
        if info and (info.itemType == SPELL or info.itemType == PET_ACTION) then
            local spellID = info.spellID
            if not spellID and C_PetInfo and C_PetInfo.GetSpellForPetAction then
                local ok, id = pcall(C_PetInfo.GetSpellForPetAction, info.actionID)
                spellID = ok and id or nil
            end
            add(info, spellID)
        end
    end
    return list
end

-- Hechizos de la mascota actual -> su hueco en el libro de la mascota (cambia al cambiar de mascota).
-- Sus cooldowns se piden por el hueco, que es lo que el juego documenta para la mascota.
local petSlots = {}
local function RebuildPetSlots()
    petSlots = {}
    local book = C_SpellBook
    if not (book and book.HasPetSpells and Enum and Enum.SpellBookSpellBank) then return end
    local ok, pets = pcall(book.HasPetSpells)
    local petBank = Enum.SpellBookSpellBank.Pet
    for slot = 1, (ok and type(pets) == "number" and pets or 0) do
        local okInfo, info = pcall(book.GetSpellBookItemInfo, slot, petBank)
        local spellID = okInfo and type(info) == "table" and info.spellID
        if type(spellID) == "number" and not ns.IsSecret(spellID) then petSlots[spellID] = slot end
    end
end

-- ¿Conoce el personaje este hechizo? true / false, o nil si el juego no deja saberlo.
-- Los perfiles pueden compartirse entre personajes: así un hechizo de otra clase nunca sale en la barra.
function ns.PlayerKnowsSpell(spellID)
    if petSlots[spellID] then return true end
    local checks = {
        IsPlayerSpell and function() return IsPlayerSpell(spellID) end,
        IsSpellKnown and function() return IsSpellKnown(spellID) end,
        IsSpellKnown and function() return IsSpellKnown(spellID, true) end, -- de la mascota
        C_SpellBook and C_SpellBook.IsSpellKnown and function() return C_SpellBook.IsSpellKnown(spellID) end,
    }
    local answered = false
    for i = 1, 4 do
        if checks[i] then
            local ok, known = pcall(checks[i])
            if ok and type(known) == "boolean" and not ns.IsSecret(known) then
                if known then return true end
                answered = true
            end
        end
    end
    if not answered then return nil end
    -- Rangos y hechizos de menús desplegables: si está en el libro del personaje, lo conoce
    local okBook, book = pcall(ns.GetSpellbookSpells)
    local name = SpellName(spellID)
    for _, sp in ipairs(okBook and book or {}) do
        if sp.name == name then return true end
        for _, id in ipairs(sp.ranks or {}) do
            if id == spellID then return true end
        end
    end
    return false
end

-- Busca un hechizo por su número o por su nombre; devuelve su número o nil
function ns.FindSpell(text)
    text = strtrim(text or "")
    if text == "" then return end
    local id = tonumber(text)
    if not id then
        local ok, info = pcall(C_Spell.GetSpellInfo, text)
        id = ok and type(info) == "table" and info.spellID or nil
    end
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return end
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok and type(name) == "string" then return id end
end

-- Funciones de objetos del juego (pueden no existir en algún cliente: entonces se ignora)
local function ItemAPI(name)
    return C_Item and C_Item[name]
end

function ns.ActiveItemIcon(itemID)
    local get = ItemAPI("GetItemIconByID")
    if not get then return end
    local ok, icon = pcall(get, itemID)
    if ok and not ns.IsSecret(icon) then return icon end
end

local function ItemName(itemID)
    local ok, name = pcall(ItemAPI("GetItemNameByID"), itemID)
    if ok and type(name) == "string" then return name end
    -- Aún no está en la caché del juego: se pide, y GET_ITEM_INFO_RECEIVED avisa cuando llega
    pcall(ItemAPI("RequestLoadItemDataByID"), itemID)
    return "#" .. itemID
end
ns.ActiveItemName = ItemName

-- Busca un objeto por su número, su enlace o su nombre (de algo que el juego conozca, como lo de las bolsas)
function ns.FindItem(text)
    text = strtrim(text or "")
    if text == "" then return end
    local id = tonumber(text) or tonumber(text:match("item:(%d+)"))
    if not id then
        local ok, found = pcall(ItemAPI("GetItemInfoInstant"), text)
        id = ok and found or nil
    end
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return end
    local ok, found = pcall(ItemAPI("GetItemInfoInstant"), id)
    if ok and found then return id end
end

-- Lo que muestra la barra: hechizos del Cooldown Manager, los añadidos (por nombre), los abalorios y los objetos,
-- en el orden que eligió el jugador (lo que no tiene sitio en ese orden va al final)
local function BuildEntries()
    local db = ns.db
    local entries, seen = {}, {}
    local names = {}
    local function addSpell(id)
        local name = SpellName(id)
        if seen[id] or names[name] then return end -- dos rangos del mismo hechizo: un solo icono
        seen[id], names[name] = true, true
        entries[#entries + 1] = { key = "spell" .. id, spell = id }
    end
    if db.activeCDM then
        for _, id in ipairs(cdmSpells) do
            if not db.activeRemove[id] then addSpell(id) end
        end
    end
    local extras = {}
    for id, on in pairs(db.activeAdd) do
        -- Un hechizo que este personaje no conoce (de otra clase que usa el mismo perfil) no sale
        if on and type(id) == "number" and not seen[id] and ns.PlayerKnowsSpell(id) ~= false then extras[#extras + 1] = { id = id, name = SpellName(id) } end
    end
    table.sort(extras, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for _, e in ipairs(extras) do addSpell(e.id) end
    for i, slot in ipairs(ns.TRINKET_SLOTS) do
        if db["activeTrinket" .. i] then entries[#entries + 1] = { key = "slot" .. slot, slot = slot } end
    end
    local items = {}
    for id, on in pairs(db.activeItems) do
        if on and type(id) == "number" then items[#items + 1] = { id = id, name = ItemName(id) } end
    end
    table.sort(items, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for _, it in ipairs(items) do entries[#entries + 1] = { key = "item" .. it.id, item = it.id } end

    local rank = {}
    for i, key in ipairs(db.activeOrder) do
        if type(key) == "string" and not rank[key] then rank[key] = i end
    end
    for i, e in ipairs(entries) do e.index = i end
    table.sort(entries, function(a, b)
        return (rank[a.key] or 10000 + a.index) < (rank[b.key] or 10000 + b.index)
    end)
    return entries
end

------------------------------------------------------------------------
-- Estado de cada cooldown (solo datos que el juego nunca oculta)
------------------------------------------------------------------------

local onGCD = {}             -- hechizo -> su cooldown es solo el GCD (se anota al recibir SPELL_UPDATE_COOLDOWN)
-- hechizo -> se vio en un cooldown real. Así no se oculta antes de tiempo si al cooldown le queda menos que
-- un GCD que acaba de empezar (el juego puede marcarlo entonces como isOnGCD)
local latched = {}
local apiState               -- el juego da isActive: true / false, o nil si aún no se ha consultado

-- El hechizo que hay ahora en lugar del elegido (talentos y formas lo cambian)
local function Resolve(base)
    if petSlots[base] then return base end
    local ok, id = pcall(C_Spell.GetOverrideSpell, base)
    if ok and type(id) == "number" and not ns.IsSecret(id) then return id end
    return base
end

local function PlainBool(value)
    return type(value) == "boolean" and not ns.IsSecret(value)
end

-- Cooldown, cargas y duraciones: de la mascota por su hueco en el libro, del jugador por el número de hechizo
local function GetCooldown(id)
    local slot = petSlots[id]
    if slot then return pcall(C_SpellBook.GetSpellBookItemCooldown, slot, Enum.SpellBookSpellBank.Pet) end
    return pcall(C_Spell.GetSpellCooldown, id)
end

local function GetCharges(id)
    local slot = petSlots[id]
    if slot then return pcall(C_SpellBook.GetSpellBookItemCharges, slot, Enum.SpellBookSpellBank.Pet) end
    return pcall(C_Spell.GetSpellCharges, id)
end

local function GetChargeDuration(id)
    local slot = petSlots[id]
    if slot then return pcall(C_SpellBook.GetSpellBookItemChargeDuration, slot, Enum.SpellBookSpellBank.Pet) end
    return pcall(C_Spell.GetSpellChargeDuration, id)
end

local function GetCooldownDuration(id)
    local slot = petSlots[id]
    if slot then
        return pcall(C_SpellBook.GetSpellBookItemCooldownDuration, slot, Enum.SpellBookSpellBank.Pet, true)
    end
    return pcall(C_Spell.GetSpellCooldownDuration, id, true)
end

-- Devuelve: activo (true/false, o nil si no se puede saber), sin cargas, recargando, si usa cargas
local function SpellState(id)
    local ok, info = GetCooldown(id)
    if not ok then
        apiState = false
        return nil
    end
    if type(info) ~= "table" then return false end -- el jugador no tiene el hechizo
    if not PlainBool(info.isActive) then
        apiState = false
        return nil
    end
    apiState = true
    if not info.isActive then latched[id] = nil end
    -- Solo cuenta si el aviso de cambio de cooldowns confirmó que no es el GCD. Al lanzar algo, todos los
    -- hechizos pasan un instante a "en cooldown" antes de ese aviso: sin esto saldrían todos de golpe.
    local empty = info.isActive and latched[id] == true
    local okc, charges = GetCharges(id)
    local max = okc and type(charges) == "table" and charges.maxCharges
    local isCharge = type(max) == "number" and not ns.IsSecret(max) and max > 1
    -- Con cargas: se ve mientras recarga alguna (el juego dice cuándo, aunque no cuántas quedan)
    local recharging = isCharge and PlainBool(charges.isActive) and charges.isActive or false
    return empty or recharging, empty, recharging, isCharge
end

-- Abalorios y objetos: el juego no oculta su cooldown, pero por si acaso se comprueba
local function TimesState(ok, start, duration, enable)
    if not ok or ns.IsSecret(start) or ns.IsSecret(duration) or ns.IsSecret(enable) then return nil end
    if type(start) ~= "number" or type(duration) ~= "number" then return false end
    local active = (enable == 1 or enable == true) and start > 0 and duration > 1.5 and start + duration > GetTime()
    return active, start, duration
end

local function SlotState(slot)
    if not GetInventoryItemCooldown then return false end
    return TimesState(pcall(GetInventoryItemCooldown, "player", slot))
end

local function ItemState(itemID)
    local get = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not get then return false end
    return TimesState(pcall(get, itemID))
end

------------------------------------------------------------------------
-- La barra propia y sus iconos
------------------------------------------------------------------------

local bar = CreateFrame("Frame", "RuscuuCDMActiveBar", UIParent)
bar:SetSize(1, 1)
bar:SetFrameStrata("MEDIUM")
bar:SetClampedToScreen(true)
bar:SetMovable(true)
bar:Hide()
-- Asa para arrastrar: solo se ve con la barra desbloqueada. Va por encima de todo (de los iconos, de los
-- buffs de Blizzard colocados en la línea y de la ventana de opciones) para que el clic siempre llegue.
bar.mover = CreateFrame("Frame", nil, bar)
bar.mover:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
bar.mover:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
bar.mover:SetFrameStrata("DIALOG")
bar.mover:EnableMouse(true)
bar.mover:RegisterForDrag("LeftButton")
bar.mover:Hide()
bar.bg = bar.mover:CreateTexture(nil, "BACKGROUND")
bar.bg:SetAllPoints()
bar.bg:SetColorTexture(ns.COLORS.purple[1], ns.COLORS.purple[2], ns.COLORS.purple[3], 0.35)
bar.label = bar.mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bar.label:SetPoint("BOTTOM", bar.mover, "TOP", 0, 2)

local icons = {}             -- clave ("spell123", "slot13") -> icono
local entries = {}           -- lo que se muestra, en orden
local lastLine               -- iconos de la última línea colocada, para no recolocar si no cambia
local layoutDirty = true     -- tamaño o separación cambiados: hay que recolocar

local function ShowTooltip(f)
    if not f.entry then return end
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    if f.entry.slot then
        GameTooltip:SetInventoryItem("player", f.entry.slot)
    elseif f.entry.item then
        GameTooltip:SetItemByID(f.entry.item)
    else
        GameTooltip:SetSpellByID(f.spellID or f.entry.spell)
    end
    GameTooltip:Show()
end

local function NewIcon()
    local f = CreateFrame("Frame", nil, bar)
    f:SetSize(40, 40)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.border = ns.MakeBorder(f, f.icon)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.icon)
    -- El juego no avisa cuando termina un cooldown: el barrido sí, y se revisa al momento
    f.cd:HookScript("OnCooldownDone", function() ns.RequestActiveUpdate() end)
    -- Textos por encima del barrido y de los bordes
    f.texts = CreateFrame("Frame", nil, f)
    f.texts:SetAllPoints(f.icon)
    f.texts:SetFrameLevel(f:GetFrameLevel() + 7)
    -- Con fuente desde el principio: escribir en un texto sin fuente da error
    f.count = f.texts:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.count:SetPoint("BOTTOMRIGHT", -2, 2)
    f.keyLabel = f.texts:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    -- Destello al terminar
    f.flash = CreateFrame("Frame", nil, f)
    f.flash:SetAllPoints(f.icon)
    f.flash:SetFrameLevel(f:GetFrameLevel() + 6)
    local glow = f.flash:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetTexture(ns.WHITE)
    glow:SetBlendMode("ADD")
    f.flash:Hide()
    -- Ayuda del hechizo al pasar el ratón, sin bloquear los clics
    f:SetMouseMotionEnabled(true)
    f:SetScript("OnEnter", ShowTooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Borde dorado: el juego decide el color con el DurationObject del cooldown
    ns.TrackExpire(f, f.icon, function() return ns.ActiveIconDuration(f) end)
    f:Hide()
    return f
end

local function GetIcon(entry)
    local f = icons[entry.key]
    if not f then
        f = NewIcon()
        icons[entry.key] = f
    end
    f.entry = entry
    return f
end

local function StyleIcon(f, db)
    local z = db.iconZoom
    f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    ns.LayoutBorder(f.border, db.borderSize, ns.BorderColor(db))
    local cd, c = f.cd, db.swipeColor
    cd:SetSwipeTexture(ns.WHITE, c[1], c[2], c[3], c[4] or 1)
    cd:SetSwipeColor(c[1], c[2], c[3], c[4] or 1)
    -- El destello de estrella solo si se pide: la barra ya tiene su propio destello al terminar
    cd:SetDrawBling(db.cooldownBling == "show")
    -- El juego calcula y dibuja los números; el addon solo decide si se muestran y con qué fuente
    cd:SetHideCountdownNumbers(not db.showNumbers)
    cd:SetCountdownFont(ns.CDM_FONT_NAME)
    ns.StyleText(cd:GetCountdownFontString(), db.fontSize, db.numberOutline, db.numberColor)
    ns.StyleText(f.count, db.countSize, db.countOutline, db.countUseColor and db.countColor or nil)
    ns.StyleKeybindText(f.keyLabel, f.texts, db)
    f.style = nil -- el aspecto del barrido depende del estado: se vuelve a aplicar
end

local function UpdateKeybind(f, db)
    local key
    if db.showKeybinds and f.entry and f.entry.spell and ns.GetSpellHotkey then
        key = ns.GetSpellHotkey(f.entry.spell) or (f.spellID and ns.GetSpellHotkey(f.spellID))
    end
    f.keyLabel:SetText(key or "")
    f.keyLabel:SetShown(key ~= nil)
end

local function UpdateTexture(f)
    local entry, texture = f.entry
    if entry.slot then
        local ok, tex = pcall(GetInventoryItemTexture, "player", entry.slot)
        texture = ok and tex or nil
    elseif entry.item then
        texture = ns.ActiveItemIcon(entry.item)
    else
        -- Con el hechizo base: el juego ya da el icono del que lo sustituye, y vuelve al original al terminar
        local ok, tex, _, conditional = pcall(C_Spell.GetSpellTexture, entry.spell)
        texture = ok and tex or nil
        if ok and conditional and not ns.IsSecret(conditional) and not ns.IsSecret(tex) then texture = conditional end
    end
    if ns.IsSecret(texture) then return end
    f.icon:SetTexture(texture or 134400)
end

-- Duración del cooldown de un icono para el borde dorado: se pide al juego cada vez, como en los iconos
-- de Blizzard (nil si no está en cooldown, si el hechizo está excluido o si el borde está apagado)
function ns.ActiveIconDuration(f)
    local kind = f.durationKind
    if not kind then return end
    if kind == "slot" then return f.slotDuration end
    local ok, d
    if kind == "charge" then
        ok, d = GetChargeDuration(f.spellID)
    else
        ok, d = GetCooldownDuration(f.spellID)
    end
    if ok then return d end
end

-- Barrido, cargas y borde dorado de un hechizo. Solo se toca cuando cambia algo (avisos del juego o estado),
-- no en cada revisión. El aspecto imita al de Blizzard: con cargas restantes, solo el borde del barrido.
local function ApplySpellCooldown(f, db, active, empty, recharging, isCharge)
    local id, duration = f.spellID, nil
    if active then
        local ok, d
        if recharging then
            ok, d = GetChargeDuration(id)
        else
            ok, d = GetCooldownDuration(id)
        end
        duration = ok and d or nil
    end
    if duration then
        f.cd:SetCooldownFromDurationObject(duration)
    else
        f.cd:Clear()
    end
    f.durationKind = nil
    if duration and ns.ExpireAllowed(f.entry.spell) and db.expireOnCDM then
        f.durationKind = recharging and "charge" or "cooldown"
    end
    local realCooldown = active and (empty or not isCharge)
    f.cd:SetDrawSwipe(db.showSwipe and realCooldown)
    if db.cooldownEdge == "blizzard" then
        f.cd:SetDrawEdge(isCharge and not empty)
    else
        f.cd:SetDrawEdge(db.cooldownEdge == "show")
    end
    f.icon:SetDesaturated(realCooldown)
    if isCharge then
        local ok, text = pcall(C_Spell.GetSpellDisplayCount, id, 99)
        if ok then
            f.count:SetText(text) -- puede ser secreto: se pasa tal cual, sin mirarlo
            f.count:Show()
        else
            f.count:Hide()
        end
    else
        f.count:Hide()
    end
end

local function ApplySlotCooldown(f, db, active, start, duration)
    if active then
        f.cd:SetCooldown(start, duration)
        f.durationKind = nil
        if C_DurationUtil and C_DurationUtil.CreateDuration then
            f.slotDuration = f.slotDuration or C_DurationUtil.CreateDuration()
            if pcall(f.slotDuration.SetTimeFromStart, f.slotDuration, start, duration) and db.expireOnCDM then
                f.durationKind = "slot"
            end
        end
    else
        f.cd:Clear()
        f.durationKind = nil
    end
    f.cd:SetDrawSwipe(db.showSwipe)
    if db.cooldownEdge ~= "blizzard" then f.cd:SetDrawEdge(db.cooldownEdge == "show") end
    f.icon:SetDesaturated(active == true)
    -- Objetos: cuántos quedan en las bolsas (pociones, piedras de salud...)
    local count = f.entry and f.entry.item and ItemAPI("GetItemCount")
    local ok, n = false, nil
    if count then ok, n = pcall(count, f.entry.item) end
    if ok and type(n) == "number" and not ns.IsSecret(n) then
        f.count:SetText(n)
        f.count:Show()
    else
        f.count:Hide()
    end
end

------------------------------------------------------------------------
-- Actualización
------------------------------------------------------------------------

local cooldownsDirty = true  -- llegó un aviso de cambio de cooldowns: se vuelven a pedir al juego
local texturesDirty = false  -- cambió el icono de algún hechizo

-- Mientras se configuran las barras se ve todo como lo deja Blizzard
local function Editing()
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
        return true
    end
    return CooldownViewerSettings ~= nil and CooldownViewerSettings:IsShown() == true
end

local function InCombat()
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    if type(inCombat) == "boolean" and not ns.IsSecret(inCombat) then return inCombat end
    return InCombatLockdown() == true
end

local function Flag(value)
    return PlainBool(value) and value
end

-- ¿Se ve la barra? Siempre, solo en combate, nunca, o como la de esenciales (su visibilidad se elige en el
-- modo de edición de Blizzard); y si se pide, no en montura o vehículo ni descansando
local function BarShown(db)
    if db.activeHideMounted and (Flag(IsMounted and IsMounted()) or Flag(UnitInVehicle and UnitInVehicle("player"))) then
        return false
    end
    if db.activeHideResting and Flag(IsResting and IsResting()) then return false end
    local mode = db.activeShow
    if mode == "always" then return true end
    if mode == "combat" then return InCombat() end
    if mode == "hidden" then return false end
    local anchor = _G.EssentialCooldownViewer
    return not anchor or Shown(anchor)
end


-- Dónde va la barra: sobre la de esenciales (se mueve con ella en el modo de edición) o libre en la pantalla,
-- más el desplazamiento elegido. Sin barra de esenciales, un poco por debajo del centro de la pantalla.
local function BarAnchor(db)
    local essential = _G.EssentialCooldownViewer
    if db.activeAnchor ~= "screen" and essential then return essential, 0 end
    return UIParent, db.activeAnchor ~= "screen" and -150 or 0
end

local placedKey
local function PlaceBar(db)
    local anchor, baseY = BarAnchor(db)
    local x, y = db.activeX or 0, (db.activeY or 0) + baseY
    local key = tostring(anchor) .. ":" .. x .. ":" .. y
    if key == placedKey and bar:GetNumPoints() > 0 then return end
    placedKey = key
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER", x, y)
end

local function ClampOffset(v)
    local limits = ns.LIMITS.activeX
    return math.max(limits[1], math.min(limits[2], math.floor(v + 0.5)))
end

-- Al cambiar de ancla, la barra se queda donde está: se recalcula su desplazamiento desde la nueva ancla
-- (si el juego no deja leer dónde están, se deja el desplazamiento como estaba)
function ns.SaveActivePosition()
    local db = ns.db
    if not db then return end
    local anchor, baseY = BarAnchor(db)
    local bx, by = bar:GetCenter()
    local ax, ay = anchor:GetCenter()
    bx, by, ax, ay = Plain(bx), Plain(by), Plain(ax), Plain(ay)
    if bx and by and ax and ay then
        local ratio = (Plain(anchor:GetEffectiveScale()) or 1) / (Plain(bar:GetEffectiveScale()) or 1)
        db.activeX = ClampOffset(bx - ax * ratio)
        db.activeY = ClampOffset(by - ay * ratio - baseY)
    end
    placedKey = nil
    if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Arrastrar: el desplazamiento guardado sigue al ratón y la barra se recoloca con él.
-- No se usa StartMoving ni se lee dónde está la barra: con la barra de esenciales como ancla,
-- el juego puede tener ese sitio en secreto y la barra volvería a su posición al soltarla.
local drag, pressX, pressY
local function DragUpdate()
    local db = ns.db
    if not (drag and db) then return end
    if not ns.activeUnlocked then
        -- Bloqueada en medio del arrastre (por ejemplo, al entrar en combate): se queda donde iba
        drag = nil
        bar.mover:SetScript("OnUpdate", nil)
        return
    end
    local x, y = GetCursorPosition()
    local scale = Plain(bar:GetEffectiveScale()) or 1
    db.activeX = ClampOffset(drag.offsetX + (x - drag.x) / scale)
    db.activeY = ClampOffset(drag.offsetY + (y - drag.y) / scale)
    PlaceBar(db)
end

local function StopDrag()
    if not drag then return end
    DragUpdate()
    drag = nil
    bar.mover:SetScript("OnUpdate", nil)
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.RequestActiveUpdate()
end

bar.mover:SetScript("OnDragStart", function(self)
    local db = ns.db
    if not (ns.activeUnlocked and db) then return end
    local x, y = GetCursorPosition()
    -- El arrastre empieza tras mover unos píxeles: se cuenta desde donde se pulsó el botón
    if pressX then x, y = pressX, pressY end
    pressX, pressY = nil, nil
    drag = { x = x, y = y, offsetX = db.activeX or 0, offsetY = db.activeY or 0 }
    self:SetScript("OnUpdate", DragUpdate)
end)
bar.mover:SetScript("OnMouseDown", function() pressX, pressY = GetCursorPosition() end)
bar.mover:SetScript("OnMouseUp", function() pressX, pressY = nil, nil end)
bar.mover:SetScript("OnDragStop", StopDrag)
bar.mover:SetScript("OnHide", StopDrag)

-- Buffs que Blizzard muestra como barra: en la línea solo se ve su icono, con el tiempo restante encima
local function Compact(item, on)
    local s = State(item)
    local barFrame = item.Bar
    local duration = barFrame and barFrame.Duration
    if on then
        if not s.compact then
            s.compact = true
            s.barMouse = item:IsMouseMotionEnabled() == true
            if barFrame then barFrame:SetAlpha(0) end
            if duration and item.Icon then
                s.durMoved = true
                duration:SetParent(item.Icon)
                duration:ClearAllPoints()
                duration:SetPoint("CENTER", item.Icon, "CENTER", 0, 0)
            end
        end
        -- La barra invisible sigue ocupando su sitio: sin ayuda al pasar el ratón por encima
        if item:IsMouseMotionEnabled() == true then item:SetMouseMotionEnabled(false) end
    elseif s.compact then
        s.compact = nil
        if barFrame then barFrame:SetAlpha(1) end
        if duration and s.durMoved then
            -- Su sitio de la plantilla de Blizzard (CooldownViewer.xml). No se leen sus anclas: con el tiempo
            -- secreto en combate también lo serían, y devolverlas daría error.
            s.durMoved = nil
            duration:SetParent(barFrame)
            duration:ClearAllPoints()
            duration:SetPoint("RIGHT", barFrame, "RIGHT", -8, 0)
        end
        item:SetMouseMotionEnabled(s.barMouse == true)
    end
end

-- Devuelve los buffs de Blizzard a su sitio (si se movieron)
local function RestoreBuff(item)
    local s = blizz[item]
    if not s then return end
    SetHidden(item, false)
    RestorePoints(item)
    RestoreScale(item)
    Compact(item, false)
end

local function RestoreAll()
    for item, s in pairs(blizz) do
        SetHidden(item, false)
        RestorePoints(item)
        RestoreScale(item)
        Compact(item, false)
        s.fitted = nil
    end
    for _, f in pairs(icons) do
        -- Al volver se pide todo de nuevo al juego (barrido, cargas y borde dorado)
        f.wasActive, f.lingerUntil, f.durationKind, f.style = nil, nil, nil, nil
        f.cd:Clear()
        f.flash:Hide()
        f:Hide()
    end
    bar:Hide()
    applied, lastLine, cooldownsDirty, layoutDirty = false, nil, true, true
end

-- ¿Muestra la barra de buffs solo el nombre (sin icono)? Entonces sus buffs no pueden ir en la línea
local function NameOnly(viewer)
    local content = Enum and Enum.CooldownViewerBarContent
    local value = Plain(viewer.barContent)
    return content ~= nil and value ~= nil and value == content.NameOnly
end

-- Un icono de buff de Blizzard al mismo tamaño que los de la barra (en las barras se mide su icono)
local function FitBuff(item, size, measure)
    local s = State(item)
    local width = Plain((measure or item):GetWidth())
    local scale, effective = Plain(item:GetScale()), Plain(item:GetEffectiveScale())
    if not (width and scale and effective) or width <= 0 or scale <= 0 then return end
    if not s.fitted then SaveScale(item) end
    local target = size * bar:GetEffectiveScale() / (width * effective / scale)
    if math.abs(scale - target) > 0.001 then item:SetScale(target) end
    s.fitted = target
end

-- Una línea centrada en la barra: primero los iconos propios y después los buffs de Blizzard.
-- Las cuentas se hacen en unidades de la barra; los buffs se colocan en sus propias unidades.
local function Arrange(line, db)
    local size, gap = db.activeSize, db.activeSpacing
    local barScale = bar:GetEffectiveScale()
    local widths, total = {}, 0
    for i, f in ipairs(line) do
        local width = size
        if f.isBlizzard then
            local measure = f.isBar and f.frame.Icon or f.frame
            FitBuff(f.frame, size, measure)
            local w, e = Plain(measure:GetWidth()), Plain(f.frame:GetEffectiveScale())
            if w and e then width = w * e / barScale end
        end
        widths[i] = width
        total = total + width + (i > 1 and gap or 0)
    end
    -- Desbloqueada y sin nada que mostrar, la barra tiene al menos el ancho de tres iconos para poder cogerla
    local minimum = ns.activeUnlocked and (3 * size + 2 * gap) or 1
    bar:SetSize(math.max(total, minimum), size)
    local x = -total / 2
    for i, f in ipairs(line) do
        local width = widths[i]
        local center = x + width / 2
        if f.isBlizzard then
            local item = f.frame
            local s = State(item)
            if not s.moved then SavePoints(item) end
            local e = Plain(item:GetEffectiveScale()) or 1
            item:ClearAllPoints()
            if f.isBar then
                -- El icono está a la izquierda de la barra de Blizzard: se coloca por ese borde
                item:SetPoint("LEFT", bar, "CENTER", x * barScale / e, 0)
            else
                item:SetPoint("CENTER", bar, "CENTER", center * barScale / e, 0)
            end
            s.moved = true
        else
            f:SetSize(size, size)
            f:ClearAllPoints()
            f:SetPoint("CENTER", bar, "CENTER", center, 0)
        end
        x = x + width + gap
    end
end

local function SameLine(a, b)
    if not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Envoltorios de los buffs de Blizzard en la línea (uno fijo por icono, para comparar líneas)
local buffSlots = setmetatable({}, { __mode = "k" })
local function BuffSlot(item, isBar)
    local slot = buffSlots[item]
    if not slot then
        slot = { isBlizzard = true, isBar = isBar, frame = item }
        buffSlots[item] = slot
    end
    return slot
end

-- ¿Está activo un buff? Blizzard lo guarda en isActive (casi nunca secreto). Si lo fuera: con "Ocultar si está
-- inactivo" Blizzard solo muestra los activos; si no, se usa el último dato que se pudo leer.
local function BuffActive(item, viewer)
    local s = State(item)
    local active = item.isActive
    if PlainBool(active) then
        s.active = active
        return active
    end
    if viewer.hideWhenInactive == true then return Shown(item) end
    return s.active == true
end

-- Todos los rangos de cada hechizo elegido (en Forever cada rango es otro hechizo con el mismo nombre):
-- el icono sale en cooldown se lance el rango que se lance
local function AttachRanks(list)
    local byID, byName = {}, {}
    local ok, book = pcall(ns.GetSpellbookSpells)
    for _, sp in ipairs(ok and book or {}) do
        for _, id in ipairs(sp.ranks or { sp.spellID }) do byID[id] = sp.ranks end
        byName[sp.name] = sp.ranks
    end
    for _, entry in ipairs(list) do
        if entry.spell then
            entry.ranks = byID[entry.spell] or byName[SpellName(entry.spell)] or { entry.spell }
        end
    end
end

local CaptureGCD -- más abajo: anota qué cooldowns son reales y cuáles solo el GCD

local function RebuildEntries()
    RebuildPetSlots()
    ReadCDMSpells()
    entries = BuildEntries()
    AttachRanks(entries)
    local used = {}
    for _, entry in ipairs(entries) do
        local f = GetIcon(entry)
        used[f] = true
        if entry.spell then f.spellID = Resolve(entry.spell) end
        UpdateTexture(f)
        StyleIcon(f, ns.db)
        UpdateKeybind(f, ns.db)
    end
    for _, f in pairs(icons) do
        if not used[f] then
            f.entry, f.wasActive, f.lingerUntil, f.durationKind, f.style = nil, nil, nil, nil, nil
            f.cd:Clear()
            f.flash:Hide()
            f:Hide()
        end
    end
    entriesDirty, cooldownsDirty, lastLine = false, true, nil
    -- Hechizos nuevos en la barra (al entrar al juego o al elegirlos) que ya estaban en cooldown: se anotan ya,
    -- sin esperar al siguiente aviso del juego. Solo los que nunca se anotaron, para no fiarse de un GCD a medias.
    pcall(CaptureGCD, true)
end

-- Vista previa: todos los iconos elegidos como si estuvieran en cooldown (botón "Probar" o barra desbloqueada)
local previewUntil, previewStart, wasPreview = 0, 0, false

local function Previewing(now)
    return ns.activeUnlocked == true or now < previewUntil
end

local function Update()
    local db = ns.db
    local now = GetTime()
    local preview = db ~= nil and Previewing(now)
    if not db or not (db.activeOnly or preview) or Editing() then
        if applied then RestoreAll() end
        wasPreview = false
        return
    end
    applied = true
    if entriesDirty then RebuildEntries() end
    if wasPreview and not preview then cooldownsDirty = true end -- se vuelve a pedir el estado real al juego
    wasPreview = preview

    -- Esenciales y utilidad de Blizzard: ocultos, la barra los sustituye
    for _, name in ipairs(COOLDOWN_VIEWERS) do
        for _, item in ipairs(ViewerItems(_G[name])) do SetHidden(item, true) end
    end

    local buffViewer, barViewer = _G[BUFF_VIEWER], _G[BUFF_BAR_VIEWER]
    if not (preview or BarShown(db)) then
        -- La barra no se ve ahora (por ejemplo, fuera de combate): los buffs vuelven a su sitio
        for _, item in ipairs(ViewerItems(buffViewer)) do RestoreBuff(item) end
        for _, item in ipairs(ViewerItems(barViewer)) do RestoreBuff(item) end
        -- Lo que termine sin verse no se anuncia al volver (ni destello ni sonido de algo que acabó hace rato)
        for _, f in pairs(icons) do
            f.wasActive, f.lingerUntil = nil, nil
            f.flash:Hide()
        end
        bar:Hide()
        lastLine = nil
        return
    end
    PlaceBar(db)
    -- La misma opacidad que la barra de esenciales (se elige en el modo de edición)
    local essential = _G.EssentialCooldownViewer
    bar:SetAlpha(essential and Plain(essential:GetAlpha()) or 1)
    local unlocked = ns.activeUnlocked == true
    bar.label:SetText(L["Ruscuu: drag the bar"])
    bar.mover:SetShown(unlocked)
    bar:Show()
    -- Desbloqueada, la vista previa se repite para que siempre se vean los iconos girando
    if unlocked and now - previewStart > PREVIEW_LENGTH then
        previewStart = now
        for _, f in pairs(icons) do f.style = nil end
    end

    local refresh, textures = cooldownsDirty, texturesDirty
    cooldownsDirty, texturesDirty = false, false
    local line = {}
    for _, entry in ipairs(entries) do
        local f = icons[entry.key]
        if preview then
            if textures then UpdateTexture(f) end
            if f.style ~= "preview" then
                f.style = "preview"
                f.cd:SetCooldown(previewStart, PREVIEW_LENGTH) -- números propios, no del juego
                f.durationKind = nil
                f.cd:SetDrawSwipe(db.showSwipe)
                f.icon:SetDesaturated(false)
                f.count:Hide()
            end
            f.wasActive, f.lingerUntil = nil, nil
            f:Show()
            line[#line + 1] = f
        else
            local active, a, b, c
            if entry.spell then
                -- El rango que esté en cooldown (o el elegido, si ninguno lo está)
                local id = Resolve(entry.spell)
                active, a, b, c = SpellState(id)
                if active ~= true then
                    for _, rank in ipairs(entry.ranks or {}) do
                        local rid = Resolve(rank)
                        if rid ~= id then
                            local ra, r1, r2, r3 = SpellState(rid)
                            if ra == true then
                                id, active, a, b, c = rid, ra, r1, r2, r3
                                break
                            end
                        end
                    end
                end
                if id ~= f.spellID then
                    f.spellID = id
                    textures = true
                    f.style = nil
                end
            elseif entry.slot then
                active, a, b = SlotState(entry.slot)
            else
                active, a, b = ItemState(entry.item)
            end
            if textures then UpdateTexture(f) end
            local known = active ~= nil
            if not known then active = true end -- sin datos se muestra, como haría Blizzard

            -- Estado nuevo: se vuelve a pedir el cooldown al juego
            local style = tostring(active) .. tostring(a) .. tostring(b) .. tostring(c)
            if refresh or style ~= f.style then
                f.style = style
                if entry.spell then
                    ApplySpellCooldown(f, db, known and active, a, b, c)
                else
                    ApplySlotCooldown(f, db, known and active, a, b)
                end
            end

            if active and not f.wasActive then f.activeSince = now end
            -- Acaba de terminar (tras más que un GCD): un momento visible con destello, y sonido si se eligió
            if f.wasActive and not active and now - (f.activeSince or now) >= MIN_FLASH then
                if db.activeFlash then f.lingerUntil = now + LINGER end
                if db.activeSound[entry.key] then ns.PlayActiveSound(db.activeSoundChoice) end
            end
            f.wasActive = active
            if f.lingerUntil and (now >= f.lingerUntil or active) then f.lingerUntil = nil end
            local show = active or f.lingerUntil ~= nil
            f:SetShown(show)
            if show then line[#line + 1] = f end
        end
    end

    -- Buffs del Cooldown Manager (iconos) en la misma línea, después de los cooldowns
    local buffsOn = db.activeBuffs and buffViewer ~= nil and Shown(buffViewer)
    for _, item in ipairs(ViewerItems(buffViewer)) do
        if buffsOn and BuffActive(item, buffViewer) then
            SetHidden(item, false)
            line[#line + 1] = BuffSlot(item)
        elseif buffsOn then
            SetHidden(item, true)
        else
            RestoreBuff(item)
        end
    end
    -- Buffs que Blizzard muestra como barras: en la línea como icono, con el tiempo restante encima
    local barsOn = db.activeBuffs and db.activeBuffBars and barViewer ~= nil and Shown(barViewer) and not NameOnly(barViewer)
    for _, item in ipairs(ViewerItems(barViewer)) do
        if barsOn and item.Icon and BuffActive(item, barViewer) then
            SetHidden(item, false)
            Compact(item, true)
            line[#line + 1] = BuffSlot(item, true)
        elseif barsOn and item.Icon then
            SetHidden(item, true)
        else
            RestoreBuff(item)
        end
    end

    if layoutDirty or not SameLine(line, lastLine) then
        layoutDirty = false
        lastLine = line
        Arrange(line, db)
    end
end

-- Un error no debe repetirse en cada revisión: se avisa una vez en el chat y se sigue
local function SafeUpdate()
    local ok, err = pcall(Update)
    if not ok then ns.ReportError(err) end
end

local function UpdateFlashes(now)
    for _, f in pairs(icons) do
        if f.lingerUntil and now < f.lingerUntil then
            f.flash:SetAlpha(0.8 * (f.lingerUntil - now) / LINGER)
            f.flash:Show()
        elseif f.flash:IsShown() then
            f.flash:Hide()
        end
    end
end

local driver = CreateFrame("Frame")
local sinceUpdate = 0

-- Revisa en el siguiente fotograma
function ns.RequestActiveUpdate()
    sinceUpdate = EVAL_INTERVAL
end
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate >= EVAL_INTERVAL then
        sinceUpdate = 0
        SafeUpdate()
    end
    UpdateFlashes(GetTime())
end)

-- isOnGCD solo es fiable al recibir el aviso de cambio de cooldowns: se anota en ese momento
function CaptureGCD(onlyNew)
    local ids = {}
    for _, entry in ipairs(entries) do
        for _, rank in ipairs(entry.ranks or { entry.spell }) do
            local id = Resolve(rank)
            if not (onlyNew and onGCD[id] ~= nil) then ids[#ids + 1] = id end
        end
    end
    for _, id in ipairs(ids) do
        local ok, info = GetCooldown(id)
        local active = ok and type(info) == "table" and PlainBool(info.isActive) and info.isActive
        onGCD[id] = ok and type(info) == "table" and PlainBool(info.isOnGCD) and info.isOnGCD or false
        if not active then
            latched[id] = nil
        elseif not onGCD[id] then
            latched[id] = true
        end
    end
end

local events = CreateFrame("Frame")
local COOLDOWN_EVENTS = { SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_CHARGES = true, SPELL_UPDATE_ICON = true,
    ACTIONBAR_UPDATE_COOLDOWN = true, BAG_UPDATE_COOLDOWN = true, BAG_UPDATE_DELAYED = true,
    PLAYER_ENTERING_WORLD = true, PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true,
    PLAYER_MOUNT_DISPLAY_CHANGED = true, PLAYER_UPDATE_RESTING = true }
local LIST_EVENTS = { SPELLS_CHANGED = true, PLAYER_EQUIPMENT_CHANGED = true, PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true, UNIT_PET = true, PET_BAR_UPDATE = true,
    GET_ITEM_INFO_RECEIVED = true }
for event in pairs(COOLDOWN_EVENTS) do pcall(events.RegisterEvent, events, event) end
for event in pairs(LIST_EVENTS) do
    if event == "UNIT_PET" then
        pcall(events.RegisterUnitEvent, events, event, "player") -- solo la mascota del jugador
    else
        pcall(events.RegisterEvent, events, event)
    end
end
events:SetScript("OnEvent", function(_, event, itemID)
    if LIST_EVENTS[event] then
        entriesDirty = true
    elseif event == "SPELL_UPDATE_ICON" then
        texturesDirty = true
    else
        cooldownsDirty = true
    end
    -- Se anota siempre, aunque la barra esté desactivada: así, al activarla, los cooldowns ya en marcha salen
    if event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_ENTERING_WORLD" then pcall(CaptureGCD) end
    -- Al entrar en combate la barra deja de estar desbloqueada (la vista previa taparía los cooldowns reales)
    if event == "PLAYER_REGEN_DISABLED" and ns.activeUnlocked then
        ns.SetActiveUnlocked(false)
        if ns.RefreshOptions then ns.RefreshOptions() end
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not (ns.db and ns.db.activeItems[itemID]) then return end
        if ns.RefreshOptions then ns.RefreshOptions() end -- el nombre del objeto ya está
    end
    if not (ns.db and ns.db.activeOnly) then return end
    SafeUpdate()
end)

-- Cuando Blizzard vuelve a colocar sus iconos: se relee la lista de hechizos, se guardan las posiciones de
-- los buffs y se rehace la línea al momento
function ns.HookActiveViewer(viewer)
    if type(viewer.Layout) ~= "function" then return end
    local isBuffs = _G[BUFF_VIEWER] == viewer or _G[BUFF_BAR_VIEWER] == viewer
    local known = isBuffs
    for _, name in ipairs(COOLDOWN_VIEWERS) do
        if _G[name] == viewer then known = true end
    end
    if not known then return end
    hooksecurefunc(viewer, "Layout", function()
        -- Con la barra oculta Blizzard no coloca nada: las posiciones actuales son las del addon
        if isBuffs and viewer:IsShown() == true then
            for _, item in ipairs(ns.GetViewerItems(viewer)) do
                SavePoints(item)
                SaveScale(item)
            end
        elseif not isBuffs then
            entriesDirty = true
        end
        lastLine = nil
        SafeUpdate()
    end)
    -- Blizzard cambia qué hechizo muestra cada icono sin recolocarlos si su número no cambia
    if not isBuffs and type(viewer.RefreshData) == "function" then
        hooksecurefunc(viewer, "RefreshData", function() entriesDirty = true end)
    end
end

-- Se llama al cambiar las opciones (y al cambiar de perfil): estilo, tamaño y lista de hechizos
function ns.RefreshActiveBar()
    entriesDirty, layoutDirty = true, true
    SafeUpdate()
end

-- Las teclas cambiaron (ActionBars.lua)
function ns.RefreshActiveKeybinds()
    if not ns.db then return end
    for _, f in pairs(icons) do
        if f.entry then UpdateKeybind(f, ns.db) end
    end
end

-- Para /rcm debug: si el juego da el dato isActive (nil si todavía no se ha usado el modo)
function ns.ActiveCooldownAPI()
    return apiState
end

-- Para /rcm debug y las pruebas
function ns.GetActiveBar() return bar end
function ns.GetActiveIcon(key) return icons[key] end
function ns.CountActiveEntries() return #entries end

-- Para las pruebas: el destello de un icono de la barra (o nil)
function ns.GetActiveFlash(key)
    local f = icons[key]
    return f and f.flash
end

-- Nombre de una entrada para la lista de opciones
function ns.TrinketLabel(i)
    return L["Trinket %d"]:format(i)
end

-- Botón "Probar": la barra se llena con los iconos elegidos durante unos segundos. Devuelve false si no hay nada
function ns.PreviewActiveBar(seconds)
    if not ns.db then return false end
    ReadCDMSpells()
    if #BuildEntries() == 0 then return false end
    previewStart = GetTime()
    previewUntil = previewStart + (seconds or PREVIEW_LENGTH)
    entriesDirty, layoutDirty = true, true
    for _, f in pairs(icons) do f.style = nil end
    SafeUpdate()
    return true
end

-- Desbloquear para arrastrar la barra con el ratón (no se guarda: al recargar vuelve a estar bloqueada)
function ns.SetActiveUnlocked(on)
    ns.activeUnlocked = on and true or nil
    if on then previewStart = 0 end
    entriesDirty, layoutDirty = true, true
    SafeUpdate()
end

-- Lo que hay en la barra, en su orden (para la página de orden y sonido)
function ns.GetActiveEntryList()
    local list = {}
    if not ns.db then return list end
    ReadCDMSpells()
    for _, e in ipairs(BuildEntries()) do
        local name, icon, ok, tex
        if e.spell then
            name = SpellName(e.spell)
            ok, tex = pcall(C_Spell.GetSpellTexture, e.spell)
        elseif e.slot then
            for i, slot in ipairs(ns.TRINKET_SLOTS) do
                if slot == e.slot then name = ns.TrinketLabel(i) end
            end
            ok, tex = pcall(GetInventoryItemTexture, "player", e.slot)
        else
            name = ItemName(e.item)
            ok, tex = true, ns.ActiveItemIcon(e.item)
        end
        if ok and not ns.IsSecret(tex) then icon = tex end
        list[#list + 1] = { key = e.key, name = name or e.key, icon = icon }
    end
    return list
end

-- Sube (delta -1) o baja (delta 1) un icono en la barra. Devuelve false si ya estaba en el borde.
function ns.MoveActiveEntry(key, delta)
    local list = ns.GetActiveEntryList()
    local index
    for i, e in ipairs(list) do
        if e.key == key then index = i end
    end
    local target = index and index + delta
    if not target or target < 1 or target > #list then return false end
    list[index], list[target] = list[target], list[index]
    local order, present = {}, {}
    for i, e in ipairs(list) do
        order[i] = e.key
        present[e.key] = true
    end
    -- Lo que ahora no está en la barra (un abalorio desmarcado, hechizos de otra especialización) conserva su sitio
    for _, saved in ipairs(ns.db.activeOrder) do
        if type(saved) == "string" and not present[saved] then
            order[#order + 1] = saved
            present[saved] = true
        end
    end
    ns.db.activeOrder = order
    ns.RefreshActiveBar()
    return true
end
