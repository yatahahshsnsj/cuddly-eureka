-- ==========================================
-- ROBLOX ADVANCED AIMBOT & ESP SUITE
-- Compatible with Delta, Krnl, Synapse, etc.
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- ==========================================
-- 1. CONFIGURAÇÕES (EDITA AQUI)
-- ==========================================
local Config = {
    ESP = {
        Enabled = true,
        Color = Color3.fromRGB(0, 255, 128),
        Thickness = 2,
        ShowHealth = true,
        ShowName = true,
        MaxDistance = 500, -- Yards
    },
    Aimbot = {
        Enabled = true,
        Key = Enum.KeyCode.LeftControl, -- Tecla para ativar
        FovSize = 150,
        FovColor = Color3.fromRGB(255, 255, 255),
        Smoothness = 12, -- 1 = Instant, 20 = Very Slow
        TargetPart = "Head", -- Head, HumanoidRootPart, etc.
        Silent = true, -- true = Mira interna (sem girar câmera), false = Gira câmera
        Prediction = true,
    },
    AntiDetect = {
        Jitter = 0.02, -- Micro-variação para parecer humano
        ThrottleFrames = 1, -- Atualiza a cada N frames (1 = 60fps, 2 = 30fps)
    }
}

local State = {
    activeAimbot = false,
    currentTarget = nil,
    lastUpdate = tick(),
    espRoot = nil,
    fovGui = nil,
}

-- ==========================================
-- 2. FUNÇÕES UTILITÁRIAS
-- ==========================================

local function GetWorldToScreen(position)
    local camera = workspace.CurrentCamera
    local success, screenPos = camera:WorldToViewportPoint(position)
    if not success then return nil, nil end
    return screenPos, camera:WorldToViewportPoint(position).Z
end

local function GetCharacterPart(character, partName)
    if not character then return nil end
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then return part end
    -- Fallback: qualquer BasePart se o nome específico não existir
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("BasePart") and child:Name ~= "HumanoidRootPart" then
            return child
        end
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function GetClosestTargetInFov(fovSize)
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera
    local centerPos = vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    local bestTarget = nil
    local bestDistance = fovSize

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local part = GetCharacterPart(plr.Character, Config.Aimbot.TargetPart)
                if part then
                    local screenPos, z = GetWorldToScreen(part.Position)
                    if screenPos and z > 0 then
                        local distToCenter = (screenPos - centerPos).Magnitude
                        if distToCenter < bestDistance then
                            bestDistance = distToCenter
                            bestTarget = {
                                Player = plr,
                                Part = part,
                                Distance = distToCenter
                            }
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

local function CreateFovGui()
    if State.fovGui then return end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "AimFovGui"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.Parent = game:GetService("CoreGui")

    local fovCircle = Instance.new("Frame")
    fovCircle.Name = "FovCircle"
    fovCircle.BackgroundColor3 = Config.Aimbot.FovColor
    fovCircle.BackgroundTransparency = 0.8
    fovCircle.BorderSizePixel = 0
    fovCircle.Size = UDim2.new(0, Config.Aimbot.FovSize, 0, Config.Aimbot.FovSize)
    fovCircle.Position = UDim2.new(0.5, -Config.Aimbot.FovSize/2, 0.5, -Config.Aimbot.FovSize/2)
    fovCircle.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = fovCircle

    fovCircle.Visible = false
    State.fovGui = sg
end

local function UpdateFovGui(visible)
    if not State.fovGui then return end
    local circle = State.fovGui:FindFirstChild("FovCircle")
    if circle then
        circle.Visible = visible
    end
end

-- ==========================================
-- 3. ESP SYSTEM (MANAGED BILLBOARDS)
-- ==========================================
local function UpdateESP()
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera
    
    -- Criar Root se não existir
    if not State.espRoot then
        State.espRoot = Instance.new("Folder")
        State.espRoot.Name = "_ESP_Root"
        State.espRoot.Parent = workspace
    end

    -- Limpar billboards antigos
    for _, child in pairs(State.espRoot:GetChildren()) do
        child:Destroy()
    end

    if not Config.ESP.Enabled then return end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
            local head = GetCharacterPart(plr.Character, "Head")
            
            if humanoid and humanoid.Health > 0 and head then
                local distance = (camera.CFrame.Position - head.Position).Magnitude
                if distance < Config.ESP.MaxDistance then
                    local bgui = Instance.new("BillboardGui")
                    bgui.Name = "ESP_" .. plr.Name
                    bgui.Adornee = head
                    bgui.Size = UDim2.new(0, 60, 0, 60)
                    bgui.AlwaysOnTop = true
                    bgui.Enabled = true
                    bgui.Parent = State.espRoot

                    local frame = Instance.new("Frame")
                    frame.Name = "Box"
                    frame.Size = UDim2.fromScale(1, 1)
                    frame.BackgroundColor3 = Config.ESP.Color
                    frame.BackgroundTransparency = 0.7
                    frame.BorderSizePixel = 0
                    frame.Parent = bgui

                    local stroke = Instance.new("UIStroke")
                    stroke.Color = Config.ESP.Color
                    stroke.Thickness = Config.ESP.Thickness
                    stroke.Parent = frame

                    if Config.ESP.ShowName then
                        local nameLabel = Instance.new("TextLabel")
                        nameLabel.Name = "Name"
                        nameLabel.Size = UDim2.new(1, 0, 0, 15)
                        nameLabel.Position = UDim2.new(0, 0, -0.3, 0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.Text = plr.Name
                        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        nameLabel.TextScaled = true
                        nameLabel.Font = Enum.Font.GothamBold
                        nameLabel.Parent = bgui
                    end

                    if Config.ESP.ShowHealth then
                        local healthBg = Instance.new("Frame")
                        healthBg.Name = "HealthBg"
                        healthBg.Size = UDim2.new(0, 10, 1, 0)
                        healthBg.Position = UDim2.new(-0.2, 0, 0, 0)
                        healthBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                        healthBg.BorderSizePixel = 0
                        healthBg.Parent = bgui

                        local healthFill = Instance.new("Frame")
                        healthFill.Name = "HealthFill"
                        healthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
                        healthFill.AnchorPoint = vector2.new(0, 0)
                        healthFill.BackgroundColor3 = Config.ESP.Color
                        healthFill.BorderSizePixel = 0
                        healthFill.Parent = healthBg
                    end
                end
            end
        end
    end
end

-- ==========================================
-- 4. AIMBOT LOGIC (SMOOTH & SILENT)
-- ==========================================
local function ApplyAimbot()
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera
    
    if not Config.Aimbot.Enabled or not State.activeAimbot then
        if State.currentTarget then
            State.currentTarget = nil
        end
        return
    end

    State.currentTarget = GetClosestTargetInFov(Config.Aimbot.FovSize)

    if State.currentTarget then
        local targetPart = State.currentTarget.Part
        local targetPos = targetPart.Position

        -- Predição
        if Config.Aimbot.Prediction then
            local char = State.currentTarget.Player.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local velocity = rootPart.AssemblyLinearVelocity
                local dist = (camera.CFrame.Position - targetPos).Magnitude
                local speed = velocity.Magnitude
                if speed > 0 then
                    local timeToTarget = dist / 120 -- Estimativa de velocidade do projétil
                    targetPos = targetPos + (velocity * timeToTarget)
                end
            end
        end

        local targetCFrame = CFrame.new(camera.CFrame.Position, targetPos)
        local currentCFrame = camera.CFrame

        -- Suavização (Lerp)
        local lerpFactor = 1 / Config.Aimbot.Smoothness
        
        -- Anti-Detect: Jitter
        local jitterX = (math.random() - 0.5) * Config.AntiDetect.Jitter
        local jitterY = (math.random() - 0.5) * Config.AntiDetect.Jitter
        local jitterZ = (math.random() - 0.5) * Config.AntiDetect.Jitter

        local targetPosJittered = targetPos + vector3.new(jitterX, jitterY, jitterZ)
        local targetCFrameJittered = CFrame.new(camera.CFrame.Position, targetPosJittered)

        local newCFrame = currentCFrame:Lerp(targetCFrameJittered, lerpFactor)

        if Config.Aimbot.Silent then
            -- Silent Aim: Modifica a direção do tiro sem mover a câmera visual
            -- Em jogos que usam CameraCFrame para mira, isso pode não funcionar perfeitamente,
            -- mas em 90% dos jogos Roblox, o "Shoot" usa a direção da câmera.
            -- Para Silent real, usamos um Raycast virtual ou ajustamos a câmera de forma imperceptível.
            -- Aqui usamos uma abordagem híbrida: Move a câmera levemente para garantir o hit, 
            -- mas mantém a transição suave.
            camera.CFrame = newCFrame
        else
            -- Normal Aim: Move a câmera visivelmente
            camera.CFrame = newCFrame
        end
    end
end

-- ==========================================
-- 5. MAIN LOOP
-- ==========================================
local frameCount = 0
RunService.Heartbeat:Connect(function(deltaTime)
    -- Throttling: Executa a lógica de Aim/ESP a cada N frames
    frameCount += 1
    if frameCount % Config.AntiDetect.ThrottleFrames ~= 0 then return end

    local player = Players.LocalPlayer
    if not player or not player.Character then return end

    -- Verificar tecla de Aimbot
    if Config.Aimbot.Enabled then
        State.activeAimbot = UserInputService:IsKeyDown(Config.Aimbot.Key)
    else
        State.activeAimbot = false
    end

    UpdateFovGui(State.activeAimbot)
    ApplyAimbot()
    UpdateESP()
end)

-- ==========================================
-- 6. MENU DE CONFIGURAÇÃO (GUI)
-- ==========================================
local function CreateMenu()
    local sg = Instance.new("ScreenGui")
    sg.Name = "CheatMenu"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = game:GetService("CoreGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    title.Text = "⚡ CyberHat Suite"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.BorderSizePixel = 0
    title.Parent = mainFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "OptionsScroll"
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0.5, -140, 0.5, -175)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
    scroll.ScrollBarThickness = 6
    scroll.Parent = mainFrame

    local row1 = Instance.new("Frame")
    row1.Name = "Row1"
    row1.Size = UDim2.new(1, 0, 0, 40)
    row1.BackgroundTransparency = 1
    row1.Parent = scroll

    -- Toggle ESP
    local espToggle = Instance.new("TextButton")
    espToggle.Name = "ToggleESP"
    espToggle.Size = UDim2.new(0.5, -10, 1, 0)
    espToggle.Position = UDim2.new(0, 10, 0, 0)
    espToggle.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    espToggle.Text = "ESP: ON"
    espToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    espToggle.TextScaled = true
    espToggle.Font = Enum.Font.Gotham
    espToggle.Parent = row1

    -- Toggle Aimbot
    local aimToggle = Instance.new("TextButton")
    aimToggle.Name = "ToggleAimbot"
    aimToggle.Size = UDim2.new(0.5, -10, 1, 0)
    aimToggle.Position = UDim2.new(0.5, 10, 0, 0)
    aimToggle.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    aimToggle.Text = "Aimbot: ON"
    aimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimToggle.TextScaled = true
    aimToggle.Font = Enum.Font.Gotham
    aimToggle.Parent = row1

    local row2 = Instance.new("Frame")
    row2.Name = "Row2"
    row2.Size = UDim2.new(1, 0, 0, 40)
    row2.Position = UDim2.new(0, 0, 40, 0)
    row2.BackgroundTransparency = 1
    row2.Parent = scroll

    -- Silent Toggle
    local silentToggle = Instance.new("TextButton")