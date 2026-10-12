-- Simulador mínimo de la API de WoW para probar la lógica del addon fuera del juego (con LuaJIT).
-- Solo imita lo que el addon necesita; los métodos desconocidos de frames y regiones no hacen nada.
-- Los valores "secretos" del juego se imitan con tablas { __secret = true }.
local M = {}

local function noop() end

local Object = {}
-- Solo los nombres con forma de método (SetX, GetX...) devuelven una función vacía; los campos quedan en nil
local METHOD_PREFIXES = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Add", "Remove", "Clear",
    "Lock", "Unlock", "Is", "Has", "Highlight", "Start", "Stop", "Create", "Play", "Pause", "Resume", "Setup", "Generate" }
Object.__index = function(_, k)
    local v = rawget(Object, k)
    if v ~= nil then return v end
    if type(k) == "string" then
        for _, p in ipairs(METHOD_PREFIXES) do
            if k:sub(1, #p) == p and k:sub(#p + 1, #p + 1):match("%u") then return noop end
        end
    end
end

function Object:IsObjectType(kind) return self._type == kind end
function Object:GetObjectType() return self._type end
function Object:GetName() return self._name end
function Object:GetParent() return self._parent end
function Object:SetParent(p) self._parent = p end
function Object:Show() self._shown = true end
function Object:Hide() self._shown = false end
function Object:SetShown(v) self._shown = v and true or false end
function Object:IsShown() return self._shown end
function Object:IsVisible()
    local f = self
    while f do
        if not f._shown then return false end
        f = f._parent
    end
    return true
end
function Object:GetFrameLevel() return self._level or 1 end
function Object:SetFrameLevel(l) self._level = l end
function Object:GetWidth() return self._width or 36 end
function Object:GetHeight() return self._height or 36 end
function Object:SetSize(w, h) self._width, self._height = w, h end
function Object:SetWidth(w) self._width = w end
function Object:SetHeight(h) self._height = h end
function Object:SetText(t) self._text = t end
function Object:GetText() return self._text end
function Object:SetFont(file, size, flags) self._font = { file, size, flags } return true end
function Object:GetFont() if self._font then return unpack(self._font) end return "Fonts\\FRIZQT__.TTF", 12, "" end
function Object:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
function Object:SetAlpha(a) self._alpha = a end
function Object:SetTextColor(r, g, b, a) self._color = { r, g, b, a } end
function Object:GetTextColor() if self._color then return unpack(self._color) end return 1, 1, 1, 1 end
function Object:SetPoint(...) self._points = self._points or {}; self._points[#self._points + 1] = { ... } end
function Object:ClearAllPoints() self._points = {} end
function Object:GetPoint(i) local p = self._points and self._points[i or 1]; if p then return unpack(p) end end
function Object:SetScript(name, fn) self._scripts = self._scripts or {}; self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts and self._scripts[name] end
function Object:HookScript(name, fn)
    self._scripts = self._scripts or {}
    local old = self._scripts[name]
    self._scripts[name] = old and function(...) old(...); fn(...) end or fn
end
function Object:Fire(name, ...) local fn = self._scripts and self._scripts[name]; if fn then return fn(self, ...) end end
function Object:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
function Object:GetChildren() return unpack(self._children or {}) end
function Object:GetRegions() return unpack(self._regions or {}) end
function Object:CreateTexture() return M.NewRegion("Texture", self) end
function Object:CreateFontString() return M.NewRegion("FontString", self) end
function Object:CreateMaskTexture() return M.NewRegion("MaskTexture", self) end
function Object:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
function Object:GetAttribute(k) return self._attr and self._attr[k] end
function Object:GetNumMaskTextures() return 0 end
function Object:GetThumbTexture() self._thumb = self._thumb or M.NewRegion("Texture", self); return self._thumb end
function Object:SetValue(v) local old = self._value; self._value = v; if old ~= v then self:Fire("OnValueChanged", v) end end
function Object:GetValue() return self._value end
function Object:SetFocus() self._focus = true; self:Fire("OnEditFocusGained") end
function Object:ClearFocus() if self._focus then self._focus = false; self:Fire("OnEditFocusLost") end end
function Object:HasFocus() return self._focus == true end
function Object:SetChecked(v) self._checked = v end
function Object:GetChecked() return self._checked end
function Object:GetStringHeight() return 12 end

function M.NewRegion(kind, parent)
    local r = setmetatable({ _type = kind, _parent = parent, _shown = true }, Object)
    if parent then parent._regions = parent._regions or {}; table.insert(parent._regions, r) end
    return r
end

M.frames = {}
function M.CreateFrame(kind, name, parent, template)
    local f = setmetatable({ _type = kind, _name = name, _parent = parent, _shown = true }, Object)
    table.insert(M.frames, f)
    template = template or ""
    if template:find("CheckButton") then f.Text = f:CreateFontString() end
    if template:find("ScrollFrame") then f.ScrollBar = setmetatable({ _type = "Slider", _shown = true }, Object) end
    if parent then parent._children = parent._children or {}; table.insert(parent._children, f) end
    if name then _G[name] = f end
    return f
end

-- Botón de acción como los de Blizzard (con cooldown, icono y texto de la tecla)
function M.NewActionButton(name, action, parent)
    local b = M.CreateFrame("CheckButton", name, parent)
    b.action = action
    b.cooldown = M.CreateFrame("Cooldown", name and (name .. "Cooldown"), b)
    b.icon = b:CreateTexture()
    b.HotKey = b:CreateFontString()
    return b
end

-- Lanza un evento a todos los frames que lo registraron (como hace el juego)
function M.FireEvent(event, ...)
    for _, f in ipairs(M.frames) do
        if f._events and f._events[event] and f._scripts and f._scripts.OnEvent then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

-- Carga archivos del addon como los carga el juego: (nombre del addon, tabla compartida)
function M.Load(ns, ...)
    for _, path in ipairs({ ... }) do
        assert(loadfile(path))("RuscuuCDM", ns)
    end
end

-- Temporizadores de C_Timer.After: se ejecutan a mano con RunTimers
M.timers = {}
function M.RunTimers()
    local list = M.timers
    M.timers = {}
    for _, fn in ipairs(list) do fn() end
end

function M.install()
    _G.SlashCmdList, _G.StaticPopupDialogs, _G.UISpecialFrames = {}, {}, {}
    _G.GetLocale = function() return "enUS" end
    _G.CreateFrame = M.CreateFrame
    _G.CreateFont = function(name) local f = M.CreateFrame("Font", name); return f end
    _G.hooksecurefunc = function(t, method, fn)
        if type(t) == "string" then t, method, fn = _G, t, method end
        local old = t[method]
        t[method] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
    end
    _G.C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }
    _G.GetTime = function() return M.now or 100 end
    _G.InCombatLockdown = function() return M.inCombat or false end
    _G.issecretvalue = function(v) return type(v) == "table" and v.__secret == true end
    _G.RANGE_INDICATOR = "●"
    _G.UIParent = M.CreateFrame("Frame", "UIParent")
    _G.unpack = unpack
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    _G.tinsert = table.insert
    _G.strsplit = function(delim, str)
        local out = {}
        for piece in (str .. delim):gmatch("(.-)" .. delim:gsub("%p", "%%%0")) do out[#out + 1] = piece end
        return unpack(out)
    end
end

return M
