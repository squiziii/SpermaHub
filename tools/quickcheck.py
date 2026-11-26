#!/usr/bin/env python3
"""Быстрая мок-проверка neverlose_gui.lua: компиляция, бут, список страниц, карточки Main."""
import sys
import lupa

RUNNER = r"""
local M = MOCK
local E = M.env

-- патчи мока под реальный Roblox
E.math.clamp = function(v, a, b) if v < a then return a elseif v > b then return b else return v end end
E.ColorSequence = function(...) return { ... } end
E.ColorSequenceKeypoint = function(t, c) return { Time = t, Value = c } end
if E.Color3 and E.Color3.toHSV == nil then
    E.Color3.toHSV = function(c) return 0, 0, 1 end
end
local CFold = E.CFrame.new
E.CFrame.new = function(...)
    local cf = CFold(...)
    if select('#', ...) >= 3 then cf.Position = E.Vector3.new(...) end
    return cf
end

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
            or o.Text == "Position" or o.Text == "Walk Speed") then
            table.insert(found, o.Text)
        end
    end
    table.sort(found)
    print("MAIN cards: " .. table.concat(found, ", "))
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
api.SetESP(false)
frame()
print("ESP off -> objects: " .. tostring(next(api.ESP.objects) == nil and 0 or 1))

-- Air Stuck: держит точку включения и гасит PlatformStand при выключении
local lpc = lp.Character
local lroot = lpc:FindFirstChild("HumanoidRootPart")
local lhum = lpc:FindFirstChildOfClass("Humanoid")
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
