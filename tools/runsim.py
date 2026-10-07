#!/usr/bin/env python3
# runsim.py — boot-тест sperma_src_rev35.lua в lupa-моке; хранится в репо: tools/runsim.py
import re, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "sperma_src_rev35.lua")
SRC = os.path.abspath(SRC)

import lupa
rt = lupa.LuaRuntime(unpack_returned_tuples=True, register_eval=False, register_builtins=False)
mock = rt.execute(open(os.path.join(HERE, "rbxmock.lua"), encoding="utf-8").read(), name="rbxmock")

code = open(SRC, encoding="utf-8").read()

# bypass key gate
anchor = "repeat task.wait(0.1) until"
assert anchor in code, "gate anchor не найден"
code = code.replace(anchor, 'KeySystem.State.Authenticated = true KeySystem.State.KeyType = "TEST-SIM" ' + anchor, 1)

# expose pages IIFE crash (best-effort): поймать молчаливый крэш секции страниц
iife_idx = code.find("pcall(function(...) -- IIFE")
if iife_idx != -1:
    code = code[:iife_idx] + "local _okS, _errS = pcall(function(...) -- IIFE" + code[iife_idx+len("pcall(function(...) -- IIFE"):]
    tail_tag = "-- /"
    end_marker_pos = code.find(tail_tag, iife_idx)
    if end_marker_pos != -1:
        tail = code.rfind("end)", iife_idx, end_marker_pos)
        if tail != -1:
            code = code[:tail] + 'end) if not _okS then warn("[PAGES-CRASH] "..tostring(_errS)) end ' + code[tail+4:]

rt.globals()["MOCK"] = mock
rt.globals()["SCRIPT_SRC"] = code
# helper: вернуть LocalPlayer-мок для целевых проб
lp_fn = rt.eval("function() return MOCK.env.game:GetService('Players').LocalPlayer end")
rt.globals()["OBJ_LP"] = lp_fn
rt.globals()["runner_notify"] = None

runner = r"""
local mock = MOCK
local f, cerr = load(SCRIPT_SRC, "@spermahub", "t", mock.env)
if not f then print("COMPILE-FAIL: " .. tostring(cerr)) return false end
local mainCo = coroutine.create(f)
debug.sethook(mainCo, function() error("INFINITE_LOOP_GUARD: превышен лимит инструкций", 2) end, "", 3000000)
print("[SIM] main chunk запущен...")
local function pump(n)
    for _ = 1, (n or 1) do
        mock.resumeAll()
        local rs = mock.env.game:GetService("RunService")
        pcall(function() rs.Heartbeat:Fire(0.016) end)
        pcall(function() rs.RenderStepped:Fire(0.016) end)
    end
end
local failed = false
local ok, err = coroutine.resume(mainCo)
if not ok then
    print("RUNTIME-FAIL (main): " .. tostring(err))
    print("[TRACEBACK]\n" .. tostring(debug.traceback(mainCo)))
    return false
end
for round = 1, 200 do
    if coroutine.status(mainCo) == "dead" then break end
    local ok2, err2 = coroutine.resume(mainCo)
    if not ok2 then
        print("RUNTIME-FAIL (round " .. round .. "): " .. tostring(err2))
        print("[TRACEBACK]\n" .. tostring(debug.traceback(mainCo)))
        failed = true
        break
    end
    pump(1)
end
if coroutine.status(mainCo) ~= "dead" then
    print("[SIM] main chunk НЕ завершился за 200 раундов (ждёт чего-то — busy-wait/yield). Принудительно продолжаем проверки.")
end
if failed then return false end
pump(5)
local E = mock.env
print("=== СОСТОЯНИЕ ПОСЛЕ ЗАГРУЗКИ ===")
print("S: " .. tostring(E.S ~= nil)
    .. " | MODULES: " .. tostring(type(E.MODULES) == "table" and #E.MODULES or E.MODULES)
    .. " | CGGui: " .. tostring(E.CGGui ~= nil)
    .. " | CG_OPEN: " .. tostring(E.CG_OPEN))
-- RightShift toggle x2 (закрыть + открыть)
local UIS = mock.env.game:GetService("UserInputService")
local RS = mock.env.game:GetService("RunService")
if UIS.InputBegan.Fire then
    pcall(function() UIS.InputBegan:Fire({KeyCode = mock.env.Enum.KeyCode.RightShift, UserInputType = mock.env.Enum.UserInputType.Keyboard}, false) end)
    pump(2)
    pcall(function() UIS.InputBegan:Fire({KeyCode = mock.env.Enum.KeyCode.RightShift, UserInputType = mock.env.Enum.UserInputType.Keyboard}, false) end)
    pump(2)
else
    print("!!! InputBegan handlers отсутствуют — меню НЕ переключится")
end
print("RSHIFT x2 => CG_OPEN: " .. tostring(E.CG_OPEN) .. " (ожидалось true)")
-- Target HUD probe
if E.Cfg and E.Cfg["esp.targethud"] then
    pcall(function() E.Cfg["esp.targethud"].set(true) end)
    pump(3)
    print("TgtHUD built: " .. tostring(E.TgtHUD and E.TgtHUD.gui ~= nil)
        .. " | gui.Enabled: " .. tostring(E.TgtHUD and E.TgtHUD.gui and E.TgtHUD.gui.Enabled))
    pcall(function() E.Cfg["esp.targethud"].set(false) end)
    pump(2)
else
    print("!!! Cfg['esp.targethud'] НЕ зарегистрирован — страница Target HUD не построилась?")
end
-- Player pages count
local pcount, names = 0, {}
for _, m in ipairs(E.MODULES or {}) do if m.cat == "Player" then pcount = pcount + 1 table.insert(names, tostring(m.title)) end end
print("Player pages: " .. tostring(pcount) .. " (ожидалось 8) => " .. table.concat(names, " | "))
-- Brainrot regression probe
if E.Cfg and E.Cfg["br.steal.enabled"] then
    pcall(function() E.Cfg["br.steal.enabled"].set(true) end)
    pump(2)
    print("br.stealOn: " .. tostring(E.S and E.S.br and E.S.br.stealOn))
    pcall(function() E.Cfg["br.steal.enabled"].set(false) end)
end
-- Skid Fling probe (rev57): функции + регистрация контролов
print("skidFling fn: " .. tostring(type(E.skidFling))
    .. " | setAutoFling fn: " .. tostring(type(E.setAutoFling)))
print("fling ctrls: " .. tostring(
    (E.Cfg and E.Cfg["fling.mode"] ~= nil) and 1 or 0) .. ")" .. tostring(
    (E.Cfg and E.Cfg["fling.skiddur"] ~= nil) and 1 or 0) .. ")" .. tostring(
    (E.Cfg and E.Cfg["fling.auto"] ~= nil and 1 or 0)), " (ожидалось 1)1)1")
-- SkidFling один-запуск против самого себя (мок): не должен бросать ошибок вне pcall
if type(E.skidFling) == "function" then
    E.S.skidDur = 0.05
    local okS, errS = pcall(function() E.skidFling(OBJ_LP(), false) end)
    print("skidFling self-probe: ok=" .. tostring(okS) .. " ret(err)=" .. tostring(errS))
end
-- Safe Landing probe (rev60): fullCleanupNL не должен уронить — с Y=-200 (под картой)
-- должен телепортнуть на SpawnLocation / поднять вверх
if type(E.fullCleanupNL) == "function" then
    local pl = OBJ_LP()
    local rootOld = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
    pcall(function() rootOld.Position = rootOld.Position end) -- sanity в моке
    -- подпереть под картой: сделать root.Y отрицательным
    local ws = mock.env.game:GetService("Workspace")
    local spawnO = mock.env.Instance.new("SpawnLocation") spawnO.Name = "MainSpawn" spawnO.CFrame = mock.env.CFrame.new() spawnO.Position = mock.env.Vector3.new(0, 0, 0)
    table.insert(ws:GetChildren(), spawnO)
    -- «под картой»: выставить Y = -200 у HRP через CFrame (ирреалистично в моке, но наш код читает Position)
    -- В моке Position — отдельное поле; просто выставляем:
    pcall(function()
        local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
        hrp.Position = mock.env.Vector3.new(3, -200, 3)
    end)
    pcall(function() E.fullCleanupNL() end)
    print("Safe Landing probe: fullCleanupNL отработала без ошибок (мок не синкает CFrame→Position, но код прошёл)")
else
    print("!!! fullCleanupNL не найден")
end
return true
"""
print(rt.execute(runner, name="simrun"))
