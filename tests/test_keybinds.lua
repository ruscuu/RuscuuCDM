-- Atajos de teclado: tecla de cada hechizo según las barras, y texto sobre los iconos del Cooldown Manager
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local bindings = {
    ACTIONBUTTON1 = "1", MULTIACTIONBAR1BUTTON1 = "X", MULTIACTIONBAR1BUTTON3 = "SHIFT-Q",
    ["CLICK BT4Button5:LeftButton"] = "F", ["CLICK DominosActionButton80:HOTKEY"] = "G",
    ["CLICK BT4Button6:LeftButton"] = "Z", MULTIACTIONBAR5BUTTON2 = "CTRL-2",
}
GetBindingKey = function(cmd) return bindings[cmd] end
GetBindingText = function(key) return (key:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-")) end
-- Contenido de los huecos de acción
local slots = { [1] = 100, [73] = 200, [63] = 600, [30] = 300, [80] = 700, [61] = 500, [31] = 500, [146] = 800, [5] = 999 }
HasAction = function(a) if a > 180 then error("hueco no válido") end return slots[a] ~= nil end
GetActionInfo = function(a) local s = slots[a]; if s then return "spell", s end end
local base = { [400] = 401 }
C_Spell = { GetBaseSpell = function(id) return base[id] or id end }
slots[10] = 400; bindings.ACTIONBUTTON10 = "0"
local ns = {}
M.Load(ns, "Locales.lua", "Core.lua", "Skin.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.ExpireAllowed = function() return true end
C_ActionBar = { GetActionCooldownDuration = function() return {} end }
-- Barras de Blizzard: la principal visible, la barra 2 oculta
for i = 1, 12 do local b = M.NewActionButton("ActionButton" .. i, i); b.bindingAction = "ACTIONBUTTON" .. i end
local bar2 = M.CreateFrame("Frame", "MultiBarBottomLeft"); bar2._shown = false
for i = 1, 12 do local b = M.NewActionButton("MultiBarBottomLeftButton" .. i, 60 + i, bar2); b.bindingAction = "MULTIACTIONBAR1BUTTON" .. i end
-- Bartender4 (LibActionButton) y Dominos
local labButtons = {}
for i, action in pairs({ [5] = 30, [6] = 31 }) do
    local b = M.NewActionButton("BT4Button" .. i, 0)
    b._state_type, b._state_action = "action", action
    b.GetBindingAction = function(self) return "CLICK " .. self:GetName() .. ":LeftButton" end
    labButtons[#labButtons + 1] = b
end
local lab = { GetAllButtons = function() local t = {}; for _, b in ipairs(labButtons) do t[b] = true end; return t end,
    RegisterCallback = function() end }
LibStub = function(name) if name == "LibActionButton-1.0" then return lab end end
local dom = M.NewActionButton("DominosActionButton80", 80); dom:SetAttribute("commandName", "CLICK DominosActionButton80:HOTKEY")
ActionBarButtonEventsFrame = { frames = { dom } }
M.Load(ns, "ActionBars.lua")
ns.HookActionBars()
ns.QueueHotkeyRebuild(); M.RunTimers()

local function key(id) return ns.GetSpellHotkey(id) end
assert(key(100) == "1", "barra principal: " .. tostring(key(100)))
assert(key(200) == "1", "forma de gato (hueco 73) usa la tecla de la barra principal")
assert(key(600) == "s-Q", "barra oculta de Blizzard por su hueco: " .. tostring(key(600)))
assert(key(300) == "F", "Bartender4: " .. tostring(key(300)))
assert(key(700) == "G", "Dominos: " .. tostring(key(700)))
assert(key(500) == "Z", "lo visible (Bartender4) manda sobre el hueco oculto: " .. tostring(key(500)))
assert(key(800) == "c-2", "barra 6 de Blizzard (hueco 146): " .. tostring(key(800)))
assert(key(401) == "0" and key(400) == "0", "hechizo base")
assert(key(999) == nil, "hueco sin tecla asignada")
assert(key({ __secret = true }) == nil, "hechizo secreto")

-- En combate no se recalcula; al salir sí
M.inCombat = true
bindings.ACTIONBUTTON1 = "R"
ns.QueueHotkeyRebuild(); M.RunTimers()
assert(key(100) == "1", "en combate se mantiene")
M.inCombat = false
M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers()
assert(key(100) == "R", "al salir de combate se recalcula: " .. tostring(key(100)))

-- Iconos del Cooldown Manager
local viewer = M.CreateFrame("Frame", "EssentialCooldownViewer")
local function item(spellID)
    local it = M.CreateFrame("Frame", nil, viewer)
    it.Icon = it:CreateTexture(); it.Cooldown = M.CreateFrame("Cooldown", nil, it)
    it.GetBaseSpellID = function() return spellID end
    return it
end
local a, b, c = item(100), item(401), item(12345)
ns.SkinAll()
local function label(it)
    for _, child in ipairs(it._children) do
        if child._regions then for _, r in ipairs(child._regions) do if r._type == "FontString" and r._text ~= nil and child._level then return r._text, child:IsShown() end end end
    end
end
local ta, sa = label(a); assert(ta == "R" and sa, "icono con tecla: " .. tostring(ta))
local tb = label(b); assert(tb == "0", "icono por hechizo base: " .. tostring(tb))
local tc, sc = label(c); assert(tc == "" and not sc, "icono sin tecla se oculta")
ns.db.showKeybinds = false; ns.SkinAll()
local _, shown = label(a); assert(not shown, "opción desactivada")
ns.db.showKeybinds = true; ns.db.enabled.essential = false; ns.SkinAll()
_, shown = label(a); assert(not shown, "visor sin estilo")
print("atajos de teclado: OK")
