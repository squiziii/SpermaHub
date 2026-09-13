-- SpermaHub v19 | Fly + Noclip + Watermark + ESP + WalkSpeed + Settings Menu
-- F=Fly | N=Noclip | E=ESP | P=Watermark | RightShift=свернуть | ✕=выгрузить
-- ⚙ (сверху) = настройки скорости полёта
-- ⚙ (снизу) = настройки скорости ходьбы

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer

-- Очистка
for _, n in ipairs({"SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle","SpermaHubESP","SpermaHubBinds","SpermaHubSettings","SpermaHubWsSettings"}) do
    local o = LP.PlayerGui:FindFirstChild(n)
    if o then o:Destroy() end
end

-- Состояние
local S = {
    flying=false, noclip=false, esp=false, speed=50, min=false,
    guiOpen=true, wmOn=true, settingsOpen=false, wsSettingsOpen=false,
    bv=nil, bg=nil, flyConn=nil, noclipConn=nil, espConn=nil,
    fps=60, ping=0,
    walkSpeed = 16,
    walkSpeedOn = false,
    wsConn = nil,
}

local EXP = UDim2.new(0,240,0,240)
local MIN = UDim2.new(0,240,0,38)

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

-- Сворачивание
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

-- Закрытие
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,24,0,24)
CloseBtn.Position = UDim2.new(1,-32,0.5,-12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,50,80)
CloseBtn.Text = "X"
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
    b.Size = UDim2.new(0.9,0,0,32)
    b.Position = UDim2.new(0.05,0,0,y)
    b.BackgroundColor3 = col
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,8)
    c.Parent = b
    return b
end

local FlyBtn    = mkBtn("✈  FLY: ВЫКЛ", 8, Color3.fromRGB(45,45,70), Content)
local NoclipBtn = mkBtn("👻  NOCLIP: ВЫКЛ", 44, Color3.fromRGB(45,45,70), Content)
local WmBtn     = mkBtn("📊  WATERMARK: ВКЛ", 80, Color3.fromRGB(45,90,70), Content)
local EspBtn    = mkBtn("👁  ESP: ВЫКЛ", 116, Color3.fromRGB(45,45,70), Content)
local WsBtn     = mkBtn("🏃  WALKSPEED: ВЫКЛ", 152, Color3.fromRGB(45,45,70), Content)

-- Первая шестерёнка (полёт)
local GearBtn = Instance.new("TextButton")
GearBtn.Size = UDim2.new(0,32,0,32)
GearBtn.Position = UDim2.new(1,-34,0,8)
GearBtn.BackgroundColor3 = Color3.fromRGB(120,60,180)
GearBtn.Text = "⚙"
GearBtn.TextColor3 = Color3.fromRGB(255,255,255)
GearBtn.Font = Enum.Font.GothamBold
GearBtn.TextSize = 16
GearBtn.Parent = Content

local GearC = Instance.new("UICorner")
GearC.CornerRadius = UDim.new(0,8)
GearC.Parent = GearBtn

-- Вторая шестерёнка (ходьба)
local GearBtn2 = Instance.new("TextButton")
GearBtn2.Size = UDim2.new(0,32,0,32)
GearBtn2.Position = UDim2.new(1,-34,0,152)
GearBtn2.BackgroundColor3 = Color3.fromRGB(60,140,180)
GearBtn2.Text = "⚙"
GearBtn2.TextColor3 = Color3.fromRGB(255,255,255)
GearBtn2.Font = Enum.Font.GothamBold
GearBtn2.TextSize = 16
GearBtn2.Parent = Content

local GearC2 = Instance.new("UICorner")
GearC2.CornerRadius = UDim.new(0,8)
GearC2.Parent = GearBtn2

local Hint = Instance.new("TextLabel")
Hint.Size = UDim2.new(0.9,0,0,14)
Hint.Position = UDim2.new(0.05,0,0,194)
Hint.BackgroundTransparency = 1
Hint.Text = "F=fly · N=noclip · E=esp · P=wm"
Hint.TextColor3 = Color3.fromRGB(140,140,160)
Hint.Font = Enum.Font.Gotham
Hint.TextSize = 10
Hint.Parent = Content

-- ============ МЕНЮ НАСТРОЕК ПОЛЁТА ============
local SetGui = Instance.new("ScreenGui")
SetGui.Name = "SpermaHubSettings"
SetGui.ResetOnSpawn = false
SetGui.IgnoreGuiInset = true
SetGui.DisplayOrder = 200
SetGui.Enabled = false
SetGui.Parent = LP:WaitForChild("PlayerGui")

local SetFrame = Instance.new("Frame")
SetFrame.Size = UDim2.new(0,260,0,120)
SetFrame.Position = UDim2.new(0.5,-130,0.5,-60)
SetFrame.BackgroundColor3 = Color3.fromRGB(20,20,28)
SetFrame.BorderSizePixel = 0
SetFrame.Active = true
SetFrame.Draggable = true
SetFrame.Parent = SetGui

local SetC = Instance.new("UICorner")
SetC.CornerRadius = UDim.new(0,12)
SetC.Parent = SetFrame

local SetS = Instance.new("UIStroke")
SetS.Color = Color3.fromRGB(180,40,200)
SetS.Thickness = 2
SetS.Transparency = 0.3
SetS.Parent = SetFrame

local SetTitle = Instance.new("TextLabel")
SetTitle.Size = UDim2.new(1,0,0,34)
SetTitle.BackgroundColor3 = Color3.fromRGB(35,25,45)
SetTitle.Text = "⚙ Скорость полёта"
SetTitle.TextColor3 = Color3.fromRGB(230,130,255)
SetTitle.Font = Enum.Font.GothamBlack
SetTitle.TextSize = 15
SetTitle.BorderSizePixel = 0
SetTitle.Parent = SetFrame

local SetTC = Instance.new("UICorner")
SetTC.CornerRadius = UDim.new(0,12)
SetTC.Parent = SetTitle

local SetBack = Instance.new("TextButton")
SetBack.Size = UDim2.new(0,24,0,24)
SetBack.Position = UDim2.new(1,-62,0,5)
SetBack.BackgroundColor3 = Color3.fromRGB(80,100,150)
SetBack.Text = "←"
SetBack.TextColor3 = Color3.fromRGB(255,255,255)
SetBack.Font = Enum.Font.GothamBold
SetBack.TextSize = 14
SetBack.Parent = SetTitle

local SetBC = Instance.new("UICorner")
SetBC.CornerRadius = UDim.new(0,6)
SetBC.Parent = SetBack

local SetClose = Instance.new("TextButton")
SetClose.Size = UDim2.new(0,24,0,24)
SetClose.Position = UDim2.new(1,-32,0,5)
SetClose.BackgroundColor3 = Color3.fromRGB(200,50,80)
SetClose.Text = "✕"
SetClose.TextColor3 = Color3.fromRGB(255,255,255)
SetClose.Font = Enum.Font.GothamBold
SetClose.TextSize = 14
SetClose.Parent = SetTitle

local SetCC = Instance.new("UICorner")
SetCC.CornerRadius = UDim.new(0,6)
SetCC.Parent = SetClose

local FlySpdTitle = Instance.new("TextLabel")
FlySpdTitle.Size = UDim2.new(0.9,0,0,16)
FlySpdTitle.Position = UDim2.new(0.05,0,0,46)
FlySpdTitle.BackgroundTransparency = 1
FlySpdTitle.Text = "✈  Скорость полёта: 50"
FlySpdTitle.TextColor3 = Color3.fromRGB(200,200,220)
FlySpdTitle.Font = Enum.Font.GothamMedium
FlySpdTitle.TextSize = 12
FlySpdTitle.TextXAlignment = Enum.TextXAlignment.Left
FlySpdTitle.Parent = SetFrame

local FlySlider = Instance.new("Frame")
FlySlider.Size = UDim2.new(0.9,0,0,16)
FlySlider.Position = UDim2.new(0.05,0,0,66)
FlySlider.BackgroundColor3 = Color3.fromRGB(40,40,55)
FlySlider.BorderSizePixel = 0
FlySlider.Parent = SetFrame

local FlySlC = Instance.new("UICorner")
FlySlC.CornerRadius = UDim.new(0,8)
FlySlC.Parent = FlySlider

local FlySlFill = Instance.new("Frame")
FlySlFill.Size = UDim2.new(0.2,0,1,0)
FlySlFill.BackgroundColor3 = Color3.fromRGB(180,60,220)
FlySlFill.BorderSizePixel = 0
FlySlFill.Parent = FlySlider

local FlySlFC = Instance.new("UICorner")
FlySlFC.CornerRadius = UDim.new(0,8)
FlySlFC.Parent = FlySlFill

local SetHint = Instance.new("TextLabel")
SetHint.Size = UDim2.new(0.9,0,0,14)
SetHint.Position = UDim2.new(0.05,0,0,90)
SetHint.BackgroundTransparency = 1
SetHint.Text = "Применяется при включённом FLY"
SetHint.TextColor3 = Color3.fromRGB(140,140,160)
SetHint.Font = Enum.Font.Gotham
SetHint.TextSize = 10
SetHint.Parent = SetFrame

-- ============ МЕНЮ НАСТРОЕК ХОДЬБЫ ============
local WsSetGui = Instance.new("ScreenGui")
WsSetGui.Name = "SpermaHubWsSettings"
WsSetGui.ResetOnSpawn = false
WsSetGui.IgnoreGuiInset = true
WsSetGui.DisplayOrder = 201
WsSetGui.Enabled = false
WsSetGui.Parent = LP:WaitForChild("PlayerGui")

local WsSetFrame = Instance.new("Frame")
WsSetFrame.Size = UDim2.new(0,260,0,120)
WsSetFrame.Position = UDim2.new(0.5,-130,0.5,-60)
WsSetFrame.BackgroundColor3 = Color3.fromRGB(20,20,28)
WsSetFrame.BorderSizePixel = 0
WsSetFrame.Active = true
WsSetFrame.Draggable = true
WsSetFrame.Parent = WsSetGui

local WsSetC = Instance.new("UICorner")
WsSetC.CornerRadius = UDim.new(0,12)
WsSetC.Parent = WsSetFrame

local WsSetS = Instance.new("UIStroke")
WsSetS.Color = Color3.fromRGB(60,180,220)
WsSetS.Thickness = 2
WsSetS.Transparency = 0.3
WsSetS.Parent = WsSetFrame

local WsSetTitle = Instance.new("TextLabel")
WsSetTitle.Size = UDim2.new(1,0,0,34)
WsSetTitle.BackgroundColor3 = Color3.fromRGB(25,35,45)
WsSetTitle.Text = "⚙ Скорость ходьбы"
WsSetTitle.TextColor3 = Color3.fromRGB(120,220,255)
WsSetTitle.Font = Enum.Font.GothamBlack
WsSetTitle.TextSize = 15
WsSetTitle.BorderSizePixel = 0
WsSetTitle.Parent = WsSetFrame

local WsSetTC = Instance.new("UICorner")
WsSetTC.CornerRadius = UDim.new(0,12)
WsSetTC.Parent = WsSetTitle

local WsSetBack = Instance.new("TextButton")
WsSetBack.Size = UDim2.new(0,24,0,24)
WsSetBack.Position = UDim2.new(1,-62,0,5)
WsSetBack.BackgroundColor3 = Color3.fromRGB(80,100,150)
WsSetBack.Text = "←"
WsSetBack.TextColor3 = Color3.fromRGB(255,255,255)
WsSetBack.Font = Enum.Font.GothamBold
WsSetBack.TextSize = 14
WsSetBack.Parent = WsSetTitle

local WsSetBC = Instance.new("UICorner")
WsSetBC.CornerRadius = UDim.new(0,6)
WsSetBC.Parent = WsSetBack

local WsSetClose = Instance.new("TextButton")
WsSetClose.Size = UDim2.new(0,24,0,24)
WsSetClose.Position = UDim2.new(1,-32,0,5)
WsSetClose.BackgroundColor3 = Color3.fromRGB(200,50,80)
WsSetClose.Text = "X"
WsSetClose.TextColor3 = Color3.fromRGB(255,255,255)
WsSetClose.Font = Enum.Font.GothamBold
WsSetClose.TextSize = 14
WsSetClose.Parent = WsSetTitle

local WsSetCC = Instance.new("UICorner")
WsSetCC.CornerRadius = UDim.new(0,6)
WsSetCC.Parent = WsSetClose

local WalkSpdTitle = Instance.new("TextLabel")
WalkSpdTitle.Size = UDim2.new(0.9,0,0,16)
WalkSpdTitle.Position = UDim2.new(0.05,0,0,46)
WalkSpdTitle.BackgroundTransparency = 1
WalkSpdTitle.Text = "🏃  Скорость ходьбы: 16"
WalkSpdTitle.TextColor3 = Color3.fromRGB(200,200,220)
WalkSpdTitle.Font = Enum.Font.GothamMedium
WalkSpdTitle.TextSize = 12
WalkSpdTitle.TextXAlignment = Enum.TextXAlignment.Left
WalkSpdTitle.Parent = WsSetFrame

local WalkSlider = Instance.new("Frame")
WalkSlider.Size = UDim2.new(0.9,0,0,16)
WalkSlider.Position = UDim2.new(0.05,0,0,66)
WalkSlider.BackgroundColor3 = Color3.fromRGB(40,40,55)
WalkSlider.BorderSizePixel = 0
WalkSlider.Parent = WsSetFrame

local WalkSlC = Instance.new("UICorner")
WalkSlC.CornerRadius = UDim.new(0,8)
WalkSlC.Parent = WalkSlider

local WalkSlFill = Instance.new("Frame")
WalkSlFill.Size = UDim2.new(0,0,1,0)
WalkSlFill.BackgroundColor3 = Color3.fromRGB(60,180,220)
WalkSlFill.BorderSizePixel = 0
WalkSlFill.Parent = WalkSlider

local WalkSlFC = Instance.new("UICorner")
WalkSlFC.CornerRadius = UDim.new(0,8)
WalkSlFC.Parent = WalkSlFill

local WsSetHint = Instance.new("TextLabel")
WsSetHint.Size = UDim2.new(0.9,0,0,14)
WsSetHint.Position = UDim2.new(0.05,0,0,90)
WsSetHint.BackgroundTransparency = 1
WsSetHint.Text = "Включи WALKSPEED в главном меню"
WsSetHint.TextColor3 = Color3.fromRGB(140,140,160)
WsSetHint.Font = Enum.Font.Gotham
WsSetHint.TextSize = 10
WsSetHint.Parent = WsSetFrame

-- ============ WATERMARK ============
local WG = Instance.new("ScreenGui")
WG.Name = "SpermaHubWatermark"
WG.ResetOnSpawn = false
WG.IgnoreGuiInset = true
WG.DisplayOrder = 100
WG.Parent = LP:WaitForChild("PlayerGui")

local WM = Instance.new("Frame")
WM.Size = UDim2.new(0,280,0,68)
WM.Position = UDim2.new(0,-300,0,12)
WM.BackgroundColor3 = Color3.fromRGB(18,18,22)
WM.BackgroundTransparency = 0.15
WM.BorderSizePixel = 0
WM.Active = true
WM.Draggable = true
WM.Parent = WG

local WMC = Instance.new("UICorner")
WMC.CornerRadius = UDim.new(0,10)
WMC.Parent = WM

local WMS = Instance.new("UIStroke")
WMS.Color = Color3.fromRGB(80,60,140)
WMS.Thickness = 1
WMS.Transparency = 0.5
WMS.Parent = WM

local TopRow = Instance.new("Frame")
TopRow.Size = UDim2.new(1,-20,0,24)
TopRow.Position = UDim2.new(0,10,0,10)
TopRow.BackgroundTransparency = 1
TopRow.Parent = WM

local BrandLabel = Instance.new("TextLabel")
BrandLabel.Size = UDim2.new(0,90,1,0)
BrandLabel.BackgroundTransparency = 1
BrandLabel.Text = "SpermaHub"
BrandLabel.TextColor3 = Color3.fromRGB(160,140,220)
BrandLabel.Font = Enum.Font.GothamBold
BrandLabel.TextSize = 14
BrandLabel.TextXAlignment = Enum.TextXAlignment.Left
BrandLabel.Parent = TopRow

local FpsIcon = Instance.new("TextLabel")
FpsIcon.Size = UDim2.new(0,18,1,0)
FpsIcon.Position = UDim2.new(0,92,0,0)
FpsIcon.BackgroundTransparency = 1
FpsIcon.Text = "📶"
FpsIcon.TextColor3 = Color3.fromRGB(140,140,200)
FpsIcon.Font = Enum.Font.Gotham
FpsIcon.TextSize = 13
FpsIcon.TextXAlignment = Enum.TextXAlignment.Center
FpsIcon.Parent = TopRow

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(0,55,1,0)
FpsLabel.Position = UDim2.new(0,110,0,0)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "-- Fps"
FpsLabel.TextColor3 = Color3.fromRGB(200,200,220)
FpsLabel.Font = Enum.Font.GothamBold
FpsLabel.TextSize = 14
FpsLabel.TextXAlignment = Enum.TextXAlignment.Left
FpsLabel.Parent = TopRow

local TimeIcon = Instance.new("TextLabel")
TimeIcon.Size = UDim2.new(0,18,1,0)
TimeIcon.Position = UDim2.new(0,170,0,0)
TimeIcon.BackgroundTransparency = 1
TimeIcon.Text = "🕐"
TimeIcon.TextColor3 = Color3.fromRGB(140,140,200)
TimeIcon.Font = Enum.Font.Gotham
TimeIcon.TextSize = 13
TimeIcon.TextXAlignment = Enum.TextXAlignment.Center
TimeIcon.Parent = TopRow

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Size = UDim2.new(0,80,1,0)
TimeLabel.Position = UDim2.new(0,188,0,0)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "00:00:00"
TimeLabel.TextColor3 = Color3.fromRGB(200,200,220)
TimeLabel.Font = Enum.Font.GothamBold
TimeLabel.TextSize = 14
TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
TimeLabel.Parent = TopRow

local BotRow = Instance.new("Frame")
BotRow.Size = UDim2.new(1,-20,0,20)
BotRow.Position = UDim2.new(0,10,0,38)
BotRow.BackgroundTransparency = 1
BotRow.Parent = WM

local PingIcon = Instance.new("TextLabel")
PingIcon.Size = UDim2.new(0,18,1,0)
PingIcon.BackgroundTransparency = 1
PingIcon.Text = "📡"
PingIcon.TextColor3 = Color3.fromRGB(160,140,220)
PingIcon.Font = Enum.Font.Gotham
PingIcon.TextSize = 13
PingIcon.Parent = BotRow

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(0,90,1,0)
PingLabel.Position = UDim2.new(0,20,0,0)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "-- Ping"
PingLabel.TextColor3 = Color3.fromRGB(200,200,220)
PingLabel.Font = Enum.Font.GothamBold
PingLabel.TextSize = 13
PingLabel.TextXAlignment = Enum.TextXAlignment.Left
PingLabel.Parent = BotRow

local DateIcon = Instance.new("TextLabel")
DateIcon.Size = UDim2.new(0,18,1,0)
DateIcon.Position = UDim2.new(0,140,0,0)
DateIcon.BackgroundTransparency = 1
DateIcon.Text = "📅"
DateIcon.TextColor3 = Color3.fromRGB(160,140,220)
DateIcon.Font = Enum.Font.Gotham
DateIcon.TextSize = 13
DateIcon.Parent = BotRow

local DateLabel = Instance.new("TextLabel")
DateLabel.Size = UDim2.new(0,110,1,0)
DateLabel.Position = UDim2.new(0,160,0,0)
DateLabel.BackgroundTransparency = 1
DateLabel.Text = "Sep.2025"
DateLabel.TextColor3 = Color3.fromRGB(200,200,220)
DateLabel.Font = Enum.Font.GothamBold
DateLabel.TextSize = 13
DateLabel.TextXAlignment = Enum.TextXAlignment.Left
DateLabel.Parent = BotRow

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

task.spawn(function()
    local months = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
    while WG.Parent do
        if WM.Parent and S.wmOn then
            local p = 0
            pcall(function()
                p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            S.ping = p
            
            local fpsColor
            if S.fps >= 50 then
                fpsColor = Color3.fromRGB(200,255,200)
            elseif S.fps >= 30 then
                fpsColor = Color3.fromRGB(255,240,160)
            else
                fpsColor = Color3.fromRGB(255,160,160)
            end
            
            local pingColor
            if p < 80 then
                pingColor = Color3.fromRGB(120,255,140)
            elseif p < 150 then
                pingColor = Color3.fromRGB(255,220,100)
            else
                pingColor = Color3.fromRGB(255,120,120)
            end
            
            FpsLabel.Text = string.format("%d Fps", S.fps)
            FpsLabel.TextColor3 = fpsColor
            
            PingLabel.Text = string.format("%d Ping", p)
            PingLabel.TextColor3 = pingColor
            
            local t = os.date("*t")
            TimeLabel.Text = string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
            DateLabel.Text = string.format("%s.%d", months[t.month], t.year)
        end
        task.wait(0.2)
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

-- ============ WALK SPEED ============
local function applyWalkSpeed()
    local ch = LP.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then
        if S.walkSpeedOn then
            hum.WalkSpeed = S.walkSpeed
        else
            hum.WalkSpeed = 16
        end
    end
end

S.wsConn = RunService.Heartbeat:Connect(function()
    local ch = LP.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then
        if S.walkSpeedOn then
            if math.abs(hum.WalkSpeed - S.walkSpeed) > 0.1 then
                hum.WalkSpeed = S.walkSpeed
            end
        end
    end
end)

-- ============ ESP ============
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "SpermaHubESP"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 50
ESPGui.Parent = LP:WaitForChild("PlayerGui")

local espObjects = {}
local skeletonFrames = {}

local function isAlive(plr)
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return ch:FindFirstChild("HumanoidRootPart") ~= nil
end

local function createESP(plr)
    if plr == LP then return end
    if espObjects[plr] then return end
    
    local data = {lines = {}, highlight = nil, billboard = nil}
    espObjects[plr] = data
    
    local ch = plr.Character
    if ch then
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 60, 60)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = ch
        hl.Parent = ESPGui
        data.highlight = hl
    end
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPName"
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ESPGui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = bb
    
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Size = UDim2.new(1, 0, 0, 16)
    hpLabel.Position = UDim2.new(0, 0, 0, 20)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Text = "100 HP"
    hpLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
    hpLabel.TextStrokeTransparency = 0
    hpLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.TextSize = 13
    hpLabel.Parent = bb
    
    data.billboard = bb
    data.nameLabel = nameLabel
    data.hpLabel = hpLabel
end

local function removeESP(plr)
    local data = espObjects[plr]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    espObjects[plr] = nil
end

local function updateESP()
    for plr, data in pairs(espObjects) do
        local ch = plr.Character
        if ch and isAlive(plr) then
            local head = ch:FindFirstChild("Head")
            local hum = ch:FindFirstChildOfClass("Humanoid")
            
            if data.highlight then data.highlight.Adornee = ch end
            if data.billboard and head then data.billboard.Adornee = head end
            if data.nameLabel then data.nameLabel.Text = plr.Name .. " [" .. plr.DisplayName .. "]" end
            if data.hpLabel and hum then
                local hp = math.floor(hum.Health)
                data.hpLabel.Text = hp .. " HP"
                local ratio = hum.Health / hum.MaxHealth
                data.hpLabel.TextColor3 = Color3.fromRGB(
                    math.floor(255 * (1 - ratio)),
                    math.floor(255 * ratio),
                    80
                )
            end
        else
            if data.highlight then data.highlight.Adornee = nil end
            if data.billboard then data.billboard.Adornee = nil end
        end
    end
end

local function drawSkeleton()
    local cam = workspace.CurrentCamera
    for plr, data in pairs(espObjects) do
        local ch = plr.Character
        if ch and isAlive(plr) then
            local parts = {}
            for _, p in ipairs(ch:GetChildren()) do
                if p:IsA("BasePart") then parts[p.Name] = p end
            end
            
            local connections
            if parts["UpperTorso"] then
                connections = {
                    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
                    {"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
                    {"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
                    {"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
                    {"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
                    {"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
                    {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
                }
            else
                connections = {
                    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
                    {"Torso","Left Leg"},{"Torso","Right Leg"},
                }
            end
            
            if not skeletonFrames[plr] then skeletonFrames[plr] = {} end
            local frames = skeletonFrames[plr]
            
            for i, conn in ipairs(connections) do
                local p1 = parts[conn[1]]
                local p2 = parts[conn[2]]
                if p1 and p2 then
                    local v1, on1 = cam:WorldToViewportPoint(p1.Position)
                    local v2, on2 = cam:WorldToViewportPoint(p2.Position)
                    
                    if on1 and on2 then
                        if not frames[i] then
                            local f = Instance.new("Frame")
                            f.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
                            f.BorderSizePixel = 0
                            f.ZIndex = 5
                            f.Parent = ESPGui
                            frames[i] = f
                        end
                        
                        local f = frames[i]
                        local dx = v2.X - v1.X
                        local dy = v2.Y - v1.Y
                        local length = math.sqrt(dx*dx + dy*dy)
                        local angle = math.atan2(dy, dx)
                        
                        f.Size = UDim2.new(0, length, 0, 1)
                        f.Position = UDim2.new(0, v1.X, 0, v1.Y)
                        f.Rotation = math.deg(angle)
                        f.Visible = true
                    else
                        if frames[i] then frames[i].Visible = false end
                    end
                else
                    if frames[i] then frames[i].Visible = false end
                end
            end
            
            for i = #connections + 1, #frames do
                frames[i].Visible = false
            end
        end
    end
end

local function enableESP()
    S.esp = true
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then createESP(plr) end
    end
    
    Players.PlayerAdded:Connect(function(plr)
        if S.esp and plr ~= LP then
            plr.CharacterAdded:Connect(function()
                task.wait(0.5)
                if S.esp then removeESP(plr) createESP(plr) end
            end)
        end
    end)
    
    Players.PlayerRemoving:Connect(function(plr)
        removeESP(plr)
        skeletonFrames[plr] = nil
    end)
    
    if S.espConn then S.espConn:Disconnect() end
    S.espConn = RunService.RenderStepped:Connect(function()
        if not S.esp then return end
        updateESP()
        drawSkeleton()
    end)
end

local function disableESP()
    S.esp = false
    if S.espConn then S.espConn:Disconnect() S.espConn = nil end
    
    for plr, _ in pairs(espObjects) do removeESP(plr) end
    espObjects = {}
    
    for plr, frames in pairs(skeletonFrames) do
        for _, f in ipairs(frames) do
            if f then f:Destroy() end
        end
    end
    skeletonFrames = {}
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

local function updEsp()
    if S.esp then
        EspBtn.Text = "👁  ESP: ВКЛ"
        EspBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
    else
        EspBtn.Text = "👁  ESP: ВЫКЛ"
        EspBtn.BackgroundColor3 = Color3.fromRGB(45,45,70)
    end
end

local function updWs()
    if S.walkSpeedOn then
        WsBtn.Text = "🏃  WALKSPEED: ВКЛ"
        WsBtn.BackgroundColor3 = Color3.fromRGB(60,180,220)
    else
        WsBtn.Text = "🏃  WALKSPEED: ВЫКЛ"
        WsBtn.BackgroundColor3 = Color3.fromRGB(45,45,70)
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

EspBtn.MouseButton1Click:Connect(function()
    if S.esp then disableESP() else enableESP() end
    updEsp()
end)

WsBtn.MouseButton1Click:Connect(function()
    S.walkSpeedOn = not S.walkSpeedOn
    applyWalkSpeed()
    updWs()
end)

-- ============ МЕНЮ НАСТРОЕК ============
local function openSettings()
    S.settingsOpen = true
    SetGui.Enabled = true
    FlySpdTitle.Text = "✈  Скорость полёта: " .. S.speed
    FlySlFill.Size = UDim2.new((S.speed - 10) / 240, 0, 1, 0)
end

local function closeSettings()
    S.settingsOpen = false
    SetGui.Enabled = false
end

local function openWsSettings()
    S.wsSettingsOpen = true
    WsSetGui.Enabled = true
    WalkSpdTitle.Text = "🏃  Скорость ходьбы: " .. S.walkSpeed
    WalkSlFill.Size = UDim2.new((S.walkSpeed - 16) / 184, 0, 1, 0)
end

local function closeWsSettings()
    S.wsSettingsOpen = false
    WsSetGui.Enabled = false
end

GearBtn.MouseButton1Click:Connect(openSettings)
GearBtn2.MouseButton1Click:Connect(openWsSettings)

SetBack.MouseButton1Click:Connect(function()
    closeSettings()
    if not S.guiOpen then toggleGui() end
end)

SetClose.MouseButton1Click:Connect(closeSettings)

WsSetBack.MouseButton1Click:Connect(function()
    closeWsSettings()
    if not S.guiOpen then toggleGui() end
end)

WsSetClose.MouseButton1Click:Connect(closeWsSettings)

-- Ползунок скорости полёта
local dragFlySet = false
FlySlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragFlySet = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragFlySet = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragFlySet then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - FlySlider.AbsolutePosition.X) / FlySlider.AbsoluteSize.X, 0, 1)
        FlySlFill.Size = UDim2.new(rel,0,1,0)
        S.speed = math.floor(rel * 240) + 10
        FlySpdTitle.Text = "✈  Скорость полёта: " .. S.speed
    end
end)

-- Ползунок скорости ходьбы
local dragWalkSet = false
WalkSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragWalkSet = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragWalkSet = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragWalkSet then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - WalkSlider.AbsolutePosition.X) / WalkSlider.AbsoluteSize.X, 0, 1)
        WalkSlFill.Size = UDim2.new(rel,0,1,0)
        S.walkSpeed = math.floor(rel * 184) + 16
        WalkSpdTitle.Text = "🏃  Скорость ходьбы: " .. S.walkSpeed
        if S.walkSpeedOn then applyWalkSpeed() end
    end
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
local function toggleMin()
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
end

MinBtn.MouseButton1Click:Connect(toggleMin)

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
    if S.espConn then S.espConn:Disconnect() end
    if S.wsConn then S.wsConn:Disconnect() end
    if S.bv then S.bv:Destroy() end
    if S.bg then S.bg:Destroy() end
    local ch = LP.Character
    if ch then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.WalkSpeed = 16
        end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = true
            end
        end
    end
    for _, n in ipairs({"SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle","SpermaHubESP","SpermaHubBinds","SpermaHubSettings","SpermaHubWsSettings"}) do
        local g = LP.PlayerGui:FindFirstChild(n)
        if g then g:Destroy() end
    end
    print("✦ SpermaHub выгружен")
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
    elseif input.KeyCode == Enum.KeyCode.E then
        if S.esp then disableESP() else enableESP() end
        updEsp()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        toggleMin()
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
    task.wait(0.2)
    applyWalkSpeed()
end)

-- ============ ИНТРО ============
task.spawn(function()
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
