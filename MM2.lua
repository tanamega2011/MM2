local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local lp = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

local farmActive = false
local lastSpeed = 0 
local tweenSpeed = 25
local currentTween = nil
local currentTargetCoin = nil 
local count = 0 
local isWarping = false
local walkFlingEnabled = false
local hiddenGuis = {}
local blackActive = false
local ignoreCoins = {} 

lp.CharacterAdded:Connect(function()
    count = 0 
    table.clear(ignoreCoins)
end)

lp.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local mainGui = Instance.new("ScreenGui")
mainGui.Name = "CustomFarmUI"
mainGui.ResetOnSpawn = false
mainGui.IgnoreGuiInset = true
mainGui.Parent = playerGui

local blackScreenFrame = Instance.new("Frame")
blackScreenFrame.Name = "BlackScreenOverlay"
blackScreenFrame.Size = UDim2.new(1, 0, 1, 0)
blackScreenFrame.Position = UDim2.new(0, 0, 0, 0)
blackScreenFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blackScreenFrame.Active = true 
blackScreenFrame.Visible = false
blackScreenFrame.ZIndex = 0 
blackScreenFrame.Parent = mainGui

local toggleGuiBtn = Instance.new("TextButton")
toggleGuiBtn.Name = "ToggleMenu"
toggleGuiBtn.Size = UDim2.new(0, 40, 0, 40)
toggleGuiBtn.Position = UDim2.new(0, 10, 0.5, -20)
toggleGuiBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
toggleGuiBtn.Text = "T"
toggleGuiBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
toggleGuiBtn.Font = Enum.Font.SourceSansBold
toggleGuiBtn.TextSize = 20
toggleGuiBtn.Active = true
toggleGuiBtn.ZIndex = 10
toggleGuiBtn.Parent = mainGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(1, 0)
btnCorner.Parent = toggleGuiBtn

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 180, 0, 110)
mainFrame.Position = UDim2.new(0.5, -90, 0.5, -55)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.2
mainFrame.Visible = true
mainFrame.Active = true 
mainFrame.ZIndex = 5
mainFrame.Parent = mainGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 15)
frameCorner.Parent = mainFrame

local farmBtn = Instance.new("TextButton")
farmBtn.Size = UDim2.new(0, 150, 0, 35)
farmBtn.Position = UDim2.new(0.5, -75, 0, 15)
farmBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
farmBtn.Text = "Farmcoin : OFF"
farmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
farmBtn.Font = Enum.Font.SourceSansLight
farmBtn.TextSize = 18
farmBtn.ZIndex = 6
farmBtn.Parent = mainFrame
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 10)

local blackBtn = Instance.new("TextButton")
blackBtn.Size = UDim2.new(0, 150, 0, 35)
blackBtn.Position = UDim2.new(0.5, -75, 0, 60)
blackBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
blackBtn.Text = "Black Screen : OFF"
blackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
blackBtn.Font = Enum.Font.SourceSansLight
blackBtn.TextSize = 18
blackBtn.ZIndex = 6
blackBtn.Parent = mainFrame
Instance.new("UICorner", blackBtn).CornerRadius = UDim.new(0, 10)

local function setupDraggable(obj)
    local dragging = false
    local dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    obj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = obj.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    obj.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

setupDraggable(toggleGuiBtn) 
setupDraggable(mainFrame)    

local function getGameStatus()
    local refPos = Vector3.new(15, 0, -25) 
    local playersFar = 0
    local myDist = 0
    local amAlive = false
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") then
        if lp.Character.Humanoid.Health > 0 then
            amAlive = true
            local myPos = lp.Character.HumanoidRootPart.Position
            myDist = (Vector3.new(myPos.X, 0, myPos.Z) - refPos).Magnitude
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") then
            if p.Character.Humanoid.Health > 0 then
                local pos = p.Character.HumanoidRootPart.Position
                local dist = (Vector3.new(pos.X, 0, pos.Z) - refPos).Magnitude
                if dist >= 500 then
                    playersFar = playersFar + 1
                end
            end
        end
    end
    return (playersFar == 0), (playersFar >= 2), (amAlive and myDist < 500), (amAlive and myDist >= 500)
end

local function getTargetWithKnife(checkSelf)
    local targetList = checkSelf and {lp} or Players:GetPlayers()
    local knifeAreaPos = Vector3.new(0, 0, 9000)
    for _, p in ipairs(targetList) do
        if checkSelf or p ~= lp then
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pPos = hrp.Position
                local distFromArea = (Vector3.new(pPos.X, 0, pPos.Z) - knifeAreaPos).Magnitude
                if distFromArea <= 250 then
                    local hasKnife = false
                    for _, v in ipairs(char:GetChildren()) do
                        if string.lower(v.Name) == "knife" then hasKnife = true break end
                    end
                    if not hasKnife and p:FindFirstChild("Backpack") then
                        for _, v in ipairs(p.Backpack:GetChildren()) do
                            if string.lower(v.Name) == "knife" then hasKnife = true break end
                        end
                    end
                    if hasKnife then return p end
                end
            end
        end
    end
    return nil
end

local function warpFunction()
    if isWarping then return end
    local target = getTargetWithKnife(false)
    local startWait = tick()
    if not target then
        repeat 
            task.wait(1)
            target = getTargetWithKnife(false)
        until target or not farmActive or (tick() - startWait > 15)
    end
    if not farmActive or not target then return end
    isWarping = true
    if lp.Character and lp.Character:FindFirstChild("Humanoid") and lp.Character.Humanoid.Health > 0 then
        lp.Character.Humanoid.Health = 0
    end
    while farmActive do
        target = getTargetWithKnife(false)
        if not target or not target.Character or not target.Character:FindFirstChild("Humanoid") or target.Character.Humanoid.Health <= 0 then
            break 
        end
        if not lp.Character or not lp.Character:FindFirstChild("Humanoid") or lp.Character.Humanoid.Health <= 0 then
            walkFlingEnabled = false
            lp.CharacterAdded:Wait(10)
            local char = lp.Character or lp.CharacterAdded:Wait(2)
            if char then
                char:WaitForChild("HumanoidRootPart", 5)
                task.wait(0.5)
            end
        end
        walkFlingEnabled = true 
        local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and myRoot then
            myRoot.Velocity = Vector3.new(0, 0, 0)
            local targetVelocity = targetRoot.Velocity
            local yawAngle = (tick() * 180) % 360 
            local moveSpeed = Vector3.new(targetVelocity.X, 0, targetVelocity.Z).Magnitude
            local basePos = targetRoot.Position
            if moveSpeed > 1 then
                local moveDirection = Vector3.new(targetVelocity.X, 0, targetVelocity.Z).Unit
                basePos = targetRoot.Position + (moveDirection * 2.5)
            end
            myRoot.CFrame = CFrame.new(basePos) * CFrame.Angles(0, math.rad(yawAngle), 0) * CFrame.Angles(math.rad(-90), 0, 0)
        end
        task.wait()
    end
    walkFlingEnabled = false 
    isWarping = false
end

RunService.Heartbeat:Connect(function()
    if walkFlingEnabled and farmActive then
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local oldV = hrp.Velocity
            hrp.Velocity = oldV * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait()
            hrp.Velocity = oldV
        end
    end
end)

RunService.Stepped:Connect(function()
    if farmActive and lp.Character then
        if walkFlingEnabled then
            for _, v in pairs(lp.Character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false v.Massless = true end
            end
        else
            for _, v in pairs(lp.Character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
            local root = lp.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

local function getNearestCoin()
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest = nil  
    local shortest = 500
    for _, v in pairs(workspace:GetDescendants()) do  
        if v:IsA("BasePart") and (v.Name:lower():find("coin") or v.Name == "Coin_Server") and not ignoreCoins[v] then  
            if v.Transparency == 0 and v.Parent then  
                local dist = (v.Position - root.Position).Magnitude  
                if dist < shortest then  
                    shortest = dist  
                    nearest = v  
                end  
            end  
        end  
    end  
    return nearest
end

local function tweenToCoin(coin)
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or not coin.Parent then return end
    local newSpeed
    repeat
        newSpeed = math.random(20, 25)
    until newSpeed ~= lastSpeed
    lastSpeed = newSpeed
    tweenSpeed = newSpeed
    hum.PlatformStand = true  
    hum.AutoRotate = false  
    local direction = (coin.Position - root.Position).Unit  
    local targetPos = coin.Position + (direction * 0.5)  
    local distance = (root.Position - targetPos).Magnitude  
    if currentTween then currentTween:Cancel() end  
    currentTween = TweenService:Create(root, TweenInfo.new(distance / tweenSpeed, Enum.EasingStyle.Linear), {  
        CFrame = CFrame.new(targetPos, targetPos + direction)  
    })  
    local coinCheck
    coinCheck = RunService.Heartbeat:Connect(function()
        if not coin or not coin.Parent or not farmActive then
            if currentTween then currentTween:Cancel() end
            coinCheck:Disconnect()
        end
    end)
    local connection
    connection = currentTween.Completed:Connect(function(state)
        if coinCheck then coinCheck:Disconnect() end
        if state == Enum.PlaybackState.Completed then
            count = count + 1
            ignoreCoins[coin] = true 
        end
        connection:Disconnect()
    end)
    currentTween:Play()
end

task.spawn(function()
    while true do
        task.wait() 
        if farmActive and not isWarping then
            local gameNotStarted, gameStarted, amNotInGame, amInGame = getGameStatus()
            if amNotInGame and gameStarted then
                warpFunction()
            else
                local coin = getNearestCoin()
                if coin then
                    if coin ~= currentTargetCoin then
                        currentTargetCoin = coin
                        tweenToCoin(coin)
                    end
                elseif amInGame then
                    currentTargetCoin = nil
                    if count > 10 then
                        local myKnife = getTargetWithKnife(true)
                        if myKnife == lp then
                            if lp.Character and lp.Character:FindFirstChild("Humanoid") then
                                lp.Character.Humanoid.Health = 0
                            end
                        else
                            warpFunction()
                        end
                    end
                else
                    currentTargetCoin = nil
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if blackActive then
            for _, v in ipairs(playerGui:GetChildren()) do
                if v:IsA("ScreenGui") and v.Name ~= "CustomFarmUI" and v.Enabled == true then
                    v.Enabled = false
                    local alreadyStored = false
                    for _, stored in ipairs(hiddenGuis) do
                        if stored == v then alreadyStored = true break end
                    end
                    if not alreadyStored then table.insert(hiddenGuis, v) end
                end
            end
        end
    end
end)

toggleGuiBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

farmBtn.MouseButton1Click:Connect(function()
    farmActive = not farmActive
    if farmActive then table.clear(ignoreCoins) end 
    farmBtn.Text = farmActive and "Farmcoin : ON" or "Farmcoin : OFF"
    farmBtn.BackgroundColor3 = farmActive and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(200, 0, 0)
    if not farmActive then
        currentTargetCoin = nil
        if currentTween then currentTween:Cancel() end
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum.AutoRotate = true
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end)

blackBtn.MouseButton1Click:Connect(function()
    blackActive = not blackActive
    blackBtn.Text = blackActive and "Black Screen : ON" or "Black Screen : OFF"
    blackBtn.BackgroundColor3 = blackActive and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(200, 0, 0)
    blackScreenFrame.Visible = blackActive
    if blackActive then
        RunService:Set3dRenderingEnabled(false)
        for _, v in pairs(playerGui:GetChildren()) do
            if v:IsA("ScreenGui") and v.Name ~= "CustomFarmUI" and v.Enabled then
                table.insert(hiddenGuis, v)
                v.Enabled = false
            end
        end
    else
        RunService:Set3dRenderingEnabled(true)
        for _, gui in pairs(hiddenGuis) do
            if gui and gui.Parent then
                gui.Enabled = true
            end
        end
        table.clear(hiddenGuis)
    end
end)
