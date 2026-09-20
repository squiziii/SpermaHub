-- SpermaHub v41 | NeverLose-style GUI
-- Интерфейс в стиле NEVERLOSE (как на скрине): сайдбар + топбар + двухколоночные панели,
-- сделан с нуля на Instance.new — внешних UI-библиотек НЕ нужно.
-- Перенесены ВСЕ вкладки и функции:
--   Combat:        Legitbot | Hitbox | Kill Player | Fling | Spectate | Anti-Aim | Auto Clicker
--   Visuals:       Players (ESP: Chams/Box/Skeleton/Names + Target ESP) | World
--   Movement:      Main (Flight/Noclip/Jesus/Spin/Bhop) | Teleport (Click TP)
--   Player:        Main (WalkSpeed + God Mode + TP Player)
--   Server:        Bypass (Anti-Cheat Bypass) | Server (Rejoin/Hop/Copy ID)
--   Miscellaneous: Configs | Script | Key Binds (клавиши/мышь/колёсико) + Target HUD
-- Управление: RightShift или круглая кнопка ✦ = скрыть/показать меню

-- отметка начала загрузки (если меню не появилось — смотри, до какого принта дошло)
print("[SpermaHub] Загрузка началась...")

-- полифилл для старых инжекторов без task.*
if type(task) ~= "table" or type(task.spawn) ~= "function" then
    local rs = game:GetService("RunService")
    task = {
        spawn = function(f, ...)
            local ok, e = pcall(f, ...)
            if not ok then warn("[SpermaHub] task err:", e) end
        end,
        wait = function(t)
            t = t or 0
            local s0 = tick()
            while tick() - s0 < t do rs.Heartbeat:Wait() end
        end,
        delay = function(t, f, ...)
            local delayArgs = {...}
            local delayN = select("#", ...)
            task.spawn(function()
                task.wait(t)
                f(unpack(delayArgs, 1, delayN))
            end)
        end,
    }
end

-- бут-окно: если меню НЕ появилось, на экране останется шаг, на котором упало
local BootGui = Instance.new("ScreenGui")
BootGui.Name = "SpermaHubBoot"
BootGui.ResetOnSpawn = false
BootGui.DisplayOrder = 999
local BootLabel = Instance.new("TextLabel")
do
    local plr = game:GetService("Players").LocalPlayer
    BootGui.Parent = plr:WaitForChild("PlayerGui")
    BootLabel.Size = UDim2.new(0, 360, 0, 22)
    BootLabel.Position = UDim2.new(0.5, -180, 0, 4)
    BootLabel.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
    BootLabel.BackgroundTransparency = 0.2
    BootLabel.BorderSizePixel = 0
    BootLabel.TextColor3 = Color3.fromRGB(200, 180, 255)
    BootLabel.Font = Enum.Font.GothamBold
    BootLabel.TextSize = 12
    BootLabel.Text = "SpermaHub: старт..."
    BootLabel.Parent = BootGui
    Instance.new("UICorner", BootLabel).CornerRadius = UDim.new(0, 5)
end
local function bootStep(s)
    BootLabel.Text = "SpermaHub: " .. s
    print("[SpermaHub] " .. s)
end
bootStep("старт")

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
    "SpermaHubFlingTarget","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL","SpermaHubNLToggle",
    "SpermaHubSpec","SpermaHubBoot","SpermaHubBinds","SpermaHubTHud"
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
    aaSpinSpeed=180, aaAngle=0, aaJitSide=false, aaSlowWalk=false, aaSlowSpeed=8, aaFreestanding=false, aaPinPos=nil, aaPinDrop=0,
    bhopOn=false, bhopConn=nil, bhopMode="Hold Space", bhopMethod="Velocity",
    afOn=false, afConn=nil, afMax=150,
    strafeOn=false, strafeConn=nil, strafeSpeed=40,
    specOn=false, specConn=nil, specTarget=nil,
    bypassMode="Off", akOn=false, akOriginal=nil,
    bindsWidgetOn=true, thudOn=false,
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
    SpermaHubESP=true, SpermaHubHUD=true, SpermaHubFov=true, SpermaHubWatermark=true, SpermaHubBinds=true, SpermaHubTHud=true, -- декоративные элементы скрипта не считаем
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

-- ============ ANTI-AIM (НАСТОЯЩИЕ fake angles) ============
-- Фейковый CFrame ставится в Heartbeat (после физики, перед отправкой на сервер)
-- и больше НЕ откатывается — его видят и сервер, и другие игроки.
-- Стабильность:
--  * yaw не влияет на физику (капсула круглая) — ходьба/прыжки как обычно;
--  * pitch: тело опускается к земле и обнуляется угловая скорость,
--    чтобы капсула спокойно лежала, а не отпрыгивала.
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
    S.aaConn = RunService.Heartbeat:Connect(function(dt)
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
            local pos
            if pitch ~= 0 then
                if hum and not hum.PlatformStand then
                    hum.PlatformStand = true -- отключить автовыпрямление: физика не борется с позой
                end
                -- зафиксировать точку лежания ОДИН раз -> тело не ездит/не крутится по земле, камера не дёргается
                if S.aaPinPos and (root.Position - S.aaPinPos).Magnitude > 6 then
                    S.aaPinPos = nil -- сдох/зареспавнился/телепорт — закрепить новое место
                end
                if not S.aaPinPos then
                    local p0 = root.Position
                    local drop0 = hum and ((hum.HipHeight or 0) + root.Size.Y / 2 - 0.5) or 0
                    if drop0 > 0 then
                        p0 = p0 - Vector3.new(0, drop0, 0)
                    end
                    S.aaPinPos = p0
                    S.aaPinDrop = math.max(drop0, 0)
                end
                pos = S.aaPinPos
            else
                -- Pitch = None: вернуть стоячую высоту, потом выпрямить (иначе выбросит вверх)
                if S.aaPinPos then
                    pos = S.aaPinPos + Vector3.new(0, S.aaPinDrop or 0, 0)
                    S.aaPinPos = nil
                else
                    pos = root.Position
                end
                if hum and hum.PlatformStand then hum.PlatformStand = false end
            end
            root.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(pitch), math.rad(yaw or getCamYawDeg()), 0)
            if pitch ~= 0 then
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        else
            if S.aaPinPos then
                root.CFrame = CFrame.new(S.aaPinPos + Vector3.new(0, S.aaPinDrop or 0, 0))
                S.aaPinPos = nil
            end
            if hum and hum.PlatformStand then hum.PlatformStand = false end
        end
    end)
end

local function disableAntiAim()
    S.aaOn = false
    if S.aaConn then S.aaConn:Disconnect() S.aaConn = nil end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if S.aaPinPos then
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(S.aaPinPos + Vector3.new(0, S.aaPinDrop or 0, 0)) end
        S.aaPinPos = nil
    end
    if hum and hum.PlatformStand then hum.PlatformStand = false end
    -- вернуть скорость после Slow Walk
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
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        if S.bhopMode == "Hold Space" and not UIS:IsKeyDown(Enum.KeyCode.Space) then return end
        if hum:GetState() == Enum.HumanoidStateType.Seated then return end
        if hum.FloorMaterial ~= Enum.Material.Air then
            if S.bhopMethod == "Velocity" then
                -- напрямую задаём вертикальную скорость: работает даже при JumpPower = 0
                local vel = root.AssemblyLinearVelocity
                local jp = math.max(hum.JumpPower or 0, 50)
                root.AssemblyLinearVelocity = Vector3.new(vel.X, jp, vel.Z)
            else
                hum.Jump = true
            end
        end
    end)
end

local function disableBhop()
    S.bhopOn = false
    if S.bhopConn then S.bhopConn:Disconnect() S.bhopConn = nil end
end

-- ============ ANTI FLING (защита от флинга) ============
local function enableAntiFling()
    S.afOn = true
    if S.afConn then S.afConn:Disconnect() end
    S.afConn = RunService.Stepped:Connect(function()
        if not S.afOn then return end
        if S.flying then return end -- Fly сам управляет скоростью
        if S.flingConn then return end -- свой флинг не трогаем
        local ch = LP.Character
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                local v = p.AssemblyLinearVelocity
                if v.Magnitude > S.afMax then
                    p.AssemblyLinearVelocity = v.Unit * S.afMax
                end
                local av = p.AssemblyAngularVelocity
                if av.Magnitude > S.afMax then
                    p.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)
end

local function disableAntiFling()
    S.afOn = false
    if S.afConn then S.afConn:Disconnect() S.afConn = nil end
end

-- ============ AUTO STRAFE (усиление bhop) ============
local function enableStrafe()
    S.strafeOn = true
    if S.strafeConn then S.strafeConn:Disconnect() end
    S.strafeConn = RunService.Heartbeat:Connect(function()
        if not S.strafeOn then return end
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if hum.FloorMaterial ~= Enum.Material.Air then return end -- только в воздухе
        local vel = root.AssemblyLinearVelocity
        local horiz = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
        if horiz < 2 then return end
        local cam = workspace.CurrentCamera
        local lv = cam.CFrame.LookVector
        local dir = Vector3.new(lv.X, 0, lv.Z)
        if dir.Magnitude < 0.05 then return end
        dir = dir.Unit
        -- подворачиваем горизонтальную скорость за камерой + лёгкий разгон до капы
        local newSpeed = math.min(horiz + 0.35, S.strafeSpeed)
        root.AssemblyLinearVelocity = Vector3.new(dir.X * newSpeed, vel.Y, dir.Z * newSpeed)
    end)
end

local function disableStrafe()
    S.strafeOn = false
    if S.strafeConn then S.strafeConn:Disconnect() S.strafeConn = nil end
end

-- ============ SPECTATE (с мини-окном) ============
local SpecGui = Instance.new("ScreenGui")
SpecGui.Name = "SpermaHubSpec"
SpecGui.ResetOnSpawn = false
SpecGui.IgnoreGuiInset = true
SpecGui.DisplayOrder = 90
SpecGui.Parent = LP:WaitForChild("PlayerGui")

local SpecWin = Instance.new("Frame")
SpecWin.Size = UDim2.new(0, 220, 0, 78)
SpecWin.Position = UDim2.new(0.5, -110, 1, -120)
SpecWin.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
SpecWin.BackgroundTransparency = 0.1
SpecWin.BorderSizePixel = 0
SpecWin.Active = true
SpecWin.Draggable = true
SpecWin.Visible = false
SpecWin.Parent = SpecGui
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = SpecWin
    local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(120, 60, 200) s.Thickness = 1 s.Transparency = 0.3 s.Parent = SpecWin
end

local SpecTitle = Instance.new("TextLabel")
SpecTitle.Size = UDim2.new(1, -70, 0, 26)
SpecTitle.Position = UDim2.new(0, 10, 0, 4)
SpecTitle.BackgroundTransparency = 1
SpecTitle.Text = "👁 Spectate"
SpecTitle.TextColor3 = Color3.fromRGB(200, 160, 255)
SpecTitle.Font = Enum.Font.GothamBold
SpecTitle.TextSize = 13
SpecTitle.TextXAlignment = Enum.TextXAlignment.Left
SpecTitle.Parent = SpecWin

local SpecExit = Instance.new("TextButton")
SpecExit.Size = UDim2.new(0, 62, 0, 20)
SpecExit.Position = UDim2.new(1, -70, 0, 6)
SpecExit.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
SpecExit.Text = "✖ Выйти"
SpecExit.TextColor3 = Color3.fromRGB(255, 220, 220)
SpecExit.Font = Enum.Font.GothamBold
SpecExit.TextSize = 11
SpecExit.BorderSizePixel = 0
SpecExit.AutoButtonColor = true
SpecExit.Parent = SpecWin
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = SpecExit
end

local SpecInfo = Instance.new("TextLabel")
SpecInfo.Size = UDim2.new(1, -20, 0, 34)
SpecInfo.Position = UDim2.new(0, 10, 0, 36)
SpecInfo.BackgroundTransparency = 1
SpecInfo.Text = "--"
SpecInfo.TextColor3 = Color3.fromRGB(230, 230, 240)
SpecInfo.Font = Enum.Font.GothamBold
SpecInfo.TextSize = 13
SpecInfo.TextXAlignment = Enum.TextXAlignment.Left
SpecInfo.TextYAlignment = Enum.TextYAlignment.Top
SpecInfo.Parent = SpecWin

local function exitSpectate()
    if not S.specOn then
        SpecWin.Visible = false
        return
    end
    S.specOn = false
    S.specTarget = nil
    if S.specConn then S.specConn:Disconnect() S.specConn = nil end
    SpecWin.Visible = false
    local cam = workspace.CurrentCamera
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then cam.CameraSubject = hum end
    cam.CameraType = Enum.CameraType.Custom
end

SpecExit.MouseButton1Click:Connect(exitSpectate)

local function startSpectate(plr)
    local tch = plr and plr.Character
    local thum = tch and tch:FindFirstChildOfClass("Humanoid")
    if not thum then
        toastImpl("Spectate", "У цели нет персонажа!")
        return
    end
    if S.specConn then S.specConn:Disconnect() end
    S.specOn = true
    S.specTarget = plr
    local cam = workspace.CurrentCamera
    cam.CameraSubject = thum
    SpecTitle.Text = "👁 Spectating"
    SpecWin.Visible = true
    toastImpl("Spectate", "Слежу за " .. plr.Name)
    S.specConn = RunService.RenderStepped:Connect(function()
        if not S.specOn then return end
        local t = S.specTarget
        local tch2 = t and t.Character
        local thum2 = tch2 and tch2:FindFirstChildOfClass("Humanoid")
        if not t or not t.Parent or not thum2 or thum2.Health <= 0 then
            toastImpl("Spectate", "Цель умерла или вышла")
            exitSpectate()
            return
        end
        cam.CameraSubject = thum2
        SpecInfo.Text = string.format("%s\n%.0f / %.0f HP", t.Name, thum2.Health, thum2.MaxHealth)
        local r = thum2.Health / thum2.MaxHealth
        SpecInfo.TextColor3 = Color3.fromRGB(math.floor(255 * (1 - r) + 80 * r), math.floor(255 * r), 120)
    end)
end

-- ============ ANTI-CHEAT BYPASS (честный) ============
-- Клиентские античиты живут в LocalScript/ModuleScript игрока — их можно убить.
-- Серверный античит клиентом не обходится в принципе (ни один чит не умеет).
local AC_PATTERNS = {
    "adonis", "anticheat", "anti-cheat", "anti cheat", "antihack", "anti-hack",
    "anticheatclient", "exploitdetector", "cheatdetector", "watchdog", "banhammer",
}

local function neuterAntiCheatScripts(dryRun)
    local killed = 0
    local roots = {
        LP:FindFirstChild("PlayerGui"),
        LP:FindFirstChild("PlayerScripts"),
        game:GetService("ReplicatedFirst"),
    }
    for _, root in ipairs(roots) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local n = string.lower(obj.Name)
                    for _, pat in ipairs(AC_PATTERNS) do
                        if string.find(n, pat, 1, true) then
                            killed = killed + 1
                            if not dryRun then
                                pcall(function() if obj:IsA("LocalScript") then obj.Disabled = true end end)
                                pcall(function() obj:Destroy() end)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    return killed
end

local function acHooksSupported()
    return type(getrawmetatable) == "function"
        and type(newcclosure) == "function"
        and type(setreadonly) == "function"
        and type(getnamecallmethod) == "function"
end

-- Anti Kick: перехват Namecall Kick (если экзекьютор умеет хуки)
local function enableAntiKick()
    if S.akOn then return true end
    if not acHooksSupported() then
        notify("Bypass", "Anti Kick недоступен: у экзекьютора нет хуков (на Xeno не работает)")
        return false
    end
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        S.akOriginal = old
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if S.akOn and method and (method == "Kick" or method == "kick") then
                return nil -- кик молча проглочен
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)
    if ok then
        S.akOn = true
        notify("Bypass", "Anti Kick включён")
    else
        notify("Bypass", "Не удалось поставить Anti Kick: " .. tostring(err))
    end
    return ok
end

local function disableAntiKick()
    if not S.akOn then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = S.akOriginal
        setreadonly(mt, true)
    end)
    S.akOn = false
    S.akOriginal = nil
end

local function applyBypassMode(mode)
    local prev = S.bypassMode
    S.bypassMode = mode
    if mode == "Off" then
        disableAntiKick()
        return
    end
    -- scripts killer (разово + авто)
    if mode == "Scripts Killer" or mode == "Full" then
        local k = neuterAntiCheatScripts(false)
        if mode ~= prev then
            toastImpl("Bypass", "Scripts Killer: отключено " .. tostring(k) .. " шт., авто-скан каждые 20 сек")
        end
    end
    -- anti kick
    if mode == "Anti Kick" or mode == "Full" then
        enableAntiKick()
    end
end

-- фоновый рескан клиентских античитов
task.spawn(function()
    while true do
        if S and S.guiAlive and (S.bypassMode == "Scripts Killer" or S.bypassMode == "Full") then
            pcall(neuterAntiCheatScripts, false)
        end
        task.wait(20)
    end
end)

local TeleportService = game:GetService("TeleportService")

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

bootStep("логика OK")

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

bootStep("ESP OK")

-- ============ WATERMARK (старый: FPS/Ping/время/дата, перетаскивается) ============
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
DateLabel.Text = "Sep.2026"
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

bootStep("Watermark OK")

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

bootStep("GUI OK")

-- ============================================================
-- ============ KEYBIND MANAGER + TARGET HUD ==================
-- ============================================================
-- обёрнуто в IIFE: локалки движка не держат регистры чанка (лимит Luau = 200)
(function()

-- список биндабельных функций (через Cfg-тогглы: меню и конфиг синхронно)
BindEntries = {
    {label = "Fly",          cfg = "fly.enabled"},
    {label = "Noclip",       cfg = "noclip.enabled"},
    {label = "Bhop",         cfg = "bhop.enabled"},
    {label = "Auto Strafe",  cfg = "bhop.strafe"},
    {label = "Jesus",        cfg = "jesus.enabled"},
    {label = "ESP",          cfg = "esp.enabled"},
    {label = "Target ESP",   cfg = "esp.target"},
    {label = "Aimbot",       cfg = "aimbot.enabled"},
    {label = "Silent Aim",   cfg = "silent.enabled"},
    {label = "Auto Clicker", cfg = "ac.enabled"},
    {label = "Hitbox",       cfg = "hitbox.enabled"},
    {label = "Anti-Aim",     cfg = "aa.enabled"},
    {label = "God Mode",     cfg = "player.god.enabled"},
    {label = "Anti Fling",   cfg = "antifling.enabled"},
    {label = "Spin",         cfg = "move.spin.enabled"},
    {label = "Click TP",     cfg = "clicktp.enabled"},
}
BindRowRefs = {} -- entry -> fn обновления текста бинда в меню

function bindDisplay(key)
    if not key then return "[-]" end
    if key == "WheelUp" then return "[Wh↑]"
    elseif key == "WheelDown" then return "[Wh↓]"
    elseif key == "MouseButton1" then return "[M1]"
    elseif key == "MouseButton2" then return "[M2]"
    elseif key == "MouseButton3" then return "[M3]"
    end
    return "[" .. tostring(key) .. "]"
end

-- ============ ВИДЖЕТ KEY BINDS (как на скрине) ============
local BindsGui = Instance.new("ScreenGui")
BindsGui.Name = "SpermaHubBinds"
BindsGui.ResetOnSpawn = false
BindsGui.IgnoreGuiInset = true
BindsGui.DisplayOrder = 102
BindsGui.Parent = LP:WaitForChild("PlayerGui")

BindsFrame = Instance.new("Frame")
BindsFrame.Position = UDim2.new(1, -185, 0, 46)
BindsFrame.Size = UDim2.new(0, 170, 0, 0)
BindsFrame.AutomaticSize = Enum.AutomaticSize.Y
BindsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 24)
BindsFrame.BackgroundTransparency = 0.12
BindsFrame.BorderSizePixel = 0
BindsFrame.Active = true
BindsFrame.Draggable = true
BindsFrame.Parent = BindsGui
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = BindsFrame
    local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(90, 70, 160) st.Thickness = 1 st.Transparency = 0.55 st.Parent = BindsFrame
end
local BindsTitle = Instance.new("TextLabel")
BindsTitle.Size = UDim2.new(1, 0, 0, 22)
BindsTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
BindsTitle.BackgroundTransparency = 0.3
BindsTitle.BorderSizePixel = 0
BindsTitle.Text = "    Key Binds"
BindsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
BindsTitle.Font = Enum.Font.GothamBold
BindsTitle.TextSize = 12
BindsTitle.TextXAlignment = Enum.TextXAlignment.Left
BindsTitle.Parent = BindsFrame
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = BindsTitle
end

local BindsList = Instance.new("Frame")
BindsList.Position = UDim2.new(0, 0, 0, 24)
BindsList.Size = UDim2.new(1, 0, 0, 0)
BindsList.AutomaticSize = Enum.AutomaticSize.Y
BindsList.BackgroundTransparency = 1
BindsList.Parent = BindsFrame
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = BindsList
    local p = Instance.new("UIPadding")
    p.PaddingBottom = UDim.new(0, 6)
    p.Parent = BindsList
end

function rebuildBindsWidget()
    for _, ch in ipairs(BindsList:GetChildren()) do
        if ch:IsA("TextLabel") then ch:Destroy() end
    end
    local order = 0
    for _, e in ipairs(BindEntries) do
        if e.key then
            order = order + 1
            local row = Instance.new("TextLabel")
            row.Size = UDim2.new(1, 0, 0, 18)
            row.BackgroundTransparency = 1
            row.Text = "   " .. e.label .. "    " .. bindDisplay(e.key)
            row.TextColor3 = Color3.fromRGB(225, 225, 240)
            row.Font = Enum.Font.GothamBold
            row.TextSize = 11
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.LayoutOrder = order
            row.Parent = BindsList
        end
    end
end

-- переключение функции по бинду (через Cfg — меню и конфиг синхронно)
local function fireBind(entry)
    local c = Cfg[entry.cfg]
    if c then
        pcall(function()
            c.set(not c.get())
        end)
    end
end

-- мышь над нашим меню? (чтобы колёсико в меню не триггерило бинды)
local function mouseOverRoot()
    if not S.guiAlive then return false end
    if not (Main and Main.Visible) then return false end
    local loc = UIS:GetMouseLocation()
    local p = Main.AbsolutePosition
    local s = Main.AbsoluteSize
    return loc.X >= p.X - 20 and loc.X <= p.X + s.X + 20
        and loc.Y >= p.Y - 70 and loc.Y <= p.Y + s.Y + 20
end

bindCapture = nil -- {entry=..., refresh=fn}

bindInputConn1 = UIS.InputBegan:Connect(function(input, gpe)
    -- режим назначения: ловим любую клавишу/кнопку мыши
    if bindCapture then
        local cap = bindCapture
        if input.KeyCode == Enum.KeyCode.Escape then
            bindCapture = nil
            cap.refresh()
            return
        end
        local keyName = nil
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
                bindCapture = nil
                cap.entry.key = nil
                cap.refresh()
                rebuildBindsWidget()
                return
            end
            keyName = input.KeyCode.Name
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            keyName = input.UserInputType.Name
        end
        if keyName then
            bindCapture = nil
            cap.entry.key = keyName
            cap.refresh()
            rebuildBindsWidget()
        end
        return
    end
    if gpe then return end
    if not S.guiAlive or mouseOverRoot() then return end
    for _, e in ipairs(BindEntries) do
        if e.key then
            local hit = false
            if input.UserInputType == Enum.UserInputType.Keyboard then
                hit = (input.KeyCode.Name == e.key)
            else
                hit = (input.UserInputType.Name == e.key)
            end
            if hit then fireBind(e) end
        end
    end
end)

bindInputConn2 = UIS.InputChanged:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
    local dir = input.Position.Z > 0 and "WheelUp" or "WheelDown"
    if bindCapture then
        local cap = bindCapture
        bindCapture = nil
        cap.entry.key = dir
        cap.refresh()
        rebuildBindsWidget()
        return
    end
    if gpe then return end
    if not S.guiAlive or mouseOverRoot() then return end
    for _, e in ipairs(BindEntries) do
        if e.key == dir then fireBind(e) end
    end
end)

-- сохранение биндов в конфиг (автоматически с нашей системой профилей)
for _, e in ipairs(BindEntries) do
    Cfg["bind." .. e.cfg] = {
        get = function() return e.key end,
        set = function(v)
            e.key = v
            if BindRowRefs[e] then BindRowRefs[e]() end
            pcall(rebuildBindsWidget)
        end,
    }
end
rebuildBindsWidget()

-- ============ TARGET HUD (аватар + ник + HP, как на скрине) ============
local THudGui = Instance.new("ScreenGui")
THudGui.Name = "SpermaHubTHud"
THudGui.ResetOnSpawn = false
THudGui.IgnoreGuiInset = true
THudGui.DisplayOrder = 103
THudGui.Parent = LP:WaitForChild("PlayerGui")

THudWin = Instance.new("Frame")
THudWin.Size = UDim2.new(0, 168, 0, 56)
THudWin.Position = UDim2.new(0, 12, 0, 96)
THudWin.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
THudWin.BackgroundTransparency = 0.15
THudWin.BorderSizePixel = 0
THudWin.Active = true
THudWin.Draggable = true
THudWin.Visible = false
THudWin.Parent = THudGui
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = THudWin
    local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(90, 60, 160) st.Thickness = 1 st.Transparency = 0.5 st.Parent = THudWin
end

local THudAva = Instance.new("ImageLabel")
THudAva.Size = UDim2.new(0, 42, 0, 42)
THudAva.Position = UDim2.new(0, 7, 0, 7)
THudAva.BackgroundColor3 = Color3.fromRGB(28, 26, 38)
THudAva.BorderSizePixel = 0
THudAva.Parent = THudWin
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = THudAva
end

local THudName = Instance.new("TextLabel")
THudName.Size = UDim2.new(1, -62, 0, 18)
THudName.Position = UDim2.new(0, 57, 0, 7)
THudName.BackgroundTransparency = 1
THudName.Text = "--"
THudName.TextColor3 = Color3.fromRGB(235, 235, 245)
THudName.Font = Enum.Font.GothamBold
THudName.TextSize = 13
THudName.TextXAlignment = Enum.TextXAlignment.Left
THudName.TextTruncate = Enum.TextTruncate.AtEnd
THudName.Parent = THudWin

local THudHp = Instance.new("TextLabel")
THudHp.Size = UDim2.new(1, -62, 0, 18)
THudHp.Position = UDim2.new(0, 57, 0, 27)
THudHp.BackgroundTransparency = 1
THudHp.Text = "HP: --"
THudHp.TextColor3 = Color3.fromRGB(170, 120, 255)
THudHp.Font = Enum.Font.GothamBold
THudHp.TextSize = 13
THudHp.TextXAlignment = Enum.TextXAlignment.Left
THudHp.Parent = THudWin

task.spawn(function()
    local lastTarget = nil
    while THudGui.Parent do
        local t = S.thudOn and currentEspTarget() or nil
        if t and t.Character then
            local tch = t.Character
            local thum = tch:FindFirstChildOfClass("Humanoid")
            if thum and thum.Health > 0 then
                if lastTarget ~= t then
                    lastTarget = t
                    THudName.Text = t.Name
                    task.spawn(function()
                        local ok, img = pcall(function()
                            return Players:GetUserThumbnailAsync(t.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                        end)
                        if ok and lastTarget == t then
                            THudAva.Image = img
                        end
                    end)
                end
                THudHp.Text = string.format("HP: %.1f", thum.Health)
                local r = thum.Health / thum.MaxHealth
                THudHp.TextColor3 = Color3.fromRGB(
                    math.floor(170 + 85 * (1 - r)),
                    math.floor(120 + 100 * r),
                    200)
                THudWin.Visible = true
            else
                THudWin.Visible = false
            end
        else
            lastTarget = nil
            THudWin.Visible = false
        end
        task.wait(0.15)
    end
end)
end)()

-- ============================================================
-- ================ СТРАНИЦЫ (все вкладки) ====================
-- ============================================================
-- обёрнуто в do...end: ~130 локалов страниц освобождаются в конце секции (лимит Luau = 200)
local doLoad, flingListCtl, killListCtl, specListCtl, tpListCtl
do

-- храним ссылки на контролы, которые нужно синкать извне
local flightToggleCtl = nil
local autoClickToggleCtl = nil
killListCtl = nil
tpListCtl = nil
flingListCtl = nil
specListCtl = nil

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

-- ==== Spectate ====
do
    local pg = addPage("Combat", "👁", "Spectate")

    local pTarget = addPanel(pg.col1, "Target")
    local specSel = nil
    local specList = makePlayerList(pTarget, 160)
    specList.connect(function(name) specSel = name end)
    specListCtl = specList
    addButton(pTarget, "Refresh List", function()
        specList.rebuild(getPlayerListData())
    end)
    addButton(pTarget, "Spectate", function()
        local plr = specSel and Players:FindFirstChild(specSel)
        if plr then
            startSpectate(plr)
        else
            toastImpl("Spectate", "Сначала выбери игрока!")
        end
    end)
    addButton(pTarget, "Exit Spectate", function()
        exitSpectate()
    end, C_RED, C_RED_H)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Камера следит за выбранным игроком. Появляется мини-окно (перетаскивается): сверху заголовок + кнопка выхода, снизу ник и HP цели.")
    addText(pInfo, "Если цель умрёт или выйдет — спек выключится сам.")
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
    addText(pInfo, "НАСТОЯЩИЕ fake angles: фейк держится постоянно — его видят и сервер, и другие игроки. Вражеский аимбот целится в фейковое тело.")
    addText(pInfo, "Slow Walk — заниженная скорость, пока включён Anti-Aim (не совмещать со Walk Speed). Pitch ложит тело на месте — движение при Pitch недоступно (как в реале).")
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
    addToggle(pTgt, "thud.enabled", "Target HUD", false, function(state)
        S.thudOn = state
        if not state then THudWin.Visible = false end
    end)
    addText(pTgt, "Пульсирующая подсветка цели Aimbot / Silent Aim. Target HUD — карточка с аватаром, ником и HP цели (перетаскивается).")
end

-- ==== World (Watermark) ====
do
    local pg = addPage("Visuals", "🌐", "World")

    local pHud = addPanel(pg.col1, "Interface")
    addToggle(pHud, "wm.enabled", "Watermark", true, function(state)
        S.wmOn = state
        WM.Visible = state
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
    addText(pInfo, "Watermark — ✦ Cracked с FPS/Ping/временем/датой. Перетаскивается.")
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
    addDropdown(pBhop, "bhop.method", "Method", {"Velocity", "Humanoid"}, "Velocity", function(v)
        S.bhopMethod = v
    end)
    addToggle(pBhop, "bhop.strafe", "Auto Strafe", false, function(state)
        if state then enableStrafe() else disableStrafe() end
    end)
    addSlider(pBhop, "bhop.strafecap", "Strafe Speed Cap", 16, 100, 40, 2, function(v)
        S.strafeSpeed = math.floor(v)
    end)
    addText(pBhop, "Auto Strafe: в воздухе подворачивает скорость за камерой и понемногу разгоняет (до капы) — классический бхоп-разгон.")
    addText(pBhop, "Кроличий прыжок: мгновенный прыжок при касании земли — без пауз. Hold Space — пока зажат пробел, Auto Jump — сам. Method: Velocity — через скорость (работает почти везде), Humanoid — через стандартный Jump.")

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

    local pAf = addPanel(pg.col2, "Anti Fling")
    addToggle(pAf, "antifling.enabled", "Enabled", false, function(state)
        if state then enableAntiFling() else disableAntiFling() end
    end)
    addSlider(pAf, "antifling.max", "Max Velocity", 50, 500, 150, 10, function(v)
        S.afMax = math.floor(v)
    end)
    addText(pAf, "Обрезает резкие рывки скорости (чужие флинги) до Max Velocity. Не трогает Fly и свой Fling.")

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

-- ---------------- SERVER ----------------
addCategory("Server")

-- ==== Bypass ====
do
    local pg = addPage("Server", "🛡", "Bypass")

    local pBy = addPanel(pg.col1, "Anti-Cheat Bypass")
    addDropdown(pBy, "bypass.mode", "Mode", {"Off", "Scripts Killer", "Anti Kick", "Full"}, "Off", function(v)
        applyBypassMode(v)
    end)
    addButton(pBy, "Neuter Now (разово)", function()
        local k = neuterAntiCheatScripts(false)
        toastImpl("Bypass", "Отключено античит-скриптов: " .. tostring(k))
    end)
    addButton(pBy, "Scan (только посчитать)", function()
        local k = neuterAntiCheatScripts(true)
        toastImpl("Bypass", "Подозрительных скриптов найдено: " .. tostring(k))
    end)
    addText(pBy, "Scripts Killer — ищет клиентские античиты (adonis/anticheat/watchdog/…) в PlayerGui, PlayerScripts и ReplicatedFirst и убивает их + авто-скан каждые 20 сек.")
    addText(pBy, "Anti Kick — перехват Namecall Kick. Нужны хуки экзекьютора (на Xeno недоступен — скрипт сам скажет). Full = оба режима.")

    local pNote = addPanel(pg.col2, "Важно")
    addText(pNote, "СЕРВЕРНЫЙ античит клиентом не обходит НИКТО — этот бипас убирает клиентские проверки (сканеры сторонних объектов, вотчдоги, клиент-кикер).")
    addText(pNote, "Если игра после Neuter сломалась (кнопки/анимации пропали) — выбери Off и перезайди: скрипты вернутся с респавном плейса.")
end

-- ==== Server ====
do
    local pg = addPage("Server", "📡", "Server")

    local pSrv = addPanel(pg.col1, "Actions")
    addButton(pSrv, "Rejoin", function()
        toastImpl("Server", "Реконнект...")
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end)
    end)
    addButton(pSrv, "Server Hop", function()
        toastImpl("Server", "Прыгаю на другой сервер...")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LP)
        end)
    end)
    addButton(pSrv, "Copy PlaceId", function()
        if type(setclipboard) == "function" then
            pcall(setclipboard, tostring(game.PlaceId))
            toastImpl("Server", "PlaceId скопирован")
        else
            toastImpl("Server", "setclipboard недоступен. ID: " .. tostring(game.PlaceId))
        end
    end)
    addButton(pSrv, "Copy JobId", function()
        if type(setclipboard) == "function" then
            pcall(setclipboard, tostring(game.JobId))
            toastImpl("Server", "JobId скопирован")
        else
            toastImpl("Server", "setclipboard недоступен")
        end
    end)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "PlaceId: " .. tostring(game.PlaceId))
    addText(pInfo, "JobId: " .. tostring(game.JobId))
    addText(pInfo, "Игроков сейчас: " .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers))
    addText(pInfo, "Server Hop отправляет на другой сервер этого же плейса (Roblox сам выберет).")
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
doLoad = function(profile, silent)
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

-- ==== Key Binds ====
do
    local pg = addPage("Miscellaneous", "⌨", "Key Binds")

    local pB = addPanel(pg.col1, "Binds")
    addText(pB, "Жми на окошко бинда, затем жми клавишу, кнопку мыши или крутани КОЛЁСИКО (вверх/вниз — разные бинды). Del/Backspace — стереть, Esc — отмена.")
    for _, e in ipairs(BindEntries) do
        local row = baseRow(pB, e.label, 160)
        local box = new("TextButton", {
            Size = UDim2.new(0, 96, 0, 20),
            Position = UDim2.new(1, -96, 0.5, -10),
            BackgroundColor3 = C_CTRL, Text = "", AutoButtonColor = false, ZIndex = 3,
        }, row)
        new("UICorner", {CornerRadius = UDim.new(0, 4)}, box)
        new("UIStroke", {Color = C_STROKE, Thickness = 1, Transparency = 0.5}, box)
        local tl = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
            Text = bindDisplay(e.key), TextColor3 = C_TXT,
            Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 3,
        }, box)
        BindRowRefs[e] = function()
            tl.Text = bindDisplay(e.key)
        end
        box.MouseButton1Click:Connect(function()
            bindCapture = {entry = e, refresh = BindRowRefs[e]}
            tl.Text = "[...]"
        end)
    end

    local pW = addPanel(pg.col2, "Widget")
    addToggle(pW, "binds.widget", "Show Key Binds Widget", true, function(state)
        S.bindsWidgetOn = state
        BindsFrame.Visible = state
    end)
    addText(pW, "Виджет Key Binds (как на скрине): показывает все назначенные бинды. Перетаскивается.")
    addText(pW, "Бинды НЕ срабатывают, когда мышь над меню — колёсико можно спокойно биндить.")
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

bootStep("страницы OK")

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
    if S.bhopConn then S.bhopConn:Disconnect() end
    if S.afConn then S.afConn:Disconnect() end
    if S.strafeConn then S.strafeConn:Disconnect() end
    if S.specConn then S.specConn:Disconnect() end
    if bindInputConn1 then bindInputConn1:Disconnect() end
    if bindInputConn2 then bindInputConn2:Disconnect() end
    pcall(exitSpectate)
    pcall(disableAntiKick)
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
    for _, n in ipairs({"SpermaHubESP","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL","SpermaHubNLToggle","SpermaHubSpec","SpermaHubWatermark","SpermaHubBinds","SpermaHubTHud"}) do
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
        pcall(function() specListCtl.rebuild(getPlayerListData()) end)
        end
    end
end)

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if S.guiAlive then
        pcall(function() killListCtl.rebuild(getPlayerListData()) end)
        pcall(function() tpListCtl.rebuild(getPlayerListData()) end)
        pcall(function() flingListCtl.rebuild(getPlayerListData()) end)
        pcall(function() specListCtl.rebuild(getPlayerListData()) end)
    end
end)
Players.PlayerRemoving:Connect(function()
    if S.guiAlive then
        pcall(function() killListCtl.rebuild(getPlayerListData()) end)
        pcall(function() tpListCtl.rebuild(getPlayerListData()) end)
        pcall(function() flingListCtl.rebuild(getPlayerListData()) end)
        pcall(function() specListCtl.rebuild(getPlayerListData()) end)
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
end -- /СЕКЦИЯ СТРАНИЦ

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
        pcall(function() specListCtl.rebuild(getPlayerListData()) end)
end)

-- тихая автозагрузка конфига Global (если есть)
task.spawn(function()
    task.wait(0.3)
    doLoad("Global", true)
end)

bootStep("финал OK")
pcall(function() BootGui:Destroy() end)
toastImpl("SpermaHub v41", "NeverLose-style GUI загружена!")
print("✦ SpermaHub v41 (NeverLose-style) загружен!")
print("Combat: Legitbot | Hitbox | Kill | Fling | Spectate | Anti-Aim | AutoClicker + AntiFling/AutoStrafe")
print("Visuals + Movement + Player + Server (Bypass/Server) | Misc")
