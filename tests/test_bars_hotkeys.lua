-- Teclas de los hechizos en barras de addons ocultas fuera de combate (Bartender4 que solo sale en combate) y de
-- botones creados más tarde
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local bindings = { ["CLICK BT4Button13:Keybind"] = "SHIFT-F", ["CLICK BT4Button20:Keybind"] = "ALT-G",
    ["CLICK BT4Button1:Keybind"] = "1" }
GetBindingKey = function(cmd) return bindings[cmd] end
GetBindingText = function(key) return (key:gsub("SHIFT%-", "s-"):gsub("ALT%-", "a-")) end
local slots = { [13] = 500, [20] = 600, [1] = 100 }
HasAction = function(a) if a > 180 then error("hueco no válido") end return slots[a] ~= nil end
GetActionInfo = function(a) local s = slots[a]; if s then return "spell", s end end
C_Spell = { GetBaseSpell = function(id) return id end }
local ns = {}
M.Load(ns, "Locales.lua", "Core.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
ns.ExpireAllowed = function() return true end
ns.TrackExpire, ns.UntrackExpire = function() end, function() end
C_ActionBar = { GetActionCooldownDuration = function() return {} end }

-- Bartender4: la barra 1 visible y la barra 2 escondida fuera de combate (solo se usa con teclas)
local labButtons = {}
local function labButton(index, action, parent)
    local b = M.NewActionButton("BT4Button" .. index, 0, parent)
    b._state_type, b._state_action = "action", action
    labButtons[#labButtons + 1] = b
    return b
end
local callbacks = {}
local lab = { GetAllButtons = function() local t = {}; for _, b in ipairs(labButtons) do t[b] = true end; return t end,
    RegisterCallback = function(_, event, fn) callbacks[event] = fn end }
LibStub = function(name) if name == "LibActionButton-1.0" then return lab end end
local bar1 = M.CreateFrame("Frame", "BT4Bar1", UIParent)
local bar2 = M.CreateFrame("Frame", "BT4Bar2", UIParent); bar2._shown = false
labButton(1, 1, bar1)
labButton(13, 13, bar2)

M.Load(ns, "ActionBars.lua")
ns.HookActionBars()
ns.QueueHotkeyRebuild(); M.RunTimers()
assert(ns.GetSpellHotkey(100) == "1", "barra visible")
assert(ns.GetSpellHotkey(500) == "s-F", "barra de Bartender4 oculta fuera de combate: " .. tostring(ns.GetSpellHotkey(500)))

-- Un botón creado más tarde (al añadir una barra) también da su tecla, sin esperar a otro evento
labButton(20, 20, bar2)
callbacks.OnButtonCreated("OnButtonCreated")
M.RunTimers() -- se engancha el botón
M.RunTimers() -- se recalculan las teclas
assert(ns.GetSpellHotkey(600) == "a-G", "botón creado tarde: " .. tostring(ns.GetSpellHotkey(600)))

print("teclas en barras ocultas: OK")
