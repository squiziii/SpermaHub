-- SpermaHub v41 | WindUI Edition
-- GUI перенесена на библиотеку WindUI (https://github.com/Footagesus/WindUI)
-- Перенесены ВСЕ разделы и функции из оригинального sperma.lua:
--   Combat:        Kill Player | Hitbox Expander | Aimbot | Silent Aim | Auto Clicker
--   Movement:      Flight | Click TP | Noclip
--   Visuals:       ESP (Box + Skeleton + HP + Hitbox) | Watermark (FPS/Ping/Time/Date) | HUD (NL-style)
--   Player:        WalkSpeed | TP Player
--   Miscellaneous: Тема | Close Script
-- Управление: RightShift или круглая кнопка = скрыть/показать меню

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer

-- ============ ОЧИСТКА СТАРЫХ ВЕРСИЙ ============
for _, n in ipairs({
    "SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle",
    "SpermaHubESP","SpermaHubSettings","SpermaHubWsSettings","SpermaHubTpList",
    "SpermaHubFlingTarget","SpermaHubFov","SpermaHubHUD"
}) do
    local o = LP.PlayerGui:FindFirstChild(n)
    if o then o:Destroy() end
end
pcall(function()
    if getgenv and getgenv().SpermaHubWindWindow then
        getgenv().SpermaHubWindWindow:Destroy()
        getgenv().SpermaHubWindWindow = nil
    end
end)

-- ============ ЗАГРУЗКА WINDUI ============
local okUI, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)
if not okUI or not WindUI then
    warn("[SpermaHub] Не удалось загрузить WindUI: " .. tostring(WindUI))
    return
end

local function notify(title, content, duration, icon)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
            Icon = icon or "bell",
        })
    end)
end

-- ============ СОСТОЯНИЕ ============
local S = {
    flying=false, noclip=false, esp=false, speed=50,
    wmOn=true,
    bv=nil, bg=nil, flyConn=nil, noclipConn=nil, espConn=nil,
    fps=60, ping=0,
    walkSpeed=16, walkSpeedOn=false, wsConn=nil,
    clickTpOn=false, clickTpHeight=3, clickTpConn=nil,
    hitboxOn=false, hitboxSize=5, hitboxConn=nil,
    aimbotOn=false, aimbotFov=120, aimbotSmooth=0.3, aimbotConn=nil,
    fovCircle=nil,
    silentAimOn=false, silentAimFov=150, silentAimConn=nil, silentAimFovCircle=nil,
    autoClickOn=false, autoClickCps=10, autoClickMode="ЛКМ",
    autoClickGen=0, autoClickBind=Enum.KeyCode.X, autoClickBindConn=nil,
    guiAlive=true,
}

-- ============================================================
-- ============ ЛОГИКА (перенесена из sperma.lua) =============
-- ============================================================

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
        S.fovCircle.Visible = S.aimbotOn
    end
end

local function updateSilentFovCircle()
    if S.silentAimFovCircle then
        local size = S.silentAimFov * 2
        S.silentAimFovCircle.Size = UDim2.new(0, size, 0, size)
        S.silentAimFovCircle.Visible = S.silentAimOn
    end
end

-- Временный показ круга при настройке FOV слайдером (аналог открытой панели)
local fovFlash = {aimbot = 0, silent = 0}
local function flashFovCircle(kind, circle, isOn)
    fovFlash[kind] = fovFlash[kind] + 1
    local token = fovFlash[kind]
    if not isOn() then circle.Visible = true end
    task.delay(1.5, function()
        if fovFlash[kind] == token and not isOn() then
            circle.Visible = false
        end
    end)
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
    local hasHook, hasMeta, hasSetReadonly, hasNewcclosure = false, false, false, false
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
        notify("Silent Aim", "Executor не поддерживает hookfunction. Работает только FOV circle", 5, "alert-triangle")
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
        notify("Silent Aim", "Ошибка: " .. tostring(err), 5, "alert-triangle")
    end
end

local function disableSilentAim()
    S.silentAimOn = false
    if S.silentAimConn then
        pcall(function() S.silentAimConn:Disconnect() end)
        S.silentAimConn = nil
    end
end

-- ============ AUTO CLICKER ЛОГИКА ============
-- Клик через VirtualInputManager (резерв, если нет функций executor'а)
local function vimClick(b) -- b: 0 = ЛКМ, 1 = ПКМ
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local loc = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(loc.X, loc.Y, b, true, false, 1)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(loc.X, loc.Y, b, false, false, 1)
    end)
end

-- button: 1 = ЛКМ, 2 = ПКМ
local function clickMouse(button)
    if button == 1 then
        if type(mouse1click) == "function" then pcall(mouse1click)
        elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
            pcall(function() mouse1press() mouse1release() end)
        else
            vimClick(0)
        end
    else
        if type(mouse2click) == "function" then pcall(mouse2click)
        elseif type(mouse2press) == "function" and type(mouse2release) == "function" then
            pcall(function() mouse2press() mouse2release() end)
        else
            vimClick(1)
        end
    end
end

local function enableAutoClicker()
    S.autoClickOn = false
    S.autoClickGen = S.autoClickGen + 1 -- останавливаем прошлый цикл
    S.autoClickOn = true
    local gen = S.autoClickGen
    task.spawn(function()
        while S.autoClickOn and gen == S.autoClickGen do
            local interval = 1 / math.max(S.autoClickCps, 1)
            if S.autoClickMode == "ЛКМ" or S.autoClickMode == "ЛКМ + ПКМ" then
                clickMouse(1)
            end
            if S.autoClickMode == "ПКМ" or S.autoClickMode == "ЛКМ + ПКМ" then
                clickMouse(2)
            end
            task.wait(interval)
        end
    end)
end

local function disableAutoClicker()
    S.autoClickOn = false
    S.autoClickGen = S.autoClickGen + 1
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

-- ============ KILL PLAYER ЛОГИКА ============
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
        notify("Kill Player", "Нет оружия в инвентаре!", 3, "alert-triangle")
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

-- ============ TP PLAYER ЛОГИКА ============
local function tpToPlayer(targetPlayer)
    local myChar = LP.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local tChar = targetPlayer and targetPlayer.Character
    if not tChar then return end
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end
    myRoot.CFrame = tRoot.CFrame + Vector3.new(0, 1, 0)
    myRoot.Velocity = Vector3.zero
    print("[SpermaHub] Телепорт к " .. targetPlayer.Name)
end

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

-- ============ HUD (NL-style: сверху по центру) ============
local HUD_BRAND = "spermahub" -- текст слева в баре, можно сменить напр. на "NL"

local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "SpermaHubHUD"
HUDGui.ResetOnSpawn = false
HUDGui.IgnoreGuiInset = true
HUDGui.DisplayOrder = 101
HUDGui.Enabled = false
HUDGui.Parent = LP:WaitForChild("PlayerGui")

local HUDBar = Instance.new("Frame")
HUDBar.Name = "HUDBar"
HUDBar.AnchorPoint = Vector2.new(0.5, 0)
HUDBar.Position = UDim2.new(0.5, 0, 0, 10)
HUDBar.Size = UDim2.new(0, 0, 0, 24)
HUDBar.AutomaticSize = Enum.AutomaticSize.X
HUDBar.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
HUDBar.BackgroundTransparency = 0.2
HUDBar.BorderSizePixel = 0
HUDBar.Parent = HUDGui

local HUDC = Instance.new("UICorner")
HUDC.CornerRadius = UDim.new(0, 6)
HUDC.Parent = HUDBar

local HUDStroke = Instance.new("UIStroke")
HUDStroke.Color = Color3.fromRGB(60, 60, 80)
HUDStroke.Thickness = 1
HUDStroke.Transparency = 0.6
HUDStroke.Parent = HUDBar

local HUDPad = Instance.new("UIPadding")
HUDPad.PaddingLeft = UDim.new(0, 10)
HUDPad.PaddingRight = UDim.new(0, 10)
HUDPad.Parent = HUDBar

local HUDLayout = Instance.new("UIListLayout")
HUDLayout.FillDirection = Enum.FillDirection.Horizontal
HUDLayout.SortOrder = Enum.SortOrder.LayoutOrder
HUDLayout.VerticalAlignment = Enum.VerticalAlignment.Center
HUDLayout.Padding = UDim.new(0, 8)
HUDLayout.Parent = HUDBar

local HUDBrand = Instance.new("TextLabel")
HUDBrand.Size = UDim2.new(0, 0, 1, 0)
HUDBrand.AutomaticSize = Enum.AutomaticSize.X
HUDBrand.BackgroundTransparency = 1
HUDBrand.Text = HUD_BRAND
HUDBrand.TextColor3 = Color3.fromRGB(235, 235, 245)
HUDBrand.Font = Enum.Font.GothamBold
HUDBrand.TextSize = 13
HUDBrand.LayoutOrder = 1
HUDBrand.Parent = HUDBar

local HUDSep = Instance.new("TextLabel")
HUDSep.Size = UDim2.new(0, 0, 1, 0)
HUDSep.AutomaticSize = Enum.AutomaticSize.X
HUDSep.BackgroundTransparency = 1
HUDSep.Text = "|"
HUDSep.TextColor3 = Color3.fromRGB(90, 90, 110)
HUDSep.Font = Enum.Font.GothamBold
HUDSep.TextSize = 13
HUDSep.LayoutOrder = 2
HUDSep.Parent = HUDBar

local HUDFps = Instance.new("TextLabel")
HUDFps.Size = UDim2.new(0, 0, 1, 0)
HUDFps.AutomaticSize = Enum.AutomaticSize.X
HUDFps.BackgroundTransparency = 1
HUDFps.Text = "-- FPS"
HUDFps.TextColor3 = Color3.fromRGB(235, 235, 245)
HUDFps.Font = Enum.Font.GothamBold
HUDFps.TextSize = 13
HUDFps.LayoutOrder = 3
HUDFps.Parent = HUDBar

-- Живой счётчик FPS (обновление раз в секунду)
task.spawn(function()
    while HUDGui.Parent do
        local f = 0
        local conn
        conn = RunService.RenderStepped:Connect(function()
            f = f + 1
        end)
        task.wait(1)
        if conn then conn:Disconnect() end
        HUDFps.Text = tostring(f) .. " FPS"
    end
end)

-- ============================================================
-- ================== WINDUI: ОКНО И РАЗДЕЛЫ ==================
-- ============================================================

local Window = WindUI:CreateWindow({
    Title = "SpermaHub",
    Author = "v41 | WindUI Edition",
    Icon = "sparkles",
    Folder = "SpermaHub",
    Size = UDim2.fromOffset(700, 480),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Resizable = true,
    Transparent = true,
    Theme = "Violet",
    SideBarWidth = 180,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    ToggleKey = Enum.KeyCode.RightShift,
    User = { Enabled = true },
    OpenButton = {
        Title = "✦ SpermaHub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromRGB(160, 60, 200),
            Color3.fromRGB(230, 130, 255)
        ),
    },
})
pcall(function()
    if getgenv then getgenv().SpermaHubWindWindow = Window end
end)

Window:Tag({
    Title = "v41",
    Icon = "github",
    Color = Color3.fromHex("#6d28d9"),
    Border = true,
})

-- ============ ДЕСТРУКТОР (полная выгрузка) ============
local unloaded = false
local function fullCleanup()
    if unloaded then return end
    unloaded = true
    S.guiAlive = false
    if S.flyConn then S.flyConn:Disconnect() end
    if S.noclipConn then S.noclipConn:Disconnect() end
    if S.espConn then S.espConn:Disconnect() end
    if S.wsConn then S.wsConn:Disconnect() end
    if S.clickTpConn then S.clickTpConn:Disconnect() end
    if S.hitboxConn then S.hitboxConn:Disconnect() end
    if S.aimbotConn then S.aimbotConn:Disconnect() end
    if S.silentAimConn then pcall(function() S.silentAimConn:Disconnect() end) end
    disableAutoClicker()
    if S.autoClickBindConn then S.autoClickBindConn:Disconnect() end
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
    pcall(disableESP)
    for _, n in ipairs({"SpermaHubESP","SpermaHubWatermark","SpermaHubFov","SpermaHubHUD"}) do
        local g = LP.PlayerGui:FindFirstChild(n)
        if g then g:Destroy() end
    end
    print("✦ SpermaHub полностью выгружен")
end

Window:OnDestroy(fullCleanup)

-- ============ ВКЛАДКИ (разделы, как в оригинале) ============
local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
local MoveTab   = Window:Tab({ Title = "Movement", Icon = "rocket" })
local VisTab    = Window:Tab({ Title = "Visuals", Icon = "eye" })
local PlayTab   = Window:Tab({ Title = "Player", Icon = "user" })
local MiscTab   = Window:Tab({ Title = "Miscellaneous", Icon = "settings" })

-- ============ СПИСКИ ИГРОКОВ (Kill / TP) ============
local function getPlayerValues()
    local list = {}
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local dist = "?"
            local tChar = plr.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if myRoot and tRoot then
                dist = tostring(math.floor((myRoot.Position - tRoot.Position).Magnitude))
            end
            table.insert(list, plr.Name .. "  [" .. dist .. "]")
        end
    end
    if #list == 0 then list = {"— Нет игроков —"} end
    return list
end

local function parsePlayerName(v)
    if type(v) ~= "string" then return nil end
    local name = string.match(v, "^(.-)%s*%[") or v
    if name == "— Нет игроков —" then return nil end
    return name
end

-- ============================================================
-- ======================= COMBAT TAB =========================
-- ============================================================

-- ---- Kill Player ----
local KillSection = CombatTab:Section({
    Title = "Kill Player",
    Icon = "skull",
    Box = true,
    Opened = true,
})

local killTargetName = nil

local KillDropdown = KillSection:Dropdown({
    Title = "Цель  [дистанция]",
    Desc = "Выбери игрока из списка",
    Values = getPlayerValues(),
    Callback = function(v)
        killTargetName = parsePlayerName(v)
    end,
})

KillSection:Button({
    Title = "Обновить список",
    Icon = "refresh-cw",
    Callback = function()
        task.spawn(function()
            KillDropdown:Refresh(getPlayerValues())
        end)
    end,
})

KillSection:Button({
    Title = "Убить цель",
    Desc = "ТП к цели + спам атакой (нужно оружие)",
    Icon = "skull",
    Color = Color3.fromHex("#c0392b"),
    Justify = "Center",
    Callback = function()
        local plr = killTargetName and Players:FindFirstChild(killTargetName)
        if plr then
            killPlayer(plr)
            print("[SpermaHub] Kill Player → " .. plr.Name)
            notify("Kill Player", "Атакую: " .. plr.Name, 2, "skull")
        else
            notify("Kill Player", "Сначала выбери цель из списка!", 3, "alert-triangle")
        end
    end,
})

-- ---- Hitbox Expander ----
local HitboxSection = CombatTab:Section({
    Title = "Hitbox Expander",
    Icon = "scan",
    Box = true,
    Opened = true,
})

HitboxSection:Toggle({
    Title = "Hitbox Expander",
    Desc = "Увеличивает хитбоксы всех игроков",
    Value = false,
    Callback = function(state)
        if state then enableHitbox() else disableHitbox() end
    end,
})

local HitboxSlider = HitboxSection:Slider({
    Title = "Размер хитбокса",
    Step = 1,
    Width = 200,
    Value = { Min = 1, Max = 30, Default = 5 },
    Callback = function(v)
        S.hitboxSize = math.floor(tonumber(v) or 5)
    end,
})

HitboxSection:Dropdown({
    Title = "Пресеты",
    Values = {"3", "5", "10", "20"},
    Callback = function(v)
        local val = tonumber(v)
        if val then
            S.hitboxSize = val
            HitboxSlider:Set(val)
        end
    end,
})

-- ---- Aimbot ----
local AimbotSection = CombatTab:Section({
    Title = "Aimbot",
    Icon = "crosshair",
    Box = true,
    Opened = true,
})

AimbotSection:Toggle({
    Title = "Aimbot",
    Desc = "Наводит камеру на ближайшего игрока в радиусе FOV",
    Value = false,
    Callback = function(state)
        if state then enableAimbot() else disableAimbot() end
        updateFovCircle()
    end,
})

local AimbotFovSlider = AimbotSection:Slider({
    Title = "FOV радиус",
    Step = 5,
    Width = 200,
    Value = { Min = 20, Max = 500, Default = 120 },
    Callback = function(v)
        S.aimbotFov = math.floor(tonumber(v) or 120)
        updateFovCircle()
        flashFovCircle("aimbot", FovCircle, function() return S.aimbotOn end)
    end,
})

AimbotSection:Slider({
    Title = "Smoothness",
    Desc = "Плавность наведения (меньше = резче)",
    Step = 0.05,
    Width = 200,
    Value = { Min = 0.05, Max = 1, Default = 0.3 },
    Callback = function(v)
        S.aimbotSmooth = tonumber(v) or 0.3
    end,
})

AimbotSection:Dropdown({
    Title = "Пресеты FOV",
    Values = {"60", "120", "200", "350"},
    Callback = function(v)
        local val = tonumber(v)
        if val then
            S.aimbotFov = val
            AimbotFovSlider:Set(val)
            updateFovCircle()
            flashFovCircle("aimbot", FovCircle, function() return S.aimbotOn end)
        end
    end,
})

-- ---- Silent Aim ----
local SilentSection = CombatTab:Section({
    Title = "Silent Aim",
    Icon = "target",
    Box = true,
    Opened = true,
})

SilentSection:Toggle({
    Title = "Silent Aim",
    Desc = "Пули летят в цель внутри FOV (нужна поддержка hookfunction)",
    Value = false,
    Callback = function(state)
        if state then enableSilentAim() else disableSilentAim() end
        updateSilentFovCircle()
    end,
})

local SilentFovSlider = SilentSection:Slider({
    Title = "FOV радиус",
    Step = 5,
    Width = 200,
    Value = { Min = 20, Max = 500, Default = 150 },
    Callback = function(v)
        S.silentAimFov = math.floor(tonumber(v) or 150)
        updateSilentFovCircle()
        flashFovCircle("silent", SilentFovCircle, function() return S.silentAimOn end)
    end,
})

SilentSection:Dropdown({
    Title = "Пресеты FOV",
    Values = {"80", "150", "250", "400"},
    Callback = function(v)
        local val = tonumber(v)
        if val then
            S.silentAimFov = val
            SilentFovSlider:Set(val)
            updateSilentFovCircle()
            flashFovCircle("silent", SilentFovCircle, function() return S.silentAimOn end)
        end
    end,
})

-- ---- Auto Clicker ----
local AcSection = CombatTab:Section({
    Title = "Auto Clicker",
    Icon = "mouse-pointer-click",
    Box = true,
    Opened = true,
})

local AutoClickToggle = AcSection:Toggle({
    Title = "Auto Clicker",
    Desc = "Сам кликает ЛКМ/ПКМ с заданной скоростью",
    Value = false,
    Callback = function(state)
        if state then enableAutoClicker() else disableAutoClicker() end
    end,
})

AcSection:Dropdown({
    Title = "Кнопки",
    Desc = "Какие кнопки мыши кликать",
    Values = {"ЛКМ", "ПКМ", "ЛКМ + ПКМ"},
    Value = "ЛКМ",
    Callback = function(v)
        if v then S.autoClickMode = v end
    end,
})

AcSection:Slider({
    Title = "CPS (кликов в секунду)",
    Step = 1,
    Width = 200,
    Value = { Min = 1, Max = 30, Default = 10 },
    Callback = function(v)
        S.autoClickCps = math.floor(tonumber(v) or 10)
    end,
})

AcSection:Keybind({
    Title = "Клавиша вкл/выкл",
    Desc = "Быстрое переключение автокликера",
    Value = "X",
    Callback = function(key)
        pcall(function()
            S.autoClickBind = Enum.KeyCode[key]
        end)
    end,
})

-- Переключение автокликера по назначенной клавише
S.autoClickBindConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not S.autoClickBind then return end
    if input.KeyCode == S.autoClickBind then
        AutoClickToggle:Set(not S.autoClickOn)
    end
end)

-- ============================================================
-- ====================== MOVEMENT TAB ========================
-- ============================================================

-- ---- Flight ----
local FlySection = MoveTab:Section({
    Title = "Flight",
    Icon = "rocket",
    Box = true,
    Opened = true,
})

local FlyToggle = FlySection:Toggle({
    Title = "Flight",
    Desc = "WASD + Space (вверх) / Ctrl (вниз)",
    Value = false,
    Callback = function(state)
        if state then startFly() else stopFly() end
    end,
})

local FlySlider = FlySection:Slider({
    Title = "Скорость",
    Step = 5,
    Width = 200,
    Value = { Min = 10, Max = 250, Default = 50 },
    Callback = function(v)
        S.speed = math.floor(tonumber(v) or 50)
    end,
})

FlySection:Dropdown({
    Title = "Пресеты",
    Values = {"50", "100", "150", "250"},
    Callback = function(v)
        local val = tonumber(v)
        if val then
            S.speed = val
            FlySlider:Set(val)
        end
    end,
})

-- ---- Click TP ----
local ClickTpSection = MoveTab:Section({
    Title = "Click TP",
    Icon = "mouse-pointer-click",
    Box = true,
    Opened = true,
})

ClickTpSection:Toggle({
    Title = "Click TP",
    Desc = "ЛКМ по месту — телепорт туда",
    Value = false,
    Callback = function(state)
        if state then enableClickTp() else disableClickTp() end
    end,
})

local ClickTpSlider = ClickTpSection:Slider({
    Title = "Высота ТП",
    Step = 1,
    Width = 200,
    Value = { Min = 1, Max = 20, Default = 3 },
    Callback = function(v)
        S.clickTpHeight = math.floor(tonumber(v) or 3)
    end,
})

ClickTpSection:Dropdown({
    Title = "Пресеты",
    Values = {"1", "3", "5", "10"},
    Callback = function(v)
        local val = tonumber(v)
        if val then
            S.clickTpHeight = val
            ClickTpSlider:Set(val)
        end
    end,
})

-- ---- Noclip ----
local NoclipSection = MoveTab:Section({
    Title = "Noclip",
    Icon = "ghost",
    Box = true,
    Opened = true,
})

NoclipSection:Toggle({
    Title = "Noclip",
    Desc = "Проход сквозь стены",
    Value = false,
    Callback = function(state)
        if state then enableNoclip() else disableNoclip() end
    end,
})

-- ============================================================
-- ======================= VISUALS TAB ========================
-- ============================================================

local EspSection = VisTab:Section({
    Title = "ESP",
    Icon = "eye",
    Box = true,
    Opened = true,
})

EspSection:Toggle({
    Title = "ESP",
    Desc = "Подсветка + бокс + скелет + HP + индикатор хитбокса",
    Value = false,
    Callback = function(state)
        if state then enableESP() else disableESP() end
    end,
})

local WmSection = VisTab:Section({
    Title = "Watermark",
    Icon = "gauge",
    Box = true,
    Opened = true,
})

WmSection:Toggle({
    Title = "Watermark",
    Desc = "FPS + Ping + Время + Дата (перетаскивается мышкой)",
    Value = true,
    Callback = function(state)
        S.wmOn = state
        WM.Visible = state
    end,
})

-- ---- HUD (NL-style) ----
local HudSection = VisTab:Section({
    Title = "HUD",
    Icon = "monitor",
    Box = true,
    Opened = true,
})

HudSection:Toggle({
    Title = "HUD (NL-style)",
    Desc = "Компактный бар сверху по центру: название + FPS",
    Value = false,
    Callback = function(state)
        HUDGui.Enabled = state
    end,
})

-- ============================================================
-- ======================== PLAYER TAB ========================
-- ============================================================

-- ---- WalkSpeed ----
local WsSection = PlayTab:Section({
    Title = "WalkSpeed",
    Icon = "footprints",
    Box = true,
    Opened = true,
})

WsSection:Toggle({
    Title = "WalkSpeed",
    Desc = "Принудительная скорость ходьбы",
    Value = false,
    Callback = function(state)
        S.walkSpeedOn = state
        applyWalkSpeed()
    end,
})

local WsSlider = WsSection:Slider({
    Title = "Скорость",
    Step = 2,
    Width = 200,
    Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(v)
        S.walkSpeed = math.floor(tonumber(v) or 16)
        if S.walkSpeedOn then applyWalkSpeed() end
    end,
})

WsSection:Dropdown({
    Title = "Пресеты",
    Values = {"16", "50", "100", "200"},
    Callback = function(v)
        local val = tonumber(v)
        if val then
            S.walkSpeed = val
            WsSlider:Set(val)
            if S.walkSpeedOn then applyWalkSpeed() end
        end
    end,
})

-- ---- TP Player ----
local TpSection = PlayTab:Section({
    Title = "TP Player",
    Icon = "map-pin",
    Box = true,
    Opened = true,
})

local tpTargetName = nil

local TpDropdown = TpSection:Dropdown({
    Title = "Игрок  [дистанция]",
    Desc = "Выбери игрока из списка",
    Values = getPlayerValues(),
    Callback = function(v)
        tpTargetName = parsePlayerName(v)
    end,
})

TpSection:Button({
    Title = "Обновить список",
    Icon = "refresh-cw",
    Callback = function()
        task.spawn(function()
            TpDropdown:Refresh(getPlayerValues())
        end)
    end,
})

TpSection:Button({
    Title = "Телепортироваться",
    Icon = "map-pin",
    Color = Color3.fromHex("#0e7a8a"),
    Justify = "Center",
    Callback = function()
        local plr = tpTargetName and Players:FindFirstChild(tpTargetName)
        if plr then
            tpToPlayer(plr)
            notify("TP Player", "Телепорт к " .. plr.Name, 2, "map-pin")
        else
            notify("TP Player", "Сначала выбери игрока из списка!", 3, "alert-triangle")
        end
    end,
})

-- ============================================================
-- ==================== MISCELLANEOUS TAB =====================
-- ============================================================

MiscTab:Section({
    Title = "Управление",
    Desc = "RightShift или круглая кнопка ✦ — скрыть/показать меню • Закрытие окна = полная выгрузка скрипта",
    Icon = "info",
    TextSize = 18,
})

MiscTab:Space()

local ThemeSection = MiscTab:Section({
    Title = "Интерфейс",
    Icon = "palette",
    Box = true,
    Opened = true,
})

ThemeSection:Dropdown({
    Title = "Тема",
    Values = {"Dark", "Light", "Violet", "Rose", "Indigo", "Sky", "Amber", "Plant"},
    Value = "Violet",
    Callback = function(theme)
        pcall(function() WindUI:SetTheme(theme) end)
    end,
})

MiscTab:Space()

local ScriptSection = MiscTab:Section({
    Title = "Скрипт",
    Icon = "power",
    Box = true,
    Opened = true,
})

ScriptSection:Button({
    Title = "Close Script",
    Desc = "Полностью выгрузить SpermaHub (отключит все функции)",
    Icon = "power",
    Color = Color3.fromHex("#c0392b"),
    Justify = "Center",
    Callback = function()
        fullCleanup()
        Window:Destroy()
    end,
})

-- ============ АВТООБНОВЛЕНИЕ СПИСКОВ ИГРОКОВ ============
local function refreshPlayerLists()
    pcall(function() KillDropdown:Refresh(getPlayerValues()) end)
    pcall(function() TpDropdown:Refresh(getPlayerValues()) end)
end

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if S.guiAlive then refreshPlayerLists() end
end)
Players.PlayerRemoving:Connect(function()
    if S.guiAlive then refreshPlayerLists() end
end)

task.spawn(function()
    while S.guiAlive do
        task.wait(2)
        if S.guiAlive then refreshPlayerLists() end
    end
end)

-- ============ РЕСПАВН ============
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if S.flying then
        stopFly()
        pcall(function() FlyToggle:Set(false) end)
    end
    if S.noclip then
        if S.noclipConn then S.noclipConn:Disconnect() end
        S.noclip = true
        enableNoclip()
    end
    task.wait(0.2)
    applyWalkSpeed()
end)

-- ============ ИНИЦИАЛИЗАЦИЯ ============
updateFovCircle()
updateSilentFovCircle()
WM.Visible = S.wmOn

notify("SpermaHub v41", "Загружен! Разделы: Combat, Movement, Visuals, Player, Miscellaneous", 4, "sparkles")
print("✦ SpermaHub v41 (WindUI) загружен!")
print("Combat: Kill Player | Hitbox Expander | Aimbot | Silent Aim | Auto Clicker")
print("Movement: Flight | Click TP | Noclip | Visuals: ESP | Watermark | HUD | Player: WalkSpeed | TP Player")
