-- rbxmock.lua — Roblox-мок для boot-теста SpermaHub под lupa (Lua 5.4)
-- хранится в репо: tools/rbxmock.lua
local M = {pool = {}, _evNames = {}}

-- форвард-декларации дататипов (newInst использует их до строк определений)
local V3, CF

-- планировщик: task.spawn в pool, task.wait = yield
local function scheduleCo(co, ...)
    table.insert(M.pool, co)
    return co
end
local function resumeAll()
    local pool = M.pool
    for i = #pool, 1, -1 do
        local co = pool[i]
        if coroutine.status(co) == "dead" then
            table.remove(pool, i)
        else
            local ok, e = coroutine.resume(co)
            if not ok then print("[SCHED-ERR] " .. tostring(e)) end
            if coroutine.status(co) == "dead" then table.remove(pool, i) end
        end
    end
end
M.resumeAll = resumeAll

local function schedSpawn(f, ...)
    local co = coroutine.create(f)
    table.insert(M.pool, co)
    local ok, e = coroutine.resume(co, ...)
    if not ok then print("[task-err] " .. tostring(e)) end
    return co
end
M.schedSpawn = schedSpawn

-- имена событий на инстансах (читаются nil → создаём)
local EVENT_NAMES = {
    MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
    MouseButton2Click = true, MouseButton2Down = true, MouseButton2Up = true,
    MouseEnter = true, MouseLeave = true, MouseMoved = true, MouseWheelForward = true, MouseWheelBackward = true,
    Activated = true, Changed = true, FocusLost = true, Focused = true,
    TextChanged = true, InputBegan = true, InputEnded = true, InputChanged = true,
    SelectorIconClicked = true, Touched = true, TouchEnded = true,
    Button1Down = true, Button1Up = true,
    AncestryChanged = true, ChildAdded = true, ChildRemoved = true,
}

local function newInst(class)
    local children = {}
    local ev = {}
    local t = {ClassName = class, Name = class, Parent = nil, _children = children, _ev = ev}
    local mt = {}
    local function mkEvent(name)
        local handlers = {}
        local e
        e = {
            _h = handlers,
            Connect = function(_, f)
                table.insert(handlers, f)
                local conn = {_f = f, Disconnect = function(cs)
                    for i, hf in ipairs(handlers) do if hf == cs._f then table.remove(handlers, i) break end end
                end}
                return conn
            end,
            Fire = function(_, ...)
                local snapshot = {}
                for _, f in ipairs(handlers) do table.insert(snapshot, f) end
                for _, f in ipairs(snapshot) do
                    local co = coroutine.create(f)
                    table.insert(M.pool, co)
                    local ok, err = coroutine.resume(co, ...)
                    if not ok then print("[EV-ERR " .. tostring(class) .. "." .. tostring(name) .. "] " .. tostring(err)) end
                end
            end,
            Wait = function() return nil end,
        }
        return e
    end
    mt.__index = function(self2, k)
        if EVENT_NAMES[k] then
            local e = mkEvent(k)
            rawset(self2, k, e)
            return e
        end
        return rawget(self2, k)
    end
    mt.__newindex = function(self2, k, v)
        if k ~= "_children" and k ~= "_ev" then rawset(self2, k, v) end
    end
    setmetatable(t, mt)

    -- универсальные поля физики (BasePart-стиль; перезаписывается UI, ничего не ломает)
    t.Position = V3(0, 0, 0)
    t.Velocity = V3(0, 0, 0)
    t.AssemblyLinearVelocity = V3(0, 0, 0)
    t.RotVelocity = V3(0, 0, 0)
    t.AssemblyAngularVelocity = V3(0, 0, 0)
    t.CFrame = CF.new()
    t.WalkSpeed = nil
    t.MoveDirection = V3(0, 0, 0)

    t.GetChildren = function(self) return children end
    t.GetDescendants = function(self)
        local out = {}
        local function rec(x)
            for _, c in ipairs(x:GetChildren()) do table.insert(out, c); rec(c) end
        end
        rec(self)
        return out
    end
    t.FindFirstChild = function(self, name, deep)
        for _, c in ipairs(children) do if c.Name == name then return c end end
        return nil
    end
    t.FindFirstChildOfClass = function(self, cls)
        for _, c in ipairs(children) do if c.ClassName == cls then return c end end
        return nil
    end
    t.FindFirstChildWhichIsA = function(self, cls)
        for _, c in ipairs(children) do if c:IsA(cls) then return c end end
        return nil
    end
    t.WaitForChild = function(self, name) return self:FindFirstChild(name) end
    t.Connect = function(self, f)
        -- низкоуровневое назначение (SetCore-styles; у настоящих сервисов Connect есть на _ev-объектах)
        return {Disconnect = function() end}
    end
    t.Destroy = function(self)
        pcall(function() if self.Parent then
            for i, c in ipairs(self.Parent:GetChildren()) do if c == self then table.remove(self.Parent:GetChildren(), i) break end end
        end end)
        for _, c in ipairs(children) do pcall(function() c:Destroy() end) end
        for i = 1, #children do children[i] = nil end
        self.Parent = nil
    end
    t.GetPropertyChangedSignal = function(self, prop) return newInst("Event") end
    t.IsA = function(self, cls)
        if cls == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"
            or self.ClassName == "Attachment" or self.ClassName == "MeshPart" or self.ClassName == "WedgePart") then
            return true
        end
        if cls == "GuiObject" and (self.ClassName == "Frame" or self.ClassName == "TextLabel" or self.ClassName == "TextButton" or self.ClassName == "ImageLabel" or self.ClassName == "ScrollingFrame" or self.ClassName == "TextBox" or self.ClassName == "CanvasGroup") then
            return true
        end
        return self.ClassName == cls
    end
    t.Clone = function(self) return newInst(self.ClassName) end
    t.SetAttribute = function() end
    t.GetAttribute = function() return nil end
    t.GetAttributes = function() return {} end
    t.SetPrimaryPartCFrame = function() end
    t.PivotTo = function() end
    t.GetPivot = function() return M.E.CFrame.new() end

    if class == "Event" or class == "RBXScriptSignal" then
        local handlers = {}
        t.Connect = function(_, f)
            table.insert(handlers, f)
            return {Disconnect = function()
                for i, hf in ipairs(handlers) do if hf == f then table.remove(handlers, i) break end end
            end}
        end
        t.Fire = function(_, ...)
            local snapshot = {}
            for _, f in ipairs(handlers) do table.insert(snapshot, f) end
            for _, f in ipairs(snapshot) do
                local co = coroutine.create(f)
                table.insert(M.pool, co)
                local ok, err = coroutine.resume(co, ...)
                if not ok then print("[EV-ERR Event] " .. tostring(err)) end
            end
        end
        t.Wait = function() return coroutine.yield() end
    end
    return t
end

M.E = {newInst = newInst, calls = {}}

-- Enum
local enumMT = {
    __index = function(_, k)
        local v = {Name = tostring(k)}
        return v
    end,
}
local Enum = setmetatable({}, {__index = function(_, k) return setmetatable({}, enumMT) end})

-- дататайпы
V3 = function(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, {
    __add = function(a, b) return V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
    __sub = function(a, b) return V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
    __mul = function(a, b) return type(a) == "number" and V3(a * b.X, a * b.Y, a * b.Z) or V3(a.X * b, a.Y * b, a.Z * b) end,
    __index = function(self, k) if k == "Magnitude" then return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2) end end,
}) end
local CFMT = {
    __mul = function(a, b) return a._ctr() end,
    __add = function(a, b) return a._ctr() end,
}
CF = {
    new = function(...)
        local t = setmetatable({Position = V3(0, 0, 0), p = V3(0, 0, 0)}, CFMT)
        t._ctr = function() return setmetatable({Position = V3(0, 0, 0), p = V3(0, 0, 0)}, CFMT) end
        return t
    end,
    Angles = function(...)
        local t = setmetatable({Position = V3(0, 0, 0), p = V3(0, 0, 0)}, CFMT)
        t._ctr = function() return setmetatable({Position = V3(0, 0, 0), p = V3(0, 0, 0)}, CFMT) end
        return t
    end,
}
local UDim = {new = function(s, o) return {Scale = s, Offset = o} end}
local UDim2 = {
    new = function(a, b, c, d) return {} end,
    fromOffset = function(a, b) return {} end,
    fromScale = function(a, b) return {} end,
}
local Color3 = {
    new = function(r, g, b) return {R = r or 1, G = g or 1, B = b or 1} end,
    fromRGB = function(r, g, b) return {R = (r or 255) / 255, G = (g or 255) / 255, B = (b or 255) / 255} end,
    fromHSV = function(h, s, v) return {R = h, G = s, B = v} end,
}
local Vector2 = {new = function(x, y) return {X = x or 0, Y = y or 0} end}

-- Instance factory
local knownClasses = {
    ScreenGui = true, Frame = true, TextLabel = true, TextButton = true, ImageLabel = true,
    ScrollingFrame = true, UICorner = true, UIStroke = true, UIPadding = true, UIListLayout = true,
    BillboardGui = true, Highlight = true, TextBox = true, UIGradient = true, Wrap = true,
    CanvasGroup = true, ViewportFrame = true, SurfaceGui = true, Part = true, SpawnLocation = true,
    Attachment = true, AlignPosition = true, AlignOrientation = true, Sound = true, BlurEffect = true,
    BloomEffect = true, ColorCorrectionEffect = true, DepthOfFieldEffect = true, SunRaysEffect = true,
    Atmosphere = true, Sky = true, Whole = true, BoolValue = true, ObjectValue = true, NumberValue = true,
}
local Instance = {new = function(class, parent)
    local t = newInst(class)
    if parent then t.Parent = parent table.insert(parent:GetChildren(), t) end
    return t
end}

-- игроки / перс
local function mkChar(name)
    local guess = newInst("Model") guess.Name = name or "Char"
    local hrp = newInst("Part") hrp.Name = "HumanoidRootPart" hrp.CFrame = CF.new() hrp.Position = V3()
    local head = newInst("Part") head.Name = "Head"
    local hum = newInst("Humanoid") hum.Name = "Humanoid" hum.Health = 100 hum.MaxHealth = 100
    hum.StateChanged = hum -- Connect-метод уже есть
    hum.Running = hum
    hum.MoveDirection = V3(0, 0, 0)
    hum.WalkSpeed = 16
    hum.Sit = false
    hum.PlatformStand = false
    hum.AutoRotate = true
    hum.RootPart = hrp
    hum.RootPart.Name = "HumanoidRootPart"
    hum.JumpPower = 50
    hum.Sit = false
    hum.SetStateEnabled = function(_, _, _) end
    hum.ChangeState = function(_, _) end
    table.insert(guess:GetChildren(), hrp)
    table.insert(guess:GetChildren(), head)
    table.insert(guess:GetChildren(), hum)
    return guess
end
local player = newInst("Player") player.Name = "Tester" player.DisplayName = "Tester"
player.Character = mkChar("Tester")
player.CharacterAdded = newInst("Event")
player.Idled = newInst("Event")
player.GetNetworkPing = function() return 0.05 end
player.PlayerGui = newInst("Folder") player.PlayerGui.Name = "PlayerGui"

local Players = setmetatable({
    LocalPlayer = player,
    MaxPlayers = 12,
    GetPlayers = function() return {player} end,
    PlayerAdded = newInst("Event"),
    PlayerRemoving = newInst("Event"),
    FindFirstChild = function(_, n) if n == "Tester" then return player end return nil end,
    GetPlayerFromCharacter = function() return nil end,
}, {})


-- сервисы
local RunService = {
    Heartbeat = newInst("Event"),
    RenderStepped = newInst("Event"),
    Stepped = newInst("Event"),
    BindToRenderStep = function() end,
    UnbindFromRenderStep = function() end,
}
local UIS = {
    InputBegan = newInst("Event"),
    InputEnded = newInst("Event"),
    InputChanged = newInst("Event"),
    JumpRequest = newInst("Event"),
    TouchStarted = newInst("Event"),
    TextBoxFocused = newInst("Event"),
    TextBoxFocusReleased = newInst("Event"),
    WindowFocused = newInst("Event"),
    WindowFocusReleased = newInst("Event"),
    WindowVisible = true,
    MouseBehavior = nil,
    GetPlatform = function() return "Windows" end,
    GetConnectedGamepads = function() return {} end,
    IsGamepadButtonDown = function() return false end,
    TouchEnabled = false,
    KeyboardEnabled = true,
    GamepadEnabled = false,
    GetMouseLocation = function() return Vector2.new(100, 100) end,
}
local WS = newInst("Workspace") WS.Name = "Workspace"
WS.Raycast = function() return nil end
WS.CurrentCamera = {ViewportSize = Vector2.new(1920, 1080), CFrame = CF.new(), WorldToViewportPoint = function() return V3(960, 540, 10), 10, true end, FieldOfView = 70}
WS.Terrain = newInst("Terrain")

local Lighting = newInst("Lighting") Lighting.GlobalShadows = true Lighting.FogStart = 0 Lighting.FogEnd = 1000
Lighting.Technology = "x" Lighting.Brightness = 2 Lighting.ClockTime = 12 Lighting.ExposureCompensation = 0

local RS = newInst("ReplicatedStorage") RS.Name = "ReplicatedStorage"
local TweenService = {Create = function(_, obj, ti, props)
    return {Play = function() for k, v in pairs(props or {}) do pcall(function() obj[k] = v end) end end}
end}
local TpService = {Teleport = function() error("nope") end, TeleportToPlaceInstance = function() error("nope") end}
local HttpService = {JSONEncode = function(_, x) return "{}" end, JSONDecode = function() return {} end,
                     GenerateGUID = function() return "guid" end}
local ProxPromptService = {PromptShown = newInst("Event"), PromptHidden = newInst("Event")}
local VirtualUser = {CaptureController = function() end, ClickButton2 = function() end}
local GuiService = {GetGuiInset = function() return Vector2.new(0, 0) end}
local StarterGui = {SetCore = function() end, SetCoreGuiEnabled = function() end}
local Stats = {}
local LogService = {}
local MarketplaceService = {GetProductInfo = function() return {} end}

local services = {
    Players = Players, RunService = RunService, UserInputService = UIS,
    Workspace = WS, Lighting = Lighting, ReplicatedStorage = RS,
    TweenService = TweenService, TeleportService = TpService, HttpService = HttpService,
    ProximityPromptService = ProxPromptService, VirtualUser = VirtualUser,
    GuiService = GuiService, StarterGui = StarterGui, Stats = Stats, LogService = LogService,
    MarketplaceService = MarketplaceService, VirtualInputManager = {SendMouseButtonEvent = function() end},
    ContextActionService = {BindAction = function() end, UnbindAction = function() end},
}

local game = setmetatable({
    PlaceId = 12345, JobId = "job-1", CreatorId = 1,
    GetService = function(_, name)
        table.insert(M.E.calls, "GetService:" .. name)
        return services[name] or newInst(name)
    end,
    HttpGet = function() return "" end,
    GetObjects = function() return {} end,
}, {})

-- workspace как верхнеуровневый глобал
local workspace = WS

-- Доп. API исполнителей
local E = {
    game = game,
    workspace = workspace,
    Enum = Enum,
    Instance = Instance,
    Vector3 = {new = V3},
    Vector2 = Vector2,
    CFrame = CF,
    UDim = UDim,
    UDim2 = UDim2,
    Color3 = Color3,
    Rect = {new = function(a, b, c, d) return {} end},
    BrickColor = {new = function(x) return {Color = Color3.fromRGB(255, 255, 255)} end},
    Font = {fromName = function() return {} end},
    NumberRange = {new = function(a, b) return {} end},
    NumberSequence = {new = function(a, b) return {} end},
    NumberSequenceKeypoint = {new = function(a, b, c) return {} end},
    TweenInfo = {new = function(...) return {} end},
    RaycastParams = {new = function()
        return {FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = true,
                CollisionGroup = nil, RespectCanCollide = false,
                AddToFilter = function() end}
    end},
    OverlapParams = {new = function()
        return {FilterType = nil, FilterDescendantsInstances = {}, MaxParts = 0}
    end},
    task = {
        spawn = function(f, ...) return schedSpawn(f, ...) end,
        wait = function(t) return coroutine.yield() end,
        delay = function(t, f, ...)
            local args = {...}
            return schedSpawn(function() coroutine.yield() f(table.unpack(args)) end)
        end,
        defer = function(f, ...) return schedSpawn(f, ...) end,
    },
    print = print, warn = warn, error = error, assert = assert, tostring = tostring, tonumber = tonumber,
    debug = debug,
    type = type, typeof = function(x) return type(x) end,
    pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
    table = table, string = string, math = math, os = os, bit32 = bit32, coroutine = coroutine,
    tick = function() return os.clock() end,
    wait = function(t) return coroutine.yield() end,
    pcall = pcall, xpcall = xpcall, rawget = rawget, rawset = rawset, rawequal = rawequal,
    setmetatable = setmetatable, getmetatable = getmetatable,
    loadstring = function(src, n)
        local f, e = load(src, n or "@ls", "t", M.env)
        return f, e
    end,
    getgenv = function() return M.env end,
    gethui = function() return player.PlayerGui end,
    setclipboard = function() end, getclipboard = function() return "" end,
    setfpscap = function() end,
    fireproximityprompt = function() end,
    Drawing = {
        new = function(class)
            return setmetatable({Visible = false, Filled = false, Thickness = 1, ZIndex = 1, Text = "", Color = Color3.new(1, 1, 1), Transparency = 1, Center = false, Outline = false, Position = Vector2.new(), Size = Vector2.new(), PointA = Vector2.new(), PointB = Vector2.new(), Font = 0, From = Vector2.new(), To = Vector2.new(), Radius = 10, NumSides = 30, Remove = function() end}, {})
        end,
    },
    getconnections = function() return {} end,
    hookmetamethod = function(_, _, f) return f end,
    newcclosure = function(f) return f end,
    getrawmetatable = function() return {} end,
    setreadonly = function() end,
    isreadonly = function() return false end,
    checkcaller = function() return false end,
    getnamecallmethod = function() return "" end,
    gethiddenproperty = function() return nil end,
    sethiddenproperty = function() end,
    getsenv = function() return {} end,
    getsynasset = function() return "" end,
    syn = {}, SENTINEL = {},
    securecall = function(f) return f() end,
    readfile = function() return "" end,
    writefile = function() end,
    isfile = function() return false end,
    isfolder = function() return false end,
    makefolder = function() end,
    listfiles = function() return {} end,
    delfile = function() end,
    appendfile = function() end,
    identifyexecutor = function() return "ArenaMock", "1.0" end,
    getexecutorname = function() return "ArenaMock" end,
    request = function() return {Body = "{}", StatusCode = 200} end,
    http_request = function() return {Body = "{}", StatusCode = 200} end,
}
-- отдельная "пустая" getgenv-таблица (главный скрипт проверяет там синглтон-флаги)
local genv = {
    Library = nil, Linoria = nil, Rayfield = nil,
    SpermaHubRevoked = nil, SpermaHubRunning = nil, SpermaHubKeySystem = nil,
    unload = nil, Toggles = nil, Options = nil,
}
setmetatable(E, {__index = function(_, k) return genv[k] end})
E.gcinfo = function() return 0 end
E.collectgarbage = collectgarbage
E.mouse1click = function() end
E.mouse1press = function() end
E.mouse1release = function() end
E.mouse2click = function() end
E.Mouse = nil
E.script = M.script or setmetatable({}, {})

-- getgenv() — отдельная таблица скрипт-флагов; env — это ОНА ЖЕ + Roblox API наверху.
-- Скрипт пишет автоматом глобалы в env; getgenv() должен их видеть.
M.env = E

return M
