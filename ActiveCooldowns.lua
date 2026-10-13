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
local EVAL_INTERVAL = 0.1    -- cada cuánto se revisa qué cooldowns están activos
local COOLDOWN_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
local BUFF_VIEWER = "BuffIconCooldownViewer"
ns.TRINKET_SLOTS = { 13, 14 }

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
    local function add(info, spellID)
        if not info or info.isPassive or info.isOffSpec or type(spellID) ~= "number" or seen[spellID] then return end
        seen[spellID] = true
        list[#list + 1] = { spellID = spellID, name = info.name or SpellName(spellID), icon = info.iconID }
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

-- Lo que muestra la barra, en orden: hechizos del Cooldown Manager, los añadidos (por nombre) y los abalorios
local function BuildEntries()
    local db = ns.db
    local entries, seen = {}, {}
    local function addSpell(id)
        if seen[id] then return end
        seen[id] = true
        entries[#entries + 1] = { key = "spell" .. id, spell = id }
    end
    if db.activeCDM then
        for _, id in ipairs(cdmSpells) do
            if not db.activeRemove[id] then addSpell(id) end
        end
    end
    local extras = {}
    for id, on in pairs(db.activeAdd) do
        if on and type(id) == "number" and not seen[id] then extras[#extras + 1] = { id = id, name = SpellName(id) } end
    end
    table.sort(extras, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for _, e in ipairs(extras) do addSpell(e.id) end
    for i, slot in ipairs(ns.TRINKET_SLOTS) do
        if db["activeTrinket" .. i] then entries[#entries + 1] = { key = "slot" .. slot, slot = slot } end
    end
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
    local empty = info.isActive and (latched[id] or not onGCD[id])
    local okc, charges = GetCharges(id)
    local max = okc and type(charges) == "table" and charges.maxCharges
    local isCharge = type(max) == "number" and not ns.IsSecret(max) and max > 1
    -- Con cargas: se ve mientras recarga alguna (el juego dice cuándo, aunque no cuántas quedan)
    local recharging = isCharge and PlainBool(charges.isActive) and charges.isActive or false
    return empty or recharging, empty, recharging, isCharge
end

-- Abalorios: el juego no oculta su cooldown, pero por si acaso se comprueba
local function SlotState(slot)
    if not GetInventoryItemCooldown then return false end
    local ok, start, duration, enable = pcall(GetInventoryItemCooldown, "player", slot)
    if not ok or ns.IsSecret(start) or ns.IsSecret(duration) or ns.IsSecret(enable) then return nil end
    if type(start) ~= "number" or type(duration) ~= "number" then return false end
    local active = (enable == 1 or enable == true) and start > 0 and duration > 1.5 and start + duration > GetTime()
    return active, start, duration
end

------------------------------------------------------------------------
-- La barra propia y sus iconos
------------------------------------------------------------------------

local bar = CreateFrame("Frame", "RuscuuCDMActiveBar", UIParent)
bar:SetSize(1, 1)
bar:SetFrameStrata("MEDIUM")
bar:Hide()

local icons = {}             -- clave ("spell123", "slot13") -> icono
local entries = {}           -- lo que se muestra, en orden
local lastLine               -- iconos de la última línea colocada, para no recolocar si no cambia
local layoutDirty = true     -- tamaño o separación cambiados: hay que recolocar

local function ShowTooltip(f)
    if not f.entry then return end
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    if f.entry.slot then
        GameTooltip:SetInventoryItem("player", f.entry.slot)
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
    f.count:Hide()
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

-- La barra se ve cuando se vería la de esenciales (su visibilidad se elige en el modo de edición)
local function AnchorShown()
    local anchor = _G.EssentialCooldownViewer
    return not anchor or Shown(anchor)
end

local function RestoreAll()
    for item, s in pairs(blizz) do
        SetHidden(item, false)
        RestorePoints(item)
        RestoreScale(item)
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

-- En el centro de la barra de esenciales (se mueve con ella en el modo de edición)
local placedOn
local function PlaceBar()
    local anchor = _G.EssentialCooldownViewer
    if anchor == placedOn and bar:GetNumPoints() > 0 then return end
    placedOn = anchor
    bar:ClearAllPoints()
    if anchor then
        bar:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    end
end

-- Devuelve los buffs de Blizzard a su sitio (si se movieron)
local function RestoreBuff(item)
    local s = blizz[item]
    if not s then return end
    SetHidden(item, false)
    RestorePoints(item)
    RestoreScale(item)
end

-- Un icono de buff de Blizzard al mismo tamaño que los de la barra
local function FitBuff(item, size)
    local s = State(item)
    local width, scale, effective = Plain(item:GetWidth()), Plain(item:GetScale()), Plain(item:GetEffectiveScale())
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
            FitBuff(f.frame, size)
            local w, e = Plain(f.frame:GetWidth()), Plain(f.frame:GetEffectiveScale())
            if w and e then width = w * e / barScale end
        end
        widths[i] = width
        total = total + width + (i > 1 and gap or 0)
    end
    bar:SetSize(math.max(total, 1), size)
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
            item:SetPoint("CENTER", bar, "CENTER", center * barScale / e, 0)
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
local function BuffSlot(item)
    local slot = buffSlots[item]
    if not slot then
        slot = { isBlizzard = true, frame = item }
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

local function RebuildEntries()
    RebuildPetSlots()
    ReadCDMSpells()
    entries = BuildEntries()
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
end

local function Update()
    local db = ns.db
    if not db or not db.activeOnly or Editing() then
        if applied then RestoreAll() end
        return
    end
    applied = true
    if entriesDirty then RebuildEntries() end

    -- Esenciales y utilidad de Blizzard: ocultos, la barra los sustituye
    for _, name in ipairs(COOLDOWN_VIEWERS) do
        for _, item in ipairs(ViewerItems(_G[name])) do SetHidden(item, true) end
    end

    local buffViewer = _G[BUFF_VIEWER]
    if not AnchorShown() then
        -- La barra de esenciales está oculta (por ejemplo, "solo en combate"): los buffs vuelven a su sitio
        for _, item in ipairs(ViewerItems(buffViewer)) do RestoreBuff(item) end
        bar:Hide()
        lastLine = nil
        return
    end
    PlaceBar()
    -- La misma opacidad que la barra de esenciales (se elige en el modo de edición)
    local anchor = _G.EssentialCooldownViewer
    bar:SetAlpha(anchor and Plain(anchor:GetAlpha()) or 1)
    bar:Show()

    local now = GetTime()
    local refresh, textures = cooldownsDirty, texturesDirty
    cooldownsDirty, texturesDirty = false, false
    local line = {}
    for _, entry in ipairs(entries) do
        local f = icons[entry.key]
        local active, a, b, c
        if entry.spell then
            local id = Resolve(entry.spell)
            if id ~= f.spellID then
                f.spellID = id
                textures = true
                f.style = nil
            end
            active, a, b, c = SpellState(id)
        else
            active, a, b = SlotState(entry.slot)
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

        if f.wasActive and not active and db.activeFlash then
            f.lingerUntil = now + LINGER -- acaba de terminar: un momento visible con destello
        end
        f.wasActive = active
        if f.lingerUntil and (now >= f.lingerUntil or active) then f.lingerUntil = nil end
        local show = active or f.lingerUntil ~= nil
        f:SetShown(show)
        if show then line[#line + 1] = f end
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
local function CaptureGCD()
    for _, entry in ipairs(entries) do
        local f = icons[entry.key]
        local id = entry.spell and f and f.spellID
        if id then
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
end

local events = CreateFrame("Frame")
local COOLDOWN_EVENTS = { SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_CHARGES = true, SPELL_UPDATE_ICON = true,
    ACTIONBAR_UPDATE_COOLDOWN = true, BAG_UPDATE_COOLDOWN = true, PLAYER_ENTERING_WORLD = true }
local LIST_EVENTS = { SPELLS_CHANGED = true, PLAYER_EQUIPMENT_CHANGED = true, PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true, UNIT_PET = true, PET_BAR_UPDATE = true }
for event in pairs(COOLDOWN_EVENTS) do pcall(events.RegisterEvent, events, event) end
for event in pairs(LIST_EVENTS) do
    if event == "UNIT_PET" then
        pcall(events.RegisterUnitEvent, events, event, "player") -- solo la mascota del jugador
    else
        pcall(events.RegisterEvent, events, event)
    end
end
events:SetScript("OnEvent", function(_, event)
    if LIST_EVENTS[event] then
        entriesDirty = true
    elseif event == "SPELL_UPDATE_ICON" then
        texturesDirty = true
    else
        cooldownsDirty = true
    end
    if not (ns.db and ns.db.activeOnly) then return end
    if event == "SPELL_UPDATE_COOLDOWN" then pcall(CaptureGCD) end
    SafeUpdate()
end)

-- Cuando Blizzard vuelve a colocar sus iconos: se relee la lista de hechizos, se guardan las posiciones de
-- los buffs y se rehace la línea al momento
function ns.HookActiveViewer(viewer)
    if type(viewer.Layout) ~= "function" then return end
    local isBuffs = _G[BUFF_VIEWER] == viewer
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
