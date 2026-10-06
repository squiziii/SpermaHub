-- синглтон: не даём запустить вторую копию (частая причина «старого худа» и пустых окон)
if getgenv and getgenv().SpermaHubRevoked then
    warn("[SpermaHub] ⛔ лицензия на этом устройстве отозвана в этой сессии — перезапуск запрещён")
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        if lp then lp:Kick("SpermaHub: лицензия отозвана администратором") end
    end)
    return
end

if getgenv and getgenv().SpermaHubRunning == true then
    warn("[SpermaHub] УЖЕ ЗАПУЩЕН — дубликат скрипта проигнорирован (перезайди в игру, если что-то не отображается)")
    return
end
if getgenv then getgenv().SpermaHubRunning = true end

-- ЛОВУШКА: фатальные ошибки потоков видны НА ЭКРАНЕ (не только в консоли)
do
    local function errToast(msg)
        pcall(function()
            local parent = nil
            pcall(function() if gethui then parent = gethui() end end)
            if not parent then parent = game:GetService("CoreGui") end
            local sg = parent:FindFirstChild("SpermaHubErrToast")
            if not sg then
                sg = Instance.new("ScreenGui")
                sg.Name = "SpermaHubErrToast"
                sg.ResetOnSpawn = false
                sg.DisplayOrder = 1002
                sg.Parent = parent
                local l = Instance.new("TextLabel")
                l.Name = "L"
                l.Size = UDim2.new(1, -40, 0, 44)
                l.Position = UDim2.new(0, 20, 0.12, 0)
                l.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
                l.TextColor3 = Color3.new(1, 1, 1)
                l.Font = Enum.Font.GothamBold
                l.TextSize = 13
                l.TextWrapped = true
                l.ZIndex = 10
                l.Parent = sg
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(0, 8)
                c.Parent = l
            end
            sg.L.Text = "SpermaHub ERROR: " .. tostring(msg):sub(1, 220)
            task.delay(8, function() pcall(function() sg:Destroy() end) end)
        end)
    end
    pcall(function()
        local lastMsg, lastAt, shown = nil, 0, 0
        game:GetService("ScriptContext").Error:Connect(function(msg, stack)
            -- реагируем ТОЛЬКО на ошибки нашего чанка (остальные — чужие скрипты)
            local st = tostring(stack or "")
            if not st:find("spermahub", 1, true) then return end
            local m = tostring(msg)
            -- дедупе: одно и то же сообщение показываем максимум раз в 60 сек; всего не больше 8 плашек
            local now = tick()
            if m == lastMsg and (now - lastAt) < 60 then return end
            if shown >= 8 then return end
            lastMsg, lastAt, shown = m, now, shown + 1
            warn("[SpermaHub][FATAL] " .. m)
            -- rev37: stacktrace печатаем — по чистому исходнику точно видно строку бага
            pcall(function()
                if st ~= "" then
                    warn("[SpermaHub][TRACE] " .. st)
                end
            end)
            errToast(m)
        end)
    end)
end

-- SpermaHub (единый скрипт: свой Click GUI + весь функционал, внешних UI-библиотек не нужно)
-- Интерфейс Voidware-стиль: панели-строки модулей, настройки на RightClick/gear,
-- нотификации свои (right-top стек).
-- Перенесены ВСЕ вкладки и функции:
--   Combat:        Legitbot | Kill Aura + Silent Aura (1.8 Arena) | Hitbox | Kill Player | Fling | Spectate | Anti-Aim | Auto Clicker
--   Visuals:       Players (ESP: Chams/Box/Skeleton/Names + Target ESP) | World
--   Movement:      Main (Flight/Noclip/Jesus/Spin/Bhop/Spider/AirStack) | Teleport (Click TP)
--   Player:        Main (WalkSpeed + God Mode + TP Player) | Invisible | No Knockback
--   Server:        Bypass (Anti-Cheat Bypass) | Server (Rejoin/Hop/Copy ID)
--   Miscellaneous: Configs | Script | Key Binds (клавиши/мышь/колёсико) + Target HUD
-- Управление: RightShift = скрыть/показать меню
-- KEY SYSTEM v2.0: админ-пароль «1337» (админка: генератор ключей), базовые ключи «sperma»/«eniloveslo» вечные

--// ============================================================
--// SPERMAHUB KEY SYSTEM v2.0
--// Админ-панель + генератор временных ключей
--// (встроена; фиксы: клики «Час»/«День» — сдвиг индексов GetChildren;
--//  math.huge в JSON (ключи «Навсегда» не сохранялись); CoreGui через GetService)
--// ============================================================

--// rev33: текущая ревизия сборки (minVersion в адмметаллце сверяется с ней)
BUILD_REV = 57

KeySystem = {
    --// Конфигурация
    Config = {
        AdminPassword = "1337",        -- Пароль от админки
        MaxAttempts = 3,               -- Попыток до кика
        SaveKeys = true,               -- Сохранять ключи в файл
        KeysFile = "sperma_keys.json", -- Файл с ключами
        HwidLock = true,               -- HWID-привязка: ключ работает только на устройстве первой активации
        MetaFile = "sperma_meta.json",       -- пароль админки + чёрный список HWID + лог активаций
        ModerPassword = "mod2288",       -- «модер»-админка (только генерация/просмотр), переопределяется meta-файлом
        HeartbeatFile = "sperma_heartbeat.json", -- метки «сейчас в игре» (key → unixtime)
        Debug = false,
        --// 🌐 СЕРВЕРНАЯ АВТОРИЗАЦИЯ (Vercel). Главная проверка ключа; оффлайн сервер → запасная локальная база.
        Server = {
            Enabled = true,
            Url = "https://sperma-key-server.vercel.app",
            AppSecret = "SineeNeboKefir13Krokodil66LetniyDen777", -- клиентская половина подписи (sig2); серверные секреты НЕ тут
            HeartbeatSecs = 120, -- каждые 2 минуты перепроверяем ключ на сервере (бан/удаление → кик)
        },
    },

    --// Типы ключей
    KeyTypes = {
        {Name = "Навсегда", Duration = math.huge, Color = Color3.fromRGB(255, 215, 0)},
        {Name = "Неделя", Duration = 7 * 24 * 3600, Color = Color3.fromRGB(147, 112, 219)},
        {Name = "День", Duration = 24 * 3600, Color = Color3.fromRGB(100, 149, 237)},
        {Name = "Час", Duration = 3600, Color = Color3.fromRGB(255, 165, 0)},
    },

    --// Состояние
    State = {
        Attempts = 0,
        Authenticated = false,
        IsAdmin = false,
        CurrentKey = nil,
        KeysDB = {}, -- {key = {type, created, expires, used, hwid, activations, banned, noHwid, note, maxActivations}}
        HwidBlacklist = {}, -- {hwid = true} — устройства в чёрном списке
        ActLog = {},        -- [{k,hw,t,ok,r}] — последние 40 событий логина
        SelectedKey = nil,
        Heartbeats = {},    -- кэш: key → unixtime последнего пинга
        AuditLog = {},      -- [{t, a}] — что админ натискал (30 посл.)
        BruteCount = {},    -- {hwid = n} — неудачные попытки с устройства
        MultiSel = {},      -- [key]=true — мультивыбор в списке
        IsModer = false, SilentTroll = false,
        Motd = "", Maintenance = false, MinVersion = nil,
        MetaAdminHwid = nil, LastAutoClean = 0,
    }
}

Players = game:GetService("Players")
LocalPlayer = Players.LocalPlayer
HttpService = game:GetService("HttpService")
CoreGuiSvc = game:GetService("CoreGui")

--// HWID устройства (gethwid → fallback UserId)
function GetHWID()
    local ok, h = pcall(function()
        if gethwid then return gethwid() end
        return LocalPlayer.UserId
    end)
    if not ok or h == nil or h == "" then
        return tostring(LocalPlayer.UserId)
    end
    return tostring(h)
end
pcall(function() math.randomseed(tick() % 1 * 1e6 + os.clock() * 1e3) end)

--// Хелперы
function ksPrint(msg)
    if KeySystem.Config.Debug then
        print("[SpermaHub Key] " .. msg)
    end
end

function ksNotify(title, msg, duration)
    if toastImpl then
        pcall(toastImpl, title, msg)
    else
        print(("[SpermaHub] %s: %s"):format(title, msg))
    end
end

--// Парс срока «6h»/«3d»/«2w»/«90m» → секунды (rev33)
function ParseDuration(str)
    str = tostring(str or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local num, unit = str:match("^(%d+)([hdwm])$")
    if not num then return nil end
    local mul = ({h = 3600, d = 86400, w = 604800, m = 60})[unit]
    return (tonumber(num) or 0) * mul
end

--// Генерация случайного ключа
function GenerateKeyString(length)
    length = length or 16
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = {}
    for i = 1, length do
        local rand = math.random(1, #chars)
        table.insert(result, chars:sub(rand, rand))
    end
    return table.concat(result)
end

--// Сохранение/загрузка ключей
--  фикс: math.huge не сериализуется в JSON → в файле храним как -1
function KeySystem:SaveKeys()
    if not self.Config.SaveKeys or not writefile then return end

    pcall(function()
        local safe = {}
        for k, d in pairs(self.State.KeysDB) do
            local c = {}
            for f, v in pairs(d) do
                c[f] = (v == math.huge and -1) or v
            end
            safe[k] = c
        end
        writefile(self.Config.KeysFile, HttpService:JSONEncode(safe))
    end)
end

function KeySystem:LoadKeys()
    if not self.Config.SaveKeys or not readfile then return end

    local ok, data = pcall(function()
        return readfile(self.Config.KeysFile)
    end)

    if ok and data then
        local decoded = nil
        pcall(function() decoded = HttpService:JSONDecode(data) end)
        if type(decoded) == "table" then
            for _, d in pairs(decoded) do
                if d.expires == -1 then d.expires = math.huge end
            end
            self.State.KeysDB = decoded
            ksPrint("Loaded " .. self:GetKeyCount() .. " keys")
        end
    end
end

--// META: пароль админа, HWID-блэклист, лог активаций
function KeySystem:SaveMeta()
    if not self.Config.SaveKeys or not writefile then return end
    pcall(function()
        writefile(self.Config.MetaFile, HttpService:JSONEncode({
            adminPassword = self.Config.AdminPassword,
            moderPassword = self.Config.ModerPassword,
            hwidBlacklist = self.State.HwidBlacklist,
            log = self.State.ActLog,
            audit = self.State.AuditLog,
            bruteCount = self.State.BruteCount,
            motd = self.State.Motd,
            maintenance = self.State.Maintenance,
            minVersion = self.State.MinVersion,
            adminHwid = self.State.MetaAdminHwid,
            lastAutoClean = self.State.LastAutoClean,
        }))
    end)
end

function KeySystem:LoadMeta()
    if not self.Config.SaveKeys or not readfile then return end
    local ok, data = pcall(function() return readfile(self.Config.MetaFile) end)
    if ok and data then
        local decoded = nil
        pcall(function() decoded = HttpService:JSONDecode(data) end)
        if type(decoded) == "table" then
            if type(decoded.adminPassword) == "string" and #decoded.adminPassword >= 2 then
                self.Config.AdminPassword = decoded.adminPassword
            end
            if type(decoded.hwidBlacklist) == "table" then
                self.State.HwidBlacklist = decoded.hwidBlacklist
            end
            if type(decoded.log) == "table" then
                self.State.ActLog = decoded.log
            end
            if type(decoded.audit) == "table" then
                self.State.AuditLog = decoded.audit
            end
            if type(decoded.bruteCount) == "table" then
                self.State.BruteCount = decoded.bruteCount
            end
            self.State.Motd = (type(decoded.motd) == "string") and decoded.motd or ""
            self.State.Maintenance = decoded.maintenance and true or false
            self.State.MinVersion = decoded.minVersion
            self.State.MetaAdminHwid = decoded.adminHwid
            self.State.LastAutoClean = tonumber(decoded.lastAutoClean) or 0
            if type(decoded.moderPassword) == "string" and #decoded.moderPassword >= 2 then
                self.Config.ModerPassword = decoded.moderPassword
            end
        end
    end
end

--// Запись в лог активаций (держим последние 40)
function KeySystem:LogEvent(key, hwid, ok, reason)
    table.insert(self.State.ActLog, 1, {
        k = tostring(key):sub(1, 16),
        hw = tostring(hwid):sub(1, 10),
        t = os.time(),
        ok = ok and true or false,
        r = tostring(reason or ""),
    })
    while #self.State.ActLog > 40 do table.remove(self.State.ActLog) end
    self:SaveMeta()
end

--// HEARTBEAT «сейчас в игре»: раз в 45 сек пишем свою метку в общий файл
function KeySystem:WriteHeartbeat(key)
    if not writefile then return end
    pcall(function()
        local hb = {}
        if readfile then
            local ok, data = pcall(function() return readfile(self.Config.HeartbeatFile) end)
            if ok and data then pcall(function() hb = HttpService:JSONDecode(data) or {} end) end
        end
        hb[key] = os.time()
        writefile(self.Config.HeartbeatFile, HttpService:JSONEncode(hb))
        self.State.Heartbeats = hb
    end)
end

function KeySystem:StartHeartbeat(key)
    self.State.Heartbeats = self.State.Heartbeats or {}
    if self.State._hbRunning and self.State._hbRunning[key] then return end
    self.State._hbRunning = self.State._hbRunning or {}
    self.State._hbRunning[key] = true
    self:WriteHeartbeat(key)
    task.spawn(function()
        while task.wait(45) do
            if KeySystem.State.Closed then break end
            -- 🎮 наигранное время +45 сек каждый пинг
            local d = KeySystem.State.KeysDB[key]
            if d and writefile then
                d.playSeconds = (d.playSeconds or 0) + 45
                pcall(function() KeySystem:SaveKeys() end)
            end
            -- ⛔ КИК-ПУЛЬТ: админ выкинул доступ с удалёнки
            if KeySystem:ReadKillFlag(key) then
                pcall(function()
                    LocalPlayer:Kick("SpermaHub: доступ отозван администратором")
                end)
                break
            end
            KeySystem:WriteHeartbeat(key)
        end
    end)
end

function KeySystem:ReadKillFlag(key)
    if not readfile then return false end
    local ks = {}
    pcall(function()
        local data = readfile("sperma_killswitch.json")
        if data then ks = HttpService:JSONDecode(data) or {} end
    end)
    return ks[key] == true
end

function KeySystem:SetKill(key, flag)
    if not writefile then return end
    local path = "sperma_killswitch.json"
    local ks = {}
    if readfile then
        pcall(function()
            local data = readfile(path)
            if data then ks = HttpService:JSONDecode(data) or {} end
        end)
    end
    ks[key] = flag and true or nil
    writefile(path, HttpService:JSONEncode(ks))
    self:Audit("killswitch " .. tostring(flag) .. " " .. key)
end

function KeySystem:ReadHeartbeats()
    local hb = {}
    if readfile then
        pcall(function()
            local data = readfile(self.Config.HeartbeatFile)
            if data then hb = HttpService:JSONDecode(data) or {} end
        end)
    end
    self.State.Heartbeats = hb
    return hb
end

--// Ключ «сейчас в игре» = пинг был < 2 минут назад
function KeySystem:IsOnline(key)
    local t = self.State.Heartbeats[key]
    return type(t) == "number" and (os.time() - t) < 120
end

function KeySystem:GetKeyCount()
    local count = 0
    for _ in pairs(self.State.KeysDB) do count = count + 1 end
    return count
end

--// Генерация нового ключа (customKey — своё слово, если задано)
function KeySystem:GenerateKey(keyTypeIndex, customKey, opts)
    local keyType = self.KeyTypes[keyTypeIndex]
    if not keyType then return nil end
    if type(opts) == "boolean" then opts = {noHwid = opts} end
    opts = opts or {}

    local newKey
    if customKey and #customKey > 0 then
        newKey = string.gsub(tostring(customKey), "%s+", "")
        if #newKey < 3 then
            return nil, nil, "tooshort"
        end
        if self.State.KeysDB[newKey] then
            return nil, nil, "exists"
        end
    else
        newKey = GenerateKeyString(16)
    end
    local now = tick()

    local dur = opts.durationSecs or keyType.Duration
    local rec = {
        type = keyType.Name,
        typeIndex = keyTypeIndex,
        created = now,
        used = false,
        generatedBy = "admin",
        hwid = nil,          -- свободен; при первом входе привяжется к устройству
        activations = 0,
        banned = false,
        silentBan = false,   -- 🤡 тихий бан (fake-успех, скрипт не грузится)
        noHwid = opts.noHwid and true or false,
        oneTime = opts.oneTime and true or false, -- 🔥 самоуничтожается после первого входа
        note = nil,
        maxActivations = nil,
        price = (tonumber(opts.price) and tonumber(opts.price) >= 0) and math.floor(tonumber(opts.price)) or nil, -- 💰 ₽
        playSeconds = 0,     -- 🎮 наиграно
        tier = opts.tier or "LITE", -- 🏆 тариф (LITE/PRO/PREMIUM)
    }
    if opts.defer then
        rec.pendingStart = true     -- ⏳ срок начнёт тикать с первого входа
        rec.durationSecs = dur
        rec.expires = nil
    else
        rec.expires = (dur == math.huge) and math.huge or (now + dur)
    end

    self.State.KeysDB[newKey] = rec
    self:SaveKeys()
    ksPrint("Generated " .. keyType.Name .. " key: " .. newKey)

    return newKey, keyType
end

--// FNV-1a 32bit — та же подпись, что на сервере (нужна для проверки sig2)
function fnv32(s)
    -- FIX rev47: h*16777619 напрямую превышает точность double (2^53) — солим.
    -- 16777619 = 16777216 + 403 → перемножаем ПО ЧАСТЯМ (все промежуточные < 2^53).
    -- Проверено: 1-в-1 совпадает с JS Math.imul на сервере.
    local MOD = 4294967296
    local h = 2166136261
    for i = 1, #s do
        h = bit32.bxor(h, s:byte(i))
        h = ((h % 256) * 16777216 % MOD + (h * 403) % MOD) % MOD
    end
    return string.format("%08x", h)
end

--// 🌐 Серверная валидация ключа (Vercel)
--  → true, data  (впускать) | "hardfail", reason (отказ ОКОНЧАТЕЛЬНЫЙ) | "offline" (→ запасная локальная проверка)
function KeySystem:ServerAuth(key)
    if not (self.Config.Server and self.Config.Server.Enabled) then return "offline" end
    local myHwid = GetHWID()
    local url = string.format("%s/api/auth?key=%s&hwid=%s&rev=%s",
        self.Config.Server.Url,
        HttpService:UrlEncode(tostring(key)),
        HttpService:UrlEncode(tostring(myHwid)),
        tostring(BUILD_REV))
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or type(raw) ~= "string" then return "offline" end
    local okJ, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okJ or type(data) ~= "table" then return "offline" end
    if data.ok ~= true then
        local err = tostring(data.err or "no_key")
        if err == "banned" and data.reason and #tostring(data.reason) > 0 then
            return "hardfail", "banned_custom:" .. tostring(data.reason)
        end
        return "hardfail", err
    end
    -- срок действия токена + подпись
    local exp = tonumber(data.exp) or 0
    if exp <= os.time() then return "hardfail", "expired_token" end
    local payload = string.format("ok=1|key=%s|hwid=%s|exp=%s", tostring(key), tostring(myHwid), tostring(exp))
    if tostring(data.sig2) ~= fnv32(payload .. "|" .. tostring(self.Config.Server.AppSecret)) then
        return "hardfail", "bad_signature"
    end
    -- апдейт-гейт ПРЯМО С СЕРВЕРА (MIN_REV из env На Vercel убивает старые билды)
    local minRevServ = tonumber(data.minRev) or 0
    if minRevServ > BUILD_REV then return "hardfail", "update_required" end
    return true, data
end

--// ❌ Серверный «терминал»: лицензия отозвана в живой сессии (бан/удаление/истёк)
function KeySystem:ServerKick(reasonCode)
    local msgs = {
        banned = "⛔ ВАШ КЛЮЧ ЗАБАНЕН АДМИНИСТРАТОРОМ",
        no_key = "⛔ ВАШ КЛЮЧ УДАЛЁН С СЕРВЕРА",
        expired = "⏰ СРОК ДЕЙСТВИЯ КОНЧИЛСЯ",
        hwid_mismatch = "⛔ КЛЮЧ ПРИВЯЗАН К ДРУГОМУ УСТРОЙСТВУ",
        update_required = "🔄 ОБНОВИ СКРИПТ — сборка устарела",
        activation_limit = "✋ ЛИМИТ АКТИВАЦИЙ ИСЧЕРПАН",
    }
    local customBan = tostring(reasonCode):match("^banned_custom:(.+)")
    local text = customBan and ("⛔ ВАШ КЛЮЧ ЗАБАНЕН: " .. customBan) or (msgs[reasonCode] or ("⛔ Лицензия отозвана: " .. tostring(reasonCode)))
    warn("[SpermaHub] ❌ серверный кик: " .. tostring(reasonCode))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "SpermaHub", Text = text, Duration = 10})
    end)
    pcall(function()
        local gui = game:GetService("CoreGui")
        for _, ch in ipairs(gui:GetChildren()) do
            if tostring(ch.Name):find("Sperma") then pcall(function() ch:Destroy() end) end
        end
    end)
    if getgenv then
        getgenv().SpermaHubRevoked = true
    end
    task.wait(1.2)
    -- Hard-кик (срабатывает на большинстве executor'ов)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        if lp then lp:Kick("SpermaHub: " .. tostring(reasonCode or "license revoked")) end
    end)
end

--// 💓 Пульс: каждые HeartbeatSecs стукаем /api/check (без накрутки активаций)
function KeySystem:StartServerHeartbeat(key)
    task.spawn(function()
        local secs = (self.Config.Server and self.Config.Server.HeartbeatSecs) or 120
        while task.wait(secs) do
            if getgenv and getgenv().SpermaHubRevoked then break end
            local srv = self.Config.Server
            if not (srv and srv.Enabled) then break end
            local myHwid = GetHWID()
            local url = string.format("%s/api/check?key=%s&hwid=%s&rev=%s",
                srv.Url,
                HttpService:UrlEncode(tostring(key)),
                HttpService:UrlEncode(tostring(myHwid)),
                tostring(BUILD_REV))
            local ok, raw = pcall(function() return game:HttpGet(url) end)
            if ok and type(raw) == "string" then
                local okJ, d = pcall(function() return HttpService:JSONDecode(raw) end)
                if okJ and type(d) == "table" then
                    if d.ok == true then
                        -- жив: лицензия на месте
                    else
                        local rc = tostring(d.err or "revoked")
                        if rc == "banned" and d.reason and #tostring(d.reason) > 0 then rc = "banned_custom:" .. tostring(d.reason) end
                        self:ServerKick(rc)
                        break
                    end
                end
            end
            -- сбой сети — молчим и ждём следующий тик (кикаем только по осознанному отказу сервера)
        end
    end)
end

--// Проверка ключа
function KeySystem:ValidateKey(key)
    key = string.gsub(tostring(key), "%s+", "") -- Чистим пробелы

    --// Админки (чёрный список и техн.режим их не блокируют)
    if key == self.Config.AdminPassword then
        local myHwid = GetHWID()
        local lock = self.State.MetaAdminHwid
        if lock == nil then
            self.State.MetaAdminHwid = myHwid -- 🔒 первая привязка админки к этому устройству
            self:SaveMeta()
        elseif lock ~= myHwid then
            ksNotify("Key System", "⛔ Админка привязана к ДРУГОМУ устройству!", 3)
            self:LogEvent(key, myHwid, false, "adminhwid")
            return false, "adminhwid"
        end
        self.State.IsAdmin = true
        self.State.Authenticated = true
        ksPrint("Admin access granted")
        return true, "admin"
    end
    if self.Config.ModerPassword and key == self.Config.ModerPassword then
        self.State.IsModer = true
        self.State.Authenticated = true
        ksPrint("Moder access granted")
        return true, "moder"
    end

    local myHwid = GetHWID()

    --// 🚫 ЧЁРНЫЙ СПИСОК устройств: не впускаем вообще, даже с верным ключом
    if self.State.HwidBlacklist[myHwid] then
        ksNotify("Key System", "🚫 Ваше устройство в чёрном списке!", 3)
        self:LogEvent(key, myHwid, false, "blacklisted")
        return false, "blacklisted"
    end

    --// 🔧 РЕЖИМ ОБСЛУЖИВАНИЯ
    if self.State.Maintenance then
        ksNotify("Key System", "🔧 Технические работы — попробуйте позже!", 3)
        return false, "maint"
    end

    --// 🌐 СЕРВЕРНАЯ ПРОВЕРКА (главная): решение сервера — финальное; оффлайн → локальная база ниже
    local sok, sres = self:ServerAuth(key)
    if sok == true then
        self.State.Authenticated = true
        self.State.CurrentKey = key
        self:LogEvent(key, myHwid, true, "server")
        ksPrint("Server auth OK: key accepted via Vercel")
        return true, "server"
    elseif sok == "hardfail" then
        self:LogEvent(key, myHwid, false, "srv:" .. tostring(sres))
        return false, "srv_" .. tostring(sres)
    end
    -- "offline" → падаем на локальную проверку ниже (сервер недоступен)

    --// Проверка в базе
    local keyData = self.State.KeysDB[key]
    if keyData then
        local now = tick()

        -- Обычный БАН
        if keyData.banned then
            ksNotify("Key System", "🚫 Ключ заблокирован администратором!", 3)
            self:LogEvent(key, myHwid, false, "banned")
            return false, "banned"
        end

        --// 🤡 ТИХИЙ БАН: юзер видит успех, но скрипт не грузится
        if keyData.silentBan then
            self.State.SilentTroll = true
            self.State.Authenticated = true
            self:LogEvent(key, myHwid, true, "silent")
            return true, "silent"
        end

        --// ⏳ Отсчёт от первого входа
        if keyData.pendingStart and keyData.expires == nil then
            local dur = keyData.durationSecs or self.KeyTypes[1].Duration
            keyData.expires = (dur == math.huge) and math.huge or (now + dur)
            self:SaveKeys()
            self:LogEvent(key, myHwid, true, "started")
        end

        -- Проверка срока (nil expires = отсчёт ещё не стартовал → валиден)
        if keyData.expires and now > keyData.expires then
            ksNotify("Key System", "Ключ истёк!", 3)
            self:LogEvent(key, myHwid, false, "expired")
            return false, "expired"
        end

        --// Лимит активаций
        if keyData.maxActivations and (keyData.activations or 0) >= keyData.maxActivations then
            ksNotify("Key System", "✋ Лимит активаций ключа исчерпан!", 3)
            self:LogEvent(key, myHwid, false, "limit")
            return false, "limit"
        end

        --// HWID-ПРИВЯЗКА (VIP noHwid — пропускаем)
        if self.Config.HwidLock and not keyData.noHwid then
            if keyData.hwid == nil then
                keyData.hwid = myHwid
                keyData.hwidSetAt = now
            elseif tostring(keyData.hwid) ~= myHwid then
                ksNotify("Key System", "⛔ Ключ привязан к ДРУГОМУ устройству!", 3)
                self:LogEvent(key, myHwid, false, "hwid")
                return false, "hwid"
            end
        end

        -- Помечаем использованным + счётчик активаций
        if not keyData.used then
            keyData.used = true
        end
        keyData.activations = (keyData.activations or 0) + 1
        self:SaveKeys()
        self:LogEvent(key, myHwid, true, keyData.type)
        self:StartHeartbeat(key) -- «сейчас в игре» + кик-пульт + playtime

        --// 🔥 одноразовый ключ самоуничтожается после первого входа
        if keyData.oneTime then
            task.delay(1.5, function()
                pcall(function()
                    if KeySystem.State.KeysDB[key] then KeySystem:RevokeKey(key) end
                end)
            end)
        end

        self.State.Authenticated = true
        self.State.CurrentKey = key
        self.State.KeyType = keyData.type
        ksPrint("Key accepted: " .. keyData.type)
        return true, keyData.type
    end

    --// Неверный ключ + брутфорс-присмотр
    self:LogEvent(key, myHwid, false, "invalid")
    self.State.BruteCount[myHwid] = (self.State.BruteCount[myHwid] or 0) + 1
    if self.State.BruteCount[myHwid] >= 4 and not self.State.HwidBlacklist[myHwid] then
        self:BlacklistHwid(myHwid)
        self:Audit("autoban hwid " .. myHwid:sub(1, 8))
        ksNotify("Key System", "🚫 Ваше устройство внесено в чёрный список (перебор ключей)", 3)
    end
    self.State.Attempts = self.State.Attempts + 1

    if self.State.Attempts >= self.Config.MaxAttempts then
        ksNotify("Key System", "Слишком много попыток!", 3)
        task.wait(1)
        LocalPlayer:Kick("SpermaHub: Invalid key attempts exceeded")
    end

    return false, "invalid"
end

--// Удаление ключа
function KeySystem:RevokeKey(key)
    if self.State.KeysDB[key] then
        self.State.KeysDB[key] = nil
        self:SaveKeys()
        return true
    end
    return false
end

--// Сброс HWID (ключ снова сможет привязаться к любому устройству)
function KeySystem:ResetHwid(key)
    if self.State.KeysDB[key] and self.State.KeysDB[key].hwid ~= nil then
        self.State.KeysDB[key].hwid = nil
        self.State.KeysDB[key].hwidSetAt = nil
        self:SaveKeys()
        return true
    end
    return false
end

--// Бан / разбан ключа
function KeySystem:SetBan(key, flag)
    local d = self.State.KeysDB[key]
    if d then d.banned = flag and true or false; self:SaveKeys(); return true end
    return false
end

--// Продлить ключ на N секунд
function KeySystem:ExtendKey(key, secs)
    local d = self.State.KeysDB[key]
    if not d then return false end
    if d.expires == math.huge then return false end -- вечный уже бесконечен
    local now = tick()
    local base = (d.expires and d.expires > now) and d.expires or now
    d.expires = base + (secs or 86400)
    self:SaveKeys()
    return true
end

--// Заметка к ключу
function KeySystem:SetNote(key, note)
    local d = self.State.KeysDB[key]
    if not d then return false end
    note = tostring(note or ""):gsub("^%s+",""):gsub("%s+$","")
    d.note = (#note > 0) and note:sub(1, 32) or nil
    self:SaveKeys()
    return true
end

--// VIP: включение/выключение HWID-привязки у конкретного ключа
function KeySystem:SetNoHwid(key, flag)
    local d = self.State.KeysDB[key]
    if not d then return false end
    d.noHwid = flag and true or false
    if flag then d.hwid = nil end
    self:SaveKeys()
    return true
end

--// Лимит активаций (nil = бесконечно)
function KeySystem:SetMaxActivations(key, n)
    local d = self.State.KeysDB[key]
    if not d then return false end
    n = tonumber(n)
    if n and n > 0 then d.maxActivations = math.floor(n) else d.maxActivations = nil end
    self:SaveKeys()
    return true
end

--// Смена типа ключа (пересчёт срока от СЕЙЧАС)
function KeySystem:CycleType(key)
    local d = self.State.KeysDB[key]
    if not d then return false end
    local nextIdx = ((d.typeIndex or 4) % #self.KeyTypes) + 1
    local kt = self.KeyTypes[nextIdx]
    local now = tick()
    d.typeIndex = nextIdx
    d.type = kt.Name
    d.expires = kt.Duration == math.huge and math.huge or (now + kt.Duration)
    self:SaveKeys()
    return true
end

--// 📚 Аудит: фиксируем действия админа
function KeySystem:Audit(action)
    table.insert(self.State.AuditLog, 1, {t = os.time(), a = tostring(action):sub(1, 80)})
    while #self.State.AuditLog > 30 do table.remove(self.State.AuditLog) end
    self:SaveMeta()
end

--// ✏️ Переименование ключа (данные перекочевывают на новое слово)
function KeySystem:RenameKey(oldKey, newKey)
    local d = self.State.KeysDB[oldKey]
    newKey = tostring(newKey or ""):gsub("%s+", "")
    if not d then return false end
    if #newKey < 3 or self.State.KeysDB[newKey] then return false end
    self.State.KeysDB[newKey] = d
    self.State.KeysDB[oldKey] = nil
    if self.State.SelectedKey == oldKey then self.State.SelectedKey = newKey end
    if self.State.Heartbeats and self.State.Heartbeats[oldKey] then
        self.State.Heartbeats[newKey] = self.State.Heartbeats[oldKey]
        self.State.Heartbeats[oldKey] = nil
    end
    self:SaveKeys()
    self:Audit("rename " .. oldKey .. " -> " .. newKey)
    return true
end

--// 💰 Цена ключа (для статистики выручки)
function KeySystem:SetPrice(key, price)
    local d = self.State.KeysDB[key]
    if not d then return false end
    price = tonumber(price)
    d.price = (price and price >= 0) and math.floor(price) or nil
    self:SaveKeys()
    return true
end

function KeySystem:GetRevenue()
    local sum, sold = 0, 0
    for _, d in pairs(self.State.KeysDB) do
        if d.used then sold = sold + 1; sum = sum + (d.price or 0) end
    end
    return sum, sold
end

--// 🤡 Тихий бан
function KeySystem:SetSilent(key, flag)
    local d = self.State.KeysDB[key]
    if d then d.silentBan = flag and true or false; self:SaveKeys(); return true end
    return false
end

--// 📣 MOTD / 🔧 Режим обслуживания / 🧱 Минимальная сборка
function KeySystem:SetMotd(t)
    self.State.Motd = tostring(t or ""):sub(1, 100)
    self:SaveMeta()
end

function KeySystem:SetMaintenance(flag)
    self.State.Maintenance = flag and true or false
    self:SaveMeta()
    self:Audit("maintenance " .. tostring(flag))
end

function KeySystem:SetMinVersion(v)
    v = tonumber(v)
    self.State.MinVersion = (v and v >= 1) and math.floor(v) or nil
    self:SaveMeta()
    self:Audit("minVersion " .. tostring(v))
end

--// Чёрный список HWID
function KeySystem:BlacklistHwid(hwid)
    hwid = tostring(hwid or "")
    if hwid == "" then return false end
    self.State.HwidBlacklist[hwid] = true
    self:SaveMeta()
    return true
end

function KeySystem:UnBlacklistHwid(hwid)
    hwid = tostring(hwid or "")
    if self.State.HwidBlacklist[hwid] then
        self.State.HwidBlacklist[hwid] = nil
        self:SaveMeta()
        return true
    end
    return false
end

--// Очистка истёкших ключей
function KeySystem:CleanExpired()
    local now = tick()
    local removed = 0
    for key, data in pairs(self.State.KeysDB) do
        -- nil expires = pending/бессрочная запись → ВАЛИДНА (как в ValidateKey), не трогаем
        if type(data) == "table" and data.expires ~= nil and now > data.expires then
            self.State.KeysDB[key] = nil
            removed = removed + 1
        elseif type(data) ~= "table" then
            -- legacy-записи старых билдов (строки/числа) — считаем бессрочными, не крешимся
        end
    end
    if removed > 0 then
        self:SaveKeys()
    end
    return removed
end

--// ============================================================
--// GUI - ПОЛЬЗОВАТЕЛЬСКАЯ ПАНЕЛЬ
--// ============================================================

function KeySystem:CreateUserGUI()
    if CoreGuiSvc:FindFirstChild("SpermaKeySystem") then
        CoreGuiSvc.SpermaKeySystem:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SpermaKeySystem"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    ScreenGui.Parent = CoreGuiSvc

    --// Main Frame
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 340, 0, 200)
    Main.Position = UDim2.new(0.5, -170, 0.5, -100)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = Main

    local Shadow = Instance.new("ImageLabel")
    Shadow.Size = UDim2.new(1, 40, 1, 40)
    Shadow.Position = UDim2.new(0, -20, 0, -20)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.4
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    Shadow.Parent = Main

    --// Title
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Main

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = TitleBar

    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 10)
    TitleFix.Position = UDim2.new(0, 0, 1, -10)
    TitleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🔑 SPERMAHUB ACCESS"
    Title.TextColor3 = Color3.fromRGB(255, 100, 100)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    --// Status
    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -40, 0, 20)
    Status.Position = UDim2.new(0, 20, 0, 50)
    Status.BackgroundTransparency = 1
    Status.Text = "Введите ключ доступа:"
    Status.TextColor3 = Color3.fromRGB(200, 200, 200)
    Status.Font = Enum.Font.Gotham
    Status.TextSize = 12
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Parent = Main

    --// Input
    local InputOutline = Instance.new("Frame")
    InputOutline.Size = UDim2.new(1, -40, 0, 40)
    InputOutline.Position = UDim2.new(0, 20, 0, 75)
    InputOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    InputOutline.BorderSizePixel = 0
    InputOutline.Parent = Main

    local InputCorner = Instance.new("UICorner")
    InputCorner.CornerRadius = UDim.new(0, 6)
    InputCorner.Parent = InputOutline

    local Input = Instance.new("TextBox")
    Input.Size = UDim2.new(1, -20, 1, 0)
    Input.Position = UDim2.new(0, 10, 0, 0)
    Input.BackgroundTransparency = 1
    Input.Text = ""
    Input.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
    Input.TextColor3 = Color3.fromRGB(255, 255, 255)
    Input.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    Input.Font = Enum.Font.GothamBold
    Input.TextSize = 14
    Input.TextXAlignment = Enum.TextXAlignment.Center
    Input.ClearTextOnFocus = false
    Input.Parent = InputOutline

    --// Submit Button
    local SubmitBtn = Instance.new("TextButton")
    SubmitBtn.Size = UDim2.new(1, -40, 0, 40)
    SubmitBtn.Position = UDim2.new(0, 20, 0, 125)
    SubmitBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    SubmitBtn.Text = "UNLOCK"
    SubmitBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    SubmitBtn.Font = Enum.Font.GothamBold
    SubmitBtn.TextSize = 14
    SubmitBtn.BorderSizePixel = 0
    SubmitBtn.Parent = Main

    local SubmitCorner = Instance.new("UICorner")
    SubmitCorner.CornerRadius = UDim.new(0, 6)
    SubmitCorner.Parent = SubmitBtn

    --// Attempts
    local AttemptsLabel = Instance.new("TextLabel")
    AttemptsLabel.Size = UDim2.new(1, -40, 0, 15)
    AttemptsLabel.Position = UDim2.new(0, 20, 0, 172)
    AttemptsLabel.BackgroundTransparency = 1
    AttemptsLabel.Text = "Попытки: 0/" .. KeySystem.Config.MaxAttempts
    AttemptsLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
    AttemptsLabel.Font = Enum.Font.Gotham
    AttemptsLabel.TextSize = 10
    AttemptsLabel.TextXAlignment = Enum.TextXAlignment.Left
    AttemptsLabel.Parent = Main

    --// Логика
    local function TryUnlock()
        local key = Input.Text
        if #key == 0 then return end

        local success, keyType = KeySystem:ValidateKey(key)

        if success then
            if keyType == "admin" or keyType == "moder" then
                Status.Text = (keyType == "admin") and "✓ Admin access!" or "✓ Moder access!"
                Status.TextColor3 = Color3.fromRGB(100, 255, 100)
                SubmitBtn.Text = "OPENING ADMIN..."
                SubmitBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)

                task.wait(0.5)
                ScreenGui:Destroy()
                KeySystem:CreateAdminGUI()
            else
                Status.Text = "✓ Access granted! [" .. tostring(keyType) .. "]"
                Status.TextColor3 = Color3.fromRGB(100, 255, 100)
                SubmitBtn.Text = "LOADING..."
                SubmitBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)

                task.wait(0.5)
                ScreenGui:Destroy()

                if keyType == "silent" then
                    -- 🤡 тихий бан: никого нет дома (waiter сверху по SilentTroll не пропустит загрузку)
                    if getgenv then getgenv().SpermaHubRunning = false end
                    return
                end
                -- 📣 MOTD от администрации
                if KeySystem.State.Motd and #KeySystem.State.Motd > 0 then
                    ksNotify("📣 SpermaHub", KeySystem.State.Motd, 5)
                end
                -- 🛰️ водяной знак: кусок ключа в углу (анти-слив)
                pcall(function()
                    if CoreGuiSvc:FindFirstChild("SpermaWatermark") then
                        CoreGuiSvc.SpermaWatermark:Destroy()
                    end
                    local wm = Instance.new("ScreenGui")
                    wm.Name = "SpermaWatermark"
                    wm.ResetOnSpawn = false
                    wm.DisplayOrder = 1
                    wm.Parent = CoreGuiSvc
                    local wl = Instance.new("TextLabel")
                    wl.Size = UDim2.new(0, 200, 0, 16)
                    wl.Position = UDim2.new(1, -210, 1, -22)
                    wl.BackgroundTransparency = 1
                    wl.Text = "lic: " .. tostring(key):sub(1, 6) .. "…"
                    wl.TextColor3 = Color3.fromRGB(90, 90, 100)
                    wl.TextTransparency = 0.55
                    wl.Font = Enum.Font.Gotham
                    wl.TextSize = 10
                    wl.TextXAlignment = Enum.TextXAlignment.Right
                    wl.Parent = wm
                end)

                -- 💓 Серверный пульс (только для серверных ключей)
                if keyType == "server" then
                    pcall(function() KeySystem:StartServerHeartbeat(key) end)
                end

                -- Запуск основного скрипта (если оформлен как функция)
                if _G.SpermaHubMain then
                    pcall(_G.SpermaHubMain)
                end
            end
        else
            local srvMsg = {
                srv_no_key = "✗ Ключ не найден в базе!",
                srv_banned = "🚫 Ключ ЗАБАНЕН!",
                srv_expired = "⏰ Ключ истёк!",
                srv_hwid_mismatch = "⛔ Ключ привязан к другому устройству!",
                srv_activation_limit = "✋ Лимит активаций исчерпан!",
                srv_update_required = "🔄 ОБНОВИ СКРИПТ!",
                srv_bad_signature = "🛡 Сервер ответил с битой подписью!",
                srv_expired_token = "⏰ Токен просрочен — повтори!",
            }
            do
                local kt = tostring(keyType)
                local customBan = kt:match("^srv_banned_custom:(.+)")
                Status.Text = customBan and ("🚫 ЗАБАН: " .. customBan) or (srvMsg[kt] or "✗ Неверный ключ!")
            end
            Status.TextColor3 = Color3.fromRGB(255, 80, 80)
            Input.Text = ""
            AttemptsLabel.Text = "Попытки: " .. KeySystem.State.Attempts .. "/" .. KeySystem.Config.MaxAttempts

            -- Shake
            local originalPos = Main.Position
            for i = 1, 5 do
                Main.Position = originalPos + UDim2.new(0, math.random(-5, 5), 0, 0)
                task.wait(0.03)
            end
            Main.Position = originalPos

            task.delay(1.5, function()
                if Status.Parent then
                    Status.Text = "Введите ключ доступа:"
                    Status.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end)
        end
    end

    SubmitBtn.MouseButton1Click:Connect(function() pcall(TryUnlock) end)
    Input.FocusLost:Connect(function(enter) if enter then pcall(TryUnlock) end end)

    task.delay(0.5, function() pcall(function() Input:CaptureFocus() end) end)

    return ScreenGui
end

--// ============================================================
--// GUI - АДМИН ПАНЕЛЬ
--// ============================================================

function KeySystem:CreateAdminGUI()
    if CoreGuiSvc:FindFirstChild("SpermaAdmin") then
        CoreGuiSvc.SpermaAdmin:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SpermaAdmin"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 1000
    ScreenGui.Parent = CoreGuiSvc

    --// Main Frame
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 560, 0, 700)
    Main.Position = UDim2.new(0.5, -280, 0.5, -350)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = Main

    local Shadow = Instance.new("ImageLabel")
    Shadow.Size = UDim2.new(1, 40, 1, 40)
    Shadow.Position = UDim2.new(0, -20, 0, -20)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.4
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    Shadow.Parent = Main

    --// Title
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Main

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = TitleBar

    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 10)
    TitleFix.Position = UDim2.new(0, 0, 1, -10)
    TitleFix.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "👑 SPERMAHUB ADMIN"
    Title.TextColor3 = Color3.fromRGB(20, 20, 30)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    --// Close
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 18
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    --// ЗАКРЫТЬ СКРИПТ (убивает админку и всё вместе с ней)
    local KillBtn = Instance.new("TextButton")
    KillBtn.Size = UDim2.new(0, 96, 0, 30)
    KillBtn.Position = UDim2.new(1, -140, 0, 5)
    KillBtn.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
    KillBtn.Text = "⛔ Скрипт"
    KillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    KillBtn.Font = Enum.Font.GothamBold
    KillBtn.TextSize = 12
    KillBtn.BorderSizePixel = 0
    KillBtn.Parent = TitleBar

    local KillCorner = Instance.new("UICorner")
    KillCorner.CornerRadius = UDim.new(0, 6)
    KillCorner.Parent = KillBtn

    KillBtn.MouseButton1Click:Connect(function()
        pcall(function()
            KeySystem.State.Closed = true
            ScreenGui:Destroy()
            local pg = CoreGuiSvc
            pcall(function() if pg:FindFirstChild("SpermaKeySystem") then pg.SpermaKeySystem:Destroy() end end)
            print("[SpermaHub] Закрыто из админ-панели")
        end)
    end)

    --// Content
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -20, 1, -60)
    Content.Position = UDim2.new(0, 10, 0, 50)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    --// Левая панель - Генератор
    local LeftPanel = Instance.new("Frame")
    LeftPanel.Size = UDim2.new(0.45, -5, 1, 0)
    LeftPanel.Position = UDim2.new(0, 0, 0, 0)
    LeftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    LeftPanel.BorderSizePixel = 0
    LeftPanel.ClipsDescendants = true
    LeftPanel.Parent = Content

    local LeftCorner = Instance.new("UICorner")
    LeftCorner.CornerRadius = UDim.new(0, 8)
    LeftCorner.Parent = LeftPanel

    local GenTitle = Instance.new("TextLabel")
    GenTitle.Size = UDim2.new(1, -20, 0, 25)
    GenTitle.Position = UDim2.new(0, 10, 0, 10)
    GenTitle.BackgroundTransparency = 1
    GenTitle.Text = "🔧 ГЕНЕРАТОР КЛЮЧЕЙ"
    GenTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    GenTitle.Font = Enum.Font.GothamBold
    GenTitle.TextSize = 14
    GenTitle.TextXAlignment = Enum.TextXAlignment.Left
    GenTitle.Parent = LeftPanel

    --// Типы ключей
    local KeyTypeList = Instance.new("Frame")
    KeyTypeList.Size = UDim2.new(1, -20, 0, 130)
    KeyTypeList.Position = UDim2.new(0, 10, 0, 40)
    KeyTypeList.BackgroundTransparency = 1
    KeyTypeList.Parent = LeftPanel

    local UIList = Instance.new("UIListLayout")
    UIList.Padding = UDim.new(0, 5)
    UIList.SortOrder = Enum.SortOrder.LayoutOrder
    UIList.Parent = KeyTypeList

    local selectedType = 1
    local typeButtons = {}

    local function paintTypeButtons()
        for j, b in ipairs(typeButtons) do
            local isSel = (j == selectedType)
            b.BackgroundColor3 = isSel and KeySystem.KeyTypes[j].Color or Color3.fromRGB(30, 30, 45)
            b.TextColor3 = isSel and Color3.fromRGB(20, 20, 30) or Color3.fromRGB(200, 200, 200)
        end
    end

    for i, keyType in ipairs(KeySystem.KeyTypes) do
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 25)
        Btn.BackgroundColor3 = i == 1 and keyType.Color or Color3.fromRGB(30, 30, 45)
        Btn.Text = "  " .. keyType.Name
        Btn.TextColor3 = i == 1 and Color3.fromRGB(20, 20, 30) or Color3.fromRGB(200, 200, 200)
        Btn.Font = Enum.Font.GothamSemibold
        Btn.TextSize = 12
        Btn.TextXAlignment = Enum.TextXAlignment.Left
        Btn.LayoutOrder = i
        Btn.BorderSizePixel = 0
        Btn.AutoButtonColor = true
        Btn.Parent = KeyTypeList

        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 4)
        BtnCorner.Parent = Btn

        typeButtons[i] = Btn

        Btn.MouseButton1Click:Connect(function()
            selectedType = i
            pcall(paintTypeButtons)
        end)
    end

    --// rev34: тир генератора (тариф)
    local genTierDefs = {{Name = "LITE", Color = Color3.fromRGB(140, 160, 180)},
                         {Name = "PRO", Color = Color3.fromRGB(100, 149, 237)},
                         {Name = "PREMIUM", Color = Color3.fromRGB(255, 215, 0)}}
    local genTierIdx = 1
    local TierBtnG = Instance.new("TextButton")
    TierBtnG.Size = UDim2.new(1, -20, 0, 20)
    TierBtnG.Position = UDim2.new(0, 10, 0, 158)
    TierBtnG.BackgroundColor3 = genTierDefs[1].Color
    TierBtnG.Text = "ТАРИФ: LITE (цикл)"
    TierBtnG.TextColor3 = Color3.fromRGB(20, 20, 30)
    TierBtnG.Font = Enum.Font.GothamSemibold
    TierBtnG.TextSize = 10
    TierBtnG.BorderSizePixel = 0
    TierBtnG.Parent = LeftPanel
    local TierGCorner = Instance.new("UICorner")
    TierGCorner.CornerRadius = UDim.new(0, 5)
    TierGCorner.Parent = TierBtnG
    TierBtnG.MouseButton1Click:Connect(function()
        genTierIdx = (genTierIdx % #genTierDefs) + 1
        local t = genTierDefs[genTierIdx]
        TierBtnG.Text = "ТАРИФ: " .. t.Name .. " (цикл)"
        TierBtnG.BackgroundColor3 = t.Color
    end)

    --// Поле СВОЕГО ключа (если пусто — случайный)
    local CustomKeyOutline = Instance.new("Frame")
    CustomKeyOutline.Size = UDim2.new(1, -20, 0, 26)
    CustomKeyOutline.Position = UDim2.new(0, 10, 0, 182)
    CustomKeyOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    CustomKeyOutline.BorderSizePixel = 0
    CustomKeyOutline.Parent = LeftPanel

    local CustomKeyCorner = Instance.new("UICorner")
    CustomKeyCorner.CornerRadius = UDim.new(0, 6)
    CustomKeyCorner.Parent = CustomKeyOutline

    local CustomKeyBox = Instance.new("TextBox")
    CustomKeyBox.Size = UDim2.new(1, -16, 1, 0)
    CustomKeyBox.Position = UDim2.new(0, 8, 0, 0)
    CustomKeyBox.BackgroundTransparency = 1
    CustomKeyBox.Text = ""
    CustomKeyBox.PlaceholderText = "свой ключ (необязательно)"
    CustomKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    CustomKeyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    CustomKeyBox.Font = Enum.Font.GothamBold
    CustomKeyBox.TextSize = 12
    CustomKeyBox.TextXAlignment = Enum.TextXAlignment.Center
    CustomKeyBox.ClearTextOnFocus = false
    CustomKeyBox.Parent = CustomKeyOutline

    --// Generate Button
    local GenBtn = Instance.new("TextButton")
    GenBtn.Size = UDim2.new(1, -20, 0, 32)
    GenBtn.Position = UDim2.new(0, 10, 0, 214)
    GenBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    GenBtn.Text = "СГЕНЕРИРОВАТЬ КЛЮЧ"
    GenBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    GenBtn.Font = Enum.Font.GothamBold
    GenBtn.TextSize = 13
    GenBtn.BorderSizePixel = 0
    GenBtn.Parent = LeftPanel

    local GenCorner = Instance.new("UICorner")
    GenCorner.CornerRadius = UDim.new(0, 6)
    GenCorner.Parent = GenBtn

    --// Result Box
    local ResultBox = Instance.new("Frame")
    ResultBox.Size = UDim2.new(1, -20, 0, 32)
    ResultBox.Position = UDim2.new(0, 10, 0, 248)
    ResultBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    ResultBox.BorderSizePixel = 0
    ResultBox.Parent = LeftPanel

    local ResultCorner = Instance.new("UICorner")
    ResultCorner.CornerRadius = UDim.new(0, 6)
    ResultCorner.Parent = ResultBox

    local ResultText = Instance.new("TextLabel")
    ResultText.Size = UDim2.new(1, -10, 1, 0)
    ResultText.Position = UDim2.new(0, 5, 0, 0)
    ResultText.BackgroundTransparency = 1
    ResultText.Text = "Нажми Generate..."
    ResultText.TextColor3 = Color3.fromRGB(150, 150, 170)
    ResultText.Font = Enum.Font.GothamBold
    ResultText.TextSize = 12
    ResultText.TextXAlignment = Enum.TextXAlignment.Center
    ResultText.Parent = ResultBox

    --// Copy Button
    local CopyBtn = Instance.new("TextButton")
    CopyBtn.Size = UDim2.new(1, -20, 0, 28)
    CopyBtn.Position = UDim2.new(0, 10, 0, 286)
    CopyBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    CopyBtn.Text = "📋 КОПИРОВАТЬ"
    CopyBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    CopyBtn.Font = Enum.Font.GothamBold
    CopyBtn.TextSize = 12
    CopyBtn.BorderSizePixel = 0
    CopyBtn.Visible = false
    CopyBtn.Parent = LeftPanel

    local CopyCorner = Instance.new("UICorner")
    CopyCorner.CornerRadius = UDim.new(0, 6)
    CopyCorner.Parent = CopyBtn

    --// ============================================================
    --// 🌐 СЕРВЕРНЫЙ ГЕНЕРАТОР КЛЮЧЕЙ (Vercel) — rev46
    --// ============================================================
    local SrvGenTitle = Instance.new("TextLabel")
    SrvGenTitle.Size = UDim2.new(1, -20, 0, 20)
    SrvGenTitle.Position = UDim2.new(0, 10, 0, 320)
    SrvGenTitle.BackgroundTransparency = 1
    SrvGenTitle.Text = "🌐 СЕРВЕРНЫЙ ГЕНЕРАТОР (Vercel)"
    SrvGenTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
    SrvGenTitle.Font = Enum.Font.GothamBold
    SrvGenTitle.TextSize = 13
    SrvGenTitle.TextXAlignment = Enum.TextXAlignment.Left
    SrvGenTitle.Parent = LeftPanel

    local ADMSEC_FILE = "sperma_admsec.txt"
    local function makeInput(yPos, placeholder, w)
        local F = Instance.new("Frame")
        F.Size = UDim2.new(w or 1, -20, 0, 24)
        F.Position = UDim2.new(0, 10, 0, yPos)
        F.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        F.BorderSizePixel = 0
        F.Parent = LeftPanel
        local FC = Instance.new("UICorner")
        FC.CornerRadius = UDim.new(0, 6)
        FC.Parent = F
        local B = Instance.new("TextBox")
        B.Size = UDim2.new(1, -16, 1, 0)
        B.Position = UDim2.new(0, 8, 0, 0)
        B.BackgroundTransparency = 1
        B.Text = ""
        B.PlaceholderText = placeholder
        B.TextColor3 = Color3.fromRGB(255, 255, 255)
        B.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
        B.Font = Enum.Font.GothamSemibold
        B.TextSize = 11
        B.TextXAlignment = Enum.TextXAlignment.Left
        B.ClearTextOnFocus = false
        B.Parent = F
        return B
    end

    --// ADMIN_SECRET (вводится один раз, кэшируется в файл — НИКОГДА не зашит в код!)
    local SecBox = makeInput(344, "ADMIN_SECRET (вводится один раз)")
    pcall(function()
        if readfile and type(readfile) == "function" then
            local okR, saved = pcall(readfile, ADMSEC_FILE)
            if okR and type(saved) == "string" and #saved > 4 then SecBox.Text = saved end
        end
    end)
    SecBox.FocusLost:Connect(function(enterPressed)
        local t = string.gsub(SecBox.Text or "", "%s+", "")
        if #t > 4 then pcall(function() if writefile then writefile(ADMSEC_FILE, t) end end) end
    end)

    --// Выбор типа ключа (цикл)
    local srvTypes = { "pending", "timed", "permanent" }
    local srvTypeIdx = 1
    local SrvTypeBtn = Instance.new("TextButton")
    SrvTypeBtn.Size = UDim2.new(1, -20, 0, 22)
    SrvTypeBtn.Position = UDim2.new(0, 10, 0, 372)
    SrvTypeBtn.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
    SrvTypeBtn.Text = "ТИП: PENDING (⏳ с 1-й активации) — цикл"
    SrvTypeBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    SrvTypeBtn.Font = Enum.Font.GothamSemibold
    SrvTypeBtn.TextSize = 10
    SrvTypeBtn.BorderSizePixel = 0
    SrvTypeBtn.Parent = LeftPanel
    local SrvTypeCorner = Instance.new("UICorner")
    SrvTypeCorner.CornerRadius = UDim.new(0, 5)
    SrvTypeCorner.Parent = SrvTypeBtn
    SrvTypeBtn.MouseButton1Click:Connect(function()
        srvTypeIdx = (srvTypeIdx % #srvTypes) + 1
        local t = srvTypes[srvTypeIdx]
        local label = (t == "pending") and "PENDING (⏳ с 1-й активации)" or (t == "timed") and "TIMED (⏰ отсчёт сразу)" or "PERMANENT (♾️ вечный)"
        SrvTypeBtn.Text = "ТИП: " .. label .. " — цикл"
    end)

    local DaysBox  = makeInput(398, "дней (по умолч. 30)")
    local CountBox = makeInput(426, "сколько ключей (по умолч. 1, макс. 50)")
    local NoteBox  = makeInput(454, "пометка (необязательно)")

    --// Кнопка генерации
    local SrvGenBtn = Instance.new("TextButton")
    SrvGenBtn.Size = UDim2.new(1, -20, 0, 28)
    SrvGenBtn.Position = UDim2.new(0, 10, 0, 482)
    SrvGenBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    SrvGenBtn.Text = "🌐 СГЕНЕРИТЬ С СЕРВЕРА"
    SrvGenBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    SrvGenBtn.Font = Enum.Font.GothamBold
    SrvGenBtn.TextSize = 12
    SrvGenBtn.BorderSizePixel = 0
    SrvGenBtn.Parent = LeftPanel
    local SrvGenCorner = Instance.new("UICorner")
    SrvGenCorner.CornerRadius = UDim.new(0, 6)
    SrvGenCorner.Parent = SrvGenBtn

    --// Результат (многострочный)
    local SrvResult = Instance.new("TextLabel")
    SrvResult.Size = UDim2.new(1, -20, 0, 56)
    SrvResult.Position = UDim2.new(0, 10, 0, 514)
    SrvResult.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    SrvResult.BorderSizePixel = 0
    SrvResult.Text = "…"
    SrvResult.TextColor3 = Color3.fromRGB(150, 150, 170)
    SrvResult.Font = Enum.Font.GothamSemibold
    SrvResult.TextSize = 10
    SrvResult.TextWrapped = true
    SrvResult.TextYAlignment = Enum.TextYAlignment.Top
    SrvResult.ClipsDescendants = true
    SrvResult.Parent = LeftPanel
    local SrvResCorner = Instance.new("UICorner")
    SrvResCorner.CornerRadius = UDim.new(0, 6)
    SrvResCorner.Parent = SrvResult
    local SrvResPad = Instance.new("UIPadding")
    SrvResPad.PaddingTop = UDim.new(0, 4)
    SrvResPad.PaddingLeft = UDim.new(0, 6)
    SrvResPad.Parent = SrvResult

    --// Копировать серверные ключи
    local lastSrvKeys = {}
    local SrvCopyBtn = Instance.new("TextButton")
    SrvCopyBtn.Size = UDim2.new(1, -20, 0, 24)
    SrvCopyBtn.Position = UDim2.new(0, 10, 0, 576)
    SrvCopyBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    SrvCopyBtn.Text = "📋 КОПИРОВАТЬ КЛЮЧИ"
    SrvCopyBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    SrvCopyBtn.Font = Enum.Font.GothamBold
    SrvCopyBtn.TextSize = 11
    SrvCopyBtn.BorderSizePixel = 0
    SrvCopyBtn.Visible = false
    SrvCopyBtn.Parent = LeftPanel
    local SrvCopyCorner = Instance.new("UICorner")
    SrvCopyCorner.CornerRadius = UDim.new(0, 6)
    SrvCopyCorner.Parent = SrvCopyBtn
    SrvCopyBtn.MouseButton1Click:Connect(function()
        if #lastSrvKeys == 0 then return end
        local all = table.concat(lastSrvKeys, "\n")
        local done = false
        pcall(function() if setclipboard then setclipboard(all) done = true end end)
        pcall(function() if (not done) and toclipboard then toclipboard(all) done = true end end)
        pcall(function() if writefile then writefile("sperma_server_keys_last.txt", all) end end)
        local prev = SrvCopyBtn.Text
        SrvCopyBtn.Text = done and "✅ В БУФЕРЕ!" or "💾 СОХРАНЕНО В ФАЙЛ"
        task.delay(1.5, function() if SrvCopyBtn.Parent then SrvCopyBtn.Text = prev end end)
    end)

    SrvGenBtn.MouseButton1Click:Connect(function()
        local secret = string.gsub(SecBox.Text or "", "%s+", "")
        if #secret <= 4 then
            SrvResult.Text = "⚠️ Введи ADMIN_SECRET (из Vercel) — один раз, сохранится сам"
            SrvResult.TextColor3 = Color3.fromRGB(255, 120, 120)
            return
        end
        local days  = tonumber(DaysBox.Text)  or 30
        local count = tonumber(CountBox.Text) or 1
        local noteStr = string.gsub(NoteBox.Text or "", "%s+", "")
        local srv = KeySystem.Config.Server
        if not (srv and srv.Enabled) then
            SrvResult.Text = "⚠️ Config.Server выключен"
            SrvResult.TextColor3 = Color3.fromRGB(255, 120, 120)
            return
        end
        SrvGenBtn.Text = "⏳ ГЕНЕРИРУЮ..."
        SrvResult.TextColor3 = Color3.fromRGB(150, 150, 170)
        SrvResult.Text = "запрашиваю сервер…"
        task.spawn(function()
            local url = string.format("%s/api/gen?secret=%s&type=%s&days=%s&count=%s%s",
                srv.Url,
                HttpService:UrlEncode(secret),
                HttpService:UrlEncode(srvTypes[srvTypeIdx]),
                tostring(math.floor(days)),
                tostring(math.floor(count)),
                (#noteStr > 0) and ("&note=" .. HttpService:UrlEncode(noteStr)) or "")
            local ok, raw = pcall(function() return game:HttpGet(url) end)
            local okJ, data = false, nil
            if ok and type(raw) == "string" then
                okJ, data = pcall(function() return HttpService:JSONDecode(raw) end)
            end
            task.defer(function() SrvGenBtn.Text = "🌐 СГЕНЕРИТЬ С СЕРВЕРА" end)
            if okJ and type(data) == "table" and data.ok == true and type(data.keys) == "table" then
                lastSrvKeys = data.keys
                local joined = table.concat(lastSrvKeys, "\n")
                SrvResult.Text = "✅ сгенерено: " .. tostring(#lastSrvKeys) .. " шт.\n" .. joined
                SrvResult.TextColor3 = Color3.fromRGB(100, 255, 150)
                SrvCopyBtn.Visible = true
                KeySystem:Audit("SRVGEN " .. tostring(#lastSrvKeys) .. "x " .. srvTypes[srvTypeIdx] .. " " .. tostring(days) .. "d")
            else
                local msg = "сервер вернул ошибку"
                if okJ and type(data) == "table" and data.err then
                    if tostring(data.err) == "forbidden" then msg = "⛔ forbidden — ADMIN_SECRET не совпадает с Vercel!"
                    else msg = "ошибка: " .. tostring(data.err) end
                elseif not ok then msg = "🔌 нет связи с сервером" end
                SrvResult.Text = "❌ " .. msg
                SrvResult.TextColor3 = Color3.fromRGB(255, 120, 120)
            end
        end)
    end)

    --// Stats
    local StatsLabel = Instance.new("TextLabel")
    StatsLabel.Size = UDim2.new(1, -20, 0, 16)
    StatsLabel.Position = UDim2.new(0, 10, 0, 614)
    StatsLabel.BackgroundTransparency = 1
    StatsLabel.Text = "Всего: 0 | Актив: 0 | Истёкло: 0"
    StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    StatsLabel.Font = Enum.Font.Gotham
    StatsLabel.TextSize = 11
    StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatsLabel.TextYAlignment = Enum.TextYAlignment.Top
    StatsLabel.ClipsDescendants = true
    StatsLabel.Parent = LeftPanel

    local HwidLabel = Instance.new("TextLabel")
    HwidLabel.Size = UDim2.new(1, -20, 0, 14)
    HwidLabel.Position = UDim2.new(0, 10, 0, 628)
    HwidLabel.BackgroundTransparency = 1
    HwidLabel.Text = "Мой HWID: " .. GetHWID():sub(1, 18) .. "…"
    HwidLabel.TextColor3 = Color3.fromRGB(110, 110, 130)
    HwidLabel.Font = Enum.Font.Gotham
    HwidLabel.TextSize = 10
    HwidLabel.TextXAlignment = Enum.TextXAlignment.Left
    HwidLabel.ClipsDescendants = true
    HwidLabel.Parent = LeftPanel

    --// Правая панель - Список ключей
    local RightPanel = Instance.new("Frame")
    RightPanel.Size = UDim2.new(0.55, -5, 1, 0)
    RightPanel.Position = UDim2.new(0.45, 5, 0, 0)
    RightPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    RightPanel.BorderSizePixel = 0
    RightPanel.ClipsDescendants = true
    RightPanel.Parent = Content

    local RightCorner = Instance.new("UICorner")
    RightCorner.CornerRadius = UDim.new(0, 8)
    RightCorner.Parent = RightPanel

    local ListTitle = Instance.new("TextLabel")
    ListTitle.Size = UDim2.new(1, -20, 0, 25)
    ListTitle.Position = UDim2.new(0, 10, 0, 10)
    ListTitle.BackgroundTransparency = 1
    ListTitle.Text = "📋 АКТИВНЫЕ КЛЮЧИ"
    ListTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    ListTitle.Font = Enum.Font.GothamBold
    ListTitle.TextSize = 14
    ListTitle.TextXAlignment = Enum.TextXAlignment.Left
    ListTitle.Parent = RightPanel

    --// Refresh Button
    local RefreshBtn = Instance.new("TextButton")
    RefreshBtn.Size = UDim2.new(0, 80, 0, 25)
    RefreshBtn.Position = UDim2.new(1, -90, 0, 8)
    RefreshBtn.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
    RefreshBtn.Text = "🔄 Обновить"
    RefreshBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    RefreshBtn.Font = Enum.Font.GothamBold
    RefreshBtn.TextSize = 11
    RefreshBtn.BorderSizePixel = 0
    RefreshBtn.Parent = RightPanel

    local RefreshCorner = Instance.new("UICorner")
    RefreshCorner.CornerRadius = UDim.new(0, 4)
    RefreshCorner.Parent = RefreshBtn

    --// Keys List
    local KeysScroll = Instance.new("ScrollingFrame")
    KeysScroll.Size = UDim2.new(1, -20, 1, -378)
    KeysScroll.Position = UDim2.new(0, 10, 0, 100)
    KeysScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    KeysScroll.BorderSizePixel = 0
    KeysScroll.ScrollBarThickness = 4
    KeysScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
    KeysScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    KeysScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    KeysScroll.Parent = RightPanel

    local KeysList = Instance.new("UIListLayout")
    KeysList.Padding = UDim.new(0, 5)
    KeysList.Parent = KeysScroll

    --// rev31: forward-decl (хендлеры ниже на них ссылаются)
    local RefreshKeysList
    local SyncEditor
    local RefreshLog
    local lastSyncSel = nil
    local keysFilter = "all"

    --// rev31: чипы-фильтры: Все / Актив / Истёк / Своб.HW
    local chipDefs = {{"all","Все"},{"active","Актив"},{"expired","Истёк"},{"free","Св.HW"}}
    local chipBtns = {}
    local function paintChips()
        for _, cd in ipairs(chipDefs) do
            local b = chipBtns[cd[1]]
            local sel = (keysFilter == cd[1])
            b.BackgroundColor3 = sel and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(30, 30, 45)
            b.TextColor3 = sel and Color3.fromRGB(20, 20, 30) or Color3.fromRGB(200, 200, 200)
        end
    end
    for i, cd in ipairs(chipDefs) do
        local Chip = Instance.new("TextButton")
        Chip.Size = UDim2.new(0, 64, 0, 24)
        Chip.Position = UDim2.new(0, 10 + (i - 1) * 69, 0, 40)
        Chip.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        Chip.Text = cd[2]
        Chip.TextColor3 = Color3.fromRGB(200, 200, 200)
        Chip.Font = Enum.Font.GothamSemibold
        Chip.TextSize = 10
        Chip.BorderSizePixel = 0
        Chip.Parent = RightPanel
        local ChipCorner = Instance.new("UICorner")
        ChipCorner.CornerRadius = UDim.new(0, 5)
        ChipCorner.Parent = Chip
        chipBtns[cd[1]] = Chip
        Chip.MouseButton1Click:Connect(function()
            keysFilter = cd[1]
            pcall(paintChips)
            if RefreshKeysList then pcall(RefreshKeysList) end
        end)
    end
    pcall(paintChips)

    --// rev34 тулбар: 🔎 поиск + ☑ мультиселект пачки
    local searchText = ""
    local SearchOutline = Instance.new("Frame")
    SearchOutline.Size = UDim2.new(0, 92, 0, 24)
    SearchOutline.Position = UDim2.new(0, 10, 0, 68)
    SearchOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    SearchOutline.BorderSizePixel = 0
    SearchOutline.Parent = RightPanel
    local SOC = Instance.new("UICorner")
    SOC.CornerRadius = UDim.new(0, 5)
    SOC.Parent = SearchOutline
    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -10, 1, 0)
    SearchBox.Position = UDim2.new(0, 5, 0, 0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.Text = ""
    SearchBox.PlaceholderText = "🔎 поиск"
    SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 11
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = SearchOutline
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchText = SearchBox.Text:lower()
        if RefreshKeysList then pcall(RefreshKeysList) end
    end)

    local function mkToolBtn(txt, xOff, w, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, w, 0, 24)
        b.Position = UDim2.new(0, xOff, 0, 68)
        b.BackgroundColor3 = color
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        b.Parent = RightPanel
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = b
        return b
    end
    local SelAllBtn = mkToolBtn("☑", 106, 28, Color3.fromRGB(70, 130, 80))
    local MassBanBtn = mkToolBtn("🚫", 138, 28, Color3.fromRGB(170, 60, 60))
    local MassExtBtn = mkToolBtn("+24", 170, 32, Color3.fromRGB(100, 149, 237))
    local MassDelBtn = mkToolBtn("🗑", 206, 28, Color3.fromRGB(200, 60, 60))
    local MassClrBtn = mkToolBtn("✖", 238, 28, Color3.fromRGB(90, 90, 110))

    SelAllBtn.MouseButton1Click:Connect(function()
        for k in pairs(KeySystem.State.KeysDB) do
            KeySystem.State.MultiSel[k] = true
        end
        if RefreshKeysList then pcall(RefreshKeysList) end
    end)
    MassClrBtn.MouseButton1Click:Connect(function()
        KeySystem.State.MultiSel = {}
        if RefreshKeysList then pcall(RefreshKeysList) end
    end)
    MassBanBtn.MouseButton1Click:Connect(function()
        local n = 0
        for k in pairs(KeySystem.State.MultiSel) do
            local d = KeySystem.State.KeysDB[k]
            if d then KeySystem:SetBan(k, not d.banned); n = n + 1 end
        end
        KeySystem:Audit("mass ban x" .. n)
        if RefreshKeysList then pcall(RefreshKeysList) end
        ksNotify("Admin", "Пакетный тогл бана: " .. n, 3)
    end)
    MassExtBtn.MouseButton1Click:Connect(function()
        local n = 0
        for k in pairs(KeySystem.State.MultiSel) do
            if KeySystem:ExtendKey(k, 86400) then n = n + 1 end
        end
        KeySystem:Audit("mass +24h x" .. n)
        if RefreshKeysList then pcall(RefreshKeysList) end
        ksNotify("Admin", "Продлено +24ч: " .. n, 3)
    end)
    MassDelBtn.MouseButton1Click:Connect(function()
        local n = 0
        for k in pairs(KeySystem.State.MultiSel) do
            if KeySystem:RevokeKey(k) then n = n + 1 end
            if KeySystem.State.SelectedKey == k then KeySystem.State.SelectedKey = nil end
        end
        KeySystem.State.MultiSel = {}
        KeySystem:Audit("mass delete x" .. n)
        if RefreshKeysList then pcall(RefreshKeysList) end
        ksNotify("Admin", "🗑 Удалено пачкой: " .. n, 3)
    end)

    --// rev31: РЕДАКТОР избранного ключа
    local Editor = Instance.new("Frame")
    Editor.Size = UDim2.new(1, -20, 0, 146)
    Editor.Position = UDim2.new(0, 10, 1, -272)
    Editor.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
    Editor.BorderSizePixel = 0
    Editor.Parent = RightPanel
    local EditorCorner = Instance.new("UICorner")
    EditorCorner.CornerRadius = UDim.new(0, 6)
    EditorCorner.Parent = Editor

    local SelLabel = Instance.new("TextLabel")
    SelLabel.Size = UDim2.new(1, -16, 0, 14)
    SelLabel.Position = UDim2.new(0, 8, 0, 4)
    SelLabel.BackgroundTransparency = 1
    SelLabel.Text = "Выбран: — (кликни по строке списка)"
    SelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    SelLabel.Font = Enum.Font.GothamBold
    SelLabel.TextSize = 11
    SelLabel.TextXAlignment = Enum.TextXAlignment.Left
    SelLabel.TextTruncate = Enum.TextTruncate.AtEnd
    SelLabel.Parent = Editor

    local NoteOutline = Instance.new("Frame")
    NoteOutline.Size = UDim2.new(0.62, -9, 0, 24)
    NoteOutline.Position = UDim2.new(0, 6, 0, 22)
    NoteOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    NoteOutline.BorderSizePixel = 0
    NoteOutline.Parent = Editor
    local NoteCorner = Instance.new("UICorner")
    NoteCorner.CornerRadius = UDim.new(0, 5)
    NoteCorner.Parent = NoteOutline

    local NoteBox = Instance.new("TextBox")
    NoteBox.Size = UDim2.new(1, -12, 1, 0)
    NoteBox.Position = UDim2.new(0, 6, 0, 0)
    NoteBox.BackgroundTransparency = 1
    NoteBox.Text = ""
    NoteBox.PlaceholderText = "заметка (ник покупателя)"
    NoteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    NoteBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    NoteBox.Font = Enum.Font.Gotham
    NoteBox.TextSize = 11
    NoteBox.TextXAlignment = Enum.TextXAlignment.Left
    NoteBox.ClearTextOnFocus = false
    NoteBox.Parent = NoteOutline

    local function mkEdBtn(text, xScale, xOff, wScale, wOff, yOff, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(wScale, wOff, 0, 24)
        b.Position = UDim2.new(xScale, xOff, 0, yOff)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        b.Parent = Editor
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = b
        return b
    end

    local NoteSaveBtn = mkEdBtn("💾 заметка", 0.64, 0, 0.36, -6, 22, Color3.fromRGB(70, 130, 80))
    local BanBtn   = mkEdBtn("🚫 БАН",  0,   4, 0, 62, 50, Color3.fromRGB(170, 60, 60))
    local SilentBtn= mkEdBtn("🤡 тих",  0,  72, 0, 62, 50, Color3.fromRGB(200, 130, 40))
    local ExtBtn   = mkEdBtn("+24 ч",   0, 140, 0, 62, 50, Color3.fromRGB(100, 149, 237))
    local LimBtn   = mkEdBtn("Лимит ∞", 0, 208, 0, 62, 50, Color3.fromRGB(120, 90, 160))
    local VipBtn   = mkEdBtn("HWID: —", 0,   4, 0, 62, 78, Color3.fromRGB(90, 90, 110))
    local TypBtn   = mkEdBtn("Тип:",    0,  72, 0, 62, 78, Color3.fromRGB(90, 90, 110))
    local BLBtn    = mkEdBtn("BL —",    0, 140, 0, 62, 78, Color3.fromRGB(150, 60, 90))
    local KickBtn  = mkEdBtn("⛔ КИК",  0, 208, 0, 62, 78, Color3.fromRGB(200, 60, 60))

    local RNameOutline = Instance.new("Frame")
    RNameOutline.Size = UDim2.new(0, 96, 0, 24)
    RNameOutline.Position = UDim2.new(0, 4, 0, 106)
    RNameOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    RNameOutline.BorderSizePixel = 0
    RNameOutline.Parent = Editor
    local RNOC = Instance.new("UICorner")
    RNOC.CornerRadius = UDim.new(0, 5)
    RNOC.Parent = RNameOutline
    local RNameBox = Instance.new("TextBox")
    RNameBox.Size = UDim2.new(1, -10, 1, 0)
    RNameBox.Position = UDim2.new(0, 5, 0, 0)
    RNameBox.BackgroundTransparency = 1
    RNameBox.Text = ""
    RNameBox.PlaceholderText = "новое имя ключа"
    RNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    RNameBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    RNameBox.Font = Enum.Font.Gotham
    RNameBox.TextSize = 10
    RNameBox.ClearTextOnFocus = false
    RNameBox.Parent = RNameOutline

    local RenameBtn = Instance.new("TextButton")
    RenameBtn.Size = UDim2.new(0, 30, 0, 24)
    RenameBtn.Position = UDim2.new(0, 104, 0, 106)
    RenameBtn.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
    RenameBtn.Text = "✏"
    RenameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameBtn.Font = Enum.Font.GothamBold
    RenameBtn.TextSize = 12
    RenameBtn.BorderSizePixel = 0
    RenameBtn.Parent = Editor
    local RBCorner = Instance.new("UICorner")
    RBCorner.CornerRadius = UDim.new(0, 5)
    RBCorner.Parent = RenameBtn

    local PriceOutline = Instance.new("Frame")
    PriceOutline.Size = UDim2.new(0, 60, 0, 24)
    PriceOutline.Position = UDim2.new(0, 140, 0, 106)
    PriceOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    PriceOutline.BorderSizePixel = 0
    PriceOutline.Parent = Editor
    local POC = Instance.new("UICorner")
    POC.CornerRadius = UDim.new(0, 5)
    POC.Parent = PriceOutline
    local PriceBox = Instance.new("TextBox")
    PriceBox.Size = UDim2.new(1, -10, 1, 0)
    PriceBox.Position = UDim2.new(0, 5, 0, 0)
    PriceBox.BackgroundTransparency = 1
    PriceBox.Text = ""
    PriceBox.PlaceholderText = "💰"
    PriceBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PriceBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    PriceBox.Font = Enum.Font.GothamBold
    PriceBox.TextSize = 10
    PriceBox.ClearTextOnFocus = false
    PriceBox.Parent = PriceOutline

    local PriceBtn = Instance.new("TextButton")
    PriceBtn.Size = UDim2.new(0, 62, 0, 24)
    PriceBtn.Position = UDim2.new(0, 204, 0, 106)
    PriceBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 80)
    PriceBtn.Text = "💾 цена"
    PriceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PriceBtn.Font = Enum.Font.GothamBold
    PriceBtn.TextSize = 10
    PriceBtn.BorderSizePixel = 0
    PriceBtn.Parent = Editor
    local PBCorner = Instance.new("UICorner")
    PBCorner.CornerRadius = UDim.new(0, 5)
    PBCorner.Parent = PriceBtn

    local EdHint = Instance.new("TextLabel")
    EdHint.Size = UDim2.new(1, -16, 0, 10)
    EdHint.Position = UDim2.new(0, 8, 0, 134)
    EdHint.BackgroundTransparency = 1
    EdHint.Text = "🤡 = фейк-успех без скрипта; ⛔КИК выкидывает юзера с удалёнки за ~45 сек"
    EdHint.TextColor3 = Color3.fromRGB(110, 110, 130)
    EdHint.Font = Enum.Font.Gotham
    EdHint.TextSize = 9
    EdHint.TextXAlignment = Enum.TextXAlignment.Left
    EdHint.Parent = Editor

    SyncEditor = function()
        local k = KeySystem.State.SelectedKey
        local d = k and KeySystem.State.KeysDB[k]
        if not d then
            SelLabel.Text = "Выбран: — (кликни по строке списка)"
            BanBtn.Text = "🚫 БАН"; SilentBtn.Text = "🤡 тих"; LimBtn.Text = "Лимит ∞"
            VipBtn.Text = "HWID: —"; TypBtn.Text = "Тип:"; BLBtn.Text = "BL —"; KickBtn.Text = "⛔ КИК"
            NoteBox.Text = ""
            lastSyncSel = nil
            return
        end
        SelLabel.Text = "Выбран: " .. k .. (d.banned and " 🚫" or "") .. (d.silentBan and " 🤡" or "")
        if lastSyncSel ~= k then
            NoteBox.Text = d.note or ""
            lastSyncSel = k
        end
        BanBtn.Text = d.banned and "✅ разбан" or "🚫 БАН"
        SilentBtn.Text = d.silentBan and "🤡 ВЫКЛ" or "🤡 тих"
        LimBtn.Text = "Лимит: " .. (d.maxActivations and tostring(d.maxActivations) or "∞")
        VipBtn.Text = d.noHwid and "HWID: ВЫКЛ" or "HWID: ВКЛ"
        TypBtn.Text = "Тип: " .. tostring(d.type)
        local blOk = d.hwid and KeySystem.State.HwidBlacklist[tostring(d.hwid)]
        BLBtn.Text = blOk and "BL ✓ (снять)" or "BL +"
        KickBtn.Text = KeySystem:ReadKillFlag(k) and "⛔ КИК ✓" or "⛔ КИК"
    end

    --// хендлеры редактора (все работают с избранным ключом)
    NoteSaveBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        if not k then return end
        KeySystem:SetNote(k, NoteBox.Text)
        pcall(SyncEditor)
        if RefreshKeysList then pcall(RefreshKeysList) end
    end)
    BanBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        local d = k and KeySystem.State.KeysDB[k]
        if not d then return end
        KeySystem:SetBan(k, not d.banned)
        ksNotify("Admin", d.banned and ("🚫 Забанен: " .. k) or ("✅ Разбанен: " .. k), 3)
        pcall(SyncEditor); pcall(RefreshKeysList)
    end)
    ExtBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        if not k then return end
        if KeySystem:ExtendKey(k, 86400) then
            ksNotify("Admin", "⏳ +24 часа: " .. k, 3)
            pcall(RefreshKeysList)
        else
            ksNotify("Admin", "Ключ и так вечный", 3)
        end
    end)
    LimBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        local d = k and KeySystem.State.KeysDB[k]
        if not d then return end
        local ladder = {5, 10, 25, 50}
        local cur = d.maxActivations
        local nxt = nil
        for _, v in ipairs(ladder) do
            if (not cur) or v > cur then nxt = v; break end
        end
        KeySystem:SetMaxActivations(k, nxt)
        ksNotify("Admin", "Лимит входов: " .. (nxt and tostring(nxt) or "бесконечно"), 3)
        pcall(SyncEditor); pcall(RefreshKeysList)
    end)
    VipBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        local d = k and KeySystem.State.KeysDB[k]
        if not d then return end
        KeySystem:SetNoHwid(k, not d.noHwid)
        ksNotify("Admin", d.noHwid and ("VIP (без HWID): " .. k) or ("HWID-привязка ВКЛ: " .. k), 3)
        pcall(SyncEditor); pcall(RefreshKeysList)
    end)
    TypBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        if not k then return end
        KeySystem:CycleType(k)
        local d = KeySystem.State.KeysDB[k]
        ksNotify("Admin", "Новый тип: " .. tostring(d and d.type), 3)
        pcall(SyncEditor); pcall(RefreshKeysList)
    end)
    BLBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        local d = k and KeySystem.State.KeysDB[k]
        if not d or not d.hwid then
            ksNotify("Admin", "⚠ у ключа пока нет HWID", 3)
            return
        end
        local hw = tostring(d.hwid)
        if KeySystem.State.HwidBlacklist[hw] then
            KeySystem:UnBlacklistHwid(hw)
            ksNotify("Admin", "🔓 HWID убран из чёрного списка", 3)
        else
            KeySystem:BlacklistHwid(hw)
            ksNotify("Admin", "⛓ HWID в чёрном списке", 3)
        end
        pcall(SyncEditor)
    end)

    SilentBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        local d = k and KeySystem.State.KeysDB[k]
        if not d then return end
        KeySystem:SetSilent(k, not d.silentBan)
        KeySystem:Audit((d.silentBan and "silent " or "unsilent ") .. k)
        ksNotify("Admin", d.silentBan and ("🤡 Тихий бан: " .. k) or ("🔊 Снят тихий бан: " .. k), 3)
        pcall(SyncEditor); pcall(RefreshKeysList)
    end)
    KickBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        if not k then return end
        local was = KeySystem:ReadKillFlag(k)
        KeySystem:SetKill(k, not was)
        ksNotify("Admin", was and ("☑ Убрал кик: " .. k) or ("⛔ КИК выдан: " .. k .. " (~45 сек)"), 4)
        pcall(SyncEditor)
    end)
    RenameBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        if not k then return end
        if KeySystem:RenameKey(k, RNameBox.Text) then
            ksNotify("Admin", "✏ Ключ переименован в: " .. RNameBox.Text, 3)
            RNameBox.Text = ""
            RefreshKeysList()
        else
            ksNotify("Admin", "⚠ не получилось (имя занято или <3)", 3)
        end
    end)
    PriceBtn.MouseButton1Click:Connect(function()
        local k = KeySystem.State.SelectedKey
        if not k then return end
        if KeySystem:SetPrice(k, PriceBox.Text) then
            ksNotify("Admin", "💰 Цена " .. tostring(PriceBox.Text) .. "₽ → " .. k, 3)
            PriceBox.Text = ""
            RefreshKeysList()
        end
    end)

    --// rev31: ЛОГ АКТИВАЦИЙ
    local LogPanel = Instance.new("Frame")
    LogPanel.Size = UDim2.new(1, -20, 0, 116)
    LogPanel.Position = UDim2.new(0, 10, 1, -122)
    LogPanel.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
    LogPanel.BorderSizePixel = 0
    LogPanel.Parent = RightPanel
    local LogCorner = Instance.new("UICorner")
    LogCorner.CornerRadius = UDim.new(0, 6)
    LogCorner.Parent = LogPanel

    local LogTitle = Instance.new("TextLabel")
    LogTitle.Size = UDim2.new(1, -110, 0, 16)
    LogTitle.Position = UDim2.new(0, 8, 0, 2)
    LogTitle.BackgroundTransparency = 1
    LogTitle.Text = "📜 ЛОГ АКТИВАЦИЙ"
    LogTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    LogTitle.Font = Enum.Font.GothamBold
    LogTitle.TextSize = 11
    LogTitle.TextXAlignment = Enum.TextXAlignment.Left
    LogTitle.Parent = LogPanel

    local LogCopy = Instance.new("TextButton")
    LogCopy.Size = UDim2.new(0, 86, 0, 16)
    LogCopy.Position = UDim2.new(1, -94, 0, 2)
    LogCopy.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    LogCopy.Text = "📋 копир."
    LogCopy.TextColor3 = Color3.fromRGB(200, 200, 220)
    LogCopy.Font = Enum.Font.GothamBold
    LogCopy.TextSize = 10
    LogCopy.BorderSizePixel = 0
    LogCopy.Parent = LogPanel
    local LogCopyCorner = Instance.new("UICorner")
    LogCopyCorner.CornerRadius = UDim.new(0, 4)
    LogCopyCorner.Parent = LogCopy

    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Size = UDim2.new(1, -16, 0, 94)
    LogScroll.Position = UDim2.new(0, 8, 0, 22)
    LogScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 3
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogScroll.Parent = LogPanel

    local LogText = Instance.new("TextLabel")
    LogText.Size = UDim2.new(1, -8, 0, 0)
    LogText.BackgroundTransparency = 1
    LogText.Text = "—"
    LogText.TextColor3 = Color3.fromRGB(180, 180, 200)
    LogText.Font = Enum.Font.Gotham
    LogText.TextSize = 10
    LogText.TextXAlignment = Enum.TextXAlignment.Left
    LogText.TextYAlignment = Enum.TextYAlignment.Top
    LogText.AutomaticSize = Enum.AutomaticSize.Y
    LogText.TextWrapped = false
    LogText.Parent = LogScroll

    RefreshLog = function()
        local lines = {}
        for i = 1, math.min(#KeySystem.State.ActLog, 25) do
            local e = KeySystem.State.ActLog[i]
            local mark = e.ok and "✓" or "✗"
            lines[#lines + 1] = string.format("%s %s %s @%s [%s]", os.date("%d.%m %H:%M", e.t), mark, e.k, e.hw, e.r)
        end
        LogText.Text = (#lines > 0) and table.concat(lines, "\n") or "пока пусто"
    end

    LogCopy.MouseButton1Click:Connect(function()
        if setclipboard then
            pcall(setclipboard, LogText.Text)
            LogCopy.Text = "✓ скоп."
            task.delay(1.5, function()
                pcall(function() LogCopy.Text = "📋 копир." end)
            end)
        end
    end)

    --// Функции
local function UpdateStats()
        local total = KeySystem:GetKeyCount()
        local active, expired = 0, 0
        local now = tick()

        for _, data in pairs(KeySystem.State.KeysDB) do
            if data.expires and now > data.expires then
                expired = expired + 1
            else
                active = active + 1
            end
        end

        -- 💰 выручка
        local revenue, sold = KeySystem:GetRevenue()
        StatsLabel.Text = string.format("Всего: %d | Актив: %d | Вых: %d₽ (%d)", total, active, revenue, sold)

        -- 📊 мини-дашборд в заголовке: входы за сутки / уник. устройства / онлайн
        local day = os.time() - 86400
        local todayIn, uniqHw = 0, {}
        for _, e in ipairs(KeySystem.State.ActLog) do
            if e.t and e.t >= day and e.ok and e.r ~= "started" then
                todayIn = todayIn + 1
                uniqHw[e.hw] = true
            end
        end
        local hu = 0
        for _ in pairs(uniqHw) do hu = hu + 1 end
        local online = 0
        for k in pairs(KeySystem.State.KeysDB) do
            if KeySystem:IsOnline(k) then online = online + 1 end
        end
        ListTitle.Text = string.format("📋 КЛЮЧИ • сег: %d вход • %d устр. • 🟢 %d",
            todayIn, hu, online) .. (KeySystem.State.IsModer and " [МОДЕР]" or "")
        ListTitle.TextSize = 11
    end

RefreshKeysList = function()
        for _, child in ipairs(KeysScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local now = tick()
        KeySystem:ReadHeartbeats()
        local filter = keysFilter or "all"
        local isModerR = KeySystem.State.IsModer
        local search = (type(searchText) == "string" and #searchText > 0) and searchText or nil

        -- сортировка: онлайн → свежие
        local rows = {}
        for key, data in pairs(KeySystem.State.KeysDB) do
            rows[#rows + 1] = {key = key, d = data}
        end
        table.sort(rows, function(a, b)
            local ao, bo = KeySystem:IsOnline(a.key), KeySystem:IsOnline(b.key)
            if ao ~= bo then return ao end
            return tostring(a.key) < tostring(b.key)
        end)

        for _, row in ipairs(rows) do
            local key = row.key
            local data = row.d
            local isExpired = data.expires ~= nil and now > data.expires

            local show = (filter == "all")
                or (filter == "active" and not isExpired)
                or (filter == "expired" and isExpired)
                or (filter == "free" and data.hwid == nil)
            if show and search then
                local hay = (tostring(key) .. "|" .. tostring(data.note or "") .. "|" .. tostring(data.hwid or "")):lower()
                if not hay:find(search, 1, true) then show = false end
            end

            if show then
                local online = KeySystem:IsOnline(key)
                local bannedNow = data.banned or data.silentBan
                local kt = KeySystem.KeyTypes[data.typeIndex]
                local keyColor = data.banned and Color3.fromRGB(255, 80, 80)
                    or (isExpired and Color3.fromRGB(100, 100, 100)
                    or (kt and kt.Color or Color3.fromRGB(255, 215, 0)))
                local isSel = (KeySystem.State.SelectedKey == key)
                local isMulti = KeySystem.State.MultiSel[key] and true or false

                local KeyFrame = Instance.new("Frame")
                KeyFrame.Size = UDim2.new(1, -10, 0, 50)
                KeyFrame.BackgroundColor3 = isSel and Color3.fromRGB(45, 45, 70)
                    or (isMulti and Color3.fromRGB(35, 50, 40) or Color3.fromRGB(25, 25, 40))
                KeyFrame.BorderSizePixel = 0
                KeyFrame.Parent = KeysScroll

                local KF_Corner = Instance.new("UICorner")
                KF_Corner.CornerRadius = UDim.new(0, 4)
                KF_Corner.Parent = KeyFrame

                -- ☑ галочка мультивыбора
                if not isModerR then
                    local ChkBtn = Instance.new("TextButton")
                    ChkBtn.Size = UDim2.new(0, 16, 0, 20)
                    ChkBtn.Position = UDim2.new(0, 4, 0, 15)
                    ChkBtn.BackgroundColor3 = isMulti and Color3.fromRGB(70, 170, 90) or Color3.fromRGB(40, 40, 58)
                    ChkBtn.Text = isMulti and "✓" or ""
                    ChkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    ChkBtn.Font = Enum.Font.GothamBold
                    ChkBtn.TextSize = 11
                    ChkBtn.BorderSizePixel = 0
                    ChkBtn.ZIndex = 3
                    ChkBtn.Parent = KeyFrame
                    local ChkCorner = Instance.new("UICorner")
                    ChkCorner.CornerRadius = UDim.new(0, 3)
                    ChkCorner.Parent = ChkBtn
                    ChkBtn.MouseButton1Click:Connect(function()
                        if KeySystem.State.MultiSel[key] then
                            KeySystem.State.MultiSel[key] = nil
                        else
                            KeySystem.State.MultiSel[key] = true
                        end
                        RefreshKeysList()
                    end)

                    -- выбор ключа кликом (остальная площадь)
                    local SelBtn = Instance.new("TextButton")
                    SelBtn.Size = UDim2.new(1, -70, 1, 0)
                    SelBtn.BackgroundTransparency = 1
                    SelBtn.Text = ""
                    SelBtn.AutoButtonColor = false
                    SelBtn.ZIndex = 2
                    SelBtn.Parent = KeyFrame
                    SelBtn.MouseButton1Click:Connect(function()
                        KeySystem.State.SelectedKey = key
                        pcall(RefreshKeysList)
                    end)
                end

                -- значки: 🔥 1-раз / 🤡 тихий / ⏳ отсчёт / 🏆 тир / 💰 цена / 🎮
                local badges = ""
                if data.oneTime then badges = badges .. "🔥 " end
                if data.silentBan and not data.banned then badges = badges .. "🤡 " end
                if data.noHwid then badges = badges .. "VIP " end
                if data.tier and data.tier ~= "LITE" then badges = badges .. "🏆" .. data.tier .. " " end
                if data.price then badges = badges .. "💰" .. tostring(data.price) .. "₽ " end
                if (data.playSeconds or 0) > 0 then badges = badges .. "🎮" .. string.format("%.1fч ", data.playSeconds / 3600) end

                local KeyLabel = Instance.new("TextLabel")
                KeyLabel.Size = UDim2.new(1, -90, 0, 20)
                KeyLabel.Position = UDim2.new(0, 26, 0, 5)
                KeyLabel.BackgroundTransparency = 1
                KeyLabel.Text = (online and "🟢 " or "") .. badges .. key .. (data.note and (" — " .. data.note) or "")
                KeyLabel.TextColor3 = keyColor
                KeyLabel.Font = Enum.Font.GothamBold
                KeyLabel.TextSize = 10
                KeyLabel.TextXAlignment = Enum.TextXAlignment.Left
                KeyLabel.TextTruncate = Enum.TextTruncate.AtEnd
                KeyLabel.Parent = KeyFrame

                local InfoLabel = Instance.new("TextLabel")
                InfoLabel.Size = UDim2.new(1, -90, 0, 15)
                InfoLabel.Position = UDim2.new(0, 26, 0, 25)
                InfoLabel.BackgroundTransparency = 1

                local timeLeft = ""
                if data.pendingStart and data.expires == nil then
                    timeLeft = "⏳ стартует при входе"
                elseif isExpired then
                    timeLeft = "ИСТЁК"
                elseif data.expires == math.huge then
                    timeLeft = "Навсегда"
                elseif data.expires == nil then
                    timeLeft = "?"
                else
                    local left = data.expires - now
                    if left > 86400 then
                        timeLeft = string.format("%.1f дн.", left / 86400)
                    elseif left > 3600 then
                        timeLeft = string.format("%.1f ч.", left / 3600)
                    else
                        timeLeft = string.format("%.0f мин.", left / 60)
                    end
                end

                local hwidShort = data.noHwid and "без HWID"
                    or ((data.hwid ~= nil) and ("HW:" .. tostring(data.hwid):sub(1, 8) .. "…") or "HW: свободен")
                local lim = data.maxActivations and ("/" .. tostring(data.maxActivations)) or ""
                InfoLabel.Text = string.format("%s%s | %s | %s | %s | x%d%s",
                    data.banned and "🚫 БАН | " or "",
                    tostring(data.type), timeLeft,
                    data.used and "Использован" or "Свежий",
                    hwidShort, data.activations or 0, lim)
                InfoLabel.TextColor3 = data.banned and Color3.fromRGB(255, 120, 120)
                    or (isExpired and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(180, 180, 200))
                InfoLabel.Font = Enum.Font.Gotham
                InfoLabel.TextSize = 10
                InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
                InfoLabel.Parent = KeyFrame

                if not isModerR then
                    -- HWID reset
                    local HwBtn = Instance.new("TextButton")
                    HwBtn.Size = UDim2.new(0, 45, 0, 20)
                    HwBtn.Position = UDim2.new(1, -55, 0, 5)
                    HwBtn.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
                    HwBtn.Text = "↺HWID"
                    HwBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    HwBtn.Font = Enum.Font.GothamBold
                    HwBtn.TextSize = 9
                    HwBtn.BorderSizePixel = 0
                    HwBtn.ZIndex = 3
                    HwBtn.Visible = (data.hwid ~= nil) and not data.noHwid
                    HwBtn.Parent = KeyFrame
                    local HwCorner = Instance.new("UICorner")
                    HwCorner.CornerRadius = UDim.new(0, 4)
                    HwCorner.Parent = HwBtn
                    HwBtn.MouseButton1Click:Connect(function()
                        KeySystem:ResetHwid(key)
                        RefreshKeysList()
                    end)

                    -- Delete
                    local DelBtn = Instance.new("TextButton")
                    DelBtn.Size = UDim2.new(0, 45, 0, 20)
                    DelBtn.Position = UDim2.new(1, -55, 0, 27)
                    DelBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                    DelBtn.Text = "Удалить"
                    DelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    DelBtn.Font = Enum.Font.GothamBold
                    DelBtn.TextSize = 10
                    DelBtn.BorderSizePixel = 0
                    DelBtn.ZIndex = 3
                    DelBtn.Parent = KeyFrame
                    local DelCorner = Instance.new("UICorner")
                    DelCorner.CornerRadius = UDim.new(0, 4)
                    DelCorner.Parent = DelBtn
                    DelBtn.MouseButton1Click:Connect(function()
                        KeySystem:RevokeKey(key)
                        if KeySystem.State.SelectedKey == key then KeySystem.State.SelectedKey = nil end
                        KeySystem.State.MultiSel[key] = nil
                        RefreshKeysList()
                    end)
                end
            end
        end

        if SyncEditor then pcall(SyncEditor) end
        UpdateStats()
    end

    --// rev31: ЛЕВАЯ ПАНЕЛЬ — мультиген / VIP / пароль / экспорт-импорт / вайп
    local genNoHwid = false

    local NOutline = Instance.new("Frame")
    NOutline.Size = UDim2.new(0, 72, 0, 26)
    NOutline.Position = UDim2.new(0, 10, 0, 322)
    NOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    NOutline.BorderSizePixel = 0
    NOutline.Parent = LeftPanel
    local NCorner = Instance.new("UICorner")
    NCorner.CornerRadius = UDim.new(0, 6)
    NCorner.Parent = NOutline
    local NBox = Instance.new("TextBox")
    NBox.Size = UDim2.new(1, -24, 1, 0)
    NBox.Position = UDim2.new(0, 6, 0, 0)
    NBox.BackgroundTransparency = 1
    NBox.Text = "1"
    NBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    NBox.Font = Enum.Font.GothamBold
    NBox.TextSize = 12
    NBox.TextXAlignment = Enum.TextXAlignment.Right
    NBox.ClearTextOnFocus = false
    NBox.Parent = NOutline
    local NMark = Instance.new("TextLabel")
    NMark.Size = UDim2.new(0, 16, 1, 0)
    NMark.Position = UDim2.new(1, -18, 0, 0)
    NMark.BackgroundTransparency = 1
    NMark.Text = "шт"
    NMark.TextColor3 = Color3.fromRGB(150, 150, 170)
    NMark.Font = Enum.Font.Gotham
    NMark.TextSize = 10
    NMark.Parent = NOutline

    local NoHwidBtn = Instance.new("TextButton")
    NoHwidBtn.Size = UDim2.new(1, -97, 0, 26)
    NoHwidBtn.Position = UDim2.new(0, 87, 0, 322)
    NoHwidBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    NoHwidBtn.Text = "HWID-привязка: ВКЛ"
    NoHwidBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    NoHwidBtn.Font = Enum.Font.GothamSemibold
    NoHwidBtn.TextSize = 10
    NoHwidBtn.BorderSizePixel = 0
    NoHwidBtn.Parent = LeftPanel
    local NoHwidCorner = Instance.new("UICorner")
    NoHwidCorner.CornerRadius = UDim.new(0, 6)
    NoHwidCorner.Parent = NoHwidBtn
    NoHwidBtn.MouseButton1Click:Connect(function()
        genNoHwid = not genNoHwid
        NoHwidBtn.Text = genNoHwid and "VIP: БЕЗ HWID" or "HWID-привязка: ВКЛ"
        NoHwidBtn.BackgroundColor3 = genNoHwid and Color3.fromRGB(147, 112, 219) or Color3.fromRGB(30, 30, 45)
    end)

    --// смена пароля админки
    local PassHint = Instance.new("TextLabel")
    PassHint.Size = UDim2.new(1, -20, 0, 12)
    PassHint.Position = UDim2.new(0, 10, 0, 412)
    PassHint.BackgroundTransparency = 1
    PassHint.Text = "Новый пароль админки (≥2 символа):"
    PassHint.TextColor3 = Color3.fromRGB(150, 150, 170)
    PassHint.Font = Enum.Font.Gotham
    PassHint.TextSize = 10
    PassHint.TextXAlignment = Enum.TextXAlignment.Left
    PassHint.Parent = LeftPanel

    local PassOutline = Instance.new("Frame")
    PassOutline.Size = UDim2.new(1, -116, 0, 26)
    PassOutline.Position = UDim2.new(0, 10, 0, 426)
    PassOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    PassOutline.BorderSizePixel = 0
    PassOutline.Parent = LeftPanel
    local PassCorner = Instance.new("UICorner")
    PassCorner.CornerRadius = UDim.new(0, 6)
    PassCorner.Parent = PassOutline
    local PassBox = Instance.new("TextBox")
    PassBox.Size = UDim2.new(1, -12, 1, 0)
    PassBox.Position = UDim2.new(0, 6, 0, 0)
    PassBox.BackgroundTransparency = 1
    PassBox.Text = ""
    PassBox.PlaceholderText = "1337 → свой пароль"
    PassBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PassBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    PassBox.Font = Enum.Font.GothamBold
    PassBox.TextSize = 11
    PassBox.TextXAlignment = Enum.TextXAlignment.Left
    PassBox.ClearTextOnFocus = false
    PassBox.Parent = PassOutline

    local PassSaveBtn = Instance.new("TextButton")
    PassSaveBtn.Size = UDim2.new(0, 96, 0, 26)
    PassSaveBtn.Position = UDim2.new(1, -106, 0, 426)
    PassSaveBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 80)
    PassSaveBtn.Text = "💾 пароль"
    PassSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PassSaveBtn.Font = Enum.Font.GothamBold
    PassSaveBtn.TextSize = 11
    PassSaveBtn.BorderSizePixel = 0
    PassSaveBtn.Parent = LeftPanel
    local PassSaveCorner = Instance.new("UICorner")
    PassSaveCorner.CornerRadius = UDim.new(0, 6)
    PassSaveCorner.Parent = PassSaveBtn
    PassSaveBtn.MouseButton1Click:Connect(function()
        local np = tostring(PassBox.Text or ""):gsub("%s+", "")
        if #np < 2 then
            ksNotify("Admin", "⚠ пароль минимум 2 символа", 3)
            return
        end
        KeySystem.Config.AdminPassword = np
        KeySystem:SaveMeta()
        PassBox.Text = ""
        ksNotify("Admin", "🔑 Пароль админки изменён!", 3)
    end)

    --// экспорт / импорт базы
    local ExpBtn = Instance.new("TextButton")
    ExpBtn.Size = UDim2.new(0.5, -15, 0, 26)
    ExpBtn.Position = UDim2.new(0, 10, 0, 458)
    ExpBtn.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
    ExpBtn.Text = "📤 Экспорт"
    ExpBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    ExpBtn.Font = Enum.Font.GothamBold
    ExpBtn.TextSize = 11
    ExpBtn.BorderSizePixel = 0
    ExpBtn.Parent = LeftPanel
    local ExpCorner = Instance.new("UICorner")
    ExpCorner.CornerRadius = UDim.new(0, 6)
    ExpCorner.Parent = ExpBtn

    local ImpBtn = Instance.new("TextButton")
    ImpBtn.Size = UDim2.new(0.5, -15, 0, 26)
    ImpBtn.Position = UDim2.new(0.5, 5, 0, 458)
    ImpBtn.BackgroundColor3 = Color3.fromRGB(147, 112, 219)
    ImpBtn.Text = "📥 Импорт"
    ImpBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    ImpBtn.Font = Enum.Font.GothamBold
    ImpBtn.TextSize = 11
    ImpBtn.BorderSizePixel = 0
    ImpBtn.Parent = LeftPanel
    local ImpCorner = Instance.new("UICorner")
    ImpCorner.CornerRadius = UDim.new(0, 6)
    ImpCorner.Parent = ImpBtn

    local ImpOutline = Instance.new("Frame")
    ImpOutline.Size = UDim2.new(1, -20, 0, 26)
    ImpOutline.Position = UDim2.new(0, 10, 0, 490)
    ImpOutline.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    ImpOutline.BorderSizePixel = 0
    ImpOutline.Parent = LeftPanel
    local ImpCorner2 = Instance.new("UICorner")
    ImpCorner2.CornerRadius = UDim.new(0, 6)
    ImpCorner2.Parent = ImpOutline
    local ImpBox = Instance.new("TextBox")
    ImpBox.Size = UDim2.new(1, -12, 1, 0)
    ImpBox.Position = UDim2.new(0, 6, 0, 0)
    ImpBox.BackgroundTransparency = 1
    ImpBox.Text = ""
    ImpBox.PlaceholderText = "вставь JSON экспорта → жми Импорт"
    ImpBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    ImpBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    ImpBox.Font = Enum.Font.Gotham
    ImpBox.TextSize = 10
    ImpBox.TextXAlignment = Enum.TextXAlignment.Left
    ImpBox.ClearTextOnFocus = false
    ImpBox.Parent = ImpOutline

    ExpBtn.MouseButton1Click:Connect(function()
        local safe = {}
        for kk, dd in pairs(KeySystem.State.KeysDB) do
            local c = {}
            for f, v in pairs(dd) do c[f] = (v == math.huge and -1) or v end
            safe[kk] = c
        end
        local payload
        local okj = pcall(function()
            payload = HttpService:JSONEncode({
                keys = safe,
                meta = {
                    adminPassword = KeySystem.Config.AdminPassword,
                    hwidBlacklist = KeySystem.State.HwidBlacklist,
                },
            })
        end)
        if not okj or not payload then
            ksNotify("Admin", "⚠ не смог сериализовать", 3)
            return
        end
        if setclipboard then pcall(setclipboard, payload) end
        ksNotify("Admin", "📤 База в буфере обмена", 3)
    end)

    ImpBtn.MouseButton1Click:Connect(function()
        local raw = tostring(ImpBox.Text or "")
        if #raw < 5 then
            ksNotify("Admin", "⚠ вставь JSON в поле ниже", 3)
            return
        end
        local decoded
        local okj = pcall(function() decoded = HttpService:JSONDecode(raw) end)
        if not okj or type(decoded) ~= "table" then
            ksNotify("Admin", "⚠ битый JSON", 3)
            return
        end
        local keys = (type(decoded.keys) == "table") and decoded.keys or decoded
        local added = 0
        for kk, dd in pairs(keys) do
            if type(dd) == "table" and dd.expires ~= nil then
                if dd.expires == -1 then dd.expires = math.huge end
                KeySystem.State.KeysDB[kk] = dd
                added = added + 1
            end
        end
        if type(decoded.meta) == "table" then
            if type(decoded.meta.adminPassword) == "string" and #decoded.meta.adminPassword >= 2 then
                KeySystem.Config.AdminPassword = decoded.meta.adminPassword
            end
            if type(decoded.meta.hwidBlacklist) == "table" then
                KeySystem.State.HwidBlacklist = decoded.meta.hwidBlacklist
            end
        end
        KeySystem:SaveKeys()
        KeySystem:SaveMeta()
        ImpBox.Text = ""
        RefreshKeysList()
        RefreshLog()
        ksNotify("Admin", "📥 Импортировано ключей: " .. added, 3)
    end)

    --// rev34: генераторные тоглы 🔥1-раз / ⏳отсчёт-с-входа / свой срок / 💰цена
    local genOneTime = false
    local OneTimeBtn = Instance.new("TextButton")
    OneTimeBtn.Size = UDim2.new(0.5, -15, 0, 24)
    OneTimeBtn.Position = UDim2.new(0, 10, 0, 352)
    OneTimeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    OneTimeBtn.Text = "🔥 ОДНОРАЗОВЫЙ"
    OneTimeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    OneTimeBtn.Font = Enum.Font.GothamBold
    OneTimeBtn.TextSize = 10
    OneTimeBtn.BorderSizePixel = 0
    OneTimeBtn.Parent = LeftPanel
    local OTCorner = Instance.new("UICorner")
    OTCorner.CornerRadius = UDim.new(0, 6)
    OTCorner.Parent = OneTimeBtn

    local genDefer = false
    local DeferBtn = Instance.new("TextButton")
    DeferBtn.Size = UDim2.new(0.5, -15, 0, 24)
    DeferBtn.Position = UDim2.new(0.5, 5, 0, 352)
    DeferBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    DeferBtn.Text = "⏳ ОТСЧЁТ-С-ВХОДА"
    DeferBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    DeferBtn.Font = Enum.Font.GothamBold
    DeferBtn.TextSize = 10
    DeferBtn.BorderSizePixel = 0
    DeferBtn.Parent = LeftPanel
    local DFCorner = Instance.new("UICorner")
    DFCorner.CornerRadius = UDim.new(0, 6)
    DFCorner.Parent = DeferBtn

    OneTimeBtn.MouseButton1Click:Connect(function()
        genOneTime = not genOneTime
        OneTimeBtn.Text = genOneTime and "🔥 1-РАЗ: ВКЛ ✓" or "🔥 ОДНОРАЗОВЫЙ"
        OneTimeBtn.BackgroundColor3 = genOneTime and Color3.fromRGB(200, 80, 40) or Color3.fromRGB(30, 30, 45)
    end)
    DeferBtn.MouseButton1Click:Connect(function()
        genDefer = not genDefer
        DeferBtn.Text = genDefer and "⏳ СТАРТ-С-ВХОДА ✓" or "⏳ ОТСЧЁТ-С-ВХОДА"
        DeferBtn.BackgroundColor3 = genDefer and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(30, 30, 45)
    end)

    local function mkSmallBox(placeholder, y, xScale, xOff, wScale, wOff)
        local o = Instance.new("Frame")
        o.Size = UDim2.new(wScale, wOff, 0, 26)
        o.Position = UDim2.new(xScale, xOff, 0, y)
        o.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        o.BorderSizePixel = 0
        o.Parent = LeftPanel
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = o
        local b = Instance.new("TextBox")
        b.Size = UDim2.new(1, -12, 1, 0)
        b.Position = UDim2.new(0, 6, 0, 0)
        b.BackgroundTransparency = 1
        b.Text = ""
        b.PlaceholderText = placeholder
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.ClearTextOnFocus = false
        b.Parent = o
        return b, o
    end
    local DurBox, DurOutline = mkSmallBox("свой срок: 6h/3d/2w", 382, 0, 10, 0.55, -13)
    local PriceGenBox, PriceGenOutline = mkSmallBox("💰 ₽/шт", 382, 0.58, 5, 0.42, -15)

    --// rev34: MOTD + Режим обслуживания
    local MotdBox, MotdOutline = mkSmallBox("📣 MOTD при входе", 550, 0, 10, 0.62, -13)
    local MaintBtn = Instance.new("TextButton")
    MaintBtn.Size = UDim2.new(0.38, -19, 0, 26)
    MaintBtn.Position = UDim2.new(0.62, 3, 0, 550)
    MaintBtn.BackgroundColor3 = KeySystem.State.Maintenance and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(70, 130, 80)
    MaintBtn.Text = KeySystem.State.Maintenance and "🔧 ВКЛ" or "🔧 ВЫКЛ"
    MaintBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MaintBtn.Font = Enum.Font.GothamBold
    MaintBtn.TextSize = 10
    MaintBtn.BorderSizePixel = 0
    MaintBtn.Parent = LeftPanel
    local MaintCorner = Instance.new("UICorner")
    MaintCorner.CornerRadius = UDim.new(0, 6)
    MaintCorner.Parent = MaintBtn
    MotdBox.FocusLost:Connect(function(enter)
        if enter then KeySystem:SetMotd(MotdBox.Text) end
    end)
    MaintBtn.MouseButton1Click:Connect(function()
        KeySystem:SetMaintenance(not KeySystem.State.Maintenance)
        MaintBtn.Text = KeySystem.State.Maintenance and "🔧 ВКЛ" or "🔧 ВЫКЛ"
        MaintBtn.BackgroundColor3 = KeySystem.State.Maintenance and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(70, 130, 80)
        ksNotify("Admin", KeySystem.State.Maintenance and "🔧 Техработы ВКЛ — все ключи молчат" or "🔧 Техработы ВЫКЛ", 3)
    end)
    MotdBox.Text = KeySystem.State.Motd or ""

    --// rev34: minVersion (минимальная ревизия сборки)
    local MinVerBox, MinVerOutline = mkSmallBox("minRev (" .. tostring(KeySystem.State.MinVersion or "—") .. ")", 582, 0, 10, 0.62, -13)
    local MVSaveBtn = Instance.new("TextButton")
    MVSaveBtn.Size = UDim2.new(0.38, -19, 0, 26)
    MVSaveBtn.Position = UDim2.new(0.62, 3, 0, 582)
    MVSaveBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
    MVSaveBtn.Text = "💾 minRev"
    MVSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MVSaveBtn.Font = Enum.Font.GothamBold
    MVSaveBtn.TextSize = 10
    MVSaveBtn.BorderSizePixel = 0
    MVSaveBtn.Parent = LeftPanel
    local MVSaveCorner = Instance.new("UICorner")
    MVSaveCorner.CornerRadius = UDim.new(0, 6)
    MVSaveCorner.Parent = MVSaveBtn
    MVSaveBtn.MouseButton1Click:Connect(function()
        local v = tonumber(MinVerBox.Text)
        KeySystem:SetMinVersion(v)
        MinVerBox.Text = ""
        MinVerBox.PlaceholderText = "minRev (" .. tostring(KeySystem.State.MinVersion or "—") .. ")"
        ksNotify("Admin", "🧱 minRev = " .. tostring(KeySystem.State.MinVersion or "снято"), 3)
    end)

    --// вайп базы (двойное нажатие)
    local WipeBtn = Instance.new("TextButton")
    WipeBtn.Size = UDim2.new(1, -20, 0, 24)
    WipeBtn.Position = UDim2.new(0, 10, 0, 522)
    WipeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    WipeBtn.Text = "🧹 УДАЛИТЬ ВСЕ КЛЮЧИ"
    WipeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    WipeBtn.Font = Enum.Font.GothamBold
    WipeBtn.TextSize = 11
    WipeBtn.BorderSizePixel = 0
    WipeBtn.Parent = LeftPanel
    local WipeCorner = Instance.new("UICorner")
    WipeCorner.CornerRadius = UDim.new(0, 6)
    WipeCorner.Parent = WipeBtn
    local wipeArmed = false
    local function wipeReset()
        wipeArmed = false
        pcall(function()
            WipeBtn.Text = "🧹 УДАЛИТЬ ВСЕ КЛЮЧИ"
            WipeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        end)
    end
    WipeBtn.MouseButton1Click:Connect(function()
        if not wipeArmed then
            wipeArmed = true
            WipeBtn.Text = "❓ ТОЧНО? жми ещё раз"
            WipeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
            task.delay(6, wipeReset)
        else
            KeySystem.State.KeysDB = {}
            KeySystem.State.SelectedKey = nil
            KeySystem:SaveKeys()
            wipeReset()
            RefreshKeysList()
            RefreshLog()
            ksNotify("Admin", "🧹 База ключей очищена", 3)
        end
    end)

    --// rev34: МОДЕР (mod2288) — видит только генерацию и список
    if KeySystem.State.IsModer then
        local hide = {Editor, LogPanel, NOutline, NMark, NoHwidBtn, OneTimeBtn, DeferBtn,
                      DurOutline, PriceGenOutline, PassHint, PassOutline, PassSaveBtn,
                      ExpBtn, ImpBtn, ImpOutline, WipeBtn, MotdOutline, MaintBtn,
                      MinVerOutline, MVSaveBtn, SearchOutline, SelAllBtn, MassBanBtn,
                      MassExtBtn, MassDelBtn, MassClrBtn}
        for _, w in ipairs(hide) do
            pcall(function() w.Visible = false end)
        end
        for _, b in pairs(chipBtns) do
            pcall(function() b.Visible = false end)
        end
        KillBtn.Visible = false
        RunBtn.Visible = false
    end

    --// авто-обновление онлайн-меток раз в 20 сек
    task.spawn(function()
        while task.wait(20) do
            if not (ScreenGui and ScreenGui.Parent) then break end
            pcall(KeySystem.ReadHeartbeats, KeySystem)
            pcall(RefreshKeysList)
        end
    end)

    --// Generate logic (rev31: ×N мультиген + VIP)
    local lastGenList = {}
    GenBtn.MouseButton1Click:Connect(function()
        local custom = tostring(CustomKeyBox.Text or "")
        local hasCustom = #custom > 0
        local n = math.clamp(math.floor(tonumber(NBox.Text) or 1), 1, 50)
        if hasCustom then n = 1 end
        local genOpts = {
            noHwid = genNoHwid,
            oneTime = genOneTime,
            defer = genDefer,
            tier = genTierDefs[genTierIdx].Name,
        }
        local dsec = ParseDuration(DurBox.Text)
        if dsec then genOpts.durationSecs = dsec end
        local prc = tonumber(PriceGenBox.Text)
        if prc then genOpts.price = prc end
        lastGenList = {}
        local lastErr = nil
        for i = 1, n do
            local newKey, keyType, err = KeySystem:GenerateKey(selectedType, (i == 1 and hasCustom) and custom or nil, genOpts)
            if newKey then
                table.insert(lastGenList, newKey)
            else
                lastErr = err
            end
        end
        if #lastGenList > 0 then
            ResultText.Text = (#lastGenList == 1) and lastGenList[1] or ("✓ создано: " .. #lastGenList .. " шт")
            ResultText.TextColor3 = Color3.fromRGB(255, 255, 255)
            CustomKeyBox.Text = ""
            CopyBtn.Visible = true
            RefreshKeysList()
            RefreshLog()
        elseif lastErr == "exists" then
            ResultText.Text = "⚠ такой ключ уже есть!"
            ResultText.TextColor3 = Color3.fromRGB(255, 165, 0)
        elseif lastErr == "tooshort" then
            ResultText.Text = "⚠ минимум 3 символа"
            ResultText.TextColor3 = Color3.fromRGB(255, 165, 0)
        end
    end)

    CopyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            local payload = (#lastGenList > 0) and table.concat(lastGenList, "\n") or ResultText.Text
            pcall(setclipboard, payload)
            CopyBtn.Text = "✓ Скопировано!"
            task.delay(1.5, function()
                pcall(function() CopyBtn.Text = "📋 КОПИРОВАТЬ" end)
            end)
        end
    end)

    RefreshBtn.MouseButton1Click:Connect(function()
        KeySystem:CleanExpired()
        KeySystem:ReadHeartbeats()
        RefreshKeysList()
        RefreshLog()
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        -- × = просто ЗАКРЫТЬ админку: основной скрипт НЕ кипит, не вылезает.
        -- Closed=true → вайтлер сверху уйдёт в return и отпустит getgenv().SpermaHubRunning
        pcall(function()
            KeySystem.State.Closed = true
            ScreenGui:Destroy()
            print("[SpermaHub] Админ-панель закрыта (основной скрипт НЕ загружен)")
        end)
    end)

    --// rev32: ▶ явный запуск основного скрипта из админки (старое поведение ×)
    local RunBtn = Instance.new("TextButton")
    RunBtn.Size = UDim2.new(0, 96, 0, 30)
    RunBtn.Position = UDim2.new(1, -245, 0, 5)
    RunBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
    RunBtn.Text = "▶ Скрипт"
    RunBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
    RunBtn.Font = Enum.Font.GothamBold
    RunBtn.TextSize = 12
    RunBtn.BorderSizePixel = 0
    RunBtn.Parent = TitleBar
    local RunCorner = Instance.new("UICorner")
    RunCorner.CornerRadius = UDim.new(0, 6)
    RunCorner.Parent = RunBtn
    RunBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        KeySystem.State.AdminDone = true -- вайтлер сверху пойдёт и загрузит основной скрипт
    end)

    --// Init
    RefreshKeysList()
    SyncEditor()
    RefreshLog()

    return ScreenGui
end

--// Инициализация
--// 🔄 Экран «нужна новая версия» (minVersion)
function KeySystem:CreateMinVersionGUI()
    if CoreGuiSvc:FindFirstChild("SpermaKeySystem") then
        CoreGuiSvc.SpermaKeySystem:Destroy()
    end
    local sg = Instance.new("ScreenGui")
    sg.Name = "SpermaKeySystem"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.Parent = CoreGuiSvc
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 340, 0, 130)
    f.Position = UDim2.new(0.5, -170, 0.5, -65)
    f.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    f.BorderSizePixel = 0
    f.Parent = sg
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = f
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 1, -20)
    t.Position = UDim2.new(0, 10, 0, 10)
    t.BackgroundTransparency = 1
    t.Text = "🔄 Обновите скрипт!\nТребуется сборка rev" .. tostring(self.State.MinVersion) .. " или новее.\nТекущая: rev" .. tostring(BUILD_REV)
    t.TextColor3 = Color3.fromRGB(255, 180, 80)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextWrapped = true
    t.Parent = f
    return sg
end

function KeySystem:Init()
    self:LoadMeta()
    self:LoadKeys()
    self:CleanExpired()

    --// Сиды: вечные базовые ключи, чтобы вход был всегда (если база пустая)
    if not next(self.State.KeysDB) then
        self.State.KeysDB["sperma"] = { type = "Навсегда", typeIndex = 1, created = tick(), expires = math.huge, used = false, generatedBy = "seed", hwid = nil, activations = 0 }
        self.State.KeysDB["eniloveslo"] = { type = "Навсегда", typeIndex = 1, created = tick(), expires = math.huge, used = false, generatedBy = "seed", hwid = nil, activations = 0 }
        self:SaveKeys()
    end

    --// 🧹 ежесуточная автоподчистка истёкших
    local nowUnix = os.time()
    if (nowUnix - (self.State.LastAutoClean or 0)) > 86400 then
        self:CleanExpired()
        self.State.LastAutoClean = nowUnix
        self:SaveMeta()
    end

    --// 💾 авто-бэкапы базы раз в 30 минут
    task.spawn(function()
        while task.wait(1800) do
            pcall(function()
                if readfile and writefile then
                    local kd = readfile(self.Config.KeysFile)
                    if kd then writefile("sperma_keys_backup.json", kd) end
                    local md = readfile(self.Config.MetaFile)
                    if md then writefile("sperma_meta_backup.json", md) end
                end
            end)
        end
    end)

    --// 🔄 блок грузчика на старых сборках
    if self.State.MinVersion and BUILD_REV < self.State.MinVersion then
        self:CreateMinVersionGUI()
        return
    end

    self:CreateUserGUI()
end

--// Запуск
KeySystem:Init()

--// Ожидание авторизации.
-- АДМИНКА НЕ ГРУЗИТ скрипт за тебя: × и ⛔ просто закрывают панель,
-- грузить скрипт из админки — отдельная зелёная ▶ в шапке.
repeat task.wait(0.1) until
    (KeySystem.State.Authenticated and not KeySystem.State.IsAdmin
        and not KeySystem.State.IsModer and not KeySystem.State.SilentTroll)
    or KeySystem.State.AdminDone
    or KeySystem.State.Closed

if KeySystem.State.Closed then
    pcall(function() if getgenv then getgenv().SpermaHubRunning = false end end)
    warn("[SpermaHub] ЗАКРЫТ ИЗ АДМИН-ПАНЕЛИ — основной скрипт не загружен")
    return
end
if KeySystem.State.AdminDone then
    print("[SpermaHub] Admin закрыл панель — загружаю основной скрипт...")
else
    print("[SpermaHub] User authenticated with key: " .. tostring(KeySystem.State.KeyType))
end
print("[SpermaHub] Key system passed, loading main script...")



-- отметка начала загрузки (если меню не появилось — смотри, до какого принта дошло)
print("[SpermaHub] Загрузка началась...")
print("[SpermaHub] сборка: build18 rev57 (Fling v3: Skid Fling из KILASIK Multi-Fling — velocity 9e7x10+rotv 9e8, FPDH NaN, Auto Fling loop по Selected/All Lobby)")

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
BootGui = Instance.new("ScreenGui")
BootGui.Name = "SpermaHubBoot"
BootGui.ResetOnSpawn = false
BootGui.DisplayOrder = 999
BootLabel = Instance.new("TextLabel")
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
function bootStep(s)
    BootLabel.Text = "SpermaHub: " .. s
    print("[SpermaHub] " .. s)
end
bootStep("старт")
-- boot-плашка живёт максимум 15 сек: если скрипт упадёт/повиснет — она не останется "старым худом"
task.delay(15, function() pcall(function() BootGui:Destroy() end) end)

Players = game:GetService("Players")
RunService = game:GetService("RunService")
UIS = game:GetService("UserInputService")
Stats = game:GetService("Stats")
GuiService = game:GetService("GuiService")
LP = Players.LocalPlayer

-- ============ ОЧИСТКА СТАРЫХ ВЕРСИЙ ============
for _, n in ipairs({
    "SpermaHub","SpermaHubToast","SpermaHubWatermark","SpermaHubToggle",
    "SpermaHubESP","SpermaHubSettings","SpermaHubWsSettings","SpermaHubTpList",
    "SpermaHubFlingTarget","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL","SpermaHubNLToggle","SpermaHubClickGui","SpermaClick",
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

-- ДОБИВАЧКА СТАРОГО HUD: если параллельно запущена древняя копия скрипта,
-- её GUI сносим повторными волнами (в 2/5/10 сек после старта)
do
    -- whitelist: ЭТИ имена трогать нельзя (это ТЕКУЩИЙ скрипт)
    local HUD_OK = {
        SpermaKeySystem = true, SpermaWatermark = true, SpermaAdmin = true, SpermaHubToast = true, SpermaHubBoot = true, SpermaHubErrToast = true, SpermaClick = true, SpermaLinoria = true, Rayfield = true, KeyUI = true,
        SpermaHubESP = true, SpermaHubFov = true, SpermaHubFx = true, SpermaHubSpec = true,
    }
    local heirs = {}
    table.insert(heirs, LP.PlayerGui)
    pcall(function() if gethui then table.insert(heirs, gethui()) end end)
    pcall(function() table.insert(heirs, game.CoreGui) end)
    local function isOldHud(gui)
        if not gui:IsA("ScreenGui") then return false end
        local okAttr = pcall(function() return gui:GetAttribute("SpermaCurrent") == true end)
        if okAttr and gui:GetAttribute("SpermaCurrent") == true then return false end
        local n = string.lower(gui.Name)
        if n:find("windui", 1, true) then return false end
        if HUD_OK[gui.Name] then return false end
        if n:find("shitaro", 1, true) then return true end
        if n:find("sperma", 1, true) then return true end
        return false
    end
    for _, delayS in ipairs({2, 5, 10}) do
        task.delay(delayS, function()
            for _, parent in ipairs(heirs) do
                pcall(function()
                    for _, gui in ipairs(parent:GetChildren()) do
                        if isOldHud(gui) then
                            gui:Destroy()
                            print("[SpermaHub] снесён старый HUD: " .. gui.Name)
                        end
                    end
                end)
            end
        end)
    end
end
pcall(function()
    local old = workspace:FindFirstChild("SpermaAirStack")
    if old then old:Destroy() end
end)
pcall(function()
    local old = workspace:FindFirstChild("SpermaAAFake")
    if old then old:Destroy() end
end)
pcall(function()
    local old = workspace:FindFirstChild("SpermaWorldFx")
    if old then old:Destroy() end
end)
pcall(function()
    local old = workspace:FindFirstChild("SpermaBT")
    if old then old:Destroy() end
end)

-- ============ УВЕДОМЛЕНИЯ (тосты; до построения UI — в консоль) ============
toastImpl = nil
function notify(title, content)
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
S = {
    flying=false, noclip=false, esp=false, speed=50,
    targetEspOn=false, targetStyle="Pink", targetEspConn=nil, targetHudOn=false,
    wmOn=true,
    bv=nil, bg=nil, flyConn=nil, noclipConn=nil,
    fps=60, ping=0,
    walkSpeed=16, walkSpeedOn=false, wsConn=nil,
    antiRagdoll=false, arConn=nil,
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
    aaOn=false, aaConn=nil, aaPitch="Up", aaYaw="Backward", aaYawJitter="Disabled",
    aaSpinSpeed=180, aaAngle=0, aaJitSide=false, aaSlowWalk=false, aaSlowSpeed=8, aaFreestanding=false, aaPinPos=nil, aaPinDrop=0, aaHeadDepth=1, aaHipOrig=nil, aaDesync=false, aaDesyncAmt=0.35, aaDesyncPrev=nil,
    aaMode="Spin", aaSpeed=10, aaJitterAngle=180, aaDesyncOffset=0.5, aaRandomRange=360, aaVisualize=true,
    aaFakeLag=false, flHistory=nil, flCycle=0, aaOnShot=false, aaFakeDuck=false, fdT=0, aaAntiBS=false, aaResAA=false,
    bhopOn=false, bhopConn=nil, bhopMode="Hold Space", bhopMethod="Velocity",
    afOn=false, afConn=nil, afMax=150,
    strafeOn=false, strafeConn=nil, strafeSpeed=40,
    specOn=false, specConn=nil, specTarget=nil,
    bypassMode="Off", akOn=false, akOriginal=nil,
    bindsWidgetOn=true, thudOn=false,
    spiderOn=false, spiderConn=nil, spiderSpeed=30,
    airstackOn=false, airstackConn=nil, airstackPlatform=nil, airstackY=0, airstackMode="Platform", airstackFrozenCF=nil, airstackSavedWS=16, airstackSavedJP=50, airstackSavedJH=7.2,
    invisOn=false, invisConn=nil, invisOffset=58, invisY=0,
    noKbOn=false, noKbConn=nil, noKbMax=45, noKbLast=nil, noKbFull=false,
    silentMode="Universal",
    flingMode="Skid Fling", flingDur=5, skidDur=2, flingScope="Selected", flingSelName=nil,
    autoFlingOn=false, flingCycleDelay=0.5, skidOldPos=nil, skidFPDH=nil,
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
    -- local/world pack
    infJumpOn=false, wallhopOn=false,
    customFovOn=false, customFov=70,
    aspectOn=false, aspectVal=100,
    chinaHatOn=false, chinaHatColor=Color3.new(0.67, 0.33, 1),
    backtrackOn=false, backtrackColor=Color3.fromRGB(255, 60, 60),
    selfChamsOn=false, selfChamsColor=Color3.fromRGB(0, 200, 255), selfChamsType="ForceField",
    landingOn=false, landingColor=Color3.fromRGB(255, 255, 255), landingDur=0.82, landingTransp=1,
    toolChamsOn=false, toolChamsType="ForceField",
    graphOn=false, graphFps=60,
    fakePosOn=false, fakePosVis=false, fakeDist=200, fakeUp=0,
    veloSpoofOn=false, veloMode="rotate", veloPow=8,
    jumpPowerOn=false, jumpPower=50,
    pixelSurfOn=false,
    antiVoidOn=false, antiAfkOn=false,
    auraOn=false, auraType="neverlose",
    deathFxOn=false, deathFxType="Emitter",
}

-- =====================================================================
-- GUI: SpermaClick — ЕДИНСТВЕННЫЙ движок меню (FULL SKID 1:1 референс).
-- rev52: Rayfield (113 KB) и Linoria удалены ЦЕЛИКОМ — ни одного остатка.
-- Рендер из реестра MODULES — в конце файла, раздел SPERMACLICK.
-- =====================================================================
-- boot-движки Rayfield/Linoria удалены (rev52). SpermaClick собирается из MODULES в конце файла.
-- RightShift-хендлер живёт в разделе SPERMACLICK (S.rsToggleConn там же).


-- ============================================================
-- ============ ЛОГИКА (перенесена из sperma.lua) =============
-- ============================================================

-- ============ TEAM CHECK / VISIBLE CHECK ============
function isTeammate(plr)
    if not S.teamCheck then return false end
    if not plr or plr == LP then return false end
    if not plr.Team or not LP.Team then return false end
    return plr.Team == LP.Team
end

visCheckParams = RaycastParams.new()
visCheckParams.FilterType = Enum.RaycastFilterType.Exclude

-- true, если от камеры до части нет препятствий (wallcheck)
function isVisible(part)
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
FovGui = Instance.new("ScreenGui")
FovGui.Name = "SpermaHubFov"
FovGui.ResetOnSpawn = false
FovGui.IgnoreGuiInset = true
FovGui.DisplayOrder = 60
FovGui.Parent = LP:WaitForChild("PlayerGui")

FovCircle = Instance.new("Frame")
FovCircle.Name = "FovCircle"
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.new(0, 240, 0, 240)
FovCircle.BackgroundTransparency = 1
FovCircle.BorderSizePixel = 0
FovCircle.Visible = false
FovCircle.ZIndex = 100
FovCircle.Parent = FovGui

FovCircleCorner = Instance.new("UICorner")
FovCircleCorner.CornerRadius = UDim.new(1, 0)
FovCircleCorner.Parent = FovCircle

FovCircleStroke = Instance.new("UIStroke")
FovCircleStroke.Color = Color3.fromRGB(255, 80, 80)
FovCircleStroke.Thickness = 2
FovCircleStroke.Transparency = 0.2
FovCircleStroke.Parent = FovCircle

S.fovCircle = FovCircle

-- FOV-круг для Silent Aim
SilentFovCircle = Instance.new("Frame")
SilentFovCircle.Name = "SilentFovCircle"
SilentFovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
SilentFovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
SilentFovCircle.Size = UDim2.new(0, 300, 0, 300)
SilentFovCircle.BackgroundTransparency = 1
SilentFovCircle.BorderSizePixel = 0
SilentFovCircle.Visible = false
SilentFovCircle.ZIndex = 99
SilentFovCircle.Parent = FovGui

SilentFovCircleCorner = Instance.new("UICorner")
SilentFovCircleCorner.CornerRadius = UDim.new(1, 0)
SilentFovCircleCorner.Parent = SilentFovCircle

SilentFovCircleStroke = Instance.new("UIStroke")
SilentFovCircleStroke.Color = Color3.fromRGB(100, 100, 255)
SilentFovCircleStroke.Thickness = 2
SilentFovCircleStroke.Transparency = 0.2
SilentFovCircleStroke.Parent = SilentFovCircle

S.silentAimFovCircle = SilentFovCircle

function updateFovCircle()
    if S.fovCircle then
        local size = S.aimbotFov * 2
        S.fovCircle.Size = UDim2.new(0, size, 0, size)
        S.fovCircle.Visible = S.aimbotOn and S.fovVisualize
    end
end

function updateSilentFovCircle()
    if S.silentAimFovCircle then
        local size = S.silentAimFov * 2
        S.silentAimFovCircle.Size = UDim2.new(0, size, 0, size)
        S.silentAimFovCircle.Visible = S.silentAimOn and S.fovVisualize
    end
end

-- Временный показ круга при настройке FOV слайдером (аналог открытой панели)
fovFlash = {aimbot = 0, silent = 0}
function flashFovCircle(kind, circle, isOn)
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
function aimBonePart(ch)
    if S.aimBone == "Torso" then
        return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
            or ch:FindFirstChild("HumanoidRootPart")
    elseif S.aimBone == "Body" then
        return ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso")
            or ch:FindFirstChild("HumanoidRootPart")
    end
    return ch:FindFirstChild("Head")
end

function getClosestTarget()
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

function aimKeyPressed()
    if S.aimKey == "Always" then return true end
    if S.aimKey == "Hold E" then
        return UIS:IsKeyDown(Enum.KeyCode.E)
    end
    -- Hold RMB по умолчанию
    return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

function enableAimbot()
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

function disableAimbot()
    S.aimbotOn = false
    if S.aimbotConn then
        RunService:UnbindFromRenderStep("SpermaHubAimbot")
        S.aimbotConn = nil
    end
end

-- ============ SILENT AIM ЛОГИКА (Real-compatible) ============
function findSilentTarget()
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

function checkSilentAimSupport()
    local hasHook, hasMeta, hasSetReadonly, hasNewcclosure = false, false, false, false
    pcall(function() hasHook = type(hookfunction) == "function" end)
    pcall(function() hasMeta = type(getrawmetatable) == "function" end)
    pcall(function() hasSetReadonly = type(setreadonly) == "function" end)
    pcall(function() hasNewcclosure = type(newcclosure) == "function" end)
    return hasHook and hasMeta and hasSetReadonly and hasNewcclosure
end

-- ============ SILENT AIM — режимы Universal / Fortline / Network ============
-- код сервисов как в Fortline-сниппете (cloneref-защита), с фолбэком без cloneref
function makeSilentServices()
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
function enableSilentFortline()
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
function enableSilentNetwork()
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

function enableSilentAim()
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

function disableSilentAim()
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
function vimClick(b) -- b: 0 = ЛКМ, 1 = ПКМ
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local loc = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(loc.X, loc.Y, b, true, false, 1)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(loc.X, loc.Y, b, false, false, 1)
    end)
end

-- button: 1 = ЛКМ, 2 = ПКМ
function clickMouse(button)
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
hudIgnore = {
    SpermaHubESP=true, SpermaHubHUD=true, SpermaHubFov=true, SpermaHubWatermark=true, SpermaHubBinds=true, SpermaHubTHud=true, -- декоративные элементы скрипта не считаем
}
function canClickInGame()
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

function enableAutoClicker()
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

function disableAutoClicker()
    S.autoClickOn = false
    S.autoClickGen = S.autoClickGen + 1
end

-- ============ HITBOX EXPANDER ЛОГИКА ============
hitboxOriginalSizes = {}

function applyHitbox()
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

function restoreHitbox()
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

function enableHitbox()
    S.hitboxOn = true
    applyHitbox()
    dcc(S.hitboxConn)
    S.hitboxConn = RunService.Heartbeat:Connect(function()
        if not S.hitboxOn then return end
        applyHitbox()
    end)
end

function disableHitbox()
    S.hitboxOn = false
    if S.hitboxConn then S.hitboxConn:Disconnect() S.hitboxConn = nil end
    restoreHitbox()
end

-- ============ KILL PLAYER ЛОГИКА ============
function killPlayer(targetPlayer)
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
function tpToPlayer(targetPlayer)
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
function startFly()
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

function stopFly()
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
function enableNoclip()
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

function disableNoclip()
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
function enableClickTp()
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

function disableClickTp()
    S.clickTpOn = false
    if S.clickTpConn then S.clickTpConn:Disconnect() S.clickTpConn = nil end
end

-- ============ JESUS (ходьба по воде) ============
jesusRayParams = RaycastParams.new()
jesusRayParams.FilterType = Enum.RaycastFilterType.Exclude
jesusRayParams.IgnoreWater = false -- чтобы рейкаст "видел" поверхность воды

function enableJesus()
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

function disableJesus()
    S.jesusOn = false
    if S.jesusConn then S.jesusConn:Disconnect() S.jesusConn = nil end
    if S.jesusPlatform then S.jesusPlatform.Position = Vector3.new(0, -1e5, 0) end
end

-- ============ SPIN (вращение персонажа) ============
function enableSpin()
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

function disableSpin()
    S.spinOn = false
    if S.spinConn then S.spinConn:Disconnect() S.spinConn = nil end
    -- спина выпрямляется обратно
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = false end) end
end

-- ============ GOD MODE (лок HP) ============
function enableGod()
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

function disableGod()
    S.godOn = false
    if S.godConn then S.godConn:Disconnect() S.godConn = nil end
end

-- ============ FLING ============
function flingPlayer(target)
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
function flingStickyPlayer(target, dur)
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

-- ============ SKID FLING (rev57: port zqyDSUWX / KILASIK Multi-Fling 1:1) ============
-- Техника: впечатываемся в цель 2с — Velocity 9e7 (вертикаль x10), RotVelocity 9e8,
-- сверху/снизу с нарастающим Angle, предикт по MoveDirection; FPDH=NaN (иммунитет к падению
-- под карту), BodyVelocity-фиксация, Seated off; финал — возврат на старую точку склейкой.
function skidFling(target, respectAuto)
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    local tChar = target and target.Character
    if not (root and tChar) then return false, "нет своего/чужого персонажа" end
    local tHum = tChar:FindFirstChildOfClass("Humanoid")
    local tRoot = tHum and tHum.RootPart
    local tHead = tChar:FindFirstChild("Head")
    local acc = tChar:FindFirstChildOfClass("Accessory")
    local handle = acc and acc:FindFirstChild("Handle")
    if tHum and tHum.Sit then return false, "цель сидит" end
    if not tChar:FindFirstChildWhichIsA("BasePart") then return false, "у цели нет пар-тов" end
    if root.Velocity.Magnitude < 50 then
        S.skidOldPos = root.CFrame -- аналог getgenv().OldPos
    end
    local cam = workspace.CurrentCamera
    local prevSubject = cam and cam.CameraSubject
    if tHead then
        cam.CameraSubject = tHead
    elseif handle then
        cam.CameraSubject = handle
    elseif tHum and tRoot then
        cam.CameraSubject = tHum
    end
    local BasePart = tRoot or tHead or handle
    if not BasePart then return false, "нет части для домашки" end

    local function FPos(part, pos, ang)
        root.CFrame = CFrame.new(part.Position) * pos * ang
        pcall(function() ch:SetPrimaryPartCFrame(CFrame.new(part.Position) * pos * ang) end)
        root.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    S.skidFPDH = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0 -- NaN: падение под мир не убивает
    S.skidActive = true -- чтобы свой Anti Fling не резал наш Velocity 9e7
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)

    local TimeToWait = tonumber(S.skidDur) or 2
    local t0 = tick()
    local Angle = 0
    repeat
        if not (root.Parent and tHum and tHum.Parent and hum.Parent) then break end
        if BasePart.Velocity.Magnitude < 50 then
            Angle = Angle + 100
            local md = tHum.MoveDirection
            local pred = md * BasePart.Velocity.Magnitude / 1.25
            FPos(BasePart, CFrame.new(0, 1.5, 0) + pred, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0) + pred, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, 1.5, 0) + pred, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0) + pred, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, 1.5, 0) + md, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0) + md, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
        else
            local ws = tHum.WalkSpeed or 16
            FPos(BasePart, CFrame.new(0, 1.5, ws), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, -ws), CFrame.Angles(0, 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, 1.5, ws), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)) task.wait()
        end
    until t0 + TimeToWait < tick() or (respectAuto and not S.autoFlingOn)

    pcall(function() bv:Destroy() end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
    if cam then cam.CameraSubject = prevSubject or hum end
    pcall(function()
        workspace.FallenPartsDestroyHeight = S.skidFPDH or -500
    end)
    -- сброс: возврат на старую точку, как в оригинале
    local old = S.skidOldPos
    if old and root.Parent then
        local n = 0
        repeat
            if not root.Parent then break end
            root.CFrame = old * CFrame.new(0, 0.5, 0)
            pcall(function() ch:SetPrimaryPartCFrame(old * CFrame.new(0, 0.5, 0)) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            for _, part in pairs(ch:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
            task.wait()
            n = n + 1
        until not root.Parent or (root.Position - old.p).Magnitude < 25 or n > 60
    end
    S.skidActive = false
    return true
end

-- авто-цикл по выбранным/всем — START FLING / STOP FLING = тогл (как у Kilasik)
function setAutoFling(b)
    S.autoFlingOn = b and true or false
    if not S.autoFlingOn then return end
    task.spawn(function()
        while S.autoFlingOn do
            local targets = {}
            if S.flingScope == "All Lobby" then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LP then table.insert(targets, plr) end
                end
            else
                local plr = S.flingSelName and Players:FindFirstChild(S.flingSelName)
                if plr then table.insert(targets, plr) end
            end
            if #targets == 0 then
                toastImpl("Fling", "Нет целей: выбери игрока в списке или Scope = All Lobby")
                S.autoFlingOn = false
                local c = Cfg["fling.auto"] if c then c.set(false) end
                break
            end
            for _, plr in ipairs(targets) do
                if not S.autoFlingOn then break end
                if plr and plr.Parent then
                    pcall(skidFling, plr, true)
                end
                if not S.autoFlingOn then break end
                task.wait(0.1)
            end
            if not S.autoFlingOn then break end
            task.wait(tonumber(S.flingCycleDelay) or 0.5)
        end
    end)
end

-- ============ BULLET TRACERS + HITMARKER ============
HM_SOUND_ID = nil -- сюда можно вписать id звука хитмаркера, напр. "rbxassetid://1234567890"

FxGui = Instance.new("ScreenGui")
FxGui.Name = "SpermaHubFx"
FxGui.ResetOnSpawn = false
FxGui.IgnoreGuiInset = true
FxGui.DisplayOrder = 102
FxGui.Parent = LP:WaitForChild("PlayerGui")

function drawTracer(from3D, to3D)
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

function showHitmarker()
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

function onShotTracer()
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

function onShotHitmarker()
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
-- ============ ANTI-AIM (ENI Suite: Spin / Jitter / Desync / Random + Fake Visualize) ============
aaState = {CurrentAngle = 0, LastTick = tick(), FakeCharacter = nil}

function aaGetRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

function aaCreateFake()
    if aaState.FakeCharacter then
        pcall(function() aaState.FakeCharacter:Destroy() end)
        aaState.FakeCharacter = nil
    end
    if not S.aaVisualize then return end
    local char = LP.Character
    if not char then return end
    local fake = Instance.new("Model")
    fake.Name = "SpermaAAFake"
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            local okc, clone = pcall(function() return v:Clone() end)
            if okc and clone then
                clone.CanCollide = false
                clone.Anchored = true
                clone.Transparency = 0.7
                pcall(function() clone.CanTouch = false clone.CanQuery = false end)
                clone.Parent = fake
            end
        end
    end
    fake.Parent = workspace
    aaState.FakeCharacter = fake
end

function aaDestroyFake()
    if aaState.FakeCharacter then
        pcall(function() aaState.FakeCharacter:Destroy() end)
        aaState.FakeCharacter = nil
    end
end

-- фейковое тело показывает, куда "смотрит" подменённый рут
function aaUpdateFake(angle)
    if not S.aaVisualize then return end
    local fake = aaState.FakeCharacter
    if not fake or not fake.Parent then return end
    local ch = LP.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local rot = CFrame.Angles(0, math.rad(angle), 0)
    local offset = root.CFrame * rot
    for _, v in pairs(fake:GetChildren()) do
        if v:IsA("BasePart") then
            local realPart = ch:FindFirstChild(v.Name)
            if realPart and realPart:IsA("BasePart") then
                pcall(function()
                    v.CFrame = offset * (root.CFrame:Inverse() * realPart.CFrame)
                end)
            end
        end
    end
end

function enableAntiAim()
    S.aaOn = true
    dcc(S.aaConn)
    aaState.LastTick = tick()
    if S.aaVisualize then aaCreateFake() end
    S.aaConn = RunService.Heartbeat:Connect(function()
        if not S.aaOn then return end
        local root = aaGetRoot()
        if not root then return end
        local now = tick()
        local dt = now - aaState.LastTick
        aaState.LastTick = now

        -- контроллер движения сам перезаписывает yaw → отрубаем AutoRotate
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                if S.aaOrigAutoRotate == nil then S.aaOrigAutoRotate = hum.AutoRotate end
                if hum.AutoRotate then hum.AutoRotate = false end
            end)
        end

        local mode = S.aaMode
        if mode == "Spin" then
            aaState.CurrentAngle = (aaState.CurrentAngle + S.aaSpeed * dt * 10) % 360
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(S.aaSpeed * dt * 10), 0)
        elseif mode == "Jitter" then
            aaState.CurrentAngle = aaState.CurrentAngle == 0 and S.aaJitterAngle or 0
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(aaState.CurrentAngle), 0)
        elseif mode == "Desync" then
            -- синусовый сдвиг ±2 стада (без накопления — через текущий root.CFrame)
            local offset = math.sin(now * S.aaDesyncOffset * 10) * 2
            root.CFrame = root.CFrame + Vector3.new(offset, 0, 0)
        else -- "Random"
            local range = math.max(tonumber(S.aaRandomRange) or 360, 1)
            aaState.CurrentAngle = math.random(-range / 2, range / 2)
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(aaState.CurrentAngle), 0)
        end

        -- Pitch manipulation
        local pitch = S.aaPitch
        if pitch == "Up" then
            root.CFrame = root.CFrame * CFrame.Angles(math.rad(-89), 0, 0)
        elseif pitch == "Down" then
            root.CFrame = root.CFrame * CFrame.Angles(math.rad(89), 0, 0)
        elseif pitch == "Random" then
            local r = math.random()
            if r < 1 / 3 then
                root.CFrame = root.CFrame * CFrame.Angles(math.rad(-89), 0, 0)
            elseif r < 2 / 3 then
                root.CFrame = root.CFrame * CFrame.Angles(math.rad(89), 0, 0)
            end
        end -- "Zero"/"None": не трогаем ориентацию по X

        aaUpdateFake(aaState.CurrentAngle)
    end)
end

function disableAntiAim()
    S.aaOn = false
    dcc(S.aaConn)
    S.aaConn = nil
    aaDestroyFake()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum and S.aaOrigAutoRotate ~= nil then
        pcall(function() hum.AutoRotate = S.aaOrigAutoRotate end)
        S.aaOrigAutoRotate = nil
    end
end

-- пересоздание фейка при респавне
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if S.aaOn and S.aaVisualize then aaCreateFake() end
end)

-- ============ BHOP (авто-прыжки) ============
function enableBhop()
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

function disableBhop()
    S.bhopOn = false
    if S.bhopConn then S.bhopConn:Disconnect() S.bhopConn = nil end
end

-- ============ ANTI FLING (защита от флинга) ============
function enableAntiFling()
    S.afOn = true
    dcc(S.afConn)
    S.afConn = RunService.Stepped:Connect(function()
        if not S.afOn then return end
        if S.flying then return end -- Fly сам управляет скоростью
        if S.flingConn then return end -- свой флинг не трогаем
        if S.skidActive then return end  -- свой skid-флинг тоже не трогаем
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

function disableAntiFling()
    S.afOn = false
    if S.afConn then S.afConn:Disconnect() S.afConn = nil end
end

-- ============ AUTO STRAFE (усиление bhop) ============
function enableStrafe()
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

function disableStrafe()
    S.strafeOn = false
    if S.strafeConn then S.strafeConn:Disconnect() S.strafeConn = nil end
end

-- ============ SPECTATE (с мини-окном) ============
SpecGui = Instance.new("ScreenGui")
SpecGui.Name = "SpermaHubSpec"
SpecGui.ResetOnSpawn = false
SpecGui.IgnoreGuiInset = true
SpecGui.DisplayOrder = 90
SpecGui.Parent = LP:WaitForChild("PlayerGui")

SpecWin = Instance.new("Frame")
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

SpecTitle = Instance.new("TextLabel")
SpecTitle.Size = UDim2.new(1, -70, 0, 26)
SpecTitle.Position = UDim2.new(0, 10, 0, 4)
SpecTitle.BackgroundTransparency = 1
SpecTitle.Text = "👁 Spectate"
SpecTitle.TextColor3 = Color3.fromRGB(200, 160, 255)
SpecTitle.Font = Enum.Font.GothamBold
SpecTitle.TextSize = 13
SpecTitle.TextXAlignment = Enum.TextXAlignment.Left
SpecTitle.Parent = SpecWin

SpecExit = Instance.new("TextButton")
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

SpecInfo = Instance.new("TextLabel")
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

function exitSpectate()
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

function startSpectate(plr)
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
AC_PATTERNS = {
    "adonis", "anticheat", "anti-cheat", "anti cheat", "antihack", "anti-hack",
    "anticheatclient", "exploitdetector", "cheatdetector", "watchdog", "banhammer",
}

function neuterAntiCheatScripts(dryRun)
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

function acHooksSupported()
    return type(getrawmetatable) == "function"
        and type(newcclosure) == "function"
        and type(setreadonly) == "function"
        and type(getnamecallmethod) == "function"
end

-- Anti Kick: перехват Namecall Kick (если экзекьютор умеет хуки)
function enableAntiKick()
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

function disableAntiKick()
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

function applyBypassMode(mode)
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

TeleportService = game:GetService("TeleportService")

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

-- ============ AIRSTACK (ходьба по воздуху на платформе / заморозка в маленьком кубе) ============
function enableAirStack()
    S.airstackOn = true
    local ch = LP.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local freeze = (S.airstackMode == "Freeze")
    -- высота платформы фиксируется в момент включения
    S.airstackY = root and (root.Position.Y - 3.2) or 60
    S.airstackFrozenCF = (freeze and root) and root.CFrame or nil
    if freeze and hum then
        -- сохранить скорости и ЗАМОРОЗИТЬ: персонаж не может ступить/прыгнуть вообще
        S.airstackSavedWS = hum.WalkSpeed
        S.airstackSavedJP = hum.JumpPower
        S.airstackSavedJH = hum.JumpHeight
        pcall(function()
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum.PlatformStand = false
        end)
    end
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
    S.airstackPlatform.Size = freeze and Vector3.new(3, 1, 3) or Vector3.new(12, 1, 12)
    dcc(S.airstackConn)
    S.airstackConn = RunService.Heartbeat:Connect(function()
        if not S.airstackOn then return end
        local ch2 = LP.Character
        if not ch2 then return end
        local root2 = ch2:FindFirstChild("HumanoidRootPart")
        local plat = S.airstackPlatform
        if not root2 or not plat then return end
        if S.airstackMode == "Freeze" and S.airstackFrozenCF then
            -- ПОЛНАЯ заморозка: нет ни шага, ни прыжка, ни дрейфа, ни кручения
            pcall(function()
                local hum2 = ch2:FindFirstChildOfClass("Humanoid")
                if hum2 then
                    if hum2.WalkSpeed ~= 0 then hum2.WalkSpeed = 0 end
                    if hum2.JumpPower ~= 0 then hum2.JumpPower = 0 end
                    if hum2.JumpHeight ~= 0 then hum2.JumpHeight = 0 end
                    local st = hum2:GetState()
                    if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
                        hum2:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
                root2.CFrame = S.airstackFrozenCF
                root2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root2.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                plat.CFrame = S.airstackFrozenCF * CFrame.new(0, -3.27, 0)
            end)
        else
            -- платформа следует за игроком по X/Z на зафиксированной высоте
            plat.Position = Vector3.new(root2.Position.X,
                (S.airstackY or 60) - plat.Size.Y / 2 + 0.05,
                root2.Position.Z)
        end
    end)
end

function disableAirStack()
    S.airstackOn = false
    S.airstackFrozenCF = nil
    -- вернуть персонажу движение
    pcall(function()
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = S.airstackSavedWS or 16
            hum.JumpPower = S.airstackSavedJP or 50
            hum.JumpHeight = S.airstackSavedJH or 7.2
        end
    end)
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

-- ============ WALK SPEED (CFrame-доводка, античит не флагит WalkSpeed) ============
function applyWalkSpeed()
    local ch = LP.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
    end
end

S.wsConn = RunService.Heartbeat:Connect(function(dt)
    if not S.walkSpeedOn then return end
    local ch = LP.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end
    local md = hum.MoveDirection
    if md.Magnitude < 0.01 then return end
    local extra = (S.walkSpeed or 16) - 16
    if extra <= 0 then return end
    pcall(function()
        local step = md * (extra * dt)
        root.CFrame = root.CFrame + Vector3.new(step.X, 0, step.Z)
    end)
end)

-- ============ ANTI RAGDOLL (не падаешь, двигаешься) ============
AR_STATES = {
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.Physics] = true,
}
S.arConn = RunService.Heartbeat:Connect(function()
    if not S.antiRagdoll then return end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local st = hum:GetState()
    if AR_STATES[st] then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
end)

bootStep("логика OK")

-- ============ ESP ============
ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "SpermaHubESP"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 50
ESPGui.Parent = LP:WaitForChild("PlayerGui")

-- rev51 FULL SKID: старый ESP (Chams / Skeleton / Gui-box / hitbox-метки) УДАЛЁН ЦЕЛИКОМ.
-- Единственный ESP — Drawing-движок 1:1 со скрина (раздел ESP MAX ниже, GUI: Visuals > Players).
-- Здесь остался только Target ESP (подсветка цели аимбота) — стили его пульсации:
TARGET_STYLES = {
    Pink   = {fill = Color3.fromRGB(255, 0, 200),  outline = Color3.fromRGB(255, 120, 240)},
    Purple = {fill = Color3.fromRGB(170, 0, 255),  outline = Color3.fromRGB(225, 110, 255)},
    Red    = {fill = Color3.fromRGB(255, 40, 40),  outline = Color3.fromRGB(255, 150, 80)},
    Gold   = {fill = Color3.fromRGB(255, 190, 40), outline = Color3.fromRGB(255, 240, 160)},
}

function isAlive(plr)
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return ch:FindFirstChild("HumanoidRootPart") ~= nil
end

-- ============ TARGET ESP (подсветка текущей цели) ============
TargetHL = Instance.new("Highlight")
TargetHL.FillTransparency = 0.35
TargetHL.OutlineTransparency = 0
TargetHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
TargetHL.Enabled = false
TargetHL.Parent = ESPGui

function currentEspTarget()
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

function enableTargetESP()
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

function disableTargetESP()
    S.targetEspOn = false
    if S.targetEspConn then S.targetEspConn:Disconnect() S.targetEspConn = nil end
    TargetHL.Enabled = false
    TargetHL.Adornee = nil
end

-- ============ TARGET HUD (FULL SKID с фото: красная скруглённая плашка) ============
-- красный box + НИК белым + "HP: x.x" + зелёный скруглённый HP-бар; висит над головой цели
TgtHUD = {conn = nil, gui = nil, nameLbl = nil, hpLbl = nil, barFill = nil, lastP = nil}

function thudBuildGui()
    if TgtHUD.gui then return end
    local gui = Instance.new("BillboardGui")
    gui.Name = "SpermaTargetHUD"
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(170, 62)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
    gui.MaxDistance = 1e9
    gui.LightInfluence = 0

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundColor3 = Color3.fromRGB(198, 37, 60)   -- крямсона с фото
    box.BackgroundTransparency = 0.04
    box.BorderSizePixel = 0
    box.Size = UDim2.new(1, 0, 1, 0)
    box.Parent = gui
    local cr = Instance.new("UICorner")
    cr.CornerRadius = UDim.new(0, 7)
    cr.Parent = box
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(110, 16, 30)
    st.Transparency = 0.55
    st.Thickness = 1
    st.Parent = box

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.new(0, 8, 0, 3)
    nameLbl.Size = UDim2.new(1, -16, 0, 19)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 15
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextStrokeTransparency = 0.55
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Text = "?"
    nameLbl.Parent = box

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Name = "HPText"
    hpLbl.BackgroundTransparency = 1
    hpLbl.Position = UDim2.new(0, 8, 0, 23)
    hpLbl.Size = UDim2.new(1, -16, 0, 15)
    hpLbl.Font = Enum.Font.GothamBold
    hpLbl.TextSize = 13
    hpLbl.TextColor3 = Color3.new(1, 1, 1)
    hpLbl.TextXAlignment = Enum.TextXAlignment.Left
    hpLbl.TextStrokeTransparency = 0.55
    hpLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    hpLbl.Text = "HP: 0"
    hpLbl.Parent = box

    -- трек бара: тёмно-красная вставка со скруглением (как на фото)
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.BackgroundColor3 = Color3.fromRGB(120, 18, 32)
    barBg.BackgroundTransparency = 0.15
    barBg.BorderSizePixel = 0
    barBg.Position = UDim2.new(0, 8, 0, 43)
    barBg.Size = UDim2.new(1, -16, 0, 12)
    barBg.Parent = box
    local cr2 = Instance.new("UICorner")
    cr2.CornerRadius = UDim.new(0, 6)
    cr2.Parent = barBg

    -- зелёная заливка HP (лаймовая с фото)
    local barFill = Instance.new("Frame")
    barFill.Name = "Fill"
    barFill.BackgroundColor3 = Color3.fromRGB(58, 215, 78)
    barFill.BorderSizePixel = 0
    barFill.Position = UDim2.new(0, 2, 0, 2)
    barFill.Size = UDim2.new(1, -4, 1, -4)
    barFill.Parent = barBg
    local cr3 = Instance.new("UICorner")
    cr3.CornerRadius = UDim.new(0, 5)
    cr3.Parent = barFill

    gui.Parent = ESPGui
    TgtHUD.gui = gui
    TgtHUD.nameLbl = nameLbl
    TgtHUD.hpLbl = hpLbl
    TgtHUD.barFill = barFill
    gui.Enabled = false
end

function thudUpdate(p)
    local ch = p and p.Character
    local head = ch and ch:FindFirstChild("Head")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (head and hum and hum.Health > 0) then return false end
    thudBuildGui()
    if TgtHUD.lastP ~= p or TgtHUD.gui.Adornee ~= head then
        TgtHUD.gui.Adornee = head
        TgtHUD.lastP = p
        TgtHUD.nameLbl.Text = tostring(p.Name)
    end
    local hp = math.max(hum.Health, 0)
    local mhp = math.max(hum.MaxHealth, 1)
    TgtHUD.hpLbl.Text = ("HP: %.1f"):format(hp)
    TgtHUD.barFill.Size = UDim2.new(math.clamp(hp / mhp, 0, 1), -4, 1, -4)
    return true
end

function enableTargetHUD()
    S.targetHudOn = true
    thudBuildGui()
    dcc(TgtHUD.conn)
    TgtHUD.conn = RunService.RenderStepped:Connect(function()
        if not S.targetHudOn then return end
        local p = nil
        pcall(function() p = currentEspTarget() end)
        local ok = false
        if p and p ~= LP and not isTeammate(p) then
            ok = thudUpdate(p)
        end
        if TgtHUD.gui then
            TgtHUD.gui.Enabled = ok
            if not ok then
                TgtHUD.gui.Adornee = nil
                TgtHUD.lastP = nil
            end
        end
    end)
end

function disableTargetHUD()
    S.targetHudOn = false
    dcc(TgtHUD.conn)
    TgtHUD.conn = nil
    if TgtHUD.gui then
        TgtHUD.gui.Enabled = false
        TgtHUD.gui.Adornee = nil
    end
    TgtHUD.lastP = nil
end

bootStep("ESP OK")

bootStep("Watermark OK")

TweenService = game:GetService("TweenService")
HttpService = game:GetService("HttpService")

-- ============================================================
-- ============ GUI MODE: SpermaClick (единственный движок, 1:1 skid) ========
-- ============================================================
-- ---------- ТЕМА (как на референсе) ----------
CT = {
    panel   = Color3.fromRGB(16, 16, 28),
    header  = Color3.fromRGB(22, 22, 38),
    row     = Color3.fromRGB(26, 27, 44),
    rowOn   = Color3.fromRGB(58, 59, 102),
    accent  = Color3.fromRGB(132, 132, 235),
    text    = Color3.fromRGB(235, 235, 250),
    dim     = Color3.fromRGB(150, 150, 180),
    line    = Color3.fromRGB(40, 40, 66),
}

-- ---------- ХЕЛПЕРЫ ----------
-- убрать 4-байтовые UTF-8 символы (эмодзи) — в шрифтах их нет
function cleanText(s)
    return (tostring(s):gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", ""))
end

function cgNew(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do pcall(function() obj[k] = v end) end
    obj.Parent = parent
    return obj
end
function cgCorner(r, parent)
    cgNew("UICorner", {CornerRadius = UDim.new(0, r or 4)}, parent)
end
function listLayout(parent, pad, order)
    local l = cgNew("UIListLayout", {
        Padding = UDim.new(0, pad or 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
    return l
end

-- ---------- ТОСТЫ (свои, без сторонних либ) ----------
ToastHolder = nil
do
    local sg = cgNew("ScreenGui", {
        Name = "SpermaHubToast",
        ResetOnSpawn = false,
        DisplayOrder = 998,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, LP:WaitForChild("PlayerGui"))
    ToastHolder = cgNew("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 250, 1, -24),
    }, sg)
    local lay = listLayout(ToastHolder, 6, true)
    lay.VerticalAlignment = Enum.VerticalAlignment.Top
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
end

function cgToastDismiss(frame)
    task.delay(2.6, function()
        pcall(function()
            TweenService:Create(frame, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
            frame.TextTransparency = 1
        end)
        task.wait(0.3)
        pcall(function() frame:Destroy() end)
    end)
end

toastImpl = function(title, msg)
    local t, text = tostring(title or ""), tostring(msg or "")
    local full = (t ~= "" and (text ~= "" and (t .. "  —  " .. text) or t) or text)
    if full == "" then return end
    pcall(function()
        -- потолок 6 тостов, самые старые выкидываем
        local kids = ToastHolder:GetChildren()
        local count = 0
        for _, k in ipairs(kids) do if k:IsA("TextLabel") then count = count + 1 end end
        if count >= 6 then
            for _, k in ipairs(kids) do
                if k:IsA("TextLabel") then k:Destroy() break end
            end
        end
        local lbl = cgNew("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = CT.panel,
            BackgroundTransparency = 0.06,
            BorderSizePixel = 0,
            Text = cleanText(full),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextColor3 = CT.text,
            Font = Enum.Font.Gotham,
            TextSize = 11.5,
            TextTransparency = 0,
        }, ToastHolder)
        cgCorner(6, lbl)
        cgNew("UIPadding", {
            PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
            PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9),
        }, lbl)
        lbl.BackgroundTransparency = 1
        TweenService:Create(lbl, TweenInfo.new(0.2), {BackgroundTransparency = 0.06}):Play()
        cgToastDismiss(lbl)
    end)
    print(("[SpermaHub] %s"):format(full))
end

-- ---------- РЕЕСТР ------
Categories = {}
Pages = {}
CatSelected = nil
Cfg = {}

-- ---------- КОРЕНЬ GUI ----------
-- Voidware/WindUI/Rayfield/Linoria УДАЛЕНЫ НАСОВСЕМ (rev52: SpermaClick — единственная оболочка)
CGGui = nil     -- SpermaClick ScreenGui (создаётся в SPERMACLICK-рендере)
CG_OPEN = false -- меню сейчас открыто?
rootF = nil     -- корень окна (compat: Library.UI.MainUI)

MODULES = {} -- все модули

-- ---------- КАТЕГОРИЯ → панель ----------
CAT_ORDER = { Combat=1, Movement=2, Visuals=3, Player=4, Server=5, Miscellaneous=6 }
curModule = nil

function addCategoryImpl(title)
    return {key = title, scroll = nil} -- категории-колонки рисует SpermaClick
end

function updModHeader(m) end

function addPageImpl(cat, icon, title)
    local catEntry = nil
    for _, c in ipairs(Categories) do if c.key == cat then catEntry = c break end end
    if not catEntry then addCategoryImpl(cat) for _, c in ipairs(Categories) do if c.key == cat then catEntry = c break end end end
    local m = {
        cat = cat, title = tostring(title), elements = {},
        enableKey = nil, bodyBuilt = true, open = false,
    }
    table.insert(Pages, m)
    table.insert(MODULES, m)
    curModule = m
    return {__module = m, col1 = {__module = m}, col2 = {__module = m}}
end

function addPanelImpl(col, title)
    local sec = {title = cleanText(title), module = col.__module, __module = col.__module}
    table.insert(col.__module.elements, {kind = "section", title = sec.title})
    return sec
end

function selectCategory(_) end
function selectPage(_) end

-- ---------- ЭЛЕМЕНТЫ (capture; рисуем лениво) ----------
keyCaptureEl = nil
-- список игроков — capture; рендерится при открытии настроек модуля
function getPlayerListData()
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

-- keybind capture listener
UIS.InputBegan:Connect(function(inp)
    if not keyCaptureEl then return end
    if inp.KeyCode == Enum.KeyCode.Escape then
        keyCaptureEl._upd()
        keyCaptureEl = nil
        return
    end
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        local el = keyCaptureEl
        keyCaptureEl = nil
        el.value = inp.KeyCode
        pcall(function() if el.cb then el.cb(inp.KeyCode) end end)
        if el._upd then el._upd() end
    end
end)

-- ---------- compat (для keybind manager/hud/cleanup) ----------
do
    setmetatable({}, {})
    local compatUI = { MainUI = rootF }
    setmetatable(compatUI, {
        __index = function(_, k)
            if k == "Faded" then return not CG_OPEN end
            return nil
        end,
    })
    getgenv().Library = {
        UI = compatUI,
        Unload = function()
            pcall(function() CGGui:Destroy() end)
        end,
        Init = function() end,
    }
end

-- ---------- ДИАГНОСТИКА/ВПЕРЁДНЫЕ ССЫЛКИ ----------
GSBuildErrors = 0
function uiCall(kind, label, f, ...)
    local args = table.pack(...)
    local ok, res = xpcall(function()
        return f(table.unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
        GSBuildErrors = GSBuildErrors + 1
        warn(("[SpermaHub][UI-ERR] %s '%s': %s"):format(tostring(kind), tostring(label), tostring(res)))
        return nil
    end
    return res
end

dummyCtl = nil
do
    local t = setmetatable({}, {
        __index = function() return function() end end,
    })
    dummyCtl = {
        sec = t, holder = nil,
        col1 = nil, col2 = nil, __module = nil,
    }
end

function addCategory(title)
    return uiCall("addCategory", title, addCategoryImpl, title)
end

function addPage(cat, icon, title)
    local r = uiCall("addPage", tostring(cat) .. "." .. tostring(title), addPageImpl, cat, icon, title)
    if r == nil then
        local m = {cat = cat, title = tostring(title), elements = {}, enableKey = nil,
                   bodyBuilt = false, open = false}
        curModule = m
        return {__module = m, col1 = {__module = m}, col2 = {__module = m}}
    end
    return r
end

HOIST_CATS = { Combat = true, Movement = true, Visuals = true }
-- эти панели НЕ вытаскивать отдельными строками — они остаются внутри своего модуля
NON_HOIST = { ["Target"] = true, ["Info"] = true, ["Silent Aura (1.8 Arena)"] = true, ["Mode Settings"] = true }
function addPanel(col, title)
    local m = col and col.__module
    if m == nil then return {module = nil, __module = nil, dim = true} end
    local t = cleanText(title)
    if m.cat and HOIST_CATS[m.cat] then
        if NON_HOIST[t] then
            -- вливаем в последний вытащенный модуль той же страницы (Kill Aura, Death FX и т.п.)
            local target = m._lastHoisted or m
            if target ~= m then
                table.insert(target.elements, {kind = "section", title = t})
            else
                table.insert(m.elements, {kind = "section", title = t})
            end
            return {module = target, __module = target, sec = {title = t}}
        end
        local rowTitle = (t == "Main") and m.title or t
        local pg2 = addPageImpl(m.cat, nil, rowTitle)
        local m2 = pg2.__module
        m2._hoisted = true
        m._lastHoisted = m2
        return {module = m2, __module = m2, sec = {title = t}}
    end
    table.insert(m.elements, {kind = "section", title = t})
    return {module = m, __module = m, sec = {title = t}}
end

function addToggle(panel, key, label, default, cb)
    local el = {panel = panel, key = key, label = label, default = default, cb = cb}
    local r = uiCall("addToggle", label, function()
        local m = panel.__module
        local e = {kind = "toggle", label = cleanText(label),
                   value = default and true or false, cb = cb, module = m, key = key}
        table.insert(m.elements, e)
        if key then
            Cfg[key] = {
                get = function() return e.value end,
                set = function(v)
                    e.value = v and true or false
                    pcall(function() if e.cb then e.cb(e.value) end end)
                    if e._upd then pcall(e._upd) end
                    if e.module then pcall(updModHeader, e.module) end
                end,
            }
        end
        if key and key:find("%.enabled$") and not m.enableKey then m.enableKey = key end
        return e
    end)
    if r == nil then
        return {set = function() end, get = function() return nil end}
    end
    return {
        set = function(v)
            r.value = v and true or false
            pcall(function() if r.cb then r.cb(r.value) end end)
            if r._upd then pcall(r._upd) end
            if r.module then pcall(updModHeader, r.module) end
        end,
        get = function() return r.value end,
        __el = r,
    }
end

function addSlider(panel, key, label, minV, maxV, default, step, cb)
    local r = uiCall("addSlider", label, function()
        local m = panel.__module
        local e = {kind = "slider", label = cleanText(label), min = minV, max = maxV,
                   step = step or 1, value = default, cb = cb, module = m}
        table.insert(m.elements, e)
        if key then Cfg[key] = {
            get = function() return e.value end,
            set = function(v)
                e.value = tonumber(v) or e.value
                pcall(function() if e.cb then e.cb(e.value) end end)
                if e._upd then pcall(e._upd) end
            end,
        } end
        return e
    end)
    if r == nil then return {set = function() end, get = function() return nil end} end
    return {
        set = function(v)
            r.value = tonumber(v) or r.value
            pcall(function() if r.cb then r.cb(r.value) end end)
            if r._upd then pcall(r._upd) end
        end,
        get = function() return r.value end,
        __el = r,
    }
end

function addDropdown(panel, key, label, options, default, cb)
    local r = uiCall("addDropdown", label, function()
        local m = panel.__module
        local e = {kind = "dropdown", label = cleanText(label), options = options,
                   value = tostring(default), cb = cb, module = m}
        table.insert(m.elements, e)
        if key then Cfg[key] = {
            get = function() return e.value end,
            set = function(v)
                e.value = tostring(v)
                pcall(function() if e.cb then e.cb(e.value) end end)
                if e._upd then pcall(e._upd) end
            end,
        } end
        return e
    end)
    if r == nil then return {set = function() end, get = function() return nil end} end
    return {
        set = function(v)
            r.value = tostring(v)
            pcall(function() if r.cb then r.cb(r.value) end end)
            if r._upd then pcall(r._upd) end
        end,
        get = function() return r.value end,
        __el = r,
    }
end

function addKeybind(panel, key, label, defaultName, cb)
    local r = uiCall("addKeybind", label, function()
        local m = panel.__module
        local defKey = nil
        if defaultName then pcall(function() defKey = Enum.KeyCode[defaultName] end) end
        local e = {kind = "keybind", label = cleanText(label), value = defKey, cb = cb, module = m}
        table.insert(m.elements, e)
        local function safeGet()
            if e.value and e.value.Name then return e.value.Name end
            return nil
        end
        if key then Cfg[key] = {
            get = safeGet,
            set = function(v)
                if v == nil then return end
                local kc = nil
                pcall(function() kc = Enum.KeyCode[tostring(v)] end)
                if kc then
                    e.value = kc
                    pcall(function() e.cb(kc) end)
                    if e._upd then pcall(e._upd) end
                end
            end,
        } end
        return {e = e, safeGet = safeGet}
    end)
    if r == nil then return {get = function() return nil end} end
    return {get = r.safeGet}
end

function addButton(panel, label, cb, color, hover)
    return uiCall("addButton", label, function()
        local m = panel.__module
        table.insert(m.elements, {kind = "button", label = cleanText(label), cb = cb, module = m})
    end)
end

function addText(panel, text)
    return uiCall("addText", tostring(text):sub(1, 32), function()
        local m = panel.__module
        table.insert(m.elements, {kind = "text", text = cleanText(text)})
    end)
end

function addBindRow(panel, entry)
    return uiCall("addBindRow", tostring(entry.label), function()
        local m = panel.__module
        table.insert(m.elements, {kind = "bindrow", entry = entry})
    end)
end

function makePlayerList(panel, height)
    local r = uiCall("makePlayerList", tostring(panel), function()
        local m = panel.__module
        local el = {kind = "plist", height = height or 140, data = {}, selected = nil,
                    onConnect = nil, module = m}
        table.insert(m.elements, el)
        local function rebuild(data)
            if data ~= nil then el.data = data else data = el.data end
            local names = {}
            for _, d in ipairs(data or {}) do table.insert(names, d.name) end
            if el.selected and not table.find(names, el.selected) then
                el.selected = nil
                if el.onConnect then pcall(el.onConnect, nil) end
            end
            if el._paint then pcall(el._paint) end
        end
        rebuild({})
        return {
            rebuild = rebuild,
            refresh = function() rebuild(nil) end,
            getSelected = function() return el.selected end,
            connect = function(cbFn) el.onConnect = cbFn end,
        }
    end)
    if r == nil then
        return {rebuild = function() end, refresh = function() end,
                getSelected = function() return nil end, connect = function() end}
    end
    return r
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
    {label = "Inf Jump",     cfg = "infjump.enabled"},
    {label = "Wallhop",      cfg = "wallhop.enabled"},
    {label = "Custom FOV",   cfg = "world.customfov"},
    {label = "Crosshair",    cfg = "world.crosshair"},
    {label = "Fullbright",   cfg = "world.fullbright"},
    {label = "Shaders",      cfg = "world.shaders"},
    {label = "China Hat",    cfg = "local.chinahat"},
    {label = "Backtrack",    cfg = "local.backtrack"},
    {label = "Self Chams",   cfg = "local.selfchams"},
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

function rebuildBindsWidget() end

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

end)()

-- ============================================================
-- ================ СТРАНИЦЫ (все вкладки) ====================
-- ============================================================
-- обёрнуто в do...end: ~130 локалов страниц освобождаются в конце секции (лимит Luau = 200)
doLoad, flingListCtl, killListCtl, specListCtl, tpListCtl = nil, nil, nil, nil, nil
; pcall(function(...) -- IIFE под pcall: крэш секции страниц не убивает меню Rayfield

-- храним ссылки на контролы, которые нужно синкать извне
local flightToggleCtl = nil
local autoClickToggleCtl = nil
killListCtl = nil
tpListCtl = nil
flingListCtl = nil
specListCtl = nil


-- ================= LOCAL/WORLD PACK (logic) =================
local Lighting = game:GetService("Lighting")

-- ============ INFINITE JUMP + WALLHOP ============
UIS.JumpRequest:Connect(function()
    if not (S.infJumpOn or S.wallhopOn) then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if hum:GetState() == Enum.HumanoidStateType.Seated then return end
    if S.infJumpOn then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        return
    end
    if S.wallhopOn then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        local cf = hrp.CFrame
        local hit = workspace:Raycast(hrp.Position, cf.LookVector * 3, params)
            or workspace:Raycast(hrp.Position, -cf.LookVector * 3, params)
            or workspace:Raycast(hrp.Position, cf.RightVector * 3, params)
            or workspace:Raycast(hrp.Position, -cf.RightVector * 3, params)
        if hit then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ============ CUSTOM FOV ============
local cfovConn = nil
function applyCustomFov()
    if cfovConn then return end
    cfovConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and S.customFovOn then
            pcall(function() cam.FieldOfView = S.customFov end)
        end
    end)
end
function removeCustomFov()
    if cfovConn then cfovConn:Disconnect() cfovConn = nil end
end

-- ============ ASPECT RATIO ============
function applyAspect()
    pcall(function() RunService:UnbindFromRenderStep("SpermaAspect") end)
    RunService:BindToRenderStep("SpermaAspect", 10000, function()
        local cam = workspace.CurrentCamera
        if not (cam and S.aspectOn) then return end
        local k = math.clamp((S.aspectVal or 100) / 100, 0.01, 1)
        if k >= 0.999 then return end
        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, k, 0, 1)
    end)
end
function removeAspect()
    pcall(function() RunService:UnbindFromRenderStep("SpermaAspect") end)
end

-- ============ CROSSHAIR (Drawing, без хуков) ============
local crossState = {lines = nil, out = nil, conn = nil, gap = 4, len = 8, thick = 2, rot = 0, col = Color3.new(1, 1, 1), ang = 0}
function updateCrosshairStyle(k, v)
    if k == "gap" then crossState.gap = v
    elseif k == "len" then crossState.len = v
    elseif k == "thick" then crossState.thick = v
    elseif k == "rot" then crossState.rot = v
    elseif k == "col" then crossState.col = v
    end
end
local function crossLine(color, thick)
    local l = Drawing.new("Line")
    l.Visible = false
    l.Color = color
    l.Thickness = thick
    l.ZIndex = 2
    return l
end
function enableCrosshair()
    local ok = pcall(function()
        if not crossState.lines then
            crossState.lines, crossState.out = {}, {}
            for i = 1, 4 do
                table.insert(crossState.out, crossLine(Color3.new(0, 0, 0), crossState.thick + 2))
                table.insert(crossState.lines, crossLine(crossState.col, crossState.thick))
            end
        end
        if crossState.conn then return end
        crossState.conn = RunService.RenderStepped:Connect(function(dt)
            local mp = UIS:GetMouseLocation()
            crossState.ang = crossState.ang + (crossState.rot or 0) * dt * 2
            local g, ln, a0 = crossState.gap, crossState.len, crossState.ang
            for i = 1, 4 do
                local a = a0 + (i - 1) * (math.pi / 2)
                local dx, dy = math.cos(a), math.sin(a)
                local o, m = crossState.out[i], crossState.lines[i]
                o.From = Vector2.new(mp.X + dx * g, mp.Y + dy * g)
                o.To = Vector2.new(mp.X + dx * (g + ln), mp.Y + dy * (g + ln))
                o.Thickness = crossState.thick + 2
                o.Visible = true
                m.From, m.To = o.From, o.To
                m.Thickness = crossState.thick
                m.Color = crossState.col
                m.Visible = true
            end
        end)
    end)
    if not ok then
        warn("[SpermaHub] Drawing API недоступен — прицел выключен")
    end
end
function disableCrosshair()
    if crossState.conn then crossState.conn:Disconnect() crossState.conn = nil end
    if crossState.lines then
        for _, l in ipairs(crossState.lines) do pcall(function() l:Remove() end) end
        for _, l in ipairs(crossState.out) do pcall(function() l:Remove() end) end
        crossState.lines, crossState.out = nil, nil
    end
end

-- ============ WORLD LIGHTING MODS ============
local wmod = {
    fb = false,
    fog = false, fogColor = Color3.fromRGB(192, 192, 192), fogStart = 0, fogEnd = 1000,
    amb = false, ambColor = Color3.fromRGB(128, 128, 128),
    exp = false, expVal = 0,
    time = false, timeVal = 12,
    shader = nil, sky = nil,
}
local worig = nil
local wpark = {}
local wmodConn = nil
local function wsave()
    if worig then return end
    worig = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ExposureCompensation = Lighting.ExposureCompensation,
    }
end
local SHADER_PRESETS = {
    morning = {Brightness = 2.2, ClockTime = 8.5, FogEnd = 100000, Ambient = Color3.fromRGB(150, 150, 150),
        GlobalShadows = true, Exposure = 0,
        atmo = {Density = 0.26, Offset = 0.25, Color = Color3.fromRGB(199, 199, 199), Decay = Color3.fromRGB(196, 196, 196), Glare = 0, Haze = 0},
        cc = {TintColor = Color3.fromRGB(255, 244, 230), Brightness = 0.03, Contrast = 0.04, Saturation = -0.05},
        sun = {Intensity = 0.045, Spread = 0.8}},
    midday = {Brightness = 3, ClockTime = 13.5, FogEnd = 100000, Ambient = Color3.fromRGB(160, 160, 160),
        GlobalShadows = true, Exposure = 0,
        atmo = {Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(210, 215, 220), Decay = Color3.fromRGB(200, 205, 215), Glare = 0, Haze = 0},
        cc = {TintColor = Color3.fromRGB(255, 255, 255), Brightness = 0, Contrast = 0.05, Saturation = 0.05},
        sun = {Intensity = 0.02, Spread = 0.7}},
    evening = {Brightness = 2, ClockTime = 18, FogEnd = 100000, Ambient = Color3.fromRGB(120, 100, 110),
        GlobalShadows = true, Exposure = 0,
        atmo = {Density = 0.33, Offset = 0.25, Color = Color3.fromRGB(255, 196, 160), Decay = Color3.fromRGB(120, 90, 110), Glare = 0.4, Haze = 1.2},
        cc = {TintColor = Color3.fromRGB(255, 222, 198), Brightness = 0, Contrast = 0.06, Saturation = 0.08},
        sun = {Intensity = 0.12, Spread = 0.92}},
    night = {Brightness = 1.4, ClockTime = 0, FogEnd = 60000, Ambient = Color3.fromRGB(60, 70, 110),
        GlobalShadows = true, Exposure = 0,
        atmo = {Density = 0.35, Offset = 0.25, Color = Color3.fromRGB(120, 140, 190), Decay = Color3.fromRGB(40, 50, 80), Glare = 0, Haze = 0.5},
        cc = {TintColor = Color3.fromRGB(195, 205, 240), Brightness = 0, Contrast = 0.03, Saturation = -0.1},
        sun = {Intensity = 0, Spread = 1}},
}
local SKY_SETS = {
    -- повтор одной текстуры на все 6 граней (не 404-нёт никогда)
    ["Jungle"] = "rbxassetid://1417494030",
    ["Blossom"] = "rbxassetid://1417494146",
    ["Red night"] = "rbxassetid://271077958",
    ["Purple default"] = "rbxassetid://159454288",
    ["Foggy"] = "rbxassetid://153695352",
    ["Galaxy"] = "rbxassetid://159454300",
    ["Anime"] = "rbxassetid://626458639",
    ["Minecraft"] = "rbxassetid://10258337305",
}
local function wparkClass(className)
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA(className) and v.Name:sub(1, 6) ~= "Sperma" then
            table.insert(wpark, v)
            v.Parent = nil
        end
    end
end
local function wclearCustom()
    for _, v in ipairs(Lighting:GetChildren()) do
        if v.Name:sub(1, 6) == "Sperma" then
            pcall(function() v:Destroy() end)
        end
    end
end
local function wapplyShader()
    if not wmod.shader then return end
    local pr = SHADER_PRESETS[wmod.shader]
    if not pr then return end
    Lighting.Brightness = pr.Brightness
    Lighting.ClockTime = pr.ClockTime
    Lighting.FogEnd = pr.FogEnd
    Lighting.Ambient = pr.Ambient
    Lighting.GlobalShadows = pr.GlobalShadows
    local atmo = Lighting:FindFirstChild("SpermaAtmo")
    if not atmo then
        atmo = Instance.new("Atmosphere")
        atmo.Name = "SpermaAtmo"
        atmo.Parent = Lighting
    end
    atmo.Density, atmo.Offset, atmo.Color, atmo.Decay, atmo.Glare, atmo.Haze =
        pr.atmo.Density, pr.atmo.Offset, pr.atmo.Color, pr.atmo.Decay, pr.atmo.Glare, pr.atmo.Haze
    local cc = Lighting:FindFirstChild("SpermaCC")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "SpermaCC"
        cc.Parent = Lighting
    end
    cc.TintColor, cc.Brightness, cc.Contrast, cc.Saturation = pr.cc.TintColor, pr.cc.Brightness, pr.cc.Contrast, pr.cc.Saturation
    local sun = Lighting:FindFirstChild("SpermaSun")
    if not sun then
        sun = Instance.new("SunRaysEffect")
        sun.Name = "SpermaSun"
        sun.Parent = Lighting
    end
    sun.Intensity, sun.Spread = pr.sun.Intensity, pr.sun.Spread
end
local function wapplySky()
    if not wmod.sky then return end
    local tex = SKY_SETS[wmod.sky]
    if not tex then return end
    wparkClass("Sky")
    local old = Lighting:FindFirstChild("SpermaSky")
    if old then old:Destroy() end
    local sky = Instance.new("Sky")
    sky.Name = "SpermaSky"
    sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = tex, tex, tex
    sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = tex, tex, tex
    sky.StarCount = 5000
    sky.Parent = Lighting
end
local function wensureConn()
    if wmodConn then return end
    wmodConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if wmod.fb then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.FogEnd = 100000
                Lighting.GlobalShadows = false
                Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            end
            if wmod.fog then
                Lighting.FogStart = wmod.fogStart
                Lighting.FogEnd = wmod.fogEnd
                Lighting.FogColor = wmod.fogColor
            end
            if wmod.amb then
                Lighting.Ambient = wmod.ambColor
                Lighting.OutdoorAmbient = wmod.ambColor
            end
            if wmod.exp then
                Lighting.ExposureCompensation = wmod.expVal
            end
            if wmod.time then
                Lighting.ClockTime = wmod.timeVal
            end
            if wmod.shader then wapplyShader() end
        end)
    end)
end
function setFullbright(b)
    wsave()
    wmod.fb = b
    if b then wensureConn() end
end
function setFog(b)
    wsave()
    wmod.fog = b
    if b then wensureConn() end
end
function setFogColor(c) wmod.fogColor = c end
function setFogStart(v) wmod.fogStart = v end
function setFogEnd(v) wmod.fogEnd = v end
function setAmbient(b)
    wsave()
    wmod.amb = b
    if b then wensureConn() end
end
function setAmbientColor(c) wmod.ambColor = c end
function setExposure(b)
    wsave()
    wmod.exp = b
    if b then wensureConn() end
end
function setExposureVal(v) wmod.expVal = v end
function setTimeChanger(b)
    wsave()
    wmod.time = b
    if b then wensureConn() end
end
function setTimeVal(v) wmod.timeVal = v end
function setShaders(b)
    wsave()
    if b then
        wmod.shader = wmod.shader or "morning"
        wparkClass("Atmosphere")
        wparkClass("ColorCorrectionEffect")
        wparkClass("BloomEffect")
        wparkClass("SunRaysEffect")
        wapplyShader()
        wensureConn()
    else
        wmod.shader = nil
        wclearCustom()
        for _, v in ipairs(wpark) do
            pcall(function() v.Parent = Lighting end)
        end
        wpark = {}
    end
end
function setShaderType(t)
    wmod.shader = t
    if t then
        wsave()
        wclearCustom()
        wapplyShader()
        wensureConn()
    end
end
function setSkybox(b)
    wsave()
    if b then
        wmod.sky = wmod.sky or "Galaxy"
        wapplySky()
    else
        setSkyboxOff()
    end
end
function setSkyboxOff()
    wmod.sky = nil
    local old = Lighting:FindFirstChild("SpermaSky")
    if old then old:Destroy() end
    for _, v in ipairs(wpark) do
        if v:IsA("Sky") then
            pcall(function() v.Parent = Lighting end)
        end
    end
end
function setSkyboxName(n)
    wmod.sky = n
    if n then
        wsave()
        wapplySky()
    end
end
function applySkybox() wapplySky() end

-- ============ WORLD FX (снег/сакура за камерой) ============
local wfx = {model = nil, part = nil, em = nil, conn = nil, tex = "rbxasset://textures/particles/sparkles_main.dds"}
function setWorldFx(b)
    if b then
        if not wfx.model then
            local m = Instance.new("Model")
            m.Name = "SpermaWorldFx"
            local pt = Instance.new("Part")
            pt.Name = "Box"
            pt.Size = Vector3.new(40, 24, 40)
            pt.Transparency = 1
            pt.Anchored = true
            pt.CanCollide = false
            pt.CanQuery = false
            pt.Parent = m
            local em = Instance.new("ParticleEmitter")
            em.Rate = 250
            em.Lifetime = NumberRange.new(2.5, 4)
            em.Speed = NumberRange.new(4, 7)
            em.VelocitySpread = 180
            em.Size = NumberSequence.new(0.35)
            em.Transparency = NumberSequence.new(0.15)
            em.RotSpeed = NumberRange.new(-60, 60)
            em.Texture = wfx.tex
            em.Parent = pt
            m.Parent = workspace
            wfx.model, wfx.part, wfx.em = m, pt, em
        end
        if not wfx.conn then
            wfx.conn = RunService.Heartbeat:Connect(function()
                local cam = workspace.CurrentCamera
                if cam and wfx.part then
                    local cf = cam.CFrame
                    wfx.part.CFrame = CFrame.new(cf.Position + cf.LookVector * 20 + Vector3.new(0, 12, 0))
                end
            end)
        end
        wfx.model.Parent = workspace
    else
        if wfx.conn then wfx.conn:Disconnect() wfx.conn = nil end
        if wfx.model then pcall(function() wfx.model:Destroy() end) wfx.model, wfx.part, wfx.em = nil, nil, nil end
    end
end
function setWorldFxType(t)
    wfx.tex = t == "Sakura" and "rbxasset://textures/particles/smoke_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
    if wfx.em then wfx.em.Texture = wfx.tex end
end
function setWorldFxColor(c)
    if wfx.em then
        wfx.em.Color = ColorSequence.new(c)
    end
    wfx.col = c
end
function setWorldFxRate(v)
    if wfx.em then wfx.em.Rate = v end
    wfx.rate = v
end

function restoreWorldMods()
    wmod.fb, wmod.fog, wmod.amb, wmod.exp, wmod.time = false, false, false, false, false
    wmod.shader, wmod.sky = nil, nil
    if wmodConn then wmodConn:Disconnect() wmodConn = nil end
    wclearCustom()
    for _, v in ipairs(wpark) do
        pcall(function() v.Parent = Lighting end)
    end
    wpark = {}
    if worig then
        pcall(function()
            Lighting.Brightness = worig.Brightness
            Lighting.ClockTime = worig.ClockTime
            Lighting.FogStart = worig.FogStart
            Lighting.FogEnd = worig.FogEnd
            Lighting.FogColor = worig.FogColor
            Lighting.GlobalShadows = worig.GlobalShadows
            Lighting.Ambient = worig.Ambient
            Lighting.OutdoorAmbient = worig.OutdoorAmbient
            Lighting.ExposureCompensation = worig.ExposureCompensation
        end)
        worig = nil
    end
    setWorldFx(false)
end

-- ============ CHINA HAT (Drawing-конус над головой) ============
local hatState = {rays = nil, conn = nil}
local HAT_N = 10
function disableChinaHat()
    if hatState.conn then hatState.conn:Disconnect() hatState.conn = nil end
    if hatState.rays then
        for _, r in ipairs(hatState.rays) do pcall(function() r:Remove() end) end
        hatState.rays = nil
    end
    if hatState.tri then
        for _, t in ipairs(hatState.tri) do pcall(function() t:Remove() end) end
        hatState.tri = nil
    end
end
local HAT2_PROFILE = {0, 1, 2, 3, 3, 2, 1}
local function ensureChinaHat()
    if hatState.conn then return end
    local ok = pcall(function()
        local tri = {}
        for i = 1, 130 do
            local t = Drawing.new("Triangle")
            t.Filled = true
            t.Thickness = 1
            t.Visible = false
            table.insert(tri, t)
        end
        hatState.tri = tri
    end)
    if not ok or not hatState.tri then hatState.tri = nil return end
    local frame = 0
    hatState.conn = RunService.RenderStepped:Connect(function()
        frame = frame + 1
        if frame % 2 ~= 0 then return end
        local tri = hatState.tri
        if not tri then return end
        local char = LP.Character
        local head = char and char:FindFirstChild("Head")
        local cam = workspace.CurrentCamera
        local ti = 0
        local function hideFrom(n)
            for i = n, #tri do tri[i].Visible = false end
        end
        if not (S.chinaHatOn and head and cam) then hideFrom(1) return end
        local col = S.chinaHatColor or Color3.new(1, 0, 1)
        local white = Color3.new(1, 1, 1)
        local hp = head.Position
        local dist = (cam.CFrame.Position - hp).Magnitude
        local k = math.clamp(dist / 70, 0.12, 1.3)
        local sq2 = k / 2
        local function w2s(wx, wy, wz)
            return cam:WorldToViewportPoint(Vector3.new(wx, wy, wz))
        end
        local function drawSq(cx, cy, cz, fill)
            local p1, o1 = w2s(cx - sq2, cy + sq2, cz)
            local p2, o2 = w2s(cx + sq2, cy + sq2, cz)
            local p3, o3 = w2s(cx - sq2, cy - sq2, cz)
            local p4, o4 = w2s(cx + sq2, cy - sq2, cz)
            if not (o1 and o2 and o3 and o4) then return end
            ti = ti + 1
            local t = tri[ti]
            if not t then return end
            t.PointA = Vector2.new(p1.X, p1.Y)
            t.PointB = Vector2.new(p2.X, p2.Y)
            t.PointC = Vector2.new(p3.X, p3.Y)
            t.Color = fill t.Visible = true
            ti = ti + 1
            t = tri[ti]
            if not t then return end
            t.PointA = Vector2.new(p3.X, p3.Y)
            t.PointB = Vector2.new(p2.X, p2.Y)
            t.PointC = Vector2.new(p4.X, p4.Y)
            t.Color = fill t.Visible = true
        end
        local function drawTri3(ax, ay, bx, by, cx2, cy2, fill)
            ti = ti + 1
            local t = tri[ti]
            if not t then ti = ti - 1 return end
            t.PointA = Vector2.new(ax, ay)
            t.PointB = Vector2.new(bx, by)
            t.PointC = Vector2.new(cx2, cy2)
            t.Color = fill
            t.Visible = true
        end
        -- ряды корпуса (белые боковые колонны + цветная середина)
        for r = 1, 7 do
            local ry = hp.Y + 1.3 - r
            local cw = HAT2_PROFILE[r]
            for j = -cw, cw do
                local fill = (math.abs(j) == cw and cw > 0) and white or col
                drawSq(hp.X + j * k, ry, hp.Z, fill)
                if ti > 112 then break end
            end
        end
        -- верхушка
        local apexW = hp + Vector3.new(0, 1.45, 0)
        local ap, onA = w2s(apexW.X, apexW.Y, apexW.Z)
        local l1, onl = w2s(hp.X - sq2, hp.Y + 1.3 - 1 + sq2, hp.Z)
        local r1, onr = w2s(hp.X + sq2, hp.Y + 1.3 - 1 + sq2, hp.Z)
        if onA and onl and onr then
            drawTri3(ap.X, ap.Y, l1.X, l1.Y, r1.X, r1.Y, col)
        end
        -- нижняя решётка-веер (только если камера близко)
        if dist <= 90 then
            local anch = (head.CFrame * CFrame.new(0, 0.4, 0)).Position
            for ang = -90, 270, 30 do
                local ca = math.rad(ang)
                local gcx = anch.X + math.cos(ca) * 3.6
                local gcz = anch.Z + math.sin(ca) * 3.6
                drawSq(gcx, anch.Y, gcz, col)
                if ti > 124 then break end
            end
            local ap2, onA2 = w2s(anch.X, anch.Y, anch.Z)
            local l2, onl2 = w2s(hp.X - k * 1.5, hp.Y + 1.3 - 7 - sq2, hp.Z)
            local r2, onr2 = w2s(hp.X + k * 1.5, hp.Y + 1.3 - 7 - sq2, hp.Z)
            if onA2 and onl2 and onr2 then
                drawTri3(ap2.X, ap2.Y, l2.X, l2.Y, r2.X, r2.Y, col)
            end
        end
        hideFrom(ti + 1)
    end)
end
function ensureChinaHatVis() ensureChinaHat() end
RunService.Heartbeat:Connect(function()
    if S.chinaHatOn then ensureChinaHat() end
end)

-- ============ BACKTRACK (клон на серверной позиции) ============
local bt = {clone = nil, buf = {}, conn = nil}
local function btDestroy()
    if bt.clone then pcall(function() bt.clone:Destroy() end) bt.clone = nil end
end
local function btMakeClone(char)
    btDestroy()
    local ok, clone = pcall(function()
        char.Archivable = true
        return char:Clone()
    end)
    if not ok or not clone then return end
    clone.Name = "SpermaBT"
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Animator") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.Anchored = true
            v.CanCollide = false
            v.CanQuery = false
            v.Transparency = 0.45
            v.Color = S.backtrackColor
            v.Material = Enum.Material.Neon
        elseif v:IsA("Decal") then
            v:Destroy()
        end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    clone.Parent = workspace
    bt.clone = clone
end
function refreshBacktrackColor(c)
    S.backtrackColor = c
    if bt.clone then
        for _, v in ipairs(bt.clone:GetDescendants()) do
            if v:IsA("BasePart") then v.Color = c end
        end
    end
end
function setBacktrack(b)
    S.backtrackOn = b
    if b then
        if bt.conn then return end
        bt.conn = RunService.Heartbeat:Connect(function()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then btDestroy() return end
            local now = tick()
            table.insert(bt.buf, {t = now, cf = hrp.CFrame})
            while #bt.buf > 0 and now - bt.buf[1].t > 1.2 do
                table.remove(bt.buf, 1)
            end
            if not bt.clone or not bt.clone.Parent then
                btMakeClone(char)
            end
            local ping = 0.12
            pcall(function()
                local item = Stats.Network:FindFirstChild("ServerStatsItem")
                local p = item and item:FindFirstChild("Data Ping")
                if p then
                    local ms = tonumber(string.match(p:GetValueString(), "%d+")) or 120
                    ping = math.clamp(ms / 1000, 0.05, 0.9)
                end
            end)
            local target = now - math.max(ping, 0.1)
            local best = bt.buf[1]
            for _, e in ipairs(bt.buf) do
                if e.t <= target then best = e else break end
            end
            if best and bt.clone then
                local chrp = bt.clone:FindFirstChild("HumanoidRootPart")
                if chrp then
                    pcall(function() bt.clone:SetPrimaryPartCFrame(best.cf) end)
                end
            end
        end)
    else
        if bt.conn then bt.conn:Disconnect() bt.conn = nil end
        bt.buf = {}
        btDestroy()
    end
end

-- ============ SELF CHAMS ============
local scOrig = {}
local scHL = nil
local scConn = nil
local function scApply(char)
    scOrig = {}
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            table.insert(scOrig, {part = v, color = v.Color, mat = v.Material})
            pcall(function()
                v.Color = S.selfChamsColor
                v.Material = S.selfChamsType == "ForceField" and Enum.Material.ForceField or Enum.Material.SmoothPlastic
            end)
        end
    end
    if S.selfChamsType == "Flat" then
        scHL = char:FindFirstChild("SpermaSelfHL")
        if not scHL then
            scHL = Instance.new("Highlight")
            scHL.Name = "SpermaSelfHL"
            scHL.OutlineTransparency = 1
            scHL.FillTransparency = 0.35
            scHL.DepthMode = Enum.HighlightDepthMode.Occluded
            scHL.Parent = char
        end
        scHL.FillColor = S.selfChamsColor
    end
end
local function scRestore(char)
    for _, e in ipairs(scOrig) do
        pcall(function()
            e.part.Color = e.color
            e.part.Material = e.mat
        end)
    end
    scOrig = {}
    if scHL then pcall(function() scHL:Destroy() end) scHL = nil end
end
function setSelfChams(b)
    S.selfChamsOn = b
    local char = LP.Character
    if b then
        if char then scApply(char) end
        if not scConn then
            scConn = LP.CharacterAdded:Connect(function(c)
                c:WaitForChild("HumanoidRootPart", 3)
                if S.selfChamsOn then scApply(c) end
            end)
        end
    else
        if char then scRestore(char) end
        if scConn then scConn:Disconnect() scConn = nil end
    end
end
RunService.Heartbeat:Connect(function()
    if S.selfChamsOn then
        local char = LP.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and v.Color ~= S.selfChamsColor then
                    pcall(function() v.Color = S.selfChamsColor end)
                end
            end
            if scHL then scHL.FillColor = S.selfChamsColor end
        end
    end
end)

-- ============ LANDING CIRCLE ============
local landConn = nil
local LAND_IMG = "rbxassetid://7185003058"
local function spawnLandingCircle(pos)
    local pt = Instance.new("Part")
    pt.Name = "SpermaLandingCircle"
    pt.Size = Vector3.new(2, 0.06, 2)
    pt.Transparency = 1
    pt.Anchored = true
    pt.CanCollide = false
    pt.CanQuery = false
    pt.CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0))
    local dec = Instance.new("Decal")
    dec.Texture = LAND_IMG
    dec.Face = Enum.NormalId.Top
    dec.Color3 = S.landingColor
    dec.Transparency = 1 - math.clamp(S.landingTransp, 0, 1)
    dec.Parent = pt
    pt.Parent = workspace
    local t0 = tick()
    local dur = math.max(S.landingDur, 0.05)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local k = (tick() - t0) / dur
        if k >= 1 or not pt.Parent then
            conn:Disconnect()
            pcall(function() pt:Destroy() end)
            return
        end
        local s = 2 + k * 7
        pt.Size = Vector3.new(s, 0.06, s)
        dec.Transparency = math.clamp((1 - S.landingTransp) + k * S.landingTransp, 0, 1)
    end)
end
function setLandingCircle(b)
    S.landingOn = b
    if b then
        if landConn then return end
        landConn = RunService.Heartbeat:Connect(function() end)
        task.spawn(function()
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.StateChanged:Connect(function(_, new)
                    if not S.landingOn then return end
                    if new == Enum.HumanoidStateType.Landed then
                        local c2 = LP.Character
                        local hrp = c2 and c2:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local params = RaycastParams.new()
                            params.FilterType = Enum.RaycastFilterType.Exclude
                            params.FilterDescendantsInstances = {c2}
                            local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -40, 0), params)
                            spawnLandingCircle(hit and hit.Position or (hrp.Position - Vector3.new(0, 3, 0)))
                        end
                    end
                end)
            end
        end)
    else
        if landConn then landConn:Disconnect() landConn = nil end
        pcall(function()
            local old = workspace:FindFirstChild("SpermaLandingCircle")
            if old then old:Destroy() end
        end)
    end
end


-- ============ FULL PACK UPGRADE build11 (полный порт поверх старого) ============
-- Переопределения + новые системы.
local SH2 = {conns = {}, objs = {}}
local function sh2Conn(c) table.insert(SH2.conns, c) return c end
local TW2 = game:GetService("TweenService")
local function sh2Wait() end -- alias placeholder (не используется)

-- ============================================================
-- SELF CHAMS v2 (ForceField / Flat / Chromatic + SurfaceAppearance)
-- ============================================================
local sc2 = {app = {}, appear = {}, conn = nil, chrom = 0}
local function sc2Strip(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("SurfaceAppearance") then
            sc2.appear[v.Parent] = v
            v.Parent = nil
        end
    end
end
local function sc2RestoreAll(char)
    for parent, obj in pairs(sc2.appear) do
        pcall(function() if parent and parent.Parent then obj.Parent = parent end end)
    end
    sc2.appear = {}
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                local o = sc2.app[v]
                if o then pcall(function() v.Material = o end) end
            end
        end
    end
    sc2.app = {}
end
function setSelfChams(b)
    S.selfChamsOn = b
    local char = LP.Character
    if b then
        pcall(function()
            if char then
                sc2Strip(char)
                local col = S.selfChamsColor
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                        sc2.app[v] = v.Material
                        v.Color = col
                        if S.selfChamsType == "ForceField" then
                            v.Material = Enum.Material.ForceField
                        elseif S.selfChamsType == "Flat" then
                            v.Material = Enum.Material.SmoothPlastic
                        elseif S.selfChamsType == "Chromatic" then
                            v.Material = Enum.Material.Neon
                        end
                    end
                end
                -- вотчер: авто восстановление поверхностей если они вернулись
                if not sc2.conn then
                    sc2.conn = sh2Conn(RunService.Heartbeat:Connect(function()
                        sc2.chrom = sc2.chrom + 1
                        if sc2.chrom % 45 == 0 then
                            local c2 = LP.Character
                            if c2 and S.selfChamsOn then
                                for _, v in ipairs(c2:GetDescendants()) do
                                    if v:IsA("SurfaceAppearance") then
                                        sc2.appear[v.Parent] = v
                                        v.Parent = nil
                                    end
                                end
                            end
                        end
                    end))
                end
            end
        end)
    else
        pcall(function()
            sc2RestoreAll(char)
            if sc2.conn then sc2.conn:Disconnect() sc2.conn = nil end
        end)
    end
end
-- реаплаи при респавне
sh2Conn(LP.CharacterAdded:Connect(function(c)
    if not S.selfChamsOn then return end
    task.wait(0.4)
    if S.selfChamsOn then setSelfChams(false) setSelfChams(true) end
end))

-- ============================================================
-- TOOL CHAMS (ForceField / Flat / Chromatic на инструменте в руке)
-- ============================================================
local tc2 = {orig = {}, conn = nil}
local function tcApply(tool)
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("BasePart") then
            if not tc2.orig[v] then tc2.orig[v] = {mat = v.Material, col = v.Color} end
            v.Color = S.selfChamsColor
            if S.toolChamsType == "ForceField" then v.Material = Enum.Material.ForceField
            elseif S.toolChamsType == "Flat" then v.Material = Enum.Material.SmoothPlastic
            else v.Material = Enum.Material.Neon end
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        end
    end
end
local function tcRestore()
    for v, o in pairs(tc2.orig) do
        pcall(function() if v and v.Parent then v.Material = o.mat v.Color = o.col end end)
    end
    tc2.orig = {}
end
function setToolChams(b)
    S.toolChamsOn = b
    if b then
        if tc2.conn then return end
        tc2.conn = sh2Conn(RunService.Heartbeat:Connect(function()
            if not S.toolChamsOn then return end
            local char = LP.Character
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then pcall(tcApply, tool) end
        end))
    else
        if tc2.conn then tc2.conn:Disconnect() tc2.conn = nil end
        tcRestore()
    end
end

-- ============================================================
-- BACKTRACK v2 (кольцевой буфер 256 кадров, сдвиг по пингу)
-- ============================================================
local bt2 = {clone = nil, buf = {}, conn = nil, ping = 0, lastPingT = 0}
local function bt2Destroy()
    if bt2.clone then pcall(function() bt2.clone:Destroy() end) bt2.clone = nil end
end
local function bt2Clone(char)
    bt2Destroy()
    local ok, cl = pcall(function()
        char.Archivable = true
        return char:Clone()
    end)
    if not ok or not cl then return end
    cl.Name = "SpermaBT2"
    for _, v in ipairs(cl:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Animator") or v:IsA("Decal") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.Anchored = true
            v.CanCollide = false
            v.CanQuery = false
            v.Transparency = 0.5
            v.Color = S.backtrackColor
            v.Material = Enum.Material.Neon
        end
    end
    local hum = cl:FindFirstChildOfClass("Humanoid")
    if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    cl.Parent = workspace
    bt2.clone = cl
end
function refreshBacktrackColor(c)
    S.backtrackColor = c
    if bt2.clone then
        for _, v in ipairs(bt2.clone:GetDescendants()) do
            if v:IsA("BasePart") then v.Color = c end
        end
    end
end
function setBacktrack(b)
    S.backtrackOn = b
    if b then
        if bt2.conn then return end
        bt2.buf = {}
        bt2.conn = sh2Conn(RunService.Heartbeat:Connect(function(dt)
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then bt2Destroy() return end
            -- пинг раз в 5 сек
            if tick() - bt2.lastPingT > 5 then
                bt2.lastPingT = tick()
                pcall(function() bt2.ping = math.clamp(LP:GetNetworkPing() * 1000, 0, 800) end)
            end
            table.insert(bt2.buf, hrp.CFrame)
            if #bt2.buf > 256 then table.remove(bt2.buf, 1) end
            local frames = math.max(1, math.floor(bt2.ping / math.max(dt * 1000, 1)))
            local idx = math.clamp(#bt2.buf - frames, 1, #bt2.buf)
            local cf = bt2.buf[idx]
            if not bt2.clone or not bt2.clone.Parent then
                bt2Clone(char)
            end
            if bt2.clone and cf then
                local tgt = (bt2.clone:GetPivot()):Lerp(cf, 0.5)
                pcall(function() bt2.clone:PivotTo(tgt) end)
            end
        end))
    else
        if bt2.conn then bt2.conn:Disconnect() bt2.conn = nil end
        bt2Destroy()
        bt2.buf = {}
    end
end

-- ============================================================
-- LANDING CIRCLE v2 (SurfaceGui + твин)
-- ============================================================
local lc2 = {conn = nil, stateConn = nil}
local function lcSpawn(hitPos)
    local ok = pcall(function()
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.Transparency = 1
        part.Size = Vector3.new(6, 0.05, 6)
        part.CFrame = CFrame.new(hitPos + Vector3.new(0, 0.51, 0))
        part.Parent = workspace
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.AlwaysOnTop = true
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(1, 0, 1, 0)
        img.Image = "rbxassetid://7185003058"
        img.ImageColor3 = S.landingColor
        img.ImageTransparency = math.clamp(1 - S.landingTransp, 0, 1)
        img.Parent = sg
        sg.Parent = part
        local dur = math.max(S.landingDur, 0.05)
        local tw = TW2:Create(img, TweenInfo.new(dur, Enum.EasingStyle.Linear), {ImageTransparency = 1})
        tw:Play()
        task.delay(dur + 0.05, function() pcall(function() part:Destroy() end) end)
    end)
end
function setLandingCircle(b)
    S.landingOn = b
    if b then
        if lc2.conn then return end
        lc2.conn = sh2Conn(LP.CharacterAdded:Connect(function() end))
        local function bindChar(c)
            local hum = c:WaitForChild("Humanoid", 5)
            if not hum then return end
            hum.StateChanged:Connect(function(_, st)
                if not S.landingOn then return end
                if st == Enum.HumanoidStateType.Landed then
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {c}
                    local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -50, 0), params)
                    lcSpawn(hit and hit.Position or (hrp.Position - Vector3.new(0, 3, 0)))
                end
            end)
        end
        if LP.Character then task.spawn(bindChar, LP.Character) end
        sh2Conn(LP.CharacterAdded:Connect(function(c) task.spawn(bindChar, c) end))
    else
        -- выкл: новые спавны просто прекратятся (S.landingOn=false)
        if lc2.conn then lc2.conn:Disconnect() lc2.conn = nil end
    end
end

-- ============================================================
-- FAKE POSITION + VELOCITY SPOOF (хуки pcall-обёрнуты; на Real работает)
-- ============================================================
local fp = {hooked = false, marker = nil}
local function fpOffset()
    local t = tick()
    local d = tonumber(S.fakeDist) or 0
    return Vector3.new(math.sin(t * 1.3) * d, (tonumber(S.fakeUp) or 0) + math.sin(t * 2.1) * math.min(d, 50), math.cos(t * 1.7) * d)
end
local function fpTryHook()
    if fp.hooked then return true end
    local ok = pcall(function()
        if type(getrawmetatable) ~= "function" then error("no getrawmetatable") end
        local mt = getrawmetatable(game)
        local oldidx = mt.__index
        if type(setreadonly) == "function" then setreadonly(mt, false) end
        local newidx
        newidx = function(t, k)
            if S.fakePosOn and (k == "CFrame" or k == "Position") then
                local safe = true
                if type(checkcaller) == "function" then
                    safe = checkcaller()
                end
                if safe then
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and t == hrp then
                        local cf = oldidx(t, "CFrame")
                        local fake = cf + fpOffset()
                        if k == "CFrame" then return fake end
                        return fake.Position
                    end
                end
            end
            return oldidx(t, k)
        end
        if type(newcclosure) == "function" then newidx = newcclosure(newidx) end
        mt.__index = newidx
        if type(setreadonly) == "function" then setreadonly(mt, true) end
        pcall(function()
            if type(sethiddenproperty) == "function" then
                sethiddenproperty(LP, "S2PhysicsSenderRate", -1)
            end
        end)
    end)
    fp.hooked = ok
    if not ok then warn("[spermahub] fakepos: хуки недоступны на этом инжекторе") end
    return ok
end
function setFakePosition(b)
    S.fakePosOn = b
    if b and not fpTryHook() then
        S.fakePosOn = false
        toastImpl("Desync", "Хуки недоступны — Fake Position выключен")
    end
end
function setFakePosVisual(b)
    S.fakePosVis = b
    if not b and fp.marker then pcall(function() fp.marker:Destroy() end) fp.marker = nil end
end
sh2Conn(RunService.Heartbeat:Connect(function()
    -- маркер фейковой позиции
    if S.fakePosOn and S.fakePosVis then
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not fp.marker or not fp.marker.Parent then
                pcall(function()
                    local p = Instance.new("Part")
                    p.Name = "SpermaFakePosMarker"
                    p.Anchored = true p.CanCollide = false p.CanQuery = false
                    p.Transparency = 1
                    p.Size = Vector3.new(1, 1, 1)
                    local bg = Instance.new("BillboardGui")
                    bg.Size = UDim2.new(0, 40, 0, 40)
                    bg.AlwaysOnTop = true
                    local img = Instance.new("ImageLabel")
                    img.BackgroundTransparency = 1
                    img.Size = UDim2.new(1, 0, 1, 0)
                    img.Image = "rbxassetid://140069439568220"
                    img.Parent = bg
                    bg.Parent = p
                    p.Parent = workspace
                    fp.marker = p
                end)
            end
            if fp.marker then
                fp.marker.CFrame = hrp.CFrame + fpOffset()
            end
        end
    elseif fp.marker then
        pcall(function() fp.marker:Destroy() end)
        fp.marker = nil
    end
    -- velocity spoof
    if S.veloSpoofOn then
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                local pw = tonumber(S.veloPow) or 8
                if S.veloMode == "velocity" then
                    local v = hrp.AssemblyLinearVelocity
                    local k1 = (math.random() - 0.5) * 2 * pw / 10
                    local k2 = (math.random() - 0.5) * 2 * pw / 10
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X * (1 + k1), v.Y, v.Z * (1 + k2))
                elseif S.veloMode == "rotate" then
                    hrp.AssemblyAngularVelocity = Vector3.new(
                        (math.random() - 0.5) * pw * 2,
                        (math.random() - 0.5) * pw * 2,
                        (math.random() - 0.5) * pw * 2)
                end
            end)
        end
    end
end))

-- ============================================================
-- PIXEL SURF (невидимая ступенька у выступа)
-- ============================================================
local ps = {conn = nil, plat = nil, cd = 0}
function setPixelSurf(b)
    S.pixelSurfOn = b
    if not b then
        if ps.conn then ps.conn:Disconnect() ps.conn = nil end
        if ps.plat then pcall(function() ps.plat:Destroy() end) ps.plat = nil end
        return
    end
    if ps.conn then return end
    ps.conn = sh2Conn(RunService.Heartbeat:Connect(function()
        if tick() - ps.cd < 1.4 then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum) then return end
        local st = hum:GetState()
        if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        -- есть стена впереди и пустота под ногами → ступенька
        local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 3, params)
        local ground = workspace:Raycast(hrp.Position, Vector3.new(0, -3.4, 0), params)
        if wall and not ground then
            ps.cd = tick()
            pcall(function()
                if ps.plat then ps.plat:Destroy() end
                local p = Instance.new("Part")
                p.Size = Vector3.new(6, 0.5, 6)
                p.Anchored = true
                p.Transparency = 0.75
                p.Color = Color3.new(1, 1, 1)
                p.Material = Enum.Material.Neon
                p.CFrame = hrp.CFrame * CFrame.new(0, -3.2, 0)
                p.Parent = workspace
                ps.plat = p
                task.delay(1.1, function()
                    pcall(function() if ps.plat == p then ps.plat = nil end p:Destroy() end)
                end)
            end)
        end
    end))
end

-- ============================================================
-- JUMP POWER
-- ============================================================
function applyJumpPower()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.UseJumpPower = true
        hum.JumpPower = S.jumpPower
    end)
end
sh2Conn(RunService.Heartbeat:Connect(function()
    if S.jumpPowerOn then
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and math.abs((hum.JumpPower or 50) - S.jumpPower) > 0.1 then
            applyJumpPower()
        end
    end
end))

-- ============================================================
-- ANTI-VOID + ANTI-AFK
-- ============================================================
local av = {part = nil, lastSafe = nil}
function setAntiVoid(b)
    S.antiVoidOn = b
    if b then
        pcall(function()
            if not av.part or not av.part.Parent then
                local p = Instance.new("Part")
                p.Name = "SpermaAntiVoid"
                p.Size = Vector3.new(2048, 2, 2048)
                p.Position = Vector3.new(0, -80, 0)
                p.Anchored = true
                p.Transparency = 0.6
                p.Color = Color3.new(1, 1, 1)
                p.Material = Enum.Material.Neon
                p.Parent = workspace
                av.part = p
            end
        end)
    else
        if av.part then pcall(function() av.part:Destroy() end) av.part = nil end
    end
end
sh2Conn(RunService.Heartbeat:Connect(function()
    if not S.antiVoidOn then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if hrp.Position.Y > -40 then
        av.lastSafe = hrp.CFrame
    elseif av.lastSafe and hrp.Position.Y < -120 then
        pcall(function() hrp.CFrame = av.lastSafe end)
    end
end))
function setAntiAfk(b)
    S.antiAfkOn = b
    if b then
        if S._afkConn then return end
        S._afkConn = sh2Conn(LP.Idled:Connect(function()
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(0, 0))
            end)
        end))
        toastImpl("Server", "Anti-AFK включён")
    else
        if S._afkConn then S._afkConn:Disconnect() S._afkConn = nil end
    end
end

-- ============================================================
-- AURA (7 видов частиц на персонаже)
-- ============================================================
local AURA_IDS = {
    neverlose = "rbxassetid://97658130917593",
    nebula    = "rbxassetid://93075928654881",
    hexagram  = "rbxassetid://97100803357010",
    sparkles  = "rbxassetid://99539945533391",
    lightning = "rbxassetid://78451820877953",
    purple    = "rbxassetid://140229739719868",
    dust      = "rbxassetid://133796497599887",
}
local auraObj = nil
local function auraDestroy()
    if auraObj then pcall(function() auraObj:Destroy() end) auraObj = nil end
end
local function auraAttach(char)
    auraDestroy()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local id = AURA_IDS[S.auraType] or AURA_IDS.neverlose
    local ok, objs = pcall(function() return game:GetObjects(id) end)
    if not ok or not objs or not objs[1] then
        warn("[spermahub] aura: не удалось загрузить ассет")
        return
    end
    local obj = objs[1]
    pcall(function()
        for _, v in ipairs(obj:GetDescendants()) do
            if v:IsA("ParticleEmitter") then
                v.Rate = 100
                v.ZOffset = 0.5
            end
        end
        obj.Parent = hrp
    end)
    auraObj = obj
end
function setAura(b)
    S.auraOn = b
    if b then
        if LP.Character then auraAttach(LP.Character) end
    else
        auraDestroy()
    end
end
sh2Conn(LP.CharacterAdded:Connect(function(c)
    if not S.auraOn then return end
    c:WaitForChild("HumanoidRootPart", 5)
    task.wait(0.5)
    if S.auraOn then auraAttach(c) end
end))

-- ============================================================
-- DEATH FX (любой игрок: Emitter / Particles / Clone)
-- ============================================================
local dfxConns = {}
local function dfxCloneFade(char)
    pcall(function()
        char.Archivable = true
        local cl = char:Clone()
        cl.Name = "SpermaDeathClone"
        for _, v in ipairs(cl:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Animator") then
                v:Destroy()
            elseif v:IsA("BasePart") then
                v.Anchored = true
                v.CanCollide = false
                v.CanQuery = false
                v.Material = Enum.Material.Neon
                v.Color = Color3.fromRGB(170, 85, 255)
            end
        end
        local hum = cl:FindFirstChildOfClass("Humanoid")
        if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
        cl.Parent = workspace
        task.delay(1.2, function()
            for i = 0, 1, 0.08 do
                for _, v in ipairs(cl:GetDescendants()) do
                    if v:IsA("BasePart") then v.Transparency = i end
                end
                task.wait(0.05)
            end
            pcall(function() cl:Destroy() end)
        end)
    end)
end
local function dfxBurst(pos)
    pcall(function()
        local p = Instance.new("Part")
        p.Anchored = true p.CanCollide = false p.CanQuery = false p.Transparency = 1
        p.Size = Vector3.new(1, 1, 1)
        p.Position = pos
        p.Parent = workspace
        local imgs = {
            "rbxassetid://12111656021", -- nova
            "rbxassetid://12109095554", -- wisp
            "rbxassetid://448336257",   -- lines
        }
        for _, tx in ipairs(imgs) do
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = tx
            pe.Rate = 0
            pe.Speed = NumberRange.new(20, 60)
            pe.Lifetime = NumberRange.new(0.4, 0.9)
            pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
            pe.Color = ColorSequence.new(Color3.fromRGB(170, 85, 255), Color3.fromRGB(90, 40, 160))
            pe.LightEmission = 1
            pe.Parent = p
            pe:Emit(14)
        end
        task.delay(1.4, function() pcall(function() p:Destroy() end) end)
    end)
end
local function dfxWatch(pl)
    local function hookChar(c)
        task.spawn(function()
            local hum = c:WaitForChild("Humanoid", 8)
            if not hum then return end
            hum.Died:Connect(function()
                if not S.deathFxOn then return end
                if S.deathFxType == "Clone" then
                    dfxCloneFade(c)
                else -- Emitter / Particles
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if hrp then dfxBurst(hrp.Position) end
                end
            end)
        end)
    end
    if pl.Character then hookChar(pl.Character) end
    table.insert(dfxConns, pl.CharacterAdded:Connect(hookChar))
end
for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LP then dfxWatch(pl) end
end
sh2Conn(Players.PlayerAdded:Connect(dfxWatch))
sh2Conn(LP.CharacterAdded:Connect(function(c)
    -- себя тоже
    task.spawn(function()
        local hum = c:WaitForChild("Humanoid", 8)
        if not hum then return end
        hum.Died:Connect(function()
            if not S.deathFxOn then return end
            if S.deathFxType == "Clone" then dfxCloneFade(c) end
        end)
    end)
end))

-- ============================================================
-- FAKE KORBLOX + FAKE HEADLESS (морфы)
-- ============================================================
local KORBLOX_IDS = {mesh = "rbxassetid://902942093", tex1 = "rbxassetid://902942096", tex2 = "rbxassetid://902843398"}
function applyFakeKorblox()
    local char = LP.Character
    if not char then return end
    pcall(function()
        local rll = char:FindFirstChild("RightLowerLeg")
        local rfl = char:FindFirstChild("RightFoot")
        local rul = char:FindFirstChild("RightUpperLeg")
        if rll then
            local m = rll:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", rll)
            m.MeshId = KORBLOX_IDS.mesh
            m.TextureId = KORBLOX_IDS.tex1
            rll.Color = Color3.fromRGB(60, 120, 255)
        end
        if rfl then
            local m = rfl:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", rfl)
            m.MeshId = KORBLOX_IDS.mesh
            m.TextureId = KORBLOX_IDS.tex2
        end
        if rul then
            rul.Transparency = 0
        end
    end)
    toastImpl("Morph", "Fake Korblox применён")
end
function applyFakeHeadless()
    local char = LP.Character
    if not char then return end
    pcall(function()
        local head = char:FindFirstChild("Head")
        if not head then return end
        local m = head:FindFirstChildOfClass("SpecialMesh")
        if m then
            m.MeshId = "rbxassetid://6686307858"
            m.TextureId = ""
            m.Scale = Vector3.new(1, 1, 1)
        else
            head.Transparency = 1
            for _, v in ipairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency = 1 end
            end
        end
    end)
    toastImpl("Morph", "Fake Headless применён")
end

-- ============================================================
-- SH2 cleanup
-- ============================================================
function sh2Cleanup()
    for _, c in ipairs(SH2.conns) do pcall(function() c:Disconnect() end) end
    SH2.conns = {}
    bt2Destroy()
    auraDestroy()
    if fp.marker then pcall(function() fp.marker:Destroy() end) fp.marker = nil end
    if av.part then pcall(function() av.part:Destroy() end) av.part = nil end
    if ps.plat then pcall(function() ps.plat:Destroy() end) ps.plat = nil end
end

-- ============================================================
-- WEAPON MOD (rev35): Rapid Fire + No Spread + No Recoil
-- ============================================================
local WeaponMod = {
    Settings = {
        RapidFire = {
            Enabled = false,
            Multiplier = 2.0,
            InstantReload = false,
            ReloadCancel = false,
        },
        NoSpread = { Enabled = false, Mode = "Full", Value = 0 },
        NoRecoil = { Enabled = false, Mode = "Full", Vertical = 0, Horizontal = 0 },
    },
    State = {
        OriginalFireRate = {}, OriginalSpread = {}, OriginalRecoil = {},
        Connections = {},
    },
}
local WeaponModRS = game:GetService("RunService")
local WeaponModLP = game:GetService("Players").LocalPlayer

local function wmGetTool()
    local char = WeaponModLP.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function wmGetWeaponStats(tool)
    if not tool then return nil end
    return tool:FindFirstChild("Stats")
        or tool:FindFirstChild("Configuration")
        or tool:FindFirstChild("WeaponStats")
        or tool:FindFirstChild("Settings")
end

local function wmForEachNumber(tool, cb)
    local stats = wmGetWeaponStats(tool)
    local root = stats or tool
    for _, obj in ipairs(root:GetDescendants()) do
        cb(obj)
    end
end

function WeaponMod:EnableRapidFire()
    if self.State.Connections.RapidFire then return end
    self.State.Connections.RapidFire = WeaponModRS.Heartbeat:Connect(function()
        if not self.Settings.RapidFire.Enabled then return end
        local tool = wmGetTool()
        if not tool then return end
        wmForEachNumber(tool, function(obj)
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                local name = obj.Name:lower()
                if name:find("firerate") or name:find("fire_rate") or name:find("rpm") or name:find("speed") then
                    if not self.State.OriginalFireRate[obj] then
                        self.State.OriginalFireRate[obj] = obj.Value
                    end
                    obj.Value = self.State.OriginalFireRate[obj] * self.Settings.RapidFire.Multiplier
                end
                if self.Settings.RapidFire.InstantReload then
                    if name:find("reload") and not name:find("ammo") then
                        if not self.State.OriginalFireRate[obj] then
                            self.State.OriginalFireRate[obj] = obj.Value
                        end
                        obj.Value = 0.1
                    end
                end
            end
        end)
    end)

    if self.Settings.RapidFire.ReloadCancel then
        self.State.Connections.ReloadCancel = WeaponModRS.Heartbeat:Connect(function()
            local tool = wmGetTool()
            if not tool then return end
            local anim = tool:FindFirstChild("ReloadAnimation")
                or tool:FindFirstChild("Reload")
                or tool:FindFirstChildWhichIsA("Animation")
            if anim and anim.IsPlaying then
                task.delay(0.15, function()
                    pcall(function()
                        if anim.IsPlaying then anim:Stop() end
                    end)
                end)
            end
        end)
    end
end

function WeaponMod:DisableRapidFire()
    if self.State.Connections.RapidFire then
        self.State.Connections.RapidFire:Disconnect()
        self.State.Connections.RapidFire = nil
    end
    if self.State.Connections.ReloadCancel then
        self.State.Connections.ReloadCancel:Disconnect()
        self.State.Connections.ReloadCancel = nil
    end
    for obj, original in pairs(self.State.OriginalFireRate) do
        if obj and obj.Parent then obj.Value = original end
    end
    self.State.OriginalFireRate = {}
end

function WeaponMod:EnableNoSpread()
    if self.State.Connections.NoSpread then return end
    self.State.Connections.NoSpread = WeaponModRS.Heartbeat:Connect(function()
        if not self.Settings.NoSpread.Enabled then return end
        local tool = wmGetTool()
        if not tool then return end

        local zoom = false
        local char = WeaponModLP.Character
        local head = char and char:FindFirstChild("Head")
        if head then
            zoom = (head.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 1
        end
        if self.Settings.NoSpread.Mode == "ADS Only" and not zoom then return end
        if self.Settings.NoSpread.Mode == "Hip Only" and zoom then return end

        wmForEachNumber(tool, function(obj)
            local name = obj.Name:lower()
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                if name:find("spread") or name:find("accuracy") or name:find("dispersion") or name:find("cone") then
                    if not self.State.OriginalSpread[obj] then
                        self.State.OriginalSpread[obj] = obj.Value
                    end
                    obj.Value = self.Settings.NoSpread.Value
                end
            elseif obj:IsA("Vector3Value") then
                if name:find("spread") or name:find("kick") then
                    if not self.State.OriginalSpread[obj] then
                        self.State.OriginalSpread[obj] = obj.Value
                    end
                    obj.Value = Vector3.new(0, 0, 0)
                end
            end
        end)
    end)
end

function WeaponMod:DisableNoSpread()
    if self.State.Connections.NoSpread then
        self.State.Connections.NoSpread:Disconnect()
        self.State.Connections.NoSpread = nil
    end
    for obj, original in pairs(self.State.OriginalSpread) do
        if obj and obj.Parent then obj.Value = original end
    end
    self.State.OriginalSpread = {}
end

function WeaponMod:EnableNoRecoil()
    if self.State.Connections.NoRecoil then return end
    local camera = workspace.CurrentCamera
    local lastCF = camera.CFrame
    self.State.Connections.NoRecoil = WeaponModRS.RenderStepped:Connect(function()
        if not self.Settings.NoRecoil.Enabled then
            lastCF = camera.CFrame
            return
        end
        local tool = wmGetTool()
        if not tool then
            lastCF = camera.CFrame
            return
        end
        local mode = self.Settings.NoRecoil.Mode
        local delta = camera.CFrame:Inverse() * lastCF
        local _, _, _, _, y, z = delta:GetComponents()
        local compensation = CFrame.new(0, 0, 0)
        if mode == "Full" or mode == "Vertical Only" then
            compensation = compensation * CFrame.Angles(0, 0, -y * self.Settings.NoRecoil.Vertical)
        end
        if mode == "Full" or mode == "Horizontal Only" then
            compensation = compensation * CFrame.Angles(-z * self.Settings.NoRecoil.Horizontal, 0, 0)
        end
        camera.CFrame = camera.CFrame * compensation
        wmForEachNumber(tool, function(obj)
            local name = obj.Name:lower()
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                if name:find("recoil") or name:find("kick") or name:find("camera") then
                    if not self.State.OriginalRecoil[obj] then
                        self.State.OriginalRecoil[obj] = obj.Value
                    end
                    if mode == "Full" or name:find("vertical") or name:find("up") then
                        obj.Value = self.State.OriginalRecoil[obj] * self.Settings.NoRecoil.Vertical
                    end
                    if mode == "Full" or name:find("horizontal") or name:find("side") then
                        obj.Value = self.State.OriginalRecoil[obj] * self.Settings.NoRecoil.Horizontal
                    end
                end
            elseif obj:IsA("Vector3Value") then
                if name:find("recoil") or name:find("kick") then
                    if not self.State.OriginalRecoil[obj] then
                        self.State.OriginalRecoil[obj] = obj.Value
                    end
                    local orig = self.State.OriginalRecoil[obj]
                    obj.Value = Vector3.new(orig.X * self.Settings.NoRecoil.Horizontal, orig.Y * self.Settings.NoRecoil.Vertical, orig.Z)
                end
            end
        end)
        lastCF = camera.CFrame
    end)
end

function WeaponMod:DisableNoRecoil()
    if self.State.Connections.NoRecoil then
        self.State.Connections.NoRecoil:Disconnect()
        self.State.Connections.NoRecoil = nil
    end
    for obj, original in pairs(self.State.OriginalRecoil) do
        if obj and obj.Parent then obj.Value = original end
    end
    self.State.OriginalRecoil = {}
end

getgenv().SpermaHubWeaponMod = WeaponMod

-- ---------------- AIMBOT (категория) ----------------
addCategory("Combat")

-- ==== 🔫 Weapon (Rapid Fire / Spread / Recoil) rev35 ====
do
    local pg = addPage("Combat", "🔫", "Weapon")

    local pRF = addPanel(pg.col1, "⚡ Rapid Fire")
    addToggle(pRF, "weap.rapidfire", "Rapid Fire", false, function(state)
        WeaponMod.Settings.RapidFire.Enabled = state
        if state then WeaponMod:EnableRapidFire() else WeaponMod:DisableRapidFire() end
    end)
    addSlider(pRF, "weap.frmult", "Fire Rate Multiplier", 1, 5, 2, 0.5, function(v)
        WeaponMod.Settings.RapidFire.Multiplier = v
    end)
    addToggle(pRF, "weap.instantreload", "Instant Reload", false, function(state)
        WeaponMod.Settings.RapidFire.InstantReload = state
    end)
    addToggle(pRF, "weap.reloadcancel", "Reload Cancel", false, function(state)
        WeaponMod.Settings.RapidFire.ReloadCancel = state
        if WeaponMod.Settings.RapidFire.Enabled then
            WeaponMod:DisableRapidFire()
            WeaponMod:EnableRapidFire()
        end
    end)
    addDropdown(pRF, nil, "Multiplier Preset", {"1.5", "2", "3", "5"}, "2", function(v)
        local c = Cfg["weap.frmult"]
        if c then c.set(tonumber(v)) end
    end)
    addText(pRF, "Multiplies FireRate значения оружия (Tool/Stats). InstantReload вгоняет reload в 0.1. ReloadCancel обрезает анимацию перезарядки.")

    local pNS = addPanel(pg.col2, "🎯 Spread Control")
    addToggle(pNS, "weap.nospread", "No Spread", false, function(state)
        WeaponMod.Settings.NoSpread.Enabled = state
        if state then WeaponMod:EnableNoSpread() else WeaponMod:DisableNoSpread() end
    end)
    addDropdown(pNS, "weap.spreadmode", "Spread Mode", {"Full", "ADS Only", "Hip Only"}, "Full", function(v)
        WeaponMod.Settings.NoSpread.Mode = v
    end)

    local pNR = addPanel(pg.col2, "📉 Recoil Control")
    addToggle(pNR, "weap.norecoil", "No Recoil", false, function(state)
        WeaponMod.Settings.NoRecoil.Enabled = state
        if state then WeaponMod:EnableNoRecoil() else WeaponMod:DisableNoRecoil() end
    end)
    addDropdown(pNR, "weap.recoilmode", "Recoil Mode", {"Full", "Vertical Only", "Horizontal Only"}, "Full", function(v)
        WeaponMod.Settings.NoRecoil.Mode = v
    end)
    addSlider(pNR, "weap.vrecoil", "Vertical Recoil % (0 = нет)", 0, 100, 0, 5, function(v)
        WeaponMod.Settings.NoRecoil.Vertical = v / 100
    end)
    addSlider(pNR, "weap.hrecoil", "Horizontal Recoil % (0 = нет)", 0, 100, 0, 5, function(v)
        WeaponMod.Settings.NoRecoil.Horizontal = v / 100
    end)
    addText(pNR, "Компенсация отдачи через камеру + нейтрализация recoil-значений внутри оружия. Если античит козлит — ставь % побольше и режим Full.")
end

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
        -- ESP MAX читает S.teamCheck каждый тик и сам прячет свою команду
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
    addDropdown(pTarget, "fling.mode", "Mode", {"Velocity Burst", "Stick TP", "Skid Fling"}, "Skid Fling", function(v)
        S.flingMode = v
    end)
    addDropdown(pTarget, "fling.scope", "Scope (Auto Fling)", {"Selected", "All Lobby"}, "Selected", function(v)
        S.flingScope = v
    end)
    addSlider(pTarget, "fling.duration", "Stick Duration", 3, 10, 5, 1, function(v)
        S.flingDur = math.floor(v)
    end)
    addSlider(pTarget, "fling.skiddur", "Skid Duration (с на цель)", 0.5, 4, 2, 0.5, function(v)
        S.skidDur = v
    end)
    addSlider(pTarget, "fling.cycledelay", "Auto Fling Cycle Delay", 0.2, 2, 0.5, 0.1, function(v)
        S.flingCycleDelay = v
    end)
    addButton(pTarget, "Fling Target", function()
        local plr = flingSel and Players:FindFirstChild(flingSel)
        if plr then
            if S.flingMode == "Stick TP" then
                flingStickyPlayer(plr, S.flingDur)
                toastImpl("Fling", "Стик-флинг (" .. tostring(S.flingDur) .. " сек): " .. plr.Name)
            elseif S.flingMode == "Velocity Burst" then
                flingPlayer(plr)
                toastImpl("Fling", "Флингую: " .. plr.Name)
            else
                toastImpl("Fling", "SKID-флинг (" .. tostring(S.skidDur) .. " с): " .. plr.Name)
                task.spawn(function() skidFling(plr, false) end)
            end
        else
            toastImpl("Fling", "Сначала выбери цель!")
        end
    end, C_RED, C_RED_H)
    addToggle(pTarget, "fling.auto", "START FLING (Auto, по Scope)", false, function(state)
        setAutoFling(state)
        if state then
            toastImpl("Fling", "Auto Fling STARTED — Scope: " .. tostring(S.flingScope))
        else
            toastImpl("Fling", "Auto Fling STOPPED")
        end
    end)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Skid Fling — порт KILASIK/zqyDSUWX 1:1: на N сек впечатываемся в цель (Velocity 9e7/Yx10, RotVelocity 9e8, BodyVelocity-фиксация), FallenParts NaN, спин сверху↔снизу с предиктом по MoveDirection — цель улетает далеко; затем сброс на старую позицию.")
    addText(pInfo, "Auto Fling: цикл по Scope — Selected (из списка) или All Lobby (все по очереди, 0.1с между, 0.5с между кругами). STOP — тот же тогл. Сидящая цель пропускается.")
    addText(pInfo, "Stick TP — телепорт на цель + клей с Velocity (0, 100000, 0) N сек, затем возврат. Velocity Burst — короткий налёт ~0.8с.")
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

-- ==== Anti-Aim (ENI Suite) ====
do
    local pg = addPage("Combat", "🔁", "Anti-Aim")

    local pAa = addPanel(pg.col1, "Anti-Aim")
    addToggle(pAa, "aa.enabled", "Enabled", false, function(state)
        if state then enableAntiAim() else disableAntiAim() end
    end)
    addDropdown(pAa, "aa.mode", "Mode", {"Spin", "Jitter", "Desync", "Random"}, "Spin", function(v)
        S.aaMode = v
    end)
    addToggle(pAa, "aa.visualize", "Visualize (фейк-тело)", true, function(state)
        S.aaVisualize = state
        if state then
            if S.aaOn then aaCreateFake() end
        else
            aaDestroyFake()
        end
    end)
    addDropdown(pAa, "aa.pitch", "Pitch", {"Up", "Down", "Zero", "Random"}, "Up", function(v)
        S.aaPitch = v
    end)

    local pSet = addPanel(pg.col1, "Mode Settings")
    addSlider(pSet, "aa.speed", "Speed (1-50)", 1, 50, 10, 1, function(v)
        S.aaSpeed = math.floor(v)
    end)
    addSlider(pSet, "aa.jitterangle", "Jitter Angle", 90, 180, 180, 1, function(v)
        S.aaJitterAngle = math.floor(v)
    end)
    addSlider(pSet, "aa.desyncoff", "Desync Offset", 0.1, 1, 0.5, 0.05, function(v)
        S.aaDesyncOffset = v
    end)
    addSlider(pSet, "aa.randomrange", "Random Range", 90, 360, 360, 5, function(v)
        S.aaRandomRange = math.floor(v)
    end)

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "ENI Anti-Aim: Spin — непрерывное вращение; Jitter — дёрг 0 <-> угол; Desync — синусовый сдвиг тела ±2 стада; Random — случайный yaw каждый тик.")
    addText(pInfo, "Pitch: Up/Down/Zero/Random. Visualize — полупрозрачная копия персонажа показывает, куда смотрит фейковый рут.")
    addText(pInfo, "Горячая клавиша для вкл/выкл — во вкладке Key Binds (строка Anti-Aim).")
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

-- ============ ESP MAX — ЕДИНСТВЕННЫЙ ESP (FULL SKID 1:1 со скрина) ============
-- чёрный тонкий бокс • НИК+HP над головой • колонка эффектов • трейс-линия
local ESPMX = {
    running = false, frames = {}, conn = nil,
    rate = 20, maxdist = 3000, tsize = 13,
    origin = "Низ экрана", tracerColor = Color3.new(1, 1, 1),
    box = true, names = true, hp = true, effects = true, tracer = true, dist = false,
}

local function espMaxMk(plr)
    local boxOut = Drawing.new("Square")
    boxOut.Filled = false boxOut.Thickness = 3 boxOut.Color = Color3.new(0, 0, 0) boxOut.ZIndex = 2 boxOut.Visible = false
    local boxIn = Drawing.new("Square")
    boxIn.Filled = false boxIn.Thickness = 1 boxIn.Color = Color3.new(1, 1, 1) boxIn.Transparency = 0.7 boxIn.ZIndex = 2 boxIn.Visible = false
    local nameT = Drawing.new("Text")
    nameT.Center = true nameT.Outline = true nameT.ZIndex = 3 nameT.Visible = false
    local hpT = Drawing.new("Text")
    hpT.Center = false hpT.Outline = true hpT.ZIndex = 3 hpT.Visible = false
    local distT = Drawing.new("Text")
    distT.Center = true distT.Outline = true distT.Color = Color3.fromRGB(190, 190, 200) distT.ZIndex = 3 distT.Visible = false
    local eff = {}
    for i = 1, 6 do
        local t = Drawing.new("Text")
        t.Center = false t.Outline = true t.ZIndex = 3 t.Visible = false
        eff[i] = t
    end
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1 tracer.ZIndex = 1 tracer.Visible = false
    ESPMX.frames[plr] = {boxOut = boxOut, boxIn = boxIn, nameT = nameT, hpT = hpT, distT = distT, eff = eff, tracer = tracer}
end

local function espMaxRm(plr)
    local fr = ESPMX.frames[plr]
    if not fr then return end
    for _, d in pairs(fr) do
        if type(d) == "table" then
            for _, t in ipairs(d) do pcall(function() t:Remove() end) end
        else pcall(function() d:Remove() end) end
    end
    ESPMX.frames[plr] = nil
end

local function espMaxHide(fr)
    fr.boxOut.Visible = false fr.boxIn.Visible = false fr.nameT.Visible = false
    fr.hpT.Visible = false fr.distT.Visible = false fr.tracer.Visible = false
    for _, t in ipairs(fr.eff) do t.Visible = false end
end

local function espMaxCollectFr()

    local out = {}
    local myChar = (LP and LP.Character) or nil
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not (S.teamCheck and isTeammate(plr)) then
            local mydist = math.huge
            local ch = plr.Character
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if myRoot and root then mydist = (myRoot.Position - root.Position).Magnitude end
            if ch and mydist <= ESPMX.maxdist then
                table.insert(out, {plr = plr, char = ch, root = root, d = mydist})
            end
        end
    end
    return out
end

local function espMaxEffects(plr, char)
    local lines = {}
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then table.insert(lines, {"⚔ " .. tostring(tool.Name), Color3.fromRGB(255, 215, 0)}) end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local ws = hum.WalkSpeed
        if math.abs(ws - 16) > 0.5 then table.insert(lines, {"Скорость " .. tostring(math.floor(ws + 0.5)), Color3.fromRGB(160, 220, 255)}) end
        local jp = hum.JumpPower
        if math.abs(jp - 50) > 0.5 then table.insert(lines, {"Прыжок " .. tostring(math.floor(jp + 0.5)), Color3.fromRGB(160, 220, 255)}) end
    end
    local okA, attrs = pcall(function() return char:GetAttributes() end)
    if okA and type(attrs) == "table" then
        local names = {}
        for n in pairs(attrs) do table.insert(names, n) end
        table.sort(names)
        for _, n in ipairs(names) do
            if #lines >= 6 then break end
            local nl = tostring(n):lower()
            if type(n) == "string" and #n <= 28
                and not nl:find("sperma") and not nl:find("respawn") and not nl:find("invincib") then
                local v = attrs[n]
                if type(v) == "number" then v = math.floor(v * 100 + 0.5) / 100 end
                local line = tostring(n)
                if type(v) ~= "boolean" then line = line .. " " .. tostring(v) end
                table.insert(lines, {line, Color3.fromRGB(200, 200, 220)})
            end
        end
    end
    return lines
end

local function espMaxTick()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    for _, pack in ipairs(espMaxCollectFr()) do
        local plr, char, root, dist = pack.plr, pack.char, pack.root, pack.d
        local fr = ESPMX.frames[plr]
        if not fr then espMaxMk(plr) fr = ESPMX.frames[plr] end
        if not root then
            espMaxHide(fr)
        else
        local ts = ESPMX.tsize
        fr.nameT.Size = ts fr.hpT.Size = ts fr.distT.Size = ts - 2
        for _, t in ipairs(fr.eff) do t.Size = ts - 2 end

        local posTop = root.Position + Vector3.new(0, 3, 0)
        local posBot = root.Position + Vector3.new(0, -3.5, 0)
        local sTop, visTop = cam:WorldToViewportPoint(posTop)
        local sBot = nil
        local _vis2
        local sTop2
        local sBotV = cam:WorldToViewportPoint(posBot)
        sBot = select(1, sBotV)
        if not visTop then espMaxHide(fr) else
        local cx, topY, botY = sTop.X, sTop.Y, sBot.Y
        local h = math.abs(botY - topY)
        if h < 6 then espMaxHide(fr) else
        local w = h * 0.62
        local x, y = cx - w / 2, topY

        -- 1) БОКС (чёрный двойной — 1:1)
        if ESPMX.box then
            local fr = fr
            fr.boxOut.Position = Vector2.new(x, y) fr.boxOut.Size = Vector2.new(w, h) fr.boxOut.Visible = true
            fr.boxIn.Position = Vector2.new(x, y) fr.boxIn.Size = Vector2.new(w, h) fr.boxIn.Visible = true
        else fr.boxOut.Visible = false fr.boxIn.Visible = false end

        -- 2) ИМЯ + HP над головой
        if ESPMX.names then
            local tag = ""
            local tagCol = Color3.new(1, 1, 1)
            local okF, isF = pcall(function() return LP:IsFriendsWith(plr.UserId) end)
            if okF and isF then tag = "[F] " tagCol = Color3.fromRGB(255, 200, 90) end
            fr.nameT.Text = tag .. plr.Name
            fr.nameT.Color = tagCol
            fr.nameT.Position = Vector2.new(cx, topY - ts - 4)
            fr.nameT.Visible = true
            if ESPMX.hp then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hp = hum and hum.Health or 0
                local mx = hum and math.max(hum.MaxHealth, 1) or 100
                local k = math.clamp(hp / mx, 0, 1)
                fr.hpT.Text = tostring(math.floor(hp + 0.5)) .. "HP"
                fr.hpT.Color = Color3.new(1 - k, k * 0.9, 0.15)
                local nameW = fr.nameT.TextBounds.X
                fr.hpT.Position = Vector2.new(cx + nameW / 2 + 6, topY - ts - 4)
                fr.hpT.Visible = true
            else fr.hpT.Visible = false end
        else fr.nameT.Visible = false fr.hpT.Visible = false end

        -- 3) ЭФФЕКТЫ справа от бокса (1:1 колонка)
        if ESPMX.effects then
            local lines = espMaxEffects(plr, char)
            for i, t in ipairs(fr.eff) do
                local ln = lines[i]
                if ln then
                    t.Text = ln[1] t.Color = ln[2]
                    t.Position = Vector2.new(x + w + 4, topY + (i - 1) * (ts - 1))
                    t.Visible = true
                else t.Visible = false end
            end
        else for _, t in ipairs(fr.eff) do t.Visible = false end end

        -- 4) ТРЕЙС (от низа экрана — 1:1)
        if ESPMX.tracer then
            local ox = (ESPMX.origin == "Низ экрана") and vp.Y or (ESPMX.origin == "Верх экрана") and 0 or vp.Y / 2
            fr.tracer.From = Vector2.new(vp.X / 2, ox)
            fr.tracer.To = Vector2.new(cx, botY)
            fr.tracer.Color = ESPMX.tracerColor
            fr.tracer.Visible = true
        else fr.tracer.Visible = false end

        -- 5) Дистанция (опционально)
        if ESPMX.dist then
            fr.distT.Text = tostring(math.floor(dist)) .. "m"
            fr.distT.Position = Vector2.new(cx, botY + 2)
            fr.distT.Visible = true
        else fr.distT.Visible = false end
        end -- h>=6
        end -- visTop
        end -- root
    end
end

local function espMaxStart()
    if ESPMX.running then return end
    if not (Drawing and Drawing.new) then warn("[SpermaHub] Drawing API недоступен — ESP MAX выключен") return end
    local ok = pcall(function()
        for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LP then espMaxMk(plr) end end
    end)
    if not ok then warn("[SpermaHub] Drawing API: объект не создался — ESP MAX выключен") return end
    ESPMX.running = true
    task.spawn(function()
        while ESPMX.running do
            local okT = pcall(function() espMaxTick() end)
            if not okT then
                for _, fr in pairs(ESPMX.frames) do pcall(function() espMaxHide(fr) end) end
            end
            task.wait(1 / math.max(5, ESPMX.rate))
        end
    end)
end

local function espMaxStop()
    ESPMX.running = false
    task.wait(0.05)
    for plr, fr in pairs(ESPMX.frames) do espMaxHide(fr) espMaxRm(plr) end
end

Players.PlayerRemoving:Connect(function(plr) pcall(function() espMaxRm(plr) end) end)
Players.PlayerAdded:Connect(function(plr) if ESPMX.running then pcall(function() espMaxMk(plr) end) end end)

-- ==== Players (ESP) — FULL SKID 1:1 со скрина ====
do
    local pg = addPage("Visuals", "👤", "Players")

    local pEsp = addPanel(pg.col1, "ESP (1:1 skid)")
    addToggle(pEsp, "esp.enabled", "Enabled", false, function(state)
        S.esp = state
        if state then espMaxStart() else espMaxStop() end
    end)
    addSlider(pEsp, "esp.maxdist", "Дальность", 100, 5000, 3000, 50, function(v)
        ESPMX.maxdist = math.floor(v)
    end)
    addSlider(pEsp, "esp.rate", "Частота обновления (FPS)", 5, 60, 20, 5, function(v)
        ESPMX.rate = math.floor(v)
    end)
    addSlider(pEsp, "esp.tsize", "Размер текста", 10, 20, 13, 1, function(v)
        ESPMX.tsize = math.floor(v)
    end)
    addText(pEsp, "Единственный ESP клиента: чистый Drawing-движок, стиль точ-в-точ со скрина. Team Check (вкладка Aimbot) прячет свою команду.")

    local pComp = addPanel(pg.col1, "Components")
    addToggle(pComp, "esp.box", "Тонкий чёрный Box", true, function(v) ESPMX.box = v end)
    addToggle(pComp, "esp.names", "НИК над головой", true, function(v) ESPMX.names = v end)
    addToggle(pComp, "esp.hp", "HP (цвет по жизни)", true, function(v) ESPMX.hp = v end)
    addToggle(pComp, "esp.effects", "Эффекты справа от бокса", true, function(v) ESPMX.effects = v end)
    addToggle(pComp, "esp.tracer", "Tracer (белая линия)", true, function(v) ESPMX.tracer = v end)
    addToggle(pComp, "esp.dist", "Дистанция под ногами", false, function(v) ESPMX.dist = v end)

    local pTr = addPanel(pg.col2, "Tracer")
    addDropdown(pTr, "esp.tracerorigin", "Линия откуда", {"Низ экрана", "Верх экрана", "Центр"}, "Низ экрана", function(v)
        ESPMX.origin = v
    end)
    addText(pTr, "Тег [F] золотой = друг. Эффекты: ⚔ оружие в руке, скорость/прыжок если кручены, атрибуты персонажа — до 6 строк.")

    local pTgt = addPanel(pg.col2, "Target ESP")
    addToggle(pTgt, "esp.target", "Enabled (Highlight)", false, function(state)
        if state then enableTargetESP() else disableTargetESP() end
    end)
    addDropdown(pTgt, "esp.targetstyle", "Color", {"Pink", "Purple", "Red", "Gold"}, "Pink", function(v)
        S.targetStyle = v
    end)
    addToggle(pTgt, "esp.targethud", "Target HUD (скид с фото)", false, function(state)
        if state then enableTargetHUD() else disableTargetHUD() end
    end)
    addText(pTgt, "Highlight — пульсирующая подсветка модели. Target HUD — красная скруглённая плашка над головой цели: НИК + HP: x.x + зелёный HP-бар (1:1 с референса). Цель берётся из Aimbot / Silent Aim.")

    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Полный аналог ESP из референса: чёрный двойной бокс (3px контур + 1px внутр. белый), «НИК 24HP» над головой, колонка эффектов справа от бокса, белая линия от низа экрана к боксу. Всё на Drawing API — работает даже там, где ScreenGui заблокирован.")
end

-- ==== World (Watermark) ====
do
    local pg = addPage("Visuals", "🌐", "World")

    local pHud = addPanel(pg.col1, "Interface")


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
    addText(pInfo, "HUD-элементы убраны — меню только Rayfield.")

    local pCam = addPanel(pg.col1, "Camera")
    addToggle(pCam, "world.customfov", "Custom FOV", false, function(state)
        S.customFovOn = state
        if state then applyCustomFov() else removeCustomFov() end
    end)
    addSlider(pCam, "world.customfov.val", "FOV", 30, 120, 70, 1, function(v)
        S.customFov = v
        if S.customFovOn then applyCustomFov() end
    end)
    addToggle(pCam, "world.aspect", "Aspect Ratio", false, function(state)
        S.aspectOn = state
        if state then applyAspect() else removeAspect() end
    end)
    addSlider(pCam, "world.aspect.val", "Stretch %", 1, 100, 100, 1, function(v)
        S.aspectVal = v
        if S.aspectOn then applyAspect() end
    end)
    addText(pCam, "Custom FOV — своё поле зрения (зум). Aspect — растягивает картинку по вертикали (тело стройнее).")

    local pCross = addPanel(pg.col1, "Crosshair")
    addToggle(pCross, "world.crosshair", "Enabled", false, function(state)
        if state then enableCrosshair() else disableCrosshair() end
    end)
    addSlider(pCross, "world.crosshair.gap", "Gap", 0, 20, 4, 1, function(v) updateCrosshairStyle("gap", v) end)
    addSlider(pCross, "world.crosshair.len", "Line Length", 2, 30, 8, 1, function(v) updateCrosshairStyle("len", v) end)
    addSlider(pCross, "world.crosshair.thick", "Thickness", 1, 5, 2, 1, function(v) updateCrosshairStyle("thick", v) end)
    addSlider(pCross, "world.crosshair.rot", "Rotation Speed", 0, 10, 0, 1, function(v) updateCrosshairStyle("rot", v) end)
    addDropdown(pCross, nil, "Line Color", {"White", "Red", "Green", "Cyan", "Purple"}, "White", function(v)
        local t = {White = Color3.fromRGB(255,255,255), Red = Color3.fromRGB(255,60,60), Green = Color3.fromRGB(80,255,120), Cyan = Color3.fromRGB(0,220,255), Purple = Color3.fromRGB(170,85,255)}
        updateCrosshairStyle("col", t[v] or t.White)
    end)
    addText(pCross, "Прицел у курсора с обводкой и вращением.")

    local pLight = addPanel(pg.col1, "Lighting")
    addToggle(pLight, "world.fullbright", "Fullbright", false, function(state) setFullbright(state) end)
    addToggle(pLight, "world.fog", "Custom Fog", false, function(state) setFog(state) end)
    addDropdown(pLight, nil, "Fog Color", {"Gray", "White", "Pink", "Blue", "Purple", "Black"}, "Gray", function(v)
        local t = {Gray = Color3.fromRGB(192,192,192), White = Color3.fromRGB(255,255,255), Pink = Color3.fromRGB(255,170,200), Blue = Color3.fromRGB(150,190,255), Purple = Color3.fromRGB(190,150,255), Black = Color3.fromRGB(15,15,20)}
        setFogColor(t[v] or t.Gray)
    end)
    addSlider(pLight, "world.fog.start", "Fog Start", 0, 1000, 0, 10, function(v) setFogStart(v) end)
    addSlider(pLight, "world.fog.end", "Fog End", 0, 1000, 1000, 10, function(v) setFogEnd(v) end)
    addToggle(pLight, "world.ambient", "Custom Ambient", false, function(state) setAmbient(state) end)
    addDropdown(pLight, nil, "Ambient Color", {"Gray", "White", "Warm", "Cold", "Purple"}, "Gray", function(v)
        local t = {Gray = Color3.fromRGB(128,128,128), White = Color3.fromRGB(220,220,220), Warm = Color3.fromRGB(180,140,100), Cold = Color3.fromRGB(120,160,200), Purple = Color3.fromRGB(150,110,200)}
        setAmbientColor(t[v] or t.Gray)
    end)
    addToggle(pLight, "world.exposure", "Exposure", false, function(state) setExposure(state) end)
    addSlider(pLight, "world.exposure.val", "Exposure Value", -5, 5, 0, 0.1, function(v) setExposureVal(v) end)
    addToggle(pLight, "world.time", "Time Changer", false, function(state) setTimeChanger(state) end)
    addSlider(pLight, "world.time.val", "Time", 0, 24, 12, 0.5, function(v) setTimeVal(v) end)

    local pShader = addPanel(pg.col2, "Shaders / Skybox")
    addToggle(pShader, "world.shaders", "Shaders", false, function(state) setShaders(state) end)
    addDropdown(pShader, "world.shaders.type", "Preset", {"morning", "midday", "evening", "night"}, "morning", function(v) setShaderType(v) end)
    addToggle(pShader, "world.skybox", "Skybox", false, function(state) setSkybox(state) end)
    addDropdown(pShader, "world.skybox.name", "Skybox Preset", {"Jungle", "Blossom", "Red night", "Purple default", "Foggy", "Galaxy", "Anime", "Minecraft"}, "Jungle", function(v) setSkyboxName(v) end)
    addText(pShader, "Shaders — готовые пресеты картинки (освещение/эффекты/атмосфера). При отключении всё возвращается как было.")

    local pWFx = addPanel(pg.col2, "World Effects")
    addToggle(pWFx, "world.fx", "Enabled", false, function(state) setWorldFx(state) end)
    addDropdown(pWFx, "world.fx.type", "Preset", {"Snow", "Sakura"}, "Snow", function(v) setWorldFxType(v) end)
    addDropdown(pWFx, nil, "Color", {"Pale", "White", "Pink", "Blue", "Green"}, "Pale", function(v)
        local t = {Pale = Color3.fromRGB(150,200,255), White = Color3.fromRGB(255,255,255), Pink = Color3.fromRGB(255,170,200), Blue = Color3.fromRGB(150,170,255), Green = Color3.fromRGB(160,255,190)}
        setWorldFxColor(t[v] or t.Pale)
    end)
    addSlider(pWFx, "world.fx.rate", "Density", 20, 900, 250, 10, function(v) setWorldFxRate(v) end)
    addText(pWFx, "Снег/сакура вокруг камеры (короб частиц следует за взглядом). Density — интенсивность потока.")
end

-- ==== Local (self visuals) ====
do
    local pg = addPage("Visuals", "✦", "Local")

    local pHat = addPanel(pg.col1, "China Hat")
    addToggle(pHat, "local.chinahat", "Enabled", false, function(state)
        S.chinaHatOn = state
        if state then ensureChinaHatVis() else disableChinaHat() end
    end)
    addSlider(pHat, "local.chinahat.r", "Red", 0, 1, 0.67, 0.01, function(v)
        local r, g, b = v, S.chinaHatColor.G, S.chinaHatColor.B
        S.chinaHatColor = Color3.new(r, g, b)
    end)
    addSlider(pHat, "local.chinahat.g", "Green", 0, 1, 0.33, 0.01, function(v)
        local r, g, b = S.chinaHatColor.R, v, S.chinaHatColor.B
        S.chinaHatColor = Color3.new(r, g, b)
    end)
    addSlider(pHat, "local.chinahat.b", "Blue", 0, 1, 1, 0.01, function(v)
        local r, g, b = S.chinaHatColor.R, S.chinaHatColor.G, v
        S.chinaHatColor = Color3.new(r, g, b)
    end)
    addText(pHat, "Пиксельный «китайский колпак» над головой (рисуется поверх экрана, видит весь лобби).")

    local pBt = addPanel(pg.col1, "Backtrack")
    addToggle(pBt, "local.backtrack", "Enabled", false, function(state)
        setBacktrack(state)
    end)
    addDropdown(pBt, nil, "Color", {"Red", "Cyan", "Purple", "White", "Green"}, "Red", function(v)
        local t = {Red = Color3.fromRGB(255,60,60), Cyan = Color3.fromRGB(0,200,255), Purple = Color3.fromRGB(170,85,255), White = Color3.fromRGB(240,240,240), Green = Color3.fromRGB(90,255,140)}
        refreshBacktrackColor(t[v] or t.Red)
    end)
    addText(pBt, "Полупрозрачный клон твоего персонажа — показывает, где сервер видит тебя на самом деле (сдвиг на пинг).")

    local pSc = addPanel(pg.col1, "Self Chams")
    addToggle(pSc, "local.selfchams", "Enabled", false, function(state)
        setSelfChams(state)
    end)
    addDropdown(pSc, "local.selfchams.type", "Type", {"ForceField", "Flat", "Chromatic"}, "ForceField", function(v)
        S.selfChamsType = v
        if S.selfChamsOn then setSelfChams(false) setSelfChams(true) end
    end)
    addDropdown(pSc, nil, "Color", {"Cyan", "Red", "Purple", "Green", "White"}, "Cyan", function(v)
        local t = {Cyan = Color3.fromRGB(0,200,255), Red = Color3.fromRGB(255,60,60), Purple = Color3.fromRGB(170,85,255), Green = Color3.fromRGB(90,255,140), White = Color3.fromRGB(240,240,240)}
        S.selfChamsColor = t[v] or t.Cyan
    end)
    addText(pSc, "Подсвечивает ТВОЕГО персонажа: ForceField — смена материала, Flat — заливка (видно сквозь стены).")

    local pLc = addPanel(pg.col2, "Landing Circle")
    addToggle(pLc, "local.landing", "Enabled", false, function(state)
        setLandingCircle(state)
    end)
    addDropdown(pLc, nil, "Color", {"White", "Cyan", "Red", "Purple"}, "White", function(v)
        local t = {White = Color3.fromRGB(255,255,255), Cyan = Color3.fromRGB(0,200,255), Red = Color3.fromRGB(255,60,60), Purple = Color3.fromRGB(170,85,255)}
        S.landingColor = t[v] or t.White
    end)
    addSlider(pLc, "local.landing.dur", "Duration", 0.1, 3, 0.82, 0.01, function(v) S.landingDur = v end)
    addSlider(pLc, "local.landing.tr", "Opacity", 0, 1, 1, 0.05, function(v) S.landingTransp = v end)
    addText(pLc, "Кольцо-солярка на земле в точке приземления после прыжка/падения.")

    local pTc = addPanel(pg.col1, "Tool Chams")
    addToggle(pTc, "local.toolchams", "Enabled", false, function(state) setToolChams(state) end)
    addDropdown(pTc, "local.toolchams.type", "Type", {"ForceField", "Flat", "Chromatic"}, "ForceField", function(v) S.toolChamsType = v end)
    addText(pTc, "Красит инструмент в твоей руке (цвет = Self Chams).")


    local pDs = addPanel(pg.col2, "Desync (Fake Pos)")
    addToggle(pDs, "local.fakepos", "Fake Position", false, function(state) setFakePosition(state) end)
    addToggle(pDs, "local.fakepos.vis", "Visual Marker", false, function(state) setFakePosVisual(state) end)
    addSlider(pDs, "local.fakepos.dist", "Distance", 0, 5000, 200, 10, function(v) S.fakeDist = math.floor(v) end)
    addSlider(pDs, "local.fakepos.up", "Up", 0, 200, 0, 1, function(v) S.fakeUp = math.floor(v) end)
    addToggle(pDs, "local.velospoof", "Velocity Spoof", false, function(state) S.veloSpoofOn = state end)
    addDropdown(pDs, "local.velospoof.mode", "Spoof Mode", {"velocity", "rotate"}, "rotate", function(v) S.veloMode = v end)
    addSlider(pDs, "local.velospoof.pow", "Spoof Power", 1, 30, 8, 1, function(v) S.veloPow = math.floor(v) end)
    addText(pDs, "Сервер/скрипты видят тебя в другом месте (спуф CFrame через метатаблицу). Velocity Spoof ломает чужой аим по тебе. Хуки pcall-обёрнуты.")

    local pAura = addPanel(pg.col2, "Aura")
    addDropdown(pAura, "local.aura.type", "Type", {"neverlose", "nebula", "hexagram", "sparkles", "lightning", "purple", "dust"}, "neverlose", function(v)
        S.auraType = v
        if S.auraOn then setAura(true) end
    end)
    addToggle(pAura, "local.aura.on", "Enabled", false, function(state) setAura(state) end)
    addText(pAura, "Частицы-аура вокруг персонажа (7 видов).")

    local pDfx = addPanel(pg.col2, "Death FX")
    addToggle(pDfx, "local.deathfx", "Enabled", false, function(state) S.deathFxOn = state end)
    addDropdown(pDfx, "local.deathfx.type", "Type", {"Emitter", "Particles", "Clone"}, "Emitter", function(v) S.deathFxType = v end)
    addText(pDfx, "Эффект на смерти любого игрока: фиолетовый взрыв частиц или исчезающий неоновый клон.")

    local pInfo2 = addPanel(pg.col2, "Info")
    addText(pInfo2, "Локальный визуал: работает только на твоём персонаже/экране. Backtrack + Self Chams + China Hat — идеальная связка для clipов.")
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
    addDropdown(pAir, "airstack.mode", "Mode", {"Platform", "Freeze"}, "Platform", function(v)
        S.airstackMode = v
        if S.airstackOn then
            disableAirStack()
            task.delay(0.05, enableAirStack)
        end
    end)
    addText(pAir, "Platform: бегай по воздуху. Freeze: ПОЛНЫЙ СТОП в маленьком кубе (3x3) — WalkSpeed/Jump в ноль + CFrame-lock, ни шага, ни прыжка, ни дрейфа.")

    local pPS = addPanel(pg.col2, "Pixel Surf")
    addToggle(pPS, "pixelsurf.enabled", "Enabled", false, function(state) setPixelSurf(state) end)
    addText(pPS, "Прыгни у стены/выступа — под ногами появится ступенька, заберёшься выше.")

    local pJump = addPanel(pg.col1, "Infinite Jump")
    addToggle(pJump, "infjump.enabled", "Enabled", false, function(state)
        S.infJumpOn = state
    end)
    addText(pJump, "Прыгай в воздухе сколько угодно раз подряд (не работает вместе с полётом — там свой подъём).")

    local pHop = addPanel(pg.col1, "Wallhop")
    addToggle(pHop, "wallhop.enabled", "Enabled", false, function(state)
        S.wallhopOn = state
    end)
    addText(pHop, "Прыжок от стены: в воздухе рядом с любой вертикальной поверхностью жми прыжок — оттолкнёшься снова.")
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

-- ==== WalkSpeed ====
do
    local pg = addPage("Player", "👟", "WalkSpeed")

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
    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Скорость ходьбы. 16 — стандарт. Держится каждый кадр, игру не перебить.")
end

-- ==== JumpPower ====
do
    local pg = addPage("Player", "🦘", "JumpPower")

    local pJp = addPanel(pg.col1, "JumpPower")
    addToggle(pJp, "jp.enabled", "Enabled", false, function(state)
        S.jumpPowerOn = state
        if state then applyJumpPower() end
    end)
    addSlider(pJp, "jp.power", "Power", 50, 500, 50, 5, function(v)
        S.jumpPower = math.floor(v)
        if S.jumpPowerOn then applyJumpPower() end
    end)
    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Сила прыжка (UseJumpPower). 50 — стандарт.")
end

-- ==== Anti Ragdoll ====
do
    local pg = addPage("Player", "🤸", "Anti Ragdoll")

    local pRagdoll = addPanel(pg.col1, "Anti Ragdoll")
    addToggle(pRagdoll, "player.antiragdoll", "Enabled", false, function(state)
        S.antiRagdoll = state
        toastImpl("Anti Ragdoll", state and "ON" or "OFF")
    end)
    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Не даёт упасть в ragdoll: при любом падении/физике мгновенно встаёт (GettingUp). Двигаться можно как обычно.")
end

-- ==== God Mode ====
do
    local pg = addPage("Player", "🛡", "God Mode")

    local pGod = addPanel(pg.col1, "God Mode")
    addToggle(pGod, "player.god.enabled", "Enabled", false, function(state)
        if state then enableGod() else disableGod() end
    end)
    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Держит HP на максимуме каждый кадр. Работает не во всех играх (где HP контролирует сервер).")
end

-- ==== Anti Fling ====
do
    local pg = addPage("Player", "🌀", "Anti Fling")

    local pAf = addPanel(pg.col1, "Anti Fling")
    addToggle(pAf, "antifling.enabled", "Enabled", false, function(state)
        if state then enableAntiFling() else disableAntiFling() end
    end)
    addSlider(pAf, "antifling.max", "Max Velocity", 50, 500, 150, 10, function(v)
        S.afMax = math.floor(v)
    end)
    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Обрезает резкие рывки скорости (чужие флинги) до Max Velocity. Не трогает Fly и свой Fling.")
end

-- ==== TP Player ====
do
    local pg = addPage("Player", "👥", "TP Player")

    local pTp = addPanel(pg.col1, "TP Player")
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
        end
    end, Color3.fromRGB(24, 70, 110), Color3.fromRGB(30, 86, 132))
    local pInfo = addPanel(pg.col2, "Info")
    addText(pInfo, "Выбери игрока из списка → Teleport — персонаж оказывается у него вплотную.")
end

-- ==== Misc (Appearance + NoKb + Invisible) ====
do
    local pg = addPage("Player", "🎭", "Misc")

    local pMorph = addPanel(pg.col1, "Appearance (Fake)")
    addButton(pMorph, "Fake Korblox", function() applyFakeKorblox() end)
    addButton(pMorph, "Fake Headless", function() applyFakeHeadless() end)
    addText(pMorph, "Визуальные морфы: Korblox-нога и Headless-голова (локально).")

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

    local pInvis = addPanel(pg.col1, "Invisible")
    addToggle(pInvis, "invis.enabled", "Enabled", false, function(state)
        setInvisible(state)
    end)
    addSlider(pInvis, "invis.offset", "Depth", 20, 200, 58, 2, function(v)
        S.invisOffset = math.floor(v)
    end)
    addText(pInvis, "Персонаж проваливается под карту (Y зафиксирован — падения нет), другие тебя не видят. Камера и управление — как обычно. Выключаешь — телепорт обратно на поверхность.")
end


addCategory("Server")

-- ==== Bypass ====
do
    local pg = addPage("Server", "🛡", "Bypass")

    local pSafe = addPanel(pg.col2, "Safety")
    addToggle(pSafe, "server.antivoid", "Anti-Void", false, function(state) setAntiVoid(state) end)
    addToggle(pSafe, "server.antiafk", "Anti-AFK", false, function(state) setAntiAfk(state) end)
    addText(pSafe, "Anti-Void: платформа под картой + возврат при падении в бездну. Anti-AFK: не выкинет за 20 мин бездействия.")

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
        addBindRow(pB, e)
    end

    addText(pg.col2, "Бинды НЕ срабатывают, когда мышь над меню — колёсико можно спокойно биндить.")
end

-- ==== Main (Configs + Info + Script) ====
local miscPage
do
    -- ==== 🔋 Performance (FPS Boost) rev36 ====
    do
        local pgPerf = addPage("Miscellaneous", "🔋", "Performance")

        local fpSaved = nil
        local function applyFpsBoost()
            pcall(function()
                local l = game:GetService("Lighting")
                fpSaved = {
                    GSh = l.GlobalShadows,
                    FogS = l.FogStart, FogE = l.FogEnd,
                    Tech = l.Technology,
                    fx = {},
                }
                for _, fx in ipairs(l:GetChildren()) do
                    if fx:IsA("BloomEffect") or fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect")
                        or fx:IsA("DepthOfFieldEffect") or fx:IsA("SunRaysEffect") then
                        table.insert(fpSaved.fx, {fx = fx, en = fx.Enabled})
                        fx.Enabled = false
                    end
                end
                l.GlobalShadows = false
                l.FogStart = 0
                l.FogEnd = 9e9
                pcall(function() l.Technology = Enum.Technology.Compatibility end)
            end)
            pcall(function()
                if sethiddenproperty then
                    local t = game:GetService("Terrain")
                    pcall(sethiddenproperty, t, "Decoration", false)
                end
            end)
        end
        local function restoreFpsBoost()
            if not fpSaved then return end
            pcall(function()
                local l = game:GetService("Lighting")
                l.GlobalShadows = fpSaved.GSh
                l.FogStart, l.FogEnd = fpSaved.FogS, fpSaved.FogE
                l.Technology = fpSaved.Tech
                for _, r in ipairs(fpSaved.fx or {}) do
                    if r.fx and r.fx.Parent then r.fx.Enabled = r.en end
                end
            end)
            fpSaved = nil
        end

        local pFb = addPanel(pgPerf.col1, "⚡ FPS Boost")
        addToggle(pFb, "perf.boost", "FPS Boost (тени/эффекты ВЫКЛ)", false, function(state)
            if state then applyFpsBoost() else restoreFpsBoost() end
            toastImpl("Performance", state and "FPS Boost ВКЛ — заслонки сняты 🚀" or "FPS Boost ВЫКЛ")
        end)
        addSlider(pFb, "perf.fpscap", "FPS Cap", 30, 240, 120, 10, function(v)
            if setfpscap then pcall(setfpscap, math.floor(v)) end
        end)
        addDropdown(pFb, "perf.quality", "Render Quality", {"Low", "Medium", "High"}, "High", function(v)
            local q = ({Low = 1, Medium = 8, High = 21})[v] or 21
            pcall(function() settings().Rendering.QualityLevel = q end)
        end)
        addText(pFb, "Boost глушит тени, туман, bloom/sunrays/DoF/блур и текстурки-тратуар (оформление терайна), рендер переводит в Compatibility. Помимо этого — включи в Visuals → ⚡ ESP Perf частоту ниже: лаг уходил именно оттуда. FPS Cap срабатывает, только если executor держит setfpscap.")
    end

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
    addText(pInfo, "Меню в оболочке Voidware-стиля, всё своё.")

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

-- ---------------- BRAINROT (rev55) ----------------
-- Пак под «Clone to Steal Eggs» (фиче-карта из Ouroboros zqgwfe):
-- Auto Steal + Delay / Instant ProximityPrompt / Eggs (hatch·place·sell) /
-- авто-апгрейды Base·Clones·Treadmill / Auto Rebirth / Train / Claim Rewards /
-- сканер ремоток с ручным вызовом. Ищем ремотки по именам (Knit-style),
-- поэтому пак работает и на наклонах игры.
addCategory("Brainrot")

do
    S.br = S.br or {
        stealOn = false, stealDelay = 0.15,
        hatchOn = false, placeOn = false, sellOn = false,
        eggDelay = 0.5, sellDelay = 1.0, sellFilter = "Все",
        upBaseOn = false, upClonesOn = false, upTreadOn = false,
        rebirthOn = false, trainOn = false, claimOn = false,
        farmDelay = 1.0, instantPrompt = false,
    }
    local br = S.br

    local brGen = {}
    local brRemotes, brScanDone = {}, false
    local brPromptConn = nil
    local brPromptSaved = {}
    local brLastRemote = "—"

    -- ===== поиск ремоток =====
    local function brRescan(force)
        if brScanDone and not force then return brRemotes end
        brRemotes = {}
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            for _, d in ipairs(rs:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent")
                    or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteFunction") then
                    table.insert(brRemotes, d)
                end
            end
        end)
        brScanDone = true
        return brRemotes
    end

    local function brFindRemote(needles)
        brRescan(false)
        for pass = 1, 2 do
            for _, r in ipairs(brRemotes) do
                local n = string.lower(tostring(r.Name))
                for _, nd in ipairs(needles) do
                    nd = string.lower(nd)
                    if (pass == 1 and n == nd)
                        or (pass == 2 and string.find(n, nd, 1, true)) then
                        return r
                    end
                end
            end
        end
        return nil
    end

    local function brCall(needles, ...)
        local r = brFindRemote(needles)
        if not r then return false, "ремотка не найдена" end
        local args = {...}
        local ok, err = pcall(function()
            if r:IsA("RemoteFunction") then
                return r:InvokeServer(table.unpack(args))
            end
            r:FireServer(table.unpack(args))
        end)
        if ok then brLastRemote = r.Name end
        return ok, err
    end

    -- свип workspace-промптов по словам (Steal/Take/Hatch/...)
    local function brPromptTick(words)
        local hit = false
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    local t = string.lower(tostring(d.ActionText) .. " " .. tostring(d.ObjectText))
                    for _, w in ipairs(words) do
                        if string.find(t, w, 1, true) then
                            if fireproximityprompt then
                                pcall(fireproximityprompt, d)
                            else
                                pcall(function() d:InputHoldBegin() end)
                            end
                            hit = true
                            break
                        end
                    end
                end
            end
        end)
        return hit
    end

    -- ===== движок циклов (gen — защита от двойного запуска) =====
    local function brLoopStart(key, fn, delayGetter)
        br[key .. "On"] = true
        brGen[key] = (brGen[key] or 0) + 1
        local gen = brGen[key]
        task.spawn(function()
            while br[key .. "On"] and brGen[key] == gen do
                pcall(fn)
                local d = delayGetter and delayGetter() or 0.3
                if d < 0.03 then d = 0.03 end
                task.wait(d)
            end
        end)
    end

    local function brLoopStop(key)
        br[key .. "On"] = false
    end

    -- ===== Instant ProximityPrompt =====
    local function brSetInstantPrompt(b)
        br.instantPrompt = b
        if b then
            pcall(function()
                local pps = game:GetService("ProximityPromptService")
                dcc(brPromptConn)
                brPromptConn = sh2Conn(pps.PromptShown:Connect(function(p)
                    pcall(function()
                        if brPromptSaved[p] == nil then brPromptSaved[p] = p.HoldDuration end
                        p.HoldDuration = 0
                    end)
                end))
            end)
            pcall(function()
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then
                        if brPromptSaved[d] == nil then brPromptSaved[d] = d.HoldDuration end
                        d.HoldDuration = 0
                    end
                end
            end)
        else
            dcc(brPromptConn)
            brPromptConn = nil
            for p, h in pairs(brPromptSaved) do
                pcall(function() if p and p.Parent then p.HoldDuration = h end end)
            end
            brPromptSaved = {}
        end
    end

    -- ===== фиче-тики =====
    local function brStealTick()
        brCall({"setautosteal", "autosteal"}, true) -- серверный автостил, как в Ouroboros
        brPromptTick({"steal", "take"})
        brCall({"steal", "stealegg", "stealanimal"})
    end
    local function brHatchTick()
        brCall({"hatchegg", "hatch", "openegg", "crack"})
        brPromptTick({"hatch"})
    end
    local function brPlaceTick()
        brCall({"placeegg", "placeanimal", "place"})
    end
    local function brSellTick()
        if br.sellFilter ~= "Все" then
            brCall({"sellrarity", "sellfilter"}, br.sellFilter)
        end
        brCall({"sellall", "sell", "selleggs", "sellanimals"})
    end

    -- ===== cleanup =====
    function brCleanupAll()
        for _, k in ipairs({"steal", "hatch", "place", "sell", "upBase",
                            "upClones", "upTread", "rebirth", "train", "claim"}) do
            br[k .. "On"] = false
        end
        brSetInstantPrompt(false)
    end

    -- ================== PAGE 1: 🥷 Steal ==================
    do
        local pg = addPage("Brainrot", "🥷", "Steal")

        local pAuto = addPanel(pg.col1, "Auto Steal")
        addToggle(pAuto, "br.steal.enabled", "Auto Steal", false, function(state)
            br.stealOn = state
            if state then
                brCall({"setautosteal", "autosteal"}, true)
                brLoopStart("steal", brStealTick, function() return br.stealDelay end)
                toastImpl("Brainrot", "Auto Steal ВКЛ — цикл по Delay")
            else
                brLoopStop("steal")
                brCall({"setautosteal", "autosteal"}, false)
            end
        end)
        addSlider(pAuto, "br.steal.delay", "Delay Between Steals", 0.05, 5, 0.15, 0.05, function(v)
            br.stealDelay = v
        end)

        local pPrompt = addPanel(pg.col1, "Промпты")
        addToggle(pPrompt, "br.instantprompt", "Instant ProximityPrompt", false, function(state)
            brSetInstantPrompt(state)
        end)

        local pInfo = addPanel(pg.col2, "Info")
        addText(pInfo, "Auto Steal (как SetAutoSteal у Ouroboros): долбит ремотку SetAutoSteal/Steal + мгновенно долбит промпты Steal/Take в мире. Задержка — слайдером.")
        addText(pInfo, "Instant ProximityPrompt: обнуляет HoldDuration всех промптов — кража руками тоже мгновенная. При выключении длительность возвращается.")
    end

    -- ================== PAGE 2: 🥚 Eggs ==================
    do
        local pg = addPage("Brainrot", "🥚", "Eggs")

        local pEg = addPanel(pg.col1, "Eggs")
        addToggle(pEg, "br.hatch.enabled", "Auto Hatch Eggs", false, function(state)
            br.hatchOn = state
            if state then
                brLoopStart("hatch", brHatchTick, function() return br.eggDelay end)
            else
                brLoopStop("hatch")
            end
        end)
        addToggle(pEg, "br.place.enabled", "Auto Place Eggs", false, function(state)
            br.placeOn = state
            if state then
                brLoopStart("place", brPlaceTick, function() return br.eggDelay end)
            else
                brLoopStop("place")
            end
        end)
        addSlider(pEg, "br.egg.delay", "Hatch/Place Interval", 0.1, 5, 0.5, 0.1, function(v)
            br.eggDelay = v
        end)

        local pSell = addPanel(pg.col2, "Sell")
        addToggle(pSell, "br.sell.enabled", "Auto Sell Animals/Eggs", false, function(state)
            br.sellOn = state
            if state then
                brLoopStart("sell", brSellTick, function() return br.sellDelay end)
            else
                brLoopStop("sell")
            end
        end)
        addSlider(pSell, "br.sell.delay", "Sell Interval", 0.2, 30, 1.0, 0.2, function(v)
            br.sellDelay = v
        end)
        addDropdown(pSell, "br.sell.filter", "Sell Egg Rarities",
            {"Все", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Godly"},
            "Все", function(v) br.sellFilter = v end)
        addText(pSell, "Фильтр пробрасывает имя редкости аргументом в sell-ремотку — сработает, если сама игра понимает фильтр. Keep Mutations у Ouroboros тоже серверный: мутантов при чужом фильтре продаст, осторожнее.")
        addText(pSell, "Place: если игра требует id яйца аргументом — сервер сам откажет, ошибки на клиент не валятся. Тогда ставь вручную, а hatch/sell пусть крутятся.")
    end

    -- ================== PAGE 3: 🏗 Auto Farm ==================
    do
        local pg = addPage("Brainrot", "🏗", "Auto Farm")

        local pUp = addPanel(pg.col1, "Upgrades")
        addToggle(pUp, "br.upbase.enabled", "Auto Upgrade Base", false, function(state)
            br.upBaseOn = state
            if state then
                brLoopStart("upBase", function()
                    brCall({"upgradebase", "baseupgrade", "buybase"})
                end, function() return br.farmDelay end)
            else
                brLoopStop("upBase")
            end
        end)
        addToggle(pUp, "br.upclones.enabled", "Auto Upgrade Clones", false, function(state)
            br.upClonesOn = state
            if state then
                brLoopStart("upClones", function()
                    brCall({"upgradeclones", "cloneupgrades", "buyclone"})
                end, function() return br.farmDelay end)
            else
                brLoopStop("upClones")
            end
        end)
        addToggle(pUp, "br.uptread.enabled", "Auto Upgrade Treadmill", false, function(state)
            br.upTreadOn = state
            if state then
                brLoopStart("upTread", function()
                    brCall({"upgradetreadmill", "treadmillupgrade", "buytreadmill"})
                end, function() return br.farmDelay end)
            else
                brLoopStop("upTread")
            end
        end)
        addSlider(pUp, "br.farm.delay", "Farm Delay", 0.2, 10, 1.0, 0.2, function(v)
            br.farmDelay = v
        end)

        local pProg = addPanel(pg.col2, "Progress")
        addToggle(pProg, "br.rebirth.enabled", "Auto Rebirth", false, function(state)
            br.rebirthOn = state
            if state then
                brLoopStart("rebirth", function()
                    brCall({"rebirth", "autorebirth"})
                end, function() return math.max(br.farmDelay, 1) end)
            else
                brLoopStop("rebirth")
            end
        end)
        addToggle(pProg, "br.train.enabled", "Auto Go On Treadmill", false, function(state)
            br.trainOn = state
            if state then
                brLoopStart("train", function()
                    brCall({"train", "goontreadmill", "starttrain", "treadmill"})
                end, function() return math.max(br.farmDelay, 2) end)
            else
                brLoopStop("train")
            end
        end)
        addToggle(pProg, "br.claim.enabled", "Auto Claim Playtime Rewards", false, function(state)
            br.claimOn = state
            if state then
                brLoopStart("claim", function()
                    brCall({"claimplaytimereward", "claimplaytime", "playtimereward",
                            "claimreward", "claim"})
                end, function() return 15 end)
            else
                brLoopStop("claim")
            end
        end)
        addText(pProg, "Нейминг — как у Ouroboros: SetAutoSteal / UpgradeBase / CloneUpgrades / Treadmill / Rebirth / Claim. Ищем точно по имени, потом подстрокой по всему ReplicatedStorage — работает и на разных клонах игры.")
    end

    -- ================== PAGE 4: 🔍 Remotes ==================
    do
        local pg = addPage("Brainrot", "🔍", "Remotes")

        local pScan = addPanel(pg.col1, "Scanner")
        addButton(pScan, "Rescan Remotes", function()
            brRescan(true)
            toastImpl("Brainrot", "Найдено ремоток: " .. tostring(#brRemotes))
            print("[SpermaHub][Brainrot] ===== REMOTES =====")
            for _, r in ipairs(brRemotes) do
                pcall(function()
                    print(("[SpermaHub][Brainrot] %s  %s"):format(r.ClassName, r:GetFullName()))
                end)
            end
        end)
        br._preset = "SetAutoSteal"
        addDropdown(pScan, nil, "Manual Fire preset",
            {"SetAutoSteal", "Steal", "Hatch", "PlaceEgg", "SellAll", "Sell",
             "UpgradeBase", "UpgradeClones", "UpgradeTreadmill",
             "Rebirth", "Train", "Claim"},
            "SetAutoSteal", function(v) br._preset = v end)
        addButton(pScan, "Fire Once (arg true)", function()
            local ok, err = brCall({br._preset or "SetAutoSteal"}, true)
            if ok then
                toastImpl("Brainrot", "Вызвал: " .. tostring(brLastRemote))
            else
                toastImpl("Brainrot", "Не вышло: " .. tostring(err))
            end
        end)

        local pSt = addPanel(pg.col2, "Status")
        addText(pSt, "Последняя удачно вызванная ремотка пишется в тост при Fire Once; авто-циклы вызывают молча.")
        addText(pSt, "Порядок: зашёл на сервер → Rescan → смотри имена в консоль → понимаешь, какие автофичи реально поймали свою ремотку.")
        addText(pSt, "Сменил сервер/игра обновилась → Rescan ещё раз.")
    end
end

bootStep("страницы OK")
-- ============================================================
-- ===================== ПОЛНАЯ ВЫГРУЗКА ======================
-- ============================================================
function fullCleanupNL()
    -- 1) снести окно SpermaClick + свои GUI (по всем контейнерам; старые имена добивыем на всякий случай)
    pcall(function()
        local heirsR = {}
        table.insert(heirsR, LP.PlayerGui)
        pcall(function() if gethui then table.insert(heirsR, gethui()) end end)
        pcall(function() table.insert(heirsR, game:GetService("CoreGui")) end)
        for _, parent in ipairs(heirsR) do
            for _, gname in ipairs({"SpermaClick", "Rayfield", "SpermaLinoria", "SpermaAdmin", "SpermaKeySystem", "SpermaWatermark"}) do
                pcall(function()
                    local rf = parent:FindFirstChild(gname)
                    if rf then rf:Destroy() end
                end)
            end
        end
    end)
    -- 2) отвязать render-loop Rayfield (остаётся жить даже после Destroy окна)
    pcall(function() RunService:UnbindFromRenderStep("SpermaRayPulse") end)
    if unloadedNL then return end
    unloadedNL = true
    dcc(S.rsToggleConn)
    S.guiAlive = false
    dcc(S.flyConn)
    dcc(S.noclipConn)
    dcc(S.targetEspConn)
    pcall(disableTargetHUD) -- rev56: Target HUD off + BillboardGui снять
    dcc(S.wsConn)
    dcc(S.arConn)
    dcc(S.clickTpConn)
    dcc(S.hitboxConn)
    if S.aimbotConn then pcall(function() RunService:UnbindFromRenderStep("SpermaHubAimbot") end) S.aimbotConn = nil end
    pcall(function() RunService:UnbindFromRenderStep("SpermaHubFlickStep") end)
    if S.silentAimConn then pcall(function() S.silentAimConn:Disconnect() end) end
    disableAutoClicker()
    pcall(brCleanupAll) -- rev55: стоп Brainrot-циклов + вернуть промптам HoldDuration
    S.autoFlingOn = false -- rev57: прекратить Auto Fling (Stop)
    pcall(function()
        if S.skidFPDH ~= nil then workspace.FallenPartsDestroyHeight = S.skidFPDH end
        S.skidActive = false
    end)
    dcc(S.autoClickBindConn)
    dcc(S.jesusConn)
    if S.jesusPlatform then S.jesusPlatform:Destroy() S.jesusPlatform = nil end
    dcc(S.spinConn)
    dcc(S.aaConn)
    pcall(aaDestroyFake)
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
    pcall(disableCrosshair)
    pcall(function() S.infJumpOn = false S.wallhopOn = false end)
    pcall(removeCustomFov)
    pcall(removeAspect)
    pcall(restoreWorldMods)
    pcall(disableChinaHat)
    pcall(function() setBacktrack(false) end)
    pcall(function() setSelfChams(false) end)
    pcall(function() setLandingCircle(false) end)
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
    pcall(function() espMaxStop() end)
    pcall(disableTargetESP)
    local heirsT = { LP.PlayerGui }
    pcall(function() if gethui then table.insert(heirsT, gethui()) end end)
    pcall(function() table.insert(heirsT, game:GetService("CoreGui")) end)
    for _, parent in ipairs(heirsT) do
        for _, n in ipairs({
            "SpermaHubESP","SpermaHubFov","SpermaHubHUD","SpermaHubFx","SpermaHubNL",
            "SpermaHubNLToggle","SpermaHubClickGui","SpermaClick","SpermaHubSpec","SpermaHubWatermark",
            "SpermaHubBinds","SpermaHubTHud","SpermaHubToast","SpermaHubBoot",
            "SpermaKeySystem","SpermaAdmin","Rayfield","SpermaLinoria","KeyUI","SpermaHubErrToast","SpermaWatermark"
        }) do
            pcall(function()
                local g = parent:FindFirstChild(n)
                if g then g:Destroy() end
            end)
        end
    end
    pcall(function() getgenv().Library:Unload() end)
    -- сброс синглтона: после close скрипт можно запустить заново без перезахода
    pcall(function() if getgenv then getgenv().SpermaHubRunning = false end end)
    print("✦ SpermaHub ПОЛНОСТЬЮ выгружен (GUI/циклы/коннекты добиты; можно запускать заново)")
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
    if not S.guiAlive then return end
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
end) -- /СЕКЦИЯ СТРАНИЦ (pcall-IIFE)
print("[SpermaHub] секция страниц выполнена")

-- ==================== ИНИЦИАЛИЗАЦИЯ =========================
-- ============================================================
updateFovCircle()
updateSilentFovCircle()
-- открыть первую категорию и её первую страницу (Legitbot)
if Categories[1] then
    selectCategory(Categories[1].key)
elseif Pages[1] then
    selectPage(Pages[1])
end

-- ============================================================
-- ============ SPERMACLICK GUI — FULL SKID 1:1 РЕФЕРЕНС ======
-- ============================================================
-- Тёмные полупрозрачные колонки категорий (Combat / Movement / Visuals /
-- — / Player / Server / Miscellaneous), у каждого модуля «...» справа —
-- настройки раскрываются ИНЛАЙН внутри колонки (как Ambience на скрине).
-- Чекбоксы, слайдеры с драгом, дропдауны-циклеры, бинды, списки игроков.
-- Поиск модулей снизу. Ctrl+G (Hold) — доп. опции. RightShift — меню.
-- ЕДИНСТВЕННЫЙ движок: Rayfield и Linoria больше не существует (rev52).
do
    local Tele = game:GetService("TeleportService")
    local CG_LINK = "https://discord.gg/bUcTUuB9U5"

    -- ---------- палитра (1:1 со скрина) ----------
    local C_BG      = Color3.fromRGB(14, 14, 26)   -- колонка
    local C_BG2     = Color3.fromRGB(9, 9, 18)     -- настройки
    local C_ROW_ON  = Color3.fromRGB(52, 52, 86)   -- включённый модуль
    local C_ROW_HOV = Color3.fromRGB(30, 30, 52)   -- ховер
    local C_TXT     = Color3.fromRGB(238, 238, 246)
    local C_DIM     = Color3.fromRGB(138, 142, 164)
    local C_ACCENT  = Color3.fromRGB(110, 124, 250) -- чекбокс / слайдер
    local C_LINE    = Color3.fromRGB(44, 44, 70)

    local COL_W, HEADER_H, ROW_H, CTL_H = 152, 34, 24, 20
    local GAP, PANEL_MAXH = 10, 480

    local CAT_SORT = { Combat = 1, Movement = 2, Visuals = 3, Player = 4, Server = 5, Miscellaneous = 6 }

    local rowRefs = {}          -- m -> {row=, dots=, paint=}
    local catCols = {}          -- cat -> {frame=, scroll=, content=}
    local colOrder = {}         -- отсортированные категории
    local openHolder = nil      -- открытая панель настроек (Frame)
    local openModule = nil
    local dragging = nil        -- активный слайдер {el,bar,fill,lab,fmt}

    -- ---------- контейнер ----------
    local gui = Instance.new("ScreenGui")
    gui.Name = "SpermaClick"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 70
    gui.Enabled = false
    pcall(function()
        if gethui then gui.Parent = gethui() end
    end)
    if not gui.Parent then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    pcall(function() if protectgui then protectgui(gui) end end)
    CGGui = gui

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.new(0.5, 0, 0.46, 0)
    root.BackgroundTransparency = 1
    root.Parent = gui
    rootF = root

    -- ---------- утилиты виджетов ----------
    local function mkCorner(inst, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 6)
        c.Parent = inst
        return c
    end
    local function mkStroke(inst)
        local st = Instance.new("UIStroke")
        st.Color = C_LINE
        st.Transparency = 0.35
        st.Thickness = 1
        st.Parent = inst
        return st
    end
    local function mkText(parent, txt, size, bold, col, align)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextSize = size or 12
        l.TextColor3 = col or C_TXT
        l.Text = tostring(txt)
        l.TextXAlignment = align or Enum.TextXAlignment.Left
        l.Parent = parent
        return l
    end

    -- ---------- настройки модуля ----------
    local function closeSettings()
        if openHolder then pcall(function() openHolder:Destroy() end) end
        openHolder = nil
        if openModule then
            local rd = rowRefs[openModule]
            if rd then pcall(function() rd.dots.TextColor3 = C_DIM end) end
        end
        openModule = nil
    end

    local buildSettings

    local function toggleSettings(m)
        if openModule == m then
            closeSettings()
            return
        end
        closeSettings()
        openModule = m
        local rd = rowRefs[m]
        if rd then pcall(function() rd.dots.TextColor3 = C_ACCENT end) end
        local col = catCols[m.cat]
        if not col then return end
        local holder = Instance.new("Frame")
        holder.Name = "Settings"
        holder.BackgroundColor3 = C_BG2
        holder.BackgroundTransparency = 0.08
        holder.BorderSizePixel = 0
        holder.AutomaticSize = Enum.AutomaticSize.Y
        holder.Size = UDim2.new(1, -6, 0, 0)
        mkCorner(holder, 6)
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 2)
        lay.Parent = holder
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 4)
        pad.Parent = holder
        holder.LayoutOrder = (rd and rd.order or 0) * 2 + 1
        holder.Parent = col.scroll
        openHolder = holder
        buildSettings(holder, m)
    end

    local function ctlFrame(parent, order, h)
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.Size = UDim2.new(1, 0, 0, h or CTL_H)
        f.LayoutOrder = order
        f.Parent = parent
        return f
    end

    local function buildToggleRow(parent, order, label, getFn, setFn)
        local f = ctlFrame(parent, order, CTL_H)
        mkText(f, label, 11.5, false, C_TXT).Size = UDim2.new(1, -24, 1, 0)
        local box = Instance.new("TextButton")
        box.Size = UDim2.new(0, 14, 0, 14)
        box.Position = UDim2.new(1, -16, 0.5, -7)
        box.Text = ""
        box.AutoButtonColor = false
        box.BorderSizePixel = 0
        mkCorner(box, 3)
        mkStroke(box)
        box.Parent = f
        local tick = mkText(box, "✓", 11, true, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
        tick.Size = UDim2.new(1, 0, 1, 0)
        local function paint()
            local on = getFn() == true
            box.BackgroundColor3 = on and C_ACCENT or C_BG2
            tick.Visible = on
        end
        box.MouseButton1Click:Connect(function()
            setFn(getFn() ~= true)
        end)
        paint()
        return paint
    end

    local function fmtVal(v, step)
        if step and step < 1 then
            return string.format("%.1f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function buildSliderBlock(parent, order, el)
        local f = ctlFrame(parent, order, CTL_H + 12)
        local lab = mkText(f, tostring(el.label) .. "  ·  " .. fmtVal(el.value, el.step), 11, false, C_DIM)
        lab.Size = UDim2.new(1, 0, 0, 14)
        local bar = Instance.new("Frame")
        bar.Active = true
        bar.BackgroundColor3 = C_LINE
        bar.BorderSizePixel = 0
        bar.Size = UDim2.new(1, -6, 0, 3)
        bar.Position = UDim2.new(0, 3, 0, CTL_H + 2)
        mkCorner(bar, 2)
        bar.Parent = f
        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = C_ACCENT
        fill.BorderSizePixel = 0
        mkCorner(fill, 2)
        fill.Parent = bar
        local knob = Instance.new("Frame")
        knob.BackgroundColor3 = C_ACCENT
        knob.BorderSizePixel = 0
        mkCorner(knob, 99)
        knob.Size = UDim2.new(0, 7, 0, 7)
        knob.Parent = bar
        local function paint()
            local frac = 0
            if el.max > el.min then
                frac = math.clamp((el.value - el.min) / (el.max - el.min), 0, 1)
            end
            fill.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, -3, 0.5, -3)
            lab.Text = tostring(el.label) .. "  ·  " .. fmtVal(el.value, el.step)
        end
        local function applyX(px)
            local w = bar.AbsoluteSize.X
            if w <= 0 then return end
            local rel = math.clamp((px - bar.AbsolutePosition.X) / w, 0, 1)
            local v = el.min + rel * (el.max - el.min)
            local st = el.step or 1
            if st > 0 then
                v = el.min + math.floor((v - el.min) / st + 0.5) * st
            end
            v = math.clamp(v, el.min, el.max)
            if v ~= el.value then
                el.value = v
                pcall(function() if el.cb then el.cb(el.value) end end)
            end
            paint()
        end
        bar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = {apply = applyX}
                applyX(inp.Position.X)
            end
        end)
        el._upd = function() pcall(paint) end
        paint()
    end

    local function buildDropdownRow(parent, order, el)
        local f = ctlFrame(parent, order, CTL_H)
        mkText(f, tostring(el.label), 11.5, false, C_TXT).Size = UDim2.new(0.55, 0, 1, 0)
        local val = mkText(f, tostring(el.value), 11, true, C_ACCENT, Enum.TextXAlignment.Right)
        val.Size = UDim2.new(0.45, -4, 1, 0)
        val.Position = UDim2.new(0.55, 0, 0, 0)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = f
        local function step(dir)
            local opts = el.options or {}
            if #opts == 0 then return end
            local idx = 0
            for i, o in ipairs(opts) do
                if tostring(o) == tostring(el.value) then idx = i break end
            end
            idx = idx + dir
            if idx > #opts then idx = 1 end
            if idx < 1 then idx = #opts end
            el.value = tostring(opts[idx])
            pcall(function() if el.cb then el.cb(el.value) end end)
            val.Text = tostring(el.value)
        end
        btn.MouseButton1Click:Connect(function() step(1) end)
        btn.MouseButton2Click:Connect(function() step(-1) end)
        el._upd = function() pcall(function() val.Text = tostring(el.value) end) end
    end

    local function buildKeybindRow(parent, order, el)
        local f = ctlFrame(parent, order, CTL_H)
        mkText(f, tostring(el.label), 11.5, false, C_TXT).Size = UDim2.new(1, -60, 1, 0)
        local kbtn = Instance.new("TextButton")
        kbtn.Size = UDim2.new(0, 52, 0, 16)
        kbtn.Position = UDim2.new(1, -54, 0.5, -8)
        kbtn.Font = Enum.Font.GothamBold
        kbtn.TextSize = 10.5
        kbtn.AutoButtonColor = false
        kbtn.BorderSizePixel = 0
        kbtn.BackgroundColor3 = C_BG
        kbtn.TextColor3 = C_ACCENT
        mkCorner(kbtn, 4)
        mkStroke(kbtn)
        kbtn.Parent = f
        local function paint()
            local n = (el.value and el.value.Name) or "None"
            kbtn.Text = "[" .. tostring(n) .. "]"
        end
        kbtn.MouseButton1Click:Connect(function()
            keyCaptureEl = el
            kbtn.Text = "[...]"
        end)
        el._upd = function() pcall(paint) end
        paint()
    end

    local function buildBindRow(parent, order, el)
        local entry = el.entry
        local f = ctlFrame(parent, order, CTL_H)
        mkText(f, tostring(entry.label), 11.5, false, C_TXT).Size = UDim2.new(1, -60, 1, 0)
        local kbtn = Instance.new("TextButton")
        kbtn.Size = UDim2.new(0, 52, 0, 16)
        kbtn.Position = UDim2.new(1, -54, 0.5, -8)
        kbtn.Font = Enum.Font.GothamBold
        kbtn.TextSize = 10.5
        kbtn.AutoButtonColor = false
        kbtn.BorderSizePixel = 0
        kbtn.BackgroundColor3 = C_BG
        kbtn.TextColor3 = C_ACCENT
        mkCorner(kbtn, 4)
        mkStroke(kbtn)
        kbtn.Parent = f
        local function paint()
            local n = (entry.key and entry.key.Name) or "None"
            kbtn.Text = "[" .. tostring(n) .. "]"
        end
        kbtn.MouseButton1Click:Connect(function()
            keyCaptureEl = {
                _upd = function() end, -- заглушка; значение пишем сами ниже
            }
            -- штатный capture пишет в el.value — нам нужен entry.key:
            keyCaptureEl = nil
            local cap = nil
            kbtn.Text = "[...]"
            cap = UIS.InputBegan:Connect(function(inp)
                if cap == nil then return end
                if inp.KeyCode == Enum.KeyCode.Escape then
                    cap:Disconnect() cap = nil
                    paint()
                    return
                end
                if inp.UserInputType == Enum.UserInputType.Keyboard then
                    pcall(function() entry.key = inp.KeyCode end)
                    if BindRowRefs and BindRowRefs[entry] then pcall(BindRowRefs[entry]) end
                    cap:Disconnect() cap = nil
                    paint()
                end
            end)
        end)
        el._upd = function() pcall(paint) end
        paint()
    end

    local function buildButtonRow(parent, order, el)
        local f = ctlFrame(parent, order, CTL_H)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundColor3 = C_ROW_ON
        btn.BackgroundTransparency = 0.55
        btn.TextColor3 = C_TXT
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11.5
        btn.Text = tostring(el.label)
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        mkCorner(btn, 4)
        btn.Parent = f
        btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.25 end)
        btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 0.55 end)
        btn.MouseButton1Click:Connect(function()
            pcall(function() if el.cb then el.cb() end end)
        end)
    end

    local function buildPlistBlock(parent, order, el)
        local h = (el.height or 140)
        local f = ctlFrame(parent, order, h + 4)
        local sf = Instance.new("ScrollingFrame")
        sf.BackgroundColor3 = C_BG
        sf.BackgroundTransparency = 0.3
        sf.BorderSizePixel = 0
        sf.Size = UDim2.new(1, 0, 1, 0)
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.ScrollBarThickness = 2
        sf.ScrollBarImageColor3 = C_ACCENT
        mkCorner(sf, 4)
        sf.Parent = f
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = sf
        local rowRefs2 = {}
        local function paintRows()
            for _, r in pairs(rowRefs2) do pcall(function() r:Destroy() end) end
            rowRefs2 = {}
            local data = el.data or {}
            if #data == 0 then
                local l = mkText(sf, "  (пусто)", 10.5, false, C_DIM)
                l.Size = UDim2.new(1, 0, 0, 18)
                table.insert(rowRefs2, l)
                return
            end
            for i, d in ipairs(data) do
                local rb = Instance.new("TextButton")
                rb.Size = UDim2.new(1, 0, 0, 18)
                rb.BackgroundTransparency = 1
                rb.Text = ""
                rb.AutoButtonColor = false
                rb.LayoutOrder = i
                rb.Parent = sf
                local sel = (el.selected == d.name)
                if sel then rb.BackgroundColor3 = C_ROW_ON rb.BackgroundTransparency = 0.2 end
                mkText(rb, d.name, 10.5, false, sel and C_TXT or C_DIM).Position = UDim2.new(0, 6, 0, 0)
                local nm = rb:FindFirstChildOfClass("TextLabel")
                if nm then nm.Size = UDim2.new(0.7, 0, 1, 0) end
                local dl = mkText(rb, tostring(d.dist), 9.5, false, C_DIM, Enum.TextXAlignment.Right)
                dl.Size = UDim2.new(0.28, -6, 1, 0)
                dl.Position = UDim2.new(0.7, 0, 0, 0)
                table.insert(rowRefs2, rb)
                rb.MouseButton1Click:Connect(function()
                    el.selected = d.name
                    if el.onConnect then pcall(el.onConnect, d.name) end
                    paintRows()
                end)
            end
        end
        el._paint = function() pcall(paintRows) end
        paintRows()
    end

    buildSettings = function(holder, m)
        local order = 0
        -- Enabled первым (если у модуля есть enableKey)
        if m.enableKey and Cfg[m.enableKey] then
            order = order + 1
            local ek = m.enableKey
            local enPaint = buildToggleRow(holder, order, "Enabled",
                function() local ok, v = pcall(function() return Cfg[ek].get() end) return ok and v end,
                function(v) pcall(function() Cfg[ek].set(v) end) end
            )
            local rd0 = rowRefs[m]
            if rd0 then rd0.enrPaint = enPaint end
        end
        for _, el in ipairs(m.elements) do
            order = order + 1
            local _el, _ord = el, order
            pcall(function()
                if _el.kind == "section" then
                    local f = ctlFrame(holder, _ord, 16)
                    local l = mkText(f, "— " .. tostring(_el.title) .. " —", 10.5, true, C_DIM, Enum.TextXAlignment.Center)
                    l.Size = UDim2.new(1, 0, 1, 0)
                elseif _el.kind == "toggle" then
                    local k = _el.key
                    local paint
                    paint = buildToggleRow(holder, _ord, _el.label,
                        function() return _el.value end,
                        function(v)
                            if k and Cfg[k] then
                                pcall(function() Cfg[k].set(v) end)
                            else
                                _el.value = v
                                pcall(function() if _el.cb then _el.cb(v) end end)
                                paint()
                            end
                        end
                    )
                    _el._upd = function() pcall(paint) end
                elseif _el.kind == "slider" then
                    buildSliderBlock(holder, _ord, _el)
                elseif _el.kind == "dropdown" then
                    buildDropdownRow(holder, _ord, _el)
                elseif _el.kind == "keybind" then
                    buildKeybindRow(holder, _ord, _el)
                elseif _el.kind == "bindrow" then
                    buildBindRow(holder, _ord, _el)
                elseif _el.kind == "button" then
                    buildButtonRow(holder, _ord, _el)
                elseif _el.kind == "text" then
                    local f = ctlFrame(holder, _ord, 10)
                    f.AutomaticSize = Enum.AutomaticSize.Y
                    local l = mkText(f, tostring(_el.text), 10, false, C_DIM)
                    l.Size = UDim2.new(1, 0, 0, 0)
                    l.AutomaticSize = Enum.AutomaticSize.Y
                    l.TextWrapped = true
                elseif _el.kind == "plist" then
                    buildPlistBlock(holder, _ord, _el)
                end
            end)
        end
    end

    -- ---------- колонка категории ----------
    local relayoutRoot
    local function makeColumn(cat)
        local f = Instance.new("Frame")
        f.Name = "Col_" .. tostring(cat)
        f.BackgroundColor3 = C_BG
        f.BackgroundTransparency = 0.12
        f.BorderSizePixel = 0
        f.Size = UDim2.new(0, COL_W, 0, 120)
        mkCorner(f, 8)
        mkStroke(f)
        f.Parent = root
        local head = mkText(f, tostring(cat), 14, true, C_TXT, Enum.TextXAlignment.Center)
        head.Size = UDim2.new(1, 0, 0, HEADER_H)
        local scroll = Instance.new("ScrollingFrame")
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.Position = UDim2.new(0, 4, 0, HEADER_H)
        scroll.Size = UDim2.new(1, -8, 1, -HEADER_H - 6)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = C_LINE
        scroll.Parent = f
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 2)
        lay.Parent = scroll
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 2)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.Parent = scroll
        local col = {frame = f, scroll = scroll, list = lay, cat = cat}
        catCols[cat] = col
        table.insert(colOrder, col)
        lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h = lay.AbsoluteContentSize.Y + HEADER_H + 12
            if h > PANEL_MAXH then h = PANEL_MAXH end
            f.Size = UDim2.new(0, COL_W, 0, h)
            if relayoutRoot then relayoutRoot() end
        end)
        return col
    end

    local function sortCols()
        table.sort(colOrder, function(a, b)
            local ka = CAT_SORT[a.cat] or 99
            local kb = CAT_SORT[b.cat] or 99
            if ka ~= kb then return ka < kb end
            return tostring(a.cat) < tostring(b.cat)
        end)
    end

    relayoutRoot = function()
        local x, maxH = 0, 0
        for _, col in ipairs(colOrder) do
            if col.frame.Visible then
                col.frame.Position = UDim2.new(0, x, 0, 0)
                x = x + COL_W + GAP
                local h = col.frame.Size.Y.Offset
                if h > maxH then maxH = h end
            end
        end
        if x > 0 then x = x - GAP end
        root.Size = UDim2.new(0, math.max(x, COL_W), 0, math.max(maxH, 80))
    end

    -- ---------- строка модуля ----------
    local searchQ = ""
    local function moduleEnabled(m)
        if not m.enableKey or not Cfg[m.enableKey] then return false end
        local ok, v = pcall(function() return Cfg[m.enableKey].get() end)
        return ok and v == true
    end

    local function applySearch()
        local q = searchQ
        for m, rd in pairs(rowRefs) do
            local vis = (q == "") or (string.find(string.lower(m.title), q, 1, true) ~= nil)
            rd.row.Visible = vis
            if not vis and openModule == m then closeSettings() end
        end
        for _, col in ipairs(colOrder) do
            local any = false
            for m, rd in pairs(rowRefs) do
                if m.cat == col.cat and rd.row.Visible then any = true break end
            end
            col.frame.Visible = any
        end
        relayoutRoot()
    end

    local function makeModuleRow(col, m, order)
        local row = Instance.new("TextButton")
        row.Name = "M_" .. tostring(m.title)
        row.Size = UDim2.new(1, -4, 0, ROW_H)
        row.BackgroundColor3 = C_ROW_ON
        row.BackgroundTransparency = 1
        row.AutoButtonColor = false
        row.BorderSizePixel = 0
        row.Text = ""
        row.LayoutOrder = order * 2
        mkCorner(row, 4)
        row.Parent = col.scroll
        local nameL = mkText(row, tostring(m.title), 12, false, C_TXT)
        nameL.Size = UDim2.new(1, -34, 1, 0)
        nameL.Position = UDim2.new(0, 9, 0, 0)
        nameL.TextTruncate = Enum.TextTruncate.AtEnd
        local dots = Instance.new("TextButton")
        dots.Size = UDim2.new(0, 26, 1, 0)
        dots.Position = UDim2.new(1, -26, 0, 0)
        dots.BackgroundTransparency = 1
        dots.Text = "•••"
        dots.Font = Enum.Font.GothamBold
        dots.TextSize = 10
        dots.TextColor3 = C_DIM
        dots.AutoButtonColor = false
        dots.Parent = row
        local rd = {order = order, dots = dots}
        rd.paint = function()
            local on = moduleEnabled(m)
            row.BackgroundTransparency = on and 0.12 or 1
            nameL.TextColor3 = on and Color3.new(1, 1, 1) or C_TXT
        end
        local openKey = (m.enableKey ~= nil) and Cfg[m.enableKey] and m.enableKey or nil
        row.MouseButton1Click:Connect(function()
            if openKey then
                pcall(function() Cfg[m.enableKey].set(not moduleEnabled(m)) end)
            else
                toggleSettings(m)
            end
        end)
        row.MouseButton2Click:Connect(function() toggleSettings(m) end)
        dots.MouseButton1Click:Connect(function() toggleSettings(m) end)
        row.MouseEnter:Connect(function()
            if not moduleEnabled(m) then
                row.BackgroundColor3 = C_ROW_HOV
                row.BackgroundTransparency = 0.35
            end
        end)
        row.MouseLeave:Connect(function()
            row.BackgroundColor3 = C_ROW_ON
            rd.paint()
        end)
        rd.row = row
        rowRefs[m] = rd
        return row
    end

    -- ---------- собрать всё из реестра MODULES ----------
    local built = 0
    do
        -- сгруппировать модули по категориям с сохранением порядка
        local byCat = {}
        local catSeq = {}
        for _, m in ipairs(MODULES) do
            if (#m.elements > 0) or m.enableKey then
                local c = tostring(m.cat or "Miscellaneous")
                if not byCat[c] then byCat[c] = {} table.insert(catSeq, c) end
                table.insert(byCat[c], m)
            end
        end
        table.sort(catSeq, function(a, b)
            return (CAT_SORT[a] or 99) < (CAT_SORT[b] or 99)
        end)
        for _, cat in ipairs(catSeq) do
            local col = makeColumn(cat)
            for i, m in ipairs(byCat[cat]) do
                local okM = pcall(function() makeModuleRow(col, m, i) end)
                if okM then built = built + 1 end
            end
        end
        sortCols()
        relayoutRoot()
    end
    print(("[SpermaHub] spermaclick: модулей отрисовано: %d, категорий: %d"):format(built, #colOrder))

    -- подсветка включённых модулей из Cfg.set / respawn-хандлеров
    updModHeader = function(m)
        local rd = rowRefs[m]
        if rd then
            pcall(rd.paint)
            if rd.enrPaint then pcall(rd.enrPaint) end
        end
    end
    for m, rd in pairs(rowRefs) do pcall(rd.paint) end

    -- ---------- дрэг слайдеров (глобальный) ----------
    UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            pcall(function() dragging.apply(inp.Position.X) end)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
    end)

    -- ---------- футер: поиск + hint + Ctrl+G полоска ----------
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "Search"
    searchBox.AnchorPoint = Vector2.new(0.5, 1)
    searchBox.Position = UDim2.new(0.5, 0, 1, -76)
    searchBox.Size = UDim2.new(0, 220, 0, 30)
    searchBox.BackgroundColor3 = C_BG
    searchBox.BackgroundTransparency = 0.12
    searchBox.PlaceholderText = "Search"
    searchBox.PlaceholderColor3 = C_DIM
    searchBox.Text = ""
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12.5
    searchBox.TextColor3 = C_TXT
    searchBox.ClearTextOnFocus = false
    mkCorner(searchBox, 6)
    mkStroke(searchBox)
    searchBox.Parent = gui
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQ = string.lower(searchBox.Text)
        applySearch()
    end)

    local hint = mkText(gui, "Additional options - CTRL + G (Hold)", 11.5, false, C_DIM, Enum.TextXAlignment.Center)
    hint.AnchorPoint = Vector2.new(0.5, 1)
    hint.Position = UDim2.new(0.5, 0, 1, -50)
    hint.Size = UDim2.new(0, 400, 0, 16)

    -- Ctrl+G (Hold): доп. опции — как в референсе
    local strip = Instance.new("Frame")
    strip.Name = "CtrlG"
    strip.AnchorPoint = Vector2.new(0.5, 1)
    strip.Position = UDim2.new(0.5, 0, 1, -116)
    strip.Size = UDim2.new(0, 360, 0, 30)
    strip.BackgroundTransparency = 1
    strip.Visible = false
    strip.Parent = gui
    local stripLay = Instance.new("UIListLayout")
    stripLay.FillDirection = Enum.FillDirection.Horizontal
    stripLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    stripLay.Padding = UDim.new(0, 8)
    stripLay.Parent = strip
    local function stripBtn(txt, fn)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 112, 0, 28)
        b.BackgroundColor3 = C_BG
        b.BackgroundTransparency = 0.12
        b.TextColor3 = C_TXT
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 11.5
        b.Text = txt
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        mkCorner(b, 6)
        mkStroke(b)
        b.Parent = strip
        b.MouseEnter:Connect(function() b.BackgroundColor3 = C_ROW_ON end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = C_BG end)
        b.MouseButton1Click:Connect(function() pcall(fn) end)
        return b
    end
    stripBtn("Rejoin", function()
        Tele:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
    stripBtn("Copy Discord", function()
        if type(setclipboard) == "function" then setclipboard(CG_LINK) end
    end)
    stripBtn("Close Script", function()
        if type(fullCleanupNL) == "function" then fullCleanupNL() end
    end)

    -- ---------- открыть/закрыть меню ----------
    local function setGuiOpen(openV)
        CG_OPEN = openV and true or false
        gui.Enabled = CG_OPEN
        if CG_OPEN then
            for m, rd in pairs(rowRefs) do pcall(rd.paint) end
            pcall(applySearch)
        end
    end
    S.rsToggleConn = UIS.InputBegan:Connect(function(input, gpe)
        if (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert) and not gpe then
            setGuiOpen(not CG_OPEN)
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape and CG_OPEN then
            setGuiOpen(false)
            return
        end
        -- Ctrl+G hold
        if input.KeyCode == Enum.KeyCode.G and CG_OPEN then
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
                strip.Visible = true
            end
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.G then strip.Visible = false end
    end)

    print("[SpermaHub] SpermaClick готов: RightShift/Insert — меню, ... — настройки модуля, Ctrl+G — доп. опции")
    -- rev54: авто-открытие при загрузке (раньше меню стартовало скрытым — юзер думал, что оно не живое)
    task.delay(0.4, function()
        pcall(function() setGuiOpen(true) end)
    end)
end

-- финальная инициализация (viewport-коннекты; watermark заглушен)
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
    if type(doLoad) == "function" then pcall(doLoad, "Global", true) end
end)

bootStep("финал OK")
pcall(function() BootGui:Destroy() end)
print("[SpermaHub] gui: рендер завершён")

toastImpl("SpermaHub", "SpermaHub загружен! RightShift/Insert — меню")
print("✦ SpermaHub загружен!")
print("Combat: Legitbot | Hitbox | Kill | Fling | Spectate | Anti-Aim | AutoClicker + AntiFling/AutoStrafe")
print("Visuals + Movement + Player + Server (Bypass/Server) | Misc")
