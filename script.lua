--[[
    SKYNET-INTERNAL: Combat Suite
    Funcionalidades: Aimbot (Smooth), ESP (Box/Tracer), Menu Customizado
]]

local Library = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configurações Iniciais
local Settings = {
    AimbotEnabled = false,
    AimbotSmoothness = 0.2,
    AimbotFOV = 150,
    ESPEnabled = false,
    ESPBoxes = false,
    ESPTracers = false,
    ESPColor = Color3.fromRGB(255, 0, 0)
}

-- UI Framework Simples
function Library:CreateWindow(title)
    local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Size = UDim2.new(0, 250, 0, 350)
    MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true

    local Title = Instance.new("TextLabel", MainFrame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = title
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold

    local Container = Instance.new("ScrollingFrame", MainFrame)
    Container.Size = UDim2.new(1, 0, 1, -30)
    Container.Position = UDim2.new(0, 0, 0, 30)
    Container.BackgroundTransparency = 1
    Container.CanvasSize = UDim2.new(0, 0, 2, 0)
    Container.ScrollBarThickness = 4

    local Layout = Instance.new("UIListLayout", Container)
    Layout.Padding = UDim.new(0, 5)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    return Container
end

function Library:AddToggle(parent, text, default, callback)
    local ToggleBtn = Instance.new("TextButton", parent)
    ToggleBtn.Size = UDim2.new(0, 200, 0, 30)
    ToggleBtn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 60) or Color3.fromRGB(180, 60, 60)
    ToggleBtn.Text = text .. ": " .. (default and "ON" or "OFF")
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Font = Enum.Font.Gotham
    ToggleBtn.TextSize = 14

    local state = default
    ToggleBtn.MouseButton1Click:Connect(function()
        state = not state
        ToggleBtn.Text = text .. ": " .. (state and "ON" or "OFF")
        ToggleBtn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 60) or Color3.fromRGB(180, 60, 60)
        callback(state)
    end)
end

function Library:AddSlider(parent, text, min, max, default, callback)
    local SliderFrame = Instance.new("Frame", parent)
    SliderFrame.Size = UDim2.new(0, 200, 0, 50)
    SliderFrame.BackgroundTransparency = 1

    local Label = Instance.new("TextLabel", SliderFrame)
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.Text = text .. ": " .. default
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 14

    local Bar = Instance.new("Frame", SliderFrame)
    Bar.Size = UDim2.new(1, 0, 0, 10)
    Bar.Position = UDim2.new(0, 0, 0, 25)
    Bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

    local Fill = Instance.new("Frame", Bar)
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    Fill.BorderSizePixel = 0

    local function update(input)
        local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        local value = math.floor(min + (max - min) * pos)
        Label.Text = text .. ": " .. value
        callback(value)
    end

    local dragging = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
end

-- Lógica do Aimbot
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = Settings.AimbotFOV

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                local distance = (Vector2.new(pos.X, pos.Y) - UserInputService:GetMouseLocation()).Magnitude
                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end

RunService.RenderStepped:Connect(function()
    if Settings.AimbotEnabled then
        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild("Head") then
            local targetPos = Camera:WorldToViewportPoint(target.Character.Head.Position)
            local mousePos = UserInputService:GetMouseLocation()
            
            local moveX = (targetPos.X - mousePos.X) * Settings.AimbotSmoothness
            local moveY = (targetPos.Y - mousePos.Y) * Settings.AimbotSmoothness
            
            mousemoverel(moveX, moveY) -- Requer executor que suporte mousemoverel
        end
    end
end)

-- Lógica do ESP
local ESP_Objects = {}

local function CreateESP(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Settings.ESPColor
    box.Thickness = 1
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Settings.ESPColor
    tracer.Thickness = 1

    ESP_Objects[player] = {Box = box, Tracer = tracer}
end

Players.PlayerAdded:Connect(CreateESP)
for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then CreateESP(p) end end

RunService.RenderStepped:Connect(function()
    for player, obj in pairs(ESP_Objects) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local rootPart = player.Character.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

            if onScreen and Settings.ESPEnabled then
                -- Box
                if Settings.ESPBoxes then
                    local size = (Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0)).Y - pos.Y)
                    obj.Box.Size = Vector2.new(size * 0.6, size)
                    obj.Box.Position = Vector2.new(pos.X - obj.Box.Size.X / 2, pos.Y - obj.Box.Size.Y / 2)
                    obj.Box.Visible = true
                else
                    obj.Box.Visible = false
                end

                -- Tracer
                if Settings.ESPTracers then
                    obj.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    obj.Tracer.To = Vector2.new(pos.X, pos.Y)
                    obj.Tracer.Visible = true
                else
                    obj.Tracer.Visible = false
                end
            else
                obj.Box.Visible = false
                obj.Tracer.Visible = false
            end
        else
            obj.Box.Visible = false
            obj.Tracer.Visible = false
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESP_Objects[player] then
        ESP_Objects[player].Box:Remove()
        ESP_Objects[player].Tracer:Remove()
        ESP_Objects[player] = nil
    end
end)

-- Montagem do Menu
local Menu = Library:CreateWindow("SKYNET Combat Suite")

Library:AddToggle(Menu, "Aimbot", Settings.AimbotEnabled, function(v) Settings.AimbotEnabled = v end)
Library:AddSlider(Menu, "Smoothness", 0.01, 1, Settings.AimbotSmoothness, function(v) Settings.AimbotSmoothness = v / 100 end)
Library:AddSlider(Menu, "FOV", 50, 800, Settings.AimbotFOV, function(v) Settings.AimbotFOV = v end)

Library:AddToggle(Menu, "ESP Master", Settings.ESPEnabled, function(v) Settings.ESPEnabled = v end)
Library:AddToggle(Menu, "ESP Boxes", Settings.ESPBoxes, function(v) Settings.ESPBoxes = v end)
Library:AddToggle(Menu, "ESP Tracers", Settings.ESPTracers, function(v) Settings.ESPTracers = v end)
