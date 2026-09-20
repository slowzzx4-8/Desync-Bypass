--[[
    PET VIEWER - Versão Premium Atualizada
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = (gethui and gethui()) or game:GetService("CoreGui")

if CoreGui:FindFirstChild("PetViewerGui") then
    CoreGui.PetViewerGui:Destroy()
end

local LocalPlayer = Players.LocalPlayer
local selectedPlayer = LocalPlayer
local currentViewedPet = nil

-- Raridades (Ordem e Cores)
local ALLOWED_RARITIES = {
    ["Unique"] = Color3.fromRGB(255, 120, 0),
    ["Epic"]   = Color3.fromRGB(170, 0, 255),
    ["Rare"]   = Color3.fromRGB(0, 150, 255)
}

local function getRarityColor(rarityName)
    return ALLOWED_RARITIES[rarityName] or Color3.fromRGB(200, 200, 200)
end

-- Configuração dos Perks
local PERK_CONFIG = {
    ["strength"] = { icon = "💪", name = "Strength", hex = "FFE600", color = Color3.fromRGB(255, 230, 0) },
    ["durability"] = { icon = "🛡️", name = "Durabilidade", hex = "0096FF", color = Color3.fromRGB(0, 150, 255) },
    ["agility"] = { icon = "⚡", name = "Agilidade", hex = "00FF50", color = Color3.fromRGB(0, 255, 80) },
    ["damage"] = { icon = "⚔️", name = "Damage", hex = "FF3232", color = Color3.fromRGB(255, 50, 50) }
}

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.1fT", n / 1e12):gsub("%.0T", "T")
    elseif n >= 1e9 then return string.format("%.1fB", n / 1e9):gsub("%.0B", "B")
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6):gsub("%.0M", "M")
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3):gsub("%.0K", "K")
    else return tostring(n) end
end

local function createStroke(parent, color, thickness, mode)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 1.5
    stroke.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function formatAssetId(raw)
    raw = tostring(raw or "")
    if raw == "" then return "" end
    if tonumber(raw) then return "rbxassetid://" .. raw end
    if raw:find("rbxasset") or raw:find("http") then return raw end
    local nums = raw:match("%d+")
    if nums then return "rbxassetid://" .. nums end
    return raw
end

-- Buscador de imagem avançado
local function extractPetImage(petInst)
    if not petInst then return "" end
    
    for _, attr in ipairs({"Icon", "icon", "Thumbnail", "thumbnail", "Image", "image", "ImageId", "Texture", "TextureId"}) do
        local val = petInst:GetAttribute(attr)
        if val and tostring(val) ~= "" and tostring(val) ~= "0" then 
            return formatAssetId(val) 
        end
    end
    
    for _, desc in ipairs(petInst:GetDescendants()) do
        if desc:IsA("StringValue") or desc:IsA("IntValue") then
            local n = desc.Name:lower()
            if n == "thumbnail" or n == "icon" or n == "image" or n == "texture" or n == "imageid" then
                if tostring(desc.Value) ~= "" and tostring(desc.Value) ~= "0" then
                    return formatAssetId(desc.Value)
                end
            end
        elseif (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and desc.Image ~= "" then 
            return formatAssetId(desc.Image)
        end
    end

    for _, desc in ipairs(petInst:GetDescendants()) do
        if desc:IsA("MeshPart") and desc.TextureID ~= "" then return formatAssetId(desc.TextureID)
        elseif desc:IsA("SpecialMesh") and desc.TextureId ~= "" then return formatAssetId(desc.TextureId)
        elseif (desc:IsA("Decal") or desc:IsA("Texture")) and desc.Texture ~= "" then return formatAssetId(desc.Texture)
        end
    end
    
    return ""
end

local function getPetData(petInst)
    local isEv = petInst:FindFirstChild("evolved")
    local isRb = petInst:FindFirstChild("robuxPet")
    local lvlVal = petInst:FindFirstChild("level")
    
    local strengthVal = 0
    local perks = petInst:FindFirstChild("perksFolder")
    if perks and perks:FindFirstChild("strength") then
        strengthVal = tonumber(perks.strength.Value) or 0
    end
    
    return {
        isEvolved = isEv and (not isEv:IsA("ValueBase") or isEv.Value == true) or false,
        isRobux = isRb and (not isRb:IsA("ValueBase") or isRb.Value == true or isRb.Value == 1) or false,
        level = lvlVal and tostring(lvlVal.Value) or "1",
        strength = strengthVal
    }
end

-- ==========================================
-- GUI PRINCIPAL
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "PetViewerGui"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 310, 0, 390)
MainFrame.Position = UDim2.new(0.5, -155, 0.5, -195)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.Active = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
createStroke(MainFrame, Color3.fromRGB(35, 35, 35), 2)

local TitleLabel = Instance.new("TextLabel", MainFrame)
TitleLabel.Size = UDim2.new(1, -70, 0, 36)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "PET VIEWER"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local dragging, dragInput, dragStart, startPos
TitleLabel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
TitleLabel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local ControlsFrame = Instance.new("Frame", MainFrame)
ControlsFrame.Size = UDim2.new(0.92, 0, 0, 32)
ControlsFrame.Position = UDim2.new(0.04, 0, 0, 42)
ControlsFrame.BackgroundTransparency = 1

local PetScroll = Instance.new("ScrollingFrame", MainFrame)
PetScroll.Size = UDim2.new(0.92, 0, 0, 298)
PetScroll.Position = UDim2.new(0.04, 0, 0, 80)
PetScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
PetScroll.BorderSizePixel = 0
PetScroll.ScrollBarThickness = 2
Instance.new("UICorner", PetScroll).CornerRadius = UDim.new(0, 8)

local DropdownList = Instance.new("ScrollingFrame", MainFrame)
DropdownList.Size = UDim2.new(0.62, 0, 0, 130)
DropdownList.Position = UDim2.new(0.04, 0, 0, 78)
DropdownList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
DropdownList.BorderSizePixel = 0
DropdownList.ScrollBarThickness = 2
DropdownList.Visible = false
DropdownList.ZIndex = 30
Instance.new("UICorner", DropdownList).CornerRadius = UDim.new(0, 6)
createStroke(DropdownList, Color3.fromRGB(45, 45, 45), 1)
local DropLayout = Instance.new("UIListLayout", DropdownList)
DropLayout.Padding = UDim.new(0, 2)
Instance.new("UIPadding", DropdownList).PaddingTop = UDim.new(0, 2)

local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 35, 35)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.TextSize = 13
CloseBtn.ZIndex = 10
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
createStroke(CloseBtn, Color3.fromRGB(0, 0, 0), 2)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- STATUS GUI
local StatusFrame = Instance.new("Frame", ScreenGui)
StatusFrame.Size = UDim2.new(0, 210, 0, 275)
StatusFrame.Position = UDim2.new(0.5, 165, 0.5, -137)
StatusFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
StatusFrame.Visible = false
StatusFrame.Active = true
Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 8)
createStroke(StatusFrame, Color3.fromRGB(45, 45, 45), 2)

local StatusTitle = Instance.new("TextLabel", StatusFrame)
StatusTitle.Size = UDim2.new(1, 0, 0, 30)
StatusTitle.Position = UDim2.new(0, 0, 0, 4)
StatusTitle.BackgroundTransparency = 1
StatusTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusTitle.Font = Enum.Font.GothamBlack
StatusTitle.TextSize = 15
StatusTitle.TextXAlignment = Enum.TextXAlignment.Center

local StatusImageBg = Instance.new("Frame", StatusFrame)
StatusImageBg.Size = UDim2.new(0, 64, 0, 64)
StatusImageBg.Position = UDim2.new(0.5, -32, 0, 34)
StatusImageBg.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
Instance.new("UICorner", StatusImageBg).CornerRadius = UDim.new(0, 5)

local StatusPetImage = Instance.new("ImageLabel", StatusImageBg)
StatusPetImage.Size = UDim2.new(1, -4, 1, -4)
StatusPetImage.Position = UDim2.new(0, 2, 0, 2)
StatusPetImage.BackgroundTransparency = 1
StatusPetImage.ScaleType = Enum.ScaleType.Fit

local StatusScroll = Instance.new("ScrollingFrame", StatusFrame)
StatusScroll.Size = UDim2.new(1, -16, 1, -110)
StatusScroll.Position = UDim2.new(0, 8, 0, 105)
StatusScroll.BackgroundTransparency = 1
StatusScroll.ScrollBarThickness = 2
local StatusLayout = Instance.new("UIListLayout", StatusScroll)
StatusLayout.Padding = UDim.new(0, 6)

local MinimizeBtn = Instance.new("TextButton", MainFrame)
MinimizeBtn.Size = UDim2.new(0, 22, 0, 22)
MinimizeBtn.Position = UDim2.new(1, -54, 0, 7)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBlack
MinimizeBtn.TextSize = 16
MinimizeBtn.ZIndex = 10
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)
createStroke(MinimizeBtn, Color3.fromRGB(0, 0, 0), 2)

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    ControlsFrame.Visible = not isMinimized
    PetScroll.Visible = not isMinimized
    DropdownList.Visible = false
    StatusFrame.Visible = false
    currentViewedPet = nil
    MainFrame.Size = isMinimized and UDim2.new(0, 310, 0, 36) or UDim2.new(0, 310, 0, 390)
end)

local DropdownBtn = Instance.new("TextButton", ControlsFrame)
DropdownBtn.Size = UDim2.new(0.62, 0, 1, 0)
DropdownBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
DropdownBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
DropdownBtn.Font = Enum.Font.GothamMedium
DropdownBtn.TextSize = 11
DropdownBtn.Text = "  " .. selectedPlayer.DisplayName
DropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", DropdownBtn).CornerRadius = UDim.new(0, 6)
createStroke(DropdownBtn, Color3.fromRGB(45, 45, 45), 1)

local ViewBtn = Instance.new("TextButton", ControlsFrame)
ViewBtn.Size = UDim2.new(0.35, 0, 1, 0)
ViewBtn.Position = UDim2.new(0.65, 0, 0, 0)
ViewBtn.BackgroundColor3 = Color3.fromRGB(130, 45, 200)
ViewBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ViewBtn.Font = Enum.Font.GothamBold
ViewBtn.TextSize = 10
ViewBtn.Text = "VIEW PETS"
Instance.new("UICorner", ViewBtn).CornerRadius = UDim.new(0, 6)
createStroke(ViewBtn, Color3.fromRGB(0, 0, 0), 1)

DropdownBtn.MouseButton1Click:Connect(function() DropdownList.Visible = not DropdownList.Visible end)

local function updateDropdown()
    for _, child in pairs(DropdownList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, plr in pairs(Players:GetPlayers()) do
        local btn = Instance.new("TextButton", DropdownList)
        btn.Size = UDim2.new(1, -4, 0, 26)
        btn.Position = UDim2.new(0, 2, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Text = "  " .. plr.DisplayName
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 10
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 31
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            DropdownBtn.Text = "  " .. plr.DisplayName
            DropdownList.Visible = false
        end)
    end
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, #Players:GetPlayers() * 28)
end
updateDropdown()
Players.PlayerAdded:Connect(updateDropdown)

local GridLayout = Instance.new("UIGridLayout", PetScroll)
GridLayout.CellSize = UDim2.new(0, 86, 0, 118)
GridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
local GridPadding = Instance.new("UIPadding", PetScroll)
GridPadding.PaddingLeft = UDim.new(0, 6); GridPadding.PaddingTop = UDim.new(0, 6)

local EmptyLabel = Instance.new("TextLabel", PetScroll)
EmptyLabel.Size = UDim2.new(1, -12, 1, -12)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Text = "Not Found"
EmptyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
EmptyLabel.Font = Enum.Font.GothamBlack
EmptyLabel.TextSize = 20
EmptyLabel.Visible = false
createStroke(EmptyLabel, Color3.fromRGB(0, 0, 0), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

-- CARREGAR PETS
local function loadPlayerPets()
    DropdownList.Visible = false
    StatusFrame.Visible = false
    currentViewedPet = nil
    for _, child in pairs(PetScroll:GetChildren()) do 
        if child:IsA("TextButton") then child:Destroy() end 
    end

    if not selectedPlayer or not selectedPlayer:FindFirstChild("petsFolder") then
        EmptyLabel.Visible = true; return
    end

    local petsFolder = selectedPlayer.petsFolder
    local petList = {}

    for _, child in pairs(petsFolder:GetDescendants()) do
        if (child:IsA("Folder") or child:IsA("Model")) and (child:FindFirstChild("perksFolder") or child:FindFirstChild("level")) then
            local rarityName = child.Parent and child.Parent.Name or "Unknown"
            if ALLOWED_RARITIES[rarityName] then
                local pData = getPetData(child)
                pData.inst = child
                pData.rarity = rarityName
                pData.color = getRarityColor(rarityName)
                table.insert(petList, pData)
            end
        end
    end

    if #petList == 0 then 
        EmptyLabel.Visible = true; 
        return 
    else 
        EmptyLabel.Visible = false 
    end

    table.sort(petList, function(a, b)
        if a.isRobux ~= b.isRobux then return a.isRobux end
        return a.strength > b.strength
    end)

    for order, data in ipairs(petList) do
        local PetCard = Instance.new("TextButton", PetScroll)
        PetCard.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        PetCard.Text = ""
        PetCard.LayoutOrder = order
        PetCard.ZIndex = 3
        Instance.new("UICorner", PetCard).CornerRadius = UDim.new(0, 6)
        createStroke(PetCard, data.color, 2)

        local PetImageFrame = Instance.new("Frame", PetCard)
        PetImageFrame.Size = UDim2.new(1, -8, 0, 58)
        PetImageFrame.Position = UDim2.new(0, 4, 0, 4)
        PetImageFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        PetImageFrame.ZIndex = 4
        Instance.new("UICorner", PetImageFrame).CornerRadius = UDim.new(0, 5)
        
        local petImgUrl = extractPetImage(data.inst)
        local PetImg = Instance.new("ImageLabel", PetImageFrame)
        PetImg.Size = UDim2.new(1, 0, 1, 0)
        PetImg.BackgroundTransparency = 1
        PetImg.ScaleType = Enum.ScaleType.Fit
        PetImg.Image = petImgUrl
        PetImg.ZIndex = 5

        if data.isEvolved then
            local EvLabel = Instance.new("TextLabel", PetImageFrame)
            EvLabel.Size = UDim2.new(1, 0, 0, 14)
            EvLabel.Position = UDim2.new(0, 0, 0, 2)
            EvLabel.BackgroundTransparency = 1
            EvLabel.Text = "EVOLVED"
            EvLabel.TextColor3 = Color3.fromRGB(170, 0, 255)
            EvLabel.Font = Enum.Font.GothamBlack
            EvLabel.TextSize = 9
            EvLabel.ZIndex = 6
            createStroke(EvLabel, Color3.fromRGB(0, 0, 0), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        end

        local LevelLabel = Instance.new("TextLabel", PetCard)
        LevelLabel.Size = UDim2.new(1, -4, 0, 12)
        LevelLabel.Position = UDim2.new(0, 2, 0, 66)
        LevelLabel.BackgroundTransparency = 1
        LevelLabel.Text = "Level " .. data.level
        LevelLabel.TextColor3 = data.color
        LevelLabel.Font = Enum.Font.GothamBold
        LevelLabel.TextSize = 9
        LevelLabel.ZIndex = 4
        createStroke(LevelLabel, Color3.fromRGB(0, 0, 0), 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

        local PetName = Instance.new("TextLabel", PetCard)
        PetName.Size = UDim2.new(1, -4, 0, 14)
        PetName.Position = UDim2.new(0, 2, 0, 81)
        PetName.BackgroundTransparency = 1
        PetName.Text = data.inst.Name
        PetName.TextColor3 = Color3.fromRGB(240, 240, 240)
        PetName.Font = Enum.Font.GothamBold
        PetName.TextSize = 9
        PetName.TextScaled = true
        PetName.ZIndex = 4

        local RarityLabel = Instance.new("TextLabel", PetCard)
        RarityLabel.Size = UDim2.new(1, -4, 0, 14)
        RarityLabel.Position = UDim2.new(0, 2, 0, 98)
        RarityLabel.BackgroundTransparency = 1
        RarityLabel.Text = data.rarity
        RarityLabel.TextColor3 = data.color
        RarityLabel.Font = Enum.Font.GothamBlack
        RarityLabel.TextSize = 9
        RarityLabel.ZIndex = 4
        createStroke(RarityLabel, Color3.fromRGB(0, 0, 0), 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

        PetCard.MouseButton1Click:Connect(function()
            if StatusFrame.Visible and currentViewedPet == data.inst then
                StatusFrame.Visible = false
                currentViewedPet = nil
                return
            end
            
            currentViewedPet = data.inst
            for _, c in pairs(StatusScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            
            StatusTitle.Text = data.rarity
            StatusTitle.TextColor3 = data.color
            createStroke(StatusTitle, Color3.fromRGB(0, 0, 0), 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            
            createStroke(StatusImageBg, data.color, 2)
            StatusPetImage.Image = petImgUrl

            local perks = data.inst:FindFirstChild("perksFolder")
            local perksData = {}
            if perks then
                for _, perk in pairs(perks:GetChildren()) do
                    if perk:IsA("ValueBase") then perksData[perk.Name:lower()] = perk end
                end
            end

            local function createPerkRow(pKey, perkObj)
                local pCfg = PERK_CONFIG[pKey] or { icon = "🔹", name = pKey, color = Color3.fromRGB(200, 200, 200) }
                local val = perkObj.Value
                
                local Row = Instance.new("Frame", StatusScroll)
                Row.Size = UDim2.new(1, 0, 0, 26)
                Row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 4)
                createStroke(Row, Color3.fromRGB(40, 40, 40), 1)

                local IconLbl = Instance.new("TextLabel", Row)
                IconLbl.Size = UDim2.new(0, 26, 1, 0)
                IconLbl.BackgroundTransparency = 1
                IconLbl.Text = pCfg.icon
                IconLbl.TextSize = 14

                local NameLbl = Instance.new("TextLabel", Row)
                NameLbl.Size = UDim2.new(1, -80, 1, 0)
                NameLbl.Position = UDim2.new(0, 30, 0, 0)
                NameLbl.BackgroundTransparency = 1
                NameLbl.Text = pCfg.name
                NameLbl.TextColor3 = pCfg.color
                NameLbl.Font = Enum.Font.GothamMedium
                NameLbl.TextSize = 12
                NameLbl.TextXAlignment = Enum.TextXAlignment.Left

                local ValLbl = Instance.new("TextLabel", Row)
                ValLbl.Size = UDim2.new(0, 50, 1, 0)
                ValLbl.Position = UDim2.new(1, -55, 0, 0)
                ValLbl.BackgroundTransparency = 1
                ValLbl.Text = "+" .. formatNumber(val)
                ValLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                ValLbl.Font = Enum.Font.GothamBold
                ValLbl.TextSize = 12
                ValLbl.TextXAlignment = Enum.TextXAlignment.Right
            end

            local PERK_ORDER = {"agility", "durability", "strength", "damage"}
            for _, pKey in ipairs(PERK_ORDER) do
                if perksData[pKey] then createPerkRow(pKey, perksData[pKey]) end
            end
            for k, v in pairs(perksData) do
                if not table.find(PERK_ORDER, k) then createPerkRow(k, v) end
            end
            
            StatusScroll.CanvasSize = UDim2.new(0, 0, 0, #StatusScroll:GetChildren() * 32)
            StatusFrame.Visible = true
        end)
    end
    PetScroll.CanvasSize = UDim2.new(0, 0, 0, (math.ceil(#petList / 3) * 124) + 10)
end

ViewBtn.MouseButton1Click:Connect(loadPlayerPets)
loadPlayerPets()
