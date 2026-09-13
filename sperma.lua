-- SpermaHub v41 | Silent Aim (Real-compatible) + Aimbot + Hitbox + ESP + FOV
-- Управление только через меню (ЛКМ = toggle, ПКМ = настройки)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer

-- Очистка
for _, n in ipairs({"SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle","SpermaHubESP","SpermaHubSettings","SpermaHubWsSettings","SpermaHubTpList","SpermaHubFlingTarget","SpermaHubFov"}) do
    local o = LP.PlayerGui:FindFirstChild(n)
    if o then o:Destroy() end
end

-- Состояние
local S = {
    flying=false, noclip=false, esp=false, speed=50,
    guiOpen=true, wmOn=true,
    bv=nil, bg=nil, flyConn=nil, noclipConn=nil, espConn=nil,
    fps=60, ping=0,
    walkSpeed = 16,
    walkSpeedOn = false,
    wsConn = nil,
    flyPanelOpen = false,
    wsPanelOpen = false,
    tpPanelOpen = false,
    killPanelOpen = false,
    clickTpOn = false,
    clickTpHeight = 3,
    clickTpPanelOpen = false,
    clickTpConn = nil,
    hitboxOn = false,
    hitboxSize = 5,
    hitboxPanelOpen = false,
    hitboxConn = nil,
    aimbotOn = false,
    aimbotFov = 120,
    aimbotSmooth = 0.3,
    aimbotPanelOpen = false,
    aimbotConn = nil,
    fovCircle = nil,
    silentAimOn = false,
    silentAimFov = 150,
    silentAimPanelOpen = false,
    silentAimConn = nil,
    silentAimFovCircle = nil,
}

-- ============ ГЛАВНОЕ ОКНО ============
local SG = Instance.new("ScreenGui")
SG.Name = "SpermaHub"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.Parent = LP:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,900,0,420)
Main.Position = UDim2.new(0.5,-450,0.5,-210)
Main.BackgroundColor3 = Color3.fromRGB(15,15,22)
Main.BackgroundTransparency = 0.1
Main.BorderSizePixel = 0
Main.Active = false
Main.Draggable = false
Main.Parent = SG

local MC = Instance.new("UICorner")
MC.CornerRadius = UDim.new(0,10)
MC.Parent = Main

local MS = Instance.new("UIStroke")
MS.Color = Color3.fromRGB(90,50,140)
MS.Thickness = 1.5
MS.Transparency = 0.4
MS.Parent = Main

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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30,20,40)
ToggleBtn.Text = "✦"
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

-- ============ КОНТЕЙНЕР КОЛОНОК ============
local ColumnsFrame = Instance.new("Frame")
ColumnsFrame.Size = UDim2.new(1,-20,1,-20)
ColumnsFrame.Position = UDim2.new(0,10,0,10)
ColumnsFrame.BackgroundTransparency = 1
ColumnsFrame.Parent = Main

local ColLayout = Instance.new("UIListLayout")
ColLayout.FillDirection = Enum.FillDirection.Horizontal
ColLayout.SortOrder = Enum.SortOrder.LayoutOrder
ColLayout.Padding = UDim.new(0,8)
ColLayout.Parent = ColumnsFrame

-- ============ ФУНКЦИЯ КОЛОНКИ ============
local function makeColumn(title, order)
    local Col = Instance.new("Frame")
    Col.Size = UDim2.new(0,170,1,0)
    Col.BackgroundColor3 = Color3.fromRGB(25,25,35)
    Col.BackgroundTransparency = 0.2
    Col.BorderSizePixel = 0
    Col.LayoutOrder = order
    Col.Parent = ColumnsFrame
    
    local ColC = Instance.new("UICorner")
    ColC.CornerRadius = UDim.new(0,8)
    ColC.Parent = Col
    
    local ColTitle = Instance.new("TextLabel")
    ColTitle.Size = UDim2.new(1,0,0,28)
    ColTitle.BackgroundColor3 = Color3.fromRGB(35,35,50)
    ColTitle.Text = title
    ColTitle.TextColor3 = Color3.fromRGB(230,130,255)
    ColTitle.Font = Enum.Font.GothamBold
    ColTitle.TextSize = 14
    ColTitle.BorderSizePixel = 0
    ColTitle.Parent = Col
    
    local CTC = Instance.new("UICorner")
    CTC.CornerRadius = UDim.new(0,8)
    CTC.Parent = ColTitle
    
    local CTF = Instance.new("Frame")
    CTF.Size = UDim2.new(1,0,0,10)
    CTF.Position = UDim2.new(0,0,1,-10)
    CTF.BackgroundColor3 = Color3.fromRGB(35,35,50)
    CTF.BorderSizePixel = 0
    CTF.Parent = ColTitle
    
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1,-8,1,-36)
    Scroll.Position = UDim2.new(0,4,0,32)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 4
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(120,60,180)
    Scroll.CanvasSize = UDim2.new(0,0,0,0)
    Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Scroll.Parent = Col
    
    local SL = Instance.new("UIListLayout")
    SL.Padding = UDim.new(0,4)
    SL.SortOrder = Enum.SortOrder.LayoutOrder
    SL.Parent = Scroll
    
    return Col, Scroll
end

-- ============ ФУНКЦИЯ СТРОКИ ============
local function makeRow(parent, text, order)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1,0,0,32)
    Row.BackgroundColor3 = Color3.fromRGB(35,35,50)
    Row.BackgroundTransparency = 0.3
    Row.BorderSizePixel = 0
    Row.LayoutOrder = order
    Row.Parent = parent
    
    local RC = Instance.new("UICorner")
    RC.CornerRadius = UDim.new(0,6)
    RC.Parent = Row
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1,-30,1,0)
    Label.Position = UDim2.new(0,8,0,0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(220,220,240)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    
    local Dots = Instance.new("TextLabel")
    Dots.Size = UDim2.new(0,24,1,0)
    Dots.Position = UDim2.new(1,-26,0,0)
    Dots.BackgroundTransparency = 1
    Dots.Text = "..."
    Dots.TextColor3 = Color3.fromRGB(140,140,170)
    Dots.Font = Enum.Font.GothamBold
    Dots.TextSize = 14
    Dots.TextXAlignment = Enum.TextXAlignment.Center
    Dots.Parent = Row
    
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1,0,1,0)
    Btn.BackgroundTransparency = 1
    Btn.Text = ""
    Btn.Parent = Row
    
    return Btn, Label, Dots, Row
end

-- ============ СОЗДАЁМ КОЛОНКИ ============
local CombatCol, CombatScroll = makeColumn("Combat", 1)
local MoveCol,   MoveScroll   = makeColumn("Movement", 2)
local VisCol,    VisScroll    = makeColumn("Visuals", 3)
local PlayCol,   PlayScroll   = makeColumn("Player", 4)
local MiscCol,   MiscScroll   = makeColumn("Miscellaneous", 5)

-- COMBAT
local KillBtn, KillLabel, KillDots = makeRow(CombatScroll, "Kill Player", 1)
local HitboxBtn, HitboxLabel, HitboxDots = makeRow(CombatScroll, "Hitbox Expander", 3)
local AimbotBtn, AimbotLabel, AimbotDots = makeRow(CombatScroll, "Aimbot", 5)
local SilentAimBtn, SilentAimLabel, SilentAimDots = makeRow(CombatScroll, "Silent Aim", 7)

-- MOVEMENT
local FlyBtn, FlyLabel, FlyDots = makeRow(MoveScroll, "Flight", 1)
local ClickTpBtn, ClickTpLabel, ClickTpDots = makeRow(MoveScroll, "Click TP", 3)
local NoclipBtn, NoclipLabel, NoclipDots = makeRow(MoveScroll, "Noclip", 5)

-- VISUALS
local EspBtn, EspLabel, EspDots = makeRow(VisScroll, "ESP", 1)
local WmBtn, WmLabel, WmDots = makeRow(VisScroll, "Watermark", 2)

-- PLAYER
local WsBtn, WsLabel, WsDots = makeRow(PlayScroll, "WalkSpeed", 1)
local TpBtn, TpLabel, TpDots = makeRow(PlayScroll, "TP Player", 3)

-- MISC
local CloseScriptBtn, CloseScriptLabel, CloseScriptDots = makeRow(MiscScroll, "Close Script", 1)

-- ============ ПАНЕЛЬ KILL PLAYER ============
local KillPanel = Instance.new("Frame")
KillPanel.Size = UDim2.new(1,0,0,0)
KillPanel.BackgroundColor3 = Color3.fromRGB(45,25,30)
KillPanel.BackgroundTransparency = 0.1
KillPanel.BorderSizePixel = 0
KillPanel.LayoutOrder = 2
KillPanel.ClipsDescendants = true
KillPanel.Visible = false
KillPanel.Parent = CombatScroll

local KillPanelC = Instance.new("UICorner")
KillPanelC.CornerRadius = UDim.new(0,6)
KillPanelC.Parent = KillPanel

local KillPanelTitle = Instance.new("TextLabel")
KillPanelTitle.Size = UDim2.new(1,-16,0,14)
KillPanelTitle.Position = UDim2.new(0,8,0,4)
KillPanelTitle.BackgroundTransparency = 1
KillPanelTitle.Text = "Выбери цель:"
KillPanelTitle.TextColor3 = Color3.fromRGB(255,140,140)
KillPanelTitle.Font = Enum.Font.GothamBold
KillPanelTitle.TextSize = 11
KillPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
KillPanelTitle.Parent = KillPanel

local KillPlayerList = Instance.new("ScrollingFrame")
KillPlayerList.Size = UDim2.new(1,-16,0,150)
KillPlayerList.Position = UDim2.new(0,8,0,22)
KillPlayerList.BackgroundColor3 = Color3.fromRGB(25,18,22)
KillPlayerList.BorderSizePixel = 0
KillPlayerList.ScrollBarThickness = 4
KillPlayerList.ScrollBarImageColor3 = Color3.fromRGB(220,80,80)
KillPlayerList.CanvasSize = UDim2.new(0,0,0,0)
KillPlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
KillPlayerList.Parent = KillPanel

local KillListC = Instance.new("UICorner")
KillListC.CornerRadius = UDim.new(0,4)
KillListC.Parent = KillPlayerList

local KillListLayout = Instance.new("UIListLayout")
KillListLayout.Padding = UDim.new(0,2)
KillListLayout.Parent = KillPlayerList

local function killPlayer(targetPlayer)
    if not targetPlayer then return end
    local myChar = LP.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local targetChar = targetPlayer.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    
    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 0.5, 0)
    myRoot.Velocity = Vector3.zero
    
    local hum = myChar:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local backpack = LP:FindFirstChild("Backpack")
    if not backpack then return end
    
    local tool = nil
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then tool = item; break end
    end
    if not tool then
        for _, item in ipairs(myChar:GetChildren()) do
            if item:IsA("Tool") then tool = item; break end
        end
    end
    if not tool then
        warn("[SpermaHub] Нет оружия для Kill Player")
        return
    end
    
    if tool.Parent == backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.1)
    end
    
    task.spawn(function()
        for i = 1, 30 do
            if not tool or not tool.Parent then break end
            if targetRoot and targetRoot.Parent then
                myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 0.5, 0)
                myRoot.Velocity = Vector3.zero
            end
            pcall(function() tool:Activate() end)
            task.wait(0.03)
        end
    end)
end

local function refreshKillList()
    for _, c in ipairs(KillPlayerList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1,0,0,26)
            b.BackgroundColor3 = Color3.fromRGB(60,35,40)
            b.Text = plr.Name
            b.TextColor3 = Color3.fromRGB(255,220,220)
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 10
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Parent = KillPlayerList
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0,4)
            bc.Parent = b
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 6)
            pad.Parent = b
            
            task.spawn(function()
                while b.Parent and KillPanel.Visible do
                    local myChar = LP.Character
                    local tChar = plr.Character
                    if myChar and tChar then
                        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                        if myRoot and tRoot then
                            b.Text = plr.Name .. "  [" .. math.floor((myRoot.Position - tRoot.Position).Magnitude) .. "]"
                        end
                    end
                    task.wait(0.5)
                end
            end)
            
            b.MouseButton1Click:Connect(function()
                killPlayer(plr)
                print("[SpermaHub] Kill Player → " .. plr.Name)
            end)
        end
    end
end

local function toggleKillPanel()
    S.killPanelOpen = not S.killPanelOpen
    if S.killPanelOpen then
        KillPanel.Visible = true
        refreshKillList()
        TweenService:Create(KillPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,180)
        }):Play()
    else
        local t = TweenService:Create(KillPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.killPanelOpen then KillPanel.Visible = false end
        end)
    end
end

-- ============ ПАНЕЛЬ HITBOX EXPANDER ============
local HitboxPanel = Instance.new("Frame")
HitboxPanel.Size = UDim2.new(1,0,0,0)
HitboxPanel.BackgroundColor3 = Color3.fromRGB(45,30,45)
HitboxPanel.BackgroundTransparency = 0.1
HitboxPanel.BorderSizePixel = 0
HitboxPanel.LayoutOrder = 4
HitboxPanel.ClipsDescendants = true
HitboxPanel.Visible = false
HitboxPanel.Parent = CombatScroll

local HitboxPanelC = Instance.new("UICorner")
HitboxPanelC.CornerRadius = UDim.new(0,6)
HitboxPanelC.Parent = HitboxPanel

local HitboxTitle = Instance.new("TextLabel")
HitboxTitle.Size = UDim2.new(1,-16,0,14)
HitboxTitle.Position = UDim2.new(0,8,0,4)
HitboxTitle.BackgroundTransparency = 1
HitboxTitle.Text = "Размер хитбокса"
HitboxTitle.TextColor3 = Color3.fromRGB(255,180,255)
HitboxTitle.Font = Enum.Font.GothamBold
HitboxTitle.TextSize = 11
HitboxTitle.TextXAlignment = Enum.TextXAlignment.Left
HitboxTitle.Parent = HitboxPanel

local HitboxValueLabel = Instance.new("TextLabel")
HitboxValueLabel.Size = UDim2.new(1,-16,0,16)
HitboxValueLabel.Position = UDim2.new(0,8,0,20)
HitboxValueLabel.BackgroundTransparency = 1
HitboxValueLabel.Text = "5"
HitboxValueLabel.TextColor3 = Color3.fromRGB(220,220,240)
HitboxValueLabel.Font = Enum.Font.GothamBold
HitboxValueLabel.TextSize = 13
HitboxValueLabel.TextXAlignment = Enum.TextXAlignment.Left
HitboxValueLabel.Parent = HitboxPanel

local HitboxSliderBg = Instance.new("Frame")
HitboxSliderBg.Size = UDim2.new(1,-16,0,12)
HitboxSliderBg.Position = UDim2.new(0,8,0,42)
HitboxSliderBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
HitboxSliderBg.BorderSizePixel = 0
HitboxSliderBg.Parent = HitboxPanel

local HitboxSlBgC = Instance.new("UICorner")
HitboxSlBgC.CornerRadius = UDim.new(0,6)
HitboxSlBgC.Parent = HitboxSliderBg

local HitboxSliderFill = Instance.new("Frame")
HitboxSliderFill.Size = UDim2.new(0.14,0,1,0)
HitboxSliderFill.BackgroundColor3 = Color3.fromRGB(230,120,255)
HitboxSliderFill.BorderSizePixel = 0
HitboxSliderFill.Parent = HitboxSliderBg

local HitboxSlFC = Instance.new("UICorner")
HitboxSlFC.CornerRadius = UDim.new(0,6)
HitboxSlFC.Parent = HitboxSliderFill

local HitboxPresetTitle = Instance.new("TextLabel")
HitboxPresetTitle.Size = UDim2.new(1,-16,0,14)
HitboxPresetTitle.Position = UDim2.new(0,8,0,60)
HitboxPresetTitle.BackgroundTransparency = 1
HitboxPresetTitle.Text = "Пресеты"
HitboxPresetTitle.TextColor3 = Color3.fromRGB(255,180,255)
HitboxPresetTitle.Font = Enum.Font.GothamBold
HitboxPresetTitle.TextSize = 10
HitboxPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
HitboxPresetTitle.Parent = HitboxPanel

local HitboxPresetRow = Instance.new("Frame")
HitboxPresetRow.Size = UDim2.new(1,-16,0,20)
HitboxPresetRow.Position = UDim2.new(0,8,0,76)
HitboxPresetRow.BackgroundTransparency = 1
HitboxPresetRow.Parent = HitboxPanel

local HitboxPL = Instance.new("UIListLayout")
HitboxPL.FillDirection = Enum.FillDirection.Horizontal
HitboxPL.Padding = UDim.new(0,3)
HitboxPL.Parent = HitboxPresetRow

local hitboxPresetBtns = {}
for i, preset in ipairs({{"3",3},{"5",5},{"10",10},{"20",20}}) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0,32,1,0)
    pBtn.BackgroundColor3 = Color3.fromRGB(50,40,60)
    pBtn.Text = preset[1]
    pBtn.TextColor3 = Color3.fromRGB(220,220,240)
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.LayoutOrder = i
    pBtn.Parent = HitboxPresetRow
    local pC = Instance.new("UICorner")
    pC.CornerRadius = UDim.new(0,4)
    pC.Parent = pBtn
    hitboxPresetBtns[i] = {btn = pBtn, val = preset[2]}
    pBtn.MouseButton1Click:Connect(function()
        S.hitboxSize = preset[2]
        HitboxValueLabel.Text = tostring(preset[2])
        HitboxSliderFill.Size = UDim2.new((preset[2] - 1) / 29, 0, 1, 0)
        for _, p in ipairs(hitboxPresetBtns) do
            p.btn.BackgroundColor3 = Color3.fromRGB(50,40,60)
        end
        pBtn.BackgroundColor3 = Color3.fromRGB(160,60,200)
    end)
end

-- ============ ПАНЕЛЬ AIMBOT ============
local AimbotPanel = Instance.new("Frame")
AimbotPanel.Size = UDim2.new(1,0,0,0)
AimbotPanel.BackgroundColor3 = Color3.fromRGB(45,30,30)
AimbotPanel.BackgroundTransparency = 0.1
AimbotPanel.BorderSizePixel = 0
AimbotPanel.LayoutOrder = 6
AimbotPanel.ClipsDescendants = true
AimbotPanel.Visible = false
AimbotPanel.Parent = CombatScroll

local AimbotPanelC = Instance.new("UICorner")
AimbotPanelC.CornerRadius = UDim.new(0,6)
AimbotPanelC.Parent = AimbotPanel

local AimbotTitle = Instance.new("TextLabel")
AimbotTitle.Size = UDim2.new(1,-16,0,14)
AimbotTitle.Position = UDim2.new(0,8,0,4)
AimbotTitle.BackgroundTransparency = 1
AimbotTitle.Text = "FOV радиус"
AimbotTitle.TextColor3 = Color3.fromRGB(255,140,140)
AimbotTitle.Font = Enum.Font.GothamBold
AimbotTitle.TextSize = 11
AimbotTitle.TextXAlignment = Enum.TextXAlignment.Left
AimbotTitle.Parent = AimbotPanel

local AimbotValueLabel = Instance.new("TextLabel")
AimbotValueLabel.Size = UDim2.new(1,-16,0,16)
AimbotValueLabel.Position = UDim2.new(0,8,0,20)
AimbotValueLabel.BackgroundTransparency = 1
AimbotValueLabel.Text = "120"
AimbotValueLabel.TextColor3 = Color3.fromRGB(220,220,240)
AimbotValueLabel.Font = Enum.Font.GothamBold
AimbotValueLabel.TextSize = 13
AimbotValueLabel.TextXAlignment = Enum.TextXAlignment.Left
AimbotValueLabel.Parent = AimbotPanel

local AimbotSliderBg = Instance.new("Frame")
AimbotSliderBg.Size = UDim2.new(1,-16,0,12)
AimbotSliderBg.Position = UDim2.new(0,8,0,42)
AimbotSliderBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
AimbotSliderBg.BorderSizePixel = 0
AimbotSliderBg.Parent = AimbotPanel

local AimbotSlBgC = Instance.new("UICorner")
AimbotSlBgC.CornerRadius = UDim.new(0,6)
AimbotSlBgC.Parent = AimbotSliderBg

local AimbotSliderFill = Instance.new("Frame")
AimbotSliderFill.Size = UDim2.new(0.2,0,1,0)
AimbotSliderFill.BackgroundColor3 = Color3.fromRGB(255,80,80)
AimbotSliderFill.BorderSizePixel = 0
AimbotSliderFill.Parent = AimbotSliderBg

local AimbotSlFC = Instance.new("UICorner")
AimbotSlFC.CornerRadius = UDim.new(0,6)
AimbotSlFC.Parent = AimbotSliderFill

local AimbotPresetTitle = Instance.new("TextLabel")
AimbotPresetTitle.Size = UDim2.new(1,-16,0,14)
AimbotPresetTitle.Position = UDim2.new(0,8,0,60)
AimbotPresetTitle.BackgroundTransparency = 1
AimbotPresetTitle.Text = "Пресеты FOV"
AimbotPresetTitle.TextColor3 = Color3.fromRGB(255,140,140)
AimbotPresetTitle.Font = Enum.Font.GothamBold
AimbotPresetTitle.TextSize = 10
AimbotPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
AimbotPresetTitle.Parent = AimbotPanel

local AimbotPresetRow = Instance.new("Frame")
AimbotPresetRow.Size = UDim2.new(1,-16,0,20)
AimbotPresetRow.Position = UDim2.new(0,8,0,76)
AimbotPresetRow.BackgroundTransparency = 1
AimbotPresetRow.Parent = AimbotPanel

local AimbotPL = Instance.new("UIListLayout")
AimbotPL.FillDirection = Enum.FillDirection.Horizontal
AimbotPL.Padding = UDim.new(0,3)
AimbotPL.Parent = AimbotPresetRow

local aimbotPresetBtns = {}
for i, preset in ipairs({{"60",60},{"120",120},{"200",200},{"350",350}}) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0,32,1,0)
    pBtn.BackgroundColor3 = Color3.fromRGB(60,40,40)
    pBtn.Text = preset[1]
    pBtn.TextColor3 = Color3.fromRGB(220,220,240)
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.LayoutOrder = i
    pBtn.Parent = AimbotPresetRow
    local pC = Instance.new("UICorner")
    pC.CornerRadius = UDim.new(0,4)
    pC.Parent = pBtn
    aimbotPresetBtns[i] = {btn = pBtn, val = preset[2]}
    pBtn.MouseButton1Click:Connect(function()
        S.aimbotFov = preset[2]
        AimbotValueLabel.Text = tostring(preset[2])
        AimbotSliderFill.Size = UDim2.new((preset[2] - 20) / 480, 0, 1, 0)
        for _, p in ipairs(aimbotPresetBtns) do
            p.btn.BackgroundColor3 = Color3.fromRGB(60,40,40)
        end
        pBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
        if S.fovCircle then
            local size = preset[2] * 2
            S.fovCircle.Size = UDim2.new(0, size, 0, size)
        end
    end)
end

-- ============ ПАНЕЛЬ SILENT AIM ============
local SilentAimPanel = Instance.new("Frame")
SilentAimPanel.Size = UDim2.new(1,0,0,0)
SilentAimPanel.BackgroundColor3 = Color3.fromRGB(30,30,50)
SilentAimPanel.BackgroundTransparency = 0.1
SilentAimPanel.BorderSizePixel = 0
SilentAimPanel.LayoutOrder = 8
SilentAimPanel.ClipsDescendants = true
SilentAimPanel.Visible = false
SilentAimPanel.Parent = CombatScroll

local SilentAimPanelC = Instance.new("UICorner")
SilentAimPanelC.CornerRadius = UDim.new(0,6)
SilentAimPanelC.Parent = SilentAimPanel

local SilentAimTitle = Instance.new("TextLabel")
SilentAimTitle.Size = UDim2.new(1,-16,0,14)
SilentAimTitle.Position = UDim2.new(0,8,0,4)
SilentAimTitle.BackgroundTransparency = 1
SilentAimTitle.Text = "FOV радиус"
SilentAimTitle.TextColor3 = Color3.fromRGB(140,140,255)
SilentAimTitle.Font = Enum.Font.GothamBold
SilentAimTitle.TextSize = 11
SilentAimTitle.TextXAlignment = Enum.TextXAlignment.Left
SilentAimTitle.Parent = SilentAimPanel

local SilentAimValueLabel = Instance.new("TextLabel")
SilentAimValueLabel.Size = UDim2.new(1,-16,0,16)
SilentAimValueLabel.Position = UDim2.new(0,8,0,20)
SilentAimValueLabel.BackgroundTransparency = 1
SilentAimValueLabel.Text = "150"
SilentAimValueLabel.TextColor3 = Color3.fromRGB(220,220,240)
SilentAimValueLabel.Font = Enum.Font.GothamBold
SilentAimValueLabel.TextSize = 13
SilentAimValueLabel.TextXAlignment = Enum.TextXAlignment.Left
SilentAimValueLabel.Parent = SilentAimPanel

local SilentAimSliderBg = Instance.new("Frame")
SilentAimSliderBg.Size = UDim2.new(1,-16,0,12)
SilentAimSliderBg.Position = UDim2.new(0,8,0,42)
SilentAimSliderBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
SilentAimSliderBg.BorderSizePixel = 0
SilentAimSliderBg.Parent = SilentAimPanel

local SilentAimSlBgC = Instance.new("UICorner")
SilentAimSlBgC.CornerRadius = UDim.new(0,6)
SilentAimSlBgC.Parent = SilentAimSliderBg

local SilentAimSliderFill = Instance.new("Frame")
SilentAimSliderFill.Size = UDim2.new(0.3,0,1,0)
SilentAimSliderFill.BackgroundColor3 = Color3.fromRGB(100,100,255)
SilentAimSliderFill.BorderSizePixel = 0
SilentAimSliderFill.Parent = SilentAimSliderBg

local SilentAimSlFC = Instance.new("UICorner")
SilentAimSlFC.CornerRadius = UDim.new(0,6)
SilentAimSlFC.Parent = SilentAimSliderFill

local SilentAimPresetTitle = Instance.new("TextLabel")
SilentAimPresetTitle.Size = UDim2.new(1,-16,0,14)
SilentAimPresetTitle.Position = UDim2.new(0,8,0,60)
SilentAimPresetTitle.BackgroundTransparency = 1
SilentAimPresetTitle.Text = "Пресеты FOV"
SilentAimPresetTitle.TextColor3 = Color3.fromRGB(140,140,255)
SilentAimPresetTitle.Font = Enum.Font.GothamBold
SilentAimPresetTitle.TextSize = 10
SilentAimPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
SilentAimPresetTitle.Parent = SilentAimPanel

local SilentAimPresetRow = Instance.new("Frame")
SilentAimPresetRow.Size = UDim2.new(1,-16,0,20)
SilentAimPresetRow.Position = UDim2.new(0,8,0,76)
SilentAimPresetRow.BackgroundTransparency = 1
SilentAimPresetRow.Parent = SilentAimPanel

local SilentAimPL = Instance.new("UIListLayout")
SilentAimPL.FillDirection = Enum.FillDirection.Horizontal
SilentAimPL.Padding = UDim.new(0,3)
SilentAimPL.Parent = SilentAimPresetRow

local silentAimPresetBtns = {}
for i, preset in ipairs({{"80",80},{"150",150},{"250",250},{"400",400}}) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0,32,1,0)
    pBtn.BackgroundColor3 = Color3.fromRGB(40,40,60)
    pBtn.Text = preset[1]
    pBtn.TextColor3 = Color3.fromRGB(220,220,240)
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.LayoutOrder = i
    pBtn.Parent = SilentAimPresetRow
    local pC = Instance.new("UICorner")
    pC.CornerRadius = UDim.new(0,4)
    pC.Parent = pBtn
    silentAimPresetBtns[i] = {btn = pBtn, val = preset[2]}
    pBtn.MouseButton1Click:Connect(function()
        S.silentAimFov = preset[2]
        SilentAimValueLabel.Text = tostring(preset[2])
        SilentAimSliderFill.Size = UDim2.new((preset[2] - 20) / 480, 0, 1, 0)
        for _, p in ipairs(silentAimPresetBtns) do
            p.btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
        end
        pBtn.BackgroundColor3 = Color3.fromRGB(100,100,200)
        if S.silentAimFovCircle then
            local size = preset[2] * 2
            S.silentAimFovCircle.Size = UDim2.new(0, size, 0, size)
        end
    end)
end

-- ============ FOV CIRCLE ============
local FovGui = Instance.new("ScreenGui")
FovGui.Name = "SpermaHubFov"
FovGui.ResetOnSpawn = false
FovGui.IgnoreGuiInset = true
FovGui.DisplayOrder = 60
FovGui.Parent = LP:WaitForChild("PlayerGui")

local FovCircle = Instance.new("Frame")
FovCircle.Name = "FovCircle"
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.new(0, 240, 0, 240)
FovCircle.BackgroundTransparency = 1
FovCircle.BorderSizePixel = 0
FovCircle.Visible = false
FovCircle.ZIndex = 100
FovCircle.Parent = FovGui

local FovCircleCorner = Instance.new("UICorner")
FovCircleCorner.CornerRadius = UDim.new(1, 0)
FovCircleCorner.Parent = FovCircle

local FovCircleStroke = Instance.new("UIStroke")
FovCircleStroke.Color = Color3.fromRGB(255, 80, 80)
FovCircleStroke.Thickness = 2
FovCircleStroke.Transparency = 0.2
FovCircleStroke.Parent = FovCircle

S.fovCircle = FovCircle

-- FOV-круг для Silent Aim
local SilentFovCircle = Instance.new("Frame")
SilentFovCircle.Name = "SilentFovCircle"
SilentFovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
SilentFovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
SilentFovCircle.Size = UDim2.new(0, 300, 0, 300)
SilentFovCircle.BackgroundTransparency = 1
SilentFovCircle.BorderSizePixel = 0
SilentFovCircle.Visible = false
SilentFovCircle.ZIndex = 99
SilentFovCircle.Parent = FovGui

local SilentFovCircleCorner = Instance.new("UICorner")
SilentFovCircleCorner.CornerRadius = UDim.new(1, 0)
SilentFovCircleCorner.Parent = SilentFovCircle

local SilentFovCircleStroke = Instance.new("UIStroke")
SilentFovCircleStroke.Color = Color3.fromRGB(100, 100, 255)
SilentFovCircleStroke.Thickness = 2
SilentFovCircleStroke.Transparency = 0.2
SilentFovCircleStroke.Parent = SilentFovCircle

S.silentAimFovCircle = SilentFovCircle

local function updateFovCircle()
    if S.fovCircle then
        local size = S.aimbotFov * 2
        S.fovCircle.Size = UDim2.new(0, size, 0, size)
        S.fovCircle.Visible = S.aimbotOn or S.aimbotPanelOpen
    end
end

local function updateSilentFovCircle()
    if S.silentAimFovCircle then
        local size = S.silentAimFov * 2
        S.silentAimFovCircle.Size = UDim2.new(0, size, 0, size)
        S.silentAimFovCircle.Visible = S.silentAimOn or S.silentAimPanelOpen
    end
end

-- ============ AIMBOT ЛОГИКА ============
local function getClosestTarget()
    local cam = workspace.CurrentCamera
    local closest = nil
    local closestDist = S.aimbotFov
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ch = plr.Character
            if ch then
                local head = ch:FindFirstChild("Head")
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 then
                    local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local centerX = cam.ViewportSize.X / 2
                        local centerY = cam.ViewportSize.Y / 2
                        local dist = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
                        if dist < closestDist then
                            closestDist = dist
                            closest = head
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function enableAimbot()
    S.aimbotOn = true
    if S.aimbotConn then S.aimbotConn:Disconnect() end
    S.aimbotConn = RunService.RenderStepped:Connect(function()
        if not S.aimbotOn then return end
        local target = getClosestTarget()
        if target then
            local cam = workspace.CurrentCamera
            local targetPos = target.Position
            local currentCF = cam.CFrame
            local lookAt = CFrame.new(currentCF.Position, targetPos)
            cam.CFrame = currentCF:Lerp(lookAt, S.aimbotSmooth)
        end
    end)
end

local function disableAimbot()
    S.aimbotOn = false
    if S.aimbotConn then S.aimbotConn:Disconnect() S.aimbotConn = nil end
end

-- ============ SILENT AIM ЛОГИКА (Real-compatible) ============
local function findSilentTarget()
    local cam = workspace.CurrentCamera
    local closest = nil
    local closestDist = S.silentAimFov
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ch = plr.Character
            if ch then
                local head = ch:FindFirstChild("Head")
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 then
                    local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local centerX = cam.ViewportSize.X / 2
                        local centerY = cam.ViewportSize.Y / 2
                        local dist = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
                        if dist < closestDist then
                            closestDist = dist
                            closest = plr
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function checkSilentAimSupport()
    local hasHook = false
    local hasMeta = false
    local hasSetReadonly = false
    local hasNewcclosure = false
    
    pcall(function() hasHook = type(hookfunction) == "function" end)
    pcall(function() hasMeta = type(getrawmetatable) == "function" end)
    pcall(function() hasSetReadonly = type(setreadonly) == "function" end)
    pcall(function() hasNewcclosure = type(newcclosure) == "function" end)
    
    return hasHook and hasMeta and hasSetReadonly and hasNewcclosure
end

local function enableSilentAim()
    S.silentAimOn = true
    
    if not checkSilentAimSupport() then
        warn("[SpermaHub] Silent Aim: executor не поддерживает hookfunction")
        warn("[SpermaHub] Работает только FOV circle")
        return
    end
    
    if S.silentAimConn then 
        pcall(function() S.silentAimConn:Disconnect() end)
        S.silentAimConn = nil 
    end
    
    local success, err = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        local oldIndex = mt.__index
        
        setreadonly(mt, false)
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            
            if S.silentAimOn and (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") then
                local target = findSilentTarget()
                if target then
                    local targetChar = target.Character
                    if targetChar then
                        local targetPart = targetChar:FindFirstChild("Head") 
                            or targetChar:FindFirstChild("UpperTorso") 
                            or targetChar:FindFirstChild("Torso")
                        if targetPart then
                            local args = {...}
                            if args[1] and args[1].Origin then
                                local origin = args[1].Origin
                                local newDir = (targetPart.Position - origin).Unit * 1000
                                args[1] = Ray.new(origin, newDir)
                            end
                            return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            
            return oldNamecall(self, ...)
        end)
        
        mt.__index = newcclosure(function(self, key)
            local result = oldIndex(self, key)
            
            if S.silentAimOn and typeof(self) == "Instance" and self:IsA("Mouse") then
                if key == "Hit" or key == "Target" then
                    local target = findSilentTarget()
                    if target and target.Character then
                        local targetPart = target.Character:FindFirstChild("Head") 
                            or target.Character:FindFirstChild("UpperTorso") 
                            or target.Character:FindFirstChild("Torso")
                        if targetPart then
                            if key == "Hit" then
                                return CFrame.new(targetPart.Position)
                            elseif key == "Target" then
                                return targetPart
                            end
                        end
                    end
                end
            end
            
            return result
        end)
        
        setreadonly(mt, true)
        
        S.silentAimConn = {
            Disconnect = function()
                pcall(function()
                    setreadonly(mt, false)
                    mt.__namecall = oldNamecall
                    mt.__index = oldIndex
                    setreadonly(mt, true)
                end)
            end
        }
    end)
    
    if success then
        print("[SpermaHub] Silent Aim активирован ✓")
    else
        warn("[SpermaHub] Silent Aim ошибка: " .. tostring(err))
    end
end

local function disableSilentAim()
    S.silentAimOn = false
    if S.silentAimConn then 
        pcall(function() S.silentAimConn:Disconnect() end)
        S.silentAimConn = nil 
    end
end

-- ============ HITBOX EXPANDER ЛОГИКА ============
local hitboxOriginalSizes = {}

local function applyHitbox()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ch = plr.Character
            if ch then
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if not hitboxOriginalSizes[part] then
                            hitboxOriginalSizes[part] = part.Size
                        end
                        part.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
                        part.Transparency = 0.7
                        part.CanCollide = false
                        part.Massless = true
                    end
                end
            end
        end
    end
end

local function restoreHitbox()
    for part, size in pairs(hitboxOriginalSizes) do
        if typeof(part) == "Instance" and part.Parent then
            pcall(function()
                part.Size = size
                part.Transparency = 0
                part.CanCollide = true
                part.Massless = false
            end)
        end
    end
    hitboxOriginalSizes = {}
end

local function enableHitbox()
    S.hitboxOn = true
    applyHitbox()
    if S.hitboxConn then S.hitboxConn:Disconnect() end
    S.hitboxConn = RunService.Heartbeat:Connect(function()
        if not S.hitboxOn then return end
        applyHitbox()
    end)
end

local function disableHitbox()
    S.hitboxOn = false
    if S.hitboxConn then S.hitboxConn:Disconnect() S.hitboxConn = nil end
    restoreHitbox()
end

-- ============ ПАНЕЛЬ FLIGHT ============
local FlyPanel = Instance.new("Frame")
FlyPanel.Size = UDim2.new(1,0,0,0)
FlyPanel.BackgroundColor3 = Color3.fromRGB(32,28,45)
FlyPanel.BackgroundTransparency = 0.1
FlyPanel.BorderSizePixel = 0
FlyPanel.LayoutOrder = 2
FlyPanel.ClipsDescendants = true
FlyPanel.Visible = false
FlyPanel.Parent = MoveScroll

local FlyPanelC = Instance.new("UICorner")
FlyPanelC.CornerRadius = UDim.new(0,6)
FlyPanelC.Parent = FlyPanel

local FlyPanelTitle = Instance.new("TextLabel")
FlyPanelTitle.Size = UDim2.new(1,-16,0,14)
FlyPanelTitle.Position = UDim2.new(0,8,0,4)
FlyPanelTitle.BackgroundTransparency = 1
FlyPanelTitle.Text = "Скорость"
FlyPanelTitle.TextColor3 = Color3.fromRGB(220,180,255)
FlyPanelTitle.Font = Enum.Font.GothamBold
FlyPanelTitle.TextSize = 11
FlyPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
FlyPanelTitle.Parent = FlyPanel

local FlyValueLabel = Instance.new("TextLabel")
FlyValueLabel.Size = UDim2.new(1,-16,0,16)
FlyValueLabel.Position = UDim2.new(0,8,0,20)
FlyValueLabel.BackgroundTransparency = 1
FlyValueLabel.Text = "50"
FlyValueLabel.TextColor3 = Color3.fromRGB(220,220,240)
FlyValueLabel.Font = Enum.Font.GothamBold
FlyValueLabel.TextSize = 13
FlyValueLabel.TextXAlignment = Enum.TextXAlignment.Left
FlyValueLabel.Parent = FlyPanel

local FlySliderBg = Instance.new("Frame")
FlySliderBg.Size = UDim2.new(1,-16,0,12)
FlySliderBg.Position = UDim2.new(0,8,0,42)
FlySliderBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
FlySliderBg.BorderSizePixel = 0
FlySliderBg.Parent = FlyPanel

local FlySlBgC = Instance.new("UICorner")
FlySlBgC.CornerRadius = UDim.new(0,6)
FlySlBgC.Parent = FlySliderBg

local FlySliderFill = Instance.new("Frame")
FlySliderFill.Size = UDim2.new(0.2,0,1,0)
FlySliderFill.BackgroundColor3 = Color3.fromRGB(180,60,220)
FlySliderFill.BorderSizePixel = 0
FlySliderFill.Parent = FlySliderBg

local FlySlFC = Instance.new("UICorner")
FlySlFC.CornerRadius = UDim.new(0,6)
FlySlFC.Parent = FlySliderFill

local FlyPresetTitle = Instance.new("TextLabel")
FlyPresetTitle.Size = UDim2.new(1,-16,0,14)
FlyPresetTitle.Position = UDim2.new(0,8,0,60)
FlyPresetTitle.BackgroundTransparency = 1
FlyPresetTitle.Text = "Пресеты"
FlyPresetTitle.TextColor3 = Color3.fromRGB(200,180,230)
FlyPresetTitle.Font = Enum.Font.GothamBold
FlyPresetTitle.TextSize = 10
FlyPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
FlyPresetTitle.Parent = FlyPanel

local FlyPresetRow = Instance.new("Frame")
FlyPresetRow.Size = UDim2.new(1,-16,0,20)
FlyPresetRow.Position = UDim2.new(0,8,0,76)
FlyPresetRow.BackgroundTransparency = 1
FlyPresetRow.Parent = FlyPanel

local FlyPL = Instance.new("UIListLayout")
FlyPL.FillDirection = Enum.FillDirection.Horizontal
FlyPL.Padding = UDim.new(0,3)
FlyPL.Parent = FlyPresetRow

local flyPresetBtns = {}
for i, preset in ipairs({{"50",50},{"100",100},{"150",150},{"250",250}}) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0,32,1,0)
    pBtn.BackgroundColor3 = Color3.fromRGB(50,40,65)
    pBtn.Text = preset[1]
    pBtn.TextColor3 = Color3.fromRGB(220,220,240)
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.LayoutOrder = i
    pBtn.Parent = FlyPresetRow
    local pC = Instance.new("UICorner")
    pC.CornerRadius = UDim.new(0,4)
    pC.Parent = pBtn
    flyPresetBtns[i] = {btn = pBtn, val = preset[2]}
    pBtn.MouseButton1Click:Connect(function()
        S.speed = preset[2]
        FlyValueLabel.Text = tostring(preset[2])
        FlySliderFill.Size = UDim2.new((preset[2] - 10) / 240, 0, 1, 0)
        for _, p in ipairs(flyPresetBtns) do
            p.btn.BackgroundColor3 = Color3.fromRGB(50,40,65)
        end
        pBtn.BackgroundColor3 = Color3.fromRGB(120,60,180)
    end)
end

-- ============ ПАНЕЛЬ CLICK TP ============
local ClickTpPanel = Instance.new("Frame")
ClickTpPanel.Size = UDim2.new(1,0,0,0)
ClickTpPanel.BackgroundColor3 = Color3.fromRGB(28,35,48)
ClickTpPanel.BackgroundTransparency = 0.1
ClickTpPanel.BorderSizePixel = 0
ClickTpPanel.LayoutOrder = 4
ClickTpPanel.ClipsDescendants = true
ClickTpPanel.Visible = false
ClickTpPanel.Parent = MoveScroll

local ClickTpPanelC = Instance.new("UICorner")
ClickTpPanelC.CornerRadius = UDim.new(0,6)
ClickTpPanelC.Parent = ClickTpPanel

local ClickTpTitle = Instance.new("TextLabel")
ClickTpTitle.Size = UDim2.new(1,-16,0,14)
ClickTpTitle.Position = UDim2.new(0,8,0,4)
ClickTpTitle.BackgroundTransparency = 1
ClickTpTitle.Text = "Высота ТП"
ClickTpTitle.TextColor3 = Color3.fromRGB(120,220,255)
ClickTpTitle.Font = Enum.Font.GothamBold
ClickTpTitle.TextSize = 11
ClickTpTitle.TextXAlignment = Enum.TextXAlignment.Left
ClickTpTitle.Parent = ClickTpPanel

local ClickTpValueLabel = Instance.new("TextLabel")
ClickTpValueLabel.Size = UDim2.new(1,-16,0,16)
ClickTpValueLabel.Position = UDim2.new(0,8,0,20)
ClickTpValueLabel.BackgroundTransparency = 1
ClickTpValueLabel.Text = "3"
ClickTpValueLabel.TextColor3 = Color3.fromRGB(220,220,240)
ClickTpValueLabel.Font = Enum.Font.GothamBold
ClickTpValueLabel.TextSize = 13
ClickTpValueLabel.TextXAlignment = Enum.TextXAlignment.Left
ClickTpValueLabel.Parent = ClickTpPanel

local ClickTpSliderBg = Instance.new("Frame")
ClickTpSliderBg.Size = UDim2.new(1,-16,0,12)
ClickTpSliderBg.Position = UDim2.new(0,8,0,42)
ClickTpSliderBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
ClickTpSliderBg.BorderSizePixel = 0
ClickTpSliderBg.Parent = ClickTpPanel

local ClickTpSlBgC = Instance.new("UICorner")
ClickTpSlBgC.CornerRadius = UDim.new(0,6)
ClickTpSlBgC.Parent = ClickTpSliderBg

local ClickTpSliderFill = Instance.new("Frame")
ClickTpSliderFill.Size = UDim2.new(0.1,0,1,0)
ClickTpSliderFill.BackgroundColor3 = Color3.fromRGB(60,180,220)
ClickTpSliderFill.BorderSizePixel = 0
ClickTpSliderFill.Parent = ClickTpSliderBg

local ClickTpSlFC = Instance.new("UICorner")
ClickTpSlFC.CornerRadius = UDim.new(0,6)
ClickTpSlFC.Parent = ClickTpSliderFill

local ClickTpPresetTitle = Instance.new("TextLabel")
ClickTpPresetTitle.Size = UDim2.new(1,-16,0,14)
ClickTpPresetTitle.Position = UDim2.new(0,8,0,60)
ClickTpPresetTitle.BackgroundTransparency = 1
ClickTpPresetTitle.Text = "Пресеты"
ClickTpPresetTitle.TextColor3 = Color3.fromRGB(120,220,255)
ClickTpPresetTitle.Font = Enum.Font.GothamBold
ClickTpPresetTitle.TextSize = 10
ClickTpPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
ClickTpPresetTitle.Parent = ClickTpPanel

local ClickTpPresetRow = Instance.new("Frame")
ClickTpPresetRow.Size = UDim2.new(1,-16,0,20)
ClickTpPresetRow.Position = UDim2.new(0,8,0,76)
ClickTpPresetRow.BackgroundTransparency = 1
ClickTpPresetRow.Parent = ClickTpPanel

local ClickTpPL = Instance.new("UIListLayout")
ClickTpPL.FillDirection = Enum.FillDirection.Horizontal
ClickTpPL.Padding = UDim.new(0,3)
ClickTpPL.Parent = ClickTpPresetRow

local clickTpPresetBtns = {}
for i, preset in ipairs({{"1",1},{"3",3},{"5",5},{"10",10}}) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0,32,1,0)
    pBtn.BackgroundColor3 = Color3.fromRGB(40,55,70)
    pBtn.Text = preset[1]
    pBtn.TextColor3 = Color3.fromRGB(220,220,240)
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.LayoutOrder = i
    pBtn.Parent = ClickTpPresetRow
    local pC = Instance.new("UICorner")
    pC.CornerRadius = UDim.new(0,4)
    pC.Parent = pBtn
    clickTpPresetBtns[i] = {btn = pBtn, val = preset[2]}
    pBtn.MouseButton1Click:Connect(function()
        S.clickTpHeight = preset[2]
        ClickTpValueLabel.Text = tostring(preset[2])
        ClickTpSliderFill.Size = UDim2.new((preset[2] - 1) / 19, 0, 1, 0)
        for _, p in ipairs(clickTpPresetBtns) do
            p.btn.BackgroundColor3 = Color3.fromRGB(40,55,70)
        end
        pBtn.BackgroundColor3 = Color3.fromRGB(60,140,180)
    end)
end

-- ============ ПАНЕЛЬ WALKSPEED ============
local WsPanel = Instance.new("Frame")
WsPanel.Size = UDim2.new(1,0,0,0)
WsPanel.BackgroundColor3 = Color3.fromRGB(28,35,48)
WsPanel.BackgroundTransparency = 0.1
WsPanel.BorderSizePixel = 0
WsPanel.LayoutOrder = 2
WsPanel.ClipsDescendants = true
WsPanel.Visible = false
WsPanel.Parent = PlayScroll

local WsPanelC = Instance.new("UICorner")
WsPanelC.CornerRadius = UDim.new(0,6)
WsPanelC.Parent = WsPanel

local WsPanelTitle = Instance.new("TextLabel")
WsPanelTitle.Size = UDim2.new(1,-16,0,14)
WsPanelTitle.Position = UDim2.new(0,8,0,4)
WsPanelTitle.BackgroundTransparency = 1
WsPanelTitle.Text = "Скорость"
WsPanelTitle.TextColor3 = Color3.fromRGB(140,200,255)
WsPanelTitle.Font = Enum.Font.GothamBold
WsPanelTitle.TextSize = 11
WsPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
WsPanelTitle.Parent = WsPanel

local WsValueLabel = Instance.new("TextLabel")
WsValueLabel.Size = UDim2.new(1,-16,0,16)
WsValueLabel.Position = UDim2.new(0,8,0,20)
WsValueLabel.BackgroundTransparency = 1
WsValueLabel.Text = "16"
WsValueLabel.TextColor3 = Color3.fromRGB(220,220,240)
WsValueLabel.Font = Enum.Font.GothamBold
WsValueLabel.TextSize = 13
WsValueLabel.TextXAlignment = Enum.TextXAlignment.Left
WsValueLabel.Parent = WsPanel

local WsSliderBg = Instance.new("Frame")
WsSliderBg.Size = UDim2.new(1,-16,0,12)
WsSliderBg.Position = UDim2.new(0,8,0,42)
WsSliderBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
WsSliderBg.BorderSizePixel = 0
WsSliderBg.Parent = WsPanel

local WsSlBgC = Instance.new("UICorner")
WsSlBgC.CornerRadius = UDim.new(0,6)
WsSlBgC.Parent = WsSliderBg

local WsSliderFill = Instance.new("Frame")
WsSliderFill.Size = UDim2.new(0,0,1,0)
WsSliderFill.BackgroundColor3 = Color3.fromRGB(60,180,220)
WsSliderFill.BorderSizePixel = 0
WsSliderFill.Parent = WsSliderBg

local WsSlFC = Instance.new("UICorner")
WsSlFC.CornerRadius = UDim.new(0,6)
WsSlFC.Parent = WsSliderFill

local WsPresetTitle = Instance.new("TextLabel")
WsPresetTitle.Size = UDim2.new(1,-16,0,14)
WsPresetTitle.Position = UDim2.new(0,8,0,60)
WsPresetTitle.BackgroundTransparency = 1
WsPresetTitle.Text = "Пресеты"
WsPresetTitle.TextColor3 = Color3.fromRGB(140,200,255)
WsPresetTitle.Font = Enum.Font.GothamBold
WsPresetTitle.TextSize = 10
WsPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
WsPresetTitle.Parent = WsPanel

local WsPresetRow = Instance.new("Frame")
WsPresetRow.Size = UDim2.new(1,-16,0,20)
WsPresetRow.Position = UDim2.new(0,8,0,76)
WsPresetRow.BackgroundTransparency = 1
WsPresetRow.Parent = WsPanel

local WsPL = Instance.new("UIListLayout")
WsPL.FillDirection = Enum.FillDirection.Horizontal
WsPL.Padding = UDim.new(0,3)
WsPL.Parent = WsPresetRow

local wsPresetBtns = {}
for i, preset in ipairs({{"16",16},{"50",50},{"100",100},{"200",200}}) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0,32,1,0)
    pBtn.BackgroundColor3 = Color3.fromRGB(40,55,70)
    pBtn.Text = preset[1]
    pBtn.TextColor3 = Color3.fromRGB(220,220,240)
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.LayoutOrder = i
    pBtn.Parent = WsPresetRow
    local pC = Instance.new("UICorner")
    pC.CornerRadius = UDim.new(0,4)
    pC.Parent = pBtn
    wsPresetBtns[i] = {btn = pBtn, val = preset[2]}
    pBtn.MouseButton1Click:Connect(function()
        S.walkSpeed = preset[2]
        WsValueLabel.Text = tostring(preset[2])
        WsSliderFill.Size = UDim2.new((preset[2] - 16) / 184, 0, 1, 0)
        if S.walkSpeedOn then
            local ch = LP.Character
            if ch then
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = preset[2] end
            end
        end
        for _, p in ipairs(wsPresetBtns) do
            p.btn.BackgroundColor3 = Color3.fromRGB(40,55,70)
        end
        pBtn.BackgroundColor3 = Color3.fromRGB(60,140,180)
    end)
end

-- ============ ПАНЕЛЬ TP PLAYER ============
local TpPanel = Instance.new("Frame")
TpPanel.Size = UDim2.new(1,0,0,0)
TpPanel.BackgroundColor3 = Color3.fromRGB(35,30,50)
TpPanel.BackgroundTransparency = 0.1
TpPanel.BorderSizePixel = 0
TpPanel.LayoutOrder = 4
TpPanel.ClipsDescendants = true
TpPanel.Visible = false
TpPanel.Parent = PlayScroll

local TpPanelC = Instance.new("UICorner")
TpPanelC.CornerRadius = UDim.new(0,6)
TpPanelC.Parent = TpPanel

local TpPanelTitle = Instance.new("TextLabel")
TpPanelTitle.Size = UDim2.new(1,-16,0,14)
TpPanelTitle.Position = UDim2.new(0,8,0,4)
TpPanelTitle.BackgroundTransparency = 1
TpPanelTitle.Text = "Игроки:"
TpPanelTitle.TextColor3 = Color3.fromRGB(200,180,255)
TpPanelTitle.Font = Enum.Font.GothamBold
TpPanelTitle.TextSize = 11
TpPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
TpPanelTitle.Parent = TpPanel

local TpPlayerList = Instance.new("ScrollingFrame")
TpPlayerList.Size = UDim2.new(1,-16,0,150)
TpPlayerList.Position = UDim2.new(0,8,0,22)
TpPlayerList.BackgroundColor3 = Color3.fromRGB(22,20,32)
TpPlayerList.BorderSizePixel = 0
TpPlayerList.ScrollBarThickness = 4
TpPlayerList.ScrollBarImageColor3 = Color3.fromRGB(140,100,220)
TpPlayerList.CanvasSize = UDim2.new(0,0,0,0)
TpPlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
TpPlayerList.Parent = TpPanel

local TpListC = Instance.new("UICorner")
TpListC.CornerRadius = UDim.new(0,4)
TpListC.Parent = TpPlayerList

local TpListLayout = Instance.new("UIListLayout")
TpListLayout.Padding = UDim.new(0,2)
TpListLayout.Parent = TpPlayerList

local function refreshTpList()
    for _, c in ipairs(TpPlayerList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1,0,0,26)
            b.BackgroundColor3 = Color3.fromRGB(45,38,60)
            b.Text = plr.Name
            b.TextColor3 = Color3.fromRGB(220,220,240)
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 10
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Parent = TpPlayerList
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0,4)
            bc.Parent = b
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 6)
            pad.Parent = b
            
            task.spawn(function()
                while b.Parent and TpPanel.Visible do
                    local myChar = LP.Character
                    local tChar = plr.Character
                    if myChar and tChar then
                        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                        if myRoot and tRoot then
                            b.Text = plr.Name .. "  [" .. math.floor((myRoot.Position - tRoot.Position).Magnitude) .. "]"
                        end
                    end
                    task.wait(0.5)
                end
            end)
            
            b.MouseButton1Click:Connect(function()
                local myChar = LP.Character
                if not myChar then return end
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                if not myRoot then return end
                local tChar = plr.Character
                if not tChar then return end
                local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                myRoot.CFrame = tRoot.CFrame + Vector3.new(0, 1, 0)
                myRoot.Velocity = Vector3.zero
                print("[SpermaHub] Телепорт к " .. plr.Name)
            end)
        end
    end
end

local function toggleTpPanel()
    S.tpPanelOpen = not S.tpPanelOpen
    if S.tpPanelOpen then
        TpPanel.Visible = true
        refreshTpList()
        TweenService:Create(TpPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,180)
        }):Play()
    else
        local t = TweenService:Create(TpPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.tpPanelOpen then TpPanel.Visible = false end
        end)
    end
end

-- ============ WATERMARK ============
local WG = Instance.new("ScreenGui")
WG.Name = "SpermaHubWatermark"
WG.ResetOnSpawn = false
WG.IgnoreGuiInset = true
WG.DisplayOrder = 100
WG.Parent = LP:WaitForChild("PlayerGui")

local WM = Instance.new("Frame")
WM.Size = UDim2.new(0,280,0,68)
WM.Position = UDim2.new(0,12,0,12)
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
BrandLabel.Text = "✦ Cracked"
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
    while WG.Parent do
        local f = 0
        local conn
        conn = RunService.RenderStepped:Connect(function()
            f = f + 1
        end)
        task.wait(1)
        if conn then conn:Disconnect() end
        S.fps = f
    end
end)

task.spawn(function()
    local months = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
    while WG.Parent do
        if S.wmOn then
            local p = 0
            pcall(function()
                local serverStats = Stats.Network.ServerStatsItem
                if serverStats and serverStats["Data Ping"] then
                    p = math.floor(serverStats["Data Ping"]:GetValue())
                end
            end)
            S.ping = p
            local fpsColor
            if S.fps >= 50 then fpsColor = Color3.fromRGB(200,255,200)
            elseif S.fps >= 30 then fpsColor = Color3.fromRGB(255,240,160)
            else fpsColor = Color3.fromRGB(255,160,160) end
            local pingColor
            if p < 80 then pingColor = Color3.fromRGB(120,255,140)
            elseif p < 150 then pingColor = Color3.fromRGB(255,220,100)
            else pingColor = Color3.fromRGB(255,120,120) end
            FpsLabel.Text = string.format("%d Fps", S.fps)
            FpsLabel.TextColor3 = fpsColor
            PingLabel.Text = string.format("%d Ping", p)
            PingLabel.TextColor3 = pingColor
            local t = os.date("*t")
            TimeLabel.Text = string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
            DateLabel.Text = string.format("%s.%d", months[t.month], t.year)
        end
        task.wait(0.5)
    end
end)

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
        if S.bv then S.bv.Velocity = d.Magnitude > 0 and d.Unit * S.speed or Vector3.zero end
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
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

local function disableNoclip()
    S.noclip = false
    if S.noclipConn then S.noclipConn:Disconnect() S.noclipConn = nil end
    local ch = LP.Character
    if ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
        end
    end
end

-- ============ CLICK TP ============
local function enableClickTp()
    S.clickTpOn = true
    if S.clickTpConn then S.clickTpConn:Disconnect() end
    S.clickTpConn = UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if not S.clickTpOn then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = LP:GetMouse()
            if mouse and mouse.Target then
                local ch = LP.Character
                if not ch then return end
                local root = ch:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local pos = mouse.Hit.Position + Vector3.new(0, S.clickTpHeight, 0)
                root.CFrame = CFrame.new(pos)
                root.Velocity = Vector3.zero
            end
        end
    end)
end

local function disableClickTp()
    S.clickTpOn = false
    if S.clickTpConn then S.clickTpConn:Disconnect() S.clickTpConn = nil end
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
    if hum and S.walkSpeedOn then
        if math.abs(hum.WalkSpeed - S.walkSpeed) > 0.1 then
            hum.WalkSpeed = S.walkSpeed
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
    local data = {lines = {}, highlight = nil, billboard = nil, boxLines = {}}
    espObjects[plr] = data
    
    local ch = plr.Character
    if ch then
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 40, 40)
        hl.OutlineColor = Color3.fromRGB(255, 255, 0)
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = ch
        hl.Parent = ESPGui
        data.highlight = hl
    end
    
    for i = 1, 4 do
        local line = Instance.new("Frame")
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
        line.BorderSizePixel = 0
        line.ZIndex = 6
        line.Visible = false
        line.Parent = ESPGui
        data.boxLines[i] = line
    end
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPName"
    bb.Size = UDim2.new(0, 220, 0, 70)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ESPGui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
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
    
    local hitboxLabel = Instance.new("TextLabel")
    hitboxLabel.Size = UDim2.new(1, 0, 0, 16)
    hitboxLabel.Position = UDim2.new(0, 0, 0, 36)
    hitboxLabel.BackgroundTransparency = 1
    hitboxLabel.Text = "Hitbox: --"
    hitboxLabel.TextColor3 = Color3.fromRGB(255, 180, 255)
    hitboxLabel.TextStrokeTransparency = 0
    hitboxLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hitboxLabel.Font = Enum.Font.GothamBold
    hitboxLabel.TextSize = 12
    hitboxLabel.Parent = bb
    
    data.billboard = bb
    data.nameLabel = nameLabel
    data.hpLabel = hpLabel
    data.hitboxLabel = hitboxLabel
end

local function removeESP(plr)
    local data = espObjects[plr]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    if data.boxLines then
        for _, line in ipairs(data.boxLines) do
            if line then line:Destroy() end
        end
    end
    espObjects[plr] = nil
end

local function updateESP()
    local cam = workspace.CurrentCamera
    for plr, data in pairs(espObjects) do
        local ch = plr.Character
        if ch and isAlive(plr) then
            local head = ch:FindFirstChild("Head")
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            
            if data.highlight then 
                data.highlight.Adornee = ch
                data.highlight.Enabled = true
            end
            if data.billboard and head then data.billboard.Adornee = head end
            if data.nameLabel then data.nameLabel.Text = plr.Name end
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
            
            if data.hitboxLabel and hrp then
                local totalSize = 0
                local count = 0
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        totalSize = totalSize + part.Size.X
                        count = count + 1
                    end
                end
                if count > 0 then
                    local avgSize = totalSize / count
                    if avgSize > 2.5 then
                        data.hitboxLabel.Text = string.format("Hitbox: %.1f ⚠", avgSize)
                        data.hitboxLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    else
                        data.hitboxLabel.Text = string.format("Hitbox: %.1f", avgSize)
                        data.hitboxLabel.TextColor3 = Color3.fromRGB(255, 180, 255)
                    end
                end
            end
            
            if hrp and data.boxLines and #data.boxLines >= 4 then
                local headPos = head and head.Position or (hrp.Position + Vector3.new(0, 1.5, 0))
                local footPos = hrp.Position - Vector3.new(0, 3, 0)
                
                local topV, topOn = cam:WorldToViewportPoint(headPos + Vector3.new(0, 0.5, 0))
                local botV, botOn = cam:WorldToViewportPoint(footPos)
                
                if topOn and botOn then
                    local height = math.abs(botV.Y - topV.Y)
                    local width = height * 0.55
                    local x = topV.X - width / 2
                    local y = topV.Y
                    
                    data.boxLines[1].Size = UDim2.new(0, width, 0, 1)
                    data.boxLines[1].Position = UDim2.new(0, x, 0, y)
                    data.boxLines[1].Visible = true
                    
                    data.boxLines[2].Size = UDim2.new(0, width, 0, 1)
                    data.boxLines[2].Position = UDim2.new(0, x, 0, y + height)
                    data.boxLines[2].Visible = true
                    
                    data.boxLines[3].Size = UDim2.new(0, 1, 0, height)
                    data.boxLines[3].Position = UDim2.new(0, x, 0, y)
                    data.boxLines[3].Visible = true
                    
                    data.boxLines[4].Size = UDim2.new(0, 1, 0, height)
                    data.boxLines[4].Position = UDim2.new(0, x + width, 0, y)
                    data.boxLines[4].Visible = true
                else
                    for _, line in ipairs(data.boxLines) do
                        line.Visible = false
                    end
                end
            end
        else
            if data.highlight then data.highlight.Adornee = nil end
            if data.billboard then data.billboard.Adornee = nil end
            if data.boxLines then
                for _, line in ipairs(data.boxLines) do
                    line.Visible = false
                end
            end
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
                            f.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
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
                        f.Size = UDim2.new(0, length, 0, 2)
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
        FlyDots.TextColor3 = Color3.fromRGB(120,255,140)
        FlyLabel.TextColor3 = Color3.fromRGB(120,255,140)
    else
        FlyDots.TextColor3 = Color3.fromRGB(140,140,170)
        FlyLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updNoclip()
    if S.noclip then
        NoclipDots.TextColor3 = Color3.fromRGB(120,255,140)
        NoclipLabel.TextColor3 = Color3.fromRGB(120,255,140)
    else
        NoclipDots.TextColor3 = Color3.fromRGB(140,140,170)
        NoclipLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updWm()
    if S.wmOn then
        WmDots.TextColor3 = Color3.fromRGB(120,255,140)
        WmLabel.TextColor3 = Color3.fromRGB(120,255,140)
    else
        WmDots.TextColor3 = Color3.fromRGB(140,140,170)
        WmLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updEsp()
    if S.esp then
        EspDots.TextColor3 = Color3.fromRGB(120,255,140)
        EspLabel.TextColor3 = Color3.fromRGB(120,255,140)
    else
        EspDots.TextColor3 = Color3.fromRGB(140,140,170)
        EspLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updWs()
    if S.walkSpeedOn then
        WsDots.TextColor3 = Color3.fromRGB(120,220,255)
        WsLabel.TextColor3 = Color3.fromRGB(120,220,255)
    else
        WsDots.TextColor3 = Color3.fromRGB(140,140,170)
        WsLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updClickTp()
    if S.clickTpOn then
        ClickTpDots.TextColor3 = Color3.fromRGB(120,220,255)
        ClickTpLabel.TextColor3 = Color3.fromRGB(120,220,255)
    else
        ClickTpDots.TextColor3 = Color3.fromRGB(140,140,170)
        ClickTpLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updHitbox()
    if S.hitboxOn then
        HitboxDots.TextColor3 = Color3.fromRGB(255,180,255)
        HitboxLabel.TextColor3 = Color3.fromRGB(255,180,255)
    else
        HitboxDots.TextColor3 = Color3.fromRGB(140,140,170)
        HitboxLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updAimbot()
    if S.aimbotOn then
        AimbotDots.TextColor3 = Color3.fromRGB(255,100,100)
        AimbotLabel.TextColor3 = Color3.fromRGB(255,100,100)
    else
        AimbotDots.TextColor3 = Color3.fromRGB(140,140,170)
        AimbotLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

local function updSilentAim()
    if S.silentAimOn then
        SilentAimDots.TextColor3 = Color3.fromRGB(140,140,255)
        SilentAimLabel.TextColor3 = Color3.fromRGB(140,140,255)
    else
        SilentAimDots.TextColor3 = Color3.fromRGB(140,140,170)
        SilentAimLabel.TextColor3 = Color3.fromRGB(220,220,240)
    end
end

-- ============ ПАНЕЛИ ============
local function toggleFlyPanel()
    S.flyPanelOpen = not S.flyPanelOpen
    if S.flyPanelOpen then
        FlyPanel.Visible = true
        FlyValueLabel.Text = tostring(S.speed)
        FlySliderFill.Size = UDim2.new((S.speed - 10) / 240, 0, 1, 0)
        TweenService:Create(FlyPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,100)
        }):Play()
    else
        local t = TweenService:Create(FlyPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.flyPanelOpen then FlyPanel.Visible = false end
        end)
    end
end

local function toggleClickTpPanel()
    S.clickTpPanelOpen = not S.clickTpPanelOpen
    if S.clickTpPanelOpen then
        ClickTpPanel.Visible = true
        ClickTpValueLabel.Text = tostring(S.clickTpHeight)
        ClickTpSliderFill.Size = UDim2.new((S.clickTpHeight - 1) / 19, 0, 1, 0)
        TweenService:Create(ClickTpPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,100)
        }):Play()
    else
        local t = TweenService:Create(ClickTpPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.clickTpPanelOpen then ClickTpPanel.Visible = false end
        end)
    end
end

local function toggleWsPanel()
    S.wsPanelOpen = not S.wsPanelOpen
    if S.wsPanelOpen then
        WsPanel.Visible = true
        WsValueLabel.Text = tostring(S.walkSpeed)
        WsSliderFill.Size = UDim2.new((S.walkSpeed - 16) / 184, 0, 1, 0)
        TweenService:Create(WsPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,100)
        }):Play()
    else
        local t = TweenService:Create(WsPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.wsPanelOpen then WsPanel.Visible = false end
        end)
    end
end

-- ============ КЛИКИ ============
KillBtn.MouseButton1Click:Connect(toggleKillPanel)

HitboxBtn.MouseButton1Click:Connect(function()
    if S.hitboxOn then disableHitbox() else enableHitbox() end
    updHitbox()
end)

HitboxBtn.MouseButton2Click:Connect(function()
    S.hitboxPanelOpen = not S.hitboxPanelOpen
    if S.hitboxPanelOpen then
        HitboxPanel.Visible = true
        HitboxValueLabel.Text = tostring(S.hitboxSize)
        HitboxSliderFill.Size = UDim2.new((S.hitboxSize - 1) / 29, 0, 1, 0)
        TweenService:Create(HitboxPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,100)
        }):Play()
    else
        local t = TweenService:Create(HitboxPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.hitboxPanelOpen then HitboxPanel.Visible = false end
        end)
    end
end)

AimbotBtn.MouseButton1Click:Connect(function()
    if S.aimbotOn then disableAimbot() else enableAimbot() end
    updateFovCircle()
    updAimbot()
end)

AimbotBtn.MouseButton2Click:Connect(function()
    S.aimbotPanelOpen = not S.aimbotPanelOpen
    if S.aimbotPanelOpen then
        AimbotPanel.Visible = true
        AimbotValueLabel.Text = tostring(S.aimbotFov)
        AimbotSliderFill.Size = UDim2.new((S.aimbotFov - 20) / 480, 0, 1, 0)
        updateFovCircle()
        TweenService:Create(AimbotPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,100)
        }):Play()
    else
        local t = TweenService:Create(AimbotPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.aimbotPanelOpen then 
                AimbotPanel.Visible = false 
                updateFovCircle()
            end
        end)
    end
end)

SilentAimBtn.MouseButton1Click:Connect(function()
    if S.silentAimOn then disableSilentAim() else enableSilentAim() end
    updateSilentFovCircle()
    updSilentAim()
end)

SilentAimBtn.MouseButton2Click:Connect(function()
    S.silentAimPanelOpen = not S.silentAimPanelOpen
    if S.silentAimPanelOpen then
        SilentAimPanel.Visible = true
        SilentAimValueLabel.Text = tostring(S.silentAimFov)
        SilentAimSliderFill.Size = UDim2.new((S.silentAimFov - 20) / 480, 0, 1, 0)
        updateSilentFovCircle()
        TweenService:Create(SilentAimPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,0,100)
        }):Play()
    else
        local t = TweenService:Create(SilentAimPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1,0,0,0)
        })
        t:Play()
        t.Completed:Connect(function()
            if not S.silentAimPanelOpen then 
                SilentAimPanel.Visible = false 
                updateSilentFovCircle()
            end
        end)
    end
end)

FlyBtn.MouseButton1Click:Connect(function()
    if S.flying then stopFly() else startFly() end
    updFly()
end)

FlyBtn.MouseButton2Click:Connect(toggleFlyPanel)

ClickTpBtn.MouseButton1Click:Connect(function()
    if S.clickTpOn then disableClickTp() else enableClickTp() end
    updClickTp()
end)

ClickTpBtn.MouseButton2Click:Connect(toggleClickTpPanel)

WsBtn.MouseButton1Click:Connect(function()
    S.walkSpeedOn = not S.walkSpeedOn
    applyWalkSpeed()
    updWs()
end)

WsBtn.MouseButton2Click:Connect(toggleWsPanel)

TpBtn.MouseButton1Click:Connect(toggleTpPanel)

NoclipBtn.MouseButton1Click:Connect(function()
    if S.noclip then disableNoclip() else enableNoclip() end
    updNoclip()
end)

EspBtn.MouseButton1Click:Connect(function()
    if S.esp then disableESP() else enableESP() end
    updEsp()
end)

WmBtn.MouseButton1Click:Connect(function()
    S.wmOn = not S.wmOn
    WM.Visible = S.wmOn
    updWm()
end)

-- Круглая кнопка
ToggleBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
    if Main.Visible then
        TweenService:Create(TS, TweenInfo.new(0.3), {Color=Color3.fromRGB(180,40,200)}):Play()
        TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {TextColor3=Color3.fromRGB(230,130,255)}):Play()
    else
        TweenService:Create(TS, TweenInfo.new(0.3), {Color=Color3.fromRGB(255,180,80)}):Play()
        TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {TextColor3=Color3.fromRGB(255,200,100)}):Play()
    end
end)

-- ============ CLOSE SCRIPT ============
CloseScriptBtn.MouseButton1Click:Connect(function()
    if S.flyConn then S.flyConn:Disconnect() end
    if S.noclipConn then S.noclipConn:Disconnect() end
    if S.espConn then S.espConn:Disconnect() end
    if S.wsConn then S.wsConn:Disconnect() end
    if S.clickTpConn then S.clickTpConn:Disconnect() end
    if S.hitboxConn then S.hitboxConn:Disconnect() end
    if S.aimbotConn then S.aimbotConn:Disconnect() end
    if S.silentAimConn then pcall(function() S.silentAimConn:Disconnect() end) end
    if S.bv then S.bv:Destroy() end
    if S.bg then S.bg:Destroy() end
    pcall(restoreHitbox)
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
    for _, n in ipairs({
        "SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle",
        "SpermaHubESP","SpermaHubSettings","SpermaHubWsSettings","SpermaHubTpList",
        "SpermaHubFov"
    }) do
        local g = LP.PlayerGui:FindFirstChild(n)
        if g then g:Destroy() end
    end
    print("✦ SpermaHub полностью выгружен")
end)

-- ============ ПОЛЗУНКИ ============
local dragFlyInline = false
FlySliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragFlyInline = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragFlyInline = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragFlyInline then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - FlySliderBg.AbsolutePosition.X) / FlySliderBg.AbsoluteSize.X, 0, 1)
        FlySliderFill.Size = UDim2.new(rel,0,1,0)
        S.speed = math.floor(rel * 240) + 10
        FlyValueLabel.Text = tostring(S.speed)
    end
end)

local dragClickTpInline = false
ClickTpSliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragClickTpInline = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragClickTpInline = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragClickTpInline then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - ClickTpSliderBg.AbsolutePosition.X) / ClickTpSliderBg.AbsoluteSize.X, 0, 1)
        ClickTpSliderFill.Size = UDim2.new(rel,0,1,0)
        S.clickTpHeight = math.floor(rel * 19) + 1
        ClickTpValueLabel.Text = tostring(S.clickTpHeight)
    end
end)

local dragWsInline = false
WsSliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragWsInline = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragWsInline = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragWsInline then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - WsSliderBg.AbsolutePosition.X) / WsSliderBg.AbsoluteSize.X, 0, 1)
        WsSliderFill.Size = UDim2.new(rel,0,1,0)
        S.walkSpeed = math.floor(rel * 184) + 16
        WsValueLabel.Text = tostring(S.walkSpeed)
        if S.walkSpeedOn then applyWalkSpeed() end
    end
end)

local dragHitboxInline = false
HitboxSliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragHitboxInline = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragHitboxInline = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragHitboxInline then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - HitboxSliderBg.AbsolutePosition.X) / HitboxSliderBg.AbsoluteSize.X, 0, 1)
        HitboxSliderFill.Size = UDim2.new(rel,0,1,0)
        S.hitboxSize = math.floor(rel * 29) + 1
        HitboxValueLabel.Text = tostring(S.hitboxSize)
    end
end)

local dragAimbotInline = false
AimbotSliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragAimbotInline = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragAimbotInline = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragAimbotInline then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - AimbotSliderBg.AbsolutePosition.X) / AimbotSliderBg.AbsoluteSize.X, 0, 1)
        AimbotSliderFill.Size = UDim2.new(rel,0,1,0)
        S.aimbotFov = math.floor(rel * 480) + 20
        AimbotValueLabel.Text = tostring(S.aimbotFov)
        if S.fovCircle then
            local size = S.aimbotFov * 2
            S.fovCircle.Size = UDim2.new(0, size, 0, size)
        end
    end
end)

local dragSilentAimInline = false
SilentAimSliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragSilentAimInline = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragSilentAimInline = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragSilentAimInline then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local rel = math.clamp((input.Position.X - SilentAimSliderBg.AbsolutePosition.X) / SilentAimSliderBg.AbsoluteSize.X, 0, 1)
        SilentAimSliderFill.Size = UDim2.new(rel,0,1,0)
        S.silentAimFov = math.floor(rel * 480) + 20
        SilentAimValueLabel.Text = tostring(S.silentAimFov)
        if S.silentAimFovCircle then
            local size = S.silentAimFov * 2
            S.silentAimFovCircle.Size = UDim2.new(0, size, 0, size)
        end
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

-- Инициализация
updFly()
updNoclip()
updWm()
updEsp()
updWs()
updClickTp()
updHitbox()
updAimbot()
updSilentAim()
updateFovCircle()
updateSilentFovCircle()
WM.Visible = S.wmOn

print("✦ SpermaHub v41 загружен! Управление только через меню")
print("Combat: Kill Player | Hitbox Expander | Aimbot | Silent Aim")
