-- =====================================================================
-- SPERMAHUB SERVER AUTH (rev45+) — клиентский блок серверной валидации
-- ВСТАВИТЬ в начало sperma_neverlose.lua ПОСЛЕ сервисов, ДО логики хаба.
-- Всё, что нужно юзеру: валидный ключ с твоего Vercel-сервера так, что
-- обрезки из утечки без сервера не работают.
-- =====================================================================

--// НАСТРОЙКИ (сменить под себя) ======================================
local SERVER_URL  = "https://ТВОЙ-ПРОЕКТ.vercel.app"  -- без слеша в конце!
local APP_SECRET  = "ТОТ_ЖЕ_СЕКРЕТ_ЧТО_В_VERCEL_ENV"  -- для проверки sig2
local TOKEN_TTL   = 600                                -- должен совпадать с сервером
-- =====================================================================

local HttpService = game:GetService("HttpService")

--// FNV-1a 32bit (та же самая функция, что на сервере)
local function fnv32(s)
    local h = 2166136261
    for i = 1, #s do
        h = bit32.bxor(h, s:byte(i))
        h = (h * 16777619) % 4294967296
    end
    return string.format("%08x", h)
end

--// Запрос авторизации → true + данные токена, или false + текст ошибки
local function ServerAuth(key, hwid, buildRev)
    local url = string.format("%s/api/auth?key=%s&hwid=%s&rev=%s",
        SERVER_URL,
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(hwid),
        tostring(buildRev))

    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or type(raw) ~= "string" then
        return false, "нет связи с сервером авторизации"
    end

    local okJ, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okJ or type(data) ~= "table" then
        return false, "сервер вернул мусор"
    end

    if data.ok ~= true then
        local msgs = {
            no_key = "ключ не найден",
            banned = "ключ ЗАБАНЕН",
            expired = "ключ истёк",
            hwid_mismatch = "ключ привязан к другому устройству (сброс — у админа)",
            activation_limit = "лимит активаций исчерпан",
            update_required = "обнови скрипт!",
            db_unavailable = "сервер базы временно недоступен"
        }
        return false, msgs[tostring(data.err)] or ("отказ: " .. tostring(data.err))
    end

    --// проверка подписи и срока токена
    local exp = tonumber(data.exp) or 0
    if exp <= os.time() then return false, "токен уже просрочен (повтори)" end
    local payload = string.format("ok=1|key=%s|hwid=%s|exp=%s", key, hwid, tostring(exp))
    if tostring(data.sig2) ~= fnv32(payload .. "|" .. APP_SECRET) then
        return false, "подпись ответа не сошлась (подделка?)"
    end

    return true, data
end

--// ОСНОВНОЙ ВЫЗОВ (пример):
--[[
local key = ВВОД_ЮЗЕРА  -- из твоего KeySystem GUI
local hwid = (gethwid and gethwid()) or (getexecutorname and getexecutorname() or "unknown") .. "|" .. game.Players.LocalPlayer.UserId
local okAuth, info = ServerAuth(key, hwid, BUILD_REV)
if not okAuth then
    warn("[SpermaHub] ⛔ серверная проверка не пройдена: " .. tostring(info))
    -- тут показать в GUI красную надпись и ВЫЙТИ, sku НЕ грузить хаб
    return
end
-- дальше грузится основной хаб (esp/gui/фичи) — без этого блока его быть не должно
]]
