-- Ruscuu Cooldown Manager Forever: botón con el logo en el minimapa y entrada en el menú de addons
local _, ns = ...

local ICON = "Interface\\AddOns\\RuscuuCDM\\Media\\minimap"
local button

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff9b4dffRuscuu|r Cooldown Manager Forever")
    GameTooltip:AddLine("Clic izquierdo: abrir opciones", 1, 1, 1)
    GameTooltip:AddLine("Clic derecho: reaplicar estilo", 1, 1, 1)
    GameTooltip:AddLine("Arrastrar: mover el botón", 1, 1, 1)
    GameTooltip:Show()
end

local function OnClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.SkinAll()
        ns.Print("Estilo reaplicado.")
    else
        ns.OpenOptions()
    end
end

-- Coloca el botón en el borde del minimapa según el ángulo guardado
local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle)
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
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
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    UpdatePosition()
    button:SetShown(not ns.db.minimap.hide)
end

function ns.SetMinimapShown(shown)
    ns.db.minimap.hide = not shown
    if button then button:SetShown(shown) end
end

-- Llamadas desde el menú de addons del minimapa (declaradas en el .toc)
function RuscuuCDM_OnAddonCompartmentClick(_, mouseButton)
    OnClick(mouseButton)
end

function RuscuuCDM_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame)
end

function RuscuuCDM_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
