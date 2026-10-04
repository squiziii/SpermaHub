--// SPERMAHUB SAFE LOADER (rev38)
--// обф → pcall, сбой → чистый исходник. Юзер никогда не упрётся.
local BRANCH = "https://raw.githubusercontent.com/squiziii/SpermaHub/arena/01a0b8ab-spermahub/"
local OBF_FILE   = "sperma_obf_build.lua"
local CLEAN_FILE = "sperma_src_rev35.lua"

local function fetch(name)
    local ok, r = pcall(function() return game:HttpGet(BRANCH .. name) end)
    if ok and type(r) == "string" and #r > 900000 then
        return r
    end
    return nil
end

local function runClean(reason)
    if reason then
        warn("[SpermaHub] обф недоступен/сломан (" .. tostring(reason) .. "), гружу чистый код")
    end
    local src = fetch(CLEAN_FILE)
    assert(src, "[SpermaHub] не смог скачать и чистый код — прием попробуй позже")
    local f, cerr = loadstring(src, "@spermahub")
    assert(f, "[SpermaHub] чистый код не скомпилировался: " .. tostring(cerr))
    f()
end

task.spawn(function()
    local obf = fetch(OBF_FILE)
    if not obf then
        runClean("не скачался обф")
        return
    end
    local f, cerr = loadstring(obf, "@spermahub_obf")
    if not f then
        runClean("обф не скомпилировался: " .. tostring(cerr))
        return
    end
    local okRun, errRun = pcall(f)
    if not okRun then
        runClean("обф упал в рантайме: " .. tostring(errRun))
        return
    end
end)
