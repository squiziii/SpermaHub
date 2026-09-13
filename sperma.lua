-- SpermaHub v6 | Fly + Noclip + Watermark + Sound
-- F=Fly | N=Noclip | P=Watermark | RightShift=свернуть | ✕=выгрузить

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local SS = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local LP = Players.LocalPlayer

-- Очистка
for _, n in ipairs({"SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle"}) do
    local o = LP.PlayerGui:FindFirstChild(n)
    if o then o:Destroy() end
end

-- Состояние
local S = {
    flying=false, noclip=false, speed=50, min=false,
    guiOpen=true, wmOn=true,
    bv=nil, bg=nil, flyConn=nil, noclipConn=nil,
    fps=60, ping=0
}

local EXP = UDim2.new(0,240,0,230)
local MIN = UDim2.new(0,240,0,38)

-- ============ ЗВУК ============
local soundDone = false
local function playSound()
    if soundDone then return end
    soundDone = true
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://6895079853"
        s.Volume = 0.5
        s.Parent = SS
        s:Play()
        Debris:AddItem(s, 4)
    end)
end
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    playSound()
end)

-- ============ ГЛАВНОЕ ОКНО ============
local SG = Instance.new("ScreenGui")
SG.Name = "SpermaHub"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.Parent = LP:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,0,0,0)
Main.Position = UDim2.new(0.5,0,0.5,0)
Main.AnchorPoint = Vector2.new(0.5,0.5)
Main.BackgroundColor3 = Color3.fromRGB(20,20,28)
Main.BackgroundTransparency = 1
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.ClipsDescendants = true
Main.Parent = SG

local MC = Instance.new("UICorner")
MC.CornerRadius = UDim.new(0,12)
MC.Parent = Main

local MS = Instance.new("UIStroke")
MS.Color = Color3.fromRGB(180,40,200)
MS.Thickness = 2
MS.Transparency = 1
MS.Parent = Main

-- Заголовок
local H = Instance.new("Frame")
H.Size = UDim2.new(1,0,0,38)
H.BackgroundColor3 = Color3.fromRGB(35,25,45)
H.BorderSizePixel = 0
H.Parent = Main

local HC = Instance.new("UICorner")
HC.CornerRadius = UDim.new(0,12)
HC.Parent = H

local HF = Instance.new("Frame")
HF.Size = UDim2.new(1,0,0,12)
HF.Position = UDim2.new(0,0,1,-12)
HF.BackgroundColor3 = Color3.fromRGB(35,25,45)
HF.BorderSizePixel = 0
HF.Parent = H

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,-80,1,0)
Title.Position = UDim2.new(0,14,0,0)
Title.BackgroundTransparency = 1
Title.Text = "SpermaHub"
Title.TextColor3 = Color3.fromRGB(230,130,255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = H

-- Кнопка сворачивания
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0,24,0,24)
MinBtn.Position = UDim2.new(1,-62,0.5,-12)
MinBtn.BackgroundColor3 = Color3.fromRGB(80,100,150)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.Parent = H

local MinC = Instance.new("UICorner")
MinC.CornerRadius = UDim.new(0,6)
MinC.Parent = MinBtn

-- Кнопка закрытия
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,24,0,24)
CloseBtn.Position = UDim2.new(1,-32,0.5,-12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,50,80)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = H

local CC = Instance.new("UICorner")
CC.CornerRadius = UDim.new(0,6)
CC.Parent = CloseBtn

-- Контейнер
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,0,1,-38)
Content.Position = UDim2.new(0,0,0,38)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- ============ КРУГЛАЯ КНОПКА ============
local TG = Instance.new("ScreenGui")
TG.Name = "SpermaHubToggle"
TG.ResetOnSpawn = false
TG.IgnoreGuiInset = true
TG.DisplayOrder = 101
TG.Parent = LP:WaitForChild("PlayerGui")

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0,50,0,50)
ToggleBtn.Position = UDim2.new(0,15,0.5,-25)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(35,25,45)
ToggleBtn.Text = "S"
ToggleBtn.TextColor3 = Color3.fromRGB(230,130,255)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 24
ToggleBtn.AutoButtonColor = false
ToggleBtn.Active = true
ToggleBtn.Draggable = true
ToggleBtn.Parent = TG

local TC = Instance.new("UICorner")
TC.CornerRadius = UDim.new(1,0)
TC.Parent = ToggleBtn

local TS = Instance.new("UIStroke")
TS.Color = Color3.fromRGB(180,40,200)
TS.Thickness = 2
TS.Transparency = 0.2
TS.Parent = ToggleBtn

-- Пульсация
task.spawn(function()
    while ToggleBtn.Parent do
        TweenService:Create(TS, TweenInfo.new(1.2), {Transparency=0.7}):Play()
        task.wait(1.2)
        if not ToggleBtn.Parent then break end
        TweenService:Create(TS, TweenInfo.new(1.2), {Transparency=0.1}):Play()
        task.wait(1.2)
    end
end)

-- ============ КНОПКИ ============
local function mkBtn(text, y, col, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9,0,0,34)
    b.Position = UDim2.new(0.05,0,0,y)
    b.BackgroundColor3 = col
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,8)
    c.Parent = b
    return b
end

local FlyBtn = mkBtn("✈  FLY: ВЫКЛ", 10, Color3.fromRGB(45,45,70), Content)
local NoclipBtn = mkBtn("👻  NOCLIP: ВЫКЛ", 50, Color3.fromRGB(45,45,70), Content)
local WmBtn = mkBtn("📊  WATERMARK: ВКЛ", 90, Color3.fromRGB(45,90,70), Content)

-- Ползунок
local SpdLabel = Instance.new("TextLabel")
SpdLabel.Size = UDim2.new(0.9,0,0,16)
SpdLabel.Position = UDim2.new(0.05,0,0,134)
SpdLabel.BackgroundTransparency = 1
SpdLabel.Text = "Скорость полёта: 50"
SpdLabel.TextColor3 = Color3.fromRGB(200,200,220)
SpdLabel.Font = Enum.Font.GothamMedium
SpdLabel.TextSize = 12
SpdLabel.TextXAlignment = Enum.TextXAlignment.Left
SpdLabel.Parent = Content

local Slider = Instance.new("Frame")
Slider.Size = UDim2.new(0.9,0,0,16)
Slider.Position = UDim2.new(0.05,0,0,154)
Slider.BackgroundColor3 = Color3.fromRGB(40,40,55)
Slider.BorderSizePixel = 0
Slider.Parent = Content

local SlC = Instance.new("UICorner")
SlC.CornerRadius = UDim.new(0,8)
SlC.Parent = Slider

local SlFill = Instance.new("Frame")
SlFill.Size = UDim2.new(0.2,0,1,0)
SlFill.BackgroundColor3 = Color3.fromRGB(180,60,220)
SlFill.BorderSizePixel = 0
SlFill.Parent = Slider

local SlFC = Instance.new("UICorner")
SlFC.CornerRadius = UDim.new(0,8)
SlFC.Parent = SlFill

local Hint = Instance.new("TextLabel")
Hint.Size = UDim2.new(0.9,0,0,14)
Hint.Position = UDim2.new(0.05,0,0,174)
Hint.BackgroundTransparency = 1
Hint.Text = "WASD · Space↑ · Ctrl↓ · F=fly · N=noclip"
Hint.TextColor3 = Color3.fromRGB(140,140,160)
Hint.Font = Enum.Font.Gotham
Hint.TextSize = 10
Hint.Parent = Content

-- ============ WATERMARK ============
local WG = Instance.new("ScreenGui")
WG.Name = "SpermaHubWatermark"
WG.ResetOnSpawn = false
WG.IgnoreGuiInset = true
WG.DisplayOrder = 100
WG.Parent = LP:WaitForChild("PlayerGui")

local WM = Instance.new("Frame")
WM.Size = UDim2.new(0,280,0,38)
WM.Position = UDim2.new(0,-300,0,12)
WM.BackgroundColor3 = Color3.fromRGB(20,20,28)
WM.BackgroundTransparency = 0.15
WM.BorderSizePixel = 0
WM.Active = true
WM.Draggable = true
WM.Parent = WG

local WMC = Instance.new("UICorner")
WMC.CornerRadius = UDim.new(0,8)
WMC.Parent = WM

local WMS = Instance.new("UIStroke")
WMS.Color = Color3.fromRGB(180,40,200)
WMS.Thickness = 1.5
WMS.Transparency = 0.3
WMS.Parent = WM

local WMLabel = Instance.new("TextLabel")
WMLabel.Size = UDim2.new(1,-20,1,0)
WMLabel.Position = UDim2.new(0,16,0,0)
WMLabel.BackgroundTransparency = 1
WMLabel.Text = "SpermaHub | FPS: -- | Ping: --ms"
WMLabel.TextColor3 = Color3.fromRGB(230,200,255)
WMLabel.Font = Enum.Font.GothamBold
WMLabel.TextSize = 14
WMLabel.TextXAlignment = Enum.TextXAlignment.Left
WMLabel.Parent = WM

local WMDot = Instance.new("Frame")
WMDot.Size = UDim2.new(0,8,0,8)
WMDot.Position = UDim2.new(0,5,0.5,-4)
WMDot.BackgroundColor3 = Color3.fromRGB(80,220,120)
WMDot.BorderSizePixel = 0
WMDot.Parent = WM

local WMDC = Instance.new("UICorner")
WMDC.CornerRadius = UDim.new(1,0)
WMDC.Parent = WMDot

-- FPS
task.spawn(function()
    local f, last = 0, tick()
    RunService.RenderStepped:Connect(function()
        f = f + 1
        local now = tick()
        if now - last >= 1 then
            S.fps = f
            f = 0
            last = now
        end
    end)
end)

-- Ping
task.spawn(function()
    while WG.Parent do
        if WM.Parent and S.wmOn then
            local p = 0
            pcall(function()
                p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            S.ping = p
            local dc = p < 80 and Color3.fromRGB(80,220,120) or (p < 150 and Color3.fromRGB(240,200,60) or Color3.fromRGB(240,70,70))
            WMDot.BackgroundColor3 = dc
            local fc = S.fps >= 50 and Color3.fromRGB(200,255,200) or (S.fps >= 30 and Color3.fromRGB(255,240,160) or Color3.fromRGB(255,160,160))
            WMLabel.Text = string.format("SpermaHub | FPS: %d | Ping: %dms", S.fps, S.ping)
            WMLabel.TextColor3 = fc
        end
        task.wait(0.5)
    end
end)

-- ============ ТОСТ ============
local TstG = Instance.new("ScreenGui")
TstG.Name = "SpermaHubToast"
TstG.ResetOnSpawn = false
TstG.IgnoreGuiInset = true
TstG.DisplayOrder = 999
TstG.Parent = LP:WaitForChild("PlayerGui")

local Toast = Instance.new("TextLabel")
Toast.Size = UDim2.new(0,320,0,60)
Toast.Position = UDim2.new(0.5,-160,0.15,-100)
Toast.BackgroundColor3 = Color3.fromRGB(30,20,40)
Toast.BackgroundTransparency = 0.05
Toast.Text = "✅ Скрипт активирован!"
Toast.TextColor3 = Color3.fromRGB(230,130,255)
Toast.Font = Enum.Font.GothamBold
Toast.TextSize = 20
Toast.BorderSizePixel = 0
Toast.Parent = TstG

local TstC = Instance.new("UICorner")
TstC.CornerRadius = UDim.new(0,12)
TstC.Parent = Toast

-- ============ FLY ============
local function startFly()
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    S.flying = true
    
    S.bv = Instance.new("BodyVelocity")
    S.bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    S.bv.Velocity = Vector3.zero
    S.bv.Parent = root
    
    S.bg = Instance.new("BodyGyro")
    S.bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
    S.bg.P = 10000
    S.bg.D = 200
    S.bg.Parent = root
    
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    
    if S.flyConn then S.flyConn:Disconnect() end
    S.flyConn = RunService.RenderStepped:Connect(function()
        if not S.flying then return end
        local cam = workspace.CurrentCamera
        local d = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0,1,0) end
        if S.bv then
            S.bv.Velocity = d.Magnitude > 0 and d.Unit * S.speed or Vector3.zero
        end
        if S.bg then S.bg.CFrame = cam.CFrame end
    end)
end

local function stopFly()
    S.flying = false
    if S.flyConn then S.flyConn:Disconnect() S.flyConn = nil end
    if S.bv then S.bv:Destroy() S.bv = nil end
    if S.bg then S.bg:Destroy() S.bg = nil end
    local ch = LP.Character
    if ch then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

-- ============ NOCLIP ============
local function enableNoclip()
    S.noclip = true
    if S.noclipConn then S.noclipConn:Disconnect() end
    S.noclipConn = RunService.Stepped:Connect(function()
        if not S.noclip then return end
        local ch = LP.Character
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    S.noclip = false
    if S.noclipConn then S.noclipConn:Disconnect() S.noclipConn = nil end
    local ch = LP.Character
    if ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = true
            end
        end
    end
end

-- ============ ОБНОВЛЕНИЕ КНОПОК ============
local function updFly()
    if S.flying then
        FlyBtn.Text = "✈  FLY: ВКЛ"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(120,60,200)
    else
        FlyBtn.Text = "✈  FLY: ВЫКЛ"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(45,45,70)
    end
end

local function updNoclip()
    if S.noclip then
        NoclipBtn.Text = "👻  NOCLIP: ВКЛ"
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(60,160,120)
    else
        NoclipBtn.Text = "👻  NOCLIP: ВЫКЛ"
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(45,45,70)
    end
end

local function updWm()
    if S.wmOn then
        WmBtn.Text = "📊  WATERMARK: ВКЛ"
        WmBtn.BackgroundColor3 = Color3.fromRGB(45,90,70)
    else
        WmBtn.Text = "📊  WATERMARK: ВЫКЛ"
        WmBtn.BackgroundColor3 = Color3.fromRGB(45,45,70)
    end
end

FlyBtn.MouseButton1Click:Connect(function()
    if S.flying then stopFly() else startFly() end
    updFly()
end)

NoclipBtn.MouseButton1Click:Connect(function()
    if S.noclip then disableNoclip() else enableNoclip() end
    updNoclip()
end)

-- ============ WATERMARK TOGGLE ============
local function setWm(on)
    S.wmOn = on
    if on then
        WM.Visible = true
        WM.Position = UDim2.new(0,-300,WM.Position.Y.Scale,WM.Position.Y.Offset)
        TweenService:Create(WM, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0,12,WM.Position.Y.Scale,WM.Position.Y.Offset)
        }):Play()
    else
        local t = TweenService:Create(WM, TweenInfo.new(0.3), {
            Position = UDim2.new(0,-320,WM.Position.Y.Scale,WM.Position.Y.Offset)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.wmOn then WM.Visible = false end
        end)
    end
    updWm()
end

WmBtn.MouseButton1Click:Connect(function()
    setWm(not S.wmOn)
end)

updWm()

-- ============ СВОРАЧИВАНИЕ ============
MinBtn.MouseButton1Click:Connect(function()
    S.min = not S.min
    if S.min then
        Content.Visible = false
        TweenService:Create(Main, TweenInfo.new(0.3), {Size=MIN}):Play()
        MinBtn.Text = "+"
    else
        TweenService:Create(Main, TweenInfo.new(0.3), {Size=EXP}):Play()
        task.wait(0.3)
        Content.Visible = true
        MinBtn.Text = "—"
    end
end)

-- ============ TOGGLE GUI ============
local function toggleGui()
    S.guiOpen = not S.guiOpen
    if S.guiOpen then
        Main.Visible = true
        Main.Size = UDim2.new(0,0,0,0)
        Main.BackgroundTransparency = 1
        MS.Transparency = 1
        local target = S.min and MIN or EXP
        TweenService:Create(Main, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=target}):Play()
        TweenService:Create(Main, TweenInfo.new(0.3), {BackgroundTransparency=0}):Play()
        TweenService:Create(MS, TweenInfo.new(0.3), {Transparency=0.3}):Play()
        TweenService:Create(TS, TweenInfo.new(0.3), {Color=Color3.fromRGB(180,40,200)}):Play()
        TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {TextColor3=Color3.fromRGB(230,130,255)}):Play()
    else
        TweenService:Create(Main, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
        TweenService:Create(MS, TweenInfo.new(0.3), {Transparency=1}):Play()
        local t = TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0)})
        t:Play()
        t.Completed:Connect(function()
            if not S.guiOpen then Main.Visible = false end
        end)
        TweenService:Create(TS, TweenInfo.new(0.3), {Color=Color3.fromRGB(255,180,80)}):Play()
        TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {TextColor3=Color3.fromRGB(255,200,100)}):Play()
    end
end

ToggleBtn.MouseButton1Click:Connect(toggleGui)

-- ============ ПОЛНАЯ ВЫГРУЗКА ============
CloseBtn.MouseButton1Click:Connect(function()
    if S.flyConn then S.flyConn:Disconnect() end
    if S.noclipConn then S.noclipConn:Disconnect() end
    if S.bv then S.bv:Destroy() end
    if S.bg then S.bg:Destroy() end
    local ch = LP.Character
    if ch then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = true
            end
        end
    end
    for _, n in ipairs({"SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle"}) do
        local g = LP.PlayerGui:FindFirstChild(n)
        if g then g:Destroy() end
    end
    print("SpermaHub выгружен")
end)

-- ============ ПОЛЗУНОК ============
local drag = false
Slider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not drag then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
        SlFill.Size = UDim2.new(rel,0,1,0)
        S.speed = math.floor(rel * 240) + 10
        SpdLabel.Text = "Скорость полёта: " .. S.speed
    end
end)

-- ============ ГОРЯЧИЕ КЛАВИШИ ============
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then
        if S.flying then stopFly() else startFly() end
        updFly()
    elseif input.KeyCode == Enum.KeyCode.N then
        if S.noclip then disableNoclip() else enableNoclip() end
        updNoclip()
    elseif input.KeyCode == Enum.KeyCode.P then
        setWm(not S.wmOn)
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        MinBtn.MouseButton1Click:Fire()
    end
end)

-- ============ РЕСПАВН ============
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if S.flying then stopFly() updFly() end
    if S.noclip then
        if S.noclipConn then S.noclipConn:Disconnect() end
        S.noclip = true
        enableNoclip()
    end
end)

-- ============ ИНТРО ============
task.spawn(function()
    playSound()
    
    Toast.Position = UDim2.new(0.5,-160,0.15,-100)
    TweenService:Create(Toast, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5,-160,0.15,20)
    }):Play()
    
    task.wait(1.5)
    
    TweenService:Create(Toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5,-160,0.15,-100)
    }):Play()
    task.wait(0.5)
    TstG:Destroy()
    
    TweenService:Create(Main, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=EXP}):Play()
    TweenService:Create(Main, TweenInfo.new(0.4), {BackgroundTransparency=0}):Play()
    TweenService:Create(MS, TweenInfo.new(0.4), {Transparency=0.3}):Play()
    
    WM.Position = UDim2.new(0,-300,0,12)
    TweenService:Create(WM, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0,12,0,12)
    }):Play()
    
    ToggleBtn.Position = UDim2.new(0,-80,0.5,-25)
    TweenService:Create(ToggleBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0,15,0.5,-25)
    }):Play()
end)

print("SpermaHub v6 загружен! F=Fly | N=Noclip | P=Watermark | RightShift=свернуть")
