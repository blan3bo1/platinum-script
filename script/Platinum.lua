local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local FLY_TOGGLE_KEY = Enum.KeyCode.F
local UP_KEY = Enum.KeyCode.Space
local DOWN_KEY = Enum.KeyCode.LeftShift

local flySpeed = 50
local flySmoothing = 2.4
local enabled = false

local hrp = nil
local humanoid = nil
local velocity = Vector3.new(0,0,0)

-- UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "FlyToggle"
toggleButton.Size = UDim2.new(0,110,0,40)
toggleButton.Position = UDim2.new(0,10,0,10)
toggleButton.Text = "Fly: Off (F)"
toggleButton.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
toggleButton.Parent = screenGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(0,110,0,18)
statusLabel.Position = UDim2.new(0,10,0,52)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
statusLabel.TextScaled = false
statusLabel.Text = "Disabled"
statusLabel.Parent = screenGui

-- Up button
local upButton = Instance.new("TextButton")
upButton.Name = "UpButton"
upButton.Size = UDim2.new(0,110,0,30)
upButton.Position = UDim2.new(0,10,0,75)
upButton.Text = "▲ Up"
upButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
upButton.TextColor3 = Color3.fromRGB(255,255,255)
upButton.Parent = screenGui

-- Down button
local downButton = Instance.new("TextButton")
downButton.Name = "DownButton"
downButton.Size = UDim2.new(0,110,0,30)
downButton.Position = UDim2.new(0,10,0,110)
downButton.Text = "▼ Down"
downButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
downButton.TextColor3 = Color3.fromRGB(255,255,255)
downButton.Parent = screenGui

-- state trackers
local uiUpPressed = false
local uiDownPressed = false

local function updateUI()
    toggleButton.Text = enabled and "Fly: On (F)" or "Fly: Off (F)"
    statusLabel.Text = enabled and "Enabled" or "Disabled"
    toggleButton.BackgroundColor3 = enabled and Color3.fromRGB(40,120,40) or Color3.fromRGB(50,50,50)
end

local function setupCharacter(char)
    if not char then
        humanoid = nil
        hrp = nil
        return
    end

    humanoid = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
    if hrp then
        velocity = hrp.AssemblyLinearVelocity or Vector3.new(0,0,0)
    else
        velocity = Vector3.new(0,0,0)
    end

    enabled = false
    if humanoid then
        humanoid.PlatformStand = false
    end
    updateUI()
end

if player.Character then
    setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

local function toggleFly()
    if not hrp or not humanoid then return end
    enabled = not enabled
    if enabled then
        humanoid.PlatformStand = true
        velocity = Vector3.new(0,0,0)
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
    else
        humanoid.PlatformStand = false
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end)
    end
    updateUI()
end

toggleButton.MouseButton1Click:Connect(toggleFly)

-- UI up/down press detection
upButton.MouseButton1Down:Connect(function() uiUpPressed = true end)
upButton.MouseButton1Up:Connect(function() uiUpPressed = false end)
upButton.MouseLeave:Connect(function() uiUpPressed = false end)

downButton.MouseButton1Down:Connect(function() uiDownPressed = true end)
downButton.MouseButton1Up:Connect(function() uiDownPressed = false end)
downButton.MouseLeave:Connect(function() uiDownPressed = false end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == FLY_TOGGLE_KEY then
        toggleFly()
    end
end)

Players.LocalPlayer:GetPropertyChangedSignal("Character"):Connect(function()
    updateUI()
end)

-- Movement loop
RunService.RenderStepped:Connect(function(dt)
    if not enabled or not hrp or not humanoid then return end

    -- combine keyboard + UI button vertical input
    local liveVertical = ((UserInputService:IsKeyDown(UP_KEY) or uiUpPressed) and 1 or 0)
                       - ((UserInputService:IsKeyDown(DOWN_KEY) or uiDownPressed) and 1 or 0)

    local moveDir = humanoid.MoveDirection or Vector3.new(0,0,0)
    local horiz = Vector3.new(moveDir.X, 0, moveDir.Z)
    local vert = Vector3.new(0, liveVertical, 0)
    local target = (horiz + vert) * flySpeed

    local t = math.clamp(flySmoothing * dt, 0, 1)
    velocity = velocity:Lerp(target, t)

    if hrp then
        pcall(function()
            hrp.AssemblyLinearVelocity = velocity
        end)
    end
end)
