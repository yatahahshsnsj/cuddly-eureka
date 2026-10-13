local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- ==========================================
-- CONFIGURAÇÕES DO MENU
-- ==========================================
local Config = {
    ESP = {
        Enabled = true,
        Color = Color3.fromRGB(0, 255, 128),
        Thickness = 2,
        ShowHealth = true,
        ShowName = true,
        BoxStyle = "Cornered", -- "Cornered", "Filled", "Outline"
    },
    Aimbot = {
        Enabled = true,
        Key = "LeftControl", -- Tecla para ativar
        FovSize = 150,
        FovColor = Color3.fromRGB(255, 255, 255),
        Smoothness = 10, -- 1 = Instant, 20 = Very Slow
        TargetPart = "Head", -- Head, HumanoidRootPart, etc.
        Silent = true, -- Atira sem mover a câmera (usando raycast interno)
        Prediction = true,
    },
    AntiDetect = {
        Jitter = 0.05, -- Adiciona micro-variações para parecer humano
        Throttle = 1, -- Frames entre atualizações (1 = todo frame)
    }
}

local state = {
    activeAimbot = false,
    currentTarget = nil,
    lastUpdate = tick(),
    menuOpen = false
}

-- ==========================================
-- FUNÇÕES UTILITÁRIAS
-- ==========================================

local function GetWorldToScreen(position)
    local camera = workspace.CurrentCamera
    local success, screenPos = camera:WorldToViewportPoint(position)
    if not success then return nil, nil end
    return screenPos, camera:WorldToViewportPoint(position).Z
end

local function GetClosestVisiblePart(target, playerPos, fovSize)
    local bestPart = nil
    local bestDistance = fovSize
    local camera = workspace.CurrentCamera
    
    -- Heurística: Procura pelo Head ou HumanoidRootPart
    local parts = {}
    local targetHead = target:FindFirstChild("Head")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    
    if targetHead then table.insert(parts, targetHead) end
    if targetRoot then table.insert(parts, targetRoot) end
    
    -- Se não encontrar, usa qualquer part no modelo
    if #parts == 0 then
        for _, part in pairs(target:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
    end

    for _, part in pairs(parts) do
        if part and part:IsA("BasePart") and part:Transparency < 1 then
            local screenPos, z = GetWorldToScreen(part.Position)
            if screenPos and z > 0 then
                local center = UDim2.fromScale(0.5, 0.5)
                local viewportSize = camera.ViewportSize
                local centerPos = vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                local distanceToCenter = (screenPos - centerPos).Magnitude
                
                if distanceToCenter < bestDistance then
                    bestDistance = distanceToCenter
                    bestPart = part
                end
            end
        end
    end
    return bestPart
end

local function GetAimTarget(playerPos, fovSize)
    local closest = nil
    local closestDist = fovSize
    
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local part = GetClosestVisiblePart(plr.Character, playerPos, fovSize)
                    if part then
                        local screenPos, z = GetWorldToScreen(part.Position)
                        if screenPos and z > 0 then
                            local centerPos = vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                            local dist = (screenPos - centerPos).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closest = {
                                    Player = plr,
                                    Part = part,
                                    Distance = dist
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function DrawAimFov()
    -- Usando Canvas para o Fov Circle (mais leve que DrawingLibrary nativo em alguns clientes)
    if not _G._fovCanvas then
        local canvas = Instance.new("SurfaceGui")
        canvas.Name = "FovCanvas"
        canvas.ResetOnSpawn = false
        canvas.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        canvas.Parent = workspace.CurrentCamera
        
        local imageLabel = Instance.new("ImageLabel")
        imageLabel.Size = UDim2.fromScale(1, 1)
        imageLabel.BackgroundTransparency = 1
        imageLabel.Image = "rbxassetid://4450949378" -- Ícone de círculo simples
        imageLabel.ImageRectOffset = vector2.new(0, 0)
        imageLabel.ImageRectSize = vector2.new(100, 100)
        imageLabel.ScaleType = Enum.ScaleType.Stretch
        imageLabel.Parent = canvas
        _G._fovCanvas = canvas
        _G._fovImage = imageLabel
    end
    
    local canvas = _G._fovCanvas
    local image = _G._fovImage
    if Config.Aimbot.Enabled and state.activeAimbot then
        canvas.Enabled = true
        local size = Config.Aimbot.FovSize
        image.Size = UDim2.new(0, size * 2, 0, size * 2)
        image.Position = UDim2.new(0.5, -size, 0.5, -size)
        image.ImageColor3 = Config.Aimbot.FovColor
        image.BackgroundTransparency = 0
    else
        canvas.Enabled = false
    end
end

-- ==========================================
-- LOOP PRINCIPAL (ANTI-EXPLOIT OPTIMIZED)
-- ==========================================

local lastFrame = tick()

RunService.Heartbeat:Connect(function(deltaTime)
    -- Throttling: Evita sobrecarregar o cliente e parecer bot
    if (tick() - lastFrame) < (Config.AntiDetect.Throttle / 60) then return end
    lastFrame = tick()

    local player = Players.LocalPlayer
    if not player or not player.Character then return end
    
    local camera = workspace.CurrentCamera
    local playerPos = player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position or camera.CFrame.Position

    -- 1. ATUALIZAR ALVO
    if Config.Aimbot.Enabled then
        state.currentTarget = GetAimTarget(playerPos, Config.Aimbot.FovSize)
    else
        state.currentTarget = nil
    end

    -- 2. ESP RENDERING (Via BillboardGui dinâmico ou Canvas)
    -- Para performance, usamos um sistema de "Billboards" gerenciados manualmente
    if Config.ESP.Enabled then
        -- Limpar billboards antigos
        if not workspace:FindFirstChild("_ESP_Root") then
            local root = Instance.new("Folder")
            root.Name = "_ESP_Root"
            root.Parent = workspace
        else
            local root = workspace["_ESP_Root"]
            for _, child in pairs(root:GetChildren()) do
                child:Destroy()
            end
        end

        local root = workspace["_ESP_Root"]

        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
                local head = plr.Character:FindFirstChild("Head")
                
                if humanoid and humanoid.Health > 0 and head then
                    local screenPos, z = GetWorldToScreen(head.Position)
                    if screenPos and z > 0 then
                        -- Criar BillboardGui
                        local bgui = Instance.new("BillboardGui")
                        bgui.Name = "ESP_" .. plr.Name
                        bgui.Adornee = head
                        bgui.Size = UDim2.new(0, 50, 0, 50)
                        bgui.AlwaysOnTop = true
                        bgui.Enabled = true
                        bgui.Parent = root

                        local frame = Instance.new("Frame")
                        frame.Name = "Box"
                        frame.Size = UDim2.fromScale(1, 1)
                        frame.BackgroundColor3 = Config.ESP.Color
                        frame.BackgroundTransparency = 0.5
                        frame.BorderSizePixel = 0
                        frame.Parent = bgui

                        -- Bordas (Canto)
                        local borderTL = Instance.new("Frame")
                        borderTL.Size = UDim2.new(0.1, 0, 0.1, 0)
                        borderTL.Position = UDim2.new(0, 0, 0, 0)
                        borderTL.BackgroundColor3 = Config.ESP.Color
                        borderTL.BorderSizePixel = 0
                        borderTL.Parent = frame
                        
                        -- Simplificação: Usando apenas um frame transparente com borda via UICorner futuro
                        -- Para manter o código curto, usamos um Frame principal e UICorner
                        local corner = Instance.new("UICorner")
                        corner.CornerRadius = UDim.new(0, 4)
                        corner.Parent = frame
                        
                        local stroke = Instance.new("UIStroke")
                        stroke.Color = Config.ESP.Color
                        stroke.Thickness = Config.ESP.Thickness
                        stroke.Parent = frame

                        -- Nome
                        if Config.ESP.ShowName then
                            local nameLabel = Instance.new("TextLabel")
                            nameLabel.Name = "Name"
                            nameLabel.Size = UDim2.fromScale(1, 0.2)
                            nameLabel.Position = UDim2.new(0, 0, -0.25, 0)
                            nameLabel.BackgroundTransparency = 1
                            nameLabel.Text = plr.Name
                            nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
                            nameLabel.TextScaled = true
                            nameLabel.Font = Enum.Font.GothamBold
                            nameLabel.Parent = bgui
                        end
                        
                        -- Health Bar
                        if Config.ESP.ShowHealth then
                            local healthBg = Instance.new("Frame")
                            healthBg.Name = "HealthBg"
                            healthBg.Size = UDim2.new(0.1, 0, 1, 0)
                            healthBg.Position = UDim2.new(-0.1, 0, 0, 0)
                            healthBg.BackgroundColor3 = Color3.fromRGB(50,50,50)
                            healthBg.BorderSizePixel = 0
                            healthBg.Parent = bgui

                            local healthFill = Instance.new("Frame")
                            healthFill.Name = "HealthFill"
                            healthFill.Size = UDim2.fromScale(humanoid.Health / humanoid.MaxHealth, 1)
                            healthFill.AnchorPoint = vector2.new(0, 0)
                            healthFill.BackgroundColor3 = Config.ESP.Color
                            healthFill.BorderSizePixel = 0
                            healthFill.Parent = healthBg
                        end
                    end
                end
            end
        end
    else
        local root = workspace:FindFirstChild("_ESP_Root")
        if root then root:Destroy() end
    end

    -- 3. AIMBOT LOGIC
    if Config.Aimbot.Enabled and state.activeAimbot and state.currentTarget then
        local target = state.currentTarget
        local targetPos = target.Part.Position
        
        -- Predição simples baseada em velocidade
        if Config.Aimbot.Prediction then
            local char = target.Player.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local velocity = rootPart.AssemblyLinearVelocity
                local distance = (camera.CFrame.Position - targetPos).Magnitude
                local speed = velocity.Magnitude
                if speed > 0 then
                    local timeToTarget = distance / 100 -- Estimativa de velocidade da bala
                    targetPos = targetPos + (velocity * timeToTarget)
                end
            end
        end

        local targetCF = CFrame.new(camera.CFrame.Position, targetPos)
        local currentCF = camera.CFrame
        
        -- Suavização (Lerp)
        local lerpFactor = 1 / Config.Aimbot.Smoothness
        -- Adiciona jitter anti-detect
        local jitter = (math.random() - 0.5) * Config.AntiDetect.Jitter
        local finalLerp = l