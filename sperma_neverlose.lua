--// SPERMAHUB SAFE LOADER (rev43)
--// 1) полифилл gcinfo (на Delta нет)  2) обф → pcall → фолбэк на чистый код
local BRANCH = "https://raw.githubusercontent.com/squiziii/SpermaHub/arena/01a0b8ab-spermahub/"
local OBF_FILE   = "sperma_obf_build.lua"
local CLEAN_FILE = "sperma_src_rev35.lua"

local G = (getgenv and getgenv()) or _G or getfenv(0)
if G.gcinfo == nil then
    G.gcinfo = function() return math.max(1, math.floor(collectgarbage("count"))) end
end
if G.syn == nil then G.syn = {} end

local function get(name)
    for i = 1, 3 do
        local ok, r = pcall(function() return game:HttpGet(BRANCH .. name .. "?t=" .. tostring(os.clock()) .. tostring(i)) end)
        if ok and type(r) == "string" and #r > 10000 then
            return r
        end
        task.wait(1.5)
    end
    return nil
end

local function isObf(s) return #s > 50000 end
local function isClean(s) return #s > 500000 and s:sub(1, 3000):find("%[SpermaHub%]") ~= nil end

local function runClean(reason)
    if reason then
        warn("[SpermaHub] обф недоступен/сломан, гружу чистый код: " .. tostring(reason))
    end
    local src = get(CLEAN_FILE)
    if not src or not isClean(src) then
        error("[SpermaHub] не смог скачать чистый код (src=" .. tostring(src and #src or nil) .. "B) — попробуй позже")
        return
    end
    local f, cerr = loadstring(src, "spermahub")
    if not f then
        error("[SpermaHub] чистый код не скомпилировался: " .. tostring(cerr))
        return
    end
    f()
end

task.spawn(function()
    local obf = get(OBF_FILE)
    if not obf or not isObf(obf) then
        runClean("нет обфа (size=" .. tostring(obf and #obf or nil) .. ")")
        return
    end
    local f, cerr = loadstring(obf, "spermahub_obf")
    if not f then
        runClean("обф не скомпилировался: " .. tostring(cerr))
        return
    end
    local okRun, errRun = xpcall(f, function(e) return tostring(e) .. " | " .. tostring(debug and debug.traceback and debug.traceback("", 2) or "") end)
    if not okRun then
        runClean("обф упал в рантайме: " .. tostring(errRun))
        return
    end
end)
