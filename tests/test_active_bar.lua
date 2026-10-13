-- Barra de "solo cooldowns activos": iconos propios para los hechizos elegidos que están en cooldown (no el GCD),
-- centrados donde está la barra de esenciales, con cargas, abalorios, buffs del Cooldown Manager en la misma
-- línea y un segundo con destello al terminar. Los iconos de esenciales y utilidad de Blizzard se ocultan.
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local Duration = M.InstallCurves()

local SECRET = { __secret = true }

-- Cooldowns simulados: isActive, isOnGCD, maxCharges y el isActive de las cargas nunca son secretos en el juego;
-- el resto (cargas actuales, tiempos) sí, y el addon no debe mirarlos
local spells = {}
for _, id in ipairs({ 1, 2, 3, 4, 5, 22, 50 }) do spells[id] = { active = false, gcd = false } end
local overrides = {}
-- Cooldowns con 2 s restantes: el borde dorado (3 s por defecto) se enciende
local function duration(id)
    local d = Duration(2)
    d.spell = id
    return d
end
local chargeDurations = {}
C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetOverrideSpell = function(id) return overrides[id] or id end,
    GetSpellName = function(id) if spells[id] then return "Hechizo " .. id end end,
    GetSpellInfo = function(name)
        local id = tonumber(tostring(name):match("^Hechizo (%d+)$"))
        if id and spells[id] then return { spellID = id } end
    end,
    -- Como el juego: con el hechizo base da el icono del que lo sustituye ahora
    GetSpellTexture = function(id) return 1000 + (overrides[id] or id) end,
    GetSpellCooldown = function(id)
        local s = spells[id]
        if not s then return nil end
        return { isActive = s.active, isOnGCD = s.gcd, isEnabled = true, startTime = SECRET, duration = SECRET }
    end,
    GetSpellCooldownDuration = function(id, ignoreGCD)
        assert(ignoreGCD == true, "el cooldown se pide sin el GCD")
        if spells[id] and spells[id].active then return duration(id) end
    end,
    GetSpellCharges = function(id)
        local s = spells[id]
        if not (s and s.max) then return nil end
        return { maxCharges = s.max, isActive = s.recharging, currentCharges = SECRET, cooldownStartTime = SECRET,
            cooldownDuration = SECRET, chargeModRate = SECRET }
    end,
    GetSpellChargeDuration = function(id)
        chargeDurations[id] = chargeDurations[id] or { charge = id }
        return chargeDurations[id]
    end,
    GetSpellDisplayCount = function() return SECRET end,
}
local trinket = { start = 0, duration = 0, enable = 1 }
GetInventoryItemCooldown = function(_, slot)
    if slot == 13 then return trinket.start, trinket.duration, trinket.enable end
    return 0, 0, 1
end
GetInventoryItemTexture = function(_, slot) return 2000 + slot end
GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip")
-- Objetos (pociones, piedras de salud): su cooldown no es secreto
local itemCooldown = { start = 0, duration = 0, enable = 1 }
C_Container = { GetItemCooldown = function() return itemCooldown.start, itemCooldown.duration, itemCooldown.enable end }
C_Item = {
    GetItemNameByID = function(id) return "Objeto " .. id end,
    GetItemIconByID = function(id) return 4000 + id end,
    GetItemCount = function() return 2 end,
}
-- Sonidos que suenan
local played = {}
SOUNDKIT = { READY_CHECK = 8960 }
PlaySound = function(kit) played[#played + 1] = kit end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua", "ActiveCooldowns.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.RebuildExpireCurve()
ns.GetSpellHotkey = function(id) if id == 2 then return "Q" end end

-- Barras de Blizzard: esenciales, utilidad (iconos al 75 %) y buffs (iconos)
local function viewer(name, scale)
    local v = M.CreateFrame("Frame", name)
    -- Como Blizzard: coloca los iconos en fila desde la izquierda (si la barra está oculta, no hace nada)
    function v:Layout()
        if not self:IsShown() then return end
        for _, item in ipairs(self._children) do
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", self, "TOPLEFT", (item.layoutIndex - 1) * 44, 0)
        end
    end
    v.itemScale = scale
    return v
end
local essential = viewer("EssentialCooldownViewer", 1)
local utility = viewer("UtilityCooldownViewer", 0.75)
local buffs = viewer("BuffIconCooldownViewer", 1)
local function item(v, index, spellID)
    local it = M.CreateFrame("Frame", nil, v)
    it.layoutIndex = index
    it._width, it._height = 40, 40
    it:SetScale(v.itemScale)
    it.Icon = it:CreateTexture()
    it.Cooldown = M.CreateFrame("Cooldown", nil, it)
    it.GetBaseSpellID = function() return spellID end
    return it
end
local e1, e2, e3 = item(essential, 1, 1), item(essential, 2, 2), item(essential, 3, 3)
local u1, u2 = item(utility, 1, 4), item(utility, 2, 5)
local b1, b2 = item(buffs, 1, 900), item(buffs, 2, 901)
b1.isActive, b2.isActive = false, false
-- Buffs como barras: un icono de 30 a la izquierda y la barra (con el tiempo restante) a su derecha
local barsViewer = viewer("BuffBarCooldownViewer", 1)
local bb = M.CreateFrame("Frame", nil, barsViewer)
bb.layoutIndex, bb._width, bb._height, bb.isActive = 1, 220, 30, false
bb.Icon = M.CreateFrame("Frame", nil, bb); bb.Icon._width, bb.Icon._height = 30, 30
bb.Bar = M.CreateFrame("StatusBar", nil, bb)
bb.Bar.Duration = bb.Bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
bb.Bar.Duration:SetPoint("RIGHT", bb.Bar, "RIGHT", -8, 0)
bb:SetMouseMotionEnabled(true)
essential:Layout(); utility:Layout(); buffs:Layout(); barsViewer:Layout()
ns.HookViewers()

local bar = ns.GetActiveBar()
local function icon(key) return ns.GetActiveIcon(key) end
local function blizzardShown(it) return it:GetAlpha() > 0 end
local function x(frame)
    local point, rel, relPoint, ox, oy = frame:GetPoint(1)
    assert(point == "CENTER" and rel == bar and relPoint == "CENTER" and oy == 0,
        "en el centro de la barra: " .. tostring(point) .. " " .. tostring(relPoint))
    return ox
end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function update()
    M.FireEvent("SPELL_UPDATE_COOLDOWN")
    M.Tick(0.2)
end
local function shownKeys()
    local list = {}
    for _, key in ipairs({ "spell1", "spell2", "spell3", "spell4", "spell5", "spell50", "slot13" }) do
        local f = icon(key)
        if f and f:IsShown() then list[#list + 1] = key end
    end
    return table.concat(list, " ")
end

-- Desactivado (por defecto): no se toca nada
spells[2].active = true
update()
assert(not bar:IsShown(), "desactivado: sin barra")
assert(blizzardShown(e1) and blizzardShown(u2), "desactivado: Blizzard visible")

-- Activado: e2 y u1 (hechizo 4) en cooldown real, e1 solo en el GCD
ns.db.activeOnly = true
ns.RefreshActiveBar()
spells[1] = { active = true, gcd = true }
spells[4].active = true
update()
assert(bar:IsShown(), "activado: la barra se ve")
assert(bar:GetPoint(1) == "CENTER" and select(2, bar:GetPoint(1)) == essential, "la barra va en el centro de esenciales")
essential:SetAlpha(0.6); M.Tick(0.2)
assert(bar:GetAlpha() == 0.6, "con la opacidad de la barra de esenciales")
essential:SetAlpha(1); M.Tick(0.2)
for _, it in ipairs({ e1, e2, e3, u1, u2 }) do
    assert(not blizzardShown(it) and not it:IsMouseMotionEnabled(), "los iconos de Blizzard se ocultan")
end
assert(shownKeys() == "spell2 spell4", "solo los cooldowns activos, sin el GCD: " .. shownKeys())
-- Línea centrada: dos iconos de 40 con 4 de separación -> 84 de ancho
assert(near(x(icon("spell2")), -22) and near(x(icon("spell4")), 22), "centrados: " .. x(icon("spell2")))
local f2 = icon("spell2")
assert(f2.cd._cooldown and f2.cd._cooldown.duration.spell == 2, "el barrido usa el DurationObject del juego")
assert(f2.icon:IsDesaturated() and f2.cd._swipe == true, "en cooldown: gris y con barrido")
assert(f2.icon._texture == 1002, "icono del hechizo")
assert(f2.keyLabel:GetText() == "Q" and f2.keyLabel:IsShown(), "con su tecla")
assert(not f2.count:IsShown(), "sin cargas no hay número")
M.Tick(0.2)
assert(M.ExpireBorder(f2), "borde dorado en la barra cuando el cooldown termina")
ns.db.expireExclude[2] = true
ns.RefreshActiveBar(); M.Tick(0.2)
assert(not M.ExpireBorder(f2), "sin borde dorado si el hechizo está excluido")
ns.db.expireExclude[2] = nil
ns.RefreshActiveBar(); M.Tick(0.2)
assert(M.ExpireBorder(f2), "el borde vuelve al incluirlo")

-- Al lanzar algo, todos los hechizos pasan un instante a "en cooldown" (el GCD) antes del aviso del juego:
-- no deben salir, ni con el aviso (isOnGCD), ni despedirse con destello al terminar el GCD
spells[5] = { active = true, gcd = false }
M.Tick(0.2)
assert(not icon("spell5"):IsShown(), "antes del aviso del juego no sale ningún hechizo nuevo")
spells[5].gcd = true
update()
assert(not icon("spell5"):IsShown(), "con el aviso: es el GCD, no sale")
spells[5] = { active = false, gcd = false }
update()
assert(not icon("spell5"):IsShown() and not ns.GetActiveFlash("spell5"):IsShown(), "sin destello al terminar el GCD")
-- Un cooldown real muy corto (menos que un GCD) sale, pero se va sin destello
spells[5] = { active = true, gcd = false }
update()
assert(icon("spell5"):IsShown(), "un cooldown real confirmado sale")
spells[5].active = false
update()
assert(not icon("spell5"):IsShown() and not ns.GetActiveFlash("spell5"):IsShown(), "corto: se va sin destello")

-- A un cooldown real le queda menos que un GCD que empieza: el juego lo marca como GCD, pero no se oculta
spells[4].gcd = true
update()
assert(icon("spell4"):IsShown() and not ns.GetActiveFlash("spell4"):IsShown(),
    "un cooldown real visto antes no se oculta (ni se despide) por el GCD")
spells[4].gcd = false

-- Tamaño y separación elegidos
ns.db.activeSize, ns.db.activeSpacing = 50, 10
ns.RefreshActiveBar()
assert(near(x(icon("spell2")), -30) and near(x(icon("spell4")), 30), "con el tamaño y la separación nuevos")
assert(icon("spell2"):GetWidth() == 50, "iconos de 50")
ns.db.activeSize, ns.db.activeSpacing = 40, 4
ns.RefreshActiveBar()

-- Termina el cooldown de e2 (tras más de un GCD visible): un segundo visible con destello y después se va
M.Tick(1); M.Tick(1)
spells[2].active = false
update()
assert(icon("spell2"):IsShown(), "al terminar se queda visible un momento")
local flash = ns.GetActiveFlash("spell2")
assert(flash:IsShown() and flash:GetAlpha() > 0, "con destello")
assert(icon("spell2").cd._cooldown == nil, "sin barrido mientras se despide")
M.Tick(0.5); M.Tick(0.5); M.Tick(0.2)
assert(not icon("spell2"):IsShown(), "pasado el segundo se oculta")
assert(near(x(icon("spell4")), 0), "u1 solo queda en el centro")

-- Sin destello: desaparece al momento
ns.db.activeFlash = false
spells[4].active = false
update()
assert(shownKeys() == "", "sin destello se oculta al momento: " .. shownKeys())
ns.db.activeFlash = true

-- Cargas: con una gastada se ve recargando (solo el borde del barrido, a color, con el número de cargas)
spells[3] = { active = false, gcd = false, max = 2, recharging = true }
update()
local f3 = icon("spell3")
assert(f3:IsShown(), "recargando una carga se ve")
assert(f3.cd._cooldown.duration == chargeDurations[3], "el barrido es el de la recarga")
assert(f3.cd._swipe == false and f3.cd._edge == true and not f3.icon:IsDesaturated(), "aspecto de cargas")
assert(f3.count:IsShown() and f3.count:GetText() == SECRET, "el número de cargas se pasa tal cual")
-- Sin cargas: barrido completo y en gris
spells[3].active = true
M.FireEvent("SPELL_UPDATE_CHARGES")
update()
assert(f3.cd._swipe == true and f3.icon:IsDesaturated(), "sin cargas: como un cooldown normal")
spells[3] = { active = false, gcd = false, max = 2, recharging = false }
update(); M.Tick(1.2)
assert(not f3:IsShown(), "con todas las cargas se oculta")

-- Hechizo que cambia por un talento: se consulta el hechizo que hay ahora
overrides[2] = 22
spells[22].active = true
update()
assert(icon("spell2"):IsShown() and icon("spell2").icon._texture == 1022, "usa el hechizo que lo sustituye")
overrides[2] = nil
spells[22].active = false
update(); M.Tick(1.2)

-- Elegir hechizos: quitar uno del Cooldown Manager y añadir otro cualquiera
spells[4].active = true
spells[50].active = true
ns.SetActiveSpellChosen(4, false)
ns.SetActiveSpellChosen(50, true)
assert(ns.db.activeRemove[4] and ns.db.activeAdd[50], "se guarda en el perfil")
assert(not ns.IsActiveSpellChosen(4) and ns.IsActiveSpellChosen(50) and ns.IsActiveSpellChosen(2), "elección")
ns.RefreshActiveBar()
update()
assert(shownKeys() == "spell50", "el quitado no sale y el añadido sí: " .. shownKeys())
ns.SetActiveSpellChosen(4, true)
assert(ns.db.activeRemove[4] == nil and ns.db.activeAdd[4] == nil, "volver a marcarlo lo deja como estaba")
ns.RefreshActiveBar()
update()
assert(shownKeys() == "spell4 spell50", "los del Cooldown Manager van primero: " .. shownKeys())
assert(x(icon("spell4")) < x(icon("spell50")), "en orden")
-- Sin los hechizos del Cooldown Manager: solo los añadidos
ns.db.activeCDM = false
ns.RefreshActiveBar()
update()
assert(shownKeys() == "spell50", "sin los del Cooldown Manager: " .. shownKeys())
assert(not ns.IsActiveSpellChosen(4), "ya no está elegido")
ns.db.activeCDM = true
ns.SetActiveSpellChosen(50, false)
ns.RefreshActiveBar()
spells[4].active, spells[50].active = false, false
update(); M.Tick(1.2)

-- Buscar un hechizo por número o por nombre
assert(ns.FindSpell("50") == 50 and ns.FindSpell(" Hechizo 22 ") == 22, "buscar hechizos")
assert(ns.FindSpell("999") == nil and ns.FindSpell("nada") == nil and ns.FindSpell("") == nil, "no encontrados")

-- Abalorio en uso
ns.db.activeTrinket1 = true
ns.RefreshActiveBar()
trinket.start, trinket.duration = 95, 60
update()
local t = icon("slot13")
assert(t:IsShown() and t.cd._cooldown.start == 95 and t.cd._cooldown.duration == 60, "abalorio en cooldown")
assert(t.icon._texture == 2013, "icono del abalorio")
trinket.start, trinket.duration = 0, 0
update(); M.Tick(1.2)
assert(not t:IsShown(), "abalorio listo: oculto")
ns.db.activeTrinket1 = false
ns.RefreshActiveBar()

-- Buffs del Cooldown Manager en la misma línea, al tamaño de la barra
ns.db.activeSize = 50
ns.RefreshActiveBar()
spells[2].active = true
b1.isActive = true
update()
assert(shownKeys() == "spell2", "un cooldown activo")
assert(blizzardShown(b1) and not blizzardShown(b2), "el buff activo se ve y el inactivo no")
assert(near(b1:GetScale(), 1.25), "el buff se escala al tamaño de la barra: " .. b1:GetScale())
-- Dos iconos de 50 con 4 de separación -> 104: el cooldown a -27 y el buff a +27 (en sus unidades, /1,25)
assert(near(x(icon("spell2")), -27), "cooldown a la izquierda: " .. x(icon("spell2")))
assert(near(x(b1), 27 / 1.25), "buff a la derecha, en sus propias unidades: " .. x(b1))
-- Blizzard reutiliza un icono oculto y le vuelve a activar la ayuda: se apaga otra vez
b2:SetMouseMotionEnabled(true); e1:SetMouseMotionEnabled(true)
M.Tick(0.2)
assert(not b2:IsMouseMotionEnabled() and not e1:IsMouseMotionEnabled(), "los ocultos siguen sin ayuda")
-- Si el juego ocultara isActive: con "Ocultar si está inactivo" manda lo que muestra Blizzard; si no, el último dato
b1.isActive = SECRET
M.Tick(0.2)
assert(b1:GetPoint(1) == "CENTER" and blizzardShown(b1), "con isActive oculto se usa el último dato")
b1.isActive = true
-- Blizzard recoloca los buffs (y vuelve a poner su escala): la línea se rehace al momento
b1:SetScale(1)
buffs:Layout()
assert(near(b1:GetScale(), 1.25) and near(x(b1), 27 / 1.25), "tras el Layout de Blizzard sigue en la línea")
-- Buffs que Blizzard muestra como barras: en la línea solo su icono, al tamaño de la barra, con el tiempo encima
bb.isActive = true
M.Tick(0.2)
assert(bb.Bar:GetAlpha() == 0 and bb.Bar.Duration:GetParent() == bb.Icon, "la barra se oculta y el tiempo va sobre el icono")
assert(not bb:IsMouseMotionEnabled(), "sin ayuda en la barra invisible")
assert(near(bb:GetScale(), 50 / 30), "el icono de la barra al tamaño de la barra: " .. bb:GetScale())
local bpoint, brel = bb:GetPoint(1)
assert(bpoint == "LEFT" and brel == bar, "colocado por el borde izquierdo de su icono")
ns.db.activeBuffBars = false
M.Tick(0.2)
assert(bb.Bar:GetAlpha() == 1 and bb.Bar.Duration:GetParent() == bb.Bar and bb.Bar.Duration:GetPoint(1) == "RIGHT",
    "sin la opción: la barra vuelve como estaba")
assert(bb:GetPoint(1) == "TOPLEFT" and near(bb:GetScale(), 1) and bb:IsMouseMotionEnabled(), "y en su sitio de Blizzard")
ns.db.activeBuffBars = true
bb.isActive = false
M.Tick(0.2)

-- Con la barra de buffs oculta Blizzard no recoloca nada: no se guardan las posiciones del addon como suyas
buffs:Hide(); buffs:Layout(); buffs:Show()
M.Tick(0.2)
-- Sin buffs en la línea: vuelven a su sitio de Blizzard
ns.db.activeBuffs = false
update()
assert(b1:GetPoint(1) == "TOPLEFT" and near(b1:GetScale(), 1) and blizzardShown(b2), "buffs devueltos")
assert(near(x(icon("spell2")), 0), "el cooldown solo, centrado")
ns.db.activeBuffs = true
update()
assert(b1:GetPoint(1) == "CENTER", "los buffs vuelven a la línea")

-- En combate el juego puede ocultar qué hechizo hay en cada icono: se conserva la lista anterior
e2.GetBaseSpellID = function() return SECRET end
ns.RefreshActiveBar()
update()
assert(icon("spell2"):IsShown(), "con el hechizo oculto se mantiene la lista")
e2.GetBaseSpellID = function() return 2 end

-- Barra de esenciales oculta (por ejemplo, solo en combate): la barra también, y los buffs vuelven a su sitio
essential:Hide()
update()
assert(not bar:IsShown() and b1:GetPoint(1) == "TOPLEFT", "esenciales ocultos: sin barra")
essential:Show()
update()
assert(bar:IsShown() and b1:GetPoint(1) == "CENTER", "esenciales visibles: vuelve la barra")

-- Cuándo se ve la barra: siempre (aunque esenciales esté oculta), solo en combate u oculta
essential:Hide()
ns.db.activeShow = "always"; M.Tick(0.2)
assert(bar:IsShown(), "siempre: se ve aunque esenciales esté oculta")
essential:Show()
ns.db.activeShow = "combat"; M.inCombat = false; M.Tick(0.2)
assert(not bar:IsShown() and b1:GetPoint(1) == "TOPLEFT", "solo en combate: fuera de combate no se ve")
M.inCombat = true; M.FireEvent("PLAYER_REGEN_DISABLED")
assert(bar:IsShown() and b1:GetPoint(1) == "CENTER", "solo en combate: al entrar en combate se ve al momento")
M.inCombat = false
ns.db.activeShow = "hidden"; M.Tick(0.2)
assert(not bar:IsShown() and not blizzardShown(e1), "oculta: no se ve nada")
ns.db.activeShow = "blizzard"; M.Tick(0.2)
assert(bar:IsShown(), "como esenciales: vuelve")

-- Montura y descanso: si se pide, la barra no se ve
local mounted, resting = false, false
IsMounted = function() return mounted end
IsResting = function() return resting end
ns.db.activeHideMounted, ns.db.activeHideResting = true, true
mounted = true; M.Tick(0.2)
assert(not bar:IsShown(), "en montura no se ve")
mounted, resting = false, true; M.Tick(0.2)
assert(not bar:IsShown(), "descansando no se ve")
resting = false; M.Tick(0.2)
assert(bar:IsShown(), "sin montura ni descanso se ve")
ns.db.activeHideMounted, ns.db.activeHideResting = false, false

-- Posición: libre en la pantalla con desplazamiento, o sobre esenciales; arrastrar guarda el desplazamiento
ns.db.activeAnchor, ns.db.activeX, ns.db.activeY = "screen", 120, -40
M.Tick(0.2)
local point, rel, _, px, py = bar:GetPoint(1)
assert(point == "CENTER" and rel == UIParent and px == 120 and py == -40, "libre en la pantalla con desplazamiento")
ns.db.activeAnchor, ns.db.activeX, ns.db.activeY = "essential", 0, 10
M.Tick(0.2)
_, rel, _, px, py = bar:GetPoint(1)
assert(rel == essential and px == 0 and py == 10, "sobre esenciales con desplazamiento")
ns.SetActiveUnlocked(true)
assert(bar:IsShown() and bar.bg:IsShown() and bar.label:IsShown(), "desbloqueada: fondo y rótulo para arrastrar")
assert(icon("spell1"):IsShown() and icon("spell5"):IsShown(), "desbloqueada: se ven todos los iconos elegidos")
function bar:GetCenter() return 530, 420 end
function essential:GetCenter() return 500, 400 end
bar:Fire("OnDragStop")
assert(ns.db.activeX == 30 and ns.db.activeY == 20, "arrastrar guarda el desplazamiento: " .. ns.db.activeX .. "," .. ns.db.activeY)
ns.SetActiveUnlocked(false)
M.Tick(0.2)
assert(not bar.bg:IsShown() and not icon("spell1"):IsShown(), "bloqueada otra vez: solo lo que está en cooldown")
ns.db.activeX, ns.db.activeY = 0, 0
M.Tick(0.2)

-- Botón "Probar": todos los iconos un rato, sin destello ni sonido al terminar
ns.db.activeSound.spell1 = true
assert(ns.PreviewActiveBar(10), "hay algo que mostrar")
assert(icon("spell1"):IsShown() and icon("spell1").cd._cooldown.duration == 10, "vista previa con su propio barrido")
M.Tick(5); M.Tick(5.5)
assert(not icon("spell1"):IsShown() and not ns.GetActiveFlash("spell1"):IsShown() and #played == 0,
    "al terminar la vista previa: sin destello ni sonido")

-- Sonido cuando un cooldown elegido está listo (tras más de un GCD)
spells[1] = { active = true, gcd = false }
update(); M.Tick(1); M.Tick(1)
spells[1].active = false
update()
assert(#played == 1 and played[1] == 8960, "suena al estar listo")
M.Tick(1.2)
ns.db.activeSound.spell1 = nil

-- Objetos: en cooldown se ven, con cuántos quedan
ns.db.activeItems[5512] = true
ns.RefreshActiveBar()
itemCooldown.start, itemCooldown.duration = 95, 120
update()
local potion = icon("item5512")
assert(potion:IsShown() and potion.cd._cooldown.duration == 120 and potion.icon._texture == 9512, "objeto en cooldown")
assert(potion.count:IsShown() and potion.count:GetText() == 2, "con cuántos quedan")
itemCooldown.start, itemCooldown.duration = 0, 0
update(); M.Tick(1.2)
assert(not potion:IsShown(), "objeto listo: oculto")
ns.db.activeItems[5512] = nil
ns.RefreshActiveBar()

-- Modo de edición abierto: todo como Blizzard
EditModeManagerFrame = { IsEditModeActive = function() return true end }
M.Tick(0.2)
assert(not bar:IsShown(), "modo de edición: sin barra")
for _, it in ipairs({ e1, e2, e3, u1, u2, b1, b2 }) do
    assert(blizzardShown(it) and it:GetPoint(1) == "TOPLEFT", "modo de edición: todo como Blizzard")
    assert(it:IsMouseMotionEnabled(), "modo de edición: la ayuda vuelve")
end
assert(near(b1:GetScale(), 1), "modo de edición: escala de Blizzard")
EditModeManagerFrame = nil
M.Tick(0.2) -- sin avisos del juego: la barra tiene que volver a pedir el cooldown por sí sola
assert(bar:IsShown() and not blizzardShown(e1), "al salir del modo de edición vuelve la barra")
M.Tick(0.2)
assert(icon("spell2").cd._cooldown and icon("spell2").cd._cooldown.duration.spell == 2 and M.ExpireBorder(icon("spell2")),
    "al volver, el barrido y el borde dorado se vuelven a pedir al juego")

-- Desactivar la opción lo devuelve todo como estaba
ns.db.activeOnly = false
update()
assert(not bar:IsShown(), "desactivado: sin barra")
for _, it in ipairs({ e1, e2, e3, u1, u2, b1, b2 }) do
    assert(blizzardShown(it) and it:GetPoint(1) == "TOPLEFT", "desactivado: todo como Blizzard")
end
print("barra de cooldowns activos: OK")
