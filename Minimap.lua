-- Ruscuu Cooldown Manager Forever: botón con el logo en el minimapa y entrada en el menú de addons
local _, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\RuscuuCDM\\Media\\minimap"
local button

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff9b4dffRuscuu|r Cooldown Manager Forever")
    GameTooltip:AddLine(L["Left-click: open options"], 1, 1, 1)
    GameTooltip:AddLine(L["Shift + left-click: choose which cooldowns are shown"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: preview the golden border"], 1, 1, 1)
    if not ns.global.minimap.lock then
        GameTooltip:AddLine(L["Drag: move button"], 1, 1, 1)
    end
    GameTooltip:Show()
end

local function OnClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.TestExpire(5)
    elseif IsShiftKeyDown() then
        ns.OpenCooldownSettings()
    else
        ns.OpenOptions()
    end
end

local OFFSET = 10 -- distancia del centro del botón al borde del minimapa
local OPPOSITE = { TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT" }

-- Forma del minimapa: los addons que lo cambian (Leatrix Plus, SexyMap...) definen GetMinimapShape
local function MinimapShape()
    if not GetMinimapShape then return "ROUND" end
    local ok, shape = pcall(GetMinimapShape)
    return (ok and type(shape) == "string") and shape or "ROUND"
end

-- ¿Es redonda esa esquina del minimapa? Formas: ROUND, SQUARE, CORNER-*, SIDE-*, TRICORNER-*
local function IsRoundCorner(shape, corner)
    if shape == "SQUARE" then return false end
    local kind, where = shape:match("^(%u+)%-(%u+)$")
    if kind == "CORNER" then return where == corner end
    if kind == "SIDE" then return corner:find(where, 1, true) ~= nil end
    if kind == "TRICORNER" then return OPPOSITE[where] ~= corner end
    return true
end

-- Posición del botón respecto al centro del minimapa para un ángulo (en grados)
function ns.MinimapButtonOffset(angleDegrees, shape, width, height)
    local angle = math.rad(angleDegrees)
    local x, y = math.cos(angle), math.sin(angle)
    local corner = (y >= 0 and "TOP" or "BOTTOM") .. (x >= 0 and "RIGHT" or "LEFT")
    local w, h = width / 2 + OFFSET, height / 2 + OFFSET
    if IsRoundCorner(shape, corner) then
        return x * w, y * h
    end
    -- Esquina recta: el botón sigue el borde del cuadrado en vez del círculo
    local m = math.max(math.abs(x), math.abs(y))
    return x / m * w, y / m * h
end

-- Coloca el botón en el borde del minimapa según el ángulo guardado
local function UpdatePosition()
    if not button then return end
    local x, y = ns.MinimapButtonOffset(ns.global.minimap.angle, MinimapShape(), Minimap:GetWidth(), Minimap:GetHeight())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
ns.UpdateMinimapPosition = UpdatePosition

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.global.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    UpdatePosition()
end

function ns.CreateMinimapButton()
    button = CreateFrame("Button", "RuscuuCDMMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    background:SetColorTexture(unpack(ns.COLORS.bg))

    -- Cara del oso recortada en círculo
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(21, 21)
    icon:SetPoint("TOPLEFT", 6, -5)
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    background:AddMaskTexture(mask)

    -- Aro de Blizzard sin el dorado y teñido del morado Ruscuu
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetDesaturated(true)
    border:SetVertexColor(0.75, 0.45, 1)

    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, mouseButton) OnClick(mouseButton) end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        if ns.global.minimap.lock then return end
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    UpdatePosition()
    button:SetShown(not ns.global.minimap.hide)
    -- Los addons de minimapa pueden cambiar su tamaño o su forma después de cargar este addon
    Minimap:HookScript("OnSizeChanged", UpdatePosition)
end

function ns.SetMinimapShown(shown)
    ns.global.minimap.hide = not shown
    if button then button:SetShown(shown) end
end

function ns.SetMinimapLocked(locked)
    ns.global.minimap.lock = locked
end

-- Llamadas desde el menú de addons del minimapa (declaradas en el .toc).
-- Según la versión del juego, el segundo argumento es el botón del ratón o una tabla que lo contiene.
function RuscuuCDM_OnAddonCompartmentClick(_, input)
    local mouseButton = input
    if type(input) == "table" then mouseButton = input.buttonName end
    OnClick(mouseButton)
end

function RuscuuCDM_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame)
end

function RuscuuCDM_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
