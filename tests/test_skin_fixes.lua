-- Estilo del Cooldown Manager: lo que Blizzard reaplica por su cuenta, restaurar sin recargar,
-- reutilizar los bordes dorados, no gastar CPU sin avisos activos y no perder instantáneas al reiniciar.
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
M.InstallCurves()
local SECRET = { __secret = true }

local reported = {}
_G.geterrorhandler = function() return function(err) reported[#reported + 1] = tostring(err) end end
local realPrint = print
print = function() end

local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua")
ns.global = { chatMessages = false }
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.RebuildExpireCurve()

local AURA_COLOR = { aura = true }
CooldownViewerConstants = { ITEM_AURA_COLOR = AURA_COLOR, ITEM_COOLDOWN_COLOR = {} }

-- Cooldown con lo justo para comprobar barrido, borde, números y fuente de la cuenta atrás
local function newCooldown(parent)
    local cd = M.CreateFrame("Cooldown", nil, parent)
    cd.SetSwipeColor = function(self, r, g, b, a) self._swipeColor = { r, g, b, a } end
    cd.SetHideCountdownNumbers = function(self, hide) self._hideNumbers = hide end
    local fs = parent:CreateFontString()
    fs._fontObject = "GameFontHighlightOutline"
    fs._font = { "Blizz.ttf", 14, "OUTLINE" }
    fs.GetFontObject = function(self) return self._fontObject end
    fs.SetFontObject = function(self, obj) self._fontObject = obj end
    cd.GetCountdownFontString = function() return fs end
    cd.SetCountdownFont = function(_, name)
        fs._fontObject = name
        fs._font = { "Addon.ttf", 20, "" }
    end
    return cd, fs
end

-- Lo que hace Blizzard en cada GCD (RefreshSpellCooldownInfo): sus colores y después SetCooldown
local function blizzardRefresh(cd)
    cd:SetSwipeColor(0, 0, 0, 0.7)
    cd:SetDrawSwipe(true)
    cd:SetDrawEdge(true)
    cd:SetCooldown(1, 10)
end

local essentialEntry, buffEntry
for _, e in ipairs(ns.VIEWERS) do
    if e.key == "essential" then essentialEntry = e end
    if e.key == "buffIcons" then buffEntry = e end
end

local viewer = M.CreateFrame("Frame", "EssentialCooldownViewer")
local item = M.CreateFrame("Frame", nil, viewer)
item.Icon = item:CreateTexture()
local cd, fs = newCooldown(item)
item.Cooldown = cd
item.GetBaseSpellID = function() return 100 end
C_Spell = { GetSpellCooldownDuration = function() return nil end, GetBaseSpell = function(id) return id end }

-- SKIN-CORE-1: el barrido del addon sobrevive a la actualización de Blizzard
ns.db.swipeColor = { 0.5, 0, 1, 0.8 }
ns.db.showSwipe = false
ns.db.cooldownEdge = "hide"
ns.SkinViewer(essentialEntry)
blizzardRefresh(cd)
assert(cd._swipeColor[1] == 0.5 and cd._swipeColor[3] == 1, "el color del barrido se reaplica tras Blizzard")
assert(cd._swipe == false, "el barrido oculto sigue oculto tras Blizzard")
assert(cd._edge == false, "el borde oculto sigue oculto tras Blizzard")
-- El amarillo de "aura activa" de Blizzard se respeta
item.cooldownSwipeColor = AURA_COLOR
cd:SetSwipeColor(1, 0.95, 0.57, 0.7)
cd:SetCooldown(1, 10)
assert(cd._swipeColor[1] == 1, "el color de aura activa no se cambia")
item.cooldownSwipeColor = nil
-- Modo "blizzard": el borde lo decide el juego en cada cooldown
ns.db.cooldownEdge = "blizzard"
ns.SkinViewer(essentialEntry)
blizzardRefresh(cd)
assert(cd._edge == true, "en modo blizzard el addon no fuerza el borde")
-- Volver a mostrar el barrido lo enseña sin esperar a Blizzard
ns.db.showSwipe = true
cd._swipe = false
ns.SkinViewer(essentialEntry)
assert(cd._swipe == true, "al volver a activar el barrido se muestra")

-- SKIN-CORE-2: al quitar el estilo vuelve la fuente de Blizzard (no la del addon)
ns.db.enabled.essential = false
ns.SkinViewer(essentialEntry)
assert(fs._fontObject == "GameFontHighlightOutline", "objeto de fuente restaurado: " .. tostring(fs._fontObject))
assert(fs._font[1] == "Blizz.ttf" and fs._font[2] == 14, "fuente restaurada: " .. tostring(fs._font[1]))
-- Sin estilo, Blizzard ya no ve el barrido del addon
cd._swipeColor = nil
cd:SetCooldown(1, 10)
assert(cd._swipeColor == nil, "sin estilo no se reaplica nada")
ns.db.enabled.essential = true

-- SKIN-CORE-3: el temporizador oculto en el Modo Edición se respeta al aplicar y al quitar el estilo
viewer.timerShown = false
ns.SkinViewer(essentialEntry)
assert(cd._hideNumbers == true, "con el temporizador oculto en Modo Edición no se muestran los números")
ns.db.enabled.essential = false
ns.SkinViewer(essentialEntry)
assert(cd._hideNumbers == true, "al quitar el estilo siguen ocultos")
viewer.timerShown = true
ns.db.enabled.essential = true
ns.SkinViewer(essentialEntry)
assert(cd._hideNumbers == false, "con el temporizador visible se muestran")

-- SKIN-CORE-6: dejar de seguir y volver a seguir reutiliza el mismo borde
local owner = M.CreateFrame("Frame")
local tex = owner:CreateTexture()
ns.TrackExpire(owner, tex, function() end)
local first = M.ExpireBorderFrame(owner)
local before = #owner._children
ns.UntrackExpire(owner)
ns.TrackExpire(owner, tex, function() end)
assert(M.ExpireBorderFrame(owner) == first and #owner._children == before, "el borde se reutiliza")

-- SKIN-CORE-7: sin avisos activos el fotograma no toca ningún borde
local _, inner = M.ExpireBorderFrame(owner)
local alphaCalls = 0
local realSetAlpha = inner.SetAlpha
inner.SetAlpha = function(self, a) alphaCalls = alphaCalls + 1; return realSetAlpha(self, a) end
ns.db.expireGlow, ns.db.buffEndGlow = false, false
ns.UpdateExpire()
M.Tick(0.2); M.Tick(0.2); M.Tick(0.2)
assert(alphaCalls == 0, "sin avisos no se cambia la transparencia: " .. alphaCalls)
-- Sin pulso la transparencia se pone una sola vez
ns.db.expireGlow, ns.db.expirePulse = true, "none"
ns.UpdateExpire()
alphaCalls = 0
M.Tick(0.2); M.Tick(0.2); M.Tick(0.2)
assert(alphaCalls == 1 and inner:GetAlpha() == 1, "sin pulso se aplica una vez: " .. alphaCalls)

-- SECRET-SWEEP-3: las auras ocultas por el juego se cuentan para /rcm debug
C_UnitAuras = { GetAuraDuration = function() return nil end }
ns.db.buffEndGlow = true
ns.UpdateExpire()
local buffViewer = M.CreateFrame("Frame", "BuffIconCooldownViewer")
local buff = M.CreateFrame("Frame", nil, buffViewer)
buff.Icon = buff:CreateTexture()
buff.GetAuraSpellInstanceID = function() return SECRET end
ns.SkinViewer(buffEntry)
local hiddenBefore = ns.CountHiddenBuffReads()
M.Tick(0.2)
assert(ns.CountHiddenBuffReads() > hiddenBefore, "el aura secreta se cuenta")

-- SKIN-CORE-9: un visor que falla no deja sin estilo a los demás del mismo repaso
local skinned = {}
local realSkinViewer = ns.SkinViewer
ns.SkinViewer = function(entry)
    if entry.key == "essential" then error("fallo de prueba") end
    skinned[entry.key] = true
end
M.timers = {}
ns.HookViewers()
M.RunTimers()
assert(skinned.buffIcons, "el otro visor recibe el estilo aunque uno falle")
local found = false
for _, r in ipairs(reported) do if r:find("fallo de prueba") then found = true end end
assert(found, "el fallo se informa")
ns.SkinViewer = realSkinViewer

-- SKIN-CORE-4: reiniciar todo conserva las instantáneas de la interfaz
_G.ReloadUI = function() end
RuscuuCDMDB = { cdmAutoDone = true, snapshots = { Raid = { x = 1 } }, snapshotRestore = { layout = false },
    profiles = { Default = {} } }
StaticPopupDialogs.RUSCUUCDM_RESET_ALL.OnAccept()
assert(RuscuuCDMDB.cdmAutoDone == true and RuscuuCDMDB.snapshots.Raid.x == 1
    and RuscuuCDMDB.snapshotRestore.layout == false and RuscuuCDMDB.profiles == nil,
    "el reinicio borra los perfiles y conserva las instantáneas")

print = realPrint
print("estilo del Cooldown Manager (reaplicar, restaurar, reutilizar, reiniciar): OK")
