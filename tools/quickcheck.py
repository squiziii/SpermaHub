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

for i = 1, 3 do
    pcall(function() M.rs.Heartbeat:Fire(0.016) end)
    pcall(function() M.rs.Stepped:Fire(0.016, 0) end)
    pcall(function() M.rs.RenderStepped:Fire(0.016) end)
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
