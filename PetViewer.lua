--[[
    PET VIEWER - Versão Final Corrigida
    Lógica de pets do script original + UI nova
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = (gethui and gethui()) or game:GetService("CoreGui")

if CoreGui:FindFirstChild("PetViewerGui") then
    CoreGui.PetViewerGui:Destroy()
end

local LocalPlayer = Players.LocalPlayer
local selectedPlayer = LocalPlayer

-- Raridades (mesmas do primeiro script que funcionava)
local ALLOWED_RARITIES = {
    ["Advanced"] = Color3.fromRGB(255, 230, 0),
    ["Unique"]   = Color3.fromRGB(255, 120, 0),
    ["Epic"]     = Color3.fromRGB(170, 0, 255),
    ["Rare"]     = Color3.fromRGB(0, 150, 255)
}

local PERK_CONFIG = {
    ["strength"] = {
        icon = "💪",
        name = "Strength",
        textColor = Color3.fromRGB(255, 230, 0),
        borderColor = Color3.fromRGB(0, 0, 0)
    },
    ["durability"] = {
        icon = "🛡️",
        name = "Durabilidade",
        textColor = Color3.fromRGB(0, 150, 255),
        borderColor = Color3.fromRGB(0, 0, 0)
    },
    ["agility"] = {
        icon = "⚡",
        name = "Agility",
        textColor = Color3.fromRGB(0, 255, 80),
        borderColor = Color3.fromRGB(0, 0, 0)
    },
    ["damage"] = {
        icon = "⚔️",
        name = "Damage",
        textColor = Color3.fromRGB(255, 50, 50),
        borderColor = Color3.fromRGB(0, 0, 0)
    }
}

local function createStroke(parent, color, thickness, mode)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 1.5
    stroke.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function formatNumber(n)
    n = tonumber(n)
    if not n then return "0" end
    if n >= 1e18 then return string.format("%.2fQt", n / 1e18) end
    if n >= 1e15 then return string.format("%.2fQ",  n / 1e15) end
    if n >= 1e12 then return string.format("%.2fT",  n / 1e12) end
    if n >= 1e9  then return string.format("%.2fB",  n / 1e9)  end
    if n >= 1e6  then return string.format("%.2fM",  n / 1e6)  end
    if n >= 1e3  then return string.format("%.2fK",  n / 1e3)  end
    return tostring(math.floor(n))
end

local function formatAssetId(raw)
    raw = tostring(raw or "")
    if tonumber(raw) then return "rbxassetid://" .. raw end
    if raw:find("rbxassetid://") or raw:find("http") then return raw end
    return ""
end

local function extractPetImage(petInst)
    if not petInst then return "" end

    for _, attr in ipairs({"Image", "ImageId", "Texture", "TextureId", "Icon"}) do
        local val = petInst:GetAttribute(attr)
        if val and tostring(val) ~= "" then return formatAssetId(val) end
    end

    for _, child in ipairs(petInst:GetChildren()) do
        if child:IsA("Decal") or child:IsA("Texture") then
            if child.Texture ~= "" then return child.Texture end
        elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
            if child.Image ~= "" then return child.Image end
        elseif child:IsA("StringValue") or child:IsA("IntValue") then
            local cName = child.Name:lower()
            if cName:find("image") or cName:find("icon") or cName:find("texture") or cName:find("id") then
                if tostring(child.Value) ~= "" then return formatAssetId(child.Value) end
            end
        end
    end

    if petInst:IsA("StringValue") and tostring(petInst.Value) ~= "" then
        return formatAssetId(petInst.Value)
    end

    return ""
end

local function checkEvolved(petInst)
    local ev = petInst:FindFirstChild("evolved")
    if ev then
        if ev:IsA("ValueBase") then return ev.Value == true end
        return true
    end
    return false
end

local function checkRobuxPet(petInst)
    local rb = petInst:FindFirstChild("robuxPet")
    if rb then
        if rb:IsA("ValueBase") then return rb.Value == true or rb.Value == 1 end
        return true
    end
    return false
end

local function getPetStrength(petInst)
    local perks = petInst:FindFirstChild("perksFolder")
    if perks then
        local str = perks:FindFirstChild("strength")
        if str and str:IsA("ValueBase") then
            return tonumber(str.Value) or 0
        end
    end
    return 0
end

local function getPetLevel(petInst)
    local lvl = petInst:FindFirstChild("level")
    if lvl and lvl:IsA("ValueBase") then
        return tostring(lvl.Value)
    end
    return "1"
end

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PetViewerGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
createStroke(MainFrame, Color3.fromRGB(38, 38, 45), 1.5)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -85, 0, 32)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "PET VIEWER"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = MainFrame

-- Draggable
local dragging, dragInput, dragStart, startPos
TitleLabel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
TitleLabel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Botão Fechar (vermelho)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 40, 45)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.TextSize = 12
CloseBtn.ZIndex = 10
CloseBtn.Parent = MainFrame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
createStroke(CloseBtn, Color3.fromRGB(0, 0, 0), 1.8)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Botão Minimizar (cinza)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -54, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBlack
MinBtn.TextSize = 14
MinBtn.ZIndex = 10
MinBtn.Parent = MainFrame
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)
createStroke(MinBtn, Color3.fromRGB(0, 0, 0), 1.8)

local ControlsFrame = Instance.new("Frame")
ControlsFrame.Size = UDim2.new(0.92, 0, 0, 30)
ControlsFrame.Position = UDim2.new(0.04, 0, 0, 38)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex = 5
ControlsFrame.Parent = MainFrame

local PetScroll = Instance.new("ScrollingFrame")
PetScroll.Size = UDim2.new(0.92, 0, 0, 260)
PetScroll.Position = UDim2.new(0.04, 0, 0, 76)
PetScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
PetScroll.BorderSizePixel = 0
PetScroll.ScrollBarThickness = 3
PetScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
PetScroll.ZIndex = 5
PetScroll.Parent = MainFrame
Instance.new("UICorner", PetScroll).CornerRadius = UDim.new(0, 8)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MainFrame.Size = UDim2.new(0, 300, 0, 32)
        ControlsFrame.Visible = false
        PetScroll.Visible = false
    else
        MainFrame.Size = UDim2.new(0, 300, 0, 350)
        ControlsFrame.Visible = true
        PetScroll.Visible = true
    end
end)

-- Dropdown
local DropdownBtn = Instance.new("TextButton")
DropdownBtn.Size = UDim2.new(0.62, 0, 1, 0)
DropdownBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
DropdownBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
DropdownBtn.Font = Enum.Font.GothamMedium
DropdownBtn.TextSize = 11
DropdownBtn.Text = "  " .. (selectedPlayer and selectedPlayer.DisplayName or "Select Player")
DropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
DropdownBtn.TextTruncate = Enum.TextTruncate.AtEnd
DropdownBtn.ZIndex = 6
DropdownBtn.Parent = ControlsFrame
Instance.new("UICorner", DropdownBtn).CornerRadius = UDim.new(0, 6)
createStroke(DropdownBtn, Color3.fromRGB(48, 48, 55), 1)

-- VIEW roxo
local ViewBtn = Instance.new("TextButton")
ViewBtn.Size = UDim2.new(0.35, 0, 1, 0)
ViewBtn.Position = UDim2.new(0.65, 0, 0, 0)
ViewBtn.BackgroundColor3 = Color3.fromRGB(110, 50, 220)
ViewBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ViewBtn.Font = Enum.Font.GothamBold
ViewBtn.TextSize = 10
ViewBtn.Text = "VIEW PETS"
ViewBtn.ZIndex = 6
ViewBtn.Parent = ControlsFrame
Instance.new("UICorner", ViewBtn).CornerRadius = UDim.new(0, 6)
createStroke(ViewBtn, Color3.fromRGB(0, 0, 0), 1.5)

local DropdownList = Instance.new("ScrollingFrame")
DropdownList.Size = UDim2.new(0.57, 0, 0, 130)
DropdownList.Position = UDim2.new(0.04, 0, 0, 70)
DropdownList.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
DropdownList.BorderSizePixel = 0
DropdownList.ScrollBarThickness = 3
DropdownList.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
DropdownList.Visible = false
DropdownList.ZIndex = 50
DropdownList.Parent = MainFrame
Instance.new("UICorner", DropdownList).CornerRadius = UDim.new(0, 7)
createStroke(DropdownList, Color3.fromRGB(45, 45, 52), 1)

local DropLayout = Instance.new("UIListLayout")
DropLayout.Padding = UDim.new(0, 2)
DropLayout.Parent = DropdownList

local DropPadding = Instance.new("UIPadding")
DropPadding.PaddingTop = UDim.new(0, 4)
DropPadding.PaddingBottom = UDim.new(0, 4)
DropPadding.PaddingLeft = UDim.new(0, 4)
DropPadding.PaddingRight = UDim.new(0, 4)
DropPadding.Parent = DropdownList

DropdownBtn.MouseButton1Click:Connect(function()
    DropdownList.Visible = not DropdownList.Visible
end)

local function updateDropdown()
    for _, child in pairs(DropdownList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, plr in pairs(Players:GetPlayers()) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
        btn.TextColor3 = Color3.fromRGB(210, 210, 220)
        btn.Text = "  " .. plr.DisplayName
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.ZIndex = 51
        btn.Parent = DropdownList
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
        end)

        btn.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            DropdownBtn.Text = "  " .. plr.DisplayName
            DropdownList.Visible = false
        end)
    end
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, #Players:GetPlayers() * 28 + 8)
end
updateDropdown()
Players.PlayerAdded:Connect(updateDropdown)
Players.PlayerRemoving:Connect(updateDropdown)

-- STATUS
local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(0, 210, 0, 210)
StatusFrame.Position = UDim2.new(0.5, 165, 0.5, -105)
StatusFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
StatusFrame.Visible = false
StatusFrame.Active = true
StatusFrame.ZIndex = 20
StatusFrame.Parent = ScreenGui
Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 9)
createStroke(StatusFrame, Color3.fromRGB(45, 45, 52), 1.5)

local StatusTitle = Instance.new("TextLabel")
StatusTitle.Size = UDim2.new(1, -40, 0, 28)
StatusTitle.Position = UDim2.new(0, 10, 0, 2)
StatusTitle.BackgroundTransparency = 1
StatusTitle.Text = "Status"
StatusTitle.Font = Enum.Font.GothamBlack
StatusTitle.TextSize = 14
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.ZIndex = 21
StatusTitle.Parent = StatusFrame

local StatusClose = Instance.new("TextButton")
StatusClose.Size = UDim2.new(0, 22, 0, 22)
StatusClose.Position = UDim2.new(1, -28, 0, 4)
StatusClose.BackgroundColor3 = Color3.fromRGB(210, 40, 45)
StatusClose.Text = "X"
StatusClose.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusClose.Font = Enum.Font.GothamBlack
StatusClose.TextSize = 12
StatusClose.ZIndex = 22
StatusClose.Parent = StatusFrame
Instance.new("UICorner", StatusClose).CornerRadius = UDim.new(0, 5)
createStroke(StatusClose, Color3.fromRGB(0, 0, 0), 1.8)

StatusClose.MouseButton1Click:Connect(function()
    StatusFrame.Visible = false
end)

local StatusScroll = Instance.new("ScrollingFrame")
StatusScroll.Size = UDim2.new(1, -16, 1, -40)
StatusScroll.Position = UDim2.new(0, 8, 0, 34)
StatusScroll.BackgroundTransparency = 1
StatusScroll.ScrollBarThickness = 2
StatusScroll.ZIndex = 21
StatusScroll.Parent = StatusFrame

local StatusLayout = Instance.new("UIListLayout")
StatusLayout.Padding = UDim.new(0, 8)
StatusLayout.Parent = StatusScroll

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0, 84, 0, 112)
GridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
GridLayout.Parent = PetScroll

local GridPadding = Instance.new("UIPadding")
GridPadding.PaddingLeft = UDim.new(0, 5)
GridPadding.PaddingTop = UDim.new(0, 5)
GridPadding.Parent = PetScroll

local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Size = UDim2.new(1, -12, 1, -12)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Text = "Not Found"
EmptyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
EmptyLabel.Font = Enum.Font.GothamBlack
EmptyLabel.TextSize = 20
EmptyLabel.Visible = false
EmptyLabel.ZIndex = 6
EmptyLabel.Parent = PetScroll
createStroke(EmptyLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

-- ==================== CARREGAR PETS (lógica do 1º script) ====================
local function loadPlayerPets()
    DropdownList.Visible = false
    StatusFrame.Visible = false

    for _, child in pairs(PetScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    if not selectedPlayer or not selectedPlayer:IsDescendantOf(Players) then
        EmptyLabel.Text = "Not Found"
        EmptyLabel.Visible = true
        return
    end

    local petsFolder = selectedPlayer:FindFirstChild("petsFolder")
    if not petsFolder then
        EmptyLabel.Text = "Not Found"
        EmptyLabel.Visible = true
        return
    end

    local petList = {}

    -- Mesma lógica do primeiro script que funcionava
    for rarityName, rarityColor in pairs(ALLOWED_RARITIES) do
        local rarityFolder = petsFolder:FindFirstChild(rarityName)
        if rarityFolder then
            for _, petInst in pairs(rarityFolder:GetChildren()) do
                table.insert(petList, {
                    inst = petInst,
                    rarity = rarityName,
                    color = rarityColor,
                    isRobux = checkRobuxPet(petInst),
                    strength = getPetStrength(petInst),
                    isEvolved = checkEvolved(petInst),
                    level = getPetLevel(petInst)
                })
            end
        end
    end

    if #petList == 0 then
        EmptyLabel.Text = "Not Found"
        EmptyLabel.Visible = true
        return
    else
        EmptyLabel.Visible = false
    end

    table.sort(petList, function(a, b)
        if a.isRobux ~= b.isRobux then
            return a.isRobux
        end
        return a.strength > b.strength
    end)

    for order, petData in ipairs(petList) do
        local petInst = petData.inst

        local PetCard = Instance.new("TextButton")
        PetCard.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        PetCard.Text = ""
        PetCard.LayoutOrder = order
        PetCard.ZIndex = 7
        PetCard.Parent = PetScroll
        Instance.new("UICorner", PetCard).CornerRadius = UDim.new(0, 6)
        createStroke(PetCard, petData.color, 1.8)

        local PetImageFrame = Instance.new("Frame")
        PetImageFrame.Size = UDim2.new(1, -8, 0, 54)
        PetImageFrame.Position = UDim2.new(0, 4, 0, 4)
        PetImageFrame.BackgroundColor3 = Color3.fromRGB(11, 11, 13)
        PetImageFrame.ZIndex = 8
        PetImageFrame.Parent = PetCard
        Instance.new("UICorner", PetImageFrame).CornerRadius = UDim.new(0, 5)

        local PetImg = Instance.new("ImageLabel")
        PetImg.Size = UDim2.new(1, 0, 1, 0)
        PetImg.BackgroundTransparency = 1
        PetImg.ScaleType = Enum.ScaleType.Fit
        PetImg.Image = extractPetImage(petInst)
        PetImg.ZIndex = 9
        PetImg.Parent = PetImageFrame

        if petData.isEvolved then
            local EvLabel = Instance.new("TextLabel")
            EvLabel.Size = UDim2.new(1, 0, 0, 13)
            EvLabel.Position = UDim2.new(0, 0, 0, 2)
            EvLabel.BackgroundTransparency = 1
            EvLabel.Text = "EVOLVED"
            EvLabel.TextColor3 = Color3.fromRGB(170, 0, 255)
            EvLabel.Font = Enum.Font.GothamBlack
            EvLabel.TextSize = 8
            EvLabel.ZIndex = 10
            EvLabel.Parent = PetImageFrame
            createStroke(EvLabel, Color3.fromRGB(0, 0, 0), 1.5, Enum.ApplyStrokeMode.Contextual)
        end

        local LevelLabel = Instance.new("TextLabel")
        LevelLabel.Size = UDim2.new(1, -4, 0, 12)
        LevelLabel.Position = UDim2.new(0, 2, 0, 62)
        LevelLabel.BackgroundTransparency = 1
        LevelLabel.Text = "Level " .. petData.level
        LevelLabel.TextColor3 = petData.color
        LevelLabel.Font = Enum.Font.GothamBold
        LevelLabel.TextSize = 9
        LevelLabel.ZIndex = 9
        LevelLabel.Parent = PetCard
        createStroke(LevelLabel, Color3.fromRGB(0, 0, 0), 1.3, Enum.ApplyStrokeMode.Contextual)

        local PetName = Instance.new("TextLabel")
        PetName.Size = UDim2.new(1, -4, 0, 13)
        PetName.Position = UDim2.new(0, 2, 0, 76)
        PetName.BackgroundTransparency = 1
        PetName.Text = petInst.Name
        PetName.TextColor3 = Color3.fromRGB(235, 235, 240)
        PetName.Font = Enum.Font.GothamBold
        PetName.TextSize = 9
        PetName.TextScaled = true
        PetName.ZIndex = 9
        PetName.Parent = PetCard

        local RarityLabel = Instance.new("TextLabel")
        RarityLabel.Size = UDim2.new(1, -4, 0, 13)
        RarityLabel.Position = UDim2.new(0, 2, 0, 92)
        RarityLabel.BackgroundTransparency = 1
        RarityLabel.Text = petData.rarity
        RarityLabel.TextColor3 = petData.color
        RarityLabel.Font = Enum.Font.GothamBlack
        RarityLabel.TextSize = 9
        RarityLabel.ZIndex = 9
        RarityLabel.Parent = PetCard
        createStroke(RarityLabel, Color3.fromRGB(0, 0, 0), 1.3, Enum.ApplyStrokeMode.Contextual)

        PetCard.MouseButton1Click:Connect(function()
            for _, c in pairs(StatusScroll:GetChildren()) do
                if c:IsA("TextLabel") or c:IsA("Frame") then
                    c:Destroy()
                end
            end

            StatusTitle.Text = "Status"
            StatusTitle.TextColor3 = petData.color

            local perks = petInst:FindFirstChild("perksFolder")
            if perks then
                for _, perk in pairs(perks:GetChildren()) do
                    if perk:IsA("ValueBase") then
                        local conf = PERK_CONFIG[perk.Name:lower()]
                        if conf then
                            local row = Instance.new("Frame")
                            row.Size = UDim2.new(1, 0, 0, 22)
                            row.BackgroundTransparency = 1
                            row.ZIndex = 22
                            row.Parent = StatusScroll

                            local nameLbl = Instance.new("TextLabel")
                            nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
                            nameLbl.BackgroundTransparency = 1
                            nameLbl.Text = conf.icon .. " " .. conf.name
                            nameLbl.TextColor3 = conf.textColor
                            nameLbl.Font = Enum.Font.GothamBold
                            nameLbl.TextSize = 12
                            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                            nameLbl.ZIndex = 23
                            nameLbl.Parent = row
                            createStroke(nameLbl, conf.borderColor, 1.4, Enum.ApplyStrokeMode.Contextual)

                            local valueLbl = Instance.new("TextLabel")
                            valueLbl.Size = UDim2.new(0.45, 0, 1, 0)
                            valueLbl.Position = UDim2.new(0.55, 0, 0, 0)
                            valueLbl.BackgroundTransparency = 1
                            valueLbl.Text = formatNumber(perk.Value)
                            valueLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                            valueLbl.Font = Enum.Font.GothamBlack
                            valueLbl.TextSize = 12
                            valueLbl.TextXAlignment = Enum.TextXAlignment.Right
                            valueLbl.ZIndex = 23
                            valueLbl.Parent = row
                            createStroke(valueLbl, Color3.fromRGB(0, 0, 0), 1.4, Enum.ApplyStrokeMode.Contextual)
                        end
                    end
                end
            end

            local count = 0
            for _, c in pairs(StatusScroll:GetChildren()) do
                if c:IsA("Frame") then count = count + 1 end
            end
            StatusScroll.CanvasSize = UDim2.new(0, 0, 0, count * 30 + 4)
            StatusFrame.Visible = true
        end)
    end

    local rows = math.ceil(#petList / 3)
    PetScroll.CanvasSize = UDim2.new(0, 0, 0, (rows * 117) + 10)
end

Players.PlayerRemoving:Connect(function(plr)
    if plr == selectedPlayer then
        selectedPlayer = nil
        DropdownBtn.Text = "  Select Player"
        loadPlayerPets()
    end
    updateDropdown()
end)

ViewBtn.MouseButton1Click:Connect(loadPlayerPets)
