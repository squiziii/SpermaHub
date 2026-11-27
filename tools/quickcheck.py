#!/usr/bin/env python3
"""Быстрая мок-проверка neverlose_gui.lua: компиляция, бут, список страниц, карточки Main."""
import sys
import lupa

RUNNER = r"""
local M = MOCK
local E = M.env

-- патчи мока под реальный Roblox
E.math.atan2 = E.math.atan2 or function(y, x) return math.atan(y, x) end
E.math.clamp = function(v, a, b) if v < a then return a elseif v > b then return b else return v end end
E.ColorSequence = function(...) return { ... } end
E.ColorSequenceKeypoint = function(t, c) return { Time = t, Value = c } end
if E.Color3 and E.Color3.toHSV == nil then
    E.Color3.toHSV = function(c) return 0, 0, 1 end
end
local CFold = E.CFrame.new
E.CFrame.new = function(...)
    local cf = CFold(...)
    if select('#', ...) >= 3 then
        cf.Position = E.Vector3.new(...)
    else
        local a = ...
        if type(a) == "table" and a.X then cf.Position = E.Vector3.new(a.X, a.Y, a.Z) end
    end
    return cf
end

-- виртуальные часы: os.clock в Lua 5.5 считает CPU-время, поэтому кулдауны
-- (scaffold delay, ESP-троттлинги) в тесте не тикали бы
local simClock = 0
os.clock = function() return simClock end

-- фейковый мир для Scaffold: пол есть везде, кроме коридора |x| < 0.5
-- (вертикальный луч — проверка опоры, горизонтальный — «рядом стоит блок»)
E.workspace.Raycast = function(self, from, dir)
    if not dir then return nil end
    local ay = math.abs(dir.Y)
    if ay > math.abs(dir.X) + math.abs(dir.Z) then
        if dir.Y < 0 and from.Y > 0 then
            if math.abs(from.X) < 0.5 then return nil end
            return {Position = E.Vector3.new(from.X, 0, from.Z)}
        end
        return nil
    end
    return {Position = from + dir * 0.5}
end

-- UIS в моке не умеет клавиши/мышь — заглушки, чтобы фрикам не падало
local uis = E.game:GetService("UserInputService")
uis.IsKeyDown = function() return false end
uis.GetMouseDelta = function() return E.Vector2.new(0, 0) end

-- executor-API для Silent Aim: без них фича не включается
E.hookfunction = function(f) return f end
E.getrawmetatable = function(o) return getmetatable(o) end
E.setreadonly = function() end
E.newcclosure = function(f) return f end
E.getnamecallmethod = function() return E.__namecallMethod or "Raycast" end
E.Ray = { new = function(origin, dir) return { Origin = origin, Direction = dir } end }

-- у game уже есть метатаблица: даём рабочие __index/__namecall, как в Luau,
-- чтобы навешенные хуки не роняли чтение свойств
local gmt = getmetatable(E.game)
E.__gameNamecall = function(self, ...)
    E.__lastCall = { ... }
    return nil
end
gmt.__index = function(t, k) return rawget(t, k) end
gmt.__namecall = E.__gameNamecall
E.__gameIndex = gmt.__index

-- файловая система в памяти: проверяем save/load конфига
local fs = {}
E.writefile = function(p, d) fs[p] = d end
E.readfile = function(p) return fs[p] or "" end
E.isfile = function(p) return fs[p] ~= nil end
E.isfolder = function() return true end
E.makefolder = function() end
E.delfile = function(p) fs[p] = nil end
E.listfiles = function(p)
    local out = {}
    local prefix = p .. "/"
    for k in pairs(fs) do
        if k:sub(1, #prefix) == prefix then
            local base = k:sub(#prefix + 1)
            if not base:find("/", 1, true) then table.insert(out, base) end
        end
    end
    return out
end

-- JSON: мок умеет только заглушки — делаем минимальный энкодер/декодер плоских таблиц
local function jenc(v)
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            if type(k) == "string" and (type(val) == "string" or type(val) == "number" or type(val) == "boolean") then
                parts[#parts + 1] = jenc(k) .. ":" .. jenc(val)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function jdec(s)
    local out = {}
    local i, n = 1, #s
    local function skipws()
        while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
    end
    local function readstr()
        i = i + 1
        local buf = {}
        while i <= n do
            local c = s:sub(i, i)
            if c == "\\" then
                buf[#buf + 1] = s:sub(i + 1, i + 1)
                i = i + 2
            elseif c == '"' then
                i = i + 1
                return table.concat(buf)
            else
                buf[#buf + 1] = c
                i = i + 1
            end
        end
        return table.concat(buf)
    end
    skipws()
    i = i + 1
    while true do
        skipws()
        if s:sub(i, i) ~= '"' then break end
        local key = readstr()
        skipws()
        if s:sub(i, i) == ":" then i = i + 1 end
        skipws()
        local val
        if s:sub(i, i) == '"' then
            val = readstr()
        else
            local rest = s:sub(i):match("^([%w%+%-%.]+)")
            if not rest then break end
            i = i + #rest
            if rest == "true" then val = true
            elseif rest == "false" then val = false
            else val = tonumber(rest) end
        end
        out[key] = val
        skipws()
        if s:sub(i, i) == "," then i = i + 1 else break end
    end
    return out
end

local GSold = E.game.GetService
E.game.GetService = function(self, name)
    local svc = GSold(self, name)
    if name == "HttpService" and svc then
        svc.JSONEncode = function(_, x) return jenc(x) end
        svc.JSONDecode = function(_, s) return jdec(s) end
    end
    return svc
end

-- NetworkClient: через него пакетный Air Stuck режет исходящий трафик
local netSvc = { limit = 10000, calls = 0 }
netSvc.SetOutgoingKBPSLimit = function(self, kbps)
    self.limit = kbps
    self.calls = self.calls + 1
end
E.netStub = netSvc
local GSoldSvc = E.game.GetService
E.game.GetService = function(self, name)
    if name == "NetworkClient" then return netSvc end
    return GSoldSvc(self, name)
end

-- Instance.new: регистрируем ребёнка по Parent (мок этого не делает)
local Iold = E.Instance.new
local pmap = setmetatable({}, { __mode = "k" })  -- proxy -> сырой инстанс
E.Instance.new = function(cls)
    local inst = Iold(cls)
    local proxy = {}
    pmap[proxy] = inst
    setmetatable(proxy, {
        __index = inst,
        __newindex = function(_, k, v)
            if k == "Parent" then
                inst.Parent = v
                local target = (v and pmap[v]) or v
                local ch = target and rawget(target, "_children")
                if ch then table.insert(ch, inst) end
            else
                inst[k] = v
            end
        end,
    })
    return proxy
end

local chunk = assert(load(SCRIPT_SRC, "@neverlose_gui", "t", E))
local ok, err = pcall(chunk)
if not ok then
    print("BOOT FAIL: " .. tostring(err))
    return
end
M.resumeAll()

local RSm = E.game:GetService("RunService")
for i = 1, 3 do
    pcall(function() RSm.Heartbeat:Fire(0.016) end)
    pcall(function() RSm.Stepped:Fire(0.016, 0) end)
    pcall(function() RSm.RenderStepped:Fire(0.016) end)
    M.resumeAll()
end
print("BOOT OK")

local api = E.SpermaHubUI or E.getgenv().SpermaHubUI
if not api then
    print("API MISSING")
    return
end

local names = {}
for name in pairs(api.Pages) do table.insert(names, name) end
table.sort(names)
print("PAGES (" .. #names .. "): " .. table.concat(names, ", "))

for _, name in ipairs(names) do
    local def = api.Pages[name]
    local ok2, err2 = pcall(function() def.btn.MouseButton1Click:Fire() end)
    M.resumeAll()
    print(("OPEN %-12s built=%s%s"):format(name, tostring(def.page ~= nil),
        ok2 and "" or (" err=" .. tostring(err2))))
end

local main = api.Pages.Main
if main and main.page then
    local found = {}
    local desc = main.page.holder:GetDescendants()
    print("MAIN descendants: " .. #desc)
    for _, o in ipairs(desc) do
        if o.ClassName == "TextLabel" and (o.Text == "Kill Player" or o.Text == "Movement"
            or o.Text == "Position" or o.Text == "Walk Speed" or o.Text == "Scaffold") then
            table.insert(found, o.Text)
        end
    end
    table.sort(found)
    print("MAIN cards: " .. table.concat(found, ", "))
end

local legit = api.Pages.Legitbot
if legit and legit.page then
    local found = {}
    for _, o in ipairs(legit.page.holder:GetDescendants()) do
        if o.ClassName == "TextLabel" and (o.Text == "Aim Assist" or o.Text == "Strength"
            or o.Text == "Only When Firing" or o.Text == "Target Part") then
            table.insert(found, o.Text)
        end
    end
    table.sort(found)
    print("LEGITBOT cards: " .. table.concat(found, ", "))
end

local aap = api.Pages["Anti Aim"]
if aap and aap.page then
    local found = {}
    for _, o in ipairs(aap.page.holder:GetDescendants()) do
        if o.ClassName == "TextLabel" and (o.Text == "Mode" or o.Text == "Pitch" or o.Text == "Enabled") then
            table.insert(found, o.Text)
        end
    end
    table.sort(found)
    print("ANTIAIM cards: " .. table.concat(found, ", ")
        .. " ctrl=" .. tostring(api.Config["Anti Aim/Anti Aim/Enabled"] ~= nil))
end

-- ESP: фильтры по команде/друзьям/дистанции + тоглы отрисовки + цвета
local PS = E.game:GetService("Players")
local lp = PS.LocalPlayer
local function mkPlayer(name, pos, isFriend, team)
    local plr = E.Instance.new("Player")
    plr.Name = name
    plr.UserId = 4242
    plr.Team = team
    local ch = E.Instance.new("Model")
    local hrp = E.Instance.new("Part"); hrp.Name = "HumanoidRootPart"
    hrp.Position = E.Vector3.new(pos[1], pos[2], pos[3])
    local head = E.Instance.new("Part"); head.Name = "Head"
    head.Position = E.Vector3.new(pos[1], pos[2] + 1.5, pos[3])
    local hum = E.Instance.new("Humanoid"); hum.Health = 100; hum.MaxHealth = 100
    table.insert(ch._children, hrp)
    table.insert(ch._children, head)
    table.insert(ch._children, hum)
    plr.Character = ch
    if isFriend then plr.IsFriendsWith = function() return true end end
    return plr
end
local myTeam = E.Instance.new("Team"); myTeam.Name = "Blue"
lp.Team = myTeam
local enemy = mkPlayer("Enemy", { 0, 0, 10 }, false, nil)
local mate = mkPlayer("Mate", { 0, 0, 20 }, false, myTeam)
local buddy = mkPlayer("Buddy", { 0, 0, 30 }, true, nil)
PS.GetPlayers = function() return { lp, enemy, mate, buddy } end

local RSf = E.game:GetService("RunService")
local function frame()
    simClock = simClock + 0.016
    pcall(function() RSf.RenderStepped:Fire(0.016) end)
    M.resumeAll()
end

api.SetESP(true)
frame()
local function dump(tag)
    local out = {}
    for plr, data in pairs(api.ESP.objects) do
        table.insert(out, plr.Name .. "=" .. (data.hidden and "hidden" or "shown"))
    end
    table.sort(out)
    print("ESP " .. tag .. ": " .. table.concat(out, ", "))
end
dump("default")
api.ESP.ignoreTeam = false; frame(); dump("team shown")
api.ESP.ignoreFriends = false; frame(); dump("friends shown")
api.ESP.maxDist = 15; frame(); dump("maxDist=15")
api.ESP.maxDist = 500
api.ESP.visibleOnly = true; frame(); print("ESP visibleOnly: no crash")
api.ESP.visibleOnly = false
api.ESP.box = false; frame()
local anyBox = false
for _, data in pairs(api.ESP.objects) do
    for _, l in ipairs(data.box) do if l.Visible then anyBox = true end end
end
print("ESP box=off -> box lines visible: " .. tostring(anyBox))
api.ESP.box = true
api.ESP.colorBox = "Красный"
frame()
local c = nil
for _, data in pairs(api.ESP.objects) do if not data.hidden then c = data.box[1].BackgroundColor3 end end
print("ESP box color: " .. (c and string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5),
    math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) or "none"))
api.ESP.name = false; frame()
local nameVisible = nil
for _, data in pairs(api.ESP.objects) do if not data.hidden then nameVisible = data.nameLabel.Visible end end
print("ESP name=off -> label visible: " .. tostring(nameVisible))

-- визуалы как в обзоре Vanish: уголки по умолчанию, дистанция и тег команды под боксом
api.ESP.name = true
api.ESP.box = true
api.ESP.boxStyle = "Уголки"
api.ESP.dist = true
api.ESP.teamTag = true
frame()
local function styleState()
    local cornersOn, frameOn, distTxt, teamTxt = false, false, nil, nil
    for plr, data in pairs(api.ESP.objects) do
        if not data.hidden then
            for _, l in ipairs(data.corners) do if l.Visible then cornersOn = true end end
            for _, l in ipairs(data.box) do if l.Visible then frameOn = true end end
            if plr.Name == "Mate" then
                distTxt = data.distLabel.Text
                teamTxt = data.teamLabel.Text
            end
        end
    end
    return cornersOn, frameOn, distTxt, teamTxt
end
local co, fo, dt, tt = styleState()
print("ESP style=Уголки: corners=" .. tostring(co) .. " frame=" .. tostring(fo))
print("ESP under-box: dist=" .. tostring(dt) .. " team=" .. tostring(tt))
api.ESP.boxStyle = "Рамка"; frame()
co, fo = styleState()
print("ESP style=Рамка: corners=" .. tostring(co) .. " frame=" .. tostring(fo))
api.ESP.boxStyle = "Уголки"
api.SetESP(false)
frame()
print("ESP off -> objects: " .. tostring(next(api.ESP.objects) == nil and 0 or 1))

-- Air Stuck (Physics): держит точку включения и гасит PlatformStand при выключении
local lpc = lp.Character
local lroot = lpc:FindFirstChild("HumanoidRootPart")
local lhum = lpc:FindFirstChildOfClass("Humanoid")
api.Features.airstuck.mode = "Physics"
api.Features.airstuck.maxHold = 0
lroot.CFrame = E.CFrame.new(3, 40, 3)
api.SetAirstuck(true)
pcall(function() RSf.Stepped:Fire(0.016, 0) end)
M.resumeAll()
print("AIRSTUCK on: platform=" .. tostring(lhum.PlatformStand))
lroot.CFrame = E.CFrame.new(99, 0, 99)
pcall(function() RSf.Stepped:Fire(0.016, 0) end)
M.resumeAll()
local ap = lroot.CFrame.Position
print(("AIRSTUCK hold: %.1f,%.1f,%.1f"):format(ap.X, ap.Y, ap.Z))
api.SetAirstuck(false)
print("AIRSTUCK off: platform=" .. tostring(lhum.PlatformStand))

-- Air Stuck (Packet): лаг-свитч режет исходящий трафик, тело локально живое
api.Features.airstuck.mode = "Packet"
api.Features.airstuck.throttle = 10
api.Features.airstuck.maxHold = 0
lroot.CFrame = E.CFrame.new(3, 40, 3)
api.SetAirstuck(true)
print("AIRSTUCK packet on: net=" .. tostring(api.Features.airstuck.net)
    .. " limit=" .. tostring(E.netStub and E.netStub.limit))
lroot.CFrame = E.CFrame.new(20, 40, 20)
pcall(function() RSf.Stepped:Fire(0.016, 0) end)
M.resumeAll()
local pp = lroot.CFrame.Position
print(("AIRSTUCK packet move: %.1f,%.1f,%.1f platform=%s"):format(pp.X, pp.Y, pp.Z, tostring(lhum.PlatformStand)))
api.SetAirstuck(false)
print("AIRSTUCK packet off: limit=" .. tostring(E.netStub and E.netStub.limit)
    .. " net=" .. tostring(api.Features.airstuck.net))

-- Max Hold сам отпускает трафик (иначе сервер кикнет за потерю связи)
api.Features.airstuck.maxHold = 0.05
api.SetAirstuck(true)
simClock = simClock + 0.2
pcall(function() RSf.Stepped:Fire(0.016, 0) end)
M.resumeAll()
print("AIRSTUCK maxHold: on=" .. tostring(api.Features.airstuck.on)
    .. " limit=" .. tostring(E.netStub and E.netStub.limit))
api.Features.airstuck.mode = "Physics"

-- Ghost Stand: якорь (для других стоишь) + телепорт к камере при выключении
local wsG = E.game:GetService("Workspace")
wsG.CurrentCamera.CFrame = E.CFrame.new(12, 50, 12)
api.SetGhostFreeze(true)
print("GHOST on: anchored=" .. tostring(lroot.Anchored))
pcall(function() RSf.RenderStepped:Fire(0.016) end)
M.resumeAll()
api.SetGhostFreeze(false)
local gp = lroot.CFrame.Position
print(("GHOST off: anchored=%s pos=%.1f,%.1f,%.1f"):format(tostring(lroot.Anchored), gp.X, gp.Y, gp.Z))

-- AIMBOT / AIM ASSIST: плавный довод камеры (шаг в углах, а не Lerp по CFrame)
local camG = wsG.CurrentCamera
local headEN = enemy.Character:FindFirstChild("Head")
local function resetCam()
    camG.CFrame = E.CFrame.lookAt(E.Vector3.new(0, 0, 0), E.Vector3.new(0, 0, 1))
end
local function camDot()
    local l = camG.CFrame.LookVector
    local h = headEN.Position
    local m = math.sqrt(h.X ^ 2 + h.Y ^ 2 + h.Z ^ 2)
    return (l.X * h.X + l.Y * h.Y + l.Z * h.Z) / m
end

resetCam()
local baseDot = camDot()
api.SetAimbot(true)
frame()
local dotAim1 = camDot()
api.SetAimbot(false)

resetCam()
api.SetAimAssist(true)
frame()
local dotAssist1 = camDot()
api.SetAimAssist(false)
print(("AIMSTEP base=%.5f aim=%.5f assist=%.5f"):format(baseDot, dotAim1, dotAssist1))
print("AIM mutually exclusive: aimOff=" .. tostring(api.Features.aim.on) .. " assistOff=" .. tostring(api.Features.assist.on))

api.SetAimbot(true)
for _ = 1, 90 do frame() end
local aimTarget = api.Features.aim.target
local dotAimEnd = camDot()
api.SetAimbot(false)
print(("AIMLOCK target=%s dot=%.5f"):format(tostring(aimTarget and aimTarget.Name), dotAimEnd))

-- SCAFFOLD: дырка под ногами -> камера в точку -> Tool:Activate()
lroot.Position = E.Vector3.new(0, 3, 0)
lroot.CFrame = E.CFrame.lookAt(E.Vector3.new(0, 3, 0), E.Vector3.new(0, 3, 1))
lroot.AssemblyLinearVelocity = E.Vector3.new(0, 0, 0)
local tool = E.Instance.new("Tool")
tool.Name = "Blocks"
local placed = 0
tool.Activate = function() placed = placed + 1 end
table.insert(lpc._children, tool)
api.SetScaffold(true)
for _ = 1, 60 do frame() end
local scf = api.Features.scaffold
print(("SCAFFOLD placed=%d cell=%s point=%s"):format(placed, tostring(scf.cell ~= nil), tostring(scf.point ~= nil)))

-- SafeWalk: скорость в сторону дырки должна погаснуть
lroot.AssemblyLinearVelocity = E.Vector3.new(0, 0, -8)
frame()
local sv = lroot.AssemblyLinearVelocity
print(("SAFEWALK vel=%.1f,%.1f,%.1f"):format(sv.X, sv.Y, sv.Z))

-- камера должна идти за персонажем и когда ставить некуда (сплошной пол)
lroot.CFrame = E.CFrame.new(0, 3, 0)
lroot.Position = E.Vector3.new(0, 3, 0)  -- в моке CFrame и Position не связаны
lroot.AssemblyLinearVelocity = E.Vector3.new(0, 0, 0)
for _ = 1, 20 do frame() end
local camHole = camG.CFrame.Position
lroot.CFrame = E.CFrame.new(40, 3, 40)
lroot.Position = E.Vector3.new(40, 3, 40)
for _ = 1, 20 do frame() end
local camSolid = camG.CFrame.Position
print(("SCAFFOLD cam follow: hole=%.1f,%.1f,%.1f solid=%.1f,%.1f,%.1f"):format(
    camHole.X, camHole.Y, camHole.Z, camSolid.X, camSolid.Y, camSolid.Z))

api.SetScaffold(false)
print("SCAFFOLD off: scriptable=" .. tostring(camG.CameraType == E.Enum.CameraType.Scriptable) .. " placed=" .. tostring(scf.placed))

-- камера осталась в Scriptable от прошлого запуска — выключение лечит
camG.CameraType = E.Enum.CameraType.Scriptable
api.SetScaffold(true)
api.SetScaffold(false)
print("SCAFFOLD heal: custom=" .. tostring(camG.CameraType == E.Enum.CameraType.Custom))

-- SILENT AIM: хуки встают и снимаются, не ломая чтение свойств, скаффолд,
-- камеру и Click TP
local gmtS = getmetatable(E.game)
local namecallBefore = gmtS.__namecall
api.SetSilentAim(true)
print("SILENT on: on=" .. tostring(api.Features.silent.on)
    .. " hooked=" .. tostring(gmtS.__namecall ~= namecallBefore))
print("SILENT read: place=" .. tostring(E.game.PlaceId)
    .. " missing=" .. tostring(E.game.__nope))

-- эмулируем Luau namecall: хук должен развернуть луч в цель
E.__namecallMethod = "FindPartOnRay"
E.__lastCall = nil
pcall(function()
    gmtS.__namecall(E.workspace, { Origin = E.Vector3.new(0, 0, 0), Direction = E.Vector3.new(0, 0, 1) })
end)
local rayD = E.__lastCall and E.__lastCall[1] and E.__lastCall[1].Direction
print("SILENT ray retarget: len=" .. (rayD and string.format("%.1f", rayD.Magnitude) or "nil")
    .. " dirZ=" .. (rayD and string.format("%.3f", rayD.Z) or "nil"))

-- Click TP под silent aim: Hit/Target подменены на голову цели, а телепорт
-- должен брать точку из UnitRay (под курсором)
local mouseMock = {
    X = 5, Y = 5,
    Target = headEN,
    Hit = E.CFrame.new(headEN.Position),
    UnitRay = { Origin = E.Vector3.new(5, 10, 5), Direction = E.Vector3.new(0, -1, 0) },
}
lp.GetMouse = function() return mouseMock end
api.Features.clickTp.height = 3
api.SetClickTp(true)
pcall(function() uis.InputBegan:Fire({ UserInputType = E.Enum.UserInputType.MouseButton1 }, false) end)
M.resumeAll()
local ctp = lroot.CFrame.Position
print(("CLICKTP under silent: %.1f,%.1f,%.1f"):format(ctp.X, ctp.Y, ctp.Z))
api.SetClickTp(false)

-- scaffold + камера под silent aim
lroot.CFrame = E.CFrame.new(0, 3, 0)
lroot.Position = E.Vector3.new(0, 3, 0)
lroot.AssemblyLinearVelocity = E.Vector3.new(0, 0, 0)
api.SetScaffold(true)
for _ = 1, 20 do frame() end
local camS1 = camG.CFrame.Position
lroot.CFrame = E.CFrame.new(40, 3, 40)
lroot.Position = E.Vector3.new(40, 3, 40)
for _ = 1, 20 do frame() end
local camS2 = camG.CFrame.Position
print(("SCAFFOLD under silent: scriptable=%s from=%.1f,%.1f,%.1f to=%.1f,%.1f,%.1f"):format(
    tostring(camG.CameraType == E.Enum.CameraType.Scriptable),
    camS1.X, camS1.Y, camS1.Z, camS2.X, camS2.Y, camS2.Z))
api.SetScaffold(false)
print("SCAFFOLD under silent off: custom=" .. tostring(camG.CameraType == E.Enum.CameraType.Custom))

-- выключили silent aim — хуки вернулись на место
api.SetSilentAim(false)
E.__namecallMethod = nil
print("SILENT off: on=" .. tostring(api.Features.silent.on)
    .. " namecall=" .. tostring(gmtS.__namecall == namecallBefore)
    .. " index=" .. tostring(gmtS.__index == E.__gameIndex))

-- SKELETON: линия должна идти от сустава к суставу (вращение вокруг центра)
local skelChar = E.Instance.new("Model")
local function bone(name, x, y)
    local part = E.Instance.new("Part")
    part.Name = name
    part.Position = E.Vector3.new(x, y, 0)
    part.Parent = skelChar
    return part
end
bone("Head", 0, 2)
bone("UpperTorso", 0, 1)
bone("LowerTorso", 0, 0)
bone("LeftUpperArm", -1, 1)
bone("RightUpperArm", 1, 1)
bone("LeftLowerArm", -2, 1)
bone("LeftHand", -2.5, 1)
bone("RightLowerArm", 2, 1)
bone("RightHand", 2.5, 1)
bone("LeftUpperLeg", -0.5, -1.5)
bone("RightUpperLeg", 0.5, -1.5)
bone("LeftLowerLeg", -0.5, -2.5)
bone("LeftFoot", -0.5, -3.5)
bone("RightLowerLeg", 0.5, -2.5)
bone("RightFoot", 0.5, -3.5)
local skelHum = E.Instance.new("Humanoid")
skelHum.Health = 100
skelHum.MaxHealth = 100
skelHum.Parent = skelChar
local skelRoot = E.Instance.new("Part")
skelRoot.Name = "HumanoidRootPart"
skelRoot.Position = E.Vector3.new(0, 1, 0)
skelRoot.Parent = skelChar
local skelPlr = E.Instance.new("Player")
skelPlr.Name = "Skelly"
skelPlr.Character = skelChar
skelChar.Parent = wsG

-- ортопроекция: 10 px на студ, центр экрана 960x540 в мировой (0,0)
camG.WorldToViewportPoint = function(_, pos)
    return E.Vector3.new(960 + pos.X * 10, 540 - pos.Y * 10, 10), 10, true
end
api.SetESP(false)
local playersOld = PS.GetPlayers
PS.GetPlayers = function() return { lp, enemy, mate, buddy, skelPlr } end
api.Features.esp.skel = true
api.SetESP(true)
frame()
local skelFrames = api.Features.esp.skelFrames[skelPlr] or {}
local lineHT = skelFrames[1]   -- Head -> UpperTorso
local lineLA = skelFrames[5]   -- LeftUpperArm -> LeftLowerArm
print(("SKELETON head-top: pos=%.1f,%.1f size=%.1f rot=%.1f"):format(
    lineHT.Position.X.Offset, lineHT.Position.Y.Offset, lineHT.Size.X.Offset, lineHT.Rotation))
print(("SKELETON arm: pos=%.1f,%.1f size=%.1f rot=%.1f"):format(
    lineLA.Position.X.Offset, lineLA.Position.Y.Offset, lineLA.Size.X.Offset, lineLA.Rotation))
local skelDots = api.Features.esp.skelDotFrames[skelPlr] or {}
local dotsOn = 0
for _, d in ipairs(skelDots) do if d.Visible then dotsOn = dotsOn + 1 end end
print("SKELETON dots: total=" .. #skelDots .. " visible=" .. dotsOn)
api.SetESP(false)
PS.GetPlayers = playersOld

-- NoClip: гасит коллизии частей и возвращает их назад
local nroot = lp.Character:FindFirstChild("HumanoidRootPart")
nroot.CanCollide = true
api.SetNoclip(true)
print("NOCLIP on: collide=" .. tostring(nroot.CanCollide))
api.SetNoclip(false)
print("NOCLIP off: collide=" .. tostring(nroot.CanCollide))

-- Free Camera: камера отцепляется и летит на WASD, тело стоит
local fcamt = wsG.CurrentCamera
uis.IsKeyDown = function(_, key) return key == E.Enum.KeyCode.W end
uis.GetMouseDelta = function() return E.Vector2.new(0, 4) end
api.SetFreecam(true)
local cp1 = api.Features.freecam.pos
pcall(function() RSf.RenderStepped:Fire(0.1) end)
M.resumeAll()
local cp2 = api.Features.freecam.pos
print(("FREECAM on: scriptable=%s from=%.1f,%.1f,%.1f to=%.1f,%.1f,%.1f walk=%s"):format(
    tostring(fcamt.CameraType == E.Enum.CameraType.Scriptable), cp1.X, cp1.Y, cp1.Z, cp2.X, cp2.Y, cp2.Z,
    tostring(api.Features.freecam.walk)))
api.Toggle(true)
local menuCursor = uis.MouseBehavior == E.Enum.MouseBehavior.Default
api.Toggle(false)
local menuLocked = uis.MouseBehavior == E.Enum.MouseBehavior.LockCenter
print("FREECAM menu: openCursor=" .. tostring(menuCursor) .. " closedLock=" .. tostring(menuLocked))
api.SetFreecam(false)
uis.IsKeyDown = function() return false end
uis.GetMouseDelta = function() return E.Vector2.new(0, 0) end
print("FREECAM off: custom=" .. tostring(fcamt.CameraType == E.Enum.CameraType.Custom)
    .. " pos=" .. tostring(api.Features.freecam.pos)
    .. " walk=" .. tostring(lhum and lhum.WalkSpeed))

-- Anti Aim: корпус реально доворачивается + режимы + head tilt
local neckM = E.Instance.new("Motor6D")
neckM.Name = "Neck"
neckM.C0 = E.CFrame.new(0, 1, 0)
neckM.Parent = lp.Character
table.insert(lp.Character._children, neckM)  -- в моке Parent сам в детей не добавляет
local AA = api.Features.antiaim
AA.mode = "Static"; AA.yaw = 90; AA.pitch = "Нет"; AA.headTilt = true; AA.pitchAngle = 50
api.SetAntiAim(true)
pcall(function() RSf.Heartbeat:Fire(0.016) end)
M.resumeAll()
local aaNeck = AA.neck
local aaOrig = aaNeck and AA.orig[aaNeck]
print(("ANTIAIM static: yaw=%.1f autoRotate=%s headTilt=%s"):format(
    math.deg(AA.lastYaw), tostring(AA.autoRotate ~= nil),
    tostring(aaOrig ~= nil and aaNeck.C0 ~= aaOrig)))
for _, m in ipairs({ "Jitter", "Spin", "Random" }) do
    AA.mode = m
    pcall(function() RSf.Heartbeat:Fire(0.05) end)
    M.resumeAll()
end
print("ANTIAIM modes: spin=" .. tostring((AA.spin or 0) ~= 0) .. " rand=" .. tostring(AA.randOff ~= nil))
AA.mode = "Static"; AA.yaw = 0; AA.pitch = "Вверх"; AA.pitchAngle = 89
pcall(function() RSf.Heartbeat:Fire(0.016) end)
M.resumeAll()
print(("ANTIAIM pitch: last=%.1f"):format(math.deg(AA.lastPitch or 0)))
api.SetAntiAim(false)
print("ANTIAIM off: neckRestored=" .. tostring(aaOrig ~= nil and aaNeck.C0 == aaOrig)
    .. " autoRotate=" .. tostring(AA.autoRotate == nil and lhum.AutoRotate == true)
    .. " conn=" .. tostring(AA.conn == nil))

-- конфиги: save -> load -> list -> delete
local sok, serr = api.SaveConfig("test")
print("SAVE: " .. tostring(sok) .. " " .. tostring(serr or ""))
local lok, lres = api.LoadConfig("test")
print("LOAD: " .. tostring(lok) .. " applied=" .. tostring(lres))
print("LIST: " .. table.concat(api.ListConfigs(), ","))
print("DELETE: " .. tostring(api.DeleteConfig("test")) .. " left=" .. #api.ListConfigs())
"""


def main() -> int:
    code = open("neverlose_gui.lua", encoding="utf-8").read()
    rt = lupa.LuaRuntime(unpack_returned_tuples=True)
    load = rt.eval("load")
    mock = load(open("tools/rbxmock.lua", encoding="utf-8").read(), "@rbxmock")()
    g = rt.globals()
    g["MOCK"] = mock
    g["SCRIPT_SRC"] = code
    runner = load(RUNNER, "@runner")
    if runner is None:
        print("RUNNER COMPILE FAIL")
        return 1
    runner()
    return 0


if __name__ == "__main__":
    sys.exit(main())
