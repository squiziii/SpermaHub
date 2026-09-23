-- SpermaHub | GAMESENSE GUI (единый скрипт: библиотека gamesense встроена + весь функционал)
-- Интерфейс в стиле GAMESENSE / SKEET.CC: иконные вкладки, подвкладки с иконками,
-- авто-растущие секции, тема gamesense (зелёный акцент). Внешних UI-библиотек не нужно.
-- Перенесены ВСЕ вкладки и функции:
--   Combat:        Legitbot | Kill Aura + Silent Aura (1.8 Arena) | Hitbox | Kill Player | Fling | Spectate | Anti-Aim | Auto Clicker
--   Visuals:       Players (ESP: Chams/Box/Skeleton/Names + Target ESP) | World
--   Movement:      Main (Flight/Noclip/Jesus/Spin/Bhop/Spider/AirStack) | Teleport (Click TP)
--   Player:        Main (WalkSpeed + God Mode + TP Player) | Invisible | No Knockback
--   Server:        Bypass (Anti-Cheat Bypass) | Server (Rejoin/Hop/Copy ID)
--   Miscellaneous: Configs | Script | Key Binds (клавиши/мышь/колёсико) + Target HUD
-- Управление: RightShift = скрыть/показать меню gamesense

-- отметка начала загрузки (если меню не появилось — смотри, до какого принта дошло)
print("[SpermaHub] Загрузка началась...")
print("[SpermaHub] сборка: GAMESENSE GUI build5 (fix: stale windows cleanup)")

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

-- уничтожить прошлые gamesense-окна (после старого краша недостроенное окно остаётся висеть
-- и прячет новое полное меню — теперь при каждом запуске всё подчищается)
pcall(function()
    local function sweep(parent)
        if not parent then return end
        for _, g in ipairs(parent:GetChildren()) do
            if g:IsA("ScreenGui") and (g.Name:find("^gamesense") or g.Name == "SpermaHubGs") then
                g:Destroy()
            end
        end
    end
    local cg = game:GetService("CoreGui")
    pcall(sweep, cg)
    pcall(function() sweep(cg:FindFirstChild("RobloxGui")) end)
    pcall(function() sweep(LP and LP:FindFirstChild("PlayerGui")) end)
    pcall(function() if gethui then sweep(gethui()) end end)
    pcall(function()
        if getgenv and getgenv().Library and getgenv().Library.Unload then getgenv().Library:Unload() end
    end)
end)
pcall(function()
    local old = workspace:FindFirstChild("SpermaJesus")
    if old then old:Destroy() end
end)
pcall(function()
    local old = workspace:FindFirstChild("SpermaAirStack")
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
-- безопасный Disconnect с проверкой типа (некоторые conn-поля — булевы маркеры)
function dcc(c)
    if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end
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
    aimKey="Hold RMB", aimBone="Head",
    fovCircle=nil,
    silentAimOn=false, silentAimFov=150, silentAimConn=nil, silentAimFovCircle=nil,
    autoClickOn=false, autoClickCps=10, autoClickMode="ЛКМ",
    autoClickGen=0, autoClickBind=Enum.KeyCode.X, autoClickBindConn=nil,
    jesusOn=false, jesusConn=nil, jesusPlatform=nil,
    teamCheck=false, visibleCheck=false,
    tracersOn=false, hitmarkerOn=false, fxConn=nil,
    spinOn=false, spinSpeed=90, spinConn=nil, spinHeadDown=false, spinAngle=0, spinBaseYaw=0,
    aaOn=false, aaConn=nil, aaPitch="Down", aaYaw="Backward", aaYawJitter="Disabled",
    aaSpinSpeed=180, aaAngle=0, aaJitSide=false, aaSlowWalk=false, aaSlowSpeed=8, aaFreestanding=false, aaPinPos=nil, aaPinDrop=0, aaHeadDepth=1, aaHipOrig=nil, aaDesync=false, aaDesyncAmt=0.35, aaDesyncPrev=nil,
    aaFakeLag=false, flHistory=nil, flCycle=0, aaOnShot=false, aaFakeDuck=false, fdT=0, aaAntiBS=false, aaResAA=false,
    bhopOn=false, bhopConn=nil, bhopMode="Hold Space", bhopMethod="Velocity",
    afOn=false, afConn=nil, afMax=150,
    strafeOn=false, strafeConn=nil, strafeSpeed=40,
    specOn=false, specConn=nil, specTarget=nil,
    bypassMode="Off", akOn=false, akOriginal=nil,
    bindsWidgetOn=true, thudOn=false,
    spiderOn=false, spiderConn=nil, spiderSpeed=30,
    airstackOn=false, airstackConn=nil, airstackPlatform=nil, airstackY=0,
    invisOn=false, invisConn=nil, invisOffset=58, invisY=0,
    noKbOn=false, noKbConn=nil, noKbMax=45, noKbLast=nil, noKbFull=false,
    silentMode="Universal",
    flingMode="Velocity Burst", flingDur=5,
    scOn=false, scConn=nil, scPrevType=nil, scSpeed=6, scDist=8, scSens=1,
    asOn=false, asConn=nil, asFovPx=80, asCps=10, asSilentHit=true, asRange=20, asOrigSize=nil, asAssist=0,
    asTp=false, asTpRange=200, asTpDist=4, asBackCF=nil, asLastSwing=0,
    asFlick=false, asReaction=0.12, asNextFire=0, asLastTarget=nil, flickHead=nil, asFlickB=false, flickHold=false,
    asSilentNet=true, asNetByAuto=false, flHookOn=false, flOldFire=nil,
    asTrigger=false, asTrigDelay=0.08, asLastTrig=0,
    kaOn=false, kaConn=nil, kaRange=10, kaCps=12, kaFace=true, kaTarget=nil,
    saOn=false, saConn=nil, saRange=15, saDelay=0.3, saTarget=nil, saOrigSize=nil,
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
local function aimBonePart(ch)
    if S.aimBone == "Torso" then
        return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
            or ch:FindFirstChild("HumanoidRootPart")
    elseif S.aimBone == "Body" then
        return ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso")
            or ch:FindFirstChild("HumanoidRootPart")
    end
    return ch:FindFirstChild("Head")
end

local function getClosestTarget()
    local cam = workspace.CurrentCamera
    local closest = nil
    local closestDist = S.aimbotFov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local ch = plr.Character
            if ch then
                local head = aimBonePart(ch)
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

local function aimKeyPressed()
    if S.aimKey == "Always" then return true end
    if S.aimKey == "Hold E" then
        return UIS:IsKeyDown(Enum.KeyCode.E)
    end
    -- Hold RMB по умолчанию
    return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local function enableAimbot()
    S.aimbotOn = true
    if S.aimbotConn then
        RunService:UnbindFromRenderStep("SpermaHubAimbot")
        S.aimbotConn = nil
    end
    S.aimbotConn = true
    -- Нормально: аим пишется ПОСЛЕ игровой камеры (иначе Фортлайн её перезаписывает)
    RunService:BindToRenderStep("SpermaHubAimbot", Enum.RenderPriority.Camera.Value + 1, function()
        if not S.aimbotOn then return end
        if not aimKeyPressed() then return end
        local target = getClosestTarget()
        if target then
            local cam = workspace.CurrentCamera
            if not cam then return end
            local targetPos = target.Position
            local currentCF = cam.CFrame
            local lookAt = CFrame.new(currentCF.Position, targetPos)
            local k = S.aimbotSmooth
            if k >= 0.95 then
                cam.CFrame = lookAt -- snap
            else
                cam.CFrame = currentCF:Lerp(lookAt, k)
            end
        end
    end)
end

local function disableAimbot()
    S.aimbotOn = false
    if S.aimbotConn then
        RunService:UnbindFromRenderStep("SpermaHubAimbot")
        S.aimbotConn = nil
    end
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

-- ============ SILENT AIM — режимы Universal / Fortline / Network ============
-- код сервисов как в Fortline-сниппете (cloneref-защита), с фолбэком без cloneref
local function makeSilentServices()
    local cR = (type(cloneref) == "function") and cloneref or function(x) return x end
    return {
        ReplicatedStorage = cR(game:GetService("ReplicatedStorage")),
        Workspace = cR(game:GetService("Workspace")),
        Players = cR(game:GetService("Players")),
        RunService = cR(game:GetService("RunService")),
        UserInputService = cR(game:GetService("UserInputService")),
    }
end

-- FORTLINE STYLE: камера сама лочится на голову цели, пока зажата кнопка огня (ЛКМ/ПКМ).
-- Работает на executor без хуков (Xeno): пули летят по центру камеры.
local function enableSilentFortline()
    print("[SpermaHub] Silent Aim: режим Fortline (camera lock while firing)")
    notify("Silent Aim", "Режим Fortline: камера лочится пока зажат огонь", 3, "info")
    local svc = makeSilentServices()
    if S.silentAimConn then pcall(function() S.silentAimConn:Disconnect() end) S.silentAimConn = nil end
    S.silentAimConn = svc.RunService.RenderStepped:Connect(function()
        if not S.silentAimOn then return end
        local uis = svc.UserInputService
        local firing = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if not firing then return end
        local cam = svc.Workspace.CurrentCamera
        if not cam then return end
        local target = findSilentTarget()
        if not (target and target.Character) then return end
        local head = target.Character:FindFirstChild("Head")
            or target.Character:FindFirstChild("UpperTorso")
            or target.Character:FindFirstChild("Torso")
        if not head then return end
        cam.CFrame = CFrame.new(cam.CFrame.Position, head.Position)
    end)
end

-- NETWORK STYLE: перенаправление FireServer оружейных ремоутов на голову цели
-- (требует метатабличные хуки executor'а; на Xeno недоступно)
local function enableSilentNetwork()
    if not checkSilentAimSupport() then
        warn("[SpermaHub] Silent Aim Network: нет хуков на этом executor")
        notify("Silent Aim", "Network нуждается в hookfunction/getrawmetatable", 5, "alert-triangle")
        return
    end
    print("[SpermaHub] Silent Aim: режим Network (FireServer redirect)")
    emitnetok = nil
    local success, err = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = (pcall(getnamecallmethod) and getnamecallmethod()) or ""
            if S.silentAimOn and (method == "FireServer" or method == "InvokeServer")
                and typeof(self) == "Instance" then
                local rn = string.lower(tostring(self.Name))
                -- эвристика оружейного ремоута
                if rn:find("shoot") or rn:find("hit") or rn:find("damage") or rn:find("fire")
                    or rn:find("weapon") or rn:find("bullet") or rn:find("attack") or rn:find("gun") then
                    local target = findSilentTarget()
                    local head = target and target.Character and (
                        target.Character:FindFirstChild("Head")
                        or target.Character:FindFirstChild("UpperTorso")
                        or target.Character:FindFirstChild("Torso"))
                    if head then
                        local args = {...}
                        local changed = false
                        for i, a in ipairs(args) do
                            if typeof(a) == "Vector3" then
                                args[i] = head.Position changed = true
                            elseif typeof(a) == "CFrame" then
                                args[i] = CFrame.new(head.Position) changed = true
                            end
                        end
                        -- дахK: таблицы с полями Position/p/Hit/target тоже в голову
                        for i, a in ipairs(args) do
                            if typeof(a) == "table" then
                                local okT, key = pcall(function()
                                    local k = next(a)
                                    return k
                                end)
                                if okT and key then
                                    local copied = false
                                    local newT = {}
                                    for k, v in pairs(a) do
                                        if k == "Position" or k == "p" or k == "Hit"
                                            or k == "Target" or k == "target"
                                            or k == "aim" or k == "Aim" then
                                            if typeof(v) == "Vector3" then
                                                newT[k] = head.Position copied = true
                                            elseif typeof(v) == "CFrame" then
                                                newT[k] = CFrame.new(head.Position) copied = true
                                            else
                                                newT[k] = v
                                            end
                                        else
                                            newT[k] = v
                                        end
                                    end
                                    if copied then
                                        args[i] = newT changed = true
                                    end
                                end
                            end
                        end
                        if changed then
                            return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
        S.silentAimConn = {
            Disconnect = function()
                pcall(function()
                    setreadonly(mt, false)
                    mt.__namecall = oldNamecall
                    setreadonly(mt, true)
                end)
            end,
        }
    end)
    if not success then
        warn("[SpermaHub] Silent Aim Network ошибка: " .. tostring(err))
    end
end

local function enableSilentAim()
    S.silentAimOn = true
    if S.silentMode == "Fortline" then
        enableSilentFortline()
        return
    elseif S.silentMode == "Network" then
        enableSilentNetwork()
        return
    end
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

-- ============ FORTLINE SILENT: хук BaseWeapon.fire (по сырцам сайлента) ====
-- WeaponsSystem.Libraries.BaseWeapon — модуль оружейной системы Fortline.
-- fire(p1, p2, p3, p4): p2 = точка выстрела, p3 = направление (Unit).
-- Редиректим p3 -> направление в голову цели из конуса (S.flickHead).
function enableFortlineSilent()
    if S.flHookOn then return true end
    if type(hookfunction) ~= "function" then return false end
    local ok = pcall(function()
        local cR = (type(cloneref) == "function") and cloneref or function(x) return x end
        local RS = cR(game:GetService("ReplicatedStorage"))
        local ws = RS:FindFirstChild("WeaponsSystem")
        if not ws then error("WeaponsSystem not found") end
        local libs = ws:FindFirstChild("Libraries")
        if not libs then error("Libraries not found") end
        local bwMod = libs:FindFirstChild("BaseWeapon")
        if not bwMod then error("BaseWeapon not found") end
        local BaseWeapon = require(bwMod)
        if type(BaseWeapon) ~= "table" or type(BaseWeapon.fire) ~= "function" then
            error("BaseWeapon.fire not a function")
        end
        local oldFire
        oldFire = hookfunction(BaseWeapon.fire, function(p1, p2, p3, p4)
            if S.asOn and S.asSilentNet and S.flickHead then
                local okH, headPos = pcall(function() return S.flickHead.Position end)
                if okH and headPos and typeof(p2) == "Vector3" then
                    local okN, newDir = pcall(function() return (headPos - p2).Unit end)
                    if okN and newDir then p3 = newDir end
                end
            end
            return oldFire(p1, p2, p3, p4)
        end)
        S.flOldFire = oldFire
        S.flHookOn = true
    end)
    return ok and S.flHookOn
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
    dcc(S.hitboxConn)
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
    dcc(S.flyConn)
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
    dcc(S.noclipConn)
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
    dcc(S.clickTpConn)
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
    dcc(S.jesusConn)
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
    dcc(S.spinConn)
    S.spinAngle = 0
    -- стартовый угол берём ИЗ ТЕКУЩЕЙ позы — спин начинается без дёргания
    S.spinBaseYaw = 0
    do
        local ch0 = LP.Character
        local root0 = ch0 and ch0:FindFirstChild("HumanoidRootPart")
        if root0 then
            local _, yy = root0.CFrame:ToEulerAnglesYXZ()
            S.spinBaseYaw = math.deg(yy)
        end
    end
    S.spinConn = RunService.RenderStepped:Connect(function(dt)
        if not S.spinOn then return end
        local ch = LP.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        S.spinAngle = (S.spinAngle + S.spinSpeed * dt) % 360
        local totalYaw = math.rad(S.spinBaseYaw + S.spinAngle)
        if S.spinHeadDown then
            -- ГОЛОВА ВНИЗУ (вертолёт): питч -90° от ТЕКУЩЕЙ позиции root.
            -- Y НЕ ЗАНИЖАЕМ => пол не пробивается, гравитация не борется.
            -- PlatformStand гасит самовыпрямление humanoid, иначе оно
            -- каждый кадр крутит тело обратно вертикально.
            local hum = ch:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    if not hum.PlatformStand then hum.PlatformStand = true end
                end)
            end
            pcall(function()
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(math.rad(-90), totalYaw, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
        else
            -- обычный вертикальный спин (как был)
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, totalYaw, 0)
        end
    end)
end

local function disableSpin()
    S.spinOn = false
    if S.spinConn then S.spinConn:Disconnect() S.spinConn = nil end
    -- спина выпрямляется обратно
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = false end) end
end

-- ============ GOD MODE (лок HP) ============
local function enableGod()
    S.godOn = true
    dcc(S.godConn)
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

-- ============ FLING 2.0 (Stick TP — из твоего сниппета) ============
-- клей: каждый кадр персонаж привязан к цели с Velocity (0, 100000, 0);
-- по таймеру рвём и возвращаемся в исходную точку 50 раз подряд (как в коде).
local function flingStickyPlayer(target, dur)
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local tChar = target and target.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end
    if S.flingConn then pcall(function() S.flingConn:Disconnect() end) S.flingConn = nil end
    local ogpos = root.CFrame
    root.CFrame = tRoot.CFrame -- мгновенный прыжок на цель
    S.flingConn = RunService.RenderStepped:Connect(function()
        if not root.Parent or not tRoot.Parent then return end
        root.CFrame = tRoot.CFrame
        root.Velocity = Vector3.new(0, 100000, 0) -- твой импульс вверх
    end)
    task.delay(dur or 5, function()
        if S.flingConn then S.flingConn:Disconnect() S.flingConn = nil end
        local p = 0
        task.spawn(function()
            repeat
                if root.Parent then
                    root.Velocity = Vector3.new(0, 0, 0)
                    root.CFrame = ogpos
                    root.Velocity = Vector3.new(0, 0, 0)
                end
                task.wait()
                p = p + 1
            until p >= 50
        end)
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
    dcc(S.aaConn)
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

        -- КЛЮЧЕВОЕ против «AA не работает в шутерах»: отрубаем AutoRotate,
        -- иначе контроллер движения каждый кадр перезаписывает наш yaw
        if hum then
            pcall(function()
                if S.aaOrigAutoRotate == nil then
                    S.aaOrigAutoRotate = hum.AutoRotate
                end
                if hum.AutoRotate then hum.AutoRotate = false end
            end)
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

        -- ANTI-BACKSTAB: враг за спиной близко => моментально лицом к нему
        if S.aaAntiBS then
            local bsBest, bsD = nil, 10
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and not isTeammate(plr) then
                    local tch = plr.Character
                    local trt = tch and tch:FindFirstChild("HumanoidRootPart")
                    local thm = tch and tch:FindFirstChildOfClass("Humanoid")
                    if trt and thm and thm.Health > 0 then
                        local d = (trt.Position - root.Position).Magnitude
                        if d < bsD then
                            bsBest, bsD = trt, d
                        end
                    end
                end
            end
            if bsBest then
                local dir = bsBest.Position - root.Position
                -- он позади? (наш forward ~= -dir)
                local fwd = root.CFrame.LookVector
                local dot = (fwd.X * dir.X + fwd.Z * dir.Z) / math.max(dir.Magnitude, 0.001)
                if dot < -0.2 then
                    yaw = math.deg(math.atan2(-dir.X, -dir.Z)) -- лицом к нему
                end
            end
        end

        -- ON-SHOT (уровень бог): пока жмём огонь, yaw дико рандомится каждый тик
        local onShotNow = S.aaOnShot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        if onShotNow then
            yaw = (yaw or baseYaw) + math.random(-170, 170)
        end

        -- Yaw Jitter поверх выбранного yaw
        if yaw and S.aaYawJitter ~= "Disabled" then
            if S.aaYawJitter == "Offset" then
                -- ЖЁСТКИЙ TWITCH: спина -> разворот на 180 -> спина (каждый тик)
                S.aaJitSide = not S.aaJitSide
                yaw = yaw + (S.aaJitSide and 0 or 180)
            else -- Random
                yaw = yaw + math.random(-60, 60)
            end
        end

        local pitch = 0
        local rollUD = false -- Upside Down: вверх ногами, голова ВНИЗУ
        if S.aaPitch == "Down" then
            pitch = -90
        elseif S.aaPitch == "Up" then
            pitch = 90
        elseif S.aaPitch == "Jitter" then
            pitch = (math.random() < 0.5) and -90 or 90
        elseif S.aaPitch == "Head Down" then
            pitch = 0 -- рут не крутим: тело СТОИТ, движение обычное; гнётся отдельно ниже
        elseif S.aaPitch == "Upside Down" then
            pitch = 0
            rollUD = true
        end

        if yaw or pitch ~= 0 or rollUD then
            local pos
            if rollUD then
                -- вверх ногами БЕЗ БАГОВ: Y НЕ ТРОГАЕМ (капсула тем же дном на полу),
                -- просто крен рута на 180° + отключули автовыпрямление humanoid
                if hum and not hum.PlatformStand then
                    hum.PlatformStand = true
                end
                pos = root.Position
            elseif pitch ~= 0 then
                if hum and not hum.PlatformStand then
                    hum.PlatformStand = true -- отключить автовыпрямление: физика не борется с позой
                end
                -- БЕЗ ОДНОКРАТНОГО ПИНА: дроп считается КАЖДЫЙ ТИК от текущего root.Position.
                -- Тело ложится ровно на пол (центр капсулы = пол + ~1), не проваливается
                -- под землю и ездит лёжа вместе с движением. Никаких накоплений Y.
                local drop = 1.5
                if hum then
                    pcall(function()
                        drop = math.max(hum.HipHeight or 0, 0.5)
                    end)
                end
                pos = root.Position - Vector3.new(0, drop, 0)
            else
                -- Pitch = None: тело стоит; если откинуло вниз — физика сама поднимет,
                -- нам только выпрямиться и снять PlatformStand
                S.aaPinPos = nil
                if hum and hum.PlatformStand then hum.PlatformStand = false end
                pos = root.Position
            end
            root.CFrame = CFrame.new(pos)
                * CFrame.Angles(math.rad(pitch), math.rad(yaw or getCamYawDeg()), rollUD and math.pi or 0)
            if pitch ~= 0 or rollUD then
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        else
            S.aaPinPos = nil
            if hum and hum.PlatformStand then hum.PlatformStand = false end
        end

        -- СТОЯЧИЙ анти-аим "Head Down" = присед к ногам.
        -- Опускается ВСЯ стойка (HipHeight): тело остаётся вертикальным,
        -- голова для других ниже, ходишь как обычно, физика не ломается.
        if S.aaPitch == "Head Down" then
            if hum then
                pcall(function()
                    if S.aaHipOrig == nil then
                        S.aaHipOrig = hum.HipHeight
                    end
                    -- pcall обязательно, иначе молчаливый краш связи убивает ВЕСЬ анти-аим
                    hum.HipHeight = math.max(0, (S.aaHipOrig or 0) - (S.aaHeadDepth or 1))
                end)
            end
        elseif S.aaHipOrig ~= nil then
            if hum then
                pcall(function()
                    hum.HipHeight = S.aaHipOrig
                end)
            end
            S.aaHipOrig = nil
        end

        -- FAKE DUCK: быстрый присед-пульс (~0.35с вниз / ~0.45с вверх)
        if S.aaFakeDuck and hum and S.aaPitch ~= "Head Down" then
            S.fdT = (S.fdT or 0) + dt
            pcall(function()
                if S.fdOrig == nil then
                    S.fdOrig = hum.HipHeight
                end
                local phase = (S.fdT or 0) % 0.8
                if phase < 0.35 then
                    hum.HipHeight = 0 -- присел
                else
                    hum.HipHeight = (S.fdOrig or 0)
                end
            end)
        elseif S.fdOrig ~= nil then
            if hum then pcall(function() hum.HipHeight = S.fdOrig end) end
            S.fdOrig = nil
        end

        -- DESYNC-JITTER: позиция хитбокса дёргается на пара стадов туда-сюда
        -- каждый тик; ДЕЛАЕТСЯ КАК ДЕЛЬТА (новый - старый) => НЕ СЛЫШАТСЯ.
        if S.aaDesync then
            local mAmt = S.aaDesyncAmt
            if onShotNow then mAmt = mAmt * 2.5 end
            if S.aaResAA and hum and hum.Health > 0 and hum.MaxHealth > 0
                and hum.Health / hum.MaxHealth < 0.3 then
                mAmt = mAmt * 2
                -- RESSURECT-AA: редкие случайные мигания при низком HP
                if math.random() < 0.08 then
                    pcall(function()
                        root.CFrame = root.CFrame + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
                    end)
                end
            end
            local prev = S.aaDesyncPrev or Vector3.new(0, 0, 0)
            local nx = (math.random() * 2 - 1) * mAmt
            local nz = (math.random() * 2 - 1) * mAmt
            root.CFrame = root.CFrame + Vector3.new(nx - prev.X, 0, nz - prev.Z)
            S.aaDesyncPrev = Vector3.new(nx, 0, nz)
        else
            S.aaDesyncPrev = nil
        end

        -- FAKE LAG: часть тиков сервер видит тебя на ПРОШЛОЙ позиции
        -- (цикл 16 тиков: 12 в прошлом -> 4 догоняем) = враги видят "в двух местах"
        if S.aaFakeLag then
            S.flHistory = S.flHistory or {}
            table.insert(S.flHistory, 1, root.Position)
            if #S.flHistory > 24 then table.remove(S.flHistory) end
            S.flCycle = (S.flCycle or 0) + 1
            if S.flCycle % 16 < 12 then
                local old = S.flHistory[math.min(12, #S.flHistory)]
                if old then
                    pcall(function()
                        root.CFrame = CFrame.new(old) * (root.CFrame - root.CFrame.Position)
                    end)
                end
            end
        else
            S.flHistory = nil
            S.flCycle = 0
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
    -- вернуть AutoRotate (а то мышь перестанет крутить персонажа, как у людей)
    if hum and S.aaOrigAutoRotate ~= nil then
        pcall(function() hum.AutoRotate = S.aaOrigAutoRotate end)
        S.aaOrigAutoRotate = nil
    end
    -- вернуть скорость после Slow Walk
    if S.aaSlowWalk and hum then
        hum.WalkSpeed = S.walkSpeedOn and S.walkSpeed or 16
    end
    -- вернуть рост после Head Down
    if S.aaHipOrig ~= nil and hum then
        pcall(function()
            hum.HipHeight = S.aaHipOrig
        end)
        S.aaHipOrig = nil
    end
end

-- ============ BHOP (авто-прыжки) ============
local function enableBhop()
    S.bhopOn = true
    dcc(S.bhopConn)
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
    dcc(S.afConn)
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
    dcc(S.strafeConn)
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
    dcc(S.specConn)
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

-- ============ SMOOTH CAMERA (плавное движение камеры) ============
-- кастомный камера-контроллер: CameraType=Scriptable, yaw/pitch сглаживаются
-- экспоненциальным фильтром; камера орбитирует вокруг головы персонажа.
scYaw = 0 scPitch = 0 scTgtYaw = 0 scTgtPitch = 0

function enableSmoothCam()
    local cam = workspace.CurrentCamera
    if not cam then
        notify("Smooth Camera", "Нет камеры")
        return
    end
    S.scOn = true
    S.scPrevType = cam.CameraType
    cam.CameraType = Enum.CameraType.Scriptable
    -- стартовые углы из текущего вида камеры
    local x, y = cam.CFrame:ToEulerAnglesYXZ()
    scPitch = x
    scYaw = y
    scTgtPitch = x
    scTgtYaw = y
    dcc(S.scConn)
    S.scConn = RunService.RenderStepped:Connect(function(dt)
        if not S.scOn then return end
        local cam2 = workspace.CurrentCamera
        if not cam2 then return end
        -- цель вращения — по дельте мыши (без мгновенного скачка)
        local md = UIS:GetMouseDelta()
        local sens = 0.0035 * S.scSens
        scTgtYaw = scTgtYaw - md.X * sens
        scTgtPitch = math.clamp(scTgtPitch - md.Y * sens, -1.45, 1.45)
        -- сглаживание (экспоненциальный фильтр, не зависит от FPS)
        local k = 1 - math.exp(-dt * S.scSpeed)
        scYaw = scYaw + (scTgtYaw - scYaw) * k
        scPitch = scPitch + (scTgtPitch - scPitch) * k
        -- орбита вокруг головы
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if root then
            local headPos = root.Position + Vector3.new(0, 1.5, 0)
            local look = CFrame.Angles(0, scYaw, 0) * CFrame.Angles(scPitch, 0, 0)
            local camPos = headPos - look.LookVector * S.scDist
            cam2.CFrame = CFrame.new(camPos, headPos)
        end
    end)
end

function disableSmoothCam()
    S.scOn = false
    if S.scConn then S.scConn:Disconnect() S.scConn = nil end
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = S.scPrevType or Enum.CameraType.Custom
    end
end

-- ============ SPIDER (лазание по стенам) ============
spiderRayParams = RaycastParams.new()
spiderRayParams.FilterType = Enum.RaycastFilterType.Exclude

function enableSpider()
    S.spiderOn = true
    dcc(S.spiderConn)
    S.spiderConn = RunService.Heartbeat:Connect(function()
        if not S.spiderOn then return end
        local ch = LP.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if hum.MoveDirection.Magnitude < 0.1 then return end -- стоишь — не лезешь
        spiderRayParams.FilterDescendantsInstances = {ch}
        local hit = workspace:Raycast(root.Position, hum.MoveDirection.Unit * 3, spiderRayParams)
        if hit then
            -- перед нами стена: ставим вертикальную скорость подъёма
            root.Velocity = Vector3.new(root.Velocity.X, S.spiderSpeed, root.Velocity.Z)
        end
    end)
end

function disableSpider()
    S.spiderOn = false
    if S.spiderConn then S.spiderConn:Disconnect() S.spiderConn = nil end
end

-- ============ AIRSTACK (ходьба по воздуху на невидимой платформе) ============
function enableAirStack()
    S.airstackOn = true
    local ch = LP.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    -- высота платформы фиксируется в момент включения
    S.airstackY = root and (root.Position.Y - 3.2) or 60
    if not S.airstackPlatform or not S.airstackPlatform.Parent then
        local p = Instance.new("Part")
        p.Name = "SpermaAirStack"
        p.Anchored = true
        p.CanCollide = true
        p.Transparency = 1
        p.CastShadow = false
        p.Size = Vector3.new(12, 1, 12)
        p.Parent = workspace
        S.airstackPlatform = p
    end
    dcc(S.airstackConn)
    S.airstackConn = RunService.Heartbeat:Connect(function()
        if not S.airstackOn then return end
        local ch2 = LP.Character
        if not ch2 then return end
        local root2 = ch2:FindFirstChild("HumanoidRootPart")
        local plat = S.airstackPlatform
        if not root2 or not plat then return end
        -- платформа следует за игроком по X/Z на зафиксированной высоте
        plat.Position = Vector3.new(root2.Position.X,
            (S.airstackY or 60) - plat.Size.Y / 2 + 0.05,
            root2.Position.Z)
    end)
end

function disableAirStack()
    S.airstackOn = false
    if S.airstackConn then S.airstackConn:Disconnect() S.airstackConn = nil end
    if S.airstackPlatform and S.airstackPlatform.Parent then
        S.airstackPlatform.Position = Vector3.new(0, -1e5, 0) -- прячем платформу далеко вниз
    end
end

-- ============ AUTO SHOT (тригер-бот: не наводится, но попадает) ============
-- камера НЕ трогается: как только вражья голова попадает в конус у прицела —
-- сам жмёт ЛКМ (инжект) + активирует оружие. Снаряд летит по центру => хит.
function asTargetInCone()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local cx = cam.ViewportSize.X / 2
    local cy = cam.ViewportSize.Y / 2
    local best, bd = nil, S.asFovPx
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isTeammate(plr) then
            local ch2 = plr.Character
            local head = ch2 and ch2:FindFirstChild("Head")
            local hum = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 and isVisible(head) then
                local sp, on = cam:WorldToViewportPoint(head.Position)
                if on then
                    local dx = sp.X - cx
                    local dy = sp.Y - cy
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d < bd then
                        bd = d
                        best = head
                    end
                end
            end
        end
    end
    return best
end

-- оружие + клинок (фолбэки для кастомных мечей)
function asGetWeapon()
    local ch = LP.Character
    local tool = ch and ch:FindFirstChildOfClass("Tool")
    local handle = nil
    if tool then
        handle = tool:FindFirstChild("Handle")
        if not (handle and handle:IsA("BasePart")) then
            handle = tool:FindFirstChildWhichIsA("BasePart", true)
        end
    end
    return tool, handle
end

function enableAutoShot()
    S.asOn = true
    dcc(S.asConn)
    local acc = 0
    -- Stepped (до физики): сервер застаёт клинок во враге => попадание гарантировано,
    -- КАМЕРА НЕ ДВИЖЕТСЯ ВООБЩЕ
    S.asConn = RunService.Stepped:Connect(function(dt)
        if not S.asOn then return end
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local tool, handle = asGetWeapon()

        -- INSTANT FLICK обрабатывается рендер-биндом ПОСЛЕ камеры игры (см. ниже).
        -- Обходим Stepped ТОЛЬКО в пушечном режиме (когда Silent Hit и TP Kill ВЫКЛЮЧЕНЫ),
        -- чтобы мечи/TP Kill из Stepped не ломались
        if S.asFlick and not S.asSilentHit and not S.asTp then return end

        -- ЦЕЛЬ (без camera-turn):
        local targetModel, targetRoot = nil, nil
        if S.asSilentHit then
            -- silent hit: ближайший живой враг в радиусе удара (в TP-режиме — в радиусе TP Дальности)
            local bd = S.asTp and S.asTpRange or S.asRange
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and not isTeammate(plr) then
                    local tch = plr.Character
                    local thr = tch and tch:FindFirstChild("HumanoidRootPart")
                    local thum = tch and tch:FindFirstChildOfClass("Humanoid")
                    if thr and thum and thum.Health > 0 then
                        local d = (thr.Position - root.Position).Magnitude
                        if d < bd then
                            bd = d
                            targetModel = tch
                            targetRoot = thr
                        end
                    end
                end
            end
        else
            -- классический/фортлайн режим: цель в конусе прицела (сам огонь)
            local head = asTargetInCone()
            if head then
                targetModel = head.Parent
                targetRoot = head
                -- FORTLINE-асист: пушки стреляют ПО КАМЕРЕ, поэтому плавно
                -- подтягиваем камеру к голове (Assist=0 — камера не двигается)
                if S.asAssist and S.asAssist > 0 then
                    local camA = workspace.CurrentCamera
                    if camA then
                        camA.CFrame = camA.CFrame:Lerp(
                            CFrame.new(camA.CFrame.Position, head.Position),
                            S.asAssist)
                    end
                end
            end
        end
        if not targetModel then return end

        -- САЙЛЕНТ ХИТ (рабочий голяк без хуков):
        --  1) REACH: клинок раздуваем до куба Reach Size — Handle.Touched
        --     сервер регистрирует по всем врагам внутри куба;
        --  2) дубль: firetouchinterest по партам ближайшей цели (если executor даёт);
        --  3) НИЧТО не двигается: ни камера, ни персонаж, ни рука.
        if S.asSilentHit and handle then
            if not S.asOrigSize then
                S.asOrigSize = handle.Size
            end
            pcall(function()
                handle.CanCollide = false
                handle.Size = Vector3.new(S.asRange, S.asRange, S.asRange)
            end)
            if saHasTouch and targetModel then
                for _, part in ipairs(targetModel:GetChildren()) do
                    if part:IsA("BasePart") then
                        saTouch(handle, part)
                    end
                end
            end
        end

        -- TP KILL (старый стиль): телепорт за спину цели -> удар -> назад
        if S.asTp and targetRoot then
            local nowT = os.clock()
            local tpPeriod = math.max(0.22, 2 / math.max(S.asCps, 1))
            if S.asBackCF then
                -- возврат на исходную позицию
                pcall(function() root.CFrame = S.asBackCF end)
                S.asBackCF = nil
            elseif nowT - (S.asLastSwing or 0) >= tpPeriod then
                S.asLastSwing = nowT
                S.asBackCF = root.CFrame
                local behind = targetRoot.Position - targetRoot.CFrame.LookVector * S.asTpDist
                pcall(function()
                    root.CFrame = CFrame.lookAt(behind, targetRoot.Position)
                end)
                -- мгновенный удар с места атаки
                pcall(function()
                    if tool then tool:Activate() end
                end)
                if saHasTouch and handle then
                    for _, part in ipairs(targetModel:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            saTouch(handle, part)
                        end
                    end
                end
            end
        end

        -- авто-огонь по CPS
        acc = acc + dt
        if acc >= 1 / math.max(S.asCps, 1) then
            acc = 0
            kaClick()
            pcall(function()
                if tool then tool:Activate() end
            end)
        end
    end)

    -- УДЕРЖАНИЕ ЛКМ: Fortline стреляет пока кнопка ЗАЖАТА (как из сниппета silent aim),
    -- поэтому авто-шот сам зажимает ЛКМ, пока есть цель (tap-клики не работают)
    local function asHoldLMB()
        if S.flickHold then return end
        S.flickHold = true
        if type(mouse1press) == "function" then
            pcall(mouse1press)
            return
        end
        pcall(function()
            local cam2 = workspace.CurrentCamera
            if cam2 then
                local vx = math.floor(cam2.ViewportSize.X / 2)
                local vy = math.floor(cam2.ViewportSize.Y / 2)
                VIMService:SendMouseButtonEvent(vx, vy, 0, true, game, 1)
            end
        end)
    end
    local function asReleaseLMB()
        if not S.flickHold then return end
        S.flickHold = false
        if type(mouse1release) == "function" then
            pcall(mouse1release)
            return
        end
        pcall(function()
            local cam2 = workspace.CurrentCamera
            if cam2 then
                local vx = math.floor(cam2.ViewportSize.X / 2)
                local vy = math.floor(cam2.ViewportSize.Y / 2)
                VIMService:SendMouseButtonEvent(vx, vy, 0, false, game, 1)
            end
        end)
    end

    -- НОРМАЛЬНЫЙ САЙЛЕНТ (Network): если executor с хуками — собственно
    -- перенаправляем FireServer оружия В ГОЛОВУ цели. Камеру двигать НЕ НАДО,
    -- пули летят куда надо сами. Мы только держим ЛКМ пока цель в конусе.
    if S.asSilentNet then
        pcall(function()
            if checkSilentAimSupport() then
                -- Fortline: точный хук BaseWeapon.fire (там настоящая пушечная система),
                -- иначе — универсальный метатабличный редирект FireServer
                if not enableFortlineSilent() then
                    enableSilentNetwork()
                end
                S.asNetByAuto = true
                S.silentAimOn = true
            else
                S.asSilentNet = false
                notify("Auto Shot", "Silent Redirect: нет хуков на этом executor — выкл", 4, "alert-triangle")
            end
        end)
    end

    -- Рендер-бинд ПОСЛЕ игровой камеры: flick-снап (если включён) и
    -- автозажим ЛКМ, когда цель в конусе
    S.asFlickB = true
    RunService:BindToRenderStep("SpermaHubFlickStep", Enum.RenderPriority.Camera.Value + 1, function()
        if not S.asOn or S.asSilentHit or S.asTp then
            -- SilentHit/TP Kill — пусть работает Stepped-механика, бинд отдыхает
            S.flickHead = nil
            asReleaseLMB()
            return
        end
        if not S.asFlick and not S.asSilentNet then
            S.flickHead = nil
            asReleaseLMB()
            return
        end
        local camF = workspace.CurrentCamera
        if not camF then return end
        local head = asTargetInCone()
        S.flickHead = head
        if not head then
            S.asLastTarget = nil
            asReleaseLMB()
            return
        end
        -- автонаведение камеры на цель ПОКА СТРЕЛЯЕМ:
        --  flick → МГНОВЕННЫЙ снап; сайлент без flick → плавный трек (камера сама догоняет)
        if not S.asSilentNet and S.asFlick then
            local okS = pcall(function()
                camF.CFrame = CFrame.lookAt(camF.CFrame.Position, head.Position)
            end)
            if not okS then return end
        else
            pcall(function()
                camF.CFrame = camF.CFrame:Lerp(
                    CFrame.new(camF.CFrame.Position, head.Position), 0.55)
            end)
        end
        -- человеческий ритм: пауза-реакция на новую цель, дальше разброс интервалов
        local targetModelF = head.Parent
        local nowF = os.clock()
        if S.asLastTarget ~= targetModelF then
            S.asLastTarget = targetModelF
            S.asNextFire = nowF + (S.asReaction or 0.12) + math.random() * 0.08
        end
        -- TRIGGER FIRE (skeet): как только прицел РЕАЛЬНО на цели (<=30 px) — мгновенный выстрел
        if S.asTrigger then
            local spT, onT = camF:WorldToViewportPoint(head.Position)
            if onT then
                local cxT = camF.ViewportSize.X / 2
                local cyT = camF.ViewportSize.Y / 2
                local dpxT = math.sqrt((spT.X - cxT) ^ 2 + (spT.Y - cyT) ^ 2)
                if dpxT <= 30 then
                    local nowT = os.clock()
                    if nowT - (S.asLastTrig or 0)
                        >= (S.asTrigDelay or 0.08) + math.random() * 0.03 then
                        S.asLastTrig = nowT
                        kaClick()
                    end
                end
            end
        end
        if nowF >= (S.asNextFire or 0) then
            -- реакция вышла: жмём ЛКМ УДЕРЖИВАЕМО (автоматный огонь по темпу пушки)
            asHoldLMB()
            local toolF = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if toolF then
                pcall(function() toolF:Activate() end)
            end
            -- доп. тап: для полуавтоматик, где hold не канает
            kaClick()
            local base = 1 / math.max(S.asCps, 1)
            S.asNextFire = nowF + base * (0.8 + math.random() * 0.5)
        end
    end)
end

function disableAutoShot()
    if S.asFlickB then
        RunService:UnbindFromRenderStep("SpermaHubFlickStep")
        S.asFlickB = false
    end
    S.flickHead = nil
    -- если сайлент включали мы (Auto Shot) — аккуратно снять
    if S.asNetByAuto then
        S.asNetByAuto = false
        pcall(function()
            if S.silentAimOn and disableSilentAim then disableSilentAim() end
        end)
    end
    -- отпустить автозажатую ЛКМ
    if S.flickHold then
        S.flickHold = false
        if type(mouse1release) == "function" then
            pcall(mouse1release)
        else
            pcall(function()
                local cam2 = workspace.CurrentCamera
                if cam2 then
                    VIMService:SendMouseButtonEvent(
                        math.floor(cam2.ViewportSize.X / 2),
                        math.floor(cam2.ViewportSize.Y / 2),
                        0, false, game, 1)
                end
            end)
        end
    end
    S.asOn = false
    if S.asConn then S.asConn:Disconnect() S.asConn = nil end
    -- восстановить позицию, если отключили во время TP Kill
    if S.asBackCF then
        local ch0 = LP.Character
        local root0 = ch0 and ch0:FindFirstChild("HumanoidRootPart")
        if root0 then pcall(function() root0.CFrame = S.asBackCF end) end
        S.asBackCF = nil
    end
    -- вернуть размер клинка
    local ch2 = LP.Character
    local tool2 = ch2 and ch2:FindFirstChildOfClass("Tool")
    local handle2 = tool2 and (tool2:FindFirstChild("Handle") or tool2:FindFirstChildWhichIsA("BasePart", true))
    if handle2 and S.asOrigSize then
        pcall(function()
            handle2.Size = S.asOrigSize
        end)
    end
    S.asOrigSize = nil
    S.asWeld = nil
    S.asWeldParent = nil
end

-- ============ KILL AURA (закликивает врага) ============
VIMService = game:GetService("VirtualInputManager")

function kaNearestTarget()
    local ch = LP.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bd = nil, S.kaRange
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isTeammate(plr) then
            local tch = plr.Character
            local thr = tch and tch:FindFirstChild("HumanoidRootPart")
            local thum = tch and tch:FindFirstChildOfClass("Humanoid")
            if thr and thum and thum.Health > 0 then
                local d = (thr.Position - root.Position).Magnitude
                if d < bd then
                    bd = d
                    best = plr
                end
            end
        end
    end
    return best
end

function kaClick()
    -- инжект реального клика ЛКМ (как делает живой игрок)
    if type(mouse1press) == "function" then
        pcall(mouse1press)
        task.delay(0.03, function()
            pcall(function()
                if type(mouse1release) == "function" then mouse1release() end
            end)
        end)
        return
    end
    -- fallback: VirtualInputManager, клик СТРОГО В ЦЕНТР ЭКРАНА (не (0,0) — некоторые
    -- игры/меню ловят клики в углу и гасят стрельбу)
    local vx, vy = 0, 0
    pcall(function()
        local cam2 = workspace.CurrentCamera
        if cam2 then
            vx = math.floor(cam2.ViewportSize.X / 2)
            vy = math.floor(cam2.ViewportSize.Y / 2)
        end
    end)
    pcall(function()
        VIMService:SendMouseButtonEvent(vx, vy, 0, true, game, 1)
    end)
    task.delay(0.03, function()
        pcall(function()
            VIMService:SendMouseButtonEvent(vx, vy, 0, false, game, 1)
        end)
    end)
end

function enableKillAura()
    S.kaOn = true
    dcc(S.kaConn)
    local acc = 0
    S.kaConn = RunService.Heartbeat:Connect(function(dt)
        if not S.kaOn then return end
        acc = acc + dt
        if acc < 1 / math.max(S.kaCps, 1) then return end
        acc = 0
        local target = kaNearestTarget()
        if not target then
            S.kaTarget = nil
            return
        end
        S.kaTarget = target
        local root2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local thr2 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if root2 and thr2 and S.kaFace then
            -- поворачиваем персонажа к цели, чтобы свинг ловил хитбокс
            root2.CFrame = CFrame.new(root2.Position,
                Vector3.new(thr2.Position.X, root2.Position.Y, thr2.Position.Z))
        end
        kaClick() -- обычный инжект-клик
        pcall(function()
            local ch2 = LP.Character
            local tool = ch2 and ch2:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end -- классическая активация оружия
        end)
    end)
end

function disableKillAura()
    S.kaOn = false
    S.kaTarget = nil
    if S.kaConn then S.kaConn:Disconnect() S.kaConn = nil end
end

-- ============ SILENT AURA (1.8 Arena: клинок телепортируется во врага) ============
-- сорцы: универсальные sword silent aura (scriptblox/reddit). Сервер валидирует урон
-- по Handle.Touched => кладём сам Handle во врага каждый Stepped-тик (до физики),
-- сервер видит РЕАЛЬНОЕ касание. firetouchinterest используем как дублирующий лейер.
saHasTouch = (type(firetouchinterest) == "function")

function saTouch(handle, part)
    pcall(function()
        firetouchinterest(handle, part, 0)
    end)
    pcall(function()
        firetouchinterest(handle, part, 1)
    end)
end

function enableSilentAura()
    S.saOn = true
    dcc(S.saConn)
    if not saHasTouch then
        notify("Silent Aura", "firetouchinterest нет — работаем на телепорте клинка (основной режим)")
    end
    local acc = 0
    -- Stepped: тикаем ДО физики, чтобы сервер застал клинок во враге
    S.saConn = RunService.Stepped:Connect(function(dt)
        if not S.saOn then return end
        local ch = LP.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        local tool = ch:FindFirstChildOfClass("Tool")
        -- ручка клинка: Handle, либо первый BasePart внутри тулса (фолбэк)
        local handle = nil
        if tool then
            handle = tool:FindFirstChild("Handle")
            if not (handle and handle:IsA("BasePart")) then
                handle = tool:FindFirstChildWhichIsA("BasePart", true)
            end
        end
        if not root or not handle then
            S.saTarget = nil
            return
        end
        -- ближайший живой враг в досягаемости
        local targetModel, targetRoot, bd = nil, nil, S.saRange
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and not isTeammate(plr) then
                local tch = plr.Character
                local thr = tch and tch:FindFirstChild("HumanoidRootPart")
                local thum = tch and tch:FindFirstChildOfClass("Humanoid")
                if thr and thum and thum.Health > 0 then
                    local d = (thr.Position - root.Position).Magnitude
                    if d < bd then
                        bd = d
                        targetModel = tch
                        targetRoot = thr
                    end
                end
            end
        end
        S.saTarget = targetModel
        if not targetRoot then return end

        -- 1) REACH: клинок раздувается в куб Reach — Handle.Touched считается
        --    по всем врагам внутри. НИЧТО не телепортируется (ни рука, ни персонаж).
        if handle then
            if not S.saOrigSize then
                S.saOrigSize = handle.Size
            end
            pcall(function()
                handle.CanCollide = false
                handle.Size = Vector3.new(S.saRange, S.saRange, S.saRange)
            end)
        end

        -- 2) firetouchinterest (если executor даёт): дублируем касание по всем партам
        if saHasTouch then
            for _, part in ipairs(targetModel:GetChildren()) do
                if part:IsA("BasePart") then
                    saTouch(handle, part)
                end
            end
        end

        -- 3) свинг с задержкой: сервер должен видеть "атаку", Delay быстрее 0.25 = бан
        acc = acc + dt
        if acc >= S.saDelay then
            acc = 0
            pcall(function()
                tool:Activate()
            end)
        end
    end)
end

function disableSilentAura()
    S.saOn = false
    S.saTarget = nil
    if S.saConn then S.saConn:Disconnect() S.saConn = nil end
    -- вернуть размер клинка
    local ch3 = LP.Character
    local tool3 = ch3 and ch3:FindFirstChildOfClass("Tool")
    local handle3 = tool3 and (tool3:FindFirstChild("Handle") or tool3:FindFirstChildWhichIsA("BasePart", true))
    if handle3 and S.saOrigSize then
        pcall(function()
            handle3.Size = S.saOrigSize
        end)
    end
    S.saOrigSize = nil
end

-- ============ NO KNOCKBACK (удар не отталкивает) ============
noKbZero = Vector3.new(0, 0, 0)

function enableNoKb()
    S.noKbOn = true
    dcc(S.noKbConn)
    S.noKbConn = RunService.Heartbeat:Connect(function()
        if not S.noKbOn then return end
        local ch = LP.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if S.flying then S.noKbLast = nil return end -- во время флая свою скорость не трогаем
        local vel = root.Velocity
        -- горизонтальная скорость выше порога = нас ударило/толкнуло
        if (vel - Vector3.new(0, vel.Y, 0)).Magnitude > S.noKbMax then
            -- возвращаем доударные X/Z (движение как ни в чём не бывало)
            local lv = S.noKbLast or noKbZero
            local keepY = vel.Y
            if S.noKbFull then keepY = 0 end -- 1.8-режим: обнуляем и подскок вверх от удара
            root.Velocity = Vector3.new(lv.X, keepY, lv.Z)
        else
            -- обычная скорость (ходьба/бег) — запоминаем как эталон
            S.noKbLast = Vector3.new(vel.X, 0, vel.Z)
        end
    end)
end

function disableNoKb()
    S.noKbOn = false
    if S.noKbConn then S.noKbConn:Disconnect() S.noKbConn = nil end
    S.noKbLast = nil
end

-- ============ INVISIBLE (оффсет персонажа под карту) ============
function setInvisible(state)
    S.invisOn = state
    if state then
        dcc(S.invisConn)
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        S.invisY = root and root.Position.Y or 60
        S.invisConn = RunService.Heartbeat:Connect(function()
            if not S.invisOn then return end
            local ch2 = LP.Character
            if not ch2 then return end
            local root2 = ch2:FindFirstChild("HumanoidRootPart")
            local hum2 = ch2:FindFirstChildOfClass("Humanoid")
            if root2 and hum2 then
                -- персонаж физически провален под карту: другие его не видят, а падения нет (Y зафиксирован)
                local p = root2.Position
                root2.Velocity = Vector3.new(0, 0, 0)
                root2.CFrame = CFrame.new(p.X, (S.invisY or p.Y) - S.invisOffset, p.Z)
                -- камеру держим на нормальной высоте — ты видишь всё как обычно
                hum2.CameraOffset = Vector3.new(0, S.invisOffset, 0)
            end
        end)
    else
        if S.invisConn then S.invisConn:Disconnect() S.invisConn = nil end
        local ch = LP.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
        if root then
            local p = root.Position
            root.CFrame = CFrame.new(p.X, (S.invisY or p.Y), p.Z) -- возврат наверх
            root.Velocity = Vector3.new(0, 0, 0)
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
    dcc(S.espConn)
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
    dcc(S.targetEspConn)
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

-- ============ WATERMARK (пилюля fatality: 🐱 ник [тег] | fps | ms | kbps) ============
local WG = Instance.new("ScreenGui")
WG.Name = "SpermaHubWatermark"
WG.ResetOnSpawn = false
WG.IgnoreGuiInset = true
WG.DisplayOrder = 100
WG.Parent = LP:WaitForChild("PlayerGui")

local WM = Instance.new("Frame")
WM.Size = UDim2.new(0, 0, 0, 26)
WM.AutomaticSize = Enum.AutomaticSize.X
WM.Position = UDim2.new(0, 12, 0, 12)
WM.BackgroundColor3 = Color3.fromRGB(14, 13, 20)
WM.BackgroundTransparency = 0.08
WM.BorderSizePixel = 0
WM.Active = true
WM.Draggable = true
WM.Parent = WG

local WMC = Instance.new("UICorner")
WMC.CornerRadius = UDim.new(0.5, 0)
WMC.Parent = WM

local WMS = Instance.new("UIStroke")
WMS.Color = Color3.fromRGB(120, 90, 170)
WMS.Thickness = 1
WMS.Transparency = 0.45
WMS.Parent = WM

local WMP = Instance.new("UIPadding")
WMP.PaddingLeft = UDim.new(0, 10)
WMP.PaddingRight = UDim.new(0, 10)
WMP.Parent = WM

local WML = Instance.new("UIListLayout")
WML.FillDirection = Enum.FillDirection.Horizontal
WML.HorizontalAlignment = Enum.HorizontalAlignment.Center
WML.VerticalAlignment = Enum.VerticalAlignment.Center
WML.SortOrder = Enum.SortOrder.LayoutOrder
WML.Padding = UDim.new(0, 5)
WML.Parent = WM

local WM_PINK   = Color3.fromRGB(255, 76, 152)
local WM_VIOLET = Color3.fromRGB(160, 152, 200)
local WM_GREY   = Color3.fromRGB(152, 150, 170)
local WM_DIM    = Color3.fromRGB(90, 87, 106)

local wmOrder = 0
local function wmSeg(txt, color, font, size)
    wmOrder = wmOrder + 1
    local l = Instance.new("TextLabel")
    l.AutomaticSize = Enum.AutomaticSize.X
    l.Size = UDim2.new(0, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = color
    l.Font = font
    l.TextSize = size
    l.LayoutOrder = wmOrder
    l.Parent = WM
    return l
end

wmSeg("🐱", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 12)
local NameLabel = wmSeg(LP.DisplayName or LP.Name, WM_PINK, Enum.Font.GothamBold, 13)
local TagLabel = wmSeg("[Разработчик]", WM_VIOLET, Enum.Font.GothamMedium, 12)
wmSeg("|", WM_DIM, Enum.Font.Gotham, 12)
local FpsLabel = wmSeg("--fps", WM_PINK, Enum.Font.GothamBold, 13)
wmSeg("|", WM_DIM, Enum.Font.Gotham, 12)
local PingLabel = wmSeg("--ms", WM_GREY, Enum.Font.GothamBold, 12)
wmSeg("|", WM_DIM, Enum.Font.Gotham, 12)
local BpsLabel = wmSeg("0.00kbps", WM_GREY, Enum.Font.GothamMedium, 12)

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
            local kb = 0
            pcall(function()
                local serverStats = Stats.Network.ServerStatsItem
                if serverStats and serverStats["Data Receive Kbps"] then
                    kb = serverStats["Data Receive Kbps"]:GetValue()
                end
            end)
            FpsLabel.Text = string.format("%dfps", S.fps or 0)
            PingLabel.Text = string.format("%dms", p)
            BpsLabel.Text = string.format("%.2fkbps", kb or 0)
        end
        task.wait(0.5)
    end
end)

bootStep("Watermark OK")

-- ============================================================
-- ================== GAMESENSE LIBRARY ======================
-- ============================================================
if Library and Library.Unload then
    Library:Unload()
end
do -- Folders
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("gamesense") then
        makefolder("gamesense")
    end
    --
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("gamesense/Configs") then
        makefolder("gamesense/Configs")
    end
end
--
do -- Library
    --
    local Workspace = game:GetService("Workspace")
    local HttpService = game:GetService("HttpService")
    local Debris = game:GetService("Debris")
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local TeleportService = game:GetService("TeleportService")
    local Lighting = game:GetService("Lighting")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Stats = game:GetService("Stats")
    local GuiService = game:GetService("GuiService")
    --
    local Client = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
    local Viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
    --
    getgenv().Library = {
        Connections = {},
        Errors = {},
        Tweens = {},
        Objects = {},
        Sections = {},
        ThemeSections = {},
        Flags = {},
        UnnamedFlags = 0,
        Build = "Beta",
        UID = "1",
        UnsafeMode = false,
        InitTime = os.clock(),
        Folder = "gamesense",
        ConfigFolder = "gamesense/Configs",
        UI = {
            Name = "gamesense",
            CloseBind = Enum.KeyCode.Insert,
            SectionResizeIncrements = 1,
            WatermarkRefreshRate = 1,
            MainUI = nil,
            Initialized = false,
            Faded = false,
            LastCopiedColor = nil,
            TabIndex = 0,
            Viewing = false,
            CurrentSelectedColorPicker = nil,
            CurrentSelectedColorPickerExtra = nil,
            CurrentSelectedKeybindMode = nil,
            TotalColorPickers = 0,
            TotalKeybindModes = 0,
            WatermarkPosition = "Top Right",
            SectionZIndex = 100,
            Resizing = false,
            DropdownZIndex = 1,
            OpenColorFrames = 0,
            ScreenGUI = nil,
            TweenSpeed = 0.15,
            NewFont = (function() local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal) end) return (ok and f) or Enum.Font.SourceSans end)(),
            FontSize = 13,
            DraggingGui = nil,
            Notifications = {TopLeft = {}, Middle = {}},
            Keys = {
                [Enum.KeyCode.LeftShift] = "LSHF",
                [Enum.KeyCode.RightShift] = "RSHF",
                [Enum.KeyCode.LeftControl] = "LCTR",
                [Enum.KeyCode.RightControl] = "RCTR",
                [Enum.KeyCode.LeftAlt] = "LALT",
                [Enum.KeyCode.RightAlt] = "RALT",
                [Enum.KeyCode.CapsLock] = "CAPS",
                [Enum.KeyCode.Space] = "SPCE",
                [Enum.KeyCode.One] = "ONE",
                [Enum.KeyCode.Two] = "TWO",
                [Enum.KeyCode.Three] = "THREE",
                [Enum.KeyCode.Four] = "FOUR",
                [Enum.KeyCode.Five] = "FIVE",
                [Enum.KeyCode.Six] = "SIX",
                [Enum.KeyCode.Seven] = "SEVEN",
                [Enum.KeyCode.Eight] = "EIGHT",
                [Enum.KeyCode.Nine] = "NINE",
                [Enum.KeyCode.Zero] = "ZERO",
                [Enum.KeyCode.KeypadOne] = "NUM1",
                [Enum.KeyCode.KeypadTwo] = "NUM2",
                [Enum.KeyCode.KeypadThree] = "NUM3",
                [Enum.KeyCode.KeypadFour] = "NUM4",
                [Enum.KeyCode.KeypadFive] = "NUM5",
                [Enum.KeyCode.KeypadSix] = "NUM6",
                [Enum.KeyCode.KeypadSeven] = "NUM7",
                [Enum.KeyCode.KeypadEight] = "NUM8",
                [Enum.KeyCode.KeypadNine] = "NUM9",
                [Enum.KeyCode.KeypadZero] = "NUM0",
                [Enum.KeyCode.Insert] = "INS",
                [Enum.KeyCode.Minus] = "-",
                [Enum.KeyCode.Equals] = "=",
                [Enum.KeyCode.Tilde] = "~",
                [Enum.KeyCode.LeftBracket] = "[",
                [Enum.KeyCode.RightBracket] = "]",
                [Enum.KeyCode.RightParenthesis] = ")",
                [Enum.KeyCode.LeftParenthesis] = "(",
                [Enum.KeyCode.Semicolon] = ",",
                [Enum.KeyCode.Quote] = "'",
                [Enum.KeyCode.BackSlash] = "\\",
                [Enum.KeyCode.Comma] = ",",
                [Enum.KeyCode.Period] = ".",
                [Enum.KeyCode.Slash] = "/",
                [Enum.KeyCode.Asterisk] = "*",
                [Enum.KeyCode.Plus] = "+",
                [Enum.KeyCode.Period] = ".",
                [Enum.KeyCode.Backquote] = "`",
                [Enum.UserInputType.MouseButton1] = "M1",
                [Enum.UserInputType.MouseButton2] = "M2",
                [Enum.UserInputType.MouseButton3] = "M3"
            },
        },
        Theme = {
            Objects = {},
            Default = {
                Accent = Color3.fromRGB(153, 196, 39),
                SecondAccent = Color3.fromRGB(124, 158, 32),
                TextColor = Color3.fromRGB(205, 205, 205),
                Risky = Color3.fromRGB(165, 165, 120),
            }
        }
    }
    --
    function Library:Validate(Defaults, Options)
        for Index, Value in Defaults do
            if Options[Index] == nil then
                Options[Index] = Value
            end
        end
        --
        return Options
    end
    --
    function Library:Connection(Signal, Func, Name, Table)
        Name = Name or "Unknown"
        Table = Table or Library.Connections
        --
        local Connection; Connection = Signal:Connect(function(...)
            local Args = {...}
            --
            local Success, Message = pcall(function() coroutine.wrap(Func)(unpack(Args)) end)
            --
            if not Success and not Library.Errors[Message] then
                if Library.Notify then
                    Library:Notify({Message = ("[ERROR] | An error has occurred:\n%s\nName: %s"):format(Message, Name), Delay = math.huge})
                else
                    warn(("[ERROR] | An error has occurred:\n%s\nName: %s"):format(Message, Name))
                end
                --
                Library.Errors[Message] = Message
                --
                if Table[Connection] then
                    Table[Connection] = nil
                end
                --
                return Connection and Connection:Disconnect()
            end
        end)
        --
        if Connection and Table then
            table.insert(Table, Connection)
        end
        --
        return Connection
    end
    --
    function Library:TweenObject(Object, Info, Goal, Callback)
        if not Object then return end
        --
        local Tween = TweenService:Create(Object, Info, Goal)
        --
        Library:Connection(Tween.Completed, Callback or function() end)
        --
        Tween:Play()
        --
        Library.Tweens[#Library.Tweens + 1] = Tween
    end
    --
    function Library:NewFlag()
        Library.UnnamedFlags += 1
        --
        return ("UnknownFlag%s"):format(tostring(Library.UnnamedFlags))
    end
    --
    function Library:ClampString(String, MaxWidth)
        local Clamped = String
        --
        local TextLabel = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextStrokeTransparency = 0,
            Text = String,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextScaled = false,
            TextWrapped = false,
            Visible = false,
            TextSize = Library.UI.FontSize,
            Parent = Client.PlayerGui
        })
        --
        if TextLabel.TextBounds.X <= MaxWidth then
            TextLabel:Destroy()
            --
            return String
        end
        --
        while TextLabel.TextBounds.X > MaxWidth and #Clamped > 0 do
            Clamped = Clamped:sub(1, #Clamped - 1)
            --
            TextLabel.Text = Clamped .. "..."
            --
            task.wait()
        end
        --
        TextLabel:Destroy()
        --
        return Clamped .. "..."
    end
    --
    function Library:GetConfig()
        local Config = {}
        --
        for Index, Value in Library.Flags do
            if Value.Get and not string.find(Index, "_Status") then
                if typeof(Value:Get()) == "table" and Value:Get().Color and Value:Get().Transparency then
                    local Transparency = Value:Get().Transparency
                    local Hue, Saturation, Value = Value:Get().Color:ToHSV()
                    --
                    Config[Index] = {Hue, Saturation, Value, Transparency}
                else
                    Config[Index] = Value:Get()
                end
            end
        end
        --
        return HttpService:JSONEncode(Config)
    end
    --
    function Library:LoadConfig(Config)
        local Config = HttpService:JSONDecode(Config)
        --
        for Index, Value in Config do
            if Library.Flags[Index] and Library.Flags[Index].Set then
                Library.Flags[Index]:Set(Value)
            end
        end
    end
    --
    function Library:SectionDragging(Frame)
        local MousePosition = UserInputService:GetMouseLocation()
        local Position = Frame.AbsolutePosition
        local Size = Frame.AbsoluteSize
        --
        local InsideX = MousePosition.X >= Position.X and MousePosition.X <= Position.X + Size.X
        local InsideY = MousePosition.Y >= Position.Y and MousePosition.Y <= Position.Y + Size.Y
        --
        return InsideX and InsideY
    end
    --
    function Library:CreateObject(Type, Properties, Hidden)
        local Hidden = Hidden or false
        local Object = Instance.new(Type)
        --
        for Index, Value in Properties do
            if (not RunService:IsStudio()) and Index == "Name" and not string.match(Value, "%d") then
                Value = "\0"
            end
            --
            if Index == "TextStrokeTransparency" and Value == 0 then
                local Stroke = Instance.new("UIStroke")
                --
                Stroke.Parent = Object
                Stroke.LineJoinMode = Enum.LineJoinMode.Miter
                --
                Library.Objects[Stroke] = {Stroke, {Parent = Object, LineJoinMode = Enum.LineJoinMode.Miter}, Hidden}
            else
                Object[Index] = Value
            end
        end
        --
        Library.Objects[Object] = {Object, Properties, Hidden}
        --
        return Object
    end
    --
    function Library:AddTheme(Object, Properties)
        for Index, Value in Properties do
            Library.Theme.Objects[Object] = Library.Theme.Objects[Object] or {}
            Library.Theme.Objects[Object][Index] = Value
        end
    end
    --
    function Library:GetTableIndexes(Table, Custom)
        local Table2 = {}
        --
        for Index, Value in Table do
            Table2[Custom and Value[1] or #Table2 + 1] = Index 
        end
        --
        return Table2
    end
    --
    function Library:UpdateConfigList(List, Type)
        for _, File in listfiles("gamesense/Configs") do
            local FileName = File:gsub("\\", "/"):gsub("gamesense/Configs/", ""):gsub(".cfg", "")
            --
            if Type == "Remove" then
                List:RemoveValue(FileName)
            else
                List:AddValue(FileName)
            end
        end
    end
    --
    function Library:GetObjectsTable(MainUI, AddMain, Ignored)
        local AddMain = AddMain or false
        local Ignored = Ignored or {}
        local DescendantTable = {}
        local NewTable = {}
        --
        for _, Descendant in MainUI:GetDescendants() do
            if table.find(Ignored, Descendant) then continue end
            --
            DescendantTable[#DescendantTable + 1] = Descendant
        end
        --
        if AddMain then
            DescendantTable[#DescendantTable + 1] = MainUI
        end
        --
        for _, Descendant in DescendantTable do
            local Found = Library.Objects[Descendant]
            --
            if Found then
                local Properties = Found[2]
                local HiddenValue = Found[3]
                --
                NewTable[#NewTable + 1] = {Descendant, Properties, HiddenValue}
            end
        end
        --
        return NewTable
    end
    --
    function Library:SetTableVisible(Table, State, Ignored)
        local Ignored = Ignored or {}
        --
        for _, Object in Table do
            if table.find(Ignored, Object) then continue end
            --
            if typeof(Object) == "table" and Object.SetVisible then 
                Object:SetVisible(State)
            end
        end
    end
    --
    function Library:UpdateColor(ColorType, ColorValue)
        Library.Theme.Default[ColorType] = ColorValue
        --
        for Object, Properties in Library.Theme.Objects do
            for Property, ThemeKeys in Properties do
                if typeof(ThemeKeys) == "table" then
                    if Object:IsA("UIGradient") and Property == "Color" then
                        if Library.Theme.Default[ThemeKeys[1]] then
                            Object.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Library.Theme.Default[ThemeKeys[1]]), ColorSequenceKeypoint.new(1, Library.Theme.Default[ThemeKeys[2]])}
                        end
                    end
                else
                    if ThemeKeys == ColorType then
                        Object[Property] = Library.Theme.Default[ThemeKeys]
                    end
                end
            end
        end
    end
    --
    function Library:ViewPlayer(Player)
        if not Library.UI.Viewing then
            Camera.CameraSubject = Player.Character.Humanoid
        else
            Camera.CameraSubject = Client.Character.Humanoid
        end
        --
        Library.UI.Viewing = not Library.UI.Viewing
    end
    --
    function Library:GetTableLength(Table)
        local Length = 0
        --
        for Index, Value in pairs(Table) do
            Length += 1
        end
        --
        return Length
    end
    --
    function Library:ScrollingCheck(ScrollingFrame, Frame)
        if not ScrollingFrame:IsA("ScrollingFrame") then return true end
        --
        local VisibleTopLeft = ScrollingFrame.CanvasPosition
        local VisibleBottomRight = VisibleTopLeft + ScrollingFrame.AbsoluteWindowSize
        --
        local FrameTopLeft = Frame.AbsolutePosition - ScrollingFrame.AbsolutePosition + ScrollingFrame.CanvasPosition
        local FrameBottomRight = FrameTopLeft + Frame.AbsoluteSize
        --
        return FrameBottomRight.X > VisibleTopLeft.X and FrameTopLeft.X < VisibleBottomRight.X and FrameBottomRight.Y > VisibleTopLeft.Y and FrameTopLeft.Y < VisibleBottomRight.Y
    end
    --
    function Library:ClampPosition(Object, Position, Offset)
        local ClampedX = math.clamp(Position.X.Offset, Offset, Viewport.X - Object.AbsoluteSize.X - Offset)
        local ClampedY = math.clamp(Position.Y.Offset, Offset, Viewport.Y - Object.AbsoluteSize.Y - Offset)
        --
        return UDim2.new(Position.X.Scale, ClampedX, Position.Y.Scale, ClampedY)
    end
    --
    function Library:Fade(State, Table, MainUI, Speed)
        local IsMainUI = Table == Library.Objects
        --
        MainUI.Active = State
        --
        if State then
            MainUI.Visible = true
        end
        --
        if IsMainUI then
            Library.UI.Faded = not State
        end
        --  handle toggle transparency when fading out since im not using fade out for now as it causes fps issues
        if not State and IsMainUI then
            -- find all toggle elements and force them transparent immediately instead of waiting since some things may not leave instantly
            for _, obj in pairs(MainUI:GetDescendants()) do
                if obj.ClassName == "Frame" then
                    if obj.Name == "ToggleMain" then
                        obj.BackgroundTransparency = 1
                    end
                end
            end
        end
        --
        for _, Object in Table do
            if not Object[3] then
                if Object[1].ClassName == "Frame" and (Object[2]["BackgroundTransparency"] or 0) ~= 1 then
                    -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1})
                    Object[1].BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1
                elseif Object[1].ClassName == "ImageLabel" or Object[1].ClassName == "ImageButton" then
                    if (Object[2]["BackgroundTransparency"] or 0) ~= 1 then
                        -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1})
                        Object[1].BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1
                    end
                    --
                    if (Object[2]["ImageTransparency"] or 0) ~= 1 then
                        -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {ImageTransparency = State and (Object[2]["ImageTransparency"] or 0) or 1})
                        Object[1].ImageTransparency = State and (Object[2]["ImageTransparency"] or 0) or 1
                    end
                elseif Object[1].ClassName == "TextLabel" or Object[1].ClassName == "TextButton" or Object[1].ClassName == "TextBox" then
                    if (Object[2]["BackgroundTransparency"] or 0) ~= 1 then
                        -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1})
                        Object[1].BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1
                    end
                    --
                    if (Object[2]["TextTransparency"] or 0) ~= 1 then
                        -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {TextTransparency = State and (Object[2]["TextTransparency"] or 0) or 1})
                        Object[1].TextTransparency = State and (Object[2]["TextTransparency"] or 0) or 1
                    end
                elseif Object[1].ClassName == "ScrollingFrame" then
                    if (Object[2]["BackgroundTransparency"] or 0) ~= 1 then
                        -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1})
                        Object[1].BackgroundTransparency = State and (Object[2]["BackgroundTransparency"] or 0) or 1
                    end
                    --
                    if (Object[2]["ScrollBarImageTransparency"] or 0) ~= 1 then
                        -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {ScrollBarImageTransparency = State and (Object[2]["ScrollBarImageTransparency"] or 0) or 1})
                        Object[1].ScrollBarImageTransparency = State and (Object[2]["ScrollBarImageTransparency"] or 0) or 1
                    end
                elseif Object[1].ClassName == "UIStroke" then
                    -- Library:TweenObject(Object[1], TweenInfo.new(Speed, Enum.EasingStyle.Linear, State and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {Transparency = State and (Object[2]["Transparency"] or 0) or 1})
                    Object[1].Transparency = State and (Object[2]["Transparency"] or 0) or 1
                end
            end
        end
        --
        if not State then
            task.delay(Speed, function()
                if not MainUI.Parent then return end
                MainUI.Visible = false
            end)
        end
    end
    --
    function Library:CheckFrameFirst(FrameA, FrameB)
        local Parent = FrameA.Parent
        local Frames = {}
        local IndexA, IndexB
        --
        for _, Child in Parent:GetChildren() do
            if Child:IsA("Frame") then
                table.insert(Frames, Child)
            end
        end
        --
        table.sort(Frames, function(a, b)
            if a.LayoutOrder == b.LayoutOrder then
                for _, Child in Parent:GetChildren() do
                    if Child == a then return true end
                    if Child == b then return false end
                end
            end
            --
            return a.LayoutOrder < b.LayoutOrder
        end)
        --
        for i, Frame in Frames do
            if Frame == FrameA then IndexA = i end
            if Frame == FrameB then IndexB = i end
        end
        --
        return IndexA and IndexB and IndexA < IndexB
    end
    --
    function Library:Resizable(Object, DragFrame, MinResize, MaxResize, Increments, UseIcon, UseParent, Delay)
        local StartingSize, ObjectSize, Dragging, MouseLocation, PerformanceDragUI, NewMouse, Hovering
        --
        local function UpdateSize()
            if not MouseLocation then return end
            --
            Library.UI.Resizing = true
            --
            local CurrentMousePosition = UserInputService:GetMouseLocation()
            local Delta = CurrentMousePosition - MouseLocation
            local NewSizeX = StartingSize.X.Offset + Delta.X
            local NewSizeY = StartingSize.Y.Offset + Delta.Y
            local Parent = Object.Parent
            local ParentSize = Parent.AbsoluteSize
            --
            if UseParent then
                local OccupiedSpaceY = 0
                local FrameCount = 0
                --
                for _, Child in Parent:GetChildren() do
                    if Child:IsA("Frame") and Child ~= Object then
                        FrameCount += 1
                        --
                        if Library:CheckFrameFirst(Object, Child) then
                            if Child.AbsoluteSize.Y >= (ParentSize.Y - Object.AbsoluteSize.Y) - 57 then
                                Child.Size = UDim2.new(Child.Size.X.Scale, Child.Size.X.Offset, 0, math.max(50, (ParentSize.Y - Object.AbsoluteSize.Y) - 57))
                            end
                        else
                            OccupiedSpaceY += Child.AbsoluteSize.Y + 19
                        end
                    end
                end
                --
                if OccupiedSpaceY == 0 then
                    MaxResize = UDim2.new(0, 0, 0, (ParentSize.Y - OccupiedSpaceY) - (FrameCount * (50 + 19)) - 38)
                else
                    MaxResize = UDim2.new(0, 0, 0, (ParentSize.Y - OccupiedSpaceY) - 38)
                end
            end
            --
            if Increments then
                NewSizeY = math.clamp(math.round(NewSizeY / Increments) * Increments, MinResize.Y.Offset, MaxResize.Y.Offset)
            else
                NewSizeY = math.clamp(NewSizeY, MinResize.Y.Offset, MaxResize.Y.Offset)
                NewSizeX = math.clamp(NewSizeX, MinResize.X.Offset, MaxResize.X.Offset)
            end
            --
            return UseParent and UDim2.new(1, 0, 0, NewSizeY) or UDim2.new(0, NewSizeX, 0, NewSizeY)
        end
        
        --
        Library:Connection(DragFrame.MouseEnter, function()
            Hovering = true
        end)
        --
        Library:Connection(DragFrame.MouseLeave, function()
            if NewMouse then NewMouse:Destroy() NewMouse = nil end
            --
            UserInputService.MouseIconEnabled = true
            Hovering = false
        end)
        --
        Library:Connection(DragFrame.InputBegan, function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Dragging = true
                MouseLocation = UserInputService:GetMouseLocation()
                StartingSize = Object.Size
            end
        end)
        --
        Library:Connection(RunService.PreRender, function()
            if (Hovering or Dragging) and UseIcon then
                local MousePosition = UserInputService:GetMouseLocation()
                --
                UserInputService.MouseIconEnabled = false
                --
                if not NewMouse then
                    NewMouse = Library:CreateObject("ImageLabel", {
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Image = "rbxassetid://87982048533100",
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Name = "Transparency",
                        Size = UDim2.new(0, 35, 0, 35),
                        ZIndex = 10000,
                        BorderSizePixel = 0,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        Parent = Library.UI.ScreenGUI
                    }, true)
                end
                --
                NewMouse.Position = UDim2.new(0, MousePosition.X, 0, MousePosition.Y)
            end
            --
            if Dragging then
                if Delay then task.delay(Delay, function()
                        Object.Size = UpdateSize()
                    end)
                else
                    Object.Size = UpdateSize()
                end
            end
        end)
        --
        Library:Connection(UserInputService.InputEnded, function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and Dragging then
                if NewMouse then NewMouse:Destroy() NewMouse = nil end
                --
                if UseParent then
                    for _, Child in Object.Parent:GetChildren() do
                        if Child:IsA("Frame") and Child ~= Object then
                            if Library:CheckFrameFirst(Object, Child) then
                                if Child.AbsoluteSize.Y >= (Object.Parent.AbsoluteSize.Y - Object.AbsoluteSize.Y) - 57 then
                                    Child.Size = UDim2.new(Child.Size.X.Scale, Child.Size.X.Offset, 0, math.max(50, (Object.Parent.AbsoluteSize.Y - Object.AbsoluteSize.Y) - 57))
                                end
                            end
                        end
                    end
                end
                --
                UserInputService.MouseIconEnabled = true
                Dragging = false
                Library.UI.Resizing = false
            end
        end)
    end
    --
    Library.__index = Library
    Library.Sections.__index = Library.Sections
    --
    local Sections = Library.Sections
    -- безопасный CanvasPosition: ближайший предок-скроллер (Frame секций не имеет CanvasPosition)
    local function gsFindScroller(inst)
        local cur = inst
        while cur ~= nil and typeof(cur) == "Instance" do
            if cur:IsA("ScrollingFrame") then return cur end
            cur = cur.Parent
        end
        return nil
    end
    --
    local function gsCanvasOf(inst)
        local scr = gsFindScroller(inst)
        return scr and scr.CanvasPosition or Vector2.new(0, 0)
    end
    --
    function Library:ColorPicker(Options)
        Options = Library:Validate({
            Name = "Preview Color Picker",
            Default = Library.Theme.Default.Accent,
            Alpha = 0,
            AlphaBar = true,
            Parent = nil,
            MainUI = nil,
            TabUI = nil,
            Count = 1,
            Keybind = false,
            Flag = Library:NewFlag(),
            Callback = function() end,
        }, Options or {})
        --
        local Hue, Saturation, Value = Options.Default:ToHSV()
        --
        local ColorPicker = {
            Hover = false,
            Active = false,
            MouseDown = false,
            MainFrameHover = false,
            Color = Options.Default,
            SecondColor = Color3.fromRGB(math.max(math.floor(Options.Default.R * 255) - 14, 0), math.max(math.floor(Options.Default.G * 255) - 14, 0), math.max(math.floor(Options.Default.B * 255) - 14, 0)),
            Saturation = {Saturation, Value},
            Alpha = Options.Alpha,
            Hue = Hue,
            ActiveFrame = false,
            LastCopiedColor = {self.Color, self.Alpha},
            FrameOpened = false,
        }
        --
        Library.Flags[Options.Flag] = ColorPicker
        --
        Library.UI.TotalColorPickers += 1
        --
        if Options.Keybind then
            Options.Count += 1
        end
        --
        local ColorPickerOutline_1 = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            Name = "ColorPickerOutline" .. Library.UI.TotalColorPickers,
            Position = UDim2.new(1, 0 - (Options.Count - 1) * 22, 0, 0),
            Size = UDim2.new(0, 17, 0, 9),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = Options.Parent
        })
        --
        local ColorPickerChecker = Library:CreateObject("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 4),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 0, 1),
            Visible = false,
            BorderSizePixel = 0,
            Parent = ColorPickerOutline_1
        })
        --
        local Button_9 = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "Button_9",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ColorPickerOutline_1
        })
        --
        local ColorPickerTransparency = Library:CreateObject("ImageLabel", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Image = "rbxassetid://18249241978",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            Name = "Transparency",
            Size = UDim2.new(1, -2, 1, -2),
            Position = UDim2.new(0, 1, 0, 1),
            BorderSizePixel = 0,
            ZIndex = 3,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ColorPickerOutline_1
        })
        --
        local ColorPickerInline_1 = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "ColorPickerInline_1",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ColorPickerOutline_1
        })
        --
        local UIGradient_24 = Library:CreateObject("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, ColorPicker.Color),
                ColorSequenceKeypoint.new(1, ColorPicker.SecondColor)
            },
            Parent = ColorPickerInline_1
        })
        --
        do -- Functions
            function ColorPicker:SetVisible(Bool)
                ColorPickerOutline_1.Visible = Bool
                --
                if Bool == false then
                    ColorPicker:RemoveFrame()
                end
            end
            --
            function ColorPicker:AddFrame()
                Library.UI.CurrentSelectedColorPicker = {ColorPicker = ColorPicker, ColorPickerOutline = ColorPickerOutline_1, Parent = Options.Parent}
                --
                Library.UI.OpenColorFrames += 1
                --
                local ColorPickerOutline = Library:CreateObject("Frame", {
                    Size = UDim2.new(0, 180, 0, 175),
                    Name = "ColorPickerFrame" .. Library.UI.TotalColorPickers,
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = Library.UI.ScreenGUI
                })
                --
                ColorPickerOutline.BackgroundTransparency = 1
                --
                local ColorPickerInline = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "ColorPickerInline",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                    Parent = ColorPickerOutline
                })
                --
                ColorPickerInline.BackgroundTransparency = 1
                --
                local ColorPickerMain = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "ColorPickerMain",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    Parent = ColorPickerInline
                })
                --
                ColorPickerMain.BackgroundTransparency = 1
                --
                local MainPicker = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -24, 1, -19),
                    Name = "MainPicker",
                    Position = UDim2.new(0, 2, 0, 2),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = ColorPickerMain
                })
                --
                MainPicker.BackgroundTransparency = 1
                --
                local Button_91 = Library:CreateObject("TextButton", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "Button_9",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    TextTransparency = 1,
                    ZIndex = 250,
                    TextSize = Library.UI.FontSize,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = MainPicker
                })
                --
                local MainPickerColor = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "MainPickerColor",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = MainPicker
                })
                --
                MainPickerColor.BackgroundTransparency = 1
                --
                local UIGradient_20 = Library:CreateObject("UIGradient", {
                    Rotation = 180,
                    Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 4)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
                    },
                    Parent = MainPickerColor
                })
                --
                local BackImage = Library:CreateObject("ImageLabel", {
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Image = "rbxassetid://13966897785",
                    BackgroundTransparency = 1,
                    Name = "BackImage",
                    Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    Parent = MainPickerColor
                })
                --
                BackImage.ImageTransparency = 1
                --
                local DraggingMainOutline = Library:CreateObject("Frame", {
                    Size = UDim2.new(0, 4, 0, 4),
                    Name = "DraggingMainOutline",
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = MainPicker
                })
                --
                DraggingMainOutline.BackgroundTransparency = 1
                --
                local DraggingMain = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "DraggingMain",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = DraggingMainOutline
                })
                --
                DraggingMain.BackgroundTransparency = 1
                --
                local SaturationSlider = Library:CreateObject("Frame", {
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    AnchorPoint = Vector2.new(0, 1),
                    Name = "SaturationSlider",
                    Position = UDim2.new(0, 2, 1, -2),
                    Size = UDim2.new(1, -24, 0, 12),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = ColorPickerMain
                })
                --
                SaturationSlider.BackgroundTransparency = 1
                --
                local Button_915241 = Library:CreateObject("TextButton", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "Button_9",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    TextTransparency = 1,
                    ZIndex = 250,
                    TextSize = Library.UI.FontSize,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = SaturationSlider
                })
                --
                local SaturationColor = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "SaturationColor",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = SaturationSlider
                })
                --
                SaturationColor.BackgroundTransparency = 1
                --
                local UIGradient_21 = Library:CreateObject("UIGradient", {
                    Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 4)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
                    },
                    Transparency = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 0.10000000149011612),
                        NumberSequenceKeypoint.new(0.5, 0.800000011920929),
                        NumberSequenceKeypoint.new(1, 1)
                    },
                    Rotation = 180,
                    Parent = SaturationColor
                })
                --
                local BackImage_1 = Library:CreateObject("ImageLabel", {
                    ScaleType = Enum.ScaleType.Tile,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "BackImage_1",
                    TileSize = UDim2.new(0, 12, 0, 12),
                    Image = "rbxassetid://18249241978",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 1, 0, 1),
                    Size = UDim2.new(1, -2, 1, -2),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    Parent = SaturationSlider
                })
                --
                BackImage_1.ImageTransparency = 1
                --
                local DraggingSatOutline = Library:CreateObject("Frame", {
                    Size = UDim2.new(0, 4, 1, 0),
                    Name = "DraggingSatOutline",
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = SaturationSlider
                })
                --
                DraggingSatOutline.BackgroundTransparency = 1
                --
                local DraggingSatMain = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "DraggingSatMain",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = DraggingSatOutline
                })
                --
                DraggingSatMain.BackgroundTransparency = 1
                --
                local HueSlider = Library:CreateObject("Frame", {
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    AnchorPoint = Vector2.new(1, 0),
                    Name = "HueSlider",
                    Position = UDim2.new(1, -2, 0, 2),
                    Size = UDim2.new(0, 17, 1, -19),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = ColorPickerMain
                })
                --
                HueSlider.BackgroundTransparency = 1
                --
                local Button_9141 = Library:CreateObject("TextButton", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "Button_9",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    TextTransparency = 1,
                    ZIndex = 250,
                    TextSize = Library.UI.FontSize,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = HueSlider
                })
                --
                local BackImage_2 = Library:CreateObject("ImageLabel", {
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "BackImage_2",
                    TileSize = UDim2.new(0, 12, 0, 12),
                    Image = "rbxassetid://8180989234",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 1, 0, 1),
                    Size = UDim2.new(1, -2, 1, -2),
                    ZIndex = 250,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    Parent = HueSlider
                })
                --
                BackImage_2.ImageTransparency = 1
                --
                local DraggingHueOutline = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, 0, 0, 4),
                    Name = "DraggingHueOutline",
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = HueSlider
                })
                --
                DraggingHueOutline.BackgroundTransparency = 1
                --
                local DraggingHueMain = Library:CreateObject("Frame", {
                    Size = UDim2.new(1, -2, 1, -2),
                    Name = "DraggingHueMain",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 251,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = DraggingHueOutline
                })
                --
                DraggingHueMain.BackgroundTransparency = 1
                --
                do -- Functions
                    function ColorPicker:UpdateSize()
                        ColorPickerOutline.Position = UDim2.new(0, ColorPickerOutline_1.AbsolutePosition.X, 0, (ColorPickerOutline_1.AbsolutePosition.Y + ColorPickerOutline_1.AbsoluteSize.Y + GuiService:GetGuiInset().Y + 2))
                    end
                    --
                    ColorPicker:UpdateSize()
                    --
                    Library:Connection(Options.MainUI:GetPropertyChangedSignal("AbsolutePosition"), ColorPicker.UpdateSize)
                    --
                    local StartingY = ColorPickerOutline_1.AbsolutePosition.Y
                    local MainUIStartingY = Options.MainUI.AbsolutePosition.Y
                    local StartingCanvasPosition = gsCanvasOf(Options.Parent)
                    --
                    Library:Connection(ColorPickerOutline_1:GetPropertyChangedSignal("AbsolutePosition"), function()
                        local CurrentY = ColorPickerOutline_1.AbsolutePosition.Y
                        local MainUICurrentY = Options.MainUI.AbsolutePosition.Y
                        local CurrentCanvasPosition = gsCanvasOf(Options.Parent)
                        --
                        if MainUICurrentY ~= MainUIStartingY then
                            MainUIStartingY = MainUICurrentY
                            StartingY = CurrentY
                            --
                            return
                        end
                        --
                        if CurrentCanvasPosition ~= StartingCanvasPosition then
                            StartingCanvasPosition = CurrentCanvasPosition
                            StartingY = CurrentY
                            --
                            return
                        end
                        --
                        if Library.UI.Resizing then
                            return
                        end
                        --
                        if CurrentY ~= StartingY then
                            ColorPicker:RemoveFrame(true)
                        end
                        --
                        StartingY = CurrentY
                    end)
                    --
                    Library:Connection(Options.MainUI:GetPropertyChangedSignal("AbsoluteSize"), function()
                        if ColorPicker.Active then
                            ColorPickerOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), ColorPickerChecker)
                        end
                        --
                        ColorPicker:UpdateSize()
                    end)
                    --
                    if gsFindScroller(Options.Parent) then
                        Library:Connection(gsFindScroller(Options.Parent):GetPropertyChangedSignal("CanvasPosition"), function()
                            ColorPicker:UpdateSize()
                            --
                            if ColorPicker.Active then
                                ColorPickerOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), ColorPickerChecker)
                            end
                        end)
                    end
                    --
                    Library:Connection(Options.MainUI:GetPropertyChangedSignal("Visible"), function()
                        if not Options.MainUI.Visible then
                            ColorPickerOutline.Visible = false
                        else
                            ColorPickerOutline.Visible = ColorPicker.Active
                        end
                    end)
                    --
                    Library:Connection(Options.Parent.Parent:GetPropertyChangedSignal("Visible"), function()
                        if not Options.Parent.Parent.Visible then
                            ColorPickerOutline.Visible = false
                        else
                            ColorPickerOutline.Visible = ColorPicker.Active
                        end
                    end)
                    --
                    function ColorPicker:Update()
                        ColorPicker.Color = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Saturation[1], ColorPicker.Saturation[2])
                        ColorPicker.SecondColor = Color3.fromRGB(math.max(math.floor(ColorPicker.Color.R * 255) - 23, 0), math.max(math.floor(ColorPicker.Color.G * 255) - 23, 0), math.max(math.floor(ColorPicker.Color.B * 255) - 23, 0))
                        --
                        UIGradient_24.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, ColorPicker.Color), ColorSequenceKeypoint.new(1, ColorPicker.SecondColor)}
                        UIGradient_20.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, ColorPicker.Color), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))}
                        UIGradient_21.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, ColorPicker.Color), ColorSequenceKeypoint.new(1, ColorPicker.Color)}
                        UIGradient_20.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromHSV(ColorPicker.Hue, 1, 1)), ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255, 255, 255))}
                        --
                        local MaxSaturationX = math.max(0, MainPickerColor.AbsoluteSize.X - DraggingMainOutline.AbsoluteSize.X) / MainPickerColor.AbsoluteSize.X
                        local MaxSaturationY = math.max(0, MainPickerColor.AbsoluteSize.Y - DraggingMainOutline.AbsoluteSize.Y) / MainPickerColor.AbsoluteSize.Y
                        local MaxAlpha = math.max(0, SaturationColor.AbsoluteSize.X - DraggingSatOutline.AbsoluteSize.X) / SaturationColor.AbsoluteSize.X
                        local MaxHue = math.max(0, BackImage_2.AbsoluteSize.Y - DraggingHueOutline.AbsoluteSize.Y) / BackImage_2.AbsoluteSize.Y
                        --
                        Library:TweenObject(DraggingMainOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromScale(math.clamp(ColorPicker.Saturation[1], 0, MaxSaturationX), math.clamp(1 - ColorPicker.Saturation[2], 0, MaxSaturationY))})
                        Library:TweenObject(DraggingSatOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(math.clamp(1 - ColorPicker.Alpha, 0, MaxAlpha), 0, 0, 0)})
                        Library:TweenObject(DraggingHueOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, math.clamp(ColorPicker.Hue, 0, MaxHue), 0)})
                        --
                        DraggingMain.BackgroundColor3 = ColorPicker.Color
                        DraggingSatMain.BackgroundColor3 = ColorPicker.Color
                        DraggingHueMain.BackgroundColor3 = ColorPicker.Color
                        ColorPickerInline_1.BackgroundTransparency = ColorPicker.Alpha
                        UIGradient_21.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.304 + (0.604 - 0.304) * ColorPicker.Alpha), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1)}
                        --
                        Options.Callback(ColorPicker.Color, ColorPicker.Alpha)
                        Library.Flags[Options.Flag] = ColorPicker
                    end
                    --
                    function ColorPicker:Set(Color, Transparency)
                        if typeof(Color) == "table" then
                            ColorPicker.Color = Color3.fromHSV(Color[1], Color[2], Color[3])
                            ColorPicker.Alpha = Color[4]
                            ColorPicker.Hue = Color[1]
                            ColorPicker.Saturation[1] = Color[2]
                            ColorPicker.Saturation[2] = Color[3]
                            ColorPicker:Update()
                            Options.Callback(ColorPicker.Color, ColorPicker.Alpha)
                        elseif typeof(Color) == "Color3" then
                            local h, s, v = Color:ToHSV()
                            --
                            ColorPicker.Color = Color3.fromHSV(h, s, v)
                            ColorPicker.Alpha = Transparency or 1
                            ColorPicker.Hue = h
                            ColorPicker.Saturation[1] = s
                            ColorPicker.Saturation[2] = v
                            ColorPicker:Update()
                            Options.Callback(ColorPicker.Color, ColorPicker.Alpha)
                        end
                    end
                    --
                    function ColorPicker:Get()
                        return {Color = ColorPicker.Color, Transparency = ColorPicker.Alpha}
                    end
                    --
                    function ColorPicker:UpdateHue(Percentage)
                        local Percentage = typeof(Percentage == "number") and math.clamp(Percentage, 0, 1) or 0
                        --
                        ColorPicker.Hue = Percentage
                        --
                        ColorPicker:Update()
                    end
                    --
                    function ColorPicker:UpdateAlpha(Percentage)
                        local Percentage = typeof(Percentage == "number") and math.clamp(Percentage, 0, 1) or 0
                        --
                        ColorPicker.Alpha = Percentage
                        --
                        ColorPicker:Update()
                    end
                    --
                    function ColorPicker:UpdateSaturation(PercentageX, PercentageY)
                        local PercentageX = typeof(PercentageX == "number") and math.clamp(PercentageX, 0, 1) or 0
                        local PercentageY = typeof(PercentageY == "number") and math.clamp(PercentageY, 0, 1) or 0
                        --
                        ColorPicker.Saturation[1] = PercentageX
                        ColorPicker.Saturation[2] = 1 - PercentageY
                        --
                        ColorPicker:Update()
                    end
                end
                --
                do -- Connections
                    Library:Connection(Button_91.InputBegan, function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                            Library.UI.DraggingGui = MainPickerColor
                            --
                            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                            local Percentage = (InputPosition - MainPickerColor.AbsolutePosition) / MainPickerColor.AbsoluteSize
                            --
                            ColorPicker:UpdateSaturation(Percentage.X, Percentage.Y)
                        end
                    end)
                    --
                    Library:Connection(Button_915241.InputBegan, function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                            Library.UI.DraggingGui = SaturationColor
                            --
                            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                            local GuiPosition = SaturationColor.AbsolutePosition.X
                            local GuiSize = SaturationColor.AbsoluteSize.X
                            local Percentage = ((GuiPosition + GuiSize - InputPosition.X) / GuiSize)
                            --
                            ColorPicker:UpdateAlpha(Percentage)
                        end
                    end)
                    --
                    Library:Connection(Button_9141.InputBegan, function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                            Library.UI.DraggingGui = BackImage_2
                            --
                            local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                            local Percentage = (InputPosition - BackImage_2.AbsolutePosition) / BackImage_2.AbsoluteSize
                            --
                            ColorPicker:UpdateHue(Percentage.Y)
                        end
                    end)
                    --
                    Library:Connection(UserInputService.InputChanged, function(Input)
                        if (Library.UI.DraggingGui ~= SaturationColor and Library.UI.DraggingGui ~= MainPickerColor and Library.UI.DraggingGui ~= BackImage_2) then return end
                        --
                        if not (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
                            Library.UI.DraggingGui = nil
                            return
                        end
                        --
                        local InputPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                        --
                        if (Input.UserInputType == Enum.UserInputType.MouseMovement) then
                            if Library.UI.DraggingGui == MainPickerColor then
                                local Percentage = (InputPosition - MainPickerColor.AbsolutePosition) / MainPickerColor.AbsoluteSize
                                --
                                ColorPicker:UpdateSaturation(Percentage.X, Percentage.Y)
                            end
                            --
                            if Library.UI.DraggingGui == SaturationColor then
                                local GuiPosition = SaturationColor.AbsolutePosition.X
                                local GuiSize = SaturationColor.AbsoluteSize.X
                                local Percentage = ((GuiPosition + GuiSize - InputPosition.X) / GuiSize)
                                --
                                ColorPicker:UpdateAlpha(Percentage)
                            end
                            --
                            if Library.UI.DraggingGui == BackImage_2 then
                                local Percentage = (InputPosition - BackImage_2.AbsolutePosition) / BackImage_2.AbsoluteSize
                                --
                                ColorPicker:UpdateHue(Percentage.Y)
                            end
                        end
                    end)
                end
                --
                ColorPicker:Update()
                Library:Fade(true, Library:GetObjectsTable(ColorPickerOutline, true), ColorPickerOutline, 0.1)
            end
            --
            function ColorPicker:RemoveFrame(Fast)
                local Fast = Fast or false
                --
                for Index, Value in Library.UI.ScreenGUI:GetChildren() do
                    if Value:IsA("Frame") and Value.Name == "ColorPickerFrame" .. Library.UI.TotalColorPickers then
                        if Fast then
                            Value:Destroy()
                        else
                            Library:Fade(false, Library:GetObjectsTable(Value, true), Value, 0.1)
                            --
                            task.delay(Library.UI.TweenSpeed, function()
                                Value:Destroy()
                            end)
                        end
                    end
                end
            end
            --
            function ColorPicker:FindFrame()
                for Index, Value in Library.UI.ScreenGUI:GetChildren() do
                    if Value:IsA("Frame") and Value.Name == "ColorPickerFrame" .. Library.UI.TotalColorPickers then
                        return true
                    end
                end
                --
                return false
            end
            --
            function ColorPicker:Toggle()
                if Library.UI.CurrentSelectedColorPicker and Library.UI.CurrentSelectedColorPicker.ColorPickerOutline.Name ~= ColorPickerOutline_1.Name then
                    Library.UI.CurrentSelectedColorPicker.ColorPicker:RemoveFrame()
                end
                --
                if not ColorPicker:FindFrame() then
                    ColorPicker.Active = true
                    ColorPicker:AddFrame()
                else
                    ColorPicker.Active = false
                    ColorPicker:RemoveFrame()
                end
            end
            --
            function ColorPicker:AddOtherFrame()
                Library.UI.CurrentSelectedColorPickerExtra = {ColorPicker = ColorPicker, ColorPickerObject = ColorPickerOutline_1, Parent = Options.Parent}
                --
                local KeybindModePickerOutline = Library:CreateObject("Frame", {
                    Name = "ColorPickerOutline" .. Library.UI.TotalColorPickers,
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Size = UDim2.new(0, 100, 0, 55),
                    BorderSizePixel = 0,
                    ZIndex = 25,
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = Library.UI.ScreenGUI
                })
                --
                local KeybindModePickerMain = Library:CreateObject("Frame", {
                    Name = "KeybindModePickerMain",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Size = UDim2.new(1, -2, 1, -2),
                    BorderSizePixel = 0,
                    ZIndex = 25,
                    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                    Parent = KeybindModePickerOutline
                })
                --
                KeybindModePickerOutline.BackgroundTransparency = 1
                KeybindModePickerMain.BackgroundTransparency = 1
                --
                local UIListLayout_9 = Library:CreateObject("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = KeybindModePickerMain
                })
                --
                function ColorPicker:UpdateSize()
                    KeybindModePickerOutline.Position = UDim2.new(0, ColorPickerOutline_1.AbsolutePosition.X - 2, 0, ColorPickerOutline_1.AbsolutePosition.Y + ColorPickerOutline_1.AbsoluteSize.Y + KeybindModePickerOutline.AbsoluteSize.Y - 4)
                end
                --
                ColorPicker:UpdateSize()
                --
                Library:Connection(Options.MainUI:GetPropertyChangedSignal("AbsolutePosition"), ColorPicker.UpdateSize)
                --
                local StartingY = ColorPickerOutline_1.AbsolutePosition.Y
                local MainUIStartingY = Options.MainUI.AbsolutePosition.Y
                local StartingCanvasPosition = gsCanvasOf(Options.Parent)
                --
                Library:Connection(ColorPickerOutline_1:GetPropertyChangedSignal("AbsolutePosition"), function()
                    local CurrentY = ColorPickerOutline_1.AbsolutePosition.Y
                    local MainUICurrentY = Options.MainUI.AbsolutePosition.Y
                    local CurrentCanvasPosition = gsCanvasOf(Options.Parent)
                    --
                    if MainUICurrentY ~= MainUIStartingY then
                        MainUIStartingY = MainUICurrentY
                        StartingY = CurrentY
                        --
                        return
                    end
                    --
                    if CurrentCanvasPosition ~= StartingCanvasPosition then
                        StartingCanvasPosition = CurrentCanvasPosition
                        StartingY = CurrentY
                        --
                        return
                    end
                    --
                    if Library.UI.Resizing then
                        return
                    end
                    --
                    if CurrentY ~= StartingY then
                        ColorPicker:RemoveOtherFrame(true)
                    end
                    --
                    StartingY = CurrentY
                end)
                --
                Library:Connection(Options.MainUI:GetPropertyChangedSignal("AbsoluteSize"), function()
                    if ColorPicker.ActiveFrame then
                        KeybindModePickerOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), ColorPickerChecker)
                    end
                    --
                    ColorPicker:UpdateSize()
                end)
                --
                if gsFindScroller(Options.Parent) then
                    Library:Connection(gsFindScroller(Options.Parent):GetPropertyChangedSignal("CanvasPosition"), function()
                        ColorPicker:UpdateSize()
                        --
                        if ColorPicker.ActiveFrame then
                            KeybindModePickerOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), ColorPickerChecker)
                        end
                    end)
                end
                --
                for Index, Value in {"Copy", "Paste", "Reset"} do
                    local ModeItem = {
                        Active = false,
                        Hovering = false,
                    }
                    --
                    local Inactive = Library:CreateObject("TextLabel", {
                        FontFace = Library.UI.NewFont,
                        TextColor3 = Color3.fromRGB(208, 208, 208),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Name = Value,
                        Text = Value,
                        RichText = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 17),
                        BorderSizePixel = 0,
                        TextSize = Library.UI.FontSize,
                        ZIndex = 25,
                        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                        Parent = KeybindModePickerMain
                    })
                    --
                    local Button_4 = Library:CreateObject("TextButton", {
                        FontFace = Library.UI.NewFont,
                        TextColor3 = Color3.fromRGB(0, 0, 0),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Name = "Button_4",
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        BorderSizePixel = 0,
                        TextTransparency = 1,
                        TextSize = Library.UI.FontSize,
                        ZIndex = 25,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        Parent = Inactive
                    })
                    --
                    local UIPadding_48 = Library:CreateObject("UIPadding", {
                        PaddingLeft = UDim.new(0, 8),
                        Parent = Inactive
                    })
                    --
                    Inactive.TextTransparency = 1
                    --
                    do -- Functions
                        function ModeItem:Activate()
                            if not ModeItem.Active then
                                ModeItem.Active = true
                                --
                                Inactive.Text = "<b>" .. Value .. "</b>"
                                Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Library.Theme.Default.Accent})
                                --
                                if Value == "Copy" then
                                    Library.UI.LastCopiedColor = {Color = ColorPicker.Color, Alpha = ColorPicker.Alpha}
                                elseif Value == "Paste" then
                                    if Library.UI.LastCopiedColor then
                                        ColorPicker:Set(Library.UI.LastCopiedColor.Color, Library.UI.LastCopiedColor.Alpha)
                                    end
                                elseif Value == "Reset" then
                                    ColorPicker:Set(Options.Default, Options.Alpha)
                                end
                                --
                                ColorPicker:RemoveOtherFrame()
                            end
                        end
                        --
                        function ModeItem:Deactivate()
                            if ModeItem.Active then
                                ModeItem.Active = false
                                ModeItem.Hovering = false
                                Inactive.Text = Value
                                Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                            end
                        end
                    end
                    --
                    do -- Connections
                        Library:Connection(Button_4.MouseButton1Click, function()
                            ModeItem:Activate()
                        end)
                        --
                        Library:Connection(Inactive.MouseEnter, function()
                            Inactive.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                            --
                            if ModeItem.Active then return end
                            --
                            Inactive.Text = "<b>" .. Value .. "</b>"
                        end)
                        --
                        Library:Connection(Inactive.MouseLeave, function()
                            Inactive.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                            --
                            if ModeItem.Active then return end
                            --
                            Inactive.Text = Value
                            Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                        end)
                    end
                end
                --
                Library:Fade(true, Library:GetObjectsTable(KeybindModePickerOutline, true), KeybindModePickerOutline, 0.1)
            end
            --
            function ColorPicker:RemoveOtherFrame(Fast)
                local Fast = Fast or false
                --
                for Index, Value in Library.UI.ScreenGUI:GetChildren() do
                    if Value:IsA("Frame") and Value.Name == "ColorPickerOutline" .. Library.UI.TotalColorPickers then
                        if Fast then
                            Value:Destroy()
                        else
                            Library:Fade(false, Library:GetObjectsTable(Value, true), Value, 0.1)
                            --
                            task.delay(Library.UI.TweenSpeed, function()
                                Value:Destroy()
                            end)
                        end
                    end
                end
            end
            --
            function ColorPicker:FindOtherFrame()
                for Index, Value in Library.UI.ScreenGUI:GetChildren() do
                    if Value:IsA("Frame") and Value.Name == "ColorPickerOutline" .. Library.UI.TotalColorPickers then
                        return true
                    end
                end
                --
                return false
            end
            --
            function ColorPicker:ToggleOtherFrame()
                if Library.UI.CurrentSelectedColorPickerExtra and Library.UI.CurrentSelectedColorPickerExtra.ColorPickerObject.Name ~= ColorPickerOutline_1.Name then
                    Library.UI.CurrentSelectedColorPickerExtra.ColorPicker:RemoveFrame()
                end
                --
                if not ColorPicker:FindOtherFrame() then
                    ColorPicker.ActiveFrame = true
                    ColorPicker:AddOtherFrame()
                else
                    ColorPicker.ActiveFrame = false
                    ColorPicker:RemoveOtherFrame()
                end
            end
        end
        --
        do -- Connections
            Library:Connection(Button_9.MouseButton2Click, function()
                ColorPicker:ToggleOtherFrame()
            end)
            --
            Library:Connection(Button_9.MouseButton1Click, function()
                ColorPicker:Toggle()
            end)
        end
        --
        ColorPicker:AddFrame()
        ColorPicker:Update()
        ColorPicker:RemoveFrame()
        --
        return ColorPicker
    end
    function Library:Keybind(Options)
        Options = Library:Validate({
            Default = Enum.KeyCode.Backspace,
            Mode = "Toggle",
            UseMode = true,
            HideFromList = false,
            Blacklisted = {},
            Parent = nil,
            Toggle = nil,
            MainUI = nil,
            Hiding = false,
            ToggleState = false,
            Flag = Library.NewFlag(),
            Count = 1,
            ChangeToggle = false,
            Callback = function() end,
        }, Options or {})
        --
        if Options.Toggle == nil then return end
        --
        local Keybind = {
            Hover = false,
            ActiveFrame = false,
            Keybind = Options.Default,
            RegKeybind = nil,
            State = false,
            SelectingKeybind = false,
            Toggle = false,
            Connection = nil,
            Mode = Options.Mode,
            ConfigKeybind = nil,
            Current = {},
            CurrentMode = nil,
            Hiding = false,
        }
        --
        Library.Flags[Options.Flag] = Keybind
        Library.UI.TotalKeybindModes += 1
        --
        local KeybindObject = Library:CreateObject("TextLabel", {
            FontFace = (function() local ok, f = pcall(function() return Font.new("rbxassetid://12187371840", Enum.FontWeight.Regular, Enum.FontStyle.Normal) end) return (ok and f) or Library.UI.NewFont end)(),
            TextColor3 = Color3.fromRGB(117, 117, 117),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = "[-]",
            Name = "KeybindOutline" .. Library.UI.TotalKeybindModes,
            AnchorPoint = Vector2.new(1, 0),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 16, 0, 7),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, 0 - (Options.Count - 1) * 22, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 3,
            TextStrokeTransparency = 0,
            TextSize = 9,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local KeybindChecker = Library:CreateObject("Frame", {
            Position = UDim2.new(0, 0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 0, 1),
            Visible = false,
            BorderSizePixel = 0,
            Parent = KeybindObject
        })
        --
        local Button_4 = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "Button_4",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = KeybindObject
        })
        --
        local UserInputTypeBinds = {"MouseButton1", "MouseButton2", "MouseButton3"}
        --
        do -- Functions
            function Keybind:SetVisible(Bool)
                local OldValues = Library.Objects[KeybindObject]
                --
                Keybind.Hiding = not Bool
                --
                if Bool then
                    Library.Objects[KeybindObject] = {KeybindObject, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(KeybindObject), KeybindObject, 0.075)
                Library:TweenObject(KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and UDim2.new(1, 0, 0, 8) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[KeybindObject] = {KeybindObject, OldValues[2], false}
                    end
                end)
            end
            --
            function Keybind:Set(Key)
                if Keybind.Hiding then return end
                if typeof(Key) == "boolean" then return end
                --
                if typeof(Key) == "EnumItem" then
                    Keybind.RegKeybind = Key
                elseif typeof(Key) == "string" then
                    if table.find(UserInputTypeBinds, Key) then
                        Keybind.RegKeybind = Enum.UserInputType[Key]
                        Key = Enum.UserInputType[Key]
                    else
                        Keybind.RegKeybind = Enum.KeyCode[Key]
                        Key = Enum.KeyCode[Key]
                    end
                end
                --
                if typeof(Key) == "string" then
                    if Key:find("KEY") then
                        Key = Enum.KeyCode[Key:gsub("KEY_", "")]
                    elseif Key:find("Input") then
                        Key = Enum.UserInputType[Key:gsub("Input_", "")]
                    end
                end
                --
                local ValidKey = false
                local KeyString = ""
                --
                if table.find(Options.Blacklisted, Key) then
                    Key = nil
                end
                --
                if Key then
                    if ((Key.EnumType == Enum.KeyCode and UserInputService:GetStringForKeyCode(Key) ~= "") or Library.UI.Keys[Key]) then
                        ValidKey = true
                        KeyString = Library.UI.Keys[Key] or UserInputService:GetStringForKeyCode(Key)
                    end
                end
                --
                if ValidKey then
                    Keybind.Keybind = KeyString
                    KeybindObject.Text = "[" .. KeyString:upper() .. "]"
                    --
                    Options.Callback(Key)
                    Library.Flags[Options.Flag] = Keybind
                else
                    Keybind.Keybind = "[-]"
                    KeybindObject.Text = Keybind.Keybind
                end
                --
                Library:TweenObject(KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(117, 117, 117)})
                KeybindObject.Size = UDim2.new(0, KeybindObject.TextBounds.X + 2, 0, 7)
            end
            --
            function Keybind:Toggle(Bool)
                if Keybind.Hiding then return end
                --
                if Bool == nil then
                    Keybind.State = not Keybind.State
                else
                    Keybind.State = Bool
                end
                --
                if not Options.HideFromList then
                    if Keybind.State then
                        --Library:AddKeybindFrame(Keybind.Mode, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                    else
                        --Library:RemoveKeybindFrame(Options.Toggle:GetName(), Options.Toggle:GetSection())
                    end
                end
                --
                if Options.Toggle.GetFlag then
                    Library.Flags[Options.Toggle:GetFlag()] = Keybind
                end
                --
                if Options.ChangeToggle then
                    -- viuslaly toggle the UI element and update its state
                    Options.Toggle:Set(Keybind.State)
                else
                    Options.Toggle:GetCallback(Keybind.State)
                end
            end
            --
            task.delay(1, function()
                Keybind:Set(Options.Default)
            end)
            --
            function Keybind:Get()
                local KeyString = Keybind.RegKeybind.EnumType == Enum.KeyCode and tostring(Keybind.RegKeybind):match("^Enum%.KeyCode%.(.+)$") or tostring(Keybind.RegKeybind):match("^Enum%.UserInputType%.(.+)$")
                --
                return KeyString
            end
            --
            function Keybind:Active()
                return (Keybind.Keybind:lower() == "[-]" and true or Keybind.State)
            end
            --
            if Options.Mode == "Always on" then
                Keybind:Toggle(true)
            end
            --
            function Keybind:SetMode(Mode)
                Keybind.Mode = Mode
                --
                if Mode == "Always on" then
                    if Mode == "Always on" then
                        Keybind:Toggle(true)
                    end
                    --
                    if not Keybind.State then
                        Keybind.State = true
                        --
                        --Library:AddKeybindFrame(Mode, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                    else
                        --Library:UpdateKeybindFrame(Mode, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                    end
                elseif Mode == "Toggle" then
                    if Keybind.State then
                        --Library:UpdateKeybindFrame(Mode, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                    end
                elseif Mode == "On hotkey" then
                    Keybind.State = false
                    --
                    --Library:RemoveKeybindFrame(Options.Toggle:GetName(), Options.Toggle:GetSection())
                end
            end
            --
            function Keybind:AddFrame()
                Library.UI.CurrentSelectedKeybindMode = {Keybind = Keybind, KeybindObject = KeybindObject, Parent = Options.Parent}
                --
                local KeybindModePickerOutline = Library:CreateObject("Frame", {
                    Name = "KeybindModePickerOutline" .. Library.UI.TotalKeybindModes,
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Size = UDim2.new(0, 100, 0, 55),
                    BorderSizePixel = 0,
                    ZIndex = 25,
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                    Parent = Library.UI.ScreenGUI
                })
                --
                local KeybindModePickerMain = Library:CreateObject("Frame", {
                    Name = "KeybindModePickerMain",
                    Position = UDim2.new(0, 1, 0, 1),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Size = UDim2.new(1, -2, 1, -2),
                    BorderSizePixel = 0,
                    ZIndex = 25,
                    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                    Parent = KeybindModePickerOutline
                })
                --
                KeybindModePickerOutline.BackgroundTransparency = 1
                KeybindModePickerMain.BackgroundTransparency = 1
                --
                local UIListLayout_9 = Library:CreateObject("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = KeybindModePickerMain
                })
                --
                function Keybind:UpdateSize()
                    KeybindModePickerOutline.Position = UDim2.new(0, KeybindObject.AbsolutePosition.X , 0, KeybindObject.AbsolutePosition.Y + KeybindObject.AbsoluteSize.Y + KeybindModePickerOutline.AbsoluteSize.Y - 2)
                end
                --
                Keybind:UpdateSize()
                --
                Library:Connection(Options.MainUI:GetPropertyChangedSignal("AbsolutePosition"), Keybind.UpdateSize)
                --
                local StartingY = KeybindObject.AbsolutePosition.Y
                local MainUIStartingY = Options.MainUI.AbsolutePosition.Y
                local StartingCanvasPosition = gsCanvasOf(Options.Parent)
                --
                Library:Connection(KeybindObject:GetPropertyChangedSignal("AbsolutePosition"), function()
                    local CurrentY = KeybindObject.AbsolutePosition.Y
                    local MainUICurrentY = Options.MainUI.AbsolutePosition.Y
                    local CurrentCanvasPosition = gsCanvasOf(Options.Parent)
                    --
                    if MainUICurrentY ~= MainUIStartingY then
                        MainUIStartingY = MainUICurrentY
                        StartingY = CurrentY
                        --
                        return
                    end
                    --
                    if CurrentCanvasPosition ~= StartingCanvasPosition then
                        StartingCanvasPosition = CurrentCanvasPosition
                        StartingY = CurrentY
                        --
                        return
                    end
                    --
                    if Library.UI.Resizing then
                        return
                    end
                    --
                    if CurrentY ~= StartingY then
                        Keybind:RemoveFrame(true)
                    end
                    --
                    StartingY = CurrentY
                end)
                --
                Library:Connection(Options.MainUI:GetPropertyChangedSignal("AbsoluteSize"), function()
                    if Keybind.ActiveFrame then
                        KeybindModePickerOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), KeybindChecker)
                    end
                    --
                    Keybind:UpdateSize()
                end)
                --
                Library:Connection(KeybindObject:GetPropertyChangedSignal("AbsoluteSize"), function()
                    Keybind:UpdateSize()
                end)
                --
                if gsFindScroller(Options.Parent) then
                    Library:Connection(gsFindScroller(Options.Parent):GetPropertyChangedSignal("CanvasPosition"), function()
                        Keybind:UpdateSize()
                        --
                        if Keybind.ActiveFrame then
                            KeybindModePickerOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), KeybindChecker)
                        end
                    end)
                end
                --
                for Index, Value in {"Always on", "On hotkey", "Toggle"} do
                    local ModeItem = {
                        Active = false,
                        Hovering = false,
                    }
                    --
                    local Inactive = Library:CreateObject("TextLabel", {
                        FontFace = Library.UI.NewFont,
                        TextColor3 = Color3.fromRGB(208, 208, 208),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Name = Value,
                        Text = Value,
                        RichText = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 17),
                        BorderSizePixel = 0,
                        TextSize = Library.UI.FontSize,
                        ZIndex = 25,
                        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                        Parent = KeybindModePickerMain
                    })
                    --
                    local Button_4 = Library:CreateObject("TextButton", {
                        FontFace = Library.UI.NewFont,
                        TextColor3 = Color3.fromRGB(0, 0, 0),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Name = "Button_4",
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        BorderSizePixel = 0,
                        TextTransparency = 1,
                        TextSize = Library.UI.FontSize,
                        ZIndex = 25,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        Parent = Inactive
                    })
                    --
                    local UIPadding_48 = Library:CreateObject("UIPadding", {
                        PaddingLeft = UDim.new(0, 8),
                        Parent = Inactive
                    })
                    --
                    Inactive.TextTransparency = 1
                    --
                    do -- Functions
                        function ModeItem:Activate()
                            if not ModeItem.Active then
                                if Keybind.CurrentMode ~= nil then
                                    Keybind.CurrentMode:Deactivate()
                                end
                                --
                                ModeItem.Active = true
                                --
                                Keybind.Mode = Value
                                Keybind.CurrentMode = ModeItem
                                --
                                Inactive.Text = "<b>" .. Value .. "</b>"
                                Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Library.Theme.Default.Accent})
                                --
                                if Value == "Always on" then
                                    if Keybind.Mode == "Always on" then
                                        Keybind:Toggle(true)
                                    end
                                    --
                                    if not Keybind.State then
                                        Keybind.State = true
                                        --
                                        --Library:AddKeybindFrame(Value, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                                    else
                                        --Library:UpdateKeybindFrame(Value, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                                    end
                                elseif Value == "Toggle" then
                                    if Keybind.State then
                                        --Library:UpdateKeybindFrame(Value, Options.Toggle:GetName(), Keybind.Keybind, Options.Toggle:GetSection())
                                    end
                                elseif Value == "On hotkey" then
                                    Keybind.State = false
                                    --
                                    --Library:RemoveKeybindFrame(Options.Toggle:GetName(), Options.Toggle:GetSection())
                                end
                            end
                        end
                        --
                        function ModeItem:Deactivate()
                            if ModeItem.Active then
                                ModeItem.Active = false
                                ModeItem.Hovering = false
                                Inactive.Text = Value
                                Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                            end
                        end
                    end
                    --
                    do -- Connections
                        Library:Connection(Button_4.MouseButton1Click, function()
                            ModeItem:Activate()
                        end)
                        --
                        Library:Connection(Inactive.MouseEnter, function()
                            Inactive.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                            --
                            if ModeItem.Active then return end
                            --
                            Inactive.Text = "<b>" .. Value .. "</b>"
                        end)
                        --
                        Library:Connection(Inactive.MouseLeave, function()
                            Inactive.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                            --
                            if ModeItem.Active then return end
                            --
                            Inactive.Text = Value
                            Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                        end)
                    end
                    --
                    if Value == Keybind.Mode then
                        ModeItem:Activate()
                    end
                end
                --
                Library:Fade(true, Library:GetObjectsTable(KeybindModePickerOutline, true), KeybindModePickerOutline, 0.1)
            end
            --
            function Keybind:RemoveFrame(Fast)
                local Fast = Fast or false
                --
                for Index, Value in Library.UI.ScreenGUI:GetChildren() do
                    if Value:IsA("Frame") and Value.Name == "KeybindModePickerOutline" .. Library.UI.TotalKeybindModes then
                        if Fast then
                            Value:Destroy()
                        else
                            Library:Fade(false, Library:GetObjectsTable(Value, true), Value, 0.1)
                            --
                            task.delay(Library.UI.TweenSpeed, function()
                                Value:Destroy()
                            end)
                        end
                    end
                end
            end
            --
            function Keybind:FindFrame()
                for Index, Value in Library.UI.ScreenGUI:GetChildren() do
                    if Value:IsA("Frame") and Value.Name == "KeybindModePickerOutline" .. Library.UI.TotalKeybindModes then
                        return true
                    end
                end
                --
                return false
            end
            --
            function Keybind:ToggleFrame()
                Library:TweenObject(KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(176, 176, 176)})
                --
                if Library.UI.CurrentSelectedKeybindMode and Library.UI.CurrentSelectedKeybindMode.KeybindObject.Name ~= KeybindObject.Name then
                    Library.UI.CurrentSelectedKeybindMode.Keybind:RemoveFrame()
                    --
                    Library:TweenObject(Library.UI.CurrentSelectedKeybindMode.KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(117, 117, 117)})
                end
                --
                if not Keybind:FindFrame() then
                    Keybind.ActiveFrame = true
                    Keybind:AddFrame()
                else
                    Keybind.ActiveFrame = false
                    Keybind:RemoveFrame()
                end
            end
        end
        --
        do -- Connections
            Library:Connection(KeybindObject.MouseEnter, function()
                if Keybind.SelectingKeybind then return end
                --
                Library:TweenObject(KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(176, 176, 176)})
            end)
            --
            Library:Connection(KeybindObject.MouseLeave, function()
                if Keybind.SelectingKeybind then return end
                --
                Library:TweenObject(KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(117, 117, 117)})
            end)
            --
            Library:Connection(Button_4.MouseButton2Click, function()
                if not Options.UseMode then return end
                --
                Keybind:ToggleFrame()
            end)
            --
            Library:Connection(Button_4.MouseButton1Click, function()
                if Keybind.Connection then
                    Keybind.Connection:Disconnect()
                end
                --
                Keybind.SelectingKeybind = true
                --
                Library:TweenObject(KeybindObject, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(255, 0, 0)})
                --
                Keybind.Connection = Library:Connection(UserInputService.InputBegan, function(Input)
                    Keybind:Set(Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode or Input.UserInputType)
                    --
                    if Keybind.Connection then
                        Keybind.Connection:Disconnect()
                        --
                        task.delay(0.1, function()
                            Keybind.Connection = nil
                            Keybind.SelectingKeybind = false
                        end)
                    end
                end)
            end)
            --
            Library:Connection(UserInputService.InputBegan, function(Input, Proccessed)
                if Proccessed then return end
                --
                if (Input.UserInputType == Enum.UserInputType.Keyboard and Keybind.Keybind ~= "[-]" and Input.KeyCode == Keybind.RegKeybind) or (Input.UserInputType == Enum.UserInputType.MouseButton1 and Keybind.Keybind == "MB1") or (Input.UserInputType == Enum.UserInputType.MouseButton2 and Keybind.Keybind == "MB2") or (Input.UserInputType == Enum.UserInputType.MouseButton3 and Keybind.Keybind == "MMB") then
                    if Keybind.Mode == "Always on" then
                        Keybind:Toggle(true)
                    else
                        Keybind:Toggle()
                    end
                end
            end)
            --
            Library:Connection(UserInputService.InputEnded, function(Input, Proccessed)
                if Proccessed then return end
                --
                if Keybind.Mode == "On hotkey" then
                    if (Input.UserInputType == Enum.UserInputType.Keyboard and Keybind.Keybind ~= "[-]" and Input.KeyCode == Keybind.RegKeybind) or (Input.UserInputType == Enum.UserInputType.MouseButton1 and Keybind.Keybind == "MB1") or (Input.UserInputType == Enum.UserInputType.MouseButton2 and Keybind.Keybind == "MB2") or (Input.UserInputType == Enum.UserInputType.MouseButton3 and Keybind.Keybind == "MMB") then
                        Keybind:Toggle()
                    end
                end
            end)
        end
        --
        if Options.Hiding then
            Keybind:SetVisible(false)
        end
        --
        return Keybind
    end
    function Library:MultiBox(Options)
        Options = Library:Validate({
            Default = "None",
            Name = "Preview MultiBox",
            Content = {},
            Parent = nil,
            MainUI = nil,
            Hiding = false,
            TabUI = nil,
            Risky = false,
            Flag = Library.NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local MultiBox = {
            Open = false,
            Hover = false,
            Items = Options.Content,
            Scrollable = false,
            Value = {},
            SelectedOrder = {},
            AllItems = {},
        }
        --
        Library.Flags[Options.Flag] = MultiBox
        Options.Callback(Options.Default)
        --
        local PreviewMultiBox_5 = Library:CreateObject("Frame", {
            Name = "PreviewMultiBox_5",
            BackgroundTransparency = 1,
            Size = Options.Name == "" and UDim2.new(1, 0, 0, 20) or UDim2.new(1, 0, 0, 31),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local MultiBoxOutline_5 = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(0, 1),
            Name = "MultiBoxOutline_5",
            Position = UDim2.new(0, -1, 1, 0),
            Size = UDim2.new(1, -19, 0, 20),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewMultiBox_5
        })
        --
        local MultiBoxChecker = Library:CreateObject("Frame", {
            Name = "MultiBoxChecker",
            Position = UDim2.new(0, 0, 1, 0),
            Visible = false,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 0, 1),
            BorderSizePixel = 0,
            Parent = MultiBoxOutline_5
        })
        --
        local MultiBoxBack_5 = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "MultiBoxBack_5",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(220, 220, 220),
            Parent = MultiBoxOutline_5
        })
        --
        local MultiBoxArrow = Library:CreateObject("ImageLabel", {
            ImageColor3 = Color3.fromRGB(151, 151, 151),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "MultiBoxArrow",
            Image = "rbxassetid://15556784588",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -11, 0, 6),
            Size = UDim2.new(0, 5, 0, 4),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = MultiBoxBack_5
        })
        --
        local UIGradient_34 = Library:CreateObject("UIGradient", {
            Rotation = -90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 39, 39)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35))
            },
            Parent = MultiBoxBack_5
        })
        --
        local MultiBoxValue_5 = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(152, 152, 152),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = "None",
            Name = "MultiBoxValue_5",
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 3,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = MultiBoxBack_5
        })
        --
        local UIPadding_87 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 5),
            Parent = MultiBoxValue_5
        })
        --
        local Button_44 = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "Button_44",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            TextSize = 14,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = MultiBoxOutline_5
        })
        --
        local MultiBoxName_5 = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Library.Theme.Default.TextColor,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = Options.Name,
            Name = "MultiBoxName_5",
            ZIndex = 3,
            Size = UDim2.new(1, -19, 1, 0),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, -4),
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewMultiBox_5
        })
        --
        local UIPadding_88 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = PreviewMultiBox_5
        })
        --
        local MultiBoxMainOutline = Library:CreateObject("Frame", {
            Name = "MultiBoxMainOutline",
            Position = UDim2.new(0, 0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 10,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = Library.UI.ScreenGUI
        })
        --
        local MultiBoxMain = Library:CreateObject("Frame", {
            Name = "MultiBoxMain",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, -2, 1, -2),
            BorderSizePixel = 0,
            ZIndex = 10,
            ClipsDescendants = true,
            BackgroundColor3 = Color3.fromRGB(35, 35, 35),
            Parent = MultiBoxMainOutline
        })
        --
        MultiBoxMainOutline.BackgroundTransparency = 1
        MultiBoxMain.BackgroundTransparency = 1
        --
        local UIListLayout_9 = Library:CreateObject("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = MultiBoxMain
        })
        --
        do -- Functions
            function MultiBox:Set(Values)
                for Index, Item in MultiBox.AllItems do
                    if not table.find(Values, Index) then
                        MultiBox.Items[Index] = false
                    else
                        MultiBox.Items[Index] = true
                    end
                    --
                    Item:Toggle()
                end
            end
            --
            function MultiBox:Get()
                return MultiBox.Value
            end
            --
            function MultiBox:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewMultiBox_5]
                --
                MultiBox.Hiding = not Bool
                --
                if Bool then
                    Library.Objects[PreviewMultiBox_5] = {PreviewMultiBox_5, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewMultiBox_5), PreviewMultiBox_5, 0.075)
                Library:TweenObject(PreviewMultiBox_5, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and (Options.Name == "" and UDim2.new(1, 0, 0, 20) or UDim2.new(1, 0, 0, 31)) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewMultiBox_5] = {PreviewMultiBox_5, OldValues[2], false}
                    end
                end)
            end
            --
            function MultiBox:AddValue(Value)
                local Item = {
                    Active = false,
                    Hovering = false,
                }
                --
                MultiBox.Items[Value] = Item
                --
                local Inactive = Library:CreateObject("TextLabel", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(208, 208, 208),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = Value,
                    Text = Value,
                    RichText = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, 0, 0, 20),
                    BorderSizePixel = 0,
                    TextSize = Library.UI.FontSize,
                    ZIndex = 10,
                    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                    Parent = MultiBoxMain
                })
                --
                local Button_4 = Library:CreateObject("TextButton", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "Button_4",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    TextTransparency = 1,
                    TextSize = Library.UI.FontSize,
                    ZIndex = 11,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = Inactive
                })
                --
                local UIPadding_48 = Library:CreateObject("UIPadding", {
                    PaddingLeft = UDim.new(0, 8),
                    Parent = Inactive
                })
                --
                Inactive.TextTransparency = 1
                --
                do -- Functions
                    function Item:GetSelectedItems()
                        local SelectedItems = {}
                        --
                        for _, Item in MultiBox.SelectedOrder do
                            if MultiBox.Items[Item] then
                                table.insert(SelectedItems, Item)
                            end
                        end
                        --
                        return SelectedItems
                    end
                    --
                    function MultiBox:UpdateValue()
                        MultiBox.Value = Item:GetSelectedItems()
                        --
                        MultiBoxValue_5.Text = Library:ClampString(table.concat(MultiBox.Value, ", "), MultiBoxMain.AbsoluteSize.X - MultiBoxArrow.AbsoluteSize.X - 4)
                    end
                    --
                    function Item:SelectItem(Item)
                        if not table.find(MultiBox.SelectedOrder, Item) then
                            table.insert(MultiBox.SelectedOrder, Item)
                        end
                        --
                        MultiBox:UpdateValue()
                    end

                    function Item:DeselectItem(Item)
                        for Index, Value in MultiBox.SelectedOrder do
                            if Value == Item then
                                table.remove(MultiBox.SelectedOrder, Index)
                                --
                                break
                            end
                        end
                        --
                        MultiBox:UpdateValue()
                    end
                    --
                    function Item:Activate()
                        if not Item.Active then
                            Item.Active = true
                            MultiBox.CurrentItem = Item
                            MultiBox.Items[Value] = true
                            Library.Flags[Options.Flag] = MultiBox
                            Item:SelectItem(Value)
                            Options.Callback(MultiBox.Value)
                            --
                            Inactive.Text = "<b>" .. Value .. "</b>"
                            Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Library.Theme.Default.Accent})
                            Library:AddTheme(Inactive, {
                                TextColor3 = "Accent",
                            })
                        end
                    end
                    --
                    function Item:Deactivate()
                        if Item.Active then
                            Item.Active = false
                            Item.Hovering = false
                            MultiBox.CurrentItem = nil
                            Library.Flags[Options.Flag] = MultiBox
                            MultiBox.Items[Value] = false
                            Item:DeselectItem(Value)
                            Options.Callback(MultiBox.Value)
                            --
                            Inactive.Text = Value
                            Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                            Library:AddTheme(Inactive, {
                                TextColor3 = "TextColor",
                            })
                        end
                    end
                    --
                    function Item:Toggle()
                        MultiBox.Items[Value] = not MultiBox.Items[Value]
                        --
                        if MultiBox.Items[Value] then
                            Item:Activate()
                        else
                            Item:Deactivate()
                        end
                    end
                end
                --
                do -- Connections
                    Library:Connection(Button_4.MouseButton1Click, function()
                        if MultiBox.Hiding then return end
                        --
                        Item:Toggle()
                    end)
                    --
                    Library:Connection(Inactive.MouseEnter, function()
                        Inactive.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                        --
                        if Item.Active then return end
                        --
                        Inactive.Text = "<b>" .. Value .. "</b>"
                    end)
                    --
                    Library:Connection(Inactive.MouseLeave, function()
                        Inactive.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                        --
                        if Item.Active then return end
                        --
                        Inactive.Text = Value
                        Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                    end)
                end
                --
                if typeof(Options.Default) == "table" and table.find(Options.Default, Value) then
                    Item:Activate()
                    Item:SelectItem(Value)
                else
                    MultiBox.Items[Value] = false
                end
            end
            --
            function MultiBox:Toggle(Fast)
                local Fast = Fast or false
                local OldValues = Library.Objects[MultiBoxMainOutline]
                --
                if MultiBox.Open then
                    if Fast then
                        Library:Fade(false, Library:GetObjectsTable(MultiBoxMainOutline, true), MultiBoxMainOutline, 0)
                        MultiBoxMainOutline.Size = UDim2.new(0, MultiBoxOutline_5.AbsoluteSize.X, 0, 0)
                        Library.Objects[MultiBoxMainOutline] = {MultiBoxMainOutline, OldValues[2], true}
                    else
                        Library:Fade(false, Library:GetObjectsTable(MultiBoxMainOutline, true), MultiBoxMainOutline, 0.1)
                        Library:TweenObject(MultiBoxMainOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, MultiBoxOutline_5.AbsoluteSize.X, 0, 0)}, function()
                            Library.Objects[MultiBoxMainOutline] = {MultiBoxMainOutline, OldValues[2], true}
                        end)
                    end
                else
                    Library.Objects[MultiBoxMainOutline] = {MultiBoxMainOutline, OldValues[2], false}
                    --
                    if Fast then
                        Library:Fade(true, Library:GetObjectsTable(MultiBoxMainOutline, true), MultiBoxMainOutline, 0)
                        MultiBoxMainOutline.Size = UDim2.new(0, MultiBoxOutline_5.AbsoluteSize.X, 0, (#Options.Content * 20) + 2)
                    else
                        Library:Fade(true, Library:GetObjectsTable(MultiBoxMainOutline, true), MultiBoxMainOutline, 0.1)
                        Library:TweenObject(MultiBoxMainOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, MultiBoxOutline_5.AbsoluteSize.X, 0, (#Options.Content * 20) + 2)})
                    end	
                end
                --
                MultiBox.Open = not MultiBox.Open
            end
            --
            function MultiBox:Update()
                MultiBoxMainOutline.Size = UDim2.new(0, MultiBoxOutline_5.AbsoluteSize.X, 0, MultiBoxMainOutline.AbsoluteSize.Y)
                MultiBoxMainOutline.Position = UDim2.new(0, MultiBoxOutline_5.AbsolutePosition.X, 0, ((MultiBoxOutline_5.AbsolutePosition.Y + MultiBoxOutline_5.AbsoluteSize.Y) + GuiService:GetGuiInset().Y + 2))
                --
                if MultiBox.Open then
                    MultiBoxMainOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), MultiBoxChecker)
                end
            end
            --
            MultiBox:Update()
            --
            Library:Connection(MultiBoxOutline_5:GetPropertyChangedSignal("AbsolutePosition"), MultiBox.Update)
            Library:Connection(MultiBoxOutline_5:GetPropertyChangedSignal("AbsoluteSize"), MultiBox.Update)
            --
            local StartingX = PreviewMultiBox_5.AbsolutePosition.X
            local StartingY = PreviewMultiBox_5.AbsolutePosition.Y
            local MainUIStartingX = Options.MainUI.AbsolutePosition.X
            local MainUIStartingY = Options.MainUI.AbsolutePosition.Y
            local StartingCanvasPosition = gsCanvasOf(Options.Parent)
            --
            Library:Connection(PreviewMultiBox_5:GetPropertyChangedSignal("AbsolutePosition"), function()
                if not MultiBox.Open then return end
                --
                local CurrentX = PreviewMultiBox_5.AbsolutePosition.X
                local CurrentY = PreviewMultiBox_5.AbsolutePosition.Y
                local MainUICurrentX = Options.MainUI.AbsolutePosition.X
                local MainUICurrentY = Options.MainUI.AbsolutePosition.Y
                local CurrentCanvasPosition = gsCanvasOf(Options.Parent)
                --
                if MainUICurrentX ~= MainUIStartingX or MainUICurrentY ~= MainUIStartingY then
                    MainUIStartingX = MainUICurrentX
                    MainUIStartingY = MainUICurrentY
                    StartingX = CurrentX
                    StartingY = CurrentY
                    --
                    return
                end
                --
                if CurrentCanvasPosition ~= StartingCanvasPosition then
                    StartingCanvasPosition = CurrentCanvasPosition
                    StartingX = CurrentX
                    StartingY = CurrentY
                    --
                    return
                end
                --
                if Library.UI.Resizing then
                    return
                end
                --
                if CurrentX ~= StartingX or CurrentY ~= StartingY then
                    MultiBox:Toggle(true)
                end
                --
                StartingX = CurrentX
                StartingY = CurrentY
            end)
            --
            if gsFindScroller(Options.Parent) then
                Library:Connection(gsFindScroller(Options.Parent):GetPropertyChangedSignal("CanvasPosition"), function()
                    MultiBox:Update()
                end)
            end
        end
        --
        do -- Connections
            Library:Connection(Button_44.MouseButton1Click, function()
                if MultiBox.Hiding then return end
                --
                MultiBox:Toggle()
            end)
            --
            Library:Connection(MultiBoxOutline_5.MouseEnter, function()
                if Library.UI.Faded then return end
                --
                if not MultiBox.Open then
                    MultiBox.Hovering = true
                    Library:TweenObject(MultiBoxBack_5, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
                end	
            end)
            --
            Library:Connection(MultiBoxOutline_5.MouseLeave, function()
                if Library.UI.Faded then return end
                --
                if not MultiBox.Open then
                    MultiBox.Hovering = false
                    Library:TweenObject(MultiBoxBack_5, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(220, 220, 220)})
                end	
            end)
        end
        --
        for Index, Value in Options.Content do
            if typeof(Value) == "boolean" or typeof(Value) == "table" then continue end
            --
            MultiBox:AddValue(Value)
        end
        --
        Library:Fade(false, Library:GetObjectsTable(MultiBoxMainOutline, true), MultiBoxMainOutline, 0.1)
        --
        if Options.Hiding then
            MultiBox:SetVisible(false)
        end
        --
        MultiBox:Toggle(true)
        --
        return MultiBox
    end
    function Library:Dropdown(Options)
        Options = Library:Validate({
            Default = "None",
            Name = "Preview Dropdown",
            Content = {},
            Parent = nil,
            MainUI = nil,
            Hiding = false,
            TabUI = nil,
            Risky = false,
            Flag = Library.NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local Dropdown = {
            Open = false,
            Active = false,
            Hovering = false,
            CurrentItem = nil,
            Scrollable = false,
            Hiding = false,
            Items = {},
            Value = Options.Default,
        }
        --
        Library.Flags[Options.Flag] = Dropdown
        --
        local PreviewDropdown_5 = Library:CreateObject("Frame", {
            Name = "PreviewDropdown_5",
            BackgroundTransparency = 1,
            Size = Options.Name == "" and UDim2.new(1, 0, 0, 20) or UDim2.new(1, 0, 0, 31),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local DropdownOutline_5 = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(0, 1),
            Name = "DropdownOutline_5",
            Position = UDim2.new(0, -1, 1, 0),
            Size = UDim2.new(1, -19, 0, 20),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewDropdown_5
        })
        --
        local DropdownChecker = Library:CreateObject("Frame", {
            Name = "DropdownChecker",
            Position = UDim2.new(0, 0, 1, 0),
            Visible = false,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 0, 1),
            BorderSizePixel = 0,
            Parent = DropdownOutline_5
        })
        --
        local DropdownBack_5 = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "DropdownBack_5",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(220, 220, 220),
            Parent = DropdownOutline_5
        })
        --
        local DropdownArrow = Library:CreateObject("ImageLabel", {
            ImageColor3 = Color3.fromRGB(151, 151, 151),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "DropdownArrow",
            Image = "rbxassetid://15556784588",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -11, 0, 6),
            Size = UDim2.new(0, 5, 0, 4),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = DropdownBack_5
        })
        --
        local UIGradient_34 = Library:CreateObject("UIGradient", {
            Rotation = -90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 39, 39)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35))
            },
            Parent = DropdownBack_5
        })
        --
        local DropdownValue_5 = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(152, 152, 152),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = Options.Default ~= "None" and table.find(Options.Content, Options.Default) and Options.Default or "None",
            Name = "DropdownValue_5",
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 3,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = DropdownBack_5
        })
        --
        local UIPadding_87 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 5),
            Parent = DropdownValue_5
        })
        --
        local Button_44 = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "Button_44",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            TextSize = 14,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = DropdownOutline_5
        })
        --
        local DropdownName_5 = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Library.Theme.Default.TextColor,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = Options.Name,
            Name = "DropdownName_5",
            ZIndex = 3,
            Position = UDim2.new(0, 0, 0, -4),
            Size = UDim2.new(1, -19, 1, 0),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewDropdown_5
        })
        --
        local UIPadding_88 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = PreviewDropdown_5
        })
        --
        local DropdownMainOutline = Library:CreateObject("Frame", {
            Name = "DropdownMainOutline",
            Position = UDim2.new(0, 0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 10,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = Library.UI.ScreenGUI
        })
        --
        local DropdownMain = Library:CreateObject("Frame", {
            Name = "DropdownMain",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, -2, 1, -2),
            BorderSizePixel = 0,
            ZIndex = 10,
            ClipsDescendants = true,
            BackgroundColor3 = Color3.fromRGB(35, 35, 35),
            Parent = DropdownMainOutline
        })
        --
        DropdownMainOutline.BackgroundTransparency = 1
        DropdownMain.BackgroundTransparency = 1
        --
        local UIListLayout_9 = Library:CreateObject("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = DropdownMain
        })
        --
        do -- Functions
            function Dropdown:Set(State)
                for Index, Value in Dropdown.Items do
                    if Index == State then
                        Value:Activate()
                    else
                        Value:Deactivate()
                    end
                end
            end
            --
            function Dropdown:Get()
                return Dropdown.Value
            end
            --
            function Dropdown:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewDropdown_5]
                --
                Dropdown.Hiding = not Bool
                --
                if Bool then
                    Library.Objects[PreviewDropdown_5] = {PreviewDropdown_5, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewDropdown_5), PreviewDropdown_5, 0.075)
                Library:TweenObject(PreviewDropdown_5, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and (Options.Name == "" and UDim2.new(1, 0, 0, 20) or UDim2.new(1, 0, 0, 31)) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewDropdown_5] = {PreviewDropdown_5, OldValues[2], false}
                    end
                end)
            end
            --
            function Dropdown:AddValue(Value)
                local Item = {
                    Active = false,
                    Hovering = false,
                }
                --
                Dropdown.Items[Value] = Item
                --
                local Inactive = Library:CreateObject("TextLabel", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(208, 208, 208),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = Value,
                    Text = Value,
                    RichText = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, 0, 0, 20),
                    BorderSizePixel = 0,
                    TextSize = Library.UI.FontSize,
                    ZIndex = 10,
                    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                    Parent = DropdownMain
                })
                --
                local Button_4 = Library:CreateObject("TextButton", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "Button_4",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    TextTransparency = 1,
                    TextSize = Library.UI.FontSize,
                    ZIndex = 10,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = Inactive
                })
                --
                local UIPadding_48 = Library:CreateObject("UIPadding", {
                    PaddingLeft = UDim.new(0, 8),
                    Parent = Inactive
                })
                --
                Inactive.TextTransparency = 1
                --
                do -- Functions
                    function Item:Activate()
                        if not Item.Active then
                            if Dropdown.CurrentItem ~= nil then
                                Dropdown.CurrentItem:Deactivate()
                            end
                            --
                            Item.Active = true
                            Dropdown.CurrentItem = Item
                            Dropdown.Value = Value
                            Library.Flags[Options.Flag] = Dropdown
                            Options.Callback(Value)
                            DropdownValue_5.Text = Value
                            --
                            Inactive.Text = "<b>" .. Value .. "</b>"
                            Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Library.Theme.Default.Accent})
                            Library:AddTheme(Inactive, {
                                TextColor3 = "Accent",
                            })
                        end
                    end
                    --
                    function Item:Deactivate()
                        if Item.Active then
                            Item.Active = false
                            Item.Hovering = false
                            Inactive.Text = Value
                            Inactive.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                            Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                            Library:AddTheme(Inactive, {
                                TextColor3 = "TextColor",
                            })
                        end
                    end
                end
                --
                do -- Connections
                    Library:Connection(Button_4.MouseButton1Click, function()
                        if Dropdown.Hiding then return end
                        --
                        Item:Activate()
                        Dropdown:Toggle()
                    end)
                    --
                    Library:Connection(Inactive.MouseEnter, function()
                        Inactive.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                        --
                        if Item.Active then return end
                        --
                        Inactive.Text = "<b>" .. Value .. "</b>"
                    end)
                    --
                    Library:Connection(Inactive.MouseLeave, function()
                        Inactive.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                        --
                        if Item.Active then return end
                        --
                        Inactive.Text = Value
                        Library:TweenObject(Inactive, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(205, 205, 205)})
                    end)
                end
                --
                if Value == Options.Default then
                    Item:Activate()
                end
            end
            --
            function Dropdown:Toggle(Fast)
                local Fast = Fast or false
                local OldValues = Library.Objects[DropdownMainOutline]
                --
                if Dropdown.Open then
                    if Fast then
                        Library:Fade(false, Library:GetObjectsTable(DropdownMainOutline, true), DropdownMainOutline, 0)
                        DropdownMainOutline.Size = UDim2.new(0, DropdownOutline_5.AbsoluteSize.X, 0, 0)
                        Library.Objects[DropdownMainOutline] = {DropdownMainOutline, OldValues[2], true}
                    else
                        Library:Fade(false, Library:GetObjectsTable(DropdownMainOutline, true), DropdownMainOutline, 0.1)
                        Library:TweenObject(DropdownMainOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, DropdownOutline_5.AbsoluteSize.X, 0, 0)}, function()
                            Library.Objects[DropdownMainOutline] = {DropdownMainOutline, OldValues[2], true}
                        end)
                    end
                else
                    Library.Objects[DropdownMainOutline] = {DropdownMainOutline, OldValues[2], false}
                    --
                    if Fast then
                        Library:Fade(true, Library:GetObjectsTable(DropdownMainOutline, true), DropdownMainOutline, 0)
                        DropdownMainOutline.Size = UDim2.new(0, DropdownOutline_5.AbsoluteSize.X, 0, (#Options.Content * 20) + 2)
                    else
                        Library:Fade(true, Library:GetObjectsTable(DropdownMainOutline, true), DropdownMainOutline, 0.1)
                        Library:TweenObject(DropdownMainOutline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, DropdownOutline_5.AbsoluteSize.X, 0, (#Options.Content * 20) + 2)})
                    end	
                end
                --
                Dropdown.Open = not Dropdown.Open
            end
            --
            function Dropdown:Update()
                DropdownMainOutline.Size = UDim2.new(0, DropdownOutline_5.AbsoluteSize.X, 0, DropdownMainOutline.AbsoluteSize.Y)
                DropdownMainOutline.Position = UDim2.new(0, DropdownOutline_5.AbsolutePosition.X, 0, ((DropdownOutline_5.AbsolutePosition.Y + DropdownOutline_5.AbsoluteSize.Y) + GuiService:GetGuiInset().Y + 2))
                --
                if Dropdown.Open then
                    DropdownMainOutline.Visible = Library:ScrollingCheck(gsFindScroller(Options.Parent), DropdownChecker)
                end
            end
            --
            Dropdown:Update()
            --
            Library:Connection(DropdownOutline_5:GetPropertyChangedSignal("AbsolutePosition"), Dropdown.Update)
            Library:Connection(DropdownOutline_5:GetPropertyChangedSignal("AbsoluteSize"), Dropdown.Update)
            --
            local StartingX = PreviewDropdown_5.AbsolutePosition.X
            local StartingY = PreviewDropdown_5.AbsolutePosition.Y
            local MainUIStartingX = Options.MainUI.AbsolutePosition.X
            local MainUIStartingY = Options.MainUI.AbsolutePosition.Y
            local StartingCanvasPosition = gsCanvasOf(Options.Parent)
            --
            Library:Connection(PreviewDropdown_5:GetPropertyChangedSignal("AbsolutePosition"), function()
                if not Dropdown.Open then return end
                --
                local CurrentX = PreviewDropdown_5.AbsolutePosition.X
                local CurrentY = PreviewDropdown_5.AbsolutePosition.Y
                local MainUICurrentX = Options.MainUI.AbsolutePosition.X
                local MainUICurrentY = Options.MainUI.AbsolutePosition.Y
                local CurrentCanvasPosition = gsCanvasOf(Options.Parent)
                --
                if MainUICurrentX ~= MainUIStartingX or MainUICurrentY ~= MainUIStartingY then
                    MainUIStartingX = MainUICurrentX
                    MainUIStartingY = MainUICurrentY
                    StartingX = CurrentX
                    StartingY = CurrentY
                    --
                    return
                end
                --
                if CurrentCanvasPosition ~= StartingCanvasPosition then
                    StartingCanvasPosition = CurrentCanvasPosition
                    StartingX = CurrentX
                    StartingY = CurrentY
                    --
                    return
                end
                --
                if Library.UI.Resizing then
                    return
                end
                --
                if CurrentX ~= StartingX or CurrentY ~= StartingY then
                    Dropdown:Toggle(true)
                end
                --
                StartingX = CurrentX
                StartingY = CurrentY
            end)
            --
            if gsFindScroller(Options.Parent) then
                Library:Connection(gsFindScroller(Options.Parent):GetPropertyChangedSignal("CanvasPosition"), function()
                    Dropdown:Update()
                end)
            end
        end
        --
        do -- Connections
            Library:Connection(Button_44.MouseButton1Click, function()
                if Dropdown.Hiding then return end
                --
                Dropdown:Toggle()
            end)
            --
            Library:Connection(DropdownOutline_5.MouseEnter, function()
                if Library.UI.Faded then return end
                --
                if not Dropdown.Open then
                    Dropdown.Hovering = true
                    Library:TweenObject(DropdownBack_5, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
                end	
            end)
            --
            Library:Connection(DropdownOutline_5.MouseLeave, function()
                if Library.UI.Faded then return end
                --
                if not Dropdown.Open then
                    Dropdown.Hovering = false
                    Library:TweenObject(DropdownBack_5, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(220, 220, 220)})
                end	
            end)
        end
        --
        for _, Value in Options.Content do
            Dropdown:AddValue(Value)
        end
        --
        Library:Fade(false, Library:GetObjectsTable(DropdownMainOutline, true), DropdownMainOutline, 0.1)
        --
        if Options.Hiding then
            Dropdown:SetVisible(false)
        end
        --
        Dropdown:Toggle(true)
        --
        return Dropdown
    end
    function Library:Slider(Options)
        Options = Library:Validate({
            Name = "Preview Slider",
            Min = 0,
            Max = 100,
            Default = 1,
            Decimal = 1,
            UseIcons = true,
            Ending = "",
            Disable = {},
            Hidden = false,
            Risky = false,
            Parent = nil,
            OverrideLimit = false, -- new parameter to allow values beyond max
            Flag = Library.NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local Slider = {
            MouseDown = false,
            Hiding = false,
            Hovering = false,
            Connection = nil,
            CurrentValue = -9999,
            LeftControlDown = false,
        }
        --
        Library.Flags[Options.Flag] = Slider
        --
        local PreviewSlider = Library:CreateObject("Frame", {
            Name = "PreviewSlider",
            BackgroundTransparency = 1,
            Size = Options.Name == "" and UDim2.new(1, 0, 0, 7) or UDim2.new(1, 0, 0, 20),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local SliderOutline = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(0, 1),
            Name = "SliderOutline",
            Position = UDim2.new(0, -1, 1, 0),
            Size = UDim2.new(1, -19, 0, 7),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewSlider
        })
        --
        local SliderBack = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "SliderBack",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(205, 205, 205),
            Parent = SliderOutline
        })
        --
        local UIGradient_2 = Library:CreateObject("UIGradient", {
            Rotation = -90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(81, 81, 81)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(68, 68, 68))
            },
            Parent = SliderBack
        })
        --
        local SliderDrag = Library:CreateObject("Frame", {
            Name = "Slider",
            Size = UDim2.new(0.5, 0, 1, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = SliderBack
        })
        --
        local UIGradient_3 = Library:CreateObject("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Library.Theme.Default.Accent),
                ColorSequenceKeypoint.new(1, Library.Theme.Default.SecondAccent)
            },
            Parent = SliderDrag
        })
        --
        Library:AddTheme(UIGradient_3, {
            Color = {"Accent", "SecondAccent"},
        })
        --
        local Button_4 = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "Button_4",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = SliderOutline
        })
        --
        local SliderName = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Options.Risky and Library.Theme.Default.Risky or Library.Theme.Default.TextColor,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = Options.Name,
            Name = "SliderName",
            ZIndex = 3,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewSlider
        })
        --
        if Options.Risky then
            Library:AddTheme(SliderName, {
                TextColor3 = "Risky",
            })
        end
        --
        local UIPadding_3 = Library:CreateObject("UIPadding", {
            PaddingTop = UDim.new(0, -4),
            PaddingLeft = UDim.new(0, 20),
            Parent = PreviewSlider
        })
        --
        local SliderValue = Library:CreateObject("TextBox", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(198, 198, 198),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = Options.Default,
            Name = "SliderValue",
            ZIndex = 3,
            AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.new(0, 100, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            BorderSizePixel = 0,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextSize = Library.UI.FontSize,
            TextStrokeTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = SliderDrag
        })
        --
        local AddButton = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(1, 1),
            Name = "AddButton",
            Position = UDim2.new(1, -13, 1, -3),
            Size = UDim2.new(0, 3, 0, 1),
            ZIndex = 3,
            BorderSizePixel = 0,
            Visible = Options.UseIcons,
            BackgroundColor3 = Color3.fromRGB(100, 100, 100),
            Parent = PreviewSlider
        })
        --
        local AddButton2 = Library:CreateObject("Frame", {
            Size = UDim2.new(0, 1, 0, 3),
            Name = "AddButton2",
            Position = UDim2.new(0, 1, 0, -1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            Visible = Options.UseIcons,
            BackgroundColor3 = Color3.fromRGB(100, 100, 100),
            Parent = AddButton
        })
        --
        local AddActualButton = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "AddActualButton",
            TextTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Size = UDim2.new(0, 11, 0, 7),
            Visible = Options.UseIcons,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -9, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 3,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewSlider
        })
        --
        local MinusActualButton = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "MinusActualButton",
            TextTransparency = 1,
            Visible = Options.UseIcons,
            AnchorPoint = Vector2.new(0, 1),
            Size = UDim2.new(0, 11, 0, 7),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, -12, 1, 0),
            BorderSizePixel = 0,
            ZIndex = 3,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewSlider
        })
        --
        local MinusButton = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(0, 1),
            Name = "MinusButton",
            Visible = Options.UseIcons,
            Position = UDim2.new(0, -8, 1, -3),
            Size = UDim2.new(0, 3, 0, 1),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(100, 100, 100),
            Parent = PreviewSlider
        })
        --
        local function GetValue(Value)
            return typeof(Value) == "string" and Value or ("%.14g"):format(Value)
        end
        --
        local function SetValue(Value, IgnoreLimit)
            if (not Value) or Slider.Hiding then return end
            --
            local OriginalValue = Value
            -- check if we should allow values beyond the max
            if Options.OverrideLimit and IgnoreLimit then
                -- allow any value (still enforce min and decimal rounding)
                Value = Value and math.max(Options.Decimal * math.round(tonumber(Value) / Options.Decimal), Options.Min) or 0
            else
                -- default behavior: clamp between min and max
                Value = Value and math.clamp(Options.Decimal * math.round(tonumber(Value) / Options.Decimal), Options.Min, Options.Max) or 0
            end
            
            local ValueText = Options.Disable[1] and ((Value <= Options.Disable[2] or Value >= Options.Disable[3]) and Options.Disable[1]) or tostring(GetValue(Value)) .. Options.Ending
            --
            SliderValue.Text = "<b>" .. ValueText .. "</b>"
            --
            if Value ~= Slider.CurrentValue then
                Slider.CurrentValue = Value
                --
                -- always display the slider within bounds, even if the value is beyond max
                local DisplayValue = math.min(Value, Options.Max)
                Library:TweenObject(SliderDrag, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new((DisplayValue - Options.Min) / (Options.Max - Options.Min), 0, 1, 0)})
                --
                SliderValue.Size = UDim2.fromOffset(SliderValue.TextBounds.X, SliderValue.TextBounds.Y)
                SliderValue.Position = UDim2.new(1, SliderValue.TextBounds.X / 2, 0, -4)
            end
            --
            Library.Flags[Options.Flag] = Slider
            Options.Callback(tonumber(GetValue(Value)))
        end
        --
        SetValue(Options.Default)
        --
        function Slider:Get()
            return tonumber(GetValue(Slider.CurrentValue))
        end
        --
        function Slider:Max()
            return Options.Max
        end
        --
        function Slider:Min()
            return Options.Min
        end
        --
        function Slider:Set(Value)
            if not Value then return end
            --
            SetValue(Value, Options.OverrideLimit) -- allow overriding limits for api calls too
        end
        --
        function Slider:GetName()
            return Options.Name
        end
        --
        function Slider:SetVisible(Bool)
            local OldValues = Library.Objects[PreviewSlider]
            --
            Slider.Hiding = not Bool
            SliderValue.Visible = Bool
            --
            if Bool then
                Library.Objects[PreviewSlider] = {PreviewSlider, OldValues[2], true}
            end
            --
            Library:Fade(Bool, Library:GetObjectsTable(PreviewSlider), PreviewSlider, 0.075)
            Library:TweenObject(PreviewSlider, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and (Options.Name == "" and UDim2.new(1, 0, 0, 7) or UDim2.new(1, 0, 0, 20)) or UDim2.new(1, 0, 0, -10)}, function()
                if not Bool then
                    Library.Objects[PreviewSlider] = {PreviewSlider, OldValues[2], false}
                end
            end)
        end
        --
        local function SlideBar(Input)
            local SizeX = (Input.Position.X - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X
            local Value = math.clamp((Options.Max - Options.Min) * SizeX + Options.Min, Options.Min, Options.Max)
            --
            SetValue(Value)
        end
        --
        do -- Connections
            Library:Connection(SliderOutline.MouseEnter, function()
                if Library.UI.Faded then return end
                --
                Library:TweenObject(SliderBack, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
            end)
            --
            Library:Connection(SliderOutline.MouseLeave, function()
                if Library.UI.Faded then return end
                --
                Library:TweenObject(SliderBack, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(205, 205, 205)})
            end)
            --
            Library:Connection(MinusActualButton.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                Slider:Set(Slider.CurrentValue - Options.Decimal)
            end)
            --
            Library:Connection(AddActualButton.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                Slider:Set(Slider.CurrentValue + Options.Decimal)
            end)
            --
            Library:Connection(Button_4.MouseButton1Down, function()
                if Library.UI.Faded then return end
                --
                Library.UI.DraggingGui = SliderDrag
                Slider.MouseDown = true
                SlideBar({Position = UserInputService:GetMouseLocation()})
            end)
            --
            Library:Connection(SliderValue.FocusLost, function()
                local NewValue = tonumber(SliderValue.Text)
                --
                if NewValue then
                    SetValue(NewValue, Options.OverrideLimit) -- pass true to allow exceeding max
                else
                    SetValue(Options.Min)
                end
            end)
            --
            Library:Connection(UserInputService.InputChanged, function(Input)
                if Library.UI.Faded then return end
                --
                if Library.UI.DraggingGui ~= SliderDrag and not (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
                    return
                end
                --
                if Slider.MouseDown and Input.UserInputType == Enum.UserInputType.MouseMovement then
                    SlideBar(Input)
                end
            end)
            --
            Library:Connection(UserInputService.InputEnded, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Slider.MouseDown = false
                end
            end)
        end
        --
        if Options.Hidden then
            Slider:SetVisible(false)
        end
        --
        return Slider
    end
    function Library:Toggle(Options)
        Options = Library:Validate({
            Default = false,
            Name = "Preview Toggle",
            Risky = false,
            SectionName = nil,
            Parent = nil,
            Hidden = false,
            AnchorPoint = Vector2.new(0, 0),
            MainUI = nil,
            Size = UDim2.new(1, 0, 0, 8),
            Position = UDim2.new(0, 0, 0, 0),
            UseToggleOutline = false,
            ZIndex = 2,
            Flag = Library:NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local Toggle = {
            Active = false,
            Hovering = false,
            State = false,
            Hiding = false,
            MainUI = Options.MainUI,
            TabUI = Options.TabUI,
            ColorPickers = {},
            KeybindState = false,
        }
        --
        Library.Flags[Options.Flag] = Toggle
        --
        local PreviewToggle = Library:CreateObject("Frame", {
            Name = "PreviewToggle",
            BackgroundTransparency = 1,
            Size = Options.Size,
            Position = Options.Position,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Options.AnchorPoint,
            ZIndex = Options.ZIndex or 2,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local ToggleOutline = Library:CreateObject("Frame", {
            Name = "ToggleOutline",
            Size = UDim2.new(0, 8, 0, 8),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = Options.ZIndex or 2,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewToggle
        })
        --
        if Options.UseToggleOutline then
            ToggleOutline.AnchorPoint = Options.AnchorPoint
            ToggleOutline.Position = Options.Position
        end
        --
        local ToggleInline = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "ToggleInline",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = Options.ZIndex or 2,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(227, 227, 227),
            Parent = ToggleOutline
        })
        --
        local UIGradient_3 = Library:CreateObject("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(84, 84, 84)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(74, 74, 74))
            },
            Parent = ToggleInline
        })
        --
        local ToggleMain = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "ToggleInline",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = Options.ZIndex or 2,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ToggleOutline
        })
        --
        Library.Objects[ToggleMain] = {ToggleMain, {BackgroundTransparency = ToggleMain.BackgroundTransparency}, false}
        --
        local UIGradient_32 = Library:CreateObject("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Library.Theme.Default.Accent),
                ColorSequenceKeypoint.new(1, Library.Theme.Default.SecondAccent)
            },
            Parent = ToggleMain
        })
        --
        Library:AddTheme(UIGradient_32, {
            Color = {"Accent", "SecondAccent"},
        })
        --
        local ToggleName = Library:CreateObject("TextLabel", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "ToggleName",
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = Options.ZIndex or 2,
            FontFace = Library.UI.NewFont,
            RichText = true,
            Text = Options.Name,
            TextColor3 = Options.Risky and Library.Theme.Default.Risky or Library.Theme.Default.TextColor,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewToggle
        })
        --
        if Options.Risky then
            Library:AddTheme(ToggleName, {
                TextColor3 = "Risky",
            })
        end
        --
        local UIPadding_7 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = ToggleName
        })
        --
        local Button_9 = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "Button_9",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewToggle
        })
        --
        do -- Functions
            function Toggle:ToggleGUI(Bool)
                if Bool == nil then
                    Toggle.State = not Toggle.State
                else
                    Toggle.State = Bool
                end
                --
                Library:TweenObject(ToggleMain, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = Toggle.State and 0 or 1})
                
                -- update the stored transparency value in the objects table, this is for the temp fix for the toggle out and toggle in 
                -- since this uses instant out and instant in instead of the normal fade in and fade out
                if Library.Objects[ToggleMain] then
                    Library.Objects[ToggleMain][2].BackgroundTransparency = Toggle.State and 0 or 1
                end
                
                --
                Library.Flags[Options.Flag] = Toggle
                Options.Callback(Toggle.State)
            end
            --
            function Toggle:GetName()
                return Options.Name
            end
            --
            function Toggle:GetFlag()
                return Options.Flag
            end
            --
            function Toggle:GetSection()
                return Options.SectionName
            end
            --
            function Toggle:GetState()
                return Toggle.State
            end
            --
            function Toggle:GetCallback(b)
                Options.Callback(b)
            end
            --
            function Toggle:Set(Value)
                Toggle:ToggleGUI(Value)
            end
            --
            function Toggle:SetName(Name)
                Options.Name = Name
                ToggleName.Text = Name
            end
            --
            function Toggle:Get()
                return Toggle.State
            end
            --
            function Toggle:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewToggle]
                --
                Toggle.Hiding = not Bool
                --
                if Bool then
                    Library.Objects[PreviewToggle] = {PreviewToggle, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewToggle), PreviewToggle, 0.075)
                Library:TweenObject(PreviewToggle, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and UDim2.new(1, 0, 0, 8) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewToggle] = {PreviewToggle, OldValues[2], false}
                    end
                end)
            end
            --
            function Toggle:ColorPicker(Options)
                Options = Library:Validate({
                    Name = "Preview Color Picker",
                    Default = Library.Theme.Default.Accent,
                    Flag = Library.NewFlag(),
                    Alpha = 0,
                    AlphaBar = true,
                    Callback = function() end,
                }, Options or {})
                --
                local ColorPicker = {}
                --
                Toggle.ColorPickers[#Toggle.ColorPickers + 1] = ColorPicker
                --
                local ColorPickerFrame = Library:ColorPicker({
                    Name = Options.Name,
                    Default = Options.Default,
                    Flag = Options.Flag,
                    Alpha = Options.Alpha,
                    AlphaBar = Options.AlphaBar,
                    MainUI = Toggle.MainUI,
                    TabUI = Toggle.TabUI,
                    Callback = Options.Callback,
                    Parent = PreviewToggle,
                    Keybind = Toggle.KeybindState,
                    Count = #Toggle.ColorPickers,
                })
                --
                return ColorPickerFrame
            end
            --
            function Toggle:Keybind(Options)
                Options = Library:Validate({
                    Default = Enum.KeyCode.Backspace,
                    Mode = "Toggle",
                    UseMode = true,
                    HideFromList = false,
                    Blacklisted = {},
                    Hiding = false,
                    ChangeToggle = false,
                    Flag = Library.NewFlag(),
                    Callback = function() end,
                }, Options or {})
                --
                local Keybind = {}
                --
                Toggle.KeybindState = true
                --
                Library:Keybind({
                    Default = Options.Default,
                    Mode = Options.Mode,
                    HideFromList = Options.HideFromList,
                    Blacklisted = Options.Blacklisted,
                    Parent = PreviewToggle,
                    UseMode = Options.UseMode,
                    Toggle = Toggle,
                    MainUI = Toggle.MainUI,
                    TabUI = Toggle.TabUI,
                    Hiding = Options.Hiding,
                    ToggleState = Toggle.State,
                    ChangeToggle = Options.ChangeToggle,
                    Flag = Options.Flag,
                    Callback = Options.Callback,
                    Count = #Toggle.ColorPickers + 1,
                })
                --
                return Keybind
            end
        end
        --
        do -- Connections
            Library:Connection(PreviewToggle.MouseEnter, function()
                if Library.UI.Faded then return end
                --
                Library:TweenObject(ToggleInline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
            end)
            --
            Library:Connection(PreviewToggle.MouseLeave, function()
                if Library.UI.Faded then return end
                --
                Library:TweenObject(ToggleInline, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(227, 227, 227)})
            end)
            --
            Library:Connection(Button_9.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                if Toggle.Hiding then return end
                --
                Toggle:ToggleGUI()
            end)
        end
        --
        Toggle:ToggleGUI(Options.Default)
        --
        if Options.Hidden then
            Toggle:SetVisible(false)
        end
        --
        return Toggle
    end
    function Library:Label(Options)
        Options = Library:Validate({
            Message = "Preview Label",
            Side = "Left",
            Risky = false,
            Parent = nil,
            MainUI = nil,
            SectionName = nil,
            Hidden = false,
            TabUI = nil,
            Callback = function() end
        }, Options or {})
        --
        local Label = {
            ColorPickers = {},
            KeybindState = false,
            Hiding = false,
            MainUI = Options.MainUI,
            TabUI = Options.TabUI,
            State = true,
        }
        --
        local PreviewLabel = Library:CreateObject("Frame", {
            Name = "PreviewLabel",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 7),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 2,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local LabelText = Library:CreateObject("TextLabel", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "ToggleName",
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment[Options.Side],
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, -1),
            ZIndex = 2,
            FontFace = Library.UI.NewFont,
            RichText = true,
            Text = Options.Message,
            TextColor3 = Color3.fromRGB(198, 198, 198),
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = PreviewLabel
        })
        --
        local UIPadding_7 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = LabelText
        })
        --
        do -- Functions
            function Label:GetName()
                return Options.Message
            end
            --
            function Label:GetState()
                return Label.State
            end
            --
            function Label:GetSection()
                return Options.SectionName
            end
            --
            function Label:GetCallback(Bool)
                Options.Callback(Bool)
            end
            --
            function Label:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewLabel]
                --
                Label.Hiding = not Bool
                --
                if Bool then
                    Library.Objects[PreviewLabel] = {PreviewLabel, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewLabel), PreviewLabel, 0.075)
                Library:TweenObject(PreviewLabel, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and UDim2.new(1, 0, 0, 8) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewLabel] = {PreviewLabel, OldValues[2], false}
                    end
                end)
            end
            --
            function Label:ColorPicker(Options)
                Options = Library:Validate({
                    Name = "Preview Color Picker",
                    Default = Library.Theme.Default.Accent,
                    Flag = Library.NewFlag(),
                    Alpha = 0,
                    AlphaBar = true,
                    MainUI = nil,
                    Callback = function() end,
                }, Options or {})
                --
                local ColorPicker = {}
                --
                Label.ColorPickers[#Label.ColorPickers + 1] = ColorPicker
                --
                local ColorPickerFrame = Library:ColorPicker({
                    Name = Options.Name,
                    Default = Options.Default,
                    Flag = Options.Flag,
                    Alpha = Options.Alpha,
                    AlphaBar = Options.AlphaBar,
                    MainUI = Label.MainUI,
                    TabUI = Label.TabUI,
                    Callback = Options.Callback,
                    Parent = PreviewLabel,
                    Keybind = Label.KeybindState,
                    Count = #Label.ColorPickers,
                })
                --
                return ColorPickerFrame
            end
            --
            function Label:Keybind(Options)
                Options = Library:Validate({
                    Default = Enum.KeyCode.Backspace,
                    Mode = "Toggle",
                    UseMode = true,
                    HideFromList = false,
                    Blacklisted = {},
                    Hiding = false,
                    Flag = Library.NewFlag(),
                    Callback = function() end,
                }, Options or {})
                --
                local Keybind = {}
                --
                Label.KeybindState = true
                --
                Library:Keybind({
                    Default = Options.Default,
                    Mode = Options.Mode,
                    HideFromList = Options.HideFromList,
                    Blacklisted = Options.Blacklisted,
                    Parent = PreviewLabel,
                    Toggle = Label,
                    UseMode = Options.UseMode,
                    MainUI = Label.MainUI,
                    TabUI = Label.TabUI,
                    Hiding = Options.Hiding,
                    ToggleState = Label.State,
                    Flag = Options.Flag,
                    Callback = Options.Callback,
                    Count = #Label.ColorPickers + 1,
                })
                --
                return Keybind
            end
        end
        --
        if Options.Hidden then
            Label:SetVisible(false)
        end
        --
        return Label
    end
    --
    function Library:TextBox(Options)
        Options = Library:Validate({
            Default = "",
            Name = "Preview TextBox",
            Max = 32,
            Parent = nil,
            Size = UDim2.new(1, 0, 0, 19),
            Position = UDim2.new(0, 0, 0, 0),
            NumbersOnly = false,
            ClearOnFocus = false,
            Hidden = false,
            TypedCheck = false,
            CheckIfPressedEnter = false,
            Risky = false,
            Flag = Library.NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local TextBox = {
            Focused = false,
            Hovering = false,
            Hiding = false,
        }
        --
        Library.Flags[Options.Flag] = TextBox
        --
        local PreviewTextBox = Library:CreateObject("Frame", {
            Name = "PreviewTextBox",
            BackgroundTransparency = 1,
            Size = Options.Size,
            Position = Options.Position,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local TextBoxOutline = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "TextBoxOutline",
            Position = UDim2.new(0, -1, 0, 0),
            Size = UDim2.new(1, -19, 0, 19),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewTextBox
        })
        --
        local TextBoxInline = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "TextBoxInline",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            Parent = TextBoxOutline
        })
        --
        local TextBoxMain = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "TextBoxMain",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            Parent = TextBoxInline
        })
        --
        local TextBoxObject = Library:CreateObject("TextBox", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Library.Theme.Default.TextColor,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = "",
            ZIndex = 3,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            SelectionStart = 1,
            ClearTextOnFocus = Options.ClearOnFocus,
            PlaceholderColor3 = Library.Theme.Default.TextColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            PlaceholderText = "_",
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = TextBoxMain
        })
        --
        TextBox.Object = TextBoxObject
        --
        local UIPadding_6 = Library:CreateObject("UIPadding", {
            PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 5),
            Parent = TextBoxObject
        })
        --
        local UIPadding_7 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = PreviewTextBox
        })
        --
        do -- Functions
            function TextBox:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewTextBox]
                --
                TextBox.Hiding = not Bool
                TextBoxObject.Visible = Bool
                --
                if Bool then
                    Library.Objects[PreviewTextBox] = {PreviewTextBox, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewTextBox), PreviewTextBox, 0.075)
                Library:TweenObject(PreviewTextBox, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and Options.Size or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewTextBox] = {PreviewTextBox, OldValues[2], false}
                    end
                end)
            end
            --
            function TextBox:Get()
                return TextBoxObject.Text
            end
        end
        --
        do -- Connections
            Library:Connection(TextBoxObject:GetPropertyChangedSignal("Text"), function()
                TextBoxObject.Text = TextBoxObject.Text:sub(1, Options.Max)
                --
                if Options.NumbersOnly then
                    TextBoxObject.Text = TextBoxObject.Text:gsub('[^%d%.%-]+', '')
                end
                --
                if Options.TypedCheck then
                    Library.Flags[Options.Flag] = TextBox
                    Options.Callback(TextBoxObject.Text)
                end
                --
                TextBox.Focused = true
            end)
            --
            Library:Connection(TextBoxObject.Focused, function()
                if Library.UI.Faded then return end
                --
                if TextBox.Hiding then
                    TextBoxObject:ReleaseFocus()
                    --
                    return
                end
                --
                TextBox.Focused = true
                --
                TextBoxObject.TextColor3 = Library.Theme.Default.Accent
                --
                Library:AddTheme(TextBoxObject, {
                    TextColor3 = "Accent",
                })
                --
                TextBoxObject.PlaceholderText = ""
            end)
            --
            Library:Connection(TextBoxObject.FocusLost, function(EnterPressed)
                if Options.CheckIfPressedEnter and not EnterPressed then return end
                --
                TextBox.Focused = false
                TextBoxObject.PlaceholderText = "_"
                --
                TextBoxObject.TextColor3 = Library.Theme.Default.TextColor
                --
                Library:AddTheme(TextBoxObject, {
                    TextColor3 = "TextColor",
                })
                --
                Library.Flags[Options.Flag] = TextBox
                Options.Callback(TextBoxObject.Text)
            end)
        end
        --
        if Options.Hidden then
            TextBox:SetVisible(false)
        end
        --
        return TextBox
    end
    function Library:List(Options)
        Options = Library:Validate({
            Size = 100,
            Hidden = false,
            Flag = Library.NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local List = {
            CurrentValue = nil,
            CurrentValueName = nil,
        }
        --
        Library.Flags[Options.Flag] = List
        --
        local PreviewList = Library:CreateObject("Frame", {
            Name = "PreviewList",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Options.Size),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local UIPadding_11 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = PreviewList
        })
        --
        local ListOutline = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -19, 1, -18),
            Name = "ListOutline",
            Position = UDim2.new(0, -1, 0, 18),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewList
        })
        --
        local ListMain = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "ListMain",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 4,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(35, 35, 35),
            Parent = ListOutline
        })
        --
        local DownArrow = Library:CreateObject("ImageButton", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "DownArrow",
            Image = "rbxassetid://15540867448",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -10, 1, -9),
            Size = UDim2.new(0, 5, 0, 4),
            ZIndex = 7,
            Visible = false,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ListMain
        })
        --
        local UpArrow = Library:CreateObject("ImageButton", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "UpArrow",
            Image = "rbxassetid://15540851994",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -10, 0, 5),
            Size = UDim2.new(0, 5, 0, 4),
            ZIndex = 7,
            Visible = false,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ListMain
        })
        --
        local ListScrolling = Library:CreateObject("ScrollingFrame", {
            ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65),
            MidImage = "rbxassetid://158362264",
            Active = true,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ScrollBarThickness = 5,
            Name = "ListScrolling",
            ZIndex = 3,
            TopImage = "rbxassetid://158362264",
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
            BottomImage = "rbxassetid://158362264",
            CanvasSize = UDim2.new(0, 0, 0, 0),
            CanvasPosition = Vector2.new(0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            Parent = ListOutline
        })
        --
        local UIListLayout_2 = Library:CreateObject("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ListScrolling
        })
        --
        local TextBox = Library:TextBox({Parent = PreviewList, TypedCheck = true, Size = UDim2.new(1, 20, 0, 19), Position = UDim2.new(0, -20, 0, 0), Callback = function(Text)
            List:UpdateSection()
            --
            for _, Frame in ListScrolling:GetChildren() do
                if Frame:IsA("Frame") then
                    Frame.Visible = string.find(Frame.Name:lower(), Text:lower()) and true or false
                end
            end
        end})
        --
        do -- Functions
            function List:Get()
                return List.CurrentValueName
            end
            --
            function List:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewList]
                --
                TextBox.Object.Visible = Bool
                --
                if Bool then
                    Library.Objects[PreviewList] = {PreviewList, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewList, false), PreviewList, 0.075)
                Library:TweenObject(PreviewList, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and UDim2.new(1, 0, 0, Options.Size) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewList] = {PreviewList, OldValues[2], false}
                    end
                end)
            end
            --
            function List:AddValue(Value, Icon)
                if ListScrolling:FindFirstChild(Value) then return end
                --
                local ListValue = {
                    Active = false,
                    Hovering = false,
                }
                --
                local InactiveValue = Library:CreateObject("Frame", {
                    Name = Value .. "1",
                    Size = UDim2.new(1, 0, 0, 20),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    ZIndex = 5,
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                    Parent = ListScrolling
                })
                --
                local Button_912 = Library:CreateObject("TextButton", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(0, 0, 0),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "Button_9",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    BorderSizePixel = 0,
                    TextTransparency = 1,
                    TextSize = Library.UI.FontSize,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = InactiveValue
                })
                --
                local ValueName_1 = Library:CreateObject("TextLabel", {
                    FontFace = Library.UI.NewFont,
                    TextColor3 = Color3.fromRGB(208, 208, 208),
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    Name = "ValueName_1",
                    BorderSizePixel = 0,
                    Text = Value,
                    RichText = true,
                    BackgroundTransparency = 1,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 5,
                    TextSize = Library.UI.FontSize,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Parent = InactiveValue
                })
                --
                if Icon then
                    local Color = Icon.Color or Color3.fromRGB(255, 255, 255)
                    --
                    local IconImage = Library:CreateObject("ImageLabel", {
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Image = Icon.Image,
                        AnchorPoint = Vector2.new(0, 0.5),
                        Position = Icon.Position or UDim2.new(0, 7, 0.5, 0),
                        BackgroundTransparency = 1,
                        Name = "BackImage",
                        Size = Icon.Size or UDim2.new(0, 13, 0, 13),
                        ZIndex = 5,
                        BorderSizePixel = 0,
                        ImageColor3 = Color,
                        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                        Parent = InactiveValue
                    })
                    --
                    local UIPadding_135 = Library:CreateObject("UIPadding", {
                        PaddingLeft = UDim.new(0, 10),
                        Parent = IconImage
                    })
                end
                --
                ValueName_1.Text = Library:ClampString(Value, ValueName_1.AbsoluteSize.X - 25)
                --
                local UIPadding_13 = Library:CreateObject("UIPadding", {
                    PaddingLeft = UDim.new(0, (Icon and 25 or 10)),
                    Parent = ValueName_1
                })
                --
                do -- Functions
                    function ListValue:Activate()
                        if not ListValue.Active then
                            --
                            if List.CurrentValue then
                                List.CurrentValue:Deactivate()
                            end
                            --
                            ListValue.Active = true
                            --
                            ValueName_1.TextColor3 = Library.Theme.Default.Accent
                            ValueName_1.Text = "<b>" .. Value .. "</b>"
                            --
                            Library:AddTheme(ValueName_1, {
                                TextColor3 = "Accent",
                            })
                            --
                            List.CurrentValue = ListValue
                            List.CurrentValueName = Value
                            Library.Flags[Options.Flag] = List
                            Options.Callback(Value)
                        end
                    end
                    --
                    function ListValue:Deactivate()
                        if ListValue.Active then
                            ListValue.Active = false
                            ListValue.Hovering = false
                            ValueName_1.TextColor3 = Library.Theme.Default.TextColor
                            --
                            Library:AddTheme(ValueName_1, {
                                TextColor3 = "TextColor",
                            })
                        end
                    end
                end
                --
                do -- Connections
                    local OldText = ValueName_1.Text
                    --
                    Library:Connection(PreviewList:GetPropertyChangedSignal("AbsoluteSize"), function()
                        ValueName_1.Text = Library:ClampString(Value, ValueName_1.AbsoluteSize.X - 25)
                    end)
                    --
                    Library:Connection(InactiveValue.MouseEnter, function()
                        if Library.UI.Faded then return end
                        --
                        InactiveValue.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                        OldText = ValueName_1.Text
                        --
                        if not ListValue.Active then
                            ValueName_1.Text = "<b>" .. OldText .. "</b>"
                        end
                    end)
                    --
                    Library:Connection(InactiveValue.MouseLeave, function()
                        if Library.UI.Faded then return end
                        --
                        InactiveValue.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                        --
                        if not ListValue.Active then
                            ValueName_1.Text = OldText
                        end
                    end)
                    --
                    Library:Connection(Button_912.MouseButton1Click, function()
                        if Library.UI.Faded then return end
                        --
                        ListValue:Activate()
                    end)
                end
            end
            --
            function List:RemoveValue(Value)
                for _, Object in ListScrolling:GetChildren() do
                    if Object.Name == Value .. "1" then
                        Object:Destroy()
                    end
                end
            end
            --
            function List:UpdateSection()
                local CanvasSize = ListScrolling.AbsoluteCanvasSize.Y
                local AbsoluteSize = ListMain.AbsoluteSize.Y
                --
                if CanvasSize > AbsoluteSize then
                    ListMain.Size = UDim2.new(1, -8, 1, -2)
                    UpArrow.Visible = not List:CheckArrows("Up")
                    DownArrow.Visible = not List:CheckArrows("Down")
                elseif CanvasSize == AbsoluteSize then
                    ListMain.Size = UDim2.new(1, -2, 1, -2)
                    UpArrow.Visible = false
                    DownArrow.Visible = false
                end
            end
            --
            function List:CheckArrows(Type)
                if Type == "Up" then
                    return ListScrolling.CanvasPosition == Vector2.new(0, 0)
                elseif Type == "Down" then
                    return ListScrolling.CanvasPosition == Vector2.new(0, ListScrolling.AbsoluteCanvasSize.Y - ListScrolling.AbsoluteSize.Y)
                else
                    return false
                end
            end
        end
        --
        List:UpdateSection()
        --
        do -- Connections
            Library:Connection(ListScrolling.ChildAdded, function()
                List:UpdateSection()
            end)
            --
            Library:Connection(ListScrolling.ChildRemoved, function()
                List:UpdateSection()
            end)
            --
            Library:Connection(ListOutline:GetPropertyChangedSignal("AbsoluteSize"), function()
                List:UpdateSection()
            end)
            --
            Library:Connection(ListScrolling:GetPropertyChangedSignal("AbsoluteSize"), function()
                List:UpdateSection()
            end)
            --
            Library:Connection(ListScrolling:GetPropertyChangedSignal("CanvasPosition"), function()
                List:UpdateSection()
            end)
            --
            Library:Connection(UpArrow.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                if not UpArrow.Visible then return end
                --
                Library:TweenObject(ListScrolling, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(0, 0)})
            end)
            --
            Library:Connection(DownArrow.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                if not DownArrow.Visible then return end
                --
                Library:TweenObject(ListScrolling, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(0, ListScrolling.AbsoluteCanvasSize.Y - ListScrolling.AbsoluteSize.Y)})
            end)
        end
        --
        if Options.Hidden then
            List:SetVisible(false)
        end
        --
        return List
    end
    --
    function Library:Button(Options)
        Options = Library:Validate({
            Name = "Preview Button",
            Confirmation = false,
            Risky = false,
            Parent = nil,
            Hidden = false,
            Flag = Library:NewFlag(),
            Callback = function() end
        }, Options or {})
        --
        local Button = {
            Hovering = false,
            Hiding = false,
            Confirming = false,
        }
        --
        Library.Flags[Options.Flag] = Button
        --
        local PreviewButton = Library:CreateObject("Frame", {
            Name = "PreviewButton1",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 19),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = Options.Parent
        })
        --
        local UIPadding_31 = Library:CreateObject("UIPadding", {
            PaddingLeft = UDim.new(0, 20),
            Parent = PreviewButton
        })
        --
        local ButtonOutline = Library:CreateObject("Frame", {
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "ButtonOutline1",
            Position = UDim2.new(0, -1, 0, 0),
            Size = UDim2.new(1, -19, 0, 19),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            Parent = PreviewButton
        })
        --
        local ButtonInline = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "ButtonInline1",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            Parent = ButtonOutline
        })
        --
        local ButtonMain = Library:CreateObject("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Name = "ButtonMain1",
            Position = UDim2.new(0, 1, 0, 1),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            ZIndex = 3,
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            Parent = ButtonInline
        })
        --
        local ButtonName = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Options.Risky and Library.Theme.Default.Risky or Library.Theme.Default.TextColor,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = Options.Name,
            Name = "ButtonName1",
            ZIndex = 4,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ButtonMain
        })
        --
        if Options.Risky then
            Library:AddTheme(ButtonName, {
                TextColor3 = "Risky",
            })
        end
        --
        local ButtonClick = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Name = "ButtonClick1",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            TextTransparency = 1,
            ZIndex = 5,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = ButtonMain
        })
        --
        do -- Functions
            function Button:SetVisible(Bool)
                local OldValues = Library.Objects[PreviewButton]
                --
                Button.Hiding = not Bool
                --
                if Bool then
                    Library.Objects[PreviewButton] = {PreviewButton, OldValues[2], true}
                end
                --
                Library:Fade(Bool, Library:GetObjectsTable(PreviewButton), PreviewButton, 0.075)
                Library:TweenObject(PreviewButton, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Bool and UDim2.new(1, 0, 0, 19) or UDim2.new(1, 0, 0, -10)}, function()
                    if not Bool then
                        Library.Objects[PreviewButton] = {PreviewButton, OldValues[2], false}
                    end
                end)
            end
            --
            function Button:GetName()
                return Options.Name
            end
        end
        --
        do -- Connections
            Library:Connection(ButtonMain.MouseEnter, function()
                if Library.UI.Faded then return end
                --
                Button.Hovering = true
                Library:TweenObject(ButtonMain, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)})
            end)
            --
            Library:Connection(ButtonMain.MouseLeave, function()
                if Library.UI.Faded then return end
                --
                Button.Hovering = false
                Library:TweenObject(ButtonMain, TweenInfo.new(Library.UI.TweenSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(24, 24, 24)})
            end)
            --
            Library:Connection(ButtonClick.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                if Button.Hiding then return end
                --
                if Options.Confirmation then
                    if Button.Confirming then
                        Button.Confirming = false
                        ButtonName.Text = Options.Name
                        Options.Callback()
                    else
                        Button.Confirming = true
                        ButtonName.Text = "Are you sure?"
                        --
                        task.delay(3, function()
                            if Button.Confirming then
                                Button.Confirming = false
                                ButtonName.Text = Options.Name
                            end
                        end)
                    end
                else
                    Options.Callback()
                end
            end)
        end
        --
        if Options.Hidden then
            Button:SetVisible(false)
        end
        --
        return Button
    end
    --
    setmetatable(Sections, Library)
    --
    function Library:Notify(Options)
        Options = Library:Validate({
            Message = "Notification",
            Delay = 4,
            Position = "Bottom"
        }, Options or {})
        --
        if not Library.UI.ScreenGUI then return end
        --
        local NotifyHolder = Library.UI.ScreenGUI:FindFirstChild("NotifyHolder1")
        --
        if not NotifyHolder then
            NotifyHolder = Library:CreateObject("Frame", {
                Name = "NotifyHolder1",
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -20),
                Size = UDim2.new(0, 260, 1, -40),
                ZIndex = 2000,
                Parent = Library.UI.ScreenGUI,
            }, true)
            --
            Library:CreateObject("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                VerticalAlignment = Enum.VerticalAlignment.Bottom,
                Padding = UDim.new(0, 5),
                Parent = NotifyHolder,
            })
        end
        --
        local NotifyOutline = Library:CreateObject("Frame", {
            Name = "NotifyOutline1",
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 0, 32),
            ZIndex = 2001,
            BorderSizePixel = 0,
            Parent = NotifyHolder,
        })
        --
        local NotifyInline = Library:CreateObject("Frame", {
            Name = "NotifyInline1",
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 2001,
            BorderSizePixel = 0,
            Parent = NotifyOutline,
        })
        --
        local NotifyAccent = Library:CreateObject("Frame", {
            Name = "NotifyAccent1",
            BackgroundColor3 = Library.Theme.Default.Accent,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(0, 2, 1, 0),
            ZIndex = 2002,
            BorderSizePixel = 0,
            Parent = NotifyInline,
        })
        --
        Library:AddTheme(NotifyAccent, {
            BackgroundColor3 = "Accent",
        })
        --
        local NotifyText = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(205, 205, 205),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = tostring(Options.Message),
            Name = "NotifyText1",
            ZIndex = 2002,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -14, 1, 0),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = NotifyInline,
        })
        --
        NotifyOutline.BackgroundTransparency = 1
        NotifyInline.BackgroundTransparency = 1
        NotifyAccent.BackgroundTransparency = 1
        NotifyText.TextTransparency = 1
        --
        Library:TweenObject(NotifyOutline, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        Library:TweenObject(NotifyInline, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        Library:TweenObject(NotifyAccent, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        Library:TweenObject(NotifyText, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0})
        --
        task.delay(tonumber(Options.Delay) or 4, function()
            if not NotifyOutline.Parent then return end
            --
            Library:TweenObject(NotifyOutline, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            Library:TweenObject(NotifyInline, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            Library:TweenObject(NotifyAccent, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            Library:TweenObject(NotifyText, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {TextTransparency = 1})
            --
            task.wait(0.35)
            NotifyOutline:Destroy()
        end)
    end
    --
    function Library:CreateWatermark()
        if not Library.UI.ScreenGUI then return end
        if Library.UI.Watermark then return end
        --
        local WatermarkOutline = Library:CreateObject("Frame", {
            Name = "WatermarkOutline1",
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 10),
            Size = UDim2.new(0, 130, 0, 22),
            ZIndex = 1500,
            BorderSizePixel = 0,
            Parent = Library.UI.ScreenGUI,
        }, true)
        --
        local WatermarkInline = Library:CreateObject("Frame", {
            Name = "WatermarkInline1",
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 1500,
            BorderSizePixel = 0,
            Parent = WatermarkOutline,
        }, true)
        --
        Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Library.Theme.Default.Accent,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = "<b>" .. tostring(Library.UI.Name) .. "</b>",
            RichText = true,
            Name = "WatermarkText1",
            ZIndex = 1501,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = WatermarkInline,
        }, true)
        --
        Library.UI.Watermark = WatermarkOutline
    end
    --
    function Library:Init()
        if Library.UI.Initialized then return end
        --
        Library.UI.Initialized = true
        --
        Library:CreateWatermark()
        --
        Library:Connection(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
            Camera = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
            --
            if Camera then
                Viewport = Camera.ViewportSize
            end
        end)
    end
    --
    function Library:Unload()
        if Library.Unloaded then return end
        Library.Unloaded = true
        --
        for _, Connection in Library.Connections do
            pcall(function() Connection:Disconnect() end)
        end
        --
        for _, TweenObject in Library.Tweens do
            pcall(function() TweenObject:Cancel() end)
        end
        --
        if Library.UI.ScreenGUI then
            pcall(function() Library.UI.ScreenGUI:Destroy() end)
        end
        --
        Library.Connections = {}
        Library.UI.Initialized = false
        Library.UI.Faded = true
    end
    --
    function Library:Disable()
        Library:Unload()
    end
    --
    function Library:Window(Options)
        Options = Library:Validate({
            Name = "gamesense",
            Size = UDim2.new(0, 700, 0, 612),
            MinResize = Vector2.new(480, 380),
            MaxResize = Vector2.new(1000, 820),
            CloseBind = Enum.KeyCode.Insert
        }, Options or {})
        --
        local MinResize = typeof(Options.MinResize) == "Vector2" and UDim2.new(0, Options.MinResize.X, 0, Options.MinResize.Y) or Options.MinResize
        local MaxResize = typeof(Options.MaxResize) == "Vector2" and UDim2.new(0, Options.MaxResize.X, 0, Options.MaxResize.Y) or Options.MaxResize
        --
        local Window = {
            Tabs = {},
            CurrentTab = nil,
            Visible = true,
            CloseBind = Options.CloseBind,
        }
        --
        local ScreenGuiParent = CoreGui
        --
        local OkGetHui, GetHuiParent = pcall(function()
            return gethui()
        end)
        --
        if OkGetHui and GetHuiParent ~= nil then
            ScreenGuiParent = GetHuiParent
        end
        --
        local ScreenGUI = Library:CreateObject("ScreenGui", {
            Name = "gamesense1",
            ResetOnSpawn = false,
            IgnoreGuiInset = false,
            DisplayOrder = 101,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Parent = ScreenGuiParent,
        }, true)
        --
        Library.UI.ScreenGUI = ScreenGUI
        --
        local WindowSizeX = Options.Size.X.Offset
        local WindowSizeY = Options.Size.Y.Offset
        --
        local MainOutline = Library:CreateObject("Frame", {
            Name = "MainOutline1",
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Position = UDim2.new(0.5, -math.floor(WindowSizeX / 2), 0.5, -math.floor(WindowSizeY / 2)),
            Size = Options.Size,
            ZIndex = 1,
            Active = true,
            BorderSizePixel = 0,
            Parent = ScreenGUI,
        })
        --
        Library.UI.MainUI = MainOutline
        --
        local MainInline = Library:CreateObject("Frame", {
            Name = "MainInline1",
            BackgroundColor3 = Color3.fromRGB(35, 35, 35),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 1,
            BorderSizePixel = 0,
            Parent = MainOutline,
        })
        --
        local MainFrame = Library:CreateObject("Frame", {
            Name = "MainFrame1",
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 1,
            BorderSizePixel = 0,
            Parent = MainInline,
        })
        --
        local AccentTop = Library:CreateObject("Frame", {
            Name = "AccentTop1",
            BackgroundColor3 = Library.Theme.Default.Accent,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 0, 2),
            ZIndex = 2,
            BorderSizePixel = 0,
            Parent = MainFrame,
        })
        --
        Library:AddTheme(AccentTop, {
            BackgroundColor3 = "Accent",
        })
        --
        local TitleLabel = Library:CreateObject("TextLabel", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(205, 205, 205),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = "<b>" .. tostring(Options.Name) .. "</b>",
            RichText = true,
            Name = "TitleLabel1",
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 2),
            Size = UDim2.new(0, 100, 0, 24),
            ZIndex = 2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = MainFrame,
        })
        --
        local TabBar = Library:CreateObject("Frame", {
            Name = "TabBar1",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 110, 0, 2),
            Size = UDim2.new(1, -120, 0, 24),
            ZIndex = 2,
            Parent = MainFrame,
        })
        --
        Library:CreateObject("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
            Parent = TabBar,
        })
        --
        local TabUnderline = Library:CreateObject("Frame", {
            Name = "TabUnderline1",
            BackgroundColor3 = Color3.fromRGB(45, 45, 45),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Position = UDim2.new(0, 0, 0, 28),
            Size = UDim2.new(1, 0, 0, 1),
            ZIndex = 1,
            BorderSizePixel = 0,
            Parent = MainFrame,
        })
        --
        local ContentHolder = Library:CreateObject("Frame", {
            Name = "ContentHolder1",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 38),
            Size = UDim2.new(1, -24, 1, -50),
            ZIndex = 1,
            Parent = MainFrame,
        })
        --
        local ResizeGrip = Library:CreateObject("TextButton", {
            FontFace = Library.UI.NewFont,
            TextColor3 = Color3.fromRGB(120, 120, 120),
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            Text = "g",
            Name = "ResizeGrip1",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -2, 1, -2),
            Size = UDim2.new(0, 16, 0, 16),
            ZIndex = 3,
            AutoButtonColor = false,
            TextSize = Library.UI.FontSize,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Parent = MainInline,
        })
        --
        Library:Resizable(MainOutline, ResizeGrip, MinResize, MaxResize, 1, true, false, nil)
        --
        do -- Window dragging
            local Dragging = false
            local DragStart = nil
            local StartPosition = nil
            --
            Library:Connection(MainFrame.InputBegan, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local Mouse = UserInputService:GetMouseLocation()
                    --
                    if Mouse.Y <= MainFrame.AbsolutePosition.Y + 34 then
                        Dragging = true
                        DragStart = Mouse
                        StartPosition = MainOutline.Position
                    end
                end
            end)
            --
            Library:Connection(MainFrame.InputEnded, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Dragging = false
                end
            end)
            --
            Library:Connection(UserInputService.InputChanged, function(Input)
                if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
                    local Mouse = UserInputService:GetMouseLocation()
                    local Delta = Mouse - DragStart
                    --
                    MainOutline.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
                end
            end)
            --
            Library:Connection(UserInputService.InputEnded, function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Dragging = false
                end
            end)
        end
        --
        local function MakeColumns(ParentFrame)
            local LeftCol = Library:CreateObject("ScrollingFrame", {
                Name = "LeftCol1",
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, -3, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ZIndex = 2,
                Parent = ParentFrame,
            })
            --
            Library:CreateObject("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = LeftCol,
            })
            --
            local RightCol = Library:CreateObject("ScrollingFrame", {
                Name = "RightCol1",
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, -3, 1, 0),
                Position = UDim2.new(0.5, 3, 0, 0),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ZIndex = 2,
                Parent = ParentFrame,
            })
            --
            Library:CreateObject("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = RightCol,
            })
            --
            return LeftCol, RightCol
        end
        --
        local ControlMethods = {
            "Toggle",
            "Slider",
            "Dropdown",
            "MultiBox",
            "Button",
            "Label",
            "TextBox",
            "ColorPicker",
            "Keybind",
            "List",
        }
        --
        local function MakeSection(ColumnFrame, SectionOptions, TabContent)
            local SectionOutline = Library:CreateObject("Frame", {
                Name = "SectionOutline1",
                BackgroundColor3 = Color3.fromRGB(12, 12, 12),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                Size = UDim2.new(1, 0, 0, 30),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 2,
                BorderSizePixel = 0,
                Parent = ColumnFrame,
            })
            --
            Library:CreateObject("UISizeConstraint", {
                MinSize = Vector2.new(0, tonumber(SectionOptions.Size) or 40),
                Parent = SectionOutline,
            })
            --
            local SectionInline = Library:CreateObject("Frame", {
                Name = "SectionInline1",
                BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                Position = UDim2.new(0, 1, 0, 1),
                Size = UDim2.new(1, -2, 1, -2),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 2,
                BorderSizePixel = 0,
                Parent = SectionOutline,
            })
            --
            local SectionMain = Library:CreateObject("Frame", {
                Name = "SectionMain1",
                BackgroundColor3 = Color3.fromRGB(24, 24, 24),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                Position = UDim2.new(0, 1, 0, 1),
                Size = UDim2.new(1, -2, 1, -2),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 2,
                BorderSizePixel = 0,
                Parent = SectionInline,
            })
            --
            local SectionTitle = Library:CreateObject("TextLabel", {
                FontFace = Library.UI.NewFont,
                TextColor3 = Color3.fromRGB(205, 205, 205),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                Text = "<b>" .. tostring(SectionOptions.Name) .. "</b>",
                RichText = true,
                Name = "SectionTitle1",
                BorderSizePixel = 0,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 5),
                Size = UDim2.new(1, -16, 0, 12),
                ZIndex = 3,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = Library.UI.FontSize,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Parent = SectionMain,
            })
            --
            local ContentHolderSection = Library:CreateObject("Frame", {
                Name = "ContentHolder1",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 21),
                Size = UDim2.new(1, 0, 0, 2),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 2,
                Parent = SectionMain,
            })
            --
            Library:CreateObject("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = ContentHolderSection,
            })
            --
            Library:CreateObject("UIPadding", {
                PaddingBottom = UDim.new(0, 6),
                Parent = ContentHolderSection,
            })
            --
            local Section = setmetatable({
                Elements = {
                    Name = SectionTitle,
                    ContentHolder = ContentHolderSection,
                },
                Frame = SectionOutline,
                TabContent = TabContent,
                SectionName = SectionOptions.Name,
            }, Sections)
            --
            for _, MethodName in ControlMethods do
                Section[MethodName] = function(Self, ControlOptions)
                    ControlOptions = ControlOptions or {}
                    ControlOptions.Parent = ContentHolderSection
                    ControlOptions.MainUI = MainOutline
                    ControlOptions.TabUI = TabContent
                    ControlOptions.SectionName = SectionOptions.Name
                    --
                    return Library[MethodName](Library, ControlOptions)
                end
            end
            --
            return Section
        end
        --
        function Window:CreateTab(TabOptions)
            TabOptions = Library:Validate({
                Icon = "",
                Name = "Tab"
            }, TabOptions or {})
            --
            local TabAsset = TabOptions.Icon
            --
            if typeof(TabAsset) == "number" then
                TabAsset = "rbxassetid://" .. tostring(TabAsset)
            end
            --
            local TabIndex = #Window.Tabs + 1
            --
            local Tab = setmetatable({
                Window = Window,
                Index = TabIndex,
                SubItems = {},
                CurrentSubItem = nil,
                HasSubBar = false,
            }, Sections)
            --
            local TabButton = Library:CreateObject("TextButton", {
                FontFace = Library.UI.NewFont,
                TextColor3 = Color3.fromRGB(0, 0, 0),
                BorderColor3 = Color3.fromRGB(45, 45, 45),
                Name = "TabButton1",
                BackgroundColor3 = Color3.fromRGB(32, 32, 32),
                BorderSizePixel = 1,
                Text = "",
                Size = UDim2.new(0, 30, 0, 24),
                ZIndex = 2,
                AutoButtonColor = false,
                TextSize = Library.UI.FontSize,
                LayoutOrder = TabIndex,
                Parent = TabBar,
            })
            --
            local TabIcon = Library:CreateObject("ImageLabel", {
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                Image = tostring(TabAsset),
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 18, 0, 18),
                ZIndex = 2,
                BorderSizePixel = 0,
                ImageColor3 = Color3.fromRGB(150, 150, 150),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                Parent = TabButton,
            })
            --
            local TabActive = Library:CreateObject("Frame", {
                Name = "TabActive1",
                BackgroundColor3 = Library.Theme.Default.Accent,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                Position = UDim2.new(0, 0, 1, -2),
                Size = UDim2.new(1, 0, 0, 2),
                ZIndex = 3,
                Visible = false,
                BorderSizePixel = 0,
                Parent = TabButton,
            })
            --
            Library:AddTheme(TabActive, {
                BackgroundColor3 = "Accent",
            })
            --
            local TabContent = Library:CreateObject("Frame", {
                Name = "TabContent1",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Visible = false,
                ZIndex = 1,
                Parent = ContentHolder,
            })
            --
            local DirectFrame = Library:CreateObject("Frame", {
                Name = "DirectFrame1",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 1,
                Parent = TabContent,
            })
            --
            Tab.Left1, Tab.Right1 = MakeColumns(DirectFrame)
            Tab.DirectFrame = DirectFrame
            Tab.Content = TabContent
            Tab.Button = TabButton
            Tab.Icon = TabIcon
            Tab.ActiveBar = TabActive
            --
            function Tab:SetActive()
                for _, OtherTab in Window.Tabs do
                    OtherTab.Content.Visible = false
                    OtherTab.ActiveBar.Visible = false
                    OtherTab.Icon.ImageColor3 = Color3.fromRGB(150, 150, 150)
                end
                --
                Window.CurrentTab = Tab
                TabContent.Visible = true
                TabActive.Visible = true
                TabIcon.ImageColor3 = Color3.fromRGB(235, 235, 235)
            end
            --
            function Tab:Section(SectionOptions)
                SectionOptions = Library:Validate({
                    Name = "Preview Section",
                    Side = "Left",
                    Fill = false,
                    Size = 40,
                }, SectionOptions or {})
                --
                local ColumnFrame = (SectionOptions.Side == "Right") and Tab.Right1 or Tab.Left1
                --
                return MakeSection(ColumnFrame, SectionOptions, TabContent)
            end
            --
            function Tab:SubSection(SubOptions)
                SubOptions = Library:Validate({
                    Name = "Preview SubSection",
                    Options = {},
                }, SubOptions or {})
                --
                if not Tab.HasSubBar then
                    Tab.HasSubBar = true
                    --
                    Tab.DirectFrame.Visible = false
                    --
                    local SubBarFrame = Library:CreateObject("Frame", {
                        Name = "SubBarFrame1",
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 61),
                        ZIndex = 2,
                        Parent = TabContent,
                    })
                    --
                    local SubBarScroll = Library:CreateObject("ScrollingFrame", {
                        Name = "SubBarScroll1",
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        ScrollBarThickness = 0,
                        ScrollingDirection = Enum.ScrollingDirection.X,
                        CanvasSize = UDim2.new(0, 0, 0, 0),
                        AutomaticCanvasSize = Enum.AutomaticSize.X,
                        ZIndex = 2,
                        Parent = SubBarFrame,
                    })
                    --
                    Library:CreateObject("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Padding = UDim.new(0, 6),
                        Parent = SubBarScroll,
                    })
                    --
                    local SubBarLine = Library:CreateObject("Frame", {
                        Name = "SubBarLine1",
                        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Position = UDim2.new(0, 0, 1, -1),
                        Size = UDim2.new(1, 0, 0, 1),
                        ZIndex = 1,
                        BorderSizePixel = 0,
                        Parent = SubBarFrame,
                    })
                    --
                    Tab.SubBarScroll = SubBarScroll
                end
                --
                local CreatedItems = {}
                --
                for ItemIndex, SubIcon in SubOptions.Options do
                    local SubAsset = SubIcon
                    --
                    if typeof(SubAsset) == "number" then
                        SubAsset = "rbxassetid://" .. tostring(SubAsset)
                    end
                    --
                    local ItemFrame = Library:CreateObject("Frame", {
                        Name = "ItemFrame1",
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 0, 0, 61),
                        Size = UDim2.new(1, 0, 1, -61),
                        Visible = false,
                        ZIndex = 1,
                        Parent = TabContent,
                    })
                    --
                    local SectionItem = setmetatable({
                        Tab = Tab,
                        ItemFrame = ItemFrame,
                        Index = #Tab.SubItems + 1,
                    }, Sections)
                    --
                    SectionItem.Left2, SectionItem.Right2 = MakeColumns(ItemFrame)
                    --
                    local SubButton = Library:CreateObject("TextButton", {
                        FontFace = Library.UI.NewFont,
                        TextColor3 = Color3.fromRGB(0, 0, 0),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Name = "SubButton1",
                        BackgroundTransparency = 1,
                        Text = "",
                        Size = UDim2.new(0, 52, 0, 52),
                        ZIndex = 2,
                        AutoButtonColor = false,
                        TextSize = Library.UI.FontSize,
                        LayoutOrder = SectionItem.Index,
                        Parent = Tab.SubBarScroll,
                    })
                    --
                    local SubIconImage = Library:CreateObject("ImageLabel", {
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Image = tostring(SubAsset),
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new(0.5, 0, 0.5, -6),
                        Size = UDim2.new(0, 26, 0, 26),
                        ZIndex = 2,
                        BorderSizePixel = 0,
                        ImageColor3 = Color3.fromRGB(150, 150, 150),
                        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                        Parent = SubButton,
                    })
                    --
                    local SubName = Library:CreateObject("TextLabel", {
                        FontFace = Library.UI.NewFont,
                        TextColor3 = Color3.fromRGB(130, 130, 130),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Text = tostring(SubOptions.Name),
                        Name = "SubName1",
                        BorderSizePixel = 0,
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0.5, 1),
                        Position = UDim2.new(0.5, 0, 1, -6),
                        Size = UDim2.new(1, 0, 0, 12),
                        ZIndex = 2,
                        TextSize = 11,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        Parent = SubButton,
                    })
                    --
                    local SubActive = Library:CreateObject("Frame", {
                        Name = "SubActive1",
                        BackgroundColor3 = Library.Theme.Default.Accent,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Position = UDim2.new(0, 0, 1, -2),
                        Size = UDim2.new(1, 0, 0, 2),
                        ZIndex = 3,
                        Visible = false,
                        BorderSizePixel = 0,
                        Parent = SubButton,
                    })
                    --
                    Library:AddTheme(SubActive, {
                        BackgroundColor3 = "Accent",
                    })
                    --
                    SectionItem.Button = SubButton
                    SectionItem.IconImage = SubIconImage
                    SectionItem.NameLabel = SubName
                    SectionItem.ActiveBar = SubActive
                    --
                    function SectionItem:Activate()
                        if Tab.CurrentSubItem == SectionItem then return end
                        --
                        for _, OtherItem in Tab.SubItems do
                            OtherItem.ItemFrame.Visible = false
                            OtherItem.ActiveBar.Visible = false
                            OtherItem.IconImage.ImageColor3 = Color3.fromRGB(150, 150, 150)
                            OtherItem.NameLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
                        end
                        --
                        Tab.CurrentSubItem = SectionItem
                        ItemFrame.Visible = true
                        SubActive.Visible = true
                        SubIconImage.ImageColor3 = Color3.fromRGB(235, 235, 235)
                        SubName.TextColor3 = Color3.fromRGB(205, 205, 205)
                    end
                    --
                    function SectionItem:Deactivate()
                        if Tab.CurrentSubItem == SectionItem then
                            Tab.CurrentSubItem = nil
                        end
                        --
                        ItemFrame.Visible = false
                        SubActive.Visible = false
                        SubIconImage.ImageColor3 = Color3.fromRGB(150, 150, 150)
                        SubName.TextColor3 = Color3.fromRGB(130, 130, 130)
                    end
                    --
                    function SectionItem:Section(SectionOptions)
                        SectionOptions = Library:Validate({
                            Name = "Preview Section",
                            Side = "Left",
                            Fill = false,
                            Size = 40,
                        }, SectionOptions or {})
                        --
                        local ColumnFrame = (SectionOptions.Side == "Right") and SectionItem.Right2 or SectionItem.Left2
                        --
                        return MakeSection(ColumnFrame, SectionOptions, ItemFrame)
                    end
                    --
                    Library:Connection(SubButton.MouseButton1Click, function()
                        if Library.UI.Faded then return end
                        --
                        SectionItem:Activate()
                    end)
                    --
                    Tab.SubItems[#Tab.SubItems + 1] = SectionItem
                    CreatedItems[#CreatedItems + 1] = SectionItem
                    --
                    if Tab.CurrentSubItem == nil then
                        SectionItem:Activate()
                    end
                end
                --
                return CreatedItems[1]
            end
            --
            Library:Connection(TabButton.MouseButton1Click, function()
                if Library.UI.Faded then return end
                --
                Tab:SetActive()
            end)
            --
            Window.Tabs[TabIndex] = Tab
            --
            Library.UI.TabIndex = TabIndex
            --
            if Window.CurrentTab == nil then
                Tab:SetActive()
            end
            --
            return Tab
        end
        --
        function Window:SetTab(TabIndex)
            local FoundTab = Window.Tabs[TabIndex]
            --
            if FoundTab then
                FoundTab:SetActive()
            end
        end
        --
        function Window:GetVisible()
            return not Library.UI.Faded
        end
        --
        Library:Connection(UserInputService.InputBegan, function(Input)
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Window.CloseBind and not UserInputService:GetFocusedTextBox() then
                Library:Fade(Library.UI.Faded, Library.Objects, MainOutline, 0.1)
                --
                Window.Visible = not Library.UI.Faded
            end
        end)
        --
        Library.UI.CloseBind = Window.CloseBind
        --
        return setmetatable(Window, Library)
    end
end


-- ============================================================
-- ============ GAMESENSE BRIDGE (адаптер страниц) ============
-- ============================================================
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local GSLib = getgenv().Library

-- ---------- ПАЛИТРА (для кастомных строк/кнопок страниц) ----------
local C_BG       = Color3.fromRGB(16, 14, 24)
local C_SIDE     = Color3.fromRGB(19, 16, 28)
local C_PANEL    = Color3.fromRGB(26, 22, 36)
local C_CTRL     = Color3.fromRGB(31, 27, 42)
local C_CTRL_H   = Color3.fromRGB(40, 34, 54)
local C_STROKE   = Color3.fromRGB(45, 39, 60)
local C_SEL      = Color3.fromRGB(40, 29, 52)
local C_ACCENT   = Color3.fromRGB(153, 196, 39)
local C_RED      = Color3.fromRGB(140, 48, 52)
local C_RED_H    = Color3.fromRGB(165, 58, 62)
local C_TXT      = Color3.fromRGB(236, 233, 242)
local C_GRAY     = Color3.fromRGB(140, 136, 152)
local C_DIM      = Color3.fromRGB(92, 88, 105)

-- ---------- ХЕЛПЕР ----------
local function new(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

-- убрать 4-байтовые UTF-8 символы (эмодзи) — в lib-шрифтах их нет
local function cleanText(s)
    return (tostring(s):gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", ""))
end

-- перенос строк для Label (≈44 символа)
local function wrapLines(text, maxLen)
    local lines = {}
    for para in tostring(text):gmatch("[^\n]+") do
        local cur = ""
        for word in para:gmatch("%S+") do
            if #cur == 0 then
                cur = word
            elseif #cur + 1 + #word <= maxLen then
                cur = cur .. " " .. word
            else
                table.insert(lines, cur)
                cur = word
            end
        end
        if #cur > 0 then table.insert(lines, cur) end
    end
    if #lines == 0 then table.insert(lines, "") end
    return lines
end

-- ---------- SCREENGUI (только тосты; меню рисует gamesense) ----------
pcall(function()
    local old = LP:WaitForChild("PlayerGui"):FindFirstChild("SpermaHubNL")
    if old then old:Destroy() end
end)
local SG = new("ScreenGui", {
    Name = "SpermaHubNL",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 104,
}, LP:WaitForChild("PlayerGui"))

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
        new("UICorner", {CornerRadius = UDim.new(0, 3)}, t)
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

-- ---------- ОКНО GAMESENSE ----------
-- свою пилюлю вотермарки оставляем (создана выше в head), штатную глушим
GSLib.CreateWatermark = function() end

GSWindow = GSLib:Window({
    Name = "SpermaHub",
    Size = UDim2.new(0, 700, 0, 612),
    MinResize = Vector2.new(480, 380),
    MaxResize = Vector2.new(1000, 820),
    CloseBind = Enum.KeyCode.RightShift,
})

-- ---------- КАРТЫ ИКОНОК ----------
-- иконки вкладок-категорий (asset id)
local CAT_ICONS = {
    Combat        = "rbxassetid://18686402989",
    Visuals       = "rbxassetid://18334627891",
    Movement      = "rbxassetid://18205822505",
    Player        = "rbxassetid://18205706952",
    Server        = "rbxassetid://18657040454",
    Miscellaneous = "rbxassetid://15453349637",
}
-- иконки страниц (SubSection bar)
local PAGE_ICONS = {
    ["Combat.Legitbot"]        = "rbxassetid://18686402989",
    ["Combat.Kill Aura"]       = "rbxassetid://18205706952",
    ["Combat.Hitbox"]          = "rbxassetid://18205822505",
    ["Combat.Kill Player"]     = "rbxassetid://18205704829",
    ["Combat.Fling"]           = "rbxassetid://18334625304",
    ["Combat.Spectate"]        = "rbxassetid://18334627891",
    ["Combat.Anti-Aim"]        = "rbxassetid://18334630306",
    ["Combat.Auto Clicker"]    = "rbxassetid://18334626899",
    ["Visuals.Players"]        = "rbxassetid://18334627891",
    ["Visuals.World"]          = "rbxassetid://18657040454",
    ["Movement.Main"]          = "rbxassetid://18205822505",
    ["Movement.Teleport"]      = "rbxassetid://18334625304",
    ["Server.Bypass"]          = "rbxassetid://18334630306",
    ["Server.Server"]          = "rbxassetid://18657040454",
    ["Miscellaneous.Key Binds"]= "rbxassetid://18334626899",
    ["Miscellaneous.Main"]     = "rbxassetid://15453349637",
}

-- ---------- КАТЕГОРИИ / СТРАНИЦЫ / ПАНЕЛИ ----------
Categories = {}
Pages = {}
catSelected = nil
local catTabs = {}

local function addCategoryImpl(title)
    local tab = GSWindow:CreateTab({Icon = CAT_ICONS[title] or "rbxassetid://18686402989"})
    catTabs[title] = tab
    table.insert(Categories, {key = title, tab = tab})
end

local function addPageImpl(cat, icon, title)
    local tab = catTabs[cat]
    local si
    if cat == "Player" then
        -- одна страница: обычные секции прямо на вкладке (без икон-бара)
        si = tab
    else
        si = tab:SubSection({
            Name = title,
            Options = { PAGE_ICONS[cat .. "." .. title] or "rbxassetid://18686402989" },
        })
    end
    local pg = {frame = nil, cat = cat, tab = tab, si = si, title = title, icon = icon}
    pg.col1 = {__page = pg, __side = "Left"}
    pg.col2 = {__page = pg, __side = "Right"}
    table.insert(Pages, pg)
    return pg
end

local function addPanelImpl(col, title)
    local pg = col.__page
    local sec = pg.si:Section({
        Name = title,
        Side = col.__side,
        Fill = false,
        Size = 40,
    })
    return {sec = sec, holder = sec.Elements.ContentHolder}
end

function selectCategory(catKey)
    catSelected = catKey
    for i, c in ipairs(Categories) do
        if c.key == catKey then
            pcall(function() GSWindow:SetTab(i) end)
            break
        end
    end
end

function selectPage(pg)
    if pg and pg.si and pg.si ~= pg.tab then
        pcall(function()
            if pg.si.Activate then pg.si:Activate() end
        end)
    end
end

-- ---------- РЕЕСТР КОНФИГА ----------
local Cfg = {}

-- ---------- КОНТРОЛЫ ----------
-- тумблер
local function addToggleImpl(panel, key, label, default, cb)
    local ctl = panel.sec:Toggle({
        Name = cleanText(label),
        Default = default and true or false,
        Callback = function(s)
            if cb then cb(s) end
        end,
    })
    if key then Cfg[key] = {get = function() return ctl:Get() end, set = function(v) ctl:Set(v and true or false) end} end
    return {set = function(v) ctl:Set(v) end, get = function() return ctl:Get() end}
end

-- слайдер
local function addSliderImpl(panel, key, label, minV, maxV, default, step, cb)
    local ctl = panel.sec:Slider({
        Name = cleanText(label),
        Min = minV,
        Max = maxV,
        Default = default,
        Decimal = step,
        Ending = "",
        Callback = function(v)
            if cb then cb(v) end
        end,
    })
    if key then Cfg[key] = {get = function() return ctl:Get() end, set = function(v) ctl:Set(v) end} end
    return {set = function(v) ctl:Set(v) end, get = function() return ctl:Get() end}
end

-- выпадающий список
local function addDropdownImpl(panel, key, label, options, default, cb)
    local ctl = panel.sec:Dropdown({
        Name = cleanText(label),
        Content = options,
        Default = tostring(default),
        Callback = function(v)
            if cb then cb(v) end
        end,
    })
    if key then Cfg[key] = {get = function() return ctl:Get() end, set = function(v) ctl:Set(tostring(v)) end} end
    return {set = function(v) ctl:Set(tostring(v)) end, get = function() return ctl:Get() end}
end

-- бинд клавиши (Label + attached Keybind; Callback в lib срабатывает при переназначении)
local function addKeybindImpl(panel, key, label, defaultName, cb)
    local lab = panel.sec:Label({Message = cleanText(label)})
    local defKey = Enum.KeyCode.Backspace
    if defaultName then
        pcall(function() defKey = Enum.KeyCode[defaultName] end)
    end
    local kb = lab:Keybind({
        Default = defKey,
        Mode = "Toggle",
        Callback = function(k)
            if cb then cb(k) end
        end,
    })
    local function safeGet()
        local ok, s = pcall(function() return kb:Get() end)
        return ok and s or nil
    end
    if key then Cfg[key] = {get = safeGet, set = function(v)
        if v == nil then return end
        local kc = nil
        pcall(function() kc = Enum.KeyCode[tostring(v)] end)
        if kc then kb:Set(kc) end
    end} end
    return {get = safeGet}
end

-- кнопка
local function addButtonImpl(panel, label, cb, color, hover)
    return panel.sec:Button({
        Name = cleanText(label),
        Risky = (color == C_RED) and true or false,
        Confirmation = (label == "Close Script") and true or false,
        Callback = function()
            if cb then cb() end
        end,
    })
end

-- текст-описание
local function addTextImpl(panel, text)
    for _, line in ipairs(wrapLines(cleanText(text), 44)) do
        panel.sec:Label({Message = line})
    end
end

-- список игроков (gamesense List + деселект по повторному клику)
local function makePlayerListImpl(panel, height)
    local selected = nil
    local lastData = {}
    local onSelectCb = nil
    local listCtl
    listCtl = panel.sec:List({
        Size = height,
        Callback = function(name)
            if selected == name then
                selected = nil
                if listCtl and listCtl.CurrentValue then
                    pcall(function() listCtl.CurrentValue:Deactivate() end)
                end
                if onSelectCb then onSelectCb(nil) end
                return
            end
            selected = name
            if onSelectCb then onSelectCb(name) end
        end,
    })
    local lastNames = {}
    local function rebuild(data)
        if data ~= nil then lastData = data else data = lastData end
        local names = {}
        for _, d in ipairs(data or {}) do
            table.insert(names, d.name)
        end
        for _, n in ipairs(lastNames) do
            if not table.find(names, n) then
                pcall(function() listCtl:RemoveValue(n) end)
            end
        end
        for _, n in ipairs(names) do
            if not table.find(lastNames, n) then
                pcall(function() listCtl:AddValue(n) end)
            end
        end
        lastNames = names
        if selected and not table.find(names, selected) then
            selected = nil
            if onSelectCb then onSelectCb(nil) end
        end
    end
    rebuild({})
    return {
        rebuild = rebuild,
        refresh = function() rebuild(nil) end,
        getSelected = function() return selected end,
        connect = function(cbFn) onSelectCb = cbFn end,
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
-- ДИАГНОСТИКА ПОСТРОЙКИ GUI: ошибка одного контрола НЕ роняет сборку
-- (красные строки [UI-ERR] в консоли покажут точное место)
-- ============================================================
GSBuildErrors = 0

local function uiCall(kind, label, f, ...)
    local args = table.pack(...)
    local ok, res = xpcall(function()
        return f(table.unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
        GSBuildErrors = GSBuildErrors + 1
        warn(("[SpermaHub][UI-ERR] %s '%s': %s"):format(tostring(kind), tostring(label), tostring(res)))
        pcall(function()
            if toastImpl then toastImpl("UI ERR", tostring(kind) .. ": " .. tostring(label)) end
        end)
        return nil
    end
    return res
end

local dummySec = {}
do
    local mt = {__index = function()
        return function()
            return {set = function() end, get = function() return nil end,
                    refresh = function() end, connect = function() end,
                    rebuild = function() end, getSelected = function() return nil end}
        end
    end}
    setmetatable(dummySec, mt)
end
local dummyPanel = {sec = dummySec, holder = nil}
local dummyPage = {cat = nil, si = nil, tab = nil, col1 = nil, col2 = nil}
do
    dummyPage.col1 = {__page = dummyPage, __side = "Left"}
    dummyPage.col2 = {__page = dummyPage, __side = "Right"}
end
local function dummyCtl()
    return {set = function() end, get = function() return nil end,
            refresh = function() end, connect = function() end,
            rebuild = function() end, getSelected = function() return nil end}
end

local function addCategory(title)
    return uiCall("addCategory", title, addCategoryImpl, title)
end

local function addPage(cat, icon, title)
    local label = tostring(cat) .. "." .. tostring(title)
    local r = uiCall("addPage", label, addPageImpl, cat, icon, title)
    if r == nil then
        local pg = {cat = cat, si = nil, tab = nil}
        pg.col1 = {__page = pg, __side = "Left"}
        pg.col2 = {__page = pg, __side = "Right"}
        if type(Pages) == "table" then table.insert(Pages, pg) end
        return pg
    end
    return r
end

local function addPanel(col, title)
    local pg = col and col.__page
    if pg == nil or pg.si == nil then
        return {sec = dummySec, holder = nil}
    end
    local r = uiCall("addPanel", tostring(title), addPanelImpl, col, title)
    if r == nil then
        return {sec = dummySec, holder = nil}
    end
    return r
end

local function addToggle(panel, key, label, default, cb)
    local r = uiCall("addToggle", label, addToggleImpl, panel, key, label, default, cb)
    return r or dummyCtl()
end

local function addSlider(panel, key, label, minV, maxV, default, step, cb)
    local r = uiCall("addSlider", label, addSliderImpl, panel, key, label, minV, maxV, default, step, cb)
    return r or dummyCtl()
end

local function addDropdown(panel, key, label, options, default, cb)
    local r = uiCall("addDropdown", label, addDropdownImpl, panel, key, label, options, default, cb)
    return r or dummyCtl()
end

local function addKeybind(panel, key, label, defaultName, cb)
    local r = uiCall("addKeybind", label, addKeybindImpl, panel, key, label, defaultName, cb)
    return r or dummyCtl()
end

local function addButton(panel, label, cb, color, hover)
    local r = uiCall("addButton", label, addButtonImpl, panel, label, cb, color, hover)
    return r or dummyCtl()
end

local function addText(panel, text)
    return uiCall("addText", tostring(text):sub(1, 32), addTextImpl, panel, text)
end

local function makePlayerList(panel, height)
    local r = uiCall("makePlayerList", tostring(panel), makePlayerListImpl, panel, height)
    return r or dummyCtl()
end

-- ============================================================
-- ============ KEYBIND MANAGER + TARGET HUD ==================
-- ============================================================
-- обёрнуто в IIFE: локалки движка не держат регистры чанка (лимит Luau = 200)
; (function() -- ";" перед IIFE: иначе Luau считает синтаксис двусмысленным

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
    {label = "Spider",       cfg = "spider.enabled"},
    {label = "AirStack",     cfg = "airstack.enabled"},
    {label = "Invisible",    cfg = "invis.enabled"},
    {label = "No Knockback", cfg = "nokb.enabled"},
    {label = "Kill Aura",    cfg = "ka.enabled"},
    {label = "Silent Aura",  cfg = "sa.enabled"},
    {label = "Smooth Cam",   cfg = "scam.enabled"},
    {label = "Auto Shot",    cfg = "asd.enabled"},
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
    local GSL = getgenv().Library
    local mu = GSL and GSL.UI and GSL.UI.MainUI
    if not (mu and mu.Parent) then return false end
    if GSL.UI.Faded then return false end
    local loc = UIS:GetMouseLocation()
    local p = mu.AbsolutePosition
    local s = mu.AbsoluteSize
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
; (function() -- IIFE: регистры страниц уходят в свой функциональный бюджет (лимит Luau=200)

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
    addDropdown(pAcc, "aimbot.key", "Aim Key", {"Hold RMB", "Always", "Hold E"}, "Hold RMB", function(v)
        S.aimKey = v
    end)
    addDropdown(pAcc, "aimbot.bone", "Bone", {"Head", "Torso", "Body"}, "Head", function(v)
        S.aimBone = v
    end)
    addText(pAcc, "Аимте пишется ПОСЛЕ камеры игры (не затирается). Smooth=1 => мгновенный снап. Бери Hold RMB — целишься при зажатой ПКМ.")
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
    addDropdown(pSilent, "silent.mode", "Silent Mode", {"Universal", "Fortline", "Network"}, "Universal", function(v)
        S.silentMode = v
        if S.silentAimOn then
            disableSilentAim()
            enableSilentAim()
        end
    end)
    addText(pSilent, "Fortline — камера сама целится ПОКА зажата кнопка огня (работает на Xeno без хуков). Network — перенаправление FireServer оружия в голов (нужны хуки). Universal — Ray/Mouse.Hit хук (нужны хуки).")

    local pAs = addPanel(pg.col2, "Auto Shot")
    addToggle(pAs, "asd.enabled", "Enabled", false, function(state)
        if state then enableAutoShot() else disableAutoShot() end
    end)
    addSlider(pAs, "asd.radius", "Cone Radius (px)", 20, 160, 80, 5, function(v)
        S.asFovPx = math.floor(v)
    end)
    addSlider(pAs, "asd.cps", "Fire Rate (CPS)", 2, 25, 10, 1, function(v)
        S.asCps = math.floor(v)
    end)
    addToggle(pAs, "asd.silenthit", "Silent Hit (попадает сам, без камеры)", true, function(state)
        S.asSilentHit = state
    end)
    addSlider(pAs, "asd.range", "Reach Size", 4, 60, 20, 1, function(v)
        S.asRange = math.floor(v)
    end)
    addToggle(pAs, "asd.tpkill", "TP Kill (старый стиль: ТП к цели и назад)", false, function(state)
        S.asTp = state
    end)
    addSlider(pAs, "asd.tprange", "TP Дальность", 10, 1000, 200, 10, function(v)
        S.asTpRange = math.floor(v)
    end)
    addSlider(pAs, "asd.tpdist", "TP Дистанция от цели", 1, 30, 4, 1, function(v)
        S.asTpDist = math.floor(v)
    end)
    addText(pAs, "TP Kill: персонаж прыгает к цели на указанной дальности, бьёт и возвращается обратно. Для мечей (1.8 Arena и подобное).")
    addSlider(pAs, "asd.assist", "Cam Assist (Fortline)", 0, 1, 0, 0.05, function(v)
        S.asAssist = v
    end)
    addToggle(pAs, "asd.silentnet", "Silent Redirect (пули САМИ в голову, камера целая)", true, function(state)
        S.asSilentNet = state
        if not state and S.asNetByAuto then
            S.asNetByAuto = false
            pcall(function()
                if S.silentAimOn and disableSilentAim then disableSilentAim() end
            end)
        end
    end)
    addToggle(pAs, "asd.flick", "Instant Flick (skeet: мгновенный флик + огонь)", false, function(state)
        S.asFlick = state
    end)
    addSlider(pAs, "asd.react", "Реакция флика (ms)", 0, 500, 120, 10, function(v)
        S.asReaction = v / 1000
    end)
    addToggle(pAs, "asd.trigger", "Trigger Fire (скит: прицел на цели => ОГОНЬ)", false, function(state)
        S.asTrigger = state
    end)
    addSlider(pAs, "asd.trigdelay", "Trigger Delay (ms)", 30, 300, 80, 5, function(v)
        S.asTrigDelay = v / 1000
    end)
    addText(pAs, "САЙЛЕНТ (Real): Silent Redirect ON — каждый выстрел летит В ГОЛОВУ (Vector3/CFrame и таблиц-аргументов в ремоуте подменяются). Камера сама следит за целью пока стреляешь. Не оставляй включённым Instant Flick на сайленте — тут он не нужен.")
    addDropdown(pAs, nil, "Game Preset", {"Custom", "Fortline"}, "Custom", function(v)
        if v == "Fortline" then
            local c1 = Cfg["asd.silenthit"] if c1 then c1.set(false) end
            local c2 = Cfg["asd.radius"] if c2 then c2.set(70) end
            local c3 = Cfg["asd.cps"] if c3 then c3.set(12) end
            local c4 = Cfg["asd.assist"] if c4 then c4.set(0.4) end
        end
    end)
    addText(pAs, "ПУШКИ (Fortline): Silent Hit=OFF + Cam Assist 0.3-0.5 — камера мягко подтягивается к голове цели в Cone Radius и пули летят в цель. МЕЧИ: Silent Hit=ON + Reach Size — клинок раздувается в куб, хиты без движения камеры.")

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

-- ==== Kill Aura ====
do
    local pg = addPage("Combat", "🗡", "Kill Aura")

    local pKa = addPanel(pg.col1, "Kill Aura")
    addToggle(pKa, "ka.enabled", "Enabled", false, function(state)
        if state then enableKillAura() else disableKillAura() end
    end)
    addSlider(pKa, "ka.range", "Range", 4, 25, 10, 1, function(v)
        S.kaRange = math.floor(v)
    end)
    addSlider(pKa, "ka.cps", "CPS", 5, 30, 12, 1, function(v)
        S.kaCps = math.floor(v)
    end)
    addToggle(pKa, "ka.face", "Face Target", true, function(state)
        S.kaFace = state
    end)
    addText(pKa, "Враг зашёл в Range — его автоматически закликивает: инжект ЛКМ + активация оружия, персонаж поворачивается к цели. CPS — кликов в секунду. Team Check учитывается.")

    local pSa = addPanel(pg.col2, "Silent Aura (1.8 Arena)")
    addToggle(pSa, "sa.enabled", "Enabled", false, function(state)
        if state then enableSilentAura() else disableSilentAura() end
    end)
    addSlider(pSa, "sa.range", "Reach Size", 4, 60, 15, 1, function(v)
        S.saRange = math.floor(v)
    end)
    addSlider(pSa, "sa.delay", "Attack Delay", 0.25, 1, 0.3, 0.05, function(v)
        S.saDelay = v
    end)
    addText(pSa, "Silent Aura REACH: клинок раздувается в невидимый куб Reach — сервер засчитывает касания всех врагов внутри, ты не клеишься к ним. Атака сама идёт по Delay (>= 0.25 — иначе бан), камера/персонаж не двигаются.")
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
    addDropdown(pTarget, "fling.mode", "Mode", {"Velocity Burst", "Stick TP"}, "Velocity Burst", function(v)
        S.flingMode = v
    end)
    addSlider(pTarget, "fling.duration", "Stick Duration", 3, 10, 5, 1, function(v)
        S.flingDur = math.floor(v)
    end)
    addButton(pTarget, "Fling Target", function()
        local plr = flingSel and Players:FindFirstChild(flingSel)
        if plr then
            if S.flingMode == "Stick TP" then
                flingStickyPlayer(plr, S.flingDur)
                toastImpl("Fling", "Стик-флинг (" .. tostring(S.flingDur) .. " сек): " .. plr.Name)
            else
                flingPlayer(plr)
                toastImpl("Fling", "Флингую: " .. plr.Name)
            end
        else
            toastImpl("Fling", "Сначала выбери цель!")
        end
    end, C_RED, C_RED_H)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Velocity Burst — старый: налет с Velocity ~0.8с. Stick TP (твой сниппет): телепорт на цель + клей каждый кадр с Velocity (0, 100000, 0) N секунд, сервер видит тебя внутри цели с гигантской скоростью => её откидывает; затем возврат 50-циклами с нулевой скоростью.")
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
    addDropdown(pAng, "aa.pitch", "Pitch", {"Down", "Up", "Jitter", "None", "Head Down", "Upside Down"}, "Down", function(v)
        S.aaPitch = v
    end)
    addSlider(pAng, "aa.headdepth", "Head Depth", 0.3, 2, 1, 0.1, function(v)
        S.aaHeadDepth = v
    end)
    addText(pAng, "Head Down — присед: стойка ниже на Head Depth, голова для других на уровне ног, ты стоишь и ходишь как обычно, никаких провалов. Не хочешь поворотов тела — поставь Yaw = Disabled.")
    addText(pAng, "Upside Down — стоишь НА ГОЛОВЕ (голова внизу). Y не занижается, поэтому без провалов под землю; движение при такой позе ограничено, как у лежачих режимов.")

    local pDes = addPanel(pg.col1, "Desync (Fortline)")
    addToggle(pDes, "aa.desync", "Jitter Enabled", false, function(state)
        S.aaDesync = state
    end)
    addSlider(pDes, "aa.desyncamt", "Jitter Amount", 0.1, 3, 0.35, 0.05, function(v)
        S.aaDesyncAmt = v
    end)
    addDropdown(pDes, nil, "Game Preset", {"Custom", "Fortline"}, "Custom", function(v)
        if v == "Fortline" then
            local cy = Cfg["aa.yaw"] if cy then cy.set("Random") end
            local cj = Cfg["aa.yawjitter"] if cj then cj.set("Random") end
            local cp = Cfg["aa.pitch"] if cp then cp.set("None") end
            local cd = Cfg["aa.desync"] if cd then cd.set(true) end
            local ca = Cfg["aa.desyncamt"] if ca then ca.set(0.6) end
        end
    end)
    addText(pDes, "Jitter = хитбокс дёргано шатается каждый тик (без накопления) => по тебе сложно попасть из оружия. Пресет Fortline: Yaw=Random + Jitter=Random + Pitch=None + Desync h0.35.")
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

    local pHvH = addPanel(pg.col2, "AA 2.0 (HvH)")
    addToggle(pHvH, "aa.fakelag", "Fake Lag", false, function(state)
        S.aaFakeLag = state
        if not state then S.flHistory = nil S.flCycle = 0 end
    end)
    addToggle(pHvH, "aa.onshot", "On-Shot (твич бога при стрельбе)", false, function(state)
        S.aaOnShot = state
    end)
    addToggle(pHvH, "aa.fakeduck", "Fake Duck (присед-пульс)", false, function(state)
        S.aaFakeDuck = state
    end)
    addToggle(pHvH, "aa.antibs", "Anti-Backstab", false, function(state)
        S.aaAntiBS = state
    end)
    addToggle(pHvH, "aa.resaa", "Ressurect AA (при low HP)", false, function(state)
        S.aaResAA = state
    end)
    addDropdown(pHvH, nil, "Jit Preset", {"Custom", "Skeet Slip", "HvH Classic", "Insanity", "Fortline RAGE"}, "Custom", function(v)
        local cy = Cfg["aa.yaw"]
        local cj = Cfg["aa.yawjitter"] or Cfg["aa.jitter"]
        local cp = Cfg["aa.pitch"]
        local cd = Cfg["aa.desync"]
        local ca = Cfg["aa.desyncamt"]
        if v == "Skeet Slip" then
            if cy then cy.set("Backward") end
            if cj then cj.set("Offset") end
            if cp then cp.set("None") end
            if cd then cd.set(true) end
            if ca then ca.set(0.4) end
        elseif v == "HvH Classic" then
            if cy then cy.set("Random") end
            if cj then cj.set("Random") end
            if cp then cp.set("None") end
            if cd then cd.set(true) end
            if ca then ca.set(0.7) end
        elseif v == "Insanity" then
            if cy then cy.set("Spin") end
            if cj then cj.set("Offset") end
            if cp then cp.set("None") end
            if cd then cd.set(true) end
            if ca then ca.set(1.5) end
            local cfd = Cfg["aa.fakeduck"] if cfd then cfd.set(true) end
        elseif v == "Fortline RAGE" then
            if cy then cy.set("Backward") end
            if cj then cj.set("Offset") end
            if cp then cp.set("None") end
            if cd then cd.set(true) end
            if ca then ca.set(0.6) end
            local cos = Cfg["aa.onshot"] if cos then cos.set(true) end
        end
    end)
    addText(pHvH, "Fake Lag: сервер часть времени видит тебя в прошлом — врагам трудно прицелиться. On-Shot: пока ЛКМ — твич максимум. Fake Duck: присядочный пульс. Anti-Backstab: лицом к тому, кто за спиной. Ressurect: при low HP — мигания + жёсткий дёрг.")

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

    local pSc = addPanel(pg.col2, "Smooth Camera")
    addToggle(pSc, "scam.enabled", "Enabled", false, function(state)
        if state then enableSmoothCam() else disableSmoothCam() end
    end)
    addSlider(pSc, "scam.smooth", "Smoothness", 2, 15, 6, 1, function(v)
        S.scSpeed = v
    end)
    addSlider(pSc, "scam.dist", "Distance", 4, 14, 8, 1, function(v)
        S.scDist = v
    end)
    addSlider(pSc, "scam.sens", "Sensitivity", 0.2, 2, 1, 0.1, function(v)
        S.scSens = v
    end)
    addText(pSc, "Кинематографическая плавная камера: движение мыши сглаживается (без рывков), орбита вокруг персонажа. Чем БОЛЬШЕ Smoothness, тем БЫСТРЕЕ доезжает до взгляда (меньше — сильнее смягчение).")

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
    addToggle(pSpin, "move.spin.headdown", "Головой вниз (вертолёт)", false, function(state)
        S.spinHeadDown = state
    end)
    addSlider(pSpin, "move.spin.speed", "Spin Speed", 1, 1000000, 90, 1000, function(v)
        S.spinSpeed = math.floor(v)
    end)
    addText(pSpin, "Вращает персонажа вокруг своей оси. Скорость — градусов в секунду (до 1 000 000 — абсолютный фланг-турбонаддув).")
    addText(pSpin, "«Головой вниз» = вертолётик: тело плоское, голова в полу, лопасти-ноги крутятся. Y не занижается — под землю не проваливаешься.")

    local pSpider = addPanel(pg.col2, "Spider")
    addToggle(pSpider, "spider.enabled", "Enabled", false, function(state)
        if state then enableSpider() else disableSpider() end
    end)
    addSlider(pSpider, "spider.speed", "Climb Speed", 10, 120, 30, 5, function(v)
        S.spiderSpeed = math.floor(v)
    end)
    addText(pSpider, "Лазание по стенам: подойди к стене и зажми W — пойдёшь вертикально вверх.")

    local pAir = addPanel(pg.col2, "AirStack")
    addToggle(pAir, "airstack.enabled", "Enabled", false, function(state)
        if state then enableAirStack() else disableAirStack() end
    end)
    addText(pAir, "Невидимая платформа под ногами на той высоте, где включишь. Подпрыгни, включи — и беги по воздуху.")
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

    local pInvis = addPanel(pg.col1, "Invisible")
    addToggle(pInvis, "invis.enabled", "Enabled", false, function(state)
        setInvisible(state)
    end)
    addSlider(pInvis, "invis.offset", "Depth", 20, 200, 58, 2, function(v)
        S.invisOffset = math.floor(v)
    end)
    addText(pInvis, "Персонаж проваливается под карту (Y зафиксирован — падения нет), другие тебя не видят. Камера и управление — как обычно. Выключаешь — телепорт обратно на поверхность.")

    local pNoKb = addPanel(pg.col2, "No Knockback")
    addToggle(pNoKb, "nokb.enabled", "Enabled", false, function(state)
        if state then enableNoKb() else disableNoKb() end
    end)
    addSlider(pNoKb, "nokb.threshold", "Threshold", 25, 100, 45, 5, function(v)
        S.noKbMax = math.floor(v)
    end)
    addToggle(pNoKb, "nokb.full", "1.8 Mode (режет и отскок вверх)", false, function(state)
        S.noKbFull = state
    end)
    addDropdown(pNoKb, nil, "Game Preset", {"Standard", "1.8 Arena"}, "Standard", function(v)
        if v == "1.8 Arena" then
            local c = Cfg["nokb.threshold"] if c then c.set(28) end
            local c2 = Cfg["nokb.full"] if c2 then c2.set(true) end
        else
            local c2 = Cfg["nokb.full"] if c2 then c2.set(false) end
        end
    end)
    addText(pNoKb, "Preset 1.8 Arena: порог 28 + обнуление вертикального подскока от ударов — комбо не рвётся, движение свободное.")

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
        local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), ZIndex = 3}, pB.holder)
        new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -160, 1, 0), Text = e.label, TextColor3 = C_GRAY, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3}, row)
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
    addDropdown(pCfg, "cfg.profile", "Profile", {"Global", "Slot 1", "Slot 2"}, currentProfile, function(v)
        currentProfile = v
    end)

    local pInfo = addPanel(miscPage.col1, "Info")
    addText(pInfo, "RightShift — скрыть/показать меню.")
    addText(pInfo, "Окно таскается за шапку, размер — за правый нижний угол.")
    addText(pInfo, "Меню стилизовано под GameSense (skeet.cc).")

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
function fullCleanupNL()
    if unloadedNL then return end
    unloadedNL = true
    S.guiAlive = false
    dcc(S.flyConn)
    dcc(S.noclipConn)
    dcc(S.espConn)
    dcc(S.targetEspConn)
    dcc(S.wsConn)
    dcc(S.clickTpConn)
    dcc(S.hitboxConn)
    if S.aimbotConn then pcall(function() RunService:UnbindFromRenderStep("SpermaHubAimbot") end) S.aimbotConn = nil end
    pcall(function() RunService:UnbindFromRenderStep("SpermaHubFlickStep") end)
    if S.silentAimConn then pcall(function() S.silentAimConn:Disconnect() end) end
    disableAutoClicker()
    dcc(S.autoClickBindConn)
    dcc(S.jesusConn)
    if S.jesusPlatform then S.jesusPlatform:Destroy() S.jesusPlatform = nil end
    dcc(S.spinConn)
    dcc(S.aaConn)
    dcc(S.bhopConn)
    dcc(S.afConn)
    dcc(S.strafeConn)
    dcc(S.specConn)
    dcc(bindInputConn1)
    dcc(bindInputConn2)
    pcall(exitSpectate)
    pcall(disableSpider)
    pcall(disableAirStack)
    pcall(function() setInvisible(false) end)
    pcall(disableNoKb)
    pcall(disableKillAura)
    pcall(disableSilentAura)
    pcall(disableSmoothCam)
    pcall(disableAutoShot)
    pcall(disableAntiKick)
    dcc(S.godConn)
    dcc(S.flingConn)
    dcc(S.fxConn)
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
    pcall(function() getgenv().Library:Unload() end)
    print("✦ SpermaHub полностью выгружен")
end
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
        dcc(S.noclipConn)
        S.noclip = true
        enableNoclip()
    end
    task.wait(0.2)
    applyWalkSpeed()
end)

-- ============================================================
end)() -- /СЕКЦИЯ СТРАНИЦ (IIFE: регистры страниц освобождены)

-- ==================== ИНИЦИАЛИЗАЦИЯ =========================
-- ============================================================
updateFovCircle()
updateSilentFovCircle()
WM.Visible = S.wmOn

-- открыть первую категорию и её первую страницу (Legitbot)
if Categories[1] then
    selectCategory(Categories[1].key)
elseif Pages[1] then
    selectPage(Pages[1])
end

-- gamesense: финальная инициализация (viewport-коннекты; watermark заглушен)
pcall(function() getgenv().Library:Init() end)
print(("[SpermaHub] постройка GUI завершена, UI-ошибок: " .. tostring(GSBuildErrors or 0)))
if (GSBuildErrors or 0) > 0 then
    warn("[SpermaHub] ВНИМАНИЕ: часть контролов не построилась — скинь разработчику красные строки [UI-ERR] из консоли (F9)")
end

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
    task.wait(2)
    doLoad("Global", true)
end)

bootStep("финал OK")
pcall(function() BootGui:Destroy() end)
toastImpl("SpermaHub", "GameSense GUI загружена!")
print("✦ SpermaHub (GameSense GUI) загружен!")
print("Combat: Legitbot | Hitbox | Kill | Fling | Spectate | Anti-Aim | AutoClicker + AntiFling/AutoStrafe")
print("Visuals + Movement + Player + Server (Bypass/Server) | Misc")
