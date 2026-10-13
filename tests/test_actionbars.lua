-- Barras de acción: botones de Blizzard, Bartender4/ElvUI (LibActionButton) y Dominos
package.path = "tests/?.lua;" .. package.path
local M = require("wowmock"); M.install()
local ns = {}
M.Load(ns, "Locales.lua", "Core.lua")
ns.db = ns.CopyTable(ns.PROFILE_DEFAULTS)
local tracked = {}
ns.TrackExpire = function(owner) tracked[owner] = true end
ns.UntrackExpire = function(owner) tracked[owner] = nil end
ns.ExpireAllowed = function() return true end
HasAction = function(a) return a ~= nil end
C_ActionBar = { GetActionCooldownDuration = function() return {} end }

-- Barras de Blizzard: principal y una barra extra
for i = 1, 12 do M.NewActionButton("ActionButton" .. i, i) end
for i = 1, 12 do M.NewActionButton("MultiBarBottomLeftButton" .. i, 60 + i) end
-- Botones de LibActionButton (Bartender4)
local labButtons = {}
local lab = { GetAllButtons = function() local t = {}; for _, b in ipairs(labButtons) do t[b] = true end; return t end }
local callbacks = {}
lab.RegisterCallback = function(_, event, fn) callbacks[event] = fn end
for i = 1, 3 do
    local b = M.NewActionButton("BT4Button" .. i, 0)
    b._state_type, b._state_action = "action", 24 + i
    labButtons[#labButtons + 1] = b
end
local custom = M.NewActionButton("BT4Button99", 0); custom._state_type, custom._state_action = "custom", { x = 1 }
labButtons[#labButtons + 1] = custom
LibStub = function(name) if name == "LibActionButton-1.0" then return lab end end
-- Dominos (plantilla de Blizzard) y botones de Blizzard que no deben tocarse
local dominos = M.NewActionButton("DominosActionButton73", 73)
local extra = M.NewActionButton("ExtraActionButton1", 169)
ActionBarButtonEventsFrame = { frames = { _G.ActionButton1, dominos, extra } }

M.Load(ns, "ActionBars.lua")
ns.HookActionBars()
-- 12 + 12 de Blizzard, 4 de LAB, 1 de Dominos; ExtraActionButton se ignora
assert(ns.CountActionCooldowns() == 29, "botones enganchados: " .. ns.CountActionCooldowns())
assert(tracked[_G.BT4Button1] and tracked[dominos] and tracked[_G.ActionButton1], "borde dorado en botones de addons")
assert(not tracked[extra], "ExtraActionButton no debe tocarse")
-- Llamar otra vez no duplica nada
ns.HookActionBars(); assert(ns.CountActionCooldowns() == 29)
-- Un botón nuevo de Bartender4 se engancha tras el aviso de la librería
local late = M.NewActionButton("BT4Button4", 0); late._state_type, late._state_action = "action", 28
labButtons[#labButtons + 1] = late
assert(callbacks.OnButtonCreated, "callback registrado")
callbacks.OnButtonCreated("OnButtonCreated", late)
M.RunTimers()
assert(ns.CountActionCooldowns() == 30 and tracked[late], "botón creado tarde")
-- Desmarcar "barras de otros addons" quita el borde de esos botones y deja los de Blizzard
ns.db.bars.addons = false; ns.StyleActionBars()
assert(not tracked[_G.BT4Button1] and not tracked[dominos] and tracked[_G.ActionButton1])
-- La lista de hechizos usa la acción de LAB (_state_action) y no los botones "custom"
ns.db.bars.addons = true
GetActionInfo = function(a) return "spell", 1000 + a end
C_Spell = { GetBaseSpell = function(id) return id end, GetSpellName = function(id) return "S" .. id end, GetSpellTexture = function() return 1 end }
local seen = {}
for _, sp in ipairs(ns.GetActionBarSpells()) do seen[sp.spellID] = true end
assert(seen[1025] and seen[1001] and seen[1073] and seen[1061], "hechizos de LAB, Blizzard y Dominos")
print("barras de acción: OK")
