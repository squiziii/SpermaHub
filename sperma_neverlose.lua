-- SpermaHub v41 | NeverLose-style GUI
-- Интерфейс в стиле NEVERLOSE (как на скрине): сайдбар + топбар + двухколоночные панели,
-- сделан с нуля на Instance.new — внешних UI-библиотек НЕ нужно.
-- Перенесены ВСЕ вкладки и функции:
--   Combat:        Legitbot (Aimbot + Silent Aim + Team/Visible Check) | Hitbox | Kill Player | Fling | Anti-Aim | Auto Clicker
--   Visuals:       Players (ESP: Chams/Box/Skeleton/Names + Target ESP) | World
--   Movement:      Main (Flight/Noclip/Jesus/Spin/Bhop) | Teleport (Click TP)
--   Player:        Main (WalkSpeed + God Mode + TP Player)
--   Miscellaneous: Configs (Save/Load/профили) | Script (Close Script)
-- Управление: RightShift или круглая кнопка ✦ = скрыть/показать меню

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")
local LP = Players.LocalPlayer

-- ============ ОЧИСТКА СТАРЫХ ВЕРСИЙ ============
for _, n in ipairs({
    "SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle",
    "SpermaHubESP","SpermaHubSettings","SpermaHubWsSettings","SpermaHubTpList",
    "SpermaHubFlingTarget","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL","SpermaHubNLToggle"
}) do
    local o = LP.PlayerGui:FindFirstChild(n)
    if o then o:Destroy() end
end
pcall(function()
    if getgenv and getgenv().SpermaHubNLGui then
        getgenv().SpermaHubNLGui:Destroy()
        getgenv().SpermaHubNLGui = nil
    end
end)
pcall(function()
    local old = workspace:FindFirstChild("SpermaJesus")
    if old then old:Destroy() end
end)

-- ============ УВЕДОМЛЕНИЯ (тосты; до построения UI — в консоль) ============
local toastImpl = nil
local function notify(title, content)
    if toastImpl then
        toastImpl(title, content)
    else
        print(("[SpermaHub] %s: %s"):format(tostring(title), tostring(content)))
    end
end
-- ============ СОСТОЯНИЕ ============
local S = {
    flying=false, noclip=false, esp=false, speed=50,
    espBox=true, espSkeleton=true, espChams=true, espNames=true, chamStyle="Purple",
    targetEspOn=false, targetStyle="Pink", targetEspConn=nil,
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
    jesusOn=false, jesusConn=nil, jesusPlatform=nil,
    teamCheck=false, visibleCheck=false,
    tracersOn=false, hitmarkerOn=false, fxConn=nil,
    spinOn=false, spinSpeed=90, spinConn=nil,
    aaOn=false, aaConn=nil, aaPitch="Down", aaYaw="Backward", aaYawJitter="Disabled",
    aaSpinSpeed=180, aaAngle=0, aaJitSide=false, aaSlowWalk=false, aaSlowSpeed=8, aaFreestanding=false,
    aaStepConn=nil, aaRealCF=nil,
    bhopOn=false, bhopConn=nil, bhopMode="Hold Space",
    godOn=false, godConn=nil, flingConn=nil,
    guiAlive=true, fovVisualize=true,
}

-- ============================================================
-- ============ ЛОГИКА (перенесена из sperma.lua) =============
-- ============================================================

-- ============ TEAM CHECK / VISIBLE CHECK ============
local function isTeammate(plr)
    if not S.teamCheck then return false end
    if not plr or plr == LP then return false end
    if not plr.Team or not LP.Team then return false end
    return plr.Team == LP.Team
end

local visCheckParams = RaycastParams.new()
visCheckParams.FilterType = Enum.RaycastFilterType.Exclude

-- true, если от камеры до части нет препятствий (wallcheck)
local function isVisible(part)
    if not S.visibleCheck then return true end
    if not part then return false end
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local ch = LP.Character
    visCheckParams.FilterDescendantsInstances = ch and {ch} or {}
    local origin = cam.CFrame.Position
    local ok, result = pcall(function()
        return workspace:Raycast(origin, part.Position - origin, visCheckParams)
    end)
    if not ok or not result then return true end
    return result.Instance:IsDescendantOf(part.Parent)
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
        S.fovCircle.Visible = S.aimbotOn and S.fovVisualize
    end
end

local function updateSilentFovCircle()
    if S.silentAimFovCircle then
        local size = S.silentAimFov * 2
        S.silentAimFovCircle.Size = UDim2.new(0, size, 0, size)
        S.silentAimFovCircle.Visible = S.silentAimOn and S.fovVisualize
    end
end

-- Временный показ круга при настройке FOV слайдером (аналог открытой панели)
local fovFlash = {aimbot = 0, silent = 0}
local function flashFovCircle(kind, circle, isOn)
    fovFlash[kind] = fovFlash[kind] + 1
    local token = fovFlash[kind]
    if not isOn() and S.fovVisualize then circle.Visible = true end
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
                if head and hum and hum.Health > 0 and not isTeammate(plr) and isVisible(head) then
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
                if head and hum and hum.Health > 0 and not isTeammate(plr) and isVisible(head) then
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

-- Клик разрешён только "в игре": не в чате и не когда курсор над любым GUI
local hudIgnore = {
    SpermaHubESP=true, SpermaHubHUD=true, SpermaHubFov=true, SpermaHubWatermark=true, -- декоративные элементы скрипта не считаем
}
local function canClickInGame()
    if UIS:GetFocusedTextBox() then return false end -- чат / поле ввода
    local loc = UIS:GetMouseLocation()
    local ok, objs = pcall(function()
        local inset = GuiService:GetGuiInset()
        return LP.PlayerGui:GetGuiObjectsAtPosition(loc.X - inset.X, loc.Y - inset.Y)
    end)
    if ok and objs then
        for _, o in ipairs(objs) do
            if o.Visible then
                local sg = o:FindFirstAncestorOfClass("ScreenGui")
                if not (sg and hudIgnore[sg.Name]) then
                    return false
                end
            end
        end
    end
    return true
end

local function enableAutoClicker()
    S.autoClickOn = false
    S.autoClickGen = S.autoClickGen + 1 -- останавливаем прошлый цикл
    S.autoClickOn = true
    local gen = S.autoClickGen
    task.spawn(function()
        while S.autoClickOn and gen == S.autoClickGen do
            local interval = 1 / math.max(S.autoClickCps, 1)
            if canClickInGame() then
                if S.autoClickMode == "ЛКМ" or S.autoClickMode == "ЛКМ + ПКМ" then
                    clickMouse(1)
                end
                if S.autoClickMode == "ПКМ" or S.autoClickMode == "ЛКМ + ПКМ" then
                    clickMouse(2)
                end
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

-- ============ JESUS (ходьба по воде) ============
local jesusRayParams = RaycastParams.new()
jesusRayParams.FilterType = Enum.RaycastFilterType.Exclude
jesusRayParams.IgnoreWater = false -- чтобы рейкаст "видел" поверхность воды

local function enableJesus()
    S.jesusOn = true
    if not S.jesusPlatform or not S.jesusPlatform.Parent then
        local p = Instance.new("Part")
        p.Name = "SpermaJesus"
        p.Anchored = true
        p.CanCollide = true
        p.Transparency = 1
        p.CastShadow = false
        p.Size = Vector3.new(10, 1, 10)
        p.Parent = workspace
        S.jesusPlatform = p
    end
    if S.jesusConn then S.jesusConn:Disconnect() end
    S.jesusConn = RunService.Heartbeat:Connect(function()
        if not S.jesusOn then return end
        local ch = LP.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local plat = S.jesusPlatform
        if not plat then return end
        jesusRayParams.FilterDescendantsInstances = {ch, plat}
        local result = workspace:Raycast(root.Position, Vector3.new(0, -25, 0), jesusRayParams)
        if result and result.Material == Enum.Material.Water then
            -- ставим платформу верхней гранью ровно на поверхность воды
            plat.Position = Vector3.new(root.Position.X, result.Position.Y - plat.Size.Y / 2 + 0.05, root.Position.Z)
        else
            -- воды под ногами нет — убираем платформу
            plat.Position = Vector3.new(0, -1e5, 0)
        end
    end)
end

local function disableJesus()
    S.jesusOn = false
    if S.jesusConn then S.jesusConn:Disconnect() S.jesusConn = nil end
    if S.jesusPlatform then S.jesusPlatform.Position = Vector3.new(0, -1e5, 0) end
end

-- ============ SPIN (вращение персонажа) ============
local function enableSpin()
    S.spinOn = true
    if S.spinConn then S.spinConn:Disconnect() end
    S.spinConn = RunService.RenderStepped:Connect(function(dt)
        if not S.spinOn then return end
        local ch = LP.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(S.spinSpeed) * dt, 0)
    end)
end

local function disableSpin()
    S.spinOn = false
    if S.spinConn then S.spinConn:Disconnect() S.spinConn = nil end
end

-- ============ GOD MODE (лок HP) ============
local function enableGod()
    S.godOn = true
    if S.godConn then S.godConn:Disconnect() end
    S.godConn = RunService.Heartbeat:Connect(function()
        if not S.godOn then return end
        local ch = LP.Character
        if not ch then return end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health < hum.MaxHealth then
            pcall(function() hum.Health = hum.MaxHealth end)
        end
    end)
end

local function disableGod()
    S.godOn = false
    if S.godConn then S.godConn:Disconnect() S.godConn = nil end
end

-- ============ FLING ============
local function flingPlayer(target)
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local tChar = target and target.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end
    if S.flingConn then pcall(function() S.flingConn:Disconnect() end) S.flingConn = nil end
    local oldCF = root.CFrame
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    local t0 = tick()
    S.flingConn = RunService.Heartbeat:Connect(function()
        if not root.Parent or not tRoot.Parent then return end
        if tick() - t0 > 0.8 then return end
        root.CFrame = tRoot.CFrame + Vector3.new(math.random(-5, 5) / 10, 0, math.random(-5, 5) / 10)
        bv.Velocity = Vector3.new((math.random() - 0.5) * 900, 350, (math.random() - 0.5) * 900)
        bv.Parent = root
    end)
    task.delay(0.85, function()
        if S.flingConn then S.flingConn:Disconnect() S.flingConn = nil end
        pcall(function() bv:Destroy() end)
        if root.Parent then
            root.Velocity = Vector3.zero
            root.CFrame = oldCF
        end
    end)
end

-- ============ BULLET TRACERS + HITMARKER ============
local HM_SOUND_ID = nil -- сюда можно вписать id звука хитмаркера, напр. "rbxassetid://1234567890"

local FxGui = Instance.new("ScreenGui")
FxGui.Name = "SpermaHubFx"
FxGui.ResetOnSpawn = false
FxGui.IgnoreGuiInset = true
FxGui.DisplayOrder = 102
FxGui.Parent = LP:WaitForChild("PlayerGui")

local function drawTracer(from3D, to3D)
    local cam = workspace.CurrentCamera
    local v1, on1 = cam:WorldToViewportPoint(from3D)
    local v2, on2 = cam:WorldToViewportPoint(to3D)
    if not on1 and not on2 then return end
    local dx = v2.X - v1.X
    local dy = v2.Y - v1.Y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 2 then return end
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0, (v1.X + v2.X) / 2, 0, (v1.Y + v2.Y) / 2)
    f.Size = UDim2.new(0, length, 0, 2)
    f.Rotation = math.deg(math.atan2(dy, dx))
    f.BackgroundColor3 = Color3.fromRGB(255, 220, 130)
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    f.ZIndex = 8
    f.Parent = FxGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = f
    local TweenService = game:GetService("TweenService")
    TweenService:Create(f, TweenInfo.new(0.28), {BackgroundTransparency = 1}):Play()
    task.delay(0.35, function() pcall(function() f:Destroy() end) end)
end

local function showHitmarker()
    for _, ang in ipairs({45, -45}) do
        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0.5, 0.5)
        bar.Position = UDim2.new(0.5, 0, 0.5, 0)
        bar.Size = UDim2.new(0, 14, 0, 2)
        bar.Rotation = ang
        bar.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
        bar.BackgroundTransparency = 0
        bar.BorderSizePixel = 0
        bar.ZIndex = 9
        bar.Parent = FxGui
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = bar
        local TweenService = game:GetService("TweenService")
        TweenService:Create(bar, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
        task.delay(0.25, function() pcall(function() bar:Destroy() end) end)
    end
    if HM_SOUND_ID then
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = HM_SOUND_ID
            s.Volume = 0.6
            s.Parent = workspace
            s:Play()
            task.delay(1, function() pcall(function() s:Destroy() end) end)
        end)
    end
end

local function onShotTracer()
    if not S.tracersOn then return end
    local ch = LP.Character
    if not ch then return end
    local tool = ch:FindFirstChildOfClass("Tool")
    if not tool then return end
    local fromPart = tool:FindFirstChild("Handle") or tool.PrimaryPart or ch:FindFirstChild("HumanoidRootPart")
    if not fromPart then return end
    local to = nil
    if S.silentAimOn then
        local t = findSilentTarget()
        local head = t and t.Character and t.Character:FindFirstChild("Head")
        if head then to = head.Position end
    end
    if not to then
        local mouse = LP:GetMouse()
        if mouse and mouse.Hit then to = mouse.Hit.Position end
    end
    if to then drawTracer(fromPart.Position, to) end
end

local function onShotHitmarker()
    if not S.hitmarkerOn then return end
    local hit = false
    if S.silentAimOn then
        if findSilentTarget() then hit = true end
    end
    if not hit then
        local mouse = LP:GetMouse()
        if mouse and mouse.Target then
            local model = mouse.Target:FindFirstAncestorOfClass("Model")
            if model then
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then hit = true end
            end
        end
    end
    if hit then showHitmarker() end
end

S.fxConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local ch = LP.Character
    if not ch or not ch:FindFirstChildOfClass("Tool") then return end
    pcall(onShotTracer)
    pcall(onShotHitmarker)
end)

-- ============ ANTI-AIM (fake angles, реал-стайл) ============
-- Схема стабильности: фейковый CFrame ставим ТОЛЬКО на рендер-кадр (RenderStepped),
-- а перед физикой (Stepped) откатываем на настоящий. Поэтому персонаж стоит ровно
-- на месте, ходит, прыгает и нормально тормозит — физика никогда не видит фейковых углов.
local function getCamYawDeg()
    local cam = workspace.CurrentCamera
    local lv = cam.CFrame.LookVector
    return math.deg(math.atan2(-lv.X, -lv.Z))
end

-- freestanding: встать спиной к ближайшему врагу в радиусе 60 стадов
local function freestandingYaw(root)
    local best, bestD = nil, 60
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isTeammate(plr) then
            local ch2 = plr.Character
            local troot = ch2 and ch2:FindFirstChild("HumanoidRootPart")
            local thum = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            if troot and thum and thum.Health > 0 then
                local d = (troot.Position - root.Position).Magnitude
                if d < bestD then
                    best, bestD = troot, d
                end
            end
        end
    end
    if not best then return nil end
    local dir = root.Position - best.Position -- направление от врага к нам
    return math.deg(math.atan2(-dir.X, -dir.Z))
end

local function enableAntiAim()
    S.aaOn = true
    if S.aaConn then S.aaConn:Disconnect() end
    if S.aaStepConn then S.aaStepConn:Disconnect() end

    -- 1) рендер-кадр: настоящий CFrame запоминаем, ставим фейковый
    S.aaConn = RunService.RenderStepped:Connect(function(dt)
        if not S.aaOn then return end
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local hum = ch:FindFirstChildOfClass("Humanoid")

        -- Slow Walk
        if S.aaSlowWalk and hum and not S.walkSpeedOn then
            hum.WalkSpeed = S.aaSlowSpeed
        end

        -- базовый угол: спиной к камере или freestanding (спиной к врагу)
        local baseYaw = getCamYawDeg() + 180
        if S.aaFreestanding then
            baseYaw = freestandingYaw(root) or baseYaw
        end

        local yaw = nil
        if S.aaYaw == "Backward" or S.aaYaw == "Backwards" then
            yaw = baseYaw
        elseif S.aaYaw == "Spin" then
            S.aaAngle = (S.aaAngle + S.aaSpinSpeed * dt) % 360
            yaw = S.aaAngle
        elseif S.aaYaw == "Random" then
            yaw = math.random(0, 359)
        end

        -- Yaw Jitter поверх выбранного yaw
        if yaw and S.aaYawJitter ~= "Disabled" then
            if S.aaYawJitter == "Offset" then
                S.aaJitSide = not S.aaJitSide
                yaw = yaw + (S.aaJitSide and 45 or -45)
            else -- Random
                yaw = yaw + math.random(-60, 60)
            end
        end

        local pitch = 0
        if S.aaPitch == "Down" then
            pitch = -90
        elseif S.aaPitch == "Up" then
            pitch = 90
        elseif S.aaPitch == "Jitter" then
            pitch = (math.random() < 0.5) and -90 or 90
        end

        if yaw or pitch ~= 0 then
            local trueCF = root.CFrame
            local pos = trueCF.Position
            S.aaRealCF = trueCF
            root.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(pitch), math.rad(yaw or getCamYawDeg()), 0)
        end
    end)

    -- 2) перед физикой: возвращаем настоящий CFrame -> никаких подпрыгиваний
    S.aaStepConn = RunService.Stepped:Connect(function()
        if not S.aaOn then return end
        if S.aaRealCF then
            local ch = LP.Character
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = S.aaRealCF
            end
            S.aaRealCF = nil
        end
    end)
end

local function disableAntiAim()
    S.aaOn = false
    if S.aaConn then S.aaConn:Disconnect() S.aaConn = nil end
    if S.aaStepConn then S.aaStepConn:Disconnect() S.aaStepConn = nil end
    S.aaRealCF = nil
    -- вернуть скорость после Slow Walk
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if S.aaSlowWalk and hum then
        hum.WalkSpeed = S.walkSpeedOn and S.walkSpeed or 16
    end
end

-- ============ BHOP (авто-прыжки) ============
local function enableBhop()
    S.bhopOn = true
    if S.bhopConn then S.bhopConn:Disconnect() end
    S.bhopConn = RunService.Heartbeat:Connect(function()
        if not S.bhopOn then return end
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if S.bhopMode == "Hold Space" and not UIS:IsKeyDown(Enum.KeyCode.Space) then return end
        if hum.FloorMaterial ~= Enum.Material.Air then
            hum.Jump = true
        end
    end)
end

local function disableBhop()
    S.bhopOn = false
    if S.bhopConn then S.bhopConn:Disconnect() S.bhopConn = nil end
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

-- неоновые стили подсветки (как на скриншотах)
local CHAM_STYLES = {
    Purple = {fill = Color3.fromRGB(170, 0, 255),  outline = Color3.fromRGB(225, 110, 255)},
    Pink   = {fill = Color3.fromRGB(255, 0, 200),  outline = Color3.fromRGB(255, 120, 240)},
    Red    = {fill = Color3.fromRGB(255, 40, 40),  outline = Color3.fromRGB(255, 150, 80)},
    Green  = {fill = Color3.fromRGB(40, 255, 130), outline = Color3.fromRGB(190, 255, 190)},
    Cyan   = {fill = Color3.fromRGB(0, 190, 255),  outline = Color3.fromRGB(150, 235, 255)},
    Gold   = {fill = Color3.fromRGB(255, 190, 40), outline = Color3.fromRGB(255, 240, 160)},
}
local TARGET_STYLES = {
    Pink   = CHAM_STYLES.Pink,
    Purple = CHAM_STYLES.Purple,
    Red    = CHAM_STYLES.Red,
    Gold   = CHAM_STYLES.Gold,
}

local function isAlive(plr)
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return ch:FindFirstChild("HumanoidRootPart") ~= nil
end

local function createESP(plr)
    if plr == LP or isTeammate(plr) then return end
    if espObjects[plr] then return end
    local data = {lines = {}, highlight = nil, billboard = nil, boxLines = {}}
    espObjects[plr] = data

    local ch = plr.Character
    if ch then
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(170, 0, 255)
        hl.OutlineColor = Color3.fromRGB(225, 110, 255)
        hl.FillTransparency = 0.5
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
        if ch and isAlive(plr) and not isTeammate(plr) then
            local head = ch:FindFirstChild("Head")
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch:FindFirstChild("HumanoidRootPart")

            if data.highlight then
                local st = CHAM_STYLES[S.chamStyle] or CHAM_STYLES.Purple
                data.highlight.Adornee = ch
                data.highlight.FillColor = st.fill
                data.highlight.OutlineColor = st.outline
                data.highlight.Enabled = S.espChams
            end
            if data.billboard then
                data.billboard.Enabled = S.espNames
                if head then data.billboard.Adornee = head end
            end
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
                if topOn and botOn and S.espBox then
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
    if not S.espSkeleton then
        for _, frames in pairs(skeletonFrames) do
            for _, f in ipairs(frames) do
                if f then f.Visible = false end
            end
        end
        return
    end
    local cam = workspace.CurrentCamera
    for plr, data in pairs(espObjects) do
        local ch = plr.Character
        if ch and isAlive(plr) and not isTeammate(plr) then
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

-- ============ TARGET ESP (подсветка текущей цели) ============
local TargetHL = Instance.new("Highlight")
TargetHL.FillTransparency = 0.35
TargetHL.OutlineTransparency = 0
TargetHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
TargetHL.Enabled = false
TargetHL.Parent = ESPGui

local function currentEspTarget()
    if S.silentAimOn then
        local p = findSilentTarget()
        if p then return p end
    end
    if S.aimbotOn then
        local part = getClosestTarget()
        if part then
            local p = Players:GetPlayerFromCharacter(part.Parent)
            if p then return p end
        end
    end
    return nil
end

local function enableTargetESP()
    S.targetEspOn = true
    if S.targetEspConn then S.targetEspConn:Disconnect() end
    S.targetEspConn = RunService.RenderStepped:Connect(function()
        if not S.targetEspOn then return end
        local p = currentEspTarget()
        if p and p ~= LP and isAlive(p) and not isTeammate(p) and p.Character then
            local st = TARGET_STYLES[S.targetStyle] or TARGET_STYLES.Pink
            TargetHL.FillColor = st.fill
            TargetHL.OutlineColor = st.outline
            TargetHL.FillTransparency = 0.35 + 0.15 * math.sin(tick() * 6) -- пульсация
            TargetHL.Adornee = p.Character
            TargetHL.Enabled = true
        else
            TargetHL.Enabled = false
            TargetHL.Adornee = nil
        end
    end)
end

local function disableTargetESP()
    S.targetEspOn = false
    if S.targetEspConn then S.targetEspConn:Disconnect() S.targetEspConn = nil end
    TargetHL.Enabled = false
    TargetHL.Adornee = nil
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
-- ============ NEVERLOSE-STYLE GUI (кастом, с нуля) ==========
-- ============================================================

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- ---------- ПАЛИТРА (как на скрине NEVERLOSE) ----------
local C_BG       = Color3.fromRGB(11, 14, 19)    -- фон окна
local C_SIDE     = Color3.fromRGB(13, 16, 22)    -- сайдбар
local C_PANEL    = Color3.fromRGB(16, 20, 28)    -- панели
local C_CTRL     = Color3.fromRGB(21, 27, 37)    -- контролы
local C_CTRL_H   = Color3.fromRGB(27, 35, 48)    -- hover
local C_STROKE   = Color3.fromRGB(28, 35, 48)    -- обводка
local C_SEL      = Color3.fromRGB(22, 29, 40)    -- выбранная вкладка
local C_ACCENT   = Color3.fromRGB(78, 160, 216)  -- голубой акцент
local C_RED      = Color3.fromRGB(140, 48, 52)   -- красная кнопка
local C_RED_H    = Color3.fromRGB(165, 58, 62)
local C_TXT      = Color3.fromRGB(230, 235, 244)
local C_GRAY     = Color3.fromRGB(140, 150, 168)
local C_DIM      = Color3.fromRGB(92, 102, 117)
local C_KNOB     = Color3.fromRGB(240, 244, 250)

local WIN_W, WIN_H = 800, 520
local SIDE_W, TOP_H = 190, 46
local COL_W = 287

-- ---------- ХЕЛПЕР ----------
local function new(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

-- ---------- SCREENGUI ----------
local SG = new("ScreenGui", {
    Name = "SpermaHubNL",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 104,
}, LP:WaitForChild("PlayerGui"))
pcall(function() if getgenv then getgenv().SpermaHubNLGui = SG end end)

-- ---------- ТОСТЫ (уведомления) ----------
local ToastHolder = new("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -12, 0, 12),
    Size = UDim2.new(0, 230, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    ZIndex = 95,
}, SG)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right}, ToastHolder)

toastImpl = function(title, msg)
    task.spawn(function()
        local t = new("Frame", {
            Size = UDim2.new(0, 230, 0, 42),
            BackgroundColor3 = C_PANEL,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 95,
        }, ToastHolder)
        new("UICorner", {CornerRadius = UDim.new(0, 6)}, t)
        local st = new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 1}, t)
        local l1 = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -18, 0, 15), Position = UDim2.new(0, 9, 0, 5),
            Text = tostring(title), TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 96,
        }, t)
        local l2 = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -18, 0, 14), Position = UDim2.new(0, 9, 0, 21),
            Text = tostring(msg), TextColor3 = C_GRAY, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 96,
        }, t)
        TweenService:Create(t, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
        TweenService:Create(st, TweenInfo.new(0.2), {Transparency = 0.4}):Play()
        TweenService:Create(l1, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        TweenService:Create(l2, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        task.wait(2.6)
        local out = TweenInfo.new(0.3)
        TweenService:Create(t, out, {BackgroundTransparency = 1}):Play()
        TweenService:Create(st, out, {Transparency = 1}):Play()
        TweenService:Create(l1, out, {TextTransparency = 1}):Play()
        TweenService:Create(l2, out, {TextTransparency = 1}):Play()
        task.wait(0.35)
        t:Destroy()
    end)
end

-- ---------- ГЛАВНОЕ ОКНО ----------
local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.new(0, WIN_W, 0, WIN_H),
    Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
    BackgroundColor3 = C_BG,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, SG)
new("UICorner", {CornerRadius = UDim.new(0, 7)}, Main)
new("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, Transparency = 0.35}, Main)

-- ---------- САЙДБАР ----------
local Sidebar = new("Frame", {
    Size = UDim2.new(0, SIDE_W, 1, 0),
    BackgroundColor3 = C_SIDE,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Main)
new("UICorner", {CornerRadius = UDim.new(0, 7)}, Sidebar)
-- затычка правого нижнего/верхнего угла сайдбара
new("Frame", {Size = UDim2.new(0, 8, 1, 0), Position = UDim2.new(1, -8, 0, 0), BackgroundColor3 = C_SIDE, BorderSizePixel = 0, ZIndex = 2}, Sidebar)
-- разделитель справа
new("Frame", {Size = UDim2.new(0, 1, 1, -20), Position = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C_STROKE, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3}, Sidebar)

local Logo = new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 44),
    Position = UDim2.new(0, 22, 0, 0),
    Text = "SPERMAHUB",
    TextColor3 = C_TXT,
    Font = Enum.Font.GothamBlack,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, Sidebar)

-- контейнер под поиск + список вкладок
local SideMid = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, -44 - 66),
    Position = UDim2.new(0, 0, 0, 44),
    ZIndex = 3,
}, Sidebar)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0)}, SideMid)

local SearchWrap = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 0),
    ClipsDescendants = true,
    LayoutOrder = 0,
}, SideMid)
local SearchBox = new("TextBox", {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, 2),
    BackgroundColor3 = C_CTRL,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search...",
    PlaceholderColor3 = C_DIM,
    TextColor3 = C_TXT,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 3,
}, SearchWrap)
new("UICorner", {CornerRadius = UDim.new(0, 5)}, SearchBox)
local sbPad = new("UIPadding", {}, SearchBox)
sbPad.PaddingLeft = UDim.new(0, 8)

local SideScroll = new("ScrollingFrame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, -30),
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    ScrollingEnabled = true,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 1,
    ZIndex = 3,
}, SideMid)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, SideScroll)
local ssPad = new("UIPadding", {}, SideScroll)
ssPad.PaddingLeft = UDim.new(0, 10)
ssPad.PaddingRight = UDim.new(0, 10)
ssPad.PaddingTop = UDim.new(0, 2)

-- карточка пользователя снизу (как avatar "Exration")
local UserCard = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 60),
    Position = UDim2.new(0, 0, 1, -60),
    ZIndex = 3,
}, Sidebar)
new("Frame", {Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0, 0), BackgroundColor3 = C_STROKE, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3}, UserCard)
local Avatar = new("ImageLabel", {
    Size = UDim2.new(0, 34, 0, 34),
    Position = UDim2.new(0, 16, 0, 14),
    BackgroundColor3 = C_CTRL,
    BorderSizePixel = 0,
    ZIndex = 3,
}, UserCard)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, Avatar)
task.spawn(function()
    pcall(function()
        Avatar.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
end)
new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 16), Position = UDim2.new(0, 58, 0, 15),
    Text = LP.Name, TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, UserCard)
new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 58, 0, 32),
    Text = "SpermaHub  v41", TextColor3 = C_ACCENT, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, UserCard)

-- ---------- ТОПБАР ----------
local Topbar = new("Frame", {
    Size = UDim2.new(1, -SIDE_W, 0, TOP_H),
    Position = UDim2.new(0, SIDE_W, 0, 0),
    BackgroundColor3 = C_BG,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Main)
new("Frame", {Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 1, 0), BackgroundColor3 = C_STROKE, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3}, Topbar)

-- ---------- OVERLAY ДЛЯ ВЫПАДАЮЩИХ СПИСКОВ ----------
local Overlay = new("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    Visible = false,
    ZIndex = 90,
    AutoButtonColor = false,
}, SG)
local ddList = nil
local function closeDropdownList()
    if ddList then ddList:Destroy() ddList = nil end
    Overlay.Visible = false
end
Overlay.MouseButton1Click:Connect(closeDropdownList)

local function openDropdownList(anchor, options, current, onPick)
    closeDropdownList()
    Overlay.Visible = true
    local ap = anchor.AbsolutePosition
    local asz = anchor.AbsoluteSize
    local maxShow = 8
    local itemH = 22
    local shown = math.min(#options, maxShow)
    ddList = new("Frame", {
        Size = UDim2.new(0, asz.X, 0, shown * itemH + 8),
        Position = UDim2.new(0, ap.X, 0, ap.Y + asz.Y + 4),
        BackgroundColor3 = Color3.fromRGB(19, 25, 35),
        BorderSizePixel = 0,
        ZIndex = 91,
    }, Overlay)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, ddList)
    new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.35}, ddList)
    local scr = new("ScrollingFrame", {
        Size = UDim2.new(1, -6, 1, -8),
        Position = UDim2.new(0, 3, 0, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C_ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 91,
    }, ddList)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, scr)
    for i, opt in ipairs(options) do
        local isCur = tostring(opt) == tostring(current)
        local b = new("TextButton", {
            Size = UDim2.new(1, -4, 0, itemH),
            BackgroundColor3 = isCur and C_CTRL_H or C_CTRL,
            BackgroundTransparency = isCur and 0 or 1,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 92,
        }, scr)
        new("UICorner", {CornerRadius = UDim.new(0, 4)}, b)
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
            Text = tostring(opt), TextColor3 = isCur and C_ACCENT or C_TXT,
            Font = Enum.Font.GothamMedium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 92,
        }, b)
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 b.BackgroundColor3 = C_CTRL_H end)
        b.MouseLeave:Connect(function()
            if tostring(opt) ~= tostring(current) then b.BackgroundTransparency = 1 end
            b.BackgroundColor3 = isCur and C_CTRL_H or C_CTRL_H
        end)
        b.MouseButton1Click:Connect(function()
            onPick(opt)
            closeDropdownList()
        end)
    end
end

-- ---------- КОНТЕНТ (страницы) ----------
local Content = new("Frame", {
    Size = UDim2.new(1, -SIDE_W, 1, -TOP_H),
    Position = UDim2.new(0, SIDE_W, 0, TOP_H),
    BackgroundTransparency = 1,
    ZIndex = 2,
}, Main)

local Pages = {}
local sideItems = {}   -- {kind="cat"|"entry", frame=, name=}
local currentPage = nil
local currentEntry = nil

local function selectPage(pg)
    if not pg then return end
    if currentPage then currentPage.frame.Visible = false end
    if currentEntry then
        currentEntry.btn.BackgroundColor3 = C_SEL
        currentEntry.btn.BackgroundTransparency = 1
        currentEntry.nameL.TextColor3 = C_GRAY
        currentEntry.iconL.TextColor3 = C_GRAY
    end
    currentPage = pg
    currentEntry = pg.entry
    pg.frame.Visible = true
    if currentEntry then
        currentEntry.btn.BackgroundTransparency = 0
        currentEntry.btn.BackgroundColor3 = C_SEL
        currentEntry.nameL.TextColor3 = C_TXT
        currentEntry.iconL.TextColor3 = C_ACCENT
    end
end

local sideOrder = 0
local function addCategory(title)
    sideOrder = sideOrder + 1
    local h = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        Text = string.upper(title),
        TextColor3 = C_DIM,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = sideOrder,
        ZIndex = 3,
    }, SideScroll)
    local hp = new("UIPadding", {}, h)
    hp.PaddingLeft = UDim.new(0, 4)
    table.insert(sideItems, {kind = "cat", frame = h})
    return h
end

local function addPage(cat, icon, title)
    sideOrder = sideOrder + 1
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = C_SEL,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = sideOrder,
        ZIndex = 3,
    }, SideScroll)
    new("UICorner", {CornerRadius = UDim.new(0, 6)}, btn)
    local iconL = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        Text = icon, TextColor3 = C_GRAY, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 3,
    }, btn)
    local nameL = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 34, 0, 0),
        Text = title, TextColor3 = C_GRAY, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    }, btn)

    local pg = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        ZIndex = 2,
    }, Content)
    local function makeCol(xoff)
        local col = new("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, COL_W, 1, -24),
            Position = UDim2.new(0, xoff, 0, 12),
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C_STROKE,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        }, pg)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)}, col)
        return col
    end
    local page = {frame = pg, col1 = makeCol(12), col2 = makeCol(311), entry = {btn = btn, nameL = nameL, iconL = iconL}}
    table.insert(Pages, page)
    table.insert(sideItems, {kind = "entry", frame = btn, name = string.lower(title), page = page})
    btn.MouseButton1Click:Connect(function() selectPage(page) end)
    return page
end

-- поиск по вкладкам
local searchVisible = false
local function applySearchFilter(q)
    q = string.lower(q or "")
    for i, it in ipairs(sideItems) do
        if it.kind == "entry" then
            it.frame.Visible = (q == "") or (string.find(it.name, q, 1, true) ~= nil)
        end
    end
    for i, it in ipairs(sideItems) do
        if it.kind == "cat" then
            local any = false
            for j = i + 1, #sideItems do
                local nx = sideItems[j]
                if nx.kind == "cat" then break end
                if nx.kind == "entry" and nx.frame.Visible then any = true break end
            end
            it.frame.Visible = any
        end
    end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    applySearchFilter(SearchBox.Text)
end)
local function toggleSearch()
    searchVisible = not searchVisible
    TweenService:Create(SearchWrap, TweenInfo.new(0.18), {Size = searchVisible and UDim2.new(1, 0, 0, 30) or UDim2.new(1, 0, 0, 0)}):Play()
    if searchVisible then SearchBox:CaptureFocus() else applySearchFilter("") end
end

-- ---------- КОНТРОЛЫ ----------
local Cfg = {} -- реестр для конфига: key -> {get, set}

local function panelOrderInc(panel)
    local n = (panel:GetAttribute("_ord") or 0) + 1
    panel:SetAttribute("_ord", n)
    return n
end

local function addPanel(col, title)
    local p = new("Frame", {
        BackgroundColor3 = C_PANEL,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
    }, col)
    new("UICorner", {CornerRadius = UDim.new(0, 6)}, p)
    new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.4}, p)
    local pad = new("UIPadding", {}, p)
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}, p)
    if title then
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 17),
            Text = title, TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, ZIndex = 2,
        }, p)
    end
    return p
end

local function baseRow(panel, label, labelOff)
    local row = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        LayoutOrder = panelOrderInc(panel),
        ZIndex = 2,
    }, panel)
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -(labelOff or 46), 1, 0),
        Text = label, TextColor3 = C_GRAY, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
    }, row)
    return row
end

-- тумблер (pill-переключатель)
local function addToggle(panel, key, label, default, cb)
    local row = baseRow(panel, label)
    local sw = new("TextButton", {
        Size = UDim2.new(0, 34, 0, 16),
        Position = UDim2.new(1, -34, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(44, 52, 68),
        Text = "", AutoButtonColor = false, ZIndex = 3,
    }, row)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, sw)
    local knob = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = C_KNOB, BorderSizePixel = 0, ZIndex = 4,
    }, sw)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    local state = default and true or false
    local function apply(v, silent)
        state = v and true or false
        TweenService:Create(sw, TweenInfo.new(0.15), {BackgroundColor3 = state and C_ACCENT or Color3.fromRGB(44, 52, 68)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(0, 20, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}):Play()
        if not silent and cb then cb(state) end
    end
    sw.MouseButton1Click:Connect(function() apply(not state) end)
    if key then Cfg[key] = {get = function() return state end, set = function(v) apply(v) end} end
    apply(state, true)
    return {set = function(v) apply(v) end, get = function() return state end}
end

-- слайдер (тонкий трек + значение справа)
local function addSlider(panel, key, label, minV, maxV, default, step, cb)
    local row = baseRow(panel, label, 154)
    local valBox = new("TextLabel", {
        Size = UDim2.new(0, 36, 0, 16),
        Position = UDim2.new(1, -36, 0.5, -8),
        BackgroundColor3 = C_CTRL, BorderSizePixel = 0,
        Text = "", TextColor3 = C_TXT, Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 3,
    }, row)
    new("UICorner", {CornerRadius = UDim.new(0, 4)}, valBox)
    local track = new("TextButton", {
        Size = UDim2.new(0, 100, 0, 16),
        Position = UDim2.new(1, -144, 0.5, -8),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3,
    }, row)
    local bar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 3),
        Position = UDim2.new(0, 0, 0.5, -1),
        BackgroundColor3 = Color3.fromRGB(44, 52, 68), BorderSizePixel = 0, ZIndex = 3,
    }, track)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C_ACCENT, BorderSizePixel = 0, ZIndex = 4,
    }, bar)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
    local knob = new("Frame", {
        Size = UDim2.new(0, 9, 0, 9),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = C_KNOB, BorderSizePixel = 0, ZIndex = 5,
    }, bar)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    local val = default
    local function fmtV(v)
        if step >= 1 then return tostring(math.floor(v + 0.5)) end
        local s = string.format("%.2f", v)
        s = s:gsub("0+$", ""):gsub("%.$", "")
        return s
    end
    local function apply(v, silent)
        v = math.clamp(tonumber(v) or minV, minV, maxV)
        v = minV + math.floor((v - minV) / step + 0.5) * step
        val = v
        local rel = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valBox.Text = fmtV(v)
        if not silent and cb then cb(v) end
    end
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        apply(minV + rel * (maxV - minV))
    end
    local dragging = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            setFromX(i.Position.X)
        end
    end)
    if key then Cfg[key] = {get = function() return val end, set = function(v) apply(v) end} end
    apply(default, true)
    return {set = function(v) apply(v) end, get = function() return val end}
end

-- выпадающий список
local function addDropdown(panel, key, label, options, default, cb)
    local row = baseRow(panel, label, 160)
    local box = new("TextButton", {
        Size = UDim2.new(0, 150, 0, 20),
        Position = UDim2.new(1, -150, 0.5, -10),
        BackgroundColor3 = C_CTRL, Text = "", AutoButtonColor = false, ZIndex = 3,
    }, row)
    new("UICorner", {CornerRadius = UDim.new(0, 4)}, box)
    new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.5}, box)
    local tl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -26, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        Text = tostring(default), TextColor3 = C_TXT, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    }, box)
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -20, 0, 0),
        Text = "▾", TextColor3 = C_GRAY, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 3,
    }, box)
    local value = default
    local opts = options
    local function apply(v, silent)
        value = v
        tl.Text = tostring(v)
        if not silent and cb then cb(v) end
    end
    box.MouseButton1Click:Connect(function()
        openDropdownList(box, opts, value, function(v) apply(v) end)
    end)
    if key then Cfg[key] = {get = function() return value end, set = function(v) apply(v) end} end
    return {set = function(v) apply(v) end, get = function() return value end, refresh = function(o) opts = o end}
end

-- бинд клавиши (капча следующей нажатой)
local function addKeybind(panel, key, label, defaultName, cb)
    local row = baseRow(panel, label, 160)
    local box = new("TextButton", {
        Size = UDim2.new(0, 150, 0, 20),
        Position = UDim2.new(1, -150, 0.5, -10),
        BackgroundColor3 = C_CTRL, Text = "", AutoButtonColor = false, ZIndex = 3,
    }, row)
    new("UICorner", {CornerRadius = UDim.new(0, 4)}, box)
    new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.5}, box)
    local value = defaultName
    local capturing = false
    local tl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0),
        Text = defaultName and ("[" .. defaultName .. "]") or "[-]",
        TextColor3 = C_TXT, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
    }, box)
    box.MouseButton1Click:Connect(function()
        capturing = true
        tl.Text = "[...]"
    end)
    UIS.InputBegan:Connect(function(i, gpe)
        if not capturing then return end
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        capturing = false
        if i.KeyCode == Enum.KeyCode.Escape then
            tl.Text = value and ("[" .. value .. "]") or "[-]"
            return
        end
        if i.KeyCode == Enum.KeyCode.Delete or i.KeyCode == Enum.KeyCode.Backspace then
            value = nil
            tl.Text = "[-]"
            if cb then cb(nil) end
            return
        end
        value = i.KeyCode.Name
        tl.Text = "[" .. value .. "]"
        if cb then cb(i.KeyCode) end
    end)
    if key then Cfg[key] = {get = function() return value end, set = function(v)
        value = v
        tl.Text = v and ("[" .. tostring(v) .. "]") or "[-]"
        if v then pcall(function() cb(Enum.KeyCode[v]) end) end
    end} end
    return {get = function() return value end}
end

-- кнопка во всю ширину
local function addButton(panel, label, cb, color, hover)
    local bg = color or C_CTRL
    local hv = hover or C_CTRL_H
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = bg,
        Text = label,
        TextColor3 = C_TXT,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        LayoutOrder = panelOrderInc(panel),
        ZIndex = 3,
    }, panel)
    new("UICorner", {CornerRadius = UDim.new(0, 4)}, b)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = hv}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = bg}):Play() end)
    b.MouseButton1Click:Connect(function() if cb then cb() end end)
    return b
end

-- текст-описание
local function addText(panel, text)
    local t = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = text,
        TextColor3 = C_DIM,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        LayoutOrder = panelOrderInc(panel),
        ZIndex = 2,
    }, panel)
    return t
end

-- список игроков (имя + дистанция, выбор подсветкой)
local function makePlayerList(panel, height)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Color3.fromRGB(13, 17, 24),
        BorderSizePixel = 0,
        LayoutOrder = panelOrderInc(panel),
        ZIndex = 2,
    }, panel)
    new("UICorner", {CornerRadius = UDim.new(0, 4)}, frame)
    new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.5}, frame)
    local scr = new("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C_ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
    }, frame)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, scr)
    local selected = nil
    local lastData = {}
    local onSelectCb = nil
    local function paintEntry(b, isSel)
        if isSel then
            b.BackgroundColor3 = C_CTRL_H
            b:FindFirstChildOfClass("UIStroke").Transparency = 0.1
        else
            b.BackgroundColor3 = C_CTRL
            b:FindFirstChildOfClass("UIStroke").Transparency = 1
        end
    end
    local function rebuild(data)
        lastData = data or lastData
        for _, c in ipairs(scr:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        if #lastData == 0 then
            new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
                Text = "— Нет игроков —", TextColor3 = C_DIM, Font = Enum.Font.GothamMedium,
                TextSize = 11, ZIndex = 2, LayoutOrder = 1,
            }, scr)
            return
        end
        for i, d in ipairs(lastData) do
            local b = new("TextButton", {
                Size = UDim2.new(1, -4, 0, 20),
                BackgroundColor3 = C_CTRL,
                Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 3,
            }, scr)
            new("UICorner", {CornerRadius = UDim.new(0, 3)}, b)
            new("UIStroke", {Color = C_ACCENT, Thickness = 1, Transparency = 1}, b)
            new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                Text = d.name, TextColor3 = C_TXT, Font = Enum.Font.GothamMedium, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
            }, b)
            new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, -50, 0, 0),
                Text = "[" .. d.dist .. "]", TextColor3 = C_DIM, Font = Enum.Font.GothamMedium, TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
            }, b)
            paintEntry(b, selected == d.name)
            b.MouseButton1Click:Connect(function()
                if selected == d.name then selected = nil else selected = d.name end
                for _, c in ipairs(scr:GetChildren()) do
                    if c:IsA("TextButton") then
                        local nm = c:FindFirstChildWhichIsA("TextLabel").Text
                        paintEntry(c, selected == nm)
                    end
                end
                if onSelectCb then onSelectCb(selected) end
            end)
        end
    end
    rebuild({})
    return {
        rebuild = rebuild,
        refresh = function() rebuild(lastData) end,
        getSelected = function() return selected end,
        connect = function(cb) onSelectCb = cb end,
    }
end

local function getPlayerListData()
    local out = {}
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
            table.insert(out, {name = plr.Name, dist = dist})
        end
    end
    return out
end

-- ============================================================
-- ================ СТРАНИЦЫ (все вкладки) ====================
-- ============================================================

-- храним ссылки на контролы, которые нужно синкать извне
local flightToggleCtl = nil
local autoClickToggleCtl = nil
local killListCtl = nil
local tpListCtl = nil
local flingListCtl = nil

-- ---------------- AIMBOT (категория) ----------------
addCategory("Combat")

-- ==== Legitbot (Aimbot + Silent Aim) ====
do
    local pg = addPage("Combat", "🎯", "Legitbot")

    local pMain = addPanel(pg.col1, "Main")
    addToggle(pMain, "aimbot.enabled", "Enabled", false, function(state)
        if state then enableAimbot() else disableAimbot() end
        updateFovCircle()
    end)

    local pAcc = addPanel(pg.col1, "Accuracy")
    addSlider(pAcc, "aimbot.fov", "Field Of View", 20, 500, 120, 5, function(v)
        S.aimbotFov = math.floor(v)
        updateFovCircle()
        flashFovCircle("aimbot", FovCircle, function() return S.aimbotOn end)
    end)
    addSlider(pAcc, "aimbot.smooth", "Smooth", 0.05, 1, 0.3, 0.05, function(v)
        S.aimbotSmooth = v
    end)
    addDropdown(pAcc, nil, "FOV Preset", {"60", "120", "200", "350"}, "120", function(v)
        local c = Cfg["aimbot.fov"]
        if c then c.set(tonumber(v)) end
    end)

    local pSilent = addPanel(pg.col2, "Silent Aim")
    addToggle(pSilent, "silent.enabled", "Enabled", false, function(state)
        if state then enableSilentAim() else disableSilentAim() end
        updateSilentFovCircle()
    end)
    addSlider(pSilent, "silent.fov", "Field Of View", 20, 500, 150, 5, function(v)
        S.silentAimFov = math.floor(v)
        updateSilentFovCircle()
        flashFovCircle("silent", SilentFovCircle, function() return S.silentAimOn end)
    end)
    addDropdown(pSilent, nil, "FOV Preset", {"80", "150", "250", "400"}, "150", function(v)
        local c = Cfg["silent.fov"]
        if c then c.set(tonumber(v)) end
    end)

    local pMisc = addPanel(pg.col2, "Misc")
    addToggle(pMisc, "aimbot.visualize", "Visualize FOV", true, function(state)
        S.fovVisualize = state
        updateFovCircle()
        updateSilentFovCircle()
    end)
    addToggle(pMisc, "aimbot.teamcheck", "Team Check", false, function(state)
        S.teamCheck = state
        if S.esp then disableESP() enableESP() end
    end)
    addToggle(pMisc, "aimbot.visiblecheck", "Visible Check", false, function(state)
        S.visibleCheck = state
    end)
    addText(pMisc, "Красный круг — Aimbot FOV, синий — Silent Aim FOV. Team Check игнорирует свою команду (и в ESP), Visible Check не целится сквозь стены.")
end

-- ==== Hitbox ====
do
    local pg = addPage("Combat", "▣", "Hitbox")

    local pMain = addPanel(pg.col1, "Main")
    addToggle(pMain, "hitbox.enabled", "Enabled", false, function(state)
        if state then enableHitbox() else disableHitbox() end
    end)
    addSlider(pMain, "hitbox.size", "Hitbox Size", 1, 30, 5, 1, function(v)
        S.hitboxSize = math.floor(v)
    end)
    addDropdown(pMain, nil, "Preset", {"3", "5", "10", "20"}, "5", function(v)
        local c = Cfg["hitbox.size"]
        if c then c.set(tonumber(v)) end
    end)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Увеличивает хитбоксы всех игроков до заданного размера (studs).")
    addText(pInfo, "Отключение возвращает оригинальные размеры.")
end

-- ==== Kill Player ====
do
    local pg = addPage("Combat", "☠", "Kill Player")

    local pTarget = addPanel(pg.col1, "Target")
    local killSel = nil
    local killList = makePlayerList(pTarget, 160)
    killList.connect(function(name) killSel = name end)
    killListCtl = killList
    addButton(pTarget, "Refresh List", function()
        killList.rebuild(getPlayerListData())
    end)
    addButton(pTarget, "Kill Target", function()
        local plr = killSel and Players:FindFirstChild(killSel)
        if plr then
            killPlayer(plr)
            print("[SpermaHub] Kill Player → " .. plr.Name)
            toastImpl("Kill Player", "Атакую: " .. plr.Name)
        else
            toastImpl("Kill Player", "Сначала выбери цель!")
        end
    end, C_RED, C_RED_H)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Телепорт к цели + спам атакой. Нужно оружие в инвентаре.")
    addText(pInfo, "Число справа в списке — дистанция до игрока (studs).")
end

-- ==== Fling ====
do
    local pg = addPage("Combat", "🌀", "Fling")

    local pTarget = addPanel(pg.col1, "Target")
    local flingSel = nil
    local flingList = makePlayerList(pTarget, 160)
    flingList.connect(function(name) flingSel = name end)
    flingListCtl = flingList
    addButton(pTarget, "Refresh List", function()
        flingList.rebuild(getPlayerListData())
    end)
    addButton(pTarget, "Fling Target", function()
        local plr = flingSel and Players:FindFirstChild(flingSel)
        if plr then
            flingPlayer(plr)
            toastImpl("Fling", "Флингую: " .. plr.Name)
        else
            toastImpl("Fling", "Сначала выбери цель!")
        end
    end, C_RED, C_RED_H)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Налетает на цель с огромной скоростью ~0.8 сек и отбрасывает её, затем возвращает тебя на место.")
end

-- ==== Anti-Aim ====
do
    local pg = addPage("Combat", "🔁", "Anti-Aim")

    local pAa = addPanel(pg.col1, "Anti-Aim")
    addToggle(pAa, "aa.enabled", "Enabled", false, function(state)
        if state then enableAntiAim() else disableAntiAim() end
    end)

    local pAng = addPanel(pg.col1, "Angles")
    addDropdown(pAng, "aa.pitch", "Pitch", {"Down", "Up", "Jitter", "None"}, "Down", function(v)
        S.aaPitch = v
    end)
    addDropdown(pAng, "aa.yaw", "Yaw", {"Disabled", "Backward", "Spin", "Random"}, "Backward", function(v)
        S.aaYaw = v
    end)
    addDropdown(pAng, "aa.jitter", "Yaw Jitter", {"Disabled", "Offset", "Random"}, "Disabled", function(v)
        S.aaYawJitter = v
    end)
    addSlider(pAng, "aa.spin", "Spin Speed", 10, 720, 180, 10, function(v)
        S.aaSpinSpeed = math.floor(v)
    end)

    local pExtra = addPanel(pg.col2, "Extra")
    addToggle(pExtra, "aa.slowwalk", "Slow Walk", false, function(state)
        S.aaSlowWalk = state
    end)
    addSlider(pExtra, "aa.slowspeed", "Slow Walk Speed", 1, 16, 8, 1, function(v)
        S.aaSlowSpeed = math.floor(v)
    end)
    addToggle(pExtra, "aa.freestanding", "Freestanding", false, function(state)
        S.aaFreestanding = state
    end)
    addText(pExtra, "Freestanding — сам встаёт спиной к ближайшему врагу (до 60 стадов). Если врага рядом нет — спиной к камере.")

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Реал-стайл анти-аим (как на скрине из Neverlose): фейковые углы тела, чтобы вражеский аимбот целился не туда.")
    addText(pInfo, "Slow Walk — заниженная скорость, пока включён Anti-Aim (не совмещать со Walk Speed из вкладки Player).")
end

-- ==== Auto Clicker ====
do
    local pg = addPage("Combat", "🖱", "Auto Clicker")

    local pMain = addPanel(pg.col1, "Main")
    autoClickToggleCtl = addToggle(pMain, "ac.enabled", "Enabled", false, function(state)
        if state then enableAutoClicker() else disableAutoClicker() end
    end)
    addDropdown(pMain, "ac.mode", "Mouse Buttons", {"ЛКМ", "ПКМ", "ЛКМ + ПКМ"}, "ЛКМ", function(v)
        S.autoClickMode = v
    end)
    addSlider(pMain, "ac.cps", "Clicks Per Second", 1, 30, 10, 1, function(v)
        S.autoClickCps = math.floor(v)
    end)
    addKeybind(pMain, "ac.bind", "Toggle Key", "X", function(kc)
        S.autoClickBind = kc
    end)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Автоматически кликает ЛКМ/ПКМ с заданной скоростью.")
    addText(pInfo, "Кликает ТОЛЬКО когда курсор над игровым миром: не в чате и не поверх любых меню.")
end

-- ---------------- VISUALS ----------------
addCategory("Visuals")

-- ==== Players (ESP) ====
do
    local pg = addPage("Visuals", "👤", "Players")

    local pEsp = addPanel(pg.col1, "ESP")
    addToggle(pEsp, "esp.enabled", "Enabled", false, function(state)
        if state then enableESP() else disableESP() end
    end)
    addText(pEsp, "Детектор чужого хитбокса (⚠ если увеличен) идёт вместе с именами.")

    local pComp = addPanel(pg.col1, "Components")
    addToggle(pComp, "esp.chams", "Chams (неон)", true, function(state)
        S.espChams = state
    end)
    addToggle(pComp, "esp.box", "Box", true, function(state)
        S.espBox = state
    end)
    addToggle(pComp, "esp.skeleton", "Skeleton", true, function(state)
        S.espSkeleton = state
    end)
    addToggle(pComp, "esp.names", "Name + HP", true, function(state)
        S.espNames = state
    end)

    local pStyle = addPanel(pg.col2, "Chams Style")
    addDropdown(pStyle, "esp.chamstyle", "Style", {"Purple", "Pink", "Red", "Green", "Cyan", "Gold"}, "Purple", function(v)
        S.chamStyle = v
    end)
    addText(pStyle, "Неоновый глоу сквозь стены — как на скринах. Стиль применяется мгновенно. R6 и R15.")

    local pTgt = addPanel(pg.col2, "Target ESP")
    addToggle(pTgt, "esp.target", "Enabled", false, function(state)
        if state then enableTargetESP() else disableTargetESP() end
    end)
    addDropdown(pTgt, "esp.targetstyle", "Color", {"Pink", "Purple", "Red", "Gold"}, "Pink", function(v)
        S.targetStyle = v
    end)
    addText(pTgt, "Пульсирующая неоновая подсветка текущей цели Aimbot / Silent Aim. Работает отдельно от обычного ESP.")
end

-- ==== World (Watermark + HUD) ====
do
    local pg = addPage("Visuals", "🌐", "World")

    local pHud = addPanel(pg.col1, "Interface")
    addToggle(pHud, "wm.enabled", "Watermark", true, function(state)
        S.wmOn = state
        WM.Visible = state
    end)
    addToggle(pHud, "hud.enabled", "HUD (NL-style)", false, function(state)
        HUDGui.Enabled = state
    end)

    local pFx = addPanel(pg.col2, "Effects")
    addToggle(pFx, "fx.tracers", "Bullet Tracers", false, function(state)
        S.tracersOn = state
    end)
    addToggle(pFx, "fx.hitmarker", "Hitmarker", false, function(state)
        S.hitmarkerOn = state
    end)
    addText(pFx, "Работают при выстреле с оружием в руках. Трассер — до точки попадания / цели Silent Aim.")

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Watermark — FPS/Ping/время/дата (перетаскивается).")
    addText(pInfo, "HUD — компактный бар сверху по центру: название + FPS.")
end

-- ---------------- MOVEMENT ----------------
addCategory("Movement")

-- ==== Main (Flight + Noclip) ====
do
    local pg = addPage("Movement", "➤", "Main")

    local pFly = addPanel(pg.col1, "Flight")
    flightToggleCtl = addToggle(pFly, "fly.enabled", "Enabled", false, function(state)
        if state then startFly() else stopFly() end
    end)
    addSlider(pFly, "fly.speed", "Speed", 10, 250, 50, 5, function(v)
        S.speed = math.floor(v)
    end)
    addDropdown(pFly, nil, "Preset", {"50", "100", "150", "250"}, "50", function(v)
        local c = Cfg["fly.speed"]
        if c then c.set(tonumber(v)) end
    end)
    addText(pFly, "WASD + Space (вверх) / Ctrl (вниз).")

    local pBhop = addPanel(pg.col1, "Bhop")
    addToggle(pBhop, "bhop.enabled", "Enabled", false, function(state)
        if state then enableBhop() else disableBhop() end
    end)
    addDropdown(pBhop, "bhop.mode", "Mode", {"Hold Space", "Auto Jump"}, "Hold Space", function(v)
        S.bhopMode = v
    end)
    addText(pBhop, "Кроличий прыжок: автоматический Jump в кадре касания земли — прыжки идут без пауз. Hold Space — прыгать пока зажат пробел, Auto Jump — без нажатий.")

    local pNc = addPanel(pg.col2, "Noclip")
    addToggle(pNc, "noclip.enabled", "Enabled", false, function(state)
        if state then enableNoclip() else disableNoclip() end
    end)
    addText(pNc, "Проход сквозь стены.")

    local pJesus = addPanel(pg.col2, "Jesus")
    addToggle(pJesus, "jesus.enabled", "Enabled", false, function(state)
        if state then enableJesus() else disableJesus() end
    end)
    addText(pJesus, "Ходьба по воде — невидимая платформа под ногами ровно на поверхности воды. Не плывёшь, а идёшь.")

    local pSpin = addPanel(pg.col2, "Spin")
    addToggle(pSpin, "move.spin.enabled", "Enabled", false, function(state)
        if state then enableSpin() else disableSpin() end
    end)
    addSlider(pSpin, "move.spin.speed", "Spin Speed", 10, 720, 90, 10, function(v)
        S.spinSpeed = math.floor(v)
    end)
    addText(pSpin, "Вращает персонажа вокруг своей оси. Скорость — градусов в секунду.")
end

-- ==== Teleport (Click TP) ====
do
    local pg = addPage("Movement", "📍", "Teleport")

    local pTp = addPanel(pg.col1, "Click TP")
    addToggle(pTp, "clicktp.enabled", "Enabled", false, function(state)
        if state then enableClickTp() else disableClickTp() end
    end)
    addSlider(pTp, "clicktp.height", "Height", 1, 20, 3, 1, function(v)
        S.clickTpHeight = math.floor(v)
    end)
    addDropdown(pTp, nil, "Preset", {"1", "3", "5", "10"}, "3", function(v)
        local c = Cfg["clicktp.height"]
        if c then c.set(tonumber(v)) end
    end)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "ЛКМ по поверхности — телепорт туда (на заданной высоте).")
end

-- ---------------- PLAYER ----------------
addCategory("Player")

-- ==== Main (WalkSpeed + TP Player) ====
do
    local pg = addPage("Player", "👣", "Main")

    local pWs = addPanel(pg.col1, "WalkSpeed")
    addToggle(pWs, "ws.enabled", "Enabled", false, function(state)
        S.walkSpeedOn = state
        applyWalkSpeed()
    end)
    addSlider(pWs, "ws.speed", "Speed", 16, 200, 16, 2, function(v)
        S.walkSpeed = math.floor(v)
        if S.walkSpeedOn then applyWalkSpeed() end
    end)
    addDropdown(pWs, nil, "Preset", {"16", "50", "100", "200"}, "16", function(v)
        local c = Cfg["ws.speed"]
        if c then c.set(tonumber(v)) end
    end)

    local pGod = addPanel(pg.col1, "God Mode")
    addToggle(pGod, "player.god.enabled", "Enabled", false, function(state)
        if state then enableGod() else disableGod() end
    end)
    addText(pGod, "Держит HP на максимуме каждый кадр. Работает не во всех играх (где HP контролирует сервер).")

    local pTp = addPanel(pg.col2, "TP Player")
    local tpSel = nil
    local tpList = makePlayerList(pTp, 150)
    tpList.connect(function(name) tpSel = name end)
    tpListCtl = tpList
    addButton(pTp, "Refresh List", function()
        tpList.rebuild(getPlayerListData())
    end)
    addButton(pTp, "Teleport", function()
        local plr = tpSel and Players:FindFirstChild(tpSel)
        if plr then
            tpToPlayer(plr)
            toastImpl("TP Player", "Телепорт к " .. plr.Name)
        else
            toastImpl("TP Player", "Сначала выбери игрока!")
        end
    end, Color3.fromRGB(24, 70, 110), Color3.fromRGB(30, 86, 132))
end

-- ---------------- MISCELLANEOUS ----------------
addCategory("Miscellaneous")

local currentProfile = "Global"

-- конфиг: сохранение/загрузка
local function cfgFile(p)
    return "spermahub_nl_" .. string.gsub(tostring(p), "%s", "_") .. ".json"
end
local function doSave(profile)
    local data = {}
    for k, v in pairs(Cfg) do
        local ok, val = pcall(v.get)
        if ok then data[k] = val end
    end
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then toastImpl("Config", "Ошибка encode") return end
    if type(writefile) == "function" then
        pcall(writefile, cfgFile(profile), json)
        toastImpl("Config", "Сохранено: " .. profile)
    elseif type(setclipboard) == "function" then
        pcall(setclipboard, json)
        toastImpl("Config", "JSON скопирован в буфер")
    else
        print("[SpermaHub] Config: " .. json)
        toastImpl("Config", "writefile недоступен — JSON в консоли")
    end
end
local function doLoad(profile, silent)
    if type(readfile) ~= "function" then
        if not silent then toastImpl("Config", "readfile недоступен") end
        return
    end
    local ok, content = pcall(readfile, cfgFile(profile))
    if not ok or not content then
        if not silent then toastImpl("Config", "Нет сохранения: " .. profile) end
        return
    end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(data) ~= "table" then
        toastImpl("Config", "Файл конфига повреждён")
        return
    end
    for k, v in pairs(data) do
        if Cfg[k] then pcall(function() Cfg[k].set(v) end) end
    end
    if not silent then toastImpl("Config", "Загружено: " .. profile) end
end

-- ==== Main (Configs + Info + Script) ====
local miscPage
do
    miscPage = addPage("Miscellaneous", "⚙", "Main")

    local pCfg = addPanel(miscPage.col1, "Configs")
    addButton(pCfg, "Save Config", function() doSave(currentProfile) end)
    addButton(pCfg, "Load Config", function() doLoad(currentProfile) end)
    addText(pCfg, "Профиль выбирается в топбаре (Global / Slot 1 / Slot 2).")

    local pInfo = addPanel(miscPage.col1, "Info")
    addText(pInfo, "RightShift — скрыть/показать меню.")
    addText(pInfo, "Круглая кнопка ✦ — то же самое.")
    addText(pInfo, "🔍 в топбаре — поиск по вкладкам.")

    local pScript = addPanel(miscPage.col2, "Script")
    addButton(pScript, "Copy Discord", function()
        local link = "https://discord.gg/bUcTUuB9U5"
        if type(setclipboard) == "function" then
            pcall(setclipboard, link)
            toastImpl("Discord", "Ссылка скопирована")
        else
            print("[SpermaHub] " .. link)
        end
    end)
    addButton(pScript, "Close Script", function()
        fullCleanupNL()
    end, C_RED, C_RED_H)
end

-- ============================================================
-- ===================== ПОЛНАЯ ВЫГРУЗКА ======================
-- ============================================================
local unloadedNL = false
function fullCleanupNL()
    if unloadedNL then return end
    unloadedNL = true
    S.guiAlive = false
    if S.flyConn then S.flyConn:Disconnect() end
    if S.noclipConn then S.noclipConn:Disconnect() end
    if S.espConn then S.espConn:Disconnect() end
    if S.targetEspConn then S.targetEspConn:Disconnect() end
    if S.wsConn then S.wsConn:Disconnect() end
    if S.clickTpConn then S.clickTpConn:Disconnect() end
    if S.hitboxConn then S.hitboxConn:Disconnect() end
    if S.aimbotConn then S.aimbotConn:Disconnect() end
    if S.silentAimConn then pcall(function() S.silentAimConn:Disconnect() end) end
    disableAutoClicker()
    if S.autoClickBindConn then S.autoClickBindConn:Disconnect() end
    if S.jesusConn then S.jesusConn:Disconnect() end
    if S.jesusPlatform then S.jesusPlatform:Destroy() S.jesusPlatform = nil end
    if S.spinConn then S.spinConn:Disconnect() end
    if S.aaConn then S.aaConn:Disconnect() end
    if S.aaStepConn then S.aaStepConn:Disconnect() end
    if S.bhopConn then S.bhopConn:Disconnect() end
    if S.godConn then S.godConn:Disconnect() end
    if S.flingConn then S.flingConn:Disconnect() end
    if S.fxConn then S.fxConn:Disconnect() end
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
    pcall(disableTargetESP)
    for _, n in ipairs({"SpermaHubESP","SpermaHubWatermark","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL","SpermaHubNLToggle"}) do
        local g = LP.PlayerGui:FindFirstChild(n)
        if g then g:Destroy() end
    end
    print("✦ SpermaHub (NL) полностью выгружен")
end

-- ============================================================
-- ===================== ТОПБАР: КНОПКИ =======================
-- ============================================================

-- Save (иконка + текст)
local SaveBtn = new("TextButton", {
    Size = UDim2.new(0, 86, 0, 26),
    Position = UDim2.new(0, 14, 0.5, -13),
    BackgroundColor3 = C_CTRL, Text = "", AutoButtonColor = false, ZIndex = 4,
}, Topbar)
new("UICorner", {CornerRadius = UDim.new(0, 5)}, SaveBtn)
new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.5}, SaveBtn)
new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(0, 8, 0, 0),
    Text = "💾", TextColor3 = C_GRAY, TextSize = 12, ZIndex = 4,
}, SaveBtn)
new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 28, 0, 0),
    Text = "Save", TextColor3 = C_TXT, Font = Enum.Font.GothamMedium, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, SaveBtn)
SaveBtn.MouseButton1Click:Connect(function() doSave(currentProfile) end)

-- Profile dropdown ("Global")
local ProfBox = new("TextButton", {
    Size = UDim2.new(0, 120, 0, 26),
    Position = UDim2.new(0, 108, 0.5, -13),
    BackgroundColor3 = C_CTRL, Text = "", AutoButtonColor = false, ZIndex = 4,
}, Topbar)
new("UICorner", {CornerRadius = UDim.new(0, 5)}, ProfBox)
new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.5}, ProfBox)
local ProfLabel = new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -26, 1, 0), Position = UDim2.new(0, 10, 0, 0),
    Text = "Global", TextColor3 = C_TXT, Font = Enum.Font.GothamMedium, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, ProfBox)
new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -20, 0, 0),
    Text = "▾", TextColor3 = C_GRAY, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 4,
}, ProfBox)
ProfBox.MouseButton1Click:Connect(function()
    openDropdownList(ProfBox, {"Global", "Slot 1", "Slot 2"}, currentProfile, function(v)
        currentProfile = v
        ProfLabel.Text = tostring(v)
        doLoad(v)
    end)
end)

-- иконки справа: discord / settings / search
local function topIcon(txt, xoff, cb)
    local b = new("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, xoff, 0.5, -13),
        BackgroundColor3 = C_CTRL, Text = txt, TextSize = 13,
        AutoButtonColor = false, ZIndex = 4,
    }, Topbar)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, b)
    b.MouseButton1Click:Connect(function() if cb then cb() end end)
    return b
end
topIcon("💬", -36, function()
    local link = "https://discord.gg/bUcTUuB9U5"
    if type(setclipboard) == "function" then pcall(setclipboard, link) toastImpl("Discord", "Ссылка скопирована") end
end)
topIcon("⚙", -68, function() selectPage(miscPage) end)
topIcon("🔍", -100, toggleSearch)

-- ============================================================
-- ============ ПЕРЕТАСКИВАНИЕ ОКНА / ОТКРЫТИЕ ================
-- ============================================================
local function makeDraggable(handle, frame)
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            closeDropdownList()
            local startPos = input.Position
            local framePos = frame.Position
            local moveConn
            moveConn = UIS.InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                    local delta = inp.Position - startPos
                    frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
                end
            end)
            local endConn
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    moveConn:Disconnect()
                    endConn:Disconnect()
                end
            end)
        end
    end)
end
makeDraggable(Topbar, Main)
makeDraggable(Logo, Main)

-- RightShift = скрыть/показать
UIS.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.RightShift and not UIS:GetFocusedTextBox() then
        if Main.Visible then closeDropdownList() end
        Main.Visible = not Main.Visible
    end
end)

-- круглая кнопка ✦ (как раньше)
local TG = new("ScreenGui", {
    Name = "SpermaHubNLToggle",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 105,
}, LP:WaitForChild("PlayerGui"))
local ToggleBtn = new("TextButton", {
    Size = UDim2.new(0, 46, 0, 46),
    Position = UDim2.new(0, 15, 0.5, -23),
    BackgroundColor3 = Color3.fromRGB(30, 20, 40),
    Text = "✦",
    TextColor3 = Color3.fromRGB(230, 130, 255),
    Font = Enum.Font.GothamBlack,
    TextSize = 22,
    AutoButtonColor = false,
    ZIndex = 5,
}, TG)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, ToggleBtn)
local TS = new("UIStroke", {Color = Color3.fromRGB(180, 40, 200), Thickness = 2, Transparency = 0.2}, ToggleBtn)
ToggleBtn.Active = true
ToggleBtn.Draggable = true
task.spawn(function()
    while ToggleBtn.Parent do
        TweenService:Create(TS, TweenInfo.new(1.2), {Transparency = 0.7}):Play()
        task.wait(1.2)
        if not ToggleBtn.Parent then break end
        TweenService:Create(TS, TweenInfo.new(1.2), {Transparency = 0.1}):Play()
        task.wait(1.2)
    end
end)
ToggleBtn.MouseButton1Click:Connect(function()
    if Main.Visible then closeDropdownList() end
    Main.Visible = not Main.Visible
end)

-- автокликер: переключение по бинду
S.autoClickBindConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not S.autoClickBind then return end
    if input.KeyCode == S.autoClickBind then
        if autoClickToggleCtl then autoClickToggleCtl.set(not S.autoClickOn) end
    end
end)

-- ============================================================
-- ================== АВТООБНОВЛЕНИЕ СПИСКОВ ==================
-- ============================================================
task.spawn(function()
    while S.guiAlive do
        task.wait(2)
        if S.guiAlive then
            pcall(function() killListCtl.rebuild(getPlayerListData()) end)
            pcall(function() tpListCtl.rebuild(getPlayerListData()) end)
        pcall(function() flingListCtl.rebuild(getPlayerListData()) end)
        end
    end
end)

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if S.guiAlive then
        pcall(function() killListCtl.rebuild(getPlayerListData()) end)
        pcall(function() tpListCtl.rebuild(getPlayerListData()) end)
        pcall(function() flingListCtl.rebuild(getPlayerListData()) end)
    end
end)
Players.PlayerRemoving:Connect(function()
    if S.guiAlive then
        pcall(function() killListCtl.rebuild(getPlayerListData()) end)
        pcall(function() tpListCtl.rebuild(getPlayerListData()) end)
        pcall(function() flingListCtl.rebuild(getPlayerListData()) end)
    end
end)

-- ============================================================
-- ======================== РЕСПАВН ===========================
-- ============================================================
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if S.flying then
        stopFly()
        if flightToggleCtl then flightToggleCtl.set(false) end
    end
    if S.noclip then
        if S.noclipConn then S.noclipConn:Disconnect() end
        S.noclip = true
        enableNoclip()
    end
    task.wait(0.2)
    applyWalkSpeed()
end)

-- ============================================================
-- ==================== ИНИЦИАЛИЗАЦИЯ =========================
-- ============================================================
updateFovCircle()
updateSilentFovCircle()
WM.Visible = S.wmOn

-- открыть первую страницу (Legitbot)
if Pages[1] then selectPage(Pages[1]) end

-- первичное заполнение списков игроков
task.spawn(function()
    task.wait(0.5)
    pcall(function() killListCtl.rebuild(getPlayerListData()) end)
    pcall(function() tpListCtl.rebuild(getPlayerListData()) end)
        pcall(function() flingListCtl.rebuild(getPlayerListData()) end)
end)

-- тихая автозагрузка конфига Global (если есть)
task.spawn(function()
    task.wait(0.3)
    doLoad("Global", true)
end)

toastImpl("SpermaHub v41", "NeverLose-style GUI загружена!")
print("✦ SpermaHub v41 (NeverLose-style) загружен!")
print("Combat: Legitbot | Hitbox | Kill Player | Fling | Anti-Aim | Auto Clicker | +Tracers/Hitmarker/Spin/GodMode/TeamCheck/VisibleCheck")
print("Visuals: Players (Chams ESP + Target ESP) | World | Movement: Fly/Noclip/Jesus/Bhop + Click TP | Player | Misc")
